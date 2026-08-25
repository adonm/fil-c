--!nonstrict
-- x86_64 instruction semantics: classify a parsed (dest-first, syntax-normalized)
-- instruction into register defs/uses and control flow. Operands come from x86parse
-- (already normalized to destination-first, so ops[1] is the destination).

local fp = require("./x86_64_fp")

local x86 = {}

-- Normalize a mnemonic to its base operation (strip AT&T size suffix; unify movz*/movs*).
local BASE = {}
for _, m in { "mov","add","sub","and","or","xor","sal","shl","sar","shr","cmp","test",
	"lea","imul","inc","dec","neg","not","push","pop","adc","sbb","mul","idiv","div","ror","rol" } do
	BASE[m] = m
	BASE[m .. "b"] = m; BASE[m .. "w"] = m; BASE[m .. "l"] = m; BASE[m .. "q"] = m
end
local FIXED = {
	movabs = "mov", movabsq = "mov",
	movzx = "movzx", movsx = "movsx", movsxd = "movsx",
	movzbl = "movzx", movzbw = "movzx", movzbq = "movzx", movzwl = "movzx", movzwq = "movzx",
	movsbl = "movsx", movsbw = "movsx", movsbq = "movsx", movswl = "movsx", movswq = "movsx",
	movslq = "movsx",
	cltq = "cltq", cdqe = "cltq", cqo = "cqo", cqto = "cqo",
	-- the rest of the sign-extension family (single-reg forms behave like cltq;
	-- the dx-writing forms are pinned implicit-GPR instructions, see classify)
	cbw = "cbw", cbtw = "cbw", cwde = "cwde", cwtl = "cwde",
	cwd = "cwd", cwtd = "cwd", cdq = "cdq", cltd = "cdq",
	-- implicit-GPR families modeled by classify's pinned branches
	mulx = "mulx", mulxl = "mulx", mulxq = "mulx",
	cmpxchg = "cmpxchg", cmpxchgb = "cmpxchg", cmpxchgw = "cmpxchg",
	cmpxchgl = "cmpxchg", cmpxchgq = "cmpxchg",
	endbr64 = "nop", nop = "nop", ud2 = "ud2", ret = "ret", retq = "ret", leave = "leave",
	call = "call", callq = "call", jmp = "jmp", jmpq = "jmp",
}
function x86.baseMnemonic(m)
	m = string.lower(m)
	if FIXED[m] then return FIXED[m] end
	if BASE[m] then return BASE[m] end
	-- conditional jumps: je/jne/jb/jae/ja/jbe/jl/jge/jg/jle/js/jns/jc/jnc/jz/jnz/jo/jno/jp/jnp
	if string.match(m, "^j%a+$") then return "jcc" end
	if string.match(m, "^set%a+$") then return "setcc" end
	if string.match(m, "^cmov%a+$") then return "cmov" end
	return m
end

local ALU2 = { add=true, sub=true, ["and"]=true, ["or"]=true, xor=true, sal=true, shl=true,
	sar=true, shr=true, imul=true, adc=true, sbb=true, ror=true, rol=true }
local FLAGS_ONLY = { cmp=true, test=true }
local DST_ONLY = { inc=true, dec=true, neg=true, ["not"]=true }
-- condition -> whether it's an unsigned/eq branch we generate; classify only needs control.
local COND_JMP = { jcc = true }

-- Label-target control mnemonics baseMnemonic does NOT map to jcc (jcxz/jecxz/
-- jrcxz already match ^j%a+$): their bare symbol operand is a code target, never
-- an absolute memory operand, so the moffs rejection below exempts them.
local LABEL_TARGET_MNEM = { loop = true, loope = true, loopz = true, loopne = true,
	loopnz = true, xbegin = true }

local function isGpr(op) return op and op.kind == "reg" and op.rc == "gpr" end

local function memRegs(op, uses)
	if op.base and isGpr(op.base) then table.insert(uses, op.base) end
	if op.index and isGpr(op.index) then table.insert(uses, op.index) end
