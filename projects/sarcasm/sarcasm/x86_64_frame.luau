--!nonstrict
-- x86_64 frame policy for the shared frame preprocessor (frame.luau). Provides frame-size
-- analysis and the per-statement rewrite: dropping SysV frame setup/teardown (push/pop of
-- rbp + callee-saved, `mov %rsp,%rbp`, `sub/add %rsp`, `leave`, `endbr64`), virtualizing
-- rbp/rsp-relative slots as pseudo-registers, and rejecting stack-address escapes.
--
-- Frame geometry is derived from the PROLOGUE PREFIX ONLY (see analyzeFrame): the leading
-- run of frame-setup instructions (callee-saved pushes/pops, `movq %rsp,%rbp`, constant
-- `subq $imm,%rsp` allocations and net-balanced `addq $imm,%rsp` undos within the prefix)
-- interleaved with prologue-transparent instructions (ones that cannot observe or modify
-- the stack state). The frame size is the NET stack depth at the end of that prefix (D0) —
-- relative to the frame pointer when one is established — so a transient mid-body
-- `subq $8,%rsp; addq $8,%rsp` pad or `pushq %rbx; ...; popq %rbx` pair can no longer
-- inflate frameSize and desync the rbp<->rsp slot normalization (a former silent
-- miscompile).
--
-- After the prologue, rsp must provably stay at D0 except inside balanced callee-saved
-- push/pop save regions (those are simply dropped — sarcasm synthesizes its own frame —
-- which is sound only while no stack access observes the shifted rsp). analyzeFrame runs a
-- control-flow rsp-depth analysis that proves at which abstract depth every instruction
-- executes, and the rewrite REJECTS whatever cannot be proven safe rather than silently
-- miscompiling:
--   * pops with no provably matching push (same register, same slot depth) on every path —
--     dropping such a pop would silently lose its load, and the slot it actually reads is
--     not that register's save (e.g. an unpaired `popq %rbx` after `pushq %rbp` reads the
--     saved frame pointer — a live stack address — into rbx). Balanced pairs, epilogue
--     restores of prologue saves, and verified-teardown pops all pair exactly and keep
--     being dropped;
--   * reads of the frame pointer as a VALUE (`movq %rbp, %rax`, an rbp memory index) while
--     rbp is the frame pointer — the same stack-address escape class as reading rsp, so the
--     fall-through escape check treats rbp as a stack register whenever usesRbp holds;
--   * mid-function constant or non-constant rsp adjustments (`subq`/`addq`/`mov` to %rsp)
--     that are not epilogue teardown (teardown = an `addq $imm,%rsp` / `movq %rbp,%rsp`
--     leading to `ret` through callee-saved pops and ordinary computation only); dynamic
--     allocation must use the `;! alloca` annotation instead. A `;! alloca` dynamic
--     `subq %rax,%rsp` makes the depth unknown but pops nothing, so the abstract save
--     stack SURVIVES across it (and across the inert computation in its scope) until
--     `leave`/`movq %rbp,%rsp` restores a known depth — clang -O0's VLA epilogue
--     (`movq %rbp,%rsp; popq %rbp; ret`) pairs its pops exactly like `leave`;
--   * stack accesses and returns executed while rsp is perturbed, unbalanced, or of
--     unknown depth (e.g. after a dynamic alloca with no rbp restore);
--   * mid-function pushes/pops of non-callee-saved operands, pops of the frame pointer
--     that do not pair with its save (a paired `popq %rbp` — e.g. the no-frame-cleanup
--     leaf epilogue `popq %rbp; ret` — IS a sound restore), `leave` without an
--     established frame pointer, and mid-function `movq %rsp,%rbp`;
--   * `enter`/`enterq` (packed push-rbp/mov/sub frame setup sarcasm does not model —
--     passed through it would shift rsp and clobber rbp inside the synthesized frame);
--   * any instruction naming a vector/floating-point (xmm-class: xmm/ymm/zmm/mm/st)
--     register — sarcasm has no vector register file, so these cannot be virtualized,
--     bounds-checked, or modeled — and any x87 FPU instruction at all (every x87
--     mnemonic begins with 'f'; ones that name no xmm-class register, like `fldz` or
--     `fnstsw %ax`, would otherwise slip past the register check).

local x86 = require("./x86_64_isa")

local x86_64_frame = {}

local WIDTH_LETTER = { b = 1, w = 2, l = 4, q = 8 }  -- AT&T size suffix -> bytes

