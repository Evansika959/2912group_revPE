# ==============================
# Open-Source Flow Makefile
# Replaces VCS/DC/Innovus with: iverilog + yosys + gtkwave
# Project layout expected (similar to your original):
#   - ../verilog/modules/*.sv           RTL sources
#   - ../verilog/testbench/mult_tb.sv   Testbench (should dump VCD)
#   - syn/ (generated here)
#   - vsim/ (generated here)
# ==============================

##### GF180 library Verilog models (behavioral) #####
# GF_STD_ROOT  := ../gf180mcu/gf180mcuD/lib.ref/gf180mcu_fd_sc_mcu7t5v0/latest
# IO_ROOT      := ../gf180mcu/gf180mcuD/lib.ref/gf180mcu_fd_io/latest
# SRAM_ROOT    := /oscar/data/class/engn2912e/shared/gf180mcu-pdk/macros/gf180mcu_fd_ip_sram/latest

# Collect common behavioral views (functional + UDPs/primitives)
# GF_STD_MODELS := $(shell find $(GF_STD_ROOT)/models -type f \
#   \( -iname "*verilog_pg*.v" -o -iname "*verilog_nonpg*.v" \
#      -o -iname "*udp*.v" -o -iname "primitives*.v" -o -iname "*_udp.v" \) \
#   | sort -u)

# GF_STD_FUNCTIONAL := $(shell find $(GF_STD_ROOT)/cells -type f -name "*.functional.v" | sort -u)

# UDP_MAP_ALIASES    := /oscar/data/class/engn2912e/shared/gf180mcu-pdk/contrib/udp_name_map/udp_aliases.v

# STD_CELLS := $(UDP_MAP_ALIASES) $(GF_STD_MODELS) $(GF_STD_FUNCTIONAL)

# Liberty for synthesis (pick a typical corner). Adjust if needed.
# LIB_SYN ?= /oscar/data/class/engn2912e/shared/gf180mcu-pdk/contrib/lib_to_db/merged_libs/gf180mcu_fd_sc_mcu7t5v0__tt_025C_1v80__COMBINED.lib
# If the above resolves to empty or a wrong file, set LIB_SYN explicitly:
# LIB_SYN := /path/to/gf180mcu_fd_sc_mcu7t5v0__tt_5v0_25c.lib

##### Sources #####

TARGET = reversible_pe

