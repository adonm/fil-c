	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	movq	%rdi, %mm0
	movq	%mm0, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
