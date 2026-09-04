#include <stdio.h>
extern long clone_anchored_lea(long *xp);
int main(void) {
    long x = 424242;
    long r = clone_anchored_lea(&x);
    if (r != 424242) { printf("FAIL: got %ld want 424242\n", r); return 1; }
    printf("clone anchored lea ok\n");
    return 0;
}
