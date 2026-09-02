#include <stdio.h>
long flow(long n);
int main() {
    /* slot squared + alloca contents: 6*6 + 7 = 43 */
    printf("%ld\n", flow(6));
    return 0;
}
