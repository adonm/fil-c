--!nonstrict
-- x86_64 Fil-C calling-convention glue (AT&T output): function getter, generic (buffer)
-- entrypoint thunk, FO object + origins, direct-call alias, and callsite resolver thunk.
-- Templates validated against the reference Fil-C clang x86_64 output (hash-filc-x86.s).
-- Data layout is identical to ARM64 (only .xword->.quad, .word->.long).

local glue_x86 = {}

local sig = require("./sig")

local FUNCTION_UPPER_FLAGS = "36873221949095936" -- 0x83 << 48

function glue_x86.getter(out, name)
	local fo = "pizlonatedFO_" .. name
	table.insert(out, "\t.text")
	table.insert(out, "\t.globl\tpizlonated_" .. name)
	table.insert(out, "\t.p2align\t4")
	table.insert(out, "\t.type\tpizlonated_" .. name .. ",@function")
	table.insert(out, "pizlonated_" .. name .. ":")
	table.insert(out, "\tleaq\t" .. fo .. "+16(%rip), %rax")
	table.insert(out, "\tmovq\t%rax, %rdx")
	table.insert(out, "\tretq")
	table.insert(out, ".Lfunc_end_getter_" .. name .. ":")
	table.insert(out, "\t.size\tpizlonated_" .. name .. ", .Lfunc_end_getter_" .. name .. "-pizlonated_" .. name)
	table.insert(out, "")
end

-- Dense fast-CC arg registers: (iv[, lo]) pairs packed consecutively; a scalar arg
-- consumes one slot, a pointer arg two. FLOAT/DOUBLE args consume NO GPR slot: they
-- pass in the vector registers xmm0..xmm7, in declaration order among the FP args
-- alone (a float in the low 32 bits, a double in the full 64), matching pizlonated
-- clang output (long(double,int,float,long): double->xmm0, int->rdx, float->xmm1,
-- long->rcx). Must stay in lockstep with denseArgSlot in x86_64_isa.luau.
-- Clang's x86_64 fast CC has only FOUR dense argument GPRs (rdx, rcx, r8, r9) --
-- wider arguments go on the stack, which sarcasm does not marshal; signatures
-- needing more than 4 GPR register argument words are rejected, so slots 5-6 below
-- are unreachable. FP args are bounded separately: at most 8 (xmm0..xmm7).
local DENSE_ARG_REGS = { "%rdx", "%rcx", "%r8", "%r9", "%r10", "%r11" }
local function denseArgRegs(argTypes, argWords)
	local ivReg, loReg = {}, {}
	local slot = 1
	for k = 1, argWords do
		if sig.isFpClass(argTypes[k]) then
			-- FP arg: passes in an xmm register, consumes no GPR slot
		elseif argTypes[k] == 7 then   -- TYPE_PTR
			ivReg[k] = DENSE_ARG_REGS[slot]
			loReg[k] = DENSE_ARG_REGS[slot + 1]
			slot += 2
		else
			ivReg[k] = DENSE_ARG_REGS[slot]
			slot += 1
		end
	end
	return ivReg, loReg
end

-- FP instruction form + xmm-register name of FP argument k: float = "movss" /
-- "%xmmN" (low 32 bits), double = "movsd" / "%xmmN" (64 bits); N = the argument's
-- 0-based ordinal among the FP args. Also used for the FP return (ordinal 0:
-- xmm0).
local function fpArgForm(argTypes, k)
	local w = sig.fpWidthBytes(argTypes[k])
		or error("sarcasm: internal error: FP register name for a non-FP argument " .. tostring(k))
	local m = 0
	for i = 1, k - 1 do
		if sig.isFpClass(argTypes[i]) then m += 1 end
	end
	return (w == 4 and "movss" or "movsd"), "%xmm" .. tostring(m)
end

-- Number of fast-CC GPR argument words a signature needs (ptr args = 2; FP args
-- pass in the xmm registers and consume none).
local function argRegWords(argTypes, argWords)
	local words = 0
	for k = 1, argWords do
		if not sig.isFpClass(argTypes[k]) then words += (argTypes[k] == 7) and 2 or 1 end
	end
	return words
end

