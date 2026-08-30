/* A control-flow path that reaches the end of the body without executing ret:
   the cbnz branches over the only ret, so control reaching .Lskip falls off the
   end of the emitted FIP body and into sarcasm's own next emission (executing
   through caller-garbage registers). Sarcasm cannot prove that safe, so the
   body must be rejected at compile time. */
	.text
	.globl	foo
	.type	foo, %function
foo:                            ;! long(long)
	mov	x0, x1
	cbnz	x0, .Lskip
	neg	x0, x0
	ret
.Lskip:
	.size	foo, .-foo
