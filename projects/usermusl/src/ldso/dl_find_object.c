#define _GNU_SOURCE
#include <dlfcn.h>
#include <pizlonated_syscalls.h>

/* dl_find_object(3) is glibc-only; musl has no equivalent. The Fil-C runtime resolves the object
   containing `address` from the loaded-object program headers and fills `result` capability-safely. */
static int static_dl_find_object(void *address, struct dl_find_object *result)
{
	return zsys_dl_find_object(address, result);
}

weak_alias(static_dl_find_object, _dl_find_object);
