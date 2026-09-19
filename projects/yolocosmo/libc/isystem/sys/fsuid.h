#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_FSUID_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_FSUID_H_
#include "libc/calls/calls.h"
#include "libc/calls/weirdtypes.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw setfsuid /
   setfsgid system call thunks but no <sys/fsuid.h>. */

int setfsuid(uid_t);
int setfsgid(gid_t);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_FSUID_H_ */
