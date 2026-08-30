--!nonstrict
-- Auto-detect the target architecture (arm64 vs x86_64) and, for x86_64, the assembly
-- syntax (att vs intel) from the input assembly text.
--
-- Directives (.intel_syntax/.att_syntax/.arch armv8) decide first. Then the x86_64
-- markers, strongest first: AT&T % register names (GPRs %r*/%e*, %rip; then the
-- vector/x87/opmask names %xmm/%ymm/%zmm/%k0-7/%st), AT&T-only instruction shapes with
-- no register marker at all (movz/movs double suffixes, movabs, the sign/byte extension
-- family, q-suffixed ALU mnemonics, line-anchored rep/lock prefixes), Intel bare vector
-- register names, and finally Intel bare GPR/PTR/bracket markers. arm64 is the
-- fallback. The same markers can be bypassed entirely with the sarcasm CLI's
-- --x86_64/--arm64/--intel/--at&t target options.

local detect = {}

-- Blank out comment text and string-literal contents before marker matching, so that
-- x86 markers mentioned in a comment or an .asciz payload of an arm64 file (and vice
-- versa) cannot spoof the architecture. Handled: `//` to end of line, `/* ... */`
-- (multi-line), `#` to end of line (the comment character in x86 GAS and in
-- preprocessor/full-line comments of clang arm64 output; stripping a mid-line arm64
-- `#immediate` is harmless -- it can only suppress x86 markers, never fabricate one),
-- and double-quoted strings (with backslash escapes). Newlines are preserved so the
-- result lines up with the input.
local function sanitize(text: string): string
	local out = {}
	local i, n = 1, #text
	local state = "code" -- code | str | line | block
	while i <= n do
		local c = string.sub(text, i, i)
		local d = string.sub(text, i + 1, i + 1)
		if state == "code" then
			if c == '"' then
				state = "str"
			elseif c == "/" and d == "/" then
				state = "line"
				i += 1
			elseif c == "/" and d == "*" then
				state = "block"
				i += 1
			elseif c == "#" then
				state = "line"
			else
				table.insert(out, c)
			end
		elseif state == "str" then
			if c == "\\" then
				i += 1 -- skip the escaped character too (e.g. \" does not end the string)
			elseif c == '"' then
				state = "code"
			elseif c == "\n" then
				state = "code" -- asm strings cannot span lines; resync
				table.insert(out, c)
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
detect.sanitize = sanitize

-- Returns arch ("arm64"|"x86_64"), syntax ("att"|"intel"|nil).
function detect.detect(text)
	text = sanitize(text)
	-- Strong, unambiguous markers first.
	if string.find(text, "%.intel_syntax") then return "x86_64", "intel" end
	if string.find(text, "%.att_syntax") then return "x86_64", "att" end
	if string.find(text, "%.arch%s+armv8") then return "arm64", nil end

	-- AT&T uses % register prefixes; x86 also has endbr64 / RIP-relative.
	if string.find(text, "%%r[a-z0-9]") or string.find(text, "%%e[a-z][a-z]")
		or string.find(text, "%%rip") or string.find(text, "endbr64", 1, true) then
		return "x86_64", "att"
	end

	-- x86-only AT&T instruction shapes that carry no % GPR marker: a register file of
	-- pure vector/x87/opmask registers (`movss myglobal, %xmm0`), the movz/movs
	-- double-suffix family (`movzbl`, `movzwq`, `movslq`, ...), `movabs`, the x86-only
	-- sign/byte extension family (`cltq`, `cqto`, `cwde`, ...), q-suffixed ALU/stack
	-- mnemonics (`movq`, `addq`, `pushq`, ...), and the rep/lock prefixes. None of
	-- these can occur in arm64 assembly, so any match proves x86_64; the shapes only
	-- occur in AT&T output, so the syntax is AT&T. (An .intel_syntax file that spelled
	-- a q-suffixed mnemonic would be misdetected here, but such a file is already
	-- caught by the .intel_syntax directive check above.)
	--
	-- These checks are anchored on a whitespace-preceded token, and a mnemonic in
	-- column 1 of the first line has no preceding whitespace in the raw text, so match
	-- against the text with a newline prepended. The newline also line-anchors the
	-- rep/lock prefix checks, so a label like `rep:` cannot spoof a prefix (Lua's `^`
	-- would anchor to the start of the whole string only).
	local anchored = "\n" .. text
	local att = string.find(anchored, "%%xmm%d") or string.find(anchored, "%%ymm%d")
		-- vector/x87/opmask register names (x87 `%st` also covers `%st(1)`).
		or string.find(anchored, "%%zmm%d") or string.find(anchored, "%%k[0-7]")
		or string.find(anchored, "%%st")
		-- movz/movs double-suffix family and movabs.
		or string.find(anchored, "%smovz[bwlq][bwlq]%f[^%w]")
		or string.find(anchored, "%smovs[bwlq][bwlq]%f[^%w]")
		or string.find(anchored, "%smovabs%f[^%w]")
	-- The x86-only sign/byte extension family (each its own word-bounded token).
	for _, ext in {"cltq", "cdqe", "cqto", "cltd", "cwde", "cbtw", "cwtl", "cwtd", "cdq", "cwd", "cbw"} do
		att = att or string.find(anchored, "%s" .. ext .. "%f[^%w]")
	end
	-- q-suffixed common ALU/stack mnemonics (` movq `, ` addq `, ...).
	for _, m in {"mov", "add", "sub", "and", "or", "xor", "cmp", "test", "lea", "shl",
		"shr", "sar", "sal", "imul", "neg", "not", "inc", "dec", "adc", "sbb", "push",
		"pop", "xadd", "div", "idiv", "mul"} do
		att = att or string.find(anchored, "%s" .. m .. "q%f[^%w]")
	end
	-- rep/lock prefixes, line-anchored (see above) so a `rep:` label cannot spoof them.
	att = att
		or string.find(anchored, "\n%s*rep%s") or string.find(anchored, "\n%s*repe%s")
		or string.find(anchored, "\n%s*repz%s") or string.find(anchored, "\n%s*repne%s")
		or string.find(anchored, "\n%s*repnz%s") or string.find(anchored, "\n%s*lock%s")
	if att then return "x86_64", "att" end

	-- Intel-syntax files whose only register markers are bare (unpercented) vector
	-- names: xmm/ymm/zmm/k0..k7. arm64 never uses these register names, so a match
	-- proves x86_64. The syntax is a best guess: an AT&T file would have carried a %
	-- register marker (caught above), so bare names imply Intel. The [^%w_] trailing
	-- guards keep the matches out of identifiers (`save_xmm0_state`).
	if string.find(text, "%f[%w]xmm%d%f[^%w_]") or string.find(text, "%f[%w]ymm%d%f[^%w_]")
		or string.find(text, "%f[%w]zmm%d%f[^%w_]") or string.find(text, "%f[%w]k[0-7]%f[^%w_]") then
		return "x86_64", "intel"
	end

	-- Intel without a .intel_syntax directive: bare 64-bit x86 registers or PTR/[] memory.
	if string.find(text, " PTR ") or string.find(text, "%[") then
		-- brackets alone aren't proof (ARM uses [x0]); require an x86 register token too.
		if string.find(text, "[ \t,%[]r[abcds][xip][ \t,%]%+%-*]")
			or string.find(text, "[ \t,%[]r%d%d?[ \t,%]%+%-*]")
			or string.find(text, " PTR ") then
			return "x86_64", "intel"
		end
	end
	if string.find(text, "[ \t,]r[abcds][xip][ \t,\n]") or string.find(text, "[ \t,]e[abcds][xip][ \t,\n]") then
		return "x86_64", "intel"
	end

	-- Default: ARM64 (x0..x30 / w0.. / sp / xzr).
	return "arm64", nil
end

return detect
