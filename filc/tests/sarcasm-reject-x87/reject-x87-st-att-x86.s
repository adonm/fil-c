	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	fstp	%st(0)
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
