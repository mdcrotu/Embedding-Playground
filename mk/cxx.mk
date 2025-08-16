# mk/cxx.mk
# Reusable C++ / SystemC helpers (no CMake required).
# Namespaced targets:
#   cxx.build   - build the binary
#   cxx.run     - run the binary
#   cxx.lint    - clang-tidy (if available)
#   cxx.format  - clang-format (if available)
#   cxx.clean   - remove build artifacts
#
# Variables you can override in your project Makefile:
#   CXX, CXX_STD, CXXFLAGS, LDFLAGS, LDLIBS
#   SRC_DIR, INC_DIRS, BUILD_DIR, BIN
#   SRCS (explicit sources if you prefer)
#   SYSTEMC_HOME (enables SystemC include/lib if set)
#   SYSTEMC_LIBDIR (defaults to $(SYSTEMC_HOME)/lib if SYSTEMC_HOME set)

CXX        ?= g++
CXX_STD    ?= c++20
SRC_DIR    ?= src
INC_DIRS   ?= include
BUILD_DIR  ?= build
BIN        ?= app

# Discover sources recursively by default (customize SRCS to override)
SRCS       ?= $(shell find $(SRC_DIR) -type f \( -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \) 2>/dev/null)
OBJS       := $(patsubst $(SRC_DIR)/%,$(BUILD_DIR)/%,$(SRCS:.cpp=.o))
OBJS       := $(OBJS:.cc=.o)
OBJS       := $(OBJS:.cxx=.o)

# Base flags
CXXFLAGS   ?= -std=$(CXX_STD) -Wall -Wextra -Wpedantic -O2
CXXFLAGS   += $(addprefix -I,$(INC_DIRS))
LDFLAGS    ?=
LDLIBS     ?=

# Optional SystemC support
ifdef SYSTEMC_HOME
  SYSTEMC_LIBDIR ?= $(SYSTEMC_HOME)/lib
  CXXFLAGS += -I$(SYSTEMC_HOME)/include
  LDFLAGS  += -L$(SYSTEMC_LIBDIR) -Wl,-rpath,$(SYSTEMC_LIBDIR)
  LDLIBS   += -lsystemc
endif

.PHONY: cxx.build cxx.run cxx.lint cxx.format cxx.clean

cxx.build: $(BUILD_DIR)/$(BIN)

cxx.run: cxx.build
	./$(BUILD_DIR)/$(BIN)

cxx.lint:
	@command -v clang-tidy >/dev/null 2>&1 || { echo "clang-tidy not found"; exit 0; }
	@echo "Running clang-tidy…"
	@clang-tidy $(SRCS) -- $(CXXFLAGS) $(CPPFLAGS) $(DEFINES) 2>/dev/null || true

cxx.format:
	@command -v clang-format >/dev/null 2>&1 || { echo "clang-format not found"; exit 0; }
	@echo "Formatting sources…"
	@clang-format -i $(SRCS) $(shell find $(INC_DIRS) -type f -name '*.[ch]pp' 2>/dev/null) || true

cxx.clean:
	rm -rf $(BUILD_DIR)

# Link
$(BUILD_DIR)/$(BIN): $(OBJS)
	@mkdir -p $(dir $@)
	$(CXX) $(LDFLAGS) -o $@ $^ $(LDLIBS)

# Compile
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cxx
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@
