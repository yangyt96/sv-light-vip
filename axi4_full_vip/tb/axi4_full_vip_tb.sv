`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "../sim/axi4_full_if.sv"
`include "../sim/axi4_full_master_vip.sv"
`include "../sim/axi4_full_slave_vip.sv"

module axi4_full_vip_tb;

  localparam int ADDR_WIDTH   = 32;
  localparam int DATA_WIDTH   = 32;
  localparam int ID_WIDTH     = 4;
  localparam int STRB_WIDTH   = DATA_WIDTH / 8;

  logic clk;
  logic rstn;

  // Create interface instance
  axi4_full_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) axi_if (clk, rstn);

  // Instantiate DUT
  axi4_full_dut #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) dut (
    .aclk             (clk),
    .aresetn          (rstn),
    .s_axi_awid       (axi_if.awid),
    .s_axi_awaddr     (axi_if.awaddr),
    .s_axi_awlen      (axi_if.awlen),
    .s_axi_awsize     (axi_if.awsize),
    .s_axi_awburst    (axi_if.awburst),
    .s_axi_awlock     (axi_if.awlock),
    .s_axi_awcache    (axi_if.awcache),
    .s_axi_awprot     (axi_if.awprot),
    .s_axi_awqos      (axi_if.awqos),
    .s_axi_awregion   (axi_if.awregion),
    .s_axi_awuser     (axi_if.awuser),
    .s_axi_awvalid    (axi_if.awvalid),
    .s_axi_awready    (axi_if.awready),
    .s_axi_wdata      (axi_if.wdata),
    .s_axi_wstrb      (axi_if.wstrb),
    .s_axi_wlast      (axi_if.wlast),
    .s_axi_wuser      (axi_if.wuser),
    .s_axi_wvalid     (axi_if.wvalid),
    .s_axi_wready     (axi_if.wready),
    .s_axi_bid        (axi_if.bid),
    .s_axi_bresp      (axi_if.bresp),
    .s_axi_buser      (axi_if.buser),
    .s_axi_bvalid     (axi_if.bvalid),
    .s_axi_bready     (axi_if.bready),
    .s_axi_arid       (axi_if.arid),
    .s_axi_araddr     (axi_if.araddr),
    .s_axi_arlen      (axi_if.arlen),
    .s_axi_arsize     (axi_if.arsize),
    .s_axi_arburst    (axi_if.arburst),
    .s_axi_arlock     (axi_if.arlock),
    .s_axi_arcache    (axi_if.arcache),
    .s_axi_arprot     (axi_if.arprot),
    .s_axi_arqos      (axi_if.arqos),
    .s_axi_arregion   (axi_if.arregion),
    .s_axi_aruser     (axi_if.aruser),
    .s_axi_arvalid    (axi_if.arvalid),
    .s_axi_arready    (axi_if.arready),
    .s_axi_rid        (axi_if.rid),
    .s_axi_rdata      (axi_if.rdata),
    .s_axi_rresp      (axi_if.rresp),
    .s_axi_rlast      (axi_if.rlast),
    .s_axi_ruser      (axi_if.ruser),
    .s_axi_rvalid     (axi_if.rvalid),
    .s_axi_rready     (axi_if.rready)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 100MHz
  end

  // Reset generation
  initial begin
    rstn = 1'b0;
    repeat (5) @(posedge clk);
    rstn = 1'b1;
  end

  // VIP instances
  Axi4FullMasterVIP #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) master_vip;

  // Test stimulus
  `TEST_SUITE
  begin
    // Initialize master VIP
    master_vip = new(axi_if.master, "MASTER_VIP_0");
    master_vip.configure_pause_generator(.enable(1'b0));

    // Wait for reset
    wait(rstn);
    repeat (5) @(posedge clk);

    `TEST_CASE("Simple Write-Read")
    begin
      logic [1:0] resp;
      logic [DATA_WIDTH-1:0] read_data;
      $display("\n=== AXI4 Full VIP Testbench Started ===");
      $display("\n--- Test 1: Simple Write-Read ---");

      // Write to address 0x1000 with data 0xDEADBEEF
      master_vip.write(
        .addr(32'h1000),
        .data(32'hDEADBEEF),
        .strb(4'hF),
        .id(4'd0),
        .len(8'd0),
        .resp(resp)
      );
      repeat (2) @(posedge clk);

      // Read from address 0x1000
      master_vip.read(
        .addr(32'h1000),
        .data(read_data),
        .resp(resp),
        .id(4'd0),
        .len(8'd0)
      );
      repeat (2) @(posedge clk);
    end

    `TEST_CASE("Multiple Writes")
    begin
      logic [1:0] resp;
      $display("\n--- Test 2: Multiple Writes ---");
      for (int i = 0; i < 4; i++) begin
        master_vip.write(
          .addr(32'h2000 + (i * 4)),
          .data(32'h11223300 + i),
          .strb(4'hF),
          .id(i[3:0]),
          .resp(resp)
        );
        repeat (2) @(posedge clk);
      end
    end

    `TEST_CASE("Multiple Reads")
    begin
      logic [1:0] resp;
      logic [DATA_WIDTH-1:0] read_data;
      $display("\n--- Test 3: Multiple Reads ---");
      for (int i = 0; i < 4; i++) begin
        master_vip.read(
          .addr(32'h2000 + (i * 4)),
          .data(read_data),
          .resp(resp),
          .id(i[3:0])
        );
        repeat (2) @(posedge clk);
      end
    end

    `TEST_CASE("Partial Write Byte Mask")
    begin
      logic [1:0] resp;
      $display("\n--- Test 4: Partial Write (Byte 1-2) ---");
      master_vip.write(
        .addr(32'h3000),
        .data(32'h12345678),
        .strb(4'b0110),  // Only bytes 1 and 2
        .id(4'd0),
        .resp(resp)
      );
      repeat (2) @(posedge clk);
    end
  end

endmodule
