# Lightweight System Verilog Verification IPs

This repository contains lightweight, class-based SystemVerilog verification IP
examples that can be compiled and run with VUnit and ModelSim. The VIPs are
kept intentionally small: each protocol has a `sim/` directory for reusable
interfaces/classes, a `tb/` directory for self-checking bring-up tests, and a
protocol README under `doc/`.

## VIPs

| VIP | Summary |
| --- | --- |
| `axi4_lite_vip` | AXI4-Lite master plus memory slave VIP |
| `axi4_full_vip` | AXI4-Full master plus burst-capable memory slave VIP |
| `axi4_stream_vip` | AXI4-Stream master/slave VIP with a small pipeline DUT |
| `uart_vip` | Direct UART TX/RX VIP, no DUT |
| `spi_vip` | Direct SPI master/slave VIP, no DUT |
| `i2c_vip` | Direct I2C master/slave VIP with open-drain bus model, no DUT |

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
