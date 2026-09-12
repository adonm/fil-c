# The OpenSSL aesni_set_decrypt_key -> call __aesni_set_encrypt_key shape
# (crypto/aes/asm/aesni-x86_64.pl): the alias is the entry-adjacent second
# label of the signatured set_encrypt_key, so an unannotated call to it is a
# local call whose clone is the function's whole body (frame setup included),
# and that clone inlines the body's calls to the top-level .Lkey_expansion_*
# locals (that is why the "End the function body here" split must precede
# them: a call to a mid-body label of a signatured function is rejected, see
# sarcasm-localcall-midfn-att). The caller then uses the %esi side channel
# the callee returns beside %eax (shl $4,$bits for rounds-1, then the end of
# the key schedule): a signature-marshalled call would preserve only %eax.
# Alias detection: tailcall.luau:86-93,146-154; whole-body claim + pristine
# clone: localcall.luau:205-221,230-236. sarcasm-localcall-into-func-att
# covers the bare alias-clone; this covers the surviving %esi side channel
# plus the inlined local call. If the sub call were not inlined (or %esi
# were lost), the returned pointer would mismatch.
	.text
	.globl	set_dec_alias
	.type	set_dec_alias, @function
set_dec_alias:                  ;! long(ptr,long,ptr)
	endbr64
	subq	$8, %rsp
	call	__set_enc_alias
	shll	$4, %esi	# rounds-1 side channel (real: shl $4,$bits)
	testl	%eax, %eax
	jnz	.Ldec_ret
	leaq	16(%rdx,%rsi), %rax	# end of key schedule (real: lea 16($key,$bits),$inp)
	addq	$8, %rsp
	ret
.Ldec_ret:
	movl	$-99, %eax
	addq	$8, %rsp
	ret
	.size	set_dec_alias, .-set_dec_alias
	.globl	set_enc_alias
	.type	set_enc_alias, @function
set_enc_alias:                  ;! long(ptr,long,ptr)
__set_enc_alias:
	subq	$8, %rsp
	call	.Lexpand_like	# inlined into the alias-clone (real: call .Lkey_expansion_128)
	movl	$0, %eax
	addq	$8, %rsp
	ret
	.size	set_enc_alias, .-set_enc_alias
	.size	__set_enc_alias, .-__set_enc_alias
.Lexpand_like:	# top-level local, like the post-split .Lkey_expansion_* routines
	movl	$9, %esi	# rounds-1 (real: mov $bits,16(%rax), i.e. 240($key))
	ret
	.section	.note.GNU-stack,"",@progbits
