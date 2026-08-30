# High-byte register operands are rejected for EVERY instruction and operand
# position (generalizing the setcc-%ah rejection). %ch/%dh/%bh never even
# parsed before: they masqueraded as bare symbols and died with the misleading
# "memory access with a symbolic address" error. This file pins %dh, %ch and
# %bh; the Intel-spelling file in this directory pins the Intel path.
	.text
	.globl	foo_dh
	.type	foo_dh, @function
foo_dh:                         ;! long(long)
	endbr64
	movb	%dh, %al
	ret
	.size	foo_dh, .-foo_dh
	.globl	foo_ch
	.type	foo_ch, @function
foo_ch:                         ;! long(long)
	endbr64
	movq	%rax, %ch
	ret
	.size	foo_ch, .-foo_ch
	.globl	foo_bh
	.type	foo_bh, @function
foo_bh:                         ;! long(long)
	endbr64
	sete	%bh
	ret
	.size	foo_bh, .-foo_bh
	.section	.note.GNU-stack,"",@progbits
