	.text
	.globl	f
	.type	f, @function
f:                              ;! float(float)
	movl	%edi, %eax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
