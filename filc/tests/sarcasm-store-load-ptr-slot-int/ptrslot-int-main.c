#include <stdio.h>
extern long store_load_ptr_slot(long *xp);
int main(void) {
    long x = 777;
    long r = store_load_ptr_slot(&x);
    if (r != 777 || x != 777) { printf("FAIL: got %ld %ld\n", r, x); return 1; }
    printf("store load ptr slot ok\n");
    return 0;
}
