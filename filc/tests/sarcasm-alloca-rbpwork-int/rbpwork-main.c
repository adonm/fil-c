#include <stdio.h>

extern long work(void);

int main(void)
{
    long r = work();
    if (r != 785) {
        printf("bad %ld\n", r);
        return 1;
    }
    printf("ok\n");
    return 0;
}
