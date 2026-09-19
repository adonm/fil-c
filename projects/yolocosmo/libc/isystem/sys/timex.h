#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_TIMEX_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_TIMEX_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/timeval.h"
#include "libc/calls/weirdtypes.h"

/* This is part of the Fil-C yolocosmo support: cosmo doesn't provide
   sys/timex.h, but the Fil-C runtime passes `struct timex` through to the
   kernel verbatim via its zsys_clock_adjtime / zsys_adjtimex system calls, so
   the struct below must match the Linux kernel ABI exactly. It is laid out
   the same way as glibc's and musl's sys/timex.h. */

#define NTP_API 1

struct timex {
	unsigned modes; /* mode selector, via ADJ_* bits */
	long offset;    /* time offset (usec) */
	long freq;      /* frequency offset (scaled ppm) */
	long maxerror;  /* maximum error (usec) */
	long esterror;  /* estimated error (usec) */
	int status;     /* clock command/status, via STA_* bits */
	long constant;  /* pll time constant */
	long precision; /* clock precision (usec) (read only) */
	long tolerance; /* clock frequency tolerance (scaled ppm) (read only) */
	struct timeval time; /* (read only, except for ADJ_SETOFFSET) */
	long tick;      /* (modified) usecs between clock ticks */
	long ppsfreq;   /* pps frequency (scaled ppm) (read only) */
	long jitter;    /* pps jitter (us) (read only) */
	int shift;      /* pps interval duration (s) (shift) */
	long stabil;    /* pps stability (scaled ppm) (read only) */
	long jitcnt;    /* jitter limit exceeded (read only) */
	long calcnt;    /* calibration intervals (read only) */
	long errcnt;    /* calibration errors (read only) */
	long stbcnt;    /* stability limit exceeded (read only) */
	int tai;        /* TAI offset (read only) */

	int :32;
	int :32;
	int :32;
	int :32;
	int :32;
	int :32;
	int :32;
	int :32;
	int :32;
	int :32;
	int :32;
};

/* mode selector bits */
#define ADJ_OFFSET            0x0001
#define ADJ_FREQUENCY         0x0002
#define ADJ_MAXERROR          0x0004
#define ADJ_ESTERROR          0x0008
#define ADJ_STATUS            0x0010
#define ADJ_TIMECONST         0x0020
#define ADJ_TAI               0x0080
#define ADJ_SETOFFSET         0x0100
#define ADJ_MICRO             0x1000
#define ADJ_NANO              0x2000
#define ADJ_TICK              0x4000
#define ADJ_OFFSET_SINGLESHOT 0x8001
#define ADJ_OFFSET_SS_READ    0xa001

/* status bits */
#define STA_PLL       0x0001
#define STA_PPSFREQ   0x0002
#define STA_PPSTIME   0x0004
#define STA_FLL       0x0008
#define STA_INS       0x0010
#define STA_DEL       0x0020
#define STA_UNSYNC    0x0040
#define STA_FREQHOLD  0x0080
#define STA_PPSSIGNAL 0x0100
#define STA_PPSJITTER 0x0200
#define STA_PPSWANDER 0x0400
#define STA_PPSERROR  0x0800
#define STA_CLOCKERR  0x1000
#define STA_NANO      0x2000
#define STA_MODE      0x4000
#define STA_CLK       0x8000

#define STA_RONLY                                                       \
	(STA_PPSSIGNAL | STA_PPSJITTER | STA_PPSWANDER | STA_PPSERROR | \
	 STA_CLOCKERR | STA_NANO | STA_MODE | STA_CLK)

/* return codes */
#define TIME_OK   0
#define TIME_INS  1
#define TIME_DEL  2
#define TIME_OOP  3
#define TIME_WAIT 4
#define TIME_ERROR 5
#define TIME_BAD  TIME_ERROR

int adjtimex(struct timex *);
int clock_adjtime(int, struct timex *);
int ntp_adjtime(struct timex *);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_TIMEX_H_ */
