#include <stdio.h>
extern long gf2m_tab_lookup(long i);
int main(void) {
    int ok = 1;
    for (long i = 0; i < 16; i++) if (gf2m_tab_lookup(i) != 3*i+1) ok = 0;
    printf("%s\n", ok ? "clone tab offset ok" : "FAIL");
    return !ok;
}
