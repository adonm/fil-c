#ifndef COSMOPOLITAN_LIBC_SOCK_STRUCT_MMSGHDR_H_
#define COSMOPOLITAN_LIBC_SOCK_STRUCT_MMSGHDR_H_
#include "libc/sock/struct/msghdr.h"
COSMOPOLITAN_C_START_

/* Fil-C port: the sendmmsg/recvmmsg vector element with the Linux kernel
   ABI.  The implementations forward to zsys_sendmmsg()/zsys_recvmmsg()
   (libc/sock/filc_sock.c). */

struct mmsghdr {
  struct msghdr msg_hdr;
  unsigned int msg_len;
};

int sendmmsg(int, struct mmsghdr *, unsigned int, unsigned int);
int recvmmsg(int, struct mmsghdr *, unsigned int, unsigned int,
             const struct timespec *);

COSMOPOLITAN_C_END_
#endif /* COSMOPOLITAN_LIBC_SOCK_STRUCT_MMSGHDR_H_ */