# SIM_FILES       = ./verilog/modules/$(TARGET).sv
SIM_FILES = $(wildcard ./verilog/modules/*.sv ./verilog/modules/*.svh)
TOP_LEVEL_TESTBENCH = ./verilog/testbench/$(TARGET)_tb.sv
TOP             ?= $(TARGET)

# Clock period for synthesis and STA (in ns). DO NOT CHANGE!
CLK_PERIOD	    ?= 50

# Gate-level netlist output from Yosys
SYN_DIR         := syn
SYN_NETLIST     := $(SYN_DIR)/$(TOP).syn.v
PERIOD_TAG      := $(SYN_DIR)/.clk_period_$(subst .,_,${CLK_PERIOD})

# Simulation output artifacts
VSIM_DIR        := vsim
RTL_VVP         := $(VSIM_DIR)/rtl.vvp
GL_VVP          := $(VSIM_DIR)/gl.vvp
RTL_VCD         ?= $(VSIM_DIR)/rtl.vcd
GL_VCD          ?= $(VSIM_DIR)/gl.vcd

# Tools
IVERILOG := iverilog
VVP      := vvp
YOSYS    := yosys
GTKWAVE  := gtkwave

# Icarus Verilog flags (SV 2012 support; add include dirs as needed)
# IVFLAGS  := -g2012 -Wall -I../verilog/modules
IVFLAGS  := -g2012 -I./verilog/modules

# If your TB supports a macro to set the VCD file, pass it here (optional):
#   In TB: `ifdef VCD_FILE initial $dumpfile(`"VCD_FILE`"); `endif
# IVDEFS_RTL := -D VCD_FILE=\"$(RTL_VCD)\"
# IVDEFS_GL  := -D SYN=1 -D VCD_FILE=\"$(GL_VCD)\"

.PHONY: all clean sim synth sim_syn view view_syn envcheck

all: clean sim synth sim_syn

# --------------------
# Golden Brick
# --------------------
c_compile:
	cd goldenbrick; gcc -Wall -ggdb -o goldenbrick goldenbrick.c
	cd goldenbrick; ./goldenbrick

# --------------------
# Environment checks
# --------------------
envcheck:
	@command -v $(IVERILOG) >/dev/null || { echo "[ERR] iverilog not found in PATH"; exit 1; }
	@command -v $(YOSYS)    >/dev/null || { echo "[ERR] yosys not found in PATH"; exit 1; }
	@mkdir -p $(VSIM_DIR) $(SYN_DIR)
	@echo "[OK] Tools present. Using LIB_SYN=$(LIB_SYN)"

# --------------------
# Behavioral Simulation
# --------------------
sim: envcheck
	@echo "[RTL] Compile behavioral RTL with Icarus Verilog"
	$(IVERILOG) $(IVFLAGS) -o $(RTL_VVP) \
	-DVCD_FILE=\"$(RTL_VCD)\" $(SIM_FILES) $(TOP_LEVEL_TESTBENCH)
	$(VVP) $(RTL_VVP) -q

check_behavior: sim c_compile
	@echo "[CHK] Comparing testbench output to golden brick..."
	if diff ./goldenbrick/goldenbrick.txt $(VSIM_DIR)/rtl_sim_output.txt; then \
		echo "Outputs match! Behavioral model passed!"; \
	else \
		echo "Outputs differ!"; \
	fi

# --------------------
# OpenROAD-style Synthesis (standalone simplified)
# Make the netlist a real target so deleting it forces re-synthesis.
# --------------------
.PHONY: run_syn
run_syn: $(SYN_NETLIST)
	@echo "[SYN][OR] Netlist is up to date: $(SYN_NETLIST)"

# Netlist build rule
$(SYN_NETLIST): envcheck syn/run_synth.tcl $(SIM_FILES) $(LIB_SYN) Makefile $(PERIOD_TAG)
	@echo "[SYN][OR] Generating $(SYN_NETLIST) via Yosys"
	LIB_SYN=$(LIB_SYN) CLK_PERIOD=$(CLK_PERIOD) $(YOSYS) -ql syn/run_synth.log -c syn/run_synth.tcl
	@test -f $(SYN_NETLIST) || { echo "[ERR] Synthesis did not produce $(SYN_NETLIST)"; exit 1; }
	@echo "[SYN][OR] Done. Log: syn/run_synth.log"

# Tag file changes when CLK_PERIOD changes to force rebuild
$(PERIOD_TAG):
	@rm -f $(SYN_DIR)/.clk_period_*
	@touch $@

# --------------------
# Gate-level Simulation
# --------------------
sim_syn: run_syn c_compile
	@echo "[GL] Compile gate-level with Icarus Verilog"
	$(IVERILOG) $(IVFLAGS) -o $(GL_VVP) \
	  $(STD_CELLS) $(SYN_NETLIST) $(TOP_LEVEL_TESTBENCH) \
	  $(IVDEFS_GL) -D VSIM_OUT=\"$(VSIM_DIR)/gl_sim_output.txt\" -D VCD_FILE=\"$(GL_VCD)\"
	$(VVP) $(GL_VVP)

check_syn: sim_syn c_compile
	@echo "[CHK] Comparing gate-level output to golden brick..."
	if diff ./goldenbrick/goldenbrick.txt $(VSIM_DIR)/gl_sim_output.txt; then \
		echo "Outputs match! Gate-level netlist passed!"; \
	else \
		echo "Outputs differ!"; \
	fi

# --------------------
# View Waveforms
# --------------------
view_syn: sim_syn
	@if [ -f "$(GL_VCD)" ]; then $(GTKWAVE) $(GL_VCD) & else echo "No GL VCD at $(GL_VCD)"; fi

view_behavior: sim
	@if [ -f "$(RTL_VCD)" ]; then $(GTKWAVE) $(RTL_VCD) & else echo "No RTL VCD at $(RTL_VCD)"; fi

# --------------------
# Static Timing Analysis (OpenSTA)
# --------------------
STA ?= sta
STA_LIB ?= $(LIB_SYN)
sta: $(SYN_NETLIST)
	@echo "[STA] Running OpenSTA on synthesized netlist"
	@if [ ! -d sta ]; then mkdir -p sta; fi
	LIB_SYN=$(STA_LIB) CLK_PERIOD=$(CLK_PERIOD) $(STA) sta/sta.tcl | tee sta/sta.log
	@echo "[STA] Done. Reports in sta/report_*.txt"

# --------------------
# Clean
# --------------------
clean:
	@rm -rf $(VSIM_DIR)/*.vvp $(VSIM_DIR)/*.vcd $(SYN_DIR)/*.v  $(SYN_DIR)/reports/\
	        $(VSIM_DIR)/*.txt $(SYN_DIR)/*.log $(SYN_DIR)/.clk_period_* \
			goldenbrick/goldenbrick.txt goldenbrick/A.txt goldenbrick/B.txt goldenbrick/At.txt goldenbrick/Bt.txt goldenbrick/goldenbrick\
			sta/sta.log sta/report_*.txt
	@echo "[CLEAN] Done."

# Notes:
# * SDF back-annotation is not supported by Icarus Verilog.
