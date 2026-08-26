/* Width-aware xmm save/restore around injected runtime calls: movsd_live
   keeps two 8-byte values in xmm0/xmm1 live across an injected filc_allocate
   call (`;! alloca`) and across ~5e8 loop-back-edge pollchecks while a
   helper thread hammers zgc_request_and_wait() so the pollcheck slow path
   (filc_pollcheck_slow) runs repeatedly. The old unconditional mechanism
   saved all of xmm0-15 at the function's widest vector width; the
   width-aware expansion must emit exactly one movsd store/load per live
   register at these sites (verified via -S, see movsd.s). Behaviorally, if
   either runtime call clobbers the low 8 bytes of either register, the sum
   comes back wrong. */
#include <stdio.h>
#include <pthread.h>
#include <stdfil.h>
#include <filc_test_support.h>

long movsd_live(long n, long seed);

#define ITERS 500000000L

static void* hammer(void* arg)
{
    int i;
    for (i = 0; i < 30; i++)
        zgc_request_and_wait();
    return NULL;
}

int main()
{
    long iters = ITERS;
    if (zgc_is_stw())
        iters = ITERS / 100;
    pthread_t t;
    if (pthread_create(&t, NULL, hammer, NULL))
        return 1;
    long r = movsd_live(iters, 3);
    if (pthread_join(t, NULL))
        return 1;
    if (r != 3 * (iters + 1)) {
        printf("movsd live BAD %ld != %ld\n", r, 3 * (iters + 1));
        return 1;
    }
    printf("movsd live ok\n");
    return 0;
}