-- generic (buffer) entrypoint pizlonated2ET<sig>.
function glue_x86.genericThunk(out, signature, argWords, retWords, retIsPtr, argTypes, retTypes)
	assert(argRegWords(argTypes, argWords) <= 4, "sarcasm: >4 register args not yet supported")
	local sym = "pizlonated2ET" .. tostring(signature)
	local argBytes = argWords * 8
	local retBytes = retWords * 8
	local L = ".LBB_2ET" .. signature
	local function e(s) table.insert(out, s) end
	-- dense CC iv/lo registers for arg k (1-based); lo only for pointer args. FP args
	-- have no GPR register (they load straight into their xmm registers).
	local ivReg, loReg = denseArgRegs(argTypes, argWords)
	local retFpForm, retFpReg = nil, nil
	if retTypes and retTypes[1] and sig.isFpClass(retTypes[1]) then
		retFpForm, retFpReg = fpArgForm(retTypes, 1)
	end
	e("\t.text")
	e("\t.weak\t" .. sym)
	e("\t.p2align\t4")
	e("\t.type\t" .. sym .. ",@function")
	e(sym .. ":")
	e("\tpushq\t%rbx")
	-- args-size check: actual (rdx) must be >= expected argBytes. Skipped for a zero-arg
	-- signature (argBytes - 1 == -1 would make the unsigned jbe ALWAYS fail — every actual
	-- size is <= -1); clang's zero-arg 2ET thunk has no check either, and the weak symbol
	-- must be link-compatible with clang's (any caller may pass extra argument words).
	if argBytes > 0 then
		e("\tcmpq\t$" .. tostring(argBytes - 1) .. ", %rdx")
		e("\tjbe\t" .. L .. "_fail")
	end
	e("\tmovq\t%rdi, %rbx")
	-- load args from the per-argument buffer slots (iv at 128+8i, lower at 384+8i)
	-- into the densely packed CC registers; FP args load into their xmm registers
	-- (declaration order among the FP args), also from 128+8i (a float loads the
	-- low 4 bytes of the 8-byte slot).
	for i = 0, argWords - 1 do
		local k = i + 1
		if sig.isFpClass(argTypes[k]) then
			local form, reg = fpArgForm(argTypes, k)
			e("\t" .. form .. "\t" .. tostring(128 + 8 * i) .. "(%rdi), " .. reg)
		else
			e("\tmovq\t" .. tostring(128 + 8 * i) .. "(%rdi), " .. ivReg[i + 1])
			if loReg[i + 1] then
				e("\tmovq\t" .. tostring(384 + 8 * i) .. "(%rdi), " .. loReg[i + 1])
			end
		end
	end
	e("\tcallq\t*(%rsi)")
	e("\ttestb\t$1, %al")
	e("\tjne\t" .. L .. "_exc")
	if retWords >= 1 then
		if retFpForm then
			-- FP return: the fast entrypoint left the value in xmm0 (the movss/movsd
			-- form: a float stores the low 4 bytes of the buffer word); the aux word
			-- (the return's "lower") is zero and the ret size stays 8.
			-- (filcc additionally emits `movl $0, 132(%rbx)` for a float return,
			-- zeroing the upper half of the 128-slot buffer word, so this thunk is
			-- not byte-identical to filcc's. The omission is deliberate and
			-- unobserved: every FP reader uses a 4- or 8-byte access — movss/movsd
			-- — so the upper half of the slot is never read.)
			e("\t" .. retFpForm .. "\t" .. retFpReg .. ", 128(%rbx)")
			e("\tmovq\t$0, 384(%rbx)")
		else
			e("\tmovq\t%rdx, 128(%rbx)")
			if retIsPtr then e("\tmovq\t%rcx, 384(%rbx)") else e("\tmovq\t$0, 384(%rbx)") end
		end
	end
	e("\tmovl\t$" .. tostring(retBytes) .. ", %edx")
	e("\tpopq\t%rbx")
	e("\tretq")
	e(L .. "_exc:")
	e("\tpopq\t%rbx")
	e("\tretq")
	e(L .. "_fail:")
	e("\tmovl\t$" .. tostring(argBytes) .. ", %esi")
	e("\tmovq\t%rdx, %rdi")
	e("\txorl\t%edx, %edx")
	e("\tcallq\tfilc_cc_args_check_failure@PLT")
	e("\t.size\t" .. sym .. ", .-" .. sym)
	e("")
end

function glue_x86.foAndOrigins(out, name, signature, numRoots, dbg)
	local fo = "pizlonatedFO_" .. name
	local strSym = ".Lfilc_string_" .. name
	local fileSym = ".Lfilc_filename_" .. name
	local fnOrigin = ".Lfilc_function_origin_" .. name
	local origin = ".Lfilc_origin_" .. name

	table.insert(out, "\t.type\t" .. fo .. ",@object")
	table.insert(out, "\t.section\t.data.rel.ro,\"aw\",@progbits")
	table.insert(out, "\t.p2align\t4, 0x0")
	table.insert(out, fo .. ":")
	table.insert(out, "\t.quad\t" .. fo .. "+16")
	table.insert(out, "\t.quad\t(" .. fo .. "+16)+" .. FUNCTION_UPPER_FLAGS)
	table.insert(out, "\t.quad\tpizlonatedFIP" .. tostring(signature) .. "_" .. name)
	table.insert(out, "\t.quad\tpizlonated2ET" .. tostring(signature))
	table.insert(out, "\t.quad\t" .. tostring(signature))
	table.insert(out, "\t.size\t" .. fo .. ", 40")
	table.insert(out, "")

	table.insert(out, "\t.type\t" .. strSym .. ",@object")
	table.insert(out, "\t.section\t.rodata.str1.1,\"aMS\",@progbits,1")
	table.insert(out, strSym .. ":")
	table.insert(out, "\t.asciz\t\"" .. name .. "\"")
	table.insert(out, "\t.size\t" .. strSym .. ", " .. tostring(#name + 1))
	table.insert(out, "")

	if dbg then
		table.insert(out, "\t.type\t" .. fileSym .. ",@object")
		table.insert(out, "\t.section\t.rodata.str1.1,\"aMS\",@progbits,1")
		table.insert(out, fileSym .. ":")
		table.insert(out, "\t.asciz\t\"" .. dbg.filename .. "\"")
		table.insert(out, "\t.size\t" .. fileSym .. ", " .. tostring(#dbg.filename + 1))
		table.insert(out, "")
	end

	table.insert(out, "\t.type\t" .. fnOrigin .. ",@object")
	table.insert(out, "\t.section\t.data.rel.ro,\"aw\",@progbits")
	table.insert(out, "\t.p2align\t4, 0x0")
	table.insert(out, fnOrigin .. ":")
	table.insert(out, "\t.quad\t" .. strSym)
	table.insert(out, "\t.quad\t" .. (dbg and fileSym or "0"))
	table.insert(out, "\t.long\t" .. tostring(numRoots))
	table.insert(out, "\t.zero\t4")
	table.insert(out, "\t.quad\t0")
	table.insert(out, "\t.byte\t0")
	table.insert(out, "\t.byte\t0")
	table.insert(out, "\t.byte\t0")
	table.insert(out, "\t.zero\t1")
	table.insert(out, "\t.long\t0")
	table.insert(out, "\t.size\t" .. fnOrigin .. ", 40")
	table.insert(out, "")

	table.insert(out, "\t.type\t" .. origin .. ",@object")
	table.insert(out, "\t.p2align\t3, 0x0")
	table.insert(out, origin .. ":")
	table.insert(out, "\t.quad\t" .. fnOrigin)
	table.insert(out, "\t.long\t" .. tostring(dbg and dbg.funcLine or 0))
	table.insert(out, "\t.long\t0")
	table.insert(out, "\t.size\t" .. origin .. ", 16")
	table.insert(out, "")
end

function glue_x86.accessOrigin(out, sym, size, align, funcName, isWrite, dbg)
	local origin = ".Lfilc_origin_" .. funcName
	if dbg then
		origin = sym .. "_o"
		table.insert(out, "\t.type\t" .. origin .. ",@object")
		table.insert(out, "\t.section\t.data.rel.ro,\"aw\",@progbits")
		table.insert(out, "\t.p2align\t3, 0x0")
		table.insert(out, origin .. ":")
		table.insert(out, "\t.quad\t.Lfilc_function_origin_" .. funcName)
		table.insert(out, "\t.long\t" .. tostring(dbg.line or 0))
		table.insert(out, "\t.long\t0")
		table.insert(out, "\t.size\t" .. origin .. ", 16")
		table.insert(out, "")
	end
	table.insert(out, "\t.type\t" .. sym .. ",@object")
	table.insert(out, "\t.section\t.data.rel.ro,\"aw\",@progbits")
	table.insert(out, "\t.p2align\t4, 0x0")
	table.insert(out, sym .. ":")
	table.insert(out, "\t.long\t" .. tostring(size))
	table.insert(out, "\t.byte\t" .. tostring(align))
	table.insert(out, "\t.byte\t0")
	table.insert(out, "\t.byte\t" .. (isWrite and "1" or "0"))
	table.insert(out, "\t.zero\t1")
	table.insert(out, "\t.quad\t" .. origin)
	table.insert(out, "\t.quad\t" .. origin)
	table.insert(out, "\t.quad\t0")
	table.insert(out, "\t.size\t" .. sym .. ", 32")
	table.insert(out, "")
end

-- A plain 16-byte filc_origin record for the masked-access fail stubs (the
-- runtime's filc_masked_read/write_check_fail and filc_expand/compress fail
-- functions take a filc_origin*, not the 32-byte optimized-access-check origin).
-- Carries the access's line when -g is on, like accessOrigin's generic origin.
function glue_x86.maskedOrigin(out, sym, funcName, dbg)
	table.insert(out, "\t.type\t" .. sym .. ",@object")
	table.insert(out, "\t.section\t.data.rel.ro,\"aw\",@progbits")
	table.insert(out, "\t.p2align\t3, 0x0")
	table.insert(out, sym .. ":")
	table.insert(out, "\t.quad\t.Lfilc_function_origin_" .. funcName)
	table.insert(out, "\t.long\t" .. tostring(dbg and dbg.line or 0))
	table.insert(out, "\t.long\t0")
	table.insert(out, "\t.size\t" .. sym .. ", 16")
	table.insert(out, "")
end

function glue_x86.alias(out, name, signature)
	table.insert(out, "\t.globl\tpizlonatedFI" .. tostring(signature) .. "_" .. name)
	table.insert(out, "\t.type\tpizlonatedFI" .. tostring(signature) .. "_" .. name .. ",@function")
	table.insert(out, ".set pizlonatedFI" .. tostring(signature) .. "_" .. name
		.. ", pizlonatedFIP" .. tostring(signature) .. "_" .. name)
end

function glue_x86.originName(funcName) return ".Lfilc_origin_" .. funcName end

-- Callsite resolver thunk pizlonatedFI<sig>_NAME (weak/hidden), validated against the
-- reference Fil-C clang x86_64 output (test3.c -> pizlonatedFI2529_foo). Resolves the
-- callee's FO via pizlonated_NAME, validates it is a function object with the canonical
-- intval and matching signature, then tail-calls the fast entrypoint; on a signature
-- mismatch it marshals through the generic (buffer) CC.
--
-- FP arguments (float/double) ride in xmm0..xmm7 and are NEVER spilled by this thunk:
-- everything between entry and the two call sites — the register saves, the getter
-- (leaq/movq/retq), the object checks and the signature compare — touches GPRs only,
-- so on the fast path the FP args are still in their xmm registers when the tail call
-- consumes them, and on the generic path they are stored into the CC buffer straight
-- from there (each at its DECLARATION index, one 8-byte word; a float stores the low
-- 4 bytes and the aux word at 384+8i is zero). An FP return is loaded back from the
-- buffer word at [myth+128] into xmm0 (movss/movsd form) after the ret-size check;
-- the ret size stays 8.
function glue_x86.callsiteThunk(out, callee, sigDesc)
	local signum = sigDesc.signature
	local sym = "pizlonatedFI" .. tostring(signum) .. "_" .. callee
	local L = ".Lcsr_" .. callee .. "_" .. tostring(signum)
	-- incoming fast-call args arrive densely packed; lo registers only for ptr args.
	-- FP args arrive in their xmm registers (fpArgForm) and pass through unmodeled —
	-- ivReg[k] is nil for them.
	local ivReg, loReg = denseArgRegs(sigDesc.argTypes, sigDesc.argWords)
	local myth = "%rbx"
	local pool = { "%r12", "%r13", "%r14", "%r15" }
	-- Hold-pool capacity check: stashing the incoming CC across the resolver call takes
	-- one callee-saved hold per GPR argument word (two per pointer arg: intval + lower).
	-- FP args need no hold: they stay in the xmm registers. A signature needing more
	-- GPR words than the pool holds cannot be marshalled -- reject it cleanly rather
	-- than running off the end of the pool.
	local holdWords = 0
	for k = 1, sigDesc.argWords do
		if not sig.isFpClass(sigDesc.argTypes[k]) then
			holdWords += (sigDesc.argTypes[k] == 7) and 2 or 1
		end
	end
	if holdWords > #pool then
		error("sarcasm: callsite thunk for '" .. callee .. "': >" .. tostring(#pool)
			.. " register argument words not yet supported (this call's signature needs "
			.. tostring(holdWords) .. ")")
	end
	local nextHold = 1
	local args = {}
	for k = 1, sigDesc.argWords do
		if ivReg[k] then
			local isPtr = sigDesc.argTypes[k] == 7
			local ent = { iv = pool[nextHold], isPtr = isPtr }; nextHold += 1
			if isPtr then ent.lo = pool[nextHold]; nextHold += 1 end
			args[k] = ent
		end
	end
	local argBytes = sigDesc.argWords * 8
	local retBytes = sigDesc.retWords * 8
	local retFpForm, retFpReg = nil, nil
	if sigDesc.retTypes[1] and sig.isFpClass(sigDesc.retTypes[1]) then
		retFpForm, retFpReg = fpArgForm(sigDesc.retTypes, 1)
	end
	local function e(s) table.insert(out, s) end

	-- push list (must leave rsp 16-byte aligned at the call: retaddr + N pushes, N odd).
	local pushList = { myth }
	for k = 1, sigDesc.argWords do
		if args[k] then
			table.insert(pushList, args[k].iv)
			if args[k].lo then table.insert(pushList, args[k].lo) end
		end
	end
	local filler = (#pushList % 2) == 0
	local function restore()
		if filler then e("\taddq\t$8, %rsp") end
		for i = #pushList, 1, -1 do e("\tpopq\t" .. pushList[i]) end
	end

	e("\t.text")
	e("\t.weak\t" .. sym)
	e("\t.hidden\t" .. sym)
	e("\t.p2align\t4")
	e("\t.type\t" .. sym .. ",@function")
	e(sym .. ":")
	for _, r in pushList do e("\tpushq\t" .. r) end
	if filler then e("\tpushq\t%rax") end
	-- stash incoming CC (myth + GPR args) into callee-saved holds. The xmm registers
	-- are untouched here (and by everything up to the calls below), so the FP args
	-- ride across the getter call in them.
	e("\tmovq\t%rdi, " .. myth)
	for k = 1, sigDesc.argWords do
		if args[k] then
			e("\tmovq\t" .. ivReg[k] .. ", " .. args[k].iv)
			if args[k].lo then e("\tmovq\t" .. loReg[k] .. ", " .. args[k].lo) end
		end
	end
	-- resolve FO
	e("\txorl\t%esi, %esi")
	e("\tcallq\tpizlonated_" .. callee .. "@PLT")   -- rax = iv, rdx = lower(FO)
	e("\tmovq\t%rdx, %rsi")                          -- rsi = FO payload
	e("\ttestq\t%rdx, %rdx")
	e("\tje\t" .. L .. "_fail")
	e("\tmovq\t-8(%rsi), %rcx")                       -- aux word (flags)
	e("\tmovabsq\t$0x780000000000000, %rdx")
	e("\tandq\t%rcx, %rdx")
	e("\tmovabsq\t$0x80000000000000, %rdi")
	e("\tcmpq\t%rdi, %rdx")
	e("\tjne\t" .. L .. "_fail")
	e("\tmovabsq\t$0xffffffffffff, %rdx")
	e("\tandq\t%rdx, %rcx")
	e("\tcmpq\t%rcx, %rax")                           -- intval must equal canonical entrypoint
	e("\tjne\t" .. L .. "_fail")
	-- signature. `cmpq $imm32, mem` sign-extends a 32-bit immediate, so signatures
	-- past imm32 (eight doubles -> 8552919316) need the constant materialized first:
	-- movabsq into %r10 (a dead scratch here — the SysV argument registers were
	-- already copied into the hold pool, and %r10 is caller-saved scratch that
	-- nothing past this compare reads), then a register compare.
	if signum <= 2147483647 and signum >= -2147483648 then
		e("\tcmpq\t$" .. tostring(signum) .. ", 16(%rsi)")
	else
		e("\tmovabsq\t$" .. tostring(signum) .. ", %r10")
		e("\tcmpq\t%r10, 16(%rsi)")
	end
	e("\tjne\t" .. L .. "_generic")
	-- direct fast call
	e("\tmovq\t(%rsi), %rax")                         -- fast entrypoint
	e("\tmovq\t" .. myth .. ", %rdi")
	for k = 1, sigDesc.argWords do
		if args[k] then
			e("\tmovq\t" .. args[k].iv .. ", " .. ivReg[k])
			if args[k].lo then e("\tmovq\t" .. args[k].lo .. ", " .. loReg[k]) end
		end
	end
	restore()
	e("\tjmpq\t*%rax")
	-- generic (buffer) call
	e(L .. "_generic:")
	for k = 1, sigDesc.argWords do
		if sig.isFpClass(sigDesc.argTypes[k]) then
			-- FP arg: still live in its xmm register (nothing clobbered the xmm
			-- file); store it at its declaration index (a float = 4-byte store into
			-- the 8-byte slot) with a zero aux word.
			local form, reg = fpArgForm(sigDesc.argTypes, k)
			e("\t" .. form .. "\t" .. reg .. ", " .. tostring(128 + 8 * (k - 1)) .. "(" .. myth .. ")")
			e("\tmovq\t$0, " .. tostring(384 + 8 * (k - 1)) .. "(" .. myth .. ")")
		else
			e("\tmovq\t" .. args[k].iv .. ", " .. tostring(128 + 8 * (k - 1)) .. "(" .. myth .. ")")
			if args[k].lo then
				e("\tmovq\t" .. args[k].lo .. ", " .. tostring(384 + 8 * (k - 1)) .. "(" .. myth .. ")")
			else
				e("\tmovq\t$0, " .. tostring(384 + 8 * (k - 1)) .. "(" .. myth .. ")")
			end
		end
	end
	e("\tmovl\t$" .. tostring(argBytes) .. ", %edx")
	e("\tmovq\t" .. myth .. ", %rdi")
	e("\tcallq\t*8(%rsi)")                            -- generic entrypoint
	e("\ttestb\t$1, %al")
	e("\tjne\t" .. L .. "_exc")
	if sigDesc.retWords >= 1 then
		e("\tcmpq\t$" .. tostring(retBytes - 1) .. ", %rdx")
		e("\tjbe\t" .. L .. "_retfail")
		if retFpForm then
			-- FP return: read the buffer word back into xmm0 (a float = 4-byte load)
			e("\t" .. retFpForm .. "\t128(" .. myth .. "), " .. retFpReg)
		else
			e("\tmovq\t128(" .. myth .. "), %rdx")
			if sigDesc.retIsPtr then e("\tmovq\t384(" .. myth .. "), %rcx") end
		end
	end
	e(L .. "_done:")
	restore()
	e("\tretq")
	e(L .. "_exc:")
	e("\tjmp\t" .. L .. "_done")
	e(L .. "_fail:")
	e("\tmovq\t%rax, %rdi")
	e("\tcallq\tfilc_check_function_call_fail@PLT")
	if sigDesc.retWords >= 1 then
		e(L .. "_retfail:")
		e("\tmovl\t$" .. tostring(retBytes) .. ", %esi")
		e("\tmovq\t%rdx, %rdi")
		e("\txorl\t%edx, %edx")
		e("\tcallq\tfilc_cc_rets_check_failure@PLT")
	end
	e("\t.size\t" .. sym .. ", .-" .. sym)
	e("")
end

return glue_x86
