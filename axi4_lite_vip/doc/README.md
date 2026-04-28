# AXI4-Lite VIP

## Overview

`axi4_lite_vip` is a lightweight AXI4-Lite Verification IP written with
SystemVerilog classes and verified with VUnit. It provides a class-based master
API and a simple memory slave module for block-level bring-up without a full UVM
environment.

The VIP currently includes:

- A parameterized AXI4-Lite interface
- A master VIP with high-level `write`/`read` tasks and channel-level APIs (`send_awchn`, `send_wchn`, `recv_bchn`, `send_archn`, `recv_rchn`)
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
│   ├── axi4_lite_mem_vip.sv
│   └── axi4_lite_vip_pkg.sv
├── tb/
│   ├── axi4_lite_vip_tb.do
│   ├── axi4_lite_vip_tb.sv
│   └── run.py
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

The master VIP drives AXI4-Lite transactions through a virtual interface. It follows the same channel-level API pattern as the AXI4-Full Master VIP.

#### High-level APIs (convenience)

```systemverilog
master.write(addr, data, strb, resp, prot);
master.read(addr, data, resp, prot);
```

#### Channel-level APIs (fine-grained control)

```systemverilog
master.send_awchn(addr, prot);     // Write Address Channel
master.send_wchn(data, strb);      // Write Data Channel
master.recv_bchn(resp);            // Write Response Channel
master.send_archn(addr, prot);     // Read Address Channel
master.recv_rchn(data, resp);      // Read Data Channel
```

#### Configuration

```systemverilog
master.configure_pause_generator(enable, min_cycles, max_cycles);
master.configure_timeout(cycles);
master.clear_outputs();            // Initialize all driven signals to zero
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
- AXI4-Lite master transaction timeout protection

## Running the Simulation

From the project root:

```bash
python3 axi4_lite_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_lite_vip/tb modelsim:20.1 python3 run.py
```
