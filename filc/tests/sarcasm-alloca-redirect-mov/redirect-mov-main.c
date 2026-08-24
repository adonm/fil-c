#include <stdio.h>
long foo(void);
int main() {
    // The region is based at rsp+0, so an unannotated `movq %rsp, %rax` re-derives
    // the buffer base: the 33 stored through it must read back via the annotated
    // pointer at the same offset.
    printf("%ld\n", foo());
    return 0;
}
