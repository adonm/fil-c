#! /usr/bin/env perl
# Copyright 2005-2026 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the Apache License 2.0 (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html


# Ascetic x86_64 AT&T to MASM/NASM assembler translator by <@dot-asm>.
#
# Why AT&T to MASM and not vice versa? Several reasons. Because AT&T
# format is way easier to parse. Because it's simpler to "gear" from
# Unix ABI to Windows one [see cross-reference "card" at the end of
# file]. Because Linux targets were available first...
#
# In addition the script also "distills" code suitable for GNU
# assembler, so that it can be compiled with more rigid assemblers,
# such as Solaris /usr/ccs/bin/as.
#
# This translator is not designed to convert *arbitrary* assembler
# code from AT&T format to MASM one. It's designed to convert just
# enough to provide for dual-ABI OpenSSL modules development...
# There *are* limitations and you might have to modify your assembler
# code or this script to achieve the desired result...
#
# Currently recognized limitations:
#
# - can't use multiple ops per line;
#
# Dual-ABI styling rules.
#
# 1. Adhere to Unix register and stack layout [see cross-reference
#    ABI "card" at the end for explanation].
# 2. Forget about "red zone," stick to more traditional blended
#    stack frame allocation. If volatile storage is actually required
#    that is. If not, just leave the stack as is.
# 3. Functions tagged with ".type name,@function" get crafted with
#    unified Win64 prologue and epilogue automatically. If you want
#    to take care of ABI differences yourself, tag functions as
#    ".type name,@abi-omnipotent" instead.
# 4. To optimize the Win64 prologue you can specify number of input
#    arguments as ".type name,@function,N." Keep in mind that if N is
#    larger than 6, then you *have to* write "abi-omnipotent" code,
#    because >6 cases can't be addressed with unified prologue.
# 5. Name local labels as .L*, do *not* use dynamic labels such as 1:
#    (sorry about latter).
# 6. Don't use [or hand-code with .byte] "rep ret." "ret" mnemonic is
#    required to identify the spots, where to inject Win64 epilogue!
#    But on the pros, it's then prefixed with rep automatically:-)
# 7. Stick to explicit ip-relative addressing. If you have to use
#    GOTPCREL addressing, stick to mov symbol@GOTPCREL(%rip),%r??.
#    Both are recognized and translated to proper Win64 addressing
#    modes.
#
# 8. In order to provide for structured exception handling unified
#    Win64 prologue copies %rsp value to %rax. For further details
#    see SEH paragraph at the end.
# 9. .init segment is allowed to contain calls to functions only.
# a. If function accepts more than 4 arguments *and* >4th argument
#    is declared as non 64-bit value, do clear its upper part.


use strict;

my $flavour = shift;
my $output  = shift;
if ($flavour =~ /\./) { $output = $flavour; undef $flavour; }

open STDOUT,">$output" || die "can't open $output: $!"
	if (defined($output));

my $gas=1;	$gas=0 if ($output =~ /\.asm$/);
my $elf=1;	$elf=0 if (!$gas);
my $win64=0;
my $prefix="";
my $decor=".L";

my $masmref=8 + 50727*2**-32;	# 8.00.50727 shipped with VS2005
my $masm=0;
my $PTR=" PTR";

my $nasmref=2.03;
my $nasm=0;

# GNU as indicator, as opposed to $gas, which indicates acceptable
# syntax
my $gnuas=0;

if    ($flavour eq "mingw64")	{ $gas=1; $elf=0; $win64=1;
				  $prefix=`echo __USER_LABEL_PREFIX__ | $ENV{CC} -E -P -`;
				  $prefix =~ s|\R$||; # Better chomp
				}
elsif ($flavour eq "macosx")	{ $gas=1; $elf=0; $prefix="_"; $decor="L\$"; }
elsif ($flavour eq "masm")	{ $gas=0; $elf=0; $masm=$masmref; $win64=1; $decor="\$L\$"; }
elsif ($flavour eq "nasm")	{ $gas=0; $elf=0; $nasm=$nasmref; $win64=1; $decor="\$L\$"; $PTR=""; }
elsif (!$gas)
{   if ($ENV{ASM} =~ m/nasm/ && `nasm -v` =~ m/version ([0-9]+)\.([0-9]+)/i)
    {	$nasm = $1 + $2*0.01; $PTR="";  }
    elsif (`ml64 2>&1` =~ m/Version ([0-9]+)\.([0-9]+)(\.([0-9]+))?/)
    {	$masm = $1 + $2*2**-16 + $4*2**-32;   }
    die "no assembler found on %PATH%" if (!($nasm || $masm));
    $win64=1;
    $elf=0;
    $decor="\$L\$";
}
# Find out if we're using GNU as
elsif (`$ENV{CC} -Wa,-v -c -o /dev/null -x assembler /dev/null 2>&1`
		=~ /GNU assembler version ([2-9]\.[0-9]+)/)
{
    $gnuas=1;
}
elsif (`$ENV{CC} --version 2>/dev/null`
		=~ /(clang .*|Intel.*oneAPI .*)/)
{
    $gnuas=1;
}
elsif (`$ENV{CC} -V 2>/dev/null`
		=~ /nvc .*/)
{
    $gnuas=1;
}

