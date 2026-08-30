#include <stdio.h>

unsigned char* hugebuf(void);

int main()
{
    unsigned char* p = hugebuf();
    if (!p) {
        printf("huge alloca returned null\n");
        return 1;
    }
    if (p[0] != 17 || ((unsigned long*)p)[137438953471UL] != 34) {
        printf("huge bad: %d %lu\n", p[0],
               ((unsigned long*)p)[137438953471UL]);
        return 1;
    }
    printf("huge ok\n");
    return 0;
}
