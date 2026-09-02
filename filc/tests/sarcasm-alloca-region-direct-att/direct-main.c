#include <stdio.h>
long direct(long n);
int main() {
    /* n + 0x1122334455667788 + 99 + 1000 */
    printf("%ld\n", direct(5));
    return 0;
}
