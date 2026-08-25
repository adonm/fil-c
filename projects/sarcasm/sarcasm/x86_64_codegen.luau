--!nonstrict
-- x86_64 codegen: the per-arch instruction emitter used by the shared GIMSO transform
-- (transform.luau). It exposes (a) static config — calling convention, operand analysis —
-- and (b) make(ctx) returning a `cg` of neutral "micro-ops" the shared transform composes
-- into access checks, invisicap loads/stores, calls, pollchecks and allocations. Output is
-- always AT&T (see x86_64_render); the IR nodes are dest-first.

local build = require("./build")
local isa = require("./x86_64_isa")
local xparse = require("./x86_64_parse")
local sig = require("./sig")
local fp = require("./x86_64_fp")

local M = {}

-- ISA passthrough ---------------------------------------------------------
M.classify = isa.classify
M.baseMnemonic = isa.baseMnemonic
M.precolorName = function(num) return xparse.regName(num, 64) end
M.ALLOCATABLE = isa.ALLOCATABLE

-- Calling convention (numbers are register encodings; see x86_64_isa).
-- Fast entrypoint: rdi=myth, (rdx,rcx)=arg0, (r8,r9)=arg1; ret al=flags, rdx=iv, rcx=lo.
-- Runtime (SysV) calls: rdi,rsi,rdx,... ; result in rax.  yolo params arrive in SysV regs.
-- A runtime filc_ptr result (the atomic pointer operations) comes back as rax=intval,
-- rdx=lower (plain SysV: two consecutive integer return words).
M.cc = {
	myth = isa.CC.myth, retFlag = isa.CC.retFlag, retIv = isa.CC.retIv, retLo = isa.CC.retLo,
	argIv = isa.CC.argIv, argLo = isa.CC.argLo,
	yoloArg = function(k) return isa.SYSV[k] end,
	rtArg = function(k) return isa.SYSV[k] end,   -- runtime-call arg registers
	rtRet = 0,                                    -- rax
	rtRetLo = 2,                                  -- rdx (filc_ptr return: lower word)
}

-- Callsite signature validation (called by the shared transform for each `;! sig` call
-- annotation). The x86_64 fast CC packs argument words densely into the FOUR registers
-- rdx,rcx,r8,r9 (a pointer arg = 2 words); wider arguments are passed on the stack,
-- which sarcasm does not yet marshal. So a call needs at most 4 register argument
-- words. (Resolved-EXTERNAL calls are also bounded by the callsite thunk's 4-register
-- hold pool -- the same limit; see x86_64_glue.callsiteThunk.) FP/vector type classes
-- are rejected outright: they marshal through vector registers sarcasm does not model,
-- so an FP callsite signature would silently pass/return garbage.
function M.checkCallsiteSig(cs, callee)
	sig.checkSupportedClasses(cs, "call to '" .. callee .. "'")
	local words = 0
	for k = 1, cs.argWords do words += (cs.argTypes[k] == 7) and 2 or 1 end
	if words > 4 then
		error("sarcasm: call to '" .. callee .. "': >4 register argument words not yet supported"
			.. " (this call's signature needs " .. tostring(words) .. ")")
	end
end

-- Static operand analysis -------------------------------------------------
function M.memOperand(stmt)
	for _, op in stmt.operands do if op.kind == "mem" then return op end end
	return nil
end

