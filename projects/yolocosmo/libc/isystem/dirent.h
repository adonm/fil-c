#ifndef _DIRENT_H
#define _DIRENT_H
#include "libc/calls/calls.h"
#include "libc/calls/struct/dirent.h"
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/dt.h"

/* Fil-C addition: getdents(2), which the Fil-C-flavored musl provides (cosmo
   has the raw sys_getdents thunk but no public function). The function is
   defined by the yolocosmo patch in libc/calls/yolo_syscall_wrappers.c. */
int getdents(int, struct dirent *, size_t);
#endif /* _DIRENT_H */