########################################################################
# Sarcasm (Fil-C memory-safe assembler) support.
#
# %SARCASM_SIGS maps every exported asm function name to its sarcasm
# entry signature. When generating gas output, the signature is
# emitted as a gas comment of the form `#! <sig>` on the function's
# entry label (see label::out) and on direct call sites that target a
# name in this table (see the main loop). Local subroutines are
# deliberately absent from the table: sarcasm auto-discovers them, so
# their call sites must stay unannotated. The padlock entries at the
# end are harmless when the padlock engine is not built.
my %SARCASM_SIGS = (
    "AES_cbc_encrypt"                   => "void(ptr,ptr,size_t,ptr,ptr,int)",
    "AES_decrypt"                       => "void(ptr,ptr,ptr)",
    "AES_encrypt"                       => "void(ptr,ptr,ptr)",
    "AES_set_decrypt_key"               => "int(ptr,int,ptr)",
    "AES_set_encrypt_key"               => "int(ptr,int,ptr)",
    "asm_AES_cbc_encrypt"               => "void(ptr,ptr,size_t,ptr,ptr,int)",
    "asm_AES_decrypt"                   => "void(ptr,ptr,ptr)",
    "asm_AES_encrypt"                   => "void(ptr,ptr,ptr)",
    "CRYPTO_memcmp"                     => "int(ptr,ptr,size_t)",
    "Camellia_DecryptBlock"             => "void(int,ptr,ptr,ptr)",
    "Camellia_DecryptBlock_Rounds"      => "void(int,ptr,ptr,ptr)",
    "Camellia_EncryptBlock"             => "void(int,ptr,ptr,ptr)",
    "Camellia_EncryptBlock_Rounds"      => "void(int,ptr,ptr,ptr)",
    "Camellia_Ekeygen"                  => "int(int,ptr,ptr)",
    "Camellia_cbc_encrypt"              => "void(ptr,ptr,size_t,ptr,ptr,int)",
    "ChaCha20_ctr32"                    => "void(ptr,ptr,size_t,ptr,ptr)",
    # File-local ISA-variant bodies (chacha-x86_64.pl): B1 tail jumps
    # from ChaCha20_ctr32 / each other.
    "ChaCha20_ssse3"                    => "void(ptr,ptr,size_t,ptr,ptr)",
    "ChaCha20_128"                      => "void(ptr,ptr,size_t,ptr,ptr)",
    "ChaCha20_4x"                       => "void(ptr,ptr,size_t,ptr,ptr)",
    "ChaCha20_4xop"                     => "void(ptr,ptr,size_t,ptr,ptr)",
    "ChaCha20_8x"                       => "void(ptr,ptr,size_t,ptr,ptr)",
    "OPENSSL_atomic_add"                => "int(ptr,int)",
    "OPENSSL_cleanse"                   => "void(ptr,size_t)",
    "OPENSSL_cpuid_setup"               => "void()",
    "OPENSSL_ia32_cpuid"                => "unsigned(ptr)",
    "OPENSSL_ia32_rdrand_bytes"         => "size_t(ptr,size_t)",
    "OPENSSL_ia32_rdseed_bytes"         => "size_t(ptr,size_t)",
    "OPENSSL_instrument_bus"            => "size_t(ptr,size_t)",
    "OPENSSL_instrument_bus2"           => "size_t(ptr,size_t,size_t)",
    "OPENSSL_rdtsc"                     => "unsigned()",
    "RC4"                               => "void(ptr,size_t,ptr,ptr)",
    "RC4_options"                       => "ptr()",
    "RC4_set_key"                       => "void(ptr,int,ptr)",
    "SHA3_absorb"                       => "size_t(ptr,ptr,size_t,size_t)",
    "SHA3_squeeze"                      => "void(ptr,ptr,size_t,size_t,int)",
    # File-local (not .globl) round function in keccak1600-x86_64.pl:
    # called only by SHA3_squeeze, in a loop. As a local subroutine its
    # clone would be re-entered by that loop, and its save/restore of
    # registers it redefines cannot be modeled across the re-entry; as a
    # signatured function the call is an ordinary call boundary.
    "KeccakF1600"                       => "void(ptr)",
    "aesni_cbc_encrypt"                 => "void(ptr,ptr,size_t,ptr,ptr,int)",
    "aesni_cbc_sha1_enc"                => "void(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_cbc_sha256_enc"              => "int(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_ccm64_decrypt_blocks"        => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_ccm64_encrypt_blocks"        => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_ctr32_encrypt_blocks"        => "void(ptr,ptr,size_t,ptr,ptr)",
    "aesni_decrypt"                     => "void(ptr,ptr,ptr)",
    "aesni_ecb_encrypt"                 => "void(ptr,ptr,size_t,ptr,int)",
    "aesni_encrypt"                     => "void(ptr,ptr,ptr)",
    "aesni_gcm_decrypt"                 => "size_t(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_gcm_encrypt"                 => "size_t(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_multi_cbc_decrypt"           => "void(ptr,ptr,int)",
    "aesni_multi_cbc_encrypt"           => "void(ptr,ptr,int)",
    "aesni_ocb_decrypt"                 => "void(ptr,ptr,size_t,ptr,size_t,ptr,ptr,ptr)",
    "aesni_ocb_encrypt"                 => "void(ptr,ptr,size_t,ptr,size_t,ptr,ptr,ptr)",
    "aesni_set_decrypt_key"             => "int(ptr,int,ptr)",
    "aesni_set_encrypt_key"             => "int(ptr,int,ptr)",
    # File-local ISA-variant bodies of aesni_cbc_sha1_enc /
    # aesni_cbc_sha256_enc (aesni-sha1-x86_64.pl / aesni-sha256-x86_64.pl):
    # entered via B1 tail jumps from the dispatchers.
    "aesni_cbc_sha1_enc_shaext"         => "void(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_cbc_sha1_enc_avx"            => "void(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_cbc_sha1_enc_ssse3"          => "void(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_cbc_sha256_enc_shaext"       => "int(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_cbc_sha256_enc_xop"          => "int(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_cbc_sha256_enc_avx"          => "int(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    "aesni_cbc_sha256_enc_avx2"         => "int(ptr,ptr,size_t,ptr,ptr,ptr,ptr)",
    # File-local AVX bodies of aesni_multi_cbc_{encrypt,decrypt}
    # (aesni-mb-x86_64.pl): B1 tail jumps from the dispatchers.
    "aesni_multi_cbc_encrypt_avx"       => "void(ptr,ptr,int)",
    "aesni_multi_cbc_decrypt_avx"       => "void(ptr,ptr,int)",
    "aesni_xts_128_decrypt_avx512"      => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_xts_128_encrypt_avx512"      => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_xts_256_decrypt_avx512"      => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_xts_256_encrypt_avx512"      => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_xts_avx512_eligible"         => "int()",
    "aesni_xts_decrypt"                 => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "aesni_xts_encrypt"                 => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "bn_GF2m_mul_2x2"                   => "void(ptr,long,long,long,long)",
    "bn_gather5"                        => "void(ptr,size_t,ptr,size_t)",
    "bn_get_bits5"                      => "int(ptr,int)",
    # File-local ISA-variant bodies (x86_64-mont.pl): .type'd but not
    # .globl; entered via B1 tail jumps from bn_mul_mont (and from each
    # other). Same signature as bn_mul_mont.
    "bn_mul4x_mont"                     => "int(ptr,ptr,ptr,ptr,ptr,int)",
    "bn_sqr8x_mont"                     => "int(ptr,ptr,ptr,ptr,ptr,int)",
    "bn_mulx4x_mont"                    => "int(ptr,ptr,ptr,ptr,ptr,int)",
    "bn_mul_mont"                       => "int(ptr,ptr,ptr,ptr,ptr,int)",
    "bn_mul_mont_gather5"               => "void(ptr,ptr,ptr,ptr,ptr,int,int)",
    # File-local ISA-variant bodies (x86_64-mont5.pl): B1 tail jumps
    # from bn_mul_mont_gather5/bn_power5. Same signature as those.
    "bn_mul4x_mont_gather5"             => "void(ptr,ptr,ptr,ptr,ptr,int,int)",
    "bn_mulx4x_mont_gather5"            => "void(ptr,ptr,ptr,ptr,ptr,int,int)",
    "bn_powerx5"                        => "void(ptr,ptr,ptr,ptr,ptr,int,int)",
    "bn_power5"                         => "void(ptr,ptr,ptr,ptr,ptr,int,int)",
    "bn_scatter5"                       => "void(ptr,size_t,ptr,size_t)",
    "bn_sqr8x_internal"                 => "void(ptr,ptr,ptr,ptr,ptr,int)",
    "bn_sqrx8x_internal"                => "void(ptr,ptr,ptr,ptr,ptr,int)",
    "ecp_nistz256_add"                  => "void(ptr,ptr,ptr)",
    "ecp_nistz256_avx2_gather_w7"       => "void(ptr,ptr,int)",
    "ecp_nistz256_div_by_2"             => "void(ptr,ptr)",
    "ecp_nistz256_from_mont"            => "void(ptr,ptr)",
    "ecp_nistz256_gather_w5"            => "void(ptr,ptr,int)",
    "ecp_nistz256_gather_w7"            => "void(ptr,ptr,int)",
    "ecp_nistz256_mul_by_2"             => "void(ptr,ptr)",
    "ecp_nistz256_mul_by_3"             => "void(ptr,ptr)",
    "ecp_nistz256_mul_mont"             => "void(ptr,ptr,ptr)",
    "ecp_nistz256_neg"                  => "void(ptr,ptr)",
    "ecp_nistz256_ord_mul_mont"         => "void(ptr,ptr,ptr)",
    "ecp_nistz256_ord_sqr_mont"         => "void(ptr,ptr,long)",
    # File-local "x" (ADX/BMI2) variant bodies
    # (ecp_nistz256-x86_64.pl): entered via B1 tail jumps from the base
    # functions; same signatures as their bases.
    "ecp_nistz256_ord_mul_montx"        => "void(ptr,ptr,ptr)",
    "ecp_nistz256_ord_sqr_montx"        => "void(ptr,ptr,long)",
    "ecp_nistz256_avx2_gather_w5"       => "void(ptr,ptr,int)",
    "ecp_nistz256_point_doublex"        => "void(ptr,ptr)",
    "ecp_nistz256_point_addx"           => "void(ptr,ptr,ptr)",
    "ecp_nistz256_point_add_affinex"    => "void(ptr,ptr,ptr)",
    "ecp_nistz256_point_add"            => "void(ptr,ptr,ptr)",
    "ecp_nistz256_point_add_affine"     => "void(ptr,ptr,ptr)",
    "ecp_nistz256_point_double"         => "void(ptr,ptr)",
    "ecp_nistz256_scatter_w5"           => "void(ptr,ptr,int)",
    "ecp_nistz256_scatter_w7"           => "void(ptr,ptr,int)",
    "ecp_nistz256_sqr_mont"             => "void(ptr,ptr)",
    "ecp_nistz256_sub"                  => "void(ptr,ptr,ptr)",
    "ecp_nistz256_to_mont"              => "void(ptr,ptr)",
    "gcm_ghash_4bit"                    => "void(ptr,ptr,ptr,size_t)",
    "gcm_ghash_avx"                     => "void(ptr,ptr,ptr,size_t)",
    "gcm_ghash_clmul"                   => "void(ptr,ptr,ptr,size_t)",
    "gcm_gmult_4bit"                    => "void(ptr,ptr)",
    "gcm_gmult_avx"                     => "void(ptr,ptr)",
    "gcm_gmult_clmul"                   => "void(ptr,ptr)",
    "gcm_init_avx"                      => "void(ptr,ptr)",
    "gcm_init_clmul"                    => "void(ptr,ptr)",
    "hw_x86_64_sm4_decrypt"             => "void(ptr,ptr,ptr)",
    "hw_x86_64_sm4_encrypt"             => "void(ptr,ptr,ptr)",
    "hw_x86_64_sm4_set_key"             => "int(ptr,ptr)",
    "ossl_aes_cfb128_vaes_dec"          => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "ossl_aes_cfb128_vaes_eligible"     => "int()",
    "ossl_aes_cfb128_vaes_enc"          => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "ossl_aes_gcm_decrypt_avx512"       => "void(ptr,ptr,ptr,ptr,size_t,ptr)",
    "ossl_aes_gcm_encrypt_avx512"       => "void(ptr,ptr,ptr,ptr,size_t,ptr)",
    "ossl_aes_gcm_finalize_avx512"      => "void(ptr,unsigned)",
    "ossl_aes_gcm_init_avx512"          => "void(ptr,ptr)",
    "ossl_aes_gcm_setiv_avx512"         => "void(ptr,ptr,ptr,size_t)",
    "ossl_aes_gcm_update_aad_avx512"    => "void(ptr,ptr,size_t)",
    "ossl_bsaes_cbc_encrypt"            => "void(ptr,ptr,size_t,ptr,ptr,int)",
    "ossl_bsaes_ctr32_encrypt_blocks"   => "void(ptr,ptr,size_t,ptr,ptr)",
    "ossl_bsaes_xts_decrypt"            => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "ossl_bsaes_xts_encrypt"            => "void(ptr,ptr,size_t,ptr,ptr,ptr)",
    "ossl_extract_multiplier_2x20_win5" => "void(ptr,ptr,int,int)",
    "ossl_extract_multiplier_2x20_win5_avx"=> "void(ptr,ptr,int,int)",
    "ossl_extract_multiplier_2x30_win5" => "void(ptr,ptr,int,int)",
    "ossl_extract_multiplier_2x30_win5_avx"=> "void(ptr,ptr,int,int)",
    "ossl_extract_multiplier_2x40_win5" => "void(ptr,ptr,int,int)",
    "ossl_extract_multiplier_2x40_win5_avx"=> "void(ptr,ptr,int,int)",
    "ossl_gcm_gmult_avx512"             => "void(ptr,ptr)",
    "ossl_hwsm3_block_data_order"       => "void(ptr,ptr,size_t)",
    "ossl_md5_block_asm_data_order"     => "void(ptr,ptr,size_t)",
    "ossl_rsaz_avx512ifma_eligible"     => "int()",
    "ossl_rsaz_avxifma_eligible"        => "int()",
    "ossl_rsaz_amm52x20_x1_avxifma256"  => "void(ptr,ptr,ptr,ptr,long)",
    "ossl_rsaz_amm52x20_x1_ifma256"     => "void(ptr,ptr,ptr,ptr,long)",
    "ossl_rsaz_amm52x20_x2_avxifma256"  => "void(ptr,ptr,ptr,ptr,ptr)",
    "ossl_rsaz_amm52x20_x2_ifma256"     => "void(ptr,ptr,ptr,ptr,ptr)",
    "ossl_rsaz_amm52x30_x1_avxifma256"  => "void(ptr,ptr,ptr,ptr,long)",
    "ossl_rsaz_amm52x30_x1_ifma256"     => "void(ptr,ptr,ptr,ptr,long)",
    "ossl_rsaz_amm52x30_x2_avxifma256"  => "void(ptr,ptr,ptr,ptr,ptr)",
    "ossl_rsaz_amm52x30_x2_ifma256"     => "void(ptr,ptr,ptr,ptr,ptr)",
    "ossl_rsaz_amm52x40_x1_avxifma256"  => "void(ptr,ptr,ptr,ptr,long)",
    "ossl_rsaz_amm52x40_x1_ifma256"     => "void(ptr,ptr,ptr,ptr,long)",
    "ossl_rsaz_amm52x40_x2_avxifma256"  => "void(ptr,ptr,ptr,ptr,ptr)",
    "ossl_rsaz_amm52x40_x2_ifma256"     => "void(ptr,ptr,ptr,ptr,ptr)",
    "ossl_vaes_vpclmulqdq_capable"      => "int()",
    "poly1305_blocks"                   => "void(ptr,ptr,size_t,unsigned)",
    "poly1305_emit"                     => "void(ptr,ptr,ptr)",
    "poly1305_init"                     => "int(ptr,ptr,ptr)",
    # File-local ISA-variant bodies (poly1305-x86_64.pl): B1 tail jumps
    # from poly1305_blocks/poly1305_emit.
    "poly1305_blocks_avx"               => "void(ptr,ptr,size_t,unsigned)",
    "poly1305_blocks_avx2"              => "void(ptr,ptr,size_t,unsigned)",
    "poly1305_emit_avx"                 => "void(ptr,ptr,ptr)",
    "rc4_md5_enc"                       => "void(ptr,ptr,ptr,ptr,ptr,size_t)",
    "rsaz_1024_gather5_avx2"            => "void(ptr,ptr,int)",
    "rsaz_1024_mul_avx2"                => "void(ptr,ptr,ptr,ptr,long)",
    "rsaz_1024_norm2red_avx2"           => "void(ptr,ptr)",
    "rsaz_1024_red2norm_avx2"           => "void(ptr,ptr)",
    "rsaz_1024_scatter5_avx2"           => "void(ptr,ptr,int)",
    "rsaz_1024_sqr_avx2"                => "void(ptr,ptr,ptr,long,int)",
    "rsaz_512_gather4"                  => "void(ptr,ptr,int)",
    "rsaz_512_mul"                      => "void(ptr,ptr,ptr,ptr,long)",
    "rsaz_512_mul_by_one"               => "void(ptr,ptr,ptr,long)",
    "rsaz_512_mul_gather4"              => "void(ptr,ptr,ptr,ptr,long,unsigned)",
    "rsaz_512_mul_scatter4"             => "void(ptr,ptr,ptr,long,ptr,unsigned)",
    "rsaz_512_scatter4"                 => "void(ptr,ptr,int)",
    "rsaz_512_sqr"                      => "void(ptr,ptr,ptr,long,int)",
    "rsaz_avx2_eligible"                => "int()",
    "sha1_block_data_order"             => "void(ptr,ptr,size_t)",
    "sha1_multi_block"                  => "void(ptr,ptr,int)",
    "sha256_block_data_order"           => "void(ptr,ptr,size_t)",
    "sha256_multi_block"                => "void(ptr,ptr,int)",
    "sha512_block_data_order"           => "void(ptr,ptr,size_t)",
    # File-local ISA-variant bodies (sha1-x86_64.pl, sha512-x86_64.pl,
    # sha1-mb-x86_64.pl, sha256-mb-x86_64.pl): entered via B1 tail jumps
    # from the dispatchers; same signatures as their dispatchers.
    "sha1_block_data_order_shaext"      => "void(ptr,ptr,size_t)",
    "sha1_block_data_order_ssse3"       => "void(ptr,ptr,size_t)",
    "sha1_block_data_order_avx"         => "void(ptr,ptr,size_t)",
    "sha1_block_data_order_avx2"        => "void(ptr,ptr,size_t)",
    "sha256_block_data_order_shaext"    => "void(ptr,ptr,size_t)",
    "sha256_block_data_order_ssse3"     => "void(ptr,ptr,size_t)",
    "sha256_block_data_order_avx"       => "void(ptr,ptr,size_t)",
    "sha256_block_data_order_avx2"      => "void(ptr,ptr,size_t)",
    "sha512_block_data_order_sha512ext" => "void(ptr,ptr,size_t)",
    "sha512_block_data_order_xop"       => "void(ptr,ptr,size_t)",
    "sha512_block_data_order_avx"       => "void(ptr,ptr,size_t)",
    "sha512_block_data_order_avx2"      => "void(ptr,ptr,size_t)",
    "sha1_multi_block_shaext"           => "void(ptr,ptr,int)",
    "sha1_multi_block_avx"              => "void(ptr,ptr,int)",
    "sha1_multi_block_avx2"             => "void(ptr,ptr,int)",
    "sha256_multi_block_shaext"         => "void(ptr,ptr,int)",
    "sha256_multi_block_avx"            => "void(ptr,ptr,int)",
    "sha256_multi_block_avx2"           => "void(ptr,ptr,int)",
    "vpaes_cbc_encrypt"                 => "void(ptr,ptr,size_t,ptr,ptr,int)",
    "vpaes_decrypt"                     => "void(ptr,ptr,ptr)",
    "vpaes_encrypt"                     => "void(ptr,ptr,ptr)",
    "vpaes_set_decrypt_key"             => "int(ptr,int,ptr)",
    "vpaes_set_encrypt_key"             => "int(ptr,int,ptr)",
    "whirlpool_block"                   => "void(ptr,ptr,size_t)",
    "x25519_fe51_mul"                   => "void(ptr,ptr,ptr)",
    "x25519_fe51_mul121666"             => "void(ptr,ptr)",
    "x25519_fe51_sqr"                   => "void(ptr,ptr)",
    "x25519_fe64_add"                   => "void(ptr,ptr,ptr)",
    "x25519_fe64_eligible"              => "int()",
    "x25519_fe64_mul"                   => "void(ptr,ptr,ptr)",
    "x25519_fe64_mul121666"             => "void(ptr,ptr)",
    "x25519_fe64_sqr"                   => "void(ptr,ptr)",
    "x25519_fe64_sub"                   => "void(ptr,ptr,ptr)",
    "x25519_fe64_tobytes"               => "void(ptr,ptr)",
    "xor128_decrypt_n_pad"              => "ptr(ptr,ptr,ptr,size_t)",
    "xor128_encrypt_n_pad"              => "ptr(ptr,ptr,ptr,size_t)",
    "padlock_capability"                => "unsigned()",
    "padlock_key_bswap"                 => "void(ptr)",
    "padlock_verify_context"            => "void(ptr)",
    "padlock_reload_key"                => "void()",
    "padlock_aes_block"                 => "void(ptr,ptr,ptr)",
    "padlock_ecb_encrypt"               => "int(ptr,ptr,ptr,size_t)",
    "padlock_cbc_encrypt"               => "int(ptr,ptr,ptr,size_t)",
    "padlock_cfb_encrypt"               => "int(ptr,ptr,ptr,size_t)",
    "padlock_ofb_encrypt"               => "int(ptr,ptr,ptr,size_t)",
    "padlock_ctr32_encrypt"             => "int(ptr,ptr,ptr,size_t)",
    "padlock_xstore"                    => "int(ptr,int)",
    "padlock_sha1_oneshot"              => "void(ptr,ptr,size_t)",
    "padlock_sha1_blocks"               => "void(ptr,ptr,size_t)",
    "padlock_sha256_oneshot"            => "void(ptr,ptr,size_t)",
    "padlock_sha256_blocks"             => "void(ptr,ptr,size_t)",
    "padlock_sha512_blocks"             => "void(ptr,ptr,size_t)",
);

