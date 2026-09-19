#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_SIGNALFD_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_SIGNALFD_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/sigset.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw signalfd
   system call thunks but no <sys/signalfd.h>. */

#define SFD_NONBLOCK 04000
#define SFD_CLOEXEC  02000000

struct signalfd_siginfo {
  uint32_t ssi_signo;
  int32_t ssi_errno;
  int32_t ssi_code;
  uint32_t ssi_pid;
  uint32_t ssi_uid;
  int32_t ssi_fd;
  uint32_t ssi_tid;
  uint32_t ssi_band;
  int32_t ssi_overrun;
  uint32_t ssi_trapno;
  int32_t ssi_status;
  int32_t ssi_int;
  uint64_t ssi_ptr;
  uint64_t ssi_utime;
  uint64_t ssi_stime;
  uint64_t ssi_addr;
  uint16_t ssi_addr_lsb;
  uint16_t ssi_pad2;
  int32_t ssi_syscall;
  uint64_t ssi_call_addr;
  uint32_t ssi_arch;
  uint8_t ssi_pad[28];
};

int signalfd(int, const sigset_t *, int);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_SIGNALFD_H_ */
