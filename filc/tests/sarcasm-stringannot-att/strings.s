# String-literal awareness of annotation markers on x86_64: marker text inside
# double-quoted strings (`;!`, `#!`, and even arm64's `//!`) must never produce
# an annotation -- these directives are parsed as ordinary data. Sarcasm drops
# top-level data, so the driver prints copies of the same payloads.
	.text
	.globl	echo_first
	.type	echo_first, @function
echo_first:                     #! long(ptr)
	movq	(%rdi), %rax
	ret
	.size	echo_first, .-echo_first
	.section	.rodata
.Ls1:
	.asciz	"a ;! b"
.Ls2:
	.asciz	"a #! b"
.Ls3:
	.asciz	"a //! b"
.Ls4:
	.asciz	"x ;! y #! z"
.Ls5:
	.asciz	"p //! q ;! r"
.Ls6:
	.string	"with .string ;! here"
.Ls7:
	.asciz	"trailing marker ;!"
.Ls8:
	.asciz	"#! at start ;! in middle //! at end"
	.section	.note.GNU-stack,"",@progbits
