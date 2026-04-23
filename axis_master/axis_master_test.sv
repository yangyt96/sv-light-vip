// AXI Stream Master Test Base Class
// Base test for AXI Stream Master VIP verification

`include "axis_master_defines.svh"

class axis_master_test extends uvm_test;

    `uvm_component_utils(axis_master_test)

    // Environment
    axis_master_env env;

    // Virtual interface
    virtual axis_master_interface #(.DATA_WIDTH(`AXIS_DATA_WIDTH)) vif;

    function new(string name = "axis_master_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get virtual interface
        if (!uvm_config_db #(virtual axis_master_interface #(.DATA_WIDTH(`AXIS_DATA_WIDTH)))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface not found for " + get_full_name())
        end
        
        // Propagate virtual interface to environment
        uvm_config_db #(virtual axis_master_interface #(.DATA_WIDTH(`AXIS_DATA_WIDTH)))::set(this, "env", "vif", vif);
        
        // Create environment
        env = axis_master_env::type_id::create("env", this);
        
        // Set print topology at end of elaboration
        uvm_top.print_topology();
        
        `uvm_info("TEST_BUILD", "Test built successfully", UVM_MEDIUM)
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("TEST_CONNECT", "Test connected successfully", UVM_MEDIUM)
    endfunction : connect_phase

    task run_phase(uvm_phase phase);
        axis_master_random_seq seq;
        
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting test run phase", UVM_MEDIUM)
        
        // Create and start the sequence
        seq = axis_master_random_seq::type_id::create("seq");
        seq.num_items = 20;
        seq.start(env.agent.sequencer);
        
        `uvm_info("TEST", "Test run phase completed", UVM_MEDIUM)
        
        phase.drop_objection(this);
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("TEST", "Test completed", UVM_MEDIUM)
    endfunction : report_phase

endclass : axis_master_test
