#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_SWAP_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_SWAP_H_
#include "libc/calls/calls.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw swap
   system call thunks but no <sys/swap.h>. */

#define SWAP_FLAG_PREFER    0x8000
#define SWAP_FLAG_PRIO_MASK 0x7fff
#define SWAP_FLAG_DISCARD   0x10000

int swapon(const char *, int);
int swapoff(const char *);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_SWAP_H_ */
