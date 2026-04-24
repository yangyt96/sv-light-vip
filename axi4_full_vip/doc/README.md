# AXI4 Full VIP (Verification IP)

A complete SystemVerilog-based verification IP for the AXI4 Full protocol, providing reusable master and slave verification components.

## Overview

AXI4 Full is an advanced memory-mapped protocol used in SoC designs. This VIP implements:

- **Full Protocol Support**: All AXI4 Full signals including ID, burst, size, length, QoS, region, lock, cache, and user sideband signals
- **Master and Slave Agents**: Complete verification components for both master and slave sides
- **Parameterizable**: Configurable address width, data width, ID width, and user signal widths
- **Flexible Transactions**: Support for single-beat and burst transactions with various configurations

## Directory Structure

```
axi4_full_vip/
├── sim/
│   ├── axi4_full_if.sv          # AXI4 Full interface with all protocol signals
│   ├── axi4_full_master_vip.sv  # Master VIP class with write/read tasks
│   └── axi4_full_slave_vip.sv   # Slave VIP class with transaction handlers
├── tb/
│   ├── axi4_full_dut.sv         # Example DUT (simple memory controller)
│   ├── axi4_full_vip_tb.sv      # Testbench with test scenarios
│   └── run.py                   # Simulation runner (optional)
├── doc/
│   └── README.md                # This file
└── run.py                        # Main simulation runner
```

## Key Features

### Write Transactions
The master VIP supports AXI4 write transactions with:
- Address channel (AW) with ID, length, size, burst type, protection signals
- Data channel (W) with byte enables (STRB)
- Response channel (B) with transaction ID and response code

### Read Transactions
The master VIP supports AXI4 read transactions with:
- Address channel (AR) with ID, length, size, burst type, protection signals
- Data channel (R) with read data, response code, and last signal

### Configuration Options
- **Pause Generator**: Add random delays between transactions on the master side
- **Backpressure**: Add random ready-signal delays on the slave side

## Usage Example

```systemverilog
// Create interface
axi4_full_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) axi_if(clk, rstn);

// Create and configure master VIP
Axi4FullMasterVIP #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) master;
master = new(axi_if.master, \"master_vip_0\");
master.configure_pause_generator(.enable(1'b1), .min_cycles(0), .max_cycles(5));

// Write transaction
logic [1:0] resp;
master.write(.addr(32'h1000), .data(32'hDEADBEEF), .strb(4'hF), .resp(resp));

// Read transaction  
logic [31:0] read_data;
master.read(.addr(32'h1000), .data(read_data), .resp(resp));
```

## Parameters

Default parameter values:
- `ADDR_WIDTH`: 32 bits
- `DATA_WIDTH`: 32 bits
- `ID_WIDTH`: 4 bits
- `LEN_WIDTH`: 8 bits (supports up to 256 beats per burst)
- `SIZE_WIDTH`: 3 bits
- `BURST_WIDTH`: 2 bits
- `PROT_WIDTH`: 3 bits
- `QOS_WIDTH`: 4 bits
- `STRB_WIDTH`: DATA_WIDTH/8 (byte enables)

## AXI4 Full Signal Summary

### Write Address Channel (AW)
| Signal | Description |
|--------|-------------|
| `awid` | Transaction ID |
| `awaddr` | Write address |
| `awlen` | Burst length (0-255) |
| `awsize` | Burst size (2^size bytes) |
| `awburst` | Burst type (0=FIXED, 1=INCR, 2=WRAP) |
| `awprot` | Protection type |
| `awqos` | Quality of Service |
| `awcache` | Cache policy |
| `awlock` | Atomic access signal |
| `awregion` | Region identifier |
| `awuser` | User sideband signal |
| `awvalid` / `awready` | Handshake signals |

### Write Data Channel (W)
| Signal | Description |
|--------|-------------|
| `wdata` | Write data |
| `wstrb` | Write strobes (byte enables) |
| `wlast` | Last transfer in burst |
| `wuser` | User sideband signal |
| `wvalid` / `wready` | Handshake signals |

### Write Response Channel (B)
| Signal | Description |
|--------|-------------|
| `bid` | Response ID |
| `bresp` | Response code (0=OKAY, 1=EXOKAY, 2=SLVERR, 3=DECERR) |
| `buser` | User sideband signal |
| `bvalid` / `bready` | Handshake signals |

### Read Address Channel (AR) & Read Data Channel (R)
Similar structure to AW and B channels with read-specific signals.

## Simulation

To run the testbench:

```bash
cd axi4_full_vip
python3 run.py  # If VUnit is available
# OR
cd tb
vlog -sv axi4_full_vip_tb.sv
vsim -do axi4_full_vip_tb.do work.axi4_full_vip_tb
```

## Test Scenarios

The included testbench demonstrates:
1. **Simple Write-Read**: Single transaction to address 0x1000
2. **Multiple Writes**: Sequential writes with different IDs
3. **Multiple Reads**: Sequential reads from written addresses
4. **Partial Writes**: Using byte strobes for selective byte updates

## Learning Points from Existing VIPs

This implementation learns from both:
- **axi4_lite_vip**: Simpler protocol structure, master/slave pattern, transaction logging
- **axi4_stream_vip**: Burst capabilities, user signals, modport design patterns

## Extending the VIP

To add more features:
1. **Burst Support**: Modify tasks to generate multiple beats with `wlast`/`rlast`
2. **Response Injection**: Add methods to configure slave responses per transaction
3. **Coverage**: Add functional coverage for protocol compliance
4. **Assertions**: Add SystemVerilog assertions for protocol checking
5. **UVM Adaptation**: Wrap VIP components in UVM agents, drivers, and monitors

## References

- AMBA AXI4 Protocol Specification
- ARM AMBA Specifications
- IEEE 1800 SystemVerilog LRM
