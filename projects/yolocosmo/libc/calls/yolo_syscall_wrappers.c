/*-*- mode:c;indent-tabs-mode:nil;c-basic-offset:2;tab-width:8;coding:utf-8   -*-│
│ vi: set noet ft=c ts=8 sw=8 fenc=utf-8                                   :vi │
╞═════════════════════════════════════════════════════════════════════════════╡
│ This file is part of the Fil-C yolocosmo support.                            │
│                                                                              │
│ It provides Linux-flavored libc functions that the Fil-C runtime (libpizlo)  │
│ needs but that cosmo doesn't export as public C functions, by wrapping the   │
│ raw .scall thunks. These wrappers have the same signatures and return        │
│ conventions (0/-1 with errno, or MAP_FAILED with errno) as the musl and      │
│ glibc functions of the same name.                                            │
╚─────────────────────────────────────────────────────────────────────────────*/
#include "libc/calls/calls.h"
#include "libc/calls/syscall-sysv.internal.h"
#include "libc/dce.h"
#include "libc/errno.h"
#include "libc/isystem/dirent.h"
#include "libc/isystem/fcntl.h"
#include "libc/isystem/limits.h"
#include "libc/isystem/sys/epoll.h"
#include "libc/isystem/sys/eventfd.h"
#include "libc/isystem/sys/io.h"
#include "libc/isystem/sys/ipc.h"
#include "libc/isystem/sys/msg.h"
#include "libc/isystem/sys/sem.h"
#include "libc/isystem/sys/shm.h"
#include "libc/isystem/sys/signalfd.h"
#include "libc/isystem/sys/socket.h"
#include "libc/isystem/sys/stat.h"
#include "libc/isystem/sys/swap.h"
#include "libc/isystem/sys/timerfd.h"
#include "libc/isystem/sys/resource.h"
#include "libc/isystem/sys/timex.h"
#include "libc/isystem/sys/wait.h"
#include "libc/isystem/sys/xattr.h"
#include "libc/str/str.h"

/* These raw thunks exist (libc/sysv/calls/sys_*.S) but aren't declared in
   libc/calls/syscall-sysv.internal.h, so declare them here. */
int sys_adjtimex(struct timex *);
int sys_clock_adjtime(int, struct timex *);
int sys_epoll_create1(int);
int sys_epoll_ctl(int, int, int, struct epoll_event *);
int sys_epoll_wait(int, struct epoll_event *, int, int);
int sys_epoll_pwait(int, struct epoll_event *, int, int, const sigset_t *,
                    size_t);
int sys_epoll_pwait2(int, struct epoll_event *, int, const struct timespec *,
                     const sigset_t *, size_t);
int sys_eventfd2(unsigned, int);
ssize_t sys_getxattr(const char *, const char *, void *, size_t);
ssize_t sys_lgetxattr(const char *, const char *, void *, size_t);
ssize_t sys_fgetxattr(int, const char *, void *, size_t);
ssize_t sys_listxattr(const char *, char *, size_t);
ssize_t sys_llistxattr(const char *, char *, size_t);
ssize_t sys_flistxattr(int, char *, size_t);
int sys_setxattr(const char *, const char *, const void *, size_t, int);
int sys_lsetxattr(const char *, const char *, const void *, size_t, int);
int sys_fsetxattr(int, const char *, const void *, size_t, int);
int sys_removexattr(const char *, const char *);
int sys_lremovexattr(const char *, const char *);
int sys_fremovexattr(int, const char *);
int sys_signalfd4(int, const sigset_t *, size_t, int);
int sys_semget(key_t, int, int);
int sys_semctl(int, int, int, unsigned long);
int sys_semop(int, struct sembuf *, size_t);
int sys_semtimedop(int, struct sembuf *, size_t, const struct timespec *);
int sys_shmget(key_t, size_t, int);
long sys_shmat(int, const void *, int);
int sys_shmdt(const void *);
int sys_shmctl(int, int, struct shmid_ds *);
int sys_msgget(key_t, int);
int sys_msgctl(int, int, struct msqid_ds *);
int sys_msgsnd(int, const void *, size_t, int);
ssize_t sys_msgrcv(int, void *, size_t, long, int);
int sys_swapon(const char *, int);
int sys_swapoff(const char *);
int sys_ioperm(unsigned long, unsigned long, int);
int sys_iopl(int);
int sys_munlockall(void);
int sys_recvmmsg(int, struct mmsghdr *, unsigned int, unsigned int,
                 const struct timespec *);
