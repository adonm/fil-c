--!nonstrict
-- The GIMSO transform (architecture-independent): rewrite a lifted yolo function into a
-- memory-safe Fil-C fast-entrypoint body (IR nodes), plus metadata for glue/prologue/
-- epilogue emission. The walk and every invisicap sequence (access checks, pointer loads/
-- stores with the FUGC store barrier, atomic pointer loads/stores/compare-exchange and
-- pointer RMWs via the Fil-C runtime, calls, pollchecks, allocations) live here ONCE; the
-- actual instructions are produced through a per-arch codegen `cg` (arm64_codegen /
-- x86_64_codegen), so the safety-critical logic is single-source across ISAs. (The
-- atomic pointer operations are shared: both backends implement their annotations —
-- x86_64 with cmpxchg/movq forms and SysV marshalling, arm64 with cas/LSE forms and
-- AAPCS64 marshalling — except `;! load store ptr`, which arm64 rejects for lack of
-- a non-atomic memory-destination RMW instruction.)
--
-- transformFunction(name, sigDesc, body, backend) where backend = { cg = <codegen module>,
-- frame = <frame module> }.

local lift = require("./lift")
local ptrflow = require("./ptrflow")
local sig = require("./sig")
local build = require("./build")
local framePass = require("./frame")

local transform = {}

-- `;! alloca ...` annotation parser (architecture-independent).
local function parseAlloca(ann)
	if not ann then return nil end
	local n = string.match(ann, "^alloca%s+size%s*%(%s*(.-)%s*%)$")
	if n then return { kind = "size", name = n } end
	local rn = string.match(ann, "^alloca%s+result%s*%(%s*(.-)%s*%)$")
	if rn then return { kind = "result", name = rn } end
	local sz = string.match(ann, "^alloca%s+result%s+size=(%w+)$")
	if sz then
		local v = tonumber(sz)
		if not v then error("sarcasm: bad alloca size literal: " .. sz) end
		return { kind = "resultSize", size = v }
	end
	if string.find(ann, "alloca", 1, true) then
		error("sarcasm: unrecognized alloca annotation: " .. ann)
	end
	return nil
end

-- The register operand of a store that is not the memory operand (the stored value).
local function storeValueOperand(stmt, mem)
	for _, op in stmt.operands do
		if op.kind == "reg" and op ~= mem then return op end
	end
	return nil
end

-- Directives that EMIT data (or define symbols/macros as values). sarcasm compiles
-- functions only: such content — whether inside a function body (literal pools, jump
-- tables) or between functions (data sections) — cannot be given a capability
-- automatically, so it is rejected rather than silently dropped. Shared with the
-- driver-level top-level scan in sarcasm.luau. (Enforced on arm64 only — see
-- strictBodyValidation / the arch gate in sarcasm.luau.)
local DATA_DIRECTIVES = {}
for _, d in {
	".word", ".xword", ".quad", ".long", ".int", ".short", ".hword",
	".2byte", ".4byte", ".8byte", ".byte", ".ascii", ".asciz", ".string",
	".zero", ".space", ".fill", ".float", ".single", ".double", ".inst",
	".dc", ".dc.b", ".dc.l", ".dc.s", ".dc.w", ".dc.x", ".dcb", ".dcb.b",
	".dcb.l", ".dcb.s", ".dcb.w", ".dcb.x", ".ds", ".skip",
	".equ", ".set", ".macro", ".comm", ".common", ".lcomm",
} do DATA_DIRECTIVES[d] = true end
transform.DATA_DIRECTIVES = DATA_DIRECTIVES

