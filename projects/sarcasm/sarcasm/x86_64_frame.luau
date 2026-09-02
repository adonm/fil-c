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
--     being dropped. Inside a VERIFIED epilogue teardown (a straight path to `ret` through
--     callee-saved pops and frame-touch-free computation) a pop at an UNKNOWN depth pairs
--     off the outstanding save stack by register alone: the slot position is unknowable
--     there, but every statement in the span is dropped and the synthesized epilogue owns
--     the real %rsp, so only the register identity matters;
--   * reads of the frame pointer as a VALUE (`movq %rbp, %rax`, an rbp memory index) while
--     rbp is the frame pointer — the same stack-address escape class as reading rsp, so the
--     fall-through escape check treats rbp as a stack register whenever usesRbp holds;
--   * mid-function constant or non-constant rsp adjustments (`subq`/`addq` to %rsp, and
--     `mov %reg,%rsp` from an unvalidated source) that are neither prologue/epilogue
--     frame setup, an `alloca`-idiom allocation, a recovery of a known-good saved
--     stack pointer, nor a PROVEN mid-function constant decrease (`addq $imm, %rsp`
--     at a statically known, non-negative resulting depth with provably dead flags
--     — the ecp_nistz256 shared-tail frame-reshape shape, accepted and dropped)
--     (dynamic allocation must use the `;! alloca` annotation instead).
--     Recovering %rsp from a known-good value — `movq %rbp,%rsp`, `leaq N(%rbp),%rsp`,
--     or a register the prologue saved %rsp into — is accepted and dropped anywhere,
--     mid-function alloca "frees" included: rbp-relative virtualization is unaffected,
--     and rsp-relative accesses, pops, and returns stay depth-gated. The prologue save
--     itself (`movq %rsp,%rbx`) is prologue-transparent and DROPPED: the parked value
--     has no meaning in the output (sarcasm synthesizes its own frame), so only the
--     recovery is consumed — the save register may not be read while it holds the save,
--     and only callee-saved registers may hold one (a call would clobber the rest). A
--     `;! alloca`
--     dynamic rsp adjustment makes the depth unknown but pops nothing, so the abstract
--     save stack SURVIVES across it (and across the inert computation in its scope)
--     until one of those recoveries restores a known depth (`movq %rbp,%rsp; popq %rbp;
--     ret` pairs its pops exactly like `leave`);
--   * a MID-FUNCTION `leave`: hardware `leave` also restores the CALLER's frame pointer
--     into %rbp, which would desync every later rbp-relative virtualization — `leave` is
--     accepted only as a proven epilogue teardown (leading straight to `ret` through
--     callee-saved pops and ordinary computation), exactly like the `addq $imm,%rsp`
--     starter. A teardown-verified `addq $imm,%rsp` (and the `ret` that terminates its
--     span) is accepted even at a dynamic-alloca-poisoned depth: the adjustment cannot be
--     PROVEN to undo the alloca, but everything in the span is dropped and the
--     synthesized epilogue owns the real %rsp, so the output is correct either way.
--     Per-point frame-pointer establishment (x86_fp) backs this up: rbp-relative
--     accesses are accepted only where %rbp provably still holds the function's frame
--     pointer on every path (an early-exit path that skipped the prologue, and any point
--     after a paired `popq %rbp`, are "not established");
--   * stack accesses and returns executed while rsp is of UNKNOWN depth
--     (e.g. after a dynamic alloca with no rbp restore), or unbalanced
--     (returns); accesses at a STATICALLY KNOWN perturbed depth key exactly in
--     normalized coordinates (disp + D0 - d) and virtualize like any other
--     slot (save-slot aliases ride the save model);
--   * mid-function pushes/pops of non-callee-saved operands, pops of the frame pointer
--     that do not pair with its save (a paired `popq %rbp` — e.g. the no-frame-cleanup
--     leaf epilogue `popq %rbp; ret` — IS a sound restore), `leave` without an
--     established frame pointer, and mid-function `movq %rsp,%rbp`;
--   * `enter`/`enterq` (packed push-rbp/mov/sub frame setup sarcasm does not model —
--     passed through it would shift rsp and clobber rbp inside the synthesized frame);
--   * vector-indexed memory operands (gather/scatter: base or index of xmm-class) —
--     they touch multiple discrete addresses that cannot be bounds-checked;
--   * a `lock` prefix on any stack-frame access — the slot is virtualized into a
--     pseudo-register or materialized into the thread-confined synthesized frame
--     before classify's lockAllows validation runs, so accepting it would silently
--     elide the prefix (a locked memory RMW degenerating into an unlocked register
--     operation); `lock` stays supported on the modeled heap mem-RMWs only.
--
-- FP/SIMD registers (xmm-class: xmm/ymm/zmm/mm/st/k) are IN SCOPE: instructions naming
-- them pass through the frame policy (heap accesses are bounds-checked later by the
-- transform using the x86_64_fp knowledge module's widths). Stack-frame accesses by
-- FP instructions cannot ride the GPR slot virtualization (a slot pseudo-register is
-- not a vector register), so analyzeFrame runs an FP TAINT SCAN over the body's stack
-- accesses: every stack range an FP/vector instruction touches — plus any GPR range
-- overlapping it (aliasing) — is MATERIALIZED into a reserved region of sarcasm's
-- synthesized frame, i.e. the instruction is kept and its memory operand rewritten to
-- a real disp(%rsp) whose offset preserves the input's guaranteed alignment. All other
-- stack slots virtualize into pseudo-registers as before.

local x86 = require("./x86_64_isa")
local x86parse = require("./x86_64_parse")
local fp = require("./x86_64_fp")
local sig = require("./sig")
local frameShared = require("./frame")

local x86_64_frame = {}

local WIDTH_LETTER = { b = 1, w = 2, l = 4, q = 8 }  -- AT&T size suffix -> bytes

-- rsp is always the stack pointer; rbp is a stack (frame) register only when the function
-- actually establishes it as a frame pointer (`mov %rsp,%rbp`). With frame-pointer omission
-- (the -O2 default), rbp is just an ordinary callee-saved GPR holding values.
local function isStackReg(op, usesRbp) return op and op.kind == "reg" and (op.rc == "sp" or (usesRbp and op.name == "rbp")) end

-- Is this instruction an FP/SIMD/x87 use of memory (vs an ordinary GPR access)? The
-- knowledge module "claims" its own mnemonics even without an xmm-class operand
-- (ldmxcsr, movnti, cvtsi2sd, ...); claim=false entries (movq, the ss/sd/ps/pd and
-- p-family patterns, ...) only engage when an xmm-class register is actually present.
-- Memory-neutral hints (prefetch*) are not FP uses: they need no slot at all.
local function isFpInsn(fpe, st)
	if fpe and fpe.noCheck then return false end
	return fp.hasFpReg(st) or (fpe ~= nil and fpe.claim ~= false)
end

-- GPR stack-access width in bytes: an Intel PTR size when present, the movz*/movs*
-- source letter, a trailing AT&T [bwlq] suffix, default 8. (FP accesses are sized by
-- the fp knowledge module instead.)
local function gprStackWidth(m, mem)
	if mem.size then return mem.size end
	local zs = string.match(m, "^mov[zs]([bwlq])")   -- movzwl -> source letter 'w'
	if zs then return WIDTH_LETTER[zs] end
	local suf = string.match(m, "([bwlq])$")
	return (suf and WIDTH_LETTER[suf]) or 8
end
local function immVal(op) if op and op.kind == "imm" then return op.value or tonumber(op.text) or 0 end return 0 end

local function isAlloca(st)
	return st.annotation and string.find(st.annotation, "alloca", 1, true) ~= nil
end

-- The abstract rsp depth: a number (bytes below the entry rsp), "dyn" (unknown —
-- a dynamic alloca's aftermath; no region coordinates), or a TABLE
-- { anchored = <region> } — "inside an alignment-anchored alloca region's scope":
-- the andq/sub that anchors the region only LOWERS rsp and nothing may move it
-- again before the recovery, so rsp-relative offsets there are region
-- coordinates (raw displacements). Any later rsp write leaves the scope (the
-- depth degrades to plain "dyn"). isDyn covers both non-numeric forms.
local function isDynDepth(d) return d == "dyn" or type(d) == "table" end
x86_64_frame.isDynDepth = isDynDepth

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

-- A full-width (64-bit) `movq %rsp, %reg` SAVE form: the register parks the stack
-- pointer. The frame-pointer establishment `movq %rsp, %rbp` is NOT a save — every
-- consumer checks the rbp case first. A sub-register form (`movl %esp, %ebx`) truncates
-- the parked value and is not a save.
local function isSpSaveForm(st)
	local ops = st.operands
	return x86.baseMnemonic(string.lower(st.mnemonic)) == "mov"
		and ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr" and ops[1].name ~= "rbp"
		and (ops[1].width == 64 or ops[1].width == nil)
		and ops[2] and ops[2].rc == "sp" and (ops[2].width == 64 or ops[2].width == nil)
end

-- The matching `movq %reg, %rsp` RECOVERY form (writing %rsp from a register). The
-- frame-pointer source `movq %rbp, %rsp` is NOT this form — every consumer checks it
-- first. A sub-register form truncates and is not a recovery.
local function isSpRecoverForm(st)
	local ops = st.operands
	return x86.baseMnemonic(string.lower(st.mnemonic)) == "mov"
		and ops[1] and ops[1].rc == "sp" and (ops[1].width == 64 or ops[1].width == nil)
		and ops[2] and ops[2].kind == "reg" and ops[2].rc == "gpr" and ops[2].name ~= "rbp"
		and (ops[2].width == 64 or ops[2].width == nil)
end

-- Result of analyzeFrame that the per-statement rewrite needs but the shared frame.luau
-- ctx does not carry (it only forwards frameSize/fpOffset/usesFp). analyzeFrame always
-- runs (via frame.preprocess) before any rewrite call for the same body, single-threaded.
local D0 = 0  -- net rsp depth at the end of the prologue prefix (the frame base)

-- Incoming yolo stack-argument state for the CURRENT function (set by analyzeFrame,
-- consumed by the rewrite — same single-threaded discipline as D0):
--   yoloCount — number of SysV stack (7th+ integer-class) arguments in the entry
--     signature; they arrive at 8+8i(%rsp) at entry, ABOVE the return address —
--     outside the analyzed frame — so their entry-time reads get redirected to
--     virtual slot webs (GPR) or the materialized area (FP/vector).
--   yoloBase — base-16-relative offset of that materialized area (nil when no FP
--     instruction reads an incoming stack argument); the transform fills it from
--     the incoming fast-CC words and the layout reserves yoloBytes for it.
local yoloCount = 0
local yoloBase = nil

-- Map a memory read to its incoming yolo stack-argument slot: return the 0-based
-- slot index i when `st` is a LOAD-LIKE instruction (the memory operand is a pure
-- source — not a store/RMW destination, not an address-taking lea) whose memory
-- operand reads exactly entry_rsp + 8 + 8*i with 0 <= i < yoloCount. `baseName` is
-- the expected base register ("rsp" for a direct read at depth 0, the alias
-- register otherwise) and `saveDepth` the depth at which that register's value
-- equals entry_rsp (0 for %rsp itself at depth 0; the alias save's depth).
local function yoloArgSlotOf(st, baseName, saveDepth)
	if yoloCount == 0 then return nil end
	local ops = st.operands
	local mem
	for _, o in ops do if o.kind == "mem" then mem = o end end
	if not mem then return nil end
	if not (mem.base and mem.base.name == baseName and mem.base.kind == "reg") then return nil end
	if mem.index or mem.dispSym then return nil end
	if ops[1] == mem then return nil end              -- store / RMW destination
	if x86.isMemRmw(st) then return nil end
	local b = x86.baseMnemonic(string.lower(st.mnemonic))
	if b == "lea" then return nil end                 -- address escape, not a read
	-- A clone statement's rsp-relative displacement keys 8 lower (the +8 rule):
	-- an incoming stack argument sits a further return-address word above it.
	local i = (mem.dispVal or 0) - saveDepth - 8 - (st.localClone and 8 or 0)
	if i < 0 or i % 8 ~= 0 then return nil end
	i = i / 8
	if i >= yoloCount then return nil end
	return i
end

-- Is `st` an entry-rsp materialization that may serve as an alias for reading the
-- incoming yolo stack arguments (`leaq 0(%rsp), %reg` — the aesni_ocb prologue
-- shape — at a provable rsp depth)? (The `movq %rsp, %reg` form is recognized by
-- isSpSaveForm instead.)
local function isYoloLeaSave(st, d)
	if yoloCount == 0 then return false end
	if d == nil or isDynDepth(d) then return false end
	if isAlloca(st) or st.allocaPlace or st.allocaOwned then return false end
	local ops = st.operands
	if x86.baseMnemonic(string.lower(st.mnemonic)) ~= "lea" then return false end
	if not (ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr" and ops[1].name ~= "rbp") then return false end
	local mem = ops[2]
	-- The entry stack pointer relative to the access's rsp: d above it for a plain
	-- statement, d + 8 for a clone (the return-address word — the +8 rule).
	local want = st.localClone and (d + 8) or 0
	return mem and mem.kind == "mem" and mem.base and mem.base.rc == "sp"
		and not mem.index and not mem.dispSym and (mem.dispVal or 0) == want
end

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
--   * st.x86_teardown      — inside such a verified teardown region (the terminating
--                            `ret` is part of the span);
-- The frame size for rbp-based normalization is D0 - fpDepth (so rbp = rsp + frameSize at
-- the post-prologue rsp); without a frame pointer it is the net constant allocation.
function x86_64_frame.analyzeFrame(body, sigDesc, regions)
	-- analyzeFrame may run more than once on the same body (the transform calls it for
	-- frame geometry before frame.preprocess runs it again for the rewrite), and it may
	-- see a DIFFERENT body state each time (the transform's deferred dynamic-alloca
	-- discovery marks statements between the two runs). The per-statement fields below
	-- are this analysis's OUTPUT: clear stale ones from a previous run so a conditional
	-- mark (an unpaired pop, a teardown region) never survives from an analysis that
	-- saw different marks.
	for _, st in body do
		st.x86_prologue = nil
		st.x86_depth = nil
		st.x86_saves = nil
		st.x86_unpairedPop = nil
		st.x86_teardownStart = nil
		st.x86_teardown = nil
		st.x86_fp = nil
		st.x86_spRecover = nil
		st.x86_saveStore = nil
		st.x86_carrierLoad = nil
		st.x86_leaSave = nil
		st.x86_spSave = nil
		st.x86_dropRestore = nil
	end

	-- Fixed-alloca region lookup mirroring frame.preprocess's: `dyn` selects the
	-- alignment-anchored regions ("dyn"-depth rsp coordinates), static the
	-- lea/mov-anchored ones. `regions` is nil on the transform's early geometry run:
	-- the region-sensitive decisions below (the caller-saved-save region corner and
	-- the in-region lea exclusion) then conservatively fall back to the behaviors
	-- that keep the early run error-free (the rewrite's run sees the regions).
	local function regionOf(off, dyn)
		for _, r in (regions or {}) do
			if (r.anchored and true or false) == (dyn and true or false)
				and off >= r.base and off < r.base + r.size then return r end
		end
		return nil
	end
	-- The alignment-anchored region (andq/sub forms) this statement anchors, if any:
	-- the annotated instruction itself (its region's `stmt`), or the andq the region
	-- scan marked as the anchoring machinery of a `subq $K, %rsp`-annotated region.
	local anchoredOf = {}
	for _, r in (regions or {}) do
		if r.anchored and r.stmt then anchoredOf[r.stmt] = r end
	end
	local function anchoredRegionOf(st)
		if st.allocaAnchor then return st.allocaAnchor end
		return anchoredOf[st]
	end

	-- (sigDesc is the function's entry signature. A float/double argument or FP
	-- return rides in the xmm registers EVEN when the body never names a vector
	-- register — FP args are typically consumed by a call, an FP return produced,
	-- without any SSE instruction in the body — so the vector-save reservation must
	-- be forced from the SIGNATURE alone, exactly like arm64's usesNeon forcing.
	-- Otherwise an injected runtime call (pollcheck slow path, allocation, ptr-store
	-- barrier) could silently clobber an FP argument. The transform's callsite-side
	-- forcing (transform.luau) covers FP CALLSITE signatures; this covers the entry.)
	local sigHasFp = false
	if sigDesc then
		if sigDesc.retTypes and sigDesc.retTypes[1] and sig.isFpClass(sigDesc.retTypes[1]) then
			sigHasFp = true
		else
			for _, t in (sigDesc.argTypes or {}) do
				if sig.isFpClass(t) then sigHasFp = true break end
			end
		end
	end

	-- Incoming yolo stack arguments (see the yoloCount/yoloBase comment above): the
	-- SysV 7th+ integer-class arguments live at 8+8i(%rsp) at entry. Count them
	-- from the signature (FP args pass in xmm0..xmm7 and never reach the stack —
	-- signatures with >8 FP args are rejected before the frame pass runs).
	yoloCount = 0
	yoloBase = nil
	if sigDesc then
		local nf = 0
		for _, t in (sigDesc.argTypes or {}) do
			if not sig.isFpClass(t) then
				nf += 1
				if nf > 6 then yoloCount += 1 end
			end
		end
	end

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
				if isAlloca(st) and insnWritesSp(st) then prologueEnd = i break
				-- (an `alloca` annotation on an instruction that does NOT write rsp is the
				-- deferred dynamic-alloca idiom's size definition — e.g. a load or an
				-- arithmetic instruction annotated `;! alloca size (ptr)` — and is
				-- prologue-transparent: the allocation happens at the later rsp
				-- adjustment, so frame setup such as `movq %rsp, %rbp` may legitimately
				-- follow it.)
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
				elseif b == "mov" and ops[2] and ops[2].rc == "sp"
					and ops[1] and ops[1].rc == "gpr" and ops[1].name ~= "rbp" then
					-- `movq %rsp, %rbx`: the prologue parked the (known) stack pointer in
					-- a register. Transparent to the frame geometry: the save is DROPPED
					-- by the rewrite (sarcasm synthesizes its own frame, so the parked
					-- value has no output meaning), the rsp-depth fixpoint tracks the
					-- save (a later `movq %rbx, %rsp` recovery revives the saved depth),
					-- and the rewrite rejects saves into anything but a callee-saved
					-- register (a call would clobber the rest).
				elseif b == "sub" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "imm" then
					depth += immVal(ops[2]); subBytes += immVal(ops[2])
				elseif b == "add" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "imm"
					and immVal(ops[2]) <= subBytes then
					-- undoes part of the prologue allocation: net it out (an epilogue add
					-- is never reached here — the scan has long stopped at the body)
					depth -= immVal(ops[2]); subBytes -= immVal(ops[2])
				elseif b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2]
					and ops[2].kind == "mem" and ops[2].base and ops[2].base.rc == "sp"
					and not ops[2].index and not ops[2].dispSym then
					-- `leaq -N(%rsp), %rsp` is the lea spelling of `subq $N, %rsp`
					-- (x25519/gf2m/bsaes prologue shape); `leaq +N(%rsp), %rsp`
					-- undoes it like the constant add.
					local v = ops[2].dispVal or 0
					if v < 0 then
						depth += -v; subBytes += -v
					elseif v > 0 and v <= subBytes then
						depth -= v; subBytes -= v
					elseif v ~= 0 then
						prologueEnd = i break
					end
				elseif insnWritesSp(st) then
					-- any other rsp write (`leaq -N(%rbp), %rsp` teardown, register-source
					-- `subq %reg, %rsp`, `movq %rbp, %rsp`) is not prologue frame setup
					prologueEnd = i break
				elseif b == "nop" then
					-- endbr64 / padding: transparent
				elseif b == "jcc" then
					-- A leading conditional branch is part of the prologue when it guards
					-- the frame setup (an early-exit path that runs with the caller's rsp
					-- and returns: `test %edi,%edi; je .Learly` before `pushq %rbp`).
					-- Hand-written code and optimized builds both spell it this way. The
					-- scan stays sound without inspecting the target path: a targeted
					-- label anywhere ahead still ends the prefix, and the CFG depth/save
					-- analysis merges the early path's depth 0 with the frame path's —
					-- any shape where the guard can jump into or out of the middle of the
					-- setup disagrees and is rejected downstream. Frame-pointer-relative
					-- accesses are additionally gated on per-point frame-pointer
					-- establishment (x86_fp), so a path that skipped the setup can never
					-- virtualize against a frame pointer it does not have.
				elseif b == "jmp" or b == "call" or b == "ret" or b == "leave"
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
	-- stack of outstanding pushes — { name = reg, num = regnum, depth = slot depth,
	-- redefined = bool } in push order — used to prove that every dropped pop restores
	-- what a matching dropped push saved. `redefined` records whether the pushed
	-- register's web was REDEFINED between the push and here (any modeled definition:
	-- an explicit move, an implicit clobber like cpuid's ebx, ...): the drop-the-pop
	-- model is only sound while the web still holds the pushed value, so a redefined
	-- save rejects aliasing slot accesses (the slot holds the value pushed BEFORE the
	-- redefinition) and its pop's reload is checked for observed uses (see the
	-- checkLostReload scan in the annotation pass below). transfer maps the state
	-- before an instruction to the state after it; merges require agreement on both
	-- components (a disagreement, or any dynamic-alloca influence, yields "dyn" —
	-- unprovable).
	local classCache = {}
	local function classOf(st)
		local c = classCache[st]
		if c == nil then c = x86.classify(st); classCache[st] = c end
		return c
	end
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
	-- The core rsp-depth/save-stack/frame-pointer transition. `recoverDepth` is the depth
	-- a `movq %reg, %rsp` recovery revives (non-nil only when the incoming smap holds an
	-- outstanding, unredefined prologue rsp save for the source register — see transfer).
	local function transferCore(st, d, sv, fp, recoverDepth)
		local m = string.lower(st.mnemonic)
		local b = x86.baseMnemonic(m)
		local ops = st.operands
		if b == "leave" then
			-- `leave` = `movq %rbp, %rsp` + `popq %rbp`: recovers a known depth (and the
			-- matching save shape) from the frame pointer; without one — or when the
			-- frame pointer is not provably established on every path to this point — it
			-- is unprovable. Hardware `leave` also RESTORES the caller's frame pointer
			-- into %rbp, so the frame-pointer state ends here either way.
			if not usesRbp or fp ~= "est" then return "dyn", "dyn", fp end
			local nd = fpDepth - 8
			return nd, truncateSaves(sv, nd), "no"
		end
		if b == "mov" and ops[1] and ops[1].rc == "sp" then
			-- The alloca idiom's rsp update (`movq %rA, %rsp` carrying the allocation
			-- address): the depth becomes unknown, but the alloca pops nothing — the
			-- outstanding saves survive at their slots exactly as for a marked sub.
			if st.allocaPlace then
				return "dyn", sv, fp
			end
			-- `movq %rbp, %rsp` restores rsp from the frame pointer — an epilogue
			-- teardown, or a mid-function alloca "free". Like `leave`, it recovers a
			-- known depth (and the surviving save shape) from the frame pointer even
			-- when a dynamic alloca made the depth unknown, so the teardown `popq %rbp`
			-- after it still pairs with the prologue save. Unlike `leave` it does not
			-- touch %rbp, so the frame-pointer state is unchanged. Any other source
			-- makes the depth unknown — except a recovery from a prologue rsp save
			-- (validated by the smap in transfer below), which is just as known-good.
			if usesRbp and fp == "est" and ops[2] and ops[2].name == "rbp" then
				return fpDepth, truncateSaves(sv, fpDepth), fp
			end
			if recoverDepth then
				return recoverDepth, truncateSaves(sv, recoverDepth), fp
			end
			return "dyn", "dyn", fp
		end
		if b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "mem"
			and usesRbp and fp == "est" and ops[2].base and ops[2].base.name == "rbp"
			and not ops[2].index and not ops[2].dispSym then
			-- `leaq -N(%rbp), %rsp` restores rsp from the frame pointer: the lea form of
			-- `movq %rbp, %rsp`, used when callee-saved registers were pushed after the
			-- frame pointer was established — as an epilogue teardown, or as a
			-- mid-function alloca "free". Like `leave`/`movq %rbp, %rsp` it recovers a
			-- known depth (fpDepth + N) and the surviving save shape from the frame
			-- pointer even when a dynamic alloca made the depth unknown; the pops that
			-- follow must still pair with the prologue saves — a mismatching depth is
			-- caught by the save-pairing analysis at the pops themselves.
			local nd = fpDepth - (ops[2].dispVal or 0)
			return nd, truncateSaves(sv, nd), fp
		end
		if b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "mem"
			and ops[2].base and ops[2].base.kind == "reg" and ops[2].base.name ~= "rbp"
			and not ops[2].index and not ops[2].dispSym and recoverDepth then
			-- `leaq K(%reg), %rsp` recovers rsp from a saved-rsp CARRIER (the lea form of
			-- `movq %reg, %rsp` — the perlasm `leaq (%rsi), %rsp`): the incoming smap
			-- proved the base register holds the save value (recoverDepth = the parked
			-- depth minus K, computed in transfer), so exactly like the mov form the
			-- recovery revives that known depth and the surviving save shape.
			return recoverDepth, truncateSaves(sv, recoverDepth), fp
		end
		if b == "mov" and ops[1] and ops[1].name == "rbp" and ops[2] and ops[2].rc == "sp" then
			-- Establishing the frame pointer (`movq %rsp, %rbp`): from here %rbp holds a
			-- fixed frame-relative value on this path. Re-establishing it mid-function
			-- is rejected by the rewrite, so this is the one transition to "est".
			return d, sv, "est"
		end
		if isDynDepth(d) or sv == "dyn" then
			-- Inside a dynamic-alloca region the DEPTH is unprovable, but the outstanding
			-- saves still sit at their slots: an instruction that cannot touch rsp
			-- propagates the save stack unchanged so a later `leave`/`movq %rbp, %rsp`
			-- can revive it (the rewrite rejects every stack access, push/pop, or
			-- return that would execute at an unknown depth, so only inert computation
			-- may carry it). A push at an unknown depth — or any state whose save shape
			-- is already unknown — is unprovable. A pop's slot position is unknowable
			-- here, but it still consumes the most recent outstanding save: whether the
			-- pop may be DROPPED as that save's restore is decided by the annotation
			-- pass, which pairs it only inside a verified epilogue teardown and rejects
			-- it everywhere else. A constant rsp adjustment pops nothing, so the save
			-- stack survives it too (the annotation pass decides whether the adjustment
			-- is a verified teardown `addq $imm, %rsp`). The frame-pointer state is
			-- INDEPENDENT of the rsp poison: an alloca perturbs rsp, never rbp, so
			-- rbp-relative spill traffic stays provable through the poisoned region and
			-- fp is propagated unchanged.
			-- The {anchored} region scope propagates through inert computation exactly
			-- like the plain "dyn": the andq only lowered rsp, and nothing may move it
			-- again before the recovery — every rsp write below degrades to plain "dyn".
			if sv == "dyn" then return "dyn", "dyn", fp end
			if b == "push" then return "dyn", "dyn", fp end
			if b == "pop" then
				local c = { table.unpack(sv) }
				if #c > 0 then
					table.remove(c)
					return "dyn", c, fp
				end
				return "dyn", "dyn", fp
			end
			if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp"
				and not (isAlloca(st) or st.allocaPlace) then
				return "dyn", sv, fp
			end
			-- An alloca-form rsp write inside the scope: the region's OWN anchoring
			-- machinery (the andq marked for this region) keeps it; anything else (a
			-- nested region, a second dynamic alloca) leaves the scope — region
			-- coordinates shift with rsp, so further offsets can no longer be keyed.
			if (b == "sub" or b == "add" or b == "and") and ops[1] and ops[1].rc == "sp"
				and (isAlloca(st) or st.allocaPlace) then
				if st.allocaAnchor and type(d) == "table" and d.anchored == st.allocaAnchor then
					return d, sv, fp
				end
				return "dyn", sv, fp
			end
			-- Any modeled definition of a pushed register breaks the link between its
			-- outstanding save and the register's CURRENT web exactly as at a known
			-- depth (the def-marking below is reached only on the known-depth path,
			-- which this branch returns before): mark the save redefined so a pop
			-- paired after the depth is revived cannot silently drop a reload of a
			-- stale value. (Never mutate the incoming list — it is shared across the
			-- fixpoint.)
			local c = classOf(st)
			if #c.defs > 0 and #sv > 0 then
				local hit = false
				for _, e in sv do
					if not e.redefined then
						for _, dd in c.defs do
							if dd.kind == "reg" and dd.rc == "gpr" and dd.num == e.num then
								hit = true break
							end
						end
					end
					if hit then break end
				end
				if hit then
					local out = {}
					for _, e in sv do
						local redefined = e.redefined
						if not redefined then
							for _, dd in c.defs do
								if dd.kind == "reg" and dd.rc == "gpr" and dd.num == e.num then
									redefined = true break
								end
							end
						end
						table.insert(out, { name = e.name, num = e.num, depth = e.depth,
							redefined = redefined })
					end
					sv = out
				end
			end
			-- Inert computation: propagate the depth (plain "dyn" or the {anchored}
			-- region scope) unchanged.
			return d, sv, fp
		end
		if b == "push" then
			local c = { table.unpack(sv) }
			table.insert(c, {
				name = (ops[1] and ops[1].kind == "reg") and ops[1].name or "?",
				num = (ops[1] and ops[1].kind == "reg") and ops[1].num or nil,
				depth = d + 8,
				redefined = false })
			return d + 8, c, fp
		end
		if b == "pop" then
			-- The pop consumes the slot at the current depth. Whether that slot holds a
			-- matching save is verified from the INCOMING state at the pop (see the
			-- x86_unpairedPop annotation); here only the stack shape is maintained.
			local c = { table.unpack(sv) }
			if #c > 0 and c[#c].depth == d then
				local poppedFp = usesRbp and c[#c].name == "rbp"
				table.remove(c)
				-- A paired `popq %rbp` restores the SAVED frame pointer — the caller's —
				-- so %rbp stops being this function's frame pointer from here on: any
				-- later rbp-relative access would address the caller's frame. The
				-- per-point frame-pointer state records exactly that.
				return d - 8, c, (poppedFp and "no") or fp
			end
			return d - 8, "dyn", fp
		end
		local nd = d
		if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp" then
			if isAlloca(st) or st.allocaPlace then
				-- dynamic alloca (`subq %rax, %rsp ;! alloca size (x)`, the deferred
				-- idiom's unannotated adjustment marked st.allocaPlace, or an
				-- `alloca result size=N`-annotated constant reservation): the depth
				-- becomes unknown, but the alloca pops nothing — the outstanding saves
				-- survive at their slots and a later fp restore revives them. (Checked
				-- BEFORE the immediate case: an annotated constant `subq $imm, %rsp`
				-- is the allocation — dropped — so its depth effect must not count.)
				-- An ANCHORED region's reservation enters the region's scope (the
				-- {anchored} depth: raw displacements are region coordinates there).
				local ar = anchoredRegionOf(st)
				if ar then return { anchored = ar }, sv, fp end
				return "dyn", sv, fp
			elseif ops[2] and ops[2].kind == "imm" then
				nd = (b == "sub") and (d + immVal(ops[2])) or (d - immVal(ops[2]))
			else
				return "dyn", "dyn", fp  -- unanalyzable rsp write
			end
		end
		if b == "and" and ops[1] and ops[1].rc == "sp" and (isAlloca(st) or st.allocaPlace) then
			-- The alignment-anchored alloca form (`andq $-A, %rsp ;! alloca result size=N`,
			-- or the andq marked as machinery of a `subq $K, %rsp`-anchored region): the
			-- andq only LOWERS rsp to an alignment boundary — nothing is popped, so the
			-- outstanding saves survive exactly as for a marked sub. (An UNMARKED andq
			-- on rsp keeps its historical treatment: no depth change here, and the
			-- rewrite rejects it as a stack-address escape.)
			local ar = anchoredRegionOf(st)
			if ar then return { anchored = ar }, sv, fp end
			return "dyn", sv, fp
		end
		if b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "mem"
			and ops[2].base and ops[2].base.rc == "sp" and not ops[2].index and not ops[2].dispSym then
			-- `leaq K(%rsp), %rsp`: the lea spelling of a constant rsp adjustment
			-- (prologue `leaq -N(%rsp), %rsp` allocation, epilogue `leaq +N(%rsp), %rsp`
			-- teardown) — same depth math as the sub/add forms.
			nd = d - (ops[2].dispVal or 0)
		end
		if nd < d then sv = truncateSaves(sv, nd) end
		-- A full-width (8-byte) plain store to a save slot RE-SYNCS the slot with the
		-- pushed register's web: the hardware slot receives the stored value and the
		-- save-slot model defines the register's web with exactly that value, so the
		-- two agree again from here on (a redefinition before the store is harmless —
		-- the store overwrites both). Clear the save's redefined state for such a
		-- store; every other access keeps the state from the def-marking below.
		if b == "mov" and sv ~= "dyn" and #sv > 0 and d == D0 then
			local mem = nil
			for _, o in ops do if o.kind == "mem" then mem = o end end
			if mem and not mem.index and not mem.dispSym and mem.base
				and (mem.base.rc == "sp" or (usesRbp and mem.base.name == "rbp")) then
				local w0 = gprStackWidth(m, mem)
				local off = (mem.dispVal or 0)
				if mem.base.rc ~= "sp" then off = frameSize + off end
				if w0 == 8 then
					local changed = false
					for _, e in sv do
						if e.redefined and off == d - e.depth then changed = true break end
					end
					if changed then
						local out = {}
						for _, e in sv do
							if e.redefined and off == d - e.depth then
								table.insert(out, { name = e.name, num = e.num,
									depth = e.depth, redefined = false })
							else
								table.insert(out, e)
							end
						end
						sv = out
					end
				end
			end
		end
		-- Any modeled definition of a pushed register breaks the link between its
		-- outstanding save and the register's CURRENT web: the save's slot still holds
		-- the value pushed before the redefinition, but the dropped pop would restore
		-- the save into a register whose web now holds something else. (Never mutate
		-- the incoming list — it is shared across the fixpoint.)
		local c = classOf(st)
		if #c.defs > 0 and sv ~= "dyn" and #sv > 0 then
			local hit = false
			for _, e in sv do
				if not e.redefined then
					for _, dd in c.defs do
						if dd.kind == "reg" and dd.rc == "gpr" and dd.num == e.num then
							hit = true break
						end
					end
				end
				if hit then break end
			end
			if hit then
				local out = {}
				for _, e in sv do
					local redefined = e.redefined
					if not redefined then
						for _, dd in c.defs do
							if dd.kind == "reg" and dd.rc == "gpr" and dd.num == e.num then
								redefined = true break
							end
						end
					end
					table.insert(out, { name = e.name, num = e.num, depth = e.depth,
						redefined = redefined })
				end
				return nd, out, fp
			end
		end
		return nd, sv, fp
	end

	-- The full transition, adding the SAVED-RSP CARRIER MAP (smap) to the core state.
	-- The prologue `movq %rsp, %reg` save (and its `leaq K(%rsp), %reg` form) parks a
	-- value sarcasm's synthesized frame makes PHANTOM: the save, every carrier flow of
	-- it, and the recovery are ALL dropped, so the value has no output existence and
	-- injected runtime calls / SysV callee clobbers can never corrupt it. The smap
	-- tracks, per program point, which CARRIERS provably hold the save value:
	--   * register carriers — keyed by register name; a save may be copied reg→reg
	--     (`movq %carrier, %reg`), keeping both;
	--   * frame-slot carriers — keyed by slot offset (`movq %carrier, off(%rsp)` /
	--     `off(%rbp)`); a full-width load from the slot (`movq off(%rsp), %reg`)
	--     re-materializes a register carrier. Slot keys live in the access's own
	--     coordinates: "S"..<normalized frame offset> at provable depth (the same
	--     key the slot virtualization uses), "D"..<disp> at "dyn" depth (the
	--     anchored-region coordinates — cleared on any later rsp write, which would
	--     shift those coordinates).
	-- A recovery (`movq %reg, %rsp`, or `leaq K(%reg), %rsp`) may read any carrier
	-- that provably holds the save value and revives the parked depth (minus K).
	-- Any OTHER read of a register carrier, and any redefinition of one, poisons it
	-- (the `redefined` merge rule); a store overlapping a slot carrier poisons the
	-- slot, and a non-carrier-form LOAD from it is rejected outright (it would
	-- observe the phantom value). CFG joins require per-key agreement.
	-- Register class is unrestricted: the carrier discipline makes every use either
	-- dropped or rejected, so a caller-saved register (or a caller-saved save riding
	-- through a region slot — the sha256/sha512/wp idiom) is exactly as sound as a
	-- callee-saved one. EXCEPTIONS: (a) with incoming yolo STACK ARGUMENTS
	-- (yoloCount > 0) a save additionally serves as an entry-rsp ALIAS whose
	-- entry-time argument reads the rewrite redirects to the arguments' slots
	-- (those reads remove the register use entirely); (b) a caller-saved save with
	-- a static fixed-alloca region based at rsp+0 is NOT a carrier — the region
	-- redirect keeps it alive as a REAL value (the region corner). Only CALLEE-SAVED
	-- prologue saves (and the yolo aliases) are recorded on the region-less early
	-- analysis run: the corner and the in-region lea exclusion need the regions, and
	-- every shape they legalize is then revalidated (and never errors early).
	-- The FP/SIMD knowledge module, aliased for scopes where the `fp` frame-pointer
	-- state parameter shadows the file-scope `fp` module.
	local fpKnowledge = fp
	local function slotKeyOf(mem, d, st)
		-- Carrier-slot key for a plain base+disp stack memory operand (see the smap
		-- comment), or nil for a non-stack/unkeyable operand. A clone statement's
		-- displacement keys 8 lower (the +8 rule — localcall.luau).
		if not (mem and mem.kind == "mem" and mem.base and mem.base.kind == "reg"
			and not mem.index and not mem.dispSym) then return nil end
		local disp = mem.dispVal or 0
		local bias = (st and st.localClone) and 8 or 0
		if mem.base.rc == "sp" then
			if isDynDepth(d) then return "D" .. disp, disp, "D" end
			if d == nil then return nil end
			return "S" .. (disp + D0 - d - bias), disp + D0 - d - bias, "S"
		end
		if usesRbp and mem.base.name == "rbp" then
			return "S" .. (frameSize + disp), frameSize + disp, "S"
		end
		return nil
	end
	-- A region-pointer value: a register provably holding <region base + K>, from a
	-- region-redirect lea (`leaq K(%rsp), %reg` landing in a fixed region — the wp
	-- `leaq 128(%rsp), %r10`). Recorded in the smap as { roff = K, rbase, rspace }:
	-- the register is a REAL pointer (reads are legal — unlike carriers), and a
	-- carrier save-store/load THROUGH it keys the slot in the region's coordinate
	-- space (`movq %rax, 32(%r10)` parks the save in region slot 128+32).
	-- Is `st` such a region-pointer lea? Returns (roff, rbase, rspace).
	local function regionLeaOf(st, d)
		local ops = st.operands
		if x86.baseMnemonic(string.lower(st.mnemonic)) ~= "lea" then return nil end
		if not (ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr" and ops[1].name ~= "rbp") then return nil end
		local mem = ops[2]
		if not (mem and mem.kind == "mem" and mem.base and mem.base.kind == "reg"
			and not mem.index and not mem.dispSym) then return nil end
		local disp = mem.dispVal or 0
		if mem.base.rc == "sp" and type(d) == "table" then
			-- anchored scope: raw displacements are the region's coordinates
			local r = d.anchored
			if disp >= r.base and disp < r.base + r.size then
				return disp - r.base, r.base, "D"
			end
			return nil
		end
		if d == nil or isDynDepth(d) then return nil end
		local off = disp
		if mem.base.rc ~= "sp" then
			if usesRbp and mem.base.name == "rbp" then off = frameSize + disp
			else return nil end
		elseif st.localClone then
			-- the +8 rule (the return-address compensation on rsp-relative
			-- clone accesses — localcall.luau)
			off = off + D0 - d - 8
		end
		local r = regionOf(off, false)
		if r then return off - r.base, r.base, "S" end
		return nil
	end
	-- Is `st` a full-width `movq %rA, %rB` copy of a region-pointer value?
	local function roffCopyOf(st, smap)
		local ops = st.operands
		if x86.baseMnemonic(string.lower(st.mnemonic)) ~= "mov" then return nil end
		if not (ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr" and ops[1].name ~= "rbp"
			and (ops[1].width == 64 or ops[1].width == nil)) then return nil end
		if not (ops[2] and ops[2].kind == "reg" and ops[2].rc == "gpr" and ops[2].name ~= "rbp"
			and (ops[2].width == 64 or ops[2].width == nil)) then return nil end
		local e = smap[ops[2].name]
		if e and e.roff and not e.redefined then return e end
		return nil
	end
	-- Slot key for a plain base+disp memory operand: stack-based (slotKeyOf), or a
	-- region-pointer-derived base register (smap[base].roff) — the latter keys the
	-- slot in the region's own coordinate space, so the two spellings of one slot
	-- (rsp-relative direct, or through a region pointer) unify.
	local function memSlotKey(mem, d, smap, st)
		if not (mem and mem.kind == "mem" and mem.base and mem.base.kind == "reg"
			and not mem.index and not mem.dispSym) then return nil end
		if mem.base.rc == "sp" or (usesRbp and mem.base.name == "rbp") then
			return slotKeyOf(mem, d, st)
		end
		local e = smap and smap[mem.base.name]
		if e and e.roff and not e.redefined then
			local off = e.rbase + e.roff + (mem.dispVal or 0)
			return e.rspace .. off, off, e.rspace
		end
		return nil
	end
	-- Is `st` a full-width `movq %carrier, %reg` carrier copy (reg→reg save flow)?
	local function carrierCopyOf(st, smap)
		local ops = st.operands
		if x86.baseMnemonic(string.lower(st.mnemonic)) ~= "mov" then return nil end
		if not (ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr" and ops[1].name ~= "rbp"
			and (ops[1].width == 64 or ops[1].width == nil)) then return nil end
		if not (ops[2] and ops[2].kind == "reg" and ops[2].rc == "gpr" and ops[2].name ~= "rbp"
			and (ops[2].width == 64 or ops[2].width == nil)) then return nil end
		local e = smap[ops[2].name]
		if e and not e.redefined and not e.slot and not e.roff then return e end
		return nil
	end
	-- Is `st` a full-width `movq %carrier, off(%rsp)/off(%rbp)` save-store (register
	-- carrier -> slot carrier)? Returns the carrier and the slot key.
	local function saveStoreOf(st, smap, d)
		local ops = st.operands
		if x86.baseMnemonic(string.lower(st.mnemonic)) ~= "mov" then return nil end
		local mem = ops[1]
		if not (mem and mem.kind == "mem") then return nil end
		if not (ops[2] and ops[2].kind == "reg" and ops[2].rc == "gpr" and ops[2].name ~= "rbp"
			and (ops[2].width == 64 or ops[2].width == nil)) then return nil end
		local e = smap[ops[2].name]
		if not (e and not e.redefined and not e.slot and not e.roff) then return nil end
		local key, off, space = memSlotKey(mem, d, smap, st)
		if not key then return nil end
		return e, key, off, space
	end
	-- Is `st` a full-width `movq off(%rsp)/off(%rbp), %reg` carrier-load (slot carrier
	-- -> register carrier)? Returns the slot carrier.
	local function carrierLoadOf(st, smap, d)
		local ops = st.operands
		if x86.baseMnemonic(string.lower(st.mnemonic)) ~= "mov" then return nil end
		if not (ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr" and ops[1].name ~= "rbp"
			and (ops[1].width == 64 or ops[1].width == nil)) then return nil end
		local key = memSlotKey(ops[2], d, smap, st)
		if not key then return nil end
		local e = smap[key]
		if e and not e.redefined then return e end
		return nil
	end
	-- Is `st` a `movq K(%carrier), %dest` epilogue restore load through a saved-rsp
	-- carrier (the perlasm movq-restore riding the recovered pointer)? The carrier's
	-- parked depth minus K names the read save slot; it is a restore iff an
	-- outstanding pushed save sits at exactly that depth and the destination is that
	-- save's register. Returns the save-stack entry, or nil.
	local function restoreLoadOf(st, smap, sv)
		local ops = st.operands
		if x86.baseMnemonic(string.lower(st.mnemonic)) ~= "mov" then return nil end
		if not (ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr"
			and (ops[1].width == 64 or ops[1].width == nil)) then return nil end
		local mem = ops[2]
		if not (mem and mem.kind == "mem" and mem.base and mem.base.kind == "reg"
			and not mem.index and not mem.dispSym) then return nil end
		if not (sv and sv ~= "dyn") then return nil end
		local e = smap and smap[mem.base.name]
		if not (e and not e.redefined and not e.slot and not e.roff) then return nil end
		local sdepth = e.depth - (mem.dispVal or 0)
		for _, s in sv do
			if s.depth == sdepth then
				if s.name == ops[1].name then return s end
				return nil
			end
		end
		return nil
	end
	local function transfer(st, d, sv, smap, fp, idx)
		local ops = st.operands
		-- The alloca machinery owns its statements outright (they are dropped or
		-- replaced wholesale by the transform — frame.preprocess routes them around the
		-- rewrite), so they are neither saves nor recoveries nor carriers.
		-- A save form records its save wherever the depth is provable (a "dyn" or
		-- unreachable depth cannot name a parked value). Post-prologue saves are as
		-- sound as prologue ones — the value derives from the CURRENT rsp at a static
		-- depth, and the carrier discipline drops or rejects every use of it — which
		-- is exactly what the perlasm shortcut-dispatch preamble needs (the save sits
		-- behind the dispatch's merge label, after the prologue scan stopped). The
		-- fixed-alloca-region corner is the one exclusion: a caller-saved save with a
		-- static region based at rsp+0 KEEPS executing with its destination
		-- redirected to the allocation pointer, so it is no save at all and its
		-- register may be read. A save is recorded even when the deferred-idiom
		-- discovery marked it allocaPlace/allocaOwned: those marks mean the statement
		-- is DROPPED by the emitter — and a dropped save is exactly what the frame
		-- rewrite does with it, so the register keeps holding the save either way. An
		-- ANNOTATED save form is excluded: a `;! alloca size` definition STAYS and
		-- computes the size, not a parked %rsp. (Register classes: see the smap
		-- comment — callee-saved always; any register with yolo stack arguments;
		-- caller-saved otherwise only on the region-carrying run and outside the
		-- rsp+0 region corner.)
		local isSave = isSpSaveForm(st) and not isAlloca(st) and d ~= nil and not isDynDepth(d)
			and (x86.CALLEE_SAVED[ops[1].name] ~= nil or yoloCount > 0
				or (regions ~= nil and not regionOf(0, false)))
			-- A POST-prologue save form owned by the deferred alloca idiom is the
			-- idiom's BASE computation (clang's VLA shape `movq %rsp, %rcx; ...;
			-- subq %rax, %rcx ;! alloca result`), not a parked stack pointer: the
			-- idiom machinery drops it. (Prologue saves are recorded even when the
			-- discovery's coarse region swallowed them — see the comment above.)
			and (idx < prologueEnd or not (st.allocaPlace or st.allocaOwned))
		-- A saved-rsp materialization via lea. The yolo form (`leaq 0(%rsp), %reg`,
		-- the aesni_ocb prologue shape) is an entry-rsp alias like the mov save. The
		-- general form — `leaq d(%rsp), %reg` at a provable depth d (the perlasm
		-- recovery-address computation, `leaq 280+48(%rsp), %rsi` at depth 328) —
		-- parks the ENTRY stack pointer (depth 0). A lea with K < d computes a
		-- frame-INTERIOR address: that is frame-address-taking into the buffer (the
		-- region redirect's domain when K lands in a region, the escape rejection
		-- otherwise), not a saved stack pointer. Excluded when K lands in a static
		-- alloca region: that lea is the region redirect's REAL pointer arithmetic,
		-- not a carrier. (Recorded only on the region-carrying run, like
		-- caller-saved saves.)
		local isLeaSave = isYoloLeaSave(st, d)
		local leaSaveForm = nil
		if not isLeaSave and regions ~= nil and not isAlloca(st)
			and not (st.allocaPlace or st.allocaOwned)
			and d ~= nil and not isDynDepth(d)
			and x86.baseMnemonic(string.lower(st.mnemonic)) == "lea" then
			local mem = ops[2]
			if ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr" and ops[1].name ~= "rbp"
				and mem and mem.kind == "mem" and mem.base and mem.base.rc == "sp"
				and not mem.index and not mem.dispSym then
				local k = mem.dispVal or 0
				-- A clone statement parks the ENTRY stack pointer with K = d + 8
				-- (the return-address word — the +8 rule); the static-region
				-- membership test keys its displacement the same way.
				local pk = st.localClone and (k - 8) or k
				local rkey = st.localClone and (k + D0 - d - 8) or k
				if pk == d and not regionOf(rkey, false) then
					isLeaSave = true
					leaSaveForm = "leaq " .. k .. "(%rsp)"
				end
			end
		end
		local owned = st.allocaPlace or st.allocaOwned or isAlloca(st)
		-- The recovery forms: `movq %reg, %rsp` revives the parked depth; `leaq K(%reg),
		-- %rsp` (base register not rbp — that is the frame-pointer recovery above)
		-- revives the parked depth minus K. Either may read any live carrier. (No
		-- callee-saved requirement: the recovery is dropped, so no clobber is
		-- observable — the carrier discipline makes every other use a rejection.)
		local recoverDepth = nil
		if not owned and isSpRecoverForm(st) then
			local e = smap[ops[2].name]
			if e and not e.redefined and not e.slot and not e.roff then recoverDepth = e.depth end
		end
		if not owned and recoverDepth == nil
			and x86.baseMnemonic(string.lower(st.mnemonic)) == "lea"
			and ops[1] and ops[1].kind == "reg" and ops[1].rc == "sp"
			and (ops[1].width == 64 or ops[1].width == nil)
			and ops[2] and ops[2].kind == "mem" and ops[2].base and ops[2].base.kind == "reg"
			and ops[2].base.name ~= "rbp" and not ops[2].index and not ops[2].dispSym then
			local e = smap[ops[2].base.name]
			if e and not e.redefined and not e.slot and not e.roff then
				local rd = e.depth - (ops[2].dispVal or 0)
				if rd >= 0 then recoverDepth = rd end
			end
		end
		-- The remaining carrier flows (register copy, save-store, carrier-load), all
		-- dropped by the rewrite exactly like the save itself.
		local copySrc = (not owned) and carrierCopyOf(st, smap) or nil
		local storeSrc, storeKey, storeOff, storeSpace = nil, nil, nil, nil
		if not owned and not copySrc then storeSrc, storeKey, storeOff, storeSpace = saveStoreOf(st, smap, d) end
		local loadSrc = (not owned and not copySrc and not storeSrc) and carrierLoadOf(st, smap, d) or nil
		local restoreSave = (not owned) and restoreLoadOf(st, smap, sv) or nil
		-- Region-pointer values (the region-redirect lea and its copies): tracked so
		-- carrier save-stores/loads THROUGH them key the slot in region coordinates.
		local rOff, rBase, rSpace = nil, nil, nil
		if not owned and not copySrc and not storeSrc and not loadSrc then
			rOff, rBase, rSpace = regionLeaOf(st, d)
		end
		local roffCopySrc = (not owned and not rOff) and roffCopyOf(st, smap) or nil
		local nd, nsv, nfp = transferCore(st, d, sv, fp, recoverDepth)
		-- An rsp write (of any form — including a recovery or a push/pop) shifts the
		-- "dyn"-space coordinates: slot carriers keyed in it cannot survive.
		local function clearDynSlots(out)
			if not insnWritesSp(st) then return out end
			local cleaned = nil
			for k, e in pairs(out) do
				if e.slot and e.space == "D" then
					if not cleaned then cleaned = {} for k2, e2 in pairs(out) do cleaned[k2] = e2 end end
					cleaned[k] = nil
				end
			end
			return cleaned or out
		end
		if isSave or isLeaSave then
			-- A (re)definition of the save: the register freshly parks a known rsp
			-- depth. This must not run the def-marking below: the save re-registers
			-- itself. (A clone statement's parked depth carries the return-address
			-- word too — the +8 rule.)
			local out = {}
			for k, e in pairs(smap) do out[k] = e end
			out[ops[1].name] = { name = ops[1].name, num = ops[1].num,
				depth = isLeaSave and (d + (st.localClone and 8 or 0) - (ops[2].dispVal or 0)) or d,
				redefined = false, form = leaSaveForm
					or (isLeaSave and "leaq 0(%rsp)" or nil) }
			return nd, nsv, clearDynSlots(out), nfp
		end
		if recoverDepth then
			-- The recovery reads the save and writes %rsp; the save REGISTER is
			-- unchanged, so it still holds the save — a second recovery from it stays
			-- valid, and so does further traffic that does not read it.
			return nd, nsv, clearDynSlots(smap), nfp
		end
		if copySrc then
			local out = {}
			for k, e in pairs(smap) do out[k] = e end
			out[ops[1].name] = { name = ops[1].name, num = ops[1].num, depth = copySrc.depth,
				redefined = false, form = copySrc.form }
			return nd, nsv, clearDynSlots(out), nfp
		end
		if storeSrc then
			local out = {}
			for k, e in pairs(smap) do out[k] = e end
			out[storeKey] = { slot = true, name = "the frame slot", depth = storeSrc.depth,
				redefined = false, off = storeOff, space = storeSpace }
			return nd, nsv, clearDynSlots(out), nfp
		end
		if loadSrc then
			local out = {}
			for k, e in pairs(smap) do out[k] = e end
			out[ops[1].name] = { name = ops[1].name, num = ops[1].num, depth = loadSrc.depth,
				redefined = false }
			return nd, nsv, clearDynSlots(out), nfp
		end
		if rOff then
			-- The region-redirect lea defines a region-pointer value (a REAL pointer —
			-- reads are legal, unlike carriers): record its offset for carrier-slot
			-- keying through the register.
			local out = {}
			for k, e in pairs(smap) do out[k] = e end
			out[ops[1].name] = { name = ops[1].name, num = ops[1].num,
				roff = rOff, rbase = rBase, rspace = rSpace, redefined = false }
			return nd, nsv, clearDynSlots(out), nfp
		end
		if roffCopySrc then
			local out = {}
			for k, e in pairs(smap) do out[k] = e end
			out[ops[1].name] = { name = ops[1].name, num = ops[1].num,
				roff = roffCopySrc.roff, rbase = roffCopySrc.rbase,
				rspace = roffCopySrc.rspace, redefined = false }
			return nd, nsv, clearDynSlots(out), nfp
		end
		-- Any other instruction. A modeled def of a save register (an ordinary move, a
		-- pop INTO it, an implicit clobber like cpuid's ebx) breaks the link between the
		-- register and its saved value — mirroring the pushed-save redefinition logic
		-- above. And while a save is OUTSTANDING (unredefined) the register's web IS the
		-- dropped save: the rewrite removed the `movq %rsp, %reg` that defined it, so
		-- the web holds no value the output computes — any read of it (as an operand,
		-- through a memory base, or by pushing the register) would observe garbage.
		-- Reject it. (Never mutate the incoming map — it is shared across the fixpoint.)
		local c = classOf(st)
		local out = smap
		for name, e in pairs(smap) do
			if not e.redefined and not e.slot and not e.roff then
				-- Count this instruction's modeled uses of the save register. Allowed
				-- survivors: the memory base of an entry-time read of an incoming yolo
				-- stack argument (the rewrite redirects it to the argument's slot,
				-- removing the register use entirely); an epilogue restore load through
				-- the carrier (its base is the only use, and the load is dropped);
				-- the self-xor/self-sub zeroing idiom (`xorl %eax, %eax` — the value
				-- written does not depend on the register's old value, so the modeled
				-- use observes nothing; the def below kills the alias, exactly as a
				-- plain redefinition). Anything else observes the dropped save.
				local zeroing = false
				do
					local bb = x86.baseMnemonic(string.lower(st.mnemonic))
					if (bb == "xor" or bb == "sub") and ops[1] and ops[2]
						and ops[1].kind == "reg" and ops[2].kind == "reg"
						and ops[1].num == e.num and ops[2].num == e.num then
						zeroing = true
					end
				end
				local nUses = 0
				for _, u in c.uses do
					if u.kind == "reg" and u.rc == "gpr" and u.num == e.num then nUses += 1 end
				end
				if nUses > 0 and not zeroing
					and not (nUses == 1 and yoloArgSlotOf(st, name, e.depth))
					and not (restoreSave and nUses == 1) then
					error("sarcasm: reading %" .. name .. " while it holds the prologue"
						.. " `" .. (e.form or "movq %rsp") .. ", %" .. name .. "` save cannot be proven safe (the"
						.. " save is dropped by the rewrite — the register's stack value"
						.. " does not exist in the output; recover %rsp from it first or"
						.. " redefine it): " .. (st.raw or st.mnemonic))
				end
			end
			if not e.redefined and not e.slot then
				for _, dd in c.defs do
					if dd.kind == "reg" and dd.rc == "gpr" and dd.num == e.num then
						if out == smap then
							out = {}
							for k, v in pairs(smap) do out[k] = v end
						end
						out[name] = { name = e.name, num = e.num, depth = e.depth,
							redefined = true }
						break
					end
				end
			end
		end
		-- Slot-carrier traffic: a stack WRITE overlapping a live slot carrier poisons
		-- the slot (the slot then holds an ordinary value; a later carrier-load or
		-- recovery from it is rejected); a stack LOAD from a live slot carrier that is
		-- not the carrier-load form would observe the phantom value — reject it.
		-- (Region-pointer-derived bases key the slot in the region's coordinates —
		-- the same space the direct rsp-relative spelling uses.)
		for _, o in ops do
			if o.kind == "mem" then
				local key, off, space = memSlotKey(o, d, smap, st)
				if key then
					local w = nil
					-- (fpKnowledge, not the `fp` frame-pointer state parameter.)
					local fpe = fpKnowledge.lookup(string.lower(st.mnemonic))
					if isFpInsn(fpe, st) then w = fpKnowledge.accessWidth(string.lower(st.mnemonic), ops, st.raw)
					else w = gprStackWidth(string.lower(st.mnemonic), o) end
					for k, e in pairs(smap) do
						if e.slot and not e.redefined and e.space == space and w
							and off < e.off + 8 and off + w > e.off then
							if ops[1] == o then
								-- a write (the mem operand is the destination): poison
								if out == smap then
									out = {}
									for k2, v in pairs(smap) do out[k2] = v end
								end
								out[k] = nil
							else
								error("sarcasm: stack access into a frame slot that holds the"
									.. " saved stack pointer cannot be proven safe (the save is"
									.. " phantom — the slot's value does not exist in the output;"
									.. " overwrite the slot first): " .. (st.raw or st.mnemonic))
							end
						end
					end
				end
			end
		end
		return nd, nsv, clearDynSlots(out), nfp
	end

	local function mergeSaves(a, b)
		if a == nil then return b end
		if a == "dyn" or b == "dyn" then return "dyn" end
		if #a ~= #b then return "dyn" end
		local grew = false
		for k = 1, #a do
			if a[k].name ~= b[k].name or a[k].depth ~= b[k].depth then return "dyn" end
			if b[k].redefined and not a[k].redefined then grew = true end
		end
		if not grew then return a end
		-- A redefinition on ONE incoming path poisons the save for both (the slot
		-- holds the pre-redefinition value regardless of which path was taken).
		local c = {}
		for k = 1, #a do
			c[k] = { name = a[k].name, num = a[k].num, depth = a[k].depth,
				redefined = a[k].redefined or b[k].redefined }
		end
		return c
	end
	local function mergeSmaps(a, b)
		if a == nil then return b end
		if b == nil then return a end
		if a == b then return a end
		-- Per-register agreement: a register's save must have the same depth and the
		-- same redefined-ness on every incoming path. Any disagreement — including one
		-- path carrying no save at all (it cannot have executed the save, or a path
		-- through a redefinition) — poisons that register: its recovery becomes
		-- unprovable and is rejected at the recovery site.
		local out = a
		for name, e in pairs(a) do
			local f = b[name]
			if not f or f.depth ~= e.depth or f.redefined ~= e.redefined
				or f.roff ~= e.roff or f.rbase ~= e.rbase or f.rspace ~= e.rspace then
				if out == a then
					out = {}
					for k, v in pairs(a) do out[k] = v end
				end
				out[name] = nil
			end
		end
		-- (A register only b holds is already absent from a — poisoned — so nothing to
		-- do for it; returning a itself when nothing was removed keeps the fixpoint's
		-- identity-based change detection stable.)
		return out
	end
	local function successors(i)
		local st = body[i]
		-- Local-subroutine marks (localcall.luau): a local call transfers to the
		-- per-caller clone's entry (no fall-through — the continuation is reached
		-- only through the clone's ret dispatch); a local ret branches to the
		-- clone's continuations. The clone executes at the CALLER's depth (the
		-- no-push clone model moves no stack pointer), so the state flows through
		-- both edges unchanged.
		if st.localCall then
			local t = labelAt[st.localCall.entry]
			if t then return { t } end
			return {}
		end
		if st.localRet then
			local out = {}
			for _, cont in st.localRet.conts do
				local t = labelAt[cont]
				if t then table.insert(out, t) end
			end
			return out
		end
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

	-- Are the condition flags DEAD after statement i — nothing reads them before a
	-- full flag write on any control-flow path? Conservative forward scan over the
	-- CFG: a flag READER (flagUse, incl. carry-in consumers) kills the proof; a
	-- full flag WRITER (flagDef: all six flags defined or documented-undefined)
	-- terminates the path soundly. A PARTIAL writer (flagWriteNoDef: inc/dec
	-- preserve CF, stc/clc replace only CF, sahf, bt*, shifts) neither reads nor
	-- fully rewrites — the flags a later reader would see through it depend on
	-- the pre-instruction value, so it also kills the proof. Paths that reach a
	-- `ret` (or the body end) are sound: nothing reads flags there. Used by the
	-- mid-function `addq $imm, %rsp` drop below (the add clobbers the flags).
	local function flagsDeadAfter(i)
		local work, seen = {}, {}
		for _, s in successors(i) do table.insert(work, s) end
		while #work > 0 do
			local j = table.remove(work)
			if not seen[j] then
				seen[j] = true
				local st = body[j]
				if st.kind == "insn" then
					if x86.flagUse(st) or x86.flagWriteNoDef(st) then return false end
					if not x86.flagDef(st) then
						for _, s in successors(j) do table.insert(work, s) end
					end
				end
			end
		end
		return true
	end
	local depthIn, savesIn, fpIn, smapIn = {}, {}, {}, {}
	do
		-- Local-ret state source (localcall.luau): a local ret resumes its
		-- continuation with the CLONE ENTRY's depth/saves/frame-pointer state —
		-- the clone's own frame machinery (its pushes, its frame sub/add) is
		-- dropped exactly like a top-level frame, so the real rsp never moved
		-- inside the clone, and the continuation executes at the caller's
		-- (callsite's) depth. The smap keeps the clone's flow (carrier
		-- redefinitions inside the clone still poison the caller's carriers;
		-- carriers created inside the clone park the clone's rsp and are
		-- dropped). Because the clone entry is not a CFG predecessor of the ret,
		-- the fixpoint re-enqueues a clone's local rets whenever the entry's
		-- state changes (see the merge below), so the override always evaluates
		-- against the converged entry state.
		local localRetByEntry = {}
		for i, st in body do
			if st.kind == "insn" and st.localRet then
				local e = labelAt[st.localRet.entry]
				if e then
					if not localRetByEntry[e] then localRetByEntry[e] = {} end
					table.insert(localRetByEntry[e], i)
				end
			end
		end
		local firstInsn
		for i, st in body do
			if st.kind == "insn" then firstInsn = i break end
		end
		if firstInsn then
			depthIn[firstInsn] = 0
			savesIn[firstInsn] = {}
			smapIn[firstInsn] = {}
			fpIn[firstInsn] = "no"
			local worklist, inq = { firstInsn }, { [firstInsn] = true }
			while #worklist > 0 do
				local i = table.remove(worklist)
				inq[i] = nil
				local od, osv, osmap, ofp = transfer(body[i], depthIn[i], savesIn[i],
					smapIn[i], fpIn[i], i)
				local st = body[i]
				if st.localRet then
					local e = labelAt[st.localRet.entry]
					if e and depthIn[i] ~= nil then
						od = depthIn[e]
						osv = savesIn[e]
						ofp = fpIn[e]
						local esmap = smapIn[e]
						if esmap then
							local out = {}
							for name, ee in pairs(osmap) do
								if esmap[name] then out[name] = ee end
							end
							osmap = out
						end
					end
				end
				for _, s in successors(i) do
					-- A nil od carries NO state across the edge: it arises only
					-- from the local-ret override above when the clone's entry
					-- has not been reached yet (the clone is entered only
					-- through its callsite, so a local ret can transiently be
					-- dequeued — through a shared clone whose other callsites
					-- ARE reached — before its own entry has state). Propagating
					-- then would poison the continuation: with an unreached
					-- successor a nil "merged" could still be assigned when a
					-- saves/smap/fp component alone differed (enqueueing a
					-- statement with depthIn nil — crashing the transfer), and
					-- with a reached one it would spuriously reset it to "dyn".
					-- The continuation is reached for real once the entry's
					-- state arrives and the ret is re-evaluated (the
					-- localRetByEntry re-enqueue below), so skipping the edge
					-- now loses nothing and keeps the fixpoint's invariant:
					-- depthIn nil means UNREACHED, and is never assigned.
					if od ~= nil then
					local cur = depthIn[s]
					local merged
					if cur == nil then merged = od
					elseif cur == "dyn" or od == "dyn" then merged = "dyn"
					elseif type(cur) == "table" or type(od) == "table" then
						-- The {anchored} region scope survives a merge only when every
						-- path sits in the SAME region's scope (a loop inside one is
						-- fine); anything else is the ordinary unprovable "dyn".
						if type(cur) == "table" and type(od) == "table"
							and cur.anchored == od.anchored then
							merged = cur
						else
							merged = "dyn"
						end
					elseif cur == od then merged = cur
					else merged = "dyn" end
					local mergedSv = mergeSaves(savesIn[s], osv)
					local mergedSmap = mergeSmaps(smapIn[s], osmap)
					local curFp, mergedFp = fpIn[s], nil
					if curFp == nil then mergedFp = ofp
					elseif curFp == "dyn" or ofp == "dyn" then mergedFp = "dyn"
					elseif curFp == ofp then mergedFp = curFp
					else mergedFp = "dyn" end
					if merged ~= cur or mergedSv ~= savesIn[s] or mergedSmap ~= smapIn[s]
						or mergedFp ~= curFp then
						depthIn[s] = merged
						savesIn[s] = mergedSv
						smapIn[s] = mergedSmap
						fpIn[s] = mergedFp
						if not inq[s] then inq[s] = true table.insert(worklist, s) end
						-- A clone entry's state changed: re-evaluate its local rets
						-- (their override reads this state; see above). Only when the
						-- ret's own flow has already reached it.
						for _, lr in (localRetByEntry[s] or {}) do
							if depthIn[lr] ~= nil and not inq[lr] then
								inq[lr] = true table.insert(worklist, lr)
							end
						end
					end
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
				-- A local call inside a teardown span is control flow the
				-- straight-line proof cannot cover. A local RET is the span's
				-- terminator exactly like a top-level ret (the clone's own epilogue
				-- teardown leads to it): it terminates the span below.
				if st.localCall then return nil end
				-- The terminating `ret` is part of the verified span (the annotation pass
				-- accepts a return at an UNKNOWN depth only inside such a span).
				if b == "ret" then table.insert(marks, j) return marks end
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
	-- A paired pop of a save whose register was redefined between the push and the
	-- pop still gets DROPPED (the save/restore round-trip is otherwise a no-op), but
	-- its RELOAD is then lost: hardware loads the pushed value into the register,
	-- while the web keeps the redefined value. That is invisible until the register
	-- is OBSERVED after the pop — so walk forward from the pop (CFG, stopping at a
	-- fresh definition of the register) and reject at the first use that would read
	-- the wrong value. The standard prologue/epilogue shapes read nothing after the
	-- epilogue pops and stay accepted. The same walk guards the dropped
	-- movq-restore loads below (there `why` names the shape).
	local function checkLostReload(popIdx, save, why)
		local work, seen = {}, {}
		for _, s in successors(popIdx) do table.insert(work, s) end
		while #work > 0 do
			local i = table.remove(work)
			if seen[i] then continue end
			seen[i] = true
			local st = body[i]
			if st.kind ~= "insn" then continue end
			local c = classOf(st)
			for _, u in c.uses do
				if u.kind == "reg" and u.rc == "gpr" and u.num == save.num then
					error("sarcasm: register " .. save.name .. " is read after the"
						.. " " .. (why or ("transient-pad pop that restores its save (the"
							.. " register was redefined between its push and that pop, so the"
							.. " pop's reload cannot be modeled and this read would see the"
							.. " redefined value; read it before the pop or don't redefine"
							.. " it inside the pad)")) .. ": " .. (st.raw or st.mnemonic))
				end
			end
			local defined = false
			for _, dd in c.defs do
				if dd.kind == "reg" and dd.rc == "gpr" and dd.num == save.num then
					defined = true break
				end
			end
			if not defined then
				for _, s in successors(i) do table.insert(work, s) end
			end
		end
	end
	-- Does the entry signature return an integer-class value (in %rax)? A restore
	-- into %rax can never be proven unobservable (the frame analysis does not model
	-- `ret`'s operand read), and a %rax carrier live at a `ret` is an escaping stack
	-- address — both checks below key off this.
	local retIsGpr = sigDesc and not sigDesc.isVoid
		and not (sigDesc.retTypes[1] and sig.isFpClass(sigDesc.retTypes[1]))
	for i, st in body do
		if st.kind == "insn" then
			st.x86_prologue = i < prologueEnd
			st.x86_depth = depthIn[i]
			-- Whether the frame pointer is provably established (its prologue value
			-- intact) on EVERY path reaching this instruction: "est", "no" (not
			-- established — an early-exit path that skipped the prologue, or a point
			-- after a paired `popq %rbp` restored the caller's frame pointer), "dyn"
			-- (paths disagree), or nil (unreachable code). Gates every rbp-relative
			-- virtualization: a static slot is only what the access addresses when
			-- %rbp provably still holds this function's frame pointer.
			st.x86_fp = fpIn[i]
			-- The outstanding pushed-register save stack at this instruction (or
			-- "dyn" when the paths disagree, or nil for unreachable code). Consumed
			-- by the rewrite: a stack access that aliases one of these save slots
			-- (a `pushq %rbx` inside the prologue pad that has not been popped yet)
			-- must not virtualize into a plain slot web — the slot's content is
			-- mirrored by the pushed register's web, because the matching pop (which
			-- the pairing analysis proves restores exactly this register) is dropped.
			st.x86_saves = savesIn[i]
			-- The prologue rsp-save map at this instruction: consumed by the rewrite
			-- to redirect entry-time reads of the incoming yolo stack arguments
			-- through an entry-rsp alias register (and to gate %rsp recoveries).
			st.x86_smap = smapIn[i]
			-- A `movq %rbx, %rsp` whose source register still holds an UNREDEFINED
			-- prologue rsp save in the converged smap at this point recovers a
			-- known-good stack pointer: the rewrite drops it and the transfer revived
			-- the depth to the saved value (even out of a dynamic-alloca "dyn" — the
			-- smap rides through the poison exactly like the save stack does). The
			-- alloca machinery's statements are excluded: they bypass the frame rewrite
			-- entirely (frame.preprocess routes them around it), so they must not
			-- double as recoveries. Anything else is rejected by the rewrite with a
			-- diagnostic naming the register.
			if isSpRecoverForm(st) and not (st.allocaPlace or st.allocaOwned or isAlloca(st)) then
				local e = smapIn[i] and smapIn[i][st.operands[2].name]
				-- any live carrier recovers (the recovery is dropped — no register
				-- clobber can be observed through it).
				if e and not e.redefined and not e.slot then
					st.x86_spRecover = true
				end
			end
			-- The lea recovery form (`leaq K(%reg), %rsp`, base not rbp): same proof as
			-- the mov form — the carrier's parked depth minus K is revived.
			if not (st.allocaPlace or st.allocaOwned or isAlloca(st))
				and x86.baseMnemonic(string.lower(st.mnemonic)) == "lea"
				and st.operands[1] and st.operands[1].kind == "reg" and st.operands[1].rc == "sp"
				and st.operands[2] and st.operands[2].kind == "mem"
				and st.operands[2].base and st.operands[2].base.kind == "reg"
				and st.operands[2].base.name ~= "rbp"
				and not st.operands[2].index and not st.operands[2].dispSym then
				local e = smapIn[i] and smapIn[i][st.operands[2].base.name]
				if e and not e.redefined and not e.slot
					and e.depth - (st.operands[2].dispVal or 0) >= 0 then
					st.x86_spRecover = true
				end
			end
			-- Phantom saved-rsp flow marks (see the smap comment in the fixpoint):
			-- save-stores and carrier-loads are dropped by the rewrite; a lea-save is
			-- dropped with the save; a restore load through a carrier is dropped like
			-- the epilogue pops (proven unobservable when the save was redefined).
			if depthIn[i] ~= nil and not (st.allocaPlace or st.allocaOwned or isAlloca(st)) then
				-- A recorded `movq %rsp, %reg` save carrier (the fixpoint's isSave,
				-- recomputed exactly): dropped by the rewrite anywhere it appears.
				if isSpSaveForm(st) and not isDynDepth(depthIn[i])
					and (x86.CALLEE_SAVED[st.operands[1].name] ~= nil or yoloCount > 0
						or (regions ~= nil and not regionOf(0, false)))
					and (st.x86_prologue or not (st.allocaPlace or st.allocaOwned)) then
					st.x86_spSave = true
				end
				local se = saveStoreOf(st, smapIn[i] or {}, depthIn[i])
				if se then st.x86_saveStore = true end
				if not se and carrierLoadOf(st, smapIn[i] or {}, depthIn[i]) then
					st.x86_carrierLoad = true
				end
				local rs = restoreLoadOf(st, smapIn[i], savesIn[i])
				if rs then
					if rs.redefined then
						if retIsGpr and st.operands[1].num == 0 then
							error("sarcasm: epilogue restore load into the integer return"
								.. " register cannot be modeled (the register was redefined"
								.. " after its save, so the restore's value and the web's"
								.. " value disagree): " .. (st.raw or st.mnemonic))
						end
						checkLostReload(i, rs,
							"epilogue restore load of a save whose register was redefined"
								.. " after the push (the load cannot be modeled — the slot"
								.. " holds the pre-push value while the register's web holds"
								.. " the redefined one — and this read would observe the"
								.. " web's value)")
					end
					st.x86_dropRestore = true
				end
				-- The general lea-save (`leaq d(%rsp), %reg` parking the entry stack
				-- pointer in a carrier): mark it for the rewrite's drop. The condition
				-- mirrors the fixpoint's isLeaSave computation exactly — including the
				-- +8 rule for clone statements (K = d + 8 parks the entry rsp).
				if regions ~= nil and not isDynDepth(depthIn[i])
					and x86.baseMnemonic(string.lower(st.mnemonic)) == "lea" then
					local ops = st.operands
					local mem = ops[2]
					if ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr"
						and ops[1].name ~= "rbp"
						and mem and mem.kind == "mem" and mem.base and mem.base.rc == "sp"
						and not mem.index and not mem.dispSym then
						local k = mem.dispVal or 0
						local pk = st.localClone and (k - 8) or k
						local rkey = st.localClone and (k + D0 - depthIn[i] - 8) or k
						if pk == depthIn[i] and not regionOf(rkey, false)
							and not (yoloCount > 0 and k == 0) then
							st.x86_leaSave = true
						end
					end
				end
			end
			-- A return reads the integer return register: if %rax still carries the
			-- saved stack pointer at a `ret`, the RETURN VALUE would be the live stack
			-- address — the one carrier read that is never droppable. Reject it.
			-- (A local subroutine's ret is exempt: it does not produce this function's
			-- Fil-C return value — a carrier %rax flowing to the continuation is the
			-- caller's phantom recovery working as intended. A cross-function-jump
			-- synthetic epilogue ret (st.tailRet — tailcall.luau) is exempt the same
			-- way: its return value is the tail-called callee's result, defined by
			-- the call, never the saved stack pointer.)
			if x86.baseMnemonic(string.lower(st.mnemonic)) == "ret" and not st.localRet
				and not st.tailRet and retIsGpr and smapIn[i] then
				local e = smapIn[i]["rax"]
				if e and not e.redefined and not e.slot then
					error("sarcasm: returning while %rax holds the saved stack pointer cannot"
						.. " be proven safe (the return value would be the live stack"
						.. " address; redefine %rax or recover %rsp from it first): "
						.. (st.raw or st.mnemonic))
				end
			end
			-- A pop provably restores a matching save only when the incoming abstract save
			-- stack shows the LAST outstanding push as the same register at the same slot
			-- depth on every path. Anything else (no outstanding push, a different register
			-- on top, an unprovable stack) loads a slot that is not that register's save.
			-- At an UNKNOWN depth (dynamic-alloca poison) the slot position cannot be
			-- checked; there the pop pairs off the outstanding save stack only inside a
			-- VERIFIED epilogue teardown (validateTeardown above: a straight path to a
			-- `ret` through callee-saved pops and frame-touch-free computation). Every
			-- statement in such a span is dropped and the synthesized epilogue owns the
			-- real %rsp, so the pairing only has to prove that the pop restores the same
			-- register a dropped push saved — the slot it reads is never emitted.
			if x86.baseMnemonic(string.lower(st.mnemonic)) == "pop" and depthIn[i] ~= nil then
				local sv, d = savesIn[i], depthIn[i]
				local n = (st.operands[1] and st.operands[1].kind == "reg")
					and st.operands[1].name or "?"
				if not isDynDepth(d) then
					if sv == "dyn" or #sv == 0
						or sv[#sv].name ~= n or sv[#sv].depth ~= d then
						st.x86_unpairedPop = true
					elseif sv[#sv].redefined then
						checkLostReload(i, sv[#sv])
					end
				elseif st.x86_teardown and sv ~= "dyn" and #sv > 0 and sv[#sv].name == n then
					if sv[#sv].redefined then
						checkLostReload(i, sv[#sv])
					end
				else
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
					or (b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2]
						and ops[2].kind == "mem" and ops[2].base and ops[2].base.name == "rbp"
						and usesRbp and not ops[2].index and not ops[2].dispSym)
					or (b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2]
						and ops[2].kind == "mem" and ops[2].base and ops[2].base.rc == "sp"
						and not ops[2].index and not ops[2].dispSym
						and (ops[2].dispVal or 0) >= 0)
					or (b == "leave" and usesRbp)
				if isTeardownStart then
					local marks = validateTeardown(nextInsn[i])
					if marks then
						st.x86_teardownStart = true
						for _, j in marks do body[j].x86_teardown = true end
					end
				end
				-- A constant mid-function rsp DECREASE (`addq $imm, %rsp`) that is not
				-- a verified epilogue teardown: sound to drop when the resulting
				-- depth is statically known and stays non-negative (every later
				-- slot access keys off the depth exactly, pops stay
				-- save-pairing-gated, returns stay depth-0-gated) AND the flags the
				-- add clobbers are provably dead — nothing reads them before a full
				-- flag write on any path. (The ecp_nistz256_point_add shape:
				-- `addq $416, %rsp` reshaping the frame into a sibling's smaller
				-- one ahead of a shared-tail join.)
				if b == "add" and ops[1] and ops[1].rc == "sp"
					and ops[2] and ops[2].kind == "imm" and not st.x86_teardownStart then
					local imm = immVal(ops[2])
					if type(depthIn[i]) == "number" and depthIn[i] - imm >= 0
						and flagsDeadAfter(i) then
						st.x86_midAdd = true
					end
				end
			end
		end
	end

	-- Epilogue movq-restore loads (the perlasm shape: `movq (%rsp), %r15; movq
	-- 8(%rsp), %r14; ...; addq $K, %rsp; ret`). The save-slot model rewrites a
	-- load from a pushed register's save slot to a read of that register's web
	-- — but when the register was REDEFINED after the push (perlasm uses the
	-- saved registers as scratch inside the body), that web holds the redefined
	-- value while the hardware slot holds the pre-push one, so the model cannot
	-- express the load and the rewrite rejects it. Yet the load's result is dead
	-- weight whenever the register is never read afterwards (the standard
	-- epilogue reads nothing but the return registers before `ret`) — exactly
	-- the situation checkLostReload proves for pops. Detect those loads here
	-- (EXACTLY the rewrite's save-slot alias computation), prove unobservability
	-- with the same forward walk, and mark them x86_dropRestore: the rewrite
	-- then drops them like the pops it already drops. A restore into the
	-- integer return register can never be proven unobservable (the frame
	-- analysis does not model `ret`'s operand read), so it stays rejected.
	for i, st in body do
		if st.kind ~= "insn" then continue end
		local ops = st.operands
		local b = x86.baseMnemonic(string.lower(st.mnemonic))
		if b ~= "mov" or not (ops[1] and ops[1].kind == "reg" and ops[1].rc == "gpr") then continue end
		local mem = ops[2]
		if not (mem and mem.kind == "mem" and not mem.index and not mem.dispSym) then continue end
		if not (mem.base and (mem.base.rc == "sp" or (usesRbp and mem.base.name == "rbp"))) then continue end
		if gprStackWidth(string.lower(st.mnemonic), mem) ~= 8 then continue end
		local sv = st.x86_saves
		if not (sv and sv ~= "dyn" and #sv > 0) then continue end
		local off = (mem.dispVal or 0)
		if mem.base.rc == "sp" then
			-- EXACTLY the rewrite's normalization: at a KNOWN perturbed depth (the
			-- early-ret-then-frame shape) the slot sits at disp + D0 - d in frame
			-- coordinates. At an UNKNOWN ("dyn") rsp depth the raw offset is NOT
			-- the slot's frame coordinate — the perturbed rsp points who-knows-where
			-- (an alloca region, a disagreeing merge) — so the load can never be a
			-- proven restore-load here. (The perlasm epilogue-restore shape this
			-- pass exists for runs at a STATIC depth.)
			local d = st.x86_depth
			if d == nil or isDynDepth(d) then continue end
			off = off + D0 - d
		else
			off = frameSize + off
		end
		local hit = nil
		for _, s in sv do
			if not (usesRbp and s.name == "rbp") then
				if off == D0 - s.depth and s.redefined then hit = s break end
			end
		end
		if not hit then continue end
		if retIsGpr and ops[1].num == 0 then
			error("sarcasm: epilogue restore load into the integer return register"
				.. " cannot be modeled (the register was redefined after its save,"
				.. " so the restore's value and the web's value disagree): "
				.. (st.raw or st.mnemonic))
		end
		checkLostReload(i, { name = ops[1].name, num = ops[1].num },
			"epilogue restore load of a save whose register was redefined after the"
				.. " push (the load cannot be modeled — the slot holds the pre-push"
				.. " value while the register's web holds the redefined one — and"
				.. " this read would observe the web's value)")
		st.x86_dropRestore = true
	end

	-- FP/SIMD stack-slot taint scan. FP/vector instructions cannot ride the GPR slot
	-- virtualization (their operands are real vector registers, not temps — the slot
	-- pseudo-register would render as garbage), so every stack range an FP
	-- instruction touches is MATERIALIZED: the instruction is kept and its memory
	-- operand is rewritten to a real disp(%rsp) into a reserved region of sarcasm's
	-- synthesized frame (see rewrite). GPR accesses overlapping an FP-touched range
	-- are materialized too (aliasing: the overlapped bytes must have exactly one
	-- home). This scan computes the tainted clusters and assigns their synthesized
	-- offsets; rewrite's fpInfo.lookup(off, w) then maps each materialized access
	-- to its final offset.
	local intervals = {}
	for _, st in body do
		if st.kind == "insn" and not (isAlloca(st) or st.allocaPlace or st.allocaOwned) then
			-- alloca machinery owns its accesses
			local mem
			for _, o in (st.operands or {}) do if o.kind == "mem" then mem = o end end
			-- Mirror exactly the rewrite's stack-mem gate: stack base, no symbolic
			-- displacement, no index register (the rewrite rejects those cleanly).
			-- Heap/global accesses are irrelevant here. An entry-time read of an
			-- incoming yolo stack argument (a depth-0 %rsp read) is irrelevant too:
			-- it is redirected to the arguments' own materialized area, not to an
			-- FP cluster.
			if mem and isStackReg(mem.base, usesRbp) and not mem.dispSym and not mem.index
				and not (mem.base.rc == "sp" and st.x86_depth ~= nil and not isDynDepth(st.x86_depth)
					and yoloArgSlotOf(st, "rsp", st.x86_depth))
				-- Phantom saved-rsp traffic (save-stores / carrier-loads) is dropped by
				-- the rewrite — no real memory exists for it — and an access landing
				-- in a fixed alloca region rides the region pointer instead of a
				-- frame slot (region coordinates never collide with cluster offsets).
				and not st.x86_saveStore and not st.x86_carrierLoad then
				local m = string.lower(st.mnemonic)
				local fpe = fp.lookup(m)
				-- Region membership in the rewrite's exact coordinates/classification.
				local rOff = (mem.dispVal or 0)
				if mem.base.rc ~= "sp" then rOff = frameSize + rOff end
				local rDyn = mem.base.rc == "sp" and not st.x86_prologue and type(st.x86_depth) == "table"
				if not (fpe and fpe.noCheck) and not regionOf(rOff, rDyn) then  -- prefetch: memory-neutral, needs no slot
					-- Normalized rsp-relative frame offset: EXACTLY the rewrite's formula.
					local off = (mem.dispVal or 0)
					if mem.base.rc ~= "sp" then off = frameSize + off end
					local isFP = isFpInsn(fpe, st)
					local w, areq = nil, 1
					if isFP then
						-- The knowledge module's width is AUTHORITATIVE for FP/SIMD
						-- (broadcast decorators, ISA-fixed vector widths, and the
						-- size-driven x87/PTR forms all resolved inside); a raw
						-- Intel mem.size must never under-size the slot, and
						-- accessWidth cleanly rejects a contradicting PTR
						-- annotation. nil: the rewrite produces the clean error.
						local fw, fa = fp.accessWidth(m, st.operands, st.raw)
						w = fw
						if fa and fa > 1 then areq = math.min(fa, 16) end  -- cap at 16
					else
						w = gprStackWidth(m, mem)
					end
					if w then
						table.insert(intervals, { lo = off, hi = off + w, fp = isFP, areq = areq })
					end
				end
			end
		end
	end
	-- Sweep-merge strictly-overlapping intervals into clusters; a cluster is TAINTED
	-- iff any member is an FP access (this is the aliasing guarantee: a GPR range
	-- overlapping an FP range joins the cluster and is materialized with it).
	table.sort(intervals, function(x, y) return x.lo < y.lo end)
	local tainted = {}
	do
		local cur = nil
		for _, iv in intervals do
			if cur and iv.lo < cur.hi then
				if iv.hi > cur.hi then cur.hi = iv.hi end
				if iv.fp then cur.fp = true end
				if iv.areq > cur.areq then cur.areq = iv.areq end
			else
				cur = { lo = iv.lo, hi = iv.hi, fp = iv.fp, areq = iv.areq }
				table.insert(tainted, cur)
			end
		end
		-- drop untainted clusters
		for i = #tainted, 1, -1 do
			if not tainted[i].fp then table.remove(tainted, i) end
		end
	end

	-- Widest xmm-class operand width/8 anywhere in the function (16/32/64): sizes
	-- the reserved vector-save area above the materialized clusters.
	local vecBytes = nil
	for _, st in body do
		if st.kind == "insn" then
			local vb = fp.widestVecBytes(st.operands or {})
			if vb and (not vecBytes or vb > vecBytes) then vecBytes = vb end
		end
	end
	-- Force the reservation from an FP entry signature alone (see the sigHasFp
	-- comment above): 16 bytes per xmm0..xmm15 slot, exactly VEC_SAVE_BYTES below.
	-- A body that already touches vector registers reserves at least this much on
	-- its own (a ymm/zmm body reserves 32/64-byte slots).
	if not vecBytes and sigHasFp then vecBytes = 16 end
	local saveBytes = vecBytes and 16 * vecBytes or 0
	local base0 = 16 + saveBytes
	local cursor = base0
	for _, c in tainted do
		local areq = math.max(c.areq, 1)
		-- The synthesized offset must preserve every input-guaranteed alignment. An
		-- input access with normalized offset off has address entry_rsp - D0 + off,
		-- and entry_rsp ≡ 8 (mod 16) (SysV: rsp+8 is 16-aligned at the call), so an
		-- input access aligned to areq (areq ≤ 16) has off ≡ D0 - 8 (mod areq) —
		-- the SAME identity for rsp-relative and normalized rbp-relative offsets.
		-- The output address is body_rsp + finalBase + (off - c.lo) with body_rsp
		-- ≡ 0 (mod 16) (computeLayout), so finalBase ≡ c.lo - (D0 - 8) (mod areq)
		-- maps every input-aligned access to an output-aligned address.
		local residue = ((c.lo - D0 + 8) % areq + areq) % areq
		local delta = ((residue - cursor % areq) % areq + areq) % areq
		c.finalBase = cursor + delta
		cursor = c.finalBase + (c.hi - c.lo)
	end
	local fpBytes = cursor - base0

	-- Incoming yolo stack-argument FP/vector reads: scan for FP-class instructions
	-- whose entry-time read maps to a yolo slot (EXACTLY the rewrite's detection:
	-- a depth-0 %rsp read, or a read through an entry-rsp alias the smap proves
	-- unredefined). When any exist, reserve the materialized area AFTER the clusters,
	-- 16-aligned (the shift past the GC root area is always a multiple of 16 — see
	-- transform.luau / computeLayout — so a mod-16 base here keeps the input's
	-- movaps-class alignment of the entry_rsp+8 word pairs: entry_rsp ≡ 8 (mod 16),
	-- hence slot pair starts ≡ 0). GPR reads of the same slots ride the virtual slot
	-- webs instead; the area is initialized by the transform's entry unpack, so both
	-- views always agree (it is read-only afterwards — stores stay rejected).
	local fpYolo = {}
	local hasFpYolo = false
	if yoloCount > 0 then
		for _, st in body do
			if st.kind == "insn" and not (isAlloca(st) or st.allocaPlace or st.allocaOwned) then
				local mem
				for _, o in (st.operands or {}) do if o.kind == "mem" then mem = o end end
				local i = nil
				if mem and mem.base then
					if mem.base.rc == "sp" and st.x86_depth ~= nil and not isDynDepth(st.x86_depth) then
						i = yoloArgSlotOf(st, "rsp", st.x86_depth)
					elseif st.x86_smap then
						local e = st.x86_smap[mem.base.name]
						if e and not e.redefined then i = yoloArgSlotOf(st, mem.base.name, e.depth) end
					end
				end
				if i then
					local fpe = fp.lookup(string.lower(st.mnemonic))
					if isFpInsn(fpe, st) then
						-- mark every slot the access can touch: a wider-than-8-byte
						-- read (movaps/movups/vmovdqu...) spans consecutive slots —
						-- the entry unpack must fill them all.
						local w = fp.accessWidth(string.lower(st.mnemonic), st.operands, st.raw) or 8
						local last = math.min(yoloCount - 1, i + math.ceil(w / 8) - 1)
						for j = i, last do fpYolo[j] = true end
						hasFpYolo = true
					end
				end
			end
		end
	end
	local yoloBytes = 0
	if hasFpYolo then
		yoloBase = math.ceil(cursor / 16) * 16
		yoloBytes = 8 * yoloCount
	end

	local fpInfo = {
		clusters = tainted,
		bytes = fpBytes,
		saveBytes = saveBytes,
		vecBytes = vecBytes,
		-- finalOff for a materialized access, or nil when it hits no tainted cluster.
		lookup = function(off, w)
			for _, c in tainted do
				if off >= c.lo and off + w <= c.hi then
					return c.finalBase + (off - c.lo)
				end
			end
			return nil
		end,
	}
	-- 5th return: the incoming yolo stack-argument info for the transform (slot
	-- count, which slots FP instructions read, the materialized area's base offset
	-- and byte size — base is nil when no FP instruction reads one).
	return frameSize, 0, usesRbp, fpInfo,
		{ count = yoloCount, fpRead = fpYolo, base = yoloBase, bytes = yoloBytes }
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

	-- A stack-register name that did not parse as a REGISTER: in an AT&T-parsed file
	-- a bare (un-%-ed) operand field falls through to the symbol parse, so a
	-- dest-first Intel spelling inside an AT&T file (`lea rsp, [rax+15]`) parses as
	-- a symbol source over a non-register destination. Every other mnemonic treats
	-- a symbol operand as memory and is rejected as global data access, but a lea's
	-- symbol operands are address materializations — so the model here sees neither
	-- a %rsp write nor a memory access: the rsp-write enforcement, the depth
	-- analysis, and the escape scan all pass, and the statement is emitted
	-- VERBATIM — a live hardware-%rsp write wherever the text assembles, and a bare
	-- `as` "operand type mismatch" (no sarcasm diagnostic) where it does not. A lea
	-- whose destination is not a register never assembles anyway (GAS lea computes
	-- into a register), so gating on that keeps every assemblable lea (including
	-- `leaq myglobal, %rax` address materializations) working while any
	-- stack-register name hiding in the operands of the malformed spelling — an
	-- unmodeled %rsp write, whatever operand carries it — is rejected with the
	-- stack-pointer-write error. (The prologue prefix scan treats such a statement
	-- as transparent, but the rewrite runs on prologue statements too, so this
	-- rejection covers the prefix as well.)
	if b == "lea" and not (ops[1] and ops[1].kind == "reg") then
		for _, o in ops do
			if o.kind == "sym" then
				local t = string.gsub(string.lower(o.text or ""), "^%%", "")
				t = string.gsub(string.gsub(t, "^%[", ""), "%]$", "")
				if string.match(t, "^[re]?[sb]p%f[^%w]") then
					error("sarcasm: writing the stack pointer through an operand that parsed"
						.. " as a symbol rather than a register (mixed AT&T/Intel operand"
						.. " syntax) cannot be proven safe: " .. (st.raw or m))
				end
			end
		end
	end

	-- Vector-indexed memory (gather/scatter: an xmm-class register as the memory base
	-- or index) touches multiple discrete addresses that cannot be bounds-checked.
	-- Reject it cleanly. (The x86_64_fp table also hard-rejects the gather/scatter
	-- mnemonics; this catches any vector-indexed form regardless of mnemonic.)
	for _, o in ops do
		if o.kind == "mem"
			and ((o.base and o.base.rc == "xmm") or (o.index and o.index.rc == "xmm")) then
			error("sarcasm: vector-indexed memory access (gather/scatter) is not supported"
				.. " (cannot prove memory safety): " .. (st.raw or m))
		end
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
			-- `leave` is an epilogue teardown only when the teardown analysis proved that
			-- it STARTS (or sits inside) a region leading straight to a `ret` through
			-- callee-saved pops and frame-touch-free computation, with the frame pointer
			-- provably established on entry. Any other `leave` is a MID-FUNCTION one and
			-- stays rejected even though the plain rsp-recovery forms (`movq %rbp, %rsp`,
			-- `leaq -N(%rbp), %rsp`) are now accepted mid-function: hardware `leave` also
			-- restores the CALLER's frame pointer into %rbp, breaking the static-frame-
			-- pointer premise every later rbp-relative virtualization rests on — silently
			-- miscompiled reads and writes. The plain recoveries touch only %rsp, which
			-- is why they can be dropped anywhere.
			if not (st.x86_teardownStart or st.x86_teardown) or st.x86_fp ~= "est" then
				error("sarcasm: mid-function `leave` cannot be proven safe (a leave that does"
					.. " not lead directly to a ret may observe the caller's frame): "
					.. (st.raw or m))
			end
			return
		end
		if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp" then
			if b == "add" and ops[2] and ops[2].kind == "imm"
				and (st.x86_teardownStart or st.x86_midAdd) then
				return  -- verified epilogue teardown / proven mid-function decrease: drop
			end
			error("sarcasm: mid-function stack-pointer adjustment cannot be proven safe"
				.. " (frame teardown must be an epilogue `addq $imm, %rsp` leading to `ret`;"
				.. " dynamic allocation must use `alloca`): " .. (st.raw or m))
		end
		if b == "mov" and ops[1] and ops[1].name == "rbp" and ops[2] and ops[2].rc == "sp" then
			error("sarcasm: establishing %rbp as a frame pointer outside the prologue cannot"
				.. " be proven safe: " .. (st.raw or m))
		end
		if b == "mov" and ops[1] and ops[1].rc == "sp" then
			if ops[2] and ops[2].name == "rbp" then
				-- Recovering %rsp from the frame pointer is sound wherever the frame
				-- pointer is provably established, and is DROPPED: the recovery cannot
				-- perturb any rbp-relative virtualization (rbp is untouched), every
				-- rsp-relative access stays gated on the revived depth, every pop stays
				-- gated on save pairing, and every return stays gated on depth 0. This
				-- accepts mid-function alloca "frees" as readily as the classic epilogue
				-- teardown — no straight-line-to-ret proof is required.
				if st.x86_fp == "est" then return end
				error("sarcasm: restoring %rsp from %rbp while the frame pointer is not"
					.. " provably established cannot be proven safe: " .. (st.raw or m))
			end
			if st.x86_spRecover then
				-- Recovery from a register the prologue saved %rsp into: the value is
				-- fixed at function entry (the fixpoint proved the save still reaches
				-- this point unredefined), so dropping the write is exactly as sound as
				-- dropping the rbp forms.
				return
			end
			local rn = (ops[2] and ops[2].name) and "%" .. ops[2].name or "a register"
			error("sarcasm: restoring %rsp from " .. rn .. " requires a prologue"
				.. " `movq %rsp, " .. rn .. "` that has not been redefined (or recover it"
				.. " from %rbp, or use an `alloca` annotation): "
				.. (st.raw or m))
		end
		if b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "mem"
			and ops[2].base and ops[2].base.name == "rbp" and usesRbp
			and not ops[2].index and not ops[2].dispSym then
			-- Same proof as the movq form: a frame-pointer-relative rsp recovery, dropped.
			if st.x86_fp == "est" then return end
			error("sarcasm: restoring %rsp from %rbp via lea while the frame pointer is not"
				.. " provably established cannot be proven safe: " .. (st.raw or m))
		end
		if b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "mem"
			and not ops[2].index and not ops[2].dispSym then
			if ops[2].base and ops[2].base.rc == "sp" then
				-- `leaq +N(%rsp), %rsp`: the lea spelling of the constant epilogue
				-- teardown — accepted exactly like `addq $imm, %rsp` when the teardown
				-- analysis verified the span; anything else is a mid-function
				-- stack-pointer adjustment.
				if (ops[2].dispVal or 0) >= 0 and st.x86_teardownStart then return end
				error("sarcasm: mid-function stack-pointer adjustment cannot be proven safe"
					.. " (frame teardown must be an epilogue `addq $imm, %rsp` /"
					.. " `leaq $imm(%rsp), %rsp` leading to `ret`; dynamic allocation must"
					.. " use `alloca`): " .. (st.raw or m))
			end
			if ops[2].base and ops[2].base.kind == "reg" and ops[2].base.name ~= "rbp" then
				-- `leaq K(%reg), %rsp`: recovery from a saved-rsp carrier (the analysis
				-- proved the base register holds the save value); dropped with it.
				if st.x86_spRecover then return end
				local rn = "%" .. ops[2].base.name
				error("sarcasm: restoring %rsp from " .. rn .. " requires a prologue"
					.. " `movq %rsp, " .. rn .. "` (or lea) save that has not been redefined"
					.. " (or recover it from %rbp, or use an `alloca` annotation): "
					.. (st.raw or m))
			end
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
		-- A return at an UNKNOWN depth is accepted only inside a verified epilogue
		-- teardown (x86_teardown: everything in the span is dropped and the synthesized
		-- epilogue owns the real %rsp — see the pop pairing above); anywhere else a
		-- return must provably sit at the entry rsp.
		-- A local subroutine's ret (st.localRet) is exempt: it is not a return — the
		-- no-push clone executes at the caller's depth and branches to the
		-- continuation, which resumes at exactly that depth. A cross-function-jump
		-- synthetic epilogue ret (st.tailRet — tailcall.luau) is exempt too: it sits
		-- at the tail branch's (arbitrary) virtual depth, but the body's stack is
		-- virtual, so the synthesized epilogue — which owns the real %rsp — tears
		-- the frame down correctly regardless.
		if b == "ret" and not st.localRet and not st.tailRet and d ~= nil and d ~= 0
			and not (isDynDepth(d) and st.x86_teardown) then
			error("sarcasm: return with a perturbed or unknown stack pointer cannot be proven"
				.. " safe: " .. (st.raw or m))
		end
		if b == "jmp" and d ~= nil and d ~= 0 and not (ops[1] and ops[1].kind == "sym") then
			error("sarcasm: indirect tail jump with a perturbed or unknown stack pointer"
				.. " cannot be proven safe: " .. (st.raw or m))
		end
	end

	-- drop CET marker and frame setup/teardown
	if b == "nop" then
		if m == "endbr64" then return end
		-- nop/nopw/nopl padding: zero-effect passthrough. Their operand (when
		-- present — `nopw 0x0(%rax,%rax,1)`) is a dummy encoding hint, NOT a memory
		-- access, so it must not ride the slot-virtualization / bounds-check
		-- machinery below: a virtualized slot would render a random web's register
		-- into the padding encoding, and a dummy (%rsp) operand would be treated as
		-- a real frame access.
		emit(st)
		return
	end
	-- (A `leave` is never prologue-transparent — the prologue prefix scan above ends at
	-- one — and every post-prologue `leave` is handled by the enforcement block above, so
	-- this legacy drop cannot be reached for it. It stays consistent with that block so a
	-- future prologue-scan change cannot silently drop an unproven `leave` here. The same
	-- holds for the %rsp-recovery forms below: the prologue scan ends at any rsp write,
	-- so they too are always handled — and gated on the frame-pointer state — above.)
	if b == "leave" then
		if not (st.x86_teardownStart or st.x86_teardown) or st.x86_fp ~= "est" then
			error("sarcasm: mid-function `leave` cannot be proven safe (a leave that does"
				.. " not lead directly to a ret may observe the caller's frame): "
				.. (st.raw or m))
		end
		return
	end
	if (b == "sub" or b == "add") and ops[1] and ops[1].rc == "sp" then return end
	-- `leaq -N(%rsp), %rsp` prologue allocation / `leaq +N(%rsp), %rsp` teardown (the
	-- lea spellings; post-prologue ones were handled — and gated — above).
	if b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "mem"
		and ops[2].base and ops[2].base.rc == "sp" and not ops[2].index and not ops[2].dispSym then
		if st.x86_prologue then return end
		if (ops[2].dispVal or 0) >= 0 and st.x86_teardownStart then return end
		error("sarcasm: mid-function stack-pointer adjustment cannot be proven safe"
			.. " (frame teardown must be an epilogue `addq $imm, %rsp` / `leaq $imm(%rsp),"
			.. " %rsp` leading to `ret`; dynamic allocation must use `alloca`): "
			.. (st.raw or m))
	end
	if b == "mov" and ops[1] and ops[1].name == "rbp" and ops[2] and ops[2].rc == "sp" then return end
	if b == "mov" and ops[1] and ops[1].rc == "sp" then
		if (ops[2] and ops[2].name == "rbp" and st.x86_fp == "est") or st.x86_spRecover then
			return
		end
		local rn = (ops[2] and ops[2].name) and "%" .. ops[2].name or "a register"
		error("sarcasm: restoring %rsp from " .. rn .. " requires a prologue"
			.. " `movq %rsp, " .. rn .. "` that has not been redefined (or recover it"
			.. " from %rbp, or use an `alloca` annotation): "
			.. (st.raw or m))
	end
	if b == "lea" and ops[1] and ops[1].rc == "sp" and ops[2] and ops[2].kind == "mem"
		and ops[2].base and ops[2].base.name == "rbp" and usesRbp
		and not ops[2].index and not ops[2].dispSym then
		if st.x86_fp == "est" then return end
		error("sarcasm: restoring %rsp from %rbp via lea while the frame pointer is not"
			.. " provably established cannot be proven safe: " .. (st.raw or m))
	end

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

	-- Emit the rewrite of an entry-time read of incoming yolo stack-argument slot i
	-- (yoloArgSlotOf already proved the shape: a load-like instruction, plain
	-- base+disp memory operand). GPR-class reads ride a virtual slot web — the
	-- transform seeds it from the incoming fast-CC argument word (with its
	-- capability lower for a pointer argument, so pointer flow propagates exactly
	-- like a register argument). FP/vector-class reads cannot name a GPR
	-- pseudo-register, so they materialize into the reserved area the transform
	-- fills with the same incoming words (see analyzeFrame).
	local function emitYoloRead(i)
		-- The `;! ... ptr` annotation family operates on REAL memory (invisicap
		-- loads/stores/RMWs); the argument slot is virtualized/materialized, not
		-- real memory, so the annotation can never be honored here — reject it
		-- exactly like an annotated ordinary frame-slot access.
		if st.annotation and sig.PTR_ANNOTATIONS[st.annotation] then
			error("sarcasm: `" .. st.annotation .. "` on an incoming stack-argument read is not"
				.. " supported (the argument is redirected to a frame slot, not real memory): "
				.. (st.raw or m))
		end
		if st.lockPrefix then
			error("sarcasm: lock prefix on an incoming stack-argument read is not supported"
				.. " (the argument is redirected to a thread-confined frame slot): " .. (st.raw or m))
		end
		for _, o in ops do
			if o.deco and string.match(o.deco, "{%%?k[0-7]}") then
				error("sarcasm: AVX512 mask-register ({k}) incoming stack-argument reads are not"
					.. " supported (masked-off lanes may not touch memory; cannot prove memory"
					.. " safety): " .. (st.raw or m))
			end
		end
		local mem
		for _, o in ops do if o.kind == "mem" then mem = o end end
		local fpEntry = fp.lookup(m)
		if isFpInsn(fpEntry, st) then
			-- FP/vector read: materialize into the reserved area (analyzeFrame
			-- assigned yoloBase precisely because this read exists). The width is
			-- the knowledge module's authoritative one (it rejects a contradicting
			-- PTR annotation); aligned >16-byte forms are rejected like anywhere.
			local wb, fa = fp.accessWidth(m, ops, st.raw)
			if not wb then
				error("sarcasm: cannot determine the memory access width of '" .. m
					.. "' (cannot prove memory safety): " .. (st.raw or m))
			end
			if fa and fa > 16 then
				error("sarcasm: aligned 32/64-byte incoming stack-argument reads are not supported"
					.. " (the stack is only guaranteed 16-byte aligned); use the unaligned form: "
					.. (st.raw or m))
			end
			local mat = { kind = "mem",
				base = { kind = "reg", rc = "sp", num = 4, width = 64, name = "rsp" },
				scale = 1, dispVal = yoloBase + 8 * i, size = wb, frameSlot = true,
				deco = mem.deco, bcastN = mem.bcastN }
			local newops = {}
			for _, o in ops do table.insert(newops, (o == mem) and mat or o) end
			emit({ kind = "insn", mnemonic = st.mnemonic, operands = newops,
				raw = st.raw, line = st.line, annotation = st.annotation })
			return
		end
		-- GPR read: a virtual slot web, keyed by slot index (shared across widths,
		-- exactly like the ordinary frame-slot virtualization).
		local wb = gprStackWidth(m, mem)
		local slot = frameShared.yoloSlotReg(i, wb * 8)
		local newops = {}
		for _, o in ops do table.insert(newops, (o == mem) and slot or o) end
		emit({ kind = "insn", mnemonic = st.mnemonic, operands = newops,
			raw = st.raw, line = st.line, annotation = st.annotation })
	end

	-- Memory access THROUGH a saved-rsp carrier register. Three legal shapes:
	--   * an entry-time read of an incoming yolo stack argument through an entry-rsp
	--     alias (`movq %rsp, %rax` / `leaq 0(%rsp), %rax`, then `8(%rax)` — the
	--     aesni_ocb / bn_mul_mont_gather5 prologue shape): the smap proves the
	--     register still holds the parked stack pointer on every path; redirect the
	--     read to the argument's slot;
	--   * an epilogue restore load through the carrier (the perlasm movq-restore
	--     riding the recovered pointer, `movq -48(%rsi), %r15`): the analysis proved
	--     it a save/restore pair (and unobservable when the save was redefined) and
	--     marked it x86_dropRestore — dropped like the epilogue pops;
	--   * anything else is the same escape class as reading the saved stack pointer
	--     itself (the transfer's use-check rejects those first — this is the
	--     defensive mirror).
	-- Phantom saved-rsp flow: save-stores and carrier-loads are DROPPED, whatever
	-- base spelling carries the slot (a stack base below, or a region-pointer-
	-- derived register — the wp `movq %rax, 32(%r10)`): the value is phantom —
	-- sarcasm owns the real frame — so no real memory exists for it (the analysis
	-- proved the flow and marked the statements).
	if st.x86_saveStore or st.x86_carrierLoad then return end
	if mem and mem.base and not isStackReg(mem.base, usesRbp) and not mem.index and not mem.dispSym then
		local e = st.x86_smap and st.x86_smap[mem.base.name]
		if e and not e.redefined and not e.slot and not e.roff then
			if st.x86_dropRestore then return end
			local i = yoloArgSlotOf(st, mem.base.name, e.depth)
			if not i then
				error("sarcasm: memory access through the saved stack pointer that is not"
					.. " an incoming stack-argument read or a saved-register restore cannot"
					.. " be proven safe: " .. (st.raw or m))
			end
			emitYoloRead(i)
			return
		end
	end

	if mem and isStackReg(mem.base, usesRbp) and not mem.dispSym then
		-- A `lock` prefix on a stack-frame access can never be honored: this rewrite
		-- runs BEFORE classify (which owns the lockAllows validation), and the slot
		-- is about to be virtualized into a pseudo-register or materialized into the
		-- thread-confined synthesized frame — either way the emitted instruction
		-- would silently lose the prefix (a locked memory RMW degenerating into an
		-- unlocked register operation, e.g. `lock addq $1, -8(%rbp)`), or carry a
		-- meaningless prefix on thread-confined memory. Reject it, mirroring the
		-- classify rejection of `lock` on everything but the modeled heap mem-RMWs.
		if st.lockPrefix then
			error("sarcasm: lock prefix on a stack-frame access is not supported (frame"
				.. " slots are thread-confined — virtualized or materialized — so `lock`"
				.. " there is meaningless; it is only allowed on the modeled"
				.. " memory-destination RMWs on real memory): " .. (st.raw or m))
		end
		-- A stack memory operand carrying an AVX512 {kN} mask decorator. On HEAP
		-- accesses the supported masked forms (vector moves, truncating stores,
		-- expand/compress) now get a mask-aware bounds check from the transform
		-- (fp.maskedAccessInfo), but on a STACK slot the frame rewrite runs FIRST
		-- and would virtualize/materialize the operand: a virtualized slot is a
		-- pseudo-register the masked vector instruction cannot take, and a
		-- materialized slot would need the mask-aware lane structure accounted
		-- for in the cluster sizing. Neither is modeled, so reject all {k}-masked
		-- stack accesses, like the unsupported masked heap forms.
		for _, o in ops do
			if o.deco and string.match(o.deco, "{%%?k[0-7]}") then
				error("sarcasm: AVX512 mask-register ({k}) stack-frame memory accesses are not"
					.. " supported (masked-off lanes may not touch memory; use an unmasked or"
					.. " heap form; cannot prove memory safety): "
					.. (st.raw or m))
			end
		end
		-- Memory-neutral hints (prefetch*) need no bounds check and no slot: the real
		-- stack address is always safe to hint at (a prefetch can never fault).
		local fpEntry = fp.lookup(m)
		if fpEntry and fpEntry.noCheck then emit(st); return end
		-- Region membership is a static fact even at a perturbed/"dyn" depth, so the
		-- region lookup runs FIRST: an access landing in a fixed alloca region passes
		-- through for the transform's region redirect (a region-pointer-relative
		-- checked access), whatever the depth. The lookup rides the access's own
		-- coordinate space: inside an {anchored} region scope (the depth is the
		-- region's table — raw displacements are that region's coordinates); plain
		-- "dyn" has NO valid coordinates (a later rsp write moved the base); and
		-- everything else matches the static regions in normalized frame coordinates
		-- (rbp-relative offsets are static at any depth). A CLONE statement's
		-- rsp-relative displacement at a static depth keys with the +8 rule (the
		-- return-address compensation: hardware has the pushed return address
		-- between the clone's rsp and the caller's frame — localcall.luau).
		local region = nil
		local rOff = (mem.dispVal or 0)
		if mem.base.rc ~= "sp" then rOff = ctx.frameSize + rOff
		elseif st.localClone and d ~= nil and not isDynDepth(d) then rOff = rOff + D0 - d - 8 end
		if mem.base.rc == "sp" and not st.x86_prologue and type(d) == "table" then
			if rOff >= d.anchored.base and rOff < d.anchored.base + d.anchored.size then
				region = d.anchored
			end
		else
			region = ctx.regionOf(rOff, false)
		end
		if region then
			-- An aligned FP/vector access needing MORE than the region's provable
			-- alignment: reject at compile time (deterministic — the alternative is a
			-- runtime alignment trap that fires only when the GC payload happens to
			-- be under-aligned). Ordinary regions are 16-aligned (the GC payload);
			-- align=A regions (and the andq-anchored forms) provably cover A.
			local _, fa = fp.accessWidth(m, ops, st.raw)
			if fa and fa > (region.align or 16) then
				error("sarcasm: aligned " .. fa .. "-byte access into a " .. (region.align or 16)
					.. "-byte-aligned alloca region cannot be proven safe (annotate the region"
					.. " `alloca result size=N align=" .. fa .. "`, or use the unaligned form): "
					.. (st.raw or m))
			end
			emit(st); return
		end
		-- A stack access is only keyable to a frame slot when rsp provably sits at the
		-- post-prologue frame base; anything else (mid-function push/sub region, dynamic
		-- alloca aftermath, unbalanced merge) is unprovable: reject. (nil depth = dead code.)
		-- EXCEPTION: an rbp-relative access while rbp provably holds the frame pointer
		-- (x86_fp == "est"). rbp's value is static — established once in the prologue,
		-- with every re-establishment, clobber, and restore rejected or tracked by the
		-- frame-pointer state — so the slot this access touches is keyed by a static
		-- offset regardless of the rsp depth. This is what lets alloca-using code spill
		-- and reload locals (the size, the buffer pointer) through rbp-relative slots
		-- AFTER the alloca perturbed rsp — hand-written code and optimized builds alike
		-- rely on it — and the arm64 backend has always allowed the analogous
		-- x29-relative accesses there.
		-- SECOND EXCEPTION: an rsp-relative access at a KNOWN perturbed depth (the
		-- early-ret-then-frame shape: an early return before the pushes leaves the
		-- framed path's pushes POST-prologue, so D0 stays 0 while the body executes
		-- at depth 8k) may still alias an outstanding pushed register's save slot —
		-- the save-slot model below keys it in normalized coordinates
		-- (disp + D0 - d) exactly like the transient prologue pad; a non-aliased
		-- access at such a depth stays rejected.
		local perturbedRsp = false
		if not st.x86_prologue and d ~= nil and d ~= D0
			and not (usesRbp and mem.base.name == "rbp" and st.x86_fp == "est") then
			if not isDynDepth(d) and mem.base.rc == "sp" then
				perturbedRsp = true
			else
				error("sarcasm: stack access while the stack pointer is perturbed or unknown"
					.. " (cannot prove which frame slot this is): " .. (st.raw or m))
			end
		end
		-- Normalize to an rsp-relative frame offset: rbp, when it is the frame pointer,
		-- sits at the frame TOP (rbp = rsp + frameSize), so an rbp-relative displacement d
		-- is frame offset frameSize + d. The slot key, region lookup, and bounds check all
		-- use this NORMALIZED offset, so rbp- and rsp-relative accesses to the same address
		-- (e.g. -8(%rbp) and 8(%rsp) with a 16-byte frame) share one slot web, while
		-- distinct addresses (e.g. -8(%rbp) vs -8(%rsp)) never alias. A CLONE statement's
		-- rsp-relative displacement additionally keys 8 lower (the +8 rule: hardware has
		-- the pushed return address between the clone's rsp and the caller's frame — at
		-- the callsite depth this is exactly disp-8).
		local off = (mem.dispVal or 0)
		if mem.base.rc ~= "sp" then off = ctx.frameSize + off
		elseif st.localClone and d ~= nil and not isDynDepth(d) then off = off + D0 - d - 8
		elseif perturbedRsp then off = off + D0 - d end
		-- An entry-rsp materialization for reading the incoming yolo stack arguments
		-- (`leaq 0(%rsp), %reg` at a provable depth — the aesni_ocb shape): dropped;
		-- reads through the register are redirected by the alias handling above.
		if b == "lea" and isYoloLeaSave(st, d) then return end
		-- A saved-rsp materialization (`leaq K(%rsp), %reg` parking a known-depth stack
		-- pointer in a carrier — the ghash/aesni-gcm recovery-address computation):
		-- dropped with the save (the carrier discipline rejects every non-carrier use).
		if st.x86_leaSave then return end
		-- A DIRECT entry-time read of an incoming yolo stack argument: %rsp-based
		-- at a PROVABLE depth d (before the body's own frame setup, in a frameless
		-- body, or — the compiler style — above the established frame), e.g.
		-- `movq 8(%rsp), %rbx` / `movd 8(%rsp), %xmm5`: at depth d the argument
		-- sits at d+8+8*i(%rsp). The address is above the caller's frame, so the
		-- ordinary bounds check below would reject it; redirect it to the
		-- argument's slot instead.
		if mem.base.rc == "sp" and d ~= nil and not isDynDepth(d) and not mem.index then
			local i = yoloArgSlotOf(st, "rsp", d)
			if i then emitYoloRead(i); return end
		end
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
		-- The `;! ... ptr` annotation family operates on REAL memory (invisicap
		-- loads/stores/RMWs); a frame slot is virtualized/materialized, not real
		-- memory, so the annotation can never be honored here. Reject cleanly
		-- (used to crash the transform).
		if st.annotation and sig.PTR_ANNOTATIONS[st.annotation] then
			error("sarcasm: `" .. st.annotation .. "` on a stack-frame access is not supported"
				.. " (frame slots are virtualized/materialized, not real memory): " .. (st.raw or m))
		end
		-- cmpxchg8b/cmpxchg16b have no register form: a frame slot cannot be
		-- virtualized for them (a slot pseudo-register is not a memory operand),
		-- and GPR-only stack slots are never materialized. Reject cleanly instead
		-- of mis-sizing the slot (the bare mnemonic has no width suffix).
		if m == "cmpxchg8b" or m == "cmpxchg16b" then
			error("sarcasm: " .. m .. " on a stack-frame access is not supported (frame slots"
				.. " are virtualized as registers and " .. m .. " has no register form): "
				.. (st.raw or m))
		end
		-- Outstanding pushed-register save slots (the transient prologue pad). When a
		-- `pushq %rbx` sits inside the prologue prefix and has not been popped yet,
		-- the bytes it saved are NOT an ordinary frame slot: their content is mirrored
		-- by the pushed register's web, because the matching pop — which the
		-- save-pairing analysis proves restores exactly this register — is dropped.
		-- Virtualizing an access that aliases such a slot into an unrelated slot web
		-- silently desyncs it from the register (a store to the slot would never reach
		-- the register, and the dropped pop would resurrect the stale pre-push value).
		-- Model it instead:
		--   * a full-slot (8-byte) GPR access is rewritten to the register itself: a
		--     store then defines the pushed register's web (so the dropped pop
		--     naturally yields the stored value, matching real x86 where the pop
		--     overwrites the register with the stored value and the pre-push value is
		--     lost), a read-modify-write operates on that web, and a load — of any
		--     width, at the slot base — reads it (before any store that IS the pushed
		--     value);
		--   * anything else that overlaps a save slot — a partial-width store (the web
		--     model has no subregister view), a vector/x87 access (it cannot name a
		--     GPR web), or an instruction whose register form is not exactly modeled
		--     (checked by classifying the rewritten instruction below) — is rejected.
		-- Multi-register pads work the same way: the FIRST push sits at the HIGHEST
		-- address, so displacement (depth - save.depth) selects the slot (0 = most
		-- recent push, 8 = the one before it, ...). The saved frame pointer (a
		-- `pushq %rbp` establishing the frame) is not a value slot and never aliases
		-- here — it sits above the frame and the bounds check rejects accesses to it.
		local sv = st.x86_saves
		if sv == "dyn" then
			-- The save state is unprovable here: the paths disagree on which registers
			-- are pushed (or a push happened while rsp was poisoned). The access cannot
			-- be checked against individual save slots — but it also cannot DESYNC one
			-- in any function sarcasm accepts: an unprovable save state always carries
			-- an unprovable rsp depth with it (each outstanding push is 8 bytes of
			-- depth, and paths that disagree on outstanding pushes disagree on depth),
			-- so this point is reachable only for rbp-relative accesses (rsp-relative
			-- ones were already rejected above at d ~= D0), and every push that made
			-- the state unprovable makes its own pop unpairable — a body with an
			-- unpairable pop or a return at a poisoned depth is rejected downstream.
			-- Virtualize without the aliasing model.
		end
		local aliasHit, aliasDisp, aliasW = nil, nil, nil
		if sv and sv ~= "dyn" and #sv > 0 and not isFpInsn(fpEntry, st) then
			local w0 = gprStackWidth(m, mem)
			if w0 then
				for _, s in sv do
					if usesRbp and s.name == "rbp" then continue end  -- saved frame pointer
					-- The save slot's NORMALIZED frame offset: its displacement from the
					-- post-prologue frame base (D0). Computed from D0 rather than the
					-- current depth d so the aliasing identity holds in normalized
					-- coordinates even for an rbp-relative access at a perturbed/unknown
					-- rsp depth (both the access's offset and the save slot's are static
					-- in these coordinates).
					local sd = D0 - s.depth  -- that save slot's frame offset (>= 0)
					if off < sd + 8 and off + w0 > sd then
						aliasHit, aliasDisp, aliasW = s, sd, w0
						break
					end
				end
			end
		end
		if aliasHit then
			local function aliasReject(why)
				error("sarcasm: stack access overlapping a pushed register's save slot inside"
					.. " the transient prologue pad " .. why .. " (the slot's content is the"
					.. " pushed register's web; use a full 8-byte access or pop the pad"
					.. " first): " .. (st.raw or m))
			end
			if off ~= aliasDisp then
				aliasReject("at a non-slot-aligned displacement")
			end
			if aliasW ~= 8 and ops[1] == mem then
				-- A narrower store cannot define the register's web (the model has no
				-- subregister view) while the remaining slot bytes keep the pushed
				-- value the dropped pop would restore.
				aliasReject("with a partial-width store")
			end
			if aliasHit.redefined and not (ops[1] == mem and aliasW == 8 and b == "mov") then
				-- The pushed register was redefined between its push and this access:
				-- the slot holds the value pushed BEFORE the redefinition, while the
				-- register's web now holds the redefined value — reading the slot (a
				-- load, or a read-modify-write) would see the wrong value. The ONE
				-- exception is a full-width plain STORE: it overwrites the slot and
				-- the model defines the register's web with exactly that value, so
				-- the slot and the web agree again (the analysis clears the save's
				-- redefined state from there on). The OTHER exception is an epilogue
				-- movq-restore load that analyzeFrame proved unobservable (its
				-- x86_dropRestore walk found no later read of the destination): it
				-- is dropped like the epilogue pops.
				if st.x86_dropRestore then return end
				error("sarcasm: stack access overlapping a pushed register's save slot inside"
					.. " the transient prologue pad whose register was redefined after the"
					.. " push (the slot still holds the pre-redefinition value, so the"
					.. " save-slot model cannot express this access; pop the pad first or"
					.. " don't redefine the register inside it): " .. (st.raw or m))
			end
			local parsed = x86parse.classifyReg(aliasHit.name)
			if not (parsed and parsed.rc == "gpr") then
				aliasReject("for an unmodelable register")
			end
			local regOp = { kind = "reg", rc = "gpr", num = parsed.num,
				width = aliasW * 8, name = parsed.name }
			local newops = {}
			for _, o in ops do table.insert(newops, (o == mem) and regOp or o) end
			-- The rewritten instruction's REGISTER form must be exactly modeled: the
			-- conservative first-reg-def fallback (e.g. shld/shrd) would silently
			-- desync the slot from the register. Classify the rewritten (now
			-- register-only) instruction; it flags `unknown` for the fallback, and
			-- anything it rejects outright is rejected with that instruction's own
			-- precise message.
			local okC, c2 = pcall(x86.classify, {
				mnemonic = st.mnemonic, operands = newops, opsize = st.opsize,
				raw = st.raw, syntax = st.syntax,
			})
			if not okC or (c2 and c2.unknown) then
				aliasReject("by an instruction whose register form sarcasm does not model exactly")
			end
			emit({ kind = "insn", mnemonic = st.mnemonic, operands = newops,
				raw = st.raw, line = st.line, annotation = st.annotation })
			return
		end
		-- A KNOWN-perturbed-depth rsp-relative access that aliases no outstanding save
		-- slot virtualizes like any other slot: the normalized offset (disp + D0 - d)
		-- is exact at a statically-known depth, so the slot web connects every access
		-- to the same address across the depth change, the bounds check below gates
		-- the frame extent, and pops/returns stay pairing/depth-gated. (Historically
		-- this was rejected: with mid-function `addq $imm, %rsp` decreases accepted
		-- above — the ecp_nistz256 shared-tail frame-reshape shape — static
		-- perturbed depths are ordinary working points, not just the early-ret
		-- transient the save-alias model was built for. An UNKNOWN depth — a
		-- dynamic-alloca poison or an anchored region's coordinates — stays
		-- rejected above.)
		-- Replace the stack-slot memory operand in place with a slot pseudo-register of the
		-- access width, keeping the original mnemonic. This uniformly handles plain moves
		-- (movq), zero/sign-extending loads (movzwl/movsbl/...), and other reg<->slot forms:
		-- e.g. `movzwl 40(%rsp), %r14d` -> `movzwl %<slot:16>, %r14d`. The slot is keyed by
		-- byte offset, so a 64-bit store and a 16-bit reload of the same offset share one web.
		-- FP/SIMD/x87 instructions get their width from the knowledge module (the AT&T
		-- suffix convention does not apply to them: movsd is 8, movss 4, fldt 10, ...).
		-- That width is AUTHORITATIVE: a raw Intel mem.size must never under-size the
		-- slot — the emitted instruction keeps its true (wider) width and would
		-- overflow the materialized frame region into the caller's stack. accessWidth
		-- itself cleanly rejects a PTR annotation contradicting the ISA-fixed width
		-- (the size-driven x87/PTR forms take the annotation as their width). GPR
		-- instructions keep the mem.size-first behavior.
		local isFP = isFpInsn(fpEntry, st)
		local alignReq = 1
		local fw, fa = fp.accessWidth(m, ops, st.raw)
		local wb
		if isFP then
			wb = fw
			if fa and fa > 1 then alignReq = fa end
		else
			wb = mem.size or fw
		end
		if not wb then
			-- An FP-class access whose width is unknowable can neither be
			-- materialized nor virtualized soundly (a guessed width could
			-- under-cover the access). Reject cleanly. (Reject-listed entries
			-- fall through to the default width: the lift's fp.classify
			-- produces their more precise error.)
			if isFP and not (fpEntry and fpEntry.reject) then
				error("sarcasm: cannot determine the memory access width of '" .. m
					.. "' (cannot prove memory safety): " .. (st.raw or m))
			end
			wb = gprStackWidth(m, mem)
		end
		-- Bounds-check against the input frame (mirrors arm64's per-access checkBounds).
		-- rsp-relative offsets address the frame [0, frameSize) plus the 128-byte SysV red
		-- zone below rsp. NORMALIZED rbp-relative offsets range over the same [-128,
		-- frameSize): with rbp = rsp + frameSize, an rbp-relative d in [-frameSize-128,
		-- -frameSize) — e.g. the leaf-function shape `-8(%rbp)` with no `subq` at all — IS
		-- the red zone. (Pre-normalization rbp-relative d >= 0 hits the saved rbp, the
		-- return address, or the caller's argument area.) Anything outside cannot be
		-- proven safe: reject (a virtualized slot would silently fabricate garbage reads /
		-- dead writes).
		ctx.checkBounds(off, wb, ops[1] == mem, st.raw, -128)
		-- Aligned >16-byte stack accesses cannot be materialized at their required
		-- alignment: the synthesized frame (like the SysV ABI at entry) guarantees
		-- only 16-byte body-rsp alignment. Reject cleanly; the unaligned forms
		-- (vmovdqu/vmovups/...) encode no alignment promise and work fine.
		if isFP and alignReq > 16 then
			error("sarcasm: aligned 32/64-byte stack accesses are not supported (the stack is only"
				.. " guaranteed 16-byte aligned); use the unaligned form (e.g. vmovdqu/vmovups): "
				.. (st.raw or m))
		end
		-- An FP/SIMD-touched stack range is MATERIALIZED into sarcasm's synthesized
		-- frame (see analyzeFrame's taint scan): keep the instruction and rewrite its
		-- memory operand to a real disp(%rsp). GPR accesses overlapping the range
		-- land here too (aliasing). The rc="sp" base keeps the operand out of the
		-- register-web analysis (classify's isGpr skips it); the renderer's
		-- baseRegName fallback renders it as %rsp. size=wb lets the renderer
		-- synthesize AT&T suffixes for reg-less forms (e.g. `movl $5, O(%rsp)`).
		local final = ctx.fpInfo and ctx.fpInfo.lookup(off, wb)
		if final then
			-- A GPR access materialized into an FP-tainted cluster becomes a real
			-- disp(%rsp) memory access: a lying Intel PTR annotation that
			-- contradicts the register-defined access width would under-size the
			-- cluster while the materialized instruction writes past it (into the
			-- GC root slots / spill slots). Reject it, mirroring the heap path
			-- (x86_64_codegen.accessSizeAlign). Virtualized GPR slots keep the
			-- mem.size-first behavior (no real memory is accessed).
			if not isFP then
				local regW = x86.gprAccessRegWidth(st)
				if regW and mem.size and mem.size ~= regW then
					error("sarcasm: PTR size annotation (" .. tostring(mem.size)
						.. " bytes) contradicts the memory access width (" .. tostring(regW)
						.. " bytes) of '" .. m .. "': " .. (st.raw or m))
				end
			end
			-- AVX512 decorators ({1toN} embedded broadcast) MUST ride along on the
			-- materialized operand: the slot was sized by the DECORATED access width
			-- (fp.accessWidth applies bcastN), so dropping the decorator would emit a
			-- full-width vector access to an element-sized slot. ({kN} masks were
			-- rejected above, so only broadcast/plain decorators can reach here.)
			local mat = { kind = "mem",
				base = { kind = "reg", rc = "sp", num = 4, width = 64, name = "rsp" },
				scale = 1, dispVal = final, size = wb, frameSlot = true,
				deco = mem.deco, bcastN = mem.bcastN }
			local newops = {}
			for _, o in ops do table.insert(newops, (o == mem) and mat or o) end
			emit({ kind = "insn", mnemonic = st.mnemonic, operands = newops, raw = st.raw, line = st.line, annotation = st.annotation })
			return
		end
		local slot = ctx.slotReg(off, wb * 8)
		local newops = {}
		for _, o in ops do table.insert(newops, (o == mem) and slot or o) end
		emit({ kind = "insn", mnemonic = st.mnemonic, operands = newops, raw = st.raw, line = st.line, annotation = st.annotation })
		return
	end

	-- (a lea of a stack address is handled — and rejected — inside the slot block above:
	-- in-region leas pass through for the transform's region redirect, symbolic-displacement
	-- stack operands were rejected above, and every other stack-based lea hits rejectEscape.)

	-- A recorded `movq %rsp, %reg` saved-rsp carrier: DROP it — sarcasm synthesizes
	-- its own frame, so the parked value has no meaning in the output (it is
	-- phantom): the carrier flows and the recovery are dropped with it, and the
	-- analysis rejects every non-carrier read of the value while the save is
	-- outstanding. Register class and position are unrestricted (every use of a
	-- carrier is dropped or rejected, so no call clobber can be observed) — EXCEPT
	-- the fixed-alloca-region corner below, which keeps a caller-saved save alive as
	-- a REAL redirected value and so records no carrier.
	if st.x86_spSave then return end
	-- Caller-saved save with a static fixed-alloca region based at rsp+0 (unrecorded
	-- by the analysis): fall through to the region passthrough below, which KEEPS
	-- the read with its destination redirected to the allocation pointer — a real
	-- value, so the register may still be read (this corner predates the rsp-save
	-- machinery).

	-- `movq %rsp, %reg`: when a fixed-alloca region is based at rsp+0 (static region, or
	-- — at a post-prologue "dyn" depth — an anchored one) the transform redirects this
	-- to the allocation pointer (mirrors arm64's `mov xD, sp` handling); pass through.
	-- The static region base is only known relative to the post-prologue frame base:
	-- reject when rsp is perturbed/unknown here (the anchored case IS the dyn one).
	if b == "mov" and ops[2] and ops[2].rc == "sp" and ops[1] and ops[1].kind == "reg"
		and ops[1].rc == "gpr" then
		local movDyn = not st.x86_prologue and type(d) == "table"
		if ctx.regionOf(0, movDyn) then
			if not st.x86_prologue and d ~= nil and d ~= D0 and not movDyn then
				error("sarcasm: reading the stack pointer while it is perturbed or unknown"
					.. " cannot be proven safe: " .. (st.raw or m))
			end
			emit(st); return
		end
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

-- The vector-save reservation x86_64 uses when a function's xmm registers must be
-- preserved across an injected runtime call (16 bytes per xmm0..xmm15 slot — the
-- Fil-C runtime is SSE2-only, so xmm16-31 / ymm / zmm / k state is unreachable
-- for it; the expandFpSaves liveness narrows each slot's mov to the live width).
-- The transform forces this reservation for FP-signature CALLSITE functions even
-- when the body touches no vector register (see transform.luau) — the ENTRY
-- signature case is forced directly in analyzeFrame above — matching
-- arm64_frame.VEC_SAVE_BYTES. Consumed by codegen (which also widens its
-- save/restore activation to any forced reservation) and the layout.
x86_64_frame.VEC_SAVE_BYTES = 16 * 16

-- The net rsp depth at the end of the prologue prefix (the frame base) of the
-- function most recently analyzed — the coordinate origin the +8 rule's clone
-- displacement bias is computed against (set by analyzeFrame; single-threaded
-- discipline, like D0).
function x86_64_frame.frameBaseDepth() return D0 end

return x86_64_frame
