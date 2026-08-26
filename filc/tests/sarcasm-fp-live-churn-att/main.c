/* Live-across-call correctness under real clobber, at three widths at once:
   scalar double accumulators in xmm0/xmm1/xmm6 (8 bytes live), a 16-byte
   movdqu value in xmm2, and a 32-byte broadcast value in ymm4 — all live
   across an injected filc_allocate call (`;! alloca`) and across every loop
   pollcheck, while a helper thread hammers the GC so the slow paths run and
   the runtime's allocation/marking code really clobbers caller-saved vector
   state. The width-aware expansion must save exactly those five registers,
   each at its live width (movsd/movsd/movsd/movdqu/vmovdqu — verified via
   -S, see churn.s). The results are checked exactly. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdfil.h>
#include <filc_test_support.h>

long fp_churn(long n, long seed, char* buf);

#define ITERS 300000000L

static void* hammer(void* arg)
{
    int i;
    for (i = 0; i < 30; i++)
        zgc_request_and_wait();
    return NULL;
}

int main()
{
    char* buf = malloc(80);
    if (!buf)
        return 1;
    memset(buf, 0, 80);
    double* d0 = (double*)(buf + 0);
    double* d1 = (double*)(buf + 8);
    float* f0 = (float*)(buf + 16);
    *d0 = 11.5;
    *d1 = -2.25;
    *f0 = 3.5f;
    long iters = ITERS;
    if (zgc_is_stw())
        iters = ITERS / 100;
    pthread_t t;
    if (pthread_create(&t, NULL, hammer, NULL))
        return 1;
    long r = fp_churn(iters, 7, buf);
    if (pthread_join(t, NULL))
        return 1;
    /* acc0 = 7*iters, acc6 = 2*7*iters, sum = 3*7*iters */
    if (r != 21 * iters) {
        printf("churn BAD ret %ld != %ld\n", r, 21 * iters);
        return 1;
    }
    /* xmm2 (the movdqu pair) must have survived: copied through the alloca
       buffer to buf[32:48). */
    if (*(double*)(buf + 32) != 11.5 || *(double*)(buf + 40) != -2.25) {
        printf("churn BAD xmm2 %f %f\n", *(double*)(buf + 32), *(double*)(buf + 40));
        return 1;
    }
    /* ymm4 (the broadcast float) must have survived: stored to buf[48:80). */
    int i;
    for (i = 0; i < 8; i++) {
        if (*(float*)(buf + 48 + 4 * i) != 3.5f) {
            printf("churn BAD ymm4 lane%d %f\n", i, (double)*(float*)(buf + 48 + 4 * i));
            return 1;
        }
    }
    printf("fp churn ok\n");
    return 0;
}
