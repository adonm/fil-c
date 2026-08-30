# A .globl with a COMMA-SEPARATED name list must register EVERY name in the
# top-level content scan: the single-name regex silently dropped the later
# names, so mydata escaped the "label outside any function" rejection and
# vanished from the object (cross-TU references then failed at link time with
# the opaque "undefined reference to pizlonated_mydata"). The same file with one
# name per .globl directive was always cleanly rejected; the comma-list form now
# rejects identically.
	.text
	.globl	myfunc, mydata
	.type	myfunc, @function
myfunc:                         ;! long()
	endbr64
	movl	$42, %eax
	ret
	.size	myfunc, .-myfunc
	.data
mydata:	.quad	12345
	.section	.note.GNU-stack,"",@progbits
