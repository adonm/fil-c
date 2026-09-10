/* REAL Camellia_cbc_encrypt DF=1 runs (item 9): the helper in cmll-df.s
 * enters the SARCASM-assembled libcrypto with DF=1 (Fil-C rejects `std`
 * in C inline asm, so the DF comes from assembly, like the old model).
 *
 * - len 0 under DF=1 must NOT trap: `cmp $0,%rdx; je .Lcbc_abort` skips
 *   both residue reps, so no checked rep executes. dst must be untouched
 *   (C assert below).
 * - len 16 under DF=1 must NOT trap either (residue 0: the block loop
 *   runs once and skips the tail), and must produce correct ciphertext:
 *   pinned by a DF=0 encrypt/decrypt round-trip first (proving the DF=0
 *   path copies forward exactly), then the DF=1 len-16 ciphertext must
 *   equal the DF=0 one (C asserts below).
 * - len 8 under DF=1 MUST trap with SIGILL (residue 8 reaches
 *   .Lcbc_enc_tail's checked rep, which observes DF=1): the manifest
 *   expects `crash` with "Illegal instruction".
 */
#include <stdio.h>
/* fflush after every line: the final SIGILL cannot flush a
 * fully-buffered stdout, so without this the harness would lose the
 * proof lines printed before the trap. */
#define EMIT(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
#include <string.h>
#include <openssl/camellia.h>

void cmll_df1_encrypt(const unsigned char *in, unsigned char *out,
    unsigned long len, const CAMELLIA_KEY *key, unsigned char *ivec,
    int enc);

static CAMELLIA_KEY key;

int main() {
    unsigned char userkey[16] =
        {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    static unsigned char iv[16], inb[32], df0out[32], df1out[32], back[32];
    Camellia_set_key(userkey, 128, &key);
    for (int i = 0; i < 32; i++)
        inb[i] = (unsigned char)(i * 3 + 1);

    /* DF=0 reference: encrypt 32 bytes, decrypt back, must round-trip. */
    memset(iv, 0, sizeof iv);
    memset(df0out, 0, sizeof df0out);
    Camellia_cbc_encrypt(inb, df0out, 32, &key, iv, 1);
    memset(iv, 0, sizeof iv);
    memset(back, 0, sizeof back);
    Camellia_cbc_encrypt(df0out, back, 32, &key, iv, 0);
    if (memcmp(back, inb, sizeof inb) != 0) {
        EMIT("cmll df0 roundtrip BAD\n");
        return 1;
    }
    EMIT("cmll df0 roundtrip ok\n");

    /* len 0 under DF=1: abort path, no rep, dst untouched. */
    memset(df1out, 0xAA, sizeof df1out);
    memset(iv, 0, sizeof iv);
    cmll_df1_encrypt(inb, df1out, 0, &key, iv, 1);
    for (int i = 0; i < 32; i++) {
        if (df1out[i] != 0xAA) {
            EMIT("cmll zero-length copy under DF=1 BAD\n");
            return 1;
        }
    }
    EMIT("cmll zero-length copy under DF=1 ok (no trap)\n");

    /* len 16 under DF=1: residue 0, tail skipped, same bytes as DF=0. */
    memset(df1out, 0, sizeof df1out);
    memset(iv, 0, sizeof iv);
    cmll_df1_encrypt(inb, df1out, 16, &key, iv, 1);
    if (memcmp(df1out, df0out, 16) != 0) {
        EMIT("cmll residue-0 copy under DF=1 BAD\n");
        return 1;
    }
    EMIT("cmll residue-0 copy under DF=1 ok (no trap)\n");

    /* len 8 under DF=1: nonzero residue reaches the checked rep: trap. */
    EMIT("cmll tail copy under DF=1 (SHOULD TRAP):\n");
    memset(df1out, 0, sizeof df1out);
    memset(iv, 0, sizeof iv);
    cmll_df1_encrypt(inb, df1out, 8, &key, iv, 1);
    EMIT("NOT REACHED\n");
    return 0;
}
