#!/usr/bin/env python3
"""
AXI4 Full VIP Test Runner using VUnit
"""

from pathlib import Path
from vunit import VUnit

# Get the directory of this script
root_dir = Path(__file__).parent
sim_dir = root_dir / "sim"
tb_dir = root_dir / "tb"
doc_dir = root_dir / "doc"

# Create VUnit instance with ModelSim as simulator
vu = VUnit.from_argv(compile_builtins=False)

# Add library
lib = vu.add_library("axi4_full_vip_lib")

# Add DUT and testbench
lib.add_source_file(tb_dir / "axi4_full_dut.sv")
lib.add_source_file(tb_dir / "axi4_full_vip_tb.sv")

# Set simulator options for ModelSim
vu.set_compile_option("modelsim.vlog_flags", ["-sv"])

# Run the tests
vu.main()
