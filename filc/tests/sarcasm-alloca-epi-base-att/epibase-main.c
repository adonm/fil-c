#include <stdio.h>

extern long epibase(long a, long b);
extern long epirbp(long a, long b);
extern long epirbp2(long a, long b);

int main(void)
{
    /* all three restore-base spellings: 2*5 + 3*11 + 7 = 10 + 33 + 7 = 50 */
    long r1 = epibase(5, 11);
    long r2 = epirbp(5, 11);
    long r3 = epirbp2(5, 11);
    if (r1 != 50 || r2 != 50 || r3 != 50) {
        printf("FAIL: got %ld/%ld/%ld, want 50 each\n", r1, r2, r3);
        return 1;
    }
    printf("alloca epi base att ok\n");
    return 0;
}
