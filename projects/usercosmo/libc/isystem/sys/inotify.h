#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_INOTIFY_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_INOTIFY_H_
/* Fil-C port: cosmopolitan libc has inotify syscall thunks but no public
   wrapper or header; libpizlo supports the inotify syscalls via zsys_*. */

#include <stdfil.h>
#include <pizlonated_syscalls.h>

/* Linux inotify event bits. */
#define IN_ACCESS        0x00000001u
#define IN_MODIFY        0x00000002u
#define IN_ATTRIB        0x00000004u
#define IN_CLOSE_WRITE   0x00000008u
#define IN_CLOSE_NOWRITE 0x00000010u
#define IN_OPEN          0x00000020u
#define IN_MOVED_FROM    0x00000040u
#define IN_MOVED_TO      0x00000080u
#define IN_CREATE        0x00000100u
#define IN_DELETE        0x00000200u
#define IN_DELETE_SELF   0x00000400u
#define IN_MOVE_SELF     0x00000800u
#define IN_UNMOUNT       0x00002000u
#define IN_Q_OVERFLOW    0x00004000u
#define IN_IGNORED       0x00008000u
#define IN_CLOSE         (IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)
#define IN_MOVE          (IN_MOVED_FROM | IN_MOVED_TO)
#define IN_ALL_EVENTS    (IN_ACCESS | IN_MODIFY | IN_ATTRIB | IN_CLOSE_WRITE | \
                          IN_CLOSE_NOWRITE | IN_OPEN | IN_MOVED_FROM |       \
                          IN_MOVED_TO | IN_CREATE | IN_DELETE |              \
                          IN_DELETE_SELF | IN_MOVE_SELF)
#define IN_ONLYDIR       0x01000000u
#define IN_DONT_FOLLOW   0x02000000u
#define IN_EXCL_UNLINK   0x04000000u
#define IN_MASK_CREATE   0x10000000u
#define IN_MASK_ADD      0x20000000u
#define IN_ISDIR         0x40000000u
#define IN_ONESHOT       0x80000000u

/* inotify_init1() flags. */
#define IN_CLOEXEC  02000000
#define IN_NONBLOCK 04000

struct inotify_event {
  int wd;
  uint32_t mask;
  uint32_t cookie;
  uint32_t len;
  char name[];
};

static inline int inotify_init(void) {
  return zsys_inotify_init();
}

static inline int inotify_init1(int flags) {
  return zsys_inotify_init1(flags);
}

static inline int inotify_add_watch(int fd, const char *pathname, uint32_t mask) {
  return zsys_inotify_add_watch(fd, pathname, mask);
}

static inline int inotify_rm_watch(int fd, int wd) {
  return zsys_inotify_rm_watch(fd, wd);
}

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_INOTIFY_H_ */