int sys_sendmmsg(int, struct mmsghdr *, unsigned int, unsigned int);
int sys_getdents(int, struct dirent *, size_t);
int sys_fallocate(int, int, off_t, off_t);
int sys_unshare(int);
int sys_setdomainname(const char *, size_t);
int sys_remap_file_pages(void *, size_t, int, size_t, int);
int sys_waitid(int, id_t, siginfo_t *, int, struct rusage *);
int sys_name_to_handle_at(int, const char *, struct file_handle *, int *, int);
int sys_open_by_handle_at(int, struct file_handle *, int);
int sys_memfd_create(const char *, unsigned int);
int sys_setns(int, int);
ssize_t sys_tee(int, int, size_t, unsigned int);
int sys_mknodat(int, const char *, unsigned, uint64_t);
int sys_personality(unsigned long);
int sys_syslog(int, char *, int);
int sys_inotify_init(void);
int sys_inotify_init1(int);
int sys_inotify_add_watch(int, const char *, uint32_t);
int sys_inotify_rm_watch(int, int);
int sys_timerfd_create(int, int);
int sys_timerfd_settime(int, int, const struct itimerspec *,
                        struct itimerspec *);
int sys_timerfd_gettime(int, struct itimerspec *);
int sys_acct(const char *);
int sys_vhangup(void);
int sys_sethostname(const char *, size_t);
int sys_umount2(const char *, int);
ssize_t sys_vmsplice(int, const struct iovec *, int64_t, uint32_t);
#if defined(__x86_64__) && SupportsLinux()
/**
 * Wrapper for the arch_prctl(2) system call, matching glibc's
 * `int arch_prctl(int code, unsigned long addr)` convention, except that the
 * address is passed as a pointer, which is more convenient for callers that
 * use ARCH_GET_FS / ARCH_GET_GS.
 */
int arch_prctl(int code, void *addr) {
  return sys_arch_prctl(code, (int64_t)(intptr_t)addr);
}
#endif /* __x86_64__ && SupportsLinux() */

/**
 * Wrapper for the mremap(2) system call, matching the glibc / musl signature
 * (the fifth argument is optional and only meaningful with MREMAP_FIXED).
 */
void *mremap(void *old_address, size_t old_size, size_t new_size, int flags,
             ...) {
  va_list ap;
  void *new_address;
  va_start(ap, flags);
  new_address = va_arg(ap, void *);
  va_end(ap);
  return sys_mremap(old_address, old_size, new_size, flags,
                    (uint64_t)(intptr_t)new_address);
}

/**
 * Wrapper for the mlockall(2) system call, matching the musl signature.
 */
int mlockall(int flags) {
  return sys_mlockall(flags);
}

#if SupportsLinux()
/**
 * Wrappers for the adjtimex(2) and clock_adjtime(2) system calls, matching
 * the musl signatures. `struct timex` comes from the sys/timex.h that the
 * Fil-C yolocosmo support adds to libc/isystem; it is passed to the kernel
 * verbatim, so it must match the Linux ABI.
 */
int adjtimex(struct timex *buf) {
  return sys_adjtimex(buf);
}

int clock_adjtime(int clock_id, struct timex *buf) {
  return sys_clock_adjtime(clock_id, buf);
}

int ntp_adjtime(struct timex *buf) {
  return adjtimex(buf);
}
#endif /* SupportsLinux() */

/**
 * Epoll wrappers, matching the musl/glibc signatures. Cosmo has the raw
 * thunks (libc/sysv/calls/sys_epoll_*.S) but no public functions. The kernel
 * wants the size of the signal set in the final argument of the pwait
 * variants; cosmo's sigset_t is a 64-bit mask, which is what the kernel wants
 * on x86_64.
 */
