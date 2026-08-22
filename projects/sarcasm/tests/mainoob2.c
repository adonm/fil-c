#include <stdio.h>
#include <stdlib.h>
#include <string.h>
unsigned long hash(unsigned char *str);
int main() {
    size_t n = 200000;
    unsigned char *buf = malloc(n);
    memset(buf, 'A', n);               // fully non-zero: hash must walk off the end
    printf("hashing %zu non-zero bytes; expect a Fil-C bounds trap\n", n);
    unsigned long h = hash(buf);
    printf("got %lu (SHOULD NOT PRINT if bounds enforced)\n", h);
    return 0;
}
