#!/usr/bin/env python3
"""VUnit test runner for the AXI Stream Master VIP."""

from pathlib import Path

from vunit import VUnit

def main():
    root = Path(__file__).parent.resolve()
    proj_root = root.parent.resolve()

    vu = VUnit.from_argv(compile_builtins=False)
    vu.add_verilog_builtins()

    lib = vu.add_library("lib")

    uvm_path = proj_root / "UVM" / "1.2" / "src"
    if not uvm_path.exists():
        print(f"ERROR: UVM library not found at {uvm_path}")
        return False

    vip_path = proj_root / "axis_master"
    include_dirs = [str(uvm_path), str(vip_path)]
    defines = {"UVM_NO_DPI": ""}

    print(f"Adding UVM sources from: {uvm_path}")
    uvm_files = lib.add_source_files(
        str(uvm_path / "uvm_pkg.sv"),
        include_dirs=include_dirs,
        defines=defines,
        no_parse=True,
    )
    uvm_files.add_compile_option("modelsim.vlog_flags", ["-sv"])

    pkg_file = vip_path / "axis_master_pkg.sv"
    vip_files = lib.add_source_files(
        str(pkg_file),
        include_dirs=include_dirs,
        defines=defines,
        no_parse=True,
    )
    vip_files.add_compile_option("modelsim.vlog_flags", ["-sv"])
    vip_files.add_dependency_on(uvm_files)
    print("  Added: axis_master_pkg.sv")

    rtl_path = root / "rtl"
    print(f"Adding testbench RTL from: {rtl_path}")
    rtl_files = lib.add_source_files(
        str(rtl_path / "*.sv"),
        include_dirs=include_dirs,
        defines=defines,
        no_parse=True,
    )
    rtl_files.add_compile_option("modelsim.vlog_flags", ["-sv"])

    tb_path = root / "tb"
    print(f"Adding testbench TB from: {tb_path}")
    tb_files = lib.add_source_files(
        str(tb_path / "*.sv"),
        include_dirs=include_dirs,
        defines=defines,
    )
    tb_files.add_compile_option("modelsim.vlog_flags", ["-sv"])
    tb_files.add_dependency_on(vip_files)
    tb_files.add_dependency_on(rtl_files)

    print("\nStarting VUnit tests...")
    return vu.main()

if __name__ == "__main__":
    exit(0 if main() else 1)
