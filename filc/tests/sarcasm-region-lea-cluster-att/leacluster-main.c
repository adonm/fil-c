#include <stdio.h>

extern long cluster(long x);

int main(void)
{
    /* region+32 ends at 103 (last of the rdi/rsi/rcx writes), region+40 = 102;
       sum = 205. */
    long r = cluster(0);
    if (r != 205) {
        printf("FAIL: got %ld, want 205\n", r);
        return 1;
    }
    printf("region lea cluster att ok\n");
    return 0;
}
