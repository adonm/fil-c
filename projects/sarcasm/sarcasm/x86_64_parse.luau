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
	-- The high-byte aliases ah/ch/dh/bh (the bytes 8-15 of rax/rcx/rdx/rbx — a
	-- separate x86 encoding from the low-byte al/cl/dl/bl). They parse so every
	-- input gets ONE clean rejection (x86_64_isa.classify: only the low byte of a
	-- register is modeled) instead of masquerading as bare symbols and dying with
	-- the misleading "memory access with a symbolic address" error. parseOnly
	-- keeps them out of the canonical-name fill (NAMES), so regName/canonical
	-- behavior stays byte-identical and the canonical names for (width=8, num) are
	-- the low-byte al/cl/dl/bl — these aliases can never become canonical.
	REG["ah"] = { num = 0, width = 8, parseOnly = true }
	REG["ch"] = { num = 1, width = 8, parseOnly = true }
	REG["dh"] = { num = 2, width = 8, parseOnly = true }
	REG["bh"] = { num = 3, width = 8, parseOnly = true }
end

-- Segment registers (encoding numbers, per the SDM Sreg encoding): recognized as
-- their OWN register class so they stop masquerading as bare symbols. This is
-- load-bearing in BOTH directions: a move INTO one (`movw %ax, %fs`) is rejected
-- by fp.unsafeReject (a segment-register write cannot be proven safe), while a
-- move FROM one (`movl %fs, %eax`) passes through as an ordinary (unknown-value)
-- definition of the destination web. The segment-QUALIFIED memory spelling
-- (`%fs:0x28`) is unaffected: classifyReg is called with the exact token
-- "fs:0x28", which is not in SEG, so that operand still parses as a symbolic
-- displacement and keeps its existing rejection. These names deliberately do NOT
-- go into REG: the canonical-names fill (NAMES) is keyed by (width, num) and a
-- 16-bit "fs" at num 4 would collide with %sp's slot (and make regName
-- order-dependent).
local SEG = { es = 0, cs = 1, ss = 2, ds = 3, fs = 4, gs = 5 }

local function classifyReg(name)
	local low = string.lower(name)
	if low == "rip" then return { kind = "reg", rc = "rip", name = "rip", width = 64 } end
	local segNum = SEG[low]
	if segNum then
		return { kind = "reg", rc = "seg", num = segNum, width = 16, name = low }
	end
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

-- Decimal text for a folded constant. tostring renders large integral doubles in
-- exponent notation ("4.6116860184274e+18"), which `as` cannot read back as an
-- integer literal; %.0f always prints the full decimal expansion.
local function intText(v)
	return string.format("%.0f", v)
end

