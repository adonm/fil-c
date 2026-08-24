#include <stdio.h>
long foo(void);
int main() {
    // gcc/clang -O0 idiom: the fixed buffer is addressed rbp-relative. The annotated
    // lea establishes the region [0, 400) (rsp-relative); the unannotated rbp-relative
    // lea re-derives the buffer address and must redirect to the allocation, so the
    // 55 stored through it reads back through the annotated pointer.
    printf("%ld\n", foo());
    return 0;
}
