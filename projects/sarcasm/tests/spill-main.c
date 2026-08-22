#include <stdio.h>
#include <stdlib.h>
unsigned long sumn(unsigned long* p);
int main() {
    unsigned long* p = malloc(26 * sizeof(unsigned long));
    for (int i = 0; i < 26; i++) p[i] = i + 1;
    printf("%lu\n", sumn(p));   // 1+2+...+26 = 351
    return 0;
}
