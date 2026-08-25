	.text
	.globl	g
	.type	g, @function
g:                              ;! long(ptr)
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rdi, %rax
	call	callee	;! long(ptr, ptr, long)
	popq	%rbp
	ret
	.size	g, .-g
