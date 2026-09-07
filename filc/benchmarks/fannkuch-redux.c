// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// Contributed by Ilya Kurdyukov
// Based on "fannkuch-redux C++ g++ #6",
// contributed by Andrei Simion (with patch from Vincent Yu)
// which in turn was based on the C++ program by Dave Compton,
// which in turn was based on the C program by Jeremy Zerfasm
// which in turn was based on the Ada program by Jonathan Parker and 
// Georg Bauhaus which in turn was based on code by Dave Fladebo, 
// Eckehard Berns, Heiner Marxen, Hongwei Xi, and The Anh Tran and 
// also the Java program by Oleg Mazurov.

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <stdlib.h>
#if defined(__x86_64__) || defined(__i386__)
#include <smmintrin.h>  /* SSE 4.1 */
#elif defined(__aarch64__)
#include <arm_neon.h>

/*
 * ARM64 (NEON) equivalents for the handful of SSE intrinsics that this
 * program uses.  Everything here is byte-granular.  The only subtle one is
 * _mm_shuffle_epi8: pshufb zeroes a result byte when the control byte has the
 * high bit set, while vqtbl1q zeroes it when the control byte is not in
 * 0..15.  These agree for all control bytes used in this file (shuffles are
 * only ever fed control bytes below 16 in lanes whose results are consumed,
 * and negative control bytes zero the lane in both cases).
 */
typedef int8x16_t __m128i;

static inline __m128i _mm_setr_epi8(signed char b0, signed char b1,
    signed char b2, signed char b3, signed char b4, signed char b5,
    signed char b6, signed char b7, signed char b8, signed char b9,
    signed char b10, signed char b11, signed char b12, signed char b13,
    signed char b14, signed char b15)
{
  signed char buf[16] = { b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11,
    b12, b13, b14, b15 };
  return vld1q_s8(buf);
}

static inline __m128i _mm_setzero_si128(void)
{
  return vdupq_n_s8(0);
}

static inline __m128i _mm_set1_epi8(signed char x)
{
  return vdupq_n_s8(x);
}

static inline __m128i _mm_add_epi8(__m128i a, __m128i b)
{
  return vaddq_s8(a, b);
}

static inline __m128i _mm_sub_epi8(__m128i a, __m128i b)
{
  return vsubq_s8(a, b);
}

/* Selects b's byte where mask's byte has the high bit set, a's byte where it
 * does not.  (vshrq_n_s8 is an arithmetic shift, so it replicates each sign
 * bit into a full 0x00/0xff byte selector for vbslq.) */
static inline __m128i _mm_blendv_epi8(__m128i a, __m128i b, __m128i mask)
{
  return vbslq_s8(vreinterpretq_u8_s8(vshrq_n_s8(mask, 7)), b, a);
}

static inline __m128i _mm_shuffle_epi8(__m128i a, __m128i ctrl)
{
  return vreinterpretq_s8_u8(
      vqtbl1q_u8(vreinterpretq_u8_s8(a), vreinterpretq_u8_s8(ctrl)));
}

/* PALIGNR concatenates a (high 16 bytes) with b (low 16 bytes), shifts right
 * by n bytes, and keeps the low 16 bytes.  VEXT computes exactly that. */
#define _mm_alignr_epi8(a, b, n) vextq_s8((b), (a), (n))

/* Byte-shift right with zero fill. */
#define _mm_bsrli_si128(a, n) vextq_s8((a), vdupq_n_s8(0), (n))

static inline int _mm_cvtsi128_si32(__m128i a)
{
  /* movd extracts the low 32 bits (not the sign-extended low byte). */
  return vgetq_lane_s32(vreinterpretq_s32_s8(a), 0);
}

/* bit k of the result is the high bit of byte k. */
static inline int _mm_movemask_epi8(__m128i a)
{
  uint16x8_t w = vandq_u16(vreinterpretq_u16_s8(a), vdupq_n_u16(0x8080));
  uint8x8_t even = vshrn_n_u16(w, 7);
  uint8x8_t odd = vshr_n_u8(vshrn_n_u16(w, 8), 7);
  uint16x8_t pair = vaddl_u8(even, vshl_n_u8(odd, 1));
  uint32x4_t q = vorrq_u32(vandq_u32(vreinterpretq_u32_u16(pair),
          vdupq_n_u32(0xffff)),
      vshrq_n_u32(vreinterpretq_u32_u16(pair), 14));
  uint64x2_t f = vreinterpretq_u64_u32(q);
  uint64_t l = vgetq_lane_u64(f, 0);
  uint64_t h = vgetq_lane_u64(f, 1);
  l = (l & 0xffffffffu) | (l >> 28);
  h = (h & 0xffffffffu) | (h >> 28);
  return (int)(uint32_t)(l | (h << 8));
}

/* ~a & b */
static inline __m128i _mm_andnot_si128(__m128i a, __m128i b)
{
  return vreinterpretq_s8_u8(vbicq_u8(vreinterpretq_u8_s8(b),
      vreinterpretq_u8_s8(a)));
}

static inline __m128i _mm_cmpgt_epi8(__m128i a, __m128i b)
{
  return vcgtq_s8(a, b);
}

static inline __m128i _mm_cmpeq_epi8(__m128i a, __m128i b)
{
  return vceqq_s8(a, b);
}
#else
#error "Unsupported architecture"
#endif

#define MAX_N 16
#define MAX_BLOCKS 24
#define ALIGN(n) __attribute__((aligned(n)))
#define LIKELY(x) __builtin_expect(!!(x), 1)
#define UNLIKELY(x) __builtin_expect(!!(x), 0)
#define RAMP16 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15

