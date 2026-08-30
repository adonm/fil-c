#include <stdio.h>

void cross(void);

int main()
{
    printf("setup ok\n");
    cross();
    printf("SHOULD NOT PRINT\n");
    return 0;
}
