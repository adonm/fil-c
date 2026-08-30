# The Intel spellings of the high-byte registers go through the same
# generalized rejection (the message names the Intel spelling and the low-byte
# form to use instead).
	.text
	.globl	foo
	.type	foo, @function
foo:                            ;! long(long)
	endbr64
	.intel_syntax noprefix
	mov	bl, ch
	.att_syntax
	movl	$0, %eax
	ret
	.size	foo, .-foo
	.section	.note.GNU-stack,"",@progbits
