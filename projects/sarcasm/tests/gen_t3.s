	.file	"test3-spasm.s"
	.text
	.globl	pizlonated_hash
	.p2align	2
	.type	pizlonated_hash,@function
pizlonated_hash:
	adrp	x0, pizlonatedFO_hash+16
	add	x0, x0, :lo12:pizlonatedFO_hash+16
	mov	x1, x0
	ret
.Lfunc_end_getter_hash:
	.size	pizlonated_hash, .Lfunc_end_getter_hash-pizlonated_hash

	.globl	pizlonatedFIP1066_hash
	.p2align	2
	.type	pizlonatedFIP1066_hash,@function
pizlonatedFIP1066_hash:
	sub	sp, sp, #128
	stp	x29, x30, [sp, #112]
	stp	x19, x20, [sp, #96]
	stp	x21, x22, [sp, #80]
	stp	x23, x24, [sp, #64]
	stp	x25, x26, [sp, #48]
	str	x27, [sp, #32]
	add	x29, sp, #112
	ldr	x9, [x0]
	cmp	sp, x9
	b.hs	.Lsovok_hash
	b	filc_stack_overflow_failure
.Lsovok_hash:
	ldr	x9, [x0, #16]
	mov	x8, sp
	adrp	x10, .Lfilc_origin_hash
	add	x10, x10, :lo12:.Lfilc_origin_hash
	stp	x9, x10, [sp, #0]
	str	x8, [x0, #16]
	mov	x19, x0
	mov	x2, x2
	mov	x24, x3
	str	x24, [sp, #16]
	mov	x20, x0
	mov	x26, x2
	add	x1, x2, #8
	cbz	x24, .Lfail_hash_1
	cmp	x1, x24
	b.lo	.Lfail_hash_1
	ldur	x3, [x24, #-16]
	add	x4, x1, #8
	cmp	x4, x3
	b.hi	.Lfail_hash_1
	tst	x1, #7
	b.ne	.Lfail_hash_1
	ldr	x1, [x2, #8]
	mov	x23, x0
	mov	x21, x0
	cbz	x1, .L4
	mov	x25, #0
	mov	x22, #5381
.L3:
	ldrb	w0, [x19, #8]
	tst	w0, #14
	b.eq	.Lpollok_hash_1
	mov	x0, x19
	adrp	x1, .Lfilc_origin_hash
	add	x1, x1, :lo12:.Lfilc_origin_hash
	bl	filc_pollcheck_slow
.Lpollok_hash_1:
	cbz	x24, .Lfail_hash_2
	cmp	x26, x24
	b.lo	.Lfail_hash_2
	ldur	x0, [x24, #-16]
	add	x1, x26, #8
	cmp	x1, x0
	b.hi	.Lfail_hash_2
	tst	x26, #7
	b.ne	.Lfail_hash_2
	sub	x0, x26, x24
	ldur	x1, [x24, #-8]
	and	x1, x1, #0xffffffffffff
	cbz	x1, .Lnulllo_hash_1
	ldr	x1, [x1, x0]
	tbz	x1, #0, .Ldirlo_hash_1
	and	x0, x1, #0xfffffffffffffffe
	ldr	x1, [x0, #8]
	b	.Lhavelo_hash_1
.Ldirlo_hash_1:
	mov	x1, x1
	b	.Lhavelo_hash_1
.Lnulllo_hash_1:
	mov	x1, xzr
.Lhavelo_hash_1:
	ldr	x2, [x26, #0]
	str	x1, [sp, #24]
	mov	x4, x25
	add	x22, x22, x22, lsl 5
	add	x25, x25, #1
	mov	x0, x19
	mov	x2, x2
	mov	x3, x1
	mov	x4, x4
	bl	pizlonatedFI2529_foo
	tbnz	w0, #0, .Lexc_hash
	mov	x0, x1
	add	x22, x22, w0, sxtw
	add	x27, x26, #8
	cbz	x24, .Lfail_hash_3
	cmp	x27, x24
	b.lo	.Lfail_hash_3
	ldur	x0, [x24, #-16]
	add	x1, x27, #8
	cmp	x1, x0
	b.hi	.Lfail_hash_3
	tst	x27, #7
	b.ne	.Lfail_hash_3
	ldr	x0, [x26, #8]
	cmp	x0, x25
	bhi	.L3
	mov	x0, x20
	mov	x0, x22
	mov	x1, x23
	mov	x1, x21
	mov	x1, x0
	mov	w0, wzr
	ldr	x8, [sp, #0]
	str	x8, [x19, #16]
	ldp	x29, x30, [sp, #112]
	ldp	x19, x20, [sp, #96]
	ldp	x21, x22, [sp, #80]
	ldp	x23, x24, [sp, #64]
	ldp	x25, x26, [sp, #48]
	ldr	x27, [sp, #32]
	add	sp, sp, #128
	ret
.L4:
	mov	x0, #5381
	mov	x0, x0
	mov	x1, x23
	mov	x1, x21
	mov	x1, x20
	mov	x1, x0
	mov	w0, wzr
	ldr	x8, [sp, #0]
	str	x8, [x19, #16]
	ldp	x29, x30, [sp, #112]
	ldp	x19, x20, [sp, #96]
	ldp	x21, x22, [sp, #80]
	ldp	x23, x24, [sp, #64]
	ldp	x25, x26, [sp, #48]
	ldr	x27, [sp, #32]
	add	sp, sp, #128
	ret
.Lexc_hash:
	ldr	x8, [sp, #0]
	str	x8, [x19, #16]
	ldp	x29, x30, [sp, #112]
	ldp	x19, x20, [sp, #96]
	ldp	x21, x22, [sp, #80]
	ldp	x23, x24, [sp, #64]
	ldp	x25, x26, [sp, #48]
	ldr	x27, [sp, #32]
	add	sp, sp, #128
	ret
.Lfail_hash_1:
	mov	x0, x1
	mov	x1, x24
	adrp	x2, .Lfilc_aco_hash_1
	add	x2, x2, :lo12:.Lfilc_aco_hash_1
	bl	filc_optimized_access_check_fail
.Lfail_hash_2:
	mov	x0, x26
	mov	x1, x24
	adrp	x2, .Lfilc_aco_hash_2
	add	x2, x2, :lo12:.Lfilc_aco_hash_2
	bl	filc_optimized_access_check_fail
.Lfail_hash_3:
	mov	x0, x27
	mov	x1, x24
	adrp	x2, .Lfilc_aco_hash_3
	add	x2, x2, :lo12:.Lfilc_aco_hash_3
	bl	filc_optimized_access_check_fail
	.size	pizlonatedFIP1066_hash, .-pizlonatedFIP1066_hash

	.weak	pizlonated2ET1066
	.p2align	2
	.type	pizlonated2ET1066,@function
pizlonated2ET1066:
	stp	x30, x19, [sp, #-16]!
	cmp	x2, #8
	b.lo	.LBB_2ET1066_fail
	ldr	x2, [x0, #128]
	ldr	x3, [x0, #384]
	mov	x19, x0
	ldr	x8, [x1]
	blr	x8
	tbnz	w0, #0, .LBB_2ET1066_exc
	str	x1, [x19, #128]
	mov	w1, #8
	str	xzr, [x19, #384]
.LBB_2ET1066_ret:
	and	w0, w0, #0x1
	ldp	x30, x19, [sp], #16
	ret
.LBB_2ET1066_exc:
	b	.LBB_2ET1066_ret
.LBB_2ET1066_fail:
	mov	x0, x2
	mov	w1, #8
	mov	x2, xzr
	bl	filc_cc_args_check_failure
	.size	pizlonated2ET1066, .-pizlonated2ET1066

	.type	pizlonatedFO_hash,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
pizlonatedFO_hash:
	.xword	pizlonatedFO_hash+16
	.xword	(pizlonatedFO_hash+16)+36873221949095936
	.xword	pizlonatedFIP1066_hash
	.xword	pizlonated2ET1066
	.xword	1066
	.size	pizlonatedFO_hash, 40

	.type	.Lfilc_string_hash,@object
	.section	.rodata.str1.4,"aMS",@progbits,1
	.p2align	2, 0x0
.Lfilc_string_hash:
	.asciz	"hash"
	.size	.Lfilc_string_hash, 5

	.type	.Lfilc_function_origin_hash,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_function_origin_hash:
	.xword	.Lfilc_string_hash
	.xword	0
	.word	2
	.zero	4
	.xword	0
	.byte	0
	.byte	0
	.byte	0
	.zero	1
	.word	0
	.size	.Lfilc_function_origin_hash, 40

	.type	.Lfilc_origin_hash,@object
	.p2align	3, 0x0
.Lfilc_origin_hash:
	.xword	.Lfilc_function_origin_hash
	.word	0
	.word	0
	.size	.Lfilc_origin_hash, 16

	.type	.Lfilc_aco_hash_1,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_aco_hash_1:
	.word	8
	.byte	8
	.byte	0
	.byte	0
	.zero	1
	.xword	.Lfilc_origin_hash
	.xword	.Lfilc_origin_hash
	.xword	0
	.size	.Lfilc_aco_hash_1, 32

	.type	.Lfilc_aco_hash_2,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_aco_hash_2:
	.word	8
	.byte	8
	.byte	0
	.byte	0
	.zero	1
	.xword	.Lfilc_origin_hash
	.xword	.Lfilc_origin_hash
	.xword	0
	.size	.Lfilc_aco_hash_2, 32

	.type	.Lfilc_aco_hash_3,@object
	.section	.data.rel.ro,"aw",@progbits
	.p2align	4, 0x0
.Lfilc_aco_hash_3:
	.word	8
	.byte	8
	.byte	0
	.byte	0
	.zero	1
	.xword	.Lfilc_origin_hash
	.xword	.Lfilc_origin_hash
	.xword	0
	.size	.Lfilc_aco_hash_3, 32

	.globl	pizlonatedFI1066_hash
	.type	pizlonatedFI1066_hash,@function
.set pizlonatedFI1066_hash, pizlonatedFIP1066_hash
	.text
	.weak	pizlonatedFI2529_foo
	.hidden	pizlonatedFI2529_foo
	.p2align	2
	.type	pizlonatedFI2529_foo,@function
pizlonatedFI2529_foo:
	sub	sp, sp, #48
	str	x30, [sp, #0]
	str	x19, [sp, #8]
	str	x20, [sp, #16]
	str	x21, [sp, #24]
	str	x22, [sp, #32]
	mov	x19, x0
	mov	x20, x2
	mov	x21, x3
	mov	x22, x4
	bl	pizlonated_foo
	cbz	x1, .Lcsr_foo_2529_fail
	ldur	x8, [x1, #-8]
	mov	x10, #36028797018963968
	and	x9, x8, #0x780000000000000
	cmp	x9, x10
	b.ne	.Lcsr_foo_2529_fail
	and	x8, x8, #0xffffffffffff
	cmp	x0, x8
	b.ne	.Lcsr_foo_2529_fail
	ldr	x8, [x1, #16]
	cmp	x8, #2529
	b.ne	.Lcsr_foo_2529_generic
	mov	x0, x19
	mov	x2, x20
	mov	x3, x21
	mov	x4, x22
	ldr	x19, [sp, #8]
	ldr	x20, [sp, #16]
	ldr	x21, [sp, #24]
	ldr	x22, [sp, #32]
	ldr	x5, [x1]
	ldr	x30, [sp, #0]
	add	sp, sp, #48
	br	x5
.Lcsr_foo_2529_generic:
	str	x20, [x19, #128]
	str	x21, [x19, #384]
	str	x22, [x19, #136]
	str	xzr, [x19, #392]
	mov	x0, x19
	mov	w2, #16
	ldr	x8, [x1, #8]
	blr	x8
	tbnz	w0, #0, .Lcsr_foo_2529_exc
	cmp	x1, #8
	b.lo	.Lcsr_foo_2529_retfail
	ldr	x1, [x19, #128]
.Lcsr_foo_2529_done:
	ldr	x19, [sp, #8]
	ldr	x20, [sp, #16]
	ldr	x21, [sp, #24]
	ldr	x22, [sp, #32]
	and	w0, w0, #0x1
	ldr	x30, [sp, #0]
	add	sp, sp, #48
	ret
.Lcsr_foo_2529_exc:
	b	.Lcsr_foo_2529_done
.Lcsr_foo_2529_fail:
	bl	filc_check_function_call_fail
.Lcsr_foo_2529_retfail:
	mov	x0, x1
	mov	w1, #8
	mov	x2, xzr
	bl	filc_cc_rets_check_failure
	.size	pizlonatedFI2529_foo, .-pizlonatedFI2529_foo

	.section	".note.GNU-stack","",@progbits
