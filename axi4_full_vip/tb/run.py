import sys
from pathlib import Path

from vunit import VUnit

ROOT = Path(__file__).resolve().parents[1]

argv = list(sys.argv[1:])

vu = VUnit.from_argv(argv=argv, compile_builtins=False)
vu.add_verilog_builtins()

lib = vu.add_library("lib")
lib.add_source_files(
    [
        ROOT / "tb/axi4_full_vip_tb.sv",
        ROOT / "tb/axi4_full_slave_vip_tb.sv",
    ],
    include_dirs=[
        (ROOT / "sim").as_posix(),
        (ROOT / "tb").as_posix(),
    ],
)

tb_vip = lib.test_bench("axi4_full_vip_tb")
tb_slave = lib.test_bench("axi4_full_slave_vip_tb")

tb_vip.set_sim_option(
    name="modelsim.init_file.gui",
    value=str(ROOT / "tb/axi4_full_vip_tb.do"),
)
tb_slave.set_sim_option(
    name="modelsim.init_file.gui",
    value=str(ROOT / "tb/axi4_full_slave_vip_tb.do"),
)

vu.set_compile_option("modelsim.vlog_flags", ["-sv"])

vu.main()
