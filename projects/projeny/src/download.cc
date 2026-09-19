/*
 * Copyright (c) 2026 Filip Pizlo. All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY FILIP PIZLO ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL FILIP PIZLO OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
// Downloading and hashing for URL:-based .projeny files. Links the curl and
// blake3 libraries directly (curl_easy and blake3_hasher APIs) — projeny
// never shells out to `curl` or `b3sum`.
#include "download.h"

#include "util.h"

#include <blake3.h>
#include <curl/curl.h>

#include <cerrno>
#include <cstring>

#include <fcntl.h>
#include <unistd.h>

namespace {

// Lowercase hex of `n` bytes (blake3 outputs raw digests; the .projeny
// "URL: <url> <hash>" form and `projeny hash` both spell them lowercase hex).
std::string hex_lowercase(const unsigned char* bytes, size_t n)
{
    static const char* digits = "0123456789abcdef";
    std::string out;
    out.reserve(n * 2);
    for (size_t i = 0; i < n; ++i) {
        out.push_back(digits[bytes[i] >> 4]);
        out.push_back(digits[bytes[i] & 0x0f]);
    }
    return out;
}

// curl_easy_writecallback: append the received bytes to the caller's
// std::string (passed via CURLOPT_WRITEDATA).
size_t append_to_string(char* ptr, size_t size, size_t nmemb, void* userdata)
{
    std::string* out = static_cast<std::string*>(userdata);
    out->append(ptr, size * nmemb);
    return size * nmemb;
}

} // namespace

std::string blake3_hash_hex(const std::string& data)
{
    blake3_hasher hasher;
    blake3_hasher_init(&hasher);
    if (!data.empty())
        blake3_hasher_update(&hasher, data.data(), data.size());
    unsigned char out[BLAKE3_OUT_LEN];
    blake3_hasher_finalize(&hasher, out, BLAKE3_OUT_LEN);
    return hex_lowercase(out, BLAKE3_OUT_LEN);
}

std::string blake3_file_hash_hex(const std::string& path)
{
    // Same read loop as read_file_bytes (64 KiB chunks, EINTR-tolerant), but
    // streaming the bytes into the hasher instead of a string: tarballs can
    // be tens of megabytes.
    int fd = open(path.c_str(), O_RDONLY);
    if (fd < 0)
        die("cannot read file '" + path + "': " + strerror(errno));
    blake3_hasher hasher;
    blake3_hasher_init(&hasher);
    char buf[65536];
    for (;;) {
        ssize_t r = read(fd, buf, sizeof(buf));
        if (r < 0) {
            if (errno == EINTR)
                continue;
            int saved = errno;
            close(fd);
            die("cannot read file '" + path + "': " + strerror(saved));
        }
        if (r == 0)
            break;
        blake3_hasher_update(&hasher, buf, (size_t)r);
    }
    close(fd);
    unsigned char out[BLAKE3_OUT_LEN];
    blake3_hasher_finalize(&hasher, out, BLAKE3_OUT_LEN);
    return hex_lowercase(out, BLAKE3_OUT_LEN);
}

bool try_download(const std::string& url, std::string* data, std::string* err)
{
    // One-time global setup (projeny is single-threaded, so the function-
    // local static's once-guard is exactly the right granularity).
    static const bool global_ok = curl_global_init(CURL_GLOBAL_ALL) == CURLE_OK;
    if (!global_ok) {
        *err = "curl_global_init failed";
        return false;
    }
    data->clear();
    CURL* c = curl_easy_init();
    if (!c) {
        *err = "curl_easy_init failed";
        return false;
    }
    std::string body;
    char curl_err[CURL_ERROR_SIZE];
    curl_err[0] = '\0';
    curl_easy_setopt(c, CURLOPT_URL, url.c_str());
    curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, append_to_string);
    curl_easy_setopt(c, CURLOPT_WRITEDATA, &body);
    curl_easy_setopt(c, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(c, CURLOPT_FAILONERROR, 1L);
    curl_easy_setopt(c, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(c, CURLOPT_ERRORBUFFER, curl_err);
    // Bound the transfer so a hung mirror cannot stall setup/commit
    // forever: give up on a connection that cannot be established within
    // 30 seconds, and on any transfer that stays below 1 byte/sec for 60
    // seconds. file:// transfers (the tests) are unaffected.
    curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(c, CURLOPT_LOW_SPEED_LIMIT, 1L);
    curl_easy_setopt(c, CURLOPT_LOW_SPEED_TIME, 60L);
    CURLcode rc = curl_easy_perform(c);
    curl_easy_cleanup(c);
    if (rc != CURLE_OK) {
        // curl_easy_strerror names the failure class; the error buffer (set
        // above) usually holds the specific cause (HTTP status, file://
        // error, ...). Both, when available.
        std::string msg = curl_easy_strerror(rc);
        if (curl_err[0] != '\0')
            msg += std::string(": ") + curl_err;
        *err = msg;
        return false;
    }
    *data = body;
    return true;
}
