#!/usr/bin/env python3
"""
VUnit test runner for AXI Stream Master VIP
This script sets up and runs the UVM testbench using VUnit and ModelSim
"""

from pathlib import Path
from vunit import VUnit
import os

def main():
    # Get the directory where this script is located
    root = Path(__file__).parent.resolve()
    proj_root = root.parent.resolve()
    
    # Create VUnit instance
    vu = VUnit.from_argv(compile_builtins=False)
    
    # Add library
    lib = vu.add_library("lib")
    
    # Add UVM library files
    uvm_path = proj_root / "UVM" / "1.2" / "src"
    if not uvm_path.exists():
        print(f"ERROR: UVM library not found at {uvm_path}")
        return False
    
    print(f"Adding UVM sources from: {uvm_path}")
    # Add all UVM files recursively using glob pattern
    lib.add_source_files(str(uvm_path / "**" / "*.sv"))

    # Add VIP source files
    vip_path = proj_root / "axis_master"
    # Only add the package file - it includes all other VIP files
    pkg_file = vip_path / "axis_master_pkg.sv"
    lib.add_source_files(str(pkg_file))
    print(f"  Added: axis_master_pkg.sv (includes all VIP components)")
    
    # Add testbench files
    tb_path = root / "rtl"
    print(f"Adding testbench RTL from: {tb_path}")
    lib.add_source_files(str(tb_path / "*.sv"))
    
    tb_path = root / "tb"
    print(f"Adding testbench TB from: {tb_path}")
    lib.add_source_files(str(tb_path / "*.sv"))
    
    print("\nStarting VUnit tests...")
    
    # Run tests
    return vu.main()

if __name__ == "__main__":
    exit(0 if main() else 1)