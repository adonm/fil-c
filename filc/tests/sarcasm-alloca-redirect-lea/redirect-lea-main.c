#include <stdio.h>
long foo(void);
int main() {
    // gcc -O0 idiom: `leaq 24(%rsp), %rax` re-derives a pointer into the region
    // [-120, 280) (== buffer+144). Storing 9 through it must be visible via the
    // annotated pointer at buffer+144, and vice versa: foo returns 9 + 5*8 = 49.
    printf("%ld\n", foo());
    return 0;
}
