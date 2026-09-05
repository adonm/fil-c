--!nonstrict

-- Optional pass-level profiling for sarcasm, enabled by SARCASM_PROFILE=1 in the
-- environment. Each mark() records wall time (os.clock) and current RSS
-- (/proc/self/status VmRSS — minilute's Luau has no collectgarbage); report()
-- prints the per-pass deltas at exit. Inert (single boolean check per call site)
-- when disabled.

local process = require("@lute/process")
local fs = require("@lute/fs")

local prof = {}

local pe = process.env
prof.enabled = pe and pe.SARCASM_PROFILE ~= nil and pe.SARCASM_PROFILE ~= "" and pe.SARCASM_PROFILE ~= "0"

local t0 = os.clock()

local function rssKb()
	local ok, f = pcall(fs.open, "/proc/self/status", "r")
	if not ok or not f then return 0 end
	local ok2, s = pcall(fs.read, f)
	if not ok2 or type(s) ~= "string" then return 0 end
	return tonumber(string.match(s, "VmRSS:%s*(%d+)")) or 0
end

local lastT, lastR = 0, 0

-- Marks go to stdout AND (unbuffered, so an OOM-killed run leaves its full
-- trail) to $SARCASM_PROFILE_LOG when that names a writable path.
local logFile = nil
if prof.enabled and pe.SARCASM_PROFILE_LOG then
	local ok, f = pcall(fs.open, pe.SARCASM_PROFILE_LOG, "w+")
	if ok and f then logFile = f end
end

function prof.mark(label)
	if not prof.enabled then return end
	local t, r = os.clock() - t0, rssKb()
	local line = string.format("[prof] %10.2fs rss=%10.1fMB (dt=%+8.2fs drss=%+10.1fMB) %s",
		t, r / 1024, t - lastT, (r - lastR) / 1024, label)
	print(line)
	if logFile then pcall(fs.write, logFile, line .. "\n") end
	lastT, lastR = t, r
end

function prof.report()
	-- marks are printed eagerly (a killed run still shows its trail)
end

return prof
