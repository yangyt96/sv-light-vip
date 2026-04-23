// AXI Stream Master VIP Package
// Includes all VIP components
`ifndef AXIS_MASTER_PKG_SV
`define AXIS_MASTER_PKG_SV

`include "axis_master_defines.svh"
`include "env/axis_master_interface.sv"

package axis_master_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Sequence Items
    `include "sequences/axis_master_seq_item.sv"
    `include "sequences/axis_master_sequences.sv"

    // Agent Components
    `include "agent/axis_master_sequencer.sv"
    `include "agent/axis_master_driver.sv"
    `include "agent/axis_master_monitor.sv"
    `include "agent/axis_master_agent.sv"

    // Environment
    `include "env/axis_master_env.sv"

endpackage : axis_master_pkg

`endif // AXIS_MASTER_PKG_SV
