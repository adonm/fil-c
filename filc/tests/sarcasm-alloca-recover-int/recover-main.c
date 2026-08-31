#include <stdio.h>

extern long rec(void);
extern long rec2(void);
extern long rec3(void);

int main(void)
{
    long a = rec();
    long b = rec2();
    long c = rec3();
    if (a != 6) {
        printf("rec mismatch: %ld\n", a);
        return 1;
    }
    if (b != 3) {
        printf("rec2 mismatch: %ld\n", b);
        return 1;
    }
    if (c != 18) {
        printf("rec3 mismatch: %ld\n", c);
        return 1;
    }
    printf("ok\n");
    return 0;
}
