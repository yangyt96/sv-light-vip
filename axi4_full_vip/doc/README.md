# AXI4 Full VIP

## Overview

`axi4_full_vip` is a lightweight AXI4-Full Verification IP written with
SystemVerilog classes and verified with VUnit. It provides a class-based master
API and a burst-capable memory slave VIP.

The VIP currently includes:

- A parameterized AXI4-Full interface with ID, burst, size, cache, protection,
  QoS, region, and user sideband signals
- A master VIP with single-beat and burst read/write APIs
- A byte-addressed memory slave VIP with `FIXED`, `INCR`, and `WRAP` address
  progression support
- Byte-strobe handling
- Optional pause generation on the master side
- Transaction logging to the simulator CLI
- A VUnit testbench with single-beat, byte-mask, and burst checks
- A ModelSim waveform setup file

## Folder Structure

```text
axi4_full_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── axi4_full_if.sv
│   ├── axi4_full_master_vip.sv
│   ├── axi4_full_mem_vip.sv
│   └── axi4_full_vip_pkg.sv
├── tb/
│   ├── axi4_full_vip_tb.do
│   ├── axi4_full_vip_tb.sv
│   └── run.py
```

## Main Components

### `axi4_full_if.sv`

Defines the AXI4-Full write-address, write-data, write-response, read-address,
and read-data channels with master and slave modports.

### `Axi4FullMasterVIP`

The master VIP drives AXI4-Full traffic through a virtual interface.

Single-beat APIs:

```systemverilog
master.write(addr, data, strb, id, len, size, burst, prot, resp);
master.read(addr, data, resp, id, len, size, burst, prot);
```

Burst APIs:

```systemverilog
master.write_burst(addr, data_array, strb_array, id, size, burst, prot, resp);
master.read_burst(addr, beat_count, data_array, resp_array, id, size, burst, prot);
```

Channel APIs (for fine-grained control):

```systemverilog
// Write channel APIs
master.send_awchn(addr, beat_count, id, size, burst, prot);
master.send_wchn(data_array, strb_array);
master.recv_bchn(resp);

// Read channel APIs
master.send_archn(addr, beat_count, id, size, burst, prot);
master.recv_rchn(data_array, resp_array, id);
```

### `axi4_full_mem_vip.sv`

The memory VIP is a single-outstanding AXI4 slave. It stores data in a
byte-addressed array, returns `OKAY` responses, preserves response IDs, handles
`wstrb`, and advances burst addresses according to `awburst/arburst`.

## Testbench Summary

The VUnit testbench connects `Axi4FullMasterVIP` directly to
`axi4_full_mem_vip`. It checks:

- Simple write/read
- Multiple write/read transactions with IDs
- Partial byte-mask writes
- `INCR` burst write/read
- `FIXED` burst byte-mask behavior
- AXI4 master transaction timeout protection

## Running the Simulation

From the project root:

```bash
python3 axi4_full_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/axi4_full_vip/tb modelsim:20.1 python3 run.py
```