# Number of arguments in a sarcasm signature string.
sub sarcasm_sig_narg {
    my $sig = shift;
    my ($args) = $sig =~ /\((.*)\)/;
    return 0 if (!defined($args) || $args eq "");
    return scalar(() = $args =~ /,/g) + 1;
}

# Set in the main loop when the current input line carried an explicit
# `#!` annotation; suppresses signature injection on that line's label
# (explicit annotation beats the injected one).
my $line_has_sarcasm_ann = 0;


my $cet_property;
if ($flavour =~ /elf/) {
	# Always generate .note.gnu.property section for ELF outputs to
	# mark Intel CET support since all input files must be marked
	# with Intel CET support in order for linker to mark output with
	# Intel CET support.
	my $p2align=3; $p2align=2 if ($flavour eq "elf32");
	my $section='.note.gnu.property, #alloc';
	$section='".note.gnu.property", "a"' if $gnuas;
	$cet_property = <<_____;
	.section $section
	.p2align $p2align
	.long 1f - 0f
	.long 4f - 1f
	.long 5
0:
	# "GNU" encoded with .byte, since .asciz isn't supported
	# on Solaris.
	.byte 0x47
	.byte 0x4e
	.byte 0x55
	.byte 0
1:
	.p2align $p2align
	.long 0xc0000002
	.long 3f - 2f
2:
	.long 3
3:
	.p2align $p2align
4:
_____
}

my $current_segment;
#
# I could not find equivalent of .previous directive for MASM (Microsoft
# assembler ML). Using of .previous got introduced to .pl files with
# placing of various constants into .rodata sections (segments).
# Each .rodata section is terminated by .previous directive which
# restores the preceding section to .rodata:
#
# .text
# 	; this is is the text section/segment
# .rodata
#	; constant definitions go here
# .previous
#	; the .text section which precedes .rodata got restored here
#
# The equivalent form for masm reads as follows:
#
# .text$	SEGMENT ALIGN(256) 'CODE'
# 	; this is is the text section/segment
# .text$	ENDS
# .rdata	SEGMENT READONLY ALIGN(64)
#	; constant definitions go here
# .rdata$	ENDS
# .text$	SEGMENT ALIGN(256) 'CODE'
#	; text section follows
# .text$	ENDS
#
# The .previous directive typically terminates .roadata segments/sections which
# hold definitions of constants. In order to place constants into .rdata
# segments when using masm we need to introduce a segment_stack array so we can
# emit proper ENDS directive whenever we see .previous.
#
# The code is tailored to work current set of .pl/asm files. There are some
# inconsistencies. For example .text section is the first section in all those
# files except ecp_nistz256. So we need to take that into account.
#
#	; stack is empty
# .text
#	; push '.text ' section twice, the stack looks as
#	; follows:
#	;	('.text', '.text')
# .rodata
#	; pop() so we can generate proper 'ENDS' for masm.
#	; stack looks like:
#	; 	('.text')
#	; push '.rodata', so we can create corresponding ENDS for masm.
#	; stack looks like:
#	;	('.rodata', '.text')
# .previous
#	; pop() '.rodata' from stack, so we create '.rodata ENDS'
#	; in masm flavour. For nasm flavour we just pop() because
#	; nasm does not use .rodata ENDS to close the current section
#	; the stack content is like this:
#	;	('.text', '.text')
#	; pop() again to find a previous section we need to restore.
#	; Depending on flavour we either generate .section .text
#	; or .text SEGMENT. The stack looks like:
#	; ('.text')
#
my @segment_stack = ();
my $current_function;
my %globals;

