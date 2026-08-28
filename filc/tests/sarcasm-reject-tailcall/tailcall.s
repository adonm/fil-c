	.text
	.globl	f
	.type	f, @function
f:                              ;! void(ptr)
	endbr64
	movq	%rdi, %rax
	# A branch to a non-local label is a tail call: even with a ;! signature it
	# is rejected (tail calls are not yet supported). Branches to local labels
	# are fine.
	jmp	somefunc            ;! int(ptr)
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
