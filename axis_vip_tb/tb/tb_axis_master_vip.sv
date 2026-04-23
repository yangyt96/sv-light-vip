// AXI Stream Master VIP Testbench
// VUnit testbench for the AXI Stream Master Verification IP
`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axis_master_defines.svh"

module tb_axis_master_vip;

    import vunit_pkg::*;
    import uvm_pkg::*;
    import axis_master_pkg::*;
    `include "uvm_macros.svh"

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

    initial begin
        uvm_config_db #(virtual axis_master_interface)::set(null, "uvm_test_top", "vif", axis_if);

        `ifdef VUNIT_SIMULATOR
            $dumpfile("wave.vcd");
            $dumpvars(0, tb_axis_master_vip);
        `endif
    end

    `TEST_SUITE begin
        `TEST_CASE("axis_master_random") begin
            uvm_top.finish_on_completion = 0;
            run_test("axis_master_test");
            #(CLK_PERIOD * 10);
        end
    end

endmodule : tb_axis_master_vip
