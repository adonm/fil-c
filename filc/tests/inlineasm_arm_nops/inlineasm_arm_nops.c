#include <stdfil.h>

int main(void)
{
    asm volatile("nop");
    asm volatile("hint #0");
    asm volatile("bti c");
    asm volatile("bti j");
    asm volatile("bti jc");
    asm volatile("yield");
    asm volatile("sev");
    asm volatile("sevl");
    asm volatile("csdb");
    asm volatile("hint #8");

    /* Nops interleaved with real work. */
    unsigned long v = 1;
    asm volatile("nop\n\t"
                 "add %0, %0, #41\n\t"
                 "yield\n\t"
                 "nop"
                 : "+r"(v)
                 :
                 : );
    ZASSERT(v == 42);
    return 0;
}
