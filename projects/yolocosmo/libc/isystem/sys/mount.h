#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_MOUNT_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_MOUNT_H_
#include "libc/calls/mount.h"
#include "libc/sysv/consts/mount.h"
#include "libc/sysv/consts/unmount.h"

/* Fil-C addition: umount2(2), which musl/glibc provide. The function is
   defined by the yolocosmo patch in libc/calls/yolo_syscall_wrappers.c. */
int umount2(const char *, int);
#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_MOUNT_H_ */
