	.arch armv8-a
	.text
	.global	foo
	.type	foo, %function
foo:                            ;! uint64_t(ptr)
	mov	x1, [x0]
	ret
	.size	foo, .-foo