{ package vex_prefix;	# pick up vex prefixes, example: {vex} vpmadd52luq m256, %ymm, %ymm
    sub re {
	my ($class, $line) = @_;
	my $self = {};
	my $ret;

	if ($$line =~ /(^\{vex\})/) {
	    bless $self,$class;
	    $self->{value} = $1;
	    $ret = $self;
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;
	}
	$ret;
	}
    sub out {
	my $self = shift;
	$self->{value};
	}
}
{ package opcode;	# pick up opcodes
    sub re {
	my	($class, $line) = @_;
	my	$self = {};
	my	$ret;

	if ($$line =~ /^([a-z][a-z0-9]*)/i) {
	    bless $self,$class;
	    $self->{op} = $1;
	    $ret = $self;
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;

	    undef $self->{sz};
	    if ($self->{op} =~ /^(movz)x?([bw]).*/) {	# movz is pain...
		$self->{op} = $1;
		$self->{sz} = $2;
	    } elsif ($self->{op} =~ /call|jmp/) {
		$self->{sz} = "";
	    } elsif ($self->{op} =~ /^p/ && $' !~ /^(ush|op|insrw)/) { # SSEn
		$self->{sz} = "";
	    } elsif ($self->{op} =~ /^[vk]/) { # VEX or k* such as kmov
		$self->{sz} = "";
	    } elsif ($self->{op} =~ /mov[dq]/ && $$line =~ /%xmm/) {
		$self->{sz} = "";
	    } elsif ($self->{op} =~ /([a-z]{3,})([qlwb])$/) {
		$self->{op} = $1;
		$self->{sz} = $2;
	    }
	}
	$ret;
    }
    sub size {
	my ($self, $sz) = @_;
	$self->{sz} = $sz if (defined($sz) && !defined($self->{sz}));
	$self->{sz};
    }
    sub out {
	my $self = shift;
	if ($gas) {
	    if ($self->{op} eq "movz") {	# movz is pain...
		sprintf "%s%s%s",$self->{op},$self->{sz},shift;
	    } elsif ($self->{op} =~ /^set/) {
		"$self->{op}";
	    } elsif ($self->{op} eq "ret") {
		my $epilogue = "";
		if ($win64 && $current_function->{abi} eq "svr4") {
		    $epilogue = "movq	8(%rsp),%rdi\n\t" .
				"movq	16(%rsp),%rsi\n\t";
		}
	    	$epilogue . ".byte	0xf3,0xc3";
	    } elsif ($self->{op} eq "call" && !$elf && $current_segment eq ".init") {
		".p2align\t3\n\t.quad";
	    } else {
		"$self->{op}$self->{sz}";
	    }
	} else {
	    $self->{op} =~ s/^movz/movzx/;
	    if ($self->{op} eq "ret") {
		$self->{op} = "";
		if ($win64 && $current_function->{abi} eq "svr4") {
		    $self->{op} = "mov	rdi,QWORD$PTR\[8+rsp\]\t;WIN64 epilogue\n\t".
				  "mov	rsi,QWORD$PTR\[16+rsp\]\n\t";
	    	}
		$self->{op} .= "DB\t0F3h,0C3h\t\t;repret";
	    } elsif ($self->{op} =~ /^(pop|push)f/) {
		$self->{op} .= $self->{sz};
	    } elsif ($self->{op} eq "call" && $current_segment eq ".CRT\$XCU") {
		$self->{op} = "\tDQ";
	    }
	    $self->{op};
	}
    }
    sub mnemonic {
	my ($self, $op) = @_;
	$self->{op}=$op if (defined($op));
	$self->{op};
    }
}
{ package const;	# pick up constants, which start with $
    sub re {
	my	($class, $line) = @_;
	my	$self = {};
	my	$ret;

	if ($$line =~ /^\$([^,]+)/) {
	    bless $self, $class;
	    $self->{value} = $1;
	    $ret = $self;
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;
	}
	$ret;
    }
    sub out {
    	my $self = shift;

	$self->{value} =~ s/\b(0b[0-1]+)/oct($1)/eig;
	if ($gas) {
	    # Solaris /usr/ccs/bin/as can't handle multiplications
	    # in $self->{value}
	    my $value = $self->{value};
	    no warnings;    # oct might complain about overflow, ignore here...
	    $value =~ s/(?<![\w\$\.])(0x?[0-9a-f]+)/oct($1)/egi;
	    if ($value =~ s/([0-9]+\s*[\*\/\%]\s*[0-9]+)/eval($1)/eg) {
		$self->{value} = $value;
	    }
	    sprintf "\$%s",$self->{value};
	} else {
	    my $value = $self->{value};
	    $value =~ s/0x([0-9a-f]+)/0$1h/ig if ($masm);
	    sprintf "%s",$value;
	}
    }
}
{ package ea;		# pick up effective addresses: expr(%reg,%reg,scale)

    my %szmap = (	b=>"BYTE$PTR",    w=>"WORD$PTR",
			l=>"DWORD$PTR",   d=>"DWORD$PTR",
			q=>"QWORD$PTR",   o=>"OWORD$PTR",
			x=>"XMMWORD$PTR", y=>"YMMWORD$PTR",
			z=>"ZMMWORD$PTR" ) if (!$gas);

    sub re {
	my	($class, $line, $opcode) = @_;
	my	$self = {};
	my	$ret;

	# optional * ----vvv--- appears in indirect jmp/call
	if ($$line =~ /^(\*?)([^\(,]*)\(([%\w,]+)\)((?:{[^}]+})*)/) {
	    bless $self, $class;
	    $self->{asterisk} = $1;
	    $self->{label} = $2;
	    ($self->{base},$self->{index},$self->{scale})=split(/,/,$3);
	    $self->{scale} = 1 if (!defined($self->{scale}));
	    $self->{opmask} = $4;
	    $ret = $self;
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;

	    if ($win64 && $self->{label} =~ s/\@GOTPCREL//) {
		die if ($opcode->mnemonic() ne "mov");
		$opcode->mnemonic("lea");
	    }
	    $self->{base}  =~ s/^%//;
	    $self->{index} =~ s/^%// if (defined($self->{index}));
	    $self->{opcode} = $opcode;
	}
	$ret;
    }
    sub size {}
    sub out {
	my ($self, $sz) = @_;

	$self->{label} =~ s/([_a-z][_a-z0-9]*)/$globals{$1} or $1/gei;
	$self->{label} =~ s/\.L/$decor/g;

	# Silently convert all EAs to 64-bit. This is required for
	# elder GNU assembler and results in more compact code,
	# *but* most importantly AES module depends on this feature!
	$self->{index} =~ s/^[er](.?[0-9xpi])[d]?$/r\1/;
	$self->{base}  =~ s/^[er](.?[0-9xpi])[d]?$/r\1/;

	# Solaris /usr/ccs/bin/as can't handle multiplications
	# in $self->{label}...
	use integer;
	$self->{label} =~ s/(?<![\w\$\.])(0x?[0-9a-f]+)/oct($1)/egi;
	$self->{label} =~ s/\b([0-9]+\s*[\*\/\%]\s*[0-9]+)\b/eval($1)/eg;

	# Some assemblers insist on signed presentation of 32-bit
	# offsets, but sign extension is a tricky business in perl...
	if ((1<<31)<<1) {
	    $self->{label} =~ s/\b([0-9]+)\b/$1<<32>>32/eg;
	} else {
	    $self->{label} =~ s/\b([0-9]+)\b/$1>>0/eg;
	}

	# if base register is %rbp or %r13, see if it's possible to
	# flip base and index registers [for better performance]
	if (!$self->{label} && $self->{index} && $self->{scale}==1 &&
	    $self->{base} =~ /(rbp|r13)/) {
		$self->{base} = $self->{index}; $self->{index} = $1;
	}

	if ($gas) {
	    $self->{label} =~ s/^___imp_/__imp__/   if ($flavour eq "mingw64");

	    if (defined($self->{index})) {
		sprintf "%s%s(%s,%%%s,%d)%s",
					$self->{asterisk},$self->{label},
					$self->{base}?"%$self->{base}":"",
					$self->{index},$self->{scale},
					$self->{opmask};
	    } else {
		sprintf "%s%s(%%%s)%s",	$self->{asterisk},$self->{label},
					$self->{base},$self->{opmask};
	    }
	} else {
	    $self->{label} =~ s/\./\$/g;
	    $self->{label} =~ s/(?<![\w\$\.])0x([0-9a-f]+)/0$1h/ig;
	    $self->{label} = "($self->{label})" if ($self->{label} =~ /[\*\+\-\/]/);

	    my $mnemonic = $self->{opcode}->mnemonic();
	    ($self->{asterisk})				&& ($sz="q") ||
	    ($mnemonic =~ /^v?mov([qd])$/)		&& ($sz=$1)  ||
	    ($mnemonic =~ /^v?pinsr([qdwb])$/)		&& ($sz=$1)  ||
	    ($mnemonic =~ /^vbroadcasti32x4$/)		&& ($sz="x") ||
	    ($mnemonic =~ /^vpbroadcast([qdwb])$/)	&& ($sz=$1)  ||
	    ($mnemonic =~ /^v(?!perm)[a-z]+[fi]128$/)	&& ($sz="x");

	    $self->{opmask}  =~ s/%(k[0-7])/$1/;

	    if (defined($self->{index})) {
		sprintf "%s[%s%s*%d%s]%s",$szmap{$sz},
					$self->{label}?"$self->{label}+":"",
					$self->{index},$self->{scale},
					$self->{base}?"+$self->{base}":"",
					$self->{opmask};
	    } elsif ($self->{base} eq "rip") {
		sprintf "%s[%s]",$szmap{$sz},$self->{label};
	    } else {
		sprintf "%s[%s%s]%s",	$szmap{$sz},
					$self->{label}?"$self->{label}+":"",
					$self->{base},$self->{opmask};
	    }
	}
    }
}
{ package register;	# pick up registers, which start with %.
    sub re {
	my	($class, $line, $opcode) = @_;
	my	$self = {};
	my	$ret;

	# optional * ----vvv--- appears in indirect jmp/call
	if ($$line =~ /^(\*?)%(\w+)((?:{[^}]+})*)/) {
	    bless $self,$class;
	    $self->{asterisk} = $1;
	    $self->{value} = $2;
	    $self->{opmask} = $3;
	    $opcode->size($self->size());
	    $ret = $self;
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;
	}
	$ret;
    }
    sub size {
	my	$self = shift;
	my	$ret;

	if    ($self->{value} =~ /^r[\d]+b$/i)	{ $ret="b"; }
	elsif ($self->{value} =~ /^r[\d]+w$/i)	{ $ret="w"; }
	elsif ($self->{value} =~ /^r[\d]+d$/i)	{ $ret="l"; }
	elsif ($self->{value} =~ /^r[\w]+$/i)	{ $ret="q"; }
	elsif ($self->{value} =~ /^[a-d][hl]$/i){ $ret="b"; }
	elsif ($self->{value} =~ /^[\w]{2}l$/i)	{ $ret="b"; }
	elsif ($self->{value} =~ /^[\w]{2}$/i)	{ $ret="w"; }
	elsif ($self->{value} =~ /^e[a-z]{2}$/i){ $ret="l"; }

	$ret;
    }
    sub out {
    	my $self = shift;
	if ($gas)	{ sprintf "%s%%%s%s",	$self->{asterisk},
						$self->{value},
						$self->{opmask}; }
	else		{ $self->{opmask} =~ s/%(k[0-7])/$1/;
			  $self->{value}.$self->{opmask}; }
    }
}
{ package label;	# pick up labels, which end with :
    sub re {
	my	($class, $line) = @_;
	my	$self = {};
	my	$ret;

	if ($$line =~ /(^[\.\w]+)\:/) {
	    bless $self,$class;
	    $self->{value} = $1;
	    $ret = $self;
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;

	    $self->{value} =~ s/^\.L/$decor/;
	}
	$ret;
    }
    sub out {
	my $self = shift;

	if ($gas) {
	    my $func = ($globals{$self->{value}} or $self->{value}) . ":";
	    # sarcasm: inject the entry signature for .type'd functions
	    # that have a %SARCASM_SIGS entry, unless the input line
	    # already carried an explicit `#!` annotation.
	    if (!$line_has_sarcasm_ann
		&& defined($current_function)
		&& defined($current_function->{name})
		&& $self->{value} eq $current_function->{name}
		&& exists($SARCASM_SIGS{$self->{value}})) {
		my $sig = $SARCASM_SIGS{$self->{value}};
		if (defined($current_function->{narg})
		    && $current_function->{narg} != main::sarcasm_sig_narg($sig)) {
		    # Some generators cap the .type narg at 6 (the
		    # win64 unified-prologue limit) even when the
		    # function takes more arguments, so this can only
		    # be a warning.
		    warn "x86_64-xlate.pl: WARNING: sarcasm signature for $self->{value} takes " .
			 main::sarcasm_sig_narg($sig) . " argument(s), but .type declares $current_function->{narg}\n";
		}
		$func .= " #! $sig";
	    }
	    if ($win64	&& $current_function->{name} eq $self->{value}
			&& $current_function->{abi} eq "svr4") {
		$func .= "\n";
		$func .= "	movq	%rdi,8(%rsp)\n";
		$func .= "	movq	%rsi,16(%rsp)\n";
		$func .= "	movq	%rsp,%rax\n";
		$func .= "${decor}SEH_begin_$current_function->{name}:\n";
		my $narg = $current_function->{narg};
		$narg=6 if (!defined($narg));
		$func .= "	movq	%rcx,%rdi\n" if ($narg>0);
		$func .= "	movq	%rdx,%rsi\n" if ($narg>1);
		$func .= "	movq	%r8,%rdx\n"  if ($narg>2);
		$func .= "	movq	%r9,%rcx\n"  if ($narg>3);
		$func .= "	movq	40(%rsp),%r8\n" if ($narg>4);
		$func .= "	movq	48(%rsp),%r9\n" if ($narg>5);
	    }
	    $func;
	} elsif ($self->{value} ne "$current_function->{name}") {
	    # Make all labels in masm global.
	    $self->{value} .= ":" if ($masm);
	    $self->{value} . ":";
	} elsif ($win64 && $current_function->{abi} eq "svr4") {
	    my $func =	"$current_function->{name}" .
			($nasm ? ":" : "\tPROC $current_function->{scope}") .
			"\n";
	    $func .= "	mov	QWORD$PTR\[8+rsp\],rdi\t;WIN64 prologue\n";
	    $func .= "	mov	QWORD$PTR\[16+rsp\],rsi\n";
	    $func .= "	mov	rax,rsp\n";
	    $func .= "${decor}SEH_begin_$current_function->{name}:";
	    $func .= ":" if ($masm);
	    $func .= "\n";
	    my $narg = $current_function->{narg};
	    $narg=6 if (!defined($narg));
	    $func .= "	mov	rdi,rcx\n" if ($narg>0);
	    $func .= "	mov	rsi,rdx\n" if ($narg>1);
	    $func .= "	mov	rdx,r8\n"  if ($narg>2);
	    $func .= "	mov	rcx,r9\n"  if ($narg>3);
	    $func .= "	mov	r8,QWORD$PTR\[40+rsp\]\n" if ($narg>4);
	    $func .= "	mov	r9,QWORD$PTR\[48+rsp\]\n" if ($narg>5);
	    $func .= "\n";
	} else {
	   "$current_function->{name}".
			($nasm ? ":" : "\tPROC $current_function->{scope}");
	}
    }
}
{ package expr;		# pick up expressions
    sub re {
	my	($class, $line, $opcode) = @_;
	my	$self = {};
	my	$ret;

	if ($$line =~ /(^[^,]+)/) {
	    bless $self,$class;
	    $self->{value} = $1;
	    $ret = $self;
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;

	    $self->{value} =~ s/\@PLT// if (!$elf);
	    $self->{value} =~ s/([_a-z][_a-z0-9]*)/$globals{$1} or $1/gei;
	    $self->{value} =~ s/\.L/$decor/g;
	    $self->{opcode} = $opcode;
	}
	$ret;
    }
    sub out {
	my $self = shift;
	if ($nasm && $self->{opcode}->mnemonic()=~m/^j(?![re]cxz)/) {
	    "NEAR ".$self->{value};
	} else {
	    $self->{value};
	}
    }
}
{ package cfi_directive;
    # CFI directives annotate instructions that are significant for
    # stack unwinding procedure compliant with DWARF specification,
    # see http://dwarfstd.org/. Besides naturally expected for this
    # script platform-specific filtering function, this module adds
    # three auxiliary synthetic directives not recognized by [GNU]
    # assembler:
    #
    # - .cfi_push to annotate push instructions in prologue, which
    #   translates to .cfi_adjust_cfa_offset (if needed) and
    #   .cfi_offset;
    # - .cfi_pop to annotate pop instructions in epilogue, which
    #   translates to .cfi_adjust_cfa_offset (if needed) and
    #   .cfi_restore;
    # - [and most notably] .cfi_cfa_expression which encodes
    #   DW_CFA_def_cfa_expression and passes it to .cfi_escape as
    #   byte vector;
    #
    # CFA expressions were introduced in DWARF specification version
    # 3 and describe how to deduce CFA, Canonical Frame Address. This
    # becomes handy if your stack frame is variable and you can't
    # spare register for [previous] frame pointer. Suggested directive
    # syntax is made-up mix of DWARF operator suffixes [subset of]
    # and references to registers with optional bias. Following example
    # describes offloaded *original* stack pointer at specific offset
    # from *current* stack pointer:
    #
    #   .cfi_cfa_expression     %rsp+40,deref,+8
    #
    # Final +8 has everything to do with the fact that CFA is defined
    # as reference to top of caller's stack, and on x86_64 call to
    # subroutine pushes 8-byte return address. In other words original
    # stack pointer upon entry to a subroutine is 8 bytes off from CFA.

    # Below constants are taken from "DWARF Expressions" section of the
    # DWARF specification, section is numbered 7.7 in versions 3 and 4.
    my %DW_OP_simple = (	# no-arg operators, mapped directly
	deref	=> 0x06,	dup	=> 0x12,
	drop	=> 0x13,	over	=> 0x14,
	pick	=> 0x15,	swap	=> 0x16,
	rot	=> 0x17,	xderef	=> 0x18,

	abs	=> 0x19,	and	=> 0x1a,
	div	=> 0x1b,	minus	=> 0x1c,
	mod	=> 0x1d,	mul	=> 0x1e,
	neg	=> 0x1f,	not	=> 0x20,
	or	=> 0x21,	plus	=> 0x22,
	shl	=> 0x24,	shr	=> 0x25,
	shra	=> 0x26,	xor	=> 0x27,
	);

    my %DW_OP_complex = (	# used in specific subroutines
	constu		=> 0x10,	# uleb128
	consts		=> 0x11,	# sleb128
	plus_uconst	=> 0x23,	# uleb128
	lit0 		=> 0x30,	# add 0-31 to opcode
	reg0		=> 0x50,	# add 0-31 to opcode
	breg0		=> 0x70,	# add 0-31 to opcole, sleb128
	regx		=> 0x90,	# uleb28
	fbreg		=> 0x91,	# sleb128
	bregx		=> 0x92,	# uleb128, sleb128
	piece		=> 0x93,	# uleb128
	);

    # Following constants are defined in x86_64 ABI supplement, for
    # example available at https://gitlab.com/x86-psABIs/x86-64-ABI.
    my %DW_reg_idx = (
	"%rax"=>0,  "%rdx"=>1,  "%rcx"=>2,  "%rbx"=>3,
	"%rsi"=>4,  "%rdi"=>5,  "%rbp"=>6,  "%rsp"=>7,
	"%r8" =>8,  "%r9" =>9,  "%r10"=>10, "%r11"=>11,
	"%r12"=>12, "%r13"=>13, "%r14"=>14, "%r15"=>15
	);

    my ($cfa_reg, $cfa_rsp);
    my @cfa_stack;

    # [us]leb128 format is variable-length integer representation base
    # 2^128, with most significant bit of each byte being 0 denoting
    # *last* most significant digit. See "Variable Length Data" in the
    # DWARF specification, numbered 7.6 at least in versions 3 and 4.
    sub sleb128 {
	use integer;	# get right shift extend sign

	my $val = shift;
	my $sign = ($val < 0) ? -1 : 0;
	my @ret = ();

	while(1) {
	    push @ret, $val&0x7f;

	    # see if remaining bits are same and equal to most
	    # significant bit of the current digit, if so, it's
	    # last digit...
	    last if (($val>>6) == $sign);

	    @ret[-1] |= 0x80;
	    $val >>= 7;
	}

	return @ret;
    }
    sub uleb128 {
	my $val = shift;
	my @ret = ();

	while(1) {
	    push @ret, $val&0x7f;

	    # see if it's last significant digit...
	    last if (($val >>= 7) == 0);

	    @ret[-1] |= 0x80;
	}

	return @ret;
    }
    sub const {
	my $val = shift;

	if ($val >= 0 && $val < 32) {
            return ($DW_OP_complex{lit0}+$val);
	}
	return ($DW_OP_complex{consts}, sleb128($val));
    }
    sub reg {
	my $val = shift;

	return if ($val !~ m/^(%r\w+)(?:([\+\-])((?:0x)?[0-9a-f]+))?/);

	my $reg = $DW_reg_idx{$1};
	my $off = eval ("0 $2 $3");

	return (($DW_OP_complex{breg0} + $reg), sleb128($off));
	# Yes, we use DW_OP_bregX+0 to push register value and not
	# DW_OP_regX, because latter would require even DW_OP_piece,
	# which would be a waste under the circumstances. If you have
	# to use DWP_OP_reg, use "regx:N"...
    }
    sub cfa_expression {
	my $line = shift;
	my @ret;

	foreach my $token (split(/,\s*/,$line)) {
	    if ($token =~ /^%r/) {
		push @ret,reg($token);
	    } elsif ($token =~ /((?:0x)?[0-9a-f]+)\((%r\w+)\)/) {
		push @ret,reg("$2+$1");
	    } elsif ($token =~ /(\w+):(\-?(?:0x)?[0-9a-f]+)(U?)/i) {
		my $i = 1*eval($2);
		push @ret,$DW_OP_complex{$1}, ($3 ? uleb128($i) : sleb128($i));
	    } elsif (my $i = 1*eval($token) or $token eq "0") {
		if ($token =~ /^\+/) {
		    push @ret,$DW_OP_complex{plus_uconst},uleb128($i);
		} else {
		    push @ret,const($i);
		}
	    } else {
		push @ret,$DW_OP_simple{$token};
	    }
	}

	# Finally we return DW_CFA_def_cfa_expression, 15, followed by
	# length of the expression and of course the expression itself.
	return (15,scalar(@ret),@ret);
    }
    sub re {
	my	($class, $line) = @_;
	my	$self = {};
	my	$ret;

	if ($$line =~ s/^\s*\.cfi_(\w+)\s*//) {
	    bless $self,$class;
	    $ret = $self;
	    undef $self->{value};
	    my $dir = $1;

	    SWITCH: for ($dir) {
	    # What is $cfa_rsp? Effectively it's difference between %rsp
	    # value and current CFA, Canonical Frame Address, which is
	    # why it starts with -8. Recall that CFA is top of caller's
	    # stack...
	    /startproc/	&& do {	($cfa_reg, $cfa_rsp) = ("%rsp", -8); last; };
	    /endproc/	&& do {	($cfa_reg, $cfa_rsp) = ("%rsp",  0);
				# .cfi_remember_state directives that are not
				# matched with .cfi_restore_state are
				# unnecessary.
				die "unpaired .cfi_remember_state" if (@cfa_stack);
				last;
			      };
	    /def_cfa_register/
			&& do {	$cfa_reg = $$line; last; };
	    /def_cfa_offset/
			&& do {	$cfa_rsp = -1*eval($$line) if ($cfa_reg eq "%rsp");
				last;
			      };
	    /adjust_cfa_offset/
			&& do {	$cfa_rsp -= 1*eval($$line) if ($cfa_reg eq "%rsp");
				last;
			      };
	    /def_cfa/	&& do {	if ($$line =~ /(%r\w+)\s*,\s*(.+)/) {
				    $cfa_reg = $1;
				    $cfa_rsp = -1*eval($2) if ($cfa_reg eq "%rsp");
				}
				last;
			      };
	    /push/	&& do {	$dir = undef;
				$cfa_rsp -= 8;
				if ($cfa_reg eq "%rsp") {
				    $self->{value} = ".cfi_adjust_cfa_offset\t8\n";
				}
				$self->{value} .= ".cfi_offset\t$$line,$cfa_rsp";
				last;
			      };
	    /pop/	&& do {	$dir = undef;
				$cfa_rsp += 8;
				if ($cfa_reg eq "%rsp") {
				    $self->{value} = ".cfi_adjust_cfa_offset\t-8\n";
				}
				$self->{value} .= ".cfi_restore\t$$line";
				last;
			      };
	    /cfa_expression/
			&& do {	$dir = undef;
				$self->{value} = ".cfi_escape\t" .
					join(",", map(sprintf("0x%02x", $_),
						      cfa_expression($$line)));
				last;
			      };
	    /remember_state/
			&& do {	push @cfa_stack, [$cfa_reg, $cfa_rsp];
				last;
			      };
	    /restore_state/
			&& do {	($cfa_reg, $cfa_rsp) = @{pop @cfa_stack};
				last;
			      };
	    }

	    $self->{value} = ".cfi_$dir\t$$line" if ($dir);

	    $$line = "";
	}

	return $ret;
    }
    sub out {
	my $self = shift;
	return ($elf ? $self->{value} : undef);
    }
}
{ package directive;	# pick up directives, which start with .
    sub re {
	my	($class, $line) = @_;
	my	$self = {};
	my	$ret;
	my	$dir;

	# chain-call to cfi_directive
	$ret = cfi_directive->re($line) and return $ret;

	if ($$line =~ /^\s*(\.\w+)/) {
	    bless $self,$class;
	    $dir = $1;
	    $ret = $self;
	    undef $self->{value};
	    $$line = substr($$line,@+[0]); $$line =~ s/^\s+//;

	    SWITCH: for ($dir) {
		/\.global|\.globl|\.extern/
			    && do { $globals{$$line} = $prefix . $$line;
				    $$line = $globals{$$line} if ($prefix);
				    last;
				  };
		/\.type/    && do { my ($sym,$type,$narg) = split(',',$$line);
				    if ($type eq "\@function") {
					undef $current_function;
					$current_function->{name} = $sym;
					$current_function->{abi}  = "svr4";
					$current_function->{narg} = $narg;
					$current_function->{scope} = defined($globals{$sym})?"PUBLIC":"PRIVATE";
				    } elsif ($type eq "\@abi-omnipotent") {
					undef $current_function;
					$current_function->{name} = $sym;
					$current_function->{scope} = defined($globals{$sym})?"PUBLIC":"PRIVATE";
				    }
				    $$line =~ s/\@abi\-omnipotent/\@function/;
				    $$line =~ s/\@function.*/\@function/;
				    last;
				  };
		/\.asciz/   && do { if ($$line =~ /^"(.*)"$/) {
					$dir  = ".byte";
					$$line = join(",",unpack("C*",$1),0);
				    }
				    last;
				  };
		/\.rva|\.long|\.quad|\.byte/
			    && do { $$line =~ s/([_a-z][_a-z0-9]*)/$globals{$1} or $1/gei;
				    $$line =~ s/\.L/$decor/g;
				    last;
				  };
	    }

	    if ($gas) {
		$self->{value} = $dir . "\t" . $$line;

		if ($dir =~ /\.extern/) {
		    $self->{value} = ""; # swallow extern
		} elsif (!$elf && $dir =~ /\.type/) {
		    $self->{value} = "";
		    $self->{value} = ".def\t" . ($globals{$1} or $1) . ";\t" .
				(defined($globals{$1})?".scl 2;":".scl 3;") .
				"\t.type 32;\t.endef"
				if ($win64 && $$line =~ /([^,]+),\@function/);
		} elsif (!$elf && $dir =~ /\.size/) {
		    $self->{value} = "";
		    if (defined($current_function)) {
			$self->{value} .= "${decor}SEH_end_$current_function->{name}:"
				if ($win64 && $current_function->{abi} eq "svr4");
			undef $current_function;
		    }
		} elsif (!$elf && $dir =~ /\.align/) {
		    $self->{value} = ".p2align\t" . (log($$line)/log(2));
		} elsif ($dir eq ".section") {
		    #
		    # get rid off align option, it's not supported/tolerated
		    # by gcc. openssl project introduced the option as an aid
		    # to deal with nasm/masm assembly.
		    #
		    $self->{value} =~ s/(.+)\s+align\s*=.*$/$1/;
                    $current_segment = pop(@segment_stack);
                    if (not $current_segment) {
                        # if no previous section is defined, then assume .text
                        # so code does not land in .data section by accident.
                        # this deals with inconsistency of perl-assembly files.
                        push(@segment_stack, ".text");
                    }
		    #
		    # $$line may still contains align= option. We do care
		    # about section type here.
		    #
		    $current_segment = $$line;
		    $current_segment =~ s/([^\s]+).*$/$1/;
                    push(@segment_stack, $current_segment);
		    if (!$elf && $current_segment eq ".rodata") {
			if	($flavour eq "macosx") { $self->{value} = ".section\t__DATA,__const"; }
			elsif	($flavour eq "mingw64")	{ $self->{value} = ".section\t.rodata"; }
		    }
		    if (!$elf && $current_segment eq ".init") {
			if	($flavour eq "macosx")	{ $self->{value} = ".mod_init_func"; }
			elsif	($flavour eq "mingw64")	{ $self->{value} = ".section\t.ctors"; }
		    }
		} elsif ($dir =~ /\.(text|data)/) {
                    $current_segment = pop(@segment_stack);
                    if (not $current_segment) {
                        # if no previous section is defined, then assume .text
                        # so code does not land in .data section by accident.
                        # this deals with inconsistency of perl-assembly files.
                        push(@segment_stack, ".text");
                    }
		    $current_segment=".$1";
		    push(@segment_stack, $current_segment);
		} elsif ($dir =~ /\.hidden/) {
		    if    ($flavour eq "macosx")  { $self->{value} = ".private_extern\t$prefix$$line"; }
		    elsif ($flavour eq "mingw64") { $self->{value} = ""; }
		} elsif ($dir =~ /\.comm/) {
		    $self->{value} = "$dir\t$prefix$$line";
		    $self->{value} =~ s|,([0-9]+),([0-9]+)$|",$1,".log($2)/log(2)|e if ($flavour eq "macosx");
		} elsif ($dir =~ /\.previous/) {
                    pop(@segment_stack); #pop ourselves
                    # just peek at the top of the stack here
                    $current_segment = @segment_stack[0];
                    if (not $current_segment) {
                        # if no previous segment was defined assume .text so
                        # the code does not accidentally land in .data section.
                        $current_segment = ".text";
                        push(@segment_stack, $current_segment);
                    }
                    if ($flavour eq "mingw64" || $flavour eq "macosx") {
		        $self->{value} = $current_segment;
                    }
		}
		$$line = "";
		return $self;
	    }

	    # non-gas case or nasm/masm
	    SWITCH: for ($dir) {
		/\.text/    && do { my $v=undef;
				    if ($nasm) {
					$current_segment = pop(@segment_stack);
					if (not $current_segment) {
					    push(@segment_stack, ".text");
				        }
					$v="section	.text code align=64\n";
					$current_segment = ".text";
					push(@segment_stack, $current_segment);
				    } else {
					$current_segment = pop(@segment_stack);
					if (not $current_segment) {
					    push(@segment_stack, ".text\$");
				        }
					$v="$current_segment\tENDS\n" if ($current_segment);
					$current_segment = ".text\$";
					push(@segment_stack, $current_segment);
					$v.="$current_segment\tSEGMENT ";
					$v.=$masm>=$masmref ? "ALIGN(256)" : "PAGE";
					$v.=" 'CODE'";
				    }
				    $self->{value} = $v;
				    last;
				  };
		/\.data/    && do { my $v=undef;
				    if ($nasm) {
					$v="section	.data data align=8\n";
				    } else {
					$current_segment = pop(@segment_stack);
					$v="$current_segment\tENDS\n" if ($current_segment);
					$current_segment = "_DATA";
					push(@segment_stack, $current_segment);
					$v.="$current_segment\tSEGMENT";
				    }
				    $self->{value} = $v;
				    last;
				  };
		/\.section/ && do { my $v=undef;
				    my $align=undef;
				    #
				    # $$line may currently contain something like this
				    #	.rodata align = 64
				    # align part is optional
				    #
				    $align = $$line;
				    $align =~ s/(.*)(align\s*=\s*\d+$)/$2/;
				    $$line =~ s/(.*)(\s+align\s*=\s*\d+$)/$1/;
				    $$line =~ s/,.*//;
				    $$line = ".CRT\$XCU" if ($$line eq ".init");
				    $$line = ".rdata" if ($$line eq ".rodata");
				    if ($nasm) {
					$current_segment = pop(@segment_stack);
					if (not $current_segment) {
					    #
					    # This is a hack which deals with ecp_nistz256-x86_64.pl,
					    # The precomputed curve is stored in the first section
					    # in .asm file. Pushing extra .text section here
					    # allows our poor man's solution to stick to assumption
					    # .text section is always the first.
					    #
					    push(@segment_stack, ".text");
					}
					$v="section	$$line";
					if ($$line=~/\.([prx])data/) {
					    if ($align =~ /align\s*=\s*(\d+)/) {
						$v.= " rdata align=$1" ;
					    } else {
						$v.=" rdata align=";
						$v.=$1 eq "p"? 4 : 8;
					    }
					} elsif ($$line=~/\.CRT\$/i) {
					    $v.=" rdata align=8";
					}
				    } else {
					$current_segment = pop(@segment_stack);
					if (not $current_segment) {
					    #
					    # same hack for masm to keep ecp_nistz256-x86_64.pl
					    # happy.
					    #
					    push(@segment_stack, ".text\$");
				        }
					$v="$current_segment\tENDS\n" if ($current_segment);
					$v.="$$line\tSEGMENT";
					if ($$line=~/\.([prx])data/) {
					    $v.=" READONLY";
					    if ($align =~ /align\s*=\s*(\d+)$/) {
						$v.=" ALIGN($1)" if ($masm>=$masmref);
					    } else {
						$v.=" ALIGN(".($1 eq "p" ? 4 : 8).")" if ($masm>=$masmref);
					    }
					} elsif ($$line=~/\.CRT\$/i) {
					    $v.=" READONLY ";
					    $v.=$masm>=$masmref ? "ALIGN(8)" : "DWORD";
					}
				    }
				    $current_segment = $$line;
				    push(@segment_stack, $$line);
				    $self->{value} = $v;
				    last;
				  };
		/\.extern/  && do { $self->{value}  = "EXTERN\t".$$line;
				    $self->{value} .= ":NEAR" if ($masm);
				    last;
				  };
		/\.globl|.global/
			    && do { $self->{value}  = $masm?"PUBLIC":"global";
				    $self->{value} .= "\t".$$line;
				    last;
				  };
		/\.size/    && do { if (defined($current_function)) {
					undef $self->{value};
					if ($current_function->{abi} eq "svr4") {
					    $self->{value}="${decor}SEH_end_$current_function->{name}:";
					    $self->{value}.=":\n" if($masm);
					}
					$self->{value}.="$current_function->{name}\tENDP" if($masm && $current_function->{name});
					undef $current_function;
				    }
				    last;
				  };
		/\.align/   && do { my $max = ($masm && $masm>=$masmref) ? 256 : 4096;
				    $self->{value} = "ALIGN\t".($$line>$max?$max:$$line);
				    last;
				  };
		/\.(value|long|rva|quad)/
			    && do { my $sz  = substr($1,0,1);
				    my @arr = split(/,\s*/,$$line);
				    my $last = pop(@arr);
				    my $conv = sub  {	my $var=shift;
							$var=~s/^(0b[0-1]+)/oct($1)/eig;
							$var=~s/^0x([0-9a-f]+)/0$1h/ig if ($masm);
							if ($sz eq "D" && ($current_segment=~/.[px]data/ || $dir eq ".rva"))
							{ $var=~s/^([_a-z\$\@][_a-z0-9\$\@]*)/$nasm?"$1 wrt ..imagebase":"imagerel $1"/egi; }
							$var;
						    };

				    $sz =~ tr/bvlrq/BWDDQ/;
				    $self->{value} = "\tD$sz\t";
				    for (@arr) { $self->{value} .= &$conv($_).","; }
				    $self->{value} .= &$conv($last);
				    last;
				  };
		/\.byte/    && do { my @str=split(/,\s*/,$$line);
				    map(s/(0b[0-1]+)/oct($1)/eig,@str);
				    map(s/0x([0-9a-f]+)/0$1h/ig,@str) if ($masm);
				    while ($#str>15) {
					$self->{value}.="DB\t"
						.join(",",@str[0..15])."\n";
					foreach (0..15) { shift @str; }
				    }
				    $self->{value}.="DB\t"
						.join(",",@str) if (@str);
				    last;
				  };
		/\.comm/    && do { my @str=split(/,\s*/,$$line);
				    my $v=undef;
				    if ($nasm) {
					$v.="common	$prefix@str[0] @str[1]";
				    } else {
					$current_segment = pop(@segment_stack);;
					$v="$current_segment\tENDS\n" if ($current_segment);
					$current_segment = "_DATA";
					push(@segment_stack, $current_segment);
					$v.="$current_segment\tSEGMENT\n";
					$v.="COMM	@str[0]:DWORD:".@str[1]/4;
				    }
				    $self->{value} = $v;
				    last;
				  };
		/^.previous/ && do {
				    my $v=undef;
				    if ($nasm) {
					pop(@segment_stack); # pop ourselves, we don't need to emit END directive
					# pop section so we can emit proper .section name.
					$current_segment = pop(@segment_stack);
					$v="section $current_segment";
					# Hack again:
					# push section/segment to stack. The .previous is currently paired
					# with .rodata only. We have to keep extra '.text' on stack for
					# situation where there is for example .pdata section 'terminated'
					# by new '.text' section.
					#
					push(@segment_stack, $current_segment);
				    } else {
					$current_segment = pop(@segment_stack);
					$v="$current_segment\tENDS\n" if ($current_segment);
					$current_segment = pop(@segment_stack);
					if ($current_segment =~ /\.text\$/) {
					    $v.="$current_segment\tSEGMENT ";
					    $v.=$masm>=$masmref ? "ALIGN(256)" : "PAGE";
					    $v.=" 'CODE'";
					    push(@segment_stack, $current_segment);
					}
				    }
				    $self->{value} = $v;
				    last;
				    };
	    }
	    $$line = "";
	}

	$ret;
    }
    sub out {
	my $self = shift;
	$self->{value};
    }
}

