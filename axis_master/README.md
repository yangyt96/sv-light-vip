# AXI Stream Master Verification IP (VIP)

## Overview

This is a complete AXI Stream Master Verification IP (VIP) based on UVM 1.2. The VIP is designed to generate stimulus transactions on an AXI Stream master interface and verify the functionality of AXI Stream slave devices.

## Project Structure

```
axis_master/                     # AXI Stream Master VIP
├── axis_master_defines.svh      # Global defines and parameters
├── axis_master_pkg.sv           # Package file with all VIP components
├── axis_master_test.sv          # Base test class
├── agent/                       # Agent components
│   ├── axis_master_agent.sv     # Top-level agent
│   ├── axis_master_driver.sv    # Driver for master interface
│   ├── axis_master_monitor.sv   # Passive monitor
│   └── axis_master_sequencer.sv # Sequencer for command generation
├── env/                         # Environment components
│   ├── axis_master_env.sv       # Verification environment
│   └── axis_master_interface.sv # SystemVerilog interface definition
└── sequences/                   # Stimulus sequences
    ├── axis_master_seq_item.sv  # Transaction definition
    └── axis_master_sequences.sv # Sequence definitions

axis_vip_tb/                     # VUnit Testbench
├── run.py                       # VUnit test runner script
├── rtl/                         # RTL design (DUT)
│   └── axis_slave_dut.sv        # Simple AXI Stream slave for testing
└── tb/                          # Testbench files
    └── tb_axis_master_vip.sv    # Top-level testbench module
```

## Features

- **Full AXI Stream Protocol Support**
  - tdata: Data payload (configurable width)
  - tvalid: Transfer valid signal
  - tready: Transfer ready signal
  - tlast: Last transfer in burst indicator
  - tstrb: Byte strobes (valid bytes)
  - tkeep: Byte enable mask
  - tuser: User-defined sideband signals
  - tid: Transaction ID (optional)
  - tdest: Destination (optional)

- **UVM 1.2 Compliant**
  - Follows UVM methodology and best practices
  - Proper phase-based execution
  - Config database integration
  - Virtual interface usage

- **Reusable Components**
  - Configurable data width via defines
  - Parameterized sequences for various test scenarios
  - Monitor for passive observation
  - Full reporting and statistics

- **VUnit Integration**
  - Easy to run with VUnit command line
  - Integrates with ModelSim simulator
  - Support for coverage and assertions

## How to Use

### Setup Environment

```bash
cd /mnt/maxtor/Project/uvm_vip
source source_me.sh
```

### Run Tests with VUnit

```bash
cd axis_vip_tb
python3 run.py --help              # Show help
python3 run.py --compile           # Compile only
python3 run.py                     # Run all tests
python3 run.py -g test_random      # Run specific test
python3 run.py --gui               # Run with GUI
```

### Creating Custom Tests

Create a new test class extending `axis_master_test`:

```systemverilog
class my_custom_test extends axis_master_test;
    `uvm_component_utils(my_custom_test)
    
    function new(string name = "my_custom_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    task run_phase(uvm_phase phase);
        my_custom_seq seq;
        phase.raise_objection(this);
        
        seq = my_custom_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask
endclass
```

### Available Sequences

1. **axis_master_random_seq** - Generates random transactions
2. **axis_master_burst_seq** - Generates burst transfers with tlast
3. **axis_master_fixed_pattern_seq** - Generates fixed pattern data

### Configuration

Edit `axis_master_defines.svh` to:
- Change `AXIS_DATA_WIDTH` for different data widths
- Enable/disable optional signals (TSTRB, TLAST, TKEEP)
- Set maximum data width limits

## VIP Interface

The VIP provides these analysis ports:
- `agent.monitor.item_collected_port` - Outputs monitored transactions

## Test Environment

The included testbench (`axis_vip_tb`) includes:
- A simple AXI Stream slave DUT that always accepts transfers
- Transfer counter and error detection
- Integration with ModelSim/ModelSim Altera Edition

## Simulation

The testbench generates waveforms in VCD format (`wave.vcd`) for debugging.

## UVM Library Path

The VIP uses UVM 1.2 located at `./UVM/1.2/`

## Notes

- The interface is configured as `DATA_WIDTH = 8` by default
- The slave DUT is always ready (no backpressure)
- All transactions are driven on clock edges
- Reset is active-low, synchronous to clock

## Future Enhancements

- Add functional coverage
- Add assertion-based checks
- Support for parameterized configurations (ID_WIDTH, DEST_WIDTH)
- Add slave VIP for complete architecture
- Support for master-to-slave and slave-to-master scenarios
