--!nonstrict

-- x86_64 floating-point / SIMD knowledge module: SSE/AVX/AVX512 scalar+packed FP,
-- vector moves, MMX, x87, AES/SHA crypto, mask (k) registers, and the unsafe-instruction
-- reject list. Consulted by x86_64_isa.classify (def/use modeling + rejections),
-- x86_64_codegen.accessSizeAlign (checked-access width/alignment), and x86_64_frame
-- (stack-slot widths).
--
-- FP/SIMD registers are NEVER modeled in defs/uses: xmm-class register numbers (0-31)
-- would collide with GPR numbers in the lift's web analysis. Only GPR operands (and
-- GPR memory base/index registers) are modeled; vector registers pass through verbatim.
--
-- Entry shape:
--   {
--     w      = <bytes> | "vec" | "pspd" | fn(ops, mem) -> bytes | nil
--              ("vec": widest vector operand bytes; "pspd": max(16, widest vector bytes))
--     align  = <bytes> | "vec" | nil     -- nil = 1 (unaligned-permissive)
--     gpr    = "dst" | "src" | fn(ops, defs, uses)   -- model the GPR operand
--     memOk  = false | nil               -- false: reject if a memory operand is present
--     reject = "<reason>"                -- always reject with a clean error
--     noCheck= true                      -- memory-neutral (prefetch): pass through, no check
--     claim  = false | nil               -- false: only engage when an xmm-class register
--                                        -- is present (for mnemonics shared with GPR code)
--   }
--
-- The resolved width is authoritative over any Intel PTR size annotation:
-- fp.accessWidth cleanly rejects a PTR size contradicting an ISA-fixed width,
-- except for the size-driven width functions (SIZE_DRIVEN: the x87 PTR fallback
-- and cvtsi2ss/sd's integer source) which take their width from the annotation.

local fp = {}

-- ---------------------------------------------------------------------------
-- operand helpers

local function isGprOp(o) return o and o.kind == "reg" and o.rc == "gpr" end
local function isXmmOp(o) return o and o.kind == "reg" and o.rc == "xmm" end

local function memOperandOf(ops)
	for _, o in ops do if o.kind == "mem" then return o end end
	return nil
end
fp.memOperand = memOperandOf

local function opsHaveFp(ops)
	for _, o in ops do
		if isXmmOp(o) then return true end
		if o.kind == "mem" and (isXmmOp(o.base) or isXmmOp(o.index)) then return true end
	end
	return false
end

function fp.hasFpReg(insn) return opsHaveFp(insn.operands or {}) end

-- Vector byte width implied by an xmm-class register operand. x87 st(N) and mask
-- k registers do not define a vector width (return nil).
local function vecBytesOf(o)
	if not isXmmOp(o) then return nil end
	local n = o.name or ""
	local p3 = string.sub(n, 1, 3)
	if p3 == "xmm" then return 16 end
	if p3 == "ymm" then return 32 end
	if p3 == "zmm" then return 64 end
	if string.sub(n, 1, 2) == "mm" then return 8 end
	return nil
end
fp.vecBytesOf = vecBytesOf

local function widestVecBytes(ops)
	local w = nil
	for _, o in ops do
		local b = vecBytesOf(o)
		if b and (not w or b > w) then w = b end
	end
	return w
end
fp.widestVecBytes = widestVecBytes

-- ---------------------------------------------------------------------------
-- width / gpr-role helper functions used by table entries

-- cvtsi2ss/cvtsi2sd (unsuffixed or VEX): the memory source is an integer of GPR width.
local function cvtIntW(ops, mem)
	if mem and mem.size then return mem.size end
	for _, o in ops do
		if isGprOp(o) then return math.max(1, math.floor((o.width or 32) / 8)) end
	end
	return 4
end

-- movnti: GPR store whose width is REGISTER-determined (%esi -> 4, %rsi -> 8). An
-- Intel mem.size (PTR) annotation never wins over the register (a `movnti DWORD PTR
-- [rdi], rsi` still stores 8 bytes); accessWidth rejects a contradicting annotation.
local function movntiW(ops, mem)
	for _, o in ops do
		if isGprOp(o) then return math.max(4, math.floor((o.width or 64) / 8)) end
	end
	return 4
end

-- Width functions whose result is DRIVEN BY the Intel mem.size (PTR) annotation:
-- the x87 memory-form fallback (fld DWORD PTR -> 4, fld TBYTE PTR -> 10 — the
-- unsuffixed x87 mnemonics encode no width of their own) and the cvtsi2ss/cvtsi2sd
-- integer memory source (m32/m64 is genuinely operand-size determined, and the PTR
-- annotation is what conveys it). accessWidth's PTR-contradiction check exempts
-- these; every other entry's width is ISA-fixed, and a contradicting PTR size is a
-- lie that would under-size the bounds check / materialized stack slot, so
-- accessWidth rejects it.
local SIZE_DRIVEN = { [cvtIntW] = true }

-- remaining-x87 memory-form width: from the Intel PTR size only (size-driven).
local function x87MemW(ops, mem) return mem and mem.size or nil end
SIZE_DRIVEN[x87MemW] = true

-- VEX/EVEX vmovddup: xmm mem form reads 8; ymm/zmm forms read the full vector.
local function vmovddupW(ops)
	local b = widestVecBytes(ops) or 16
	return (b >= 32) and b or 8
end

-- VEX/EVEX widening convert (vcvtps2pd, vcvtdq2pd, vcvtph2ps): mem source is half the
-- destination vector width.
local function vCvtHalfW(ops)
	local d = vecBytesOf(ops and ops[1]) or 16
	return math.max(1, math.floor(d / 2))
end

-- VEX/EVEX narrowing converts (vcvtpd2ps & siblings): the memory SOURCE width is
-- SIZE-DRIVEN, because the destination register class does not determine it —
-- e.g. vcvtpd2ps reads m128 into an xmm (.128), m256 into an xmm (.256), or m512
-- into a YMM (.512), and the ph family (vcvtpd2ph, ...) reads m128/m256/m512
-- into an xmm every time. The width comes from the Intel PTR size annotation or
-- the AT&T source-width suffix (vcvtpd2psx -> 16, vcvtpd2psy -> 32; the ph-quad
-- family also has vcvtpd2phz -> 64 — its .512 form shares the xmm destination,
-- so the z suffix is its only gas-encodable sized spelling). A bare unsized
-- memory operand is accepted only when the destination class is unambiguous
-- (ymm destination => .512 => m512 for the ps/dq/bf16 family); everything else
-- is ambiguous (gas rejects it too, but we must reject it BEFORE rendering
-- anything gas would fail — and before ever under-checking the access).
--
-- Families (gas 2.42 form matrix, verified against `as`):
--   "dbl"   ps/dq/bf16 converts: source 16/32/64, dest xmm/xmm/ymm. No z suffix.
--   "quadz" 8-byte->ph converts: source 16/32/64, dest xmm always. x/y/z suffixes.
--   "quad"  4-byte->ph converts: source 16/32/64, dest xmm/xmm/ymm. x/y suffixes
--           only — the .512 form has NO z-suffixed spelling (`vcvtdq2phz` does
--           not assemble); like the dbl family it is written bare with a ymm
--           destination, so a bare ymm-dest form means an m512 source.
local NARROW_DBL = { vcvtpd2ps = true, vcvtpd2dq = true, vcvttpd2dq = true,
	vcvtpd2udq = true, vcvttpd2udq = true, vcvtuqq2ps = true, vcvtqq2ps = true,
	vcvtneps2bf16 = true, vcvtps2phx = true }
local NARROW_QUADZ = { vcvtpd2ph = true, vcvtqq2ph = true, vcvtuqq2ph = true }
local NARROW_QUAD = { vcvtdq2ph = true, vcvtudq2ph = true }

-- Resolve a narrowing-convert mnemonic to (family, x/y/z suffix, base mnemonic),
-- or nil when it is not one. The x/y/z suffix is part of the SPELLING, not the
-- AT&T [bwlq] size suffix (vcvtps2phx is itself a base mnemonic whose suffixed
-- forms are vcvtps2phxx/vcvtps2phxy).
local function narrowFamily(mnem)
	if NARROW_DBL[mnem] then return "dbl", nil, mnem end
	if NARROW_QUADZ[mnem] then return "quadz", nil, mnem end
	if NARROW_QUAD[mnem] then return "quad", nil, mnem end
	local base, suf = string.match(mnem, "^(.-)([xyz])$")
	if base then
		if NARROW_DBL[base] and suf ~= "z" then return "dbl", suf, base end
		if NARROW_QUADZ[base] then return "quadz", suf, base end
		if NARROW_QUAD[base] and suf ~= "z" then return "quad", suf, base end
	end
	return nil
end
fp.narrowFamily = narrowFamily

-- The AT&T rendering of a BARE narrowing mnemonic with a sized memory operand
-- needs the source-width suffix (bare vcvtpd2ps with an xmm destination is
-- ambiguous to gas): 16 -> x, 32 -> y, 64 -> z for the ph-quad family (the
-- ps/dq family's .512 form stays bare — its ymm destination disambiguates it).
function fp.narrowSuffix(mnem, memSize)
	local fam, suf = narrowFamily(mnem)
	if not fam or suf then return nil end
	if memSize == 16 then return "x" end
	if memSize == 32 then return "y" end
	if memSize == 64 and fam == "quadz" then return "z" end
	return nil
end

local function vCvtNarrowW(ops, mem, mnem, raw)
	local fam, suf, base = narrowFamily(mnem)
	base = base or mnem
	local legal = { [16] = true, [32] = true, [64] = true }
	local w
	if suf then
		w = (suf == "x") and 16 or (suf == "y") and 32 or 64
	elseif mem and mem.size then
		w = mem.size
		if not legal[w] then
			error("sarcasm: PTR size annotation (" .. tostring(w) .. " bytes) is not a legal"
				.. " memory source width for '" .. base .. "' (one of 16, 32, 64): " .. (raw or mnem))
		end
	elseif (fam == "dbl" or fam == "quad") and vecBytesOf(ops and ops[1]) == 32 then
		-- bare unsized, unambiguous ymm destination => .512 (m512 source). The
		-- quad family's .512 form has no z-suffixed spelling, so the bare
		-- ymm-dest form is its ONLY gas-encodable sized spelling.
		w = 64
	else
		error("sarcasm: cannot determine the memory access width of '" .. mnem
			.. "' (unsized memory operand is ambiguous; use a size suffix or PTR annotation): "
			.. (raw or mnem))
	end
	-- the destination vector class must match the resolved form (gas rejects
	-- e.g. vcvtpd2psy with a ymm destination — reject it cleanly ourselves)
	local dw = vecBytesOf(ops and ops[1])
	local need = ((fam == "dbl" or fam == "quad") and w == 64) and 32 or 16
	if dw and dw ~= need then
		error("sarcasm: '" .. mnem .. "' has no memory form with a " .. w
			.. "-byte source and this destination register class: " .. (raw or mnem))
	end
	return w
end
SIZE_DRIVEN[vCvtNarrowW] = true

-- EVEX widening convert from ph (2-byte) elements to 8-byte destinations
-- (vcvtph2pd, vcvtph2qq, vcvtph2uqq): the memory source is a QUARTER of the
-- destination vector width (zmm dest -> m128).
local function vCvtQuarterW(ops)
	local d = vecBytesOf(ops and ops[1]) or 16
	return math.max(1, math.floor(d / 4))
end

-- lzcnt/tzcnt/popcnt: the memory source width is the DESTINATION GPR's byte width
-- (lzcnt (%rdi), %rax -> 8, %eax -> 4, %ax -> 2).
local function dstGprW(ops, mem)
	local o = ops and ops[1]
	if isGprOp(o) then return math.max(1, math.floor((o.width or 64) / 8)) end
	if mem and mem.size then return mem.size end
	return 8
end

-- vcvtps2ph with a memory DESTINATION (its only memory form: the source is always a
-- register): the ph side is HALF the ps side, so the store is half the SOURCE vector
-- width (ymm -> 16, zmm -> 32). (vCvtDoubleW is WRONG here: it models a double-width
-- memory source, which is the vcvtpd2ps shape, not the vcvtps2ph shape.)
local function vcvtps2phW(ops)
	local b = widestVecBytes(ops) or 16
	return math.max(1, math.floor(b / 2))
end

-- lss/lfs/lgs: far-pointer load — memory source width = destination GPR bytes plus
-- the 2-byte segment selector (16-bit dest -> 4, 32-bit -> 6, 64-bit -> 10).
local function farPtrW(ops)
	local o = ops and ops[1]
	if isGprOp(o) then return math.max(1, math.floor((o.width or 32) / 8)) + 2 end
	return 6
end

-- movd/movq/kmov family: the lone GPR operand is a def when it is the destination
-- (ops[1], dest-first), otherwise a use.
local function gprByPosition(ops, defs, uses)
	for _, o in ops do
		if isGprOp(o) then
			if o == ops[1] then table.insert(defs, o) else table.insert(uses, o) end
		end
	end
end

-- xadd: BOTH explicit operands are read-modify-write (the source receives the old
-- destination); a memory destination is an RMW store. (The conservative
-- first-reg-def model is wrong here: it would drop the source's def and the
-- destination's use.)
local function gprXadd(ops, defs, uses)
	for _, o in ops do
		if isGprOp(o) then table.insert(defs, o); table.insert(uses, o) end
	end
end

-- adcx/adox/crc32: the destination is read-modify-write (dst += src + CF, resp.
-- dst = crc32(dst, src)); the source is a plain use. (adcx/adox DO have r/m
-- source forms — opcode 0f38f6 takes r/m32/64 — so the memory forms are modeled
-- like the register forms, not rejected.)
local function gprRmwDst(ops, defs, uses)
	if isGprOp(ops[1]) then table.insert(defs, ops[1]); table.insert(uses, ops[1]) end
	for i = 2, #ops do
		if isGprOp(ops[i]) then table.insert(uses, ops[i]) end
	end
end

-- xadd/adcx/adox: the access width is the shared operand width — the register
-- operand that is always present determines it (xaddb %sil, (%rdi) -> 1).
local function firstGprW(ops, mem)
	for _, o in ops do
		if isGprOp(o) then return math.max(1, math.floor((o.width or 64) / 8)) end
	end
	if mem and mem.size then return mem.size end
	return 8
end

-- crc32: the memory source width is the crc SOURCE width (r/m8 -> 1, r/m16 -> 2,
-- r/m32 -> 4, r/m64 -> 8), from the AT&T suffix (crc32b/w/l/q), the source
-- register width, or the Intel PTR size; an unsized memory source defaults to
-- the DESTINATION register width, mirroring gas (`crc32 (%rdi), %eax` assembles
-- as crc32l). Not every (dest, source) pair is encodable — an r32 destination
-- takes m8/m16/m32, an r64 destination takes m8/m64 — illegal combinations are
-- rejected cleanly rather than emitted for gas to fail.
local CRC32_SUFFIX = { b = 1, w = 2, l = 4, q = 8 }
local function crc32W(ops, mem, mnem, raw)
	local w = CRC32_SUFFIX[string.match(mnem, "^crc32([bwlq])$") or ""]
	if not w then
		local src = ops and ops[2]
		if isGprOp(src) then w = math.max(1, math.floor((src.width or 32) / 8)) end
	end
	if not w and mem and mem.size then w = mem.size end
	local dstW
	local dst = ops and ops[1]
	if isGprOp(dst) then dstW = math.max(1, math.floor((dst.width or 32) / 8)) end
	if not w and dstW then w = dstW end
	w = w or 4
	if dstW and not (w == 1 or (dstW == 4 and (w == 2 or w == 4)) or (dstW == 8 and w == 8)) then
		error("sarcasm: illegal crc32 destination/source width combination (" .. dstW
			.. "-byte destination, " .. w .. "-byte source) for '" .. mnem .. "': "
			.. (raw or mnem))
	end
	return w
end

-- ---------------------------------------------------------------------------
-- reject reasons

local REASON_X87STATE = "x87 environment/state-save instructions are not supported (cannot prove memory safety)"
local REASON_XSAVE = "xsave/xrstor state save/restore size is CPU-dependent (cannot prove memory safety)"
local REASON_GATHER = "gather/scatter instructions touch multiple discrete addresses (cannot prove memory safety)"
local REASON_MASKMOV = "vector-masked loads/stores may not touch all addressed lanes (cannot prove memory safety)"
local REASON_ESTRI = "pcmpestri/pcmpistri-family instructions have implicit GPR operands (rax/rdx/rcx) that are not modeled (cannot prove memory safety)"
local REASON_AMX = "AMX tile instructions have strided, configuration-dependent memory footprints that cannot be bounds-checked (cannot prove memory safety)"

local REJECT_GATHER = { reject = REASON_GATHER, claim = true }

-- ---------------------------------------------------------------------------
-- the EXACT table

local EXACT = {
	-- SSE scalar FP ---------------------------------------------------------
	movss = { w = 4, claim = true }, movsd = { w = 8, claim = true },
	addss = { w = 4, claim = true }, addsd = { w = 8, claim = true },
	subss = { w = 4, claim = true }, subsd = { w = 8, claim = true },
	mulss = { w = 4, claim = true }, mulsd = { w = 8, claim = true },
	divss = { w = 4, claim = true }, divsd = { w = 8, claim = true },
	minss = { w = 4, claim = true }, minsd = { w = 8, claim = true },
	maxss = { w = 4, claim = true }, maxsd = { w = 8, claim = true },
	sqrtss = { w = 4, claim = true }, sqrtsd = { w = 8, claim = true },
	rcpss = { w = 4, claim = true }, rsqrtss = { w = 4, claim = true },
	cmpss = { w = 4, claim = true }, cmpsd = { w = 8, claim = true },
	comiss = { w = 4, claim = true }, comisd = { w = 8, claim = true },
	ucomiss = { w = 4, claim = true }, ucomisd = { w = 8, claim = true },
	roundss = { w = 4, claim = true }, roundsd = { w = 8, claim = true },
	cvtss2sd = { w = 4, claim = true }, cvtsd2ss = { w = 8, claim = true },

	-- SSE packed FP ---------------------------------------------------------
	movups = { w = 16, claim = true }, movupd = { w = 16, claim = true },
	movaps = { w = 16, align = 16, claim = true }, movapd = { w = 16, align = 16, claim = true },
	movntps = { w = 16, claim = true }, movntpd = { w = 16, claim = true },
	movhps = { w = 8, claim = true }, movhpd = { w = 8, claim = true },
	movlps = { w = 8, claim = true }, movlpd = { w = 8, claim = true },
	movddup = { w = 8, claim = true },  -- NB: SSE mem form reads 8, not 16
	movsldup = { w = 16, claim = true }, movshdup = { w = 16, claim = true },
	addps = { w = 16, claim = true }, addpd = { w = 16, claim = true },
	subps = { w = 16, claim = true }, subpd = { w = 16, claim = true },
	mulps = { w = 16, claim = true }, mulpd = { w = 16, claim = true },
	divps = { w = 16, claim = true }, divpd = { w = 16, claim = true },
	minps = { w = 16, claim = true }, minpd = { w = 16, claim = true },
	maxps = { w = 16, claim = true }, maxpd = { w = 16, claim = true },
	sqrtps = { w = 16, claim = true }, sqrtpd = { w = 16, claim = true },
	rcpps = { w = 16, claim = true }, rsqrtps = { w = 16, claim = true },
	cmpps = { w = 16, claim = true }, cmppd = { w = 16, claim = true },
	andps = { w = 16, claim = true }, andpd = { w = 16, claim = true },
	andnps = { w = 16, claim = true }, andnpd = { w = 16, claim = true },
	orps = { w = 16, claim = true }, orpd = { w = 16, claim = true },
	xorps = { w = 16, claim = true }, xorpd = { w = 16, claim = true },
	shufps = { w = 16, claim = true }, shufpd = { w = 16, claim = true },
	unpckhps = { w = 16, claim = true }, unpckhpd = { w = 16, claim = true },
	unpcklps = { w = 16, claim = true }, unpcklpd = { w = 16, claim = true },
	haddps = { w = 16, claim = true }, haddpd = { w = 16, claim = true },
	hsubps = { w = 16, claim = true }, hsubpd = { w = 16, claim = true },
	addsubps = { w = 16, claim = true }, addsubpd = { w = 16, claim = true },
	dpps = { w = 16, claim = true }, dppd = { w = 16, claim = true },
	roundps = { w = 16, claim = true }, roundpd = { w = 16, claim = true },
	blendps = { w = 16, claim = true }, blendpd = { w = 16, claim = true },
	blendvps = { w = 16, claim = true }, blendvpd = { w = 16, claim = true },
	insertps = { w = 4, claim = true },  -- mem form reads m32

	-- SSE/AVX converts (asymmetric shapes) ------------------------------------
	cvtps2pd = { w = 8, claim = true }, cvtpd2ps = { w = 16, claim = true },
	cvtdq2ps = { w = 16, claim = true }, cvtps2dq = { w = 16, claim = true },
	cvttps2dq = { w = 16, claim = true }, cvtdq2pd = { w = 8, claim = true },
	cvtpd2dq = { w = 8, claim = true }, cvttpd2dq = { w = 8, claim = true },
	cvtpi2ps = { w = 8, claim = true }, cvtpi2pd = { w = 8, claim = true },
	cvtps2pi = { w = 8, claim = true }, cvttps2pi = { w = 8, claim = true },
	cvtpd2pi = { w = 16, claim = true }, cvttpd2pi = { w = 16, claim = true },
	vcvtps2pd = { w = vCvtHalfW, claim = true }, vcvtdq2pd = { w = vCvtHalfW, claim = true },
	vcvtph2ps = { w = vCvtHalfW, claim = true },
	vcvtps2ph = { w = vcvtps2phW, claim = true },
	-- NB: the narrowing converts (vcvtpd2ps & siblings, incl. the AT&T x/y/z
	-- suffix spellings) are NOT here — they resolve through narrowFamily in
	-- fp.lookup with the size-driven vCvtNarrowW width.

	-- remaining AVX512 packed converts (mem bytes = source lanes x source element
	-- bytes; element sizes from the SDM operand forms) ---------------------------
	-- widening (mem = dest vector bytes / 2)
	vcvtudq2pd = { w = vCvtHalfW, claim = true },
	vcvtps2qq = { w = vCvtHalfW, claim = true }, vcvttps2qq = { w = vCvtHalfW, claim = true },
	vcvtps2uqq = { w = vCvtHalfW, claim = true }, vcvttps2uqq = { w = vCvtHalfW, claim = true },
	vcvtph2dq = { w = vCvtHalfW, claim = true }, vcvttph2dq = { w = vCvtHalfW, claim = true },
	vcvtph2udq = { w = vCvtHalfW, claim = true }, vcvttph2udq = { w = vCvtHalfW, claim = true },
	vcvtph2psx = { w = vCvtHalfW, claim = true },
	-- widening ph (2-byte) -> 8-byte destinations (mem = dest vector bytes / 4)
	vcvtph2pd = { w = vCvtQuarterW, claim = true },
	vcvtph2qq = { w = vCvtQuarterW, claim = true }, vcvttph2qq = { w = vCvtQuarterW, claim = true },
	vcvtph2uqq = { w = vCvtQuarterW, claim = true }, vcvttph2uqq = { w = vCvtQuarterW, claim = true },
	-- same-width element re-interpretations (mem = dest vector bytes)
	vcvtps2udq = { w = "vec", claim = true }, vcvttps2udq = { w = "vec", claim = true },
	vcvtpd2qq = { w = "vec", claim = true }, vcvttpd2qq = { w = "vec", claim = true },
	-- full-width UNSIGNED converts (8-byte elements either side, like pd2qq)
	vcvtpd2uqq = { w = "vec", claim = true }, vcvttpd2uqq = { w = "vec", claim = true },
	vcvtuqq2pd = { w = "vec", claim = true }, vcvtqq2pd = { w = "vec", claim = true },
	vcvtudq2ps = { w = "vec", claim = true },
	vcvtne2ps2bf16 = { w = "vec", claim = true },
	vcvtph2w = { w = "vec", claim = true }, vcvttph2w = { w = "vec", claim = true },
	vcvtw2ph = { w = "vec", claim = true },

	-- AVX512-VNNI / AVX-VNNI(-INT8) dot products: FULL-vector memory source. The
	-- ss/sd suffix rule would otherwise pin e.g. vpdpwssd to 8 bytes for a 64-byte
	-- read. (Must be EXACT: the p-family pattern would catch the vp* spellings but
	-- never vp4dpwssd, whose post-v character is a digit.)
	vpdpbusd = { w = "vec", claim = true }, vpdpbusds = { w = "vec", claim = true },
	vpdpwssd = { w = "vec", claim = true }, vpdpwssds = { w = "vec", claim = true },
	vpdpbssd = { w = "vec", claim = true }, vpdpbssds = { w = "vec", claim = true },
	-- 4VNNIW: the memory operand is a single m128 (16 bytes) regardless of the zmm
	-- width (EVEX.512 ... m128 per the SDM) — NOT the vector width.
	vp4dpwssd = { w = 16, claim = true }, vp4dpwssds = { w = 16, claim = true },
	-- AVX512-IFMA 52-bit multiply-add: full-vector memory source. (Must be EXACT:
	-- the digits keep the p-family pattern from matching — "vpmadd52luq" is not
	-- ^v?p[%a]+$.)
	vpmadd52huq = { w = "vec", claim = true }, vpmadd52luq = { w = "vec", claim = true },
	-- AVX512BW sum-of-absolute-differences: full-width memory source.
	vdbpsadbw = { w = "vec", claim = true },

	-- vector moves ------------------------------------------------------------
	movd = { w = 4, gpr = gprByPosition, claim = true },
	movq = { w = 8, gpr = gprByPosition, claim = false },  -- shared with GPR `movq`
	movdqa = { w = 16, align = 16, claim = true }, movdqu = { w = 16, claim = true },
	lddqu = { w = 16, claim = true }, movntdq = { w = 16, claim = true },
	movntdqa = { w = 16, claim = true },
	movnti = { w = movntiW, gpr = "src", claim = true },
	-- AVX512 byte/word/dword/qword vector moves (width = vector width)
	vmovdqu8 = { w = "vec", claim = true }, vmovdqu16 = { w = "vec", claim = true },
	vmovdqu32 = { w = "vec", claim = true }, vmovdqu64 = { w = "vec", claim = true },
	vmovdqa32 = { w = "vec", align = "vec", claim = true },
	vmovdqa64 = { w = "vec", align = "vec", claim = true },
	vmovddup = { w = vmovddupW, claim = true },
	-- broadcasts (non-decorator forms)
	vbroadcastss = { w = 4, claim = true }, vbroadcastsd = { w = 8, claim = true },
	vbroadcastf128 = { w = 16, claim = true },
	vbroadcastf32x2 = { w = 8, claim = true }, vbroadcastf32x4 = { w = 16, claim = true },
	vbroadcastf32x8 = { w = 32, claim = true },
	vbroadcastf64x2 = { w = 16, claim = true }, vbroadcastf64x4 = { w = 32, claim = true },
	vbroadcasti32x2 = { w = 8, claim = true }, vbroadcasti32x4 = { w = 16, claim = true },
	vbroadcasti32x8 = { w = 32, claim = true },
	vbroadcasti64x2 = { w = 16, claim = true }, vbroadcasti64x4 = { w = 32, claim = true },
	-- AVX512 single-element broadcasts: the memory form reads ONE element (1/2/4/8
	-- bytes) regardless of the destination vector width, and the AVX512 GPR-source
	-- form reads a GPR that MUST be modeled (otherwise regalloc can rename the
	-- producing web and the broadcast reads a stale register). gpr="src" is a no-op
	-- for the xmm/memory-source forms (no GPR operand exists).
	vpbroadcastb = { w = 1, gpr = "src", claim = true },
	vpbroadcastw = { w = 2, gpr = "src", claim = true },
	vpbroadcastd = { w = 4, gpr = "src", claim = true },
	vpbroadcastq = { w = 8, gpr = "src", claim = true },
	-- extract/insert 128-bit lanes (mem width = lane width)
	vperm2f128 = { w = "vec", claim = true }, vperm2i128 = { w = "vec", claim = true },
	vextractf128 = { w = 16, claim = true }, vextracti128 = { w = 16, claim = true },
	vinsertf128 = { w = 16, claim = true }, vinserti128 = { w = 16, claim = true },
	vextractf32x4 = { w = 16, claim = true }, vextractf32x8 = { w = 32, claim = true },
	vextractf64x2 = { w = 16, claim = true }, vextractf64x4 = { w = 32, claim = true },
	vinsertf32x4 = { w = 16, claim = true }, vinsertf32x8 = { w = 32, claim = true },
	vinsertf64x2 = { w = 16, claim = true }, vinsertf64x4 = { w = 32, claim = true },
	vextracti32x4 = { w = 16, claim = true }, vextracti32x8 = { w = 32, claim = true },
	vextracti64x2 = { w = 16, claim = true }, vextracti64x4 = { w = 32, claim = true },
	vinserti32x4 = { w = 16, claim = true }, vinserti32x8 = { w = 32, claim = true },
	vinserti64x2 = { w = 16, claim = true }, vinserti64x4 = { w = 32, claim = true },
	vshuff32x4 = { w = "vec", claim = true }, vshuff64x2 = { w = "vec", claim = true },
	vshufi32x4 = { w = "vec", claim = true }, vshufi64x2 = { w = "vec", claim = true },
	valignd = { w = "vec", claim = true }, valignq = { w = "vec", claim = true },

	-- GPR-mixing conversions (the miscompile fixes: the GPR must be modeled right) --
	cvtsi2ss = { w = cvtIntW, gpr = "src", claim = true },
	cvtsi2sd = { w = cvtIntW, gpr = "src", claim = true },
	cvtsi2ssl = { w = 4, gpr = "src", claim = true }, cvtsi2ssq = { w = 8, gpr = "src", claim = true },
	cvtsi2sdl = { w = 4, gpr = "src", claim = true }, cvtsi2sdq = { w = 8, gpr = "src", claim = true },
	cvttss2si = { w = 4, gpr = "dst", claim = true }, cvttsd2si = { w = 8, gpr = "dst", claim = true },
	cvtss2si = { w = 4, gpr = "dst", claim = true }, cvtsd2si = { w = 8, gpr = "dst", claim = true },
	cvttss2sil = { w = 4, gpr = "dst", claim = true }, cvttss2siq = { w = 4, gpr = "dst", claim = true },
	cvttsd2sil = { w = 8, gpr = "dst", claim = true }, cvttsd2siq = { w = 8, gpr = "dst", claim = true },
	cvtss2sil = { w = 4, gpr = "dst", claim = true }, cvtss2siq = { w = 4, gpr = "dst", claim = true },
	cvtsd2sil = { w = 8, gpr = "dst", claim = true }, cvtsd2siq = { w = 8, gpr = "dst", claim = true },
	-- EVEX unsigned-integer scalar converts (vcvtusi2ss/sd mirror cvtsi2ss/sd: the
	-- GPR/mem integer source is size-driven and MUST be modeled as a use — an
	-- unmodeled source reads a stale register after regalloc. The reverse usi
	-- family mirrors cvttss2si & co: mem forms read m32/m32/m64/m64.)
	vcvtusi2ss = { w = cvtIntW, gpr = "src", claim = true },
	vcvtusi2sd = { w = cvtIntW, gpr = "src", claim = true },
	vcvtusi2ssl = { w = 4, gpr = "src", claim = true }, vcvtusi2ssq = { w = 8, gpr = "src", claim = true },
	vcvtusi2sdl = { w = 4, gpr = "src", claim = true }, vcvtusi2sdq = { w = 8, gpr = "src", claim = true },
	vcvttss2usi = { w = 4, gpr = "dst", claim = true }, vcvtss2usi = { w = 4, gpr = "dst", claim = true },
	vcvttsd2usi = { w = 8, gpr = "dst", claim = true }, vcvtsd2usi = { w = 8, gpr = "dst", claim = true },
	-- move-mask extracts: GPR destination, register-only
	movmskps = { gpr = "dst", memOk = false, claim = true },
	movmskpd = { gpr = "dst", memOk = false, claim = true },
	pmovmskb = { gpr = "dst", memOk = false, claim = true },
	vpmovmskb = { gpr = "dst", memOk = false, claim = true },
	vpmovmskw = { gpr = "dst", memOk = false, claim = true },
	vpmovmskd = { gpr = "dst", memOk = false, claim = true },
	vpmovmskq = { gpr = "dst", memOk = false, claim = true },
	pextrb = { w = 1, gpr = "dst", claim = true }, pextrw = { w = 2, gpr = "dst", claim = true },
	pextrd = { w = 4, gpr = "dst", claim = true }, pextrq = { w = 8, gpr = "dst", claim = true },
	extractps = { w = 4, gpr = "dst", claim = true },
	pinsrb = { w = 1, gpr = "src", claim = true }, pinsrw = { w = 2, gpr = "src", claim = true },
	pinsrd = { w = 4, gpr = "src", claim = true }, pinsrq = { w = 8, gpr = "src", claim = true },
	-- opmask moves (k<->gpr/mem)
	kmovb = { w = 1, gpr = gprByPosition, claim = true },
	kmovw = { w = 2, gpr = gprByPosition, claim = true },
	kmovd = { w = 4, gpr = gprByPosition, claim = true },
	kmovq = { w = 8, gpr = gprByPosition, claim = true },

	-- crypto --------------------------------------------------------------------
	aesenc = { w = 16, claim = true }, aesdec = { w = 16, claim = true },
	aesenclast = { w = 16, claim = true }, aesdeclast = { w = 16, claim = true },
	aesimc = { memOk = false, claim = true },
	aeskeygenassist = { w = 16, claim = true },
	pclmulqdq = { w = 16, claim = true }, vpclmulqdq = { w = "vec", claim = true },
	sha1rnds4 = { w = 16, claim = true }, sha1nexte = { w = 16, claim = true },
	sha1msg1 = { w = 16, claim = true }, sha1msg2 = { w = 16, claim = true },
	sha256rnds2 = { w = 16, claim = true }, sha256msg1 = { w = 16, claim = true },
	sha256msg2 = { w = 16, claim = true },
	-- GFNI: width = vector width (xmm=16; the VEX/EVEX vgf2p8* forms ride the
	-- v-alias of these entries, ymm=32/zmm=64). gf2p8affine* carry a trailing
	-- immediate. NB: LLVM and GNU binutils spell Intel's GF2P8AFFINEB (opcode
	-- 0F3A CE) as "gf2p8affineqb" and GF2P8AFFINEQB (0F3A CF) as
	-- "gf2p8affineinvqb" — all three spellings are covered.
	gf2p8mulb = { w = "vec", claim = true },
	gf2p8affineb = { w = "vec", claim = true }, gf2p8affineqb = { w = "vec", claim = true },
	gf2p8affineinvqb = { w = "vec", claim = true },
	-- SM3/SM4: xmm-only families, one 16-byte mem operand (clang/binutils spell
	-- them vsm3*/vsm4* — VEX.128 encodings — which ride the v-alias of these).
	sm3rnds2 = { w = 16, claim = true }, sm3msg1 = { w = 16, claim = true },
	sm3msg2 = { w = 16, claim = true },
	sm4key4 = { w = 16, claim = true }, sm4rnds4 = { w = 16, claim = true },

	-- mxcsr ---------------------------------------------------------------------
	ldmxcsr = { w = 4, claim = true }, stmxcsr = { w = 4, claim = true },

	-- descriptor-table/system-register memory forms (unprivileged) ----------------
	-- sgdt/sidt store 2-byte limit + 8-byte base = 10 bytes; sldt/str/smsw store
	-- 2 bytes (their register forms take a GPR destination). The store-vs-load
	-- labeling for these lives in x86_64_codegen.isStoreInsn.
	sgdt = { w = 10, claim = true }, sidt = { w = 10, claim = true },
	sldt = { w = 2, gpr = "dst", claim = true }, str = { w = 2, gpr = "dst", claim = true },
	smsw = { w = 2, gpr = "dst", claim = true },
	-- far-pointer loads: dest GPR bytes + 2-byte selector (load semantics).
	lss = { w = farPtrW, gpr = "dst", claim = true },
	lfs = { w = farPtrW, gpr = "dst", claim = true },
	lgs = { w = farPtrW, gpr = "dst", claim = true },

	-- x87 memory forms (AT&T suffixes: s/l/t for float, s/l/q(ll) for integer) -----
	flds = { w = 4, claim = true }, fldl = { w = 8, claim = true }, fldt = { w = 10, claim = true },
	fsts = { w = 4, claim = true }, fstl = { w = 8, claim = true }, fstt = { w = 10, claim = true },
	fstps = { w = 4, claim = true }, fstpl = { w = 8, claim = true }, fstpt = { w = 10, claim = true },
	filds = { w = 2, claim = true }, fildl = { w = 4, claim = true },
	fildq = { w = 8, claim = true }, fildll = { w = 8, claim = true },
	fists = { w = 2, claim = true }, fistl = { w = 4, claim = true },
	fistq = { w = 8, claim = true },
	fistps = { w = 2, claim = true }, fistpl = { w = 4, claim = true },
	fistpq = { w = 8, claim = true }, fistpll = { w = 8, claim = true },
	fisttps = { w = 2, claim = true }, fisttpl = { w = 4, claim = true }, fisttpq = { w = 8, claim = true },
	fiadds = { w = 2, claim = true }, fiaddl = { w = 4, claim = true },
	fisubs = { w = 2, claim = true }, fisubl = { w = 4, claim = true },
	fisubrs = { w = 2, claim = true }, fisubrl = { w = 4, claim = true },
	fimuls = { w = 2, claim = true }, fimull = { w = 4, claim = true },
	fidivs = { w = 2, claim = true }, fidivl = { w = 4, claim = true },
	fidivrs = { w = 2, claim = true }, fidivrl = { w = 4, claim = true },
	ficoms = { w = 2, claim = true }, ficoml = { w = 4, claim = true },
	ficomps = { w = 2, claim = true }, ficompl = { w = 4, claim = true },
	fcoms = { w = 4, claim = true }, fcoml = { w = 8, claim = true },
	fcomps = { w = 4, claim = true }, fcompl = { w = 8, claim = true },
	fadds = { w = 4, claim = true }, faddl = { w = 8, claim = true },
	fsubs = { w = 4, claim = true }, fsubl = { w = 8, claim = true },
	fmuls = { w = 4, claim = true }, fmull = { w = 8, claim = true },
	fdivs = { w = 4, claim = true }, fdivl = { w = 8, claim = true },
	fsubrs = { w = 4, claim = true }, fsubrl = { w = 8, claim = true },
	fdivrs = { w = 4, claim = true }, fdivrl = { w = 8, claim = true },
	fbld = { w = 10, claim = true }, fbstp = { w = 10, claim = true },
	fnstsw = { w = 2, gpr = "dst", claim = true }, fstsw = { w = 2, gpr = "dst", claim = true },
	fnstcw = { w = 2, claim = true }, fstcw = { w = 2, claim = true }, fldcw = { w = 2, claim = true },

	-- fxsave/fxrstor: fixed 512-byte state image, 16-byte aligned -----------------
	fxsave = { w = 512, align = 16, claim = true }, fxsave64 = { w = 512, align = 16, claim = true },
	fxrstor = { w = 512, align = 16, claim = true }, fxrstor64 = { w = 512, align = 16, claim = true },

	-- MMX/misc reg-only ----------------------------------------------------------
	emms = { memOk = false, claim = true }, femms = { memOk = false, claim = true },
	vzeroupper = { memOk = false, claim = true }, vzeroall = { memOk = false, claim = true },

	-- memory-neutral hints --------------------------------------------------------
	prefetch = { noCheck = true, claim = true },
	prefetcht0 = { noCheck = true, claim = true }, prefetcht1 = { noCheck = true, claim = true },
	prefetcht2 = { noCheck = true, claim = true }, prefetchnta = { noCheck = true, claim = true },
	prefetchw = { noCheck = true, claim = true }, prefetchwt1 = { noCheck = true, claim = true },

	-- hard rejects -----------------------------------------------------------------
	fsave = { reject = REASON_X87STATE, claim = true }, fnsave = { reject = REASON_X87STATE, claim = true },
	frstor = { reject = REASON_X87STATE, claim = true },
	fstenv = { reject = REASON_X87STATE, claim = true }, fnstenv = { reject = REASON_X87STATE, claim = true },
	fldenv = { reject = REASON_X87STATE, claim = true },
	xsave = { reject = REASON_XSAVE, claim = true }, xsave64 = { reject = REASON_XSAVE, claim = true },
	xrstor = { reject = REASON_XSAVE, claim = true }, xrstor64 = { reject = REASON_XSAVE, claim = true },
	xsaveopt = { reject = REASON_XSAVE, claim = true }, xsaveopt64 = { reject = REASON_XSAVE, claim = true },
	xsaves = { reject = REASON_XSAVE, claim = true }, xsaves64 = { reject = REASON_XSAVE, claim = true },
	xrstors = { reject = REASON_XSAVE, claim = true }, xrstors64 = { reject = REASON_XSAVE, claim = true },
	xsavec = { reject = REASON_XSAVE, claim = true }, xsavec64 = { reject = REASON_XSAVE, claim = true },
	vmaskmovps = { reject = REASON_MASKMOV, claim = true },
	vmaskmovpd = { reject = REASON_MASKMOV, claim = true },
	vpmaskmovd = { reject = REASON_MASKMOV, claim = true },
	vpmaskmovq = { reject = REASON_MASKMOV, claim = true },
	maskmovdqu = { reject = REASON_MASKMOV, claim = true },  -- implicit rdi addressing
	maskmovq = { reject = REASON_MASKMOV, claim = true },
	-- NB: cmpxchg8b/cmpxchg16b are NOT here — they are genuinely MODELED (implicit
	-- edx:eax/ecx:ebx resp. rdx:rax/rcx:rbx operand pairs pinned through
	-- emitPinned) in x86_64_isa.classify.
}
fp.EXACT = EXACT

-- reg-only x87 (no memory form): reject only if a memory operand sneaks in.
for _, m in { "fldz", "fld1", "fldpi", "fldl2t", "fldl2e", "fldlg2", "fldln2",
	"faddp", "fsubp", "fsubrp", "fmulp", "fdivp", "fdivrp", "fcompp", "fucompp",
	"fxch", "fxtract", "fyl2x", "fyl2xp1", "f2xm1", "fabs", "fchs", "fcos", "fsin",
	"fsincos", "fptan", "fpatan", "fprem", "fprem1", "frndint", "fscale", "fsqrt",
	"ftst", "fxam", "fwait", "fnop", "ffree", "ffreep", "fincstp", "fdecstp",
	"fnclex", "fclex", "fninit", "finit",
	"fcomi", "fcomip", "fucomi", "fucomip",
	"fcmovb", "fcmove", "fcmovbe", "fcmovu", "fcmovnb", "fcmovne", "fcmovnbe", "fcmovnu" } do
	EXACT[m] = { memOk = false, claim = true }
end

-- BMI1/BMI2/ADX/bsf/bsr/xadd/crc32 GPR instructions (common in clang
-- -march=native output): exact entries, like lzcnt/tzcnt/popcnt above. Only
-- gas-encodable spellings are listed (e.g. there are no 16-bit BMI forms —
-- shlxw/bextrw/pdepw do not exist — so those stay unknown and reject on any
-- memory operand). The trivial entries model first-reg-def/rest-use with the
-- access width from the destination GPR; xadd is RMW on BOTH explicit operands;
-- adcx/adox/crc32 are RMW-destination. mulx and cmpxchg are deliberately NOT
-- here: they have implicit rax/rdx effects and are pinned in x86_64_isa.classify.
for _, m in { "shlx", "sarx", "shrx", "andn", "bextr", "blsi", "blsr", "blsmsk",
	"bzhi", "pdep", "pext", "rorx" } do
	for _, s in { "", "l", "q" } do
		EXACT[m .. s] = { w = dstGprW, gpr = gprByPosition, claim = true }
	end
end
for _, m in { "bsf", "bsr" } do
	for _, s in { "", "w", "l", "q" } do
		EXACT[m .. s] = { w = dstGprW, gpr = gprByPosition, claim = true }
	end
end
for _, s in { "", "b", "w", "l", "q" } do
	EXACT["xadd" .. s] = { w = firstGprW, gpr = gprXadd, claim = true }
	EXACT["crc32" .. s] = { w = crc32W, gpr = gprRmwDst, claim = true }
end
for _, m in { "adcx", "adox" } do
	for _, s in { "", "l", "q" } do
		EXACT[m .. s] = { w = firstGprW, gpr = gprRmwDst, claim = true }
	end
end

-- pmovzx/pmovsx: memory source width = destination vector bytes / divisor.
local PMOV_DIV = { bw = 2, bd = 4, bq = 8, wd = 2, wq = 4, dq = 2 }

-- vpmovqb/qw/qd/db/dw/wb truncating stores (and the saturating vpmovs*/vpmovus*
-- families): memory width = source vector bytes / divisor (qb: 8 qwords -> 8 bytes
-- from a zmm, ...). Same divisors for all three families.
local PMOVTR_DIV = { qb = 8, qw = 4, qd = 2, db = 4, dw = 2, wb = 2 }

-- ---------------------------------------------------------------------------
-- lookup: EXACT table + pattern rules

-- shared entry for the narrowing converts (see vCvtNarrowW): size-driven width.
local NARROW_ENTRY = { w = vCvtNarrowW, claim = true }

function fp.lookup(mnem)
	mnem = string.lower(mnem)
	local e = EXACT[mnem]
	if e then return e end

	-- narrowing converts (vcvtpd2ps & siblings + their AT&T x/y/z suffix
	-- spellings). Must precede the ss/sd/ps/pd suffix rule below ("vcvtpd2ps"
	-- would otherwise parse a bogus "ps" suffix) and the p-family pattern.
	if narrowFamily(mnem) then return NARROW_ENTRY end

	-- hard-reject families (patterned; also caught by the vector-index frame check)
	if string.sub(mnem, 1, 7) == "vgather" or string.sub(mnem, 1, 8) == "vpgather"
		or string.sub(mnem, 1, 8) == "vscatter" or string.sub(mnem, 1, 9) == "vpscatter" then
		return REJECT_GATHER
	end

	-- AMX tiles (tileloadd/tileloadd64/tileloaddt1/tilestored/tilestored64/
	-- tilestoredt1/tilezero/tilerelease + ldtilecfg): a tile load/store touches a
	-- strided, palette-configuration-dependent footprint (up to 16 rows x 64
	-- bytes) that cannot be bounds-checked as a single access.
	if string.sub(mnem, 1, 4) == "tile" or mnem == "ldtilecfg" then
		return { reject = REASON_AMX, claim = true }
	end

	-- lzcnt/tzcnt/popcnt (+ AT&T w/l/q size suffixes): GPR bit-scan/count ops
	-- whose memory source width is the destination GPR's byte width; the GPR
	-- operand is a def. (Must precede the p-family pattern: "popcnt" would
	-- otherwise parse as an MMX-class mnemonic.)
	if string.match(mnem, "^lzcnt[wlq]?$") or string.match(mnem, "^tzcnt[wlq]?$")
		or string.match(mnem, "^popcnt[wlq]?$") then
		return { w = dstGprW, gpr = gprByPosition, claim = true }
	end

	-- vexpand*/vcompress* (AVX512 expand/compress; the vpexpand*/vpcompress*
	-- spellings ride the p-family pattern below): with no {k} writemask these touch
	-- ALL addressed lanes — a contiguous full-width access — so the width is the
	-- vector width. Masked forms are rejected by the generic {k}-decorator rule
	-- (fp.classify and the frame rewrite). (Must precede the ss/sd/ps/pd suffix
	-- rule: "vcompressd" would otherwise parse a bogus "sd" suffix at 8 bytes.)
	if string.match(mnem, "^vexpand[bdwq]$") or string.match(mnem, "^vcompress[bdwq]$") then
		return { w = "vec", claim = true }
	end

	-- vpermi2*/vpermt2* two-source permutes (vpermi2b/w/d/q/ps/pd, vpermt2b/w/d/q/
	-- ps/pd): the digits defeat the p-family and ss/sd/ps/pd suffix patterns; a
	-- full-vector-width access like the other full-vector permutes. (Must precede
	-- the ss/sd/ps/pd suffix rule so the digit forms get one consistent entry.)
	if string.match(mnem, "^vperm[it]2") then return { w = "vec", claim = true } end

	-- pcmpestri/pcmpistri/pcmpestrm/pcmpistrm: accepted by the p-family pattern below,
	-- but they have UNMODELED IMPLICIT GPR effects — the estri forms read physical
	-- rax/rdx (explicit string lengths) and pcmpestri/pcmpistri clobber rcx (the
	-- index result). The def/use model cannot express that, so regalloc could rename
	-- those registers and silently miscompile: reject. (No VEX forms exist, but
	-- strip a hypothetical v-prefix so such spellings get the same clean error.)
	do
		local e = mnem
		if string.sub(e, 1, 1) == "v" then e = string.sub(e, 2) end
		if e == "pcmpestri" or e == "pcmpistri" or e == "pcmpestrm" or e == "pcmpistrm" then
			return { reject = REASON_ESTRI, claim = true }
		end
	end

	-- pmovzx/pmovsx (also VEX): ^v?pmov[sz]x(bw|bd|bq|wd|wq|dq)$
	local px, pair = string.match(mnem, "^v?pmov([sz])x([a-z]+)$")
	if px then
		local div = PMOV_DIV[pair]
		if div then
			return { w = function(ops)
				local d = vecBytesOf(ops and ops[1]) or 16
				return math.max(1, math.floor(d / div))
			end, claim = true }
		end
		return nil
	end

	-- vpmovqb/qw/qd/db/dw/wb and the saturating vpmovs*/vpmovus* forms (EVEX-only):
	-- TRUNCATING stores — the memory destination is the source vector bytes divided
	-- by the element-ratio (qb: zmm -> 8 bytes, not the full 64 the p-family
	-- pattern would check). Takes precedence over that pattern.
	local tsat, tpair = string.match(mnem, "^v?pmov([su]*)([a-z][a-z])$")
	if tpair and (tsat == "" or tsat == "s" or tsat == "us") then
		local div = PMOVTR_DIV[tpair]
		if div then
			return { w = function(ops)
				local b = widestVecBytes(ops) or 16
				return math.max(1, math.floor(b / div))
			end, claim = true }
		end
	end

	-- VEX/EVEX alias of an EXACT entry (vaddps -> addps, ...): packed 16-byte forms
	-- widen to the operand vector width; aligned forms keep their alignment.
	if string.sub(mnem, 1, 1) == "v" and #mnem > 1 then
		local be = EXACT[string.sub(mnem, 2)]
		if be then
			local c = {}
			for k, v in be do c[k] = v end
			if c.w == 16 then c.w = "vec" end
			if c.align == 16 then c.align = "vec" end
			return c
		end
	end

	-- scalar/packed suffix rules: a (possibly v-prefixed) FP mnemonic ending in
	-- ss/sd/ps/pd (or the AVX512-FP16 packed suffix ph) whose stem starts with a
	-- letter. (v4fmaddps fails the stem rule: after stripping 'v' it starts with
	-- a digit, so it stays unknown -> rejected.)
	--
	-- p-STEM EXCLUSION: after the optional 'v', a stem starting with 'p' is NEVER
	-- a scalar/packed-FP mnemonic — the p-family is the integer vector family
	-- (pabsd, pmaxsd, pminsd, vpdpwusd[s], vpdpbsud[s], vpdpwsud[s], vpopcntd,
	-- ...), where a trailing "sd"/"ss"/"ps"/"pd" is part of the NAME, not a
	-- scalar/packed suffix. The scalar rule pinned those FULL-VECTOR accesses to
	-- 8 bytes (vpabsd (%rdi), %zmm0 reads 64 bytes but was checked at 8);
	-- excluding p-stems lets them fall through to the p-family pattern below
	-- (width = widest vector operand). Scalar FMA keeps its scalar width:
	-- vfmadd231sd's stem is "fmadd231" -> 8 bytes.
	--
	-- The AVX512-FP16 packed suffix ph resolves to "pspd" (= the full vector
	-- width, like ps/pd): vaddph/vmulph/vgetexpph/... are full-vector forms. The
	-- SCALAR FP16 suffix sh is deliberately NOT matched here: vaddsh & co read
	-- m16 (2 bytes), but a width from this rule would be wrong for the
	-- GPR-mixing scalar-half converts (vcvtusi2sh's integer source is m32/m64)
	-- and would leave vcvtsh2si's GPR destination unmodeled — so every sh form
	-- stays unknown and rejects cleanly on a memory operand instead.
	do
		local rest = mnem
		if string.sub(rest, 1, 1) == "v" then rest = string.sub(rest, 2) end
		if string.sub(rest, 1, 1) ~= "p" then
			local stem, suf = string.match(rest, "^([%a][%w]-)([ps][sdh])$")
			if stem and suf ~= "sh" then
				if suf == "ss" then return { w = 4, claim = false } end
				if suf == "sd" then return { w = 8, claim = false } end
				return { w = "pspd", claim = false }
			end
		end
	end

	-- MMX/SSE/AVX integer p-family (padd*, psub*, pand*, pcmpeq*, pshuf*, ...):
	-- width = widest vector operand (mm=8 covers all MMX forms).
	if string.match(mnem, "^v?p[%a]+$") then return { w = "vec", claim = false } end

	-- opmask register ops (kandw/korw/kxnorq/...): register-only (kmov is EXACT).
	if string.match(mnem, "^k[%a%d]+$") then return { memOk = false, claim = true } end

	-- remaining x87-shaped mnemonics: reg-only forms pass through; an Intel-sized
	-- memory form (fadd DWORD PTR [rdi]) gets its width from mem.size.
	if string.match(mnem, "^f[%a%d]*$") then
		return { w = x87MemW, claim = true }
	end

	return nil
end

-- ---------------------------------------------------------------------------
-- def/use modeling. Returns the same shape as x86.classify, or nil when the
-- mnemonic is not an FP/SIMD instruction. Raises clean sarcasm: errors for reject
-- entries, memOk=false with a memory operand, and masked-{k} memory accesses.

function fp.classify(insn)
	local mnem = string.lower(insn.mnemonic)
	local ops = insn.operands or {}
	local raw = insn.raw or mnem
	local entry = fp.lookup(mnem)
	local mem = memOperandOf(ops)
	if entry then
		if entry.reject then
			error("sarcasm: " .. entry.reject .. ": " .. raw)
		end
		if not opsHaveFp(ops) and not entry.claim then
			return nil  -- not an FP use of a shared mnemonic (e.g. GPR `movq`)
		end
		if mem then
			if entry.memOk == false then
				error("sarcasm: `" .. mnem .. "` does not have a memory form"
					.. " (cannot prove memory safety): " .. raw)
			end
			for _, o in ops do
				if o.deco and string.match(o.deco, "{%%?k[0-7]}") then
					error("sarcasm: AVX512 mask-register ({k}) memory accesses are not supported"
						.. " (masked-off lanes may not touch memory; cannot prove memory safety): "
						.. raw)
				end
			end
		end
		local defs, uses = {}, {}
		local g = entry.gpr
		if g == "dst" or g == "src" then
			for _, o in ops do
				if isGprOp(o) then table.insert(g == "dst" and defs or uses, o) end
			end
		elseif type(g) == "function" then
			g(ops, defs, uses)
		end
		if mem then
			if isGprOp(mem.base) then table.insert(uses, mem.base) end
			if isGprOp(mem.index) then table.insert(uses, mem.index) end
		end
		-- RMW registers: a GPR operand that is both a def and a use (xadd's two
		-- operands, the adcx/adox/crc32 destination) must have its use and def
		-- webs unioned — otherwise the operand renders as the use web's register
		-- while subsequent reads reach the def web's (a silent desync). (Also
		-- covers a memory base/index register aliasing the destination.)
		local rmw = {}
		local defNums = {}
		for _, o in defs do defNums[o.num] = true end
		for _, o in uses do
			if defNums[o.num] then table.insert(rmw, o.num) end
		end
		return { defs = defs, uses = uses, rmw = rmw, control = "none", fallsThrough = true }
	end
	-- unknown mnemonic: an FP/vector/x87/VEX-shaped instruction with a memory
	-- operand whose width we cannot determine is unsound to check at any default
	-- width, so reject it. Register-only unknown forms pass through.
	if mem and (opsHaveFp(ops) or string.match(mnem, "^[fv]")) then
		error("sarcasm: cannot determine the memory access width of '" .. mnem
			.. "' (cannot prove memory safety): " .. raw)
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- memory access width/alignment. Returns (w, align) or nil when there is no
-- memory operand or the width is unknowable. (noCheck entries return nil; the
-- codegen lowerSpecial hook passes them through unchecked.)
--
-- The width resolved here is AUTHORITATIVE: an Intel PTR size annotation
-- (mem.size) must never override it — the emitted instruction encodes the
-- ISA-fixed width regardless of the annotation (a `vmovdqu64 DWORD PTR [mem],
-- zmm0` still stores 64 bytes), so letting a lying annotation under-size the
-- result would under-check a heap access or under-size a materialized stack slot
-- (a stack-overflow-into-the-caller hole). Instead, a PTR size that CONTRADICTS
-- the resolved ISA-fixed width is rejected cleanly. Size-driven width functions
-- (SIZE_DRIVEN — the x87 PTR fallback and the cvtsi2ss/sd integer source) take
-- their width FROM the annotation by design and are exempt. `raw` (the source
-- text of the instruction) is used only for the rejection message.

function fp.accessWidth(mnem, ops, raw)
	ops = ops or {}
	local mem = memOperandOf(ops)
	if not mem then return nil end
	local function checkSize(w)
		if w and mem.size and mem.size ~= w then
			error("sarcasm: PTR size annotation (" .. tostring(mem.size)
				.. " bytes) contradicts the memory access width (" .. tostring(w)
				.. " bytes) of '" .. mnem .. "': " .. (raw or mnem))
		end
		return w
	end
	-- embedded broadcast {1toN}: the access is one element (all lanes share it).
	if mem.bcastN then
		local b = widestVecBytes(ops) or 16
		return checkSize(math.max(1, math.floor(b / mem.bcastN))), 1
	end
	local entry = fp.lookup(mnem)
	if not entry or entry.reject or entry.noCheck then return nil end
	if not opsHaveFp(ops) and not entry.claim then return nil end
	local w = entry.w
	local sizeDriven = false
	if type(w) == "function" then
		sizeDriven = SIZE_DRIVEN[w] or false
		w = w(ops, mem, mnem, raw)
	end
	if w == "vec" then w = widestVecBytes(ops) end
	if w == "pspd" then w = math.max(16, widestVecBytes(ops) or 16) end
	if not w then return nil end
	if not sizeDriven then checkSize(w) end
	local a = entry.align
	if a == "vec" then a = widestVecBytes(ops) end
	return w, (a or 1)
end

-- ---------------------------------------------------------------------------
-- unsafe-instruction rejection (consulted for EVERY mnemonic, FP or not, at the
-- top of x86.classify before baseMnemonic mapping, so e.g. `movsq` is seen
-- before it maps to `mov`). Returns a reason string or nil.

local REASON_SYSCALL = "system-call instructions cannot be bounds-checked (their effect on memory safety is unknowable)"
local REASON_PORTIO = "port-I/O instructions cannot be bounds-checked (they transfer data the checker cannot see)"
local REASON_PRIV = "privileged instructions are not supported (cannot prove memory safety)"
local REASON_STRING = "string instructions use implicit rsi/rdi memory operands that cannot be bounds-checked (cannot prove memory safety)"
local REASON_PREFIX = "instruction prefixes (rep/lock/xacquire/xrelease) are not supported (the prefixed instruction's memory effects cannot be modeled; cannot prove memory safety)"
local REASON_INT = "software interrupt `int N` is not supported for N != 3 (only int3/`int $3`, which raises SIGTRAP, is allowed)"
local REASON_CRDR = "control/debug register moves are not supported (privileged processor state; cannot prove memory safety)"
local REASON_CLZERO = "clzero stores to an implicit memory operand (the 64-byte cache line addressed by rax) that cannot be bounds-checked (cannot prove memory safety)"
local REASON_XLAT = "xlatb loads from an implicit memory operand (the byte at rbx + al) that cannot be bounds-checked (cannot prove memory safety)"
local REASON_FARCTL = "far control-transfer instructions (lcall/ljmp) have implicit stack memory effects (a far return-frame push) that cannot be modeled (cannot prove memory safety)"

-- Instructions with implicit GPR operands the def/use model cannot express (same
-- class as pcmpestri/pcmpistri, which the fp table rejects): regalloc could rename
-- the registers they secretly read/write and silently miscompile. (Exact-key table:
-- `rdtsc` matches only "rdtsc", never a legit look-alike mnemonic.)
local function implicitGprReason(mnem, list)
	return mnem .. " has implicit GPR operands (" .. list
		.. ") that are not modeled (cannot prove memory safety)"
end

local UNSAFE = {
	syscall = REASON_SYSCALL, sysenter = REASON_SYSCALL,
	sysexit = REASON_SYSCALL, sysret = REASON_SYSCALL,
	["in"] = REASON_PORTIO, ins = REASON_PORTIO,
	inb = REASON_PORTIO, inw = REASON_PORTIO, inl = REASON_PORTIO,
	insb = REASON_PORTIO, insw = REASON_PORTIO, insl = REASON_PORTIO, insd = REASON_PORTIO,
	out = REASON_PORTIO, outs = REASON_PORTIO,
	outb = REASON_PORTIO, outw = REASON_PORTIO, outl = REASON_PORTIO,
	outsb = REASON_PORTIO, outsw = REASON_PORTIO, outsl = REASON_PORTIO, outsd = REASON_PORTIO,
	hlt = REASON_PRIV, wrmsr = REASON_PRIV, rdmsr = REASON_PRIV,
	-- privileged descriptor-table/machine-status-word loads (#GP at CPL > 0);
	-- sgdt/sidt/sldt/str/smsw are unprivileged and supported (EXACT widths above).
	lgdt = REASON_PRIV, lidt = REASON_PRIV, lldt = REASON_PRIV,
	ltr = REASON_PRIV, lmsw = REASON_PRIV,
	into = REASON_INT, int1 = REASON_INT,
	-- implicit memory operands the checker cannot see (same class as the string
	-- ops): clzero writes the 64-byte line at rax, xlatb reads rbx + al.
	clzero = REASON_CLZERO,
	xlat = REASON_XLAT, xlatb = REASON_XLAT,
	-- far call/jump: implicit far return-frame stack push (and a code-segment
	-- change) sarcasm cannot model — even the immediate form touches the stack.
	lcall = REASON_FARCTL, ljmp = REASON_FARCTL,
	-- implicit GPR reads/writes the def/use model cannot express: cpuid writes
	-- rax/rbx/rcx/rdx; rdtsc/rdtscp write rax/rdx (and rcx for rdtscp); xgetbv
	-- writes rax/rdx; rdpkru/wrpkru read/write eax/ecx/edx; monitor reads
	-- rax/rcx/rdx; mwait reads rax/rcx; umwait/tpause read the implicit EDX:EAX
	-- TSC-deadline pair (the explicit r32 is only a control hint; SDM Vol. 2B —
	-- "UMWAIT r32, <edx>, <eax>", "TPAUSE r32, <edx>, <eax>").
	cpuid = implicitGprReason("cpuid", "rax/rbx/rcx/rdx"),
	rdtsc = implicitGprReason("rdtsc", "rax/rdx"),
	rdtscp = implicitGprReason("rdtscp", "rax/rdx/rcx"),
	xgetbv = implicitGprReason("xgetbv", "rax/rdx"),
	rdpkru = implicitGprReason("rdpkru", "eax/ecx/edx"),
	wrpkru = implicitGprReason("wrpkru", "eax/ecx/edx"),
	monitor = implicitGprReason("monitor", "rax/rcx/rdx"),
	mwait = implicitGprReason("mwait", "rax/rcx"),
	umwait = implicitGprReason("umwait", "rax/rdx"),
	tpause = implicitGprReason("tpause", "rax/rdx"),
	-- umonitor has no implicit GPR (its address is the explicit operand), but it
	-- arms address-monitoring hardware on a cache-line-sized memory range the
	-- checker cannot see or bounds-check — the same class as monitor/mwait.
	umonitor = "umonitor arms address-monitoring hardware on a memory range whose extent cannot be bounds-checked (cannot prove memory safety)",
}

-- string ops: implicit rsi/rdi memory the checker cannot see. (The Intel dword
-- forms lodsd/stosd/scasd are unambiguous; movsd/cmpsd are FP instructions when
-- they have operands, so those reject only in their zero-operand string form.)
local STRINGOPS = {
	movs = true, movsb = true, movsw = true, movsl = true, movsq = true,
	stos = true, stosb = true, stosw = true, stosl = true, stosq = true, stosd = true,
	lods = true, lodsb = true, lodsw = true, lodsl = true, lodsq = true, lodsd = true,
	scas = true, scasb = true, scasw = true, scasl = true, scasq = true, scasd = true,
	cmps = true, cmpsb = true, cmpsw = true, cmpsl = true, cmpsq = true,
}
local STRINGOPS_ZERO_OPERAND = { movsd = true, cmpsd = true }

-- prefixes that still reach here as mnemonics (the real instruction trails as
-- operands). `lock` is parsed as a prefix TAG by the parser (x86_64_parse) and
-- validated in x86_64_isa.classify — a "lock" mnemonic only survives here when
-- the input stacks prefixes (`lock lock xadd`), which stays rejected.
local PREFIXES = {
	rep = true, repe = true, repne = true, repz = true, repnz = true,
	lock = true, xacquire = true, xrelease = true,
}

function fp.unsafeReject(mnem, insn)
	mnem = string.lower(mnem)
	local reason = UNSAFE[mnem]
	if reason then return reason end
	if STRINGOPS[mnem] then return REASON_STRING end
	if PREFIXES[mnem] then return REASON_PREFIX end
	if STRINGOPS_ZERO_OPERAND[mnem] and #(insn.operands or {}) == 0 then return REASON_STRING end
	if mnem == "int" then
		local ops = insn.operands or {}
		local v = ops[1] and ops[1].kind == "imm" and (ops[1].value or tonumber(ops[1].text)) or nil
		if v == 3 then return nil end  -- int $3 == int3: SIGTRAP is fine
		return REASON_INT
	end
	-- mov to/from %crN/%drN: the parser leaves cr3/dr7 etc. as bare symbols (keeping
	-- a leading `%` in AT&T syntax).
	if mnem == "mov" or mnem == "movq" or mnem == "movl" then
		for _, o in (insn.operands or {}) do
			if o.kind == "sym" and string.match(string.lower(o.text), "^%%?[cd]r[0-9]+$") then
				return REASON_CRDR
			end
		end
	end
	return nil
end

return fp