end

-- Classify. Returns { defs, uses, rmw, control, targets, fallsThrough }.
function x86.classify(insn)
	-- Unsafe instructions (syscall/privileged/port-I/O/string-ops/prefixes/cr-dr
	-- moves) are rejected here, BEFORE baseMnemonic mapping (e.g. `movsq` would
	-- otherwise map to `mov`), and FP/SIMD/x87 instructions get their def/use
	-- modeling from the fp knowledge module (GPR operands only; xmm-class
	-- registers are deliberately never modeled).
	local rawMnem = string.lower(insn.mnemonic)
	local why = fp.unsafeReject(rawMnem, insn)
	if why then error("sarcasm: " .. why .. ": " .. (insn.raw or rawMnem)) end

	local m = x86.baseMnemonic(insn.mnemonic)
	local ops = insn.operands or {}

	-- Absolute-address (moffs) operands: a bare (non-$-prefixed) symbol or a bare
	-- numeric literal operand is, in gas's dialects, an ABSOLUTE MEMORY operand,
	-- not a value: `movq %rsi, myglobal` stores 8 bytes to the global, `addq
	-- myglobal, %rax` reads it, and `movq 0x600000, %rax` LOADS from that address
	-- (the AT&T parser tags such numeric literals with absAddr; the $-spelling is
	-- the immediate). Gas's Intel syntax gives a bare symbol the same moffs
	-- reading (`mov rsi, myglobal` loads — verified against `as`: it emits an
	-- R_X86_64_32S absolute relocation); only a bare NUMBER is an immediate
	-- there, and the Intel parser never tags it. No capability covers such an
	-- access, so it cannot be bounds-checked — the same class as a symbolic
	-- displacement (rejected by codegen.computeAddr) — but the parser does not
	-- surface it as a mem operand, so reject it here rather than passing it
	-- through unchecked (or worse, rendering the numeric form as an immediate
	-- move — a silent load-to-imm rewrite). This fires for every operand
	-- position (load, store, ALU source, push/pop) — and, via the `*` indirect
	-- marker overriding the codeTarget exemption below, for indirect-branch
	-- memory operands (`jmp *myglobal` & co) — and runs before fp.classify
	-- so FP/vector forms (`movss myglobal, %xmm0`) get the same rejection.
	-- Exempt mnemonics whose bare operand is a CODE target or not memory at all:
	-- call/jmp/jcc (incl. numeric local labels, which numlabel already rewrote
	-- to plain syms), the loop*/xbegin label forms, `int` (its operand is the
	-- immediate vector, not an address), and lea (address arithmetic — no
	-- dereference; `leaq myglobal, %rax` materializes the address as a value,
	-- like the supported `leaq myglobal(%rip), %rax`).
	local codeTarget = m == "call" or m == "jmp" or m == "jcc" or m == "lea"
		or rawMnem == "int" or LABEL_TARGET_MNEM[rawMnem]
	for _, o in ops do
		-- The exemption is about operands that NAME a code target; an
		-- operand-level indirect marker (`*`) on a sym/absolute operand is an
		-- indirect branch THROUGH an absolute memory operand (`jmp *myglobal`
		-- jumps to the qword stored AT myglobal): the same un-checkable
		-- absolute-read class as every other moffs form — and for jcc there is
		-- no indirect encoding at all (rendering would silently emit the DIRECT
		-- branch). So the flag overrides the exemption. Register- and
		-- register-based-memory indirect branches (`jmp *%rdi`, `call
		-- *(%rax,%rcx,8)`) are reg/mem operands, untouched here.
		if not codeTarget or o.indirect then
			if o.kind == "sym" then
				-- Segment-register operands (%gs / gs) parse as bare symbols (the
				-- parser does not classify segment registers); a move to/from one
				-- (`movw %gs, %cx`) is a register move, never an absolute memory
				-- operand. The pattern follows the input syntax, so a bare AT&T
				-- symbol merely NAMED gs/fs/... is still treated as an address.
				-- (cr/dr register moves were already rejected by unsafeReject.)
				-- The `*` marker on a segment-register spelling is never valid,
				-- so this exemption does not apply to indirect-marked operands.
				local t = string.lower(o.text)
				local seg
				if not o.indirect then
					if insn.syntax == "intel" then seg = string.match(t, "^[cdefgs]s$")
					else seg = string.match(t, "^%%[cdefgs]s$") end
				end
				if not seg then
					error("sarcasm: memory access with a symbolic address cannot be"
						.. " bounds-checked (global data access is not yet supported): "
						.. (insn.raw or rawMnem))
				end
			end
			if o.kind == "imm" and o.absAddr then
				error("sarcasm: memory access with an absolute address cannot be"
					.. " bounds-checked (global data access is not yet supported): "
					.. (insn.raw or rawMnem))
			end
		end
	end

	local fpc = fp.classify(insn)
	if fpc then return fpc end
	local defs, uses, rmw = {}, {}, {}
	local control, targets, fallsThrough = "none", nil, true

	local function useOperand(o)
		if isGpr(o) then table.insert(uses, o) elseif o and o.kind == "mem" then memRegs(o, uses) end
	end

	if m == "jmp" then
		control, fallsThrough = "branch", false
		targets = {}
		for _, o in ops do if o.kind == "sym" then table.insert(targets, o.text) end end
		if ops[1] and (isGpr(ops[1]) or (ops[1].kind == "mem")) then control = "indirect"; useOperand(ops[1]) end
	elseif m == "jcc" then
		control = "condbranch"; targets = {}
		for _, o in ops do if o.kind == "sym" then table.insert(targets, o.text) end end
	elseif m == "call" then
		control = "call"
		if ops[1] and (isGpr(ops[1]) or ops[1].kind == "mem") then control = "indcall"; useOperand(ops[1]) end
	elseif m == "ret" then
		control, fallsThrough = "return", false
	elseif m == "nop" or m == "ud2" or m == "leave" then
		-- no gpr effects we model (leave restores rsp/rbp; frame handled elsewhere)
	elseif m == "cltq" or m == "cbw" or m == "cwde" then
		-- single-register sign extension (al->ax / ax->eax / eax->rax): an RMW of
		-- the rax web; codegen's lowerSpecial rewrites it to a renameable movsxx.
		table.insert(defs, { kind="reg", rc="gpr", num=0, width=64, name="rax" })
		table.insert(uses, { kind="reg", rc="gpr", num=0, width=64, name="rax" })
		table.insert(rmw, 0)
	elseif m == "cqo" or m == "cdq" or m == "cwd" then
		-- sign-extend the accumulator into the paired dx register (rax->rdx:rax,
		-- eax->edx:eax, ax->dx:ax): implicit USE of rax, implicit DEF of rdx,
		-- pinned to the physical registers by codegen's emitPinned (regalloc must
		-- not rename either side, or the extension silently reads/writes the
		-- wrong webs — this is the div/idiv setup idiom).
		-- NB: every implicit operand OCCURRENCE is a fresh table — the lift keys
		-- node.opTemp by table identity, so a def table and a use table for the
		-- same register must never be shared (the use's temp would clobber the
		-- def's in opTemp and the pin-out copy would write the wrong web).
		local axU = { kind="reg", rc="gpr", num=0, width=64, name="rax", implicit=true }
		local dxD = { kind="reg", rc="gpr", num=2, width=64, name="rdx", implicit=true }
		table.insert(uses, axU)
		table.insert(defs, dxD)
		return { defs = defs, uses = uses, rmw = rmw, control = "none", fallsThrough = true,
			pin = { uses = { axU }, defs = { dxD } } }
	elseif m == "div" or m == "idiv" or m == "mul" or (m == "imul" and #ops == 1) then
		-- One-operand multiply/divide: the explicit operand is the divisor /
		-- multiplicand (a use); the accumulator pair rdx:rax is an implicit
		-- operand the def/use model must name, or regalloc will color those webs
		-- elsewhere and the dividend/quotient silently corrupts. The implicit
		-- registers are pinned to the physical registers by codegen's emitPinned:
		-- the reaching webs are copied into physical rax/rdx before the
		-- instruction and the result webs are copied back out after it
		-- (coalescing makes the copies free when the user already had the values
		-- in rax/rdx — the common case).
		--   div/idiv: dividend rdx:rax (uses both), quotient rax + remainder rdx
		--     (defs both). The 8-bit form uses/defs AX alone — modeled as rax.
		--   mul/imul: multiplicand rax (use), product rdx:rax (defs both). The
		--     8-bit form uses AL and defs AX — both modeled as rax alone.
		-- (2/3-operand imul has NO implicit effects and keeps the ALU2 model.)
		local w = insn.opsize
		if not w then
			for _, o in ops do
				if isGpr(o) then w = math.max(1, math.floor((o.width or 64) / 8)) break end
			end
		end
		if not w then
			for _, o in ops do
				if o and o.kind == "mem" and o.size then w = o.size break end
			end
		end
		if not w then
			error("sarcasm: cannot determine the memory access width of '" .. rawMnem
				.. "' (unsized memory operand is ambiguous; use a size suffix or PTR annotation): "
				.. (insn.raw or rawMnem))
		end
		for _, o in ops do useOperand(o) end
		-- fresh table per implicit occurrence (see the cqo comment above)
		local function imp(num)
			return { kind="reg", rc="gpr", num=num, width=w * 8,
				name = (num == 0) and "rax" or "rdx", implicit=true }
		end
		local pin
		if w == 1 then
			local axU, axD = imp(0), imp(0)
			table.insert(uses, axU); table.insert(defs, axD)
			pin = { uses = { axU }, defs = { axD } }
		elseif m == "mul" or m == "imul" then
			local axU, axD, dxD = imp(0), imp(0), imp(2)
			table.insert(uses, axU)
			table.insert(defs, axD); table.insert(defs, dxD)
			pin = { uses = { axU }, defs = { axD, dxD } }
		else
			local axU, dxU, axD, dxD = imp(0), imp(2), imp(0), imp(2)
			table.insert(uses, axU); table.insert(uses, dxU)
			table.insert(defs, axD); table.insert(defs, dxD)
			pin = { uses = { axU, dxU }, defs = { axD, dxD } }
		end
		return { defs = defs, uses = uses, rmw = rmw, control = "none", fallsThrough = true, pin = pin }
	elseif m == "mulx" then
		-- BMI2 MULX dst1, dst2, src2: dst1:dst2 = rdx * src2 — rdx is an implicit
		-- SOURCE (pinned in by emitPinned, like the div family) but is NOT
		-- written; both explicit destinations are ordinary renameable defs. (The
		-- conservative first-reg-def model was wrong twice over: the second
		-- destination was unmodeled and the implicit rdx use invisible.)
		local dx = { kind="reg", rc="gpr", num=2, width=64, name="rdx", implicit=true }
		if isGpr(ops[1]) then table.insert(defs, ops[1]) end
		if isGpr(ops[2]) then table.insert(defs, ops[2]) end
		for i = 3, #ops do useOperand(ops[i]) end
		table.insert(uses, dx)
		return { defs = defs, uses = uses, rmw = rmw, control = "none", fallsThrough = true,
			pin = { uses = { dx }, defs = {} } }
	elseif m == "cmpxchg" then
		-- CMPXCHG dest, src: the accumulator (al/ax/eax/rax by size) is an
		-- implicit read-modify-write operand (compared with dest; overwritten
		-- with dest on mismatch), the explicit dest is an RMW, src a use. The
		-- accumulator is pinned to physical rax by emitPinned. (cmpxchg8b/16b
		-- stay rejected by the fp table — they have the paired-register forms.)
		local w = insn.opsize
		if not w then
			for _, o in ops do
				if isGpr(o) then w = math.max(1, math.floor((o.width or 64) / 8)) break end
			end
		end
		-- fresh table per implicit accumulator occurrence (see the cqo comment)
		local accU = { kind="reg", rc="gpr", num=0, width=(w or 64) * 8, name="rax", implicit=true }
		local accD = { kind="reg", rc="gpr", num=0, width=(w or 64) * 8, name="rax", implicit=true }
		if isGpr(ops[1]) then
			table.insert(defs, ops[1]); table.insert(uses, ops[1]); table.insert(rmw, ops[1].num)
		elseif ops[1] and ops[1].kind == "mem" then
			memRegs(ops[1], uses)
		end
		for i = 2, #ops do useOperand(ops[i]) end
		table.insert(uses, accU); table.insert(defs, accD)
		return { defs = defs, uses = uses, rmw = rmw, control = "none", fallsThrough = true,
			pin = { uses = { accU }, defs = { accD } } }
	elseif FLAGS_ONLY[m] then
		for _, o in ops do useOperand(o) end
	elseif ALU2[m] then
		-- dst = dst OP src : ops[1] is def+use, rest are uses
		if isGpr(ops[1]) then table.insert(defs, ops[1]); table.insert(uses, ops[1]); table.insert(rmw, ops[1].num)
		elseif ops[1] and ops[1].kind == "mem" then memRegs(ops[1], uses) end
		for i = 2, #ops do useOperand(ops[i]) end
	elseif DST_ONLY[m] then
		if isGpr(ops[1]) then table.insert(defs, ops[1]); table.insert(uses, ops[1]); table.insert(rmw, ops[1].num)
		elseif ops[1] and ops[1].kind == "mem" then memRegs(ops[1], uses) end
	elseif m == "mov" or m == "movzx" or m == "movsx" or m == "lea" or m == "cmov" or m == "setcc" then
		-- ops[1] def, ops[2..] use (mem regs used); a store (mem dst) uses the value instead.
		if isGpr(ops[1]) then table.insert(defs, ops[1])
		elseif ops[1] and ops[1].kind == "mem" then memRegs(ops[1], uses) end
		if (ops[1] and ops[1].kind == "mem") and isGpr(ops[2]) then table.insert(uses, ops[2]) end
		if m == "cmov" and isGpr(ops[1]) then table.insert(uses, ops[1]); table.insert(rmw, ops[1].num) end
		for i = 2, #ops do
			local o = ops[i]
			if o and o.kind == "mem" then memRegs(o, uses)
			elseif isGpr(o) and not (ops[1] and ops[1].kind == "mem") then table.insert(uses, o) end
		end
	elseif m == "push" then
		useOperand(ops[1])
	elseif m == "pop" then
		if isGpr(ops[1]) then table.insert(defs, ops[1]) end
	else
		-- Unknown mnemonic. With a memory operand there is no way to determine the
		-- access width, so any default-width bounds check is unsound (enqcmd's m512
		-- source, an unknown vector load, a gather/scatter spelling the fp table
		-- missed, ...): reject. Register-only unknown forms still pass through with
		-- the conservative first-reg-def model below.
		for _, o in ops do
			if o.kind == "mem" then
				error("sarcasm: cannot determine the memory access width of '" .. rawMnem
					.. "' (cannot prove memory safety): " .. (insn.raw or rawMnem))
			end
		end
		-- unknown: conservative (first reg def, rest use)
		local first = true
		for _, o in ops do
			if isGpr(o) then
				if first then table.insert(defs, o); first = false else table.insert(uses, o) end
			elseif o and o.kind == "mem" then memRegs(o, uses) end
		end
		return { defs = defs, uses = uses, rmw = rmw, control = "none", fallsThrough = true, unknown = true }
	end

	return { defs = defs, uses = uses, rmw = rmw, control = control, targets = targets, fallsThrough = fallsThrough }
end

x86.isGpr = isGpr

-- The register-defined memory access width (bytes) of a GPR instruction, or nil when
-- the instruction's memory width is NOT register-defined: the movzx/movsx narrowing
-- family and lea are size-driven/memory-neutral, and no-GPR-operand forms
-- (push/pop/call/jmp mem forms, inc/dec/neg/not mem-only forms) legitimately take
-- their width from the PTR annotation or AT&T suffix. Used by the heap path
-- (x86_64_codegen.accessSizeAlign) and the frame rewrite (x86_64_frame) to reject an
-- Intel PTR size annotation that CONTRADICTS the true access width — the emitted
-- instruction encodes the register width regardless of the annotation
-- (`mov WORD PTR [rdi], rax` stores 8 bytes, not 2).
function x86.gprAccessRegWidth(stmt)
	local b = x86.baseMnemonic(string.lower(stmt.mnemonic))
	if b == "lea" or b == "movzx" or b == "movsx" then return nil end
	if stmt.opsize then return stmt.opsize end
	for _, o in (stmt.operands or {}) do
		if isGpr(o) then return math.max(1, math.floor((o.width or 64) / 8)) end
	end
	return nil
end

-- Register/calling-convention configuration (SysV AMD64 + Fil-C fast entrypoint) -------
-- Reserved: rsp (stack), r11 (dedicated glue/epilogue scratch, like ARM x8).
-- Allocatable = the other 14 GPRs. rbp is allocatable (we synthesize rsp-relative frames).
x86.ALLOCATABLE = { "rax","rcx","rdx","rbx","rbp","rsi","rdi","r8","r9","r10","r12","r13","r14","r15" }
x86.CALLEE_SAVED = { rbx=true, rbp=true, r12=true, r13=true, r14=true, r15=true }
x86.CALLEE_SAVED_ORDER = { "rbx","rbp","r12","r13","r14","r15" }  -- push order (r15 pushed last)
x86.CALLER_SAVED = { rax=true, rcx=true, rdx=true, rsi=true, rdi=true, r8=true, r9=true, r10=true }
x86.SCRATCH = "r11"       -- non-allocatable glue scratch
x86.SCRATCH_NUM = 11
-- caller-saved register numbers clobbered by a call (used to model call defs).
x86.CALLER_SAVED_NUMS = { 0, 1, 2, 6, 7, 8, 9, 10 }

-- Fil-C fast-entrypoint calling convention (register numbers).
-- Args are packed DENSELY (a pointer-class arg occupies two consecutive slots --
-- intval, lower; a scalar-class arg occupies one slot, intval only), matching
-- pizlonated clang output. Clang's x86_64 fast CC has only FOUR dense argument
-- registers (rdx, rcx, r8, r9); arguments beyond the fourth word are passed on the
-- stack. sarcasm does not marshal stack arguments -- it rejects signatures needing
-- more than 4 register argument words (see sarcasm.luau / x86_64_codegen.luau), so
-- only the first four slots below are ever used.
local DENSE_ARG_REGS = { 2, 1, 8, 9, 10, 11 }  -- rdx, rcx, r8, r9, (r10, r11: unreachable)
local function denseArgSlot(argTypes, k)
	local slot = 1
	for i = 1, k - 1 do
		slot += (argTypes[i] == 7) and 2 or 1   -- 7 = TYPE_PTR (see sig.luau)
	end
	return slot
end
x86.CC = {
	myth = 7,       -- rdi
	fo = 6,         -- rsi
	argIv = function(argTypes, k) return DENSE_ARG_REGS[denseArgSlot(argTypes, k)] end,
	argLo = function(argTypes, k) return DENSE_ARG_REGS[denseArgSlot(argTypes, k) + 1] end,  -- ptr args only
	retFlag = 0,    -- al (rax)
	retIv = 2,      -- rdx
	retLo = 1,      -- rcx
}
-- SysV C-call argument registers: rdi, rsi, rdx, rcx, r8, r9.
x86.SYSV = { 7, 6, 2, 1, 8, 9 }

return x86
