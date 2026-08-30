--!nonstrict
-- sarcasm assembly parser for ARM64 GNU-as / clang assembly.
--
-- Produces a flat list of "statements". Each statement is one of:
--   { kind = "blank",     text = <original> }
--   { kind = "label",     name = <string>, annotation = <string?> }
--   { kind = "directive", name = ".text", args = <string>, raw = <string>, annotation = <string?> }
--   { kind = "insn",      mnemonic = "ldr", operands = { <operand>... }, cond = <string?>,
--                         annotation = <string?>, raw = <string> }
--
-- Operands are structured:
--   { kind = "reg",  name = "x0", rc = "gpr"|"neon"|"sve"|"sp"|"zr", width = 32|64|..., shift = <shift?> }
--   { kind = "imm",  text = "5381", value = <number?> }
--   { kind = "sym",  text = "foo+16", reloc = <string?> }   -- reloc e.g. "lo12","got","got_lo12"
--   { kind = "mem",  base = <reg>, index = <operand?>, writeback = "pre"|"post"|nil,
--                    shift = <shift?>, text = <original> }
--   { kind = "reglist", regs = {<neon reg>...}, lane = <number?>, text = <original> }
--
-- NEON register operands carry their arrangement/element qualification:
--   v0.16b / v3.2d -> { kind="reg", rc="neon", arrangement = { lanes = 16|nil, elem = "b" } }
--   v0.d[1]        -> { kind="reg", rc="neon", element = { elem = "d", index = 1 } }
--   b0/h0/s0/d0/q0/v0 (bare) -> rc="neon", width in BITS (8/16/32/64/128)
-- SVE registers (z0-31, p0-15, bare or .b/.h/.s/.d-qualified, predicates with /z or /m)
-- parse as rc="sve" so the ISA layer can reject them cleanly.
-- A shift is { op = "lsl"|"lsr"|"asr"|"ror"|"uxtb"|... , amount = <number?>, amountText = <string?> }

local numlabel = require("./numlabel")

local parse = {}

local SHIFT_OPS = {
	lsl = true, lsr = true, asr = true, ror = true, msl = true,
	uxtb = true, uxth = true, uxtw = true, uxtx = true,
	sxtb = true, sxth = true, sxtw = true, sxtx = true,
}

-- Registers ---------------------------------------------------------------

