// projeny - original work, MIT-licensed. See projeny_file.h.
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
    std::vector<std::string> lines = split_lines(data);

    // Headers: leading Key: lines; terminated by the first blank line or the
    // first non-header line. Extra/unknown headers are preserved verbatim.
    size_t i = 0;
    std::vector<std::string> head_lines;
    while (i < lines.size()) {
        if (lines[i].empty()) {
            ++i; // consume the blank-line terminator
            break;
        }
        if (!is_header_line(lines[i]))
            break; // no headers at all; whole file is free text
        head_lines.push_back(lines[i]);
        ++i;
        // A blank line ends the header block.
        if (i < lines.size() && lines[i].empty()) {
            ++i;
            break;
        }
    }
    pf.head = join_lines(head_lines);

    // The patch starts at the first "diff --git " line; tolerate leading
    // whitespace before it. Everything between the headers and the patch is
    // free text (it may itself contain blank lines).
    size_t diff_at = lines.size();
    for (size_t k = i; k < lines.size(); ++k) {
        if (starts_with(ltrim(lines[k]), "diff --git ")) {
            diff_at = k;
            break;
        }
    }
    std::vector<std::string> mid(lines.begin() + i,
                                 lines.begin() + (diff_at < lines.size() ? diff_at
                                                                        : lines.size()));
    pf.middle = join_lines(mid);
    if (diff_at < lines.size())
        pf.patch =
            join_lines(std::vector<std::string>(lines.begin() + diff_at, lines.end()));
    else
        pf.patch = "";

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
    // The embedded .projeny copy is byte-exact: everything after the
    // delimiter line, up to (but excluding) ONE status-file terminating
    // newline, belongs to the copy. split_lines consumed one '\n' per line,
    // so re-joining adds exactly one '\n' per line back; only strip the final
    // newline when the ORIGINAL data did not end with one (i.e. the .projeny
    // file itself had no trailing newline). Binary-safe: no other bytes are
    // added, removed, or normalized.
    size_t rest_begin = (i < lines.size()) ? i : lines.size();
    std::vector<std::string> rest(lines.begin() + rest_begin, lines.end());
    sd.embedded = join_lines(rest);
    if (!data.empty() && data.back() != '\n' && !sd.embedded.empty() &&
        sd.embedded.back() == '\n')
        sd.embedded.pop_back();
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
