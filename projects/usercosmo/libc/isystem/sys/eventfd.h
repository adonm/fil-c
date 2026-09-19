#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_EVENTFD_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_EVENTFD_H_
/* Fil-C port: cosmopolitan libc has an eventfd syscall thunk but no public
   wrapper or header; libpizlo supports eventfd(2) via zsys_eventfd(). */

#include <stdfil.h>
#include <pizlonated_syscalls.h>

#define EFD_SEMAPHORE 1
#define EFD_CLOEXEC   02000000
#define EFD_NONBLOCK  04000

static inline int eventfd(unsigned int initval, int flags) {
  return zsys_eventfd(initval, flags);
}

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_EVENTFD_H_ */
