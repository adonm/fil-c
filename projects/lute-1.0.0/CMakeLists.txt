cmake_minimum_required(VERSION 3.13)

# Make sure 'set' for variables is respected by options in nested files
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# set the module path
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMakeBuild")

include(get_version)

project(
    Lute
    VERSION ${LUTE_VERSION}
    LANGUAGES CXX C
)

# Enable sanitizers globally before any subdirectory is added
option(LUTE_ENABLE_SANITIZERS "Enable sanitizers" OFF)
if (LUTE_ENABLE_SANITIZERS)
    if(NOT MSVC)
        add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
        add_link_options(-fsanitize=address,undefined)
    endif()
endif()

# luau setup
set(LUAU_BUILD_CLI OFF)
set(LUAU_BUILD_TESTS OFF)

add_subdirectory(extern/luau)

# libuv setup
# Fil-C: this port always uses an already Fil-C-ported libuv from a userland
# install prefix (e.g. pizfix). The vendored extern/libuv was removed, so lute
# can no longer build its own event loop library and LUTE_SYSTEM_LIBUV is
# required. The imported target reuses the target name (uv_a) that the
# vendored libuv build used to define, so nothing else in the build needs to
# care which libuv is in use. We link the shared library (libuv.so): its
# system dependencies ride along as DT_NEEDED entries, so there is no
# transitive link interface to enumerate here.
set(LUTE_SYSTEM_LIBUV "" CACHE PATH "Path to a Fil-C libuv install prefix (pizfix); required, since this port removed the vendored libuv")
if(NOT LUTE_SYSTEM_LIBUV)
    message(FATAL_ERROR
        "LUTE_SYSTEM_LIBUV is not set. This Fil-C port of lute requires a "
        "prebuilt Fil-C libuv install prefix (e.g. pizfix): re-run cmake with "
        "-DLUTE_SYSTEM_LIBUV=<prefix>. The vendored extern/libuv was removed "
        "from this port, so lute cannot build its own event loop library.")
endif()
add_library(uv_a SHARED IMPORTED GLOBAL)
set_target_properties(uv_a PROPERTIES
    IMPORTED_LOCATION "${LUTE_SYSTEM_LIBUV}/lib/libuv.so"
    INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_LIBUV}/include")
set(LIBUV_INCLUDE_DIR "${LUTE_SYSTEM_LIBUV}/include")

# zlib setup
# Fil-C: same story as libuv: use an already Fil-C-ported zlib from a userland
# install prefix (e.g. pizfix). The vendored extern/zlib was removed, so
# LUTE_SYSTEM_ZLIB is required. The imported target reuses the target name
# (zlibstatic) that the vendored zlib build used to define, so nothing else in
# the build needs to care which zlib is in use; the name is a misnomer now
# that we link the shared library (libz.so).
set(LUTE_SYSTEM_ZLIB "" CACHE PATH "Path to a Fil-C zlib install prefix (pizfix); required, since this port removed the vendored zlib")
if(NOT LUTE_SYSTEM_ZLIB)
    message(FATAL_ERROR
        "LUTE_SYSTEM_ZLIB is not set. This Fil-C port of lute requires a "
        "prebuilt Fil-C zlib install prefix (e.g. pizfix): re-run cmake with "
        "-DLUTE_SYSTEM_ZLIB=<prefix>. The vendored extern/zlib was removed "
        "from this port, so lute cannot build its own compression library.")
endif()
add_library(zlibstatic SHARED IMPORTED GLOBAL)
set_target_properties(zlibstatic PROPERTIES
    IMPORTED_LOCATION "${LUTE_SYSTEM_ZLIB}/lib/libz.so"
    INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_ZLIB}/include")
# These variables are consumed by CMakeBuild/uWebSockets.cmake
# (ZLIB_INCLUDE_DIRS, ZLIB_LIBRARIES) and lute/cli (ZLIB_INCLUDE_DIR).
set(ZLIB_INCLUDE_DIR "${LUTE_SYSTEM_ZLIB}/include")
set(ZLIB_INCLUDE_DIRS "${LUTE_SYSTEM_ZLIB}/include")
set(ZLIB_LIBRARIES zlibstatic)

# OpenSSL setup
# Fil-C: this port always uses an already Fil-C-ported OpenSSL from a userland
# install prefix (e.g. pizfix). The vendored extern/boringssl was removed, so
# lute can no longer build its own TLS library and LUTE_SYSTEM_OPENSSL is
# required. The imported targets reuse the target names the vendored boringssl
# build used to define (ssl, crypto), and point at the shared libraries
# (libssl.so, libcrypto.so). lute/crypto falls back to libsodium for
# blake2b256, which OpenSSL doesn't provide as an EVP (see
# lute/crypto/src/crypto.cpp).
set(LUTE_SYSTEM_OPENSSL "" CACHE PATH "Path to a Fil-C OpenSSL install prefix (pizfix); required, since this port removed the vendored boringssl")
if(NOT LUTE_SYSTEM_OPENSSL)
    message(FATAL_ERROR
        "LUTE_SYSTEM_OPENSSL is not set. This Fil-C port of lute requires a "
        "prebuilt Fil-C OpenSSL install prefix (e.g. pizfix): re-run cmake with "
        "-DLUTE_SYSTEM_OPENSSL=<prefix>. The vendored extern/boringssl was "
        "removed from this port, so lute cannot build its own TLS library.")
