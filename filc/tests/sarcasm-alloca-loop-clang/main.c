#include <stdio.h>
extern void foo(int, int);
int main() {
    foo(2, 100);
    printf("ok\n");
    return 0;
}