local WIDTH_LETTER = { b = 1, w = 2, l = 4, q = 8 }
function M.accessSizeAlign(stmt)
	local mnem = string.lower(stmt.mnemonic)
	-- FP/SIMD/x87 instructions get their access width from the knowledge module
	-- (authoritative — it cleanly rejects an Intel PTR size annotation that
	-- contradicts the ISA-fixed width).
	local fw, fa = fp.accessWidth(mnem, stmt.operands or {}, stmt.raw)
	if fw then
		-- The access check's alignment is capped at the word size, exactly like the
		-- Fil-C compiler (FilPizlonator's buildCheck does std::min(Alignment,
		-- WordSize)): the runtime's optimized-access-check origin cannot express
		-- larger alignments (filc_runtime.c asserts check_origin->alignment <=
		-- FILC_WORD_SIZE). A movdqa-class access to an address that is word-aligned
		-- but not vector-aligned passes the check and then faults in hardware,
		-- same as compiled code — the bounds check is unaffected.
		if fa > 8 then fa = 8 end
		return fw, fa
	end
	-- Defense in depth: an FP-class instruction with a memory operand whose width
	-- is unknowable must never fall back to a default width (fp.classify normally
	-- already rejected it during the lift).
	do
		local hasMem = false
		for _, op in (stmt.operands or {}) do if op.kind == "mem" then hasMem = true break end end
		if hasMem and fp.hasFpReg(stmt) then
			error("sarcasm: cannot determine the memory access width of '" .. mnem
				.. "' (cannot prove memory safety): " .. (stmt.raw or mnem))
		end
	end
	local zs = string.match(mnem, "^mov[zs]([bw])")  -- movzbl/movswq/... source width letter
	if zs then local s = WIDTH_LETTER[zs]; return s, s end
	local mem
	for _, op in stmt.operands do if op.kind == "mem" then mem = op end end
	-- cmpxchg8b/cmpxchg16b: the ISA-fixed width is in the mnemonic itself (there
	-- is no size suffix and no register form); the sole operand is memory. An
	-- Intel PTR size annotation CONTRADICTING the ISA-fixed width is rejected
	-- like any other annotation lie. (cmpxchg16b's 16-byte alignment requirement
	-- is hardware-enforced; checking it here keeps a misaligned address a clean
	-- filc trap rather than a #GP.)
	if mnem == "cmpxchg8b" or mnem == "cmpxchg16b" then
		local w = (mnem == "cmpxchg16b") and 16 or 8
		if mem and mem.size and mem.size ~= w then
			error("sarcasm: PTR size annotation (" .. tostring(mem.size)
				.. " bytes) contradicts the memory access width (" .. tostring(w)
				.. " bytes) of '" .. mnem .. "': " .. (stmt.raw or mnem))
		end
		return w, w
	end
	local base = isa.baseMnemonic(mnem)
	if (base == "movzx" or base == "movsx") and mem and mem.size then return mem.size, mem.size end
	-- GPR access: the width is register-defined (AT&T suffix / first GPR operand
	-- width). An Intel PTR size annotation CONTRADICTING that width is a lie — the
	-- emitted instruction encodes the register width regardless (`mov WORD PTR
	-- [rdi], rax` stores 8 bytes, not 2) — so reject rather than under-size the
	-- bounds check. Size-driven (movzx/movsx) and memory-neutral (lea) forms and
	-- no-GPR-operand forms (push/pop/call/jmp, inc/dec/neg/not mem-only) take
	-- their width from the annotation/suffix legitimately (gprAccessRegWidth is
	-- nil for them).
	local regW = isa.gprAccessRegWidth(stmt)
	if mem and mem.size and regW and mem.size ~= regW then
		error("sarcasm: PTR size annotation (" .. tostring(mem.size)
			.. " bytes) contradicts the memory access width (" .. tostring(regW)
			.. " bytes) of '" .. mnem .. "': " .. (stmt.raw or mnem))
	end
	local sz = (mem and mem.size) or regW or 8
	return sz, sz
end

-- Fixed-size alloca base (mirrors arm64's `mov rd, sp` / `add rd, sp, #imm`): a fixed
-- stack buffer's address is materialized with `leaq disp(%rbp), %rd` when a frame pointer
-- is in use (the gcc/clang -O0 idiom), or `leaq disp(%rsp), %rd` / `movq %rsp, %rd` under
-- frame-pointer omission. `fctx` carries the frame analysis ({ frameSize, usesFp }); an
-- rbp-relative displacement is normalized to an rsp-relative frame offset (rbp = rsp +
-- frameSize) so region math stays in one coordinate space. Returns the rsp-relative base
-- offset, or nil if the annotated instruction does not compute a stack-frame-relative
-- address.
function M.allocaRegionBase(stmt, fctx)
	local m = isa.baseMnemonic(string.lower(stmt.mnemonic))
	local ops = stmt.operands
	if m == "lea" then
		local mem = M.memOperand(stmt)
		if mem and mem.base and not mem.index and not mem.dispSym then
			if mem.base.rc == "sp" then return mem.dispVal or 0 end
			if fctx and fctx.usesFp and mem.base.name == "rbp" then
				return fctx.frameSize + (mem.dispVal or 0)
			end
		end
		return nil
	end
	if m == "mov" and ops[1] and ops[1].kind == "reg" and ops[1].rc ~= "sp"
		and ops[2] and ops[2].rc == "sp" then
		return 0
	end
	return nil
end

-- Is this a load/store the transform models? On x86 most instructions can carry a memory
-- operand (it is a load/store architecture only in spirit), so any mem operand is a real
-- access to bounds-check; nothing to reject as "mem on a non-load/store".
function M.isMemInsn(mnem) return true end

-- `alloca size` size operand: `sub rsp, X` -> X is operands[2] (dest-first).
function M.allocaSizeOperand(stmt) return stmt.operands[2] end

-- Ptr-annotation shape validation (the shared transform rejects `;! load ptr` /
-- `;! store ptr` on anything that is not the matching plain access — a mismatch
-- used to be a SILENT MISCOMPILE: the annotated instruction was replaced by an
-- invisicap load/store, dropping the original operation). Returns:
--   "load"  — a plain 8-byte GPR load  (`movq (mem), %reg64` / Intel `mov r64, [mem]`)
--   "store" — a plain 8-byte GPR store (`movq %reg64, (mem)`)
--   "rmw"   — a memory-destination read-modify-write (ALU mem-RMW, xadd, cmpxchg,
--             adcx/adox/crc32, cmpxchg8b/16b): needs `;! load store ptr` instead
--   "other" — anything else (no memory operand, FP/SIMD, imm store, narrow mov, ...)
function M.ptrAccessKind(stmt)
	local ops = stmt.operands or {}
	local mem = M.memOperand(stmt)
	if not mem then return "other" end
	if isa.isMemRmw(stmt) then return "rmw" end
	local base = isa.baseMnemonic(string.lower(stmt.mnemonic))
	if base == "mov" and #ops == 2 then
		if ops[1] == mem and isa.isGpr(ops[2]) and (ops[2].width or 64) == 64 then return "store" end
		if ops[2] == mem and isa.isGpr(ops[1]) and (ops[1].width or 64) == 64 then return "load" end
	end
	return "other"
end

-- The memory-destination RMW operations supported on pointer slots (8-byte forms):
-- the lockable ALU family plus the unary inc/dec/neg/not. (Shifts/rotates/imul are
-- memory-destination RMWs too, but a shift/rotate/multiply of a pointer intval is
-- not a capability-preserving operation sarcasm implements.)
local PTR_RMW_OPS = { add = true, adc = true, ["and"] = true, ["or"] = true, sbb = true,
	sub = true, xor = true, inc = true, dec = true, neg = true, ["not"] = true }

-- Shape validation for the Phase-2 atomic/pointer-RMW annotations (`;! atomic load ptr`,
-- `;! atomic store ptr`, `;! atomic ptr`, `;! load store ptr`,
-- `;! atomic load store ptr`). Returns the sequence kind for the shared transform:
--   "atomicload" / "atomicstore" — runtime atomic pointer load/store (plain movq forms)
--   "cas"       — `;! atomic ptr` on cmpxchgq (pointer compare-exchange)
--   "rmw"       — `;! load store ptr` on a supported 8-byte mem-RMW (non-atomic)
--   "atomicrmw" — `;! atomic load store ptr` on a supported 8-byte mem-RMW
-- Anything else raises a clean sarcasm: error. (cmpxchg8b/cmpxchg16b are rejected
-- earlier, in the shared transform, for EVERY ptr-family annotation.)
function M.ptrAtomicShape(ann, stmt)
	local raw = stmt.raw or stmt.mnemonic or "?"
	if ann == "atomic load ptr" or ann == "atomic store ptr" then
		local want = (ann == "atomic load ptr") and "load" or "store"
		if M.ptrAccessKind(stmt) ~= want then
			error("sarcasm: `;! " .. ann .. "` requires a plain 8-byte GPR " .. want
				.. " instruction: " .. raw)
		end
		return (ann == "atomic load ptr") and "atomicload" or "atomicstore"
	end
	local base = isa.baseMnemonic(string.lower(stmt.mnemonic))
	local ops = stmt.operands or {}
	if ann == "atomic ptr" then
		if base ~= "cmpxchg" then
			error("sarcasm: `;! atomic ptr` is only supported on cmpxchg (pointer"
				.. " compare-exchange): " .. raw)
		end
		if not (ops[1] and ops[1].kind == "mem") then
			error("sarcasm: `;! atomic ptr` requires cmpxchg with a memory destination"
				.. " (the register form has no capability slot to exchange against): " .. raw)
		end
		if #ops ~= 2 or not isa.isGpr(ops[2]) then
			error("sarcasm: `;! atomic ptr` requires the cmpxchg mem, reg form"
				.. " (a GPR new-value operand): " .. raw)
		end
		local w = M.accessSizeAlign(stmt)
		if w ~= 8 then
			error("sarcasm: `;! atomic ptr` requires the 8-byte (q) cmpxchg form"
				.. " (pointer slots are 8 bytes): " .. raw)
		end
		return "cas"
	end
	-- `;! load store ptr` / `;! atomic load store ptr`: pointer RMWs.
	if M.ptrAccessKind(stmt) ~= "rmw" then
		error("sarcasm: `;! " .. ann .. "` requires a memory-destination"
			.. " read-modify-write instruction: " .. raw)
	end
	if base == "cmpxchg" then
		error("sarcasm: `;! " .. ann .. "` on cmpxchg; pointer compare-exchange needs"
			.. " `;! atomic ptr`: " .. raw)
	end
	if string.match(string.lower(stmt.mnemonic), "^xadd[bwlq]?$") then
		error("sarcasm: `;! " .. ann .. "` is not supported on xadd: its source register"
			.. " is also a destination (it would receive the old pointer value, needing a"
			.. " pointer def + lower — use a `;! atomic ptr` cmpxchg loop instead): " .. raw)
	end
	if not PTR_RMW_OPS[base] then
		error("sarcasm: `;! " .. ann .. "` is not supported on '" .. string.lower(stmt.mnemonic)
			.. "' (supported pointer RMWs: add/adc/and/or/sbb/sub/xor, inc/dec/neg/not): " .. raw)
	end
	-- Operand shape: the unary forms are mem-only; the binary forms are
	-- mem, reg|imm. A second MEMORY operand is not encodable in x86 for these
	-- (a gas error) and would sneak an unchecked heap read into the re-emitted
	-- register operation — reject it here.
	if PTR_RMW_OPS[base] and (base == "inc" or base == "dec" or base == "neg" or base == "not") then
		if #ops ~= 1 then
			error("sarcasm: `;! " .. ann .. "` on " .. base .. " requires the one-operand"
				.. " memory form: " .. raw)
		end
	elseif #ops ~= 2 or not (isa.isGpr(ops[2]) or ops[2].kind == "imm") then
		error("sarcasm: `;! " .. ann .. "` requires a GPR register or immediate source"
			.. " operand (x86 has no mem-to-mem " .. base .. " form): " .. raw)
	end
	local w = M.accessSizeAlign(stmt)
	if w ~= 8 then
		error("sarcasm: `;! " .. ann .. "` requires the 8-byte (q) form"
			.. " (pointer slots are 8 bytes): " .. raw)
	end
	if ann == "load store ptr" and stmt.lockPrefix then
		error("sarcasm: `lock` on a `;! load store ptr` RMW is a lie (the sequence is a"
			.. " non-atomic load+op+store); use `;! atomic load store ptr` for an atomic"
			.. " pointer RMW: " .. raw)
	end
	return (ann == "load store ptr") and "rmw" or "atomicrmw"
end
-- a store writes memory when the (dest-first) first operand is the memory operand.
-- Single-memory-operand FP/x87 instructions break that positional rule: the lone
-- memory operand can be a source (fldl, faddl, fcoml, fxrstor, ldmxcsr, ...), so
-- decide those from the mnemonic — the stores are exactly the fst*/fist*/fbstp/
-- fnst*/fxsave/stmxcsr families, plus the unprivileged system-table stores
-- sgdt/sidt/sldt/str/smsw (all single-memory-operand stores the fp table claims;
-- vstmxcsr is the VEX alias of stmxcsr and reaches here by name).
function M.isStoreInsn(stmt)
	local ops = stmt.operands
	if ops[1] and ops[1].kind == "mem" and #ops == 1 then
		local mnem = string.lower(stmt.mnemonic)
		if fp.lookup(mnem) then
			return mnem == "fbstp" or mnem == "fxsave" or mnem == "fxsave64"
				or mnem == "stmxcsr" or mnem == "vstmxcsr"
				or mnem == "sgdt" or mnem == "sidt"
				or mnem == "sldt" or mnem == "str" or mnem == "smsw"
				or string.match(mnem, "^fst") ~= nil
				or string.match(mnem, "^fist") ~= nil
				or string.match(mnem, "^fnst") ~= nil
		end
	end
	return ops[1] and ops[1].kind == "mem"
end

-- x86 conditions for the neutral cmp/test conditions used by the shared transform.
local JCC = { ult = "jb", uge = "jae", ugt = "ja", ule = "jbe", eq = "je", ne = "jne" }

function M.make(ctx)
	local emit, allocTemp, pColored, temps = ctx.emit, ctx.allocTemp, ctx.pColored, ctx.temps
	local pf = ctx.pf
	local cg = { cc = M.cc }

	local function rt(t, w) return build.rt(t, w) end
	local function branch(cc_, lbl)
		emit(build.insn(cc_, { build.sym(lbl) }, { control = "condbranch", targets = {lbl} }))
	end

	function cg.move(dst, src, coalesce)
		emit(build.insn("mov", { rt(dst), rt(src) },
			{ defs = {dst}, uses = {src}, move = coalesce and { dst = dst, src = src } or nil }))
	end
	function cg.moveImm(dst, v) emit(build.insn("mov", { rt(dst), build.imm(v) }, { defs = {dst} })) end
	function cg.moveZero(dst) emit(build.insn("mov", { rt(dst), build.imm(0) }, { defs = {dst} })) end
	function cg.movBig(dst, hex) emit(build.insn("mov", { rt(dst), build.imm(hex) }, { defs = {dst} })) end

	function cg.load(dst, base, off, size)
		-- byte loads zero-extend into a 32-bit dest (mirrors ARM `ldrb`); wider loads are plain.
		local mnem = (size == 1) and "movzbl" or "mov"
		local w = (size == 1) and 32 or (size and size * 8 or 64)
		emit(build.insn(mnem, { rt(dst, w),
			build.memx(rt(base), { dispVal = off ~= 0 and off or nil }) }, { defs = {dst}, uses = {base} }))
	end
	function cg.loadIndexed(dst, base, idx, scale, size)
		emit(build.insn("mov", { rt(dst, size and size * 8 or 64),
			build.memx(rt(base), { index = rt(idx), scale = scale or 1 }) }, { defs = {dst}, uses = {base, idx} }))
	end
	function cg.store(src, base, off)
		emit(build.insn("mov", { build.memx(rt(base), { dispVal = off ~= 0 and off or nil }), rt(src) },
			{ uses = {src, base} }))
	end
	function cg.storeIndexed(src, base, idx, scale)
		emit(build.insn("mov", { build.memx(rt(base), { index = rt(idx), scale = scale or 1 }), rt(src) },
			{ uses = {src, base, idx} }))
	end
	-- dst = base + off + idx*scale (lea; base/idx are temps, may be nil)
	function cg.effAddr(dst, base, off, idx, scale)
		local uses, mopts = {}, { dispVal = (off ~= 0) and off or nil }
		if base then table.insert(uses, base) end
		if idx then mopts.index = rt(idx); mopts.scale = scale or 1; table.insert(uses, idx) end
		emit(build.insn("lea", { rt(dst), build.memx(base and rt(base) or nil, mopts) }, { defs = {dst}, uses = uses }))
	end
	function cg.addImm(dst, src, imm)  -- dst = src + imm
		emit(build.insn("lea", { rt(dst), build.memx(rt(src), { dispVal = imm }) }, { defs = {dst}, uses = {src} }))
	end
	function cg.subImm(dst, src, imm)  -- dst = src - imm
		emit(build.insn("lea", { rt(dst), build.memx(rt(src), { dispVal = -imm }) }, { defs = {dst}, uses = {src} }))
	end
	function cg.subReg(dst, a, b)      -- dst = a - b
		cg.move(dst, a)
		emit(build.insn("sub", { rt(dst), rt(b) }, { defs = {dst}, uses = {dst, b} }))
	end
	function cg.andImmInPlace(dst, mask)  -- dst = dst & mask
		emit(build.insn("and", { rt(dst), build.imm(mask) }, { defs = {dst}, uses = {dst} }))
	end
	function cg.maskLow48(dst)  -- dst = dst & 0xffffffffffff  (shl 16; shr 16 clears top 16)
		emit(build.insn("shl", { rt(dst), build.imm(16) }, { defs = {dst}, uses = {dst} }))
		emit(build.insn("shr", { rt(dst), build.imm(16) }, { defs = {dst}, uses = {dst} }))
	end

	function cg.branchZero(reg, lbl)
		emit(build.insn("test", { rt(reg), rt(reg) }, { uses = {reg} })); branch("je", lbl)
	end
	function cg.branchNonZero(reg, lbl)
		emit(build.insn("test", { rt(reg), rt(reg) }, { uses = {reg} })); branch("jne", lbl)
	end
	function cg.cmpBranch(a, b, cond, lbl)
		emit(build.insn("cmp", { rt(a), rt(b) }, { uses = {a, b} })); branch(JCC[cond], lbl)
	end
	function cg.cmpImmBranch(a, imm, cond, lbl)
		emit(build.insn("cmp", { rt(a), build.imm(imm) }, { uses = {a} })); branch(JCC[cond], lbl)
	end
	-- branch if (reg & mask) cond 0   (cond "eq"/"ne"). x86 `test` only takes a 32-bit
	-- (sign-extended) immediate, so a mask that doesn't fit imm32 must go through a register.
	function cg.testMaskBranch(reg, mask, cond, lbl, width)
		local mval = (type(mask) == "number") and mask or tonumber(mask)
		local big = (mval == nil) or mval > 0x7fffffff or mval < -0x80000000
		if big then
			local m = allocTemp({ role = "scratch" }); cg.movBig(m, mask)
			emit(build.insn("test", { rt(reg), rt(m) }, { uses = {reg, m} }))
		else
			emit(build.insn("test", { rt(reg, width), build.imm(mask) }, { uses = {reg} }))
		end
		branch(cond == "eq" and "je" or "jne", lbl)
	end
	function cg.jump(lbl)
		emit(build.insn("jmp", { build.sym(lbl) }, { control = "branch", targets = {lbl}, fallsThrough = false }))
	end
	function cg.label(name) emit(build.label(name)) end

	function cg.call(sym, uses, clobbers, indirect)
		local node = build.insn("call", { build.sym(sym, indirect and nil or "plt") },
			{ control = "call", uses = uses, defs = clobbers })
		if indirect then node.indirect = true end
		emit(node)
	end
	function cg.callerSavedClobbers()
		local clob = {}
		for _, rn in isa.CALLER_SAVED_NUMS do table.insert(clob, pColored(rn)) end
		return clob
	end
	function cg.leaGlobal(destPhys, sym)  -- destPhys is a physical reg num
		emit(build.insn("lea", { build.rp(destPhys), build.memx({ kind = "reg", rc = "rip" }, { dispSym = sym }) },
			{ defs = { pColored(destPhys) } }))
	end

	-- Stack marshalling for a runtime call with a trailing filc_ptr argument past
	-- the six SysV argument registers (filc_strong_cas_ptr_with_manual_tracking's
	-- new_value): the words must sit at [rsp]=intval, [rsp+8]=lower AT the call.
	-- The values are stored into the red zone FIRST (-16/-8(%rsp), clobber-free per
	-- the SysV ABI) and rsp is then dropped over them — this order keeps every
	-- temp-using instruction (the two stores, incl. any spill reloads regalloc
	-- inserts for them) on the UNADJUSTED rsp that the frame layout is computed
	-- against; only the call itself (whose def/use temps are all precolored,
	-- never spill-rewritten) executes inside the adjusted window. popStackPtr
	-- restores rsp right after the call (before fpRestore, whose frame slots are
	-- also rsp-relative).
	function cg.pushStackPtr(ivTemp, loTemp)
		emit(build.insn("mov", { build.memx(build.rp(4), { dispVal = -16 }), rt(ivTemp) },
			{ uses = { ivTemp } }))
		emit(build.insn("mov", { build.memx(build.rp(4), { dispVal = -8 }), rt(loTemp) },
			{ uses = { loTemp } }))
		emit(build.insn("sub", { build.rp(4), build.imm(16) }, {}))
	end
	function cg.popStackPtr()
		emit(build.insn("add", { build.rp(4), build.imm(16) }, {}))
	end

	-- effective address + capability selection for a memory operand.
	function cg.computeAddr(node, mem)
		-- A symbolic displacement (RIP-relative global access, `sym(%rip)`) cannot be
		-- bounds-checked: there is no capability for the target. Reject cleanly
		-- instead of crashing later in the renderer.
		if mem.dispSym then
			error("sarcasm: memory access with a symbolic address cannot be bounds-checked"
				.. " (global data access is not yet supported): " .. (node.stmt.raw or "?"))
		end
		local baseTemp = mem.base and node.opTemp[mem.base] or nil
		local indexTemp = (mem.index and mem.index.kind == "reg") and node.opTemp[mem.index] or nil
		local capLo
		if baseTemp and pf.isPtr[baseTemp] then capLo = pf.lowerTemp[baseTemp]
		elseif indexTemp and pf.isPtr[indexTemp] then capLo = pf.lowerTemp[indexTemp] end
		local disp = mem.dispVal or 0
		local effTemp = baseTemp
		if indexTemp or disp ~= 0 or not baseTemp then
			effTemp = allocTemp({ role = "eff" })
			cg.effAddr(effTemp, baseTemp, disp, indexTemp, mem.scale or 1)
		end
		return effTemp, capLo
	end

	-- store-barrier marking-state test: branch to `lbl` if FUGC marking is active.
	function cg.markingStateNonzeroBranch(lbl)
		local msp = allocTemp({ role = "scratch" })
		emit(build.insn("mov", { rt(msp), build.memx({ kind = "reg", rc = "rip" },
			{ dispSym = "filc_current_marking_state", dispReloc = "gotpcrel" }) }, { defs = {msp} }))
		local msv = allocTemp({ role = "scratch" })
		emit(build.insn("mov", { rt(msv, 32), build.memx(rt(msp), {}) }, { defs = {msv}, uses = {msp} }))
		emit(build.insn("test", { rt(msv, 32), rt(msv, 32) }, { uses = {msv} })); branch("jne", lbl)
	end
	-- branch to exception epilogue if the call's return flag bit 0 is set (al bit0).
	function cg.exceptionBranch(lbl)
		emit(build.insn("test", { build.rp(M.cc.retFlag, 8), build.imm(1) }, { uses = { pColored(M.cc.retFlag) } }))
		branch("jne", lbl)
	end

	function cg.clearRetFlag()
		emit(build.insn("mov", { build.rp(M.cc.retFlag, 32), build.imm(0) }, { defs = { pColored(M.cc.retFlag) } }))
	end
	-- Redirect an rsp/rbp-relative address computation landing inside a fixed alloca region
	-- to the allocation pointer (gcc -O0 re-derives the buffer address per use). Returns
	-- true if it replaced the node; a direct stack-relative *access* into a region is
	-- rejected (mirrors arm64's regionRedirect). All matching happens in rsp-relative
	-- frame offsets: an rbp-relative displacement d is normalized to frameSize + d (rbp =
	-- rsp + frameSize when it is the frame pointer).
	local fctx = ctx.frameCtx

	-- FP/SIMD save/restore around sarcasm-injected RETURNING runtime calls (the pollcheck
	-- slow path, filc_allocate, the ptr-store slow paths, the Phase-2 atomic pointer
	-- load/store/compare-exchange runtime calls). The source program never saw
	-- these calls, so its live xmm/ymm/zmm values would be silently clobbered by them:
	-- SysV makes every FP/SIMD register caller-saved. The Fil-C runtime is compiled
	-- SSE2-only (pizfix/lib/libpizlo.a contains xmm instructions but zero ymm/zmm), so
	-- preserving the WIDEST vector class the function itself uses (fpInfo.vecBytes)
	-- covers whatever the runtime can clobber, and also covers the function's own wider
	-- state regardless of which subset of it the runtime actually touches.
	--
	-- A nil vecBytes (a GPR-only function, or one using only k-opmask/x87/mm registers)
	-- emits NOTHING. For x87/mm state this is sound NOT because "an SSE2-only runtime
	-- cannot clobber x87" — libpizlo.a DOES contain x87 instructions (the fldt/fstpt
	-- in the zmath long-double wrappers) — but because the only callees these
	-- injected-call paths can reach (filc_pollcheck_slow, filc_allocate, the two
	-- store-barrier slow paths filc_object_ensure_aux_ptr_outline /
	-- filc_store_barrier_for_lower_slow, and the Phase-2 atomic pointer operations
	-- filc_load_ptr_atomic_with_manual_tracking_outline /
	-- filc_store_ptr_atomic_outline / filc_strong_cas_ptr_with_manual_tracking —
	-- whose internal ensure-aux/box-allocation/barrier paths are the same
	-- allocation/barrier code the first four already cover) never execute those
	-- wrappers. k-opmask state
	-- genuinely cannot be clobbered by an SSE2-only runtime (it is EVEX-only). If the
	-- runtime is ever compiled with AVX512, this must be extended to also save
	-- zmm16-31 and k0-7 (EVEX state an AVX512 build could clobber).
	--
	-- The save area sits above the GC root area of the synthesized frame (reserved by
	-- x86_64_render.computeLayout); slot i is assigned 16+i*vecBytes(%rsp) here —
	-- relative to base 16, like the materialized clusters — and transform shifts it
	-- past the root area once numRoots is known (the frameSlot tag is what the shift
	-- looks for). The unaligned forms (movdqu/vmovdqu/vmovdqu64) need no alignment
	-- beyond the frame's guaranteed 16-byte body alignment, and each is exactly the
	-- ISA level the function's own widest register class already requires
	-- (SSE2 / AVX / AVX512F). The vector registers render by name (fixed operands;
	-- the register allocator never models xmm-class registers); the slot base is a
	-- fixed %rsp operand (4 = rsp).
	local fpInfo = fctx and fctx.fp
	local vecBytes = fpInfo and fpInfo.vecBytes or nil
	local vecSaveMnem, vecClass = nil, nil
	if vecBytes == 16 then vecSaveMnem, vecClass = "movdqu", "xmm"
	elseif vecBytes == 32 then vecSaveMnem, vecClass = "vmovdqu", "ymm"
	elseif vecBytes == 64 then vecSaveMnem, vecClass = "vmovdqu64", "zmm" end
	local function vecSaveInsn(isRestore, i)
		local vreg = { kind = "reg", rc = "xmm", num = i, width = vecBytes * 8, name = vecClass .. i }
		local slot = build.memx(build.rp(4), { dispVal = 16 + i * vecBytes })
		-- Synthesized-frame slot: transform shifts its dispVal past the GC root area
		-- (roots must occupy [16, 16+8*numRoots) for the Fil-C GC).
		slot.frameSlot = true
		if isRestore then
			return build.insn(vecSaveMnem, { vreg, slot }, {})
		end
		return build.insn(vecSaveMnem, { slot, vreg }, {})
	end
	function cg.fpSave()
		if not vecSaveMnem then return end  -- no vector state the runtime could clobber
		for i = 0, 15 do emit(vecSaveInsn(false, i)) end
	end
	function cg.fpRestore()
		if not vecSaveMnem then return end
		for i = 0, 15 do emit(vecSaveInsn(true, i)) end
	end

	local function stackOff(base, disp)
		if not base then return nil end
		if base.rc == "sp" then return disp end
		if fctx and fctx.usesFp and base.name == "rbp" then return fctx.frameSize + disp end
		return nil  -- not a stack base (e.g. rbp as an ordinary GPR with frame-pointer omission)
	end
	function cg.regionRedirect(node, regionOf)
		-- A materialized FP frame-slot operand (disp(%rsp) into sarcasm's synthesized
		-- frame) is NOT an input-frame access; its positive offset can numerically
		-- coincide with an alloca-region frame offset. Never redirect/reject it.
		local fsmem = M.memOperand(node.stmt)
		if fsmem and fsmem.frameSlot then return false end
		local m = isa.baseMnemonic(string.lower(node.stmt.mnemonic))
		local ops = node.stmt.operands
		if m == "lea" then
			local mem = M.memOperand(node.stmt)
			if mem and not mem.index and not mem.dispSym then
				local off = stackOff(mem.base, mem.dispVal or 0)
				local r = off and regionOf(off)
				if r then
					local rd = node.defTemps[1]
					cg.addImm(rd, r.ptrTemp, off - r.base)
					pf.isPtr[rd] = true; pf.lowerTemp[rd] = r.loTemp
					return true
				end
			end
		end
		if m == "mov" and ops[1] and ops[1].kind == "reg" and ops[1].rc ~= "sp"
			and ops[2] and ops[2].rc == "sp" then
			local r = regionOf(0)
			if r then
				local rd = node.defTemps[1]
				-- rsp+0 redirected into the region: buffer + (0 - base), NOT buffer + 0.
				cg.addImm(rd, r.ptrTemp, -r.base)
				pf.isPtr[rd] = true; pf.lowerTemp[rd] = r.loTemp
				return true
			end
		end
		local mem = M.memOperand(node.stmt)
		if mem and not mem.dispSym then
			local off = stackOff(mem.base, mem.dispVal or 0)
			if off and regionOf(off) then
				error("sarcasm: direct stack-relative memory access into an alloca region is not supported: " .. node.stmt.raw)
			end
		end
		return false
	end

	-- passthrough special-casing: cltq -> renameable movslq on the rax web; lea does not
	-- access memory (its [mem] is an address computation), so pass it through unchecked.
	-- Memory-neutral hints (prefetch*) also pass through with no access check.
	function cg.lowerSpecial(node, mem)
		-- A materialized FP frame-slot operand is a real disp(%rsp) into sarcasm's
		-- own synthesized frame: the access is always in-bounds (the frame contains
		-- its own slots), so it needs no access check — pass the instruction
		-- through untouched. (`;! load/store ptr` on a stack access was already
		-- rejected by the frame rewrite; keep a defensive copy here.)
		if mem and mem.frameSlot then
			local ann = node.stmt.annotation
			if ann and sig.PTR_ANNOTATIONS[ann] then
				error("sarcasm: `;! " .. ann .. "` on a stack-frame access is not supported"
					.. " (frame slots are virtualized/materialized, not real memory): "
					.. (node.stmt.raw or "?"))
			end
			emit(node); return true
		end
		local base = isa.baseMnemonic(node.stmt.mnemonic)
		local fpe = fp.lookup(string.lower(node.stmt.mnemonic))
		if fpe and fpe.noCheck then emit(node); return true end
		-- fnstsw/fstsw with a register destination write ONLY %ax (the encoding is
		-- hardwired): pin the access to physical rax and copy out, rather than
		-- letting regalloc rename the operand into an invalid `fnstsw %dx`.
		if (base == "fnstsw" or base == "fstsw") and node.stmt.operands[1]
			and node.stmt.operands[1].kind == "reg" and node.stmt.operands[1].rc == "gpr" then
			local t = node.defTemps and node.defTemps[1]
			emit(build.insn(node.stmt.mnemonic, { build.rp(0, 16) }, { defs = { pColored(0) } }))
			if t then cg.move(t, pColored(0), true) end
			return true
		end
		if base == "cltq" then
			local t = node.defTemps and node.defTemps[1]
			if t then emit(build.insn("movslq", { rt(t, 64), rt(t, 32) }, { defs = {t}, uses = {t} })) else emit(node) end
			return true
		elseif base == "cbw" then
			local t = node.defTemps and node.defTemps[1]
			if t then emit(build.insn("movsbw", { rt(t, 16), rt(t, 8) }, { defs = {t}, uses = {t} })) else emit(node) end
			return true
		elseif base == "cwde" then
			local t = node.defTemps and node.defTemps[1]
			if t then emit(build.insn("movswl", { rt(t, 32), rt(t, 16) }, { defs = {t}, uses = {t} })) else emit(node) end
			return true
		elseif base == "lea" then
			emit(node); return true
		end
		return false
	end

	-- Implicit-GPR pinning (div/idiv/mul/1-op imul, mulx, cmpxchg, cqo/cdq/cwd).
	-- These instructions read and/or write physical rax/rdx beyond what their
	-- explicit operands say; classify names those effects with implicit def/use
	-- operand tables (recorded in node.c.pin), so the lift's web analysis
	-- connects them to the surrounding code. We then pin the implicit registers
	-- to the physical registers with synthesized moves AROUND the instruction —
	-- exactly the way the fnstsw->rax pin and the calling-convention boundary
	-- copies work: before the instruction, copy the CURRENT webs of the
	-- implicit-use registers into their physical registers; after it, copy the
	-- physical registers back out into the fresh webs that the lift made the
	-- reaching defs for subsequent reads of rax/rdx. The instruction keeps only
	-- its explicit operands in the emitted text; its def/use temp lists (what
	-- regalloc sees) reference the precolored physical temps for the implicit
	-- registers, so the register allocator colors everything else AROUND the
	-- fixed rax/rdx effects. Regalloc coalescing makes the pin moves free in
	-- the common case (the user just wrote rax/rdx).
	--
	-- An explicit operand that NAMES a pinned register (cmpxchg %rsi, %rax;
	-- mulxq %rsi, %rdx, %rax; idiv %rdx) is rendered as the FIXED physical
	-- register: renaming it would desync it from the implicit pin (its web's
	-- value flows through the physical register via the pin-in/pin-out copies,
	-- so the semantics stay correct either way).
	--
	-- Called by the transform wherever a plain node would be emitted (with or
	-- without a preceding access check); returns false for unpinned nodes.
	function cg.emitPinned(node)
		local c = node.c
		local pin = c and c.pin
		if not pin then return false end
		local pinnedNums = {}
		for _, r in (pin.uses or {}) do pinnedNums[r.num] = true end
		for _, r in (pin.defs or {}) do pinnedNums[r.num] = true end
		-- private opTemp copy (spill rewriting mutates it in place)
		local opT = {}
		for k, v in (node.opTemp or {}) do opT[k] = v end
		-- pin-in: every modeled use of a pinned register (an implicit table or an
		-- explicit operand naming the register) gets its reaching web copied into
		-- the physical register. (Same-web duplicates collapse: the lift keys use
		-- webs by register number.)
		local moved = {}
		for _, r in (c.uses or {}) do
			if pinnedNums[r.num] and not moved[r.num] then
				moved[r.num] = true
				local t = opT[r]
				if t then cg.move(pColored(r.num), t, true) end
			end
		end
		-- the pinned instruction itself
		local defTemps, useTemps, newops = {}, {}, {}
		for _, o in (node.stmt.operands or {}) do
			if o.kind == "reg" and o.rc == "gpr" and pinnedNums[o.num] then
				table.insert(newops, build.rp(o.num, o.width))
			else
				table.insert(newops, o)
			end
		end
		for _, r in (c.uses or {}) do
			local t = pinnedNums[r.num] and pColored(r.num) or opT[r]
			if t then table.insert(useTemps, t) end
		end
		for _, r in (c.defs or {}) do
			local t = pinnedNums[r.num] and pColored(r.num) or opT[r]
			if t then table.insert(defTemps, t) end
		end
		emit({
			kind = "insn", synth = true, mnemonic = node.stmt.mnemonic,
			operands = newops, opTemp = opT,
			defTemps = defTemps, useTemps = useTemps,
			control = "none", fallsThrough = true,
			lockPrefix = node.stmt.lockPrefix,  -- `lock cmpxchg...` rides through the pin
		})
		-- pin-out: every modeled def of a pinned register gets the physical
		-- register copied out into its fresh web (the reaching def for all
		-- subsequent reads of that register).
		local outDone = {}
		for _, r in (c.defs or {}) do
			local t = opT[r]
			if pinnedNums[r.num] and t and not outDone[t] then
				outDone[t] = true
				cg.move(t, pColored(r.num), true)
			end
		end
		return true
	end
	function cg.checkMemInsn(node, mem) end  -- x86: any memory operand is a real access

	-- one access-check-fail stub, appended to `list` (arch-specific arg regs + rip origin).
	function cg.failStub(list, lbl, ivTemp, loTemp, acoSym)
		local a1, a2, a3 = M.cc.rtArg(1), M.cc.rtArg(2), M.cc.rtArg(3)
		table.insert(list, build.label(lbl))
		table.insert(list, build.insn("mov", { build.rp(a1), rt(ivTemp) }, { defs = { pColored(a1) }, uses = {ivTemp} }))
		if loTemp then
			table.insert(list, build.insn("mov", { build.rp(a2), rt(loTemp) }, { defs = { pColored(a2) }, uses = {loTemp} }))
		else
			table.insert(list, build.insn("mov", { build.rp(a2), build.imm(0) }, { defs = { pColored(a2) } }))
		end
		table.insert(list, build.insn("lea", { build.rp(a3), build.memx({ kind = "reg", rc = "rip" }, { dispSym = acoSym }) },
			{ defs = { pColored(a3) } }))
		table.insert(list, build.insn("call", { build.sym("filc_optimized_access_check_fail", "plt") },
			{ control = "call", uses = { pColored(a1), pColored(a2), pColored(a3) } }))
	end

	-- Fail stub for an alignment failure the optimized-access-check origin cannot
	-- express (an alignment wider than a word — cmpxchg16b's 16): the origin's
	-- recorded alignment is word-clamped, so filc_optimized_access_check_fail
	-- could not attribute an in-bounds, writable, word-aligned-but-not-fully-
	-- aligned pointer to ANY failure and would hit its "Should not be reached"
	-- assert (a pas crash, not a clean trap). filc_check_aligned_access_fail
	-- takes the TRUE alignment as a plain argument and reports it ("alignment
	-- requirement of 16 bytes not met during write") via the usual filc safety
	-- panic. Machine-level args: (ptr iv, ptr lower, bytes, alignment, kind,
	-- ptr_name iv, ptr_name lower) — kind is filc_access_kind (0=read, 1=write);
	-- the 7th word (ptr_name's lower) is marshalled on the stack at [rsp] AT the
	-- call, exactly like pushStackPtr (a NULL ptr_name iv makes the runtime
	-- ignore the name, so the lower's value is never consulted — write 0 anyway).
	function cg.alignFailStub(list, lbl, ivTemp, loTemp, size, align, isWrite)
		local a1, a2, a3 = M.cc.rtArg(1), M.cc.rtArg(2), M.cc.rtArg(3)
		local a4, a5, a6 = M.cc.rtArg(4), M.cc.rtArg(5), M.cc.rtArg(6)
		table.insert(list, build.label(lbl))
		table.insert(list, build.insn("mov", { build.rp(a1), rt(ivTemp) }, { defs = { pColored(a1) }, uses = {ivTemp} }))
		if loTemp then
			table.insert(list, build.insn("mov", { build.rp(a2), rt(loTemp) }, { defs = { pColored(a2) }, uses = {loTemp} }))
		else
			table.insert(list, build.insn("mov", { build.rp(a2), build.imm(0) }, { defs = { pColored(a2) } }))
		end
		table.insert(list, build.insn("mov", { build.rp(a3), build.imm(size) }, { defs = { pColored(a3) } }))
		table.insert(list, build.insn("mov", { build.rp(a4), build.imm(align) }, { defs = { pColored(a4) } }))
		table.insert(list, build.insn("mov", { build.rp(a5), build.imm(isWrite and 1 or 0) }, { defs = { pColored(a5) } }))
		table.insert(list, build.insn("mov", { build.rp(a6), build.imm(0) }, { defs = { pColored(a6) } }))
		local nameLoSlot = build.memx(build.rp(4), { dispVal = -16 })
		nameLoSlot.size = 8  -- lets the renderer synthesize the movq suffix for the reg-less form
		table.insert(list, build.insn("mov", { nameLoSlot, build.imm(0) }, {}))
		table.insert(list, build.insn("sub", { build.rp(4), build.imm(16) }, {}))
		table.insert(list, build.insn("call", { build.sym("filc_check_aligned_access_fail", "plt") },
			{ control = "call", uses = { pColored(a1), pColored(a2), pColored(a3),
				pColored(a4), pColored(a5), pColored(a6) } }))
	end

	return cg
end

return M
