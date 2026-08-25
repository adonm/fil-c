	.text
	.global	f
	.type	f, %function
f:                              ;! int(ptr)
	# the atomic pointer annotations are x86_64-only for now
	ldr	x0, [x0]        ;! atomic load ptr
	ret
	.size	f, .-f
