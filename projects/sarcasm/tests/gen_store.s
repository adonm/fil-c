	.file	"store-spasm.s"
	.text
	.globl	pizlonated_store_ptr
	.p2align	2
	.type	pizlonated_store_ptr,@function
pizlonated_store_ptr:
	adrp	x0, pizlonatedFO_store_ptr+16
	add	x0, x0, :lo12:pizlonatedFO_store_ptr+16
	mov	x1, x0
	ret
.Lfunc_end_getter_store_ptr:
	.size	pizlonated_store_ptr, .Lfunc_end_getter_store_ptr-pizlonated_store_ptr

	.globl	pizlonatedFIP12769_store_ptr
	.p2align	2
	.type	pizlonatedFIP12769_store_ptr,@function
pizlonatedFIP12769_store_ptr:
	sub	sp, sp, #96
	stp	x29, x30, [sp, #80]
	stp	x19, x20, [sp, #64]
	stp	x21, x22, [sp, #48]
	stp	x23, x24, [sp, #32]
	add	x29, sp, #80
	ldr	x9, [x0]
	cmp	sp, x9
	b.hs	.Lsovok_store_ptr
	b	filc_stack_overflow_failure
.Lsovok_store_ptr:
	ldr	x9, [x0, #16]
	mov	x8, sp
	adrp	x10, .Lfilc_origin_store_ptr
	add	x10, x10, :lo12:.Lfilc_origin_store_ptr
	stp	x9, x10, [sp, #0]
	str	x8, [x0, #16]
	mov	x22, x0
	mov	x21, x2
	mov	x3, x3
	str	x3, [sp, #16]
	mov	x20, x4
	mov	x19, x5
	str	x19, [sp, #24]
	cbz	x3, .Lfail_store_ptr_1
	tst	x21, #7
	b.ne	.Lfail_store_ptr_1
	cmp	x21, x3
	b.lo	.Lfail_store_ptr_1
	ldur	x0, [x3, #-8]
	tst	x0, #0x6000000000000
	b.ne	.Lfail_store_ptr_1
	ldur	x1, [x3, #-16]
	add	x2, x21, #8
	cmp	x2, x1
	b.hi	.Lfail_store_ptr_1
	sub	x24, x21, x3
	and	x23, x0, #0xffffffffffff
	cbz	x23, .Lneedaux_store_ptr_st_1
.Lbarrier_store_ptr_st_1:
	adrp	x0, :got:filc_current_marking_state
	ldr	x0, [x0, :got_lo12:filc_current_marking_state]
	ldr	w0, [x0, #0]
	cbnz	w0, .Ldobar_store_ptr_st_1
.Lstore_store_ptr_st_1:
	str	x19, [x23, x24]
	str	x20, [x21, #0]
	b	.Ldone_store_ptr_st_1
.Lneedaux_store_ptr_st_1:
	sub	x1, x3, #16
	mov	x0, x22
	mov	x1, x1
	bl	filc_object_ensure_aux_ptr_outline
	mov	x23, x0
	b	.Lbarrier_store_ptr_st_1
.Ldobar_store_ptr_st_1:
	mov	x0, x22
	mov	x1, x19
	bl	filc_store_barrier_for_lower_slow
	b	.Lstore_store_ptr_st_1
.Ldone_store_ptr_st_1:
	mov	w0, wzr
	ldr	x8, [sp, #0]
	str	x8, [x22, #16]
	ldp	x29, x30, [sp, #80]
	ldp	x19, x20, [sp, #64]
	ldp	x21, x22, [sp, #48]
	ldp	x23, x24, [sp, #32]
	add	sp, sp, #96
	ret
.Lfail_store_ptr_1:
	mov	x0, x21
	mov	x1, x3
	adrp	x2, .Lfilc_aco_store_ptr_1
	add	x2, x2, :lo12:.Lfilc_aco_store_ptr_1
	bl	filc_optimized_access_check_fail
	.size	pizlonatedFIP12769_store_ptr, .-pizlonatedFIP12769_store_ptr

	.weak	pizlonated2ET12769
	.p2align	2
	.type	pizlonated2ET12769,@function
pizlonated2ET12769:
	stp	x30, x19, [sp, #-16]!
	cmp	x2, #16
	b.lo	.LBB_2ET12769_fail
	ldr	x2, [x0, #128]
	ldr	x3, [x0, #384]
	ldr	x4, [x0, #136]
	ldr	x5, [x0, #392]
	mov	x19, x0
	ldr	x8, [x1]
	blr	x8
	tbnz	w0, #0, .LBB_2ET12769_exc
	mov	w1, #0
.LBB_2ET12769_ret:
	and	w0, w0, #0x1
	ldp	x30, x19, [sp], #16
	ret
.LBB_2ET12769_exc:
	b	.LBB_2ET12769_ret
.LBB_2ET12769_fail:
	mov	x0, x2
	mov	w1, #16
	mov	x2, xzr
	bl	filc_cc_args_check_failure
	.size	pizlonated2ET12769, .-pizlonated2ET12769

	.type	pizlonatedFO_store_ptr,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
pizlonatedFO_store_ptr:
	.xword	pizlonatedFO_store_ptr+16
	.xword	(pizlonatedFO_store_ptr+16)+36873221949095936
	.xword	pizlonatedFIP12769_store_ptr
	.xword	pizlonated2ET12769
	.xword	12769
	.size	pizlonatedFO_store_ptr, 40

	.type	.Lfilc_string_store_ptr,@object
	.section	.rodata.str1.4,"aMS",@progbits,1
	.p2align	2, 0x0
.Lfilc_string_store_ptr:
	.asciz	"store_ptr"
	.size	.Lfilc_string_store_ptr, 10

	.type	.Lfilc_function_origin_store_ptr,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_function_origin_store_ptr:
	.xword	.Lfilc_string_store_ptr
	.xword	0
	.word	2
	.zero	4
	.xword	0
	.byte	0
	.byte	0
	.byte	0
	.zero	1
	.word	0
	.size	.Lfilc_function_origin_store_ptr, 40

	.type	.Lfilc_origin_store_ptr,@object
	.p2align	3, 0x0
.Lfilc_origin_store_ptr:
	.xword	.Lfilc_function_origin_store_ptr
	.word	0
	.word	0
	.size	.Lfilc_origin_store_ptr, 16

	.type	.Lfilc_aco_store_ptr_1,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_aco_store_ptr_1:
	.word	8
	.byte	8
	.byte	0
	.byte	1
	.zero	1
	.xword	.Lfilc_origin_store_ptr
	.xword	.Lfilc_origin_store_ptr
	.xword	0
	.size	.Lfilc_aco_store_ptr_1, 32

	.globl	pizlonatedFI12769_store_ptr
	.type	pizlonatedFI12769_store_ptr,@function
.set pizlonatedFI12769_store_ptr, pizlonatedFIP12769_store_ptr
	.section	".note.GNU-stack","",@progbits
