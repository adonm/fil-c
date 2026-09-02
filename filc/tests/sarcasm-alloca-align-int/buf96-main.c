#include <stdio.h>
#include <string.h>

extern void buf96(void *dst, const void *src);

int main(void)
{
    unsigned long src[8], dst[8];
    for (int i = 0; i < 8; i++) src[i] = 0x1000 + i;
    memset(dst, 0xEE, sizeof dst);
    buf96(dst, src);
    for (int i = 0; i < 4; i++) {
        if (dst[i] != src[i] + 1) { printf("mismatch scalar %d\n", i); return 1; }
    }
    for (int i = 4; i < 8; i++) {
        if (dst[i] != src[i]) { printf("mismatch vec %d\n", i); return 1; }
    }
    printf("ok\n");
    return 0;
}
