	.text
	.globl	f
	.type	f, @function
f:                              ;! long(long)
	# setcc with the HIGH-byte destination %ah: the web model has no
	# subregister view (x86_64_parse maps ah to the same register 0 web as al)
	# and the renderer always names the LOW byte of the colored register, so
	# this would silently write %al. Rejected at compile time.
	endbr64
	movq	%rdx, %rax
	cmpq	$5, %rax
	sete	%ah
	retq
	.size	f, .-f
	.section	.note.GNU-stack,"",@progbits
