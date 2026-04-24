import sys
from pathlib import Path

from vunit import VUnit

ROOT = Path(__file__).parents[0]

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

vu.main()
