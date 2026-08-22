int g3(int a, int b, int c) { return a+b+c; }         // 3 int args, 0 ptrs
int h1(int* p) { return *p; }                          // 1 ptr arg, deref
int h2(int* p, int* q) { return *p + *q; }             // 2 ptr args
