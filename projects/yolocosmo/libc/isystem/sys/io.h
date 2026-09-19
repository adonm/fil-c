#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_IO_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_IO_H_
#include "libc/calls/calls.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw ioperm/iopl
   system call thunks but no <sys/io.h>. These are x86-only system calls. */

int ioperm(unsigned long, unsigned long, int);
int iopl(int);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_IO_H_ */
