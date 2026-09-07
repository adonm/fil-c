/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * contributed by Miles
 * optimization with 4x4 kernel + intrinsics
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#if defined(__x86_64__) || defined(__i386__)
#include <x86intrin.h>
#else
/*
 * Portable emulation (using generic vector extensions) of the subset of x86
 * AVX intrinsics that this program uses.  This keeps the benchmark's 4x4
 * kernel structure intact on non-x86 targets; LLVM lowers the 32-byte vectors
 * to whatever the target supports (2x NEON on ARM64).
 */
typedef int __v2si __attribute__((__vector_size__(8)));
typedef int __v4si __attribute__((__vector_size__(16)));
typedef unsigned __v4su __attribute__((__vector_size__(16)));
typedef double __v2df __attribute__((__vector_size__(16)));
typedef double __v4df __attribute__((__vector_size__(32)));
typedef float __v2sf __attribute__((__vector_size__(8)));
typedef float __v4sf __attribute__((__vector_size__(16)));
typedef __v4si __m128i;
typedef __v2df __m128d;
typedef __v4df __m256d;
typedef __v4sf __m128;

#define _mm256_add_pd(a, b) ((a) + (b))
#define _mm256_sub_pd(a, b) ((a) - (b))
#define _mm256_mul_pd(a, b) ((a) * (b))
#define _mm_add_epi32(a, b) ((a) + (b))
#define _mm_mullo_epi32(a, b) ((__m128i)((__v4su)(a) * (__v4su)(b)))
#define _mm_srli_epi32(a, n) ((__m128i)((__v4su)(a) >> (n)))
#define _mm_add_pd(a, b) ((a) + (b))

static inline __m128i _mm_set1_epi32(int x)
{
    return (__m128i){ x, x, x, x };
}

static inline __m128i _mm_setr_epi32(int x0, int x1, int x2, int x3)
{
    return (__m128i){ x0, x1, x2, x3 };
}

static inline __m256d _mm256_set1_pd(double x)
{
    return (__v4df){ x, x, x, x };
}

static inline __m256d _mm256_cvtepi32_pd(__m128i a)
{
    return __builtin_shufflevector(
        __builtin_convertvector(__builtin_shufflevector(a, a, 0, 1), __v2df),
        __builtin_convertvector(__builtin_shufflevector(a, a, 2, 3), __v2df),
        0, 1, 2, 3);
}

/* Swaps the two doubles within each 128-bit half according to imm's bits:
 * bit0 picks lane0's source, bit1 lane1's, bit2 lane2's, bit3 lane3's
 * (0 = the even element of the half, 1 = the odd element). */
#define _mm256_permute_pd(a, imm) __builtin_shufflevector((a), (a), \
    ((imm) & 1) ? 1 : 0, ((imm) & 2) ? 1 : 0, \
    ((imm) & 4) ? 3 : 2, ((imm) & 8) ? 3 : 2)

/* Picks 128-bit halves of a and b according to the nibbles of imm (bit 0:
 * half index, bit 1: operand select, bit 3: zero the half). */
static inline __m256d _mm256_permute2f128_pd(__m256d a, __m256d b, int imm)
{
    __v2df al = __builtin_shufflevector(a, a, 0, 1);
    __v2df ah = __builtin_shufflevector(a, a, 2, 3);
    __v2df bl = __builtin_shufflevector(b, b, 0, 1);
    __v2df bh = __builtin_shufflevector(b, b, 2, 3);
    __v2df zero = (__v2df){ 0.0, 0.0 };
    int c0 = imm & 0xf;
    int c1 = (imm >> 4) & 0xf;
    __v2df lo = (c0 & 8) ? zero :
        (c0 & 2) ? ((c0 & 1) ? bh : bl) : ((c0 & 1) ? ah : al);
    __v2df hi = (c1 & 8) ? zero :
        (c1 & 2) ? ((c1 & 1) ? bh : bl) : ((c1 & 1) ? ah : al);
    return __builtin_shufflevector(lo, hi, 0, 1, 2, 3);
}

/* Lane i of the result comes from b if bit i of imm is set, else from a. */
#define _mm256_blend_pd(a, b, imm) __builtin_shufflevector((a), (b), \
    ((imm) & 1) ? 4 : 0, ((imm) & 2) ? 5 : 1, ((imm) & 4) ? 6 : 2, \
    ((imm) & 8) ? 7 : 3)

static inline __m128 _mm256_cvtpd_ps(__m256d a)
{
    return __builtin_shufflevector(
        __builtin_convertvector(__builtin_shufflevector(a, a, 0, 1), __v2sf),
        __builtin_convertvector(__builtin_shufflevector(a, a, 2, 3), __v2sf),
        0, 1, 2, 3);
}

