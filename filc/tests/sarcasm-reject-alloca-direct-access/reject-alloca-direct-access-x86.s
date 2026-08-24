	.file	"alloca-direct.c"
	.text
	.globl	foo
	.type	foo, @function
foo:                            ;! long()
	subq	$408, %rsp
	leaq	-120(%rsp), %rcx   ;! alloca result size=400
	movq	$9, -120(%rsp)
	movq	-120(%rsp), %rax
	addq	$408, %rsp
	ret
	.size	foo, .-foo
	.section	.note.GNU-stack,"",@progbits
