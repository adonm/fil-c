#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_EPOLL_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_EPOLL_H_
#include "libc/calls/calls.h"
#include "libc/calls/struct/sigset.h"
#include "libc/calls/struct/timespec.h"
#include "libc/calls/weirdtypes.h"

/* This is part of the Fil-C yolocosmo support: cosmo has raw epoll system
   call thunks but no <sys/epoll.h>, and the Fil-C runtime needs the real
   Linux ABI (the struct is `packed` on x86 so `data` sits at offset 4). */

#ifndef EPOLL_PACKED
#define EPOLL_PACKED __attribute__((__packed__))
#endif

enum EPOLL_EVENTS {
  EPOLLIN = 0x001,
#define EPOLLIN EPOLLIN
  EPOLLPRI = 0x002,
#define EPOLLPRI EPOLLPRI
  EPOLLOUT = 0x004,
#define EPOLLOUT EPOLLOUT
  EPOLLRDNORM = 0x040,
#define EPOLLRDNORM EPOLLRDNORM
  EPOLLRDBAND = 0x080,
#define EPOLLRDBAND EPOLLRDBAND
  EPOLLWRNORM = 0x100,
#define EPOLLWRNORM EPOLLWRNORM
  EPOLLWRBAND = 0x200,
#define EPOLLWRBAND EPOLLWRBAND
  EPOLLMSG = 0x400,
#define EPOLLMSG EPOLLMSG
  EPOLLERR = 0x008,
#define EPOLLERR EPOLLERR
  EPOLLHUP = 0x010,
#define EPOLLHUP EPOLLHUP
  EPOLLRDHUP = 0x2000,
#define EPOLLRDHUP EPOLLRDHUP
  EPOLLEXCLUSIVE = 0x10000000,
#define EPOLLEXCLUSIVE EPOLLEXCLUSIVE
  EPOLLWAKEUP = 0x20000000,
#define EPOLLWAKEUP EPOLLWAKEUP
  EPOLLONESHOT = 0x40000000,
#define EPOLLONESHOT EPOLLONESHOT
  EPOLLET = 0x80000000,
#define EPOLLET EPOLLET
};

#define EPOLL_CTL_ADD 1
#define EPOLL_CTL_DEL 2
#define EPOLL_CTL_MOD 3

typedef union epoll_data {
  void *ptr;
  int fd;
  uint32_t u32;
  uint64_t u64;
} epoll_data_t;

struct epoll_event {
  uint32_t events; /* Epoll events */
  epoll_data_t data; /* User data variable */
} EPOLL_PACKED;

int epoll_create(int);
int epoll_create1(int);
int epoll_ctl(int, int, int, struct epoll_event *);
int epoll_wait(int, struct epoll_event *, int, int);
int epoll_pwait(int, struct epoll_event *, int, int, const sigset_t *);
int epoll_pwait2(int, struct epoll_event *, int, const struct timespec *,
                 const sigset_t *);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_EPOLL_H_ */
