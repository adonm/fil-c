--!nonstrict
-- Pointer-flow analysis over the lifted IR (register webs = temps).
-- Determines which temps hold pointers and, for each, the temp that carries its
-- `lower` (capability). Lowers propagate unchanged through copies and address
-- arithmetic (GEP), matching GIMSO semantics.
--
-- Seeds (provided by the caller):
--   argPtrTemps  : array of temp ids that are pointer arguments
--   loadPtrDefs  : set of node -> true for `;! load ptr` nodes (their def temp is a ptr)
--   callPtrDefs  : set of node -> true for call nodes whose result is a pointer
--
-- Returns { isPtr = {temp->bool}, lowerTemp = {temp->loTemp}, newTemps = {...} }
-- New lower temps are allocated via allocTemp().

local ptrflow = {}

function ptrflow.analyze(lf, seeds, allocTemp, opts)
	opts = opts or {}
	local baseMnemonic = opts.baseMnemonic or function(m) return string.lower(m) end
	local isPtr = {}
	local lowerTemp = {}     -- ptr temp -> its lower temp
	local nodes = lf.nodes

	local function ensureLower(t)
		if not lowerTemp[t] then
			lowerTemp[t] = allocTemp({ isLower = true, forPtr = t })
		end
		return lowerTemp[t]
	end

	-- Seed argument pointers.
	for _, t in (seeds.argPtrTemps or {}) do
		isPtr[t] = true
		ensureLower(t)
	end
	-- Seed load-ptr / call-ptr / alloca-result definitions (their def temp is a pointer
	-- with a fresh lower).
	for _, node in nodes do
		if node.kind == "insn" then
			if (seeds.loadPtrDefs and seeds.loadPtrDefs[node])
				or (seeds.callPtrDefs and seeds.callPtrDefs[node])
				or (seeds.allocaResultDefs and seeds.allocaResultDefs[node]) then
				local d = node.defTemps and node.defTemps[1]
				if d then isPtr[d] = true; ensureLower(d) end
			end
		end
	end

	-- Fixpoint propagation through copies and address arithmetic.
	--
	-- Convergence. isPtr only ever goes false->true, but a temp's lower CAN be reassigned
	-- by a later def of the same web (x86 2-operand RMW instructions and branch joins
	-- both give one web several def nodes). Reassignment is fine when the web's pointer
	-- sources eventually agree (e.g. a `;! load ptr` seed's fresh lower gets replaced by
	-- the propagated source's lower and stays there). A web whose defs draw on genuinely
	-- different pointer origins never settles: the lower flip-flops between the origins'
	-- lowers forever. Each pass is a deterministic function of the (isPtr, lowerTemp)
	-- state, so a repeated global state proves non-convergence.
	--
	-- Dynamic-lower widening (the pointer-SWAP case). A non-converging web is not always
	-- a genuine conflict: a loop-carried pointer swap (keccak1600's `xchgq %rsi,%rdi`
	-- bounce-buffer round, or the equivalent three-move rotation) oscillates because no
	-- STATIC lower is correct for a web whose runtime value alternates between two
	-- origins — but a DYNAMIC lower is: give the web its own fresh lower temp and mirror
	-- every pointer def of the iv web with a lower def from the same source (a "lockstep
	-- copy"), so the (iv, lower) pairing tracks the iv dataflow exactly at runtime. The
	-- lower temp then has one def per iv def (a phi, exactly like the iv web itself) and
	-- the assignment lowerTemp[web] is fixed at creation — the fixpoint can no longer
	-- oscillate on it. Widening is monotone (a web goes dynamic at most once), so the
	-- loop terminates. The copies themselves are emitted by the transform from the
	-- returned dynCopy map; a swap's crossed pair is emitted atomically (via a scratch).
	-- Widening is sound: every capability a dynamic lower can hold entered through a
	-- seed, and every seed roots its lower at definition, so the GC still sees every
	-- live capability; and a stale lower on a scalar-holding def can only trap or pass
	-- for an in-bounds address, never access out of bounds.
	--
	-- Contagion: a pointer COPY whose source is dynamic must snapshot the source's
	-- lower at the copy point (sharing it would observe the source's LATER swaps), so
	-- copies out of dynamic webs widen the destination too. xchg is modeled as the
	-- crossed pair (first operand's def web receives the second operand's pointer-ness
	-- and lower, and vice versa); in a loop the crossed sharing oscillates and the
	-- widening above turns it into the runtime lower swap. A web defined by an xchg is
	-- widened together with its swap partner: the emission exchanges the two lowers,
	-- so both sides must be dynamic (or neither).
	-- The widening machinery is enabled per-target (x86_64; arm64 keeps the
	-- historical clean rejection — no xchg exists there, and its codegen is
	-- unchanged by construction).
	local widen = opts.widenSwaps and true or false
	local dynamic = {}        -- web -> true once widened to a lockstep lower
	local dynSrc = {}         -- node -> { [defWeb] = sourceWeb } for dynamic defs
	local isXchg = function(m) return string.match(m, "^xchg[bwlq]?$") ~= nil end

	local dynamicize
	function dynamicize(d)
		if dynamic[d] or not widen then return dynamic[d] and true or false end
		dynamic[d] = true
		isPtr[d] = true
		lowerTemp[d] = allocTemp({ isLower = true, forPtr = d, dynamicLower = true })
		-- Widen the swap partner too (see above): the xchg emission swaps the lowers.
		for _, node in nodes do
			if node.kind == "insn" then
				local m = baseMnemonic(node.stmt and node.stmt.mnemonic or node.mnemonic or "")
				if isXchg(m) then
					local defs = node.defTemps or {}
					if defs[1] == d and defs[2] and isPtr[defs[2]] then dynamicize(defs[2]) end
					if defs[2] == d and defs[1] and isPtr[defs[1]] then dynamicize(defs[1]) end
				end
			end
		end
		return true
	end

	local seenStates = {}
	local changed = true
	while changed do
		changed = false
		local reassigned = {}
		for _, node in nodes do
			local seeded = (seeds.loadPtrDefs and seeds.loadPtrDefs[node])
				or (seeds.allocaResultDefs and seeds.allocaResultDefs[node])
			if node.kind == "insn" and not seeded then
				local m = baseMnemonic(node.stmt and node.stmt.mnemonic or node.mnemonic or "")
				local us = node.useTemps or {}
				local function markFrom(d, srcPtr)
					if not d or not isPtr[srcPtr] then return end
					if dynamic[srcPtr] and not dynamic[d] then
						-- snapshot contagion (see above)
						dynamicize(d)
						changed = true
					end
					if dynamic[d] then
						-- the lower is fixed; record the def's source for the lockstep
						-- copy the transform emits at this node.
						dynSrc[node] = dynSrc[node] or {}
						dynSrc[node][d] = srcPtr
						return
					end
					if not isPtr[d] then isPtr[d] = true; changed = true end
					local lo = lowerTemp[srcPtr]
					if lo and lowerTemp[d] ~= lo then
						if lowerTemp[d] ~= nil then reassigned[d] = true end
						lowerTemp[d] = lo; changed = true
					end
				end
				-- A memory operand's base/index registers are consumed as an ADDRESS, not
				-- as a value source: a memory-source instruction is a LOAD, and the loaded
				-- value's pointer-ness comes from a `;! load ptr` seed, never the address
				-- register. On x86 a load is `mov reg, [mem]`, so without the hasMemSrc
				-- guard ptrflow would treat it as `reg = base` and flip-flop the lower
				-- forever. The same applies to memory-source arithmetic like
				-- `addq (%rsi), %rax` (which adds the loaded SCALAR to %rax): the address
				-- registers are excluded from the pointer-source candidates, otherwise
				-- each such def would re-derive %rax's lower from its own address register
				-- and flip-flop across the defs of the web. (`lea` is the exception: its
				-- memory-shaped operand IS the computed value, so its base/index remain
				-- legitimate pointer sources.)
				local hasMemSrc = false
				local addrUse = nil
				local sops = node.stmt and node.stmt.operands
				if sops then
					for _, op in sops do
						if op.kind == "mem" then
							hasMemSrc = true
							if m ~= "lea" and node.opTemp then
								if op.base and node.opTemp[op.base] then
									if not addrUse then addrUse = {} end
									addrUse[node.opTemp[op.base]] = true
								end
								if op.index and node.opTemp[op.index] then
									if not addrUse then addrUse = {} end
									addrUse[node.opTemp[op.index]] = true
								end
							end
						end
					end
				end
				if isXchg(m) then
					-- register-register xchg (memory forms are rejected by classify):
					-- the crossed pair — each def web receives the OTHER operand's value.
					local defs = node.defTemps or {}
					if #defs == 2 and #us == 2 then
						-- A LOOP-CARRIED swap (each def web coincides with its use web —
						-- the def site reaches back into the web the xchg reads): the
						-- web's runtime value alternates between the two origins, so no
						-- static lower is correct (crossed sharing converges to BOTH
						-- webs sharing one origin's lower — false traps half the time).
						-- Force the dynamic lower swap. (A straight-line xchg has fresh
						-- def webs: crossed sharing is exact there, and a swap of two
						-- same-origin pointers shares one lower already.)
						local loopCarried = (defs[1] == us[1] or defs[1] == us[2])
							and (defs[2] == us[1] or defs[2] == us[2])
						if widen and loopCarried and isPtr[us[1]] and isPtr[us[2]]
							and lowerTemp[us[1]] ~= lowerTemp[us[2]]
							and not (dynamic[defs[1]] and dynamic[defs[2]]) then
							dynamicize(defs[1])
							dynamicize(defs[2])
							changed = true
						end
						markFrom(defs[1], us[2])
						markFrom(defs[2], us[1])
					end
				else
					local d = node.defTemps and node.defTemps[1]
					if d then
						if m == "mov" and #us == 1 and not hasMemSrc then
							markFrom(d, us[1])
						elseif m == "cmov" then
							-- x86 cmov: a CONDITIONAL merge of the register source into
							-- the destination web (the rmw union makes the def web the
							-- destination's use web): d = cond ? src : d. A memory
							-- source is a load — the loaded value is a scalar here
							-- (pointer loads carry `;! load ptr`, never a cmov), and
							-- memory address registers are excluded from value sources
							-- as usual. Pointer-ness merges in from the source: a web
							-- not yet a pointer simply shares the source's lower (the
							-- not-taken path then carries a stale lower on a scalar —
							-- the documented sound case, like a join). A web that is
							-- ALREADY a pointer with the SAME lower needs nothing.
							-- With DIFFERENT lowers no static lower is correct (the
							-- hardware picks per execution): widen to a dynamic
							-- (lockstep) lower and maintain it at this node with a
							-- CONDITIONAL lower copy — a cmov on the lower temps with
							-- the same condition, emitted by the transform right after
							-- the iv cmov (dynCopy carries `cmov = true`).
							local src = nil
							for _, u in us do
								if u ~= d and not (addrUse and addrUse[u]) then src = u break end
							end
							if src and isPtr[src] then
								if dynamic[d] then
									dynSrc[node] = dynSrc[node] or {}
									dynSrc[node][d] = src
								elseif isPtr[d] and lowerTemp[d] ~= lowerTemp[src] then
									if dynamicize(d) then
										dynSrc[node] = dynSrc[node] or {}
										dynSrc[node][d] = src
										changed = true
									else
										-- widening disabled on this target: treat as a
										-- plain conflicting merge — the cycle detector
										-- reports the non-convergence cleanly.
										markFrom(d, src)
									end
								elseif not isPtr[d] then
									markFrom(d, src)
								end
							end
						elseif m == "add" or m == "sub" or m == "orr" or m == "lea"
							or m == "lsl" or m == "lsr" or m == "asr" or m == "and"
							or m == "or" or m == "shl" or m == "shr" or m == "sar" then
							-- address arithmetic / alignment: a pointer combined with integers
							-- keeps the pointer's lower (bounds checks still guard any misuse).
							local ptrSrc, intCount = nil, 0
							for _, u in us do
								if addrUse and addrUse[u] then
									-- consumed as a memory address, not a value source
								elseif isPtr[u] then ptrSrc = u else intCount += 1 end
							end
							if ptrSrc and not (m == "sub" and intCount == 0) then
								markFrom(d, ptrSrc)
							end
						end
					end
				end
			end
		end
		if changed then
			-- Cycle detection: a repeated (isPtr, lowerTemp) state after a changing pass
			-- means the deterministic sharing iteration would loop forever (see above);
			-- widen the webs it reassigned to dynamic lowers and keep going.
			local parts = {}
			for t, lo in lowerTemp do table.insert(parts, tostring(t) .. "=" .. tostring(lo)) end
			for t, v in isPtr do if v then table.insert(parts, tostring(t) .. "=ptr") end end
			for t, v in dynamic do if v then table.insert(parts, tostring(t) .. "=dyn") end end
			table.sort(parts)
			local key = table.concat(parts, ";")
			if seenStates[key] then
				-- Widen in sorted order: the fresh lower temps are allocated in this
				-- order, and hash iteration over the reassigned set would make the
				-- temp ids (and every later temp id, spill layout, and coloring
				-- tie-break) reorder per process — nondeterministic output.
				local widened = {}
				for d in reassigned do table.insert(widened, d) end
				table.sort(widened)
				local any = false
				for _, d in widened do
					if dynamicize(d) then any = true end
				end
				if not any then
					-- Genuine conflict (or widening disabled on this target): one web
					-- has a single runtime lower, so it cannot hold pointers from two
					-- origins — reject cleanly instead of spinning.
					error("sarcasm: pointer-flow analysis does not converge: a register web "
						.. "has conflicting pointer sources (one temp cannot carry two capabilities)")
				end
				seenStates = {}
			else
				seenStates[key] = true
			end
		end
	end

	-- The lockstep emission map for the transform, in statement order (deterministic):
	-- mov/lea-family defs of a dynamic web get a lower copy from the def's source;
	-- a cmov def gets a CONDITIONAL lower copy (cmov = true — the iv merge is
	-- conditional, so the lower merge must be too); an xchg gets the crossed pair
	-- (emitted atomically — the sources alias the destinations in a loop-carried
	-- swap).
	local dynCopy = {}
	for _, node in nodes do
		local dm = dynSrc[node]
		if dm then
			local m = baseMnemonic(node.stmt and node.stmt.mnemonic or node.mnemonic or "")
			if isXchg(m) then
				local defs = node.defTemps or {}
				local c1 = dm[defs[1]] and { dst = lowerTemp[defs[1]], src = lowerTemp[dm[defs[1]]] } or nil
				local c2 = dm[defs[2]] and { dst = lowerTemp[defs[2]], src = lowerTemp[dm[defs[2]]] } or nil
				if c1 and c1.dst == c1.src then c1 = nil end
				if c2 and c2.dst == c2.src then c2 = nil end
				if (c1 and not c1.src) or (c2 and not c2.src) then
					-- one-sided swap with a lower-less (non-pointer) partner: the dynamic
					-- side's static lower stays correct for its origin (the swap hands
					-- the scalar side a null capability — pointer uses of it trap).
					if c1 and not c1.src then c1 = nil end
					if c2 and not c2.src then c2 = nil end
				end
				local copies = {}
				if c1 then table.insert(copies, c1) end
				if c2 then table.insert(copies, c2) end
				if #copies > 0 then dynCopy[node] = { xchg = true, copies = copies } end
			else
				local copies = {}
				for _, d in (node.defTemps or {}) do
					local srcPtr = dm[d]
					local dstLo = d and lowerTemp[d]
					local srcLo = srcPtr and lowerTemp[srcPtr]
					if dstLo and srcLo and dstLo ~= srcLo then
						table.insert(copies, { dst = dstLo, src = srcLo })
					end
				end
				-- A cmov's lockstep copy must be CONDITIONAL (the iv merge fires
				-- only when the condition holds): `cmov = true` tells the
				-- transform to emit it as a cmov with the node's own condition,
				-- immediately after the iv cmov (the flags still hold it).
				if #copies > 0 then dynCopy[node] = { copies = copies, cmov = (m == "cmov") or nil } end
			end
		end
	end

	return { isPtr = isPtr, lowerTemp = lowerTemp, dynCopy = dynCopy }
end

return ptrflow
