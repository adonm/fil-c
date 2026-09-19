#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_IPC_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_IPC_H_
#include "libc/calls/ipc.h"
#include "libc/calls/weirdtypes.h"

/* Fil-C addition: the `struct ipc_perm` that the SysV IPC stat structures
   are built on, with the Linux kernel ABI (and musl's sys/ipc.h layout,
   which the Fil-C user-side uses). cosmo's libc/calls/ipc.h provides the
   IPC_* command constants and ftok(). */

struct ipc_perm {
  key_t key;
  uid_t uid;
  gid_t gid;
  uid_t cuid;
  gid_t cgid;
  mode_t mode;
  int seq;
  long __pad1;
  long __pad2;
};

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_IPC_H_ */
