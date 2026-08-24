--!nonstrict
-- Fil-C signature encoding and parsing of ;! function-signature annotations.
--
-- Annotation grammar (as seen in the *-sarcasm.s inputs):
--   RET(ARG0, ARG1, ...)        e.g. "unsigned(ptr)", "int(ptr, size_t)", "void(ptr,ptr)"
-- Types are C-ish tokens; we only need to know each type's Fil-C type class.

local sig = {}

-- Fil-C type-class indices (see ABI-NOTES.md).
local TYPE_INT = 0
local TYPE_FLOAT = 1
local TYPE_DOUBLE = 2
local TYPE_LONGDOUBLE = 3
-- 4..6 vectors, 7 pointer
local TYPE_PTR = 7

-- Map a C type token (already trimmed, may contain spaces) to a type class.
local function classifyType(tok: string): number?
	tok = (string.gsub(tok, "%s+", " "))
	tok = (string.gsub(tok, "^%s*(.-)%s*$", "%1"))
	local low = string.lower(tok)
	if low == "void" or low == "" then
		return nil
	end
	if low == "ptr" or string.find(low, "%*") then
		return TYPE_PTR
	end
	if low == "float" then
		return TYPE_FLOAT
	end
	if low == "double" then
		return TYPE_DOUBLE
	end
	if low == "long double" then
		return TYPE_LONGDOUBLE
	end
	-- everything else integer-class: int, unsigned, long, size_t, char, bool, enums, etc.
	return TYPE_INT
end
sig.classifyType = classifyType

-- enc(t1..tn) = sum_{i} 11^(i-1) * (1 + t_i); 0 if empty.
local function encodeList(types: { number }): number
	local acc = 0
	local mult = 1
	for _, t in types do
		acc += mult * (1 + t)
		mult *= 11
	end
	return acc
end

-- Split "a, b, c" respecting nested parens.
local function splitArgs(s: string): { string }
	local out = {}
	local depth = 0
	local cur = {}
	for i = 1, #s do
		local c = string.sub(s, i, i)
		if c == "(" then depth += 1; table.insert(cur, c)
		elseif c == ")" then depth -= 1; table.insert(cur, c)
		elseif c == "," and depth == 0 then
			table.insert(out, table.concat(cur)); cur = {}
		else table.insert(cur, c) end
	end
	local last = table.concat(cur)
	if (string.gsub(last, "%s", "")) ~= "" then
		table.insert(out, last)
	end
	return out
end

-- Parse "RET(ARGS)" into a descriptor:
--   { retTypes = {..}, argTypes = {..}, signature = <number>, argWords = <number>,
--     retWords = <number>, isVoid = <bool> }
function sig.parseSignature(ann: string)
	local retStr, argStr = string.match(ann, "^%s*(.-)%s*%((.*)%)%s*$")
	if not retStr then
		error("sarcasm: cannot parse function signature annotation: " .. ann)
	end
	local retTypes = {}
	local rc = classifyType(retStr)
	if rc ~= nil then
		table.insert(retTypes, rc)
	end
	local argTypes = {}
	for _, a in splitArgs(argStr) do
		local c = classifyType(a)
		-- void as a lone arg means no args
		if c ~= nil then
			table.insert(argTypes, c)
		end
	end
	local Ret = encodeList(retTypes)
	local Arg = encodeList(argTypes)
	local signature = 1 + Ret + 133 * Arg
	return {
		retTypes = retTypes,
		argTypes = argTypes,
		signature = signature,
		argWords = #argTypes,      -- each scalar/pointer arg occupies one 8-byte word
		retWords = #retTypes,
		isVoid = #retTypes == 0,
		retIsPtr = retTypes[1] == TYPE_PTR,
	}
end

-- Canonical names for the classes classifyType can produce (for diagnostics).
local CLASS_NAME = {
	[TYPE_INT] = "integer", [TYPE_FLOAT] = "float", [TYPE_DOUBLE] = "double",
	[TYPE_LONGDOUBLE] = "long double", [TYPE_PTR] = "ptr",
}

-- Floating-point/vector type classes cannot be marshalled: sarcasm packs and unpacks
-- dense GPRs only, while the Fil-C ABI passes and returns FP/vector values in vector
-- registers (which sarcasm rejects wholesale). An FP-typed signature would therefore
-- silently miscompile the ABI at BOTH ends (entry unpacking and callsite packing), so
-- reject it wherever a signature is consumed. `where` optionally prefixes a context
-- (e.g. "call to 'foo'"). Raises a clean sarcasm: error naming the offending type.
function sig.checkSupportedClasses(sd, where)
	local function check(t)
		if t ~= TYPE_INT and t ~= TYPE_PTR then
			error("sarcasm: " .. (where and (where .. ": ") or "")
				.. "floating-point types are not supported in signatures: "
				.. (CLASS_NAME[t] or ("type class " .. tostring(t))))
		end
	end
	for _, t in (sd.retTypes or {}) do check(t) end
	for _, t in (sd.argTypes or {}) do check(t) end
end

sig.TYPE_INT = TYPE_INT
sig.TYPE_PTR = TYPE_PTR

return sig
