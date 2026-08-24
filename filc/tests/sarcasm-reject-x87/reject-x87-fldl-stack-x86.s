	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$16, %rsp
	fldl	-8(%rbp)
	fistpq	-8(%rbp)
	movq	-8(%rbp), %rax
	leave
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
