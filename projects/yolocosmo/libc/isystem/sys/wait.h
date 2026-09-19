#ifndef LIBC_ISYSTEM_SYS_WAIT_H_
#define LIBC_ISYSTEM_SYS_WAIT_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/siginfo.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/w.h"
#include "libc/sysv/consts/waitid.h"

/* Fil-C additions: waitid() and its idtype_t argument type, which musl and
   glibc provide. The function is defined by the yolocosmo patch in
   libc/calls/yolo_syscall_wrappers.c. */
typedef enum {
  P_ALL = 0,
  P_PID = 1,
  P_PGID = 2,
  P_PIDFD = 3,
} idtype_t;

int waitid(idtype_t, id_t, siginfo_t *, int);
#endif /* LIBC_ISYSTEM_SYS_WAIT_H_ */
