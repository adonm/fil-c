/* A constant initializer with a pointer at a misaligned offset (packed struct)
   used to hit an assertion in the pizlonator's computeConstantRelocations. It
   must be lowered like any other store: the pizlonator has to fall back to
   storing the initializer at run time instead of asserting.  This test
   exercises that compile-time lowering.  We deliberately never touch `g` or
   `g2` at run time: a pointer at a misaligned offset has no capability slot,
   so the pizlonator thwarts dereferencing it, and even forming `&g` would run
   the getter, which stores the pointer's capability at a misaligned offset in
   the aux, which the garbage collector cannot scan. */

#include <stdfil.h>
#include <stdio.h>

struct big {
    long x;
};

struct __attribute__((packed)) packedptr {
    char c;
    struct big* p;
};

struct big target;

struct packedptr g = { 7, &target };
struct packedptr g2 = { 9, 0 };

int main(void)
{
    zgc_request_and_wait();
    printf("misaligned const ptr ok\n");
    return 0;
}
