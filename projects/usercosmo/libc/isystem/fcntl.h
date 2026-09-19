#ifndef _FCNTL_H
#define _FCNTL_H
#include "libc/calls/calls.h"
#include "libc/calls/struct/flock.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/at.h"
#include "libc/sysv/consts/f.h"
#include "libc/sysv/consts/o.h"
#include "libc/sysv/consts/posix.h"
#include "libc/sysv/consts/s.h"
#include "libc/sysv/consts/splice.h"
#ifdef __FILC__
/* Fil-C port: musl exposes these; cosmo's fcntl surface doesn't.  The
   implementation lives in libc/mem/filc_extra.c (zsys_fallocate). */
#define AT_EMPTY_PATH 0x1000
int posix_fallocate(int, long, long) libcesque;
#endif
#endif /* _FCNTL_H */
