/* xmm3 is live at exactly 4 bytes (movss/addss) across the injected
   filc_allocate call (`;! alloca result size=32`): the width-aware
   save/restore must be a single movss store/load at slot 3 (verified via
   -S, see movss.s). The C side round-trips the float bit pattern under FUGC
   churn so the runtime call's allocation paths actually run and could
   clobber caller-saved xmm state. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdfil.h>
#include <filc_test_support.h>

long movss_live(float* in);

int main()
{
    float* in = malloc(sizeof(float));
    if (!in)
        return 1;
    *in = 1.5f;
    unsigned expect = 0x40400000u;  /* 3.0f == 1.5f + 1.5f */
    size_t i, repeat = 100000;
    if (zgc_is_stw())
        repeat = 10000;
    for (i = 0; i < repeat; i++) {
        void* junk = malloc(64);
        memset(junk, 1, 64);
        free(junk);
        unsigned got = (unsigned)movss_live(in);
        if (got != expect) {
            printf("movss live BAD 0x%x != 0x%x\n", got, expect);
            return 1;
        }
    }
    printf("movss live ok\n");
    return 0;
}
