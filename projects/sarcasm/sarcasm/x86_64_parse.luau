--!nonstrict
-- x86_64 assembly parser (both AT&T and Intel syntax) producing the common operand
-- model used by the rest of sarcasm. Registers are canonicalized to an encoding number
-- (rax=0..r15=15) plus a width in bits.
--
-- Operand model (shared with the ARM64 parser):
--   { kind="reg",  num, width, name, rc="gpr"|"sp"|"rip", indirect=<bool?> }
--   { kind="imm",  value, text }
--   { kind="sym",  text, reloc=<@PLT/@GOTPCREL/nil> }
--   { kind="mem",  base=<reg?>, index=<reg?>, scale=<1|2|4|8>, dispVal=<num?>,
--                  dispSym=<str?>, size=<bytes?>, indirect=<bool?> }

local numlabel = require("./numlabel")

local x86parse = {}

-- name -> { num, width } ---------------------------------------------------
local REG = {}
do
	local q = { "rax","rcx","rdx","rbx","rsp","rbp","rsi","rdi",
		"r8","r9","r10","r11","r12","r13","r14","r15" }
	local d = { "eax","ecx","edx","ebx","esp","ebp","esi","edi",
		"r8d","r9d","r10d","r11d","r12d","r13d","r14d","r15d" }
	local w = { "ax","cx","dx","bx","sp","bp","si","di",
		"r8w","r9w","r10w","r11w","r12w","r13w","r14w","r15w" }
	local b = { "al","cl","dl","bl","spl","bpl","sil","dil",
		"r8b","r9b","r10b","r11b","r12b","r13b","r14b","r15b" }
	for i = 1, 16 do
		REG[q[i]] = { num = i - 1, width = 64 }
		REG[d[i]] = { num = i - 1, width = 32 }
		REG[w[i]] = { num = i - 1, width = 16 }
		REG[b[i]] = { num = i - 1, width = 8 }
	end
	REG["ah"] = { num = 0, width = 8, parseOnly = true }  -- high byte (rare); parse-only alias for reg 0
end

local function classifyReg(name)
	local low = string.lower(name)
	if low == "rip" then return { kind = "reg", rc = "rip", name = "rip", width = 64 } end
	local r = REG[low]
	if not r then
		-- Vector/x87 register names (xmm/ymm/zmm/mm/st) get rc="xmm" so downstream (the
		-- frame policy) can REJECT them cleanly; left unclassified they would masquerade
		-- as symbols and pass through into garbage output or cryptic assembler errors.
		local vec, num = string.match(low, "^([xyz]?mm)(%d+)$")
		if vec then
			local w = (vec == "xmm") and 128 or (vec == "ymm") and 256 or (vec == "zmm") and 512 or 64
			return { kind = "reg", rc = "xmm", num = tonumber(num), width = w, name = low }
		end
		-- AVX512 opmask registers k0-k7 (rc="xmm" class so they pass through unmodeled,
		-- like vector registers; they never participate in GPR webs).
		local kn = string.match(low, "^k([0-7])$")
		if kn then
			return { kind = "reg", rc = "xmm", num = tonumber(kn), width = 64, name = low }
		end
		-- x87 FPU stack registers: st / st(N) / stN (AT&T %st/%st(N); Intel st/st(N)/stN).
		local stn = string.match(low, "^st%((%d+)%)$") or string.match(low, "^st(%d+)$")
		if low == "st" or stn then
			return { kind = "reg", rc = "xmm", num = tonumber(stn) or 0, width = 80, name = low }
		end
		return nil
	end
	local rc = (r.num == 4) and "sp" or "gpr"  -- rsp is the stack pointer
	return { kind = "reg", rc = rc, num = r.num, width = r.width, name = low }
end
x86parse.classifyReg = classifyReg

