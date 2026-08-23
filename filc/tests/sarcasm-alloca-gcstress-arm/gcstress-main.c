/* GC stress for the sarcasm-assembled alloca test: foo's alloca lowers to filc_allocate
   (a GC safepoint) and the result's lower is rooted right after that call. If sarcasm
   leaves the root slot uninitialized, the GC may observe stack garbage as a capability
   at the filc_allocate safepoint and die. Run many threads with allocation churn and
   stack-shape variety so allocation + scanning never stops. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdfil.h>
#include <filc_test_support.h>
#include "utils.h"

#define ASSERT(exp) do { \
    if ((exp)) \
        break; \
    fprintf(stderr, "%s:%d: %s: assertion %s failed.\n", \
            __FILE__, __LINE__, __PRETTY_FUNCTION__, #exp); \
    abort(); \
} while (0)

void foo(int* x, size_t size);

#define N 50

static size_t num_threads = 10;
static size_t repeat = 1000000;

/* Same idea as in sarcasm-t3valid-gcstress: leave wild-integer spill values where foo's
   frame (and its GC root slots) will land. */
static volatile unsigned long junk_source = 0xdeadbeef12345678UL;

__attribute__((noinline)) static unsigned long dirty_stack(void)
{
    unsigned long a0 = junk_source, a1 = junk_source + 1, a2 = junk_source + 2;
    unsigned long a3 = junk_source + 3, a4 = junk_source + 4, a5 = junk_source + 5;
    unsigned long a6 = junk_source + 6, a7 = junk_source + 7, a8 = junk_source + 8;
    unsigned long a9 = junk_source + 9, a10 = junk_source + 10, a11 = junk_source + 11;
    unsigned long a12 = junk_source + 12, a13 = junk_source + 13, a14 = junk_source + 14;
    unsigned long a15 = junk_source + 15, a16 = junk_source + 16, a17 = junk_source + 17;
    unsigned long a18 = junk_source + 18, a19 = junk_source + 19, a20 = junk_source + 20;
    unsigned long a21 = junk_source + 21, a22 = junk_source + 22, a23 = junk_source + 23;
    unsigned long a24 = junk_source + 24, a25 = junk_source + 25, a26 = junk_source + 26;
    unsigned long a27 = junk_source + 27, a28 = junk_source + 28, a29 = junk_source + 29;
    unsigned long a30 = junk_source + 30, a31 = junk_source + 31;
    opaque(NULL);
    return a0 ^ a1 ^ a2 ^ a3 ^ a4 ^ a5 ^ a6 ^ a7 ^ a8 ^ a9 ^ a10 ^ a11
        ^ a12 ^ a13 ^ a14 ^ a15 ^ a16 ^ a17 ^ a18 ^ a19 ^ a20 ^ a21 ^ a22 ^ a23
        ^ a24 ^ a25 ^ a26 ^ a27 ^ a28 ^ a29 ^ a30 ^ a31;
}

static void* worker(void* arg)
{
    int* x = malloc(N * sizeof(int));
    ASSERT(x);
    unsigned long sink = 0;
    size_t i, j;
    for (i = 0; i < repeat; i++) {
        for (j = 0; j < N; j++)
            x[j] = (int)(j * 3 + i);
        sink ^= dirty_stack();
        foo(x, N);   /* copies x->buf->x (identity) via a GC allocation */
        for (j = 0; j < N; j++)
            ASSERT(x[j] == (int)(j * 3 + i));
    }
    free(x);
    return (void*)sink;
}

int main()
{
    if (zgc_is_stw()) {
        num_threads = 2;
        repeat = 1000;
    }
    pthread_t th[num_threads];
    size_t i;
    for (i = 0; i < num_threads; i++)
        ASSERT(!pthread_create(&th[i], NULL, worker, NULL));
    for (i = 0; i < num_threads; i++)
        ASSERT(!pthread_join(th[i], NULL));
    printf("ok\n");
    return 0;
}
