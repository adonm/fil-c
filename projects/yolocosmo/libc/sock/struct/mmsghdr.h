#ifndef COSMOPOLITAN_LIBC_SOCK_STRUCT_MMSGHDR_H_
#define COSMOPOLITAN_LIBC_SOCK_STRUCT_MMSGHDR_H_
#include "libc/sock/struct/msghdr.h"
COSMOPOLITAN_C_START_

/* This is part of the Fil-C yolocosmo support: the Fil-C runtime needs
   `struct mmsghdr` (the sendmmsg/recvmmsg vector element) with the Linux
   kernel ABI. */

struct mmsghdr {
  struct msghdr msg_hdr;
  unsigned int msg_len;
};

int sendmmsg(int, struct mmsghdr *, unsigned int, unsigned int);
int recvmmsg(int, struct mmsghdr *, unsigned int, unsigned int,
             const struct timespec *);

COSMOPOLITAN_C_END_
#endif /* COSMOPOLITAN_LIBC_SOCK_STRUCT_MMSGHDR_H_ */
