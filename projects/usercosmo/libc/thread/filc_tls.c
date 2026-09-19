/*-*- mode:c;indent-tabs-mode:nil;c-basic-offset:2;tab-width:8;coding:utf-8     -*-│
│ vi: set noet ft=c ts=2 sts=2 sw=2 fenc=utf-8                             :vi │
╞══════════════════════════════════════════════════════════════════════════════╡
│ Fil-C port of Cosmopolitan libc: pizlonated thread information block.        │
│                                                                              │
│ The Fil-Pizlonator rejects inline asm touching segment registers, so cosmo's │
│ canonical `__get_tls()` (mov %fs:0) can not be used from pizlonated code.    │
│ Under Fil-C, the TIB is simply a `__thread` variable: every pizlonated       │
│ thread (created by pthread_create() → zthread_create2(), or the main thread  │
│ started by __libc_start_main()) automatically gets its own zero-initialized  │
│ copy of this structure, and __get_tls() (see libc/thread/tls.h) hands out    │
│ its address.  There is no kernel TLS setup (set_thread_area/arch_prctl)      │
│ involved anywhere on this side.                                              │
│                                                                              │
│ The yolo (non-pizlonated) part of the process — libpizlo.a and libyolocosmo  │
│ — keeps using the regular kernel TIB at %fs:0 which the yolo boot            │
│ (cosmo() → _init → __enable_tls) installs; the two worlds are independent.   │
╚─────────────────────────────────────────────────────────────────────────────*/
#include "libc/thread/posixthread.internal.h"

__thread struct CosmoTib __filc_tib;

/* tls.h maps __tls_enabled to the constant 1 under __FILC__; here we are
   defining the actual variable, so undo the macro first. */
#undef __tls_enabled

/* The plain (yolo) copy of this flag lives in libc/sysv/hostos.S and gates
 * fast paths in yolo assembly (systemfive.S etc).  Pizlonated code compiles
 * __tls_enabled to a constant 1 (see tls.h), but a few pizlonated translation
 * units still reference the symbol, so provide a Fil-C-land definition of it
 * that is permanently true. */
char __tls_enabled = 1;

/**
 * Wires up the TIB of the current thread.
 *
 * Called by __libc_start_main() (filc_libc_start_main.c) for the main thread
 * and by the pthread_create() trampoline for spawned threads, since each
 * pizlonated thread starts with a fresh zero-initialized __filc_tib.
 */
void *__filc_init_tib(struct PosixThread *pt) {
  __filc_tib.tib_self = &__filc_tib;
  __filc_tib.tib_self2 = &__filc_tib;
  __filc_tib.tib_pthread = pt;
  return &__filc_tib;
}