-- Classify a bare register token. Returns a reg operand table, or nil.
local function classifyReg(tok: string)
	local low = string.lower(tok)
	if low == "sp" then
		return { kind = "reg", name = "sp", rc = "sp", width = 64 }
	end
	if low == "wsp" then
		return { kind = "reg", name = "wsp", rc = "sp", width = 32 }
	end
	if low == "xzr" then
		return { kind = "reg", name = "xzr", rc = "zr", width = 64 }
	end
	if low == "wzr" then
		return { kind = "reg", name = "wzr", rc = "zr", width = 32 }
	end
	-- gcc-style aliases: fp = x29 (frame pointer), lr = x30 (link register).
	if low == "fp" then
		return { kind = "reg", name = "x29", rc = "gpr", width = 64, num = 29 }
	end
	if low == "lr" then
		return { kind = "reg", name = "x30", rc = "gpr", width = 64, num = 30 }
	end
	-- NEON lane-qualified vector register: v0.16b, v3.4s, v12.2d, v0.1q.
	local vn, lanes, elem = string.match(low, "^v(%d+)%.(%d*)([bhsdq])$")
	if vn and tonumber(vn) <= 31 then
		return { kind = "reg", name = low, rc = "neon", width = 128, num = tonumber(vn),
			arrangement = { lanes = (lanes ~= "" and tonumber(lanes) or nil), elem = elem } }
	end
	-- NEON single-element reference: v0.b[3], v0.d[1], v4.h[0].
	local en, eelem, eidx = string.match(low, "^v(%d+)%.([bhsdq])%[(%d+)%]$")
	if en and tonumber(en) <= 31 then
		return { kind = "reg", name = low, rc = "neon", width = 128, num = tonumber(en),
			element = { elem = eelem, index = tonumber(eidx) } }
	end
	-- SVE scalable vector / predicate registers (parsed so the ISA layer can reject
	-- them cleanly): z0-z31 bare or .b/.h/.s/.d-qualified, p0-p15 bare, qualified,
	-- or with a /z or /m predication suffix.
	local zn = string.match(low, "^z(%d+)$") or string.match(low, "^z(%d+)%.[bhsdq]$")
	if zn and tonumber(zn) <= 31 then
		return { kind = "reg", name = low, rc = "sve", width = 128, num = tonumber(zn) }
	end
	local pn = string.match(low, "^p(%d+)$") or string.match(low, "^p(%d+)%.[bhsdq]$")
		or string.match(low, "^p(%d+)/[zm]$") or string.match(low, "^p(%d+)%.[bhsdq]/[zm]$")
	if pn and tonumber(pn) <= 15 then
		return { kind = "reg", name = low, rc = "sve", width = 32, num = tonumber(pn) }
	end
	local prefix, num = string.match(low, "^([a-z]+)(%d+)$")
	if prefix and num then
		local n = tonumber(num)
		if prefix == "x" and n <= 30 then
			return { kind = "reg", name = low, rc = "gpr", width = 64, num = n }
		elseif prefix == "w" and n <= 30 then
			return { kind = "reg", name = low, rc = "gpr", width = 32, num = n }
		elseif (prefix == "v" or prefix == "q" or prefix == "d" or prefix == "s" or prefix == "h" or prefix == "b") and n <= 31 then
			local bits = (prefix == "b") and 8 or (prefix == "h") and 16
				or (prefix == "s") and 32 or (prefix == "d") and 64 or 128
			return { kind = "reg", name = low, rc = "neon", width = bits, num = n }
		end
	end
	return nil
end
parse.classifyReg = classifyReg

-- Given a gpr num and desired width, return the canonical name.
function parse.gprName(num: number, width: number): string
	if width == 32 then
		return "w" .. tostring(num)
	end
	return "x" .. tostring(num)
end

-- Operand tokenization ----------------------------------------------------

-- Split an operand string into top-level comma-separated fields, respecting
-- [], () and {} (NEON structure lists) nesting.
local function splitTopLevel(s: string): { string }
	local out = {}
	local depth = 0
	local cur = {}
	local i = 1
	local n = #s
	while i <= n do
		local c = string.sub(s, i, i)
		if c == "[" or c == "(" or c == "{" then
			depth += 1
			table.insert(cur, c)
		elseif c == "]" or c == ")" or c == "}" then
			depth -= 1
			table.insert(cur, c)
		elseif c == "," and depth == 0 then
			table.insert(out, table.concat(cur))
			cur = {}
		else
			table.insert(cur, c)
		end
		i += 1
	end
	table.insert(out, table.concat(cur))
	-- trim
	for idx, field in out do
		out[idx] = (string.gsub(field, "^%s*(.-)%s*$", "%1"))
	end
	return out
end
parse.splitTopLevel = splitTopLevel

-- Parse a shift/extend field like "lsl 5", "lsl #5", "uxtb", "sxtw".
local function parseShift(field: string)
	local op, rest = string.match(field, "^(%a+)%s*(.*)$")
	if not op or not SHIFT_OPS[string.lower(op)] then
		return nil
	end
	op = string.lower(op)
	rest = (string.gsub(rest, "^%s*(.-)%s*$", "%1"))
	local amount, amountText
	if rest ~= "" then
		amountText = rest
		local numtxt = (string.gsub(rest, "^#", ""))
		amount = tonumber(numtxt)
	end
	return { op = op, amount = amount, amountText = amountText }
end

