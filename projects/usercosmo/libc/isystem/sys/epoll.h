#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_EPOLL_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_EPOLL_H_
/* Fil-C port: cosmopolitan libc does not ship an epoll API (only the raw
   sys_epoll_* syscall thunks), but libpizlo supports the epoll syscalls
   including the fd-table bookkeeping for epoll_data.ptr.  Wrap them here so
   portable Linux code (and the Fil-C test suite) keeps working. */

#include <stdfil.h>
#include <pizlonated_syscalls.h>
#include "libc/calls/struct/sigset.h"

/* cosmo has no sysv/consts/epoll.h; these are the Linux values. */
#define EPOLLIN        0x00000001u
#define EPOLLPRI       0x00000002u
#define EPOLLOUT       0x00000004u
#define EPOLLERR       0x00000008u
#define EPOLLHUP       0x00000010u
#define EPOLLRDNORM    0x00000040u
#define EPOLLRDBAND    0x00000080u
#define EPOLLWRNORM    0x00000100u
#define EPOLLWRBAND    0x00000200u
#define EPOLLMSG       0x00000400u
#define EPOLLRDHUP     0x00002000u
#define EPOLLEXCLUSIVE (1u << 28)
#define EPOLLWAKEUP    (1u << 29)
#define EPOLLONESHOT   (1u << 30)
#define EPOLLET        (1u << 31)

#define EPOLL_CTL_ADD 1
#define EPOLL_CTL_DEL 2
#define EPOLL_CTL_MOD 3

typedef union epoll_data {
  void *ptr;
  int fd;
  uint32_t u32;
  uint64_t u64;
} epoll_data_t;

/* Layout must match struct epoll_event in filc/src/runtime.c, which casts
   the user pointer to its own definition. */
struct epoll_event {
  uint32_t events;
  epoll_data_t data;
};

static inline int epoll_create(int size) {
  (void)size;
  return zsys_epoll_create1(0);
}

static inline int epoll_create1(int flags) {
  return zsys_epoll_create1(flags);
}

static inline int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event) {
  return zsys_epoll_ctl(epfd, op, fd, event);
}

static inline int epoll_wait(int epfd, struct epoll_event *events, int maxevents,
                             int timeout) {
  return zsys_epoll_wait(epfd, events, maxevents, timeout);
}

static inline int epoll_pwait(int epfd, struct epoll_event *events, int maxevents,
                              int timeout, const sigset_t *sigmask) {
  return zsys_epoll_pwait(epfd, events, maxevents, timeout, sigmask);
}

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_EPOLL_H_ */
