	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	fnstsw	%ax
	movzwl	%ax, %eax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
