#include <stdio.h>

extern void *work(void);
extern void *work2(void);

static int check(unsigned char *p, int n)
{
    for (int i = 0; i < n; i++) {
        if (p[i] != (unsigned char)i) {
            printf("mismatch %d: %d\n", i, p[i]);
            return 0;
        }
    }
    return 1;
}

int main(void)
{
    unsigned char *p = work();
    if (!p) {
        printf("null\n");
        return 1;
    }
    if (!check(p, 666))
        return 1;
    unsigned char *q = work2();
    if (!q) {
        printf("null2\n");
        return 1;
    }
    if (!check(q, 333))
        return 1;
    printf("ok\n");
    return 0;
}
