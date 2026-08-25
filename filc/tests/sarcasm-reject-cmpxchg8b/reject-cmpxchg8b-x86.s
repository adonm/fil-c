	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr)
	# cmpxchg8b has implicit edx:eax / ecx:ebx operands that the def/use model
	# cannot express: reject (cannot prove memory safety).
	cmpxchg8b	(%rdi)
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
