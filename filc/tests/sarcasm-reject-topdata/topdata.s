# Top-level (inter-function) data cannot be given a capability automatically:
# a .data/.quad block outside any function -- here under a global label -- must
# be rejected, not silently dropped (a silently dropped global would make any
# reach of it hand out a raw address). Mirrors the arm64 top-level data
# rejection with the same diagnostic.
	.text
	.globl	foo
	.type	foo, @function
foo:                            ;! unsigned(void)
	endbr64
	movq	%rdi, %rax
	movl	$42, %eax
	ret
	.size	foo, .-foo
	.data
	.globl	myglob
myglob:
	.quad	42
	.section	.note.GNU-stack,"",@progbits
