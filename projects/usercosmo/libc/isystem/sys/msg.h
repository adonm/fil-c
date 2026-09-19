#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_MSG_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_MSG_H_
#include "libc/calls/weirdtypes.h"
#include "libc/sysv/consts/msg.h"
#ifdef __FILC__
/* Fil-C port: cosmo's msg.h is just the MSG_* constants; the SysV message
   queue API lives here, forwarding to libpizlo's zsys_msg*(). */
#include "libc/calls/ipc.h"
#include <pizlonated_syscalls.h>

struct msgbuf {
  long mtype;
  char mtext[1];
};

/* Only IPC_RMID/IPC_STAT are meaningful here; the layout follows the kernel's
   struct msqid64_ds for IPC_STAT users. */
struct ipc_perm {
  unsigned int __key;
  unsigned int uid;
  unsigned int gid;
  unsigned int cuid;
  unsigned int cgid;
  unsigned short mode;
  unsigned short __pad1;
};

struct msqid_ds {
  struct ipc_perm msg_perm;
  long int msg_stime;
  long int msg_rtime;
  long int msg_ctime;
  unsigned long int msg_cbytes;
  unsigned long int msg_qnum;
  unsigned long int msg_qbytes;
  int msg_lspid;
  int msg_lrpid;
};

static inline int msgget(key_t key, int msgflg) {
  return zsys_msgget(key, msgflg);
}

static inline int msgsnd(int msqid, const void *msgp, size_t msgsz, int msgflg) {
  return zsys_msgsnd(msqid, msgp, msgsz, msgflg);
}

static inline long msgrcv(int msqid, void *msgp, size_t msgsz, long msgtyp,
                          int msgflg) {
  return zsys_msgrcv(msqid, msgp, msgsz, msgtyp, msgflg);
}

static inline int msgctl(int msqid, int cmd, struct msqid_ds *buf) {
  return zsys_msgctl(msqid, cmd, buf);
}
#endif
#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_MSG_H_ */
