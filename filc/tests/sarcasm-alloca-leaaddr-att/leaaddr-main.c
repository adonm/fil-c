#include <stdio.h>

long leaaddr(void);

void fill32(long *p)
{
    for (int i = 0; i < 4; i++) p[i] = 100 + i;
}

int main()
{
    /* (100+101) + (100+101) = 402 */
    printf("%ld\n", leaaddr());
    return 0;
}
