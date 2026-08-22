#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct String { unsigned char* bytes; unsigned long size; };
unsigned long hash(struct String* s);
int main() {
    unsigned char* b = malloc(4); memset(b,'A',4);
    struct String bad = { b, 999999 };   // size lies -> foo(b, i) must trap
    printf("expect trap:\n");
    printf("%lu SHOULD NOT PRINT\n", hash(&bad));
    return 0;
}
