#include <stdio.h>
#include <stdlib.h>

unsigned long* recurse(unsigned long* p, long depth);
void churn(long n);

int main()
{
    unsigned long* p = (unsigned long*)malloc(4096);
    unsigned long* r = recurse(p, 20000);
    if (r != p) {
        printf("recurse returned %p want %p\n", (void*)r, (void*)p);
        return 1;
    }
    if (p[0] != 0x5500550055005500UL) {
        printf("sentinel = %lx\n", p[0]);
        return 1;
    }
    printf("recurse gc ok\n");
    return 0;
}

void churn(long n)
{
    /* Allocation churn: unreachable garbage forces FUGC cycles while the
       whole 20000-frame recursion is live on the stack. */
    for (long i = 0; i < n; ++i) {
        unsigned long* q = (unsigned long*)malloc(512);
        q[0] = (unsigned long)i;
    }
}
