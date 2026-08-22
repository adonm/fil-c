-- Unit test for architecture + syntax auto-detection and the dual-syntax x86 parser.
-- Verifies detect() picks the right (arch, syntax) and that AT&T and Intel inputs parse
-- to the same operand model.

local detect = require("../sarcasm/detect")
local x86parse = require("../sarcasm/x86_64_parse")

local pass, fail = 0, 0
local function ck(name, got, want)
	if got == want then print("  ok: " .. name); pass += 1
	else print("  FAIL: " .. name .. " (got '" .. tostring(got) .. "' want '" .. tostring(want) .. "')"); fail += 1 end
end

-- detection
local a1, s1 = detect.detect("\tmovzbl\t(%rdi), %eax\n\tret\n")
ck("detect AT&T arch", a1, "x86_64"); ck("detect AT&T syntax", s1, "att")

local a2, s2 = detect.detect("\t.intel_syntax noprefix\n\tmovzx eax, BYTE PTR [rdi]\n")
ck("detect Intel arch", a2, "x86_64"); ck("detect Intel syntax", s2, "intel")

local a3 = detect.detect("\t.arch armv8-a\n\tldrb w0, [x0]\n\tret\n")
ck("detect ARM64 arch", a3, "arm64")

local a4, s4 = detect.detect("\tmov eax, DWORD PTR [rdi+rsi*4]\n\tret\n")
ck("detect Intel (no directive) arch", a4, "x86_64"); ck("detect Intel (no directive) syntax", s4, "intel")

-- dual-syntax parser equivalence: AT&T and Intel produce the same normalized model
local att = x86parse.parseString("\tmovzbl\t(%rdi,%rsi,1), %eax\n", "att")
local intel = x86parse.parseString("\tmovzx\teax, BYTE PTR [rdi+rsi*1]\n", "intel")
local function firstInsn(stmts) for _, s in stmts do if s.kind == "insn" then return s end end end
local ia, ii = firstInsn(att), firstInsn(intel)
ck("att/intel same dest reg", ia.operands[1].name, ii.operands[1].name)
ck("att/intel same mem base", ia.operands[2].base.name, ii.operands[2].base.name)
ck("att/intel same mem index", ia.operands[2].index.name, ii.operands[2].index.name)
ck("att/intel same mem scale", ia.operands[2].scale, ii.operands[2].scale)

print("detect-test: " .. pass .. " passed, " .. fail .. " failed")
