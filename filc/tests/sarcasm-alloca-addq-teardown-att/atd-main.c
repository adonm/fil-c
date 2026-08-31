#include <stdio.h>

extern long atd(void);

int main(void)
{
    long a = atd();
    if (a != 5) {
        printf("atd mismatch: %ld\n", a);
        return 1;
    }
    printf("ok\n");
    return 0;
}
