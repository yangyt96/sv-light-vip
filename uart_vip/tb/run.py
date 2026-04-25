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
        ROOT / "sim/*.sv",
        ROOT / "tb/*.sv",
    ],
    include_dirs=[(ROOT / "sim").as_posix()],
)

lib.set_sim_option(
    name="modelsim.init_file.gui",
    value=str(ROOT / "tb/uart_vip_tb.do"),
)

vu.main()
