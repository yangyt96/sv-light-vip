
from vunit import VUnit
from pathlib import Path

ROOT = Path(__file__).parents[0]

vu = VUnit.from_argv(compile_builtins=False)

vu.add_verilog_builtins()

lib = vu.add_library("lib")

lib.add_source_files(
    [
        ROOT / "*.sv",
    ],
    # include_dirs=ROOT.as_posix()
)


vu.main()
