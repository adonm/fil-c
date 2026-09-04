// projeny - project tarball+patch manager.
// Original work for the Fil-C project, MIT-licensed. Contains no GPL code.
// Uses only the C++ standard library and POSIX. No third-party dependencies.
#pragma once

#include <string>
#include <utility>
#include <vector>

#include <cstdint>

// Result of running a child process. `output` merges stdout and stderr.
struct CmdResult {
    int code = -1;
    std::string output;
};

// Run argv[0] with args (no shell). cwd "" means inherit. Exactly one of
// stdin_data / stdin_file may be provided to feed the child's stdin.
// extra_env entries look like "KEY=VALUE" and are set in the child.
CmdResult run_cmd(const std::vector<std::string>& argv, const std::string& cwd = "",
                  const std::string& stdin_data = "", const std::string& stdin_file = "",
                  const std::vector<std::string>& extra_env = std::vector<std::string>());

// Minimal environment overrides so git never touches the user's config or
// any enclosing repository (projeny works on plain directories).
std::vector<std::string> git_env();

// Convenience wrapper that runs `git <args ...>`.
inline CmdResult run_git(const std::vector<std::string>& args, const std::string& cwd = "",
                         const std::string& stdin_data = "", const std::string& stdin_file = "")
{
    std::vector<std::string> argv;
    argv.reserve(args.size() + 1);
    argv.push_back("git");
    argv.insert(argv.end(), args.begin(), args.end());
    return run_cmd(argv, cwd, stdin_data, stdin_file, git_env());
}

// Print "projeny: error: <msg>" (plus optional detail) and exit(1).
// Also removes any registered temp dirs first.
[[noreturn]] void die(const std::string& msg, const std::string& detail = "");
void warn(const std::string& msg);

// Whole-file binary-safe IO. Reading a missing file dies.
std::string read_file_bytes(const std::string& path);
bool try_read_file_bytes(const std::string& path, std::string* out);
void write_file_bytes(const std::string& path, const std::string& data);
void copy_file_bytes(const std::string& src, const std::string& dst);
// FNV-1a 64-bit content hash (hex) and byte size of a file. Used to detect
// "same basename, different content" tarballs in rebase; dies on IO errors.
std::string file_hash_hex(const std::string& path);
uint64_t file_size_bytes(const std::string& path);
bool path_exists(const std::string& p);
bool is_dir(const std::string& p);

std::string join_path(const std::string& a, const std::string& b);
std::string basename_of(const std::string& p);
std::string dirname_of(const std::string& p); // "" and bare names -> "."
std::string strip_trailing_slashes(const std::string& p);

// Split on '\n'. A trailing '\n' does not produce a final empty element.
// Strips a trailing '\r' from each line (tolerates CRLF input).
std::vector<std::string> split_lines(const std::string& s);
std::string join_lines(const std::vector<std::string>& lines); // adds '\n' after each

std::string ltrim(const std::string& s);
std::string rtrim(const std::string& s);
std::string trim(const std::string& s);
bool starts_with(const std::string& s, const std::string& pfx);
bool ends_with(const std::string& s, const std::string& sfx);

std::string get_cwd();
std::string absolutize(const std::string& p); // lexical, based on get_cwd()
// Lexically normalize: collapse ".", duplicate slashes; ".." pops textually.
std::string normalize_lexical(const std::string& p);

// Create a unique temp dir parent/prefixXXXXXX (mkdtemp). Dies on failure.
std::string make_tempdir(const std::string& parent, const std::string& prefix);
// System scratch parent for temp dirs/files that must never live inside a
// workdir (crashed runs would otherwise pollute the next diff): $TMPDIR when
// it names an existing absolute directory, else /tmp.
std::string system_scratch_parent();
// Create a temp file containing data; returns path (caller removes it).
std::string write_temp_input(const std::string& parent, const std::string& prefix,
                             const std::string& data);

// Temp dir tracking so die() can clean up even on hard-error paths.
void register_tempdir(const std::string& path);
void unregister_tempdir(const std::string& path);

// RAII temp dir. Removes the tree on destruction unless released().
class TempDir {
  public:
    TempDir(const std::string& parent, const std::string& prefix);
    ~TempDir();
    TempDir(const TempDir&) = delete;
    TempDir& operator=(const TempDir&) = delete;
    void release();
    std::string path;
  private:
    bool owned_ = false;
};

bool remove_recursive(const std::string& path); // true on success; missing -> true
void make_dirs(const std::string& path);        // mkdir -p, dies on failure
std::vector<std::string> list_dir_names(const std::string& path); // sorted, no . / ..
void move_path(const std::string& src, const std::string& dst);   // rename(2), dies
void copy_recursive(const std::string& src, const std::string& dst); // cp -a, dies

bool contains_nul(const std::string& s);

// Status-file path escaping: workdir-relative paths are stored one-per-line,
// so backslash, newline and carriage return are backslash-escaped; unescape()
// reverses it. '>' is also escaped, so the "Renamed: <src> -> <dst>" split
// (first raw " -> ") can never hit separator text inside a filename.
// Escaped paths never contain a raw newline.
std::string escape_status_path(const std::string& p);
std::string unescape_status_path(const std::string& e);

// git-path quoting helpers for rewriting diff labels.
std::string unquote_git_path(const std::string& p);
std::string quote_git_path(const std::string& p);

// Replace the value of a "Key: ..." line inside a header block, or prepend
// "Key: value\n" if the key is absent. Matches lines starting with "Key:".
std::string replace_header_value(const std::string& head, const std::string& key,
                                 const std::string& value);
