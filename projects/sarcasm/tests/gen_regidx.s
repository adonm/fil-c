	.file	"regidx-spasm.s"
	.text
	.globl	pizlonated_get
	.p2align	2
	.type	pizlonated_get,@function
pizlonated_get:
	adrp	x0, pizlonatedFO_get+16
	add	x0, x0, :lo12:pizlonatedFO_get+16
	mov	x1, x0
	ret
.Lfunc_end_getter_get:
	.size	pizlonated_get, .Lfunc_end_getter_get-pizlonated_get

	.globl	pizlonatedFIP2529_get
	.p2align	2
	.type	pizlonatedFIP2529_get,@function
pizlonatedFIP2529_get:
	sub	sp, sp, #48
	stp	x29, x30, [sp, #32]
	add	x29, sp, #32
	ldr	x9, [x0]
	cmp	sp, x9
	b.hs	.Lsovok_get
	b	filc_stack_overflow_failure
.Lsovok_get:
	ldr	x9, [x0, #16]
	mov	x8, sp
	adrp	x10, .Lfilc_origin_get
	add	x10, x10, :lo12:.Lfilc_origin_get
	stp	x9, x10, [sp, #0]
	str	x8, [x0, #16]
	mov	x5, x0
	mov	x2, x2
	mov	x3, x3
	str	x3, [sp, #16]
	mov	x4, x4
	add	x0, x2, x4
	cbz	x3, .Lfail_get_1
	cmp	x0, x3
	b.lo	.Lfail_get_1
	ldur	x1, [x3, #-16]
	cmp	x0, x1
	b.hs	.Lfail_get_1
	ldrb	w0, [x2, x4]
	mov	x1, x0
	mov	w0, wzr
	ldr	x8, [sp, #0]
	str	x8, [x5, #16]
	ldp	x29, x30, [sp, #32]
	add	sp, sp, #48
	ret
.Lfail_get_1:
	mov	x0, x0
	mov	x1, x3
	adrp	x2, .Lfilc_aco_get_1
	add	x2, x2, :lo12:.Lfilc_aco_get_1
	bl	filc_optimized_access_check_fail
	.size	pizlonatedFIP2529_get, .-pizlonatedFIP2529_get

	.weak	pizlonated2ET2529
	.p2align	2
	.type	pizlonated2ET2529,@function
pizlonated2ET2529:
	stp	x30, x19, [sp, #-16]!
	cmp	x2, #16
	b.lo	.LBB_2ET2529_fail
	ldr	x2, [x0, #128]
	ldr	x3, [x0, #384]
	ldr	x4, [x0, #136]
	ldr	x5, [x0, #392]
	mov	x19, x0
	ldr	x8, [x1]
	blr	x8
	tbnz	w0, #0, .LBB_2ET2529_exc
	str	x1, [x19, #128]
	mov	w1, #8
	str	xzr, [x19, #384]
.LBB_2ET2529_ret:
	and	w0, w0, #0x1
	ldp	x30, x19, [sp], #16
	ret
.LBB_2ET2529_exc:
	b	.LBB_2ET2529_ret
.LBB_2ET2529_fail:
	mov	x0, x2
	mov	w1, #16
	mov	x2, xzr
	bl	filc_cc_args_check_failure
	.size	pizlonated2ET2529, .-pizlonated2ET2529

	.type	pizlonatedFO_get,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
pizlonatedFO_get:
	.xword	pizlonatedFO_get+16
	.xword	(pizlonatedFO_get+16)+36873221949095936
	.xword	pizlonatedFIP2529_get
	.xword	pizlonated2ET2529
	.xword	2529
	.size	pizlonatedFO_get, 40

	.type	.Lfilc_string_get,@object
	.section	.rodata.str1.4,"aMS",@progbits,1
	.p2align	2, 0x0
.Lfilc_string_get:
	.asciz	"get"
	.size	.Lfilc_string_get, 4

	.type	.Lfilc_function_origin_get,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_function_origin_get:
	.xword	.Lfilc_string_get
	.xword	0
	.word	1
	.zero	4
	.xword	0
	.byte	0
	.byte	0
	.byte	0
	.zero	1
	.word	0
	.size	.Lfilc_function_origin_get, 40

	.type	.Lfilc_origin_get,@object
	.p2align	3, 0x0
.Lfilc_origin_get:
	.xword	.Lfilc_function_origin_get
	.word	0
	.word	0
	.size	.Lfilc_origin_get, 16

	.type	.Lfilc_aco_get_1,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_aco_get_1:
	.word	1
	.byte	1
	.byte	0
	.byte	0
	.zero	1
	.xword	.Lfilc_origin_get
	.xword	.Lfilc_origin_get
	.xword	0
	.size	.Lfilc_aco_get_1, 32

	.globl	pizlonatedFI2529_get
	.type	pizlonatedFI2529_get,@function
.set pizlonatedFI2529_get, pizlonatedFIP2529_get
	.section	".note.GNU-stack","",@progbits
