# minilute - a minimal lute-compatible Luau runtime for running sarcasm.
#
# Copyright (c) 2026 Filip Pizlo. All Rights Reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY FILIP PIZLO ``AS IS AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL FILIP PIZLO OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# ----------------------------------------------------------------------------
# Variables you may want to set (environment or make command line):
#
#   CC, CXX   - the C and C++ toolchains to use for BOTH minilute itself and
#               the vendored luau sub-build. Set these to your Fil-C compilers,
#               e.g.:
#
#                 make CC=$FILC/build/bin/clang CXX=$FILC/build/bin/clang++
#
#               (defaults: cc / c++)
#
#   LUAU_DIR  - location of the luau source tree that is built (release mode,
#               in-tree under LUAU_DIR/build/) and linked against.
#               (default: ../lute-1.0.0/extern/luau)
#
#   CONFIG    - luau build configuration (its Makefile's `config` variable).
#               (default: release)
#
# Targets:
#   all       - build the luau static libraries, then minilute (default)
#   clean     - remove minilute's own artifacts only (leaves luau's build/)
#   distclean - clean + remove LUAU_DIR/build entirely
# ----------------------------------------------------------------------------

CC ?= cc
CXX ?= c++

LUAU_DIR ?= ../lute-1.0.0/extern/luau
CONFIG ?= release

LUAU_BUILD := $(LUAU_DIR)/build/$(CONFIG)

# The luau static libraries minilute needs, as targets of luau's own Makefile
# (relative to LUAU_DIR) and as paths (for linking).
LUAU_LIB_NAMES := libluauvm.a libluaucompiler.a libluauast.a libluauconfig.a libluaurequire.a libluaucommon.a
LUAU_LIB_TARGETS := $(LUAU_LIB_NAMES:%=build/$(CONFIG)/%)
LUAU_LIBS := $(LUAU_LIB_NAMES:%=$(LUAU_BUILD)/%)

# Anything that could require a luau rebuild. Luau's own Makefile does the real
# incremental work; this stamp just decides when to re-invoke it.
LUAU_SOURCES := $(shell find $(LUAU_DIR)/VM/src $(LUAU_DIR)/Compiler/src $(LUAU_DIR)/Ast/src $(LUAU_DIR)/Config/src $(LUAU_DIR)/Common/src $(LUAU_DIR)/Require/src $(LUAU_DIR)/VM/include $(LUAU_DIR)/Compiler/include $(LUAU_DIR)/Ast/include $(LUAU_DIR)/Config/include $(LUAU_DIR)/Common/include $(LUAU_DIR)/Require/include -type f 2>/dev/null) $(LUAU_DIR)/Makefile

LUAU_STAMP := $(LUAU_BUILD)/.minilute-luau.stamp

LUAU_INCLUDES := \
	-I$(LUAU_DIR)/VM/include \
	-I$(LUAU_DIR)/Compiler/include \
	-I$(LUAU_DIR)/Ast/include \
	-I$(LUAU_DIR)/Config/include \
	-I$(LUAU_DIR)/Common/include \
	-I$(LUAU_DIR)/Require/include

CXXFLAGS ?= -O2 -g
ALL_CXXFLAGS := $(CXXFLAGS) -std=c++17 -Wall $(LUAU_INCLUDES)

OBJS := minilute.o pathutils.o fs.o process.o require.o

all: minilute

$(LUAU_STAMP): $(LUAU_SOURCES)
	$(MAKE) -C $(LUAU_DIR) config=$(CONFIG) CC="$(CC)" CXX="$(CXX)" $(LUAU_LIB_TARGETS)
	touch $@

minilute: $(OBJS) $(LUAU_STAMP)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $(OBJS) -Wl,--start-group $(LUAU_LIBS) -Wl,--end-group

%.o: %.cpp
	$(CXX) $(ALL_CXXFLAGS) -MMD -MP -c -o $@ $<

clean:
	rm -f minilute $(OBJS) $(OBJS:.o=.d)

distclean: clean
	rm -rf $(LUAU_DIR)/build

.PHONY: all clean distclean

-include $(OBJS:.o=.d)
