#include <stdio.h>

extern void dynoob_like(long n);

int main(void)
{
    /* n=0: region size = 16, but the body accesses region offset 24 — past
       the dynamic allocation. The checked region access traps. */
    dynoob_like(0);
    printf("FAIL: returned without trapping\n");
    return 1;
}
