#include <stdio.h>
extern void oob(void *src);
extern long oob_index(void *src, long i);
int main(void) {
    unsigned long src[16];
    for (int i = 0; i < 16; i++) src[i] = 0x1000 + i;
    printf("expect trap:\n");
    oob_index(src, -8);     /* 8 bytes below the region's lower bound */
    printf("SHOULD NOT PRINT\n");
    return 0;
}
