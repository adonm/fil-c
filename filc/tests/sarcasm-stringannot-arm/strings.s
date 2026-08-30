/* String-literal awareness of annotation markers on arm64: marker text inside
   double-quoted strings (`//!`, `;!`, and even x86_64's `#!`) must never
   produce an annotation -- these directives are parsed as ordinary data.
   Sarcasm drops top-level data, so the driver prints copies of the payloads. */
	.arch armv8-a
	.text
	.global	echo_first
	.type	echo_first, %function
echo_first:                     //! long(ptr)
	ldr	x0, [x0]
	ret
	.size	echo_first, .-echo_first
	.section	.rodata
.Ls1:
	.asciz	"a //! b"
.Ls2:
	.asciz	"a ;! b"
.Ls3:
	.asciz	"a #! b"
.Ls4:
	.asciz	"x //! y ;! z"
.Ls5:
	.string	"trailing marker ;!"
.Ls6:
	.asciz	"//! at start ;! in middle #! at end"
	.section	.note.GNU-stack,"",@progbits
