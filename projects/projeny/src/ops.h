// projeny - original work, MIT-licensed. See ops.cc.
#pragma once

#include <string>
#include <vector>

// Resolved locations for "<pdir>/<archive>", "<pdir>/<name>/", etc.
// `projeny_arg` is the .projeny path exactly as given on the command line
// (relative paths resolve against the caller's CWD).
struct Ctx {
    std::string projeny_arg;
    std::string pdir;       // directory containing the .projeny file
    std::string statusfile; // "<projeny path>.status"
};

Ctx resolve_ctx(const std::string& projeny_arg);

int cmd_setup(const std::string& projeny_arg);
int cmd_commit(const std::string& projeny_arg);
int cmd_add(const std::string& projeny_arg, const std::string& path);
int cmd_rm(const std::string& projeny_arg, const std::string& path);
int cmd_mv(const std::string& projeny_arg, const std::string& src,
           const std::string& dst);
int cmd_resolve(const std::string& projeny_arg, const std::string& path);
int cmd_rebase(const std::string& projeny_arg, const std::string& new_tarball);
int cmd_status(const std::string& projeny_arg);
int cmd_help(const std::string& arg0);
