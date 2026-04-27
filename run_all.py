#!/usr/bin/env python3
"""Run all VIP regressions.

Usage:
    python3 run_all.py              # Run all VIPs
    python3 run_all.py --gui        # Run with ModelSim GUI
    python3 run_all.py --list       # List available VIPs
"""

import subprocess
import sys
import os

# Use ASCII-safe markers for Docker environments without UTF-8 locale
PASS = "[PASS]"
FAIL = "[FAIL]"
WARN = "[WARN]"

# List of all VIPs in recommended execution order
# (simpler protocols first, more complex later)
VIPS = [
    "uart_vip",
    "spi_vip",
    "i2c_vip",
    "i2s_vip",
    "apb_vip",
    "axi4_lite_vip",
    "axi4_stream_vip",
    "axi4_full_vip",
]

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))


def run_vip(vip_name, extra_args=None):
    """Run a single VIP's test suite. Returns (vip_name, returncode)."""
    tb_dir = os.path.join(ROOT_DIR, vip_name, "tb")
    run_py = os.path.join(tb_dir, "run.py")

    if not os.path.exists(run_py):
        print(f"  {WARN} {vip_name}: run.py not found at {run_py}")
        return (vip_name, -1)

    cmd = [sys.executable, run_py]
    if extra_args:
        cmd.extend(extra_args)

    print(f"\n{'='*60}")
    print(f"  Running: {vip_name}")
    print(f"  Command: {' '.join(cmd)}")
    print(f"{'='*60}")

    result = subprocess.run(cmd, cwd=tb_dir)

    if result.returncode == 0:
        print(f"  {PASS} {vip_name}: ALL TESTS PASSED")
    else:
        print(f"  {FAIL} {vip_name}: FAILED (return code {result.returncode})")

    return (vip_name, result.returncode)


def main():
    extra_args = None

    if "--help" in sys.argv or "-h" in sys.argv:
        print(__doc__)
        return 0

    if "--list" in sys.argv:
        print("Available VIPs:")
        for vip in VIPS:
            tb_dir = os.path.join(ROOT_DIR, vip, "tb")
            run_py = os.path.join(tb_dir, "run.py")
            status = PASS if os.path.exists(run_py) else FAIL
            print(f"  {status} {vip}")
        return 0

    if "--gui" in sys.argv:
        extra_args = ["--gui"]

    print(f"sv-light-vip Regression Suite")
    print(f"{'='*60}")
    print(f"Starting {len(VIPS)} VIP test suites...\n")

    failures = []
    for vip in VIPS:
        name, rc = run_vip(vip, extra_args)
        if rc != 0:
            failures.append(name)

    print(f"\n{'='*60}")
    print(f"  RESULTS SUMMARY")
    print(f"{'='*60}")
    total = len(VIPS)
    passed = total - len(failures)
    print(f"  Total: {total}  |  Passed: {passed}  |  Failed: {len(failures)}")

    if failures:
        print(f"\n  {FAIL} FAILED VIPs:")
        for name in failures:
            print(f"     - {name}")
        return 1
    else:
        print(f"\n  {PASS} ALL TESTS PASSED")
        return 0


if __name__ == "__main__":
    sys.exit(main())
