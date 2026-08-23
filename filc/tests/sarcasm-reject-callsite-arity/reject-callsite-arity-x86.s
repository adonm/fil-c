	.text
	.globl	g
	.type	g, @function
g:                              ;! long(ptr, ptr, long)
	pushq	%rbp
	movq	%rsp, %rbp
	call	callee	;! long(ptr, ptr, long)
	popq	%rbp
	ret
	.size	g, .-g
