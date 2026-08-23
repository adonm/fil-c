# Fil-C build configuration.
#
# git 2.55.0 builds a Rust component (libgitcore, linked into the git
# binary) by default, which requires cargo. There is no Fil-C Rust
# compiler, so disable the Rust parts; the C code is fully functional
# without them (varint.o provides the C fallback used when Rust is
# disabled, and the WITH_RUST code in help.c/repository.c compiles out).
NO_RUST = 1
