	.file	"alloca-direct-rbp.c"
	.text
	.globl	foo
	.type	foo, @function
foo:                            ;! long()
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$408, %rsp
	leaq	-120(%rsp), %rcx   ;! alloca result size=400
	movq	$9, -400(%rbp)
	movq	(%rcx), %rax
	leave
	ret
	.size	foo, .-foo
	.section	.note.GNU-stack,"",@progbits
