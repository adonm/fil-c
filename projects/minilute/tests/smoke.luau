-- minilute smoke test. Exercises the whole supported API surface:
--   - relative require of a sibling module
--   - @lute/fs: open/write/read-back/exists/type/stat/remove
--   - @lute/process: run (capture, exit codes, stderr), cwd, env get/set/unset,
--     args
-- Run from the repo root: pizfix/bin/minilute projects/minilute/tests/smoke.luau

local fs = require("@lute/fs")
local process = require("@lute/process")

-- relative require of a sibling module (resolved relative to THIS file's
-- directory, not the cwd)
local smokelib = require("./smokelib")
assert(smokelib.answer == 42, "relative require: bad answer")
assert(smokelib.greet("minilute") == "hello, minilute", "relative require: bad greet")

-- fs: write + read-back + exists + type + stat + remove
local tmp = "minilute-smoke-test.tmp"
local payload = "minilute smoke payload"
fs.write(fs.open(tmp, "w+"), payload) -- deliberately no fs.close: writes are unbuffered
assert(fs.exists(tmp), "fs.exists: file should exist after write")
assert(fs.type(tmp) == "file", "fs.type: expected 'file'")
assert(fs.read(fs.open(tmp, "r")) == payload, "fs read-back mismatch")
local st = fs.stat(tmp)
assert(st.size == #payload, "fs.stat: wrong size")
assert(st.type == "file", "fs.stat: wrong type")
assert(st.permissions.readonly == false, "fs.stat: expected writable")
fs.remove(tmp)
assert(not fs.exists(tmp), "fs.exists: file should be gone after remove")

-- fs: directories
local tmpdir = "minilute-smoke-test.dir"
fs.mkdir(tmpdir)
assert(fs.exists(tmpdir), "fs.mkdir: dir should exist")
assert(fs.type(tmpdir) == "dir", "fs.type: expected 'dir'")
local sawSelf = false
for _, entry in fs.listdir(".") do
	assert(type(entry.name) == "string" and type(entry.type) == "string", "fs.listdir: bad entry")
	if entry.name == tmpdir and entry.type == "dir" then
		sawSelf = true
	end
end
assert(sawSelf, "fs.listdir: did not see created dir")
fs.rmdir(tmpdir)
assert(not fs.exists(tmpdir), "fs.rmdir: dir should be gone")

-- process.run: capture stdout, ok/exitcode
local res = process.run({ "sh", "-c", "printf hello" })
assert(res.ok == true, "process.run: ok should be true")
assert(res.exitcode == 0, "process.run: exitcode should be 0")
assert(res.stdout == "hello", "process.run: stdout mismatch: " .. string.format("%q", res.stdout))
assert(res.stderr == "", "process.run: stderr should be empty")
assert(res.signal == nil, "process.run: signal should be nil")

-- process.run: failing command with stderr
local res2 = process.run({ "sh", "-c", "echo oops >&2; exit 7" })
assert(res2.ok == false, "process.run: ok should be false")
assert(res2.exitcode == 7, "process.run: exitcode should be 7")
assert(res2.stderr == "oops\n", "process.run: stderr mismatch: " .. string.format("%q", res2.stderr))

-- process.run: spawn failure raises a Lua error
local spawnOk, spawnErr = pcall(process.run, { "minilute-definitely-not-a-command-xyz" })
assert(not spawnOk, "process.run: spawn failure should raise")
assert(string.find(tostring(spawnErr), "Failed to spawn process", 1, true), "process.run: bad spawn error: " .. tostring(spawnErr))

-- process.system
local res3 = process.system("printf sys")
assert(res3.ok and res3.stdout == "sys", "process.system mismatch")

-- process.cwd / homedir / execPath return strings
assert(type(process.cwd()) == "string" and #process.cwd() > 0, "process.cwd: bad result")
assert(type(process.homedir()) == "string" and #process.homedir() > 0, "process.homedir: bad result")
assert(type(process.execPath()) == "string" and #process.execPath() > 0, "process.execPath: bad result")

-- process.env: get/set/unset roundtrip + iteration
process.env.MINILUTE_SMOKE = "xyzzy"
assert(process.env.MINILUTE_SMOKE == "xyzzy", "process.env: set/get mismatch")
process.env.MINILUTE_SMOKE = nil
assert(process.env.MINILUTE_SMOKE == nil, "process.env: unset failed")
local sawPath = false
for k, v in process.env do
	if k == "PATH" then
		sawPath = true
	end
end
assert(sawPath, "process.env: iteration did not see PATH")

-- process.args: 1-based, args[1] is the script path as typed on the command line
assert(type(process.args) == "table" and #process.args >= 1, "process.args: bad shape")
assert(string.sub(process.args[1], -10) == "smoke.luau", "process.args[1] should be the script path, got: " .. tostring(process.args[1]))

print("minilute smoke test: PASS")