-- Parse a NEON/SVE structure-list operand field: `{v0.16b, v1.16b}` (full
-- structures), `{v0.b}[3]` / `{v0.h, v1.h}[1]` (single-element with a lane
-- index). Returns a reglist operand, or nil if malformed.
local function parseRegList(field: string)
	local inner, rest = string.match(field, "^(%b{})%s*(.-)%s*$")
	if not inner then return nil end
	local body = string.sub(inner, 2, -2)
	local regs = {}
	for part in string.gmatch(body .. ",", "(.-),") do
		local r = classifyReg((string.gsub(part, "^%s*(.-)%s*$", "%1")))
		if not r or (r.rc ~= "neon" and r.rc ~= "sve") then return nil end
		table.insert(regs, r)
	end
	if #regs == 0 then return nil end
	local lane = string.match(rest, "^%[(%d+)%]$")
	if rest ~= "" and not lane then return nil end
	return { kind = "reglist", regs = regs, lane = lane and tonumber(lane) or nil, text = field }
end

-- Parse a single (non-memory, non-shift) operand field.
local function parseSimple(field: string)
	-- register?
	local reg = classifyReg(field)
	if reg then
		return reg
	end
	-- NEON/SVE structure list ({v0.16b, v1.16b} / {v0.b}[3]): the only legal
	-- operand starting with '{' in A64 assembly, so a malformed one is an error,
	-- not a symbol (silently treating it as a symbol would hide the access width).
	if string.sub(field, 1, 1) == "{" then
		local rl = parseRegList(field)
		if not rl then
			error("sarcasm: malformed register list operand '" .. field .. "'")
		end
		return rl
	end
	-- immediate: #num, num, 0x..., -num
	local imm = string.match(field, "^#(.+)$")
	if imm then
		return { kind = "imm", text = imm, value = tonumber(imm) }
	end
	-- numeric local label reference: `1f` / `1b` (next/previous `1:` definition)
	local nref, ndir = string.match(field, "^(%d+)([fb])$")
	if nref then
		return { kind = "numref", text = field, num = nref, dir = ndir }
	end
	if string.match(field, "^-?%d") or string.match(field, "^0[xX]") then
		return { kind = "imm", text = field, value = tonumber(field) }
	end
	-- reloc-decorated symbol: :lo12:sym, :got:sym, etc.
	local reloc, sym = string.match(field, "^:(%w+):(.+)$")
	if reloc then
		return { kind = "sym", text = sym, reloc = reloc }
	end
	-- plain symbol / label / expression
	return { kind = "sym", text = field }
end

-- Parse a memory operand starting with '['.
local function parseMem(field: string, postIndex: string?)
	local writeback = nil
	local inner = field
	if string.sub(inner, -1) == "!" then
		writeback = "pre"
		inner = string.sub(inner, 1, -2)
	end
	-- strip [ ]
	inner = string.match(inner, "^%[(.*)%]$") or inner
	inner = (string.gsub(inner, "^%s*(.-)%s*$", "%1"))
	local parts = splitTopLevel(inner)
	local base = parseSimple(parts[1])
	local mem = { kind = "mem", base = base, text = field, writeback = writeback }
	if #parts >= 2 then
		-- second part is index/offset; third (if any) is a shift/extend on the index
		local idx = parts[2]
		local sh = parseShift(idx)
		if sh then
			mem.shift = sh
		else
			mem.index = parseSimple(idx)
		end
		if #parts >= 3 then
			mem.shift = parseShift(parts[3])
		end
	end
	if postIndex then
		mem.writeback = "post"
		local sh = parseShift(postIndex)
		if sh then
			mem.postShift = sh
		else
			mem.index = parseSimple(postIndex)
		end
	end
	return mem
end

