#ifndef COSMOPOLITAN_LIBC_STDIO_SYSCALL_H_
#define COSMOPOLITAN_LIBC_STDIO_SYSCALL_H_
COSMOPOLITAN_C_START_

/* These are the real Linux system call numbers, matching musl's
   bits/syscall.h. They used to be private translation-layer ordinals for a
   small syscall() shim, but the Fil-C yolocosmo support needs syscall(2) to
   be a raw system call forwarder, which in turn means these constants must
   have their true Linux values.  The numbers below are per-architecture:
   x86_64 uses the classic table, aarch64 uses the asm-generic table (the
   same numbers cosmo's own libc/sysv/calls thunk sources pass to .scall). */
#ifdef __x86_64__
#define SYS_gettid    186
#define SYS_getrandom 318
#define SYS_getcpu    309
#else
#define SYS_gettid    178
#define SYS_getrandom 278
#define SYS_getcpu    168
#endif

/* Additional numbers needed by the Fil-C runtime (libpizlo), which calls
   syscall(2) directly for the things musl/glibc expose as C functions. */
#ifdef __x86_64__
#define SYS_capget                   125
#define SYS_capset                   126
#define SYS_sched_getparam           143
#define SYS_sched_getscheduler       145
#define SYS_modify_ldt               154
#define SYS_pivot_root               155
#define SYS_init_module              175
#define SYS_delete_module            176
#define SYS_sched_getaffinity        204
#define SYS_timer_create             222
#define SYS_timer_settime            223
#define SYS_timer_gettime            224
#define SYS_timer_getoverrun         225
#define SYS_timer_delete             226
#define SYS_set_mempolicy            238
#define SYS_get_mempolicy            239
#define SYS_add_key                  248
#define SYS_request_key              249
#define SYS_keyctl                   250
#define SYS_perf_event_open          298
#define SYS_finit_module             313
#define SYS_renameat2                316
#define SYS_statx                    332
#define SYS_sendmmsg                 307
#else
/* aarch64 has no modify_ldt (it is an x86-specific interface); 245 is in
   the reserved hole block of the asm-generic table, so the kernel reports
   ENOSYS, which is the same thing the syscall would do anyway. */
#define SYS_capget                   90
#define SYS_capset                   91
#define SYS_sched_getparam           121
#define SYS_sched_getscheduler       120
#define SYS_modify_ldt               245
#define SYS_pivot_root               41
#define SYS_init_module              105
#define SYS_delete_module            106
#define SYS_sched_getaffinity        123
#define SYS_timer_create             107
#define SYS_timer_settime            110
#define SYS_timer_gettime            108
#define SYS_timer_getoverrun         109
#define SYS_timer_delete             111
#define SYS_set_mempolicy            237
#define SYS_get_mempolicy            236
#define SYS_add_key                  217
#define SYS_request_key              218
#define SYS_keyctl                   219
#define SYS_perf_event_open          241
#define SYS_finit_module             273
#define SYS_renameat2                276
#define SYS_statx                    291
#define SYS_sendmmsg                 269
#endif

/* Unified numbers (same on every architecture). */
#define SYS_pidfd_send_signal        424
#define SYS_pidfd_open               434
#define SYS_openat2                  437
#define SYS_pidfd_getfd              438
#define SYS_landlock_create_ruleset  444
#define SYS_landlock_add_rule        445
#define SYS_landlock_restrict_self   446

long syscall(long, ...) libcesque;

COSMOPOLITAN_C_END_
#endif /* COSMOPOLITAN_LIBC_STDIO_SYSCALL_H_ */