static inline __m256d _mm256_cvtps_pd(__m128 a)
{
    return __builtin_shufflevector(
        __builtin_convertvector(__builtin_shufflevector(a, a, 0, 1), __v2df),
        __builtin_convertvector(__builtin_shufflevector(a, a, 2, 3), __v2df),
        0, 1, 2, 3);
}

/* Exact (not approximate) reciprocal; the Goldschmidt-style refinement in
 * kernel() below converges to the same value either way. */
static inline __m128 _mm_rcp_ps(__m128 a)
{
    __v4sf r;
    for (int i = 0; i < 4; i++)
        r[i] = 1.0f / a[i];
    return r;
}

/* { a0, b0, a2, b2 } */
#define _mm256_unpacklo_pd(a, b) __builtin_shufflevector((a), (b), 0, 4, 2, 6)

/* { a1, b1, a3, b3 } */
#define _mm256_unpackhi_pd(a, b) __builtin_shufflevector((a), (b), 1, 5, 3, 7)

static inline __m256d _mm256_load_pd(const double *p)
{
    return *(const __v4df *)p;
}

static inline void _mm256_store_pd(double *p, __m256d v)
{
    *(__v4df *)p = v;
}

/* { a0+a1, b0+b1, a2+a3, b2+b3 } */
static inline __m256d _mm256_hadd_pd(__m256d a, __m256d b)
{
    __v2df sa = __builtin_shufflevector(a, a, 0, 2) +
        __builtin_shufflevector(a, a, 1, 3);
    __v2df sb = __builtin_shufflevector(b, b, 0, 2) +
        __builtin_shufflevector(b, b, 1, 3);
    return __builtin_shufflevector(sa, sb, 0, 2, 1, 3);
}

#define _mm256_extractf128_pd(v, imm) __builtin_shufflevector((v), (v), \
    (imm) ? 2 : 0, (imm) ? 3 : 1)

static inline __m128d _mm_sqrt_pd(__m128d a)
{
    return (__v2df){ sqrt(a[0]), sqrt(a[1]) };
}

static inline void _mm_store_pd(double *p, __m128d v)
{
    *(__v2df *)p = v;
}
#endif

// compute values of A 4 at a time instead of 1
static inline __m256d eval_A(__m128i i, __m128i j) {
    __m128i ONE = _mm_set1_epi32(1);
    __m128i ip1 = _mm_add_epi32(i, ONE);
    __m128i ipj = _mm_add_epi32(i, j);
    __m128i ipjp1 = _mm_add_epi32(ip1, j);
    __m128i a = _mm_mullo_epi32(ipj, ipjp1);
    a = _mm_srli_epi32(a, 1);
    a = _mm_add_epi32(a, ip1);
    return _mm256_cvtepi32_pd(a);
}

// compute results over a 4x4 submatrix of A
static inline void kernel(__m256d u, __m256d s[4], __m256d r[4]) {
    __m256d f[4], p[4];

    // f[i] is each outfix of size 1 for r[i], scaled by u
    // p[i] is the product of r[i]
    for (int i = 0; i < 4; i++) {
        f[i] = _mm256_permute_pd(r[i], 0b0101);
        p[i] = _mm256_mul_pd(r[i], f[i]);
        __m256d t = _mm256_permute2f128_pd(p[i], p[i], 0x01);
        f[i] = _mm256_mul_pd(t, f[i]);
        p[i] = _mm256_mul_pd(t, p[i]);
        f[i] = _mm256_mul_pd(f[i], u);
    }

    __m256d w, x, y, z;

    // collect p[i] into z, and get reciprocal
    x = _mm256_blend_pd(p[0], p[1], 0b1010);
    y = _mm256_blend_pd(p[2], p[3], 0b1010);
    z = _mm256_blend_pd(x, y, 0b1100);
    __m128 q = _mm256_cvtpd_ps(z);
    // approximate reciprocal
    q = _mm_rcp_ps(q);
    x = _mm256_cvtps_pd(q);
    // refine with variation of Goldschmidt’s algorithm
    w = _mm256_mul_pd(x, z);
    y = _mm256_set1_pd(3.0);
    z = _mm256_mul_pd(w, x);
    w = _mm256_sub_pd(w, y);
    x = _mm256_mul_pd(x, y);
    z = _mm256_mul_pd(z, w);
    z = _mm256_add_pd(z, x);

    // broadcast each 1/z over p[i]
    x = _mm256_unpacklo_pd(z, z);
    y = _mm256_unpackhi_pd(z, z);
    w = _mm256_permute2f128_pd(x, x, 1);
    z = _mm256_permute2f128_pd(y, y, 1);
    p[0] = _mm256_blend_pd(x, w, 0b1100);
    p[1] = _mm256_blend_pd(y, z, 0b1100);
    p[2] = _mm256_blend_pd(x, w, 0b0011);
    p[3] = _mm256_blend_pd(y, z, 0b0011);

    // increment each row-sum by the product u / A[i, j..j+3]
    for (int i = 0; i < 4; i++) {
        __m256d t = _mm256_mul_pd(f[i], p[i]);
        s[i] = _mm256_add_pd(s[i], t);
    }
}

