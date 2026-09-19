#ifndef LIBC_ISYSTEM_SYS_TIME_H_
#define LIBC_ISYSTEM_SYS_TIME_H_
#include "libc/calls/struct/itimerval.h"
#include "libc/calls/struct/timeval.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sock/select.h"
#include "libc/sysv/consts/clock.h"
#include "libc/sysv/consts/itimer.h"
#include "libc/time.h"

/* Fil-C addition: adjtime(3), which musl and glibc provide. The function is
   defined by the yolocosmo patch in libc/calls/yolo_syscall_wrappers.c. */
int adjtime(const struct timeval *, struct timeval *);
#endif
