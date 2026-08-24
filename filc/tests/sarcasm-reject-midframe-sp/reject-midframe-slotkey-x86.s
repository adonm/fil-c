	.file	"midframe-slotkey.c"
	.text
	.globl	f
	.type	f, @function
f:                              ;! long()
	subq	$16, %rsp
	movq	$5, (%rsp)
	subq	$8, %rsp
	movq	$6, (%rsp)
	addq	$8, %rsp
	movq	(%rsp), %rax
	addq	$16, %rsp
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
