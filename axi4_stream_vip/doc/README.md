# AXI Stream VIP

## Overview

`axi4_stream_vip` is a lightweight AXI4-Stream Verification IP written with
SystemVerilog classes and verified with VUnit. It provides simple class-based
source and sink APIs for driving and sampling AXI Stream traffic without a full
UVM environment.

The VIP currently includes:

- A parameterized AXI Stream interface
- A master VIP with `send_single` / `send_multi` APIs
- A slave VIP with `recv_single` / `recv_multi` APIs
- Optional pause generation on the master side
- Optional backpressure generation on the slave side
- Transaction logging to the simulator CLI
- A VUnit testbench with single-transfer, burst, continuous stream, and
  sideband signal coverage

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

Supported signals:

- `tdata`, `tvalid`, `tready`
- `tkeep`, `tstrb`, `tlast`
- `tid`, `tdest`, `tuser`

### `Axi4StreamMasterVIP`

The master VIP is a class-based traffic source.

Features:

- Parameterized by `DATA_WIDTH`, `KEEP_WIDTH`, `TID_WIDTH`, `TDEST_WIDTH`, `TUSER_WIDTH`
- Named instance support through the constructor
- Configurable pause generator (random pauses between beats in `send_multi`)
- CLI transaction logging using `TX`

Constructor:

```systemverilog
Axi4StreamMasterVIP #(DATA_WIDTH, KEEP_WIDTH) master;
master = new(axis_if.master, "master_vip");
```

Channel-level API (single beat):

```systemverilog
master.send_single(tdata, tkeep, tstrb, tlast, tid, tdest, tuser);
```

High-level API (multi-beat burst):

```systemverilog
master.send_multi(tdata_array, tkeep_array, tstrb_array, tlast_array,
                  tid_array, tdest_array, tuser_array);
```

Pause generation (applied between beats in `send_multi` only):

```systemverilog
master.configure_pause_generator(enable, min_cycles, max_cycles);
```

### `Axi4StreamSlaveVIP`

The slave VIP is a class-based traffic sink.

Features:

- Parameterized by `DATA_WIDTH`, `KEEP_WIDTH`, `TID_WIDTH`, `TDEST_WIDTH`, `TUSER_WIDTH`
- Named instance support through the constructor
- Configurable backpressure (random stalls between beats in `recv_multi`)
- CLI transaction logging using `RX`

Constructor:

```systemverilog
Axi4StreamSlaveVIP #(DATA_WIDTH, KEEP_WIDTH) slave;
slave = new(axis_if.slave, "slave_vip");
```

Channel-level API (single beat):

```systemverilog
slave.recv_single(tdata, tkeep, tstrb, tlast, tid, tdest, tuser);
```

High-level API (multi-beat burst until tlast):

```systemverilog
slave.recv_multi(tdata_array, tkeep_array, tstrb_array, tlast_array,
                 tid_array, tdest_array, tuser_array);
```

Backpressure generation (applied between beats in `recv_multi` only):

```systemverilog
slave.configure_backpressure(enable, min_cycles, max_cycles);
```

## Transaction Logging

Each `send_single` and `recv_single` call prints a transaction summary to
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
- a continuous streaming phase with parallel drive and receive activity

Current test cases:

| Test Case | Description |
|-----------|-------------|
| `BasicTransfers` | 48 single transfers, no pause/backpressure |
| `PauseGenerator` | 40 single transfers with master pause (1-4 cycles) |
| `Backpressure` | 40 single transfers with slave backpressure (2-6 cycles) |
| `ContinuousStream` | 64 continuous transfers in parallel fork |
| `BurstTransfers` | 10 random-length bursts (2-16 beats) |
| `SidebandSignals` | 16 transfers testing TID/TDEST/TUSER boundary values |

## Running the Simulation

From the project root:

```bash
python3 axi4_stream_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_stream_vip/tb modelsim:20.1 python3 run.py
```

Or via Makefile:

```bash
make test-axi4_stream_vip
```

## Notes

- Multiple VIP objects can be instantiated in one testbench as long as each
  object is connected to the intended interface instance or modport.
- The VIP is intentionally lightweight and class-based, making it useful for
  focused protocol checks and simple block-level verification.
- Master and slave share a single `axis_if` interface directly (no DUT between
  them), which is suitable for VIP bring-up and protocol-level testing.
