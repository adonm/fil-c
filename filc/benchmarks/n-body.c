/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * contributed by Miles
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#if defined(__x86_64__) || defined(__i386__)
#include <x86intrin.h>
#else
/*
 * Portable emulation (using generic vector extensions) of the subset of x86
 * AVX intrinsics that this program uses.  This keeps the benchmark's 4-lane
 * double structure intact on non-x86 targets; LLVM lowers the 32-byte vectors
 * to whatever the target supports (2x NEON on ARM64).
 */
typedef double __v2df __attribute__((__vector_size__(16)));
typedef double __v4df __attribute__((__vector_size__(32)));
typedef float __v2sf __attribute__((__vector_size__(8)));
typedef float __v4sf __attribute__((__vector_size__(16)));
typedef __v2df __m128d;
typedef __v4df __m256d;
typedef __v4sf __m128;

#define _mm256_add_pd(a, b) ((a) + (b))
#define _mm256_sub_pd(a, b) ((a) - (b))
#define _mm256_mul_pd(a, b) ((a) * (b))
#define _mm_add_pd(a, b) ((a) + (b))

static inline __m256d _mm256_set1_pd(double x)
{
    return (__v4df){ x, x, x, x };
}

static inline __m256d _mm256_setr_pd(double x0, double x1, double x2, double x3)
{
    return (__v4df){ x0, x1, x2, x3 };
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

static inline __m256d _mm256_load_pd(const double *p)
{
    return *(const __v4df *)p;
}

static inline void _mm256_store_pd(double *p, __m256d v)
{
    *(__v4df *)p = v;
}

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

/* Exact (not approximate) reciprocal square root; the Goldschmidt refinement
 * in _mm256_rsqrt_pd below converges to the same value either way. */
static inline __m128 _mm_rsqrt_ps(__m128 a)
{
    __v4sf r;
    for (int i = 0; i < 4; i++)
        r[i] = (float)(1.0 / sqrt((double)a[i]));
    return r;
}
#endif

#define N 5
#define PI 3.141592653589793
#define SOLAR_MASS (4 * PI * PI)
#define DAYS_PER_YEAR 365.24
#define PAIRS (N*(N-1)/2)

// utilize vrsqrtps to compute an approximation of 1/sqrt(x) with float,
// cast back to double and refine using a variation of
// Goldschmidt’s algorithm to get < 1e-9 error
static inline __m256d _mm256_rsqrt_pd(__m256d s) {
    __m128 q = _mm256_cvtpd_ps(s);
    q = _mm_rsqrt_ps(q);
    __m256d x = _mm256_cvtps_pd(q);
    __m256d y = s * x * x;
    __m256d a = _mm256_mul_pd(y, _mm256_set1_pd(0.375));
    a = _mm256_mul_pd(a, y);
    __m256d b = _mm256_mul_pd(y, _mm256_set1_pd(1.25));
    b = _mm256_sub_pd(b, _mm256_set1_pd(1.875));
    y = _mm256_sub_pd(a, b);
    x = _mm256_mul_pd(x, y);
    return x;
}

// compute rsqrt of distance between each pair of bodies
static inline void kernel(__m256d *r, double *w, __m256d *p) {
    for (int i = 1, k = 0; i < N; i++)
        for (int j = 0; j < i; j++, k++)
            r[k] = _mm256_sub_pd(p[i], p[j]);
    
    for (int k = 0; k < PAIRS; k += 4) {
        __m256d x0 = _mm256_mul_pd(r[k  ], r[k  ]);
        __m256d x1 = _mm256_mul_pd(r[k+1], r[k+1]);
        __m256d x2 = _mm256_mul_pd(r[k+2], r[k+2]);
        __m256d x3 = _mm256_mul_pd(r[k+3], r[k+3]);

        __m256d t0 = _mm256_hadd_pd(x0, x1);
        __m256d t1 = _mm256_hadd_pd(x2, x3);
        __m256d y0 = _mm256_permute2f128_pd(t0, t1, 0x21);
        __m256d y1 = _mm256_blend_pd(t0, t1, 0b1100);

        __m256d z = _mm256_add_pd(y0, y1);
        z = _mm256_rsqrt_pd(z);
        _mm256_store_pd(w+k, z);
    }
}

static double energy(double *m, __m256d *p, __m256d *v) {
    double e = 0.0;

    __m256d r[PAIRS+3];
    double w[PAIRS+3] __attribute__((aligned(sizeof(__m256d))));
    printf("r = %p\n", (void*)r);

    r[N] = _mm256_set1_pd(0.0);
    r[N+1] = _mm256_set1_pd(0.0);
    r[N+2] = _mm256_set1_pd(0.0);

    for (int k = 0; k < N; k++)
        r[k] = _mm256_mul_pd(v[k], v[k]);

    for (int k = 0; k < N; k += 4) {
        __m256d t0 = _mm256_hadd_pd(r[k  ], r[k+1]);
        __m256d t1 = _mm256_hadd_pd(r[k+2], r[k+3]);
        __m256d y0 = _mm256_permute2f128_pd(t0, t1, 0x21);
        __m256d y1 = _mm256_blend_pd(t0, t1, 0b1100);

        __m256d z = _mm256_add_pd(y0, y1);
        _mm256_store_pd(w+k, z);
    }

    for (int k = 0; k < N; k++)
        e += 0.5 * m[k] * w[k];

    r[PAIRS] = _mm256_set1_pd(1.0);
    r[PAIRS+1] = _mm256_set1_pd(1.0);
    r[PAIRS+2] = _mm256_set1_pd(1.0);

    kernel(r, w, p);

    for (int i = 1, k = 0; i < N; i++)
        for (int j = 0; j < i; j++, k++)
            e -= m[i] * m[j] * w[k];

    return e;
}

static void advance(int n, double dt, double *m, __m256d *p, __m256d *v) {
    __m256d r[PAIRS+3];
    double w[PAIRS+3] __attribute__((aligned(sizeof(__m256d))));

    r[PAIRS] = _mm256_set1_pd(1.0);
    r[PAIRS+1] = _mm256_set1_pd(1.0);
    r[PAIRS+2] = _mm256_set1_pd(1.0);

    __m256d rt = _mm256_set1_pd(dt);

    __m256d rm[N];
    for (int i = 0; i < N; i++)
        rm[i] = _mm256_set1_pd(m[i]);

    for (int s = 0; s < n; s++) {
        kernel(r, w, p);

        for (int k = 0; k < PAIRS; k += 4) {
            __m256d x = _mm256_load_pd(w+k);
            __m256d y = _mm256_mul_pd(x, x);
            __m256d z = _mm256_mul_pd(x, rt);
            x = _mm256_mul_pd(y, z);
            _mm256_store_pd(w+k, x);
        }

        for (int i = 1, k = 0; i < N; i++)
            for (int j = 0; j < i; j++, k++) {
                __m256d t = _mm256_set1_pd(w[k]);
                t = _mm256_mul_pd(r[k], t);
                __m256d x = _mm256_mul_pd(t, rm[j]);
                __m256d y = _mm256_mul_pd(t, rm[i]);

                v[i] = _mm256_sub_pd(v[i], x);
                v[j] = _mm256_add_pd(v[j], y);
            }

        for (int i = 0; i < N; i++) {
            __m256d t = _mm256_mul_pd(v[i], rt);
            p[i] = _mm256_add_pd(p[i], t);
        }
    }
}

int main(int argc, char *argv[]) {
    int n = atoi(argv[1]);

    double m[N];
    __m256d p[N], v[N];

    // sun
    m[0] = SOLAR_MASS;
    p[0] = _mm256_set1_pd(0.0);
    v[0] = _mm256_set1_pd(0.0);

    // jupiter
    m[1] = 9.54791938424326609e-04 * SOLAR_MASS;
    p[1] = _mm256_setr_pd(0.0,
         4.84143144246472090e+00,
        -1.16032004402742839e+00,
        -1.03622044471123109e-01);
    v[1] = _mm256_setr_pd(0.0,
         1.66007664274403694e-03 * DAYS_PER_YEAR,
         7.69901118419740425e-03 * DAYS_PER_YEAR,
        -6.90460016972063023e-05 * DAYS_PER_YEAR);

    // saturn
    m[2] = 2.85885980666130812e-04 * SOLAR_MASS;
    p[2] = _mm256_setr_pd(0.0,
         8.34336671824457987e+00,
         4.12479856412430479e+00,
        -4.03523417114321381e-01);
    v[2] = _mm256_setr_pd(0.0,
        -2.76742510726862411e-03 * DAYS_PER_YEAR,
         4.99852801234917238e-03 * DAYS_PER_YEAR,
         2.30417297573763929e-05 * DAYS_PER_YEAR);

    // uranus
    m[3] = 4.36624404335156298e-05 * SOLAR_MASS;
    p[3] = _mm256_setr_pd(0.0,
         1.28943695621391310e+01,
        -1.51111514016986312e+01,
        -2.23307578892655734e-01);
    v[3] = _mm256_setr_pd(0.0,
         2.96460137564761618e-03 * DAYS_PER_YEAR,
         2.37847173959480950e-03 * DAYS_PER_YEAR,
        -2.96589568540237556e-05 * DAYS_PER_YEAR);

    // neptune
    m[4] = 5.15138902046611451e-05 * SOLAR_MASS;
    p[4] = _mm256_setr_pd(0.0,
         1.53796971148509165e+01,
        -2.59193146099879641e+01,
         1.79258772950371181e-01);
    v[4] = _mm256_setr_pd(0.0,
         2.68067772490389322e-03 * DAYS_PER_YEAR,
         1.62824170038242295e-03 * DAYS_PER_YEAR,
        -9.51592254519715870e-05 * DAYS_PER_YEAR);

    // offset momentum
    __m256d o = _mm256_set1_pd(0.0);
    for (int i = 0; i < N; i++) {
        __m256d t = _mm256_mul_pd(_mm256_set1_pd(m[i]), v[i]);
        o = _mm256_add_pd(o, t);
    }
    v[0] = _mm256_mul_pd(o, _mm256_set1_pd(-1.0 / SOLAR_MASS));

    printf("%.9f\n", energy(m, p, v));
    advance(n, 0.01, m, p, v);
    printf("%.9f\n", energy(m, p, v));

    return 0;
}
