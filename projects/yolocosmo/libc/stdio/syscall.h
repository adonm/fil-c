#ifndef COSMOPOLITAN_LIBC_STDIO_SYSCALL_H_
#define COSMOPOLITAN_LIBC_STDIO_SYSCALL_H_
COSMOPOLITAN_C_START_

/* These are the real Linux (x86_64) system call numbers, matching musl's
   bits/syscall.h. They used to be private translation-layer ordinals for a
   small syscall() shim, but the Fil-C yolocosmo support needs syscall(2) to
   be a raw system call forwarder, which in turn means these constants must
   have their true Linux values. */
#define SYS_gettid    186
#define SYS_getrandom 318
#define SYS_getcpu    309

/* Additional numbers needed by the Fil-C runtime (libpizlo), which calls
   syscall(2) directly for the things musl/glibc expose as C functions. */
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
#define SYS_pidfd_send_signal        424
#define SYS_pidfd_open               434
#define SYS_openat2                  437
#define SYS_pidfd_getfd              438
#define SYS_landlock_create_ruleset  444
#define SYS_landlock_add_rule        445
#define SYS_landlock_restrict_self   446
#define SYS_sendmmsg                 307

long syscall(long, ...) libcesque;

COSMOPOLITAN_C_END_
#endif /* COSMOPOLITAN_LIBC_STDIO_SYSCALL_H_ */
