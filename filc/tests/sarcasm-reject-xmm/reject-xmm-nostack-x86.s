	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	cvtsi2sdq	%rdi, %xmm0
	cvttsd2siq	%xmm0, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
