--!nonstrict
-- Frame preprocessing (architecture-independent skeleton). Rewrites a function body so the
-- register allocator can treat the input's own stack frame as virtual locals:
--   * the input's frame setup/teardown (sp/rsp adjustment, fp establishment, callee-saved
--     save/restore, writeback frame stores, CET/`leave`) is DROPPED — sarcasm synthesizes
--     its own Fil-C frame.
--   * every other stack-pointer-relative load/store becomes a copy to/from a slot pseudo-
--     register keyed by its byte offset, so reaching-definitions connects producers and
--     consumers of that slot (uniformly handling ABI callee-saved round-trips and genuine
--     local spills).
--   * taking the address of the stack frame (a potential escape) is REJECTED.
--   * a stack access outside the frame [0, frameSize) is a compile-time error.
--
-- The per-stmt classification/rewrite is architecture-specific and supplied via `policy`
-- (arm64_frame / x86_64_frame): `policy.analyzeFrame(body) -> frameSize, fpOffset, usesFp
-- [, fpInfo]` (fpInfo is x86_64-only: FP/SIMD stack-slot materialization clusters,
-- forwarded into ctx.fpInfo) and `policy.rewrite(stmt, ctx)`, where the shared `ctx`
-- provides the slot constructor, region lookup, bounds check, escape rejection, and the
-- output sink.

local frame = {}

-- Slot pseudo-registers get reg numbers in a high range so they never collide with real
-- GPRs (0..30) and are always virtual (never precolored).
local SLOT_BASE = 1000

-- Yolo incoming stack-argument slots (x86_64): the SysV 7th+ integer-class arguments
-- arrive ABOVE the caller's frame at entry (8+8i(%rsp), above the return address) —
-- outside the analyzed frame, so they cannot share the ordinary frame-slot band
-- (SLOT_BASE + offset, offset bounded by the frame size, red-zone slots reaching down
-- to SLOT_BASE - 128). Their virtual slot webs live in a dedicated band below it.
-- (Only the entry side uses these; the outgoing stack arguments at a CALLSITE are
-- ordinary frame slots at offsets [0, 8*o) — the compiler-style outgoing area.)
local YOLO_SLOT_BASE = 500

local function yoloSlotNum(index) return YOLO_SLOT_BASE + 8 * index end

local function yoloSlotReg(index, width)
	return { kind = "reg", rc = "gpr", num = yoloSlotNum(index), width = width or 64,
		name = "__yoloarg" .. tostring(index), isSlot = true }
end

local function slotReg(off, width)
	return { kind = "reg", rc = "gpr", num = SLOT_BASE + off, width = width or 64,
		name = "__slot" .. tostring(off), isSlot = true }
end

local function immVal(op)
	if op and op.kind == "imm" then return op.value or tonumber(op.text) or 0 end
	return 0
end

-- Rewrite `body` using the arch `policy`. `regions` are fixed-size alloca regions (their
-- stack math is redirected to the allocation by the transform, so it passes through here).
-- `sigDesc` (optional) is the function's entry signature: arm64's frame analysis uses it
-- to force the vector-save reservation for FP-signature functions (float/double args or
-- an FP return ride in the v registers even when the body never names a NEON register).
function frame.preprocess(body, regions, policy, sigDesc)
	-- fpInfo (x86_64 only): FP/SIMD stack-slot materialization clusters (or nil).
	local frameSize, fpOffset, usesFp, fpInfo = policy.analyzeFrame(body, sigDesc)
	local out = {}
	local function emit(n) out[#out + 1] = n end

	local function regionOf(off)
		for _, r in (regions or {}) do
			if off >= r.base and off < r.base + r.size then return r end
		end
		return nil
	end

	-- `lowBound` overrides the lowest legal offset (default 0); x86_64 passes -128 for
	-- both rsp-relative and (normalized) rbp-relative accesses to permit the SysV red
	-- zone below the stack pointer.
	local function checkBounds(off, width, isWrite, raw, lowBound)
		if off < (lowBound or 0) then
			error("sarcasm: stack access below frame (sp offset " .. off .. "): " .. (raw or "?"))
		end
		if off + width > frameSize then
			if isWrite then
				error("sarcasm: store into the caller's argument area / outside the frame "
					.. "(sp offset " .. off .. ", frame size " .. frameSize .. "): " .. (raw or "?"))
			end
			error("sarcasm: stack access outside the frame (sp offset " .. off
				.. ", frame size " .. frameSize .. "): " .. (raw or "?"))
		end
	end

	local function rejectEscape(raw)
		error("sarcasm: taking address of stack frame is not supported (cannot prove safety): "
			.. (raw or "?"))
	end

	local ctx = {
		frameSize = frameSize, fpOffset = fpOffset, usesFp = usesFp, fpInfo = fpInfo,
		slotReg = slotReg, immVal = immVal,
		regionOf = regionOf, checkBounds = checkBounds, rejectEscape = rejectEscape,
		emit = emit,
	}

	for _, st in body do
		if st.kind ~= "insn" then
			emit(st)
		elseif st.allocaPlace or st.allocaOwned then
			-- The deferred dynamic-alloca idiom's unannotated machinery (x86_64 -- see
			-- the transform's idiom discovery): the input's stack math must not execute
			-- (the allocation pointer replaces it), so it passes through untouched (no
			-- setup drop, escape check, or slot conversion) and the emitter drops it.
			emit(st)
		elseif not (st.annotation and string.find(st.annotation, "alloca", 1, true)) then
			policy.rewrite(st, ctx)
		elseif string.match(st.annotation, "^alloca%s+result")
			or (string.match(st.annotation, "^alloca%s+size")
				and st.operands[1] and st.operands[1].kind == "reg"
				and st.operands[1].rc == "sp") then
			-- The instruction the transform replaces wholesale: the allocation-form
			-- `;! alloca size` sitting on the rsp-writing adjustment itself, and the
			-- `;! alloca result` / `;! alloca result size=N` forms. Bypass the rewrite.
			emit(st)
		else
			-- A deferred-idiom `;! alloca size` definition on an ordinary value-producing
			-- instruction (a load, an ALU op, ...): the instruction STAYS and lowers
			-- ordinarily, so its memory operands are ordinary frame accesses and must be
			-- virtualized / bounds-checked exactly like unannotated traffic. (Passing it
			-- through raw left a live %rbp/%rsp memory operand in the lifted IR, which
			-- the transform then checked as a HEAP access through a non-pointer web --
			-- an unconditional always-trap at runtime.)
			policy.rewrite(st, ctx)
		end
	end
	return out
end

frame.SLOT_BASE = SLOT_BASE
frame.slotReg = slotReg
frame.YOLO_SLOT_BASE = YOLO_SLOT_BASE
frame.yoloSlotNum = yoloSlotNum
frame.yoloSlotReg = yoloSlotReg
return frame
