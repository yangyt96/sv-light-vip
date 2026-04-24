# AXI4-Lite VIP

## Overview

`axi4_lite_vip` is a lightweight AXI4-Lite Verification IP built in the same
style as `axi4_stream_vip`. It uses simple SystemVerilog classes for manager and
subordinate behavior and a VUnit regression for bring-up.

The package currently includes:

- a parameterized AXI4-Lite interface
- a master VIP for blocking `write` and `read` accesses
- a slave VIP for handling write/read requests and generating responses
- configurable master pause generation
- configurable slave backpressure
- CLI transaction logging with named VIP instances
- a pass-through DUT used to connect both VIPs in the testbench

## Folder Structure

```text
axi4_lite_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── axi4_lite_if.sv
│   ├── axi4_lite_master_vip.sv
│   └── axi4_lite_slave_vip.sv
├── tb/
│   ├── axi4_lite_dut.sv
│   └── axi4_lite_vip_tb.sv
└── run.py
```

## Main Components

### `axi4_lite_if.sv`

Defines a parameterized AXI4-Lite interface with all five AXI4-Lite channels:

- write address: `aw*`
- write data: `w*`
- write response: `b*`
- read address: `ar*`
- read data: `r*`

### `Axi4LiteMasterVIP`

The master VIP models an AXI4-Lite manager.

Main APIs:

```systemverilog
master.write(addr, data, strb, resp);
master.read(addr, data, resp);
```

Features:

- parameterized address and data widths
- optional pause generation before each transaction
- named instances through the constructor
- CLI logging for write and read activity

### `Axi4LiteSlaveVIP`

The slave VIP models an AXI4-Lite subordinate.

Main APIs:

```systemverilog
slave.handle_write(addr, data, strb, prot, resp);
slave.handle_read(addr, prot, data, resp);
```

Features:

- parameterized address and data widths
- optional backpressure/stall insertion
- named instances through the constructor
- CLI logging for write and read activity

## Testbench Summary

The VUnit testbench:

- instantiates an upstream AXI4-Lite interface and downstream AXI4-Lite interface
- places a simple pass-through DUT between them
- drives the upstream side with `Axi4LiteMasterVIP`
- services the downstream side with `Axi4LiteSlaveVIP`
- checks both write and read transactions

Current regression includes:

- 32 write transactions
- 32 read transactions
- a no-stall phase
- a phase with master pause generation and slave backpressure enabled

## Running the Simulation

From the project root:

```bash
python3 axi4_lite_vip/run.py
```

The runner compiles:

- `axi4_lite_vip/sim/*.sv`
- `axi4_lite_vip/tb/*.sv`