# Upon initial x86_64 introduction SSE>2 extensions were not introduced
# yet. In order not to be bothered by tracing exact assembler versions,
# but at the same time to provide a bare security minimum of AES-NI, we
# hard-code some instructions. Extensions past AES-NI on the other hand
# are traced by examining assembler version in individual perlasm
# modules...

my %regrm = (	"%eax"=>0, "%ecx"=>1, "%edx"=>2, "%ebx"=>3,
		"%esp"=>4, "%ebp"=>5, "%esi"=>6, "%edi"=>7	);

sub rex {
 my $opcode=shift;
 my ($dst,$src,$rex)=@_;

   $rex|=0x04 if($dst>=8);
   $rex|=0x01 if($src>=8);
   push @$opcode,($rex|0x40) if ($rex);
}

my $movq = sub {	# elderly gas can't handle inter-register movq
  my $arg = shift;
    return () if ($gas);	# any modern gas handles inter-register movq
  my @opcode=(0x66);
    if ($arg =~ /%xmm([0-9]+),\s*%r(\w+)/) {
	my ($src,$dst)=($1,$2);
	if ($dst !~ /[0-9]+/)	{ $dst = $regrm{"%e$dst"}; }
	rex(\@opcode,$src,$dst,0x8);
	push @opcode,0x0f,0x7e;
	push @opcode,0xc0|(($src&7)<<3)|($dst&7);	# ModR/M
	@opcode;
    } elsif ($arg =~ /%r(\w+),\s*%xmm([0-9]+)/) {
	my ($src,$dst)=($2,$1);
	if ($dst !~ /[0-9]+/)	{ $dst = $regrm{"%e$dst"}; }
	rex(\@opcode,$src,$dst,0x8);
	push @opcode,0x0f,0x6e;
	push @opcode,0xc0|(($src&7)<<3)|($dst&7);	# ModR/M
	@opcode;
    } else {
	();
    }
};

