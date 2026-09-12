# A call to a label in the middle of a signatured function's own body is not
# a local call and must fail to compile. Mechanism, with sources:
# - Subroutine regions are maximal spans of unconsumed top-level statements
#   headed by a non-.globl, non-signature label (localcall.luau:130-140); a
#   signature-annotated label is never subroutine content, so .Lmidsub below
#   (consumed by outer_midfn's body) belongs to no region.
# - A label is claimable only via a region or via a sig'd function's
#   entry-adjacent alias (localcall.luau:259-261); the alias-clone path is
#   the whole-body pristine copy for entry-adjacent aliases
#   (localcall.luau:205-221,230-236; alias detection tailcall.luau:86-93,
#   146-154). .Lmidsub is neither, so the call is never claimed -- even with
#   `#! local` it would be rejected by localMismatch (localcall.luau:274-281).
# - The unclaimed, unannotated call then hits transform's rejection:
#   "call to '.Lmidsub' has no signature annotation (annotate the callsite,
#   e.g. `call .Lmidsub ;! int(ptr)')" (transform.luau:308-312).
# Contrast sarcasm-localcall-midlabel-att, where a mid-label call inside a
# SUBROUTINE body is valid (clone = [mid-label .. ret(s)]), and
# sarcasm-localcall-sidechan-att, the positive companion: the
# .Lkey_expansion_* routines must be lifted to top-level labels (the OpenSSL
# aesni_set_encrypt_key "End the function body here" split) precisely so the
# alias-clone can inline them. This test must fail to compile; if it ever
# compiles, the split can go away.
	.text
	.globl	outer_midfn
	.type	outer_midfn, @function
outer_midfn:                    ;! long(long)
	endbr64
	movq	%rdi, %r10
	call	.Lmidsub
	movq	%r9, %rax
	ret
	.align	16
.Lmidsub:
	leaq	(%r10,%r10), %r9
	addq	$3, %r9
	ret
	.size	outer_midfn, .-outer_midfn
	.section	.note.GNU-stack,"",@progbits
