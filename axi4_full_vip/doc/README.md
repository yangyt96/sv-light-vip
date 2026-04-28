# AXI4 Full VIP

## Overview

`axi4_full_vip` is a lightweight AXI4-Full Verification IP written with
SystemVerilog classes and verified with VUnit. It provides a class-based master
API, a class-based slave VIP with backpressure, and a burst-capable memory
slave module.

The VIP currently includes:

- A parameterized AXI4-Full interface with ID, burst, size, cache, protection,
  QoS, region, and user sideband signals
- A master VIP with single-beat, burst, and channel-level read/write APIs
- A class-based slave VIP with configurable backpressure on all channels
- A byte-addressed memory slave VIP with `FIXED`, `INCR`, and `WRAP` address
  progression support
- Byte-strobe handling
- Optional pause generation on the master side
- Optional backpressure on the slave side
- Transaction logging to the simulator CLI
- Two VUnit testbenches: master+mem and slave VIP tests
- A ModelSim waveform setup file

## Folder Structure

```text
axi4_full_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── axi4_full_if.sv
│   ├── axi4_full_master_vip.sv
│   ├── axi4_full_mem_vip.sv          # Hardware memory slave module
│   ├── axi4_full_slave_vip.sv        # Class-based slave VIP with backpressure
│   └── axi4_full_vip_pkg.sv
├── tb/
│   ├── axi4_full_mem_vip_tb.do
│   ├── axi4_full_mem_vip_tb.sv           # Master + mem VIP testbench
│   ├── axi4_full_vip_tb.do
│   ├── axi4_full_vip_tb.sv     # Slave VIP testbench
│   └── run.py
```

## Main Components

### `axi4_full_if.sv`

Defines the AXI4-Full write-address, write-data, write-response, read-address,
and read-data channels with master and slave modports.

### `Axi4FullMasterVIP`

The master VIP drives AXI4-Full traffic through a virtual interface.

**Single-beat APIs:**

```systemverilog
master.write(addr, data, strb, id, len, size, burst, prot, resp);
master.read(addr, data, resp, id, len, size, burst, prot);
```

**Burst APIs:**

```systemverilog
master.write_burst(addr, data_array, strb_array, id, size, burst, prot, resp);
master.read_burst(addr, beat_count, data_array, resp_array, id, size, burst, prot);
```

**Channel-level APIs (fine-grained control):**

```systemverilog
// Write channel
master.send_awchn(addr, beat_count, id, size, burst, prot);
master.send_wchn(data_array, strb_array);
master.recv_bchn(resp);

// Read channel
master.send_archn(addr, beat_count, id, size, burst, prot);
master.recv_rchn(data_array, resp_array, id);
```

**Configuration:**

```systemverilog
master.configure_pause_generator(enable, min_cycles, max_cycles);
master.configure_timeout(cycles);
```

### `Axi4FullSlaveVIP`

The class-based slave VIP provides configurable backpressure on all channels.
Its API is symmetric with `Axi4FullMasterVIP`:

| Master | Slave |
|--------|-------|
| `send_awchn()` | `recv_awchn()` |
| `send_wchn()` | `recv_wchn()` |
| `recv_bchn()` | `send_bchn()` |
| `send_archn()` | `recv_archn()` |
| `recv_rchn()` | `send_rchn()` |
| `write_burst()` | `expect_write_burst()` |
| `read_burst()` | `respond_read_burst()` |
| `write()` | `expect_write_single()` |
| `read()` | `respond_read_single()` |

#### Channel-level APIs

```systemverilog
// Write channel
slave.recv_awchn(addr, id, len, size, burst, prot);
slave.recv_wchn(data, strb, last);
slave.send_bchn(id, resp);

// Read channel
slave.recv_archn(addr, id, len, size, burst, prot);
slave.send_rchn(data[], id, resp);
```

#### High-level APIs

```systemverilog
// Expect a complete write burst (AW + all W beats) and send B response
slave.expect_write_burst(data[], strb[], resp);

// Expect a single-beat write and send B response
slave.expect_write_single(data, strb, resp);

// Respond to a read burst (AR + all R beats)
slave.respond_read_burst(data[], resp);

// Respond to a single-beat read
slave.respond_read_single(data, resp);
```

**Configuration:**

```systemverilog
slave.configure_backpressure(enable, min_cycles, max_cycles);
slave.configure_timeout(cycles);
slave.clear_outputs();
```

### `axi4_full_mem_vip.sv`

The memory VIP is a single-outstanding AXI4 slave module. It stores data in a
byte-addressed array, returns `OKAY` responses, preserves response IDs, handles
`wstrb`, and advances burst addresses according to `awburst/arburst`.

## Testbench Summary

### `axi4_full_mem_vip_tb.sv` — Master + Mem VIP tests

| Test Case | Description |
|-----------|-------------|
| **Simple Write-Read** | Single write then read |
| **Multiple Write-Reads** | 8 write-read pairs with different IDs |
| **Partial Write Byte Mask** | Write with varying `wstrb` patterns |
| **INCR Burst Write-Read** | 8-beat INCR burst write then read |
| **FIXED Burst Byte Mask** | FIXED burst with byte mask |
| **Multiple Outstanding Writes** | 4 outstanding writes before reading back |
| **Multiple Outstanding Reads** | 4 outstanding reads |
| **Mixed Outstanding Read-Write** | Interleaved read/write outstanding |

### `axi4_full_vip_tb.sv` — Slave VIP tests

| Test Case | Description |
|-----------|-------------|
| **Basic Write-Read** | Single write then read via slave VIP |
| **Burst Write-Read** | 4-beat burst via slave VIP |
| **Slave Error Response** | Slave injects SLVERR on write and read |
| **Backpressure Write** | Slave stalls AW and W channels |
| **Backpressure Read** | Slave stalls AR and R channels |
| **Multiple Outstanding Transactions** | 4 outstanding writes then reads |
| **Mixed Backpressure All Channels** | Backpressure on all channels simultaneously |

## Running the Simulation

From the project root:

```bash
python3 axi4_full_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_full_vip/tb modelsim:20.1 python3 run.py
```
