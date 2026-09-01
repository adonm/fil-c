--!nonstrict
-- x86_64 rendering + frame policy for the shared emit loop (emit.luau). Renders IR nodes
-- (dest-first operand model) back to assembly text in the requested syntax ("att"/"intel"),
-- substituting register allocations, and synthesizes the Fil-C prologue/epilogue/frame.
-- Interface used by emit.emitFip: makeColorNum / usedCalleeSaved / computeLayout / header /
-- prologue / epilogue / rootStore / renderInsn / isSelfMove.

local x86 = require("./x86_64_isa")
local x86parse = require("./x86_64_parse")
local fp = require("./x86_64_fp")

local x86_64_render = {}

local SUFFIX = { [8] = "b", [16] = "w", [32] = "l", [64] = "q" }

-- mnemonics that take an AT&T size suffix when synthesized (bare)
local SUFFIXABLE = {
	mov=true, add=true, sub=true, ["and"]=true, ["or"]=true, xor=true, cmp=true, test=true,
	-- adc/sbb: same story as add/sub (their only width-less rendering is imm+mem),
	-- but they were missing until locked imm+mem RMWs exposed it: a lifted
	-- `lock adc QWORD PTR [rdi], 3` has NO register operand to imply a width, so
	-- the bare AT&T rendering (`lock adc $3, (%rbx)`) assembled as gas's silent
	-- l-default (32-bit `f0 83 /2 ib` = adcl) while the injected bounds check
	-- covered the requested 8 bytes — a silent width-changing miscompile.
	adc=true, sbb=true,
	shl=true, shr=true, sal=true, sar=true, imul=true, inc=true, dec=true, neg=true, ["not"]=true,
	-- the one-operand mul/div family: an Intel PTR-sized memory form (`div QWORD
	-- PTR [rdi]`) carries its width only in mem.size, and a bare AT&T rendering
	-- would assemble as the l-default — synthesize the suffix like cmp/test.
	div=true, idiv=true, mul=true,
}

-- xadd/cmpxchg ALWAYS render with an explicit size suffix: gas cannot infer the
-- width of `xadd (%rdi), %rsi` / `cmpxchg (%rdi), %rsi` (the memory operand
-- comes first) and rejects the bare form — including when the input was legal
-- Intel syntax (`xadd [rdi], rsi`). The width comes from the register operand
-- (always present: xadd/cmpxchg are r/m, r) or the memory size.
local FORCE_SUFFIX = { xadd = true, cmpxchg = true }

-- Bare (unsuffixed) x87 mnemonic + a sized memory operand -> the suffixed AT&T
-- mnemonic encoding that size. gas's default width for an unsuffixed x87 mnemonic
-- (fld -> flds) silently changes the access width of a PTR-sized Intel memory form
-- (`fld QWORD PTR [rdi]` must render fldl; rendered bare it assembles to a 4-byte
-- flds while being bounds-checked at 8 — a silent width-changing miscompile).
-- Combinations the ISA does not have (fst with a tbyte operand, fiadd with a qword,
-- ...) are rejected cleanly. Form matrix verified against `as`: the float family
-- has m32/m64 forms (plus m80 for fld/fstp only); the int family has m16/m32 forms
-- (plus m64 for fild/fistp/fisttp only).
local X87_MEM_FORM = {}
for _, m in { "fadd", "fsub", "fsubr", "fmul", "fdiv", "fdivr", "fcom", "fcomp" } do
	X87_MEM_FORM[m] = { [4] = m .. "s", [8] = m .. "l" }
end
for _, m in { "fiadd", "fisub", "fisubr", "fimul", "fidiv", "fidivr", "ficom", "ficomp" } do
	X87_MEM_FORM[m] = { [2] = m .. "s", [4] = m .. "l" }
end
X87_MEM_FORM.fld = { [4] = "flds", [8] = "fldl", [10] = "fldt" }
X87_MEM_FORM.fst = { [4] = "fsts", [8] = "fstl" }            -- fst has no tbyte form
X87_MEM_FORM.fstp = { [4] = "fstps", [8] = "fstpl", [10] = "fstpt" }
X87_MEM_FORM.fild = { [2] = "filds", [4] = "fildl", [8] = "fildq" }
X87_MEM_FORM.fist = { [2] = "fists", [4] = "fistl" }         -- fist has no qword form
X87_MEM_FORM.fistp = { [2] = "fistps", [4] = "fistpl", [8] = "fistpq" }
X87_MEM_FORM.fisttp = { [2] = "fisttps", [4] = "fisttpl", [8] = "fisttpq" }

