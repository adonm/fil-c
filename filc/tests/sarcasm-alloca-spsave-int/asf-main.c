#include <stdio.h>

extern void *asf(long n);

int main(void)
{
    unsigned char *p = asf(37);
    if (!p) {
        printf("null\n");
        return 1;
    }
    for (int i = 0; i < 37; i++) {
        if (p[i] != (unsigned char)i) {
            printf("mismatch %d: %d\n", i, p[i]);
            return 1;
        }
    }
    printf("ok\n");
    return 0;
}
