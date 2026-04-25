# Lightweight System Verilog Verification IPs

This repository contains lightweight, class-based SystemVerilog verification IP
examples that can be compiled and run with VUnit and ModelSim. The VIPs are
kept intentionally small: each protocol has a `sim/` directory for reusable
interfaces/classes, a `tb/` directory for self-checking bring-up tests, and a
protocol README under `doc/`.

Each `tb/run.py` compiles one top-level testbench. That testbench includes its
protocol interface, VIP package, and any local DUT/memory model through the
`sim/` and `tb/` include paths, so compile order stays explicit and consistent
across all VIPs. Reusable class-based VIP components are grouped in
`sim/*_vip_pkg.sv`; protocol interfaces and synthesizable-style helper modules
remain as normal standalone SystemVerilog units.

## VIPs

| VIP | Summary |
| --- | --- |
| `axi4_lite_vip` | AXI4-Lite master plus memory slave VIP |
| `axi4_full_vip` | AXI4-Full master plus burst-capable memory slave VIP |
| `axi4_stream_vip` | AXI4-Stream master/slave VIP with a small pipeline DUT |
| `apb_vip` | Direct APB master/slave VIP, no DUT |
| `uart_vip` | Direct UART TX/RX VIP, no DUT |
| `spi_vip` | Direct SPI master/slave VIP, no DUT |
| `i2c_vip` | Direct I2C master/slave VIP with open-drain bus model, no DUT |
| `i2s_vip` | Direct I2S stereo TX/RX VIP, no DUT |

## Docker Environment
Build from here
```
https://github.com/yangyt96/docker-hdl-images/blob/master/modelsim-image/Dockerfile.modelsim
```

## Running Regressions

From the repository root, run a VIP with:

```bash
python3 <vip_name>/tb/run.py
```

With the provided Docker image:

```bash
docker run --rm -v "$PWD":/work -w /work/<vip_name>/tb modelsim:20.1 python3 run.py
```

Example:

```bash
docker run --rm -v "$PWD":/work -w /work/i2c_vip/tb modelsim:20.1 python3 run.py
```

Run all VIP regressions with the local ModelSim Docker image:

```bash
python3 tools/run_all.py
```

Use `python3 tools/run_all.py --mode native` to run each `tb/run.py` directly
on the host, or `python3 tools/run_all.py --vip apb_vip` to run one VIP.

## GUI Use

For ModelSim GUI use through Docker:

```bash
xhost +local:docker
docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$PWD":/work \
  -w /work \
  modelsim:20.1
```

Most VIPs include a `tb/*_tb.do` waveform setup file and register it through
the VUnit `modelsim.init_file.gui` option.
