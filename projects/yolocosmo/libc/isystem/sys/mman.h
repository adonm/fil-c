#ifndef LIBC_ISYSTEM_SYS_MMAN_H_
#define LIBC_ISYSTEM_SYS_MMAN_H_
#include "libc/calls/calls.h"
#include "libc/calls/weirdtypes.h"
#include "libc/runtime/runtime.h"
#include "libc/sysv/consts/madv.h"
#include "libc/sysv/consts/map.h"
#include "libc/sysv/consts/mlock.h"
#include "libc/sysv/consts/msync.h"
#include "libc/sysv/consts/posix.h"
#include "libc/sysv/consts/prot.h"
#if defined(_GNU_SOURCE)
#include "libc/sysv/consts/mfd.h"
#include "libc/sysv/consts/mremap.h"
#endif

/* Fil-C additions: the Fil-C runtime uses mlockall()/munlockall(), which
   cosmo provides as raw system calls (sys_mlockall / sys_munlockall) but
   doesn't declare. The functions are defined by the yolocosmo patch in
   libc/calls/yolo_syscall_wrappers.c. */
int mlockall(int);
int munlockall(void);
void *mremap(void *, size_t, size_t, int, ...);
int remap_file_pages(void *, size_t, int, size_t, int);
int memfd_create(const char *, unsigned);
#endif