-- canonical name for (num, width)
local NAMES = { [64] = {}, [32] = {}, [16] = {}, [8] = {} }
do
	-- DETERMINISM: REG is string-keyed, and a VM's string-keyed hash-table iteration
	-- order is an implementation detail not derived from the input, so sort the names
	-- rather than rely on it (this also stays deterministic if a future Luau seeds
	-- string hashes). "ah" and "al" both map to (width=8, num=0); skip the parse-only
	-- "ah" alias during the fill so the canonical low-byte name wins (matching the
	-- standard encoding, where al/cl/dl/bl are nums 0-3).
	local regNames = {}
	for name in REG do table.insert(regNames, name) end
	table.sort(regNames)
	for _, name in regNames do
		local r = REG[name]
		if not r.parseOnly and not NAMES[r.width][r.num] then NAMES[r.width][r.num] = name end
	end
	-- prefer the standard names
	local pref64 = { [0]="rax","rcx","rdx","rbx","rsp","rbp","rsi","rdi","r8","r9","r10","r11","r12","r13","r14","r15" }
	for n, nm in pref64 do NAMES[64][n] = nm end
end
function x86parse.regName(num, width)
	return NAMES[width] and NAMES[width][num] or ("r" .. num)
end

-- PTR size specifier -> bytes
local PTRSIZE = { byte = 1, word = 2, dword = 4, qword = 8, xmmword = 16,
	ymmword = 32, zmmword = 64, tbyte = 10, oword = 16 }

local function trim(s) return (string.gsub(s, "^%s*(.-)%s*$", "%1")) end

-- Split an operand string into top-level comma fields, respecting () and [].
local function splitOperands(s)
	local out, depth, cur = {}, 0, {}
	for i = 1, #s do
		local c = string.sub(s, i, i)
		if c == "(" or c == "[" then depth += 1; table.insert(cur, c)
		elseif c == ")" or c == "]" then depth -= 1; table.insert(cur, c)
		elseif c == "," and depth == 0 then table.insert(out, trim(table.concat(cur))); cur = {}
		else table.insert(cur, c) end
	end
	local last = trim(table.concat(cur))
	if last ~= "" then table.insert(out, last) end
	return out
end

-- Parse a symbol reference possibly decorated with @PLT/@GOTPCREL and +disp.
local function parseSym(text)
	local reloc
	local at = string.find(text, "@", 1, true)
	if at then reloc = string.sub(text, at + 1); text = string.sub(text, 1, at - 1) end
	return { kind = "sym", text = text, reloc = reloc }
end

