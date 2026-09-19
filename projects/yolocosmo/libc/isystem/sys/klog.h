#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_KLOG_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_KLOG_H_
#include "libc/calls/calls.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw syslog
   system call thunk but no <sys/klog.h>. */

int klogctl(int, char *, int);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_KLOG_H_ */
