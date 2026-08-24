	.intel_syntax noprefix
	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	sub	rsp, 24
	movdqa	XMMWORD PTR [rsp], xmm0
	movdqa	xmm1, XMMWORD PTR [rsp]
	add	rsp, 24
	mov	rax, rdi
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
