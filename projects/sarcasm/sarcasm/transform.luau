--!nonstrict
-- The GIMSO transform (architecture-independent): rewrite a lifted yolo function into a
-- memory-safe Fil-C fast-entrypoint body (IR nodes), plus metadata for glue/prologue/
-- epilogue emission. The walk and every invisicap sequence (access checks, pointer loads/
-- stores with the FUGC store barrier, atomic pointer loads/stores/compare-exchange and
-- pointer RMWs via the Fil-C runtime, calls, pollchecks, allocations) live here ONCE; the
-- actual instructions are produced through a per-arch codegen `cg` (arm64_codegen /
-- x86_64_codegen), so the safety-critical logic is single-source across ISAs. (The
-- atomic pointer operations are x86_64-only: the arm64 backend rejects their
-- annotations during shape validation, so those sequences are unreachable there.)
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

function transform.transformFunction(name, sigDesc, body, backend)
	local cgm = backend.cg          -- codegen module (static config + make)
	local framePolicy = backend.frame  -- per-arch frame policy (analyzeFrame + rewrite)
	local cc = cgm.cc

	local returnRegs = sigDesc.isVoid and {} or {0}
	local funcLine = (body[1] and body[1].line) or 0
	local curLine = funcLine

	-- Frame geometry (size, whether rbp/x29 is the frame pointer) is needed before the
	-- region scan: fixed alloca bases are normalized to sp-relative frame offsets, which
	-- requires frameSize. The analysis is pure; frame.preprocess re-runs it internally.
	local fctx = nil
	if framePolicy.analyzeFrame then
		-- 4th return (x86_64 only): FP/SIMD stack-slot materialization info.
		local fs, fpo, ufp, fpinfo = framePolicy.analyzeFrame(body)
		fctx = { frameSize = fs, fpOffset = fpo, usesFp = ufp, fp = fpinfo }
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

	body = framePass.preprocess(body, allocaRegions, framePolicy)

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
				local callee = stmt.operands and stmt.operands[1] and stmt.operands[1].text or "?"
				cgm.checkCallsiteSig(cs, callee)
			end
			callSigCache[stmt] = cs
		end
		return callSigCache[stmt]
	end
	local function callInfo(stmt)
		local cs = callSigOf(stmt)
		if not cs then return nil end
		local argRegs = {}
		for k = 1, cs.argWords do table.insert(argRegs, cc.yoloArg(k)) end
		return { argRegs = argRegs, resultReg = cs.isVoid and nil or 0 }
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
	local argPtrTemps = {}
	local argInfo = {}
	for k, ty in sigDesc.argTypes do
		local yreg = cc.yoloArg(k)
		local et = lf.entryTemp[yreg]
		argInfo[k] = { isPtr = (ty == 7), yoloReg = yreg, entryTemp = et }
		if ty == 7 and et then table.insert(argPtrTemps, et) end
	end

	-- classify nodes: load-ptr / store-ptr / call / alloca. EVERY annotation on an
	-- instruction must be recognized and honored — an unrecognized or mismatched
	-- one was historically SILENTLY IGNORED, and a `;! load ptr` / `;! store ptr`
	-- on the wrong instruction shape was a silent miscompile (the annotated
	-- instruction was replaced by an invisicap load/store, dropping the original
	-- operation). Both are now clean compile-time errors.
	local loadPtrDefs, storePtrNodes, callNodes, allocaNodes, allocaResultDefs = {}, {}, {}, {}, {}
	local callPtrDefs = {}
	-- Phase 2 (x86_64-only): atomic pointer operations and pointer RMWs.
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
					-- Phase 2 annotations: the per-arch shape validator returns the
					-- sequence kind (raising the shape errors); the arm64 backend
					-- rejects all five with a "not supported on ARM64" error.
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

	local pf = ptrflow.analyze(lf,
		{ argPtrTemps = argPtrTemps, loadPtrDefs = ptrSeedDefs, allocaResultDefs = allocaResultDefs,
			callPtrDefs = callPtrDefs },
		allocTemp, { baseMnemonic = cgm.baseMnemonic })

	-- Link each fixed-size alloca-result node to its region; give the region a stable pointer
	-- temp for redirecting sp-relative math and a shared lower (the result's seeded lower).
	for node, al in allocaNodes do
		if al.kind == "resultSize" then
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
			local hi = allocTemp({ role = "scratch" })
			cg.addImm(hi, effTemp, size)          -- hi = eff + size
			cg.cmpBranch(hi, upper, "ugt", lbl)   -- eff+size > upper
		else
			cg.cmpBranch(effTemp, upper, "uge", lbl)  -- eff >= upper
		end
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
		local hi = allocTemp({ role = "scratch" })
		cg.addImm(hi, effTemp, 8); cg.cmpBranch(hi, upper, "ugt", lbl)  -- upper bound
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

	-- Phase 2 (x86_64): atomic pointer operations and pointer RMWs, via the Fil-C
	-- runtime — exactly the calls filcc emits for C11 atomic pointer operations
	-- (verified against build/bin/clang output; see ABI-NOTES-x86.md). The callees
	-- are nounwind runtime entrypoints in plain SysV: a filc_ptr argument is two
	-- consecutive argument words (intval first, then lower), a filc_ptr result comes
	-- back as rax=intval, rdx=lower — so there is NO exception-flag check after
	-- these calls (unlike pizlonated-function calls). Returned lowers are rooted
	-- immediately (a safepoint may run before the next use); pointer ARGUMENTS need
	-- no caller rooting (the runtime protects them itself). Each sequence emits the
	-- usual inline access check first (null-cap -> align -> CanWrite -> lower ->
	-- upper) so a trap gets sarcasm's origin; the runtime re-checks internally.
	--
	-- EFLAGS: a flag consumer (jcc/setcc) immediately after the annotated
	-- instruction must see the flags the NATIVE instruction would produce, but the
	-- injected sequences clobber EFLAGS. The RMW/CAS paths therefore keep the
	-- pre-op value (and the source operand) live in webs and re-execute the
	-- operation on a scratch copy as the LAST flag-affecting step (the result
	-- moves and root stores in between don't touch flags). A consumer that does
	-- NOT immediately follow still sees clobbered flags — the same documented
	-- caveat as the injected bounds checks everywhere else.
	local function marshalResultPtr(dstIv, dstLo)
		cg.move(dstIv, pColored(cc.rtRet))
		cg.move(dstLo, pColored(cc.rtRetLo))
		emitRootStore(dstLo)
	end

	-- filc_load_ptr_atomic_with_manual_tracking_outline(slot) -> old (rax=iv, rdx=lo).
	-- No myth arg, does not allocate, can only panic.
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
	-- new_value travels on the STACK ([rsp]=iv, [rsp+8]=lower at the call; see
	-- codegen's pushStackPtr). Can allocate => GC safepoint. Success <=> returned
	-- old.iv == expected.iv (a raw-intval comparison; the runtime compares intvals
	-- only). The expected's lower may be null ("integer guess") — the comparison
	-- ignores it.
	local function emitAtomicCasCall(effTemp, capLoTemp, expIv, expLo, newIv, newLo)
		cg.fpSave()
		cg.move(pColored(cc.rtArg(1)), vMyth)
		cg.move(pColored(cc.rtArg(2)), effTemp)
		cg.move(pColored(cc.rtArg(3)), capLoTemp)
		cg.moveZero(pColored(cc.rtArg(4)))          -- offset = 0
		cg.move(pColored(cc.rtArg(5)), expIv)
		cg.move(pColored(cc.rtArg(6)), expLo)
		cg.pushStackPtr(newIv, newLo)
		cg.call("filc_strong_cas_ptr_with_manual_tracking",
			{ pColored(cc.rtArg(1)), pColored(cc.rtArg(2)), pColored(cc.rtArg(3)),
				pColored(cc.rtArg(4)), pColored(cc.rtArg(5)), pColored(cc.rtArg(6)) },
			cg.callerSavedClobbers())
		cg.popStackPtr()
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

	-- `;! atomic load store ptr`: WITHOUT `lock`, an atomic load, the op, and an
	-- atomic store (each access atomic; the RMW as a whole is not). WITH `lock`, a
	-- compare-exchange loop through the runtime — a real atomic RMW.
	local alrmwCounter = 0
	local function emitAtomicLoadStorePtr(node, mem)
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
		local argTemps = {}
		for _, r in node.c.uses do if r.argReg then argTemps[r.num] = node.opTemp[r] end end
		cg.move(pColored(cc.myth), vMyth)
		local callUses = { pColored(cc.myth) }
		for k = 1, cs.argWords do
			local aTemp = argTemps[cc.yoloArg(k)]
			cg.move(pColored(cc.argIv(cs.argTypes, k)), aTemp)
			table.insert(callUses, pColored(cc.argIv(cs.argTypes, k)))
			if cs.argTypes[k] == 7 then table.insert(callUses, emitCapMove(cc.argLo(cs.argTypes, k), aTemp)) end
		end
		cg.call("pizlonatedFI" .. cs.signature .. "_" .. callee, callUses, cg.callerSavedClobbers())
		cg.exceptionBranch(ensureExcLabel())
		if not cs.isVoid then
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
				if loopHeaderLabels[node.name] then emitPollcheck() end
			end
		elseif node.kind == "other" then
			-- drop directives
		elseif node.kind == "insn" then
			local c = node.c
			curLine = (node.stmt and node.stmt.line) or curLine
			if allocaNodes[node] then
				emitAlloca(node, allocaNodes[node])
			elseif c.control == "return" then
				if not sigDesc.isVoid then
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
					emitPtrLoad(node, mem, dstIv, dstLo)
					emitRootStore(dstLo)
				elseif storePtrNodes[node] then
					local valOp = storeValueOperand(node.stmt, mem)
					local valIv = valOp and node.opTemp[valOp] or nil
					if not valIv then
						error("sarcasm: `;! store ptr` requires a modeled (GPR) value"
							.. " register: " .. (node.stmt.raw or "?"))
					end
					local valLo = pf.lowerTemp[valIv]
					emitPtrStore(node, mem, valIv, valLo)
				elseif atomicLoadPtrDefs[node] then
					emitAtomicPtrLoad(node, mem)
				elseif atomicStorePtrNodes[node] then
					emitAtomicPtrStore(node, mem)
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
					emitAccessCheck(effTemp, capLo, size, align, isWrite)
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

	local externsList = {}
	for _, e in calledExterns do table.insert(externsList, e) end

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
