# sv-light-vip  
**Lightweight, class‑based SystemVerilog Verification IPs (UVM‑free)**


## 🚀 Lightweight SystemVerilog Verification IPs  
**Pure SystemVerilog • Class‑Based • UVM‑Free • VUnit‑Ready • ModelSim‑Friendly**

This repository provides a collection of **lightweight, class‑based SystemVerilog Verification IPs (VIPs)** designed for engineers who want reusable, protocol‑accurate verification components **without the overhead of UVM**.

Each VIP is intentionally small, readable, and self‑contained. The structure is consistent across all protocols:

- `sim/` — reusable interfaces, transaction classes, drivers, monitors, scoreboards  
- `tb/` — self‑checking bring‑up testbenches with VUnit integration  
- `doc/` — protocol‑specific notes and diagrams  

Every VIP includes its own `tb/run.py`, keeping compile order explicit and avoiding hidden dependencies.

---

## 🧭 Motivation

Most open‑source verification resources fall into two extremes:

- **Heavy UVM frameworks** that require complex infrastructure and commercial simulators  
- **Minimal BFMs** that lack structure, reuse, and realistic protocol behavior  

This project fills the gap by providing:

- **Pure SystemVerilog, class‑based VIPs**  
- **No UVM, no factories, no phases**  
- **Accurate protocol behavior** for AXI, APB, UART, SPI, I2C, I2S  
- **VUnit + ModelSim ASE compatibility**  
- **Readable, hackable, and easy to integrate**  

The goal is to offer a practical, modern, open‑source VIP suite that works for FPGA/ASIC bring‑up, education, and small/medium verification environments.

---

## 📦 Supported VIPs

| VIP | Description |
|-----|-------------|
| **axi4_lite_vip** | AXI4‑Lite master + memory slave |
| **axi4_full_vip** | AXI4‑Full master + burst‑capable memory slave |
| **axi4_stream_vip** | AXI4‑Stream master/slave with small pipeline DUT |
| **apb_vip** | APB master/slave |
| **uart_vip** | UART TX/RX |
| **spi_vip** | SPI master/slave |
| **i2c_vip** | I2C master/slave with open‑drain bus model |
| **i2s_vip** | I2S stereo TX/RX |

All VIPs follow the same structure and coding style for consistency.

---

## 🧪 Running Regressions

### Run all VIPs (regression suite)

```bash
python3 run_all.py
```

### Run a single VIP

From the repository root:

```bash
python3 <vip_name>/tb/run.py
```

### Regression script options

```bash
python3 run_all.py --list    # List available VIPs
python3 run_all.py --gui     # Run with ModelSim GUI
python3 run_all.py --help    # Show help
```

## 🐳 Docker Environment
A ready‑to‑use ModelSim ASE Docker image is available:

```Code
https://github.com/yangyt96/docker-hdl-images/blob/master/modelsim-image/Dockerfile.modelsim
```

Run a single VIP inside Docker:
```bash
docker run --rm -v "$PWD":/work -w /work/<vip_name>/tb modelsim:20.1 python3 run.py
```

Run the full regression suite inside Docker:
```bash
docker run --rm -v "$PWD":/workspace -w /workspace modelsim:20.1 python3 run_all.py
```

## 🖥️ ModelSim GUI (via Docker)

```bash
xhost +local:docker
docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$PWD":/work \
  -w /work \
  modelsim:20.1
```

## 🧩 Project Philosophy
Human‑designed, AI‑assisted: AI tools were used to accelerate boilerplate and documentation, but all protocol behavior, architecture, and verification methodology are manually reviewed and engineered.

Lightweight by design: No UVM, no unnecessary abstraction layers.

Readable and educational: Suitable for learning, teaching, and real bring‑up.

Open and extendable: Contributions and extensions are welcome.

## 📜 License
This project is open‑source and available under the MIT license.

