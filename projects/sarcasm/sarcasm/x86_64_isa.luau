--!nonstrict
-- x86_64 instruction semantics: classify a parsed (dest-first, syntax-normalized)
-- instruction into register defs/uses and control flow. Operands come from x86parse
-- (already normalized to destination-first, so ops[1] is the destination).

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

local function isGpr(op) return op and op.kind == "reg" and op.rc == "gpr" end

local function memRegs(op, uses)
	if op.base and isGpr(op.base) then table.insert(uses, op.base) end
	if op.index and isGpr(op.index) then table.insert(uses, op.index) end
end

-- Classify. Returns { defs, uses, rmw, control, targets, fallsThrough }.
function x86.classify(insn)
	local m = x86.baseMnemonic(insn.mnemonic)
	local ops = insn.operands or {}
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
	elseif m == "cltq" or m == "cqo" then
		table.insert(defs, { kind="reg", rc="gpr", num=0, width=64, name="rax" })
		table.insert(uses, { kind="reg", rc="gpr", num=0, width=64, name="rax" })
		table.insert(rmw, 0)
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
