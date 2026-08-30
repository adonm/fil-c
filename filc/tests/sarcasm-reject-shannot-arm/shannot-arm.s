/* `#!` is NOT an annotation marker on arm64 (only `;!` and `//!` are): the
   text stays in the code part, so the function label ends up without a
   signature and the file is rejected. */
	.arch armv8-a
	.text
	.global	f
	.type	f, %function
f:	#! unsigned(ptr)
	ret
	.size	f, .-f
