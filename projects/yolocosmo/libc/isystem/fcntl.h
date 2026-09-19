#ifndef _FCNTL_H
#define _FCNTL_H
#include "libc/calls/calls.h"
#include "libc/calls/struct/flock.h"
#include "libc/calls/struct/f_owner_ex.h"
#include "libc/calls/weirdtypes.h"
#include "libc/isystem/sys/uio.h"
#include "libc/sysv/consts/at.h"
#include "libc/sysv/consts/f.h"
#include "libc/sysv/consts/o.h"
#include "libc/sysv/consts/posix.h"
#include "libc/sysv/consts/s.h"
#include "libc/sysv/consts/splice.h"

/* Fil-C additions: file handles (name_to_handle_at / open_by_handle_at) and
   fallocate(), which musl/glibc provide. The functions are defined by the
   yolocosmo patch in libc/calls/yolo_syscall_wrappers.c. */
struct file_handle {
  unsigned handle_bytes;
  int handle_type;
  unsigned char f_handle[];
};
#define MAX_HANDLE_SZ 128
#define FALLOC_FL_KEEP_SIZE  1
#define FALLOC_FL_PUNCH_HOLE 2
#define FALLOC_FL_NO_HIDE_STALE 3
#define FALLOC_FL_COLLAPSE_RANGE 8
#define FALLOC_FL_ZERO_RANGE 16
#define FALLOC_FL_INSERT_RANGE 32
#define FALLOC_FL_UNSHARE_RANGE 64
int fallocate(int, int, off_t, off_t);
int posix_fallocate(int, off_t, off_t);
ssize_t tee(int, int, size_t, unsigned);
int name_to_handle_at(int, const char *, struct file_handle *, int *, int);
int open_by_handle_at(int, struct file_handle *, int);
#endif /* _FCNTL_H */
