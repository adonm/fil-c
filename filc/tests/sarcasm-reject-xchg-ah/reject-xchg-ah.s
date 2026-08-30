# XCHG with a high-byte register: the web model has no subregister view, so
# `ah` maps onto the SAME web as `al` and the renderer always names the LOW
# byte of the colored register — `xchgb %ah, %bl` would silently swap %al.
# Hardware ground truth (rax=0x1100000000000200, rbx=0x55550000000000AA in):
# rax=0x110000000000aa00 out; sarcasm's old silent model gave
# 0x11000000000002aa. High-byte operands are rejected in every position.
	.text
	.globl	foo
	.type	foo, @function
foo:                            ;! long(long)
	endbr64
	movabsq	$0x1100000000000200, %rax
	movabsq	$0x55550000000000AA, %rbx
	xchgb	%ah, %bl
	movq	%rbx, %rax
	movl	$0, %edx
	ret
	.size	foo, .-foo
	.section	.note.GNU-stack,"",@progbits
