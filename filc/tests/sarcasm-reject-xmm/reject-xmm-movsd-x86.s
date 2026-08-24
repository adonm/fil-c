	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$16, %rsp
	movsd	%xmm0, -8(%rbp)
	movsd	-8(%rbp), %xmm1
	cvttsd2siq	%xmm1, %rax
	leave
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
