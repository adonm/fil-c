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
#include <cstdio>
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

// Progress state for one download: what was already printed, so the
// callback can decide when the next line is due.
struct DownloadProgress {
    std::string url;
    curl_off_t printed_bytes = 0;  // received count at the last printed line
    int printed_pct = -1;          // whole-percent at the last printed line
    curl_off_t last_total = 0;     // the current transfer's dltotal (0 = unknown)
    bool printed_any = false;      // whether any progress line printed at all
};

// One progress line: bare '\r'-terminated (no ANSI escapes, no padding,
// no isatty tricks), so a terminal redraws the line in place while a log
// file keeps every line.
void print_progress_line(const DownloadProgress& st, curl_off_t now,
                         curl_off_t total)
{
    if (total > 0)
        fprintf(stderr, "projeny: downloading '%s': %lld/%lld bytes (%d%%)\r",
                st.url.c_str(), (long long)now, (long long)total,
                (int)((100 * now) / total));
    else
        fprintf(stderr, "projeny: downloading '%s': %lld bytes\r",
                st.url.c_str(), (long long)now);
}

// curl xferinfo callback (CURLOPT_XFERINFOFUNCTION; needs
// CURLOPT_NOPROGRESS set to 0 to fire at all). Throttled by two gates that
// BOTH must pass before a line prints (see download.h for the rationale):
// at least 64 KiB since the last line, and — only when the total is known —
// a whole-percent boundary crossed since the last line.
int download_progress_cb(void* clientp, curl_off_t dltotal, curl_off_t dlnow,
                         curl_off_t ultotal, curl_off_t ulnow)
{
    (void)ultotal; (void)ulnow;
    DownloadProgress* st = static_cast<DownloadProgress*>(clientp);
    if (dlnow < 0)
        return 0;
    if (dlnow < st->printed_bytes) {
        // The body restarted (curl retried or rewound): reset the throttle
        // so the new run's progress is reported from scratch.
        st->printed_bytes = 0;
        st->printed_pct = -1;
    }
    // Mirror, never latch: one progress struct spans the whole redirect
    // chain (CURLOPT_FOLLOWLOCATION), so a redirect hop's Content-Length
    // must not survive into the closing line of a target that sends none —
    // a latched total printed bogus "N/M bytes (P%)" closers (P far past
    // 100) for unknown-length final bodies.
    st->last_total = dltotal;
    bool have_total = dltotal > 0;
    bool bytes_step = dlnow - st->printed_bytes >= 65536;
    int pct = have_total ? (int)((100 * dlnow) / dltotal) : -1;
    bool pct_step = !have_total || pct > st->printed_pct;
    if (!bytes_step || !pct_step)
        return 0;
    print_progress_line(*st, dlnow, dltotal);
    st->printed_bytes = dlnow;
    st->printed_pct = pct;
    st->printed_any = true;
    return 0;
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
    // Announce the attempt before it starts, then wire up the progress
    // callback. libcurl suppresses progress callbacks by default
    // (CURLOPT_NOPROGRESS defaults to 1), so lifting that is required for
    // download_progress_cb to fire at all.
    note("downloading '" + url + "'");
    DownloadProgress progress;
    progress.url = url;
    curl_easy_setopt(c, CURLOPT_NOPROGRESS, 0L);
    curl_easy_setopt(c, CURLOPT_XFERINFOFUNCTION, download_progress_cb);
    curl_easy_setopt(c, CURLOPT_XFERINFODATA, &progress);
    CURLcode rc = curl_easy_perform(c);
    if (rc == CURLE_OK) {
        // curl does not promise a progress tick landing exactly on the
        // received count, so close the report explicitly — unless the
        // callback already printed exactly that state.
        if (!progress.printed_any ||
            progress.printed_bytes != (curl_off_t)body.size())
            print_progress_line(progress, (curl_off_t)body.size(),
                                progress.last_total);
    }
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
