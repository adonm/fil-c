#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_EVENTFD_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_EVENTFD_H_
#include "libc/calls/calls.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw eventfd
   system call thunks but no <sys/eventfd.h>. */

#define EFD_SEMAPHORE 1
#define EFD_CLOEXEC   02000000
#define EFD_NONBLOCK  04000

int eventfd(unsigned, int);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_EVENTFD_H_ */
