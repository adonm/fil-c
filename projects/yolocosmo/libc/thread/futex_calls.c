/*-*- mode:c;indent-tabs-mode:nil;c-basic-offset:2;tab-width:8;coding:utf-8   -*-│
│ vi: set noet ft=c ts=8 sw=8 fenc=utf-8                                   :vi │
╞═════════════════════════════════════════════════════════════════════════════╡
│ This file is part of the Fil-C yolocosmo support.                            │
│                                                                              │
│ It implements the yolo futex primitives that the Fil-C runtime (libpizlo)    │
│ uses to implement its zsys_futex_* pass-through system calls. The musl       │
│ flavored equivalents live in projects/yolomusl/src/thread/futex_calls.c and  │
│ these functions have exactly the same signatures and semantics.              │
╚─────────────────────────────────────────────────────────────────────────────*/
#include "libc/calls/struct/timespec.h"
#include "libc/cosmo.h"
#include "libc/errno.h"
#include "libc/thread/thread.h"

/**
 * Raw futex(2) thunk generated from libc/sysv/calls/sys_futex.S.
 *
 * Like all .scall thunks it returns the syscall result on success, or -1 with
 * `errno` set on error (Linux futexes never return a negative result on
 * success, so this is unambiguous).
 */
long sys_futex(volatile void *, int, int, const void *, volatile void *, int);

#define YOLO_FUTEX_WAIT         0
#define YOLO_FUTEX_WAKE         1
#define YOLO_FUTEX_REQUEUE      3
#define YOLO_FUTEX_LOCK_PI      6
#define YOLO_FUTEX_UNLOCK_PI    7
#define YOLO_FUTEX_PRIVATE_FLAG 128

static char yolo_futex_pshare(int priv) {
  if (priv)
    return PTHREAD_PROCESS_PRIVATE;
  return PTHREAD_PROCESS_SHARED;
}

/**
 * Runs a futex syscall and returns its result, or -errno on error, without
 * clobbering `errno`.
 */
static int yolo_futex_raw(volatile void *uaddr, int op, int val,
                          const void *timeout, volatile void *uaddr2) {
  int e = errno;
  long r = sys_futex(uaddr, op, val, timeout, uaddr2, 0);
  if (r < 0) {
    r = -errno;
    errno = e;
  }
  return (int)r;
}

void yolo_futex_wake(volatile int *addr, int cnt, int priv) {
  int op = YOLO_FUTEX_WAKE;
  if (priv)
    op |= YOLO_FUTEX_PRIVATE_FLAG;
  /* Matches musl's __wake(). */
  yolo_futex_raw(addr, op, cnt, 0, 0);
}

void yolo_futex_wait(volatile int *addr, int val, int priv) {
  int op = YOLO_FUTEX_WAIT;
  if (priv)
    op |= YOLO_FUTEX_PRIVATE_FLAG;
  /* Matches musl's __futexwait(): wait forever and ignore errors, since
     callers are expected to use this inside a loop that rechecks `*addr`. */
  yolo_futex_raw(addr, op, val, 0, 0);
}

int yolo_futex_timedwait(volatile int *addr, int val, int clock_id,
                         const struct timespec *timeout, int priv) {
  /* Matches musl's __timedwait(): `timeout` is an absolute time measured
     against `clock_id`. Returns 0 on success (including the EAGAIN case where
     `*addr` already had a different value) or a positive errno. musl maps
     everything except EINTR, ETIMEDOUT, and ECANCELED to zero. */
  int rc = cosmo_futex_wait((cosmo_futex_t *)addr, val, yolo_futex_pshare(priv),
                            clock_id, timeout);
  if (rc == -EAGAIN)
    return 0;
  if (rc == -EINTR || rc == -ETIMEDOUT || rc == -ECANCELED)
    return -rc;
  if (rc == -EINVAL)
    return EINVAL;
  return 0;
}

int yolo_futex_unlock_pi(volatile int *addr, int priv) {
  int op = YOLO_FUTEX_UNLOCK_PI;
  if (priv)
    op |= YOLO_FUTEX_PRIVATE_FLAG;
  return yolo_futex_raw(addr, op, 0, 0, 0);
}

int yolo_futex_lock_pi(volatile int *addr, int priv,
                       const struct timespec *timeout) {
  int op = YOLO_FUTEX_LOCK_PI;
  if (priv)
    op |= YOLO_FUTEX_PRIVATE_FLAG;
  /* The kernel interprets the timeout for FUTEX_LOCK_PI itself (absolute
     time); pass it through untouched, just like musl does. */
  return yolo_futex_raw(addr, op, 0, timeout, 0);
}

int yolo_futex_requeue(volatile int *addr, int priv, int wake_count,
                       int requeue_count, volatile int *addr2) {
  int op = YOLO_FUTEX_REQUEUE;
  if (priv)
    op |= YOLO_FUTEX_PRIVATE_FLAG;
  /* The requeue count is passed in the timeout argument slot, as the futex
     syscall's fourth argument doubles as val2 for the requeue operations. */
  yolo_futex_raw(addr, op, wake_count, (const void *)(intptr_t)requeue_count,
                 addr2);
  return 0;
}
