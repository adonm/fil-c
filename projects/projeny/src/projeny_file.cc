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
#include "projeny_file.h"

#include "util.h"

const char* kStatusDelim = "--- projeny content ---";

namespace {
// Status value lines look like "Key: <escaped-path>". Only the single
// delimiter space after the colon is stripped; any further leading spaces
// (and all trailing spaces) belong to the filename and are preserved.
std::string strip_one_space(const std::string& v)
{
    if (!v.empty() && v[0] == ' ')
        return v.substr(1);
    return v;
}
// A header line is "Key: value" where Key holds no spaces/tabs/colon and the
// line is not indented (indented lines start the free-text section, per the
// spec example which shows 4-space-indented text after the blank line).
bool is_header_line(const std::string& line)
{
    if (line.empty() || line[0] == ' ' || line[0] == '\t')
        return false;
    size_t colon = line.find(':');
    if (colon == std::string::npos || colon == 0)
        return false;
    for (size_t i = 0; i < colon; ++i) {
        char c = line[i];
        if (c == ' ' || c == '\t')
            return false;
    }
    return true;
}
}

std::string ProjenyFile::header_value(const std::string& key) const
{
    for (const std::string& line : split_lines(head)) {
        if (line.size() > key.size() && line.compare(0, key.size(), key) == 0 &&
            line[key.size()] == ':') {
            std::string v = line.substr(key.size() + 1);
            return trim(v);
        }
    }
    return "";
}

ProjenyFile ProjenyFile::parse(const std::string& path)
{
    return parse_bytes(read_file_bytes(path), "'" + path + "'");
}

ProjenyFile ProjenyFile::parse_bytes(const std::string& data,
                                     const std::string& what_for_errors)
{
    ProjenyFile pf;
    pf.raw = data;
    if (contains_nul(data))
        die("file " + what_for_errors + " contains NUL bytes");
    // Raw lines (split on '\n', interior '\r' preserved) with byte offsets,
    // so middle/patch extraction below is byte-exact (CRLF content inside
    // hunk bodies survives). Structural tests strip one trailing '\r'.
    std::vector<std::string> lines;
    std::vector<size_t> starts;
    {
        size_t pos = 0;
        starts.push_back(0);
        while (pos < data.size()) {
            size_t nl = data.find('\n', pos);
            if (nl == std::string::npos) {
                lines.push_back(data.substr(pos));
                pos = data.size();
            } else {
                lines.push_back(data.substr(pos, nl - pos));
                pos = nl + 1;
                if (pos < data.size())
                    starts.push_back(pos);
                else {
                    // Trailing newline: no further line (matches split_lines:
                    // a trailing '\n' does not produce a final empty element).
                }
            }
        }
        if (data.empty()) {
            lines.clear();
            starts.clear();
        }
    }
    auto no_cr = [](const std::string& l) -> std::string {
        if (!l.empty() && l.back() == '\r')
            return l.substr(0, l.size() - 1);
        return l;
    };
    auto line_start = [&](size_t k) -> size_t {
        return k < starts.size() ? starts[k] : data.size();
    };

    // Headers: leading Key: lines; terminated by the first blank line or the
    // first non-header line. Extra/unknown headers are preserved verbatim.
    size_t i = 0;
    std::vector<std::string> head_lines;
    while (i < lines.size()) {
        std::string t = no_cr(lines[i]);
        if (t.empty()) {
            ++i; // consume the blank-line terminator
            break;
        }
        if (!is_header_line(t))
            break; // no headers at all; whole file is free text
        head_lines.push_back(t);
        ++i;
        // A blank line ends the header block.
        if (i < lines.size() && no_cr(lines[i]).empty()) {
            ++i;
            break;
        }
    }
    pf.head = join_lines(head_lines);

    // The patch starts at the first "diff --git "/"diff --cc "/"diff
    // --combined " line; tolerate leading whitespace before it. Everything
    // between the headers and the patch is free text (it may itself contain
    // blank lines). Combined diffs are recognized as patch (not free text)
    // so the applier can reject them with a precise error instead of
    // silently ignoring them.
    size_t diff_at = lines.size();
    for (size_t k = i; k < lines.size(); ++k) {
        std::string t = ltrim(no_cr(lines[k]));
        if (starts_with(t, "diff --git ") || starts_with(t, "diff --cc ") ||
            starts_with(t, "diff --combined ")) {
            diff_at = k;
            break;
        }
    }
    size_t mid_start = line_start(i);
    size_t patch_start =
        diff_at < lines.size() ? line_start(diff_at) : data.size();
    pf.middle = data.substr(mid_start, patch_start - mid_start);
    pf.patch = data.substr(patch_start);

    pf.archive = pf.header_value("Archive");
    pf.origname = pf.header_value("Origname");
    pf.name = pf.header_value("Name");
    if (pf.archive.empty() || pf.origname.empty() || pf.name.empty()) {
        die("file " + what_for_errors +
            " is missing a required header (need Archive:, Origname:, Name:)");
    }
    if (pf.archive.find('/') != std::string::npos)
        die("file " + what_for_errors + ": Archive: must be a plain filename");
    if (pf.origname.find('/') != std::string::npos ||
        pf.origname == "." || pf.origname == "..")
        die("file " + what_for_errors + ": bad Origname: header");
    if (pf.name.find('/') != std::string::npos || pf.name == "." || pf.name == "..")
        die("file " + what_for_errors + ": bad Name: header");
    return pf;
}

