/* Host-compiled (yolo) glue for the usercosmo flavor.
 *
 * This file is compiled by the HOST compiler (not the Fil-C compiler) and
 * fused into pizfix/lib/crt1.o by build_usercosmo.sh.  It exists to provide
 * plain (un-pizlonated) symbols that the yolo side of the final binary —
 * libpizlo.a and libyolort.a, which are yolo code — references but which
 * libyolocosmo.a doesn't define.  It must live in crt1.o (a plain object
 * linked before all archives) because archive members are only pulled on
 * demand: by the time libpizlo.a's reference to these symbols is seen,
 * libc.a has already been scanned without pulling a member defining them.
 *
 * Do NOT add pizlonated-side code here; it would still be yolo code (this
 * file is host-compiled) and would run without any memory safety.
 */

/* libpizlo.a's filc_native_zmath_llrintl() calls llrintl on the raw long
   double.  Cosmo only defines llrintl when long double is 64-bit mantissa
   (MODE=nox87); in optlinux mode long double is x87 80-bit, so nothing
   provides it.  lrintl() rounds per the current rounding mode, which is
   exactly what llrintl does; the long long result only differs for values
   outside long range, where the C behavior is undefined anyway. */
#include <math.h>
long long llrintl(long double x) {
  return lrintl(x);
}
