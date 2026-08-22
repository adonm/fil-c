-- Unit test for the spill reload-elimination cleanup in emit.emitFip.
-- Builds a controlled node stream with two reloads of the same spill slot and a fixed
-- coloring, and checks that a reload whose destination register still holds the slot's
-- value is dropped, while a reload into a different register is kept.

local build = require("../sarcasm/build")
local emit = require("../sarcasm/emit")
local arm64_render = require("../sarcasm/arm64_render")

-- temp ids
local vMyth, acc, f1, f2 = 1, 2, 3, 4
local SPILLOFF = 16  -- spillBase (numRoots=0) + slot 0

local function reload(f)
	local n = build.insn("ldr", { build.rt(f), build.mem(build.sp(), SPILLOFF) }, { defs = { f } })
	n.spillReload = true; n.spillOff = SPILLOFF; n.spillTemp = f
	return n
end
local function useOf(f)  -- add acc, acc, f  (uses f + acc, defs acc; does not clobber f's reg)
	return build.insn("add", { build.rt(acc), build.rt(acc), build.rt(f) }, { defs = { acc }, uses = { acc, f } })
end

local function run(f2color)
	local tr = {
		name = "t",
		sigDesc = { signature = 1 },
		numRoots = 0,
		numSpillSlots = 1,
		vMyth = vMyth,
		originSym = ".Lfilc_origin_t",
		fipNodes = {
			{ kind = "prologue", name = "t" },
			reload(f1), useOf(f1),
			reload(f2), useOf(f2),
			{ kind = "epilogue", name = "t", useTemps = { vMyth } },
			build.insn("ret", {}, { control = "return", fallsThrough = false }),
		},
	}
	local colorResult = {
		color = { [vMyth] = "x19", [acc] = "x1", [f1] = "x5", [f2] = f2color },
		spilled = {},
	}
	local out = {}
	emit.emitFip(out, tr, colorResult, arm64_render, nil)
	local reloads = 0
	for _, line in out do
		if string.find(line, "ldr\tx" , 1, true) and string.find(line, "[sp, #16]", 1, true) then
			reloads += 1
		end
	end
	return reloads
end

local ok = true
-- f2 colored x5 (same as f1, still holds slot 16, not clobbered) -> second reload dropped
local same = run("x5")
if same == 1 then print("  ok: redundant same-register reload eliminated (1 reload)")
else print("  FAIL: expected 1 reload after cleanup, got " .. same); ok = false end
-- f2 colored x6 (different register) -> both reloads kept
local diff = run("x6")
if diff == 2 then print("  ok: reload into a different register is preserved (2 reloads)")
else print("  FAIL: expected 2 reloads, got " .. diff); ok = false end

if not ok then error("cleanup-test failed") end
print("cleanup-test: PASS")
