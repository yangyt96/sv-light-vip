# AXI Stream VIP

## Overview

`axi4_stream_vip` is a lightweight AXI4-Stream Verification IP written with
SystemVerilog classes and verified with VUnit. It provides simple class-based
source and sink APIs for driving and sampling AXI Stream traffic without a full
UVM environment.

The VIP currently includes:

- A parameterized AXI Stream interface
- A master VIP with `transmit`
- A slave VIP with `receive`
- Optional pause generation on the master side
- Optional backpressure generation on the slave side
- Transaction logging to the simulator CLI
- A VUnit testbench with both exact transfer checks and continuous streaming
  coverage

## Folder Structure

```text
axi4_stream_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── axi4_stream_if.sv
│   ├── axi4_stream_master_vip.sv
│   ├── axi4_stream_slave_vip.sv
│   └── axi4_stream_vip_pkg.sv
├── tb/
│   ├── axi4_stream_dut.sv
│   ├── axi4_stream_vip_tb.do
│   ├── axi4_stream_vip_tb.sv
│   └── run.py
```

## Main Components

### `axi4_stream_if.sv`

Defines the shared AXI Stream interface and modports:

- `master`: drives `tvalid`, `tdata`, `tkeep`, `tstrb`, `tlast`, `tid`,
  `tdest`, `tuser`
- `slave`: drives `tready` and samples the source signals

Supported sideband signals:

- `tdata`
- `tvalid`
- `tready`
- `tkeep`
- `tstrb`
- `tlast`
- `tid`
- `tdest`
- `tuser`

### `Axi4StreamMasterVIP`

The master VIP is a class-based traffic source.

Features:

- Parameterized by `DATA_WIDTH` and `KEEP_WIDTH`
- Named instance support through the constructor
- Configurable pause generator
- CLI transaction logging using `TX`

Constructor:

```systemverilog
Axi4StreamMasterVIP #(DATA_WIDTH, KEEP_WIDTH) master;
master = new(s_axis_if.master, "master_vip");
```

Main API:

```systemverilog
master.transmit(tdata, tkeep, tstrb, tlast, tid, tdest, tuser);
```

Pause generation:

```systemverilog
master.configure_pause_generator(enable, min_cycles, max_cycles);
```

### `Axi4StreamSlaveVIP`

The slave VIP is a class-based traffic sink.

Features:

- Parameterized by `DATA_WIDTH` and `KEEP_WIDTH`
- Named instance support through the constructor
- Configurable backpressure
- CLI transaction logging using `RX`

Constructor:

```systemverilog
Axi4StreamSlaveVIP #(DATA_WIDTH, KEEP_WIDTH) slave;
slave = new(m_axis_if.slave, "slave_vip");
```

Main API:

```systemverilog
slave.receive(tdata, tkeep, tstrb, tlast, tid, tdest, tuser);
```

Backpressure generation:

```systemverilog
slave.configure_backpressure(enable, min_cycles, max_cycles);
```

## Transaction Logging

Each `transmit` and `receive` call prints a transaction summary to
the simulator CLI.

Example format:

```text
[55] master_vip TX tdata=... tkeep=... tstrb=... tlast=... tid=... tdest=... tuser=...
[65] slave_vip  RX tdata=... tkeep=... tstrb=... tlast=... tid=... tdest=... tuser=...
```

This is useful for quick bring-up, debug, and correlating stimulus with DUT
behavior.

## Testbench Summary

The VUnit testbench in `tb/axi4_stream_vip_tb.sv` uses:

- `DATA_WIDTH = 64`
- named master/slave VIP instances
- exact end-to-end checking for single transfers
- a continuous streaming phase with parallel drive and monitor activity

Current coverage includes:

- basic transfers
- pause generator enabled on the master
- backpressure enabled on the slave
- continuous packet injection and continuous packet observation
- ready/valid payload stability checks while stalled
- master/slave transaction timeout protection

The DUT in `tb/axi4_stream_dut.sv` is a simple one-stage AXI Stream pipeline used
for VIP bring-up and regression.

## Running the Simulation

From the project root:

```bash
python3 axi4_stream_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_stream_vip/tb modelsim:20.1 python3 run.py
```

The VUnit runner compiles `tb/axi4_stream_vip_tb.sv` as the single top-level
testbench. The testbench includes the interface, VIP classes, and local DUT
through the `sim/` and `tb/` include paths.

## Notes

- Multiple VIP objects can be instantiated in one testbench as long as each
  object is connected to the intended interface instance or modport.
- The VIP is intentionally lightweight and class-based, making it useful for
  focused protocol checks and simple block-level verification.
