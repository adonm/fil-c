#ifndef _UNISTD_H
#define _UNISTD_H
#include "libc/calls/calls.h"
#include "libc/calls/weirdtypes.h"
#include "libc/runtime/pathconf.h"
#include "libc/runtime/runtime.h"
#include "libc/runtime/sysconf.h"
#include "libc/sysv/consts/f.h"
#include "libc/sysv/consts/fileno.h"
#include "libc/sysv/consts/l.h"
#include "libc/sysv/consts/o.h"
#include "libc/sysv/consts/ok.h"
#include "libc/time.h"
#include "libc/unistd.h"
#include "third_party/getopt/long1.h"
#include "third_party/musl/crypt.h"
#include "third_party/musl/lockf.h"

/* Fil-C addition: setdomainname(2), which musl/glibc provide. The function
   is defined by the yolocosmo patch in libc/calls/yolo_syscall_wrappers.c. */
int setdomainname(const char *, size_t);
int sethostname(const char *, size_t);
int acct(const char *);
int vhangup(void);
#endif /* _UNISTD_H */
