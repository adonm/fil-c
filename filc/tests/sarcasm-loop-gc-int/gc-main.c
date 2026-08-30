#include <stdio.h>

/* Gap-(b)(ii) probe main: the counter countdown must survive GC churn in its
   body - the churn loop's back-edge pollcheck is not the counter's own, and
   the injected filc_allocate call clobbers rcx. Pre-fix the countdown never
   terminated; post-fix it must match hardware exactly (1000 iterations). */
long loopgc_count(long *);

int main()
{
    long r = loopgc_count(0);
    if (r != 1000) { printf("bad loopgc count %ld\n", r); return 1; }
    printf("loop gc int ok\n");
    return 0;
}
