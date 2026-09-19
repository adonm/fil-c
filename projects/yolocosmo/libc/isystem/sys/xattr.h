#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_XATTR_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_XATTR_H_
#include "libc/calls/calls.h"
#include "libc/limits.h"

/* This is part of the Fil-C yolocosmo support: cosmo has the raw xattr
   system call thunks but no <sys/xattr.h>. */

#define XATTR_CREATE  1
#define XATTR_REPLACE 2

ssize_t getxattr(const char *, const char *, void *, size_t);
ssize_t lgetxattr(const char *, const char *, void *, size_t);
ssize_t fgetxattr(int, const char *, void *, size_t);
ssize_t listxattr(const char *, char *, size_t);
ssize_t llistxattr(const char *, char *, size_t);
ssize_t flistxattr(int, char *, size_t);
int removexattr(const char *, const char *);
int lremovexattr(const char *, const char *);
int fremovexattr(int, const char *);
int setxattr(const char *, const char *, const void *, size_t, int);
int lsetxattr(const char *, const char *, const void *, size_t, int);
int fsetxattr(int, const char *, const void *, size_t, int);

#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_XATTR_H_ */
