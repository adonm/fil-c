#include <stdio.h>
long foo(void);
int main() {
    // `movq %rsp, %rax` re-derives rsp+0, which is offset 120 inside the region
    // [-120, 280): the redirect must yield buffer+120 (holding 77), not buffer+0.
    printf("%ld\n", foo());
    return 0;
}
