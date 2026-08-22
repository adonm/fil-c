-- Sibling module for minilute's smoke test: exercises relative require of a
-- sibling module (and a nested relative require of its own).
local M = {}

M.answer = 42

function M.greet(name: string): string
	return "hello, " .. name
end

return M