-- The integer-source cvt family has the same gas-default-width trap: a bare AT&T
-- `cvtsi2ss (%rdi), %xmm0` assembles as m32 (cvtsi2ssl). When an Intel PTR size
-- selected the m32/m64 form, synthesize the suffix so the emitted encoding matches
-- the bounds-checked width (the fp table's cvtIntW width function is
-- annotation-driven). A PTR size that is not a real form (e.g. WORD PTR) is
-- rejected cleanly rather than under-checked.
local CVT_INT_MEM_FORM = {
	cvtsi2ss = { [4] = "cvtsi2ssl", [8] = "cvtsi2ssq" },
	cvtsi2sd = { [4] = "cvtsi2sdl", [8] = "cvtsi2sdq" },
	vcvtusi2ss = { [4] = "vcvtusi2ssl", [8] = "vcvtusi2ssq" },
	vcvtusi2sd = { [4] = "vcvtusi2sdl", [8] = "vcvtusi2sdq" },
}

-- Bare `crc32` with a sized (Intel PTR, or materialized frame slot) memory
-- source: gas would otherwise default the width from the destination register,
-- silently changing the crc source width (`crc32 eax, BYTE PTR [rdi]` must read
-- 1 byte, not 4). Synthesize the suffix that encodes the annotation.
local CRC32_MEM_FORM = { crc32 = { [1] = "crc32b", [2] = "crc32w", [4] = "crc32l", [8] = "crc32q" } }

local function regName(num, width) return x86parse.regName(num, width) end
x86_64_render.regName = regName

-- physical number for an operand (fixed, tempRef, or lifted opTemp).
local function physOf(node, op, colorNum)
	if not op or op.kind ~= "reg" then return nil end
	if op.fixedNum ~= nil then return op.fixedNum end
	if op.tempRef ~= nil then return colorNum and colorNum(op.tempRef) end
	if node.opTemp and node.opTemp[op] ~= nil then return colorNum and colorNum(node.opTemp[op]) end
	return nil
end

local function renderOperandRaw(node, op, colorNum, syntax)
	local function numOf(o)
		if o.fixedNum ~= nil then return o.fixedNum end
		if o.tempRef ~= nil then return colorNum and colorNum(o.tempRef) end
		if node.opTemp then local t = node.opTemp[o]; if t ~= nil then return colorNum and colorNum(t) end end
		return nil
	end
	-- name for a memory base/index register: the allocated physical register, or the
	-- original name when the operand was never modeled (e.g. a raw %rsp base passed
	-- through by a memory-neutral instruction).
	local function baseRegName(o)
		local n = numOf(o)
		if n ~= nil then return regName(n, 64) end
		return (o and o.name) or "?"
	end
	if op.kind == "reg" then
		if op.rc == "rip" then return syntax == "att" and "%rip" or "rip" end
		local num = numOf(op)
		local name = (num ~= nil) and regName(num, op.width or 64) or op.name
		return syntax == "att" and ("%" .. name) or name
	elseif op.kind == "imm" then
		return syntax == "att" and ("$" .. op.text) or op.text
	elseif op.kind == "sym" then
		local t = op.text
		if op.reloc == "plt" then t = t .. "@PLT"
		elseif op.reloc == "gotpcrel" then t = t .. "@GOTPCREL" end
		return t
	elseif op.kind == "mem" then
		local ripBase = op.base and op.base.kind == "reg" and op.base.rc == "rip"
		local disp = ""
		if op.dispSym then
			disp = op.dispSym
			if op.dispReloc == "gotpcrel" then disp = disp .. "@GOTPCREL"
			elseif op.dispReloc == "plt" then disp = disp .. "@PLT" end
		end
		if syntax == "att" then
			local dtext = disp
			if op.dispVal and op.dispVal ~= 0 then
				dtext = (dtext ~= "" and dtext or "") .. (op.dispVal < 0 and tostring(op.dispVal) or ("+" .. op.dispVal))
				if disp == "" then dtext = tostring(op.dispVal) end
			end
			if ripBase then return dtext .. "(%rip)" end
			if op.index then
				local b = op.base and ("%" .. baseRegName(op.base)) or ""
				return dtext .. "(" .. b .. ",%" .. baseRegName(op.index) .. "," .. tostring(op.scale or 1) .. ")"
			end
			if not op.base then
				-- A displacement-only memory operand (no base, no index): classify
				-- rejects it as an absolute address, but the renderer must never
				-- crash on one regardless (it renders as the bare displacement).
				return dtext
			end
			return dtext .. "(%" .. baseRegName(op.base) .. ")"
		else
			if ripBase then return "[rip + " .. disp .. "]" end
			local parts = {}
			if op.base then table.insert(parts, baseRegName(op.base)) end
			if op.index then table.insert(parts, baseRegName(op.index) .. "*" .. tostring(op.scale or 1)) end
			if disp ~= "" then table.insert(parts, disp) end
			if op.dispVal and op.dispVal ~= 0 then
				table.insert(parts, (op.dispVal < 0 and tostring(op.dispVal)) or ("+" .. tostring(op.dispVal)))
			end
			-- (A displacement-only operand with no base and no index is rejected by
			-- classify as an absolute address; the renderer still never crashes on it.)
			local body = parts[1] or ""
			for k = 2, #parts do
				local p = parts[k]
				if string.sub(p, 1, 1) == "+" or string.sub(p, 1, 1) == "-" then body = body .. " " .. string.sub(p,1,1) .. " " .. string.sub(p,2)
				else body = body .. " + " .. p end
			end
			return "[" .. body .. "]"
		end
	end
	return "?"
