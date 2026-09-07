	.text
	# `new capability` requires an instruction with a memory operand.
	.globl	newcap_nomem
	.type	newcap_nomem, @function
newcap_nomem:                   ;! long(ptr)
	endbr64
	addq	$8, %rdi #! new capability %rdi
	movq	%rdi, %rax
	ret
	.size	newcap_nomem, .-newcap_nomem
	.section	.note.GNU-stack,"",@progbits
