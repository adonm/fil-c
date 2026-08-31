	.text
	.globl	mid
	.type	mid, @function
mid:                            ;! long(long)
	endbr64
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$16, %rsp
	movq	%rdi, -8(%rbp)
	movq	%rsp, %rbx          # a post-prologue rsp save: still a stack-address escape
	movq	-8(%rbp), %rax
	movq	%rax, %rdi
	movq	%rdi, %rax
	leave
	ret
	.size	mid, .-mid
	.section	.note.GNU-stack,"",@progbits
