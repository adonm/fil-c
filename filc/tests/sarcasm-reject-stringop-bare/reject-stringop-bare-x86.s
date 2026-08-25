	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr, ptr)
	movsq
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