-- rsp is always the stack pointer; rbp is a stack (frame) register only when the function
-- actually establishes it as a frame pointer (`mov %rsp,%rbp`). With frame-pointer omission
-- (the -O2 default), rbp is just an ordinary callee-saved GPR holding values.
local function isStackReg(op, usesRbp) return op and op.kind == "reg" and (op.rc == "sp" or (usesRbp and op.name == "rbp")) end
local function immVal(op) if op and op.kind == "imm" then return op.value or tonumber(op.text) or 0 end return 0 end

local function isAlloca(st)
	return st.annotation and string.find(st.annotation, "alloca", 1, true) ~= nil
end

-- Does the instruction read or write rsp (as an explicit operand or memory base/index), or
-- access memory through rbp while rbp is the frame pointer? push/pop/call/ret/leave also
-- touch rsp implicitly; callers handle those separately.
local function insnTouchesFrame(st, usesRbp)
	for _, o in (st.operands or {}) do
		if o.kind == "reg" then
			if o.rc == "sp" then return true end
		elseif o.kind == "mem" then
			if (o.base and o.base.rc == "sp") or (o.index and o.index.rc == "sp") then return true end
			if usesRbp and o.base and o.base.name == "rbp" then return true end
		end
	end
	return false
end

-- Does the instruction write rsp (destination operand, or the implicit push/pop write)?
local function insnWritesSp(st)
	local ops = st.operands
	if ops[1] and ops[1].kind == "reg" and ops[1].rc == "sp" then return true end
	local b = x86.baseMnemonic(string.lower(st.mnemonic))
	return b == "push" or b == "pop"
end

-- Result of analyzeFrame that the per-statement rewrite needs but the shared frame.luau
-- ctx does not carry (it only forwards frameSize/fpOffset/usesFp). analyzeFrame always
-- runs (via frame.preprocess) before any rewrite call for the same body, single-threaded.
local D0 = 0  -- net rsp depth at the end of the prologue prefix (the frame base)