static void eval_A_times_u(int n, double *u, double *Au) {
    // force static schedule since each chunk performs equal amounts of work
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < n; i += 4) {
        __m256d s[4];
        for (int k = 0; k < 4; k++)
            s[k] = _mm256_set1_pd(0.0);

        for (int j = 0; j < n; j += 4) {
            __m256d r[4];
            // generate the values of A for the 4x4 submatrix with
            // upper-left at (i, j)
            for (int k = 0; k < 4; k++) {
                __m128i x = _mm_set1_epi32(i+k);
                __m128i y = _mm_setr_epi32(j, j+1, j+2, j+3);
                r[k] = eval_A(x, y);
            }

            kernel(_mm256_load_pd(u+j), s, r);
        }

        // sum the values in each s[i] and store in z
        __m256d t0 = _mm256_hadd_pd(s[0], s[1]);
        __m256d t1 = _mm256_hadd_pd(s[2], s[3]);
        __m256d x = _mm256_permute2f128_pd(t0, t1, 0x21);
        __m256d y = _mm256_blend_pd(t0, t1, 0b1100);
        __m256d z = _mm256_add_pd(x, y);

        _mm256_store_pd(Au+i, z);
    }

    // clear overhang values
    Au[n] = 0.0;
    Au[n+1] = 0.0;
    Au[n+2] = 0.0;
}

// same as above except indices of A flipped (transposed)
static void eval_At_times_u(int n, double *u, double *Au) {
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < n; i += 4) {
        __m256d s[4];
        for (int k = 0; k < 4; k++)
            s[k] = _mm256_set1_pd(0.0);

        for (int j = 0; j < n; j += 4) {
            __m256d r[4];
            for (int k = 0; k < 4; k++) {
                __m128i x = _mm_set1_epi32(i+k);
                __m128i y = _mm_setr_epi32(j, j+1, j+2, j+3);
                r[k] = eval_A(y, x);
            }

            kernel(_mm256_load_pd(u+j), s, r);
        }

        __m256d t0 = _mm256_hadd_pd(s[0], s[1]);
        __m256d t1 = _mm256_hadd_pd(s[2], s[3]);
        __m256d x = _mm256_permute2f128_pd(t0, t1, 0x21);
        __m256d y = _mm256_blend_pd(t0, t1, 0b1100);
        __m256d z = _mm256_add_pd(x, y);

        _mm256_store_pd(Au+i, z);
    }

    Au[n] = 0.0;
    Au[n+1] = 0.0;
    Au[n+2] = 0.0;
}

static void eval_AtA_times_u(int n, double *u, double *AtAu) {
    double v[n+3] __attribute__((aligned(sizeof(__m256d))));

    eval_A_times_u(n, u, v);
    eval_At_times_u(n, v, AtAu);
}

int main(int argc, char *argv[]) {
    int n = atoi(argv[1]);

    // overhang of 3 values for computing in strides of 4 incase n % 4 != 0
    // aligned to __m256d to use aligned loads/stores
    double u[n+3] __attribute__((aligned(sizeof(__m256d))));
    double v[n+3] __attribute__((aligned(sizeof(__m256d))));

    for (int i = 0; i < n; i++)
        u[i] = 1.0;
    // initiate overhang values to zero
    u[n] = 0.0;
    u[n+1] = 0.0;
    u[n+2] = 0.0;

    for (int i = 0; i < 10; i++) {
        eval_AtA_times_u(n, u, v);
        eval_AtA_times_u(n, v, u);
    }

    __m256d uv = _mm256_set1_pd(0.0);
    __m256d v2 = _mm256_set1_pd(0.0);

    for (int i = 0; i < n; i += 4) {
        __m256d x = _mm256_load_pd(u+i);
        __m256d y = _mm256_load_pd(v+i);
        x = _mm256_mul_pd(x, y);
        y = _mm256_mul_pd(y, y);
        uv = _mm256_add_pd(uv, x);
        v2 = _mm256_add_pd(v2, y);
    }

    __m256d z = _mm256_hadd_pd(uv, v2);
    __m128d x = _mm256_extractf128_pd(z, 0);
    __m128d y = _mm256_extractf128_pd(z, 1);
    x = _mm_add_pd(x, y);
    x = _mm_sqrt_pd(x);
    double r[2] __attribute__((aligned(sizeof(__m128d))));
    _mm_store_pd(r, x);

    printf("%0.9f\n", r[0] / r[1]);

    return 0;
}
