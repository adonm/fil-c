/* Intel-syntax twin of sarcasm-fp-live-churn-att (see its main.c for the
   full story): scalar double accumulators in xmm0/xmm1/xmm6 (8 bytes live),
   a 16-byte movdqu value in xmm2, and a 32-byte broadcast value in ymm4 —
   all live across an injected filc_allocate call and every loop pollcheck
   under GC churn. The width-aware expansion must save exactly those five
   registers, each at its live width (-S verified, see churn-int.s). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdfil.h>
#include <filc_test_support.h>

long fp_churn_int(long n, long seed, char* buf);

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
    long r = fp_churn_int(iters, 7, buf);
    if (pthread_join(t, NULL))
        return 1;
    if (r != 21 * iters) {
        printf("churn int BAD ret %ld != %ld\n", r, 21 * iters);
        return 1;
    }
    if (*(double*)(buf + 32) != 11.5 || *(double*)(buf + 40) != -2.25) {
        printf("churn int BAD xmm2 %f %f\n", *(double*)(buf + 32), *(double*)(buf + 40));
        return 1;
    }
    int i;
    for (i = 0; i < 8; i++) {
        if (*(float*)(buf + 48 + 4 * i) != 3.5f) {
            printf("churn int BAD ymm4 lane%d %f\n", i, (double)*(float*)(buf + 48 + 4 * i));
            return 1;
        }
    }
    printf("fp churn int ok\n");
    return 0;
}
