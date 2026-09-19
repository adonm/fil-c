/*-*- mode:c;indent-tabs-mode:nil;c-basic-offset:2;tab-width:8;coding:utf-8 -*-│
│ vi: set et ft=c ts=2 sts=2 sw=2 fenc=utf-8                               :vi │
╞══════════════════════════════════════════════════════════════════════════════╡
│ Copyright 2023 Justine Alexandra Roberts Tunney                              │
│                                                                              │
│ Permission to use, copy, modify, and/or distribute this software for         │
│ any purpose with or without fee is hereby granted, provided that the         │
│ above copyright notice and this permission notice appear in all copies.      │
│                                                                              │
│ THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL                │
│ WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED                │
│ WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE             │
│ AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL         │
│ DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR        │
│ PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER               │
│ TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR             │
│ PERFORMANCE OF THIS SOFTWARE.                                                │
╚─────────────────────────────────────────────────────────────────────────────*/
#include "libc/stdio/syscall.h"
#include "libc/calls/calls.h"
#include "libc/errno.h"
#include "libc/stdio/rand.h"
#ifdef __FILC__
#include <stdfil.h>
#include <pizlonated_syscalls.h>
/* The Linux numbers for the calls we forward (the libc build does not see
   the extended sys/syscall.h that gets installed for user programs). */
#define FILC_SYS_write            1
#define FILC_SYS_futex            202
#define FILC_SYS_getdents64       217
#define FILC_SYS_copy_file_range  326
#define FILC_SYS_statx            332
#define FILC_SYS_openat2          437
#endif

/**
 * Translation layer for some Linux system calls:
 *
 * - `SYS_gettid`
 * - `SYS_getrandom`
 *
 * @return system call result, or -1 w/ errno
 */
long syscall(long number, ...) {
#ifdef __FILC__
  /* Fil-C port: forward to libpizlo, which understands the supported Linux
     calls (futex, openat2, write, statx, copy_file_range, getdents64, ...)
     and traps on anything else.  The three cosmo-isms below are handled
     first since they are not Linux numbers.

     NOTE: the arguments have to be read with va_arg() per syscall and the
     supported calls go to their typed zsys_* entry points.  We can not just
     zcall(zsys_syscall, zargs()) here: the raw argument-area arithmetic
     inside zsys_syscall() only works for argument areas produced by direct
     calls to it, and this function's vararg area is laid out differently. */
  va_list va;
  long a0, a1, a2, a3, a4, a5;
  switch (number) {
    case FILC_SYS_futex:
      /* Handled through zsys_syscall(), whose futex case does the
         FUTEX_WAIT timeout conversion; the argument types match what musl
         programs pass. */
      return *(long *)zcall(zsys_syscall, zargs());
    case FILC_SYS_write: {
      va_start(va, number);
      int fd = va_arg(va, int);
      const void *buf = va_arg(va, const void *);
      size_t count = va_arg(va, size_t);
      va_end(va);
      return zsys_write(fd, buf, count);
    }
    case FILC_SYS_statx: {
      va_start(va, number);
      int dirfd = va_arg(va, int);
      const char *pathname = va_arg(va, const char *);
      int flags = va_arg(va, int);
      unsigned mask = va_arg(va, unsigned);
      void *statxbuf = va_arg(va, void *);
      va_end(va);
      return zsys_statx(dirfd, pathname, flags, mask, statxbuf);
    }
    case FILC_SYS_copy_file_range: {
      va_start(va, number);
      int fd_in = va_arg(va, int);
      long *off_in = va_arg(va, long *);
      int fd_out = va_arg(va, int);
      long *off_out = va_arg(va, long *);
      size_t len = va_arg(va, size_t);
      unsigned flags = va_arg(va, unsigned);
      va_end(va);
      return zsys_copy_file_range(fd_in, off_in, fd_out, off_out, len, flags);
    }
    case FILC_SYS_openat2: {
      va_start(va, number);
      int dirfd = va_arg(va, int);
      const char *pathname = va_arg(va, const char *);
      const void *how = va_arg(va, const void *);
      size_t size = va_arg(va, size_t);
      va_end(va);
      return zsys_openat2(dirfd, pathname, how, size);
    }
    case FILC_SYS_getdents64: {
      va_start(va, number);
      unsigned fd = va_arg(va, unsigned);
      void *dirent = va_arg(va, void *);
      unsigned count = va_arg(va, unsigned);
      va_end(va);
      return zsys_getdents(fd, dirent, count);
    }
    default:
      errno = ENOSYS;
      return -1;
  }
#else
  switch (number) {
    default:
      errno = ENOSYS;
      return -1;
    case SYS_gettid:
      return gettid();
    case SYS_getrandom: {
      va_list va;
      va_start(va, number);
      void *buf = va_arg(va, void *);
      size_t buflen = va_arg(va, size_t);
      unsigned flags = va_arg(va, unsigned);
      va_end(va);
      return getrandom(buf, buflen, flags);
    }
    case SYS_getcpu: {
      va_list va;
      va_start(va, number);
      unsigned *cpu = va_arg(va, unsigned *);
      unsigned *node = va_arg(va, unsigned *);
      va_end(va);
      return getcpu(cpu, node);
    }
  }
#endif
}