end

-- AVX512 decorators ({%k1}{z}, {1to16}, ...) ride along on the operand and are
-- re-rendered verbatim after the register/memory text.
local function renderOperand(node, op, colorNum, syntax)
	local s = renderOperandRaw(node, op, colorNum, syntax)
	if op.deco then s = s .. op.deco end
	return s
end
x86_64_render.renderOperand = renderOperand

-- operation size (bytes) for a synthesized instruction (widest reg, or mem.size).
-- Lifted nodes carry their operands in node.stmt.operands (only synthesized nodes
-- have node.operands), so look at both — this is what sizes the AT&T suffix of a
-- reg-less lifted form (e.g. a materialized `movl $5, O(%rsp)` frame-slot store).
local function opSize(node, colorNum)
	local w = nil
	for _, op in ((node.stmt and node.stmt.operands) or node.operands or {}) do
		if op.kind == "reg" and op.rc ~= "rip" then w = math.max(w or 0, op.width or 64)
		elseif op.kind == "mem" and op.size then w = math.max(w or 0, op.size * 8) end
	end
	return w or 64
end

local INTEL_PTR = { [1]="BYTE PTR", [2]="WORD PTR", [4]="DWORD PTR", [8]="QWORD PTR" }

-- rel8-reachable trampoline for the rel8-ONLY implicit-counter branches
-- (`loop`/`loopq`/`loopl` decrement-and-branch and `jrcxz`/`jecxz` branch-on-counter-
-- zero re-emit verbatim and have NO rel32/abs encoding). Sarcasm's instrumentation —
-- the pollcheck at a back-edge label, the per-access bounds checks — routinely pushes
-- the branch target beyond +-127 bytes, and gas then rejects the emitted file with an
-- opaque "value of ... too large for field of 1 byte" error from the temp .yolo.s.
-- Sarcasm cannot predict the post-instrumentation displacement (the instrumentation is
-- injected between the branch and its target by earlier stages), so EVERY such branch
-- is rewritten at render time, unconditionally, to jump through a nearby trampoline:
--
--	loop	.Lsarctramp_<fn>_<n>t    # the original instruction, unchanged semantics
--	jmp	.Lsarctramp_<fn>_<n>s    # skip past the stub
--.Lsarctramp_<fn>_<n>t:
--	jmp	<original target>        # rel32 — always reachable
--.Lsarctramp_<fn>_<n>s:
--
-- The trampoline (stub) label sits 2 bytes ahead of the branch — always within rel8
-- reach — the skip jmp lands past the stub, and the stub's `jmp T` can be rel32. NO
-- flag-affecting instruction is added: jmp preserves all flags and loop/jrcxz/jecxz
-- do not read flags, so both the taken and the fall-through path see the same flags as
-- before (a dec/jne rewrite is REJECTED as an approach: it would change the flags the
-- fall-through path observes). Fall-through semantics are unchanged, and the IR-level
-- instruction plus its original target stay exactly as they are — validateBody,
-- reachability, liveness, the counter web's rcx use/def/RMW + fixedReg precolor and
-- the pollcheck-at-back-edge machinery (which lives at the TARGET label, saving and
-- restoring physical rcx around filc_pollcheck_slow) all still see the original
-- branch; only the final emitted text changes. <n> is a per-function statement-order
-- counter (deterministic: renderInsn runs once per FIP node, in emission order), the
-- function name keeps sites of different functions apart, and the counter is bumped
-- past any name a user label of this function already uses.
local trampFn = nil      -- current function's plain name (set by header)
local trampCounter = 0   -- per-function statement-order trampoline counter
local trampUsed = nil    -- label names already defined in the current function

