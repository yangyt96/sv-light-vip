// AXI Stream Master Sequencer
// Handles sequencing of transactions for the master driver
`ifndef AXIS_MASTER_SEQUENCER_SV
`define AXIS_MASTER_SEQUENCER_SV

class axis_master_sequencer extends uvm_sequencer #(axis_master_seq_item);

    `uvm_component_utils(axis_master_sequencer)

    function new(string name = "axis_master_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : axis_master_sequencer

`endif // AXIS_MASTER_SEQUENCER_SV
