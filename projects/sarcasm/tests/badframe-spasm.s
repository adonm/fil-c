	.arch armv8-a
	.text
	.global	badstore
	.type	badstore, %function
badstore:                       ;! void(int)
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	str	x0, [sp, 64]
	ldp	x29, x30, [sp], 16
	ret
	.size	badstore, .-badstore
