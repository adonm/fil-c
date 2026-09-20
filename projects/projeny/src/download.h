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
#pragma once

#include <set>
#include <string>
#include <vector>

// BLAKE3 (64 lowercase hex chars) of in-memory data / of a file's contents.
// The file variant dies if the file cannot be read.
std::string blake3_hash_hex(const std::string& data);
std::string blake3_file_hash_hex(const std::string& path);

// Downloads `url` fully into *data using the linked libcurl (no subprocess).
// Returns false and sets *err on any failure (network, HTTP error, file://
// error, ...). Follows redirects.
//
// Feedback (all of it on stderr, all prefixed "projeny:", so interactive
// users and logs see the same story): before the transfer starts, a normal
// line announces it ("downloading '<url>'" — the only line that names the
// URL); while data arrives, short progress lines ("projeny: download
// progress: ...") report the byte count (and, when the total size is known
// from Content-Length, the whole-percentage) — each terminated by a bare
// '\r' and using no other trick (no ANSI escapes, no backspaces, no isatty
// checks, no padding), so a terminal redraws the line in place while a log
// file keeps every line. The progress line's short form — the URL lives
// only on the announcement, which it never repeats — keeps it within an
// 80-column terminal. A progress line prints only when BOTH at least 64 KiB
// have arrived since the last printed line AND — when the total is known —
// the whole-percent count has grown since then: a 70 MB tarball then
// reports its ~100 whole percents instead of ~1100 64 KiB lines, smaller
// downloads (1% under 64 KiB) degrade to plain 64 KiB steps, and unknown
// totals use 64 KiB steps throughout. After a successful transfer one last
// '\r'-terminated line reports the final byte count (skipped when the
// progress callback already printed exactly that state).
bool try_download(const std::string& url, std::string* data, std::string* err);

// One package to download in a batch: `name` is the identity (the archive
// basename; two callers wanting the same name share one download), `urls`
// are candidate URLs in priority order (mirrors of the same archive), and
// `accepted_hashes` are the blake3 (64 lowercase hex) hashes any of which
// verifies the download.
struct BatchPackageSpec {
    std::string name;
    std::vector<std::string> urls;
    std::set<std::string> accepted_hashes;
};

struct BatchPackageResult {
    std::string name;
    bool ok = false;                  // transferred AND hash-verified
    std::string data;                 // accepted bytes (valid iff ok)
    std::string hash;                 // blake3 hex of data (iff ok)
    std::string url;                  // URL the accepted bytes came from
    std::vector<std::string> errors;  // one human-readable line per failed attempt
};

// Parallel batch download. Phase 1 drives the curl MULTI API with at most
// `curl_jobs` (>=1) easy handles in flight; each in-flight handle belongs to
// a distinct package (NEVER two concurrent transfers of the same package,
// neither from the same URL nor from different URLs), and a package whose
// transfer fails moves on to its next candidate URL. All curl API calls
// happen on the calling thread (curl handles are not thread-safe); workers
// never touch curl. Phase 2 blake3-hash-checks every transferred package on
// at most `hash_jobs` (>=1) threads (run_parallel). Packages that fail
// (transfer error or hash mismatch) then get ONE full retry pass: the
// scheduler runs again over the failed packages' candidate lists (still
// <= curl_jobs in flight, still one handle per package, candidates
// restarting from the first URL) followed by another parallel hash round.
//
// Feedback, one atomic line per event (note/warn, serialized by
// g_output_mutex):
//   per attempt start:      "downloading '<name>' from '<url>'"
//   transfer failure:       "failed to download '<name>' from '<url>': <curl error>"
//   hash mismatch:          "downloaded '<name>' from '<url>' but blake3 hash mismatch (got <hash>)"
//   verified:               "downloaded '<name>' (<N> bytes); blake3 hash verified"
//   retry pass (k>0):       "retrying <k> failed download(s): <comma-separated names>"
// Batch mode uses NO per-transfer progress callback (no '\r' spam from
// concurrent transfers; NOPROGRESS=1 on the easy handles). Returns one
// result per spec, in spec order. Never dies on download failures — every
// failure lands in the result's `errors` (a die() would mean an internal or
// allocation-level error only). All packages are held in RAM, exactly like
// try_download.
std::vector<BatchPackageResult> download_batch(const std::vector<BatchPackageSpec>& specs,
                                               int curl_jobs, int hash_jobs);
