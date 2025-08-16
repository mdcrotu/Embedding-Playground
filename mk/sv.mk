# mk/sv.mk
# Reusable SystemVerilog helpers.
# Namespaced targets:
#   sv.build     - compile elaborated sim (verilator or iverilog)
#   sv.run       - run simulation
#   sv.lint      - verilator --lint-only (if available)
#   sv.format    - verible-verilog-format (if available)
#   sv.clean     - remove build artifacts
#
# Variables you can override in your project Makefile:
#   SV_TOP        (top module name, default: top)
#   SV_SOURCES    (paths to RTL; default: find rtl/**/*.sv)
#   SV_TB         (testbench top; default: tb/tb.sv if exists)
#   SV_SIM        (verilator|iverilog; default: verilator)
#   SV_DEFINES    (e.g., +define+TRACE or -DTRACE depending on tool)
#   SV_INCLUDES   (list of +incdir+… or -I… depending on tool)
#   SV_BUILD_DIR  (default: build/sv)
#   SV_WAVES      (1 to enable tracing for verilator builds)

SV_TOP       ?= top
SV_BUILD_DIR ?= build/sv
SV_SIM       ?= verilator

# Discover sources (customize as needed)
SV_SOURCES   ?= $(shell find rtl -type f \( -name '*.sv' -o -name '*.v' \) 2>/dev/null)
# Default TB if present
SV_TB        ?= $(shell test -f tb/tb.sv && echo tb/tb.sv || echo "")

# Optional: tracing for Verilator
SV_WAVES     ?= 0

.PHONY: sv.build sv.run sv.lint sv.format sv.clean

sv.build:
ifeq ($(SV_SIM),verilator)
	@command -v verilator >/dev/null 2>&1 || { echo "verilator not found"; exit 1; }
	@mkdir -p $(SV_BUILD_DIR)
# Verilator flags: generates C++ sim under $(SV_BUILD_DIR)/obj_dir and a binary named V$(SV_TOP)
# Adjust includes/defines style for your project as needed.
	verilator -Wall --cc --exe --build \
		$(if $(filter 1,$(SV_WAVES)),--trace,) \
		$(SV_TB) $(SV_SOURCES) \
		-o $(SV_BUILD_DIR)/V$(SV_TOP) \
		-CFLAGS "-O2" \
		# Add include/define translations here if you maintain them as +incdir+/-D lists
else
	@command -v iverilog >/dev/null 2>&1 || { echo "iverilog not found"; exit 1; }
	@mkdir -p $(SV_BUILD_DIR)
	iverilog -g2012 -o $(SV_BUILD_DIR)/sim $(SV_SOURCES) $(SV_TB)
endif

sv.run: sv.build
ifeq ($(SV_SIM),verilator)
	$(SV_BUILD_DIR)/V$(SV_TOP)
else
	vvp $(SV_BUILD_DIR)/sim
endif

sv.lint:
	@command -v verilator >/dev/null 2>&1 || { echo "verilator not found"; exit 0; }
	@echo "Running verilator --lint-only…"
	verilator --lint-only -Wall $(SV_SOURCES) $(SV_TB)

sv.format:
	@command -v verible-verilog-format >/dev/null 2>&1 || { echo "verible-verilog-format not found"; exit 0; }
	@echo "Formatting SV files…"
	@verible-verilog-format -i $(SV_SOURCES) $(SV_TB)

sv.clean:
	rm -rf $(SV_BUILD_DIR)
