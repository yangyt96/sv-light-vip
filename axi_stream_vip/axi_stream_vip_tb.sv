`timescale 1ns/1ps




`include "vunit_defines.svh"

module axi_stream_dut_tb;

  import vunit_pkg::*;  // VUnit integration

  // clock and reset
  logic clk;
  logic rstn;

  // instantiate AXI Stream interface
  axi_stream_if #(32) axis_if(clk, rstn);

  // DUT instantiation (explicit ports if not using interface)
  axi_stream_dut #(.DATA_WIDTH(32)) dut (
    .aclk(clk),
    .aresetn(rstn),
    .s_axis_tdata (axis_if.tdata),
    .s_axis_tvalid(axis_if.tvalid),
    .s_axis_tready(axis_if.tready),
    .s_axis_tkeep (axis_if.tkeep),
    .s_axis_tstrb (axis_if.tstrb),
    .s_axis_tlast (axis_if.tlast),
    .s_axis_tid   (axis_if.tid),
    .s_axis_tdest (axis_if.tdest),
    .s_axis_tuser (axis_if.tuser),

    .m_axis_tdata (axis_if.tdata),
    .m_axis_tvalid(axis_if.tvalid),
    .m_axis_tready(axis_if.tready),
    .m_axis_tkeep (axis_if.tkeep),
    .m_axis_tstrb (axis_if.tstrb),
    .m_axis_tlast (axis_if.tlast),
    .m_axis_tid   (axis_if.tid),
    .m_axis_tdest (axis_if.tdest),
    .m_axis_tuser (axis_if.tuser)
  );

  // VIP handles
  AxiStreamMasterVIP master;
  AxiStreamSlaveVIP  slave;

  // clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // reset
  initial begin
    rstn = 0;
    #20 rstn = 1;
  end


  `TEST_SUITE begin

      master = new(axis_if.master);
      slave  = new(axis_if.slave);

      // push one packet from master
      master.push_axi_stream(32'hCAFEBABE,
                             4'hF, 4'hF,
                             1'b1,
                             8'h02,
                             8'h01,
                             32'h87654321);

      // pop it at slave
      logic [31:0] tdata;
      logic [3:0]  tkeep, tstrb;
      bit          tlast;
      byte         tid, tdest;
      int unsigned tuser;

      slave.pop_axi_stream(tdata, tkeep, tstrb, tlast, tid, tdest, tuser);

      // check result
      assert(tdata == 32'hCAFEBABE) else $error("Data mismatch!");
      assert(tlast == 1'b1) else $error("TLAST mismatch!");
  end


endmodule