void ProjenyFile::rebuild(const std::string& new_patch)
{
    // raw = head + "\n" + middle + patch, where middle already ends in '\n'
    // when non-empty (join_lines). The patch body is replaced verbatim, so
    // trailing whitespace inside the new patch is preserved byte-for-byte.
    // NOTE: binary-safety here only concerns the trailing-newline guarantee:
    // commit/rebase always pass normalized text patches; raw .projeny files
    // with or without a trailing newline parse identically, but rebuilt files
    // end with exactly one '\n'.
    std::string out = head;
    out += "\n";
    out += middle;
    std::string np = new_patch;
    if (!np.empty() && np.back() != '\n')
        np += "\n";
    out += np;
    raw = out;
    patch = np;
}

// ---- status file ----
//
// Text format, chosen for debuggability:
//
//   Status: setup
//   Conflict: <workdir-relative path>     (repeatable, optional)
//   Added: <path>                         (repeatable, optional)
//   Removed: <path>                       (repeatable, optional)
//   Renamed: <src> -> <dst>               (repeatable, optional)
//   --- projeny content ---
//   <verbatim .projeny bytes to EOF>
//
// Paths are backslash-escaped (escape_status_path: "\" -> "\\",
// newline -> "\n", CR -> "\r", ">" -> "\>") so filenames containing
// newlines roundtrip (escaped values never contain a raw newline, so one
// path per line holds) and the "Renamed: <src> -> <dst>" separator stays
// unambiguous: ">" is always escaped inside values, so a raw " -> " in the
// line can only be the real field separator (split on the first one, then
// unescape each side). Only the single delimiter space after "Key:" is
// stripped; leading/trailing spaces inside filenames are preserved.
//
// The "Status:" line says whether the workdir was set up. The embedded copy
// is the .projeny file exactly as it was at the last setup/commit, so setup
// can reconstruct the expected tree even after the user edits .projeny.
// Conflict lines list files with conflict markers. Added/Removed/Renamed
// lines are pending operations not yet folded into the patch by commit.

StatusData StatusData::parse(const std::string& path)
{
    return parse_bytes(read_file_bytes(path), "'" + path + "'");
}

StatusData StatusData::parse_bytes(const std::string& data,
                                   const std::string& what_for_errors)
{
    StatusData sd;
    std::vector<std::string> lines = split_lines(data);
    size_t i = 0;
    bool saw_status = false;
    for (; i < lines.size(); ++i) {
        const std::string& l = lines[i];
        if (l == kStatusDelim) {
            ++i;
            break;
        }
        if (l.empty())
            continue;
        if (starts_with(l, "Status:")) {
            sd.status = trim(l.substr(7));
            saw_status = true;
        } else if (starts_with(l, "Conflict:")) {
            sd.conflicts.push_back(unescape_status_path(strip_one_space(l.substr(9))));
        } else if (starts_with(l, "Added:")) {
            sd.added.push_back(unescape_status_path(strip_one_space(l.substr(6))));
        } else if (starts_with(l, "Removed:")) {
            sd.removed.push_back(unescape_status_path(strip_one_space(l.substr(8))));
        } else if (starts_with(l, "Renamed:")) {
            std::string rest = strip_one_space(l.substr(8));
            size_t arrow = rest.find(" -> ");
            if (arrow == std::string::npos)
                die("file " + what_for_errors + " has a malformed Renamed: line");
            // '>' is escaped inside values, so the first raw " -> " is
            // always the real separator, even when a filename contains it.
            sd.renamed.push_back({unescape_status_path(rest.substr(0, arrow)),
                                  unescape_status_path(rest.substr(arrow + 4))});
        } else {
            die("file " + what_for_errors + " has an unrecognized status line: '" +
                l + "'");
        }
    }
    if (!saw_status)
        die("file " + what_for_errors + " is missing the Status: line");
    // The embedded .projeny copy is byte-exact: the raw bytes after the
    // delimiter line through EOF belong to the copy verbatim (no re-join,
    // so interior CR bytes from CRLF patch content and the trailing-newline
    // state both survive exactly).
    size_t emb_off = data.size();
    {
        size_t pos = 0;
        for (size_t k = 0; k < i; ++k) {
            size_t nl = data.find('\n', pos);
            if (nl == std::string::npos) {
                pos = data.size();
                break;
            }
            pos = nl + 1;
        }
        emb_off = pos;
    }
    sd.embedded = data.substr(emb_off);
    return sd;
}

std::string StatusData::serialize() const
{
    std::string out = "Status: " + status + "\n";
    for (const auto& c : conflicts)
        out += "Conflict: " + escape_status_path(c) + "\n";
    for (const auto& a : added)
        out += "Added: " + escape_status_path(a) + "\n";
    for (const auto& r : removed)
        out += "Removed: " + escape_status_path(r) + "\n";
    for (const auto& rn : renamed)
        out += "Renamed: " + escape_status_path(rn.first) + " -> " +
               escape_status_path(rn.second) + "\n";
    out += std::string(kStatusDelim) + "\n";
    // The embedded .projeny copy is byte-exact: stored verbatim (even
    // without a trailing newline) and compared as raw bytes on commit.
    // NOTE: no terminating newline is added when the copy lacks one, so the
    // status file itself simply doesn't end with '\n' in that case — which is
    // exactly how parse_bytes() tells "copy ends with '\n'" apart from "copy
    // has no trailing newline" on the way back in. Adding a terminator here
    // would make the two cases indistinguishable and break commit's raw-bytes
    // comparison for newline-less .projeny files.
    out += embedded;
    return out;
}
