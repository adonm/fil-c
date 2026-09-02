--!nonstrict

-- Cross-function jumps (x86_64): tail branches to function entries (class B1,
-- the call+epilogue conversion) and mid-body shared-tail joins (class B2,
-- region cloning), plus ALIAS ENTRY LABELS (multiple names at one function's
-- entry). This is the OpenSSL perlasm cross-function-jump shape (the complete
-- table lives in the perlasm analysis): dispatcher functions capability-check
-- and then `jnz variant` / `jmp variant` to same-file ISA-variant bodies or
-- exported functions, and a handful of functions jump into the middle of a
-- sibling's tail, sharing register state (x25519 .Lreduce51/.Lreduce64, ecp
-- .Lpoint_double_shortcut[qx], chacha .Ldo_sse3_after_all, mont5
-- .Lsqr4x_sub_entry).
--
-- B1 — tail branch to a signatured function entry (or extern symbol with an
-- inline signature annotation): the jump is rewritten as an ordinary annotated
-- CALL to that function (full Fil-C CC marshalling of the current SysV
-- arg-register webs — exactly like any annotated call; the webs trace to the
-- jumper's own entry unpacking, correct by construction for the corpus dispatch
-- shapes, which jump before the argument registers are repurposed), immediately
-- followed by a jump to the function's shared synthetic epilogue block
-- (`.Ltailret_<fn>: ret`). The callee's return value becomes the jumper's
-- return value (the call's result web reaches the epilogue's `ret`, which the
-- ordinary return path moves into the fast-CC return registers). A conditional
-- jump synthesizes a via block: `jcc .Lvia; <fallthrough>; .Lvia: call ...;
-- jmp .Ltailret`. The jump site may sit at any virtual frame depth: the body's
-- stack is virtualized, so the epilogue (which owns the real rsp) tears down
-- correctly regardless — the synthetic `ret` carries the st.tailRet mark, which
-- exempts the frame pass's depth-0-at-ret proof gate (the exemption is sound:
-- the emitted epilogue restores the sarcasm frame, never the body's virtual
-- one). Dense argument words beyond the four fast-CC registers travel on the
-- stack at the call; for a tail call those words must be the jumper's OWN
-- incoming SysV stack arguments (a hardware `jmp` passes them through in
-- place), so the synthetic call is marked st.tailCall and the marshalling
-- sources its 7th+ argument webs from the yolo incoming-argument slots instead
-- of the outgoing-argument frame slots (transform.luau's callArgSource).
--
-- B2 — tail branch into a MID-BODY label of another same-file function (or of a
-- local subroutine): the region [target label .. the region's ret(s)] is cloned
-- into the JUMPER (renamed labels appended to its body, reusing the localcall
-- cloning style): the jump targets the clone entry, and the clone's rets stay
-- PLAIN rets — a shared-tail join returns from the jumper (hardware: the ret
-- pops the jumper's own return address, since a `jmp` pushed nothing). There is
-- NO -8 clone bias for B2 (the localcall +8 return-address compensation applies
-- to CALL-clones only: a `jmp` keeps rsp unchanged, so the clone's stack
-- accesses key into the jumper's frame at the jumper's own depth, and the
-- frame pass's ordinary checks reject genuine depth mismatches). Local calls
-- inside the cloned region are cloned transitively (they are recorded into the
-- localcall discovery's per-function callsite list, so the ordinary augment
-- clones their subroutines and marks them). Register state is shared by
-- construction — that is the point of a mid-body join.
--
-- A tail join FROM INSIDE a local subroutine (mont5's mul4x/mulx4x_internal
-- `jmp .Lsqr4x_sub_entry` into __bn_post4x_internal's tail) is discovered by
-- localcall.discover as a "tailjoin" edge and cloned by localcall.augment: the
-- tail clone's statements ride the jumping subroutine's clone context (the +8
-- bias — the tail executes inside the subroutine's activation, whose caller DID
-- push a return address) and its rets dispatch to the JUMPING subroutine's
-- continuations (hardware: the ret pops the jumping subroutine's return
-- address). This module provides the shared region computation for both
-- integration points.
--
-- ALIAS ENTRY LABELS: a label immediately adjacent to a signature-annotated
-- function label (nothing between them but blanks, non-data directives and
-- CET/nop markers) names the same entry — asm_AES_encrypt:/AES_encrypt:,
-- .Lenc_rounds:/Camellia_EncryptBlock_Rounds:, and the following-label forms
-- sha1_block_data_order_shaext:/_shaext_shortcut:,
-- gcm_init_clmul:/.L_init_clmul:. Jumps (and annotated calls) to the alias
-- resolve to the owning function; a .globl alias additionally gets its own
-- getter/direct-call alias emission so C callers of the alias link (the
-- splitFunctions integration lives in sarcasm.luau, the emission in the glue
-- modules).
--
-- arm64: none of this runs there — an annotated jump reaches validateBody's
-- annotation walk, which rejects it with a clean "not yet supported" error.

local x86_64_isa = require("./x86_64_isa")
local sig = require("./sig")
local transform = require("./transform")

local tailcall = {}

local SECTION_DIRECTIVES = {
	[".section"] = true, [".text"] = true, [".data"] = true, [".rodata"] = true,
	[".bss"] = true, [".previous"] = true,
	[".pushsection"] = true, [".popsection"] = true,
}

local function isRetMnem(m)
	return x86_64_isa.baseMnemonic(string.lower(m or "")) == "ret"
end

-- Is the mnemonic a DIRECT jump (conditional or unconditional)? loop* classifies
-- as a conditional branch too, but it carries an implicit counter register —
-- cross-function loop branches are deliberately NOT rewritten (they keep the
-- ordinary "leaves the function" rejection), so this returns nil for them.
local function jumpKind(mnemonic)
	local b = x86_64_isa.baseMnemonic(string.lower(mnemonic or ""))
	if b == "jmp" then return "jmp" end
	if b == "jcc" then return "jcc" end
	return nil
end

local function branchTargetSym(st)
	local op = st.operands and st.operands[1]
	if op and op.kind == "sym" then return op.text end
	return nil
end

-- A potentially-local call (a direct call with a bare-symbol target, unannotated
-- or carrying the explicit `#! local` marker) — mirrors localcall.luau.
local function localCallTarget(st)
	if st.kind ~= "insn" then return nil end
	local m = string.lower(st.mnemonic or "")
	if m ~= "call" and m ~= "callq" then return nil end
	if st.annotation ~= nil and st.annotation ~= "local" then return nil end
	local op = st.operands and st.operands[1]
	if op and op.kind == "sym" then return op.text end
	return nil
end
tailcall.localCallTarget = localCallTarget

-- Alias entry labels: scan for labels immediately adjacent to a
-- signature-annotated function label. Returns aliases[name] = { owner = <entry
-- label name>, where = "pre" | "post" }. A label PRECEDING the annotated label
-- (asm_AES_encrypt, .Lenc_rounds) aliases it; so does a label FOLLOWING it
-- (_shaext_shortcut, .L_init_clmul) when only transparent content intervenes
-- (blanks, non-data non-section directives, CET/nop marker instructions) — the
-- skipped no-ops make a jump to the following alias exactly equivalent to
-- entering the function.
function tailcall.scanAliases(stmts, arch)
	local function hasSig(st)
		return st.kind == "label" and st.annotation ~= nil
			and string.find(st.annotation, "%(") ~= nil
	end
	local function transparent(st)
		if st.kind == "blank" then return true end
		if st.kind == "label" then return not hasSig(st) end
		if st.kind == "directive" then
			if SECTION_DIRECTIVES[st.name] then return false end
			if transform.DATA_DIRECTIVES[st.name] then return false end
			return true
		end
		if st.kind == "insn" then
			local m = string.lower(st.mnemonic or "")
			if arch == "arm64" then return m == "nop" end
			return x86_64_isa.baseMnemonic(m) == "nop"
		end
		return false
	end
	local aliases = {}
	for i, st in stmts do
		if hasSig(st) then
			local j = i - 1
			while j >= 1 and transparent(stmts[j]) do
				if stmts[j].kind == "label" then
					aliases[stmts[j].name] = { owner = st.name, where = "pre" }
				end
				j -= 1
			end
			j = i + 1
			while j <= #stmts and transparent(stmts[j]) do
				if stmts[j].kind == "label" and not aliases[stmts[j].name] then
					aliases[stmts[j].name] = { owner = st.name, where = "post" }
				end
				j += 1
			end
		end
	end
	return aliases
end

-- Deep-copy a statement (operands recursively). B2 shared-tail regions are
-- extracted from PRISTINE copies of the owner bodies: the transform rewrites
-- some memory operands IN PLACE (the alloca-region redirect substitutes the
-- region-pointer temp for the stack base register), so a body whose owner was
-- already compiled is no longer a valid clone source for a later jumper.
local function deepCopyOp(op)
	if type(op) ~= "table" then return op end
	local cp = {}
	for k, v in pairs(op) do
		if k == "base" or k == "index" then cp[k] = deepCopyOp(v) else cp[k] = v end
	end
	return cp
end

local function deepCopyStmt(st)
	if st.kind == "insn" then
		local cp = {}
		for k, v in pairs(st) do cp[k] = v end
		if st.operands then
			local ops = {}
			for i, op in st.operands do ops[i] = deepCopyOp(op) end
			cp.operands = ops
		end
		return cp
	end
	if st.kind == "label" then
		return { kind = "label", name = st.name, line = st.line, annotation = st.annotation }
	end
	return st
end

-- Build the cross-jump resolution context. `functions` is the splitFunctions
-- result (bodies already .byte-decoded on x86_64), `aliases` the scanAliases
-- result (already filtered by splitFunctions to the labels it accepted),
-- `locals` the localcall discovery result (or nil).
function tailcall.buildContext(functions, aliases, locals)
	local ctx = {
		fnSigs = {},      -- function name -> its signature annotation text
		fnByName = {},    -- function name -> its splitFunctions record
		fnLabels = {},    -- mid-body label name -> { fn = <record>, pos = <body index> }
		fnBodies = {},    -- function name -> PRISTINE copy of its body statements
		subLabels = {},   -- subroutine-region label name -> { name, pos, stmts }
		aliases = aliases or {},
		regions = {},     -- B2 shared-tail region cache: source\0label -> descriptor
	}
	for _, fn in functions do
		ctx.fnSigs[fn.name] = fn.sigAnn
		ctx.fnByName[fn.name] = fn
		local pristine = {}
		for pos, st in fn.body do
			pristine[pos] = deepCopyStmt(st)
			if st.kind == "label" and pos ~= 1 and not ctx.fnLabels[st.name] then
				ctx.fnLabels[st.name] = { fn = fn, pos = pos }
			end
		end
		ctx.fnBodies[fn.name] = pristine
	end
	if locals then
		for name, sub in locals.subs do
			local r = sub.region
			for pos, st in r.stmts do
				if st.kind == "label" and not ctx.subLabels[st.name] then
					ctx.subLabels[st.name] = { name = name, pos = pos, stmts = r.stmts }
				end
			end
		end
	end
	return ctx
end

-- Compute the shared-tail region of a source (a function body or a local
-- subroutine's region) reached from `entryLabel`: the statements REACHABLE from
-- the entry label (following fall-through and in-source branch targets — which
-- may name labels BEFORE the entry, like mont5's .Lsqr4x_sub loop head), in
-- source order. Every reachable branch must stay inside the source (a branch
-- out is a nested cross-function jump — rejected; local CALLS pass through and
-- are cloned transitively), no path may fall off the end, and no branch may
-- re-enter the owner's own entry label. Results are cached per (source, label)
-- in ctx.regions (validation errors therefore fire at most once, at the first
-- jumper in file order — deterministic).
function tailcall.computeRegion(ctx, srcName, srcStmts, srcEntryName, entryLabel, entryPos, jumperName)
	local key = srcName .. "\0" .. entryLabel
	local cached = ctx.regions[key]
	if cached then return cached end
	local labelPos = {}
	for pos, st in srcStmts do
		if st.kind == "label" then
			if not labelPos[st.name] then labelPos[st.name] = {} end
			table.insert(labelPos[st.name], pos)
		end
	end
	local reachable, work = {}, { entryPos }
	local retPos = {}
	while #work > 0 do
		local pos = table.remove(work)
		if not reachable[pos] then
			reachable[pos] = true
			if pos <= #srcStmts then
				local st = srcStmts[pos]
				local ft = true
				if st.kind == "insn" then
					if isRetMnem(st.mnemonic) then
						ft = false
						retPos[pos] = true
					else
						local jk = jumpKind(st.mnemonic)
						local isLoop = string.match(string.lower(st.mnemonic or ""), "^loop") ~= nil
						if jk or isLoop then
							local t = branchTargetSym(st)
							if t then
								if not labelPos[t] then
									error("sarcasm: branch to '" .. t .. "' in the shared tail of '"
										.. srcName .. "' (joined from '" .. jumperName .. "') leaves"
										.. " the region (nested cross-function jumps are not"
										.. " supported): " .. (st.raw or st.mnemonic))
								end
								if t == srcEntryName then
									error("sarcasm: branch to '" .. t .. "' in the shared tail of '"
										.. srcName .. "' re-enters the function's entry (cannot be"
										.. " cloned): " .. (st.raw or st.mnemonic))
								end
								for _, p in labelPos[t] do table.insert(work, p) end
							end
							ft = (jk == "jcc") or isLoop
						end
					end
				end
				if ft then table.insert(work, pos + 1) end
			end
		end
	end
	if reachable[#srcStmts + 1] then
		error("sarcasm: the shared tail of '" .. srcName .. "' from '" .. entryLabel
			.. "' (joined from '" .. jumperName .. "') can fall off its end; every"
			.. " control-flow path must end with a ret instruction")
	end
	local stmts, rets, calls = {}, {}, {}
	for pos = 1, #srcStmts do
		if reachable[pos] then
			local st = srcStmts[pos]
			table.insert(stmts, st)
			if retPos[pos] then rets[#stmts] = true end
			local t = localCallTarget(st)
			if t then calls[#stmts] = t end
		end
	end
	local region = { srcName = srcName, entryLabel = entryLabel,
		stmts = stmts, rets = rets, calls = calls }
	ctx.regions[key] = region
	return region
end

-- Operand/statement copying with in-clone label renaming (mirrors
-- localcall.augment: regions are shared across jumpers and downstream passes
-- rewrite operands in place, so every cloned operand table must be fresh). No
-- localcall marks are applied here — a top-level B2 clone's statements are
-- ordinary jumper statements (NO -8 bias: a `jmp` pushed nothing).
local function copyOp(op, ren)
	if type(op) ~= "table" then return op end
	local cp = {}
	for k, v in pairs(op) do
		if k == "base" or k == "index" then
			cp[k] = copyOp(v, ren)
		elseif (k == "text" and op.kind == "sym") or k == "dispSym" then
			cp[k] = ren[v] or v
		else
			cp[k] = v
		end
	end
	return cp
end

local function cloneStmt(st, ren)
	if st.kind == "label" then
		return { kind = "label", name = ren[st.name], line = st.line }
	end
	if st.kind == "insn" then
		local cp = {}
		for k, v in pairs(st) do cp[k] = v end
		if st.operands then
			local ops = {}
			for i, op in st.operands do ops[i] = copyOp(op, ren) end
			cp.operands = ops
		end
		return cp
	end
	return st   -- blanks/directives are never mutated downstream
end
tailcall.cloneStmt = cloneStmt

-- Rewrite one function's cross-function jumps. Returns the (possibly new) body.
-- B1 sites become annotated calls + epilogue jumps (via blocks for conditional
-- jumps); B2 sites are retargeted to per-jumper clones of the shared tails.
-- Local calls inside B2 clones are recorded into locals.callsByFn[fnName] so
-- localcall.augment (which runs after this) clones their subroutines.
-- `userLabels` is the file-global user-label set (synthesized names are bumped
-- past it). DETERMINISM: sites are processed in body order, synthesized labels
-- derive from the function/owner/label names with a per-function counter.
function tailcall.rewriteFunction(fnName, body, ctx, locals, userLabels)
	local localLabels = {}
	for _, st in body do
		if st.kind == "label" then localLabels[st.name] = true end
	end

	-- Classify every direct jump out of the body (in body order).
	local sites = {}
	for _, st in body do
		if st.kind == "insn" then
			local jk = jumpKind(st.mnemonic)
			if jk then
				local t = branchTargetSym(st)
				if t and not localLabels[t] then
					local ann = st.annotation
					local hasSigAnn = ann and string.find(ann, "%(") ~= nil
					local owner = ctx.aliases[t]
					local callTarget, sigAnn = nil, nil
					if owner and owner ~= fnName and ctx.fnSigs[owner] then
						-- jump to an alias entry label: resolve to the owning function
						callTarget, sigAnn = owner, ctx.fnSigs[owner]
					elseif ctx.fnSigs[t] and t ~= fnName then
						-- jump straight to a signatured function's entry label
						callTarget, sigAnn = t, ctx.fnSigs[t]
					elseif hasSigAnn and not owner and not ctx.fnSigs[t]
						and not ctx.fnLabels[t] and not ctx.subLabels[t] then
						-- extern symbol carrying an inline signature annotation
						callTarget, sigAnn = t, ann
					end
					if callTarget then
						table.insert(sites, { stmt = st, kind = "b1", jk = jk,
							callTarget = callTarget, sigAnn = sigAnn })
					elseif not hasSigAnn then
						local fl = ctx.fnLabels[t]
						local sl = ctx.subLabels[t]
						if fl and fl.fn.name ~= fnName then
							table.insert(sites, { stmt = st, kind = "b2", jk = jk, target = t,
								srcName = fl.fn.name, srcStmts = ctx.fnBodies[fl.fn.name],
								srcEntry = fl.fn.name, entryPos = fl.pos })
						elseif sl then
							table.insert(sites, { stmt = st, kind = "b2", jk = jk, target = t,
								srcName = sl.name, srcStmts = sl.stmts,
								srcEntry = sl.name, entryPos = sl.pos })
						end
					end
				end
			end
		end
	end
	if #sites == 0 then return body end

	-- Fresh-label allocator, bumped past every user label in the file.
	local used = {}
	for n in (userLabels or {}) do used[n] = true end
	local function fresh(base)
		local nm, k = base, 0
		while used[nm] do k += 1; nm = base .. "_" .. k end
		used[nm] = true
		return nm
	end

	local mySig = sig.parseSignature(ctx.fnSigs[fnName])
	local tailRet = nil
	local function ensureTailRet()
		if not tailRet then tailRet = fresh(".Ltailret_" .. fnName) end
		return tailRet
	end
	local function callStmt(site, line)
		-- A pointer-returning function may not tail-call a non-pointer-returning
		-- one: the callee's result would become the jumper's return value with a
		-- silently-null capability. (Every other return-shape combination is
		-- hardware-faithful — the result registers pass through unchanged.)
		local cs = sig.parseSignature(site.sigAnn)
		if mySig.retIsPtr and not cs.retIsPtr then
			error("sarcasm: tail call to '" .. site.callTarget .. "' in function '" .. fnName
				.. "' does not return a pointer, but '" .. fnName .. "' returns one (the"
				.. " callee's return value becomes the caller's): " .. (site.stmt.raw or ""))
		end
		return { kind = "insn", mnemonic = "call",
			operands = { { kind = "sym", text = site.callTarget } },
			annotation = site.sigAnn, raw = "call\t" .. site.callTarget, line = line,
			tailCall = true }
	end

	local newBody, tail = {}, {}
	local viaCount = 0
	local clones = {}   -- B2 clone cache for THIS function: source\0label -> { entry, stmts }
	local function b2Clone(site)
		local key = site.srcName .. "\0" .. site.target
		local cl = clones[key]
		if cl then return cl end
		local region = tailcall.computeRegion(ctx, site.srcName, site.srcStmts,
			site.srcEntry, site.target, site.entryPos, fnName)
		local ren = {}
		for _, st in region.stmts do
			if st.kind == "label" then
				ren[st.name] = fresh(".Ltailjoin_" .. fnName .. "_" .. site.srcName .. "_" .. st.name)
			end
		end
		local stmts = {}
		for idx, st in region.stmts do
			local cp = cloneStmt(st, ren)
			if idx == 1 then
				-- validateBody: the clone's FIRST statement is reached only
				-- through branches (the cross-jump edge or a backward branch
				-- inside the region — mont5's .Lsqr4x_sub loop head precedes
				-- the join label, and the region's own text falls THROUGH the
				-- join label, which must NOT carry this mark): falling INTO it
				-- means the preceding body fell off its end.
				cp.crossJumpEntry = true
			end
			table.insert(stmts, cp)
			-- Clone local calls transitively: record them for localcall.augment.
			local tgt = region.calls[idx]
			if tgt and locals and locals.subs[tgt] then
				local l = locals.callsByFn[fnName]
				if not l then l = {}; locals.callsByFn[fnName] = l end
				table.insert(l, { stmt = cp, target = tgt })
			end
		end
		cl = { entry = ren[site.target], stmts = stmts }
		clones[key] = cl
		for _, cst in stmts do table.insert(tail, cst) end
		return cl
	end

	local siteByStmt = {}
	for _, s in sites do siteByStmt[s.stmt] = s end
	for _, st in body do
		local s = siteByStmt[st]
		if not s then
			table.insert(newBody, st)
		elseif s.kind == "b1" and s.jk == "jmp" then
			-- Unconditional tail branch: call the target, then jump to the
			-- epilogue (the return path).
			local tr = ensureTailRet()
			table.insert(newBody, callStmt(s, st.line))
			table.insert(newBody, { kind = "insn", mnemonic = "jmp",
				operands = { { kind = "sym", text = tr } }, raw = "jmp\t" .. tr, line = st.line })
		elseif s.kind == "b1" then
			-- Conditional tail branch: jcc .Lvia_K; <fallthrough>; the via block
			-- (appended) calls the target and jumps to the epilogue. The
			-- annotation moves from the jump to the synthesized call.
			viaCount += 1
			local via = fresh(".Ltailcall_" .. fnName .. "_via" .. viaCount)
			local tr = ensureTailRet()
			local cp = {}
			for k, v in pairs(st) do cp[k] = v end
			cp.operands = { { kind = "sym", text = via } }
			cp.annotation = nil
			table.insert(newBody, cp)
			table.insert(tail, { kind = "label", name = via, crossJumpEntry = true })
			table.insert(tail, callStmt(s, st.line))
			table.insert(tail, { kind = "insn", mnemonic = "jmp",
				operands = { { kind = "sym", text = tr } }, raw = "jmp\t" .. tr, line = st.line })
		else
			-- B2 mid-body join: retarget the jump to the per-jumper clone's entry.
			local cl = b2Clone(s)
			local cp = {}
			for k, v in pairs(st) do cp[k] = v end
			cp.operands = { { kind = "sym", text = cl.entry } }
			table.insert(newBody, cp)
		end
	end
	for _, blk in tail do table.insert(newBody, blk) end
	if tailRet then
		-- The shared synthetic epilogue block: an ordinary `ret` (the transform's
		-- return path emits the frame teardown), marked so the frame pass exempts
		-- its depth-0 proof gate — the jump site may sit at any virtual depth.
		table.insert(newBody, { kind = "label", name = tailRet, crossJumpEntry = true })
		table.insert(newBody, { kind = "insn", mnemonic = "ret", operands = {},
			raw = "ret", tailRet = true })
	end
	return newBody
end

return tailcall
