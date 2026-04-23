// AXI Stream Master VIP Testbench
// VUnit testbench for the AXI Stream Master Verification IP
`timescale 1ns/1ps

`include "axis_master_defines.svh"

module tb_axis_master_vip #(
    string runner_cfg = runner_cfg_default
);

    import uvm_pkg::*;
    import axis_master_pkg::*;
    `include "uvm_macros.svh"

    // Default runner configuration
    localparam string runner_cfg_default = "";

    // Configuration
    localparam int DATA_WIDTH = `AXIS_DATA_WIDTH;
    localparam int CLK_PERIOD = 10;  // 100 MHz

    // Clock and reset
    logic clk;
    logic rst_n;

    // Interface instance
    axis_master_interface #(.DATA_WIDTH(DATA_WIDTH)) axis_if (
        .clk(clk),
        .rst_n(rst_n)
    );

    // DUT instantiation
    axis_slave_dut #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(axis_if.tdata),
        .s_axis_tvalid(axis_if.tvalid),
        .s_axis_tready(axis_if.tready),
        .s_axis_tlast(axis_if.tlast),
        .s_axis_tstrb(axis_if.tstrb),
        .s_axis_tkeep(axis_if.tkeep),
        .s_axis_tuser(axis_if.tuser),
        .transfer_count(),
        .error_count(),
        .last_data()
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 1'b0;
        #(CLK_PERIOD * 5) rst_n = 1'b1;
    end

    // Test class
    class axis_master_test extends uvm_test;

        `uvm_component_utils(axis_master_test)

        // Environment
        axis_master_env env;

        // Virtual interface
        virtual axis_master_interface #(.DATA_WIDTH(DATA_WIDTH)) vif;

        function new(string name = "axis_master_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction : new

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            
            // Get virtual interface
            if (!uvm_config_db #(virtual axis_master_interface #(.DATA_WIDTH(DATA_WIDTH)))::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "Virtual interface not found for " + get_full_name())
            end
            
            // Propagate virtual interface to environment
            uvm_config_db #(virtual axis_master_interface #(.DATA_WIDTH(DATA_WIDTH)))::set(this, "env", "vif", vif);
            
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

    // UVM Test
    initial begin
        // Register the virtual interface with config database
        uvm_config_db #(virtual axis_master_interface #(.DATA_WIDTH(DATA_WIDTH)))::set(null, "uvm_test_top", "vif", axis_if);
        
        // Enable tracing for waveform
        `ifdef VUNIT_SIMULATOR
            $dumpfile("wave.vcd");
            $dumpvars(0, tb_axis_master_vip);
        `endif

        // Run the test
        run_test();
        
        // Final delay to capture last events
        #(CLK_PERIOD * 10);
        
        $finish;
    end

endmodule : tb_axis_master_vip
