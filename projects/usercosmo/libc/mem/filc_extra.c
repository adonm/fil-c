/*-*- mode:c;indent-tabs-mode:nil;c-basic-offset:2;tab-width:8;coding:utf-8     -*-│
│ vi: set noet ft=c ts=2 sts=2 sw=2 fenc=utf-8                             :vi │
╞══════════════════════════════════════════════════════════════════════════════╡
│ Fil-C port of Cosmopolitan libc: stragglers.                                 │
│                                                                              │
│  - bsearch(): cosmo gets it from third_party/musl which is not part of       │
│    this build.                                                               │
│  - llrintl(): cosmo only defines it as a weak alias of lrint when long       │
│    double is 64-bit; on x86_64 nothing provides it, but libpizlo and user    │
│    code want it.                                                             │
╚─────────────────────────────────────────────────────────────────────────────*/
#include "libc/stdlib.h"
#include "libc/math.h"
#include "libc/calls/calls.h"
#include "libc/runtime/zipos.internal.h"
#include <pizlonated_syscalls.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/types.h>

void *bsearch(const void *key, const void *base, size_t nel, size_t width,
              int (*cmp)(const void *, const void *)) {
  size_t lo = 0, hi = nel;
  while (lo < hi) {
    size_t mid = lo + (hi - lo) / 2;
    const char *p = (const char *)base + mid * width;
    int c = cmp(key, p);
    if (c < 0) {
      hi = mid;
    } else if (c > 0) {
      lo = mid + 1;
    } else {
      return (void *)p;
    }
  }
  return 0;
}

long long llrintl(long double x) {
  return lrintl(x);
}

/**
 * Creates a child process.
 *
 * cosmo's fork() runs the pthread atfork handlers and reinitializes the
 * __maps machinery; under Fil-C the runtime's own fork handling
 * (filc_thread.forked) makes a plain fork work for simple children.
 * Threads are not inherited across fork (per POSIX).
 */
int fork(void) {
  return zsys_fork();
}

/**
 * Reads directory entries (libc/sysv has no .scall thunk for this; cosmo's
 * version is declared directly in libc/stdio/dirstream.c).
 */
int sys_getdents(unsigned fd, void *dirent, unsigned len, long *basep) {
  (void)basep;
  return zsys_getdents(fd, dirent, len);
}

/**
 * waitid(): cosmo's thunk isn't wired up; libpizlo's zsys_waitid() has the
 * POSIX shape.  Note zsys_waitid takes an unsigned id (idtype dispatch is
 * done by the kernel).  The rusage argument that waitid() technically has
 * is not supported (Linux ignores it when null, and we always pass null).
 */
int waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options) {
  int rc = zsys_waitid((int)idtype, (unsigned)id, infop, options);
  if (rc >= 0 && infop) {
    /* POSIX says waitid() returns 0 and fills infop; leave si_pid etc. to
       the caller. */
  }
  return rc;
}

/**
 * zipos stubs: dirstream.c references these for /zip/ directory iteration,
 * which is unreachable in a Fil-C cosmo program (no embedded zip, and the fd
 * table never tracks kFdZip).  The zipos machinery itself is excluded.
 */
struct Zipos;
struct ZiposUri;
uint64_t __zipos_inode(struct Zipos *zipos, int64_t cfile,
                       const void *path, size_t pathlen) {
  (void)zipos;
  (void)cfile;
  (void)path;
  (void)pathlen;
  return 0;
}

ssize_t __zipos_scan(struct Zipos *zipos, struct ZiposUri *prefix) {
  (void)zipos;
  (void)prefix;
  return 0;
}
