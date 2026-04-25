#!/usr/bin/env python3
"""Run one or more VIP VUnit regressions."""

import argparse
import subprocess
import sys
from pathlib import Path


VIP_NAMES = (
    "apb_vip",
    "axi4_lite_vip",
    "axi4_stream_vip",
    "axi4_full_vip",
    "i2c_vip",
    "i2s_vip",
    "spi_vip",
    "uart_vip",
)


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mode",
        choices=("docker", "native"),
        default="docker",
        help="Run regressions in Docker or with the host Python environment.",
    )
    parser.add_argument(
        "--image",
        default="modelsim:20.1",
        help="Docker image to use when --mode=docker.",
    )
    parser.add_argument(
        "--vip",
        action="append",
        choices=VIP_NAMES,
        help="VIP to run. Can be passed multiple times. Defaults to all VIPs.",
    )
    parser.add_argument(
        "vunit_args",
        nargs=argparse.REMAINDER,
        help="Arguments after '--' are forwarded to each VUnit run.py.",
    )
    return parser.parse_args()


def vunit_args_from_remainder(remainder):
    if remainder and remainder[0] == "--":
        return remainder[1:]
    return remainder


def build_command(repo_root, vip_name, args):
    tb_dir = repo_root / vip_name / "tb"
    run_args = vunit_args_from_remainder(args.vunit_args)

    if args.mode == "docker":
        return [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{repo_root}:/work",
            "-w",
            f"/work/{vip_name}/tb",
            args.image,
            "python3",
            "run.py",
            *run_args,
        ]

    return [
        sys.executable,
        "run.py",
        *run_args,
    ], tb_dir


def run_one(repo_root, vip_name, args):
    print(f"\n===== {vip_name} =====", flush=True)
    command = build_command(repo_root, vip_name, args)

    if args.mode == "native":
        command, cwd = command
        return subprocess.run(command, cwd=cwd, check=False).returncode

    return subprocess.run(command, cwd=repo_root, check=False).returncode


def main():
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    vip_names = args.vip if args.vip else VIP_NAMES

    for vip_name in vip_names:
        returncode = run_one(repo_root, vip_name, args)
        if returncode != 0:
            return returncode

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