int epoll_create1(int flags) {
  return sys_epoll_create1(flags);
}

int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event) {
  return sys_epoll_ctl(epfd, op, fd, event);
}

int epoll_wait(int epfd, struct epoll_event *events, int maxevents,
               int timeout) {
  return sys_epoll_wait(epfd, events, maxevents, timeout);
}

int epoll_pwait(int epfd, struct epoll_event *events, int maxevents,
                int timeout, const sigset_t *sigmask) {
  return sys_epoll_pwait(epfd, events, maxevents, timeout, sigmask,
                         sizeof(sigset_t));
}

int epoll_pwait2(int epfd, struct epoll_event *events, int maxevents,
                 const struct timespec *timeout, const sigset_t *sigmask) {
  return sys_epoll_pwait2(epfd, events, maxevents, timeout, sigmask,
                          sizeof(sigset_t));
}

/**
 * eventfd(2) wrapper, matching the musl signature (musl implements it on top
 * of the eventfd2 system call).
 */
int eventfd(unsigned initval, int flags) {
  return sys_eventfd2(initval, flags);
}

/**
 * Extended attribute wrappers, matching the musl/glibc signatures. Cosmo has
 * the raw thunks (libc/sysv/calls/sys_*xattr.S) but no public functions.
 */
ssize_t getxattr(const char *path, const char *name, void *value,
                 size_t size) {
  return sys_getxattr(path, name, value, size);
}

ssize_t lgetxattr(const char *path, const char *name, void *value,
                  size_t size) {
  return sys_lgetxattr(path, name, value, size);
}

ssize_t fgetxattr(int fd, const char *name, void *value, size_t size) {
  return sys_fgetxattr(fd, name, value, size);
}

ssize_t listxattr(const char *path, char *list, size_t size) {
  return sys_listxattr(path, list, size);
}

ssize_t llistxattr(const char *path, char *list, size_t size) {
  return sys_llistxattr(path, list, size);
}

ssize_t flistxattr(int fd, char *list, size_t size) {
  return sys_flistxattr(fd, list, size);
}

int setxattr(const char *path, const char *name, const void *value,
             size_t size, int flags) {
  return sys_setxattr(path, name, value, size, flags);
}

int lsetxattr(const char *path, const char *name, const void *value,
              size_t size, int flags) {
  return sys_lsetxattr(path, name, value, size, flags);
}

int fsetxattr(int fd, const char *name, const void *value, size_t size,
              int flags) {
  return sys_fsetxattr(fd, name, value, size, flags);
}

int removexattr(const char *path, const char *name) {
  return sys_removexattr(path, name);
}

int lremovexattr(const char *path, const char *name) {
  return sys_lremovexattr(path, name);
}

int fremovexattr(int fd, const char *name) {
  return sys_fremovexattr(fd, name);
}

/**
 * signalfd(2) wrapper, matching the musl signature (musl implements it on
 * top of the signalfd4 system call). Cosmo's sigset_t is a 64-bit mask,
 * which is the sigsetsize the kernel wants on x86_64.
 */
int signalfd(int fd, const sigset_t *mask, int flags) {
  return sys_signalfd4(fd, mask, sizeof(sigset_t), flags);
}

/**
 * SysV IPC wrappers, matching the musl/glibc signatures. Cosmo has the raw
 * thunks (libc/sysv/calls/sys_{sem,shm,msg}*.S) but no public functions.
 */
int semget(key_t key, int nsems, int semflg) {
  return sys_semget(key, nsems, semflg);
}

int semctl(int semid, int semnum, int cmd, ...) {
  va_list ap;
  unsigned long arg;
  va_start(ap, cmd);
  arg = va_arg(ap, unsigned long);
  va_end(ap);
  return sys_semctl(semid, semnum, cmd, arg);
}

int semop(int semid, struct sembuf *sops, size_t nsops) {
  return sys_semop(semid, sops, nsops);
}

int semtimedop(int semid, struct sembuf *sops, size_t nsops,
               const struct timespec *timeout) {
  return sys_semtimedop(semid, sops, nsops, timeout);
}

