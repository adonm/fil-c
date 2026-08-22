	.file	"nullcap-spasm.s"
	.text
	.globl	pizlonated_deref_int
	.p2align	2
	.type	pizlonated_deref_int,@function
pizlonated_deref_int:
	adrp	x0, pizlonatedFO_deref_int+16
	add	x0, x0, :lo12:pizlonatedFO_deref_int+16
	mov	x1, x0
	ret
.Lfunc_end_getter_deref_int:
	.size	pizlonated_deref_int, .Lfunc_end_getter_deref_int-pizlonated_deref_int

	.globl	pizlonatedFIP135_deref_int
	.p2align	2
	.type	pizlonatedFIP135_deref_int,@function
pizlonatedFIP135_deref_int:
	sub	sp, sp, #32
	stp	x29, x30, [sp, #16]
	add	x29, sp, #16
	ldr	x9, [x0]
	cmp	sp, x9
	b.hs	.Lsovok_deref_int
	b	filc_stack_overflow_failure
.Lsovok_deref_int:
	ldr	x9, [x0, #16]
	mov	x8, sp
	adrp	x10, .Lfilc_origin_deref_int
	add	x10, x10, :lo12:.Lfilc_origin_deref_int
	stp	x9, x10, [sp, #0]
	str	x8, [x0, #16]
	mov	x3, x0
	mov	x2, x2
	cbz	xzr, .Lfail_deref_int_1
	ldr	w0, [x2]
	mov	x1, x0
	mov	w0, wzr
	ldr	x8, [sp, #0]
	str	x8, [x3, #16]
	ldp	x29, x30, [sp, #16]
	add	sp, sp, #32
	ret
.Lfail_deref_int_1:
	mov	x0, x2
	mov	x1, xzr
	adrp	x2, .Lfilc_aco_deref_int_1
	add	x2, x2, :lo12:.Lfilc_aco_deref_int_1
	bl	filc_optimized_access_check_fail
	.size	pizlonatedFIP135_deref_int, .-pizlonatedFIP135_deref_int

	.weak	pizlonated2ET135
	.p2align	2
	.type	pizlonated2ET135,@function
pizlonated2ET135:
	stp	x30, x19, [sp, #-16]!
	cmp	x2, #8
	b.lo	.LBB_2ET135_fail
	ldr	x2, [x0, #128]
	ldr	x3, [x0, #384]
	mov	x19, x0
	ldr	x8, [x1]
	blr	x8
	tbnz	w0, #0, .LBB_2ET135_exc
	str	x1, [x19, #128]
	mov	w1, #8
	str	xzr, [x19, #384]
.LBB_2ET135_ret:
	and	w0, w0, #0x1
	ldp	x30, x19, [sp], #16
	ret
.LBB_2ET135_exc:
	b	.LBB_2ET135_ret
.LBB_2ET135_fail:
	mov	x0, x2
	mov	w1, #8
	mov	x2, xzr
	bl	filc_cc_args_check_failure
	.size	pizlonated2ET135, .-pizlonated2ET135

	.type	pizlonatedFO_deref_int,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
pizlonatedFO_deref_int:
	.xword	pizlonatedFO_deref_int+16
	.xword	(pizlonatedFO_deref_int+16)+36873221949095936
	.xword	pizlonatedFIP135_deref_int
	.xword	pizlonated2ET135
	.xword	135
	.size	pizlonatedFO_deref_int, 40

	.type	.Lfilc_string_deref_int,@object
	.section	.rodata.str1.4,"aMS",@progbits,1
	.p2align	2, 0x0
.Lfilc_string_deref_int:
	.asciz	"deref_int"
	.size	.Lfilc_string_deref_int, 10

	.type	.Lfilc_function_origin_deref_int,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_function_origin_deref_int:
	.xword	.Lfilc_string_deref_int
	.xword	0
	.word	0
	.zero	4
	.xword	0
	.byte	0
	.byte	0
	.byte	0
	.zero	1
	.word	0
	.size	.Lfilc_function_origin_deref_int, 40

	.type	.Lfilc_origin_deref_int,@object
	.p2align	3, 0x0
.Lfilc_origin_deref_int:
	.xword	.Lfilc_function_origin_deref_int
	.word	0
	.word	0
	.size	.Lfilc_origin_deref_int, 16

	.type	.Lfilc_aco_deref_int_1,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_aco_deref_int_1:
	.word	4
	.byte	4
	.byte	0
	.byte	0
	.zero	1
	.xword	.Lfilc_origin_deref_int
	.xword	.Lfilc_origin_deref_int
	.xword	0
	.size	.Lfilc_aco_deref_int_1, 32

	.globl	pizlonatedFI135_deref_int
	.type	pizlonatedFI135_deref_int,@function
.set pizlonatedFI135_deref_int, pizlonatedFIP135_deref_int
	.section	".note.GNU-stack","",@progbits