my $pextrd = sub {
    return () if ($gas);	# any modern gas handles pextrd
    if (shift =~ /\$([0-9]+),\s*%xmm([0-9]+),\s*(%\w+)/) {
      my @opcode=(0x66);
	my $imm=$1;
	my $src=$2;
	my $dst=$3;
	if ($dst =~ /%r([0-9]+)d/)	{ $dst = $1; }
	elsif ($dst =~ /%e/)		{ $dst = $regrm{$dst}; }
	rex(\@opcode,$src,$dst);
	push @opcode,0x0f,0x3a,0x16;
	push @opcode,0xc0|(($src&7)<<3)|($dst&7);	# ModR/M
	push @opcode,$imm;
	@opcode;
    } else {
	();
    }
};

my $pinsrd = sub {
    return () if ($gas);	# any modern gas handles pinsrd
    if (shift =~ /\$([0-9]+),\s*(%\w+),\s*%xmm([0-9]+)/) {
      my @opcode=(0x66);
	my $imm=$1;
	my $src=$2;
	my $dst=$3;
	if ($src =~ /%r([0-9]+)/)	{ $src = $1; }
	elsif ($src =~ /%e/)		{ $src = $regrm{$src}; }
	rex(\@opcode,$dst,$src);
	push @opcode,0x0f,0x3a,0x22;
	push @opcode,0xc0|(($dst&7)<<3)|($src&7);	# ModR/M
	push @opcode,$imm;
	@opcode;
    } else {
	();
    }
};

