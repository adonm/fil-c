	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr)
	# {k}-masked forms are supported only on the vector moves, truncating
	# stores, and expand/compress forms. A masked ALU memory source (whose
	# lane/mask structure sarcasm does not model) stays rejected.
	vaddps	(%rdi), %zmm0, %zmm1{%k1}
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
