#include <stdio.h>

extern long rsaz_like(long x);

int main(void)
{
    /* the sub writes x*3 to all 8 qwords of the caller's buffer:
       rsaz_like(7) = 8 * 21 = 168. */
    long r = rsaz_like(7);
    if (r != 168) {
        printf("FAIL: got %ld, want 168\n", r);
        return 1;
    }
    printf("localcall stk8 att ok\n");
    return 0;
}
