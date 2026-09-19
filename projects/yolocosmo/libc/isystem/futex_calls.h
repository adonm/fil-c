#ifndef COSMOPOLITAN_LIBC_ISYSTEM_FUTEX_CALLS_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_FUTEX_CALLS_H_
#include "libc/calls/struct/timespec.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Fil-C runtime (libpizlo) pass-through futex primitives.

   These are the yolo-libc counterparts of the zsys_futex_* system calls that
   the Fil-C runtime implements; see projects/yolomusl/src/thread/futex_calls.c
   for the musl-flavored versions with the same signatures and semantics.

   The `priv` argument is nonzero for futexes shared between threads of the
   same process (FUTEX_PRIVATE_FLAG) and zero for process-shared futexes. */

void yolo_futex_wake(volatile int *addr, int cnt, int priv);
void yolo_futex_wait(volatile int *addr, int val, int priv);

/* yolo_futex_timedwait takes an absolute `timeout` measured against `clock_id`
   and returns 0 on success or the errno as a positive value (it does not set
   errno). The PI calls return the errno as a negative value (they do not set
   errno). */
int yolo_futex_timedwait(volatile int *addr, int val, int clock_id, const struct timespec *timeout, int priv);
int yolo_futex_unlock_pi(volatile int *addr, int priv);
int yolo_futex_lock_pi(volatile int *addr, int priv, const struct timespec *timeout);
int yolo_futex_requeue(volatile int *addr, int priv, int wake_count, int requeue_count, volatile int *addr2);

#ifdef __cplusplus
}
#endif

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_FUTEX_CALLS_H_ */
