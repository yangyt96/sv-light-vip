# AXI4-Lite VIP

## Overview

`axi4_lite_vip` is a lightweight AXI4-Lite Verification IP written with
SystemVerilog classes and verified with VUnit. It provides a class-based master
API, a class-based slave VIP with backpressure, and a simple memory slave module
for block-level bring-up without a full UVM environment.

The VIP currently includes:

- A parameterized AXI4-Lite interface with master and slave modports
- A master VIP with high-level `write`/`read` tasks and channel-level APIs
  (`send_awchn`, `send_wchn`, `recv_bchn`, `send_archn`, `recv_rchn`)
- A class-based slave VIP with configurable backpressure on all channels
- A memory slave VIP with byte-enable support
- Optional pause generation on the master side
- Optional backpressure on the slave side
- Transaction logging to the simulator CLI
- Two VUnit testbenches: master+mem and slave VIP tests
- A ModelSim waveform setup file

## Folder Structure

```text
axi4_lite_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── axi4_lite_if.sv
│   ├── axi4_lite_master_vip.sv
│   ├── axi4_lite_mem_vip.sv          # Hardware memory slave module
│   ├── axi4_lite_slave_vip.sv        # Class-based slave VIP with backpressure
│   └── axi4_lite_vip_pkg.sv
├── tb/
│   ├── axi4_lite_mem_vip_tb.do
│   ├── axi4_lite_mem_vip_tb.sv       # Master + mem VIP testbench
│   ├── axi4_lite_vip_tb.do
│   ├── axi4_lite_vip_tb.sv           # Slave VIP testbench
│   └── run.py
```

## Main Components

### `axi4_lite_if.sv`

Defines the five AXI4-Lite channels with master and slave modports:

- Write address: `awaddr`, `awprot`, `awvalid`, `awready`
- Write data: `wdata`, `wstrb`, `wvalid`, `wready`
- Write response: `bresp`, `bvalid`, `bready`
- Read address: `araddr`, `arprot`, `arvalid`, `arready`
- Read data: `rdata`, `rresp`, `rvalid`, `rready`

### `Axi4LiteMasterVIP`

The master VIP drives AXI4-Lite transactions through a virtual interface. It follows the same channel-level API pattern as the AXI4-Full Master VIP.

#### High-level APIs (convenience)

```systemverilog
master.write_req_single(addr, data, strb, resp, prot);
master.read_req_single(addr, data, resp, prot);
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

**Complete usage example:**

```systemverilog
// 1. Create interface and VIP instances
axi4_lite_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) axi_if (clk, rstn);
Axi4LiteMasterVIP #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) master_vip;
master_vip = new(axi_if.master, "MASTER_VIP");
master_vip.clear_outputs();

// 2. Single-beat write-read
logic [1:0] resp;
logic [31:0] rd_data;
master_vip.write_req_single(.addr(32'h1000), .data(32'hDEADBEEF), .strb(4'hF), .resp(resp));
master_vip.read_req_single(.addr(32'h1000), .data(rd_data), .resp(resp));

// 3. Channel-level: outstanding transactions
master_vip.send_awchn(.addr(32'h3000));
master_vip.send_wchn(.data(32'h1234), .strb(4'hF));
master_vip.recv_bchn(.resp(resp));
master_vip.send_archn(.addr(32'h3000));
master_vip.recv_rchn(.data(rd_data), .resp(resp));
```

### `Axi4LiteSlaveVIP`

The class-based slave VIP provides configurable backpressure on all channels.
Its API is symmetric with `Axi4LiteMasterVIP`:

| Master | Slave |
|--------|-------|
| `send_awchn()` | `recv_awchn()` |
| `send_wchn()` | `recv_wchn()` |
| `recv_bchn()` | `send_bchn()` |
| `send_archn()` | `recv_archn()` |
| `recv_rchn()` | `send_rchn()` |
| `write_req_single()` | `write_resp_single()` |
| `read_req_single()` | `read_resp_single()` |

#### Channel-level APIs

```systemverilog
// Write channel
slave.recv_awchn(addr, prot);
slave.recv_wchn(data, strb);
slave.send_bchn(resp);

// Read channel
slave.recv_archn(addr, prot);
slave.send_rchn(data, resp);
```

#### High-level APIs

```systemverilog
// Respond to a complete write (AW + W) and send B response
slave.write_resp_single(data, strb, resp);

// Respond to a read (AR + R)
slave.read_resp_single(data, resp);
```

**Backpressure architecture:**

The slave VIP uses `apply_stall()` to inject random backpressure on all channels.
Following the same pattern as the Master's `apply_pause()`, `apply_stall()` is called
**only in high-level tasks** (`write_resp_single`, `read_resp_single`), NOT inside
channel-level APIs (`recv_awchn`, `recv_wchn`, `send_bchn`, `recv_archn`, `send_rchn`).
This ensures backpressure is applied between channel phases rather than within a
single handshake, matching real-world slave behavior.

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
axi4_lite_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) axi_if (clk, rstn);
Axi4LiteSlaveVIP #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) slave_vip;
slave_vip = new(axi_if.slave, "SLAVE_VIP");
slave_vip.clear_outputs();

// 2. Single-beat write response
slave_vip.write_resp_single(.data(32'hDEADBEEF), .strb(4'hF), .resp(2'b00));

// 3. Single-beat read response
slave_vip.read_resp_single(.data(32'h12345678), .resp(2'b00));

// 4. Enable backpressure
slave_vip.configure_backpressure(.enable(1'b1), .min_cycles(0), .max_cycles(3));
```

### `axi4_lite_mem_vip.sv`

The memory VIP is a simple AXI4-Lite slave module. It stores data in a
byte-addressed array, returns `OKAY` responses, and honors `wstrb` byte enables
during writes.

## Testbench Summary

### `axi4_lite_mem_vip_tb.sv` — Master + Mem VIP tests

| Test Case | Description |
|-----------|-------------|
| **Write then Read** | Multiple writes with varying byte strobes, then readback verification |
| *(single test with 32 writes + 32 reads)* | |

### `axi4_lite_vip_tb.sv` — Slave VIP tests

| Test Case | Description |
|-----------|-------------|
| **Basic Write-Read** | Single write then read via slave VIP |
| **Slave Error Response** | Slave injects SLVERR on write and read |
| **Backpressure Write** | Slave stalls AW and W channels |
| **Backpressure Read** | Slave stalls AR and R channels |
| **Multiple Outstanding Transactions** | 4 outstanding writes then reads |
| **DECERR Response** | Slave injects DECERR on write and read |
| **EXOKAY Response** | Slave injects EXOKAY on write and read |
| **Mixed Backpressure All Channels** | Backpressure on all channels simultaneously |
| **Channel-Level Write with prot** | Write using channel-level APIs with prot signal |
| **Channel-Level Read with prot** | Read using channel-level APIs with prot signal |

## Running the Simulation

From the project root:

```bash
python3 axi4_lite_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_lite_vip/tb modelsim:20.1 python3 run.py
```

Or using the project Makefile:

```bash
make test-axi4_lite_vip
```
