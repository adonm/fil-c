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
# Fil-C: lute can use an already Fil-C-ported libuv from a userland install prefix
# (e.g. pizfix) instead of building the vendored extern/libuv a second time.
set(LUTE_SYSTEM_LIBUV "" CACHE PATH "Path to a Fil-C libuv install prefix (pizfix); if set, don't build extern/libuv")
if(LUTE_SYSTEM_LIBUV)
    # The Fil-C build of libuv installs a static archive as lib/libuv.a. Expose it
    # under the same target name (uv_a) that the vendored libuv build would define,
    # so nothing else in the build needs to care which libuv is in use.
    add_library(uv_a STATIC IMPORTED GLOBAL)
    set_target_properties(uv_a PROPERTIES
        IMPORTED_LOCATION "${LUTE_SYSTEM_LIBUV}/lib/libuv.a"
        INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_LIBUV}/include"
        # libuv's Linux system dependencies (see libuv.pc Libs.private)
        INTERFACE_LINK_LIBRARIES "pthread;dl;rt")
    set(LIBUV_INCLUDE_DIR "${LUTE_SYSTEM_LIBUV}/include")
else()
    set(LIBUV_BUILD_SHARED OFF)
    set(BUILD_SHARED_LIBS OFF) # why does an option for LIBUV_BUILD_SHARED exist separately
    set(LIBUV_BUILD_TESTS OFF)
    set(LIBUV_BUILD_BENCH OFF)
    add_subdirectory(extern/libuv)

    # Define libuv include directory here, before it's needed by other subdirectories
    set(LIBUV_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/libuv/include)
endif()

# zlib setup
#
set(ZLIB_BUILD_EXAMPLES OFF CACHE BOOL "Do not build examples" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static zlib" FORCE)
add_subdirectory(extern/zlib)

set(ZLIB_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/extern/zlib")

set(ZLIB_FOUND TRUE CACHE BOOL "" FORCE)

if(MSVC)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/zlibstaticd.lib")
    else()
        set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/zlibstatic.lib")
    endif()
else()
    set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/libz.a")
endif()
set(ZLIB_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/zlib;${ZLIB_OUTPUT_DIR})
set(ZLIB_INCLUDE_DIRS ${ZLIB_INCLUDE_DIR} CACHE STRING "" FORCE)

# OpenSSL setup
# Fil-C: this port always uses an already Fil-C-ported OpenSSL from a userland
# install prefix (e.g. pizfix). The vendored extern/boringssl was removed, so
# lute can no longer build its own TLS library and LUTE_SYSTEM_OPENSSL is
# required. The imported targets reuse the target names the vendored boringssl
# build used to define (ssl, crypto), and curl finds the same OpenSSL via
# OPENSSL_ROOT_DIR. lute/crypto falls back to libsodium for blake2b256, which
# OpenSSL doesn't provide as an EVP (see lute/crypto/src/crypto.cpp).
set(LUTE_SYSTEM_OPENSSL "" CACHE PATH "Path to a Fil-C OpenSSL install prefix (pizfix); required, since this port removed the vendored boringssl")
if(NOT LUTE_SYSTEM_OPENSSL)
    message(FATAL_ERROR
        "LUTE_SYSTEM_OPENSSL is not set. This Fil-C port of lute requires a "
        "prebuilt Fil-C OpenSSL install prefix (e.g. pizfix): re-run cmake with "
        "-DLUTE_SYSTEM_OPENSSL=<prefix>. The vendored extern/boringssl was "
        "removed from this port, so lute cannot build its own TLS library.")
endif()
add_library(ssl STATIC IMPORTED GLOBAL)
set_target_properties(ssl PROPERTIES
    IMPORTED_LOCATION "${LUTE_SYSTEM_OPENSSL}/lib/libssl.a"
    INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_OPENSSL}/include"
    INTERFACE_LINK_LIBRARIES "pthread;dl")
add_library(crypto STATIC IMPORTED GLOBAL)
set_target_properties(crypto PROPERTIES
    IMPORTED_LOCATION "${LUTE_SYSTEM_OPENSSL}/lib/libcrypto.a"
    INTERFACE_INCLUDE_DIRECTORIES "${LUTE_SYSTEM_OPENSSL}/include"
    INTERFACE_LINK_LIBRARIES "pthread;dl")
# lute's own CMakeBuild/FindOpenSSL.cmake (used by curl's find_package) derives
# all of its paths from these two variables (the BORINGSSL_* names are
# upstream's), so point them at the system prefix.
set(BORINGSSL_OUTPUT_DIR "${LUTE_SYSTEM_OPENSSL}/lib")
set(BORINGSSL_INCLUDE_DIR "${LUTE_SYSTEM_OPENSSL}/include")

# curl setup

set(USE_LIBIDN2 OFF)
set(USE_NGHTTP2 OFF)
set(CURL_USE_LIBPSL OFF)
set(CURL_USE_LIBSSH2 OFF)
set(CURL_ZLIB ON)
SET(CURL_ZSTD OFF CACHE STRING "Disable ZSTD" FORCE)
set(CURL_BROTLI OFF CACHE STRING "Disable brotli support" FORCE)
set(CURL_ENABLE_SSL ON)
set(CURL_USE_OPENSSL ON)
set(BUILD_EXAMPLES OFF)
set(BUILD_CURL_EXE OFF)
set(BUILD_SHARED_LIBS OFF)
set(BUILD_STATIC_LIBS ON)

# curl needs to know whether the OpenSSL it links is actually BoringSSL. This
# port always links the system OpenSSL (LUTE_SYSTEM_OPENSSL is required), so
# HAVE_BORINGSSL is never forced on and curl's own header check
# (check_symbol_exists for OPENSSL_IS_BORINGSSL) gets the right answer.
add_subdirectory(extern/curl)

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