int shmget(key_t key, size_t size, int shmflg) {
  return sys_shmget(key, size, shmflg);
}

void *shmat(int shmid, const void *shmaddr, int shmflg) {
  return (void *)sys_shmat(shmid, shmaddr, shmflg);
}

int shmdt(const void *shmaddr) {
  return sys_shmdt(shmaddr);
}

int shmctl(int shmid, int cmd, struct shmid_ds *buf) {
  return sys_shmctl(shmid, cmd, buf);
}

int msgget(key_t key, int msgflg) {
  return sys_msgget(key, msgflg);
}

int msgctl(int msqid, int cmd, struct msqid_ds *buf) {
  return sys_msgctl(msqid, cmd, buf);
}

int msgsnd(int msqid, const void *msgp, size_t msgsz, int msgflg) {
  return sys_msgsnd(msqid, msgp, msgsz, msgflg);
}

ssize_t msgrcv(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg) {
  return sys_msgrcv(msqid, msgp, msgsz, msgtyp, msgflg);
}

/**
 * swap(2) wrappers, matching the musl signatures. Cosmo has the raw thunks
 * (libc/sysv/calls/sys_swap{on,off}.S) but no public functions.
 */
int swapon(const char *path, int swapflags) {
  return sys_swapon(path, swapflags);
}

int swapoff(const char *path) {
  return sys_swapoff(path);
}

/**
 * x86 port I/O wrappers, matching the musl signatures. Cosmo has the raw
 * thunks (libc/sysv/calls/sys_ioperm.S and sys_iopl.S) but no public
 * functions.
 */
int ioperm(unsigned long from, unsigned long num, int turn_on) {
  return sys_ioperm(from, num, turn_on);
}

int iopl(int level) {
  return sys_iopl(level);
}

/**
 * mlockall / munlockall companions for the mlockall wrapper above.
 */
int munlockall(void) {
  return sys_munlockall();
}

/**
 * mkfifo(3), matching the musl signature (implemented via mknod, which is
 * what musl does).
 */
int mkfifo(const char *path, mode_t mode) {
  return mknod(path, mode | S_IFIFO, 0);
}

/**
 * sendmmsg / recvmmsg wrappers, matching the musl signatures. Cosmo had a
 * recvmmsg thunk but no sendmmsg thunk (libc/sysv/calls/sys_sendmmsg.S is
 * part of the yolocosmo patch) and no public functions.
 */
int sendmmsg(int fd, struct mmsghdr *msgvec, unsigned int vlen,
             unsigned int flags) {
  return sys_sendmmsg(fd, msgvec, vlen, flags);
}

int recvmmsg(int fd, struct mmsghdr *msgvec, unsigned int vlen,
             unsigned int flags, const struct timespec *timeout) {
  return sys_recvmmsg(fd, msgvec, vlen, flags, timeout);
}

/**
 * adjtime(3), matching the musl signature. There is no adjtime system call
 * on x86_64, so this is implemented on top of adjtimex, exactly like musl
 * does.
 */
int adjtime(const struct timeval *in, struct timeval *out) {
  struct timex utx;
  int r;
  memset(&utx, 0, sizeof(utx));
  if (in) {
    if (in->tv_sec > 1000000 || in->tv_usec > 1000000) {
      errno = EINVAL;
      return -1;
    }
    utx.modes = ADJ_OFFSET_SINGLESHOT;
    utx.offset = in->tv_sec * 1000000 + in->tv_usec;
  }
  r = sys_adjtimex(&utx);
  if (r < 0)
    return -1;
  if (out) {
    out->tv_sec = utx.offset / 1000000;
    out->tv_usec = utx.offset % 1000000;
  }
  return 0;
}

/**
 * getdents(2), matching the Fil-C musl flavor's version (it clamps the
 * length to INT_MAX and forwards to the getdents system call).
 */
int getdents(int fd, struct dirent *buf, size_t len) {
  if (len > INT_MAX)
    len = INT_MAX;
  return sys_getdents(fd, buf, len);
}

/**
 * fallocate(2) and posix_fallocate(3), matching the musl signatures. musl
 * implements posix_fallocate on top of the fallocate system call and returns
 * the (positive) errno, per POSIX.
 */
