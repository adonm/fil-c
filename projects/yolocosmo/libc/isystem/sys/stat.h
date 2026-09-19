#ifndef LIBC_ISYSTEM_SYS_STAT_H_
#define LIBC_ISYSTEM_SYS_STAT_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/stat.h"
#include "libc/calls/struct/stat.macros.h"
#include "libc/calls/struct/timespec.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/s.h"
#include "libc/sysv/consts/utime.h"
#include "libc/time.h"

/* Fil-C addition: mkfifo(3) and mknodat(2), which musl and glibc provide
   (cosmo provides mknod but not mkfifo/mknodat). The functions are defined
   by the yolocosmo patch in libc/calls/yolo_syscall_wrappers.c. */
int mkfifo(const char *, mode_t);
int mknodat(int, const char *, mode_t, dev_t);
#endif
