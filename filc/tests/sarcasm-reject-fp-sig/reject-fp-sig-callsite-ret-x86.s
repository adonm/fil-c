	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	movq	%rdi, %rax
	call	g ;! double(long)
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