local function trampNames()
	while true do
		local t = ".Lsarctramp_" .. (trampFn or "?") .. "_" .. trampCounter .. "t"
		local s = ".Lsarctramp_" .. (trampFn or "?") .. "_" .. trampCounter .. "s"
		trampCounter += 1
		if not (trampUsed[t] or trampUsed[s]) then return t, s end
	end
end

-- Is this an implicit-counter branch that must go through the trampoline? Only the
-- supported forms reach the renderer (loopb/loopw and the ZF-consuming loop variants
-- and jcxz are rejected at classify), but the shape is checked defensively: a label
-- operand is required (a loop/jcxz with no label target never gets here — validateBody
-- rejects it first).
local function isCounterBranch(low)
	return string.match(low, "^loop[bwlq]?$") ~= nil or low == "jrcxz" or low == "jecxz"
end

function x86_64_render.renderInsn(node, colorNum, syntax, rc)
	local mnem = node.stmt and node.stmt.mnemonic or node.mnemonic
	local ops = node.stmt and node.stmt.operands or node.operands or {}
	local low = string.lower(mnem)

	-- Displacement fixups for two synthesized node kinds whose %rsp-relative
	-- offsets are only known once the frame layout is (they cannot be baked into
	-- the operand at transform time):
	--   * inArgWord — an INCOMING fast-CC stack-argument load (cg.loadInArg): the
	--     word sits at [entry_rsp + 8 + 8*w] (above the return address), i.e. at
	--     [rsp + 8*#calleeSaved + layout.total + 8 + 8*w] at the body frame base.
	--   * spillShift — a spill reload/store regalloc inserted inside an outgoing
	--     stack-arg window (cg.beginStackArgs/endStackArgs), where rsp was dropped
	--     by N: re-base the slot by the window's shift so it addresses the same
	--     frame slot (see sarcasm.luau's rewriteSpills).
	local dispDelta = 0
	if node.inArgWord and rc and rc.layout then
		dispDelta = rc.layout.total + 8 * #rc.calleeSaved + 8 + 8 * node.inArgWord
	end
	if node.spillShift then dispDelta += node.spillShift end
	if dispDelta ~= 0 then
		local adjusted = {}
		for _, o in ops do
			if o.kind == "mem" and o.base and o.base.fixedNum == 4 then
				local c = {}
				for k, v in o do c[k] = v end
				c.dispVal = (c.dispVal or 0) + dispDelta
				table.insert(adjusted, c)
			else
				table.insert(adjusted, o)
			end
		end
		ops = adjusted
		-- renderOperandRaw looks up temps through node.opTemp keyed by operand
		-- identity; the cloned operand carries the same tempRef field, so only a
		-- node.opTemp-mapped operand would lose its temp — clone carefully: the
		-- memory operands these node kinds carry never use opTemp (their base is
		-- the fixed rsp), so this is safe.
	end

	-- Bare multi-byte padding NOPs do not assemble (gas rejects the bare mnemonic
	-- with "invalid instruction suffix for `nop'"), and the operand-ful padding
	-- forms (nopw 0x0(%rax,%rax,1)) are zero-effect encodings that render verbatim.
	-- Normalize the bare forms to plain `nop` so the emitted file always assembles.
	if (low == "nopw" or low == "nopl") and #ops == 0 then
		return "\tnop"
	end

	-- The rel8 trampoline for loop/jrcxz/jecxz (see the long comment above). Emitted
	-- as one renderInsn result: emitFip joins the output lines with newlines, so the
	-- five-line form lands verbatim in the assembly.
	if trampUsed and node.stmt and isCounterBranch(low)
		and ops[1] and ops[1].kind == "sym" then
		local tgt = renderOperand(node, ops[1], colorNum, syntax)
		local t, s = trampNames()
		return "\t" .. low .. "\t" .. t .. "\n"
			.. "\tjmp\t" .. s .. "\n"
			.. t .. ":\n"
			.. "\tjmp\t" .. tgt .. "\n"
			.. s .. ":"
	end

	-- A validated `lock` prefix (parser tag; x86_64_isa.classify allows it only
	-- on exactly-modeled memory-destination RMWs) re-emits ahead of the mnemonic.
	local lockPfx = ((node.stmt and node.stmt.lockPrefix) or node.lockPrefix) and "lock " or ""

	-- control-only forms: an indirect call/jump renders its target operand with
	-- the AT&T `*`. The marker comes from a synthesized node's `indirect` flag
	-- (the transform's indirect-call sequence), from the PARSED operand's own
	-- `*` (x86_64_parse records it in op.indirect), or implicitly: a call/jmp
	-- whose operand is a register or memory operand is ALWAYS indirect (x86 has
	-- no direct register/memory call or jmp — direct forms take a symbol), which
	-- also covers Intel-syntax input (`jmp rax` has no `*` to record). Losing
	-- the marker renders `jmp %rax`, which clang's integrated assembler rejects
	-- and gas only warns about.
	local ctlBase = x86.baseMnemonic(mnem)
	local op1 = ops[1]
	local indir = node.indirect or (op1 and op1.indirect)
		or (op1 and (op1.kind == "reg" or op1.kind == "mem"))
	if indir and (ctlBase == "call" or ctlBase == "jmp") then
		local tgt = renderOperand(node, op1, colorNum, syntax)
		return "\t" .. low .. "\t" .. (syntax == "att" and ("*" .. tgt) or tgt)
	end

	-- AT&T size suffix. movzx/movsx need an explicit source+dest size pair (movzbl, ...)
	-- since bare `movzx` with a memory source is ambiguous in AT&T; derive it from the
	-- source size (AT&T suffix letter or BYTE/WORD PTR) and the destination register width.
	local outMnem = mnem
	local base = x86.baseMnemonic(mnem)
	if syntax == "att" then
		local sizedForm = X87_MEM_FORM[low] or CVT_INT_MEM_FORM[low] or CRC32_MEM_FORM[low]
		if sizedForm then
			-- Bare x87 / cvt-int mnemonic with a sized (Intel PTR, or materialized
			-- frame slot) memory operand: emit the suffix encoding that size (see
			-- the table comments). Already-suffixed input (fldl, cvtsi2ssq) is not
			-- table-keyed and stays untouched.
			local memsz = nil
			for _, op in ops do
				if op.kind == "mem" and op.size then memsz = op.size break end
			end
			if memsz then
				local f = sizedForm[memsz]
				if not f then
					error("sarcasm: " .. low .. " has no " .. tostring(memsz)
						.. "-byte memory form: " .. (node.stmt and node.stmt.raw or mnem))
				end
				outMnem = f
			end
		elseif FORCE_SUFFIX[low] then
			-- xadd/cmpxchg: gas cannot infer the width of a bare mnemonic (see the
			-- table comment) — always render an explicit size suffix.
			local w = 0
			for _, op in ops do
				if op.kind == "reg" and op.rc ~= "rip" then w = math.max(w, op.width or 64)
				elseif op.kind == "mem" and op.size then w = math.max(w, op.size * 8) end
			end
			outMnem = low .. (SUFFIX[w > 0 and w or 64] or "q")
		elseif (base == "movzx" or base == "movsx") and string.match(low, "^mov[zs][bwlq][bwlq]$") then
			outMnem = low  -- already a full AT&T form (movzbl, movslq, ...): render verbatim
		elseif base == "movzx" or base == "movsx" then
			local letter = string.match(low, "^mov[zs]([bw])")
			local srcBytes = letter and ({ b = 1, w = 2 })[letter] or nil
			if not srcBytes then for _, op in ops do if op.kind == "mem" and op.size then srcBytes = op.size end end end
			if not srcBytes and ops[2] and ops[2].kind == "reg" and ops[2].rc ~= "rip" then
				srcBytes = math.floor((ops[2].width or 16) / 8)
			end
			srcBytes = srcBytes or 1
			local dstW = 32
			for _, op in ops do if op.kind == "reg" and op.rc ~= "rip" then dstW = op.width or 64; break end end
			outMnem = "mov" .. (base == "movzx" and "z" or "s") .. SUFFIX[srcBytes * 8] .. SUFFIX[dstW]
		elseif node.synth then
			if low == "lea" then outMnem = "leaq"
			elseif SUFFIXABLE[low] then
				outMnem = low .. (SUFFIX[opSize(node, colorNum)] or "q")
			end
		elseif SUFFIXABLE[low] then
			-- Lifted node with a bare mnemonic (Intel input) and no register operand to imply
			-- the operand width (e.g. `cmp $0, 8(%rdx)`): AT&T needs an explicit size suffix.
			local hasReg = false
			for _, op in ops do if op.kind == "reg" and op.rc ~= "rip" then hasReg = true; break end end
			if not hasReg then outMnem = low .. (SUFFIX[opSize(node, colorNum)] or "q") end
		end
		-- Bare narrowing convert with a sized memory operand: gas needs the
		-- source-width suffix (vcvtpd2psx/y, vcvtpd2phz, ...) — the bare rendering
		-- is ambiguous and fails assembly.
		if outMnem == mnem then
			local memsz = nil
			for _, op in ops do
				if op.kind == "mem" and op.size then memsz = op.size break end
			end
			local ns = memsz and fp.narrowSuffix(low, memsz)
			if ns then outMnem = low .. ns end
		end
	end

	-- determine a memory size for intel PTR prefixes (imm+mem ambiguity)
	local memSize = nil
	do
		local w = 0
		local hasMem = false
		for _, op in ops do
			if op.kind == "reg" and op.rc ~= "rip" then w = math.max(w, op.width or 64)
			elseif op.kind == "mem" then hasMem = true; if op.size then w = math.max(w, op.size*8) end end
		end
		if hasMem and syntax == "intel" then memSize = math.floor((w > 0 and w or 64) / 8) end
	end

	local rendered = {}
	for _, op in ops do
		local s = renderOperand(node, op, colorNum, syntax)
		if op.kind == "mem" and syntax == "intel" and memSize and INTEL_PTR[memSize] then
			s = INTEL_PTR[memSize] .. " " .. s
		end
		table.insert(rendered, s)
	end
	if #rendered == 0 then return "\t" .. lockPfx .. outMnem end
	-- Operands are stored destination-first (Intel order). AT&T lists them source-first.
	if syntax == "att" and #rendered >= 2 then
		local rev = {}
		for k = #rendered, 1, -1 do table.insert(rev, rendered[k]) end
		rendered = rev
	end
	return "\t" .. lockPfx .. outMnem .. "\t" .. table.concat(rendered, ", ")
end

function x86_64_render.isSelfMove(node, colorNum)
	local mnem = node.stmt and node.stmt.mnemonic or node.mnemonic
	if not mnem then return false end
	local low = string.lower(mnem)
	if low ~= "mov" and low ~= "movq" then return false end
	-- a 32-bit `movl %eax, %eax` is NOT a no-op — it zero-extends into %rax. Only a full
	-- 64-bit reg-reg move to the same register is a true no-op we may drop.
	local ops = node.stmt and node.stmt.operands or node.operands
	if not ops or #ops ~= 2 then return false end
	if ops[1].kind ~= "reg" or ops[2].kind ~= "reg" then return false end
	if (ops[1].width or 64) ~= 64 or (ops[2].width or 64) ~= 64 then return false end
	local a = physOf(node, ops[1], colorNum)
	local b = physOf(node, ops[2], colorNum)
	return a ~= nil and a == b
end

-- Frame layout -----------------------------------------------------------
-- [0,16) prev+origin; [16, 16+8*numRoots) the GC root slots — this placement is an
-- ABI requirement: the Fil-C GC reads a frame's roots as frame->lowers[index], i.e.
-- immediately after the parent+origin header (filc_runtime.h's filc_frame). Then the
-- reserved vector-save area and the materialized FP/SIMD frame-slot clusters (whose
-- analyzeFrame-assigned offsets are relative to base 16 and get shifted past the root
-- area by transform once numRoots is known), then the materialized incoming yolo
-- stack-argument area (x86_64 only — yoloBytes; fed by the entry unpack, read by
-- FP/vector argument reads), then regalloc spill slots. The FP/SIMD+yolo region
-- starts on a 16-byte boundary (8 bytes of padding after the root slots when
-- numRoots is odd) so the clusters' and the yolo area's mod-16 alignment residues
-- (movaps-class accesses) survive the shift. The alignment modulus stays 16 (body
-- rsp ≡ 0 mod 16); aligned >16-byte stack accesses are rejected by the frame rewrite.
local function computeLayout(calleeSaved, numRoots, spillBytes, fpSaveBytes, fpBytes, yoloBytes)
	spillBytes = spillBytes or 0
	fpSaveBytes = fpSaveBytes or 0
	fpBytes = fpBytes or 0
	yoloBytes = yoloBytes or 0
	local p = #calleeSaved
	local rootBase = 16
	local fpPad = ((fpSaveBytes + fpBytes + yoloBytes) > 0 and numRoots % 2 == 1) and 8 or 0
	local spillBase = 16 + 8 * numRoots + fpPad + fpSaveBytes + fpBytes + yoloBytes
	local base = spillBase + spillBytes  -- prev+origin+roots(+pad+save+fp+yolo+spills)
	-- Maintain 16-byte alignment at call sites: (8 retaddr + 8*p pushes + N) % 16 == 0.
	local target = ((p % 2) == 0) and 8 or 0
	local N = base
	while (N % 16) ~= target do N += 1 end
	return { total = N, rootBase = rootBase, spillBase = spillBase, pushed = calleeSaved }
end
x86_64_render.computeLayout = computeLayout

-- x86 color name -> physical number (via classifyReg).
function x86_64_render.makeColorNum(color)
	return function(t)
		local c = color[t]
		if not c then return nil end
		local r = x86parse.classifyReg(c)
		return r and r.num or nil
	end
end

-- Used callee-saved GPRs in canonical push order.
function x86_64_render.usedCalleeSaved(color)
	local usedCallee = {}
	for _, c in color do usedCallee[c] = true end
	local calleeSaved = {}
	for _, r in x86.CALLEE_SAVED_ORDER do if usedCallee[r] then table.insert(calleeSaved, r) end end
	return calleeSaved
end

-- prologue/epilogue/rootStore emit in the requested syntax.
local function att_(rc) return rc.syntax == "att" end

function x86_64_render.header(rc)
	local out, sigName = rc.out, rc.sigName
	-- Trampoline state for this function (see the rel8-trampoline comment above):
	-- statement-order counter restarts at 0 and the used-name set collects every
	-- label this function's FIP body defines, PLUS every user label of EVERY
	-- function in the file (rc.tr.fileUserLabels, collected by the driver):
	-- .Lsarctramp_* names are FILE-GLOBAL assembly symbols, so a user label in
	-- one function named exactly like another function's generated trampoline
	-- name would collide in the object (gas: "symbol ... is already defined",
	-- plus a knock-on rel8 error). Generated names of OTHER functions cannot
	-- collide with this function's — each embeds its own function name — so the
	-- per-function statement-order counter stays deterministic.
	trampFn = rc.tr.name
	trampCounter = 0
	trampUsed = {}
	for n in (rc.tr.fileUserLabels or {}) do trampUsed[n] = true end
	for _, n in rc.tr.fipNodes do
		if n.kind == "label" then trampUsed[n.name] = true end
	end
	table.insert(out, "\t.text")
	table.insert(out, "\t.globl\t" .. sigName)
	table.insert(out, "\t.p2align\t4")
	table.insert(out, "\t.type\t" .. sigName .. ",@function")
	table.insert(out, sigName .. ":")
end

function x86_64_render.prologue(rc)
	local out, tr, layout = rc.out, rc.tr, rc.layout
	local att = att_(rc)
	local SC = x86.SCRATCH  -- r11
	local mq = att and "movq" or "mov"
	local function ln(s) table.insert(out, s) end
	local function I(v) return att and ("$" .. v) or tostring(v) end
	for _, r in rc.calleeSaved do ln("\t" .. (att and "pushq" or "push") .. "\t" .. (att and ("%" .. r) or r)) end
	ln("\t" .. (att and "subq" or "sub") .. "\t" .. (att and (I(layout.total) .. ", %rsp") or ("rsp, " .. layout.total)))
	-- stack-overflow check: fail when rsp <= limit (limit at [myth=rdi]).
	if att then
		ln("\tcmpq\t%rsp, (%rdi)")
		ln("\tjae\tfilc_stack_overflow_failure@PLT")
	else
		ln("\tcmp\trsp, QWORD PTR [rdi]")
		ln("\tjbe\tfilc_stack_overflow_failure@PLT")
	end
	-- push filc_frame at (rsp): prev, origin; myth->top_frame = rsp.
	ln("\t" .. mq .. "\t" .. (att and ("16(%rdi), %" .. SC) or (SC .. ", QWORD PTR [rdi + 16]")))
	ln("\t" .. mq .. "\t" .. (att and ("%" .. SC .. ", (%rsp)") or ("QWORD PTR [rsp], " .. SC)))
	ln("\t" .. mq .. "\t" .. (att and ("%rsp, 16(%rdi)") or ("QWORD PTR [rdi + 16], rsp")))
	ln("\t" .. (att and "leaq" or "lea") .. "\t" .. (att and (tr.originSym .. "(%rip), %" .. SC) or (SC .. ", [rip + " .. tr.originSym .. "]")))
	ln("\t" .. mq .. "\t" .. (att and ("%" .. SC .. ", 8(%rsp)") or ("QWORD PTR [rsp + 8], " .. SC)))
	-- Zero-initialize every GC root slot. Root slots are written lazily by rootStore (arg
	-- lowers at entry; load-ptr / alloca / call-result lowers after those points), but the
	-- frame declares all of them from the start — so any safepoint (pollcheck, allocation,
	-- call) that runs before a slot's first rootStore would otherwise expose stack garbage
	-- to the GC as a live lower. Matches clang, which emits `movq $0, slot(%rsp)` for its
	-- lowers in the prologue.
	for i = 0, (tr.numRoots or 0) - 1 do
		local off = layout.rootBase + 8 * i
		ln("\t" .. mq .. "\t" .. (att and ("$0, " .. off .. "(%rsp)") or ("QWORD PTR [rsp + " .. off .. "], 0")))
	end
end

function x86_64_render.epilogue(rc)
	local out, layout = rc.out, rc.layout
	local att = att_(rc)
	local SC = x86.SCRATCH
	local mq = att and "movq" or "mov"
	local mythName = regName(rc.mythNum, 64)
	local function ln(s) table.insert(out, s) end
	local function I(v) return att and ("$" .. v) or tostring(v) end
	-- pop frame: myth->top_frame = frame.prev  (scratch = r11, preserves rax/rdx/rcx)
	ln("\t" .. mq .. "\t" .. (att and ("(%rsp), %" .. SC) or (SC .. ", QWORD PTR [rsp]")))
	ln("\t" .. mq .. "\t" .. (att and ("%" .. SC .. ", 16(%" .. mythName .. ")") or ("QWORD PTR [" .. mythName .. " + 16], " .. SC)))
	ln("\t" .. (att and "addq" or "add") .. "\t" .. (att and (I(layout.total) .. ", %rsp") or ("rsp, " .. layout.total)))
	for i = #rc.calleeSaved, 1, -1 do ln("\t" .. (att and "popq" or "pop") .. "\t" .. (att and ("%" .. rc.calleeSaved[i]) or rc.calleeSaved[i])) end
end

function x86_64_render.rootStore(rc, node)
	local att = att_(rc)
	local mq = att and "movq" or "mov"
	local off = rc.layout.rootBase + 8 * node.index
	local rn = regName(rc.colorNum(node.temp), 64)
	table.insert(rc.out, "\t" .. mq .. "\t" .. (att and ("%" .. rn .. ", " .. off .. "(%rsp)") or ("QWORD PTR [rsp + " .. off .. "], " .. rn)))
end

return x86_64_render
