	.file	"cmll-df.c"
	.text

	# REAL Camellia_cbc_encrypt DF torture (item 9 — replaces the former
	# model-only residue tails): this helper enters the SARCASM-assembled
	# Camellia_cbc_encrypt
	# (projects/openssl-3.6.4/crypto/camellia/asm/cmll-x86_64.pl) with DF=1
	# set by the `std` below — standing in for an ABI-violating caller
	# (System V requires DF=0 across calls and sarcasm never emits std).
	# The residue tails (.Lcbc_enc_pushf / .Lcbc_dec_pushf) copy the saved
	# partial block with a CLD-LESS `rep movsb` whose count is the length
	# residue; sarcasm's checked rep lowering traps DF=1 with an illegal
	# instruction when the count is nonzero — it must NOT copy backwards
	# (native hardware without cld) and must NOT silently return with DF
	# cleared (a cld without the pushfq/popfq save/restore would normalize
	# the caller's DF). The `cld` after the call is test hygiene so the
	# harness keeps running with DF=0 after a surviving call.
	#
	# Residue analysis (which lengths trap — verified against the .pl AND
	# empirically 2026-09, and pinned by cmll-df-main.c):
	# - len == 0 takes `cmp $0,%rdx; je .Lcbc_abort` up front and never
	#   reaches a rep: no trap even with DF=1, dst untouched.
	# - len == 16 (encrypt): residue = 16&15 = 0 and inp != end, so the
	#   block loop runs once and `cmp $0,%rcx; jne .Lcbc_enc_tail` skips
	#   the tail: no rep executes, no trap, correct ciphertext. (An
	#   earlier draft of this task said "len=16 must-trap"; that is wrong
	#   for a multiple-of-16 length — only a NONZERO residue reaches a
	#   rep. len=16 is kept as a no-trap pin for the residue-0 path.)
	# - len == 8 (encrypt): `and $-16,%rdx` leaves end == inp, so
	#   `cmp $inp,%rdx; je .Lcbc_enc_tail` enters the tail with
	#   residue == len == 8 (nonzero): the checked rep observes DF=1 and
	#   traps. Any len with len&15 != 0 traps the same way (verified
	#   len=20); any multiple of 16 does not (verified len=32).
	# The DF=0 forward-copy path is covered by rep_movsb in
	# sarcasm-rep-movs-att (same cld-less shape) and by the DF=0
	# encrypt/decrypt round-trip in cmll-df-main.c.
	#
	# Proof obligations for the two tails (re-check against generated asm):
	# - No std/cld sits between Camellia_cbc_encrypt entry and either rep,
	#   so the rep observes the entry DF. Grep the SARCASM=1 output:
	#     awk '/^Camellia_cbc_encrypt:/,/\.Lcbc_abort:/' cmll.yolo.s |
	#       grep -c -e '\bstd\b' -e '\bcld\b'   # must be 0
	#   (both reps are bare `rep movsb`; the full file contains no std).
	# - pushfq/popfq counts: the gas output keeps both pristine pairs
	#   (`rg -c pushfq` == 2, `rg -c popfq` == 2); the SARCASM=1 output
	#   elides them (`rg -c 'pushfq|popfq'` == 0) by design — the checked
	#   rep traps DF=1 instead of saving/restoring it.
	# (In-test greps cannot run inside filc/run-tests, so the recipes above
	# are documentation; the C driver pins the same properties at runtime
	# with asserts: len-0 dst-untouched, len-16 round-trip, len-8 trap.)
	.globl	cmll_df1_encrypt
	.type	cmll_df1_encrypt, @function
cmll_df1_encrypt:               ;! void(ptr, ptr, size_t, ptr, ptr, int)
	# %rdi=in %rsi=out %rdx=len %rcx=key %r8=ivec %r9d=enc. The call
	# marshalling (plain moves) preserves DF from the std to the callee.
	std
	call	Camellia_cbc_encrypt ;! void(ptr, ptr, size_t, ptr, ptr, int)
	cld
	ret
	.size	cmll_df1_encrypt, .-cmll_df1_encrypt
	.section	.note.GNU-stack,"",@progbits
