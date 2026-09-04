# projeny - project tarball+patch manager.
# Original work for the Fil-C project, MIT-licensed.
# Runtime helpers shelled out to (direct posix_spawnp, no shell): tar, git, cp.
# Build requires only a C++17 compiler.
CXX ?= g++
CC ?= cc
CXXFLAGS ?= -std=c++17 -O2 -g -Wall -Wextra
CPPFLAGS ?=
LDFLAGS ?=

SRC := src/main.cc src/util.cc src/projeny_file.cc src/tree.cc src/ops.cc
OBJ := $(SRC:.cc=.o)
DEP := $(OBJ:.o=.d)
BIN := projeny

all: $(BIN)

$(BIN): $(OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJ) $(LDFLAGS)

# Automatic header dependencies; parallel-safe (-j).
%.o: %.cc
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

-include $(DEP)

test check: all
	./tests/run_tests.sh ./$(BIN)

clean:
	rm -f $(BIN) $(OBJ) $(DEP)

.PHONY: all test check clean
