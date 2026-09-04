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
            "usage: %s "
            "<setup|commit|add|rm|mv|resolve|rebase|status|diff|patch|package|extract|help> "
            "[args]\n"
            "  setup <f.projeny>\n"
            "  commit <f.projeny>\n"
            "  add <f.projeny> <path>\n"
            "  rm <f.projeny> <path>\n"
            "  mv <f.projeny> <src> <dst>\n"
            "  resolve <f.projeny> <path>\n"
            "  rebase <f.projeny> <new-tarball>\n"
            "  status <f.projeny>\n"
            "  diff <dir> <other-dir>\n"
            "  patch <dir> <patch-file>\n"
            "  package <f.projeny|dir> <output-tarball>\n"
            "  extract <f.projeny|dir> <dest-dir>\n"
            "  help [command]\n",
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
        if (args.size() == 1)
            return cmd_help(arg0);
        if (args.size() == 2)
            return cmd_help_topic(arg0, args[1]);
        return usage(arg0.c_str(), true);
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
    if (cmd == "diff") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_diff(args[1], args[2]);
    }
    if (cmd == "patch") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_patch(args[1], args[2]);
    }
    if (cmd == "package") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_package(args[1], args[2]);
    }
    if (cmd == "extract") {
        if (args.size() != 3)
            return usage(arg0.c_str(), true);
        return cmd_extract(args[1], args[2]);
    }
    fprintf(stderr, "projeny: error: unknown command '%s'\n", cmd.c_str());
    return usage(arg0.c_str(), true);
}
