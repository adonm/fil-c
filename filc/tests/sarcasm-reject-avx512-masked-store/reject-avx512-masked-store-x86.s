	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr, ptr)
	vmovdqu64	%zmm0, (%rsi){%k3}
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
