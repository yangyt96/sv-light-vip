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
master.write_req_single(addr, data, strb, id, resp);
master.read_req_single(addr, data, resp, id);
```

**Burst APIs:**

```systemverilog
master.write_req_burst(addr, data_array, strb_array, id, size, burst, prot, resp);
master.read_req_burst(addr, beat_count, data_array, resp_array, id, size, burst, prot);
```

**Channel-level APIs (fine-grained control):**

```systemverilog
// Write channel
master.send_awchn(addr, beat_count, id, size, burst, prot);
master.send_wchn(data, strb, last);          // single beat (scalar)
master.recv_bchn(resp);

// Read channel
master.send_archn(addr, beat_count, id, size, burst, prot);
master.recv_rchn(data, resp, id, last);      // single beat (scalar)
```

**Configuration:**

```systemverilog
master.configure_pause_generator(enable, min_cycles, max_cycles);
master.configure_timeout(cycles);
```

**Complete usage example:**

```systemverilog
// 1. Create interface and VIP instances
axi4_full_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) axi_if (clk, rstn);
Axi4FullMasterVIP #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) master_vip;
master_vip = new(axi_if.master, "MASTER_VIP");
master_vip.clear_outputs();

// 2. Single-beat write-read
logic [1:0] resp;
logic [31:0] rd_data;
master_vip.write_req_single(.addr(32'h1000), .data(32'hDEADBEEF), .strb(4'hF), .id(4'd0), .resp(resp));
master_vip.read_req_single(.addr(32'h1000), .data(rd_data), .resp(resp), .id(4'd0));

// 3. Burst write-read (4 beats, INCR)
logic [31:0] wr_data[4] = '{32'hA, 32'hB, 32'hC, 32'hD};
logic [31:0] rd_data[4];
logic [1:0]  rd_resp[4];
master_vip.write_req_burst(.addr(32'h2000), .data(wr_data), .strb('{4'hF,4'hF,4'hF,4'hF}),
                           .id(4'd5), .burst(2'b01), .resp(resp));
master_vip.read_req_burst(.addr(32'h2000), .beat_count(4), .data(rd_data), .resp(rd_resp),
                          .id(4'd5), .burst(2'b01));

// 4. Channel-level: outstanding transactions
master_vip.send_awchn(.addr(32'h3000), .beat_count(1), .id(4'd0));
master_vip.send_wchn(.data(32'h1234), .strb(4'hF), .last(1'b1));
master_vip.recv_bchn(.resp(resp));
master_vip.send_archn(.addr(32'h3000), .beat_count(1), .id(4'd0));
master_vip.recv_rchn(.data(rd_data), .resp(resp), .id(rd_id), .last(rd_last), .ruser(rd_ruser));
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
| `write_req_burst()` | `write_resp_burst()` |
| `read_req_burst()` | `read_resp_burst()` |
| `write_req_single()` | `write_resp_single()` |
| `read_req_single()` | `read_resp_single()` |

#### Channel-level APIs

```systemverilog
// Write channel — recv_awchn captures all AW signals including optional sidebands
slave.recv_awchn(addr, id, len, size, burst, prot, cache, lock, qos, region, awuser);
slave.recv_wchn(data, strb, last, wuser);
slave.send_bchn(id, resp);

// Read channel — recv_archn captures all AR signals including optional sidebands
slave.recv_archn(addr, id, len, size, burst, prot, cache, lock, qos, region, aruser);
slave.send_rchn(data, id, resp, last);  // single beat (scalar)
```

#### High-level APIs

```systemverilog
// Respond to a complete write burst (AW + all W beats) and send B response
slave.write_resp_burst(data[], strb[], resp);

// Respond to a single-beat write and send B response
slave.write_resp_single(data, strb, resp);

// Respond to a read burst (AR + all R beats)
slave.read_resp_burst(data[], resp);

// Respond to a single-beat read
slave.read_resp_single(data, resp);
```

**Backpressure architecture:**

The slave VIP uses `apply_stall()` to inject random backpressure on all channels.
Following the same pattern as the Master's `apply_pause()`, `apply_stall()` is called
**only in high-level tasks** (`write_resp_*`, `read_resp_*`), NOT inside channel-level
APIs (`recv_awchn`, `recv_wchn`, `send_bchn`, `recv_archn`, `send_rchn`). This ensures
backpressure is applied between channel phases rather than within a single handshake,
matching real-world slave behavior.

```systemverilog
// Backpressure is applied between channel phases:
// recv_awchn → [apply_stall] → recv_wchn → [apply_stall] → send_bchn
```

**Configuration:**

```systemverilog
slave.configure_backpressure(enable, min_cycles, max_cycles);
slave.configure_timeout(cycles);
slave.clear_outputs();
```

**Complete usage example:**

```systemverilog
// 1. Create interface and VIP instances
axi4_full_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) axi_if (clk, rstn);
Axi4FullSlaveVIP #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) slave_vip;
slave_vip = new(axi_if.slave, "SLAVE_VIP");
slave_vip.clear_outputs();

// 2. Single-beat write response
slave_vip.write_resp_single(.data(32'hDEADBEEF), .strb(4'hF), .resp(2'b00));

// 3. Burst write response (4 beats)
logic [31:0] wr_data[4] = '{32'hA, 32'hB, 32'hC, 32'hD};
logic [3:0]  wr_strb[4] = '{4'hF, 4'hF, 4'hF, 4'hF};
slave_vip.write_resp_burst(.data(wr_data), .strb(wr_strb), .resp(2'b00));

// 4. Single-beat read response
slave_vip.read_resp_single(.data(32'h12345678), .resp(2'b00));

// 5. Burst read response (4 beats)
logic [31:0] rd_data[4] = '{32'hA, 32'hB, 32'hC, 32'hD};
slave_vip.read_resp_burst(.data(rd_data), .resp(2'b00));

// 6. Enable backpressure
slave_vip.configure_backpressure(.enable(1'b1), .min_cycles(0), .max_cycles(3));
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
| **Multiple Write-Reads** | 4 write-read pairs with different IDs |
| **Partial Write Byte Mask** | Write with varying `wstrb` patterns |
| **INCR Burst Write-Read** | 4-beat INCR burst write then read |
| **FIXED Burst Byte Mask** | FIXED burst with byte mask |
| **Multiple Outstanding Writes** | 4 outstanding writes before reading back |
| **Multiple Outstanding Reads** | 4 outstanding reads |
| **Mixed Outstanding Read-Write** | Interleaved read/write outstanding |
| **WRAP Burst Write-Read** | 4-beat WRAP burst on 16-byte boundary |
| **Outstanding Reads with Different IDs** | Two outstanding reads with different IDs, received in order (mem_vip is single-outstanding) |

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
| **WRAP Burst via Slave VIP** | 4-beat WRAP burst through slave VIP |

## Running the Simulation

From the project root:

```bash
python3 axi4_full_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_full_vip/tb modelsim:20.1 python3 run.py
```
