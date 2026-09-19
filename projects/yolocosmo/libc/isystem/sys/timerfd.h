#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_TIMERFD_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_TIMERFD_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/timespec.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/o.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw timerfd
   system call thunks but no <sys/timerfd.h>. */

#if !defined(__COSMO_ITIMERSPEC_DEFINED_)
#define __COSMO_ITIMERSPEC_DEFINED_
struct itimerspec {
  struct timespec it_interval; /* Interval for periodic timer */
  struct timespec it_value;    /* Initial expiration */
};
#endif

#define TFD_NONBLOCK O_NONBLOCK
#define TFD_CLOEXEC  O_CLOEXEC
#define TFD_TIMER_ABSTIME       1
#define TFD_TIMER_CANCEL_ON_SET (1 << 1)

int timerfd_create(int, int);
int timerfd_settime(int, int, const struct itimerspec *, struct itimerspec *);
int timerfd_gettime(int, struct itimerspec *);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_TIMERFD_H_ */