-- Pre-scan the frame: derive its geometry from the PROLOGUE PREFIX (net depth at the first
-- instruction that is not frame setup and cannot be prologue-transparent), determine
-- whether rbp is established as the frame pointer there, and annotate every statement with
--   * st.x86_prologue      — inside the prologue prefix;
--   * st.x86_depth         — abstract rsp depth (bytes below the entry rsp) at which the
--                            instruction executes, or "dyn" when unknown, or nil when the
--                            instruction is unreachable (dead code gets no depth checks);
--   * st.x86_teardownStart — a post-prologue `addq $imm,%rsp` / `movq %rbp,%rsp` verified
--                            as epilogue teardown (a straight path to `ret` involving only
--                            callee-saved pops and ordinary, non-stack computation);
--   * st.x86_teardown      — inside such a verified teardown region.
-- The frame size for rbp-based normalization is D0 - fpDepth (so rbp = rsp + frameSize at
-- the post-prologue rsp); without a frame pointer it is the net constant allocation.
function x86_64_frame.analyzeFrame(body)
	-- jump-target label names (backward edges must end the prologue: instructions behind
	-- such a label can re-execute, so their stack effect cannot be counted once)
	local targeted = {}
	for _, st in body do
		if st.kind == "insn" then
			local b = x86.baseMnemonic(string.lower(st.mnemonic))
			if b == "jmp" or b == "jcc" then
				for _, o in st.operands do
					if o.kind == "sym" then targeted[o.text] = true end
				end
			end
		end
	end

	-- label name -> index of the insn it precedes; nextInsn[i] -> next insn index after i
	local labelAt, nextInsn = {}, {}
	do
		local pending = {}
		for i, st in body do
			if st.kind == "insn" then
				for _, n in pending do labelAt[n] = i end
				pending = {}
			elseif st.kind == "label" then
				table.insert(pending, st.name)
			end
		end
		for _, n in pending do labelAt[n] = #body + 1 end
		local nxt = #body + 1
		for i = #body, 1, -1 do
			nextInsn[i] = nxt
			if body[i].kind == "insn" then nxt = i end
		end
	end

	-- Prologue prefix scan.
	local depth, subBytes = 0, 0
	local pstack = {}  -- outstanding saves: { name = reg, depth = slot depth }, push order
	local fpDepth, usesRbp = nil, false
	local prologueEnd = #body + 1
	do
		local i = 1
		while i <= #body do
			local st = body[i]
			if st.kind ~= "insn" then
				if st.kind == "label" and targeted[st.name] then prologueEnd = i break end
			else
				local m = string.lower(st.mnemonic)
				local b = x86.baseMnemonic(m)
				local ops = st.operands
				if isAlloca(st) then prologueEnd = i break
				elseif b == "push" and ops[1] and ops[1].kind == "reg" and x86.CALLEE_SAVED[ops[1].name] then
					depth += 8
					table.insert(pstack, { name = ops[1].name, depth = depth })
				elseif b == "pop" and ops[1] and ops[1].kind == "reg" and x86.CALLEE_SAVED[ops[1].name]
					and #pstack > 0 and pstack[#pstack].name == ops[1].name
					and pstack[#pstack].depth == depth
					and not (usesRbp and ops[1].name == "rbp") then
					-- net-balanced transient save pair inside the prefix: the pop must
					-- restore the LAST outstanding push of the SAME register at the SAME
					-- slot depth — anything else reads a slot that is not that register's
					-- save (e.g. the saved frame pointer), so it is not a save/restore
					-- round-trip and cannot be netted out. (Popping the frame pointer
					-- itself is an rbp clobber, not frame setup: it ends the prefix.)
					depth -= 8
					table.remove(pstack)
				elseif b == "push" or b == "pop" then
					-- any other push/pop is never prologue-transparent (implicit rsp write)
					prologueEnd = i break
				elseif b == "mov" and ops[1] and ops[1].name == "rbp" and ops[2] and ops[2].rc == "sp"
					and not usesRbp then
					usesRbp = true; fpDepth = depth
				elseif b == "sub" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "imm" then
					depth += immVal(ops[2]); subBytes += immVal(ops[2])
				elseif b == "add" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "imm"
					and immVal(ops[2]) <= subBytes then
					-- undoes part of the prologue allocation: net it out (an epilogue add
					-- is never reached here — the scan has long stopped at the body)
					depth -= immVal(ops[2]); subBytes -= immVal(ops[2])
				elseif b == "nop" then
					-- endbr64 / padding: transparent
				elseif b == "jmp" or b == "jcc" or b == "call" or b == "ret" or b == "leave"
					or string.match(m, "^loop") then
					prologueEnd = i break
				elseif insnTouchesFrame(st, usesRbp) then
					prologueEnd = i break
				elseif usesRbp and ops[1] and ops[1].kind == "reg" and ops[1].name == "rbp" then
					prologueEnd = i break  -- rbp clobbered after being established as fp
				end
			end
			i += 1
		end
	end
	D0 = depth
	local frameSize = usesRbp and (depth - fpDepth) or subBytes

	-- Control-flow rsp-depth + save-pairing analysis. The abstract state is (depth, saves):
	-- depth is bytes below the entry rsp ("dyn" when unknown), and saves is the abstract
	-- stack of outstanding pushes — { name = reg, depth = slot depth } in push order —
	-- used to prove that every dropped pop restores what a matching dropped push saved.
	-- transfer maps the state before an instruction to the state after it; merges require
	-- agreement on both components (a disagreement, or any dynamic-alloca influence,
	-- yields "dyn" — unprovable).
	local function truncateSaves(sv, nd)
		-- Drop save entries whose slots are no longer above rsp (deeper than the new
		-- depth): after rsp is reset to a known position (`leave` / `movq %rbp, %rsp`) the
		-- saves below it are abandoned.
		if sv == "dyn" then return "dyn" end
		local c = {}
		for _, e in sv do
			if e.depth > nd then break end
			table.insert(c, e)
		end
		return c
	end
	local function transfer(st, d, sv)
		local m = string.lower(st.mnemonic)
		local b = x86.baseMnemonic(m)
		local ops = st.operands
		if b == "leave" then
			-- `leave` = `movq %rbp, %rsp` + `popq %rbp`: recovers a known depth (and the
			-- matching save shape) from the frame pointer; without one it is unprovable.
			if not usesRbp then return "dyn", "dyn" end
			local nd = fpDepth - 8
			return nd, truncateSaves(sv, nd)
		end
		if b == "mov" and ops[1] and ops[1].rc == "sp" then
			-- `movq %rbp, %rsp` restores rsp from the frame pointer (epilogue teardown):
			-- like `leave`, it recovers a known depth (and the surviving save shape)
			-- from the frame pointer even when a dynamic alloca made the depth unknown
			-- (clang -O0's VLA epilogue), so the teardown `popq %rbp` after it still
			-- pairs with the prologue save. Any other write to rsp makes both unknown.
			if usesRbp and ops[2] and ops[2].name == "rbp" then
				return fpDepth, truncateSaves(sv, fpDepth)
			end
			return "dyn", "dyn"
		end
		if d == "dyn" or sv == "dyn" then
			-- Inside a dynamic-alloca region the DEPTH is unprovable, but the outstanding
			-- saves still sit at their slots: an instruction that cannot touch rsp
			-- propagates the save stack unchanged so a later `leave`/`movq %rbp, %rsp`
			-- can revive it (the rewrite rejects every stack access, push/pop, or
			-- return that would execute at an unknown depth, so only inert computation
			-- may carry it). A push/pop or a non-alloca rsp adjustment at an unknown
			-- depth — or any state whose save shape is already unknown — is unprovable.
			if sv == "dyn" then return "dyn", "dyn" end
			if b == "push" or b == "pop" then return "dyn", "dyn" end
			if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp" and not isAlloca(st) then
				return "dyn", "dyn"
			end
			return "dyn", sv
		end
		if b == "push" then
			local c = { table.unpack(sv) }
			table.insert(c, {
				name = (ops[1] and ops[1].kind == "reg") and ops[1].name or "?",
				depth = d + 8 })
			return d + 8, c
		end
		if b == "pop" then
			-- The pop consumes the slot at the current depth. Whether that slot holds a
			-- matching save is verified from the INCOMING state at the pop (see the
			-- x86_unpairedPop annotation); here only the stack shape is maintained.
			local c = { table.unpack(sv) }
			if #c > 0 and c[#c].depth == d then table.remove(c) else c = "dyn" end
			return d - 8, c
		end
		local nd = d
		if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp" then
			if ops[2] and ops[2].kind == "imm" then
				nd = (b == "sub") and (d + immVal(ops[2])) or (d - immVal(ops[2]))
			elseif isAlloca(st) then
				-- dynamic alloca (`subq %rax, %rsp ;! alloca size (x)`): the depth
				-- becomes unknown, but the alloca pops nothing — the outstanding saves
				-- survive at their slots and a later fp restore revives them.
				return "dyn", sv
			else
				return "dyn", "dyn"  -- unanalyzable rsp write
			end
		end
		if nd < d then sv = truncateSaves(sv, nd) end
		return nd, sv
	end
	local function mergeSaves(a, b)
		if a == nil then return b end
		if a == "dyn" or b == "dyn" then return "dyn" end
		if #a ~= #b then return "dyn" end
		for k = 1, #a do
			if a[k].name ~= b[k].name or a[k].depth ~= b[k].depth then return "dyn" end
		end
		return a
	end
	local function successors(i)
		local st = body[i]
		local m = string.lower(st.mnemonic)
		local b = x86.baseMnemonic(m)
		local nxt = nextInsn[i]
		local out = {}
		if b == "ret" then return out end
		if b == "jmp" then
			local o = st.operands[1]
			if o and o.kind == "sym" and labelAt[o.text] then return { labelAt[o.text] } end
			return out  -- indirect jump: leaves the function (tail call)
		end
		if b == "jcc" or string.match(m, "^loop") then
			local o = st.operands[1]
			if o and o.kind == "sym" and labelAt[o.text] then table.insert(out, labelAt[o.text]) end
		end
		if nxt <= #body then table.insert(out, nxt) end
		return out
	end
	local depthIn, savesIn = {}, {}
	do
		local firstInsn
		for i, st in body do
			if st.kind == "insn" then firstInsn = i break end
		end
		if firstInsn then
			depthIn[firstInsn] = 0
			savesIn[firstInsn] = {}
			local worklist, inq = { firstInsn }, { [firstInsn] = true }
			while #worklist > 0 do
				local i = table.remove(worklist)
				inq[i] = nil
				local od, osv = transfer(body[i], depthIn[i], savesIn[i])
				for _, s in successors(i) do
					local cur = depthIn[s]
					local merged
					if cur == nil then merged = od
					elseif cur == "dyn" or od == "dyn" then merged = "dyn"
					elseif cur == od then merged = cur
					else merged = "dyn" end
					local mergedSv = mergeSaves(savesIn[s], osv)
					if merged ~= cur or mergedSv ~= savesIn[s] then
						depthIn[s] = merged
						savesIn[s] = mergedSv
						if not inq[s] then inq[s] = true table.insert(worklist, s) end
					end
				end
			end
		end
	end

	-- Verify epilogue teardown regions: from the instruction after a teardown starter to a
	-- `ret`, allow only callee-saved pops, `leave`, and ordinary computation that never
	-- touches the stack or control flow. Returns the covered insn indices, or nil.
	local function validateTeardown(afterIdx)
		local marks = {}
		local j = afterIdx
		while j <= #body do
			local st = body[j]
			if st.kind == "label" and targeted[st.name] then return nil end
			if st.kind == "insn" then
				local m = string.lower(st.mnemonic)
				local b = x86.baseMnemonic(m)
				local ops = st.operands
				if isAlloca(st) then return nil end
				if b == "ret" then return marks end
				if b == "jmp" or b == "jcc" or b == "call" or string.match(m, "^loop") then return nil end
				if b == "leave" then
					table.insert(marks, j)
				elseif b == "pop" and ops[1] and ops[1].kind == "reg" and x86.CALLEE_SAVED[ops[1].name] then
					table.insert(marks, j)
				else
					if b == "push" or b == "pop" or insnWritesSp(st)
						or insnTouchesFrame(st, usesRbp) then return nil end
					table.insert(marks, j)
				end
			end
			j += 1
		end
		return nil
	end

	-- Annotate.
	for i, st in body do
		if st.kind == "insn" then
			st.x86_prologue = i < prologueEnd
			st.x86_depth = depthIn[i]
			-- A pop provably restores a matching save only when the incoming abstract save
			-- stack shows the LAST outstanding push as the same register at the same slot
			-- depth on every path. Anything else (no outstanding push, a different register
			-- on top, an unprovable stack) loads a slot that is not that register's save.
			if x86.baseMnemonic(string.lower(st.mnemonic)) == "pop" and depthIn[i] ~= nil then
				local sv, d = savesIn[i], depthIn[i]
				local n = (st.operands[1] and st.operands[1].kind == "reg")
					and st.operands[1].name or "?"
				if sv == "dyn" or d == "dyn" or #sv == 0
					or sv[#sv].name ~= n or sv[#sv].depth ~= d then
					st.x86_unpairedPop = true
				end
			end
			if not st.x86_prologue then
				local b = x86.baseMnemonic(string.lower(st.mnemonic))
				local ops = st.operands
				local isTeardownStart = (b == "add" and ops[1] and ops[1].rc == "sp"
						and ops[2] and ops[2].kind == "imm")
					or (b == "mov" and ops[1] and ops[1].rc == "sp" and ops[2]
						and ops[2].name == "rbp" and usesRbp)
				if isTeardownStart then
					local marks = validateTeardown(nextInsn[i])
					if marks then
						st.x86_teardownStart = true
						for _, j in marks do body[j].x86_teardown = true end
					end
				end
			end
		end
	end

	return frameSize, 0, usesRbp
end

function x86_64_frame.rewrite(st, ctx)
	local emit = ctx.emit
	local usesRbp = ctx.usesFp
	local m = string.lower(st.mnemonic)
	local b = x86.baseMnemonic(m)
	local ops = st.operands

	-- `enter`/`enterq` (push rbp; mov rsp,rbp; sub imm,rsp as ONE instruction) is frame
	-- setup sarcasm does not model: passed through it would shift rsp and clobber rbp
	-- inside the synthesized Fil-C frame (the frame-link restore would read garbage and
	-- `ret` would pop a wild address). Reject it — frame setup must be the canonical
	-- push %rbp / mov %rsp,%rbp / sub $imm,%rsp form the prologue analysis recognizes.
	if b == "enter" or b == "enterq" then
		error("sarcasm: `enter` is not supported (cannot prove safety; use the canonical"
			.. " push %rbp / mov %rsp,%rbp / sub $imm,%rsp frame setup): " .. (st.raw or m))
	end

	-- sarcasm has no vector/floating-point register file: an instruction naming an
	-- xmm-class register (as an operand or a memory base/index) cannot be virtualized,
	-- bounds-checked, or even modeled — passing it through silently miscompiles or dies
	-- later with a cryptic assembler error. Reject it cleanly.
	for _, o in ops do
		if (o.kind == "reg" and o.rc == "xmm") or (o.kind == "mem"
			and ((o.base and o.base.rc == "xmm") or (o.index and o.index.rc == "xmm"))) then
			error("sarcasm: vector/floating-point (xmm) registers are not supported: "
				.. (st.raw or m))
		end
	end

	-- x87 FPU instructions that never name an xmm-class register escape the check above:
	-- `fldz` has no operands at all, and `fnstsw %ax` writes a plain GPR. Every x87/FPU
	-- mnemonic begins with 'f' (fld*, fst*, fist*, fi*, fcom*, fnst*, fwait,
	-- fxsave/fxrstor, ...) and no non-floating-point x86 mnemonic does, so reject the
	-- whole class here: sarcasm has no x87 register stack to virtualize or model, and
	-- passing one through would silently miscompile or die later with a cryptic
	-- assembler error (e.g. "invalid instruction suffix" on a virtualized slot form).
	if string.sub(m, 1, 1) == "f" then
		error("sarcasm: x87 FPU instructions are not supported (floating-point is out of"
			.. " scope): " .. (st.raw or m))
	end

	-- Post-prologue enforcement (annotations from analyzeFrame; see the file header). The
	-- prologue prefix itself is handled by the legacy drops below — frame setup there is
	-- accounted for in the frame geometry and simply dropped.
	local d = st.x86_depth
	if not st.x86_prologue then
		if b == "leave" then
			if not usesRbp then
				error("sarcasm: `leave` without a frame pointer established in the prologue"
					.. " cannot be proven safe: " .. (st.raw or m))
			end
			return
		end
		if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp" then
			if b == "add" and ops[2] and ops[2].kind == "imm" and st.x86_teardownStart then
				return  -- verified epilogue teardown: drop
			end
			error("sarcasm: mid-function stack-pointer adjustment cannot be proven safe"
				.. " (frame teardown must be an epilogue `addq $imm, %rsp` leading to `ret`;"
				.. " dynamic allocation must use `;! alloca`): " .. (st.raw or m))
		end
		if b == "mov" and ops[1] and ops[1].name == "rbp" and ops[2] and ops[2].rc == "sp" then
			error("sarcasm: establishing %rbp as a frame pointer outside the prologue cannot"
				.. " be proven safe: " .. (st.raw or m))
		end
		if b == "mov" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].name == "rbp" then
			if st.x86_teardownStart then return end  -- `movq %rbp, %rsp` epilogue teardown
			error("sarcasm: restoring %rsp from %rbp outside epilogue teardown cannot be"
				.. " proven safe: " .. (st.raw or m))
		end
		if b == "push" then
			-- Balanced callee-saved save/restore pairs are dropped; the rsp-depth analysis
			-- rejects any stack access or return that would observe the shifted rsp.
			if ops[1] and ops[1].kind == "reg" and x86.CALLEE_SAVED[ops[1].name] then return end
			error("sarcasm: mid-function push of a non-callee-saved operand cannot be proven"
				.. " safe: " .. (st.raw or m))
		end
		if b == "pop" then
			if ops[1] and ops[1].kind == "reg" and x86.CALLEE_SAVED[ops[1].name] then
				-- Popping the frame pointer is sound only as its save's restore: inside a
				-- verified epilogue teardown, or provably paired with the outstanding save
				-- of rbp (e.g. the leaf `popq %rbp; ret` with no frame cleanup — rsp still
				-- sits at the save slot). After such a pop the depth analysis rejects any
				-- further stack access (rsp/rbp-relative) and any unbalanced return, so
				-- only ordinary computation may follow. An UNPAIRED rbp-pop reads a slot
				-- that is not the saved frame pointer (it can be another register's save
				-- or the return address): reject.
				if ops[1].name == "rbp" and usesRbp and not st.x86_teardown and st.x86_unpairedPop then
					error("sarcasm: popping the frame pointer with no matching earlier save"
						.. " cannot be proven safe (it is not an epilogue restore): "
						.. (st.raw or m))
				end
				-- Dropping the pop is sound only when it provably restores a matching
				-- dropped push of the same register on every path (balanced save region,
				-- epilogue restore of a prologue save, or verified teardown). An unpaired
				-- pop's load would be silently lost — and the slot it reads is not that
				-- register's save (it can be the saved frame pointer or the return
				-- address).
				if st.x86_unpairedPop then
					error("sarcasm: pop with no matching earlier push of the same register"
						.. " cannot be proven safe (dropping it would lose the load): "
						.. (st.raw or m))
				end
				return
			end
			error("sarcasm: mid-function pop into a non-callee-saved register cannot be"
				.. " proven safe: " .. (st.raw or m))
		end
		-- d is nil for unreachable instructions (dead code: no depth checks — the drops and
		-- rejections above still apply, and surviving accesses stay virtualized).
		if b == "ret" and d ~= nil and d ~= 0 then
			error("sarcasm: return with a perturbed or unknown stack pointer cannot be proven"
				.. " safe: " .. (st.raw or m))
		end
		if b == "jmp" and d ~= nil and d ~= 0 and not (ops[1] and ops[1].kind == "sym") then
			error("sarcasm: indirect tail jump with a perturbed or unknown stack pointer"
				.. " cannot be proven safe: " .. (st.raw or m))
		end
	end

	-- drop CET marker and frame setup/teardown
	if b == "nop" and m == "endbr64" then return end
	if b == "leave" then return end
	if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp" then return end
	if b == "mov" and ops[1] and ops[1].name == "rbp" and ops[2] and ops[2].rc == "sp" then return end
	if b == "mov" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].name == "rbp" then return end

	-- push/pop of callee-saved registers (and rbp frame pointer): save/restore round-trips -> drop.
	if b == "push" and ops[1] and ops[1].kind == "reg" and (x86.CALLEE_SAVED[ops[1].name] or ops[1].name == "rbp") then return end
	if b == "pop" and ops[1] and ops[1].kind == "reg" and (x86.CALLEE_SAVED[ops[1].name] or ops[1].name == "rbp") then return end

	-- rbp/rsp-relative memory access -> slot pseudo-register (unless it lands in a region).
	local mem
	for _, o in ops do if o.kind == "mem" then mem = o end end
	-- A stack-relative operand with a SYMBOLIC displacement (`movq foo(%rsp), %rax`) has an
	-- unknown-at-compile-time target: it cannot be bounds-checked or virtualized, so reject
	-- it cleanly (both the AT&T and Intel parsers set mem.dispSym on the memory operand).
	if mem and isStackReg(mem.base, usesRbp) and mem.dispSym then
		error("sarcasm: stack-relative memory access with a symbolic displacement cannot be"
			.. " proven safe: " .. (st.raw or m))
	end
	if mem and isStackReg(mem.base, usesRbp) and not mem.dispSym then
		-- A stack access is only keyable to a frame slot when rsp provably sits at the
		-- post-prologue frame base; anything else (mid-function push/sub region, dynamic
		-- alloca aftermath, unbalanced merge) is unprovable: reject. (nil depth = dead code.)
		if not st.x86_prologue and d ~= nil and d ~= D0 then
			error("sarcasm: stack access while the stack pointer is perturbed or unknown"
				.. " (cannot prove which frame slot this is): " .. (st.raw or m))
		end
		-- Normalize to an rsp-relative frame offset: rbp, when it is the frame pointer,
		-- sits at the frame TOP (rbp = rsp + frameSize), so an rbp-relative displacement d
		-- is frame offset frameSize + d. The slot key, region lookup, and bounds check all
		-- use this NORMALIZED offset, so rbp- and rsp-relative accesses to the same address
		-- (e.g. -8(%rbp) and 8(%rsp) with a 16-byte frame) share one slot web, while
		-- distinct addresses (e.g. -8(%rbp) vs -8(%rsp)) never alias.
		local off = (mem.dispVal or 0)
		if mem.base.rc ~= "sp" then off = ctx.frameSize + off end
		if ctx.regionOf(off) then emit(st); return end
		-- lea of a stack address computes/escapes a pointer into the frame: reject.
		if b == "lea" then ctx.rejectEscape(st.raw or m) end
		-- only plain base+disp slots are virtualizable (no index register)
		if mem.index then
			error("sarcasm: indexed stack-relative access is not supported on x86: " .. (st.raw or m))
		end
		-- The slot virtualization rewrites ONLY the memory operand. Any other operand that
		-- is (or contains) a stack register would leak the live sp/fp value into a virtual
		-- temp — `movq %rsp, (%rsp)`, `movq %rbp, -8(%rbp)`, `movq (%rsp), %rsp` — the same
		-- escape class as `movq %rsp, %rax`, which the fall-through scan below catches only
		-- because no stack-mem operand virtualizes first. Reject it here.
		for _, o in ops do
			if o ~= mem then
				if isStackReg(o, usesRbp) then ctx.rejectEscape(st.raw or m) end
				if o.kind == "mem" and (isStackReg(o.base, usesRbp) or isStackReg(o.index, usesRbp)) then
					ctx.rejectEscape(st.raw or m)
				end
			end
		end
		-- Replace the stack-slot memory operand in place with a slot pseudo-register of the
		-- access width, keeping the original mnemonic. This uniformly handles plain moves
		-- (movq), zero/sign-extending loads (movzwl/movsbl/...), and other reg<->slot forms:
		-- e.g. `movzwl 40(%rsp), %r14d` -> `movzwl %<slot:16>, %r14d`. The slot is keyed by
		-- byte offset, so a 64-bit store and a 16-bit reload of the same offset share one web.
		local wb = mem.size
		if not wb then
			local zs = string.match(m, "^mov[zs]([bwlq])")   -- movzwl -> source letter 'w'
			if zs then wb = WIDTH_LETTER[zs]
			else local suf = string.match(m, "([bwlq])$"); wb = (suf and WIDTH_LETTER[suf]) or 8 end
		end
		-- Bounds-check against the input frame (mirrors arm64's per-access checkBounds).
		-- rsp-relative offsets address the frame [0, frameSize) plus the 128-byte SysV red
		-- zone below rsp. NORMALIZED rbp-relative offsets range over the same [-128,
		-- frameSize): with rbp = rsp + frameSize, an rbp-relative d in [-frameSize-128,
		-- -frameSize) — e.g. the gcc -O0 leaf shape `-8(%rbp)` with no `subq` at all — IS
		-- the red zone. (Pre-normalization rbp-relative d >= 0 hits the saved rbp, the
		-- return address, or the caller's argument area.) Anything outside cannot be
		-- proven safe: reject (a virtualized slot would silently fabricate garbage reads /
		-- dead writes).
		ctx.checkBounds(off, wb, ops[1] == mem, st.raw, -128)
		local slot = ctx.slotReg(off, wb * 8)
		local newops = {}
		for _, o in ops do table.insert(newops, (o == mem) and slot or o) end
		emit({ kind = "insn", mnemonic = st.mnemonic, operands = newops, raw = st.raw, line = st.line, annotation = st.annotation })
		return
	end

	-- (a lea of a stack address is handled — and rejected — inside the slot block above:
	-- in-region leas pass through for the transform's region redirect, symbolic-displacement
	-- stack operands were rejected above, and every other stack-based lea hits rejectEscape.)

	-- `movq %rsp, %reg`: when a fixed-alloca region is based at rsp+0 the transform redirects
	-- this to the allocation pointer (mirrors arm64's `mov xD, sp` handling); pass through.
	-- The region base is only known relative to the post-prologue frame base: reject when
	-- rsp is perturbed/unknown here.
	if b == "mov" and ops[2] and ops[2].rc == "sp" and ops[1] and ops[1].kind == "reg"
		and ops[1].rc ~= "sp" and ctx.regionOf(0) then
		if not st.x86_prologue and d ~= nil and d ~= D0 then
			error("sarcasm: reading the stack pointer while it is perturbed or unknown"
				.. " cannot be proven safe: " .. (st.raw or m))
		end
		emit(st); return
	end

	-- Any remaining instruction consuming a stack register as a VALUE (e.g.
	-- `movq %rsp, %rax`, `pushq %rsp`) obtains a live stack address sarcasm cannot track:
	-- reject (arm64 rejects the analogous `mov/add xD, sp, ...`). When rbp is the frame
	-- pointer it IS a stack register (rbp = rsp + frameSize), so reading it as a value —
	-- `movq %rbp, %rax`, arithmetic on it — is the same escape class. (The frame setup /
	-- teardown paths that legitimately name rbp — `movq %rsp, %rbp`, `movq %rbp, %rsp`,
	-- `leave`, teardown `popq %rbp` — all return earlier.) Stack-register memory BASES
	-- were handled above (virtualized or rejected); a stack register hiding in a memory
	-- operand's INDEX slot (`movq (%rdi,%rsp,1), %rax` — which the encoding forbids but
	-- the parser accepts — or `movq (%rdi,%rbp,1), %rax` in an fp frame) escapes the same
	-- way, so scan nested memory registers too.
	for _, o in ops do
		if isStackReg(o, usesRbp) then ctx.rejectEscape(st.raw or m) end
		if o.kind == "mem" and (isStackReg(o.base, usesRbp) or isStackReg(o.index, usesRbp)) then
			ctx.rejectEscape(st.raw or m)
		end
	end

	emit(st)
end

return x86_64_frame
