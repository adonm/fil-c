// projeny - original work, MIT-licensed. See projeny_file.cc.
#pragma once

#include <string>
#include <utility>
#include <vector>

// A parsed .projeny file.
//
// Layout: "Key: value" headers at the top, terminated by a blank line,
// then free text and a git-style patch. Only the three required keys are
// interpreted; everything else is preserved verbatim:
//   head    = the header block (without the trailing blank line)
//   patch   = everything from the "diff --git" block onward (may be empty)
//   middle  = free text between the blank line and the first "diff --git"
struct ProjenyFile {
    std::string raw;    // full verbatim bytes
    std::string head;   // headers, no trailing blank line
    std::string middle; // free text between headers and patch
    std::string patch;  // from first "diff --git " line to EOF (or "")
    std::string archive;
    std::string origname;
    std::string name;

    static ProjenyFile parse(const std::string& path);
    static ProjenyFile parse_bytes(const std::string& data,
                                   const std::string& what_for_errors);
    std::string header_value(const std::string& key) const; // "" if absent

    // Rebuild raw from head/middle/patch (headers kept verbatim, patch body
    // replaced). Used by commit/rebase to preserve the user's headers.
    void rebuild(const std::string& new_patch);
};

// Status file bookkeeping (see projeny_file.cc for the format).
struct StatusData {
    std::string status; // e.g. "setup"
    std::vector<std::string> conflicts;
    std::vector<std::string> added;
    std::vector<std::string> removed;
    // Renamed pairs are (src, dst), workdir-relative paths.
    std::vector<std::pair<std::string, std::string>> renamed;
    std::string embedded; // verbatim .projeny copy, exactly as stored

    static StatusData parse(const std::string& path);
    static StatusData parse_bytes(const std::string& data,
                                  const std::string& what_for_errors);
    std::string serialize() const;
};

extern const char* kStatusDelim;
