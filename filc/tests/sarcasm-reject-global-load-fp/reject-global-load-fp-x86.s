	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr)
	movsd	g(%rip), %xmm0
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.comm	g,8,8
	.section	.note.GNU-stack,"",@progbits
