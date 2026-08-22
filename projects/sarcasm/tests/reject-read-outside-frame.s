	.text
	.global	f
	.type	f, %function
f:                              ;! unsigned(void)
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	ldr	x0, [sp, 64]
	ldp	x29, x30, [sp], 16
	ret
	.size	f, .-f
