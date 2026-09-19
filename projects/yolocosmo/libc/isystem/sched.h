#ifndef LIBC_ISYSTEM_SCHED_H_
#define LIBC_ISYSTEM_SCHED_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/cpuset.h"
#include "libc/calls/struct/sched_param.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/sched.h"

/* Fil-C additions: unshare(2) and setns(2), which musl/glibc provide. The
   functions are defined by the yolocosmo patch in
   libc/calls/yolo_syscall_wrappers.c. */
int unshare(int);
int setns(int, int);
#endif
