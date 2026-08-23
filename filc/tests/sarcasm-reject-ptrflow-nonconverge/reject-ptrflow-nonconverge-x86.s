# The join at .L2 merges %rax's two defs into one register web, but the defs copy
# from two different pointer origins (%rdi vs %rsi). One temp cannot carry two
# capabilities, so pointer-flow analysis never converges and sarcasm must reject
# this cleanly: "pointer-flow analysis does not converge: ...".
	.text
	.globl	f
	.type	f, @function
f:                              ;! void(ptr, ptr)
	movq	(%rdi), %rcx      # scalar condition (plain load, not a pointer source)
	testq	%rcx, %rcx
	je	.L1
	movq	%rdi, %rax
	jmp	.L2
.L1:
	movq	%rsi, %rax
.L2:
	movq	%rdi, (%rax)    ;! store ptr
	ret
	.size	f, .-f
