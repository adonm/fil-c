	.intel_syntax noprefix
	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	fxch	st(1)
	mov	rax, rdi
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
