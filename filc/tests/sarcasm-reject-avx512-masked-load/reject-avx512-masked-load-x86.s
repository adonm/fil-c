	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr)
	vmovdqu8	(%rdi), %zmm0{%k1}
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
