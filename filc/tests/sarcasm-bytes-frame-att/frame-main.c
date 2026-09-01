#include <stdio.h>

long framed8(long x);
long framed40(long x);
long framed264(long x);
long leabytes(void);

int main(void)
{
    /* Byte-encoded prologue stack adjustments must be real frame instructions:
       the frame pass sizes and tears down the frame from them. */
    long a = framed8(35);     /* +7  */
    long b = framed40(33);    /* +9  */
    long c = framed264(31);   /* +11 */
    long d = leabytes();      /* 9 through the leaq (%rsp),%r10 byte form */
    if (a != 42 || b != 42 || c != 42 || d != 9) {
        printf("bad %ld %ld %ld %ld\n", a, b, c, d);
        return 1;
    }
    printf("bytes frame att ok\n");
    return 0;
}