-- Parse the full operand list of an instruction.
local function parseOperands(s: string)
	s = (string.gsub(s, "^%s*(.-)%s*$", "%1"))
	if s == "" then
		return {}
	end
	local fields = splitTopLevel(s)
	local operands = {}
	local i = 1
	while i <= #fields do
		local field = fields[i]
		if field == "" then
			i += 1
		elseif string.sub(field, 1, 1) == "[" then
			-- memory operand; check for post-index (a following field that is
			-- not a shift and this bracket has no '!').
			if string.sub(field, -1) ~= "!" and i + 1 <= #fields and not parseShift(fields[i + 1]) then
				table.insert(operands, parseMem(field, fields[i + 1]))
				i += 2
			else
				table.insert(operands, parseMem(field, nil))
				i += 1
			end
		else
			local sh = parseShift(field)
			if sh and #operands > 0 then
				-- attach to previous operand
				operands[#operands].shift = sh
			else
				table.insert(operands, parseSimple(field))
			end
			i += 1
		end
	end
	return operands
end
parse.parseOperands = parseOperands

-- Line splitting ----------------------------------------------------------

-- Remove a trailing // comment that is not inside a string literal. A `\`
-- inside a string escapes the following character (so `"a \" // x"` keeps its
-- slashes), mirroring stripComments below; `\` has no quoting power outside
-- strings.
local function stripLineComment(s: string): string
	local inStr = false
	local i = 1
	local n = #s
	while i <= n do
		local c = string.sub(s, i, i)
		if c == '"' then
			inStr = not inStr
		elseif inStr and c == "\\" then
			-- escaped character inside the string (e.g. the `"` of `\"`): skip it
			-- whole so it cannot close the string and expose a `//` that is still
			-- inside the string
			i += 1
		elseif not inStr and c == "/" and string.sub(s, i + 1, i + 1) == "/" then
			return string.sub(s, 1, i - 1)
		end
		i += 1
	end
	return s
end

-- Remove comments from the whole text before line splitting: `/* ... */` (inline and
-- multi-line) and `//` to end of line, neither of which may appear inside a
-- double-quoted string (`.asciz "a // b"` keeps its slashes). `#` is NOT a comment
-- here -- on arm64 it introduces an immediate, and `#!` is not an annotation marker
-- either, so `#!` text stays in the code part and produces a normal parse error. The
-- one exception to `//` starting a comment: `//!` is an annotation marker ("a comment
-- that means more", the arm64 sibling of the universal `;!`), so it is emitted
-- verbatim for splitAnnotation to find while the rest of the line keeps being scanned
-- (a later `//` on the same line is still a comment). Block comments still take
-- precedence, so `/* //! load ptr */` is a comment, not an annotation. A comment is
-- replaced by a single space (comments act as token separators in GAS); newlines
-- inside block comments are kept so statement line numbers still match the source.
local function stripComments(text: string): string
	local out = {}
	local i, n = 1, #text
	local state = "code" -- code | str | line | block
	while i <= n do
		local c = string.sub(text, i, i)
		local d = string.sub(text, i + 1, i + 1)
		if state == "code" then
			if c == '"' then
				state = "str"
				table.insert(out, c)
			elseif c == "/" and d == "/" then
				if string.sub(text, i + 2, i + 2) == "!" then
					-- `//!` is an annotation marker, not a comment: keep it
					-- verbatim so splitAnnotation can find it
					table.insert(out, c)
					table.insert(out, d)
					table.insert(out, "!")
					i += 2
				else
					state = "line"
					table.insert(out, " ")
					i += 1
				end
			elseif c == "/" and d == "*" then
				state = "block"
				table.insert(out, " ")
				i += 1
			else
				table.insert(out, c)
			end
		elseif state == "str" then
			table.insert(out, c)
			if c == "\\" then
				local e = string.sub(text, i + 1, i + 1)
				if e ~= "" then table.insert(out, e); i += 1 end
			elseif c == '"' then
				state = "code"
			elseif c == "\n" then
				state = "code" -- unterminated string; resync at the line boundary
			end
		elseif state == "line" then
			if c == "\n" then
				state = "code"
				table.insert(out, c)
			end
		else -- block
			if c == "*" and d == "/" then
				state = "code"
				i += 1
			elseif c == "\n" then
				table.insert(out, c)
			end
		end
		i += 1
	end
	return table.concat(out)
end
parse.stripComments = stripComments

local function trim(s: string): string
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- Split off an annotation marker (returns code, annotation-or-nil). Markers are
-- `;!` (supported on all architectures) and `//!` (`//` is the comment introducer
-- on arm64, so `//!` reads as "a comment that means more"). The EARLIEST marker
-- outside a string literal wins; the body is the trimmed text after the marker,
-- taken verbatim (stripComments already removed `//` and `/* */` comments). Text
-- inside a double-quoted string never produces an annotation, so `.asciz "a ;! b"`
-- and `.asciz "a //! b"` are ordinary directives, and a `\` inside a string
-- escapes the following character (so `"a \" ;! b"` keeps its `;!`), exactly as
-- in stripComments above; `\` has no quoting power outside strings. `#!` is not
-- a marker here: it stays in the code part and produces a normal parse error.
local function splitAnnotation(s: string): (string, string?)
	local inStr = false
	local i, n = 1, #s
	while i <= n do
		local c = string.sub(s, i, i)
		if c == '"' then
			inStr = not inStr
		elseif inStr and c == "\\" then
			-- escaped character inside the string (e.g. the `"` of `\"`): skip it
			-- whole so it can neither close the string nor be mistaken for a
			-- marker; mirrors stripComments above
			i += 1
		elseif not inStr then
			local d = string.sub(s, i + 1, i + 1)
			if c == ";" and d == "!" then
				return string.sub(s, 1, i - 1), trim(string.sub(s, i + 2))
			elseif c == "/" and d == "/" and string.sub(s, i + 2, i + 2) == "!" then
				return string.sub(s, 1, i - 1), trim(string.sub(s, i + 3))
			end
		end
		i += 1
	end
	return s, nil
end

-- Parse one source line into zero or more statements, appending to `out`.
local function parseLine(rawLine: string, out)
	local code, annotation = splitAnnotation(rawLine)
	code = stripLineComment(code)
	local trimmed = trim(code)

	if trimmed == "" then
		if annotation then
			-- annotation on an otherwise-blank line: attach to a blank marker
			table.insert(out, { kind = "blank", text = rawLine, annotation = annotation })
		else
			table.insert(out, { kind = "blank", text = rawLine })
		end
		return
	end

	-- Peel labels off the front: NAME:
	while true do
		local name, rest = string.match(trimmed, "^([%w_.$][%w_.$@]*):%s*(.*)$")
		if not name then
			break
		end
		table.insert(out, { kind = "label", name = name })
		trimmed = trim(rest)
		if trimmed == "" then
			break
		end
	end

	-- Attach annotation to the last produced statement for this line (if any),
	-- but if there's remaining code, it will be attached below instead.
	if trimmed == "" then
		if annotation and #out > 0 then
			out[#out].annotation = annotation
		end
		return
	end

	-- Directive or instruction.
	local mnemonic, rest = string.match(trimmed, "^([%.%w_][%w_.]*)%s*(.*)$")
	if not mnemonic then
		table.insert(out, { kind = "directive", name = trimmed, args = "", raw = trimmed, annotation = annotation })
		return
	end
	rest = trim(rest)

	if string.sub(mnemonic, 1, 1) == "." then
		table.insert(out, {
			kind = "directive",
			name = mnemonic,
			args = rest,
			raw = trimmed,
			annotation = annotation,
		})
		return
	end

	-- Instruction. Split optional condition suffix off branch mnemonics like b.hs.
	local operands = parseOperands(rest)
	table.insert(out, {
		kind = "insn",
		mnemonic = mnemonic,
		operands = operands,
		annotation = annotation,
		raw = trimmed,
	})
end

function parse.parseString(text: string)
	local out = {}
	-- normalize CRLF
	text = (string.gsub(text, "\r\n", "\n"))
	-- strip C/C++ comments (string-literal aware) before line splitting; the `//!`
	-- annotation marker survives this pass so splitAnnotation can find it
	text = stripComments(text)
	local lineNo = 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		lineNo += 1
		local before = #out
		parseLine(line, out)
		-- stamp every statement produced from this source line with its line number
		for k = before + 1, #out do out[k].line = lineNo end
	end
	numlabel.resolve(out)
	return out
end

return parse