my $pshufb = sub {
    return () if ($gas);	# any modern gas handles pshufb
    if (shift =~ /%xmm([0-9]+),\s*%xmm([0-9]+)/) {
      my @opcode=(0x66);
	rex(\@opcode,$2,$1);
	push @opcode,0x0f,0x38,0x00;
	push @opcode,0xc0|($1&7)|(($2&7)<<3);		# ModR/M
	@opcode;
    } else {
	();
    }
};

my $palignr = sub {
    return () if ($gas);	# any modern gas handles palignr
    if (shift =~ /\$([0-9]+),\s*%xmm([0-9]+),\s*%xmm([0-9]+)/) {
      my @opcode=(0x66);
	rex(\@opcode,$3,$2);
	push @opcode,0x0f,0x3a,0x0f;
	push @opcode,0xc0|($2&7)|(($3&7)<<3);		# ModR/M
	push @opcode,$1;
	@opcode;
    } else {
	();
    }
};

my $pclmulqdq = sub {
    return () if ($gas);	# any modern gas handles pclmulqdq
    if (shift =~ /\$([x0-9a-f]+),\s*%xmm([0-9]+),\s*%xmm([0-9]+)/) {
      my @opcode=(0x66);
	rex(\@opcode,$3,$2);
	push @opcode,0x0f,0x3a,0x44;
	push @opcode,0xc0|($2&7)|(($3&7)<<3);		# ModR/M
	my $c=$1;
	push @opcode,$c=~/^0/?oct($c):$c;
	@opcode;
    } else {
	();
    }
};

my $rdrand = sub {
  my $arg = shift;
    # any modern gas handles rdrand, but rejects a size suffix on it,
    # so pass the instruction through verbatim (string return) rather
    # than letting the generic path append a suffix
    return ("rdrand\t$arg") if ($gas);
    if ($arg =~ /%[er](\w+)/) {
      my @opcode=();
      my $dst=$1;
	if ($dst !~ /[0-9]+/) { $dst = $regrm{"%e$dst"}; }
	rex(\@opcode,0,$dst,8);
	push @opcode,0x0f,0xc7,0xf0|($dst&7);
	@opcode;
    } else {
	();
    }
};

my $rdseed = sub {
  my $arg = shift;
    # see $rdrand
    return ("rdseed\t$arg") if ($gas);
    if ($arg =~ /%[er](\w+)/) {
      my @opcode=();
      my $dst=$1;
	if ($dst !~ /[0-9]+/) { $dst = $regrm{"%e$dst"}; }
	rex(\@opcode,0,$dst,8);
	push @opcode,0x0f,0xc7,0xf8|($dst&7);
	@opcode;
    } else {
	();
    }
};

# Not all AVX-capable assemblers recognize AMD XOP extension. Since we
# are using only two instructions hand-code them in order to be excused
# from chasing assembler versions...

sub rxb {
 my $opcode=shift;
 my ($dst,$src1,$src2,$rxb)=@_;

   $rxb|=0x7<<5;
   $rxb&=~(0x04<<5) if($dst>=8);
   $rxb&=~(0x01<<5) if($src1>=8);
   $rxb&=~(0x02<<5) if($src2>=8);
   push @$opcode,$rxb;
}

my $vprotd = sub {
    return () if ($gas);	# any modern gas handles vprotd
    if (shift =~ /\$([x0-9a-f]+),\s*%xmm([0-9]+),\s*%xmm([0-9]+)/) {
      my @opcode=(0x8f);
	rxb(\@opcode,$3,$2,-1,0x08);
	push @opcode,0x78,0xc2;
	push @opcode,0xc0|($2&7)|(($3&7)<<3);		# ModR/M
	my $c=$1;
	push @opcode,$c=~/^0/?oct($c):$c;
	@opcode;
    } else {
	();
    }
};

my $vprotq = sub {
    return () if ($gas);	# any modern gas handles vprotq
    if (shift =~ /\$([x0-9a-f]+),\s*%xmm([0-9]+),\s*%xmm([0-9]+)/) {
      my @opcode=(0x8f);
	rxb(\@opcode,$3,$2,-1,0x08);
	push @opcode,0x78,0xc3;
	push @opcode,0xc0|($2&7)|(($3&7)<<3);		# ModR/M
	my $c=$1;
	push @opcode,$c=~/^0/?oct($c):$c;
	@opcode;
    } else {
	();
    }
};

# Intel Control-flow Enforcement Technology extension. All functions and
# indirect branch targets will have to start with this instruction...

my $endbranch = sub {
    return ("endbr64") if ($gas);	# emit the real mnemonic
    (0xf3,0x0f,0x1e,0xfa);
};

########################################################################

