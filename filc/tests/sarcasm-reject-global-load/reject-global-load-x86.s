	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr)
	movq	g(%rip), %rax
	ret
	.size	f, .-f
	.comm	g,8,8
	.section	.note.GNU-stack,"",@progbits
