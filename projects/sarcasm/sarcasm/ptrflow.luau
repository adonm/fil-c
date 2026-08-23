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
	-- state, so a repeated global state proves non-convergence. That is a genuine
	-- conflict -- one web has a single runtime lower, so it cannot hold pointers from
	-- two origins -- and is rejected cleanly instead of spinning.
	local seenStates = {}
	local changed = true
	while changed do
		changed = false
		for _, node in nodes do
			local seeded = (seeds.loadPtrDefs and seeds.loadPtrDefs[node])
				or (seeds.allocaResultDefs and seeds.allocaResultDefs[node])
			if node.kind == "insn" and not seeded then
				local m = baseMnemonic(node.stmt and node.stmt.mnemonic or node.mnemonic or "")
				local d = node.defTemps and node.defTemps[1]
				local us = node.useTemps or {}
				local function markFrom(srcPtr)
					if not isPtr[d] then isPtr[d] = true; changed = true end
					local lo = lowerTemp[srcPtr]
					if lo and lowerTemp[d] ~= lo then lowerTemp[d] = lo; changed = true end
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
				if d then
					if m == "mov" and #us == 1 and not hasMemSrc then
						if isPtr[us[1]] then markFrom(us[1]) end
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
							markFrom(ptrSrc)
						end
					end
				end
			end
		end
		if changed then
			-- Cycle detection: a repeated (isPtr, lowerTemp) state after a changing pass
			-- means the deterministic iteration would loop forever (see above).
			local parts = {}
			for t, lo in lowerTemp do table.insert(parts, tostring(t) .. "=" .. tostring(lo)) end
			for t, v in isPtr do if v then table.insert(parts, tostring(t) .. "=ptr") end end
			table.sort(parts)
			local key = table.concat(parts, ";")
			if seenStates[key] then
				error("sarcasm: pointer-flow analysis does not converge: a register web "
					.. "has conflicting pointer sources (one temp cannot carry two capabilities)")
			end
			seenStates[key] = true
		end
	end

	return { isPtr = isPtr, lowerTemp = lowerTemp }
end

return ptrflow
