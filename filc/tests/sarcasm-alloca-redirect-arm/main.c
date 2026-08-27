#include <stdio.h>

long foo1(void);
long foo2(void);

int main() {

    // foo1: gcc -O0 idiom with a frame pointer — `add x10, sp, #24` re-derives a
    // pointer into the x29-derived alloca region [16, 416) (== buffer+8).
    // Storing 9 through it must be visible via the annotated pointer at
    // buffer+8, and vice versa: foo1 returns 9 + 5*8 = 49.
    //
    // foo2: the mirror image — `add x10, x29, #24` re-derives a pointer into
    // the sp-derived alloca region [16, 416) (== buffer+8): foo2 returns
    // 7 + 3*8 = 31.
    printf("%ld\n%ld\n", foo1(), foo2());
    return 0;
}
