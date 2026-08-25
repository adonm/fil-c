	.text
	.globl	f
	.type	f, @function
f:                              ;! long(ptr)
	# cpuid implicitly writes rax/rbx/rcx/rdx; the def/use model cannot
	# express that (regalloc could rename those registers and silently
	# miscompile), so it must reject. (The endbr64/GPR instructions keep the
	# file arch-detected as x86_64.)
	endbr64
	cpuid
	movq	%rdi, %rax
	ret
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