-- AVX512 decorator handling -------------------------------------------------
-- Strip trailing {...} groups off an operand field (`%zmm0{%k1}{z}`, `(%rdi){1to16}`,
-- `[rdi]{k3}`). Returns the stripped field plus the decorator strings in left-to-right
-- order.
local function stripDecos(field)
	local decos = {}
	while true do
		local d = string.match(field, "(%b{})$")
		if not d then break end
		table.insert(decos, 1, d)
		field = string.sub(field, 1, #field - #d)
	end
	return field, decos
end

-- Attach decorators to a parsed operand: `{1toN}` on a memory operand records the
-- embedded-broadcast factor in op.bcastN; the raw text of every decorator is kept in
-- op.deco for re-rendering and validation. A mask group written without `%` (Intel
-- syntax `{k1}`) is normalized to the AT&T spelling `{%k1}` (output is always AT&T).
local function attachDecos(op, decos)
	if #decos == 0 then return op end
	local parts = {}
	for _, d in decos do
		local kn = string.match(d, "^{k([0-7])}$")
		if kn then d = "{%k" .. kn .. "}" end
		if op.kind == "mem" then
			local n = string.match(d, "^{1to(%d+)}$")
			if n then op.bcastN = tonumber(n) end
		end
		table.insert(parts, d)
	end
	op.deco = table.concat(parts)
	return op
end

-- AT&T operand ------------------------------------------------------------
local function parseAttOperandRaw(field)
	local indirect = false
	if string.sub(field, 1, 1) == "*" then indirect = true; field = string.sub(field, 2) end
	if string.sub(field, 1, 1) == "$" then
		local t = string.sub(field, 2)
		return { kind = "imm", text = t, value = tonumber(t) }
	end
	-- A `%reg` operand is register-shaped unless the parens make it memory — EXCEPT the
	-- x87 stack register %st(N), whose parens are part of the register NAME; classifying
	-- it here keeps it out of the memory parse below (where it would become a bogus
	-- "%st"-displacement operand and crash or corrupt the renderer).
	if string.sub(field, 1, 1) == "%"
		and (not string.find(field, "(", 1, true) or string.match(field, "^%%st%(%d+%)$")) then
		local r = classifyReg(string.sub(field, 2))
		if r then r.indirect = indirect; return r end
	end
	-- memory: disp(base, index, scale)  [disp and any component optional]
	local pre, inside = string.match(field, "^(.-)%((.*)%)$")
	if inside ~= nil then
		local mem = { kind = "mem", scale = 1, indirect = indirect }
		pre = trim(pre)
		if pre ~= "" then
			local n = tonumber(pre)
			if n then mem.dispVal = n else mem.dispSym = (parseSym(pre)).text; mem.dispReloc = (parseSym(pre)).reloc end
		end
		local parts = {}
		for p in (inside .. ","):gmatch("(.-),") do table.insert(parts, trim(p)) end
		if parts[1] and parts[1] ~= "" then mem.base = classifyReg(string.sub(parts[1], 2)) end
		if parts[2] and parts[2] ~= "" then mem.index = classifyReg(string.sub(parts[2], 2)) end
		if parts[3] and parts[3] ~= "" then mem.scale = tonumber(parts[3]) or 1 end
		return mem
	end
	-- numeric local label reference: `1f` / `1b` (next/previous `1:` definition)
	local nref, ndir = string.match(field, "^(%d+)([fb])$")
	if nref then
		return { kind = "numref", text = field, num = nref, dir = ndir, indirect = indirect }
	end
	-- bare symbol / label / number
	if string.match(field, "^-?%d") or string.match(field, "^0[xX]") then
		-- A bare (non-$-prefixed) numeric literal in AT&T syntax is NOT an
		-- immediate: gas reads it as an absolute (moffs) MEMORY operand
		-- (`movq 0x600000, %rax` LOADS from that address). Tag it so
		-- x86_64_isa.classify can reject the absolute access cleanly instead
		-- of silently rendering it as an immediate move. (Intel syntax is
		-- different: a bare number there IS an immediate, so the Intel parser
		-- never sets this tag.) The `*` indirect marker is retained too, so
		-- `jmp *0x600000` / `call *0x600000` (an indirect branch THROUGH that
		-- absolute address) classify as the same un-checkable absolute read
		-- rather than falling through the call/jmp moffs exemption.
		return { kind = "imm", text = field, value = tonumber(field), absAddr = true,
			indirect = indirect }
	end
	local s = parseSym(field); s.indirect = indirect; return s
end

local function parseAttOperand(field)
	local f, decos = stripDecos(field)
	return attachDecos(parseAttOperandRaw(f), decos)
end

-- Intel operand -----------------------------------------------------------
local function parseIntelOperandRaw(field)
	-- An AT&T-style memory operand (disp(base,index,scale)) is never a valid
	-- Intel-syntax operand, but without an explicit check it falls through to
	-- parseSym below and RE-RENDERS verbatim as valid AT&T memory syntax — with
	-- Intel dest-first operand order applied and NO capability/bounds check (a
	-- total check-bypass: `movq (%rdi), %rsi` in Intel mode emitted an unchecked
	-- 8-byte store). Reject any field containing parens — covering the parseSym
	-- fallthrough, the numeric-prefix immediate path (`8(%rdi)`), and
	-- whitespace-dodged forms (`( %rdi )`). The ONLY legitimate parens in an
	-- Intel operand are the x87 stack-register name st(N).
	if string.find(field, "[()]") and not string.match(string.lower(field), "^st%(%d+%)$") then
		error("sarcasm: AT&T-style operand in Intel-syntax input"
			.. " (use [bracket] memory operands): " .. field)
	end
	local indirect = false
	local size = nil
	-- size specifier: BYTE PTR / WORD PTR / ...
	local sz, rest = string.match(field, "^(%a+)%s+PTR%s+(.*)$")
	if sz and PTRSIZE[string.lower(sz)] then size = PTRSIZE[string.lower(sz)]; field = trim(rest) end
	-- memory: optional leading disp then [ ... ]  (GAS Intel: `8[rbx]`, `[rbx+8]`, `[rip+sym]`)
	local pre, inside = string.match(field, "^(.-)%[(.*)%]$")
	if inside ~= nil then
		local mem = { kind = "mem", scale = 1, size = size }
		pre = trim(pre)
		if pre ~= "" then
			local n = tonumber(pre)
			if n then mem.dispVal = n else mem.dispSym = pre end
		end
		-- inside: base [+ index*scale] [+/- disp]  (also `rip + sym`)
		inside = (string.gsub(inside, "%s+", ""))
		-- split on + / - keeping sign
		local terms = {}
		local i, n = 1, #inside
		local sign = 1
		local tok = {}
		local function flush()
			local t = table.concat(tok); tok = {}
			if t ~= "" then table.insert(terms, { sign = sign, tok = t }) end
		end
		while i <= n do
			local c = string.sub(inside, i, i)
			if c == "+" then flush(); sign = 1
			elseif c == "-" then flush(); sign = -1
			else table.insert(tok, c) end
			i += 1
		end
		flush()
		for _, term in terms do
			local t = term.tok
			if string.find(t, "*", 1, true) then
				local rn, sc = string.match(t, "^(.-)%*(%d+)$")
				mem.index = classifyReg(rn); mem.scale = tonumber(sc) or 1
			else
				local r = classifyReg(t)
				if r then
					if r.rc == "rip" then mem.base = r
					elseif not mem.base then mem.base = r else mem.index = r end
				else
					local num = tonumber(t)
					if num then mem.dispVal = (mem.dispVal or 0) + term.sign * num
					else mem.dispSym = t end
				end
			end
		end
		return mem
	end
	local r = classifyReg(field)
	if r then r.indirect = indirect; return r end
	-- numeric local label reference: `1f` / `1b` (next/previous `1:` definition)
	local nref, ndir = string.match(field, "^(%d+)([fb])$")
	if nref then
		return { kind = "numref", text = field, num = nref, dir = ndir, indirect = indirect }
	end
	if string.match(field, "^-?%d") or string.match(field, "^0[xX]") then
		return { kind = "imm", text = field, value = tonumber(field) }
	end
	return parseSym(field)
end

local function parseIntelOperand(field)
	local f, decos = stripDecos(field)
	return attachDecos(parseIntelOperandRaw(f), decos)
end

-- Strip an AT&T size suffix (movq->mov, addl->add) when the base mnemonic exists in both.
-- We keep the full mnemonic but also record a `.opsize` (bytes) when a suffix is present.
local ATT_SUFFIX = { b = 1, w = 2, l = 4, q = 8 }
local function attMnemonic(m)
	-- movzbl/movsbl etc. keep as-is (semantic); only strip a trailing size on plain ops
	local base, suf = string.match(m, "^(.-)([bwlq])$")
	if base and ATT_SUFFIX[suf] and #base >= 2 then
		return base, ATT_SUFFIX[suf]
	end
	return m, nil
end

-- comments: strip `#` to end of line (not inside strings) BEFORE the `;!` split (see
-- parseString below — comment text must not fabricate annotations).
local function stripComment(s)
	local inStr = false
	for i = 1, #s do
		local c = string.sub(s, i, i)
		if c == '"' then inStr = not inStr
		elseif not inStr and c == "#" then return string.sub(s, 1, i - 1) end
	end
	return s
end

local function splitAnnotation(s)
	local idx = string.find(s, ";!", 1, true)
	if idx then return string.sub(s, 1, idx - 1), trim(string.sub(s, idx + 2)) end
	return s, nil
end

function x86parse.parseString(text, syntax)
	local out = {}
	text = (string.gsub(text, "\r\n", "\n"))
	local lineNo = 0
	for raw in (text .. "\n"):gmatch("(.-)\n") do
		lineNo += 1
		-- Strip `#` comments BEFORE splitting the `;!` annotation (the arm64 parser
		-- strips comments first, too): comment text must never fabricate an
		-- annotation — a line like `# use ;! load ptr here` would otherwise attach a
		-- spurious annotation to an otherwise-empty statement, which the shared body
		-- validation rejects ("annotation on an otherwise-empty line"). A `#` after
		-- the annotation still ends a trailing comment.
		local code, annotation = splitAnnotation(stripComment(raw))
		local t = trim(code)
		local before = #out
		if t == "" then
			table.insert(out, { kind = "blank", text = raw, annotation = annotation })
		else
			-- peel labels
			while true do
				local name, rest = string.match(t, "^([%w_.$][%w_.$@]*):%s*(.*)$")
				if not name then break end
				table.insert(out, { kind = "label", name = name })
				t = trim(rest)
				if t == "" then break end
			end
			if t ~= "" then
				local mnem, rest = string.match(t, "^([%.%w_][%w_.]*)%s*(.*)$")
				rest = trim(rest or "")
				if string.sub(mnem, 1, 1) == "." then
					table.insert(out, { kind = "directive", name = mnem, args = rest, raw = t })
				else
					-- `lock` is an instruction PREFIX, not a mnemonic: gas emits it
					-- as a leading token on the same line (`lock xaddq %rsi, (%rdi)`,
					-- also `lock;`-separated). Re-split the remainder into the real
					-- mnemonic + operands and tag the instruction; WHICH instructions
					-- may carry the prefix is validated in x86_64_isa.classify.
					-- rep*/xacquire/xrelease stay reject-listed "mnemonics"
					-- (fp.unsafeReject) — only `lock` gets prefix parsing.
					local lockPrefix = false
					if string.lower(mnem) == "lock" then
						local r2 = (string.gsub(rest, "^%s*;%s*", ""))
						local m2, rest2 = string.match(r2, "^([%.%w_][%w_.]*)%s*(.*)$")
						if not m2 then
							error("sarcasm: `lock` prefix with no following instruction: " .. t)
						end
						mnem, rest = m2, trim(rest2 or "")
						lockPrefix = true
					end
					local opsize
					if syntax == "att" then local _; _, opsize = attMnemonic(mnem) end
					local ops = {}
					for _, f in splitOperands(rest) do
						if f ~= "" then
							table.insert(ops, syntax == "att" and parseAttOperand(f) or parseIntelOperand(f))
						end
					end
					-- AT&T lists operands source-first; normalize to dest-first (like Intel/ARM)
					if syntax == "att" and #ops >= 2 then
						local rev = {}
						for i = #ops, 1, -1 do table.insert(rev, ops[i]) end
						ops = rev
					end
					table.insert(out, { kind = "insn", mnemonic = string.lower(mnem), operands = ops,
						opsize = opsize, raw = t, syntax = syntax, lockPrefix = lockPrefix or nil })
				end
			end
		end
		if annotation and #out > before then out[#out].annotation = annotation end
		for k = before + 1, #out do out[k].line = out[k].line or lineNo end
	end
	numlabel.resolve(out)
	return out
end

return x86parse