endif()
add_library(ssl SHARED IMPORTED GLOBAL)
set_target_properties(ssl PROPERTIES
    IMPORTED_LOCATION "${LUTE_SYSTEM_OPENSSL}/lib/libssl.so"
    INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_OPENSSL}/include")
add_library(crypto SHARED IMPORTED GLOBAL)
set_target_properties(crypto PROPERTIES
    IMPORTED_LOCATION "${LUTE_SYSTEM_OPENSSL}/lib/libcrypto.so"
    INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_OPENSSL}/include")
# CMakeBuild/uSockets.cmake's WITH_BORINGSSL branch adds ${BORINGSSL_INCLUDE_DIR}
# to uSockets' include path (the BORINGSSL_* name is upstream's); point it at
# the system prefix.
set(BORINGSSL_INCLUDE_DIR "${LUTE_SYSTEM_OPENSSL}/include")

# curl setup
# Fil-C: same story again: use an already Fil-C-ported curl from a userland
# install prefix (e.g. pizfix). The vendored extern/curl was removed, so
# LUTE_SYSTEM_CURL is required. The imported target reuses the target name
# (libcurl) that the vendored curl build used to define. We link the shared
# library (libcurl.so), whose dependencies ride along as DT_NEEDED entries,
# so there is no transitive link interface to enumerate here. That matters:
# exactly what the corpus curl was built against (OpenSSL, zlib, zstd,
# nghttp2, brotli, ...) changes as build_all_slow.sh evolves, and only the
# shared library knows the answer.
set(LUTE_SYSTEM_CURL "" CACHE PATH "Path to a Fil-C curl install prefix (pizfix); required, since this port removed the vendored curl")
if(NOT LUTE_SYSTEM_CURL)
    message(FATAL_ERROR
        "LUTE_SYSTEM_CURL is not set. This Fil-C port of lute requires a "
        "prebuilt Fil-C curl install prefix (e.g. pizfix): re-run cmake with "
        "-DLUTE_SYSTEM_CURL=<prefix>. The vendored extern/curl was removed "
        "from this port, so lute cannot build its own HTTP client library.")
endif()
add_library(libcurl SHARED IMPORTED GLOBAL)
set_target_properties(libcurl PROPERTIES
    IMPORTED_LOCATION "${LUTE_SYSTEM_CURL}/lib/libcurl.so"
    INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_CURL}/include")

# uWebSockets setup
# Fil-C: WITH_BORINGSSL is uSockets/uWebSockets' upstream toggle for TLS via an
# OpenSSL-compatible libssl/libcrypto; here the ssl/crypto targets are the
# imported system OpenSSL from LUTE_SYSTEM_OPENSSL above, not BoringSSL.
set(WITH_BORINGSSL ON)
set(WITH_LIBUV ON)
set(WITH_ZLIB ON)

# Set the correct libuv library name for uWebSockets
set(LIBUV_LIBRARY uv_a)
include(uSockets)
include(uWebSockets)

# Define include directories for uWebSockets and uSockets
set(UWEBSOCKETS_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/uWebSockets/src)

# libsodium for `pwhash`
include(libsodium)

# Lute
set(LUTE_OPTIONS)

if(MSVC)
    list(APPEND LUTE_OPTIONS /DNOMINMAX)
    list(APPEND LUTE_OPTIONS /D_CRT_SECURE_NO_WARNINGS) # We need to use the portable CRT functions.
    list(APPEND LUTE_OPTIONS "/we4018") # Signed/unsigned mismatch
    list(APPEND LUTE_OPTIONS "/we4388") # Also signed/unsigned mismatch
    if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        list(APPEND LUTE_OPTIONS "/Zc:externConstexpr") # MSVC does not comply with C++ standard by default
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        list(APPEND LUTE_OPTIONS "/EHsc") # The CMake clang-cl target doesn't enable exceptions by default
    endif()
    # FIXME: list(APPEND LUTE_OPTIONS /WX) # Warnings are errors
else()
    list(APPEND LUTE_OPTIONS -Wall) # All warnings
    list(APPEND LUTE_OPTIONS -Wimplicit-fallthrough)
    list(APPEND LUTE_OPTIONS -Wsign-compare) # This looks to be included in -Wall for GCC but not clang
    # Fil-C: -Werror removed. The Fil-C compiler emits warnings that lute and its
    # vendored dependencies don't expect, so warnings must not be errors here.
endif()

# libraries
add_subdirectory(lute/batteries)
add_subdirectory(lute/common)
add_subdirectory(lute/definitions)
add_subdirectory(lute/require)
add_subdirectory(lute/runtime)
add_subdirectory(lute/crypto)
add_subdirectory(lute/fs)
add_subdirectory(lute/luau)
add_subdirectory(lute/net)
add_subdirectory(lute/std)
add_subdirectory(lute/task)
add_subdirectory(lute/vm)
add_subdirectory(lute/process)
add_subdirectory(lute/system)
add_subdirectory(lute/time)
add_subdirectory(lute/io)

# executables
add_subdirectory(lute/cli)
add_subdirectory(tests)
