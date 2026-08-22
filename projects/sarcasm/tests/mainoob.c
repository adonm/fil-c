#include <stdio.h>
#include <stdlib.h>
#include <string.h>
unsigned long hash(unsigned char *str);
int main() {
    unsigned char *buf = malloc(3);   // no null terminator on purpose
    memset(buf, 'A', 3);
    printf("about to hash OOB\n");
    unsigned long h = hash(buf);       // must trap at bounds, not read OOB
    printf("got %lu (SHOULD NOT PRINT)\n", h);
    return 0;
}
