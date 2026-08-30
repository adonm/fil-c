#include <stdio.h>
#include <string.h>

unsigned long* mkbuf(void);

int main()
{
    unsigned long* p = mkbuf();
    if (p[0] != 0x4142434445464745UL || p[49] != 0x4142434445464745UL) {
        printf("escape pre = %lx %lx\n", p[0], p[49]);
        return 1;
    }
    /* Writes AFTER the asm function returned: the GC allocation is still
       alive and writable (the returned lower is rooted by the return path). */
    p[1] = 0x1122334455667788UL;
    p[48] = 0x99AABBCCDDEEFF00UL;
    memset(p + 2, 0x5A, 368);
    unsigned long s = 0;
    for (int i = 0; i < 50; ++i)
        s ^= p[i];
    /* p[0]^p[49] = 0, p[2..47] cancel, leaving p[1]^p[48]. */
    if (s != 0x8888888888888888UL) {
        printf("escape xor = %lx\n", s);
        return 1;
    }
    printf("alloca escape ok\n");
    return 0;
}
