#include <stdio.h>

extern void *work(long n);

static long check(unsigned char *p, long n)
{
    for (long i = 0; i < n; i++)
        if (p[i] != (unsigned char)i)
            return i;
    return -1;
}

int main(void)
{
    long sizes[5] = { 1, 2, 17, 666, 4096 };
    for (int k = 0; k < 5; k++) {
        unsigned char *p = work(sizes[k]);
        if (check(p, sizes[k]) != -1) {
            printf("bad %ld\n", sizes[k]);
            return 1;
        }
    }
    work(0);
    printf("ok\n");
    return 0;
}
