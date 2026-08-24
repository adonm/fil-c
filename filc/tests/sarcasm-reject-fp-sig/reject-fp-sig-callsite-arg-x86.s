	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	movq	%rdi, %rax
	call	g ;! long(double)
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