-- Validate a function's RAW body before the frame pass runs (the frame pass rewrites
-- stack accesses, stripping annotations from the statements it virtualizes, so
-- annotation validation must see the original statements). ARM64-only (gated on
-- cgm.strictBodyValidation — the x86_64 backend deliberately keeps its historical
-- acceptance of unannotated calls, tail branches and looser annotation placement):
--  * unannotated `bl`/`call` are rejected (raw calls are not marshalled); indirect
--    calls and indirect branches are handled by the shared annotation walk below
--    (a REGISTER-indirect call with a signature annotation is supported there —
--    on both architectures — while a memory-operand or unannotated one is
--    rejected; every register-target branch classifies as an indirect branch and
--    is rejected too);
--  * `b`/cond-branch to a non-local target is a tail call — not yet supported;
--  * every `;!` annotation must be a recognized form (alloca family, a ptr
--    annotation with a valid instruction shape, or a callsite signature on a call);
--  * a `;!` annotation on a mid-body label, an empty line, or a directive is
--    rejected (only the function-entry label carries the signature — any other
--    non-instruction annotation would be silently dropped);
--  * data-emitting directives inside the body are rejected;
--  * arch-specific forged-address instructions (adrp/adr/ldr-literal) are rejected.
local function validateBody(body, cgm)
	local localLabels = {}
	for _, st in body do
		if st.kind == "label" then localLabels[st.name] = true end
	end
	for _, st in body do
		if st.kind == "blank" then
			-- an annotation all alone on its line is a typo (the annotation belongs on
			-- the instruction's own line) — silently dropping it could skip a barrier.
			if st.annotation then
				error("sarcasm: ;! annotation '" .. st.annotation
					.. "' on an otherwise-empty line (annotations go on the instruction's own line)")
			end
		elseif st.kind == "label" then
			-- The function-entry label (body[1]) carries the ;! signature. An annotation
			-- on any other label would be silently ignored (annotations are consumed from
			-- instructions only), so reject it like the blank-line case.
			if st.annotation and st ~= body[1] then
				error("sarcasm: ;! annotation '" .. st.annotation .. "' on a label ('" .. st.name
					.. "') inside a function body is not supported (only the function-entry label"
					.. " carries the ;! signature; instruction annotations go on the instruction's"
					.. " own line)")
			end
		elseif st.kind == "directive" then
			if DATA_DIRECTIVES[st.name] then
				error("sarcasm: data in a function body is not supported (literal pools,"
					.. " jump tables and constants cannot be made memory-safe automatically): directive '"
					.. st.name .. "'")
			end
			if st.annotation then
				error("sarcasm: ;! annotation '" .. st.annotation .. "' on a directive ('"
					.. st.name .. "') is not supported")
			end
		elseif st.kind == "insn" then
			local c = cgm.classify(st)
			local ann = st.annotation
			local raw = st.raw or st.mnemonic
			if c.control == "call" then
				if not ann then
					local callee = st.operands and st.operands[1] and st.operands[1].text or "?"
					error("sarcasm: call to '" .. callee .. "' has no ;! signature annotation"
						.. " (annotate the callsite, e.g. `" .. string.lower(st.mnemonic) .. " "
						.. callee .. " ;! int(ptr)`): " .. raw)
				end
			elseif c.control == "indcall" then
				-- An indirect call is validated by the SHARED annotation walk below
				-- (memory-operand, missing-annotation and target-must-be-a-pointer
				-- rejections), so nothing is rejected here: on both architectures a
				-- register-indirect call with a signature annotation is supported,
				-- and every other indirect call shape is rejected by the walk.
			elseif c.control == "indirect" then
				error("sarcasm: indirect branch through a raw register cannot be made memory-safe"
					.. " (computed goto / switch jump tables are not supported): " .. raw)
			elseif (c.control == "branch" or c.control == "condbranch") and c.targets then
				for _, t in c.targets do
					if not localLabels[t] then
						error("sarcasm: branch to '" .. t .. "' leaves the function"
							.. " (a tail call); tail calls are not yet supported: " .. raw)
					end
				end
			end
			if ann then
				if parseAlloca(ann) then
					-- alloca family: validated/consumed by the transform below
				elseif ann == "load ptr" then
					cgm.validatePtrAccess(st, "load")
				elseif ann == "store ptr" then
					cgm.validatePtrAccess(st, "store")
				elseif sig.PTR_ANNOTATIONS[ann] then
					-- atomic/pointer-RMW family: the per-arch shape validator runs;
					-- the transform's annotation walk re-validates later.
					if cgm.ptrAtomicShape then cgm.ptrAtomicShape(ann, st) end
				elseif c.control == "call" or c.control == "indcall" then
					-- callsite signature (direct or register-indirect call): parse now
					-- to reject malformed sigs early (the transform re-parses via
					-- callSigOf when marshalling).
					sig.parseSignature(ann)
				elseif string.find(ann, "%(") then
					error("sarcasm: signature annotation '" .. ann
						.. "' on a non-call instruction is not supported: " .. raw)
				elseif ann == "" then
					error("sarcasm: empty ;! annotation: " .. raw)
				else
					error("sarcasm: unrecognized ;! annotation '" .. ann
						.. "' (expected 'load ptr', 'store ptr', 'alloca ...', or a callsite"
						.. " signature like 'int(ptr)'): " .. raw)
				end
			end
			if cgm.checkForgedAddress then cgm.checkForgedAddress(st) end
		end
	end
end

function transform.transformFunction(name, sigDesc, body, backend)
	local cgm = backend.cg          -- codegen module (static config + make)
	local framePolicy = backend.frame  -- per-arch frame policy (analyzeFrame + rewrite)
	local cc = cgm.cc

	-- Floating-point signature classes (float/double). The arm64 backend supports
	-- them: FP args pass in v0..v7 (in declaration order among FP args, unmodeled by
	-- the GPR webs — they flow through the body verbatim) and an FP return rides in
	-- v0. The x86_64 backend rejects every FP class at signature validation (entry
	-- validation in sarcasm.luau / checkCallsiteSig here), so the FP paths below are
	-- unreachable on x86_64; the hasFp guards are defense in depth.
	local function isFp(t) return sig.isFpClass(t) end
	local retIsFp = (not sigDesc.isVoid) and isFp(sigDesc.retTypes[1])
	local function csHasFp(cs)
		if cs.retTypes[1] and isFp(cs.retTypes[1]) then return true end
		for _, t in cs.argTypes do if isFp(t) then return true end end
		return false
	end
	local function fpOrdinalOf(argTypes, k)
		local m = 0
		for i = 1, k - 1 do
			if isFp(argTypes[i]) then m += 1 end
		end
		return m
	end

	-- An FP-returning function leaves the value in v0; the body never produces a
	-- yolo GPR result (no synthetic x0 use at `ret`, like the void case — an FP-ret
	-- body may leave x0 undefined).
	local returnRegs = (sigDesc.isVoid or retIsFp) and {} or {0}
	local funcLine = (body[1] and body[1].line) or 0
	local curLine = funcLine

	-- Frame geometry (size, whether rbp/x29 is the frame pointer) is needed before the
	-- region scan: fixed alloca bases are normalized to sp-relative frame offsets, which
	-- requires frameSize. The analysis is pure; frame.preprocess re-runs it internally.
	local fctx = nil
	if framePolicy.analyzeFrame then
		-- 4th return (x86_64 only): FP/SIMD stack-slot materialization info. The
		-- signature is passed so the arm64 analysis can force the vector-save
		-- reservation for FP-signature functions (see arm64_frame.analyzeFrame).
		local fs, fpo, ufp, fpinfo = framePolicy.analyzeFrame(body, sigDesc)
		fctx = { frameSize = fs, fpOffset = fpo, usesFp = ufp, fp = fpinfo }
	end

	-- FP values ride in the v registers (arm64) even when the body itself never
	-- names a NEON register: an FP argument/return of the ENTRY signature (handled
	-- by the arm64 frame analysis above), an FP value passed BETWEEN two calls
	-- (an FP-returning call feeding an FP-argument call), or FP arguments placed
	-- for a call by the source program. Around every INJECTED runtime call the
	-- fpSave/fpRestore machinery must be active, or such a value would be silently
	-- clobbered — so force the vector-save reservation whenever any signature in
	-- play (entry or callsite) has a float/double class. (The arm64 backend
	-- supports FP signatures; the x86_64 backend rejects them at validation, so
	-- this is gated on cgm.fpSignatures and can never fire there.)
	if fctx and fctx.fp and cgm.fpSignatures and fctx.fp.saveBytes == 0 then
		local bodyUsesFp = false
		local function sigUsesFp(cs)
			if cs.retTypes[1] and isFp(cs.retTypes[1]) then return true end
			for _, t in cs.argTypes do
				if isFp(t) then return true end
			end
			return false
		end
		for _, st in body do
			if st.kind == "insn" and st.annotation and string.find(st.annotation, "%(") then
				local ok, cs = pcall(sig.parseSignature, st.annotation)
				if ok and cs and sigUsesFp(cs) then
					bodyUsesFp = true
					break
				end
			end
		end
		if bodyUsesFp then fctx.fp.saveBytes = backend.frame.VEC_SAVE_BYTES end
	end

	-- Fixed-size stack allocations establish sp-relative "regions" [base, base+size); gcc -O0
	-- re-derives the buffer address per use, so we redirect such sp math into the allocation.
	local allocaRegions = {}
	for _, st in body do
		if st.kind == "insn" then
			local al = parseAlloca(st.annotation)
			if al and al.kind == "resultSize" then
				local base = cgm.allocaRegionBase(st, fctx)
				if base then
					table.insert(allocaRegions, { base = base, size = al.size, stmt = st })
				else
					-- Without a recognized base the annotation would silently create NO
					-- region: the buffer address escapes as a bare allocation pointer while
					-- stack-relative accesses meant for the buffer virtualize into unrelated
					-- slots — a silent miscompile. Reject instead.
					error("sarcasm: `;! alloca result size=N` annotation is on an instruction"
						.. " that does not compute a stack-frame-relative address (cannot prove"
						.. " safety): " .. (st.raw or st.mnemonic))
				end
			end
		end
	end
	local function regionOf(spOff)
		for _, r in allocaRegions do
			if spOff >= r.base and spOff < r.base + r.size then return r end
		end
		return nil
	end

	-- Reject unannotated/indirect calls, tail calls, unknown/misplaced annotations,
	-- in-body data, and forged addresses BEFORE any rewriting (see validateBody).
	-- ARM64-only: cgm.strictBodyValidation is set by the arm64 backend; x86_64 has
	-- no such flag and keeps its historical acceptance exactly.
	if cgm.strictBodyValidation then
		validateBody(body, cgm)
	end

	body = framePass.preprocess(body, allocaRegions, framePolicy, sigDesc)

	-- per-call signature info
	local callSigCache = {}
	local function callSigOf(stmt)
		local ann = stmt.annotation
		if not ann then return nil end
		if callSigCache[stmt] == nil then
			local cs = sig.parseSignature(ann)
			-- Per-arch callsite arity validation (the argument marshal has a finite
			-- number of CC registers). Raises a clean sarcasm: error when over limit.
			if cgm.checkCallsiteSig then
				-- a direct call names a symbol; an indirect call's target register
				-- has a register name instead of a symbol text.
				local op1 = stmt.operands and stmt.operands[1]
				local callee = (op1 and (op1.text or op1.name)) or "?"
				cgm.checkCallsiteSig(cs, callee)
			end
			callSigCache[stmt] = cs
		end
		return callSigCache[stmt]
	end
	local function callInfo(stmt)
		local cs = callSigOf(stmt)
		if not cs then return nil end
		-- Only the GPR-class arguments get yolo GPR uses (FP args pass through the
		-- v registers unmodeled); an FP result is returned in v0, so there is no
		-- yolo result register to model.
		local argRegs = {}
		for k = 1, cs.argWords do
			if not isFp(cs.argTypes[k]) then
				table.insert(argRegs, cc.yoloArg(k, cs.argTypes))
			end
		end
		local resultReg = (cs.isVoid or (cs.retTypes[1] and isFp(cs.retTypes[1]))) and nil or 0
		return { argRegs = argRegs, resultReg = resultReg }
	end

	local lf = lift.liftFunction(body, { classify = cgm.classify, returnRegs = returnRegs, callInfo = callInfo })

	local temps = lf.temps
	local nextTemp = lf.nextTemp
	local function allocTemp(desc)
		nextTemp += 1
		temps[nextTemp] = desc or {}
		return nextTemp
	end

	-- Precolored physical-register temps: ONE node per machine register (as IRC requires).
	local pregTemps = {}
	local function pColored(num)
		if not pregTemps[num] then
			pregTemps[num] = allocTemp({ precolor = cgm.precolorName(num), phys = num })
		end
		return pregTemps[num]
	end

	-- Seeds for pointer flow: pointer args occupy their yolo argument registers.
	-- FP args (float/double on arm64) pass in the v registers unmodeled: no yolo
	-- GPR, no entry temp — the entry unpack below skips them entirely.
	local argPtrTemps = {}
	local argInfo = {}
	for k, ty in sigDesc.argTypes do
		if isFp(ty) then
			argInfo[k] = { isPtr = false, fp = true, fpOrdinal = fpOrdinalOf(sigDesc.argTypes, k),
				yoloReg = nil, entryTemp = nil }
		else
			local yreg = cc.yoloArg(k, sigDesc.argTypes)
			local et = yreg and lf.entryTemp[yreg] or nil
			argInfo[k] = { isPtr = (ty == 7), yoloReg = yreg, entryTemp = et }
			if ty == 7 and et then table.insert(argPtrTemps, et) end
		end
	end

	-- classify nodes: load-ptr / store-ptr / call / alloca. EVERY annotation on an
	-- instruction must be recognized and honored — an unrecognized or mismatched
	-- one was historically SILENTLY IGNORED, and a `;! load ptr` / `;! store ptr`
	-- on the wrong instruction shape was a silent miscompile (the annotated
	-- instruction was replaced by an invisicap load/store, dropping the original
	-- operation). Both are now clean compile-time errors.
	local loadPtrDefs, storePtrNodes, callNodes, allocaNodes, allocaResultDefs = {}, {}, {}, {}, {}
	local callPtrDefs = {}
	-- Annotated register-indirect calls (`call *%reg ;! sig(...)` on x86_64,
	-- `blr xN ;! sig(...)` on arm64).
	local indcallNodes = {}
	-- Atomic pointer operations and pointer RMWs (x86_64 cmpxchg/movq forms;
	-- arm64 cas/LSE forms — `;! load store ptr` excepted, arm64-only rejection).
	local atomicLoadPtrDefs, atomicStorePtrNodes = {}, {}
	local atomicCasPtrDefs, loadStorePtrNodes, atomicRmwPtrNodes = {}, {}, {}
	local sizeNames = {}
	for _, node in lf.nodes do
		if node.kind == "insn" then
			local ann = node.stmt.annotation
			local raw = node.stmt.raw or node.stmt.mnemonic or "?"
			local al = parseAlloca(ann)
			if al then
				allocaNodes[node] = al
				if al.kind == "size" then
					if sizeNames[al.name] then error("sarcasm: duplicate `alloca size (" .. al.name .. ")`") end
					sizeNames[al.name] = true
				else
					allocaResultDefs[node] = true
				end
			elseif ann and sig.PTR_ANNOTATIONS[ann] then
				-- cmpxchg8b/cmpxchg16b cannot be made to work on pointers: an
				-- invisicap is a (intval, lower) pair whose updates cannot be
				-- synthesized from a double-width compare-and-swap. Reject every
				-- ptr-family annotation on them (including the future atomic
				-- forms, so they can never sneak through).
				local bm = cgm.baseMnemonic(string.lower(node.stmt.mnemonic))
				if bm == "cmpxchg8b" or bm == "cmpxchg16b" then
					error("sarcasm: " .. bm .. " cannot operate on pointers: " .. raw)
				end
				if ann == "load ptr" or ann == "store ptr" then
					local kind = cgm.ptrAccessKind and cgm.ptrAccessKind(node.stmt) or "other"
					if kind == "rmw" then
						error("sarcasm: `;! " .. ann .. "` on a read-modify-write instruction;"
							.. " pointer RMWs need `;! load store ptr` (or `;! atomic load store ptr`): " .. raw)
					end
					local want = (ann == "load ptr") and "load" or "store"
					if kind ~= want then
						error("sarcasm: `;! " .. ann .. "` requires a plain 8-byte GPR " .. want
							.. " instruction: " .. raw)
					end
					if ann == "load ptr" then loadPtrDefs[node] = true else storePtrNodes[node] = true end
				else
					-- atomic/pointer-RMW annotations: the per-arch shape validator
					-- returns the sequence kind (raising the shape errors).
					if not cgm.ptrAtomicShape then
						error("sarcasm: `;! " .. ann .. "` is not supported on this target: " .. raw)
					end
					local shape = cgm.ptrAtomicShape(ann, node.stmt)
					if shape == "atomicload" then atomicLoadPtrDefs[node] = true
					elseif shape == "atomicstore" then atomicStorePtrNodes[node] = true
					elseif shape == "cas" then atomicCasPtrDefs[node] = true
					elseif shape == "rmw" then loadStorePtrNodes[node] = true
					elseif shape == "atomicrmw" then atomicRmwPtrNodes[node] = true
					else error("sarcasm: internal error: bad ptr-atomic shape " .. tostring(shape)) end
				end
			elseif node.c.control == "call" and ann then
				callNodes[node] = ann
				local cs = callSigOf(node.stmt)
				if cs and cs.retIsPtr then callPtrDefs[node] = true end
			elseif node.c.control == "indcall" then
				-- Indirect calls (a register-indirect call with a callsite signature
				-- annotation is supported on BOTH architectures; the emission is
				-- arch-neutral through the cg hooks). A MEMORY-indirect call
				-- (`call *mem`) can never be made memory-safe: the loaded value
				-- carries no capability. A register-indirect call is supported
				-- exactly like an annotated direct call, but only when it carries a
				-- callsite signature — an unannotated one would get no
				-- callee-is-a-function checks (and historically didn't even model
				-- the caller-saved clobbers or the result redefinition).
				if cgm.memOperand(node.stmt) then
					error("sarcasm: indirect call through a memory operand cannot be made"
						.. " memory-safe (load the function pointer into a register first,"
						.. " e.g. with `;! load ptr`, then call the register): " .. raw)
				end
				if not ann then
					error("sarcasm: indirect call has no ;! signature annotation (annotate"
						.. " the callsite with the callee's signature, e.g. `;! int(ptr)`): "
						.. raw)
				end
				indcallNodes[node] = ann
				local cs = callSigOf(node.stmt)
				if cs and cs.retIsPtr then callPtrDefs[node] = true end
			elseif ann then
				if string.find(ann, "%(") then
					error("sarcasm: signature annotation `" .. ann .. "` on a non-call"
						.. " instruction: " .. raw)
				end
				error("sarcasm: unrecognized annotation: " .. ann .. " (on: " .. raw .. ")")
			end
		end
	end

	-- The atomic pointer load (`;! atomic load ptr`) and the pointer compare-exchange
	-- (`;! atomic ptr` on cmpxchg — its def temp is the implicit accumulator def web)
	-- define pointer results exactly like `;! load ptr`: seed them the same way so
	-- ptrflow allocates their lower temps.
	local ptrSeedDefs = {}
	for n in pairs(loadPtrDefs) do ptrSeedDefs[n] = true end
	for n in pairs(atomicLoadPtrDefs) do ptrSeedDefs[n] = true end
	for n in pairs(atomicCasPtrDefs) do ptrSeedDefs[n] = true end
	if cgm.atomicRmwPlan then
		-- arm64: the LSE pointer-RMW's old-value destination register (ldadd's
		-- Wt / swp's Wt) receives the slot's old value — a genuine pointer
		-- (old.iv, old.lo), exactly like an `;! atomic load ptr` result. Seed it
		-- the same way so ptrflow allocates its lower temp. (x86_64's annotated
		-- RMWs have no destination register; nothing is seeded there.)
		for n in pairs(atomicRmwPtrNodes) do ptrSeedDefs[n] = true end
	end

	local pf = ptrflow.analyze(lf,
		{ argPtrTemps = argPtrTemps, loadPtrDefs = ptrSeedDefs, allocaResultDefs = allocaResultDefs,
			callPtrDefs = callPtrDefs },
		allocTemp, { baseMnemonic = cgm.baseMnemonic })

	-- Link each fixed-size alloca-result node to its region; give the region a stable pointer
	-- temp for redirecting sp-relative math and a shared lower (the result's seeded lower).
	-- DETERMINISM: iterate lf.nodes in statement order, NOT allocaNodes itself — allocaNodes
	-- is keyed by node IDENTITY, and hash iteration over pointer keys varies per process
	-- (Luau seeds object hashes per VM), so the regionptr temp ids (and with them every
	-- later temp id, spill slot layout, and coloring tie-break) would reorder per run.
	for _, node in lf.nodes do
		local al = allocaNodes[node]
		if al and al.kind == "resultSize" then
			for _, r in allocaRegions do
				if r.stmt == node.stmt then al.region = r; break end
			end
			local r = al.region
			if r and not r.ptrTemp then
				r.ptrTemp = allocTemp({ role = "regionptr" })
				local resultIv = node.defTemps and node.defTemps[1]
				r.loTemp = resultIv and pf.lowerTemp[resultIv]
				pf.isPtr[r.ptrTemp] = true
				if r.loTemp then pf.lowerTemp[r.ptrTemp] = r.loTemp end
			end
		end
	end

	-- loop headers (targets of back edges) get a pollcheck
	local loopHeaderLabels = {}
	for _, node in lf.nodes do
		if node.kind == "insn" and node.c.targets and #node.c.targets > 0 then
			for _, t in node.c.targets do
				local ti = lf.labelToFlow[t]
				if ti and ti <= node.fi then loopHeaderLabels[t] = true end
			end
		end
	end

	local out = {}
	local function emit(n) table.insert(out, n) end
	local vMyth = allocTemp({ role = "myth" })
	temps[vMyth].spillCost = 1e9
	local originSym = ".Lfilc_origin_" .. name

	emit({ kind = "prologue", name = name })

	local cg = cgm.make({ emit = emit, allocTemp = allocTemp, pColored = pColored, pf = pf, temps = temps,
		frameCtx = fctx })

	-- Condition-flag (NZCV) liveness at instrumentation points. The instrumented
	-- sequences (access checks, invisicap loads/stores, pollchecks, allocations) write
	-- the condition flags (cmp/tst); gcc -O2 routinely leaves flags live across a
	-- memory instruction (`cmp; ldr; adcs`), so an inserted flag write would corrupt
	-- the program's pending condition. Scan forward from the insertion point: if the
	-- next flag-relevant instruction is a USE (csel/b.cond/adcs/...) the flags are
	-- live and the sequence must be bracketed by a save/restore; if it is a DEF
	-- (cmp/subs) the incoming flags are dead; calls clobber the flags per the ABI
	-- (no valid code reads them across a call); at a basic-block end (label, branch,
	-- return, or the end of the function) conservatively assume live-out — a flag
	-- consumer in a successor block (e.g. the b.cond terminating THIS block) counts.
	--
	-- ARM64-ONLY: the capability is keyed off cg.saveFlags (mrs/msr nzcv), which only
	-- the arm64 codegen provides (x86_64 has no flag save/restore — EFLAGS clobbering
	-- there is the documented known issue — so on x86 flagsLiveFrom is constant-false
	-- and withFlagSave is a plain passthrough, keeping x86 output byte-identical).
	local nodeIndex = {}
	for i, nd in lf.nodes do nodeIndex[nd] = i end
	local flagLiveCache = {}
	local flagCapable = (cgm.flagUse and cgm.flagDef and cg.saveFlags and cg.restoreFlags) and true or false
	local function flagsLiveFrom(i)
		if not flagCapable then return false end
		if flagLiveCache[i] ~= nil then return flagLiveCache[i] end
		local res = true   -- conservative default (end of function = live-out)
		local j = i
		while j <= #lf.nodes do
			local nd = lf.nodes[j]
			if nd.kind == "insn" then
				local ctrl = nd.c and nd.c.control or "none"
				if cgm.flagUse(nd.stmt) then res = true; break
				elseif cgm.flagDef(nd.stmt) then res = false; break
				elseif ctrl == "call" or ctrl == "indcall" then res = false; break
				elseif ctrl ~= "none" then res = true; break
				end
			elseif nd.kind == "label" then
				res = true; break
			end
			j += 1
		end
		flagLiveCache[i] = res
		return res
	end
	-- Run f() emitting an instrumented sequence, bracketed by a flag save/restore iff
	-- the program's flags are live at the sequence's insertion point.
	local function withFlagSave(live, f)
		if not live then f(); return end
		local t = cg.saveFlags()
		f()
		cg.restoreFlags(t)
	end

	-- GC root slots
	local rootTemps, loToSlot = {}, {}
	local function rootSlotFor(loT)
		if loToSlot[loT] == nil then
			table.insert(rootTemps, loT)
			loToSlot[loT] = #rootTemps - 1
			if temps[loT] then temps[loT].spillCost = 1e9 end
		end
		return loToSlot[loT]
	end
	local function emitRootStore(loT) emit({ kind = "rootstore", temp = loT, index = rootSlotFor(loT), useTemps = { loT } }) end

	-- entry CC unpacking: myth <- myth reg; params from CC iv/lo regs into their yolo webs.
	-- FP args (float/double on arm64) are SKIPPED entirely: their value is already in
	-- its v register (v0..v7, in declaration order among the FP args) and the body
	-- reads it there — no move, no entry temp, no rooting.
	cg.move(vMyth, pColored(cc.myth), true)
	for k, ty in sigDesc.argTypes do
		local info = argInfo[k]
		if info.entryTemp then
			cg.move(info.entryTemp, pColored(cc.argIv(sigDesc.argTypes, k)), true)
			if info.isPtr then
				local loT = pf.lowerTemp[info.entryTemp]
				cg.move(loT, pColored(cc.argLo(sigDesc.argTypes, k)), true)
				emitRootStore(loT)
			end
		end
	end

	-- access-fail stubs (bookkeeping here; the stub body is arch-specific via cg.failStub).
	local accessOrigins, failStubs, failCounter = {}, {}, 0
	local function failLabelFor(ivTemp, loTemp, size, align, isWrite)
		failCounter += 1
		local aco = ".Lfilc_aco_" .. name .. "_" .. failCounter
		local lbl = ".Lfail_" .. name .. "_" .. failCounter
		-- The runtime's optimized-access-check origin cannot express alignments
		-- wider than a word (filc_optimized_access_check_fail asserts
		-- check_origin->alignment <= FILC_WORD_SIZE), so the recorded alignment
		-- is clamped to 8 — exactly like the compiler (FilPizlonator's
		-- buildCheck does std::min(Alignment, WordSize)). The CHECK above still
		-- tests the full alignment (e.g. cmpxchg16b's 16); since the clamped
		-- origin could not attribute a word-aligned-but-not-fully-aligned
		-- pointer (every recorded test would pass — the runtime's "Should not
		-- be reached" assert), that failure goes to a dedicated stub reporting
		-- the true alignment (see emitAccessCheck). For the merely-word-
		-- misaligned case the clamp only affects the trap-message text.
		table.insert(accessOrigins, { sym = aco, size = size, align = math.min(align, 8),
			write = isWrite and true or false, line = curLine })
		cg.failStub(failStubs, lbl, ivTemp, loTemp, aco)
		return lbl
	end

	-- access check for a precomputed effective address (capLo==nil => null cap, always traps).
	-- Check order: null capability, alignment, not-readonly/CanWrite (writes), lower
	-- bound, upper bound. This matches the compiler's emitted order exactly:
	-- FilPizlonator's canonicalizeAccessChecks stable-sorts each access's checks by
	-- CheckKind, whose declaration order is ValidObject < Alignment < CanWrite <
	-- LowerBound < UpperBound (verified against filcc -O0/-O2 IR: the CanWrite aux
	-- test precedes the lower-bound compare). Note the runtime's hand-written
	-- inline helper (filc_check_aligned_access_with_name) and sarcasm's own
	-- pointer-store sequence (emitPtrStore below) both do the bounds tests BEFORE
	-- the readonly reject instead — every order traps equivalently, since all
	-- failures branch to the same fail stub / panic, so the difference is
	-- unobservable.
	local function emitAccessCheck(effTemp, capLo, size, align, isWrite)
		if capLo == nil then
			cg.jump(failLabelFor(effTemp, nil, size, align, isWrite))
			return
		end
		local lbl = failLabelFor(effTemp, capLo, size, align, isWrite)
		cg.branchZero(capLo, lbl)                 -- null capability
		if align > 1 then
			-- An alignment wider than a word (cmpxchg16b's 16 — x86_64 only;
			-- arm64 access alignments cap at 8) cannot be attributed by the
			-- optimized fail stub: the origin records the word-clamped
			-- alignment, so an in-bounds, writable, word-aligned-but-not-fully-
			-- aligned pointer would pass every recorded test and hit the
			-- runtime's "Should not be reached" assert (a pas crash, not a
			-- clean trap). Give the alignment failure its own stub, reporting
			-- the TRUE alignment through filc_check_aligned_access_fail.
			local aLbl = lbl
			if align > 8 then
				failCounter += 1
				aLbl = ".Lalignfail_" .. name .. "_" .. failCounter
				cg.alignFailStub(failStubs, aLbl, effTemp, capLo, size, align, isWrite)
			end
			cg.testMaskBranch(effTemp, align - 1, "ne", aLbl)
		end
		if isWrite then
			-- CanWrite: every heap write rejects read-only/special objects,
			-- exactly like compiled Fil-C (and the ptr-store path below): the
			-- aux word at [lower-8] carries ObjectFlagReadonly|ObjectFlagFree
			-- at bits 49-50. The fail origin's write bit makes the runtime
			-- report "cannot write to read-only object." (resp. free object).
			local auxword = allocTemp({ role = "scratch" })
			cg.load(auxword, capLo, -8, 8)
			cg.testMaskBranch(auxword, "0x6000000000000", "ne", lbl)
		end
		cg.cmpBranch(effTemp, capLo, "ult", lbl)  -- eff < lower
		local upper = allocTemp({ role = "scratch" })
		cg.load(upper, capLo, -16, 8)             -- upper = [lower-16]
		if size > 1 then
			-- Overflow-free upper-bound form, exactly like the compiler
			-- (FilPizlonator's buildCheck comment: "Ptr <= Upper - Size" is an
			-- "overflow-free way of saying Ptr + Size <= Upper"). The naive
			-- `hi = eff + size; hi ugt upper` WRAPS for eff in
			-- [2^64 - size, 2^64) (reachable: pointer base + a huge index via
			-- lea), letting the check pass so the CPU faults on the wild
			-- address — a SIGSEGV instead of a clean filc trap. Real uppers
			-- are < 2^48, so upper - size never wraps, and any eff that large
			-- fails the compare.
			local upperMinusSize = allocTemp({ role = "scratch" })
			cg.subImm(upperMinusSize, upper, size)      -- upperMinusSize = upper - size
			cg.cmpBranch(effTemp, upperMinusSize, "ugt", lbl)  -- eff > upper - size
		else
			cg.cmpBranch(effTemp, upper, "uge", lbl)  -- eff >= upper
		end
	end

	-- AVX512 {k}-masked / AVX2 vmaskmov-vpmaskmov heap access check (x86_64 only —
	-- the codegen surfaces cgm.maskedAccessInfo for the supported forms). This is
	-- EXACTLY the check algorithm the Fil-C compiler emits for the masked
	-- intrinsics (FilPizlonator's lowerIntrinsicAccess, verified against clang
	-- output): for a fixed-position access of N lanes x E bytes (V = N*E the full
	-- footprint), flight ptr (eff, lower), upper at [lower-16]:
	--   1. ValidObject: lower == 0 fails EVEN when the mask is zero (the runtime
	--      reports "cannot access pointer with null object." via a size=0 origin).
	--   2. Stores: CanWrite (aux flags at [lower-8], the uniform
	--      READONLY|FREE mask, like every sarcasm store).
	--   3. Fast path: eff < lower -> below-slow; eff > upper - V -> above-slow
	--      (upper - V is overflow-free, like the plain check's upper - size);
	--      else execute with no mask work.
	--   4. Below-slow: mask == 0 -> execute (masked-off lanes touch nothing).
	--      Fixed-position: i = cttz(mask); fail iff eff < lower - i*E (the first
	--      enabled lane must be in bounds; on success rejoin the upper check —
	--      the tail lanes may still be out, e.g. an object smaller than V).
	--      Contiguous (expand/compress): always fail (the access starts at eff).
	--   5. Above-slow: mask == 0 -> execute. Fixed-position: h = index of the
	--      highest set mask bit; fail iff eff > upper - (h+1)*E. Contiguous:
	--      c = popcount(mask); fail iff eff > upper - c*E.
	--   6. Fail: the runtime's dedicated masked fail functions
	--      (filc_masked_read/write_check_fail, resp. filc_expand_read /
	--      filc_compress_write_check_fail) — "masked read not in bounds (even
	--      accounting for the mask)." & co.
	local maskedCounter = 0
	local function emitMaskedAccessCheck(effTemp, capLo, info, align, isWrite)
		maskedCounter += 1
		local tag = name .. "_" .. maskedCounter
		local E, N, V = info.elem, info.lanes, info.vecsize
		-- ValidObject + CanWrite share ONE size=0 origin: the runtime then
		-- reports "cannot access pointer with null object." (resp. "cannot
		-- access pointer to free object." / "cannot write to read-only
		-- object."), exactly like filcc's masked path.
		if capLo == nil then
			cg.jump(failLabelFor(effTemp, nil, 0, 1, isWrite))
			return
		end
		local lbl = failLabelFor(effTemp, capLo, 0, 1, isWrite)
		cg.branchZero(capLo, lbl)                                 -- ValidObject
		if align > 1 then
			-- Aligned forms (vmovdqa32/64, vmovaps/pd): keep the plain path's
			-- alignment check (clamped to 8 by accessSizeAlign, exactly like
			-- the unmasked forms). It needs its own size=V origin: a size=0
			-- origin could not attribute the failure (the runtime would hit
			-- its "Should not be reached" assert). Conservative when the mask
			-- is zero (hardware suppresses even alignment faults there).
			local aLbl = failLabelFor(effTemp, capLo, V, align, isWrite)
			cg.testMaskBranch(effTemp, align - 1, "ne", aLbl)
		end
		if isWrite then
			-- CanWrite, same aux-flags test as every store (see emitAccessCheck).
			local auxword = allocTemp({ role = "scratch" })
			cg.load(auxword, capLo, -8, 8)
			cg.testMaskBranch(auxword, "0x6000000000000", "ne", lbl)
		end
		local upperL = ".Lmaskupper_" .. tag
		local belowL = ".Lmaskbelow_" .. tag
		local aboveL = ".Lmaskabove_" .. tag
		local execL  = ".Lmaskexec_" .. tag
		-- The mask-refined bounds failures go to the runtime's dedicated masked
		-- fail function (a new fail-stub kind), with a generic 16-byte filc_origin
		-- (maskedOrigin record; the size/vector details travel as call arguments).
		failCounter += 1
		local failL = ".Lmaskfail_" .. name .. "_" .. failCounter
		local mko = ".Lfilc_mko_" .. name .. "_" .. failCounter
		table.insert(accessOrigins, { sym = mko, maskedOrigin = true, line = curLine })
		local maskT = allocTemp({ role = "mask" })
		-- fast path
		cg.cmpBranch(effTemp, capLo, "ult", belowL)
		cg.label(upperL)
		local upper = allocTemp({ role = "scratch" })
		cg.load(upper, capLo, -16, 8)
		local upperMinusV = allocTemp({ role = "scratch" })
		cg.subImm(upperMinusV, upper, V)               -- overflow-free (real upper < 2^48)
		cg.cmpBranch(effTemp, upperMinusV, "ugt", aboveL)
		cg.jump(execL)
		-- E is always a power of two (1/2/4/8), so lane-extent multiplies are shifts.
		local shE = ({ [1] = 0, [2] = 1, [4] = 2, [8] = 3 })[E]
		-- below-slow
		cg.label(belowL)
		cg.maskToGpr(maskT, info)
		cg.branchZero(maskT, execL)
		if info.contiguous then
			cg.jump(failL)
		else
			local i = allocTemp({ role = "scratch" })
			emit(build.insn("tzcntq", { build.rt(i), build.rt(maskT) },
				{ defs = { i }, uses = { maskT } }))
			if shE > 0 then
				emit(build.insn("shl", { build.rt(i), build.imm(shE) }, { defs = { i }, uses = { i } }))
			end
			local bound = allocTemp({ role = "scratch" })
			cg.subReg(bound, capLo, i)                 -- lower - i*E (overflow-free)
			cg.cmpBranch(effTemp, bound, "ult", failL)
			cg.jump(upperL)
		end
		-- above-slow
		cg.label(aboveL)
		cg.maskToGpr(maskT, info)
		cg.branchZero(maskT, execL)
		if info.contiguous then
			local c = allocTemp({ role = "scratch" })
			emit(build.insn("popcntq", { build.rt(c), build.rt(maskT) },
				{ defs = { c }, uses = { maskT } }))
			if shE > 0 then
				emit(build.insn("shl", { build.rt(c), build.imm(shE) }, { defs = { c }, uses = { c } }))
			end
			local bound = allocTemp({ role = "scratch" })
			cg.subReg(bound, upper, c)                 -- upper - c*E (overflow-free)
			cg.cmpBranch(effTemp, bound, "ugt", failL)
			cg.jump(execL)
		else
			local h = allocTemp({ role = "scratch" })
			emit(build.insn("bsrq", { build.rt(h), build.rt(maskT) },
				{ defs = { h }, uses = { maskT } }))
			cg.addImm(h, h, 1)                         -- h+1 lanes through the top
			if shE > 0 then
				emit(build.insn("shl", { build.rt(h), build.imm(shE) }, { defs = { h }, uses = { h } }))
			end
			local bound = allocTemp({ role = "scratch" })
			cg.subReg(bound, upper, h)                 -- upper - (h+1)*E (overflow-free)
			cg.cmpBranch(effTemp, bound, "ugt", failL)
			cg.jump(execL)
		end
		cg.label(execL)
		cg.maskedFailStub(failStubs, failL, effTemp, capLo, maskT, info, isWrite, mko)
	end

	-- invisicap pointer load: load (dstIv, dstLo) from the address of `mem`.
	local ptrldCounter = 0
	local function emitPtrLoad(node, mem, dstIv, dstLo)
		ptrldCounter += 1
		local tag = name .. "_" .. ptrldCounter
		local effTemp, baseLo = cg.computeAddr(node, mem)
		emitAccessCheck(effTemp, baseLo, 8, 8)
		if baseLo == nil then cg.moveZero(dstLo); cg.moveZero(dstIv); return end
		local offInObj = allocTemp({ role = "offobj" })
		cg.subReg(offInObj, effTemp, baseLo)                       -- offInObj = eff - lower
		local aux = allocTemp({ role = "aux" })
		cg.load(aux, baseLo, -8, 8); cg.maskLow48(aux)             -- aux = [lower-8] & 0xffffffffffff
		local nullL, haveL, direct = ".Lnulllo_" .. tag, ".Lhavelo_" .. tag, ".Ldirlo_" .. tag
		cg.branchZero(aux, nullL)
		local auxE = allocTemp({ role = "auxentry" })
		cg.loadIndexed(auxE, aux, offInObj, 1, 8)                  -- auxE = [aux + offInObj]
		cg.testMaskBranch(auxE, 1, "eq", direct)                   -- bit0 clear -> direct
		local boxp = allocTemp({ role = "box" })
		cg.move(boxp, auxE); cg.andImmInPlace(boxp, -2); cg.load(dstLo, boxp, 8, 8)  -- box: lower=[(auxE&~1)+8]
		cg.jump(haveL)
		cg.label(direct); cg.move(dstLo, auxE, true); cg.jump(haveL)
		cg.label(nullL); cg.moveZero(dstLo)
		cg.label(haveL); cg.load(dstIv, effTemp, 0, 8)             -- dstIv = [eff]
	end

	-- invisicap pointer store (aux allocation + readonly reject + FUGC store barrier).
	local ptrstCounter = 0
	local function emitPtrStore(node, mem, valIv, valLo)
		ptrstCounter += 1
		local tag = name .. "_st_" .. ptrstCounter
		local effTemp, baseLo = cg.computeAddr(node, mem)
		if baseLo == nil then emitAccessCheck(effTemp, nil, 8, 8, true); return end
		if valLo == nil then valLo = allocTemp({ role = "nulllo" }); cg.moveZero(valLo) end
		local lbl = failLabelFor(effTemp, baseLo, 8, 8, true)
		cg.branchZero(baseLo, lbl)
		cg.testMaskBranch(effTemp, 7, "ne", lbl)                   -- alignment
		cg.cmpBranch(effTemp, baseLo, "ult", lbl)                  -- lower bound
		local auxword = allocTemp({ role = "auxword" })
		cg.load(auxword, baseLo, -8, 8)
		cg.testMaskBranch(auxword, "0x6000000000000", "ne", lbl)   -- read-only/special reject
		local upper = allocTemp({ role = "scratch" })
		cg.load(upper, baseLo, -16, 8)
		-- Same overflow-free upper-bound form as emitAccessCheck (upper - 8,
		-- never eff + 8: eff + 8 wraps for eff in [2^64-8, 2^64)).
		local upperMinus8 = allocTemp({ role = "scratch" })
		cg.subImm(upperMinus8, upper, 8); cg.cmpBranch(effTemp, upperMinus8, "ugt", lbl)  -- upper bound
		local offInObj = allocTemp({ role = "offobj" })
		cg.subReg(offInObj, effTemp, baseLo)
		local aux = allocTemp({ role = "aux" })
		cg.move(aux, auxword); cg.maskLow48(aux)
		local needAux, barrier, doBarrier, storeLbl, doneLbl =
			".Lneedaux_" .. tag, ".Lbarrier_" .. tag, ".Ldobar_" .. tag, ".Lstore_" .. tag, ".Ldone_" .. tag
		cg.branchZero(aux, needAux)
		cg.label(barrier)
		cg.markingStateNonzeroBranch(doBarrier)
		cg.label(storeLbl)
		cg.storeIndexed(valLo, aux, offInObj, 1)
		cg.store(valIv, effTemp, 0)
		cg.jump(doneLbl)
		-- need-aux: filc_object_ensure_aux_ptr_outline(myth, lower-16) -> aux
		-- (injected returning runtime call, out of the hot line: preserve the function's
		-- live FP/SIMD state around it — no-op for GPR-only functions)
		cg.label(needAux)
		cg.fpSave()
		local header = allocTemp({ role = "scratch" })
		cg.subImm(header, baseLo, 16)
		cg.move(pColored(cc.rtArg(1)), vMyth)
		cg.move(pColored(cc.rtArg(2)), header)
		cg.call("filc_object_ensure_aux_ptr_outline", { pColored(cc.rtArg(1)), pColored(cc.rtArg(2)) }, cg.callerSavedClobbers())
		cg.fpRestore()
		cg.move(aux, pColored(cc.rtRet))
		cg.jump(barrier)
		-- do-barrier: filc_store_barrier_for_lower_slow(myth, lower) — but only for a
		-- non-null lower: the runtime's filc_store_barrier_for_lower guards
		-- `marking && lower`, and its _slow entrypoint asserts the lower is non-null
		-- (storing a NULL/integer-derived pointer has no object to barrier).
		cg.label(doBarrier)
		cg.branchZero(valLo, storeLbl)
		cg.fpSave()
		cg.move(pColored(cc.rtArg(1)), vMyth)
		cg.move(pColored(cc.rtArg(2)), valLo)
		cg.call("filc_store_barrier_for_lower_slow", { pColored(cc.rtArg(1)), pColored(cc.rtArg(2)) }, cg.callerSavedClobbers())
		cg.fpRestore()
		cg.jump(storeLbl)
		cg.label(doneLbl)
	end

	-- Pre/post-index writeback for annotated pointer accesses. The invisicap sequence
	-- replaces the load/store wholesale, so the base register's `base += index` side
	-- effect must be re-applied explicitly (e.g. `ldr x0, [x0], #8 ;! load ptr` walking
	-- an array). Only the intval temp advances; the lower (capability) is unchanged —
	-- it is the same object. The effective address used for the access is already
	-- correct (old base for post-index, base+index for pre-index via computeAddr), so
	-- a single add/sub after the sequence covers both forms. (x86_64 has no writeback
	-- addressing modes, so this is a no-op there.)
	local function emitWriteback(node, mem)
		if not mem or not mem.writeback then return end
		local baseT = node.opTemp[mem.base]
		if not baseT then
			error("sarcasm: writeback base of an annotated pointer access has no usable value: "
				.. (node.stmt and node.stmt.raw or "?"))
		end
		local amt = (mem.index and mem.index.kind == "imm")
			and (mem.index.value or tonumber(mem.index.text)) or nil
		if not amt then
			error("sarcasm: annotated pointer access with a non-immediate writeback index"
				.. " is not supported: " .. (node.stmt and node.stmt.raw or "?"))
		end
		if amt > 0 then cg.addImm(baseT, baseT, amt)
		elseif amt < 0 then cg.subImm(baseT, baseT, -amt) end
	end

	-- pollcheck: myth flags at [myth+8], bits 0xe.
	local pollCounter = 0
	local function emitPollcheck()
		pollCounter += 1
		local okLbl = ".Lpollok_" .. name .. "_" .. pollCounter
		local flags = allocTemp({ role = "scratch" })
		cg.load(flags, vMyth, 8, 1)
		cg.testMaskBranch(flags, 0xe, "eq", okLbl, 32)
		-- Slow path, out of the hot line (the not-taken branch skips it): an injected
		-- RETURNING runtime call the source program never saw, so its live FP/SIMD
		-- state must be preserved around it (fpSave/fpRestore are no-ops when the
		-- function uses no vector registers).
		cg.fpSave()
		cg.move(pColored(cc.rtArg(1)), vMyth)
		cg.leaGlobal(cc.rtArg(2), originSym)
		cg.call("filc_pollcheck_slow", { pColored(cc.rtArg(1)), pColored(cc.rtArg(2)) }, cg.callerSavedClobbers())
		cg.fpRestore()
		cg.label(okLbl)
	end

	-- Atomic pointer operations and pointer RMWs, via the Fil-C runtime — exactly
	-- the calls filcc emits for C11 atomic pointer operations (verified against
	-- build/bin/clang output; see ABI-NOTES-x86.md). The callees are nounwind
	-- runtime entrypoints: a filc_ptr argument is two consecutive argument words
	-- (intval first, then lower), a filc_ptr result comes back as two words
	-- (x86_64 SysV: rax=intval, rdx=lower; arm64 AAPCS64: x0=intval, x1=lower) —
	-- so there is NO exception-flag check after these calls (unlike
	-- pizlonated-function calls). Returned lowers are rooted
	-- immediately (a safepoint may run before the next use); pointer ARGUMENTS need
	-- no caller rooting (the runtime protects them itself). Each sequence emits the
	-- usual inline access check first (null-cap -> align -> CanWrite -> lower ->
	-- upper) so a trap gets sarcasm's origin; the runtime re-checks internally.
	--
	-- EFLAGS (x86_64): a flag consumer (jcc/setcc) immediately after the annotated
	-- instruction must see the flags the NATIVE instruction would produce, but the
	-- injected sequences clobber EFLAGS. The RMW/CAS paths therefore keep the
	-- pre-op value (and the source operand) live in webs and re-execute the
	-- operation on a scratch copy as the LAST flag-affecting step (the result
	-- moves and root stores in between don't touch flags). A consumer that does
	-- NOT immediately follow still sees clobbered flags — the same documented
	-- caveat as the injected bounds checks everywhere else.
	-- NZCV (arm64): only `;! atomic ptr` (cas) has a flag contract — NZCV is
	-- recomputed as (expected − old) as the last flag-affecting step, mirroring
	-- the x86 cmpxchg form so a following b.eq/cset behaves natively. The native
	-- arm64 forms (ldar/stlr/ldapr, the LSE RMWs) write NO flags, so their
	-- sequences instead PRESERVE the program's live NZCV around themselves
	-- (withFlagSave at the dispatch; constant-false on x86_64, which keeps its
	-- EFLAGS behavior and byte-identical output).
	local function marshalResultPtr(dstIv, dstLo)
		cg.move(dstIv, pColored(cc.rtRet))
		cg.move(dstLo, pColored(cc.rtRetLo))
		emitRootStore(dstLo)
	end

	-- filc_load_ptr_atomic_with_manual_tracking_outline(slot) -> old (rtRet=iv,
	-- rtRetLo=lo). No myth arg, does not allocate, can only panic.
	local function emitAtomicLoadCall(effTemp, capLoTemp)
		cg.fpSave()
		cg.move(pColored(cc.rtArg(1)), effTemp)
		cg.move(pColored(cc.rtArg(2)), capLoTemp)
		cg.call("filc_load_ptr_atomic_with_manual_tracking_outline",
			{ pColored(cc.rtArg(1)), pColored(cc.rtArg(2)) }, cg.callerSavedClobbers())
		cg.fpRestore()
	end

	-- filc_store_ptr_atomic_outline(myth, slot, value). Can allocate (creates the
	-- 16-byte atomic box / ensures aux) => GC safepoint; barriers value internally.
	local function emitAtomicStoreCall(effTemp, capLoTemp, valIv, valLo)
		cg.fpSave()
		cg.move(pColored(cc.rtArg(1)), vMyth)
		cg.move(pColored(cc.rtArg(2)), effTemp)
		cg.move(pColored(cc.rtArg(3)), capLoTemp)
		cg.move(pColored(cc.rtArg(4)), valIv)
		cg.move(pColored(cc.rtArg(5)), valLo)
		cg.call("filc_store_ptr_atomic_outline",
			{ pColored(cc.rtArg(1)), pColored(cc.rtArg(2)), pColored(cc.rtArg(3)),
				pColored(cc.rtArg(4)), pColored(cc.rtArg(5)) }, cg.callerSavedClobbers())
		cg.fpRestore()
	end

	-- filc_strong_cas_ptr_with_manual_tracking(myth, slot, 0, expected, new) -> old.
	-- Can allocate => GC safepoint. Success <=> returned old.iv == expected.iv (a
	-- raw-intval comparison; the runtime compares intvals only). The expected's
	-- lower may be null ("integer guess") — the comparison ignores it.
	-- new_value marshalling is arch-specific: on x86_64 (SysV, six argument
	-- registers) it travels on the STACK ([rsp]=iv, [rsp+8]=lower at the call;
	-- see codegen's pushStackPtr); on arm64 (AAPCS64) all eight argument words
	-- fit in x0..x7, so it marshals in registers (cg.casNewInRegs).
	local function emitAtomicCasCall(effTemp, capLoTemp, expIv, expLo, newIv, newLo)
		cg.fpSave()
		cg.move(pColored(cc.rtArg(1)), vMyth)
		cg.move(pColored(cc.rtArg(2)), effTemp)
		cg.move(pColored(cc.rtArg(3)), capLoTemp)
		cg.moveZero(pColored(cc.rtArg(4)))          -- offset = 0
		cg.move(pColored(cc.rtArg(5)), expIv)
		cg.move(pColored(cc.rtArg(6)), expLo)
		local casUses = { pColored(cc.rtArg(1)), pColored(cc.rtArg(2)), pColored(cc.rtArg(3)),
			pColored(cc.rtArg(4)), pColored(cc.rtArg(5)), pColored(cc.rtArg(6)) }
		if cg.casNewInRegs then
			cg.move(pColored(cc.rtArg(7)), newIv)
			cg.move(pColored(cc.rtArg(8)), newLo)
			table.insert(casUses, pColored(cc.rtArg(7)))
			table.insert(casUses, pColored(cc.rtArg(8)))
		else
			cg.pushStackPtr(newIv, newLo)
		end
		cg.call("filc_strong_cas_ptr_with_manual_tracking", casUses, cg.callerSavedClobbers())
		if not cg.casNewInRegs then cg.popStackPtr() end
		cg.fpRestore()
	end

	-- filc_xchg_ptr_with_manual_tracking(myth, slot, 0, new) -> old: the exact
	-- primitive filcc emits for C11 atomic_exchange (FilPizlonator's AtomicRMW
	-- Xchg case — a direct call, no pollcheck; the runtime retries a weak CAS
	-- internally and barriers the new value itself). Can allocate (the retry
	-- path creates the atomic box) => GC safepoint. Six argument words (myth,
	-- slot.iv, slot.lower, offset, new.iv, new.lower) — they fit in argument
	-- registers on BOTH ABIs (x86_64 SysV has six; the CAS call above needs
	-- the stack only for words seven and eight). Currently only reached from
	-- the arm64 LSE swp lowering (x86_64 has no swp).
	local function emitAtomicXchgCall(effTemp, capLoTemp, newIv, newLo)
		cg.fpSave()
		cg.move(pColored(cc.rtArg(1)), vMyth)
		cg.move(pColored(cc.rtArg(2)), effTemp)
		cg.move(pColored(cc.rtArg(3)), capLoTemp)
		cg.moveZero(pColored(cc.rtArg(4)))          -- offset = 0
		cg.move(pColored(cc.rtArg(5)), newIv)
		cg.move(pColored(cc.rtArg(6)), newLo)
		cg.call("filc_xchg_ptr_with_manual_tracking",
			{ pColored(cc.rtArg(1)), pColored(cc.rtArg(2)), pColored(cc.rtArg(3)),
				pColored(cc.rtArg(4)), pColored(cc.rtArg(5)), pColored(cc.rtArg(6)) },
			cg.callerSavedClobbers())
		cg.fpRestore()
	end

	-- `;! atomic load ptr`: movq (mem), %reg — the runtime atomic pointer load.
	local function emitAtomicPtrLoad(node, mem)
		local dstIv = node.defTemps[1]
		if not dstIv then
			error("sarcasm: `;! atomic load ptr` requires a modeled (GPR) destination"
				.. " register: " .. (node.stmt.raw or "?"))
		end
		local dstLo = pf.lowerTemp[dstIv]
		local effTemp, capLo = cg.computeAddr(node, mem)
		emitAccessCheck(effTemp, capLo, 8, 8, false)
		if capLo == nil then cg.moveZero(dstLo); cg.moveZero(dstIv); emitRootStore(dstLo); return end
		emitAtomicLoadCall(effTemp, capLo)
		marshalResultPtr(dstIv, dstLo)
	end

	-- `;! atomic store ptr`: movq %reg, (mem) — the runtime atomic pointer store.
	local function emitAtomicPtrStore(node, mem)
		local valOp = storeValueOperand(node.stmt, mem)
		local valIv = valOp and node.opTemp[valOp] or nil
		if not valIv then
			error("sarcasm: `;! atomic store ptr` requires a modeled (GPR) value"
				.. " register: " .. (node.stmt.raw or "?"))
		end
		local valLo = pf.lowerTemp[valIv]
		local effTemp, capLo = cg.computeAddr(node, mem)
		emitAccessCheck(effTemp, capLo, 8, 8, true)
		if capLo == nil then return end
		if valLo == nil then valLo = allocTemp({ role = "nulllo" }); cg.moveZero(valLo) end
		emitAtomicStoreCall(effTemp, capLo, valIv, valLo)
	end

	-- `;! atomic ptr` on cmpxchgq (lock or not — both go through the runtime call):
	-- pointer compare-exchange. BYPASSES emitPinned: the expected value (the
	-- implicit accumulator's use web) travels in argument registers instead of
	-- physical rax; the old value arrives in rax/rdx and defines the accumulator's
	-- def web (seeded as a pointer by ptrflow).
	local function emitAtomicPtrCas(node, mem)
		local c = node.c
		local pin = c.pin
		local accUseT = (pin and pin.uses and pin.uses[1]) and node.opTemp[pin.uses[1]] or nil
		local accDefT = (pin and pin.defs and pin.defs[1]) and node.opTemp[pin.defs[1]] or nil
		if not (accUseT and accDefT) then
			error("sarcasm: internal error: cmpxchg implicit accumulator has no temp: "
				.. (node.stmt.raw or "?"))
		end
		local accDefLo = pf.lowerTemp[accDefT]
		local accUseLo = pf.lowerTemp[accUseT]
		local srcOp = node.stmt.operands[2]
		local newIv = srcOp and node.opTemp[srcOp] or nil
		if not newIv then
			error("sarcasm: `;! atomic ptr` requires a modeled (GPR) new-value register: "
				.. (node.stmt.raw or "?"))
		end
		local newLo = pf.lowerTemp[newIv]
		local effTemp, capLo = cg.computeAddr(node, mem)
		emitAccessCheck(effTemp, capLo, 8, 8, true)
		-- The expected intval must survive the call for the flag recompute below:
		-- the expected and result webs can COINCIDE (a cmpxchg retry loop unions
		-- the accumulator's use and def webs), so compare against a private copy.
		local expCopy = allocTemp({ role = "casexp" })
		cg.move(expCopy, accUseT)
		if capLo == nil then
			cg.moveZero(accDefT); cg.moveZero(accDefLo); emitRootStore(accDefLo); return
		end
		if not accUseLo then accUseLo = allocTemp({ role = "nullexp" }); cg.moveZero(accUseLo) end
		if not newLo then newLo = allocTemp({ role = "nullnew" }); cg.moveZero(newLo) end
		emitAtomicCasCall(effTemp, capLo, accUseT, accUseLo, newIv, newLo)
		marshalResultPtr(accDefT, accDefLo)
		-- Native cmpxchg sets flags from (accumulator - dest); dest's old value is
		-- the returned old value, so (expected - old) reproduces the native flags
		-- exactly (ZF=1 iff the exchange happened). MUST be the last flag-affecting
		-- step: a following je/sete behaves natively.
		emit(build.insn("cmp", { build.rt(expCopy), build.rt(accDefT) },
			{ uses = { expCopy, accDefT } }))
	end

	-- Pointer-RMW support (`;! load store ptr` / `;! atomic load store ptr`).
	local RMW_UNARY = { inc = true, dec = true, neg = true, ["not"] = true }

	-- The source operand of a supported pointer-RMW node: a register web temp or an
	-- immediate operand (neither for the unary inc/dec/neg/not forms).
	local function rmwSource(node)
		local bm = cgm.baseMnemonic(string.lower(node.stmt.mnemonic))
		if RMW_UNARY[bm] then return nil, nil, true end
		local so = node.stmt.operands[2]
		if so and so.kind == "reg" then
			local t = node.opTemp[so]
			if not t then
				error("sarcasm: `;! " .. node.stmt.annotation .. "` source register has no"
					.. " temp: " .. (node.stmt.raw or "?"))
			end
			return t, nil, false
		end
		return nil, so, false   -- immediate operand (the 8-byte form was validated)
	end

	-- Re-emit the annotated ALU operation as a register operation: dstT = dstT OP src.
	local function emitRmwAluOp(node, dstT, srcT, srcImmOp, unary)
		local operands = { build.rt(dstT) }
		local uses = { dstT }
		if not unary then
			if srcT then table.insert(operands, build.rt(srcT)); table.insert(uses, srcT)
			else table.insert(operands, srcImmOp) end
		end
		emit(build.insn(node.stmt.mnemonic, operands, { defs = { dstT }, uses = uses }))
	end

	-- Recompute the native flags of the RMW (old OP src) as the last flag-affecting
	-- step (see the EFLAGS comment above). `not` sets no flags (native behavior is
	-- "flags unchanged", unrecoverable across the injected checks — the documented
	-- EFLAGS caveat); adc/sbb read a carry-in the checks already clobbered (also
	-- documented-indeterminate, like the pinned adcx forms) — and note the clobbered
	-- carry-in already affected the STORED result too: the op itself ran on it right
	-- after the load/check sequence (deterministically CF=0 for the non-atomic
	-- `;! load store ptr` path, whose last flag-affecting instruction is a `test`;
	-- whatever the runtime call left for the atomic forms).
	local function emitRmwFlags(node, oldIv, srcT, srcImmOp, unary)
		local scratch = allocTemp({ role = "rmwflags" })
		cg.move(scratch, oldIv)
		emitRmwAluOp(node, scratch, srcT, srcImmOp, unary)
	end

	-- `;! load store ptr`: NON-atomic RMW on a pointer slot = the box-aware
	-- non-atomic pointer load, the ALU op on the intval, then the non-atomic
	-- pointer store (checks incl. CanWrite, ensure-aux, barrier, lower+iv stores).
	-- The capability rides through unchanged — Fil-C pointer arithmetic through
	-- memory.
	local function emitLoadStorePtr(node, mem)
		local srcT, srcImmOp, unary = rmwSource(node)
		local oldIv = allocTemp({ role = "lspold" })
		local oldLo = allocTemp({ role = "lsplo" })
		emitPtrLoad(node, mem, oldIv, oldLo)
		emitRootStore(oldLo)
		local newIv = allocTemp({ role = "lspnew" })
		cg.move(newIv, oldIv)
		emitRmwAluOp(node, newIv, srcT, srcImmOp, unary)
		emitPtrStore(node, mem, newIv, oldLo)
		emitRmwFlags(node, oldIv, srcT, srcImmOp, unary)
	end

	-- `;! atomic load store ptr` on ARM64: an LSE atomic RMW (ldadd/ldset/ldeor/
	-- ldclr/swp, or the st<op> no-result aliases) on a pointer slot.
	--
	-- ldadd/ldset/ldeor/ldclr (and the st<op> aliases): the native instruction
	-- is already a single atomic RMW, so the faithful lowering is the runtime
	-- compare-exchange loop — exactly the x86 `lock` form's shape (inline
	-- checks once before the loop; per iteration a pollcheck, an atomic load,
	-- the op re-executed on the intval as a register operation, and
	-- filc_strong_cas_ptr_with_manual_tracking with expected = current old and
	-- new = old.iv OP src carrying the SAME lower — the capability rides
	-- through: Fil-C pointer arithmetic through memory).
	--
	-- swp is the exception: its "op" is a plain move of the SOURCE, so the new
	-- value is not derived from the old one and must carry the SOURCE's
	-- capability — a source pointer into a DIFFERENT object stored with the
	-- old value's lower would trap on first dereference. swp therefore lowers
	-- to a single filc_xchg_ptr_with_manual_tracking call (the exact primitive
	-- filcc emits for C11 atomic_exchange) with new = (src.iv, src's OWN
	-- lower); a non-pointer source has no lower temp and gets a null
	-- capability (mirroring emitAtomicPtrStore — storing an integer into a
	-- pointer slot is legal; it just can't be dereferenced afterwards).
	--
	-- Either way the old-value destination register (ldadd's Wt / swp's Wt)
	-- receives the old value AS A POINTER (old.iv, old.lo, rooted — exactly
	-- like an `;! atomic load ptr` result); the st<op> forms have no
	-- destination. NZCV is preserved across the whole sequence (the native
	-- instruction writes no flags — the dispatch below brackets the emission
	-- withFlagSave when the program's flags are live).
	local lseRmwCounter = 0
	local function emitAtomicLoadStorePtrLse(node, mem)
		local m = string.lower(node.stmt.mnemonic)
		local plan = cgm.atomicRmwPlan(m)
		local ops = node.stmt.operands
		-- operand roles (swp and the ld<op> forms agree: ops[1] = source,
		-- ops[2] = old-value destination); the st<op> aliases have no
		-- old-value destination.
		local srcOp = ops[1]
		local dstOp = (plan.kind == "st") and nil or ops[2]
		local srcT = srcOp and node.opTemp[srcOp] or nil
		if not srcT then
			error("sarcasm: `;! atomic load store ptr` source register has no temp: "
				.. (node.stmt.raw or "?"))
		end
		local dstT = dstOp and node.opTemp[dstOp] or nil
		local effTemp, capLo = cg.computeAddr(node, mem)
		emitAccessCheck(effTemp, capLo, 8, 8, true)
		-- a null capability trapped above; keep the (unreachable) fall-through
		-- well-formed with a null-lower marshal temp
		local capLoArg = capLo
		if not capLoArg then capLoArg = allocTemp({ role = "nullcap" }); cg.moveZero(capLoArg) end
		local oldIv = allocTemp({ role = "alspold" })
		local oldLo = allocTemp({ role = "alsplo" })
		if plan.alu == "mov" then
			-- swp: the new value IS the source operand, so it carries the
			-- SOURCE's capability (a null capability for a non-pointer
			-- source) — never the old value's lower. One runtime exchange
			-- call, no CAS loop (filcc's C11 atomic_exchange shape).
			local newLo = pf.lowerTemp[srcT]
			if not newLo then newLo = allocTemp({ role = "nullnew" }); cg.moveZero(newLo) end
			emitAtomicXchgCall(effTemp, capLoArg, srcT, newLo)
			marshalResultPtr(oldIv, oldLo)
		else
			local newIv = allocTemp({ role = "alspnew" })
			lseRmwCounter += 1
			local loopTop = ".Llcasloop_" .. name .. "_" .. lseRmwCounter
			cg.label(loopTop)
			-- a safepoint on every iteration (a contended CAS loop must not starve
			-- the GC's stop-the-world; filcc's atomic-RMW loops pollcheck too)
			emitPollcheck()
			emitAtomicLoadCall(effTemp, capLoArg)
			marshalResultPtr(oldIv, oldLo)
			-- new = old OP src (the annotated op re-executed as a register
			-- operation on the intval), carrying the SAME lower as old.
			emit(build.insn(plan.alu, { build.rt(newIv), build.rt(oldIv), build.rt(srcT) },
				{ defs = { newIv }, uses = { oldIv, srcT } }))
			emitAtomicCasCall(effTemp, capLoArg, oldIv, oldLo, newIv, oldLo)
			local casIv = allocTemp({ role = "alspcas" })
			cg.move(casIv, pColored(cc.rtRet))
			cg.cmpBranch(oldIv, casIv, "ne", loopTop)   -- mismatch: retry
		end
		-- the old-value destination receives the old value AS A POINTER (old.iv,
		-- old.lo — seeded in ptrflow, like an `;! atomic load ptr` result); the
		-- lower rides the final iteration's marshal temps.
		if dstT then
			cg.move(dstT, oldIv)
			local dstLo = pf.lowerTemp[dstT]
			if dstLo then
				cg.move(dstLo, oldLo)
				emitRootStore(dstLo)
			end
		end
	end

	-- `;! atomic load store ptr`: WITHOUT `lock`, an atomic load, the op, and an
	-- atomic store (each access atomic; the RMW as a whole is not). WITH `lock`, a
	-- compare-exchange loop through the runtime — a real atomic RMW. (x86_64; the
	-- arm64 LSE form lowers to emitAtomicLoadStorePtrLse above.)
	local alrmwCounter = 0
	local function emitAtomicLoadStorePtr(node, mem)
		if cgm.atomicRmwPlan then
			-- arm64: the LSE RMW is already atomic, so only the compare-exchange
			-- loop lowering exists; NZCV is preserved across it (the native
			-- instruction writes no flags).
			withFlagSave(flagsLiveFrom(nodeIndex[node]), function()
				emitAtomicLoadStorePtrLse(node, mem)
			end)
			return
		end
		local srcT, srcImmOp, unary = rmwSource(node)
		local effTemp, capLo = cg.computeAddr(node, mem)
		emitAccessCheck(effTemp, capLo, 8, 8, true)
		-- a null capability trapped above; keep the (unreachable) fall-through
		-- well-formed with a null-lower marshal temp
		local capLoArg = capLo
		if not capLoArg then capLoArg = allocTemp({ role = "nullcap" }); cg.moveZero(capLoArg) end
		local oldIv = allocTemp({ role = "alspold" })
		local oldLo = allocTemp({ role = "alsplo" })
		local newIv = allocTemp({ role = "alspnew" })
		if not node.stmt.lockPrefix then
			emitAtomicLoadCall(effTemp, capLoArg)
			marshalResultPtr(oldIv, oldLo)
			cg.move(newIv, oldIv)
			emitRmwAluOp(node, newIv, srcT, srcImmOp, unary)
			emitAtomicStoreCall(effTemp, capLoArg, newIv, oldLo)
		else
			alrmwCounter += 1
			local loopTop = ".Lcasloop_" .. name .. "_" .. alrmwCounter
			cg.label(loopTop)
			-- a safepoint on every iteration (a contended CAS loop must not starve
			-- the GC's stop-the-world; filcc's atomic-RMW loops pollcheck too)
			emitPollcheck()
			emitAtomicLoadCall(effTemp, capLoArg)
			marshalResultPtr(oldIv, oldLo)
			cg.move(newIv, oldIv)
			emitRmwAluOp(node, newIv, srcT, srcImmOp, unary)
			emitAtomicCasCall(effTemp, capLoArg, oldIv, oldLo, newIv, oldLo)
			local casIv = allocTemp({ role = "alspcas" })
			cg.move(casIv, pColored(cc.rtRet))
			cg.cmpBranch(oldIv, casIv, "ne", loopTop)   -- mismatch: retry
		end
		emitRmwFlags(node, oldIv, srcT, srcImmOp, unary)
	end

	local excLabel = nil
	local function ensureExcLabel() if not excLabel then excLabel = ".Lexc_" .. name end return excLabel end
	local calledExterns = {}

	-- move the web's capability (its lower, or null) into a physical register.
	local function emitCapMove(destReg, web)
		local pDest = pColored(destReg)
		local loT = web and pf.lowerTemp[web]
		if loT then cg.move(pDest, loT) else cg.moveZero(pDest) end
		return pDest
	end

	local function emitCall(node)
		local cs = callSigOf(node.stmt)
		local callee = node.stmt.operands[1].text
		calledExterns[callee] = { name = callee, sig = cs.signature, sigDesc = cs,
			sigName = "pizlonatedFI" .. cs.signature .. "_" .. callee }
		-- FP signatures are arm64-only (x86_64 rejects them at checkCallsiteSig);
		-- error defensively if a backend without the FP marshalling atoms got here.
		local hasFp = csHasFp(cs)
		if hasFp and not cg.storeFpArg then
			error("sarcasm: internal error: floating-point signature marshalling is"
				.. " not implemented for this target (call to '" .. callee .. "')")
		end
		local argTemps = {}
		for _, r in node.c.uses do if r.argReg then argTemps[r.num] = node.opTemp[r] end end
		cg.move(pColored(cc.myth), vMyth)
		local callUses = { pColored(cc.myth) }
		local fpVecUses = nil
		for k = 1, cs.argWords do
			if isFp(cs.argTypes[k]) then
				-- FP arg: passes through its v register (placed there by the source
				-- program, per AAPCS) — no GPR marshalling, but the value must stay
				-- live up to the call for the FP save/restore liveness.
				local m = fpOrdinalOf(cs.argTypes, k)
				fpVecUses = fpVecUses or {}
				fpVecUses[m] = sig.fpWidthBytes(cs.argTypes[k])
			else
				local aTemp = argTemps[cc.yoloArg(k, cs.argTypes)]
				cg.move(pColored(cc.argIv(cs.argTypes, k)), aTemp)
				table.insert(callUses, pColored(cc.argIv(cs.argTypes, k)))
				if cs.argTypes[k] == 7 then table.insert(callUses, emitCapMove(cc.argLo(cs.argTypes, k), aTemp)) end
			end
		end
		local callNode = cg.call("pizlonatedFI" .. cs.signature .. "_" .. callee, callUses, cg.callerSavedClobbers())
		if fpVecUses then callNode.fpVecUses = fpVecUses end
		cg.exceptionBranch(ensureExcLabel())
		if not cs.isVoid and not isFp(cs.retTypes[1]) then
			cg.move(node.defTemps[1], pColored(cc.retIv))
			if cs.retIsPtr then
				-- a pointer call result is (iv, lo); define its lower from retLo and root it
				-- before any later safepoint can run.
				local loT = pf.lowerTemp[node.defTemps[1]]
				if loT then
					cg.move(loT, pColored(cc.retLo))
					emitRootStore(loT)
				end
			end
		end
	end

	-- Annotated register-indirect call (`call *%reg ;! sig(...)` on x86_64,
	-- `blr xN ;! sig(...)` on arm64 — the sequence below is arch-neutral; the
	-- x86-isms live in the cg hooks). Emits filcc's exact indirect-call
	-- sequence for a flight pointer (P = target intval, L = target lower):
	--   1. L == 0 -> fail (null capability);
	--   2. aux = [L-8]; (aux & 0x780000000000000) != 0x80000000000000 -> fail
	--      (object's special type must be FUNCTION);
	--   3. P != (aux & 0xFFFFFFFFFFFF) -> fail (ptr must equal the object's aux
	--      pointer);
	--   4. [L+16] == S (the callsite signature number) -> fast path: call *[L+0]
	--      with the fast-CC marshalling below; otherwise the GENERIC path marshals
	--      the arguments through my_thread's CC buffer (data words at 128(myth),
	--      aux/lower words at 384(myth)), sets the argument byte size (the CC's
	--      third runtime argument register: edx / x2), and calls the generic
	--      entrypoint *[L+8], then tests the exception flag FIRST (on the
	--      exception edge the ret-size register is undefined, so the ret-size
	--      check must not run first), checks the returned ret_size, and unmarshals
	--      the result from the buffer into the fast-CC return registers — exactly
	--      the L_generic mismatch path of the direct-call callsite thunk
	--      (x86_64_glue / arm64_glue callsiteThunk), INLINED. filcc instead
	--      dispatches to pizlonated1ET<S> there, but that weak thunk only exists
	--      when some C compilation unit in the link contains an indirect callsite
	--      with signature S — referencing it would be a link error otherwise, so
	--      sarcasm must not (and does not) depend on it. The buffer-CC callee has
	--      the SAME callsite-visible ABI as the fast entrypoint (flag bit0 =
	--      exception flag; result in the ret registers after unmarshalling), so
	--      both paths rejoin at the shared exception check + result unpacking.
	--   5. fail: (P, L) = (arg0, arg1), call filc_check_function_call_fail
	--      (noreturn; the runtime re-derives the precise cause).
	-- No bounds check: a function object's bounds are degenerate (upper == lower).
	-- GC safety is exactly emitCall's: the target's lower and every pointer
	-- argument's lower were rooted into the frame's root slots when their webs
	-- were defined (entry, `;! load ptr`, a ptr-returning call), so every lower
	-- live across the call is in its slot; a pointer result's lower is rooted
	-- right after the call.
	local indcallCounter = 0
	local function emitIndirectCall(node)
		local cs = callSigOf(node.stmt)
		local raw = node.stmt.raw or node.stmt.mnemonic or "?"
		-- FP signatures are arm64-only (x86_64 rejects them at checkCallsiteSig);
		-- error defensively if a backend without the FP marshalling atoms got here.
		local hasFp = csHasFp(cs)
		if hasFp and not cg.storeFpArg then
			error("sarcasm: internal error: floating-point signature marshalling is"
				.. " not implemented for this target (indirect call): " .. raw)
		end
		local targetOp = node.stmt.operands and node.stmt.operands[1]
		local fpIv = targetOp and node.opTemp[targetOp] or nil
		local fpLo = fpIv and pf.lowerTemp[fpIv] or nil
		if not (fpIv and pf.isPtr[fpIv] and fpLo) then
			-- The target register's web is not a known pointer value, so its
			-- lower (capability) is unknowable and the callee-is-a-function
			-- checks cannot be emitted.
			error("sarcasm: indirect call target must be a function pointer value"
				.. " (a pointer argument, or the result of `;! load ptr` /"
				.. " a ptr-returning call): " .. raw)
		end
		indcallCounter += 1
		local tag = name .. "_" .. indcallCounter
		local genL = ".Lindcall_generic_" .. tag
		local rejoinL = ".Lindcall_rejoin_" .. tag
		local failL = ".Lindcall_fail_" .. tag
		local retfailL = ".Lindcall_retfail_" .. tag

		-- yolo argument webs (SysV argument registers), exactly like emitCall.
		local argTemps = {}
		for _, r in node.c.uses do if r.argReg then argTemps[r.num] = node.opTemp[r] end end

		-- 1. null capability
		cg.branchZero(fpLo, failL)
		-- 2. special type == FUNCTION (aux word at [L-8])
		local auxT = allocTemp({ role = "scratch" })
		cg.load(auxT, fpLo, -8, 8)
		local maskedT = allocTemp({ role = "scratch" })
		cg.andConst(maskedT, auxT, "0x780000000000000")   -- maskedT = aux & FUNCTION-type mask
		local valT = allocTemp({ role = "scratch" })
		cg.movBig(valT, "0x80000000000000")
		cg.cmpBranch(maskedT, valT, "ne", failL)
		-- 3. ptr == canonical entrypoint (aux & 0xFFFFFFFFFFFF)
		local canonT = allocTemp({ role = "scratch" })
		cg.move(canonT, auxT, true)
		cg.maskLow48(canonT)
		cg.cmpBranch(fpIv, canonT, "ne", failL)
		-- 4. signature dispatch: [L+16] == S -> fast entrypoint at [L+0]
		local sigT = allocTemp({ role = "scratch" })
		cg.load(sigT, fpLo, 16, 8)
		-- the signature number can exceed any arch's immediate-compare range, so
		-- the compare goes through the widened hook (x86_64: plain cmp imm32;
		-- arm64: plain 12-bit cmp when it fits, else the movz/sub-cmp schemes).
		cg.cmpImmBranchWidened(sigT, cs.signature, "ne", genL)
		local fnT = allocTemp({ role = "scratch" })
		cg.load(fnT, fpLo, 0, 8)
		-- fast path: myth = CC myth, fo = callee lower, dense fast-CC args.
		-- FP args are SKIPPED (they pass through their v registers, placed there by
		-- the source program per AAPCS) — but they must stay live up to the call,
		-- so the call node is tagged with their vector uses for the FP save/restore
		-- liveness (fpVecUses, see arm64_codegen.expandFpSaves).
		cg.move(pColored(cc.myth), vMyth)
		cg.move(pColored(cc.fo), fpLo)
		local fastUses = { pColored(cc.myth), pColored(cc.fo), fnT }
		local fpVecUses = nil
		for k = 1, cs.argWords do
			if isFp(cs.argTypes[k]) then
				local m = fpOrdinalOf(cs.argTypes, k)
				fpVecUses = fpVecUses or {}
				fpVecUses[m] = sig.fpWidthBytes(cs.argTypes[k])
			else
				local aTemp = argTemps[cc.yoloArg(k, cs.argTypes)]
				cg.move(pColored(cc.argIv(cs.argTypes, k)), aTemp)
				table.insert(fastUses, pColored(cc.argIv(cs.argTypes, k)))
				if cs.argTypes[k] == 7 then table.insert(fastUses, emitCapMove(cc.argLo(cs.argTypes, k), aTemp)) end
			end
		end
		local fastNode = cg.emitIndirectCallInsn(fnT, fastUses, cg.callerSavedClobbers())
		if fpVecUses then fastNode.fpVecUses = fpVecUses end
		cg.jump(rejoinL)
		-- generic (buffer-CC) path for a signature mismatch: marshal the args into
		-- my_thread's CC buffer, set the argument byte size, call *[L+8]. The buffer
		-- word index is the argument's DECLARATION index for EVERY class: GPR intval
		-- words at 128+8i (lower words at 384+8i), FP args as one 8-byte word at
		-- 128+8i (a float writes the low 4 bytes; the upper bytes are never read)
		-- with a zero aux word at 384+8i — exactly filcc's buffer marshalling. The
		-- FP values are read straight out of their v registers (still live there).
		cg.label(genL)
		local argBytes = cs.argWords * 8
		local zeroT = nil
		for k = 1, cs.argWords do
			local ty = cs.argTypes[k]
			local bufOff = 128 + 8 * (k - 1)
			local loOff = 384 + 8 * (k - 1)
			if isFp(ty) then
				cg.storeFpArg(ty, fpOrdinalOf(cs.argTypes, k), vMyth, bufOff)
				if not zeroT then zeroT = allocTemp({ role = "scratch" }); cg.moveZero(zeroT) end
				cg.store(zeroT, vMyth, loOff)
			else
				local aTemp = argTemps[cc.yoloArg(k, cs.argTypes)]
				cg.store(aTemp, vMyth, bufOff)
				local loT = (ty == 7) and pf.lowerTemp[aTemp] or nil
				if loT then
					cg.store(loT, vMyth, loOff)
				else
					-- scalar arg (or a pointer arg whose web has no capability):
					-- the aux word is 0, exactly like the callsite thunk.
					if not zeroT then zeroT = allocTemp({ role = "scratch" }); cg.moveZero(zeroT) end
					cg.store(zeroT, vMyth, loOff)
				end
			end
		end
		cg.moveImm(pColored(cc.rtArg(3)), argBytes)   -- argument byte size (CC arg 3)
		cg.move(pColored(cc.myth), vMyth)             -- myth = CC myth register
		cg.move(pColored(cc.fo), fpLo)                -- fo = callee lower
		cg.emitGenericIndirectCall(fpLo,
			{ pColored(cc.myth), pColored(cc.fo), pColored(cc.rtArg(3)), fpLo },
			cg.callerSavedClobbers())
		-- Test the exception flag IMMEDIATELY after the generic call, BEFORE the
		-- ret-size check and the result unmarshal — exactly L_generic's order in
		-- the callsite thunk (and filcc's pizlonated1ET thunk). On the exception
		-- edge the buffer CC leaves the ret-size register (rdx / x1) UNDEFINED, so
		-- a ret-size check running first could spuriously fire
		-- filc_cc_rets_check_failure instead of propagating the exception. Branches
		-- to the SAME shared exception label the fast path's rejoin test uses.
		cg.exceptionBranch(ensureExcLabel())
		if cs.retWords >= 1 then
			-- the buffer CC returns the actual result byte size in the retIv
			-- register (rdx / x1); it must cover the signature's result words (else
			-- filc_cc_rets_check_failure), then the result unmarshals into the
			-- fast-CC return registers. An FP result (float/double) unmarshals from
			-- the buffer into v0 (s0/d0) instead of the retIv register.
			local retBytes = cs.retWords * 8
			cg.cmpImmBranchWidened(pColored(cc.retIv), retBytes - 1, "ule", retfailL)
			if isFp(cs.retTypes[1]) then
				cg.loadFpRet(cs.retTypes[1], vMyth, 128)
			else
				cg.load(pColored(cc.retIv), vMyth, 128, 8)
				if cs.retIsPtr then cg.load(pColored(cc.retLo), vMyth, 384, 8) end
			end
		end
		-- rejoin: exception-flag test + result unpacking, identical to emitCall.
		-- (On the generic fall-through edge the flag is already known clear, so
		-- the shared re-test just falls through.)
		cg.label(rejoinL)
		cg.exceptionBranch(ensureExcLabel())
		if not cs.isVoid and not isFp(cs.retTypes[1]) then
			cg.move(node.defTemps[1], pColored(cc.retIv))
			if cs.retIsPtr then
				local loT = pf.lowerTemp[node.defTemps[1]]
				if loT then
					cg.move(loT, pColored(cc.retLo))
					emitRootStore(loT)
				end
			end
		end
		-- fail stubs (noreturn; emitted at function end): the function-call check
		-- failure gets the flight pointer (arg0 = P, arg1 = L); the buffer-CC
		-- ret-size failure gets (arg0 = actual size, arg1 = expected size, arg2 = 0).
		cg.emitIndcallFailStub(failStubs, failL, fpIv, fpLo)
		if cs.retWords >= 1 then
			cg.emitRetsFailStub(failStubs, retfailL, pColored(cc.retIv), cs.retWords * 8)
		end
	end

	-- Stack allocations. `;! alloca size (x)` captures the byte size; `;! alloca result (x)` /
	-- `;! alloca result size=N` becomes filc_allocate(myth, size); payload = allocation+16.
	local allocaSizes = {}
	local function emitAlloca(node, al)
		if al.kind == "size" then
			local sizeOp = cgm.allocaSizeOperand(node.stmt)
			local sizeTemp = allocTemp({ role = "allocasize" })
			-- node.opTemp is non-nil only for operands the lift modeled (GPRs); anything
			-- else (e.g. a vector register) is not a usable size operand.
			if sizeOp and sizeOp.kind == "reg" and node.opTemp[sizeOp] then cg.move(sizeTemp, node.opTemp[sizeOp], true)
			elseif sizeOp and sizeOp.kind == "imm" then cg.moveImm(sizeTemp, sizeOp.value or tonumber(sizeOp.text))
			else error("sarcasm: `alloca size` instruction has no size operand: " .. node.stmt.raw) end
			allocaSizes[al.name] = sizeTemp
			return
		end
		cg.move(pColored(cc.rtArg(1)), vMyth)
		if al.kind == "result" then
			local sizeTemp = allocaSizes[al.name]
			if not sizeTemp then
				error("sarcasm: `alloca result (" .. al.name .. ")` has no preceding `alloca size (" .. al.name .. ")`")
			end
			cg.move(pColored(cc.rtArg(2)), sizeTemp)
		else
			cg.moveImm(pColored(cc.rtArg(2)), al.size)
		end
		-- Injected returning runtime call: preserve live FP/SIMD state around it
		-- (no-op for GPR-only functions).
		cg.fpSave()
		cg.call("filc_allocate", { pColored(cc.rtArg(1)), pColored(cc.rtArg(2)) }, cg.callerSavedClobbers())
		cg.fpRestore()
		local resultIv = node.defTemps and node.defTemps[1]
		if not resultIv then error("sarcasm: `alloca result` instruction has no destination register: " .. node.stmt.raw) end
		local ret = pColored(cc.rtRet)  -- allocation base; payload = base + 16
		if al.region then
			local r = al.region
			cg.effAddr(resultIv, ret, 16)
			if r.loTemp then cg.effAddr(r.loTemp, ret, 16) end
			cg.effAddr(r.ptrTemp, ret, 16)
			if r.loTemp then emitRootStore(r.loTemp) end
		else
			local resultLo = pf.lowerTemp[resultIv]
			cg.effAddr(resultIv, ret, 16)
			cg.effAddr(resultLo, ret, 16)
			emitRootStore(resultLo)
		end
	end

	-- Redirect an sp-relative address computation that lands inside a fixed alloca region to
	-- the allocation pointer (gcc -O0). Arch-specific; returns true if it replaced the node.
	local function emitRegionRedirect(node)
		if #allocaRegions == 0 or not cg.regionRedirect then return false end
		return cg.regionRedirect(node, regionOf)
	end

	-- Walk the lifted body.
	for _, node in lf.nodes do
		if node.kind == "label" then
			if node.name ~= name and not string.match(node.name, "^%.LF[BE]") then
				emit(node)
				if loopHeaderLabels[node.name] then
					withFlagSave(flagsLiveFrom(nodeIndex[node] + 1), emitPollcheck)
				end
			end
		elseif node.kind == "other" then
			-- drop directives
		elseif node.kind == "insn" then
			local c = node.c
			curLine = (node.stmt and node.stmt.line) or curLine
			if allocaNodes[node] then
				withFlagSave(flagsLiveFrom(nodeIndex[node]), function()
					emitAlloca(node, allocaNodes[node])
				end)
			elseif c.control == "return" then
				-- An FP-returning function (float/double on arm64) leaves the value
				-- in v0 — skip the retIv move (and the ptr-lower cap move; an FP
				-- return is never a pointer), exactly like the void case skips both.
				if not sigDesc.isVoid and not retIsFp then
					local retTemp
					for _, r in c.uses do if r.retReg then retTemp = node.opTemp[r] end end
					if retTemp then cg.move(pColored(cc.retIv), retTemp) end
					if sigDesc.retIsPtr then emitCapMove(cc.retLo, retTemp) end
				end
				cg.clearRetFlag()
				emit({ kind = "epilogue", name = name, useTemps = { vMyth } })
				emit(build.insn("ret", {}, { control = "return", fallsThrough = false }))
			elseif c.control == "call" and callNodes[node] then
				emitCall(node)
			elseif c.control == "indcall" then
				-- The annotation classification above already rejected every
				-- unannotated or memory-operand indirect call, so only an
				-- annotated register-indirect call reaches here (on both
				-- architectures).
				emitIndirectCall(node)
			elseif emitRegionRedirect(node) then
				-- sp-relative address computation redirected into an alloca region
			else
				local mem = cgm.memOperand(node.stmt)
				if cg.lowerSpecial(node, mem) then
					-- arch-specific passthrough lowering (e.g. x86 cltq -> movslq, lea passthrough)
				elseif loadPtrDefs[node] then
					local dstIv = node.defTemps[1]
					-- an FP/vector (or otherwise unmodeled) destination has no temp:
					-- reject cleanly instead of indexing the lower-temp table with nil.
					if not dstIv then
						error("sarcasm: `;! load ptr` requires a modeled (GPR) destination"
							.. " register: " .. (node.stmt.raw or "?"))
					end
					local dstLo = pf.lowerTemp[dstIv]
					withFlagSave(flagsLiveFrom(nodeIndex[node]), function()
						emitPtrLoad(node, mem, dstIv, dstLo)
						emitWriteback(node, mem)
					end)
					emitRootStore(dstLo)
				elseif storePtrNodes[node] then
					local valOp = storeValueOperand(node.stmt, mem)
					local valIv = valOp and node.opTemp[valOp] or nil
					if not valIv then
						error("sarcasm: `;! store ptr` requires a modeled (GPR) value"
							.. " register: " .. (node.stmt.raw or "?"))
					end
					local valLo = pf.lowerTemp[valIv]
					withFlagSave(flagsLiveFrom(nodeIndex[node]), function()
						emitPtrStore(node, mem, valIv, valLo)
						emitWriteback(node, mem)
					end)
				elseif atomicLoadPtrDefs[node] then
					-- arm64: ldar/ldapr write no flags — preserve the program's
					-- live NZCV around the injected check+call (x86_64:
					-- flagsLiveFrom is constant-false, so this wrap is a plain
					-- passthrough and the output is unchanged).
					withFlagSave(flagsLiveFrom(nodeIndex[node]), function()
						emitAtomicPtrLoad(node, mem)
					end)
				elseif atomicStorePtrNodes[node] then
					withFlagSave(flagsLiveFrom(nodeIndex[node]), function()
						emitAtomicPtrStore(node, mem)
					end)
				elseif atomicCasPtrDefs[node] then
					-- bypasses emitPinned entirely: the runtime call needs no
					-- physical rax pinning (see emitAtomicPtrCas)
					emitAtomicPtrCas(node, mem)
				elseif loadStorePtrNodes[node] then
					emitLoadStorePtr(node, mem)
				elseif atomicRmwPtrNodes[node] then
					emitAtomicLoadStorePtr(node, mem)
				elseif mem then
					cg.checkMemInsn(node, mem)
					local effTemp, capLo = cg.computeAddr(node, mem)
					local size, align = cgm.accessSizeAlign(node.stmt)
					local isWrite = cgm.isStoreInsn(node.stmt)
					-- AVX512 {k}-masked / AVX2 vmaskmov memory operands get the
					-- mask-aware check (x86_64 only; nil everywhere else).
					local minfo = cgm.maskedAccessInfo and cgm.maskedAccessInfo(node.stmt)
					if minfo then
						emitMaskedAccessCheck(effTemp, capLo, minfo, align, isWrite)
					else
						withFlagSave(flagsLiveFrom(nodeIndex[node]), function()
							emitAccessCheck(effTemp, capLo, size, align, isWrite)
						end)
					end
					-- an implicit-GPR-pinned instruction (x86 div/mul/cmpxchg/...)
					-- emits its pin moves around itself; the access check above
					-- rightly precedes the pin-in (checks never touch GPRs)
					if not (cg.emitPinned and cg.emitPinned(node)) then emit(node) end
				else
					if not (cg.emitPinned and cg.emitPinned(node)) then emit(node) end
				end
			end
		else
			emit(node)
		end
	end

	if excLabel then
		emit(build.label(excLabel))
		emit({ kind = "epilogue", name = name, useTemps = { vMyth } })
		emit(build.insn("ret", {}, { control = "return", fallsThrough = false }))
	end
	for _, s in failStubs do emit(s) end

	-- FP/SIMD save/restore expansion: cg.fpSave/fpRestore emitted PLACEHOLDER
	-- nodes around the injected returning runtime calls; expand them now into
	-- the exact vector save/restore movs the post-transform width-liveness
	-- analysis proves live at each site. Runs BEFORE the frameSlot numRoots
	-- shift below so the expanded movs' frameSlot operands are shifted with
	-- everything else, and pre-regalloc (the movs carry no temps — regalloc
	-- never sees vector-class registers, and no placeholder node kind ever
	-- leaks past this point). The third argument is the final GC root count
	-- (arm64's hook computes its slot base from it directly; x86_64's hook
	-- ignores it — it tags slots frameSlot and rides the shift below instead).
	if cg.expandFpSaves then cg.expandFpSaves(out, fctx, #rootTemps) end

	-- DETERMINISM: externsList is consumed per-function to build the module-level
	-- callsite-thunk map, whose emission order is fixed in sarcasm.compile; build it
	-- in sorted-callee order so the array (and anything downstream of it) does not
	-- inherit hash iteration order from the string-keyed calledExterns map.
	local externsList = {}
	do
		local calleeNames = {}
		for callee in calledExterns do table.insert(calleeNames, callee) end
		table.sort(calleeNames)
		for _, callee in calleeNames do table.insert(externsList, calledExterns[callee]) end
	end

	-- GC root-slot ABI fixup (x86_64 FP/SIMD): the Fil-C GC reads a frame's roots as
	-- frame->lowers[index] (filc_frame: parent, origin, then lowers[]), so the root
	-- slots MUST occupy frame offsets [16, 16+8*numRoots). The FP/SIMD regions — the
	-- vector-save area and the materialized frame-slot clusters, all marked
	-- frameSlot — were assigned offsets relative to base 16 by analyzeFrame /
	-- preprocess / codegen before numRoots was known; shift them past the root area
	-- (and its 16-byte alignment pad, matching computeLayout) now. The shift is a
	-- multiple of 16, preserving the clusters' mod-16 alignment residues
	-- (movaps-class accesses). No-op on arm64 (no frameSlot operands) and whenever
	-- there are no roots.
	do
		local shift = 8 * #rootTemps
		if fctx and fctx.fp and (fctx.fp.bytes + fctx.fp.saveBytes) > 0 and #rootTemps % 2 == 1 then
			shift += 8
		end
		if shift > 0 then
			local seen = {}
			local function shiftOps(ops)
				for _, o in (ops or {}) do
					if o.kind == "mem" and o.frameSlot and not seen[o] then
						seen[o] = true
						o.dispVal = o.dispVal + shift
					end
				end
			end
			for _, node in out do
				shiftOps(node.operands)
				if node.stmt then shiftOps(node.stmt.operands) end
			end
		end
	end

	return {
		name = name, sigDesc = sigDesc, fipNodes = out, temps = temps, vMyth = vMyth,
		originSym = originSym, numRoots = #rootTemps, funcLine = funcLine, nextTemp = nextTemp,
		rootTemps = rootTemps, accessOrigins = accessOrigins, calledExterns = externsList,
		lf = lf, pf = pf,
		-- FP/SIMD frame-slot region sizes for the layout (0 on arm64 / when no FP
		-- stack slot was materialized).
		fpBytes = (fctx and fctx.fp and fctx.fp.bytes) or 0,
		fpSaveBytes = (fctx and fctx.fp and fctx.fp.saveBytes) or 0,
	}
end

return transform
