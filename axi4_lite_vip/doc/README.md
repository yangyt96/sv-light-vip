# AXI4-Lite VIP

## Overview

`axi4_lite_vip` is a lightweight AXI4-Lite Verification IP written with
SystemVerilog classes and verified with VUnit. It provides a class-based master
API and a simple memory slave module for block-level bring-up without a full UVM
environment.

The VIP currently includes:

- A parameterized AXI4-Lite interface
- A master VIP with blocking `write` and `read` tasks
- A memory slave VIP with byte-enable support
- Optional pause generation on the master side
- Transaction logging to the simulator CLI
- A VUnit testbench with write/read and byte-mask checks
- A ModelSim waveform setup file

## Folder Structure

```text
axi4_lite_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── axi4_lite_if.sv
│   ├── axi4_lite_master_vip.sv
│   └── axi4_lite_mem_vip.sv
├── tb/
│   ├── axi4_lite_vip_tb.do
│   └── axi4_lite_vip_tb.sv
└── run.py
```

## Main Components

### `axi4_lite_if.sv`

Defines the five AXI4-Lite channels:

- Write address: `awaddr`, `awprot`, `awvalid`, `awready`
- Write data: `wdata`, `wstrb`, `wvalid`, `wready`
- Write response: `bresp`, `bvalid`, `bready`
- Read address: `araddr`, `arprot`, `arvalid`, `arready`
- Read data: `rdata`, `rresp`, `rvalid`, `rready`

### `Axi4LiteMasterVIP`

The master VIP drives AXI4-Lite transactions through a virtual interface.

Main APIs:

```systemverilog
master.write(addr, data, strb, resp, prot);
master.read(addr, data, resp, prot);
```

Pause generation:

```systemverilog
master.configure_pause_generator(enable, min_cycles, max_cycles);
```

### `axi4_lite_mem_vip.sv`

The memory VIP is a simple AXI4-Lite slave module. It stores 32-bit words and
honors `wstrb` byte enables during writes.

## Testbench Summary

The VUnit testbench connects one master VIP directly to `axi4_lite_mem_vip`.
It checks:

- Multiple writes
- Multiple reads
- Readback data correctness
- Byte-strobe masking
- Master pause generation

## Running the Simulation

From the project root:

```bash
python3 axi4_lite_vip/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_lite_vip modelsim:20.1 python3 run.py
```
