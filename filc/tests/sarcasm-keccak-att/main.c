#include <stdio.h>
#include <string.h>

size_t SHA3_absorb(unsigned char A[200], const unsigned char* in, size_t len, size_t r);
void SHA3_squeeze(unsigned char A[200], unsigned char* out, size_t len, size_t r, int next);

/* SHA3-256("abc") — the keccak1600 bounce-buffer permutation (a loop-carried
   pointer swap between the state and the bounce buffer, xchg'd every round). */
int main()
{
    static const unsigned char expect[32] = {
        0x3a,0x98,0x5d,0xa7,0x4f,0xe2,0x25,0xb2,0x04,0x5c,0x17,0x2d,0x6b,0xd3,0x90,0xbd,
        0x85,0x5f,0x08,0x6e,0x3e,0x9d,0x52,0x5b,0x46,0xbf,0xe2,0x45,0x11,0x43,0x15,0x32
    };
    unsigned char A[200];
    unsigned char out[32];
    unsigned char blk[136];
    memset(A, 0, sizeof(A));
    memset(blk, 0, sizeof(blk));
    memcpy(blk, "abc", 3);
    blk[3] = 0x06;          /* SHA3 domain separation */
    blk[135] = 0x80;        /* pad10*1 */
    SHA3_absorb(A, blk, sizeof(blk), sizeof(blk));
    SHA3_squeeze(A, out, 32, sizeof(blk), 0);
    if (memcmp(out, expect, 32)) {
        printf("FAIL sha3-256(abc): ");
        for (int i = 0; i < 32; i++) printf("%02x", out[i]);
        printf("\n");
        return 1;
    }
    printf("keccak att ok\n");
    return 0;
}
