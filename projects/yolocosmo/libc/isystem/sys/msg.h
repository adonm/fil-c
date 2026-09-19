#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_MSG_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_MSG_H_
#include "libc/calls/calls.h"
#include "libc/calls/weirdtypes.h"
#include "libc/isystem/sys/ipc.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw SysV IPC
   system call thunks but no <sys/msg.h>. The structs and constants below
   match the Linux kernel ABI (and musl's sys/msg.h, which the Fil-C
   user-side uses). */

typedef unsigned long msgqnum_t;
typedef unsigned long msglen_t;

#define MSG_NOERROR 010000
#define MSG_EXCEPT  020000

#define MSG_STAT      (11 | (IPC_STAT & 0x100))
#define MSG_INFO      12
#define MSG_STAT_ANY  (13 | (IPC_STAT & 0x100))

struct msqid_ds {
  struct ipc_perm msg_perm;
  time_t msg_stime;
  time_t msg_rtime;
  time_t msg_ctime;
  unsigned long msg_cbytes;
  msgqnum_t msg_qnum;
  msglen_t msg_qbytes;
  pid_t msg_lspid;
  pid_t msg_lrpid;
  unsigned long __unused[2];
};

struct msginfo {
  int msgpool, msgmap, msgmax, msgmnb, msgmni, msgssz, msgtql;
  unsigned short msgseg;
};

int msgctl(int, int, struct msqid_ds *);
int msgget(key_t, int);
ssize_t msgrcv(int, void *, size_t, long, int);
int msgsnd(int, const void *, size_t, int);

struct msgbuf {
  long mtype;
  char mtext[1];
};

#include "libc/sysv/consts/msg.h"
#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_MSG_H_ */
