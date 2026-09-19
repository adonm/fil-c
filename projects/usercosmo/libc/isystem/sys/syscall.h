#ifndef COSMOPOLITAN_LIBC_ISYSTEM_SYS_SYSCALL_H_
#define COSMOPOLITAN_LIBC_ISYSTEM_SYS_SYSCALL_H_
#include "libc/stdio/syscall.h"
#ifdef __FILC__
/* Fil-C port: the test suite (and portable Linux code) uses the Linux SYS_*
   numbers with syscall(2).  cosmo's sys/syscall.h defines only three
   cosmo-ism ordinals (SYS_gettid=1, SYS_getrandom=2, SYS_getcpu=3), which
   collide with the real Linux numbers (write=1, ...); replace them with the
   real Linux x86_64 values, matching what the musl flavor exposes. */
#undef SYS_gettid
#undef SYS_getrandom
#undef SYS_getcpu
#define SYS_gettid           186
#define SYS_getrandom        318
#define SYS_getcpu           309
#define SYS_write            1
#define SYS_read             0
#define SYS_futex            202
#define SYS_getdents64       217
#define SYS_statx            332
#define SYS_copy_file_range  326
#define SYS_openat2          437
#endif
#endif /* COSMOPOLITAN_LIBC_ISYSTEM_SYS_SYSCALL_H_ */
