#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct String { unsigned char* bytes; size_t size; };
unsigned long hash(struct String* s);
int main() {
    struct String a = { (unsigned char*)"hello", 5 };
    printf("%lu\n", hash(&a));           // expect 210714636441
    struct String e = { (unsigned char*)"", 0 };
    printf("%lu\n", hash(&e));           // expect 5381
    // OOB: size claims more than the buffer holds
    unsigned char* buf = malloc(4); memset(buf,'A',4);
    struct String bad = { buf, 1000000 };
    printf("hashing OOB, expect trap\n");
    printf("%lu (SHOULD NOT PRINT)\n", hash(&bad));
    return 0;
}
