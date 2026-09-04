#include <stdio.h>

extern long dynalloca_like(void *p, long n);

int main(void)
{
    /* region[8+8i] = i*i for i in [0,n); read back and verify; result is the
       sum n(n-1)(2n-1)/6. n=5: 0+1+4+9+16 = 30. */
    long r = dynalloca_like((void *)0, 5);
    if (r != 30) {
        printf("FAIL: got %ld, want 30\n", r);
        return 1;
    }
    printf("alloca dyn direct att ok\n");
    return 0;
}