int fallocate(int fd, int mode, off_t offset, off_t len) {
  return sys_fallocate(fd, mode, offset, len);
}

int posix_fallocate(int fd, off_t base, off_t len) {
  int e = errno;
  int r = sys_fallocate(fd, 0, base, len);
  if (r < 0) {
    r = errno;
    errno = e;
  }
  return r;
}

/**
 * unshare(2), matching the musl signature.
 */
int unshare(int flags) {
  return sys_unshare(flags);
}

/**
 * setdomainname(2), matching the musl signature.
 */
int setdomainname(const char *name, size_t len) {
  return sys_setdomainname(name, len);
}

/**
 * remap_file_pages(2), matching the musl signature.
 */
int remap_file_pages(void *addr, size_t size, int prot, size_t pgoff,
                     int flags) {
  return sys_remap_file_pages(addr, size, prot, pgoff, flags);
}

/**
 * waitid(2), matching the musl signature (the kernel's fifth argument, a
 * struct rusage pointer, may be null).
 */
int waitid(idtype_t type, id_t id, siginfo_t *info, int options) {
  return sys_waitid(type, id, info, options, 0);
}

/**
 * name_to_handle_at(2) / open_by_handle_at(2), matching the musl/glibc
 * signatures.
 */
int name_to_handle_at(int dirfd, const char *pathname,
                      struct file_handle *handle, int *mount_id, int flags) {
  return sys_name_to_handle_at(dirfd, pathname, handle, mount_id, flags);
}

int open_by_handle_at(int mount_fd, struct file_handle *handle, int flags) {
  return sys_open_by_handle_at(mount_fd, handle, flags);
}

/**
 * memfd_create(2), setns(2), tee(2), and mknodat(2), matching the musl
 * signatures.
 */
int memfd_create(const char *name, unsigned int flags) {
  return sys_memfd_create(name, flags);
}

int setns(int fd, int nstype) {
  return sys_setns(fd, nstype);
}

ssize_t tee(int fd_in, int fd_out, size_t len, unsigned int flags) {
  return sys_tee(fd_in, fd_out, len, flags);
}

int mknodat(int dirfd, const char *pathname, mode_t mode, dev_t dev) {
  return sys_mknodat(dirfd, pathname, mode, dev);
}

/**
 * personality(2), klogctl(3), inotify, timerfd, acct(2), vhangup(2),
 * sethostname(2), umount2(2), and vmsplice(2) wrappers, matching the musl
 * signatures. Cosmo has the raw thunks but no public functions.
 */
int personality(unsigned long persona) {
  return sys_personality(persona);
}

int klogctl(int type, char *buf, int len) {
  return sys_syslog(type, buf, len);
}

int inotify_init(void) {
  return sys_inotify_init();
}

int inotify_init1(int flags) {
  return sys_inotify_init1(flags);
}

int inotify_add_watch(int fd, const char *pathname, uint32_t mask) {
  return sys_inotify_add_watch(fd, pathname, mask);
}

int inotify_rm_watch(int fd, int wd) {
  return sys_inotify_rm_watch(fd, wd);
}

int timerfd_create(int clockid, int flags) {
  return sys_timerfd_create(clockid, flags);
}

int timerfd_settime(int fd, int flags, const struct itimerspec *new_value,
                    struct itimerspec *old_value) {
  return sys_timerfd_settime(fd, flags, new_value, old_value);
}

int timerfd_gettime(int fd, struct itimerspec *curr_value) {
  return sys_timerfd_gettime(fd, curr_value);
}

int acct(const char *filename) {
  return sys_acct(filename);
}

int vhangup(void) {
  return sys_vhangup();
}

int sethostname(const char *name, size_t len) {
  return sys_sethostname(name, len);
}

int umount2(const char *target, int flags) {
  return sys_umount2(target, flags);
}

ssize_t vmsplice(int fd, const struct iovec *iov, int64_t nr_segs,
                 uint32_t flags) {
  return sys_vmsplice(fd, iov, nr_segs, flags);
}
