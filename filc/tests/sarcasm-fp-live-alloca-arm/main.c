/* f_alloca_live(a, b) keeps q0 = {a, b} and s2 = 2.0f*a live across a
   filc_allocate (the annotated alloca), then returns a + b + b + 2*a:
   (3,12) -> 33, (10,20) -> 70. Called under allocation churn so the
   filc_allocate safepoint runs GC code that would clobber unsaved vector
   state. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdfil.h>
#include <filc_test_support.h>

#define ASSERT(exp) do { \
    if ((exp)) \
        break; \
    fprintf(stderr, "%s:%d: %s: assertion %s failed.\n", \
            __FILE__, __LINE__, __PRETTY_FUNCTION__, #exp); \
    abort(); \
} while (0)

long f_alloca_live(long a, long b);

int main()
{
    size_t i, repeat = 30000;
    if (zgc_is_stw())
        repeat = 1000;
    for (i = 0; i < repeat; i++) {
        void* junk = malloc(64);
        memset(junk, 1, 64);
        free(junk);
        ASSERT(f_alloca_live(3, 12) == 33);
        ASSERT(f_alloca_live(10, 20) == 70);
    }
    printf("alloca 33 70\n");
    return 0;
}
