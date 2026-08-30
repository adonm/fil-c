#include <stdio.h>

unsigned char* zerobuf(void);

int main()
{
    unsigned char* p = zerobuf();
    if (!p) {
        printf("zero alloca returned null\n");
        return 1;
    }
    printf("setup ok\n");
    /* The allocation has zero writable bytes: this store must trap. */
    p[0] = 1;
    printf("SHOULD NOT PRINT\n");
    return 0;
}
