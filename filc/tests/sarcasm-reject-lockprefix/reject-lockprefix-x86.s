	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr, ptr)
	lock xaddq	%rsi, (%rdi)
	movq	%rsi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
