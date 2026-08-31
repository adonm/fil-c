#include <stdio.h>
extern void foo(int, int);
int main() {
    foo(3, 7);
    printf("ok\n");
    return 0;
}
