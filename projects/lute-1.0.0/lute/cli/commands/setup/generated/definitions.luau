return {["lute/process.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
--- How a child process's standard streams should be handled:
--- - `"default"`: Capture stdout and stderr to pipes, accessible via `ProcessResult`.
--- - `"inherit"`: Pass the parent process's stdio streams through to the child.
--- - `"none"`: Discard the child's stdio streams.
export type StdioKind = "default" | "inherit" | "none"

--- Options for `process.run`:
--- - `cwd`: The working directory for the child process. Defaults to the current working directory.
--- - `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.
--- - `env`: Environment variables for the child process. If omitted, inherits the parent's environment.
export type ProcessRunOptions = {
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}

--- Options for `process.system`:
--- - `system`: The shell executable to use. If omitted, uses the platform default (`$SHELL` on Unix, `%COMSPEC%` on Windows).
--- - `cwd`: The working directory for the child process. Defaults to the current working directory.
--- - `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.
--- - `env`: Environment variables for the child process. If omitted, inherits the parent's environment.
export type ProcessSystemOptions = {
	system: string?,
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}

--- The result of a completed process, including exit code and captured stdout/stderr.
export type ProcessResult = {
	stdout: string,
	stderr: string,

	ok: boolean,
	exitcode: number,
	signal: string?,
}

local process = {}

--- Command-line arguments passed to the current script, as an array of strings.
process.args = {} :: { string }
--- A table of environment variables for the current process.
process.env = {} :: { [string]: string }

--- Returns the current user's home directory as a string.
function process.homedir(): string
	error("not implemented")
end

--- Returns the current working directory as a string.
function process.cwd(): string
	error("not implemented")
end

--- Runs the program given by `args[1]` with the remaining entries as arguments. Returns the process result including exit code and any captured output.
function process.run(args: { string }, options: ProcessRunOptions?): ProcessResult
	error("not implemented")
end

--- Runs `command` through the system shell. Returns the process result.
function process.system(command: string, options: ProcessSystemOptions?): ProcessResult
	error("not implemented")
end

--- Exits the current process with the given `exitcode`.
function process.exit(exitcode: number): never
	error("not implemented")
end

--- Returns the path of the currently running lute executable as a string.
function process.execPath(): string
	error("not implemented")
end

return process
]==],["lute/net/client.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local client = {}

--- HTTP request metadata, including optional method, body, and headers.
export type Metadata = {
	method: string?,
	body: string?,
	headers: { [string]: string }?,
}

--- An HTTP response, containing status code, headers, body, and a success flag.
export type Response = {
	body: string,
	headers: { [string]: string },
	status: number,
	ok: boolean,
}

--- Makes an HTTP request to `url` with optional request metadata. Returns the response.
function client.request(url: string, metadata: Metadata?): Response
	error("not implemented")
end

--- Options for establishing a WebSocket connection, including optional event handlers.
export type WebSocketOptions = {
	headers: { [string]: string }?,
	onopen: (() -> ())?,
	onmessage: ((message: string | buffer) -> ())?,
	onclose: ((code: number, reason: string) -> ())?,
	onerror: ((error: string) -> ())?,
}

--- A client-side WebSocket connection handle.
export type WebSocket = {
	send: (self: WebSocket, data: string | buffer) -> (),
	close: (self: WebSocket) -> (),
}

--- Opens a WebSocket connection to `url`. Returns a `WebSocket` handle.
function client.websocket(url: string, options: WebSocketOptions?): WebSocket
	error("not implemented")
end

return client
]==],["std/path/win32/init.luau"] = [==[local process = require("@lute/process")
local win32types = require("@self/types")
local pathinterface = require("./pathinterface")

export type PathKind = win32types.PathKind
export type Path = win32types.Path
export type Pathlike = win32types.Pathlike

local win32 = {}
win32.pathmt = {} :: pathinterface.PathInterface

--- Returns the last component of `path`, or `nil` if the path has no components.
function win32.basename(path: Pathlike): string?
	path = if typeof(path) == "string" then win32.parse(path) else path
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

--- Returns the directory portion of `path` as a string (everything except the last component).
function win32.dirname(path: Pathlike): string
	path = if typeof(path) == "string" then win32.parse(path) else path

	if #path.parts == 0 then
		return win32.format(path)
	else
		return win32.format({
			parts = { table.unpack(path.parts, 1, #path.parts - 1) },
			kind = path.kind,
			drive = path.drive,
		})
	end
end

--- Returns the file extension of `path` (including the leading dot), or `""` if there is none.
function win32.extname(path: Pathlike): string
	path = if typeof(path) == "string" then win32.parse(path) else path

	if #path.parts == 0 then
		return ""
	end

	local filename = path.parts[#path.parts]

	if filename == "." or filename == ".." then
		return ""
	end

	local dotIndex, _ = filename:find("%.[^%.]*$")
	if dotIndex == nil or dotIndex == 1 then
		return ""
	end

	return filename:sub(dotIndex)
end

--- Returns a `Path` representing just the drive root of `path` (e.g. `C:\`). Errors if `path` has no drive letter.
function win32.drive(path: Pathlike): Path
	path = if typeof(path) == "string" then win32.parse(path) else path

	if path.drive == nil then
		error("Path does not have a drive letter: " .. win32.format(path))
	end

	return setmetatable(
		{
			parts = {},
			kind = "absolute",
			drive = path.drive,
		} :: win32types.PathData,
		win32.pathmt
	)
end

--- Converts `path` to its Windows string representation using backslash separators.
function win32.format(path: Pathlike): string
	if typeof(path) == "string" then
		return path
	end

	if #path.parts == 0 then
		if path.kind == "unc" then
			return "\\\\"
		elseif path.drive ~= nil then
			return table.concat({ path.drive, ":", (if path.kind == "absolute" then "\\" else "") })
		else
			return "."
		end
	else
		local parts = table.concat(path.parts, "\\")
		if path.kind == "unc" then
			return "\\\\" .. parts
		elseif path.drive ~= nil then
			return table.concat({ path.drive, ":", (if path.kind == "absolute" then "\\" else ""), parts })
		else
			return parts
		end
	end
end

--- Returns `true` if `path` is absolute (drive-rooted or UNC).
function win32.isAbsolute(path: Pathlike): boolean
	path = if typeof(path) == "string" then win32.parse(path) else path
	return path.kind ~= "relative"
end

-- In place extends path with addend
local function joinHelper(path: Path, addend: Pathlike): ()
	addend = if typeof(addend) == "string" then win32.parse(addend) else addend

	if addend.kind ~= "relative" then
		error(`Could not join {path.kind} path {win32.format(path)} and {addend.kind} path {win32.format(addend)}`)
	end

	local driveLettersIncompatible = path.drive ~= nil
		and addend.drive ~= nil
		and addend.drive:lower() ~= path.drive:lower()

	if driveLettersIncompatible then
		error(`Could not join paths with incompatible drive letters: {win32.format(path)} and {win32.format(addend)}`)
	end

	table.move(addend.parts, 1, #addend.parts, #path.parts + 1, path.parts)

	if path.drive == nil and addend.drive ~= nil then
		path.drive = addend.drive
	end
end

--- Joins one or more path segments into a single `Path`. Each segment after the first must be relative.
function win32.join(...: Pathlike): Path
	local parts = { ... }
	if #parts == 0 then
		return setmetatable(
			{
				parts = {},
				kind = "relative",
				drive = nil,
			} :: win32types.PathData, -- Cast needed because of table invariance
			win32.pathmt
		)
	end

	local path: Path = if typeof(parts[1]) == "string"
		then win32.parse(parts[1])
		else setmetatable({
			parts = table.clone((parts[1] :: Path).parts), -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
			kind = (parts[1] :: Path).kind, -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
			drive = (parts[1] :: Path).drive, -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
		}, win32.pathmt)

	for i = 2, #parts do
		joinHelper(path, parts[i])
	end

	return path
end

--- Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.
function win32.normalize(path: Pathlike): Path
	path = if typeof(path) == "string" then win32.parse(path) else path

	local newParts = {}
	for _, part in path.parts do
		if part == "" or part == "." then
			continue
		elseif part == ".." then
			if path.kind == "unc" or path.kind == "absolute" then
				if #newParts > 0 then -- if absolute, only pop if we're not at the root
					table.remove(newParts, #newParts)
				end
			else -- if a relative path, we keep .. prefixes
				if #newParts > 0 and newParts[#newParts] ~= ".." then
					table.remove(newParts, #newParts)
				else
					table.insert(newParts, "..")
				end
			end
		else
			table.insert(newParts, part)
		end
	end

	return setmetatable({
		parts = newParts,
		kind = path.kind,
		drive = path.drive,
	}, win32.pathmt)
end

--- Parses `path` into a structured `Path` value.
function win32.parse(path: Pathlike): Path
	if typeof(path) == "table" then
		return setmetatable(path, win32.pathmt)
	end
	if typeof(path) ~= "string" then
		error("Expected string or path")
	end

	local kind: PathKind = "relative"
	local driveLetter = nil

	-- Check if path is absolute and if it's a unc path on Windows
	if string.sub(path, 1, 2) == "\\\\" then
		-- unc path
		kind = "unc"
	elseif string.match(path, "^%a:") ~= nil then
		driveLetter = string.sub(path, 1, 1)
		-- Windows: starts with drive letter + separator (C:\ or C:/)
		local sep = path:sub(3, 3)
		kind = if sep == "\\" or sep == "/" then "absolute" else "relative"
	end

	local parts = {}
	-- Windows supports mixed separators, so sub forward slashes for backslashes first
	path = path:gsub("/", "\\")

	if kind == "unc" then
		-- Strip out the leading \\ for unc paths
		parts = path:sub(3):split("\\")
	elseif kind == "absolute" then
		-- Strip out the drive letter, colon, and backslash (C:\)
		parts = path:sub(4):split("\\")
	elseif driveLetter ~= nil then
		-- Strip out the drive letter and colon (C:)
		parts = path:sub(3):split("\\")
	else
		parts = path:split("\\")
	end

	-- Filter out empty parts (can happen with leading/trailing separators)
	if #parts > 0 then
		if parts[#parts] == "" then
			table.remove(parts, #parts)
		end
		if #parts > 0 and parts[1] == "" then
			table.remove(parts, 1)
		end
	end

	return setmetatable({
		parts = parts,
		kind = kind,
		drive = driveLetter,
	}, win32.pathmt)
end

--- Returns the relative path from `from` to `to`. Both paths must have the same kind and drive.
function win32.relative(from: Pathlike, to: Pathlike): Path
	from = if typeof(from) == "string" then win32.parse(from) else from
	to = if typeof(to) == "string" then win32.parse(to) else to

	if from.kind ~= to.kind then
		error("Cannot compute relative path between different kinds of paths")
	end

	if from.drive ~= to.drive then
		error("Cannot compute relative path between different drives")
	end

	local commonPrefixLength = 0

	for i = 1, math.min(#from.parts, #to.parts) do
		if from.parts[i] ~= to.parts[i] then
			break
		end
		commonPrefixLength += 1
	end

	local relativeParts = {}

	if #from.parts > commonPrefixLength then
		for _ = commonPrefixLength + 1, #from.parts do
			table.insert(relativeParts, "..")
		end
	end

	if #to.parts > commonPrefixLength then
		for i = commonPrefixLength + 1, #to.parts do
			table.insert(relativeParts, to.parts[i])
		end
	end

	return setmetatable({
		parts = relativeParts,
		kind = "relative",
		drive = nil :: string?,
	}, win32.pathmt)
end

--- Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.
function win32.resolve(...: Pathlike): Path
	local parts = { ... }
	if #parts == 0 then
		return win32.parse(process.cwd())
	end

	local path = win32.parse(parts[#parts])

	for i = #parts - 1, 1, -1 do
		if win32.isAbsolute(path) then
			break
		end

		local segment = win32.parse(parts[i])

		if #segment.parts == 0 then
			continue
		end

		joinHelper(segment, path)
		path = segment
	end

	if not win32.isAbsolute(path) then
		local cwd = win32.parse(process.cwd())
		joinHelper(cwd, path)
		path = cwd
	end

	return win32.normalize(path)
end

function win32.pathmt:__tostring(): string
	return win32.format(self :: Path)
end

return table.freeze(win32)
]==],["std/test/init.luau"] = [==[--!strict
-- @std/test
-- Standard test library for Luau

local types = require("@self/types")
local env = require("@self/env")

type Test = types.Test
type TestCase = types.TestCase
type TestSuite = types.TestSuite
type TestReporter = types.TestReporter

local TestSuite = {}
TestSuite.__index = TestSuite

--- Creates a new, empty `TestSuite` with the given `name`.
function TestSuite.new(name: string): TestSuite
	local self = setmetatable({
		name = name,
		cases = {},
		_beforeEach = nil,
		_beforeAll = nil,
		_afterEach = nil,
		_afterAll = nil,
	}, TestSuite)
	return self :: TestSuite
end

--- Registers a test case with `name` in this suite.
function TestSuite:case(name: string, testCase: Test)
	table.insert(self.cases, { name = name, case = testCase })
end

--- Registers a hook to run before each test case in this suite.
function TestSuite:beforeEach(hook: () -> ())
	self._beforeEach = hook
end

--- Registers a hook to run once before all test cases in this suite.
function TestSuite:beforeAll(hook: () -> ())
	self._beforeAll = hook
end

--- Registers a hook to run after each test case in this suite.
function TestSuite:afterEach(hook: () -> ())
	self._afterEach = hook
end

--- Registers a hook to run once after all test cases in this suite.
function TestSuite:afterAll(hook: () -> ())
	self._afterAll = hook
end

-- Test library export surface
local test = {}

--- Registers an anonymous (top-level) test case with the given `name`.
function test.case(name: string, case: Test)
	local testcase = { name = name, case = case }
	table.insert(env.anonymous, testcase)

	-- Update caseindex
	if not env.caseindex[name] then
		env.caseindex[name] = { anonymous = { testcase }, suites = {} }
	else
		table.insert(env.caseindex[name].anonymous, testcase)
	end
end

--- Registers a test suite with `name`, using `registerFn` to define its test cases.
function test.suite(name: string, registerFn: (TestSuite) -> ())
	local suite = TestSuite.new(name)
	registerFn(suite)
	table.insert(env.suites, suite)

	-- Update suiteindex
	env.suiteindex[name] = suite

	-- Update caseindex for all cases in this suite
	for _, testcase in suite.cases do
		if not env.caseindex[testcase.name] then
			env.caseindex[testcase.name] = { anonymous = {}, suites = {} }
		end
		if not env.caseindex[testcase.name].suites[name] then
			env.caseindex[testcase.name].suites[name] = {}
		end
		table.insert(env.caseindex[testcase.name].suites[name], testcase)
	end
end

-- get all registered tests without running them (internal)
function test._registered()
	return table.freeze({
		anonymous = env.anonymous,
		suites = env.suites,
		suiteindex = env.suiteindex,
		caseindex = env.caseindex,
	})
end

return table.freeze(test)
]==],["lute/fs.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local time = require("./time")

local fs = {}

--- An open file handle returned by `fs.open`.
export type FileHandle = {
	fd: number,
	err: number,
}

--- The type of a filesystem entry:
--- - `"file"`: A regular file.
--- - `"dir"`: A directory.
--- - `"link"`: A symbolic link.
--- - `"fifo"`: A named pipe (FIFO).
--- - `"socket"`: A Unix domain socket.
--- - `"char"`: A character device.
--- - `"block"`: A block device.
--- - `"unknown"`: An entry whose type could not be determined.
export type FileType = "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown"
--- How a file should be opened:
--- - `"r"`: Open for reading. Fails if the file does not exist.
--- - `"w"`: Open for writing; creates the file if absent, truncates it if present.
--- - `"x"`: Open for exclusive creation. Fails if the file already exists.
--- - `"a"`: Open for appending; creates the file if absent, writes go to the end.
--- - `"r+"`: Open for reading and writing. Fails if the file does not exist.
--- - `"w+"`: Open for reading and writing; creates the file if absent, truncates it if present.
--- - `"x+"`: Open for reading and exclusive creation. Fails if the file already exists.
--- - `"a+"`: Open for reading and appending; creates the file if absent, writes go to the end.
export type HandleMode = "r" | "w" | "x" | "a" | "r+" | "w+" | "x+" | "a+"

--- Metadata about a filesystem entry, such as size, type, and timestamps.
export type FileMetadata = {
	type: FileType,
	permissions: { readonly: boolean },
	size: number,
	created: time.Duration,
	accessed: time.Duration,
	modified: time.Duration,
}

--- A single entry returned by `fs.listdir`, containing the entry's name and type.
export type DirectoryEntry = {
	name: string,
	type: FileType,
}

--- A handle to an active filesystem watcher, returned by `fs.watch`.
export type WatchHandle = {
	close: (self: WatchHandle) -> (),
}

--- A filesystem change event passed to the `fs.watch` callback.
export type WatchEvent = {
	change: boolean,
	rename: boolean,
}

--- Opens the file at `path` in the given `mode` (defaults to `"r"`). Returns a file handle.
function fs.open(path: string, mode: HandleMode?): FileHandle
	error("not implemented")
end

--- Reads the full contents of `handle` and returns them as a string.
function fs.read(handle: FileHandle): string
	error("not implemented")
end

--- Writes `contents` to `handle`.
function fs.write(handle: FileHandle, contents: string): ()
	error("not implemented")
end

--- Closes `handle`, flushing any pending writes.
function fs.close(handle: FileHandle): ()
	error("not implemented")
end

--- Removes the file at `path`.
function fs.remove(path: string): ()
	error("not implemented")
end

--- Returns metadata for the file or directory at `path`.
function fs.stat(path: string): FileMetadata
	error("not implemented")
end

--- Returns the `FileType` of the entry at `path`.
function fs.type(path: string): FileType
	error("not implemented")
end

--- Creates a directory at the specified path.
--- To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.
function fs.mkdir(path: string): ()
	error("not implemented")
end

--- Creates a hard link at `dest` pointing to `src`.
function fs.link(src: string, dest: string): ()
	error("not implemented")
end

--- Creates a symbolic link at `dest` pointing to `src`.
function fs.symlink(src: string, dest: string): ()
	error("not implemented")
end

--- Watches `path` for filesystem changes, calling `callback` with the filename and event on each change.
function fs.watch(path: string, callback: (filename: string, event: WatchEvent) -> ()): WatchHandle
	error("not implemented")
end

--- Returns `true` if a file or directory exists at `path`.
function fs.exists(path: string): boolean
	error("not implemented")
end

--- Copies the file at `src` to `dest`.
function fs.copy(src: string, dest: string): ()
	error("not implemented")
end

--- Returns an array of `DirectoryEntry` values for the immediate children of the directory at `path`.
function fs.listdir(path: string): { DirectoryEntry }
	error("not implemented")
end

--- Removes the directory at `path`.
function fs.rmdir(path: string): ()
	error("not implemented")
end

return fs
]==],["std/syntax/query.luau"] = [==[--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local tableext = require("@std/tableext")
local types = require("./types")
local visitor = require("./visitor")

type Node = types.AstNode

--- A collection of AST nodes that supports chained filtering, mapping, and replacement operations.
export type Query<T = Node> = {
	nodes: { T },
	filter: (self: Query<T>, pred: (T) -> boolean) -> Query<T>,
	replace: (self: Query<T>, repl: (T) -> string?) -> types.Replacements,
	map: <U>(self: Query<T>, fn: (T) -> U?) -> Query<U>, -- recursion violation reported
	forEach: (self: Query<T>, callback: (T) -> ()) -> Query<T>,
	findAll: <U>(self: Query<T>, fn: (Node) -> U?) -> Query<U>,
	flatMap: <U>(self: Query<T>, fn: (T) -> { U }) -> Query<U>,
	mapToArray: <U>(self: Query<T>, fn: (T) -> U?) -> { U },
}

local queryLib = {}

--- Retains only the nodes for which `pred` returns `true`. Mutates and returns the query.
function queryLib.filter<T>(self: Query<T>, pred: (T) -> boolean): Query<T>
	local newNodes = {}
	for _, node in self.nodes do
		if pred(node) then
			table.insert(newNodes, node)
		end
	end
	self.nodes = newNodes
	return self
end

--- Calls `repl` on each node and collects the non-nil results into a `Replacements` table for use with the printer.
function queryLib.replace<T>(self: Query<T>, repl: (T) -> string?): types.Replacements
	local replacements = {}
	for _, node in self.nodes do
		local r = repl(node)
		if r ~= nil then
			replacements[node] = r
		end
	end
	return replacements
end

--- Replaces the query's nodes with the non-nil values returned by `fn` for each node. Mutates and returns the query.
function queryLib.map<T, U>(self: Query<T>, fn: (T) -> U?): Query<U>
	local newNodes = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if mapped ~= nil then
			table.insert(newNodes, mapped)
		end
	end
	self.nodes = newNodes
	return self
end

--- Calls `callback` on each node. Returns the query unchanged for chaining.
function queryLib.forEach<T>(self: Query<T>, callback: (T) -> ()): Query<T>
	for _, node in self.nodes do
		callback(node)
	end
	return self
end

local function newSelectVisitor<T>(nodes: { T }, fn: (Node) -> T?): visitor.Visitor
	local function visit(n: Node)
		local selected = fn(n)
		if selected ~= nil then
			table.insert(nodes, selected)
		end
		return true
	end

	local selectVisitor = visitor.create(visit)
	selectVisitor.visitStatBlockEnd = function(_) end
	selectVisitor.visitStatLocalDeclarationEnd = function(_) end
	selectVisitor.visitExpr = function(_)
		return true
	end
	selectVisitor.visitExprEnd = function(_) end

	return selectVisitor
end

--- Recursively visits every descendant of each node in the query and collects those for which `fn` returns a non-nil value. Mutates and returns the query.
function queryLib.findAll<T, U>(self: Query<T>, fn: (Node) -> U?): Query<U>
	local selectedNodes: { U } = {}

	local selectVisitor = newSelectVisitor(selectedNodes, fn)

	for _, node in self.nodes do
		visitor.visit(node, selectVisitor)
	end

	self.nodes = selectedNodes

	return self
end

--- Replaces each node with the array of values returned by `fn`, flattening one level. Mutates and returns the query.
function queryLib.flatMap<T, U>(self: Query<T>, fn: (T) -> { U }): Query<U>
	local newNodes: { U } = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if #mapped > 0 then
			tableext.extend(newNodes, mapped)
		end
	end
	self.nodes = newNodes
	return self
end

--- Returns a plain array of the non-nil values produced by calling `fn` on each node. Does not mutate the query.
function queryLib.mapToArray<T, U>(self: Query<T>, fn: (T) -> U?): { U }
	local result = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if mapped ~= nil then
			table.insert(result, mapped)
		end
	end
	return result
end

--- Creates a new `Query` by visiting every node in `ast` and collecting those for which `fn` returns a non-nil value.
function queryLib.findAllFromRoot<T>(ast: types.ParseResult | Node, fn: (Node) -> T?): Query<T>
	local nodes: { T } = {}

	local selectVisitor = newSelectVisitor(nodes, fn)

	local root: Node = if (ast :: any).root ~= nil then (ast :: any).root else ast :: any -- LUAUFIX: Replace any cast with cast to node once code too complex no longer emitted
	visitor.visit(root, selectVisitor)

	return {
		nodes = nodes,
		filter = queryLib.filter,
		replace = queryLib.replace,
		map = queryLib.map :: any, -- LUAUFIX: Remove any cast once recursion restriction is loosened
		forEach = queryLib.forEach,
		findAll = queryLib.findAll :: any, -- LUAUFIX: Remove any cast once recursion restriction is loosened
		flatMap = queryLib.flatMap,
		mapToArray = queryLib.mapToArray :: any, -- Any cast because mapToArray has generics quantified at a different level than the query type expects
	}
end

return table.freeze(queryLib)
]==],["std/test/runner.luau"] = [==[--!strict
-- @std/test/runner
-- Standard test runner library for Luau
local ps = require("@std/process")

local asserts = require("./assert")
local failure = require("./failure")
local reporter = require("./reporter")
local types = require("./types")
local env = require("./env")

type Test = types.Test
type TestCase = types.TestCase
type TestSuite = types.TestSuite
type TestEnvironment = types.TestEnvironment
type TestReporter = types.TestReporter
type FailedTest = types.FailedTest
type TestRunResult = types.TestRunResult

local runner = {}

--- Runs all test cases and suites in `env`, executing lifecycle hooks around each case. Returns the aggregate results.
function runner.run(env: TestEnvironment): TestRunResult
	local failures: { FailedTest } = {}
	local total = 0
	local failed = 0
	local passed = 0

	-- Error handler for beforeAll hook
	local function beforeAllErrorHandler(suite: TestSuite)
		return function(err)
			-- If beforeAll fails, skip all tests in the suite
			total += #suite.cases
			failed += #suite.cases
			for _, tc in suite.cases do
				local failedtest: FailedTest = {
					test = `{suite.name}.{tc.name}`,
					failure = failure.lifecycle("beforeAll", err),
				}
				table.insert(failures, failedtest)
			end
			return err
		end
	end

	-- Error handler for beforeEach hook
	local function beforeEachErrorHandler(testFullName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = testFullName,
				failure = failure.lifecycle("beforeEach", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Error handler for afterEach hook
	local function afterEachErrorHandler(testFullName: string)
		return function(err)
			local failedtest: FailedTest = {
				test = testFullName,
				failure = failure.lifecycle("afterEach", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Error handler for afterAll hook
	local function afterAllErrorHandler(suiteName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = suiteName,
				failure = failure.lifecycle("afterAll", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Run anonymous tests
	for _, tc in env.anonymous do
		total += 1
		local function handlefailure(err)
			local wasruntimefailure = not (typeof(err) == "table" and err.__tag and err.__tag == "assertion")
			local failedtest: FailedTest = {
				test = tc.name,
				failure = if wasruntimefailure then failure.runtimeerror(err) else err,
			}
			table.insert(failures, failedtest)
			failed += 1
		end

		local success = xpcall(tc.case, handlefailure, asserts)
		if success then
			passed += 1
		end
	end

	-- Run tests from suites
	for _, suite in env.suites do
		-- Run beforeAll hook once per suite
		if suite._beforeAll then
			local beforeAllSuccess = xpcall(suite._beforeAll, beforeAllErrorHandler(suite))
			if not beforeAllSuccess then
				-- If beforeAll fails, skip all tests in the suite
				continue
			end
		end

		for _, tc in suite.cases do
			total += 1
			local testFullName = `{suite.name}.{tc.name}`
			local function handlefailure(err)
				local wasruntimefailure = not (typeof(err) == "table" and err.__tag and err.__tag == "assertion")
				local failedtest: FailedTest = {
					test = testFullName,
					failure = if wasruntimefailure then failure.runtimeerror(err) else err,
				}
				table.insert(failures, failedtest)
			end

			-- Run beforeEach hook if it exists
			if suite._beforeEach then
				local beforeSuccess = xpcall(suite._beforeEach, beforeEachErrorHandler(testFullName))
				if not beforeSuccess then
					continue
				end
			end

			local success = xpcall(tc.case, handlefailure, asserts)
			-- Run afterEach hook if it exists (runs even if test failed)
			if suite._afterEach then
				local afterSuccess = xpcall(suite._afterEach, afterEachErrorHandler(testFullName))
				if not afterSuccess then
					-- If test passed but afterEach failed, mark as failed
					success = false
				end
			end
			-- if the test and the teardown method passed, the test passes
			if success then
				passed += 1
			else
				failed += 1
			end
		end

		-- Run afterAll hook once per suite (runs even if tests failed)
		if suite._afterAll then
			xpcall(suite._afterAll, afterAllErrorHandler(suite.name))
		end
	end

	return {
		failures = failures,
		total = total,
		failed = failed,
		passed = passed,
	}
end

--- Runs all globally registered tests, prints the results with the simple reporter, then exits the process with code 0 on success or 1 on failure.
function runner.runRegisteredTests()
	local result = runner.run(env)
	reporter.simple(result)
	if result.failed ~= 0 then
		ps.exit(1)
	end
	ps.exit(0)
end

return table.freeze(runner)
]==],["lute/task.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local time = require("./time")

local task = {}

--- Schedules `routine` to run immediately on the next resumption cycle, passing any additional arguments to it. Returns the thread.
function task.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	error("unimplemented")
end

--- Schedules `routine` to run after the current thread yields, passing any additional arguments to it. Returns the thread.
function task.defer<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	error("unimplemented")
end

--- Resumes `thread`, running it until it yields or completes. Returns the thread.
function task.resume(thread: thread): thread
	error("unimplemented")
end

--- Yields the current thread and re-schedules it for the next resumption cycle.
function task.deferSelf()
	error("unimplemented")
end

--- Yields the current thread for `dur` seconds (or until the next cycle if `dur` is omitted). Returns the actual time waited.
function task.wait(dur: (number | time.Duration)?): number
	error("unimplemented")
end

--- Schedules `routine` to run after `dur` seconds, passing any additional arguments to it. Returns the thread.
function task.delay<T..., U...>(dur: number | time.Duration, routine: thread | ((T...) -> U...), ...: T...): thread
	error("unimplemented")
end

return task
]==],["std/process.luau"] = [==[--!strict
-- @std/process
-- stdlib for `@lute/process`
-- Provides process-related utility functions that handles file paths as path types instead of strings

local process = require("@lute/process")
local pathlib = require("@std/path")

local processlib = {}

--- How a child process's standard streams should be handled:
--- - `"default"`: Capture stdout and stderr to pipes, accessible via `ProcessResult`.
--- - `"inherit"`: Pass the parent process's stdio streams through to the child.
--- - `"none"`: Discard the child's stdio streams.
export type StdioKind = process.StdioKind
--- Options for `process.run`:
--- - `cwd`: The working directory for the child process. Defaults to the current working directory.
--- - `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.
--- - `env`: Environment variables for the child process. If omitted, inherits the parent's environment.
export type ProcessRunOptions = process.ProcessRunOptions
--- Options for `process.system`:
--- - `system`: The shell executable to use. If omitted, uses the platform default (`$SHELL` on Unix, `%COMSPEC%` on Windows).
--- - `cwd`: The working directory for the child process. Defaults to the current working directory.
--- - `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.
--- - `env`: Environment variables for the child process. If omitted, inherits the parent's environment.
export type ProcessSystemOptions = process.ProcessSystemOptions
--- The result of a completed process, including exit code and captured stdout/stderr.
export type ProcessResult = process.ProcessResult
--- A structured, platform-aware file system path.
export type Path = pathlib.Path
--- Anything that can be used as a path: a string, a `Path`, or raw path data.
export type Pathlike = pathlib.Pathlike

--- Returns the current user's home directory as a `Path`.
function processlib.homedir(): Path
	return pathlib.parse(process.homedir())
end

--- Returns the current working directory as a `Path`.
function processlib.cwd(): Path
	return pathlib.parse(process.cwd())
end

--- Runs the program given by `args[1]` with the remaining entries as arguments.
--- Returns the process result including exit code and any captured output.
function processlib.run(args: { string }, options: ProcessRunOptions?): ProcessResult
	return process.run(args, options)
end

--- Runs `command` through the system shell. Returns the process result.
function processlib.system(command: string, options: ProcessSystemOptions?): ProcessResult
	return process.system(command, options)
end

--- Exits the current process with the given `exitcode`.
function processlib.exit(exitcode: number): never
	return process.exit(exitcode)
end

--- Returns the path of the currently running lute executable as a `Path`.
function processlib.execPath(): Path
	return pathlib.parse(process.execPath())
end

-- re-exports
processlib.args = process.args
processlib.env = process.env

return table.freeze(processlib)
]==],["std/io.luau"] = [==[--!strict
-- @std/io
-- stdlib for `@lute/io`
-- Provides standard input, output, and other I/O utility functions

local io = require("@lute/io")

local iolib = {}

--- Writes one or more strings to standard output without a trailing newline.
function iolib.write(...: string): ()
	io.write(...)
end

--- Reads a line from standard input. If `prompt` is provided, it is written to stdout before waiting for input.
--- User input can be provided via command line stdin, piped input, or redirection from a file. See `examples/user_input.luau`.
function iolib.input(prompt: string?): string
	if prompt then
		io.write(prompt)
	end
	return io.read()
end

return table.freeze(iolib)
]==],["std/path/posix/types.luau"] = [==[local pathinterface = require("../pathinterface")

--- The raw data of a POSIX path: an array of components and a flag indicating whether the path is absolute.
export type PathData = {
	parts: { string },
	absolute: boolean,
}

--- A structured POSIX path.
export type Path = setmetatable<PathData, pathinterface.PathInterface>

--- Anything that can be used as a POSIX path: a string, a `Path`, or raw `PathData`.
export type Pathlike = string | Path | PathData

return {}
]==],["std/test/failure.luau"] = [==[--!strict
-- @std/test/failure
-- utilities for working with test failures
local types = require("./types")

type Failure = types.Failure

local failures = {}

--- Returns a `Failure` describing an assertion failure at the call site, with `msg` as the failure message.
function failures.assertion(msg: string, depth: number?): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	local stackdepth = depth or 4
	local filename, linenumber = debug.info(stackdepth, "sl")
	local name = debug.info(2, "n")
	return { assertion = name, msg = msg, filename = filename, linenumber = linenumber, __tag = "assertion" }
end

--- Returns a `Failure` describing an error that occurred in the `hook` lifecycle callback.
function failures.lifecycle(hook: types.Hook, err): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	local filename, linenumber = debug.info(3, "sl")
	return { hook = hook, msg = tostring(err), filename = filename, linenumber = linenumber, __tag = "lifecycle" }
end

--- Returns a `Failure` describing an unhandled runtime error, including a stack trace.
function failures.runtimeerror(err): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	return { msg = tostring(err), stacktrace = debug.traceback(tostring(err)), __tag = "runtime_error" }
end

return table.freeze(failures)
]==],["std/system/platform.luau"] = [==[local system = require("@lute/system")

local osName = string.lower(system.os)

local win32 = osName == "windows_nt"
local linux = osName == "linux"
local macos = osName == "darwin"
local unix = macos or linux or osName == "unix" or osName == "posix"

return table.freeze({ win32 = win32, linux = linux, macos = macos, unix = unix })
]==],["lute/time.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local time = {}

local duration_ops = {}
local instant = {}

--- Returns the current time as an `Instant`.
function time.now(): Instant
	error("not implemented")
end

--- Returns the number of seconds elapsed since `instant`.
function time.since(instant: Instant): number
	error("not implemented")
end

time.duration = {}

--- Creates a `Duration` from `seconds` and a fractional `subsecnanos` nanosecond component.
function time.duration.create(seconds: number, subsecnanos: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of nanoseconds.
function time.duration.nanoseconds(nanoseconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of microseconds.
function time.duration.microseconds(microseconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of milliseconds.
function time.duration.milliseconds(milliseconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of seconds.
function time.duration.seconds(seconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of minutes.
function time.duration.minutes(minutes: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of hours.
function time.duration.hours(hours: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of days.
function time.duration.days(days: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of weeks.
function time.duration.weeks(weeks: number): Duration
	error("not implemented")
end

function instant.elapsed(self: Instant): number
	error("not implemented")
end

function duration_ops.toNanoseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toMicroseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toMilliseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toSeconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toMinutes(self: Duration): number
	error("not implemented")
end

function duration_ops.toHours(self: Duration): number
	error("not implemented")
end

function duration_ops.toDays(self: Duration): number
	error("not implemented")
end

function duration_ops.toWeeks(self: Duration): number
	error("not implemented")
end

function duration_ops.subsecnanos(self: Duration): number
	error("not implemented")
end

function duration_ops.subsecmicros(self: Duration): number
	error("not implemented")
end

function duration_ops.subsecmillis(self: Duration): number
	error("not implemented")
end

type Frozen = typeof(table.freeze({}))
--- A time duration with nanosecond precision. Supports arithmetic via `+`, `-`, `*`, `/`, and comparison operators.
export type Duration = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(duration_ops)),
	read __add: (Duration, Duration) -> Duration,
	read __sub: (Duration, Duration) -> Duration,
	read __mul: (Duration, number) -> Duration,
	read __div: (Duration, number) -> Duration,
	read __eq: (Duration, Duration) -> boolean,
	read __lt: (Duration, Duration) -> boolean,
	read __le: (Duration, Duration) -> boolean,
}>

--- A point in time with nanosecond precision. Can be subtracted from another `Instant` to produce a `Duration`.
export type Instant = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(instant)),
	read __sub: (Instant, Instant) -> Duration,
	read __eq: (Instant, Instant) -> boolean,
	read __lt: (Instant, Instant) -> boolean,
	read __le: (Instant, Instant) -> boolean,
}>

return time
]==],["std/test/env.luau"] = [==[--!strict
--@std/test/types
-- Environment to store discovered tests

local types = require("./types")
type TestEnvironment = types.TestEnvironment

local env: TestEnvironment = { anonymous = {}, suites = {}, suiteindex = {}, caseindex = {} }

-- not frozen, the internal test library needs to mutate this during test discovery
return env
]==],["lint/types.luau"] = [==[local path = require("@std/path")
local syntax = require("@std/syntax")

export type severity = "error" | "warning" | "info" | "hint"
export type tag = "unnecessary" | "deprecated"

export type LintViolation = {
	lintname: string,
	location: syntax.Span,
	message: string,
	severity: severity,
	sourcepath: path.Path?,
	suggestedfix: {
		read location: syntax.Span?, -- if nil, applies to whole violation location
		read fix: string,
	}?,
	target: string?, -- Additional information on the violation (e.g link to docs)
	tags: { tag }?,
}

export type GlobalsConfig = { [string]: unknown }
export type RuleOptions = { [string]: unknown }

export type RuleContext = {
	globals: GlobalsConfig,
	options: RuleOptions,
}

export type LintRule = {
	read lint: (ast: syntax.AstStatBlock, sourcepath: path.Path?, context: RuleContext) -> { LintViolation },
	read name: string,
}

return {}
]==],["std/path/types.luau"] = [==[local posixtypes = require("@std/path/posix/types")
local win32types = require("@std/path/win32/types")

export type Path = posixtypes.Path | win32types.Path
export type Pathlike = posixtypes.Pathlike | win32types.Pathlike

return {}
]==],["std/test/assert.luau"] = [==[--!strict
-- @std/test/assert
-- Standard assertion library for Luau

local failure = require("./failure")
local stringext = require("@std/stringext")
local types = require("./types")

-- types
type Failure = types.Failure
type Asserts = types.Asserts

-- more utils
local assertion = failure.assertion

-- Helper to format values for error messages
local function formatValue(val: any): string
	if type(val) == "nil" then
		return "nil"
	elseif type(val) == "string" then
		return `"{val}"`
	elseif type(val) == "table" then
		return "table"
	else
		return tostring(val)
	end
end

-- Structural equality for two tables
local function tablesEqual(t1: unknown, t2: unknown, path: string): (boolean, string?)
	if typeof(t1) ~= "table" or typeof(t2) ~= "table" then
		if t1 ~= t2 then
			return false, `lhs{path} = {formatValue(t1)} but rhs{path} = {formatValue(t2)}`
		end
		return true, nil
	end

	-- Check all keys in t1
	for k, v1 in t1 do
		local v2 = (t2 :: any)[k]
		local newPath = if path == "" then `[{k}]` else `{path}[{k}]`

		-- Check if key exists in t2
		if v2 == nil then
			return false, `lhs{newPath} = {formatValue(v1)} but rhs{newPath} does not exist`
		end

		local equal, msg = tablesEqual(v1, v2, newPath)
		if not equal then
			return false, msg
		end
	end

	-- Check for keys in t2 that aren't in t1
	for k, v in t2 do
		local v1 = (t1 :: any)[k]
		if v1 == nil then
			local newPath = if path == "" then `[{k}]` else `{path}[{k}]`
			return false, `rhs{newPath} = {formatValue(v)} but lhs{newPath} does not exist`
		end
	end

	return true, nil
end

local function neq<T>(lhs: T, rhs: T, msg: string?): Failure?
	if lhs ~= rhs then
		return nil
	end

	return assertion(msg or `{lhs} == {rhs}`)
end

local function that(value: unknown, msg: string?): Failure?
	if value then
		return nil
	end

	return assertion(msg or `Expected a truthy value, but got {formatValue(value)}`)
end

local function throws<T...>(func: (T...) -> ...unknown, ...: T...): Failure?
	local success = pcall(func, ...)
	-- if the callback failed, then this assert passes
	if not success then
		return nil
	end

	return assertion(`{func} did not throw error.`)
end

-- FIXME(Luau): We would like this to be two read-only indexers, but the
-- best option we have otherwise is two error suppressing indexers.
-- Table equality assertionsion with deep comparison
local function tableeq(lhs: { [any]: any }, rhs: { [any]: any }, depth: number?): Failure?
	local stackdepth = depth or 4

	local equal, msg = tablesEqual(lhs, rhs, "")
	if equal then
		return nil
	end
	return assertion(msg or "tables are not equal", stackdepth)
end

local function buffereq(lhs: buffer, rhs: buffer, depth: number?): Failure?
	local stackdepth = depth or 4

	if typeof(lhs) ~= "buffer" then
		return assertion(`lhs is of type {typeof(lhs)}, not buffer`, stackdepth)
	end

	if typeof(rhs) ~= "buffer" then
		return assertion(`rhs is of type {typeof(rhs)}, not buffer`, stackdepth)
	end

	if buffer.len(lhs) ~= buffer.len(rhs) then
		return assertion("buffers are of unequal length", stackdepth)
	end

	local len = buffer.len(lhs)
	for offset = 0, len - 1 do
		local left = buffer.readu8(lhs, offset)
		local right = buffer.readu8(rhs, offset)

		if left ~= right then
			return assertion(
				string.format("lhs[%d] = %02x, but rhs[%d] = %02x", offset, left, offset, right),
				stackdepth
			)
		end
	end
	return nil
end

local function eq(lhs: unknown, rhs: unknown, msg: string?): Failure?
	local stackdepth = 4

	-- Simple equality check for non-tables
	if lhs == rhs then
		return nil
	end

	-- Handle type mismatch
	if typeof(lhs) ~= typeof(rhs) then
		return assertion(msg or `lhs is of type {typeof(lhs)}, but rhs is of type {typeof(rhs)}`)
	end

	-- Check for buffer equality
	if typeof(lhs) == "buffer" then
		-- increment stack depth for debug info by 1 when calling buffereq to account for additional function call (eq -> buffereq)
		return buffereq(lhs :: buffer, rhs :: buffer, stackdepth + 1)
	end

	-- Check for table equality
	if typeof(lhs) == "table" then
		-- increment stack depth for debug info by 1 when calling tableeq to account for additional function call (eq -> tableeq)
		return tableeq(lhs :: { [any]: any }, rhs :: { [any]: any }, stackdepth + 1)
	end

	return assertion(msg or `{lhs} ~= {rhs}`)
end

local function throwsWith<T...>(with: any, func: (T...) -> ...unknown, ...: T...): Failure?
	local success, err = pcall(func, ...)
	if success then
		return assertion(`Expected function to throw/raise error.`)
	end

	local actualErrorMessage = tostring(err)

	if typeof(with) == "string" then
		-- pcall appends filename and line number of the error, so we check suffix only
		if not stringext.hasSuffix(actualErrorMessage, with) then
			return assertion(`Expected suffix of error message "{with}", but got "{actualErrorMessage}"`)
		end
	else
		return eq(err, with, `Expected error "{with}", but got "{formatValue(err)}"`)
	end

	return nil
end

local function strContains(haystack: string, needle: string, instances: number?, msg: string?): Failure?
	if instances == nil then
		if haystack:find(needle, 1, true) == nil then
			return assertion(if msg then msg else `Expected "{haystack}" to contain "{needle}".`)
		end

		return nil
	end

	instances = instances or 1

	if instances <= 0 then
		return assertion("instances must be greater than 0")
	end

	if #haystack:split(needle) ~= instances + 1 then
		return assertion(if msg then msg else `Expected "{haystack}" to contain "{needle}" {instances} times.`)
	end

	return nil
end

local function strNotContains(haystack: string, needle: string, msg: string?): Failure?
	if haystack:find(needle, 1, true) ~= nil then
		return assertion(if msg then msg else `Expected "{haystack}" to not contain "{needle}".`)
	end

	return nil
end

-- utility for taking an assertion and wrapping it as a check that must complete successfully or will return control flow to the error handler
local function reqassert<T...>(req: (T...) -> Failure?): (T...) -> Failure?
	return function(...): Failure?
		local result: Failure? = req(...)
		if result ~= nil then
			error(result)
		end

		return nil
	end
end

return table.freeze({
	eq = reqassert(eq),
	neq = reqassert(neq),
	throws = reqassert(throws),
	throwsWith = reqassert(throwsWith),
	strContains = reqassert(strContains),
	strNotContains = reqassert(strNotContains),
	that = reqassert(that),
}) :: Asserts
]==],["std/syntax/utils/trivia.luau"] = [==[local query = require("../query")
local types = require("../types")

local retrieverLib = {}

--- Returns the leading trivia of the leftmost token in `n`, or an empty array if there are no tokens.
function retrieverLib.leftmostTrivia(n: types.AstNode): { types.Trivia }
	local q = query.findAllFromRoot<<types.Token>>(
		n :: any,
		function(n: types.AstNode) -- LUAUFIX: Code too complex emitted because AstNode is very large
			return if n.kind == "token" then n else nil
		end
	)

	local leftmostToken: types.Token? = nil

	for _, token in q.nodes do
		if leftmostToken == nil then
			leftmostToken = token
		elseif token.location.beginLine < leftmostToken.location.beginLine then
			leftmostToken = token
		elseif
			token.location.beginLine == leftmostToken.location.beginLine
			and token.location.beginColumn < leftmostToken.location.beginColumn
		then
			leftmostToken = token
		end
	end

	return if leftmostToken ~= nil then leftmostToken.leadingTrivia else {}
end

--- Returns the trailing trivia of the rightmost token in `n`, or an empty array if there are no tokens.
function retrieverLib.rightmostTrivia(n: types.AstNode): { types.Trivia }
	local q = query.findAllFromRoot(
		n :: any,
		function(n: types.AstNode) -- LUAUFIX: Code too complex emitted because AstNode is very large
			return if n.kind == "token" then n else nil
		end
	)

	local rightmostToken: types.Token? = nil

	for _, token in q.nodes do
		if rightmostToken == nil then
			rightmostToken = token
		elseif token.location.beginLine > rightmostToken.location.beginLine then
			rightmostToken = token
		elseif
			token.location.beginLine == rightmostToken.location.beginLine
			and token.location.beginColumn > rightmostToken.location.beginColumn
		then
			rightmostToken = token
		end
	end

	return if rightmostToken ~= nil then rightmostToken.trailingTrivia else {}
end

return table.freeze(retrieverLib)
]==],["std/path/posix/init.luau"] = [==[local process = require("@lute/process")
local posixtypes = require("@self/types")
local pathinterface = require("./pathinterface")

export type Path = posixtypes.Path
export type Pathlike = posixtypes.Pathlike

local posix = {}
posix.pathmt = {} :: pathinterface.PathInterface

--- Returns the last component of `path`, or `nil` if the path has no components.
function posix.basename(path: Pathlike): string?
	path = if typeof(path) == "string" then posix.parse(path) else path
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

--- Returns the directory portion of `path` as a string (everything except the last component).
function posix.dirname(path: Pathlike): string
	path = if typeof(path) == "string" then posix.parse(path) else path

	if #path.parts == 0 then
		return posix.format(path)
	else
		return posix.format({
			parts = { table.unpack(path.parts, 1, #path.parts - 1) },
			absolute = path.absolute,
		})
	end
end

--- Returns the file extension of `path` (including the leading dot), or `""` if there is none.
function posix.extname(path: Pathlike): string
	path = if typeof(path) == "string" then posix.parse(path) else path

	if #path.parts == 0 then
		return ""
	end

	local filename = path.parts[#path.parts]

	if filename == "." or filename == ".." then
		return ""
	end

	local dotIndex, _ = filename:find("%.[^%.]*$")
	if dotIndex == nil or dotIndex == 1 then
		return ""
	end

	return filename:sub(dotIndex)
end

--- Converts `path` to its POSIX string representation.
function posix.format(path: Pathlike): string
	if typeof(path) == "string" then
		return path
	end

	if #path.parts == 0 then
		return if path.absolute then "/" else "."
	else
		return (if path.absolute then "/" else "") .. table.concat(path.parts, "/")
	end
end

--- Returns `true` if `path` is absolute (begins with `/`).
function posix.isAbsolute(path: Pathlike): boolean
	path = if typeof(path) == "string" then posix.parse(path) else path
	return path.absolute
end

-- In place extends path with addend
local function joinHelper(path: Path, addend: Pathlike): ()
	addend = if typeof(addend) == "string" then posix.parse(addend) else addend

	if addend.absolute then
		local stringPath = posix.format(path)
		local stringAddend = posix.format(addend)
		error(
			`Could not join {if path.absolute then "absolute" else "relative"} path {stringPath} and absolute path {stringAddend}`
		)
	end

	table.move(addend.parts, 1, #addend.parts, #path.parts + 1, path.parts)
end

--- Joins one or more path segments into a single `Path`. Each segment after the first must be relative.
function posix.join(...: Pathlike): Path
	local parts: { Pathlike } = { ... }
	if #parts == 0 then
		return setmetatable({
			parts = {},
			absolute = false,
		}, posix.pathmt)
	end

	local path: Path = if typeof(parts[1]) == "string"
		then posix.parse(parts[1])
		else setmetatable({
			parts = table.clone((parts[1] :: Path).parts), -- LUAUFIX: Shouldn't need cast
			absolute = (parts[1] :: Path).absolute, -- LUAUFIX: Shouldn't need cast
		}, posix.pathmt)

	for i = 2, #parts do
		joinHelper(path, parts[i])
	end

	return path
end

--- Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.
function posix.normalize(path: Pathlike): Path
	path = if typeof(path) == "string" then posix.parse(path) else path

	local newParts = {}
	for _, part in path.parts do
		if part == "" or part == "." then
			continue
		elseif part == ".." then
			if path.absolute then
				if #newParts > 0 then -- if absolute, only pop if we're not at the root
					table.remove(newParts, #newParts)
				end
			else -- if a relative path, we keep .. prefixes
				if #newParts > 0 and newParts[#newParts] ~= ".." then
					table.remove(newParts, #newParts)
				else
					table.insert(newParts, "..")
				end
			end
		else
			table.insert(newParts, part)
		end
	end

	return setmetatable({
		parts = newParts,
		absolute = path.absolute,
	}, posix.pathmt)
end

--- Parses `path` into a structured `Path` value.
function posix.parse(path: Pathlike): Path
	if typeof(path) == "table" then
		return setmetatable(path, posix.pathmt)
	end
	if typeof(path) ~= "string" then
		error("Expected string or path")
	end

	local isAbs = false

	-- Check if path is absolute
	isAbs = string.sub(path, 1, 1) == "/"

	local parts = {}
	if isAbs then
		-- Strip out the leading / for absolute paths
		parts = path:sub(2):split("/")
	else
		parts = path:split("/")
	end

	-- Filter out empty parts (can happen with leading/trailing separators)
	if #parts > 0 then
		if parts[#parts] == "" then
			table.remove(parts, #parts)
		end
		if #parts > 0 and parts[1] == "" then
			table.remove(parts, 1)
		end
	end

	return setmetatable({
		parts = parts,
		absolute = isAbs,
	}, posix.pathmt)
end

--- Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.
function posix.resolve(...: Pathlike): Path
	local parts = { ... }
	if #parts == 0 then
		return posix.parse(process.cwd())
	end

	local path = posix.parse(parts[#parts])

	for i = #parts - 1, 1, -1 do
		if posix.isAbsolute(path) then
			break
		end

		local segment = posix.parse(parts[i])

		if #segment.parts == 0 then
			continue
		end

		joinHelper(segment, path)
		path = segment
	end

	if not posix.isAbsolute(path) then
		local cwd = posix.parse(process.cwd())
		joinHelper(cwd, path)
		path = cwd
	end

	return posix.normalize(path)
end

--- Returns the relative path from `from` to `to`. Both paths must be of the same kind (both absolute or both relative).
function posix.relative(from: Pathlike, to: Pathlike): Path
	from = if typeof(from) == "string" then posix.parse(from) else from
	to = if typeof(to) == "string" then posix.parse(to) else to

	if from.absolute ~= to.absolute then
		error("Cannot compute relative path between absolute and relative paths")
	end

	local commonPrefixLength = 0

	for i = 1, math.min(#from.parts, #to.parts) do
		if from.parts[i] ~= to.parts[i] then
			break
		end
		commonPrefixLength += 1
	end

	local relativeParts = {}

	if #from.parts > commonPrefixLength then
		for _ = commonPrefixLength + 1, #from.parts do
			table.insert(relativeParts, "..")
		end
	end

	if #to.parts > commonPrefixLength then
		for i = commonPrefixLength + 1, #to.parts do
			table.insert(relativeParts, to.parts[i])
		end
	end

	return setmetatable({
		parts = relativeParts,
		absolute = false,
	}, posix.pathmt)
end

function posix.pathmt:__tostring(): string
	return posix.format(self :: Path)
end

return table.freeze(posix)
]==],["std/syntax/visitor.luau"] = [==[--!strict
-- @std/syntax/visitor
-- Visitor pattern implementation for traversing Luau AST nodes

local types = require("./types")

local visitorlib = {}

--- A table of callbacks invoked during AST traversal. Each `visit` callback receives the corresponding node and
--- returns `true` to continue visiting its children, or `false` to skip them. "End" callbacks fire after all children
--- of that sort have been visited. Override only the callbacks you care about; unset callbacks default to visiting all children.
export type Visitor = {
	visitStatBlock: (types.AstStatBlock) -> boolean,
	visitStatBlockEnd: (types.AstStatBlock) -> (),
	visitStatDo: (types.AstStatDo) -> boolean,
	visitStatIf: (types.AstStatIf) -> boolean,
	visitStatWhile: (types.AstStatWhile) -> boolean,
	visitStatRepeat: (types.AstStatRepeat) -> boolean,
	visitStatBreak: (types.AstStatBreak) -> boolean,
	visitStatContinue: (types.AstStatContinue) -> boolean,
	visitStatReturn: (types.AstStatReturn) -> boolean,
	visitStatLocalDeclaration: (types.AstStatLocal) -> boolean,
	visitStatLocalDeclarationEnd: (types.AstStatLocal) -> (),
	visitStatFor: (types.AstStatFor) -> boolean,
	visitStatForEnd: (types.AstStatFor) -> (),
	visitStatForIn: (types.AstStatForIn) -> boolean,
	visitStatForInEnd: (types.AstStatForIn) -> (),
	visitStatAssign: (types.AstStatAssign) -> boolean,
	visitStatCompoundAssign: (types.AstStatCompoundAssign) -> boolean,
	visitStatFunction: (types.AstStatFunction) -> boolean,
	visitStatLocalFunction: (types.AstStatLocalFunction) -> boolean,
	visitStatTypeAlias: (types.AstStatTypeAlias) -> boolean,
	visitStatTypeFunction: (types.AstStatTypeFunction) -> boolean,
	visitStatExpr: (types.AstStatExpr) -> boolean,

	visitExpr: (types.AstExpr) -> boolean,
	visitExprEnd: (types.AstExpr) -> (),
	visitExprConstantNil: (types.AstExprConstantNil) -> boolean,
	visitExprConstantString: (types.AstExprConstantString) -> boolean,
	visitExprConstantBool: (types.AstExprConstantBool) -> boolean,
	visitExprConstantNumber: (types.AstExprConstantNumber) -> boolean,
	visitExprLocal: (types.AstExprLocal) -> boolean,
	visitExprGlobal: (types.AstExprGlobal) -> boolean,
	visitExprCall: (types.AstExprCall) -> boolean,
	visitExprUnary: (types.AstExprUnary) -> boolean,
	visitExprBinary: (types.AstExprBinary) -> boolean,
	visitExprFunction: (types.AstExprFunction) -> boolean,
	visitExprFunctionEnd: (types.AstExprFunction) -> (),
	visitExprInstantiate: (types.AstExprInstantiate) -> boolean,
	visitTableExprItem: (types.AstTableExprItem) -> boolean,
	visitExprTable: (types.AstExprTable) -> boolean,
	visitExprIndexName: (types.AstExprIndexName) -> boolean,
	visitExprIndexExpr: (types.AstExprIndexExpr) -> boolean,
	visitExprGroup: (types.AstExprGroup) -> boolean,
	visitExprInterpString: (types.AstExprInterpString) -> boolean,
	visitExprTypeAssertion: (types.AstExprTypeAssertion) -> boolean,
	visitExprIfElse: (types.AstExprIfElse) -> boolean,
	visitExprVarargs: (types.AstExprVarargs) -> boolean,

	visitTypeReference: (types.AstTypeReference) -> boolean,
	visitTypeSingletonBool: (types.AstTypeSingletonBool) -> boolean,
	visitTypeSingletonString: (types.AstTypeSingletonString) -> boolean,
	visitTypeTypeof: (types.AstTypeTypeof) -> boolean,
	visitTypeGroup: (types.AstTypeGroup) -> boolean,
	visitTypeOptional: (types.AstTypeOptional) -> boolean,
	visitTypeUnion: (types.AstTypeUnion) -> boolean,
	visitTypeIntersection: (types.AstTypeIntersection) -> boolean,
	visitTypeArray: (types.AstTypeArray) -> boolean,
	visitTypeTable: (types.AstTypeTable) -> boolean,
	visitTypeFunction: (types.AstTypeFunction) -> boolean,

	visitTypePackExplicit: (types.AstTypePackExplicit) -> boolean,
	visitTypePackGeneric: (types.AstTypePackGeneric) -> boolean,
	visitTypePackVariadic: (types.AstTypePackVariadic) -> boolean,

	visitToken: (types.Token) -> boolean,

	visitLocal: (types.AstLocal) -> boolean,

	visitAttribute: (types.AstAttribute) -> boolean,
}

local function alwaysVisit(...: types.AstNode)
	return true
end

local defaultVisitor: Visitor = {
	visitStatBlock = alwaysVisit,
	visitStatBlockEnd = alwaysVisit :: (types.AstNode) -> (),
	visitStatDo = alwaysVisit,
	visitStatIf = alwaysVisit,
	visitStatWhile = alwaysVisit,
	visitStatRepeat = alwaysVisit,
	visitStatBreak = alwaysVisit,
	visitStatContinue = alwaysVisit,
	visitStatReturn = alwaysVisit,
	visitStatLocalDeclaration = alwaysVisit,
	visitStatLocalDeclarationEnd = alwaysVisit :: (types.AstNode) -> (),
	visitStatFor = alwaysVisit,
	visitStatForEnd = alwaysVisit :: (types.AstNode) -> (),
	visitStatForIn = alwaysVisit,
	visitStatForInEnd = alwaysVisit :: (types.AstNode) -> (),
	visitStatAssign = alwaysVisit,
	visitStatCompoundAssign = alwaysVisit,
	visitStatFunction = alwaysVisit,
	visitStatLocalFunction = alwaysVisit,
	visitStatTypeAlias = alwaysVisit,
	visitStatTypeFunction = alwaysVisit,
	visitStatExpr = alwaysVisit,

	visitExpr = alwaysVisit,
	visitExprConstantNil = alwaysVisit,
	visitExprConstantString = alwaysVisit,
	visitExprConstantBool = alwaysVisit,
	visitExprConstantNumber = alwaysVisit,
	visitExprEnd = alwaysVisit :: (types.AstNode) -> (),
	visitExprLocal = alwaysVisit,
	visitExprGlobal = alwaysVisit,
	visitExprCall = alwaysVisit,
	visitExprUnary = alwaysVisit,
	visitExprBinary = alwaysVisit,
	visitExprFunction = alwaysVisit,
	visitExprFunctionEnd = alwaysVisit :: (types.AstNode) -> (),
	visitExprInstantiate = alwaysVisit,
	visitTableExprItem = alwaysVisit :: (types.AstTableExprItem) -> boolean,
	visitExprTable = alwaysVisit,
	visitExprIndexName = alwaysVisit,
	visitExprIndexExpr = alwaysVisit,
	visitExprGroup = alwaysVisit,
	visitExprInterpString = alwaysVisit,
	visitExprTypeAssertion = alwaysVisit,
	visitExprIfElse = alwaysVisit,
	visitExprVarargs = alwaysVisit,

	visitTypeReference = alwaysVisit,
	visitTypeSingletonBool = alwaysVisit,
	visitTypeSingletonString = alwaysVisit,
	visitTypeTypeof = alwaysVisit,
	visitTypeGroup = alwaysVisit,
	visitTypeOptional = alwaysVisit,
	visitTypeUnion = alwaysVisit,
	visitTypeIntersection = alwaysVisit,
	visitTypeArray = alwaysVisit,
	visitTypeTable = alwaysVisit :: (types.AstTypeTable) -> boolean, -- LUAUFIX: Code too complex emitted in absence of cast
	visitTypeFunction = alwaysVisit,

	visitTypePackExplicit = alwaysVisit,
	visitTypePackGeneric = alwaysVisit,
	visitTypePackVariadic = alwaysVisit,

	visitToken = alwaysVisit,

	visitLocal = alwaysVisit,

	visitAttribute = alwaysVisit,
}

local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function visitToken<T>(token: types.Token<T>, visitor: Visitor)
	visitor.visitToken(token)
end

local function visitPunctuated<T, Separator>(list: types.Punctuated<T, Separator>, visitor: Visitor, apply: (T, Visitor) -> ())
	for _, item in list do
		apply(item.node, visitor)
		if item.separator then
			visitToken(item.separator, visitor)
		end
	end
end

local function visitLocal(node: types.AstLocal, visitor: Visitor)
	if visitor.visitLocal(node) then
		visitToken(node.name, visitor)
		if node.colon then
			visitToken(node.colon, visitor)
		end
		if node.annotation then
			visitType(node.annotation, visitor)
		end
	end
end

local function visitTypeOrTypePack(node: types.AstType | types.AstTypePack, visitor: Visitor)
	if node.kind == "type" then
		visitType(node, visitor)
	else
		visitTypePack(node, visitor)
	end
end

local function visitStatBlock(block: types.AstStatBlock, visitor: Visitor)
	if visitor.visitStatBlock(block) then
		for _, statement in block.statements do
			visitStatement(statement, visitor)
		end

		visitor.visitStatBlockEnd(block)
	end
end

local function visitStatDo(node: types.AstStatDo, visitor: Visitor)
	if visitor.visitStatDo(node) then
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
	end
end

local function visitStatIf(node: types.AstStatIf, visitor: Visitor)
	if visitor.visitStatIf(node) then
		visitToken(node.ifKeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.thenKeyword, visitor)
		visitStatBlock(node.thenBlock, visitor)
		for _, elseifNode in node.elseifs do
			visitToken(elseifNode.elseIfKeyword, visitor)
			visitExpr(elseifNode.condition, visitor)
			visitToken(elseifNode.thenKeyword, visitor)
			visitStatBlock(elseifNode.thenBlock, visitor)
		end
		if node.elseKeyword then
			visitToken(node.elseKeyword, visitor)
		end
		if node.elseBlock then
			visitStatBlock(node.elseBlock, visitor)
		end
		visitToken(node.endKeyword, visitor)
	end
end

local function visitStatWhile(node: types.AstStatWhile, visitor: Visitor)
	if visitor.visitStatWhile(node) then
		visitToken(node.whileKeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
	end
end

local function visitStatRepeat(node: types.AstStatRepeat, visitor: Visitor)
	if visitor.visitStatRepeat(node) then
		visitToken(node.repeatKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.untilKeyword, visitor)
		visitExpr(node.condition, visitor)
	end
end

local function visitStatBreak(node: types.AstStatBreak, visitor: Visitor)
	if visitor.visitStatBreak(node) then
		visitToken(node.token, visitor)
	end
end

local function visitStatContinue(node: types.AstStatContinue, visitor: Visitor)
	if visitor.visitStatContinue(node) then
		visitToken(node.token, visitor)
	end
end

local function visitStatReturn(node: types.AstStatReturn, visitor: Visitor)
	if visitor.visitStatReturn(node) then
		visitToken(node.returnKeyword, visitor)
		visitPunctuated(node.expressions, visitor, visitExpr)
	end
end

local function visitLocalStatement(node: types.AstStatLocal, visitor: Visitor)
	if visitor.visitStatLocalDeclaration(node) then
		visitToken(node.localKeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		if node.equals then
			visitToken(node.equals, visitor)
		end
		visitPunctuated(node.values, visitor, visitExpr)

		visitor.visitStatLocalDeclarationEnd(node)
	end
end

local function visitStatFor(node: types.AstStatFor, visitor: Visitor)
	if visitor.visitStatFor(node) then
		visitToken(node.forKeyword, visitor)
		visitLocal(node.variable, visitor)
		visitToken(node.equals, visitor)
		visitExpr(node.from, visitor)
		visitToken(node.toComma, visitor)
		visitExpr(node.to, visitor)
		if node.stepComma then
			visitToken(node.stepComma, visitor)
		end
		if node.step then
			visitExpr(node.step, visitor)
		end
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
		visitor.visitStatForEnd(node)
	end
end

local function visitStatForIn(node: types.AstStatForIn, visitor: Visitor)
	if visitor.visitStatForIn(node) then
		visitToken(node.forKeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		visitToken(node.inKeyword, visitor)
		visitPunctuated(node.values, visitor, visitExpr)
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
		visitor.visitStatForInEnd(node)
	end
end

local function visitStatAssign(node: types.AstStatAssign, visitor: Visitor)
	if visitor.visitStatAssign(node) then
		visitPunctuated(node.variables, visitor, visitExpr)
		visitToken(node.equals, visitor)
		visitPunctuated(node.values, visitor, visitExpr)
	end
end

local function visitStatCompoundAssign(node: types.AstStatCompoundAssign, visitor: Visitor)
	if visitor.visitStatCompoundAssign(node) then
		visitExpr(node.variable, visitor)
		visitToken(node.operand, visitor)
		visitExpr(node.value, visitor)
	end
end

local function visitGeneric(node: types.AstGenericType, visitor: Visitor)
	visitToken(node.name, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitType(node.default, visitor)
	end
end

local function visitGenericPack(node: types.AstGenericTypePack, visitor: Visitor)
	visitToken(node.name, visitor)
	visitToken(node.ellipsis, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitTypePack(node.default, visitor)
	end
end

local function visitStatTypeAlias(node: types.AstStatTypeAlias, visitor: Visitor)
	if visitor.visitStatTypeAlias(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.typeToken, visitor)
		visitToken(node.name, visitor)
		if node.openGenerics then
			visitToken(node.openGenerics, visitor)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric)
		end
		if node.genericPacks then
			visitPunctuated(node.genericPacks, visitor, visitGenericPack)
		end
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor)
		end
		visitToken(node.equals, visitor)
		visitType(node.type, visitor)
	end
end

local function visitStatExpr(node: types.AstStatExpr, visitor: Visitor)
	if visitor.visitStatExpr(node) then
		visitExpr(node.expression, visitor)
	end
end

local function visitExprConstantString(node: types.AstExprConstantString, visitor: Visitor)
	if visitor.visitExprConstantString(node) then
		visitor.visitToken(node.token)
	end
end

local function visitExprConstantNil(node: types.AstExprConstantNil, visitor: Visitor)
	if visitor.visitExprConstantNil(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprConstantBool(node: types.AstExprConstantBool, visitor: Visitor)
	if visitor.visitExprConstantBool(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprConstantNumber(node: types.AstExprConstantNumber, visitor: Visitor)
	if visitor.visitExprConstantNumber(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprLocal(node: types.AstExprLocal, visitor: Visitor)
	if visitor.visitExprLocal(node) then
		visitor.visitToken(node.token)
	end
end

local function visitExprGlobal(node: types.AstExprGlobal, visitor: Visitor)
	if visitor.visitExprGlobal(node) then
		visitor.visitToken(node.name)
	end
end

local function visitExprVarargs(node: types.AstExprVarargs, visitor: Visitor)
	if visitor.visitExprVarargs(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprCall(node: types.AstExprCall, visitor: Visitor)
	if visitor.visitExprCall(node) then
		visitExpr(node.func, visitor)
		if node.openParens then
			visitToken(node.openParens, visitor)
		end
		visitPunctuated(node.arguments, visitor, visitExpr)
		if node.closeParens then
			visitToken(node.closeParens, visitor)
		end
	end
end

local function visitExprUnary(node: types.AstExprUnary, visitor: Visitor)
	if visitor.visitExprUnary(node) then
		visitToken(node.operator, visitor)
		visitExpr(node.operand, visitor)
	end
end

local function visitExprBinary(node: types.AstExprBinary, visitor: Visitor)
	if visitor.visitExprBinary(node) then
		visitExpr(node.lhsOperand, visitor)
		visitToken(node.operator, visitor)
		visitExpr(node.rhsOperand, visitor)
	end
end

local function visitAttribute(node: types.AstAttribute, visitor: Visitor)
	if visitor.visitAttribute(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprFunction(
	node: types.AstExprFunction,
	visitor: Visitor,
	shouldVisitAttributes: boolean?,
	shouldVisitFunctionKeyword: boolean?
)
	if visitor.visitExprFunction(node) then
		if shouldVisitAttributes ~= false then
			for _, attribute in node.attributes do
				visitAttribute(attribute, visitor)
			end
		end
		if shouldVisitFunctionKeyword ~= false then
			visitToken(node.functionKeyword, visitor)
		end
		if node.openGenerics then
			visitToken(node.openGenerics, visitor)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric)
		end
		if node.genericPacks then
			visitPunctuated(node.genericPacks, visitor, visitGenericPack)
		end
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor)
		end
		visitToken(node.openParens, visitor)
		visitPunctuated(node.parameters, visitor, visitLocal)
		if node.vararg then
			visitToken(node.vararg, visitor)
		end
		if node.varargColon then
			visitToken(node.varargColon, visitor)
		end
		if node.varargAnnotation then
			visitTypePack(node.varargAnnotation, visitor)
		end
		visitToken(node.closeParens, visitor)
		if node.returnSpecifier then
			visitToken(node.returnSpecifier, visitor)
		end
		if node.returnAnnotation then
			visitTypePack(node.returnAnnotation, visitor)
		end
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
		visitor.visitExprFunctionEnd(node)
	end
end

local function visitExprInstantiate(node: types.AstExprInstantiate, visitor: Visitor)
	if visitor.visitExprInstantiate(node) then
		visitExpr(node.expr, visitor)
		visitToken(node.leftArrow1, visitor)
		visitToken(node.leftArrow2, visitor)
		visitPunctuated(node.typeArguments, visitor, visitTypeOrTypePack)
		visitToken(node.rightArrow1, visitor)
		visitToken(node.rightArrow2, visitor)
	end
end

local function visitStatFunction(node: types.AstStatFunction, visitor: Visitor)
	if visitor.visitStatFunction(node) then
		-- We need to visit in lexical order
		for _, attribute in node.func.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.func.functionKeyword, visitor)
		visitExpr(node.name, visitor)
		visitExprFunction(node.func, visitor, false, false)
	end
end

local function visitStatLocalFunction(node: types.AstStatLocalFunction, visitor: Visitor)
	if visitor.visitStatLocalFunction(node) then
		for _, attribute in node.func.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.localKeyword, visitor)
		visitToken(node.func.functionKeyword, visitor)
		visitLocal(node.name, visitor)
		visitExprFunction(node.func, visitor, false, false)
	end
end

local function visitStatTypeFunction(node: types.AstStatTypeFunction, visitor: Visitor)
	if visitor.visitStatTypeFunction(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.type, visitor)
		visitToken(node.body.functionKeyword, visitor)
		visitToken(node.name, visitor)
		visitExprFunction(node.body, visitor, true, false)
	end
end

local function visitTableExprItem(node: types.AstTableExprItem, visitor: Visitor)
	if visitor.visitTableExprItem(node) then
		if node.kind == "list" then
			visitExpr(node.value, visitor)
		elseif node.kind == "record" then
			visitToken(node.key, visitor)
			visitToken(node.equals, visitor)
			visitExpr(node.value, visitor)
		elseif node.kind == "general" then
			visitToken(node.indexerOpen, visitor)
			visitExpr(node.key, visitor)
			visitToken(node.indexerClose, visitor)
			visitToken(node.equals, visitor)
			visitExpr(node.value, visitor)
		else
			exhaustiveMatch(node.kind)
		end

		if node.separator then
			visitToken(node.separator, visitor)
		end
	end
end

local function visitExprTable(node: types.AstExprTable, visitor: Visitor)
	if visitor.visitExprTable(node) then
		visitToken(node.openBrace, visitor)
		for _, item in node.entries do
			visitTableExprItem(item, visitor)
		end
		visitToken(node.closeBrace, visitor)
	end
end

local function visitExprIndexName(node: types.AstExprIndexName, visitor: Visitor)
	if visitor.visitExprIndexName(node) then
		visitExpr(node.expression, visitor)
		visitToken(node.accessor, visitor)
		visitToken(node.index, visitor)
	end
end

local function visitExprIndexExpr(node: types.AstExprIndexExpr, visitor: Visitor)
	if visitor.visitExprIndexExpr(node) then
		visitExpr(node.expression, visitor)
		visitToken(node.openBrackets, visitor)
		visitExpr(node.index, visitor)
		visitToken(node.closeBrackets, visitor)
	end
end

local function visitExprGroup(node: types.AstExprGroup, visitor: Visitor)
	if visitor.visitExprGroup(node) then
		visitToken(node.openParens, visitor)
		visitExpr(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitExprInterpString(node: types.AstExprInterpString, visitor: Visitor)
	if visitor.visitExprInterpString(node) then
		for i = 1, #node.strings do
			visitToken(node.strings[i], visitor)
			if i <= #node.expressions then
				visitExpr(node.expressions[i], visitor)
			end
		end
	end
end

local function visitExprTypeAssertion(node: types.AstExprTypeAssertion, visitor: Visitor)
	if visitor.visitExprTypeAssertion(node) then
		visitExpr(node.operand, visitor)
		visitToken(node.operator, visitor)
		visitType(node.annotation, visitor)
	end
end

local function visitExprIfElse(node: types.AstExprIfElse, visitor: Visitor)
	if visitor.visitExprIfElse(node) then
		visitToken(node.ifKeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.thenKeyword, visitor)
		visitExpr(node.thenExpr, visitor)
		for _, elseifs in node.elseifs do
			visitToken(elseifs.elseIfKeyword, visitor)
			visitExpr(elseifs.condition, visitor)
			visitToken(elseifs.thenKeyword, visitor)
			visitExpr(elseifs.thenExpr, visitor)
		end
		visitToken(node.elseKeyword, visitor)
		visitExpr(node.elseExpr, visitor)
	end
end

local function visitTypeOrPack(node: types.AstType | types.AstTypePack, visitor: Visitor)
	if node.kind == "typepack" then
		visitTypePack(node, visitor)
	else
		visitType(node, visitor)
	end
end

local function visitTypeReference(node: types.AstTypeReference, visitor: Visitor)
	if visitor.visitTypeReference(node) then
		if node.prefix then
			visitToken(node.prefix, visitor)
		end
		if node.prefixPoint then
			visitToken(node.prefixPoint, visitor)
		end
		visitToken(node.name, visitor)
		if node.openParameters then
			visitToken(node.openParameters, visitor)
		end
		if node.parameters then
			visitPunctuated(node.parameters, visitor, visitTypeOrPack)
		end
		if node.closeParameters then
			visitToken(node.closeParameters, visitor)
		end
	end
end

local function visitTypeSingletonBool(node: types.AstTypeSingletonBool, visitor: Visitor)
	if visitor.visitTypeSingletonBool(node) then
		visitToken(node.token, visitor)
	end
end

local function visitTypeSingletonString(node: types.AstTypeSingletonString, visitor: Visitor)
	if visitor.visitTypeSingletonString(node) then
		visitToken(node.token, visitor)
	end
end

local function visitTypeTypeof(node: types.AstTypeTypeof, visitor: Visitor)
	if visitor.visitTypeTypeof(node) then
		visitToken(node.typeof, visitor)
		visitToken(node.openParens, visitor)
		visitExpr(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitTypeGroup(node: types.AstTypeGroup, visitor: Visitor)
	if visitor.visitTypeGroup(node) then
		visitToken(node.openParens, visitor)
		visitType(node.type, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitTypeOptional(node: types.AstTypeOptional, visitor: Visitor)
	if visitor.visitTypeOptional(node) then
		visitToken(node.token, visitor)
	end
end

local function visitTypeUnion(node: types.AstTypeUnion, visitor: Visitor)
	if visitor.visitTypeUnion(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeIntersection(node: types.AstTypeIntersection, visitor: Visitor)
	if visitor.visitTypeIntersection(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeArray(node: types.AstTypeArray, visitor: Visitor)
	if visitor.visitTypeArray(node) then
		visitToken(node.openBrace, visitor)
		if node.access then
			visitToken(node.access, visitor)
		end
		visitType(node.type, visitor)
		visitToken(node.closeBrace, visitor)
	end
end

local function visitTypeTable(node: types.AstTypeTable, visitor: Visitor)
	if visitor.visitTypeTable(node) then
		visitToken(node.openBrace, visitor)
		for _, entry in node.entries do
			if entry.access then
				visitToken(entry.access, visitor)
			end
			if entry.kind == "indexer" then
				visitToken(entry.indexerOpen, visitor)
				visitType(entry.key, visitor)
				visitToken(entry.indexerClose, visitor)
			elseif entry.kind == "stringproperty" then
				visitToken(entry.indexerOpen, visitor)
				visitTypeSingletonString(entry.key, visitor)
				visitToken(entry.indexerClose, visitor)
			else
				visitToken(entry.key, visitor)
			end
			visitToken(entry.colon, visitor)
			visitType(entry.value, visitor)
			if entry.separator then
				visitToken(entry.separator, visitor)
			end
		end
		visitToken(node.closeBrace, visitor)
	end
end

local function visitFunctionTypeParameter(node: types.AstFunctionTypeParameter, visitor)
	if node.name then
		visitToken(node.name, visitor)
	end
	if node.colon then
		visitToken(node.colon, visitor)
	end
	visitType(node.type, visitor)
end

local function visitTypeFunction(node: types.AstTypeFunction, visitor: Visitor)
	if visitor.visitTypeFunction(node) then
		if node.openGenerics then
			visitToken(node.openGenerics, visitor)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric)
		end
		if node.genericPacks then
			visitPunctuated(node.genericPacks, visitor, visitGenericPack)
		end
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor)
		end
		visitToken(node.openParens, visitor)
		visitPunctuated(node.parameters, visitor, visitFunctionTypeParameter)
		if node.vararg then
			visitTypePack(node.vararg, visitor)
		end
		visitToken(node.closeParens, visitor)
		visitToken(node.returnArrow, visitor)
		visitTypePack(node.returnTypes, visitor)
	end
end

local function visitTypePackExplicit(node: types.AstTypePackExplicit, visitor: Visitor)
	if visitor.visitTypePackExplicit(node) then
		if node.openParens then
			visitToken(node.openParens, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
		if node.tailType then
			visitTypePack(node.tailType, visitor)
		end
		if node.closeParens then
			visitToken(node.closeParens, visitor)
		end
	end
end

local function visitTypePackGeneric(node: types.AstTypePackGeneric, visitor: Visitor)
	if visitor.visitTypePackGeneric(node) then
		visitToken(node.name, visitor)
		visitToken(node.ellipsis, visitor)
	end
end

local function visitTypePackVariadic(node: types.AstTypePackVariadic, visitor: Visitor)
	if visitor.visitTypePackVariadic(node) then
		if node.ellipsis then
			visitToken(node.ellipsis, visitor)
		end
		visitType(node.type, visitor)
	end
end

function visitExpr(expression: types.AstExpr, visitor: Visitor)
	if visitor.visitExpr(expression) then
		if expression.tag == "nil" then
			visitExprConstantNil(expression, visitor)
		elseif expression.tag == "boolean" then
			visitExprConstantBool(expression, visitor)
		elseif expression.tag == "number" then
			visitExprConstantNumber(expression, visitor)
		elseif expression.tag == "string" then
			visitExprConstantString(expression, visitor)
		elseif expression.tag == "local" then
			visitExprLocal(expression, visitor)
		elseif expression.tag == "global" then
			visitExprGlobal(expression, visitor)
		elseif expression.tag == "vararg" then
			visitExprVarargs(expression, visitor)
		elseif expression.tag == "call" then
			visitExprCall(expression, visitor)
		elseif expression.tag == "unary" then
			visitExprUnary(expression, visitor)
		elseif expression.tag == "binary" then
			visitExprBinary(expression, visitor)
		elseif expression.tag == "function" then
			visitExprFunction(expression, visitor)
		elseif expression.tag == "instantiate" then
			visitExprInstantiate(expression, visitor)
		elseif expression.tag == "table" then
			visitExprTable(expression, visitor)
		elseif expression.tag == "indexname" then
			visitExprIndexName(expression, visitor)
		elseif expression.tag == "index" then
			visitExprIndexExpr(expression, visitor)
		elseif expression.tag == "group" then
			visitExprGroup(expression, visitor)
		elseif expression.tag == "interpolatedstring" then
			visitExprInterpString(expression, visitor)
		elseif expression.tag == "cast" then
			visitExprTypeAssertion(expression, visitor)
		elseif expression.tag == "conditional" then
			visitExprIfElse(expression, visitor)
		else
			exhaustiveMatch(expression.tag)
		end

		visitor.visitExprEnd(expression)
	end
end

function visitStatement(statement: types.AstStat, visitor: Visitor)
	if statement.tag == "block" then
		visitStatBlock(statement, visitor)
	elseif statement.tag == "do" then
		visitStatDo(statement, visitor)
	elseif statement.tag == "conditional" then
		visitStatIf(statement, visitor)
	elseif statement.tag == "expression" then
		visitStatExpr(statement, visitor)
	elseif statement.tag == "local" then
		visitLocalStatement(statement, visitor)
	elseif statement.tag == "return" then
		visitStatReturn(statement, visitor)
	elseif statement.tag == "while" then
		visitStatWhile(statement, visitor)
	elseif statement.tag == "break" then
		visitStatBreak(statement, visitor)
	elseif statement.tag == "continue" then
		visitStatContinue(statement, visitor)
	elseif statement.tag == "repeat" then
		visitStatRepeat(statement, visitor)
	elseif statement.tag == "for" then
		visitStatFor(statement, visitor)
	elseif statement.tag == "forin" then
		visitStatForIn(statement, visitor)
	elseif statement.tag == "assign" then
		visitStatAssign(statement, visitor)
	elseif statement.tag == "compoundassign" then
		visitStatCompoundAssign(statement, visitor)
	elseif statement.tag == "function" then
		visitStatFunction(statement, visitor)
	elseif statement.tag == "localfunction" then
		visitStatLocalFunction(statement, visitor)
	elseif statement.tag == "typealias" then
		visitStatTypeAlias(statement, visitor)
	elseif statement.tag == "typefunction" then
		visitStatTypeFunction(statement, visitor)
	else
		exhaustiveMatch(statement.tag)
	end
end

function visitType(type: types.AstType, visitor: Visitor)
	if type.tag == "reference" then
		visitTypeReference(type, visitor)
	elseif type.tag == "boolean" then
		visitTypeSingletonBool(type, visitor)
	elseif type.tag == "string" then
		visitTypeSingletonString(type, visitor)
	elseif type.tag == "typeof" then
		visitTypeTypeof(type, visitor)
	elseif type.tag == "group" then
		visitTypeGroup(type, visitor)
	elseif type.tag == "union" then
		visitTypeUnion(type, visitor)
	elseif type.tag == "intersection" then
		visitTypeIntersection(type, visitor)
	elseif type.tag == "optional" then
		visitTypeOptional(type, visitor)
	elseif type.tag == "array" then
		visitTypeArray(type, visitor)
	elseif type.tag == "table" then
		visitTypeTable(type, visitor)
	elseif type.tag == "function" then
		visitTypeFunction(type, visitor)
	else
		exhaustiveMatch(type.tag)
	end
end

function visitTypePack(type: types.AstTypePack, visitor: Visitor)
	if type.tag == "explicit" then
		visitTypePackExplicit(type, visitor)
	elseif type.tag == "generic" then
		visitTypePackGeneric(type, visitor)
	elseif type.tag == "variadic" then
		visitTypePackVariadic(type, visitor)
	else
		exhaustiveMatch(type.tag)
	end
end

--- Creates a `Visitor` where every callback delegates to `visit`. If `visit` is omitted, all callbacks default to visiting every node.
local function create(visit: ((types.AstNode) -> boolean)?): Visitor
	if visit then
		return {
			visitStatBlock = visit,
			visitStatBlockEnd = function(s)
				visit(s)
			end,
			visitStatDo = visit,
			visitStatIf = visit,
			visitStatWhile = visit,
			visitStatRepeat = visit,
			visitStatBreak = visit,
			visitStatContinue = visit,
			visitStatReturn = visit,
			visitStatLocalDeclaration = visit,
			visitStatLocalDeclarationEnd = function(s)
				visit(s)
			end,
			visitStatFor = visit,
			visitStatForEnd = function(s)
				visit(s)
			end,
			visitStatForIn = visit,
			visitStatForInEnd = function(s)
				visit(s)
			end,
			visitStatAssign = visit,
			visitStatCompoundAssign = visit,
			visitStatFunction = visit,
			visitStatLocalFunction = visit,
			visitStatTypeAlias = visit,
			visitStatTypeFunction = visit,
			visitStatExpr = visit,

			visitExpr = visit,
			visitExprEnd = function(s)
				visit(s)
			end,
			visitExprLocal = visit,
			visitExprGlobal = visit,
			visitExprCall = visit,
			visitExprUnary = visit,
			visitExprBinary = visit,
			visitExprFunction = visit,
			visitExprFunctionEnd = function(s)
				visit(s)
			end,
			visitExprInstantiate = visit,
			visitTableExprItem = visit :: (types.AstTableExprItem) -> boolean,
			visitExprTable = visit,
			visitExprIndexName = visit,
			visitExprIndexExpr = visit,
			visitExprGroup = visit,
			visitExprInterpString = visit,
			visitExprTypeAssertion = visit,
			visitExprIfElse = visit,

			visitTypeReference = visit,
			visitTypeSingletonBool = visit,
			visitTypeSingletonString = visit,
			visitTypeTypeof = visit,
			visitTypeGroup = visit,
			visitTypeOptional = visit,
			visitTypeUnion = visit,
			visitTypeIntersection = visit,
			visitTypeArray = visit,
			visitTypeTable = visit :: (types.AstTypeTable) -> boolean, -- LUAUFIX: Remove cast once code too complex no longer emitted
			visitTypeFunction = visit,

			visitTypePackExplicit = visit,
			visitTypePackGeneric = visit,
			visitTypePackVariadic = visit,

			visitToken = visit :: (types.Token) -> boolean,
			visitExprConstantNil = visit,
			visitExprConstantString = visit,
			visitExprConstantBool = visit,
			visitExprConstantNumber = visit,
			visitLocal = visit,
			visitExprVarargs = visit,

			visitAttribute = visit,
		}
	else
		return table.clone(defaultVisitor)
	end
end

--- Dispatches `node` to the appropriate `visitor` callback based on its `kind`.
local function visit(node: types.AstNode, visitor: Visitor)
	if node.kind == "stat" then
		visitStatement(node, visitor)
	elseif node.kind == "expr" then
		visitExpr(node, visitor)
	elseif node.kind == "type" then
		visitType(node, visitor)
	elseif node.kind == "typepack" then
		visitTypePack(node, visitor)
	elseif node.kind == "local" then
		visitLocal(node, visitor)
	elseif node.kind == "attribute" then
		visitAttribute(node, visitor)
	elseif node.kind == "token" then
		visitToken(node, visitor)
	elseif (node :: types.AstTableExprItem).isTableItem then
		visitTableExprItem(node :: types.AstTableExprItem, visitor)
	else
		exhaustiveMatch(node.kind)
	end
end

--- Creates a `Visitor` where every callback delegates to `visit`. If `visit` is omitted, all callbacks default to visiting every node.
visitorlib.create = create
--- Visits all statements in a block.
visitorlib.visitBlock = visitStatBlock
--- Visits a single statement, dispatching to the appropriate callback.
visitorlib.visitStatement = visitStatement
--- Visits an expression, dispatching to the appropriate callback.
visitorlib.visitExpression = visitExpr
--- Visits a type annotation, dispatching to the appropriate callback.
visitorlib.visitType = visitType
--- Visits a type pack, dispatching to the appropriate callback.
visitorlib.visitTypePack = visitTypePack
--- Visits a single token.
visitorlib.visitToken = visitToken
--- Visits any AST node, dispatching by `node.kind`.
visitorlib.visit = visit

return table.freeze(visitorlib)
]==],["lute/net/server.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local server = {}

--- An HTTP request received by the server, containing method, path, body, query params, and headers.
export type ReceivedRequest = {
	method: string,
	path: string,
	body: string,
	query: { [string]: string },
	headers: { [string]: string },
}

--- A response that can be returned from a server handler: a plain string body, or a table with status, body, and headers.
export type ServerResponse = string | {
	status: number?,
	body: string?,
	headers: { [string]: string }?,
}

--- A server-side WebSocket connection handle.
export type ServerWebSocket = {
	send: (self: ServerWebSocket, data: string | buffer) -> number,
	close: (self: ServerWebSocket, code: number?, message: string?) -> (),
}

--- Event handlers for server-side WebSocket connections.
export type WebSocketHandlers = {
	open: ((ws: ServerWebSocket) -> ())?,
	message: ((ws: ServerWebSocket, message: string | buffer) -> ())?,
	close: ((ws: ServerWebSocket, code: number, message: string) -> ())?,
	drain: ((ws: ServerWebSocket) -> ())?,
}

--- A running HTTP server handle, with hostname, port, and lifecycle methods.
export type Server = {
	hostname: string,
	port: number,
	close: () -> (),
	upgrade: (self: Server, req: ReceivedRequest) -> boolean,
}

--- A request handler function: receives a `ReceivedRequest` and `Server`, and returns a `ServerResponse`.
export type Handler = (request: ReceivedRequest, server: Server) -> ServerResponse?

--- Configuration for starting an HTTP server.
export type Configuration = {
	hostname: string?,
	port: number?,
	reuseport: boolean?,
	tls: { certfilename: string, keyfilename: string, passphrase: string?, cafilename: string? }?,
	handler: Handler?,
	websocket: WebSocketHandlers?,
}

--- Starts an HTTP server with the given handler or full configuration. Returns a `Server` handle.
function server.serve(config: Handler | Configuration): Server
	error("not implemented")
end

return server
]==],["std/test/reporter.luau"] = [==[--!strict
-- @std/test/reporter
-- Standard test reporter library for Luau

local types = require("./types")

type FailedTest = types.FailedTest
type TestRunResult = types.TestRunResult

local reporter = {}

local function printFailedTest(failed: FailedTest)
	print(`❌ {failed.test}`)
	if failed.failure.__tag == "assertion" then
		print(`\t{failed.failure.filename}:{failed.failure.linenumber}`)
		print(`\t\t{failed.failure.assertion}: {failed.failure.msg}`)
	elseif failed.failure.__tag == "lifecycle" then
		print(`\t{failed.failure.filename}:{failed.failure.linenumber}`)
		print(`\t\t{failed.failure.hook}: {failed.failure.msg}`)
	else
		print(`\tRuntime error: {failed.failure.msg}`)
		print(`Stacktrace:`)
		print(failed.failure.stacktrace)
	end
	print()
end

--- Prints a simple human-readable summary of `result` to stdout, listing any failures and the pass/fail counts.
function reporter.simple(result: TestRunResult)
	print("\n" .. string.rep("=", 50))
	print("TEST RESULTS")
	print(string.rep("=", 50))

	if #result.failures > 0 then
		print(`\nFailed Tests ({#result.failures}):\n`)
		for _, failed in result.failures do
			printFailedTest(failed)
		end
	end

	print(string.rep("-", 50))
	print(`Total:  {result.total}`)
	print(`Passed: {result.passed} ✓`)
	print(`Failed: {result.failed} ✗`)
	print(string.rep("=", 50) .. "\n")
end

return table.freeze(reporter)
]==],["std/system/init.luau"] = [==[--!strict
-- @std/system
-- stdlib for `@lute/system`
-- Provides re-exports of `@lute/system` and boolean properties for OS detection

local system = require("@lute/system")
local path = require("@std/path")
local platform = require("@self/platform")

local systemlib = {}

--- Returns the path of the system's temporary directory.
function systemlib.tmpdir(): path.Path
	return path.parse(system.tmpdir())
end

-- re-exports
systemlib.os = system.os
systemlib.arch = system.arch

systemlib.threadCount = system.threadCount
systemlib.hostName = system.hostName
systemlib.totalMemory = system.totalMemory
systemlib.freeMemory = system.freeMemory
systemlib.uptime = system.uptime
systemlib.cpus = system.cpus

-- boolean properties
systemlib.win32 = platform.win32
systemlib.linux = platform.linux
systemlib.macos = platform.macos
systemlib.unix = platform.unix

return table.freeze(systemlib)
]==],["std/syntax/utils/init.luau"] = [==[local types = require("./types")

local utils = {}

--- Returns `n` narrowed to `AstLocal` if it is a local variable node, or `nil` otherwise.
function utils.isLocal(n: types.AstNode): types.AstLocal?
	return if n.kind == "local" then n else nil
end

--- Returns `n` narrowed to `AstExprGroup` if it is a parenthesized expression, or `nil` otherwise.
function utils.isExprGroup(n: types.AstNode): types.AstExprGroup?
	return if n.kind == "expr" and n.tag == "group" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantNil` if it is a nil literal expression, or `nil` otherwise.
function utils.isExprConstantNil(n: types.AstNode): types.AstExprConstantNil?
	return if n.kind == "expr" and n.tag == "nil" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantBool` if it is a boolean literal expression, or `nil` otherwise.
function utils.isExprConstantBool(n: types.AstNode): types.AstExprConstantBool?
	return if n.kind == "expr" and n.tag == "boolean" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantNumber` if it is a number literal expression, or `nil` otherwise.
function utils.isExprConstantNumber(n: types.AstNode): types.AstExprConstantNumber?
	return if n.kind == "expr" and n.tag == "number" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantString` if it is a string literal expression, or `nil` otherwise.
function utils.isExprConstantString(n: types.AstNode): types.AstExprConstantString?
	return if n.kind == "expr" and n.tag == "string" then n else nil
end

--- Returns `n` narrowed to `AstExprLocal` if it is a local variable reference expression, or `nil` otherwise.
function utils.isExprLocal(n: types.AstNode): types.AstExprLocal?
	return if n.kind == "expr" and n.tag == "local" then n else nil
end

--- Returns `n` narrowed to `AstExprGlobal` if it is a global variable reference expression, or `nil` otherwise.
function utils.isExprGlobal(n: types.AstNode): types.AstExprGlobal?
	return if n.kind == "expr" and n.tag == "global" then n else nil
end

--- Returns `n` narrowed to `AstExprVarargs` if it is a varargs expression (`...`), or `nil` otherwise.
function utils.isExprVarargs(n: types.AstNode): types.AstExprVarargs?
	return if n.kind == "expr" and n.tag == "vararg" then n else nil
end

--- Returns `n` narrowed to `AstExprCall` if it is a call expression, or `nil` otherwise.
function utils.isExprCall(n: types.AstNode): types.AstExprCall?
	return if n.kind == "expr" and n.tag == "call" then n else nil
end

--- Returns `n` as an `AstExprCall` if it is a `require(...)` call expression, or `nil` otherwise.
function utils.isRequireCall(n: types.AstNode): types.AstExprCall?
	local call = utils.isExprCall(n)
	local global = call and utils.isExprGlobal(call.func)
	return if global and global.name.text == "require" then call else nil
end

--- Returns `n` narrowed to `AstExprIndexName` if it is a field access expression (e.g. `a.b`), or `nil` otherwise.
function utils.isExprIndexName(n: types.AstNode): types.AstExprIndexName?
	return if n.kind == "expr" and n.tag == "indexname" then n else nil
end

--- Returns `n` narrowed to `AstExprIndexExpr` if it is an index expression (e.g. `a[b]`), or `nil` otherwise.
function utils.isExprIndexExpr(n: types.AstNode): types.AstExprIndexExpr?
	return if n.kind == "expr" and n.tag == "index" then n else nil
end

--- Returns `n` narrowed to `AstExprFunction` if it is a function expression, or `nil` otherwise.
function utils.isExprFunction(n: types.AstNode): types.AstExprFunction?
	return if n.kind == "expr" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `AstExprTable` if it is a table constructor expression, or `nil` otherwise.
function utils.isExprTable(n: types.AstNode): types.AstExprTable?
	return if n.kind == "expr" and n.tag == "table" then n else nil
end

--- Returns `n` narrowed to `AstTableExprItem` if it is a table constructor item, or `nil` otherwise.
function utils.isTableExprItem(n: types.AstNode | types.AstTableExprItem): types.AstTableExprItem?
	return if (n :: types.AstTableExprItem).isTableItem then n :: types.AstTableExprItem else nil
end

--- Returns `n` narrowed to `AstExprUnary` if it is a unary expression, or `nil` otherwise.
function utils.isExprUnary(n: types.AstNode): types.AstExprUnary?
	return if n.kind == "expr" and n.tag == "unary" then n else nil
end

--- Returns `n` narrowed to `AstExprBinary` if it is a binary expression, or `nil` otherwise.
function utils.isExprBinary(n: types.AstNode): types.AstExprBinary?
	return if n.kind == "expr" and n.tag == "binary" then n else nil
end

--- Returns `n` narrowed to `AstExprInterpString` if it is an interpolated string expression, or `nil` otherwise.
function utils.isExprInterpString(n: types.AstNode): types.AstExprInterpString?
	return if n.kind == "expr" and n.tag == "interpolatedstring" then n else nil
end

--- Returns `n` narrowed to `AstExprTypeAssertion` if it is a type assertion expression (`expr :: Type`), or `nil` otherwise.
function utils.isExprTypeAssertion(n: types.AstNode): types.AstExprTypeAssertion?
	return if n.kind == "expr" and n.tag == "cast" then n else nil
end

--- Returns `n` narrowed to `AstExprIfElse` if it is an `if-then-else` expression, or `nil` otherwise.
function utils.isExprIfElse(n: types.AstNode): types.AstExprIfElse?
	return if n.kind == "expr" and n.tag == "conditional" then n else nil
end

--- Returns `n` narrowed to `AstExpr` if it is any expression node, or `nil` otherwise.
function utils.isExpr(n: types.AstNode): types.AstExpr?
	return if n.kind == "expr" then n else nil
end

--- Returns `n` narrowed to `AstStatBlock` if it is a block statement (do...end), or `nil` otherwise.
function utils.isStatBlock(n: types.AstNode): types.AstStatBlock?
	return if n.kind == "stat" and n.tag == "block" then n else nil
end

--- Returns `n` narrowed to `AstStatIf` if it is an if statement, or `nil` otherwise.
function utils.isStatIf(n: types.AstNode): types.AstStatIf?
	return if n.kind == "stat" and n.tag == "conditional" then n else nil
end

--- Returns `n` narrowed to `AstStatWhile` if it is a while statement, or `nil` otherwise.
function utils.isStatWhile(n: types.AstNode): types.AstStatWhile?
	return if n.kind == "stat" and n.tag == "while" then n else nil
end

--- Returns `n` narrowed to `AstStatRepeat` if it is a repeat-until statement, or `nil` otherwise.
function utils.isStatRepeat(n: types.AstNode): types.AstStatRepeat?
	return if n.kind == "stat" and n.tag == "repeat" then n else nil
end

--- Returns `n` narrowed to `AstStatBreak` if it is a break statement, or `nil` otherwise.
function utils.isStatBreak(n: types.AstNode): types.AstStatBreak?
	return if n.kind == "stat" and n.tag == "break" then n else nil
end

--- Returns `n` narrowed to `AstStatContinue` if it is a continue statement, or `nil` otherwise.
function utils.isStatContinue(n: types.AstNode): types.AstStatContinue?
	return if n.kind == "stat" and n.tag == "continue" then n else nil
end

--- Returns `n` narrowed to `AstStatReturn` if it is a return statement, or `nil` otherwise.
function utils.isStatReturn(n: types.AstNode): types.AstStatReturn?
	return if n.kind == "stat" and n.tag == "return" then n else nil
end

--- Returns `n` narrowed to `AstStatExpr` if it is an expression statement, or `nil` otherwise.
function utils.isStatExpr(n: types.AstNode): types.AstStatExpr?
	return if n.kind == "stat" and n.tag == "expression" then n else nil
end

--- Returns `n` narrowed to `AstStatLocal` if it is a local variable declaration, or `nil` otherwise.
function utils.isStatLocal(n: types.AstNode): types.AstStatLocal?
	return if n.kind == "stat" and n.tag == "local" then n else nil
end

--- Returns `n` narrowed to `AstStatFor` if it is a numeric for statement, or `nil` otherwise.
function utils.isStatFor(n: types.AstNode): types.AstStatFor?
	return if n.kind == "stat" and n.tag == "for" then n else nil
end

--- Returns `n` narrowed to `AstStatForIn` if it is a generic for-in statement, or `nil` otherwise.
function utils.isStatForIn(n: types.AstNode): types.AstStatForIn?
	return if n.kind == "stat" and n.tag == "forin" then n else nil
end

--- Returns `n` narrowed to `AstStatAssign` if it is an assignment statement, or `nil` otherwise.
function utils.isStatAssign(n: types.AstNode): types.AstStatAssign?
	return if n.kind == "stat" and n.tag == "assign" then n else nil
end

--- Returns `n` narrowed to `AstStatCompoundAssign` if it is a compound assignment statement (e.g. `+=`), or `nil` otherwise.
function utils.isStatCompoundAssign(n: types.AstNode): types.AstStatCompoundAssign?
	return if n.kind == "stat" and n.tag == "compoundassign" then n else nil
end

--- Returns `n` narrowed to `AstStatFunction` if it is a function declaration statement, or `nil` otherwise.
function utils.isStatFunction(n: types.AstNode): types.AstStatFunction?
	return if n.kind == "stat" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `AstStatLocalFunction` if it is a local function declaration, or `nil` otherwise.
function utils.isStatLocalFunction(n: types.AstNode): types.AstStatLocalFunction?
	return if n.kind == "stat" and n.tag == "localfunction" then n else nil
end

--- Returns `n` narrowed to `AstStatTypeAlias` if it is a type alias declaration, or `nil` otherwise.
function utils.isStatTypeAlias(n: types.AstNode): types.AstStatTypeAlias?
	return if n.kind == "stat" and n.tag == "typealias" then n else nil
end

--- Returns `n` narrowed to `AstStatTypeFunction` if it is a type function declaration, or `nil` otherwise.
function utils.isStatTypeFunction(n: types.AstNode): types.AstStatTypeFunction?
	return if n.kind == "stat" and n.tag == "typefunction" then n else nil
end

--- Returns `n` narrowed to `AstStat` if it is any statement node, or `nil` otherwise.
function utils.isStat(n: types.AstNode): types.AstStat?
	return if n.kind == "stat" then n else nil
end

--- Returns `n` narrowed to `AstGenericType` if it is a generic type parameter, or `nil` otherwise.
function utils.isGenericType(n: types.AstNode): types.AstGenericType?
	return if n.kind == "type" and n.tag == "generic" then n else nil
end

--- Returns `n` narrowed to `AstGenericTypePack` if it is a generic type pack parameter, or `nil` otherwise.
function utils.isGenericTypePack(n: types.AstNode): types.AstGenericTypePack?
	return if n.kind == "typepack" and n.tag == "genericpack" then n else nil
end

--- Returns `n` narrowed to `AstTypeReference` if it is a type reference, or `nil` otherwise.
function utils.isTypeReference(n: types.AstNode): types.AstTypeReference?
	return if n.kind == "type" and n.tag == "reference" then n else nil
end

--- Returns `n` narrowed to `AstTypeSingletonBool` if it is a boolean singleton type, or `nil` otherwise.
function utils.isTypeSingletonBool(n: types.AstNode): types.AstTypeSingletonBool?
	return if n.kind == "type" and n.tag == "boolean" then n else nil
end

--- Returns `n` narrowed to `AstTypeSingletonString` if it is a string singleton type, or `nil` otherwise.
function utils.isTypeSingletonString(n: types.AstNode): types.AstTypeSingletonString?
	return if n.kind == "type" and n.tag == "string" then n else nil
end

--- Returns `n` narrowed to `AstTypeTypeof` if it is a `typeof(...)` type, or `nil` otherwise.
function utils.isTypeTypeof(n: types.AstNode): types.AstTypeTypeof?
	return if n.kind == "type" and n.tag == "typeof" then n else nil
end

--- Returns `n` narrowed to `AstTypeGroup` if it is a parenthesized type, or `nil` otherwise.
function utils.isTypeGroup(n: types.AstNode): types.AstTypeGroup?
	return if n.kind == "type" and n.tag == "group" then n else nil
end

--- Returns `n` narrowed to `AstTypeOptional` if it is an optional type (`T?`), or `nil` otherwise.
function utils.isTypeOptional(n: types.AstNode): types.AstTypeOptional?
	return if n.kind == "type" and n.tag == "optional" then n else nil
end

--- Returns `n` narrowed to `AstTypeUnion` if it is a type union, or `nil` otherwise.
function utils.isTypeUnion(n: types.AstNode): types.AstTypeUnion?
	return if n.kind == "type" and n.tag == "union" then n else nil
end

--- Returns `n` narrowed to `AstTypeIntersection` if it is a type intersection, or `nil` otherwise.
function utils.isTypeIntersection(n: types.AstNode): types.AstTypeIntersection?
	return if n.kind == "type" and n.tag == "intersection" then n else nil
end

--- Returns `n` narrowed to `AstTypeArray` if it is an array type (`{T}`), or `nil` otherwise.
function utils.isTypeArray(n: types.AstNode): types.AstTypeArray?
	return if n.kind == "type" and n.tag == "array" then n else nil
end

--- Returns `n` narrowed to `AstTypeTable` if it is a table type, or `nil` otherwise.
function utils.isTypeTable(n: types.AstNode): types.AstTypeTable?
	return if n.kind == "type" and n.tag == "table" then n else nil
end

--- Returns `n` narrowed to `AstTypeFunction` if it is a function type, or `nil` otherwise.
function utils.isTypeFunction(n: types.AstNode): types.AstTypeFunction?
	return if n.kind == "type" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `AstType` if it is any type annotation node, or `nil` otherwise.
function utils.isType(n: types.AstNode): types.AstType?
	return if n.kind == "type" then n else nil
end

--- Returns `n` narrowed to `AstTypePackExplicit` if it is an explicit type pack, or `nil` otherwise.
function utils.isTypePackExplicit(n: types.AstNode): types.AstTypePackExplicit?
	return if n.kind == "typepack" and n.tag == "explicit" then n else nil
end

--- Returns `n` narrowed to `AstTypePackVariadic` if it is a variadic type pack, or `nil` otherwise.
function utils.isTypePackVariadic(n: types.AstNode): types.AstTypePackVariadic?
	return if n.kind == "typepack" and n.tag == "variadic" then n else nil
end

--- Returns `n` narrowed to `AstTypePackGeneric` if it is a generic type pack, or `nil` otherwise.
function utils.isTypePackGeneric(n: types.AstNode): types.AstTypePackGeneric?
	return if n.kind == "typepack" and n.tag == "generic" then n else nil
end

--- Returns `n` narrowed to `AstTypePack` if it is any type pack node, or `nil` otherwise.
function utils.isTypePack(n: types.AstNode): types.AstTypePack?
	return if n.kind == "typepack" then n else nil
end

--- Returns `n` narrowed to `Token` if it is a token, or `nil` otherwise.
function utils.isToken(n: types.AstNode): types.Token?
	return if n.kind == "token" then n else nil
end

--- Returns `n` narrowed to `AstAttribute` if it is an attribute node, or `nil` otherwise.
function utils.isAttribute(n: types.AstNode): types.AstAttribute?
	return if n.kind == "attribute" then n else nil
end

return table.freeze(utils)
]==],["std/path/win32/types.luau"] = [==[local pathinterface = require("../pathinterface")

--- Describes how a Windows path is rooted:
--- - `"absolute"`: Drive-rooted path, e.g. `C:\foo`.
--- - `"unc"`: UNC path, e.g. `\\server\share`.
--- - `"relative"`: A path with no drive or UNC root.
export type PathKind = "unc" | "absolute" | "relative"

--- The raw data of a Windows path: an array of components, the path kind, and an optional drive letter.
export type PathData = {
	parts: { string },
	kind: PathKind,
	drive: string?,
}

--- A structured Windows path.
export type Path = setmetatable<PathData, pathinterface.PathInterface>

--- Anything that can be used as a Windows path: a string, a `Path`, or raw `PathData`.
export type Pathlike = string | PathData | Path

return {}
]==],["std/syntax/parser.luau"] = [==[--!strict
-- @std/syntax/parser
-- Parser for Luau source code into Luau AST nodes

local luau = require("@lute/luau")
local types = require("./types")

local parser = {}

--- Parses Luau source code into an AstStatBlock
function parser.parseBlock(source: string): types.AstStatBlock
	return luau.parse(source).root
end

--- Parses `source` as a single Luau expression and returns the resulting `AstExpr`.
function parser.parseExpr(source: string): types.AstExpr
	return luau.parseExpr(source)
end

--- Parses `source` as a complete Luau file and returns the full `ParseResult`, including the root block and EOF token.
function parser.parse(source: string): types.ParseResult
	return luau.parse(source)
end

return table.freeze(parser)
]==],["lute/net/init.luau"] = [==[local client = require("@self/client")
local server = require("@self/server")

local net = {}

--- HTTP request metadata, including optional method, body, and headers.
export type Metadata = client.Metadata
--- An HTTP response, containing status code, headers, body, and a success flag.
export type Response = client.Response
--- Options for establishing a WebSocket connection, including optional event handlers.
export type WebSocketOptions = client.WebSocketOptions
--- A client-side WebSocket connection handle.
export type WebSocket = client.WebSocket
--- An HTTP request received by the server, containing method, path, body, query params, and headers.
export type ReceivedRequest = server.ReceivedRequest
--- A response that can be returned from a server handler: a plain string body, or a table with status, body, and headers.
export type ServerResponse = server.ServerResponse
--- A request handler function: receives a `ReceivedRequest` and `Server`, and returns a `ServerResponse`.
export type Handler = server.Handler
--- Configuration for starting an HTTP server.
export type Configuration = server.Configuration
--- A running HTTP server handle, with hostname, port, and lifecycle methods.
export type Server = server.Server
--- A server-side WebSocket connection handle.
export type ServerWebSocket = server.ServerWebSocket
--- Event handlers for server-side WebSocket connections.
export type WebSocketHandlers = server.WebSocketHandlers

net.client = client
net.server = server

return net
]==],["std/time/init.luau"] = [==[--!strict
-- @std/time
-- Provides utility functions for time

local luteTime = require("@lute/time")
local duration = require("@self/duration")

local time = {}

--- A span of time.
export type Duration = duration.Duration
--- An opaque point in time, used with `time.since` to measure elapsed time.
export type Instant = luteTime.Instant

time.duration = duration

--- Returns the current point in time as an `Instant`.
function time.now(): Instant
	return luteTime.now()
end

--- Returns the number of seconds elapsed since `instant`.
function time.since(instant: Instant): number
	return luteTime.since(instant)
end

return table.freeze(time)
]==],["std/time/duration.luau"] = [==[--!strict
-- Submodule of @std/time that provides utility functions for time durations

local time = require("@lute/time")

--- A span of time.
export type Duration = time.Duration

local duration = {}

--- Creates a `Duration` from a number of `seconds` and an additional number of nanoseconds, `subsecnanos`.
function duration.create(seconds: number, subsecnanos: number): Duration
	return time.duration.create(seconds, subsecnanos)
end

--- Creates a `Duration` from a number of nanoseconds.
function duration.nanoseconds(nanoseconds: number): Duration
	return time.duration.nanoseconds(nanoseconds)
end

--- Creates a `Duration` from a number of microseconds.
function duration.microseconds(microseconds: number): Duration
	return time.duration.microseconds(microseconds)
end

--- Creates a `Duration` from a number of milliseconds.
function duration.milliseconds(milliseconds: number): Duration
	return time.duration.milliseconds(milliseconds)
end

--- Creates a `Duration` from a number of seconds.
function duration.seconds(seconds: number): Duration
	return time.duration.seconds(seconds)
end

--- Creates a `Duration` from a number of minutes.
function duration.minutes(minutes: number): Duration
	return time.duration.minutes(minutes)
end

--- Creates a `Duration` from a number of hours.
function duration.hours(hours: number): Duration
	return time.duration.hours(hours)
end

--- Creates a `Duration` from a number of days.
function duration.days(days: number): Duration
	return time.duration.days(days)
end

--- Creates a `Duration` from a number of weeks.
function duration.weeks(weeks: number): Duration
	return time.duration.weeks(weeks)
end

return table.freeze(duration)
]==],["std/task.luau"] = [==[--!strict
-- @std/task
-- stdlib for `@lute/task`
-- Provides utilities for creating and managing asynchronous tasks

local lutetask = require("@lute/task")

local task = {}

--- Schedules `routine` to run immediately on the next resumption cycle, passing any additional arguments to it. Returns the thread.
function task.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.spawn(routine, ...)
end

--- Schedules `routine` to run after the current thread yields, passing any additional arguments to it. Returns the thread.
function task.defer<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.defer(routine, ...)
end

--- Schedules `routine` to run after `dur` seconds, passing any additional arguments to it. Returns the thread.
function task.delay<T..., U...>(dur: number, routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.delay(dur, routine, ...)
end

--- Yields the current thread for `dur` seconds (or until the next cycle if `dur` is omitted). Returns the actual time waited.
function task.wait(dur: number?): number
	return lutetask.wait(dur)
end

--- Cancels `thread`, preventing it from being resumed again.
function task.cancel(thread: thread)
	coroutine.close(thread)
end

return table.freeze(task)
]==],["std/path/pathinterface.luau"] = [==[export type PathInterface = {
	__tostring: (self: PathInterface) -> string,
}

return table.freeze({})
]==],["std/syntax/types.luau"] = [==[local luau = require("@lute/luau")

export type Span = luau.Span

export type Whitespace = luau.Whitespace
export type SingleLineComment = luau.SingleLineComment
export type MultiLineComment = luau.MultiLineComment

export type Trivia = luau.Trivia

export type Token<Kind = string> = luau.Token<Kind>

export type Eof = luau.Eof

export type Pair<T, Separator> = luau.Pair<T, Separator>
export type Punctuated<T, Separator = ","> = luau.Punctuated<T, Separator>

export type AstLocal = luau.AstLocal

export type AstExprGroup = luau.AstExprGroup

export type AstExprConstantNil = luau.AstExprConstantNil

export type AstExprConstantBool = luau.AstExprConstantBool

export type AstExprConstantNumber = luau.AstExprConstantNumber

export type AstExprConstantString = luau.AstExprConstantString

export type AstExprLocal = luau.AstExprLocal

export type AstExprGlobal = luau.AstExprGlobal

export type AstExprVarargs = luau.AstExprVarargs

export type AstExprCall = luau.AstExprCall

export type AstExprInstantiate = luau.AstExprInstantiate

export type AstExprIndexName = luau.AstExprIndexName

export type AstExprIndexExpr = luau.AstExprIndexExpr

export type AstExprFunction = luau.AstExprFunction

export type AstTableExprListItem = luau.AstTableExprListItem

export type AstTableExprRecordItem = luau.AstTableExprRecordItem

export type AstTableExprGeneralItem = luau.AstTableExprGeneralItem

export type AstTableExprItem = luau.AstTableExprItem

export type AstExprTable = luau.AstExprTable

export type AstExprUnary = luau.AstExprUnary

export type AstExprBinary = luau.AstExprBinary

export type AstExprInterpString = luau.AstExprInterpString

export type AstExprTypeAssertion = luau.AstExprTypeAssertion

export type AstElseIfExpr = luau.AstElseIfExpr

export type AstExprIfElse = luau.AstExprIfElse

export type AstExpr = luau.AstExpr

export type AstStatBlock = luau.AstStatBlock

export type AstStatDo = luau.AstStatDo

export type AstElseIfStat = luau.AstElseIfStat

export type AstStatIf = luau.AstStatIf

export type AstStatWhile = luau.AstStatWhile

export type AstStatRepeat = luau.AstStatRepeat

export type AstStatBreak = luau.AstStatBreak

export type AstStatContinue = luau.AstStatContinue

export type AstStatReturn = luau.AstStatReturn

export type AstStatExpr = luau.AstStatExpr

export type AstStatLocal = luau.AstStatLocal

export type AstStatFor = luau.AstStatFor

export type AstStatForIn = luau.AstStatForIn

export type AstStatAssign = luau.AstStatAssign

export type AstStatCompoundAssign = luau.AstStatCompoundAssign

export type AstAttribute = luau.AstAttribute

export type AstStatFunction = luau.AstStatFunction

export type AstStatLocalFunction = luau.AstStatLocalFunction

export type AstStatTypeAlias = luau.AstStatTypeAlias

export type AstStatTypeFunction = luau.AstStatTypeFunction

export type AstStat = luau.AstStat

export type AstGenericType = luau.AstGenericType

export type AstGenericTypePack = luau.AstGenericTypePack

export type AstTypeReference = luau.AstTypeReference

export type AstTypeSingletonBool = luau.AstTypeSingletonBool

export type AstTypeSingletonString = luau.AstTypeSingletonString

export type AstTypeTypeof = luau.AstTypeTypeof

export type AstTypeGroup = luau.AstTypeGroup

export type AstTypeOptional = luau.AstTypeOptional

export type AstTypeUnion = luau.AstTypeUnion

export type AstTypeIntersection = luau.AstTypeIntersection

export type AstTypeArray = luau.AstTypeArray

export type AstTableTypeItemIndexer = luau.AstTableTypeItemIndexer

export type AstTableTypeItemStringProperty = luau.AstTableTypeItemStringProperty

export type AstTableTypeItemProperty = luau.AstTableTypeItemProperty

export type AstTableTypeItem = luau.AstTableTypeItem

export type AstTypeTable = luau.AstTypeTable

export type AstFunctionTypeParameter = luau.AstFunctionTypeParameter

export type AstTypeFunction = luau.AstTypeFunction

export type AstType = luau.AstType

export type AstTypePackExplicit = luau.AstTypePackExplicit

export type AstTypePackGeneric = luau.AstTypePackGeneric

export type AstTypePackVariadic = luau.AstTypePackVariadic

export type AstTypePack = luau.AstTypePack

export type AstNode = luau.AstNode

export type ParseResult = luau.ParseResult

export type Replacements = { [AstNode]: string }

export type Type = luau.Type

export type TypePack = luau.TypePack

return {}
]==],["std/.luaurc"] = [==[{
    "languageMode": "strict",
    "aliases": {
        "batteries": "../../../batteries"
    }
}
]==],["std/syntax/init.luau"] = [==[local parser = require("@self/parser")
local types = require("@self/types")

local luau = require("@lute/luau")

export type Span = types.Span

local span = {
	--- Creates a `Span` from begin/end line and column values.
	create = luau.span.create,
}

--- Returns `true` if `haystack` fully contains `needle`.
function span.subsumes(haystack: Span, needle: Span): boolean
	return (
		if haystack.beginLine == needle.beginLine
			then haystack.beginColumn <= needle.beginColumn
			else haystack.beginLine < needle.beginLine
	)
		and (
			if haystack.endLine == needle.endLine
				then haystack.endColumn >= needle.endColumn
				else haystack.endLine > needle.endLine
		)
end

export type Whitespace = types.Whitespace
export type SingleLineComment = types.SingleLineComment
export type MultiLineComment = types.MultiLineComment

export type Trivia = types.Trivia

export type Token<Kind = string> = types.Token<Kind>

export type Eof = types.Eof

export type Pair<T, Separator> = types.Pair<T, Separator>
export type Punctuated<T, Separator = ","> = types.Punctuated<T, Separator>

export type AstLocal = types.AstLocal

export type AstExprGroup = types.AstExprGroup

export type AstExprConstantNil = types.AstExprConstantNil

export type AstExprConstantBool = types.AstExprConstantBool

export type AstExprConstantNumber = types.AstExprConstantNumber

export type AstExprConstantString = types.AstExprConstantString

export type AstExprLocal = types.AstExprLocal

export type AstExprGlobal = types.AstExprGlobal

export type AstExprVarargs = types.AstExprVarargs

export type AstExprCall = types.AstExprCall

export type AstExprInstantiate = types.AstExprInstantiate

export type AstExprIndexName = types.AstExprIndexName

export type AstExprIndexExpr = types.AstExprIndexExpr

export type AstExprFunction = types.AstExprFunction

export type AstTableExprListItem = types.AstTableExprListItem

export type AstTableExprRecordItem = types.AstTableExprRecordItem

export type AstTableExprGeneralItem = types.AstTableExprGeneralItem

export type AstTableExprItem = types.AstTableExprItem

export type AstExprTable = types.AstExprTable

export type AstExprUnary = types.AstExprUnary

export type AstExprBinary = types.AstExprBinary

export type AstExprInterpString = types.AstExprInterpString

export type AstExprTypeAssertion = types.AstExprTypeAssertion

export type AstElseIfExpr = types.AstElseIfExpr

export type AstExprIfElse = types.AstExprIfElse

export type AstExpr = types.AstExpr

export type AstStatBlock = types.AstStatBlock

export type AstStatDo = types.AstStatDo

export type AstElseIfStat = types.AstElseIfStat

export type AstStatIf = types.AstStatIf

export type AstStatWhile = types.AstStatWhile

export type AstStatRepeat = types.AstStatRepeat

export type AstStatBreak = types.AstStatBreak

export type AstStatContinue = types.AstStatContinue

export type AstStatReturn = types.AstStatReturn

export type AstStatExpr = types.AstStatExpr

export type AstStatLocal = types.AstStatLocal

export type AstStatFor = types.AstStatFor

export type AstStatForIn = types.AstStatForIn

export type AstStatAssign = types.AstStatAssign

export type AstStatCompoundAssign = types.AstStatCompoundAssign

export type AstAttribute = types.AstAttribute

export type AstStatFunction = types.AstStatFunction

export type AstStatLocalFunction = types.AstStatLocalFunction

export type AstStatTypeAlias = types.AstStatTypeAlias

export type AstStatTypeFunction = types.AstStatTypeFunction

export type AstStat = types.AstStat

export type AstGenericType = types.AstGenericType

export type AstGenericTypePack = types.AstGenericTypePack

export type AstTypeReference = types.AstTypeReference

export type AstTypeSingletonBool = types.AstTypeSingletonBool

export type AstTypeSingletonString = types.AstTypeSingletonString

export type AstTypeTypeof = types.AstTypeTypeof

export type AstTypeGroup = types.AstTypeGroup

export type AstTypeOptional = types.AstTypeOptional

export type AstTypeUnion = types.AstTypeUnion

export type AstTypeIntersection = types.AstTypeIntersection

export type AstTypeArray = types.AstTypeArray

export type AstTableTypeItemIndexer = types.AstTableTypeItemIndexer

export type AstTableTypeItemStringProperty = types.AstTableTypeItemStringProperty

export type AstTableTypeItemProperty = types.AstTableTypeItemProperty

export type AstTableTypeItem = types.AstTableTypeItem

export type AstTypeTable = types.AstTypeTable

export type AstFunctionTypeParameter = types.AstFunctionTypeParameter

export type AstTypeFunction = types.AstTypeFunction

export type AstType = types.AstType

export type AstTypePackExplicit = types.AstTypePackExplicit

export type AstTypePackGeneric = types.AstTypePackGeneric

export type AstTypePackVariadic = types.AstTypePackVariadic

export type AstTypePack = types.AstTypePack

export type AstNode = types.AstNode

export type ParseResult = types.ParseResult

return table.freeze({
	parseBlock = parser.parseBlock,
	parseExpr = parser.parseExpr,
	parse = parser.parse,
	span = table.freeze(span),
})
]==],["std/json.luau"] = [==[--!strict
-- @std/json
-- JSON serialization and deserialization library

local json = {
	--- A sentinel value representing JSON `null`. Not actually `nil` — use this when you need to serialize a null field.
	null = newproxy() :: nil,
}

--- A JSON object: a table with string keys.
export type Object = { [string]: Value }
--- A JSON array: a table with integer keys.
export type Array = { [number]: Value }
--- Any JSON value: `null`, a number, string, boolean, array, or object.
export type Value = nil | number | string | boolean | Array | Object

-- a unique key to identify an object vs a table
local object_key = newproxy()

-- serialization

local bufferSize = 1024

type SerializerState = {
	buf: buffer,
	cursor: number,
	prettyPrint: boolean,
	depth: number,
}

local function checkState(state: SerializerState, len: number): ()
	local curLen = buffer.len(state.buf)

	if state.cursor + len < curLen then
		return
	end

	local newBuffer = buffer.create(curLen * 2)

	buffer.copy(newBuffer, 0, state.buf)

	state.buf = newBuffer
end

local function writeByte(state: SerializerState, byte: number): ()
	checkState(state, 1)

	buffer.writeu8(state.buf, state.cursor, byte)

	state.cursor += 1
end

local function writeSpaces(state: SerializerState): ()
	if state.depth == 0 then
		return
	end

	if state.prettyPrint then
		checkState(state, state.depth * 4)

		for _ = 1, state.depth do
			buffer.writeu32(state.buf, state.cursor, 0x_20_20_20_20)
			state.cursor += 4
		end
	else
		buffer.writeu8(state.buf, state.cursor, (string.byte(" ")))

		state.cursor += 1
	end
end

local function writeString(state: SerializerState, str: string): ()
	checkState(state, #str)

	buffer.writestring(state.buf, state.cursor, str)

	state.cursor += #str
end

local serializeAny: (SerializerState, (Array | Object | boolean | number | string)?) -> ()

local ESCAPE_MAP = {
	[0x5C] = string.byte("\\"), -- 5C = '\'
	[0x08] = string.byte("b"),
	[0x0C] = string.byte("f"),
	[0x0A] = string.byte("n"),
	[0x0D] = string.byte("r"),
	[0x09] = string.byte("t"),
	[0x22] = string.byte('"'),
}

local function serializeUnicode(codepoint: number): string
	if codepoint >= 0x10000 then
		local high = math.floor((codepoint - 0x10000) / 0x400) + 0xD800
		local low = ((codepoint - 0x10000) % 0x400) + 0xDC00
		return string.format("\\u%04x\\u%04x", high, low)
	end

	return string.format("\\u%04x", codepoint)
end

local function serializeString(state: SerializerState, str: string): ()
	checkState(state, #str)

	writeByte(state, string.byte('"'))

	for _, codepoint in utf8.codes(str) do
		if ESCAPE_MAP[codepoint] then
			writeByte(state, string.byte("\\"))
			writeByte(state, ESCAPE_MAP[codepoint])
		elseif codepoint < 32 or codepoint > 126 then
			writeString(state, serializeUnicode(codepoint))
		else
			writeString(state, utf8.char(codepoint))
		end
	end

	writeByte(state, string.byte('"'))
end

local function serializeArray(state: SerializerState, array: Array): ()
	state.depth += 1

	writeByte(state, string.byte("["))

	if state.prettyPrint and #array ~= 0 then
		writeByte(state, string.byte("\n"))
	end

	for i, value in array do
		if i ~= 1 then
			writeByte(state, string.byte(","))

			if state.prettyPrint then
				writeByte(state, string.byte("\n"))
			end
		end

		if i ~= 1 or state.prettyPrint then
			writeSpaces(state)
		end

		serializeAny(state, value)
	end

	state.depth -= 1

	if state.prettyPrint and #array ~= 0 then
		writeByte(state, string.byte("\n"))
		writeSpaces(state)
	end

	writeByte(state, string.byte("]"))
end

local function serializeTable(state: SerializerState, object: Object): ()
	writeByte(state, string.byte("{"))

	if state.prettyPrint then
		writeByte(state, string.byte("\n"))
	end

	state.depth += 1

	local first = true
	for key, value in object do
		if key == object_key then
			continue
		end

		if not first then
			writeByte(state, string.byte(","))
			writeByte(state, string.byte(" "))

			if state.prettyPrint then
				writeByte(state, string.byte("\n"))
			end
		end

		first = false

		writeSpaces(state)

		serializeString(state, key)
		writeString(state, ": ")

		serializeAny(state, value)
	end

	if state.prettyPrint then
		writeByte(state, string.byte("\n"))
	end

	state.depth -= 1

	writeSpaces(state)

	writeByte(state, string.byte("}"))
end

serializeAny = function(state: SerializerState, value: Value): ()
	local valueType = type(value)

	if value == json.null then
		writeString(state, "null")
	elseif valueType == "boolean" then
		writeString(state, if value then "true" else "false")
	elseif valueType == "number" then
		writeString(state, tostring(value))
	elseif valueType == "string" then
		serializeString(state, value :: string)
	elseif valueType == "table" then
		if #(value :: {}) == 0 and next(value :: { [unknown]: unknown }) ~= nil then
			serializeTable(state, value :: Object)
		else
			serializeArray(state, value :: Array)
		end
	else
		error("Unknown value", 2)
	end
end

-- deserialization

type DeserializerState = {
	src: string,
	cursor: number,
}

local function deserializerError(state: DeserializerState, msg: string): never
	return error(`JSON error - {msg} around {state.cursor}`)
end

local function skipWhitespace(state: DeserializerState): boolean
	state.cursor = string.find(state.src, "[^ \n\r\t]", state.cursor) :: number

	if not state.cursor then
		return false
	end

	return true
end

local function currentByte(state: DeserializerState): number
	return (string.byte(state.src, state.cursor))
end

local function deserializeNumber(state: DeserializerState): number?
	-- Integer part
	local nStart, nEnd = string.find(state.src, "^-?[1-9]%d*", state.cursor)
	if not nStart then
		nStart, nEnd = string.find(state.src, "^-?0", state.cursor)
		if not nStart then
			deserializerError(state, "Malformed number (bad integer part)")
		end

		local nextChar = string.byte(state.src, nEnd :: number + 1)
		if nextChar and nextChar >= string.byte("0") and nextChar <= string.byte("9") then
			deserializerError(state, "Malformed number (leading zeros not allowed)")
		end
	end

	-- Decimal part
	local decStart, decEnd = string.find(state.src, "^%.%d+", nEnd :: number + 1)
	if decStart then
		nEnd = decEnd
	end

	-- Exponential part
	local expStart, expEnd = string.find(state.src, "^[eE][+-]?%d+", nEnd :: number + 1)
	if expStart then
		nEnd = expEnd
	end

	local num = tonumber(string.sub(state.src, nStart :: number, nEnd))
	if not num then
		deserializerError(state, "Malformed number value")
	end

	state.cursor = nEnd :: number + 1
	return num
end

local function decodeSurrogatePair(high, low): string?
	local highVal = tonumber(high, 16)
	local lowVal = tonumber(low, 16)
	if not highVal or not lowVal then
		return nil -- Invalid
	end
	-- Calculate the actual Unicode codepoint
	local codepoint = 0x10000 + ((highVal - 0xD800) * 0x400) + (lowVal - 0xDC00)
	return utf8.char(codepoint)
end

local function deserializeString(state: DeserializerState): string
	-- Must start with "
	if currentByte(state) ~= string.byte('"') then
		return deserializerError(state, "Expected string opening quote")
	end

	-- Skip opening quote "
	state.cursor += 1

	local startPos = state.cursor

	while state.cursor <= #state.src do
		local byte = currentByte(state)

		-- Check for unescaped control characters (0x00-0x1F)
		if byte < 0x20 then
			return deserializerError(state, "Unescaped control character in string")
		end

		if byte == string.byte('"') then
			state.cursor += 1
			local source = string.sub(state.src, startPos, state.cursor - 2)

			-- Validate escape sequences
			-- Remove valid \\ first
			local temp = string.gsub(source, "\\\\", "")

			-- Check for invalid single-char escapes
			if temp:match('\\[^bfnrt"\\/u]') then
				return deserializerError(state, "Invalid escape sequence")
			end

			-- Check that all \u escapes have exactly 4 hex digits
			if temp:match("\\u[^0-9a-fA-F]") or temp:match("\\u%x?%x?%x?$") then
				return deserializerError(state, "Incomplete or invalid \\u escape")
			end

			-- Handle all surrogate pairs
			source = string.gsub(
				source,
				"\\u([dD][89aAbB][0-9a-fA-F][0-9a-fA-F])\\u([dD][c-fC-F][0-9a-fA-F][0-9a-fA-F])",
				function(high, low)
					return decodeSurrogatePair(high, low) or deserializerError(state, "Invalid unicode surrogate pair")
				end :: any
			)

			-- Detect incomplete/invalid surrogates
			if source:match("\\u[dD][89aAbB][0-9a-fA-F][0-9a-fA-F]") then
				return deserializerError(state, "Incomplete surrogate pair")
			end

			-- Handle regular Unicode escapes
			source = string.gsub(source, "\\u(%x%x%x%x)", function(code)
				return utf8.char(tonumber(code, 16) :: number)
			end)

			source = string.gsub(source, "\\\\", "\0")
			source = string.gsub(source, "\\b", "\b")
			source = string.gsub(source, "\\f", "\f")
			source = string.gsub(source, "\\n", "\n")
			source = string.gsub(source, "\\r", "\r")
			source = string.gsub(source, "\\t", "\t")
			source = string.gsub(source, '\\"', '"')
			source = string.gsub(source, "\\/", "/")
			source = string.gsub(source, "\0", "\\")

			return source
		end

		if byte == string.byte("\\") then
			state.cursor += 1
		end

		state.cursor += 1
	end

	state.cursor = startPos
	return deserializerError(state, "Unterminated string")
end

local deserialize: (DeserializerState) -> (Array | Object | boolean | number | string)?

local function deserializeArray(state: DeserializerState): Array
	if currentByte(state) ~= string.byte("[") then
		return deserializerError(state, "Expected array opening '['")
	end

	state.cursor += 1
	skipWhitespace(state)

	local current: Array = {}
	local index = 1

	-- empty array
	if currentByte(state) == string.byte("]") then
		state.cursor += 1
		return current
	end

	local expectingValue = true

	while state.cursor <= #state.src do
		if not expectingValue then
			-- Expect a comma or closing bracket
			if currentByte(state) == string.byte(",") then
				expectingValue = true
				state.cursor += 1
				if not skipWhitespace(state) then
					return deserializerError(state, "Unterminated array")
				end
			elseif currentByte(state) == string.byte("]") then
				state.cursor += 1
				return current
			else
				return deserializerError(state, "Expected ',' or ']' after array value")
			end
		else
			-- Expect a value next
			if currentByte(state) == string.byte("]") then
				if index == 1 then
					-- empty array is ok
					state.cursor += 1
					return current
				else
					return deserializerError(state, "Trailing comma in array")
				end
			end

			table.insert(current, deserialize(state))
			index += 1
			expectingValue = false
		end

		if not skipWhitespace(state) then
			return deserializerError(state, "Unterminated array")
		end
	end

	return deserializerError(state, "Unterminated array")
end

local function deserializeObject(state: DeserializerState): Object
	state.cursor += 1

	local current = {}

	local expectingValue = false
	while state.cursor < #state.src do
		skipWhitespace(state)

		if currentByte(state) == string.byte("}") then
			break
		end

		skipWhitespace(state)

		if currentByte(state) ~= string.byte('"') then
			return deserializerError(state, "Expected a string key")
		end

		local key = deserializeString(state)

		skipWhitespace(state)

		if currentByte(state) ~= string.byte(":") then
			return deserializerError(state, "Expected ':' for key value pair")
		end

		state.cursor += 1

		local value = deserialize(state)

		current[key] = value

		if not skipWhitespace(state) then
			deserializerError(state, "Unterminated object")
		end

		skipWhitespace(state)

		if currentByte(state) == string.byte(",") then
			expectingValue = true
			state.cursor += 1
		else
			expectingValue = false
		end
	end

	if expectingValue then
		return deserializerError(state, "Trailing comma")
	end

	if not skipWhitespace(state) or currentByte(state) ~= string.byte("}") then
		deserializerError(state, "Unterminated object")
	end

	state.cursor += 1

	return current
end

deserialize = function(state: DeserializerState): Value
	skipWhitespace(state)

	local fourChars = string.sub(state.src, state.cursor, state.cursor + 3)

	if string.match(fourChars, "^null") then
		state.cursor += 4
		return json.null
	elseif string.match(fourChars, "^true") then
		state.cursor += 4
		return true
	elseif string.match(string.sub(state.src, state.cursor, state.cursor + 4), "^false") then
		state.cursor += 5
		return false
	elseif string.match(state.src, "^[%-%d]", state.cursor) then
		-- potential number
		return deserializeNumber(state)
	elseif string.match(state.src, '^"', state.cursor) then
		return deserializeString(state)
	elseif string.match(state.src, "^%[", state.cursor) then
		return deserializeArray(state)
	elseif string.match(state.src, "^{", state.cursor) then
		local obj = deserializeObject(state)
		obj[object_key] = true
		return obj
	end

	return deserializerError(state, `Unexpected token '{string.sub(state.src, state.cursor, state.cursor)}'`)
end

-- user-facing

--- Serializes `value` to a JSON string. If `prettyPrint` is `true`, the output is indented for readability.
function json.serialize(value: Value, prettyPrint: boolean?): string
	local state: SerializerState = {
		buf = buffer.create(bufferSize),
		cursor = 0,
		prettyPrint = prettyPrint or false,
		depth = 0,
	}

	serializeAny(state, value)

	return buffer.readstring(state.buf, 0, state.cursor)
end

--- Parses a JSON string and returns the corresponding Luau value. Returns `json.null` for a JSON `null` literal; compare with `json.null` rather than `nil` to check for null.
function json.deserialize(src: string): (Array | Object | boolean | number | string)?
	local state = {
		src = src,
		cursor = 0,
	}

	local result = deserialize(state)

	-- After parsing a value, there must be no non-whitespace trailing characters.
	if skipWhitespace(state) then
		deserializerError(state, "Trailing characters after JSON value")
	end

	return result
end

--- Creates a JSON `Object` from `props`. Use this to distinguish an empty object `{}` from an empty array when serializing.
function json.object(props: { [string]: Value }): Object
	local res: Object = { [object_key] = true }

	for key, value in props do
		res[key] = value
	end

	return res
end

--- Returns `value` as an `Object` if it is a JSON object, or `nil` otherwise.
function json.asObject(value: Value): Object?
	if typeof(value) == "table" and value[object_key] then
		return value :: Object
	end

	return nil
end

--- Returns `value` as an `Array` if it is a JSON array, or `nil` otherwise.
function json.asArray(value: Value): Array?
	if typeof(value) == "table" and not value[object_key] then
		return value :: Array
	end

	return nil
end

return table.freeze(json)
]==],["std/fs.luau"] = [==[--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local deque = require("@batteries/collections/deque")
local fs = require("@lute/fs")
local pathlib = require("@std/path")
local sys = require("@std/system")
local win32paths = require("@std/path/win32")

local fslib = {}

--- How a file should be opened:
--- - `"r"`: Open for reading. Fails if the file does not exist.
--- - `"w"`: Open for writing; creates the file if absent, truncates it if present.
--- - `"x"`: Open for exclusive creation. Fails if the file already exists.
--- - `"a"`: Open for appending; creates the file if absent, writes go to the end.
--- - `"r+"`: Open for reading and writing. Fails if the file does not exist.
--- - `"w+"`: Open for reading and writing; creates the file if absent, truncates it if present.
--- - `"x+"`: Open for reading and exclusive creation. Fails if the file already exists.
--- - `"a+"`: Open for reading and appending; creates the file if absent, writes go to the end.
export type HandleMode = fs.HandleMode
--- An open file handle.
export type File = fs.FileHandle
--- The type of a filesystem entry:
--- - `"file"`: A regular file.
--- - `"dir"`: A directory.
--- - `"link"`: A symbolic link.
--- - `"fifo"`: A named pipe (FIFO).
--- - `"socket"`: A Unix domain socket.
--- - `"char"`: A character device.
--- - `"block"`: A block device.
--- - `"unknown"`: An entry whose type could not be determined.
export type FileType = fs.FileType
--- Metadata about a filesystem entry, such as size, type, and timestamps.
export type FileMetadata = fs.FileMetadata
--- A single entry returned by `listDirectory`, containing the entry's name and type.
export type DirectoryEntry = fs.DirectoryEntry
--- A handle to an active filesystem watcher, returned by `watch`.
export type WatchHandle = fs.WatchHandle
--- A filesystem change event, yielded by a `Watcher`.
export type WatchEvent = fs.WatchEvent

type Pathlike = pathlib.Pathlike
type Path = pathlib.Path
type win32path = win32paths.Path

--- Options for `createDirectory`:
--- - `makeParents`: If `true`, creates any missing parent directories. Defaults to `false`.
export type CreateDirectoryOptions = {
	makeParents: boolean?,
}

--- Options for `removeDirectory`:
--- - `recursive`: If `true`, removes all contents of the directory before deleting it. Defaults to `false`.
export type RemoveDirectoryOptions = {
	recursive: boolean?,
}

--- Options for `walk`:
--- - `recursive`: If `true`, descends into subdirectories. Defaults to `false`.
export type WalkOptions = {
	recursive: boolean?,
}

type Watcher = {
	next: (Watcher) -> WatchEvent?,
	close: (self: Watcher) -> (),
}

--- Opens the file at `path` in the given `mode` (defaults to `"r"`). Returns a file handle.
function fslib.open(path: Pathlike, mode: HandleMode?): File
	return fs.open(pathlib.format(path), mode)
end

--- Reads the full contents of `file` and returns them as a string.
function fslib.read(file: File): string
	return fs.read(file)
end

--- Writes `contents` to `file`.
function fslib.write(file: File, contents: string): ()
	return fs.write(file, contents)
end

--- Closes `file`, flushing any pending writes.
function fslib.close(file: File): ()
	return fs.close(file)
end

--- Removes the file at `path`.
function fslib.remove(path: Pathlike): ()
	return fs.remove(pathlib.format(path))
end

--- Returns metadata for the file or directory at `path`.
function fslib.metadata(path: Pathlike): FileMetadata
	return fs.stat(pathlib.format(path))
end

--- Returns the `FileType` of the entry at `path` (e.g. `"file"`, `"dir"`, `"symlink"`).
function fslib.type(path: Pathlike): FileType
	return fs.type(pathlib.format(path))
end

--- Creates a hard link at `dest` pointing to `src`.
function fslib.link(src: Pathlike, dest: Pathlike): ()
	return fs.link(pathlib.format(src), pathlib.format(dest))
end

--- Creates a symbolic link at `dest` pointing to `src`.
function fslib.symbolicLink(src: Pathlike, dest: Pathlike): ()
	return fs.symlink(pathlib.format(src), pathlib.format(dest))
end

--- Watches `path` for filesystem changes. Returns a `Watcher` with a `next` method that returns the next
--- `WatchEvent`, or `nil` if none is available, and a `close` method to stop watching.
--- Note: a while loop must be used rather than a for loop. See example/watch_directory.luau for usage.
function fslib.watch(path: Pathlike): Watcher
	-- In the future this could be written with explicit instantiation syntax
	-- as in:
	--
	--	deque.new<<{ filename: path, event: watchevent }>>()
	local deq = deque.new(nil :: { filename: Path, event: WatchEvent }?)
	local handle = fs.watch(pathlib.format(path), function(filename, event)
		deq:pushback({ filename = pathlib.parse(filename), event = event })
	end)

	return {
		next = function(_self: Watcher): WatchEvent?
			if not deq:peekfront() then
				return nil
			end
			local item = deq:popfront()
			assert(item)
			return item.event
		end,
		close = function(_self: Watcher): ()
			if handle then
				handle:close()
			end
		end,
	}
end

--- Returns `true` if a file or directory exists at `path`.
function fslib.exists(path: Pathlike): boolean
	return fs.exists(pathlib.format(path))
end

--- Copies the file at `src` to `dest`.
function fslib.copy(src: Pathlike, dest: Pathlike): ()
	return fs.copy(pathlib.format(src), pathlib.format(dest))
end

--- Returns an array of `DirectoryEntry` values for the immediate children of the directory at `path`.
function fslib.listDirectory(path: Pathlike): { DirectoryEntry }
	return fs.listdir(pathlib.format(path))
end

--- Returns the entire contents of the file at `filepath` as a string.
function fslib.readFileToString(filepath: Pathlike): string
	local f = fs.open(pathlib.format(filepath), "r")
	local contents = fs.read(f)
	fs.close(f)
	return contents
end

--- Writes `contents` to the file at `filepath`, replacing any existing contents.
function fslib.writeStringToFile(filepath: Pathlike, contents: string): ()
	local f = fs.open(pathlib.format(filepath), "w+")
	fs.write(f, contents)
	fs.close(f)
end

--- Creates a directory at `path`. If `options.makeParents` is `true`, creates any missing parent directories as well.
function fslib.createDirectory(path: Pathlike, options: CreateDirectoryOptions?): ()
	if options and options.makeParents then
		local parsed = pathlib.parse(path)
		local parts: { string } = parsed.parts

		local subdir: Pathlike = "."
		if pathlib.isAbsolute(path) then
			if sys.win32 then
				-- Windows path - get the drive root like "C:\"
				subdir = pathlib.win32.drive(parsed :: win32path)
			else
				-- POSIX absolute path - start from root "/"
				subdir = pathlib.format({ absolute = true, parts = {} })
			end
		end

		for _, part in parts do
			subdir = pathlib.join(subdir, part)
			if not fslib.exists(subdir) then
				fs.mkdir(pathlib.format(subdir))
			end
		end
	else
		fs.mkdir(pathlib.format(path))
	end
end

--- Removes the directory at `path`. If `options.recursive` is `true`, removes all contents first.
function fslib.removeDirectory(path: Pathlike, options: RemoveDirectoryOptions?): ()
	if options and options.recursive then
		-- Recursively delete all contents first
		if fslib.exists(path) and fslib.type(path) == "dir" then
			local entries = fslib.listDirectory(path)
			for _, entry in entries do
				local entryPath = pathlib.join(path, entry.name)
				if entry.type == "dir" then
					fslib.removeDirectory(entryPath, { recursive = true })
				else
					fslib.remove(entryPath)
				end
			end
			fs.rmdir(pathlib.format(path))
		end
	else
		fs.rmdir(pathlib.format(path))
	end
end

--- Returns an iterator over all paths under `path`. If `options.recursive` is `true`, descends into subdirectories.
--- See example/walk_directory.luau for usage.
function fslib.walk(path: Pathlike, options: WalkOptions?): () -> Path?
	local queue: { Path } = { pathlib.parse(path) }
	local recursive = if options then options.recursive else false

	return function()
		while #queue > 0 do
			local current = table.remove(queue, 1)
			if not current then
				return nil
			end

			if fslib.type(current) == "dir" and recursive then
				local entries = fslib.listDirectory(current)
				for _, entry in entries do
					local fullPath = pathlib.join(current, entry.name)
					table.insert(queue, fullPath)
				end
			end

			return current
		end

		return nil
	end
end

return table.freeze(fslib)
]==],["lute/io.luau"] = [==[local io = {}

--- Writes one or more strings to standard output without a trailing newline.
function io.write(...: string): ()
	error("unimplemented")
end

--- Reads a line from standard input and returns it as a string.
function io.read(): string
	error("unimplemented")
end

return io
]==],["std/path/init.luau"] = [==[local platform = require("@std/system/platform")

local posix = require("@self/posix")
local win32 = require("@self/win32")

local pathtypes = require("@self/types")

local pathlib = {}

--- A structured, platform-aware file system path.
export type Path = pathtypes.Path
--- Anything that can be used as a path: a string, a `Path`, or raw path data.
export type Pathlike = pathtypes.Pathlike

local onWindows = platform.win32

--- Returns the last component of `path` (the filename or directory name), or `nil` if the path has no components.
function pathlib.basename(path: Pathlike): string?
	if onWindows then
		return win32.basename(path :: win32.Pathlike)
	else
		return posix.basename(path :: posix.Pathlike)
	end
end

--- Returns the directory portion of `path` as a string (everything except the last component).
function pathlib.dirname(path: Pathlike): string
	if onWindows then
		return win32.dirname(path :: win32.Pathlike)
	else
		return posix.dirname(path :: posix.Pathlike)
	end
end

--- Returns the file extension of `path` (including the leading dot), or `""` if there is none.
function pathlib.extname(path: Pathlike): string
	if onWindows then
		return win32.extname(path :: win32.Pathlike)
	else
		return posix.extname(path :: posix.Pathlike)
	end
end

--- Converts `path` to its string representation using the platform's separator.
function pathlib.format(path: Pathlike): string
	if onWindows then
		return win32.format(path :: win32.Pathlike)
	else
		return posix.format(path :: posix.Pathlike)
	end
end

--- Returns `true` if `path` is absolute.
function pathlib.isAbsolute(path: Pathlike): boolean
	if onWindows then
		return win32.isAbsolute(path :: win32.Pathlike)
	else
		return posix.isAbsolute(path :: posix.Pathlike)
	end
end

--- Joins one or more path segments together into a single `Path`. Each segment after the first must be relative.
function pathlib.join(...: Pathlike): Path
	if onWindows then
		return win32.join(...)
	else
		return posix.join(...)
	end
end

--- Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.
function pathlib.normalize(path: Pathlike): Path
	if onWindows then
		return win32.normalize(path :: win32.Pathlike)
	else
		return posix.normalize(path :: posix.Pathlike)
	end
end

--- Parses `path` into a structured `Path` value.
function pathlib.parse(path: Pathlike): Path
	if onWindows then
		return win32.parse(path :: win32.Pathlike)
	else
		return posix.parse(path :: posix.Pathlike)
	end
end

--- Returns the relative path from `from` to `to`. Both paths must be of the same kind (both absolute or both relative).
function pathlib.relative(from: Pathlike, to: Pathlike): Path
	if onWindows then
		return win32.relative(from :: win32.Pathlike, to :: win32.Pathlike)
	else
		return posix.relative(from :: posix.Pathlike, to :: posix.Pathlike)
	end
end

--- Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.
function pathlib.resolve(...: Pathlike): Path
	if onWindows then
		return win32.resolve(...)
	else
		return posix.resolve(...)
	end
end

pathlib.win32 = win32
pathlib.posix = posix

return table.freeze(pathlib)
]==],["std/luau.luau"] = [==[--!strict
-- @std/luau
-- stdlib for `@lute/luau`
-- Provides utilities for parsing and compiling Luau source code

local luteLuau = require("@lute/luau")

local fs = require("@lute/fs")
local path = require("@std/path")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")
local printer = require("@std/syntax/printer")

local luau = {}

--- Compiled Luau bytecode produced by `luau.compile`.
export type Bytecode = luteLuau.Bytecode

--- A `require(...)` call found in a source file, with its resolved absolute path and the raw require string.
export type RequireNode = {
	resolvedPath: string?,
	requirePath: string?,
	requireExpr: luteLuau.AstExprCall,
}

--- Compiles Luau source code into bytecode.
function luau.compile(source: string): Bytecode
	return luteLuau.compile(source)
end

--- Loads `bytecode` into a callable function. `chunkname` names the chunk for error messages.
--- An optional `env` table can be provided to override the global environment for the loaded chunk.
function luau.load(bytecode: Bytecode, chunkname: string?, env: { [any]: any }?): (...any) -> ...any
	return luteLuau.load(bytecode, if chunkname ~= nil then `@{chunkname}` else "=luau.load", env)
end

--- Loads and executes the Luau file at `requirePath`, returning its result.
--- An optional `env` table can be provided to override the global environment.
function luau.loadModule(requirePath: path.Pathlike, env: { [any]: any }?): any
	local requirePathStr = if typeof(requirePath) == "string" then requirePath else path.format(requirePath)

	local migrationHandle = fs.open(requirePathStr, "r")

	local migrationBytecode = luau.compile(fs.read(migrationHandle))

	fs.close(migrationHandle)

	return luau.load(migrationBytecode, requirePathStr, env)()
end

--- A Luau type pack, representing a sequence of types.
export type TypePack = luteLuau.TypePack
--- A Luau type, representing the type of a value or expression.
export type Type = luteLuau.Type

--- Returns the type pack representing the return types of the module at `modulepath`, or `nil` if unavailable.
function luau.typeofModule(modulepath: path.Pathlike): TypePack?
	local modulePathStr = if typeof(modulepath) == "string" then modulepath else path.format(modulepath)

	return luteLuau.typeofModule(modulePathStr)
end

--- Resolves the require path `modulepath` relative to `frompath`, returning the absolute path.
function luau.resolveModule(modulepath: string, frompath: path.Pathlike): path.Pathlike
	local frompathString = if typeof(frompath) == "string" then frompath else path.format(frompath)
	return luteLuau.resolveModule(modulepath, `@{frompathString}`)
end

--- Returns all `require(...)` calls found in the file at `filePath`, with resolved absolute paths where available.
function luau.requires(filePath: path.Pathlike): { RequireNode }
	local filePathStr = if typeof(filePath) == "string" then filePath else path.format(filePath)

	local handle = fs.open(filePathStr, "r")
	local source = fs.read(handle)
	fs.close(handle)

	local ast = luteLuau.parse(source)

	local requireCalls = query.findAllFromRoot(ast, utils.isRequireCall)

	return requireCalls:mapToArray(function(call: luteLuau.AstExprCall): RequireNode?
		local argNode = call.arguments[1].node
		if argNode == nil then
			return nil
		end

		local content: string? = nil
		if argNode.tag == "string" then
			content = (argNode :: luteLuau.AstExprConstantString).token.text
		else
			content = printer.printNode(argNode)
		end

		local resolved: string? = nil
		if content ~= nil then
			local ok, result = pcall(luteLuau.resolveModule, content, `@{filePathStr}`)
			if ok then
				resolved = result
			end
		end

		return {
			resolvedPath = resolved,
			requirePath = content,
			requireExpr = call,
		}
	end)
end

return table.freeze(luau)
]==],["std/test/types.luau"] = [==[--!strict
-- @std/test/types
-- Standard test types library for Luau

--- The name of a lifecycle hook that can run around test cases:
--- - `"beforeEach"`: Runs before each test case in the suite.
--- - `"beforeAll"`: Runs once before all test cases in the suite.
--- - `"afterEach"`: Runs after each test case in the suite.
--- - `"afterAll"`: Runs once after all test cases in the suite.
export type Hook = "beforeEach" | "beforeAll" | "afterEach" | "afterAll"
--- Describes why a test failed:
--- - `"assertion"`: An assertion (e.g. `t.eq`) failed. Includes the assertion name, message, filename, and line number.
--- - `"lifecycle"`: A lifecycle hook threw an error. Includes the hook name, message, filename, and line number.
--- - `"runtime_error"`: The test body threw an unhandled error. Includes the message and stack trace.
export type Failure =
	{
		assertion: string, -- name of the assertion
		msg: string, -- failure message
		filename: string, -- filename
		linenumber: number, -- linenumber
		__tag: "assertion",
	}
	| {
		hook: Hook, -- the name of the hook that broke
		msg: string, -- failure message
		filename: string, -- filename
		linenumber: number, -- linenumber
		__tag: "lifecycle",
	}
	| {
		msg: string, -- failure message
		stacktrace: string, -- stacktrace
		__tag: "runtime_error",
	}

--- The assertion functions passed to each test case. Each assertion returns a `Failure` on failure, or `nil` on success.
export type Asserts = {
	eq: <T>(T, T, string?) -> Failure?,
	neq: <T>(T, T, string?) -> Failure?,
	throws: <T...>((T...) -> ...unknown, T...) -> Failure?,
	throwsWith: <T...>(any, (T...) -> ...unknown, T...) -> Failure?,
	strContains: (string, string, number?, string?) -> Failure?,
	strNotContains: (string, string, string?) -> Failure?,
	that: (unknown, string?) -> Failure?,
}

--- A test function that receives the assertion helpers and runs one test case.
export type Test = (Asserts) -> ()

--- A named test case pairing a name with its test function.
export type TestCase = { name: string, case: Test }

--- A named collection of test cases with optional lifecycle hooks.
export type TestSuite = {
	name: string,
	cases: { TestCase },
	_beforeEach: (() -> ())?,
	_beforeAll: (() -> ())?,
	_afterEach: (() -> ())?,
	_afterAll: (() -> ())?,
	case: (self: TestSuite, string, Test) -> (),
	beforeEach: (self: TestSuite, () -> ()) -> (),
	beforeAll: (self: TestSuite, () -> ()) -> (),
	afterEach: (self: TestSuite, () -> ()) -> (),
	afterAll: (self: TestSuite, () -> ()) -> (),
}

--- A test case that failed, paired with the failure that caused it.
export type FailedTest = {
	test: string, -- name of the test case that failed
	failure: Failure,
}

--- The aggregate results of a test run: total, passed, failed counts and the list of failures.
export type TestRunResult = {
	failures: { FailedTest },
	total: number,
	failed: number,
	passed: number,
}

--- A function that receives a `TestRunResult` and reports it (e.g. prints to stdout).
export type TestReporter = (TestRunResult) -> ()

-- Testing Environment
--- An index entry mapping a test case name to all anonymous instances and suite instances with that name.
export type CaseIndexEntry = {
	anonymous: { TestCase },
	suites: { [string]: { TestCase } },
}

--- The full set of discovered tests: anonymous cases, suites, and lookup indexes by name.
export type TestEnvironment = {
	anonymous: { TestCase },
	suites: { TestSuite },
	suiteindex: { [string]: TestSuite },
	caseindex: { [string]: CaseIndexEntry },
}

--- A function that runs a `TestEnvironment` and returns the results.
export type TestRunner = (TestEnvironment) -> TestRunResult

return {}
]==],["std/syntax/printer.luau"] = [==[--!strict
-- @std/syntax/printer

local triviaUtils = require("./utils/trivia")
local types = require("./types")
local visitor = require("./visitor")

local printerLib = {}

type PrintVisitor = visitor.Visitor & {
	result: buffer,
	cursor: number,
	replacements: types.Replacements,
	write: (self: PrintVisitor, str: string) -> (),
	printTrivia: (self: PrintVisitor, trivia: types.Trivia) -> (),
	printTriviaList: (self: PrintVisitor, trivia: { types.Trivia }) -> (),
	printToken: (self: PrintVisitor, token: types.Token) -> (),
	printString: (self: PrintVisitor, expr: types.AstExprConstantString | types.AstTypeSingletonString) -> (),
	printInterpolatedString: (self: PrintVisitor, expr: types.AstExprInterpString) -> (),
	printReplacement: (self: PrintVisitor, node: types.AstNode, replacement: string) -> (),
}
local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function printTrivia(self: PrintVisitor, trivia: types.Trivia)
	if trivia.tag == "whitespace" or trivia.tag == "comment" or trivia.tag == "blockcomment" then
		self:write(trivia.text)
	else
		exhaustiveMatch(trivia.tag)
	end
end

local function printTriviaList(self: PrintVisitor, trivia: { types.Trivia })
	for _, trivia in trivia do
		self:printTrivia(trivia)
	end
end

local function printToken(self: PrintVisitor, token: types.Token)
	if self.replacements[token] ~= nil then
		self:printReplacement(token, self.replacements[token])
		return
	end

	self:printTriviaList(token.leadingTrivia)
	self:write(token.text)
	self:printTriviaList(token.trailingTrivia)
end

local function printString(self: PrintVisitor, expr: types.AstExprConstantString | types.AstTypeSingletonString)
	if self.replacements[expr] ~= nil then
		self:printReplacement(expr, self.replacements[expr])
		return
	end

	self:printTriviaList(expr.token.leadingTrivia)

	if expr.quoteStyle == "single" then
		self:write(`'{expr.token.text}'`)
	elseif expr.quoteStyle == "double" then
		self:write(`"{expr.token.text}"`)
	elseif expr.quoteStyle == "block" then
		local equals = string.rep("=", expr.blockDepth)
		self:write(`[{equals}[{expr.token.text}]{equals}]`)
	elseif expr.quoteStyle == "interp" then
		self:write("`" .. expr.token.text .. "`")
	else
		exhaustiveMatch(expr.quoteStyle)
	end

	self:printTriviaList(expr.token.trailingTrivia)
end

local function printInterpolatedString(self: PrintVisitor, expr: types.AstExprInterpString)
	if self.replacements[expr] ~= nil then
		self:printReplacement(expr, self.replacements[expr])
		return
	end

	for i = 1, #expr.strings do
		self:printTriviaList(expr.strings[i].leadingTrivia)
		if i == 1 then
			self:write("`")
		else
			self:write("}")
		end
		self:write(expr.strings[i].text)

		if i == #expr.strings then
			self:write("`")
			self:printTriviaList(expr.strings[i].trailingTrivia)
		else
			self:write("{")
			self:printTriviaList(expr.strings[i].trailingTrivia)
			visitor.visitExpression(expr.expressions[i], self)
		end
	end
end

local function printReplacement(self: PrintVisitor, node: types.AstNode, replacement: string)
	local leftmostTrivia = triviaUtils.leftmostTrivia(node)
	if leftmostTrivia ~= nil then
		self:printTriviaList(leftmostTrivia)
	end

	assert(typeof(replacement) == "string", "Unsupported replacement type")
	self:write(replacement)

	local rightmostTrivia = triviaUtils.rightmostTrivia(node)
	if rightmostTrivia ~= nil then
		self:printTriviaList(rightmostTrivia)
	end
end

local function write(self: PrintVisitor, str: string)
	local totalSize = self.cursor + #str
	local bufferSize = buffer.len(self.result)

	if totalSize >= bufferSize then
		repeat
			bufferSize *= 2
		until bufferSize >= totalSize

		local newBuffer = buffer.create(bufferSize)
		buffer.copy(newBuffer, 0, self.result)
		self.result = newBuffer
	end

	buffer.writestring(self.result, self.cursor, str)
	self.cursor = totalSize
end

local function printVisitor(replacements: types.Replacements?)
	local result = buffer.create(1024)
	local cursor = 0

	local printer: PrintVisitor = {} :: PrintVisitor

	-- The visitor library doesn't use methods, so we access replacements through a closure
	local function maybeReplace(node: types.AstNode): boolean
		if replacements == nil then
			return true
		end
		local replacement: string? = replacements[node]
		if replacement == nil then
			return true
		end
		printer:printReplacement(node, replacement)
		return false
	end

	printer = visitor.create(maybeReplace) :: PrintVisitor

	printer.result = result
	printer.cursor = cursor
	printer.replacements = if replacements ~= nil then replacements else {} :: types.Replacements
	printer.write = write
	printer.printTrivia = printTrivia
	printer.printTriviaList = printTriviaList
	printer.printToken = printToken
	printer.printString = printString
	printer.printInterpolatedString = printInterpolatedString
	printer.printReplacement = printReplacement
	printer.visitExprInterpString = function(node: types.AstExprInterpString)
		printer:printInterpolatedString(node)
		return false
	end
	printer.visitTypeSingletonString = function(node: types.AstTypeSingletonString)
		printer:printString(node)
		return false
	end
	printer.visitToken = function(node: types.Token)
		printer:printToken(node)
		return false
	end
	printer.visitExprConstantString = function(node: types.AstExprConstantString)
		printer:printString(node)
		return false
	end

	return printer
end

--- Returns `node` as source text, optionally applying `replacements` to substitute specific nodes with new text.
function printerLib.printNode(node: types.AstNode, replacements: types.Replacements?): string
	local printer = printVisitor(replacements)
	visitor.visit(node, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

--- Returns an entire parsed file as source text, including the EOF token, optionally applying `replacements`.
function printerLib.printFile(result: types.ParseResult, replacements: types.Replacements?): string
	local printer = printVisitor(replacements)
	visitor.visitBlock(result.root, printer)
	visitor.visitToken(result.eof, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

return table.freeze(printerLib)
]==],["std/tableext.luau"] = [==[--!strict
-- @std/tableext
-- stdlib for an extension of the built-in table library in Luau
-- Provides additional utility functions for table operations

local tableext = {}

-- Functions on general tables

--- Returns a new table with the same keys as `table`, where each value has been transformed by applying `f` to it.
function tableext.map<K, A, B>(table: { [K]: A }, f: (A) -> B): { [K]: B }
	local new = {}

	for k, v in table do
		new[k] = f(v)
	end

	return new
end

--- Returns a new table containing only the key-value pairs from `table` for which `predicate` returns `true`.
function tableext.filter<K, V>(table: { [K]: V }, predicate: (V) -> boolean): { [K]: V }
	local new = {}

	for k, v in table do
		if predicate(v) then
			new[k] = v
		end
	end

	return new
end

--- Merges all additional tables into `tbl` in order. When the same key appears in multiple tables, the value from the last table containing that key wins. Returns `tbl`.
function tableext.combine<K, V>(tbl: { [K]: V }, ...: { [K]: V }): { [K]: V }
	local tables = table.pack(...)
	tables.n = nil :: any
	for _, tocombine in tables do
		for key, val in tocombine do
			tbl[key] = val
		end
	end
	return tbl
end

--- Returns an array of all keys in `tbl`. Order is not guaranteed.
function tableext.keys<K, V>(tbl: { [K]: V }): { K }
	local keys = {}
	for k, _ in tbl do
		table.insert(keys, k)
	end
	return keys
end

-- Functions on array-like tables

--- Converts an array into a set-like table where each element maps to `true`.
function tableext.toSet<T>(tbl: { T }): { [T]: true }
	local set: { [T]: true } = {}
	for _, v in tbl do
		set[v] = true
	end
	return set
end

--- Appends all elements from each additional array into `tbl` in order, mutating it in place.
function tableext.extend<T>(tbl: { T }, ...: { T }): ()
	local extensions = table.pack(...)
	extensions.n = nil :: any
	for _, extension in extensions do
		for _, entry in extension do
			table.insert(tbl, entry)
		end
	end
end

--- Returns `tbl` with its elements in reverse order. If `inplace` is `true`, reverses `tbl` in place; otherwise returns a new array.
function tableext.reverse<T>(tbl: { T }, inplace: boolean?): { T }
	local new = if inplace then tbl else {}
	local i, j = 1, #tbl
	while i <= j do
		new[i], new[j] = tbl[j], tbl[i]
		i += 1
		j -= 1
	end
	return new
end

--- Returns `true` if `predicate` returns `true` for at least one element of `arr`.
function tableext.any<T>(arr: { T }, predicate: (T) -> boolean): boolean
	for _, v in arr do
		if predicate(v) then
			return true
		end
	end
	return false
end

--- Returns `true` if `predicate` returns `true` for every element of `arr`.
function tableext.all<T>(arr: { T }, predicate: (T) -> boolean): boolean
	for _, v in arr do
		if not predicate(v) then
			return false
		end
	end
	return true
end

return table.freeze(tableext)
]==],["lute/vm.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local vm = {}

--- Creates a new Luau VM from the module at `path` and returns its exported table.
function vm.create(path: string): { [any]: any }
	error("not implemented")
end

return vm
]==],["std/net.luau"] = [==[--!strict
-- @std/net
-- stdlib for `@lute/net`

local client = require("@lute/net/client")

local netlib = {}

--- Options for an HTTP request:
--- - `method`: The HTTP method (e.g. `"GET"`, `"POST"`). Defaults to `"GET"`.
--- - `body`: The request body as a string. If omitted, no body is sent.
--- - `headers`: A table of HTTP headers to include in the request.
export type Metadata = client.Metadata
--- An HTTP response, containing status, headers, and body.
export type Response = client.Response

--- Makes an HTTP request to `url` with optional request metadata. Returns the response.
function netlib.request(url: string, metadata: Metadata?): Response
	return client.request(url, metadata)
end

return table.freeze(netlib)
]==],["lute/system.luau"] = [==[--- CPU information for a single logical processor, including model, speed, and time-usage breakdown.
export type CpuInfo = {
	model: string,
	speed: number,

	times: {
		sys: number,
		idle: number,
		irq: number,
		nice: number,
		user: number,
	},
}

local system = {}

--- Returns the number of logical CPU threads available on the current machine.
function system.threadCount(): number
	error("unimplemented")
end

--- Returns the hostname of the current machine.
function system.hostName(): string
	error("unimplemented")
end

--- Returns the path to the system's temporary directory.
function system.tmpdir(): string
	error("unimplemented")
end

--- Returns the total amount of system memory in bytes.
function system.totalMemory(): number
	error("unimplemented")
end

--- Returns the amount of free (available) system memory in bytes.
function system.freeMemory(): number
	error("unimplemented")
end

--- Returns the system uptime in seconds.
function system.uptime(): number
	error("unimplemented")
end

--- Returns CPU information for each logical processor on the current machine.
function system.cpus(): { CpuInfo }
	error("unimplemented")
end

--- The current operating system, e.g. `"linux"`, `"macos"`, `"windows"`.
system.os = "" :: string
--- The CPU architecture of the current machine, e.g. `"x64"`, `"arm64"`.
system.arch = "" :: string

return system
]==],["lute/luau.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local luau = {}

type SpanData = {
	read beginLine: number,
	read beginColumn: number,
	read endLine: number,
	read endColumn: number,
}
type SpanMT = {
	read __lt: (a: SpanData, b: SpanData) -> boolean,
}
--- A source location range, defined by begin and end line/column positions.
export type Span = setmetatable<SpanData, SpanMT>

luau.span = {}

--- Creates a `Span` from a table with `beginLine`, `beginColumn`, `endLine`, and `endColumn`.
function luau.span.create(tbl: { beginLine: number, beginColumn: number, endLine: number, endColumn: number }): Span
	error("not implemented")
end

--- A whitespace trivia token.
export type Whitespace = {
	read tag: "whitespace",
	read location: Span,
	read text: string,
}

--- A single-line comment trivia token (`--`).
export type SingleLineComment = {
	read tag: "comment",
	read location: Span,
	read text: string,
}

--- A multi-line block comment trivia token (`--[[...]]`).
export type MultiLineComment = {
	read tag: "blockcomment",
	read location: Span,
	read text: string,
	-- TODO: depth: number,
}

--- Trivia attached to a token: whitespace or comments.
export type Trivia = Whitespace | SingleLineComment | MultiLineComment

export type Token<Kind = string> = {
	read leadingTrivia: { Trivia },
	read location: Span,
	read text: Kind,
	read trailingTrivia: { Trivia },
	read kind: "token",
}

--- The end-of-file token.
export type Eof = Token<""> & { read tag: "eof" }

export type Pair<T, Separator> = { read node: T, read separator: Token<Separator>? }
export type Punctuated<T, Separator = ","> = { Pair<T, Separator> }

--- A local variable binding site in the AST.
export type AstLocal = {
	read location: Span,
	read kind: "local",
	read name: Token<string>,
	read colon: Token<":">?,
	read annotation: AstType?,
	read shadows: AstLocal?,
}

--- A parenthesized expression node.
export type AstExprGroup = {
	read location: Span,
	read kind: "expr",
	read tag: "group",
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}

--- A `nil` literal node.
export type AstExprConstantNil = {
	read location: Span,
	read kind: "expr",
	read tag: "nil",
	read token: Token<"nil">,
}

--- A boolean literal node (`true` or `false`).
export type AstExprConstantBool = {
	read location: Span,
	read kind: "expr",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}

--- A number literal node.
export type AstExprConstantNumber = {
	read location: Span,
	read kind: "expr",
	read tag: "number",
	read value: number,
	read token: Token<string>,
}

--- A string literal node.
export type AstExprConstantString = {
	read location: Span,
	read kind: "expr",
	read tag: "string",
	read quoteStyle: "single" | "double" | "block" | "interp",
	read blockDepth: number,
	read token: Token<string>,
}

--- A reference to a local variable.
export type AstExprLocal = {
	read location: Span,
	read kind: "expr",
	read tag: "local",
	read token: Token<string>,
	read ["local"]: AstLocal,
	read upvalue: boolean,
}

--- A reference to a global variable.
export type AstExprGlobal = { read location: Span, read kind: "expr", read tag: "global", read name: Token }

--- A varargs expression node (`...`).
export type AstExprVarargs = {
	read location: Span,
	read kind: "expr",
	read tag: "vararg",
	read token: Token<"...">,
}

--- A function call expression node.
export type AstExprCall = {
	read location: Span,
	read kind: "expr",
	read tag: "call",
	read func: AstExpr,
	read openParens: Token<"(">?,
	read arguments: Punctuated<AstExpr>,
	read closeParens: Token<")">?,
	read self: boolean,
	read argLocation: Span,
}

--- An explicit generic instantiation expression node (e.g., `f<<T>>`).
export type AstExprInstantiate = {
	read location: Span,
	read kind: "expr",
	read tag: "instantiate",
	read expr: AstExpr,
	read leftArrow1: Token<"<">,
	read leftArrow2: Token<"<">,
	read typeArguments: Punctuated<AstType | AstTypePack>,
	read rightArrow1: Token<">">,
	read rightArrow2: Token<">">,
}

--- A dot or colon index expression node (e.g., `t.k` or `t:method`).
export type AstExprIndexName = {
	read location: Span,
	read kind: "expr",
	read tag: "indexname",
	read expression: AstExpr,
	read accessor: Token<"." | ":">,
	read index: Token<string>,
	read indexLocation: Span,
}

--- A bracketed index expression node (e.g., `t[k]`).
export type AstExprIndexExpr = {
	read location: Span,
	read kind: "expr",
	read tag: "index",
	read expression: AstExpr,
	read openBrackets: Token<"[">,
	read index: AstExpr,
	read closeBrackets: Token<"]">,
}

--- An anonymous function expression node.
export type AstExprFunction = {
	read location: Span,
	read kind: "expr",
	read tag: "function",
	read attributes: { AstAttribute },
	read functionKeyword: Token<"function">,
	read openGenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericPacks: Punctuated<AstGenericTypePack>?,
	read closeGenerics: Token<">">?,
	read openParens: Token<"(">,
	read self: AstLocal?,
	read parameters: Punctuated<AstLocal>,
	read vararg: Token<"...">?,
	read varargColon: Token<":">?,
	read varargAnnotation: AstTypePack?,
	read closeParens: Token<")">,
	read returnSpecifier: Token<":">?,
	read returnAnnotation: AstTypePack?,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

-- helper types for items contained in an AstExprTable, not actually AstExprs themselves
--- A positional table constructor entry (e.g., `value` in `{ value }`).
export type AstTableExprListItem = {
	read location: Span,
	read kind: "list",
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}

--- A named table constructor entry (e.g., `key = value`).
export type AstTableExprRecordItem = {
	read location: Span,
	read kind: "record",
	read key: Token<string>,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}

--- A table constructor entry with a computed key (e.g., `[expr] = value`).
export type AstTableExprGeneralItem = {
	read location: Span,
	read kind: "general",
	read indexerOpen: Token<"[">,
	read key: AstExpr,
	read indexerClose: Token<"]">,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}

--- Union of all table constructor entry types.
export type AstTableExprItem = AstTableExprListItem | AstTableExprRecordItem | AstTableExprGeneralItem

--- A table constructor expression node.
export type AstExprTable = {
	read location: Span,
	read kind: "expr",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableExprItem },
	read closeBrace: Token<"}">,
}

--- A unary expression node (e.g., `not x`, `-x`, `#x`).
export type AstExprUnary = {
	read location: Span,
	read kind: "expr",
	read tag: "unary",
	read operator: Token<"not" | "-" | "#">,
	read operand: AstExpr,
}

--- A binary expression node (e.g., `a + b`).
export type AstExprBinary = {
	read location: Span,
	read kind: "expr",
	read tag: "binary",
	read lhsOperand: AstExpr,
	read operator: Token,
	read rhsOperand: AstExpr,
}

--- An interpolated string expression node (e.g., `` `hello {name}` ``).
export type AstExprInterpString = {
	read location: Span,
	read kind: "expr",
	read tag: "interpolatedstring",
	read strings: { Token<string> },
	read expressions: { AstExpr },
}

--- A type assertion expression node (e.g., `x :: T`).
export type AstExprTypeAssertion = {
	read location: Span,
	read kind: "expr",
	read tag: "cast",
	read operand: AstExpr,
	read operator: Token<"::">,
	read annotation: AstType,
}

-- helper type for elseif clauses of an if-else expression, not actually an AstExpr itself
--- An `elseif` clause in an if-else expression.
export type AstElseIfExpr = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenExpr: AstExpr,
}

--- An if-else expression node.
export type AstExprIfElse = {
	read location: Span,
	read kind: "expr",
	read tag: "conditional",
	read ifKeyword: Token<"if">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenExpr: AstExpr,
	read elseifs: { AstElseIfExpr },
	read elseKeyword: Token<"else">,
	read elseExpr: AstExpr,
}

--- Union of all expression node types in the Luau AST.
export type AstExpr =
	| AstExprGroup
	| AstExprConstantNil
	| AstExprConstantBool
	| AstExprConstantNumber
	| AstExprConstantString
	| AstExprLocal
	| AstExprGlobal
	| AstExprVarargs
	| AstExprCall
	| AstExprInstantiate
	| AstExprIndexName
	| AstExprIndexExpr
	| AstExprFunction
	| AstExprTable
	| AstExprUnary
	| AstExprBinary
	| AstExprInterpString
	| AstExprTypeAssertion
	| AstExprIfElse

--- A block statement node (a sequence of statements).
export type AstStatBlock = {
	read location: Span,
	read kind: "stat",
	read tag: "block",
	read statements: { AstStat },
}

--- A `do...end` block statement node.
export type AstStatDo = {
	read location: Span,
	read kind: "stat",
	read tag: "do",
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

--- An `elseif` clause in an if statement.
export type AstElseIfStat = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenBlock: AstStatBlock,
}

--- An `if...then...elseif...else...end` statement node.
export type AstStatIf = {
	read location: Span,
	read kind: "stat",
	read tag: "conditional",
	read ifKeyword: Token<"if">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenBlock: AstStatBlock,
	read elseifs: { AstElseIfStat },
	read elseKeyword: Token<"else">?, -- TODO: This could be elseif!
	read elseBlock: AstStatBlock?,
	read endKeyword: Token<"end">,
}

--- A `while...do...end` loop statement node.
export type AstStatWhile = {
	read location: Span,
	read kind: "stat",
	read tag: "while",
	read whileKeyword: Token<"while">,
	read condition: AstExpr,
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

--- A `repeat...until` loop statement node.
export type AstStatRepeat = {
	read location: Span,
	read kind: "stat",
	read tag: "repeat",
	read repeatKeyword: Token<"repeat">,
	read body: AstStatBlock,
	read untilKeyword: Token<"until">,
	read condition: AstExpr,
}

--- A `break` statement node.
export type AstStatBreak = { read location: Span, read kind: "stat", read tag: "break", read token: Token<"break"> }

--- A `continue` statement node.
export type AstStatContinue = {
	read location: Span,
	read kind: "stat",
	read tag: "continue",
	read token: Token<"continue">,
}

--- A `return` statement node.
export type AstStatReturn = {
	read location: Span,
	read kind: "stat",
	read tag: "return",
	read returnKeyword: Token<"return">,
	read expressions: Punctuated<AstExpr>,
}

--- A statement consisting of a bare expression (e.g., a function call used as a statement).
export type AstStatExpr = {
	read location: Span,
	read kind: "stat",
	read tag: "expression",
	read expression: AstExpr,
}

--- A `local` variable declaration statement node.
export type AstStatLocal = {
	read location: Span,
	read kind: "stat",
	read tag: "local",
	read localKeyword: Token<"local">,
	read variables: Punctuated<AstLocal>,
	read equals: Token<"=">?,
	read values: Punctuated<AstExpr>,
}

--- A numeric `for` loop statement node.
export type AstStatFor = {
	read location: Span,
	read kind: "stat",
	read tag: "for",
	read forKeyword: Token<"for">,
	read variable: AstLocal,
	read equals: Token<"=">,
	read from: AstExpr,
	read toComma: Token<",">,
	read to: AstExpr,
	read stepComma: Token<",">?,
	read step: AstExpr?,
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

--- A generic `for...in` loop statement node.
export type AstStatForIn = {
	read location: Span,
	read kind: "stat",
	read tag: "forin",
	read forKeyword: Token<"for">,
	read variables: Punctuated<AstLocal>,
	read inKeyword: Token<"in">,
	read values: Punctuated<AstExpr>,
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

--- An assignment statement node.
export type AstStatAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "assign",
	read variables: Punctuated<AstExpr>,
	read equals: Token<"=">,
	read values: Punctuated<AstExpr>,
}

--- A compound assignment statement node (e.g., `x += 1`).
export type AstStatCompoundAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "compoundassign",
	read variable: AstExpr,
	read operand: Token, -- TODO: Enforce token type
	read value: AstExpr,
}

--- A function attribute node (`@checked`, `@native`, or `@deprecated`).
export type AstAttribute = {
	read location: Span,
	read kind: "attribute",
	read token: Token<"@checked" | "@native" | "@deprecated">,
}

--- A function declaration statement node.
export type AstStatFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "function",
	read name: AstExpr,
	read func: AstExprFunction,
}

--- A `local function` declaration statement node.
export type AstStatLocalFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "localfunction",
	read localKeyword: Token<"local">,
	read name: AstLocal,
	read func: AstExprFunction,
}

--- A `type` alias declaration statement node.
export type AstStatTypeAlias = {
	read location: Span,
	read kind: "stat",
	read tag: "typealias",
	read export: Token<"export">?,
	read typeToken: Token<"type">,
	read name: Token,
	read openGenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericPacks: Punctuated<AstGenericTypePack>?,
	read closeGenerics: Token<">">?,
	read equals: Token<"=">,
	read type: AstType,
}

-- A type function
--- A `type function` declaration statement node.
export type AstStatTypeFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "typefunction",
	read export: Token<"export">?,
	read type: Token<"type">,
	read name: Token,
	read body: AstExprFunction,
}

--- Union of all statement node types in the Luau AST.
export type AstStat =
	| AstStatBlock
	| AstStatDo
	| AstStatIf
	| AstStatWhile
	| AstStatRepeat
	| AstStatBreak
	| AstStatContinue
	| AstStatReturn
	| AstStatExpr
	| AstStatLocal
	| AstStatFor
	| AstStatForIn
	| AstStatAssign
	| AstStatCompoundAssign
	| AstStatFunction
	| AstStatLocalFunction
	| AstStatTypeAlias
	| AstStatTypeFunction

--- A generic type parameter (e.g., `T` in `function f<T>`).
export type AstGenericType = {
	read tag: "generic",
	read name: Token<string>,
	read equals: Token<"=">?,
	read default: AstType?,
}

--- A generic type pack parameter (e.g., `T...` in `function f<T...>`).
export type AstGenericTypePack = {
	read tag: "genericpack",
	read name: Token<string>,
	read ellipsis: Token<"...">,
	read equals: Token<"=">?,
	read default: AstTypePack?,
}

--- A named type reference node (e.g., `string`, `MyType<T>`).
export type AstTypeReference = {
	read location: Span,
	read kind: "type",
	read tag: "reference",
	read prefix: Token<string>?,
	read prefixPoint: Token<".">?,
	read name: Token<string>,
	read openParameters: Token<"<">?,
	read parameters: Punctuated<AstType | AstTypePack>?,
	read closeParameters: Token<">">?,
}

--- A boolean singleton type node (`true` or `false`).
export type AstTypeSingletonBool = {
	read location: Span,
	read kind: "type",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}

--- A string singleton type node (e.g., `"hello"`).
export type AstTypeSingletonString = {
	read location: Span,
	read kind: "type",
	read tag: "string",
	read quoteStyle: "single" | "double",
	read token: Token<string>,
}

--- A `typeof(expr)` type annotation node.
export type AstTypeTypeof = {
	read location: Span,
	read kind: "type",
	read tag: "typeof",
	read typeof: Token<"typeof">,
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}

--- A parenthesized type annotation node.
export type AstTypeGroup = {
	read location: Span,
	read kind: "type",
	read tag: "group",
	read openParens: Token<"(">,
	read type: AstType,
	read closeParens: Token<")">,
}

--- An optional type annotation node (e.g., `T?`).
export type AstTypeOptional = { read location: Span, read kind: "type", read tag: "optional", read token: Token<"?"> }

--- A union type annotation node (e.g., `A | B`).
export type AstTypeUnion = {
	read location: Span,
	read kind: "type",
	read tag: "union",
	read leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	read types: Punctuated<AstType, "|">,
}

--- An intersection type annotation node (e.g., `A & B`).
export type AstTypeIntersection = {
	read location: Span,
	read kind: "type",
	read tag: "intersection",
	read leading: Token<"&">?,
	read types: Punctuated<AstType, "&">,
}

--- An array type annotation node (e.g., `{ T }`).
export type AstTypeArray = {
	read location: Span,
	read kind: "type",
	read tag: "array",
	read openBrace: Token<"{">,
	read access: Token<"read" | "write">?,
	read type: AstType,
	read closeBrace: Token<"}">,
}

--- A computed-key indexer entry in a table type (e.g., `[K]: V`).
export type AstTableTypeItemIndexer = {
	read kind: "indexer",
	read access: Token<"read" | "write">?,
	read indexerOpen: Token<"[">,
	read key: AstType,
	read indexerClose: Token<"]">,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

--- A string-literal-keyed property entry in a table type (e.g., `["key"]: T`).
export type AstTableTypeItemStringProperty = {
	read kind: "stringproperty",
	read access: Token<"read" | "write">?,
	read indexerOpen: Token<"[">,
	read key: AstTypeSingletonString,
	read indexerClose: Token<"]">,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

--- A named property entry in a table type (e.g., `key: T`).
export type AstTableTypeItemProperty = {
	read kind: "property",
	read access: Token<"read" | "write">?,
	read key: Token,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

--- Union of all table type entry kinds.
export type AstTableTypeItem = AstTableTypeItemIndexer | AstTableTypeItemStringProperty | AstTableTypeItemProperty

--- A table type annotation node.
export type AstTypeTable = {
	read location: Span,
	read kind: "type",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableTypeItem },
	read closeBrace: Token<"}">,
}

--- A parameter in a function type annotation.
export type AstFunctionTypeParameter = {
	read location: Span,
	read name: Token?,
	read colon: Token<":">?,
	read type: AstType,
}

-- A type representing a Luau function
--- A function type annotation node.
export type AstTypeFunction = {
	read location: Span,
	read kind: "type",
	read tag: "function",
	read openGenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericPacks: Punctuated<AstGenericTypePack>?,
	read closeGenerics: Token<">">?,
	read openParens: Token<"(">,
	read parameters: Punctuated<AstFunctionTypeParameter>,
	read vararg: AstTypePack?,
	read closeParens: Token<")">,
	read returnArrow: Token<"->">,
	read returnTypes: AstTypePack,
}

--- Union of all type annotation node types in the Luau AST.
export type AstType =
	| AstTypeReference
	| AstTypeSingletonBool
	| AstTypeSingletonString
	| AstTypeTypeof
	| AstTypeGroup
	| AstTypeUnion
	| AstTypeIntersection
	| AstTypeOptional
	| AstTypeArray
	| AstTypeTable
	| AstTypeFunction

--- An explicit type pack annotation node (e.g., `(T, U)`).
export type AstTypePackExplicit = {
	read location: Span,
	read kind: "typepack",
	read tag: "explicit",
	read openParens: Token<"(">?,
	read types: Punctuated<AstType>,
	read tailType: AstTypePack?,
	read closeParens: Token<")">?,
}

--- A generic type pack annotation node (e.g., `T...`).
export type AstTypePackGeneric = {
	read location: Span,
	read kind: "typepack",
	read tag: "generic",
	read name: Token,
	read ellipsis: Token<"...">,
}

--- A variadic type pack annotation node (e.g., `...T`).
export type AstTypePackVariadic = {
	read location: Span,
	read kind: "typepack",
	read tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	read ellipsis: Token<"...">?,
	read type: AstType,
}

--- Union of all type pack annotation node types in the Luau AST.
export type AstTypePack = AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic

--- Union of all node types in the Luau AST.
export type AstNode = AstExpr | AstStat | AstType | AstTypePack | AstLocal | AstAttribute | Token

--- The result of parsing a Luau script, containing the root block, EOF token, and source location info.
export type ParseResult = {
	read root: AstStatBlock,
	read eof: Eof,
	read lines: number,
	read lineOffsets: { number },
}

--- Parses `source` as a Luau script and returns the resulting AST.
function luau.parse(source: string): ParseResult
	error("not implemented")
end

--- Parses `source` as a single Luau expression and returns the resulting AST node.
function luau.parseExpr(source: string): AstExpr
	error("not implemented")
end

--- Compiled Luau bytecode produced by `luau.compile`.
export type Bytecode = { bytecode: string }

--- Compiles Luau `source` to bytecode.
function luau.compile(source: string): Bytecode
	error("not implemented")
end

--- Loads `bytecode` into a callable function. `chunkname` names the chunk for error messages. An optional `env` table can override the global environment.
function luau.load(bytecode: Bytecode, chunkname: string, env: { [any]: any }?): (...any) -> ...any
	error("not implemented")
end

--- Resolves the require path `path` relative to `fromchunkname`, returning the absolute path.
function luau.resolveModule(path: string, fromchunkname: string): string
	error("not implemented")
end

--- A resolved Luau type, as returned by `typeofModule`.
export type Type = {
	tag: "nil"
		| "unknown"
		| "never"
		| "any"
		| "boolean"
		| "number"
		| "string"
		| "buffer"
		| "thread"
		| "singleton"
		| "negation"
		| "union"
		| "intersection"
		| "table"
		| "function"
		| "extern"
		| "generic",

	-- for singleton type
	value: string | boolean | nil,

	-- for negation type
	inner: Type,

	-- for union and intersection types
	components: { Type },

	-- for table type
	properties: { [string]: { read: Type?, write: Type? } },
	indexer: { index: Type }?, -- TODO: add readresult and writeresult
	-- TODO: readindexer: { index: type, result: type } }?,
	-- TODO: writeindexer: { index: type, result: type } }?,
	metatable: Type?,

	-- for function type
	parameters: TypePack,
	argnames: { string? },
	returns: TypePack,
	generics: { Type },
	genericpacks: { TypePack },

	-- for extern type
	-- 'properties', 'metatable' are shared with table type
	parent: Type?,

	-- for generic type
	name: string,
	ispack: boolean,
}

--- A resolved Luau type pack, as returned by `typeofModule`.
export type TypePack = {
	tag: "typepack" | "variadic" | "generic",
	head: { Type }?,
	tail: TypePack?,

	-- for variadic type packs
	type: Type,
	hidden: boolean,

	-- for generic type packs
	name: string,
	ispack: boolean,
}

--- Returns the type pack representing the return types of the module at `modulepath`, or `nil` if unavailable.
function luau.typeofModule(modulepath: string): TypePack?
	error("not implemented")
end

return luau
]==],["lute/crypto.luau"] = [==[-- lute-lint-global-ignore(unused_variable)
local crypto = {}

export type Hash<T> = { __hash: T }

crypto.hash = table.freeze({
	md5 = {} :: Hash<"md5">,
	sha1 = {} :: Hash<"sha1">,
	sha256 = {} :: Hash<"sha256">,
	sha512 = {} :: Hash<"sha512">,
	blake2b256 = {} :: Hash<"blake2b256">,
})

--- Computes a cryptographic hash of `message` using the given `hash` algorithm. Returns the hash as a buffer.
function crypto.digest(hash: Hash<any>, message: string | buffer): buffer
	error("not implemented")
end

crypto.secretbox = {}

--- A sealed message containing the encrypted ciphertext, nonce, and key.
export type SecretBox = {
	read ciphertext: buffer,
	read nonce: buffer,
	read key: buffer,
}

--- Generates a new random secret key for use with `secretbox.seal`.
function crypto.secretbox.keygen(): buffer
	error("not implemented")
end

--- Encrypts `message` with `key` (or a freshly generated key if omitted). Returns a `SecretBox`.
function crypto.secretbox.seal(message: string | buffer, key: buffer?): SecretBox
	error("not implemented")
end

--- Decrypts `box` and returns the original plaintext as a buffer.
function crypto.secretbox.open(box: SecretBox): buffer
	error("not implemented")
end

crypto.password = {}

--- Hashes `password` using a slow, memory-hard algorithm suitable for password storage. Returns the hash as a buffer.
function crypto.password.hash(password: string): buffer
	error("not implemented")
end

--- Verifies that `password` matches the stored `hash`. Returns `true` if the password is correct.
function crypto.password.verify(hash: buffer, password: string): boolean
	error("not implemented")
end

return crypto
]==],["std/stringext.luau"] = [==[--!strict
-- @std/stringext
-- stdlib for an extension of the built-in string library in Luau
-- Provides additional utility functions for string operations

local stringext = {}

--- Returns `true` if `str` begins with `prefix`.
function stringext.hasPrefix(str: string, prefix: string): boolean
	if #prefix > #str then
		return false
	end

	return str:sub(1, #prefix) == prefix
end

--- Returns `str` with `prefix` removed from the front. If `str` does not start with `prefix`, returns `str` unchanged.
function stringext.removePrefix(str: string, prefix: string): string
	if not stringext.hasPrefix(str, prefix) then
		return str
	end

	return str:sub(#prefix + 1)
end

--- Returns `true` if `str` ends with `suffix`.
function stringext.hasSuffix(str: string, suffix: string): boolean
	return str:sub(-#suffix) == suffix
end

--- Returns `str` with `suffix` removed from the end. If `str` does not end with `suffix`, returns `str` unchanged.
function stringext.removeSuffix(str: string, suffix: string): string
	if not stringext.hasSuffix(str, suffix) then
		return str
	end

	return str:sub(0, -#suffix - 1)
end

--- Returns `str` with leading and trailing whitespace removed.
function stringext.trim(str: string): string
	-- Pattern is guaranteed to return a result
	return str:match("^%s*(.-)%s*$") :: string
end

--- Counts the number of occurrences of `pattern` in `str`, optionally restricted to the range `[startPos, endPos]`.
function stringext.count(str: string, pattern: string, startPos: number?, endPos: number?): number
	if startPos and endPos then
		str = str:sub(startPos, endPos)
	elseif startPos then
		str = str:sub(startPos)
	elseif endPos then
		str = str:sub(1, endPos)
	end

	local count = 0
	for _ in str:gmatch(pattern) do
		count += 1
	end

	return count
end

return table.freeze(stringext)
]==],}