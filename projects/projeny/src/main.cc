// projeny - project tarball+patch manager.
// Original work for the Fil-C project, MIT-licensed. Contains no GPL code.
// Uses only the C++ standard library and POSIX; shells out at runtime to
// tar, git, and cp (direct posix_spawnp, no shell).
#include "ops.h"
#include "util.h"

#include <cstdio>
#include <string>
#include <vector>

namespace {
int usage(const char* arg0, bool err)
{
    FILE* f = err ? stderr : stdout;
    fprintf(f,
            "usage: %s <setup|commit|add|rm|mv|resolve|rebase|status|help> "
            "[args]\n"
            "  setup <f.projeny>\n"
            "  commit <f.projeny>\n"
            "  add <f.projeny> <path>\n"
            "  rm <f.projeny> <path>\n"
            "  mv <f.projeny> <src> <dst>\n"
            "  resolve <f.projeny> <path>\n"
            "  rebase <f.projeny> <new-tarball>\n"
            "  status <f.projeny>\n"
            "  help\n",
            arg0);
    return err ? 1 : 0;
}
}

int main(int argc, char** argv)
{
    std::string arg0 = argc > 0 ? argv[0] : "projeny";
    std::vector<std::string> args;
    for (int i = 1; i < argc; ++i)
        args.push_back(argv[i]);
    if (args.empty())
        return usage(arg0.c_str(), true);

    const std::string& cmd = args[0];
    if (cmd == "help" || cmd == "--help" || cmd == "-h") {
        if (args.size() != 1)
            return usage(arg0.c_str(), true);
        return cmd_help(arg0);
    }
    if (cmd == "setup") {
        if (args.size() != 2)
            return usage(arg0.c_str(), true);
        return cmd_setup(args[1]);
    }
    if (cmd == "commit") {
        if (args.size() != 2)
            return usage(arg0.c_str(), true);
        return cmd_commit(args[1]);
    }
    if (cmd == "add") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_add(args[1], args[2]);
    }
    if (cmd == "rm") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_rm(args[1], args[2]);
    }
    if (cmd == "mv") {
        if (args.size() != 4)
            return usage(arg0.c_str(), true);
        return cmd_mv(args[1], args[2], args[3]);
    }
    if (cmd == "resolve") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_resolve(args[1], args[2]);
    }
    if (cmd == "rebase") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_rebase(args[1], args[2]);
    }
    if (cmd == "status") {
        if (args.size() != 2)
            return usage(arg0.c_str(), true);
        return cmd_status(args[1]);
    }
    fprintf(stderr, "projeny: error: unknown command '%s'\n", cmd.c_str());
    return usage(arg0.c_str(), true);
}
