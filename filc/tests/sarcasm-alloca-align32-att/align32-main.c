#include <stdio.h>
#include <string.h>

extern void align32(void *buf);

int main(void)
{
    unsigned long buf[8];
    for (int i = 0; i < 8; i++) buf[i] = 0xAAAAAAAAAAAAAAAAUL + i;
    unsigned long x[8];
    memcpy(x, buf, sizeof x);
    align32(buf);
    /* buf[0..3] = x[0..3] ^ x[4..7] */
    for (int i = 0; i < 4; i++) {
        if (buf[i] != (x[i] ^ x[i + 4])) { printf("mismatch %d\n", i); return 1; }
    }
    printf("ok\n");
    return 0;
}
