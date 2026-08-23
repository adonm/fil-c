	.text
	.globl	f
	.type	f, @function
f:                              ;! void(void)
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	8(%rsp), %rax
	popq	%rbp
	ret
	.size	f, .-f
