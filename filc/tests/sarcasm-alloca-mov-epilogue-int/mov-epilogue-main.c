#include <stdio.h>
#include <stdlib.h>
void foo(int* x, size_t size);
int main() {
    // Dynamic alloca with clang -O0's VLA epilogue shape:
    // `movq %rbp, %rsp; popq %rbp; ret` instead of `leave; ret`.
    size_t n = 50;
    int* x = malloc(n * sizeof(int));
    for (size_t i = 0; i < n; i++) x[i] = (int)(i * 3 + 1);
    foo(x, n);                                  // copies x->buf->x (identity)
    int ok = 1;
    for (size_t i = 0; i < n; i++) if (x[i] != (int)(i * 3 + 1)) ok = 0;
    printf("%s\n", ok ? "ok" : "BAD");
    return 0;
}
