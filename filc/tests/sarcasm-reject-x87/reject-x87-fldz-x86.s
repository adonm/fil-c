	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	fldz
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
