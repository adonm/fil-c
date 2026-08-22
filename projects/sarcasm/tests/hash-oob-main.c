#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct String { unsigned char* bytes; unsigned long size; };
unsigned long hash(struct String* s);
int main() {
    unsigned char* b = malloc(4); memset(b, 'A', 4);
    struct String s = { b, 1000000 };   // lying size -> hash walks off the end -> trap
    printf("%lu\n", hash(&s));
    return 0;
}
