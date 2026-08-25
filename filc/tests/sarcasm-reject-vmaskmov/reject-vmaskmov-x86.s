	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr)
	vmaskmovps	(%rdi), %xmm1, %xmm0
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
