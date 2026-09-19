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
#include "libc/dce.h"
#include "libc/errno.h"
#include "libc/stdio/rand.h"

#if defined(__x86_64__)
/**
 * Raw system call forwarder.
 *
 * This is part of the Fil-C yolocosmo support: the Fil-C runtime (libpizlo)
 * calls syscall(2) with the real Linux numbers (see libc/stdio/syscall.h), so
 * `syscall()` has to be a raw forwarder rather than the old translation shim.
 * The return value follows the Linux kernel convention (-errno on error),
 * which `syscall()` converts to -1 w/ errno below.
 */
static long yolo_raw_syscall(long number, long a1, long a2, long a3, long a4,
                             long a5, long a6) {
  long ret;
  register long r10 __asm__("r10") = a4;
  register long r8 __asm__("r8") = a5;
  register long r9 __asm__("r9") = a6;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(number), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8),
                     "r"(r9)
                   : "rcx", "r11", "memory");
  return ret;
}
#endif /* __x86_64__ */

/**
 * Performs a system call.
 *
 * @return system call result, or -1 w/ errno
 */
long syscall(long number, ...) {
#if defined(__x86_64__)
  va_list va;
  long a1 = 0, a2 = 0, a3 = 0, a4 = 0, a5 = 0, a6 = 0;
  long r;
  va_start(va, number);
  a1 = va_arg(va, long);
  a2 = va_arg(va, long);
  a3 = va_arg(va, long);
  a4 = va_arg(va, long);
  a5 = va_arg(va, long);
  a6 = va_arg(va, long);
  va_end(va);
  r = yolo_raw_syscall(number, a1, a2, a3, a4, a5, a6);
  if ((unsigned long)r > (unsigned long)-4096) {
    errno = -r;
    return -1;
  }
  return r;
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
#endif /* __x86_64__ */
}