if ($nasm) {
    print <<___;
default	rel
%define XMMWORD
%define YMMWORD
%define ZMMWORD
___
} elsif ($masm) {
    print <<___;
OPTION	DOTNAME
___
}
while(defined(my $line=<>)) {

    $line =~ s|\R$||;           # Better chomp

    # sarcasm: capture a `#!` annotation before the comment strip and
    # re-append it verbatim at the final print (gas output only; for
    # nasm/masm the strip below removes it as before).
    my $ann;
    $line_has_sarcasm_ann = 0;
    if ($gas && $line =~ s/[ \t]*#!(.*)$//) {
	$ann = $1;
	$line_has_sarcasm_ann = 1;
    }

    $line =~ s|[#!].*$||;	# get rid of asm-style comments...
    $line =~ s|/\*.*\*/||;	# ... and C-style comments...
    $line =~ s|^\s+||;		# ... and skip whitespaces in beginning
    $line =~ s|\s+$||;		# ... and at the end

    if (my $label=label->re(\$line))	{ print $label->out(); }

    if (my $directive=directive->re(\$line)) {
	printf "%s",$directive->out();
    } else {
	if (my $vex_prefix=vex_prefix->re(\$line)) {
	printf "%s",$vex_prefix->out();
	}
	if (my $opcode=opcode->re(\$line)) {
	# sarcasm: annotate direct calls to functions present in
	# %SARCASM_SIGS (local subroutines are deliberately absent from
	# the table; sarcasm auto-discovers them), and rip-relative
	# references to the OPENSSL_ia32cap_P extern global (the only
	# extern data symbol in the corpus).
	if ($gas && !defined($ann)) {
	    if ($opcode->mnemonic() eq "call"
		&& $line =~ /^[A-Za-z_][\w.]*$/
		&& exists($SARCASM_SIGS{$line})) {
		$ann = " $SARCASM_SIGS{$line}";
	    } elsif ($line =~ /OPENSSL_ia32cap_P([+]\d+)?\(%rip\)/) {
		$ann = " global ptr";
	    }
	}

	my $asm = eval("\$".$opcode->mnemonic());

	if ((ref($asm) eq 'CODE') && scalar(my @bytes=&$asm($line))) {
	    if ($bytes[0] =~ /^[a-z]/) {
		# the sub returned a literal instruction to emit
		# verbatim (e.g. endbr64, rdrand)
		print "\t",join("\t",@bytes),(defined($ann) ? " #!$ann" : ""),"\n";
	    } else {
		print $gas?".byte\t":"DB\t",join(',',@bytes),"\n";
	    }
	    next;
	}

	my @args;
	ARGUMENT: while (1) {
	    my $arg;

	    ($arg=register->re(\$line, $opcode))||
	    ($arg=const->re(\$line))		||
	    ($arg=ea->re(\$line, $opcode))	||
	    ($arg=expr->re(\$line, $opcode))	||
	    last ARGUMENT;

	    push @args,$arg;

	    last ARGUMENT if ($line !~ /^,/);

	    $line =~ s/^,\s*//;
	} # ARGUMENT:

	if ($#args>=0) {
	    my $insn;
	    my $sz=$opcode->size();

	    if ($gas) {
		$insn = $opcode->out($#args>=1?$args[$#args]->size():$sz);
		@args = map($_->out($sz),@args);
		printf "\t%s\t%s",$insn,join(",",@args);
	    } else {
		$insn = $opcode->out();
		foreach (@args) {
		    my $arg = $_->out();
		    # $insn.=$sz compensates for movq, pinsrw, ...
		    if ($arg =~ /^xmm[0-9]+$/) { $insn.=$sz; $sz="x" if(!$sz); last; }
		    if ($arg =~ /^ymm[0-9]+$/) { $insn.=$sz; $sz="y" if(!$sz); last; }
		    if ($arg =~ /^zmm[0-9]+$/) { $insn.=$sz; $sz="z" if(!$sz); last; }
		    if ($arg =~ /^mm[0-9]+$/)  { $insn.=$sz; $sz="q" if(!$sz); last; }
		}
		@args = reverse(@args);
		undef $sz if ($nasm && $opcode->mnemonic() eq "lea");
		printf "\t%s\t%s",$insn,join(",",map($_->out($sz),@args));
	    }
	} else {
	    printf "\t%s",$opcode->out();
	}
	}
    }

    print $line,(defined($ann) ? " #!$ann" : ""),"\n";
}

print "$cet_property"			if ($cet_property);
print "\n$current_segment\tENDS\n"	if ($current_segment && $masm);
print "END\n"				if ($masm);

close STDOUT or die "error closing STDOUT: $!;"

#################################################
# Cross-reference x86_64 ABI "card"
#
# 		Unix		Win64
# %rax		*		*
# %rbx		-		-
# %rcx		#4		#1
# %rdx		#3		#2
# %rsi		#2		-
# %rdi		#1		-
# %rbp		-		-
# %rsp		-		-
# %r8		#5		#3
# %r9		#6		#4
# %r10		*		*
# %r11		*		*
# %r12		-		-
# %r13		-		-
# %r14		-		-
# %r15		-		-
#
# (*)	volatile register
# (-)	preserved by callee
# (#)	Nth argument, volatile
#
# In Unix terms top of stack is argument transfer area for arguments
# which could not be accommodated in registers. Or in other words 7th
# [integer] argument resides at 8(%rsp) upon function entry point.
# 128 bytes above %rsp constitute a "red zone" which is not touched
# by signal handlers and can be used as temporal storage without
# allocating a frame.
#
# In Win64 terms N*8 bytes on top of stack is argument transfer area,
# which belongs to/can be overwritten by callee. N is the number of
# arguments passed to callee, *but* not less than 4! This means that
# upon function entry point 5th argument resides at 40(%rsp), as well
# as that 32 bytes from 8(%rsp) can always be used as temporal
# storage [without allocating a frame]. One can actually argue that
# one can assume a "red zone" above stack pointer under Win64 as well.
# Point is that at apparently no occasion Windows kernel would alter
# the area above user stack pointer in true asynchronous manner...
#
# All the above means that if assembler programmer adheres to Unix
# register and stack layout, but disregards the "red zone" existence,
# it's possible to use following prologue and epilogue to "gear" from
# Unix to Win64 ABI in leaf functions with not more than 6 arguments.
#
# omnipotent_function:
# ifdef WIN64
#	movq	%rdi,8(%rsp)
#	movq	%rsi,16(%rsp)
#	movq	%rcx,%rdi	; if 1st argument is actually present
#	movq	%rdx,%rsi	; if 2nd argument is actually ...
#	movq	%r8,%rdx	; if 3rd argument is ...
#	movq	%r9,%rcx	; if 4th argument ...
#	movq	40(%rsp),%r8	; if 5th ...
#	movq	48(%rsp),%r9	; if 6th ...
# endif
#	...
# ifdef WIN64
#	movq	8(%rsp),%rdi
#	movq	16(%rsp),%rsi
# endif
#	ret
#
#################################################
# Win64 SEH, Structured Exception Handling.
#
# Unlike on Unix systems(*) lack of Win64 stack unwinding information
# has undesired side-effect at run-time: if an exception is raised in
# assembler subroutine such as those in question (basically we're
# referring to segmentation violations caused by malformed input
# parameters), the application is briskly terminated without invoking
# any exception handlers, most notably without generating memory dump
# or any user notification whatsoever. This poses a problem. It's
# possible to address it by registering custom language-specific
# handler that would restore processor context to the state at
# subroutine entry point and return "exception is not handled, keep
# unwinding" code. Writing such handler can be a challenge... But it's
# doable, though requires certain coding convention. Consider following
# snippet:
#
# .type	function,@function
# function:
#	movq	%rsp,%rax	# copy rsp to volatile register
#	pushq	%r15		# save non-volatile registers
#	pushq	%rbx
#	pushq	%rbp
#	movq	%rsp,%r11
#	subq	%rdi,%r11	# prepare [variable] stack frame
#	andq	$-64,%r11
#	movq	%rax,0(%r11)	# check for exceptions
#	movq	%r11,%rsp	# allocate [variable] stack frame
#	movq	%rax,0(%rsp)	# save original rsp value
# magic_point:
#	...
#	movq	0(%rsp),%rcx	# pull original rsp value
#	movq	-24(%rcx),%rbp	# restore non-volatile registers
#	movq	-16(%rcx),%rbx
#	movq	-8(%rcx),%r15
#	movq	%rcx,%rsp	# restore original rsp
# magic_epilogue:
#	ret
# .size function,.-function
#
# The key is that up to magic_point copy of original rsp value remains
# in chosen volatile register and no non-volatile register, except for
# rsp, is modified. While past magic_point rsp remains constant till
# the very end of the function. In this case custom language-specific
# exception handler would look like this:
#
# EXCEPTION_DISPOSITION handler (EXCEPTION_RECORD *rec,ULONG64 frame,
#		CONTEXT *context,DISPATCHER_CONTEXT *disp)
# {	ULONG64 *rsp = (ULONG64 *)context->Rax;
#	ULONG64  rip = context->Rip;
#
#	if (rip >= magic_point)
#	{   rsp = (ULONG64 *)context->Rsp;
#	    if (rip < magic_epilogue)
#	    {	rsp = (ULONG64 *)rsp[0];
#		context->Rbp = rsp[-3];
#		context->Rbx = rsp[-2];
#		context->R15 = rsp[-1];
#	    }
#	}
#	context->Rsp = (ULONG64)rsp;
#	context->Rdi = rsp[1];
#	context->Rsi = rsp[2];
#
#	memcpy (disp->ContextRecord,context,sizeof(CONTEXT));
#	RtlVirtualUnwind(UNW_FLAG_NHANDLER,disp->ImageBase,
#		dips->ControlPc,disp->FunctionEntry,disp->ContextRecord,
#		&disp->HandlerData,&disp->EstablisherFrame,NULL);
#	return ExceptionContinueSearch;
# }
#
# It's appropriate to implement this handler in assembler, directly in
# function's module. In order to do that one has to know members'
# offsets in CONTEXT and DISPATCHER_CONTEXT structures and some constant
# values. Here they are:
#
#	CONTEXT.Rax				120
#	CONTEXT.Rcx				128
#	CONTEXT.Rdx				136
#	CONTEXT.Rbx				144
#	CONTEXT.Rsp				152
#	CONTEXT.Rbp				160
#	CONTEXT.Rsi				168
#	CONTEXT.Rdi				176
#	CONTEXT.R8				184
#	CONTEXT.R9				192
#	CONTEXT.R10				200
#	CONTEXT.R11				208
#	CONTEXT.R12				216
#	CONTEXT.R13				224
#	CONTEXT.R14				232
#	CONTEXT.R15				240
#	CONTEXT.Rip				248
#	CONTEXT.Xmm6				512
#	sizeof(CONTEXT)				1232
#	DISPATCHER_CONTEXT.ControlPc		0
#	DISPATCHER_CONTEXT.ImageBase		8
#	DISPATCHER_CONTEXT.FunctionEntry	16
#	DISPATCHER_CONTEXT.EstablisherFrame	24
#	DISPATCHER_CONTEXT.TargetIp		32
#	DISPATCHER_CONTEXT.ContextRecord	40
#	DISPATCHER_CONTEXT.LanguageHandler	48
#	DISPATCHER_CONTEXT.HandlerData		56
#	UNW_FLAG_NHANDLER			0
#	ExceptionContinueSearch			1
#
# In order to tie the handler to the function one has to compose
# couple of structures: one for .xdata segment and one for .pdata.
#
# UNWIND_INFO structure for .xdata segment would be
#
# function_unwind_info:
#	.byte	9,0,0,0
#	.rva	handler
#
# This structure designates exception handler for a function with
# zero-length prologue, no stack frame or frame register.
#
# To facilitate composing of .pdata structures, auto-generated "gear"
# prologue copies rsp value to rax and denotes next instruction with
# .LSEH_begin_{function_name} label. This essentially defines the SEH
# styling rule mentioned in the beginning. Position of this label is
# chosen in such manner that possible exceptions raised in the "gear"
# prologue would be accounted to caller and unwound from latter's frame.
# End of function is marked with respective .LSEH_end_{function_name}
# label. To summarize, .pdata segment would contain
#
#	.rva	.LSEH_begin_function
#	.rva	.LSEH_end_function
#	.rva	function_unwind_info
#
# Reference to function_unwind_info from .xdata segment is the anchor.
# In case you wonder why references are 32-bit .rvas and not 64-bit
# .quads. References put into these two segments are required to be
# *relative* to the base address of the current binary module, a.k.a.
# image base. No Win64 module, be it .exe or .dll, can be larger than
# 2GB and thus such relative references can be and are accommodated in
# 32 bits.
#
# Having reviewed the example function code, one can argue that "movq
# %rsp,%rax" above is redundant. It is not! Keep in mind that on Unix
# rax would contain an undefined value. If this "offends" you, use
# another register and refrain from modifying rax till magic_point is
# reached, i.e. as if it was a non-volatile register. If more registers
# are required prior [variable] frame setup is completed, note that
# nobody says that you can have only one "magic point." You can
# "liberate" non-volatile registers by denoting last stack off-load
# instruction and reflecting it in finer grade unwind logic in handler.
# After all, isn't it why it's called *language-specific* handler...
#
# SE handlers are also involved in unwinding stack when executable is
# profiled or debugged. Profiling implies additional limitations that
# are too subtle to discuss here. For now it's sufficient to say that
# in order to simplify handlers one should either a) offload original
# %rsp to stack (like discussed above); or b) if you have a register to
# spare for frame pointer, choose volatile one.
#
# (*)	Note that we're talking about run-time, not debug-time. Lack of
#	unwind information makes debugging hard on both Windows and
#	Unix. "Unlike" refers to the fact that on Unix signal handler
#	will always be invoked, core dumped and appropriate exit code
#	returned to parent (for user notification).
