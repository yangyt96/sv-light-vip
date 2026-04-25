# APB VIP

## Overview

`apb_vip` is a lightweight AMBA APB Verification IP written with
SystemVerilog classes and verified with VUnit. It follows the direct
VIP-to-VIP style used by the serial VIPs in this repository.

The VIP currently includes:

- A parameterized APB interface
- A master VIP with blocking `write` and `read` APIs
- A slave VIP with `expect_write` and `respond_read` APIs
- `PREADY` delay insertion on the slave side
- `PSTRB`, `PPROT`, and `PSLVERR` handling
- APB access stability checks and transaction timeout protection
- A self-checking VUnit testbench and ModelSim waveform setup

## Folder Structure

```text
apb_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── apb_if.sv
│   ├── apb_master_vip.sv
│   ├── apb_slave_vip.sv
│   └── apb_vip_pkg.sv
├── tb/
│   ├── apb_vip_tb.do
│   ├── apb_vip_tb.sv
│   └── run.py
```

## Main APIs

```systemverilog
master_vip.write(addr, data, strb, slverr, prot);
master_vip.read(addr, data, slverr, prot);

slave_vip.expect_write(addr, data, strb, prot, slverr);
slave_vip.respond_read(read_data, addr, prot, slverr);
```

## Running the Simulation

From the project root:

```bash
python3 apb_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/apb_vip/tb modelsim:20.1 python3 run.py
```