static __m128i masks_shift[16] ALIGN(16);
static uint64_t factorials[MAX_N + 1];

struct fannkuch_data {
  uint64_t block_start, block_size, block_end;
  long long checksum;
  unsigned max_flips, n, mutex;
};

static void* fannkuch_func(void* param) {
  struct fannkuch_data *data = (struct fannkuch_data*)param;
  long long checksum = 0;
  unsigned max_flips = 0;

  int n = data->n;
  uint64_t block_size = data->block_size;
  uint64_t block_end = data->block_end;

  if (n < 1 || n > MAX_N) __builtin_unreachable();

  // iterate over each block.
  for (;;) {
    uint64_t block_start = __sync_fetch_and_add(&data->block_start, block_size);
    if (block_start >= block_end) break;

    __m128i ramp = _mm_setr_epi8(RAMP16), current = ramp;
	  __m128i c0 = _mm_setzero_si128();
		__m128i count_vec = c0;
    unsigned i = n;
    {  
	    uint64_t j = block_start;
      __m128i v0, v1, v2, mask, c1 = _mm_set1_epi8(1);
      mask = _mm_sub_epi8(ramp, _mm_set1_epi8(i));
      while (i--) {
        uint64_t d = j / factorials[i];
        j -= d * factorials[i];
        v2 = _mm_set1_epi8(d);
				count_vec = _mm_alignr_epi8(count_vec, v2, 15);
        v1 = _mm_add_epi8(ramp, v2);
        v0 = _mm_add_epi8(mask, v2);  // ramp - i + d
        v0 = _mm_blendv_epi8(v0, v1, v0);
        v2 = _mm_shuffle_epi8(current, v0);
        current = _mm_blendv_epi8(current, v2, mask);
        mask = _mm_add_epi8(mask, c1);
      }
    }

    // iterate over each permutation in the block.
    uint64_t block_left = block_size;

    do {
			__m128i v0, v1, v2, v3;	unsigned i, first;
#define X(op) \
			v2 = current; \
			first = _mm_cvtsi128_si32(current); \
			v0 = _mm_sub_epi8(count_vec, ramp); \
			i = __builtin_ctz(_mm_movemask_epi8(v0)); \
			v0 = _mm_set1_epi8(i); \
			v1 = _mm_andnot_si128(_mm_cmpgt_epi8(v0, ramp), count_vec); \
			count_vec = _mm_sub_epi8(v1, _mm_cmpeq_epi8(v0, ramp)); \
      current = _mm_shuffle_epi8(current, masks_shift[i]); \
      if (LIKELY(first & 0xff)) { \
        unsigned flips = 0; \
				v3 = _mm_shuffle_epi8(v2, c0); \
        do { \
   				v0 = _mm_sub_epi8(v3, ramp); \
					v3 = _mm_shuffle_epi8(v2, v3); \
   				v0 = _mm_blendv_epi8(v0, ramp, v0); \
          v2 = _mm_shuffle_epi8(v2, v0); \
          first = _mm_cvtsi128_si32(v3); \
          flips++; \
        } while (UNLIKELY(first & 0xff)); \
        checksum op flips; \
        if (flips > max_flips) max_flips = flips; \
      }
			X(+=) if (UNLIKELY(block_left == 1)) break; X(-=)
    } while (LIKELY(block_left -= 2));
  }

  __sync_add_and_fetch(&data->checksum, checksum);
  while (__sync_lock_test_and_set(&data->mutex, 1));
  if (data->max_flips < max_flips) data->max_flips = max_flips;
  __sync_lock_release(&data->mutex);
  return NULL;
}

#define MAX_THREADS 64

int main(int argc, char **argv) {   
  int i, n, nthreads = 4; uint64_t tmp = 1;
  __m128i ramp = _mm_setr_epi8(RAMP16);
  __m128i c1 = _mm_set1_epi8(1), v0, v1, v2;
  __m128i ramp1 = _mm_bsrli_si128(ramp, 1), old = ramp;
  factorials[0] = 1;
  v0 = _mm_sub_epi8(_mm_setzero_si128(), ramp);
  for (i = 0; i < MAX_N; v0 = _mm_add_epi8(v0, c1)) {
    v2 = _mm_blendv_epi8(v0, ramp, v0);
		v1 = _mm_blendv_epi8(ramp1, v2, _mm_sub_epi8(v0, c1));
		old = _mm_shuffle_epi8(old, v1);
    masks_shift[i] = old;
		tmp *= ++i;
		factorials[i] = tmp;
  }

  if (argc > 2 && !strcmp(argv[1], "-t"))
    argc -= 2, argv += 2, nthreads = atoi(*argv);
  if (nthreads < 1) nthreads = 1;
  if (nthreads > MAX_THREADS) nthreads = MAX_THREADS;

  while (argc-- > 1) {
    struct fannkuch_data data = { 0 };
    uint64_t block_end;
    pthread_t buf[MAX_THREADS];

    data.n = n = atoi(*++argv);
    if (n < 1 || n > MAX_N) return 1;

    block_end = factorials[n];
    data.block_size = block_end / (block_end > MAX_BLOCKS ? MAX_BLOCKS : 1);
    data.block_end = block_end;

    for (i = 1; i < nthreads; i++)
      pthread_create(buf + i, NULL, fannkuch_func, &data);
    fannkuch_func(&data);
    for (i = 1; i < nthreads; i++) pthread_join(buf[i], NULL);
    printf("%lld\nPfannkuchen(%u) = %u\n", data.checksum, n, data.max_flips);
  }
}