-- Constant-expression evaluation for immediates and displacements ------------------
--
-- gas folds integer constant expressions at assembly time, and real-world inputs
-- rely on it (OpenSSL perlasm emits `subq $64+32,%rsp`, `movl 512-128(%rcx), %eax`,
-- `movq $1<<4, %rax`, `K256+512(%rip)`). The operand model keeps an immediate as
-- (text, value) and a displacement as (dispSym, dispVal), so the parser must fold
-- such expressions itself: parseDispExpr(text) evaluates an integer constant
-- expression and returns { sym = <name?>, const = <number> } — a pure constant has
-- no sym, and a symbolic displacement is the bare symbol plus a folded constant
-- offset. Supported syntax: decimal and 0x-hex literals, the binary operators
-- + - * / % << >> (integer semantics: / truncates toward zero like C/gas, >> is an
-- arithmetic shift), unary - and +, and parentheses. A symbol may only stand alone
-- or be added to/subtracted from constants: sym*2, sym-sym, -sym and friends are
-- not representable as one displacement and are rejected, as is anything
-- malformed — a misparse must NEVER silently become a 0 immediate/displacement
-- (which is what tonumber's nil used to turn it into). `what` ("immediate" /
-- "displacement") is for error messages.
local function parseDispExpr(text, what)
	-- A GNU-as numeric local label reference (`1f`/`2b`) is a SYMBOL as far as the
	-- operand model is concerned (numlabel.luau rewrites it after parsing).
	if string.match(text, "^%d+[fb]$") then return { sym = text, const = 0 } end
	-- Fast path: a plain literal keeps the exact tonumber semantics it always had,
	-- so every non-expression input behaves byte-identically to before.
	local plain = tonumber(text)
	if plain then return { const = plain } end

	-- Tokenize into operator strings plus { num = n } / { sym = name } tables.
	local tokens = {}
	local i, n = 1, #text
	while i <= n do
		local c = string.sub(text, i, i)
		if string.match(c, "%s") then
			i += 1
		elseif string.match(c, "[%a_.$]") then
			local name = string.match(text, "^[%a_.$][%w_.$]*", i)
			table.insert(tokens, { sym = name })
			i += #name
		elseif string.match(c, "%d") then
			local hex = string.match(text, "^0[xX][0-9a-fA-F]+", i)
			if hex then
				table.insert(tokens, { num = tonumber(hex) })
				i += #hex
			else
				local digits = string.match(text, "^%d+", i)
				-- digits directly followed by f/b are a numeric local label
				-- reference (`1f`/`2b`), which gas accepts anywhere a symbol goes.
				local fb = string.sub(text, i + #digits, i + #digits)
				if fb == "f" or fb == "b" then
					table.insert(tokens, { sym = digits .. fb })
					i += #digits + 1
				else
					table.insert(tokens, { num = tonumber(digits) })
					i += #digits
				end
			end
		elseif c == "<" or c == ">" then
			if string.sub(text, i + 1, i + 1) ~= c then
				error("sarcasm: unsupported operator '" .. c .. "' in " .. what
					.. " expression: " .. text)
			end
			table.insert(tokens, c .. c)
			i += 2
		elseif c == "+" or c == "-" or c == "*" or c == "/" or c == "%"
			or c == "(" or c == ")" then
			table.insert(tokens, c)
			i += 1
		else
			error("sarcasm: unexpected character '" .. c .. "' in " .. what
				.. " expression: " .. text)
		end
	end
	if #tokens == 0 then
		error("sarcasm: empty " .. what .. " expression")
	end

	-- Recursive descent. Every value is { const = n } or { sym = name, const = n }:
	-- a displacement is affine, so at most ONE symbol may appear, and only under
	-- +/- with constants.
	local pos = 0
	local function peek() return tokens[pos + 1] end
	local function take() pos += 1; return tokens[pos] end

	local parseExpr

	local function constOf(v, opname)
		if v.sym then
			error("sarcasm: symbol '" .. v.sym .. "' cannot appear in a '" .. opname
				.. "' " .. what .. " expression: " .. text)
		end
		return v.const
	end

	local function parseFactor()
		local t = take()
		if t == nil then
			error("sarcasm: missing operand in " .. what .. " expression: " .. text)
		end
		if t == "(" then
			local v = parseExpr()
			if take() ~= ")" then
				error("sarcasm: missing ')' in " .. what .. " expression: " .. text)
			end
			return v
		end
		if t == "-" then return { const = -constOf(parseFactor(), "-") } end
		if t == "+" then return { const = constOf(parseFactor(), "+") } end
		if type(t) == "table" then return { sym = t.sym, const = t.num or 0 } end
		error("sarcasm: unexpected '" .. tostring(t) .. "' in " .. what .. " expression: " .. text)
	end

	local function parseTerm()
		local v = parseFactor()
		while true do
			local op = peek()
			if op ~= "*" and op ~= "/" and op ~= "%" and op ~= "<<" and op ~= ">>" then return v end
			take()
			local lhs = constOf(v, op)
			local rhs = constOf(parseFactor(), op)
			if op == "*" then v = { const = lhs * rhs }
			elseif op == "<<" or op == ">>" then
				if rhs < 0 then
					error("sarcasm: negative shift count in " .. what .. " expression: " .. text)
				end
				if op == "<<" then v = { const = lhs * 2^rhs }
				else v = { const = math.floor(lhs / 2^rhs) } end
			elseif rhs == 0 then
				error("sarcasm: division by zero in " .. what .. " expression: " .. text)
			else
				local q = lhs / rhs
				local qt = q >= 0 and math.floor(q) or math.ceil(q)
				if op == "/" then v = { const = qt } else v = { const = lhs - qt * rhs } end
			end
		end
	end

	parseExpr = function()
		local v = parseTerm()
		while true do
			local op = peek()
			if op ~= "+" and op ~= "-" then return v end
			take()
			local rhs = parseTerm()
			if op == "+" then
				if v.sym and rhs.sym then
					error("sarcasm: more than one symbol in " .. what .. " expression ('"
						.. v.sym .. "', '" .. rhs.sym .. "'): " .. text)
				end
				v = { sym = v.sym or rhs.sym, const = v.const + rhs.const }
			else
				if rhs.sym then
					error("sarcasm: subtracting symbol '" .. rhs.sym .. "' in a " .. what
						.. " expression is not a displacement: " .. text)
				end
				v = { sym = v.sym, const = v.const - rhs.const }
			end
		end
	end

	local result = parseExpr()
	if pos ~= #tokens then
		error("sarcasm: unexpected trailing text in " .. what .. " expression: " .. text)
	end
	-- folded: real evaluation happened (the fast paths above leave it nil), so a
	-- caller that re-renders the text (the $-immediate path) canonicalizes it.
	result.folded = true
	return result
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
		-- Fold a constant expression (`$64+32`, `$1<<4`): the value feeds frame-size
		-- and bounds analysis, and when real evaluation happened the folded TEXT
		-- replaces the operand text so every downstream consumer (and the
		-- re-rendered output) sees the constant. A symbolic immediate (`$sym`,
		-- `$sym+8`) keeps its verbatim text — `as` resolves the relocation — as
		-- does an @RELOC decoration, which is never an expression. A malformed
		-- expression is a clean compile error here, never a silent 0.
		if not string.find(t, "@", 1, true) then
			local e = parseDispExpr(t, "immediate")
			if not e.sym then
				return { kind = "imm", text = e.folded and intText(e.const) or t, value = e.const }
			end
		end
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
		-- gas concatenates base/index expressions: `(4096)(%rbx)` means
		-- `4096(%rbx)`. Rewrite any `(...)(` concatenation into the equivalent
		-- single group so the standard parse below covers it.
		while true do
			local gsubbed = string.gsub(field, "%(([^()]*)%)%(", "%1(")
			if gsubbed == field then break end
			field = gsubbed
		end
		pre, inside = string.match(field, "^(.-)%((.*)%)$")
		local mem = { kind = "mem", scale = 1, indirect = indirect }
		pre = trim(pre)
		if pre ~= "" then
			-- The displacement may be a constant expression (`512-128(%rcx)`, or
			-- `(64+32)(%rsp)` after the concatenation rewrite above) or a symbol
			-- plus/minus a folded constant (`K256+512(%rip)`): split any @reloc
			-- decoration first, then fold. A numeric local label reference (`1f`)
			-- stays a symbol for numlabel.luau. dispVal stays nil for a bare
			-- symbol (the exact shape downstream expects) and is set whenever a
			-- nonzero constant rides alongside one (the renderer re-joins them).
			local ps = parseSym(pre)
			if ps.reloc then
				-- @-decorated: a relocation attaches to a symbol, never to a
				-- folded constant — keep the verbatim symbol pass-through.
				mem.dispSym = ps.text
				mem.dispReloc = ps.reloc
			else
				local e = parseDispExpr(ps.text, "displacement")
				mem.dispSym = e.sym
				if not e.sym or e.const ~= 0 then mem.dispVal = e.const end
			end
		end
		local parts = {}
		for p in (inside .. ","):gmatch("(.-),") do table.insert(parts, trim(p)) end
		if parts[1] and parts[1] ~= "" then
			-- A NUMBER in the base position is a displacement (gas: `(4096)` ==
			-- `4096` — an absolute address), never a register: keeping it as the
			-- displacement lets classify reject the absolute access precisely
			-- instead of silently dropping the displacement. The same goes for a
			-- constant EXPRESSION there (`(64+32)` == `96`) — anything starting
			-- with a digit/sign/paren is expression-shaped; other junk keeps the
			-- old silent-drop behavior.
			mem.base = classifyReg(string.sub(parts[1], 2))
			if not mem.base then
				if tonumber(parts[1]) then
					mem.dispVal = tonumber(parts[1])
				elseif string.match(parts[1], "^[%d%+%-%(]") then
					local e = parseDispExpr(parts[1], "displacement")
					mem.dispSym = e.sym
					if not e.sym or e.const ~= 0 then mem.dispVal = e.const end
				end
			end
		end
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
	-- size specifier: BYTE PTR / WORD PTR / ... — the PTR keyword itself is
	-- matched in any case (real assemblers accept `qword ptr`, `QWORD PTR`,
	-- `Qword Ptr`, ... alike); the size word is lowercased for PTRSIZE below.
	local sz, rest = string.match(field, "^(%a+)%s+[Pp][Tt][Rr]%s+(.*)$")
	if sz and PTRSIZE[string.lower(sz)] then size = PTRSIZE[string.lower(sz)]; field = trim(rest) end
	-- memory: optional leading disp then [ ... ]  (GAS Intel: `8[rbx]`, `[rbx+8]`, `[rip+sym]`)
	local pre, inside = string.match(field, "^(.-)%[(.*)%]$")
	if inside ~= nil then
		local mem = { kind = "mem", scale = 1, size = size }
		pre = trim(pre)
		if pre ~= "" then
			-- A leading displacement may be a constant expression (`64+32[rbx]`),
			-- folded like the AT&T displacement above. An @-decorated symbol is
			-- not an expression: keep it verbatim.
			if not string.find(pre, "@", 1, true) then
				local e = parseDispExpr(pre, "displacement")
				mem.dispSym = e.sym
				if not e.sym or e.const ~= 0 then mem.dispVal = e.const end
			else
				mem.dispSym = pre
			end
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
				local ir = rn and classifyReg(rn)
				if ir then
					mem.index = ir; mem.scale = tonumber(sc) or 1
				else
					-- Not reg*scale: a constant-product term (`[rbx+8*4]` = +32),
					-- folded into the displacement. Anything else (sym*K, junk)
					-- is a clean parse error instead of a silently dropped term.
					local e = parseDispExpr(t, "displacement")
					mem.dispVal = (mem.dispVal or 0) + term.sign * e.const
				end
			else
				local r = classifyReg(t)
				if r then
					if r.rc == "rip" then mem.base = r
					elseif not mem.base then mem.base = r else mem.index = r end
				elseif string.find(t, "@", 1, true) then
					-- @-decorated symbol (`[rip+sym@GOTPCREL]`): not an expression,
					-- keep it verbatim (the AT&T renderer re-attaches the reloc).
					mem.dispSym = t
				else
					-- A constant-expression term (`[rbx+1<<4]`, `[rip+K256]`):
					-- fold the constant into the displacement, keep any symbol
					-- bare. A NEGATED symbol (`[rip-sym]`) is not a representable
					-- displacement (gas rejects it too), so error rather than
					-- silently dropping the sign.
					local e = parseDispExpr(t, "displacement")
					if e.sym then
						if term.sign < 0 then
							error("sarcasm: subtracting symbol '" .. e.sym
								.. "' in a displacement expression is not a displacement: " .. field)
						end
						if mem.dispSym then
							error("sarcasm: more than one displacement symbol in memory operand ('"
								.. mem.dispSym .. "', '" .. e.sym .. "'): " .. field)
						end
						mem.dispSym = e.sym
						-- a symbol term carries no constant of its own (the +/- term
						-- split guarantees that), so dispVal keeps its exact old shape
						if e.const ~= 0 then mem.dispVal = (mem.dispVal or 0) + term.sign * e.const end
					else
						mem.dispVal = (mem.dispVal or 0) + term.sign * e.const
					end
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
		-- A digit-led field is an immediate (unlike AT&T, where a bare number is
		-- an absolute memory operand): fold a constant expression (`sub rsp,
		-- 64+32`, `mov eax, 1<<4`) exactly like the AT&T $-immediate path — a
		-- malformed expression errors cleanly instead of silently becoming a
		-- nil-valued (zero for frame purposes) immediate. A symbol caught by the
		-- leading-digit heuristic (`8+sym`) or an @ decoration keeps the
		-- verbatim pass-through.
		if not string.find(field, "@", 1, true) then
			local e = parseDispExpr(field, "immediate")
			if not e.sym then
				return { kind = "imm", text = e.folded and intText(e.const) or field, value = e.const }
			end
		end
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

-- Comments and annotation markers.
--
-- `#` starts a comment that runs to end of line (never inside strings). But
-- `#!` is an ANNOTATION MARKER, like the universal `;!`: on x86_64 GAS, `#` is
-- the comment introducer, so `#!` reads as "a comment that means more". The
-- EARLIEST marker outside a string literal splits the line into code +
-- annotation body (see splitAnnotation below — comment text must not fabricate
-- annotations).
--
-- stripComment truncates `#`-to-EOL (string-aware). It is applied to the text
-- after an annotation marker so a trailing comment is stripped from the body
-- exactly as it was when the whole line was comment-stripped before the split:
-- `movq %rax, (%rbx) ;! store ptr # note` has body `store ptr`. Like the other
-- string-aware scans, a `\` inside a string escapes the following character, so
-- the `#` in `;! store "a \" # b"` is still inside the string; `\` has no
-- quoting power outside strings.
local function stripComment(s)
	local inStr = false
	local i = 1
	while i <= #s do
		local c = string.sub(s, i, i)
		if c == '"' then
			inStr = not inStr
		elseif inStr and c == "\\" then
			-- escaped character inside the string (e.g. the `"` of `\"`): skip it
			-- whole so it can neither close the string nor start structure; this
			-- mirrors arm64 stripComments and detect.luau's sanitize
			i += 1
		elseif not inStr and c == "#" then
			return string.sub(s, 1, i - 1)
		end
		i += 1
	end
	return s
end

-- Split the EARLIEST `;!` or `#!` annotation marker off a line, string-aware
-- (returns code, annotation-or-nil). Text inside a double-quoted string never
-- produces an annotation (`.asciz "a ;! b"` is an ordinary directive), and a
-- `\` inside a string escapes the following character, so `"a \" ;! b"` keeps
-- its `;!` (the string is still open); `\` has no quoting power outside
-- strings. A `#` NOT immediately followed by `!` starts a comment: the rest
-- of the line is dropped and no annotation is fabricated, even if the comment
-- text contains
-- `;!` or `#!` (e.g. `# use ;! load ptr here`). The annotation body is the
-- text after the marker with any trailing `#` comment stripped and then
-- trimmed (`movq %rax, (%rbx) #! store ptr # note` has body `store ptr`).
local function splitAnnotation(s)
	local inStr = false
	local i = 1
	while i <= #s do
		local c = string.sub(s, i, i)
		if c == '"' then
			inStr = not inStr
		elseif inStr and c == "\\" then
			-- escaped character inside the string (e.g. the `"` of `\"`): skip it
			-- whole so it can neither close the string nor be mistaken for a
			-- marker; mirrors arm64 stripComments and detect.luau's sanitize
			i += 1
		elseif not inStr then
			local d = string.sub(s, i + 1, i + 1)
			if (c == ";" or c == "#") and d == "!" then
				-- earliest annotation marker: `;!` or `#!`
				return string.sub(s, 1, i - 1), trim(stripComment(string.sub(s, i + 2)))
			elseif c == "#" then
				-- plain `#` comment: drop the rest of the line, no annotation
				return string.sub(s, 1, i - 1), nil
			end
		end
		i += 1
	end
	return s, nil
end

-- Parse one instruction line (mnemonic plus operand text; labels and annotations
-- already peeled) into an insn statement. parseString uses this for spelled
-- instructions; the .byte decoder (decodeByteInsns below) uses it for the
-- canonical AT&T spellings its byte sequences stand for, so a decoded
-- instruction is indistinguishable from a spelled one in every downstream pass
-- (validation, frame analysis, lift, codegen, rendering).
local function parseInsnText(t, syntax)
	local mnem, rest = string.match(t, "^([%.%w_][%w_.]*)%s*(.*)$")
	if not mnem then
		-- The line starts with something that can neither begin a mnemonic nor a
		-- directive (e.g. `//!` annotation text, which is NOT a marker on x86_64
		-- and so stays in the code part). Raise a normal parse error rather than
		-- choking on string.sub(nil, ...) below (a latent crash for such lines
		-- before markers existed).
		error("sarcasm: cannot parse line: " .. t)
	end
	rest = trim(rest or "")
	-- `lock` is an instruction PREFIX, not a mnemonic: gas emits it as a leading
	-- token on the same line (`lock xaddq %rsi, (%rdi)`, also
	-- `lock;`-separated). Re-split the remainder into the real mnemonic +
	-- operands and tag the instruction; WHICH instructions may carry the prefix
	-- is validated in x86_64_isa.classify. rep*/xacquire/xrelease stay
	-- reject-listed "mnemonics" (fp.unsafeReject) — only `lock` gets prefix
	-- parsing.
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
	return { kind = "insn", mnemonic = string.lower(mnem), operands = ops,
		opsize = opsize, raw = t, syntax = syntax, lockPrefix = lockPrefix or nil }
end

function x86parse.parseString(text, syntax)
	local out = {}
	text = (string.gsub(text, "\r\n", "\n"))
	local lineNo = 0
	for raw in (text .. "\n"):gmatch("(.-)\n") do
		lineNo += 1
		-- Split the annotation marker (`;!` everywhere, or `#!` — on x86_64 `#` is
		-- the comment introducer, so `#!` is "a comment that means more") off the
		-- line, string-aware. Comment text must never fabricate an annotation: a
		-- line like `# use ;! load ptr here` would otherwise attach a spurious
		-- annotation to an otherwise-empty statement, which the shared body
		-- validation rejects ("annotation on an otherwise-empty line"); the arm64
		-- parser keeps `//`/`//!`/`/* */` comments out of annotations the same
		-- way. A `#` after the annotation still ends a trailing comment inside
		-- the body.
		local code, annotation = splitAnnotation(raw)
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
				if not mnem then
					-- The line starts with something that can neither begin a
					-- mnemonic nor a directive (e.g. `//!` annotation text, which is
					-- NOT a marker on x86_64 and so stays in the code part). Raise a
					-- normal parse error rather than choking on string.sub(nil, ...)
					-- below (a latent crash for such lines before markers existed).
					error("sarcasm: cannot parse line: " .. t)
				end
				rest = trim(rest or "")
				if string.sub(mnem, 1, 1) == "." then
					table.insert(out, { kind = "directive", name = mnem, args = rest, raw = t })
				else
					table.insert(out, parseInsnText(t, syntax))
				end
			end
		end
		if annotation and #out > before then out[#out].annotation = annotation end
		for k = before + 1, #out do out[k].line = out[k].line or lineNo end
	end
	numlabel.resolve(out)
	return out
end

-- .byte instruction decoding (OpenSSL perlasm legacy-gas workarounds) -----------
--
-- OpenSSL's perlasm emits many instructions as raw `.byte` sequences inside
-- function bodies (legacy-gas workarounds): every function ends with
-- `.byte 0xf3,0xc3` (rep ret), CET entry points are `.byte 243,15,30,250`
-- (endbr64), locked RMWs are a `.byte 0xf0` line followed by the spelled
-- instruction, prologue stack adjustments are `.byte 0x48,0x83,0xEC,0x08`, and
-- so on. Data in a function body is rejected (transform's validateBody), so
-- such inputs would not compile at all. decodeByteInsns rewrites a function
-- body's RUNS of adjacent `.byte` statements into the instructions those byte
-- sequences encode — at parse time, by re-parsing the canonical AT&T spelling
-- through parseInsnText, so the result is indistinguishable from a spelled
-- instruction for every downstream pass (a decoded `ret` IS a `ret` to the
-- frame pass and the fall-off reachability check; a decoded `lock cmpxchgl`
-- carries the same lockPrefix tag a spelled one does, with identical
-- validation). Sequences that do not match the table stay `.byte` directives,
-- so genuine data keeps hitting the exact same "data in a function body"
-- compile error as before (a clean sarcasm error, never a crash).
--
-- The table is data-driven: an ordered list of { bytes = {..}, text = ".."},
-- plus the special `lock` marker (0xf0), which JOINS the following instruction
-- — the next bytes of the same run, or the spelled instruction on the next
-- line — exactly like the spelled `lock` prefix (x86_64_isa.lockAllows decides
-- whether the joined instruction may carry it, so a byte-encoded `lock ret`
-- rejects precisely like the spelled form). Matching is greedy longest-first
-- at each buffer position; no table entry is a prefix of another today, but
-- the longest-match rule keeps future entries order-independent.
local BYTE_DECODE = {
	-- rep ret: the 0xf3 is an AMD branch-prediction hint; treat exactly like ret.
	{ bytes = { 0xf3, 0xc3 }, text = "ret" },
	-- CET indirect-branch landing pad (modeled as a nop by x86_64_isa).
	{ bytes = { 0xf3, 0x0f, 0x1e, 0xfa }, text = "endbr64" },
	{ bytes = { 0x0f, 0x0b }, text = "ud2" },
	-- the 3-byte padding nop; its (%rax) operand is an encoding hint, not an access.
	{ bytes = { 0x0f, 0x1f, 0x00 }, text = "nopl (%rax)" },
	-- 0xf0 lock prefix: joins the next instruction (see the long comment above).
	{ bytes = { 0xf0 }, lock = true },
	{ bytes = { 0x48, 0x98 }, text = "cdqe" },          -- aka cltq
	{ bytes = { 0x0f, 0x01, 0xd0 }, text = "xgetbv" },
	{ bytes = { 0x49, 0x0f, 0xc7, 0xf2 }, text = "rdrand %r10" },  -- REX.WB 0f c7 /6, r10
	{ bytes = { 0x49, 0x0f, 0xc7, 0xfa }, text = "rdseed %r10" },  -- REX.WB 0f c7 /7, r10
	-- frame-relevant prologue forms (must be real sub/lea to the frame pass):
	{ bytes = { 0x48, 0x83, 0xec, 0x08 }, text = "subq $8,%rsp" },
	{ bytes = { 0x48, 0x83, 0xec, 0x28 }, text = "subq $40,%rsp" },
	{ bytes = { 0x48, 0x81, 0xec, 0x08, 0x01, 0x00, 0x00 }, text = "subq $0x108,%rsp" },
	{ bytes = { 0x4c, 0x8d, 0x14, 0x24 }, text = "leaq (%rsp),%r10" },
	-- single-byte filler prefixes gas emits as standalone `.byte` lines for
	-- alignment padding: each lone byte is its own nop.
	{ bytes = { 0x66 }, text = "nop" },
	{ bytes = { 0x67 }, text = "nop" },
	{ bytes = { 0x3e }, text = "nop" },
}

-- Parse the byte values of a `.byte` directive's argument list: a
-- comma-separated list of decimal or 0x-hex literals, each in [0, 255]. Returns
-- the array of values, or nil when any field is not a plain byte literal (such
-- a directive is data — a symbol, an expression, an out-of-range value — not an
-- instruction encoding, and stays for the downstream data rejection).
local function byteValues(args)
	local vals = {}
	for _, f in splitOperands(args or "") do
		local v = tonumber(f)
		if not v or v ~= math.floor(v) or v < 0 or v > 255 then return nil end
		table.insert(vals, v)
	end
	if #vals == 0 then return nil end
	return vals
end

-- Find the longest table entry matching `bytes` at `pos` (first-listed wins a
-- length tie). Returns the entry and its length, or nil.
local function matchBytes(bytes, pos)
	local best, bestLen = nil, 0
	for _, e in BYTE_DECODE do
		local eb = e.bytes
		if #eb > bestLen and pos + #eb - 1 <= #bytes then
			local match = true
			for k = 1, #eb do
				if bytes[pos + k - 1] ~= eb[k] then match = false break end
			end
			if match then best, bestLen = e, #eb end
		end
	end
	return best, bestLen
end

-- Rewrite the decodable `.byte` runs of a function body (a statement array as
-- produced by parseString and splitFunctions) into insn statements. Returns the
-- new body; bodies with no `.byte` directives are returned unchanged. Runs that
-- do not fully decode keep their undecodable bytes as `.byte` directives (a
-- whole undecodable run is kept byte-for-byte as written), so the downstream
-- "data in a function body" rejection fires exactly as it does without this
-- pass. x86_64-only: the encodings (and the perlasm idiom) do not exist on
-- arm64, whose top-level/body data rules are unchanged.
function x86parse.decodeByteInsns(body)
	local hasBytes = false
	for _, st in body do
		if st.kind == "directive" and st.name == ".byte" then hasBytes = true break end
	end
	if not hasBytes then return body end

	local out = {}
	local i, n = 1, #body
	while i <= n do
		local st = body[i]
		if st.kind ~= "directive" or st.name ~= ".byte" then
			table.insert(out, st)
			i += 1
		else
			-- maximal run of ADJACENT `.byte` statements [i..j]. A label (or any
			-- other statement) breaks the run: bytes on either side of a label
			-- are not one instruction — a branch to the label would land in the
			-- middle of the encoding.
			local j = i
			while j + 1 <= n and body[j + 1].kind == "directive"
				and body[j + 1].name == ".byte" do
				j += 1
			end
			-- An annotation anywhere in the run must never be silently dropped
			-- or moved onto a decoded instruction: keep the run verbatim and let
			-- validateBody reject it (annotation on a directive / data in a
			-- function body) with its own precise message.
			local annotated = false
			for k = i, j do
				if body[k].annotation then annotated = true break end
			end
			if annotated then
				for k = i, j do table.insert(out, body[k]) end
				i = j + 1
			else
				-- Accumulate the run's byte values (tracking the source line of
				-- each byte for origins on the decoded instructions). A
				-- statement whose args are not all plain byte literals ends the
				-- accumulation; it (and the rest of the run) stays verbatim.
				local bytes, lines = {}, {}
				local overflow = nil
				for k = i, j do
					local vals = byteValues(body[k].args)
					if not vals then overflow = k break end
					for _, v in vals do
						table.insert(bytes, v)
						table.insert(lines, body[k].line)
					end
				end
				-- Greedy longest-match decode of the buffer.
				local decoded = {}
				local pos = 1
				local lockPos = nil   -- buffer position of a pending (unjoined) lock byte
				while pos <= #bytes do
					local e, elen = matchBytes(bytes, pos)
					if not e then break end
					if e.lock then
						lockPos = pos
						pos += elen
					else
						local insn = parseInsnText(e.text, "att")
						insn.line = lines[pos]
						if lockPos then insn.lockPrefix = true; lockPos = nil end
						table.insert(decoded, insn)
						pos += elen
					end
				end
				-- A lock byte pending at the end of the buffer joins the SPELLED
				-- instruction following the run (OpenSSL's `.byte 0xf0` +
				-- `cmpxchgl ...` idiom): tag it exactly like the parser's
				-- spelled-`lock` path does. Any non-instruction follower leaves
				-- the lock byte undecoded (it rejoins the data below).
				local joined = false
				if lockPos and pos > #bytes and not overflow then
					local nxt = body[j + 1]
					if nxt and nxt.kind == "insn" then
						nxt.lockPrefix = true
						joined = true
						lockPos = nil
					end
				end
				-- Where the undecodable tail starts (the pending lock byte takes
				-- precedence: it never decoded into anything).
				local leftoverStart = lockPos or (pos <= #bytes and pos or nil)
				if #decoded == 0 and not joined then
					-- Nothing decoded at all: keep the run byte-for-byte as
					-- written — the downstream data rejection sees the original
					-- directive text.
					for k = i, j do table.insert(out, body[k]) end
				else
					for _, insn in decoded do table.insert(out, insn) end
					if leftoverStart then
						local parts = {}
						for p = leftoverStart, #bytes do
							table.insert(parts, string.format("0x%02x", bytes[p]))
						end
						local args = table.concat(parts, ",")
						table.insert(out, { kind = "directive", name = ".byte",
							args = args, raw = ".byte " .. args, line = lines[leftoverStart] })
					end
					if overflow then
						for k = overflow, j do table.insert(out, body[k]) end
					end
				end
				i = j + 1
			end
		end
	end
	return out
end

return x86parse
