#ifndef LIBC_ISYSTEM_SYS_WAIT_H_
#define LIBC_ISYSTEM_SYS_WAIT_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/siginfo.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/w.h"
#include "libc/sysv/consts/waitid.h"
#endif

#ifdef __FILC__
/* Fil-C port: cosmo's waitid() support is only partially wired up; declare
   the POSIX surface that programs expect and provide P_* id types. */
typedef enum { P_ALL, P_PID, P_PGID } idtype_t;

int waitid(idtype_t, id_t, siginfo_t *, int);
#endif
