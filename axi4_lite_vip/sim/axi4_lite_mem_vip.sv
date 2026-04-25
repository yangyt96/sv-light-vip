// axi4_lite_mem_vip.sv
// Simple memory VIP that acts as a slave to store and read data

`timescale 1ns / 1ps

module axi4_lite_mem_vip (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic [15:0] awaddr,
    input  logic [ 2:0] awprot,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic [ 3:0] wstrb,
    input  logic        wvalid,
    output logic        wready,
    output logic [ 1:0] bresp,
    output logic        bvalid,
    input  logic        bready,
    input  logic [15:0] araddr,
    input  logic [ 2:0] arprot,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [ 1:0] rresp,
    output logic        rvalid,
    input  logic        rready
);

  // Internal memory - 256 entries x 32 bits = 8KB
  logic [31:0] mem[256];

  // Write address latch (captured during AW handshake for use during W handshake)
  logic [15:0] wr_addr;

  // Write path state machine:
  //   awready=1, wready=0, bvalid=0 : Idle - ready for AW
  //   awready=0, wready=1, bvalid=0 : AW received - waiting for W
  //   awready=0, wready=0, bvalid=1 : Write complete - response pending
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      awready <= 1'b1;
      wready  <= 1'b0;
      bvalid  <= 1'b0;
      bresp   <= 2'b00;
      wr_addr <= '0;
      for (int i = 0; i < 256; i++) begin
        mem[i] <= '0;
      end
    end else begin
      // AW channel handshake: capture write address, transition to W phase
      if (awvalid && awready) begin
        awready <= 1'b0;
        wready  <= 1'b1;
        wr_addr <= awaddr;
      end

      // W channel handshake: write data to memory, assert B response
      if (wvalid && wready) begin
        wready <= 1'b0;
        bvalid <= 1'b1;
        bresp  <= 2'b00;
        for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
          if (wstrb[byte_idx]) begin
            mem[wr_addr[7:0]][8*byte_idx+:8] <= wdata[8*byte_idx+:8];
          end
        end
      end

      // B channel handshake: deassert response, return to idle
      if (bready && bvalid) begin
        bvalid  <= 1'b0;
        awready <= 1'b1;
      end
    end
  end

  // Read path state machine:
  //   arready=1, rvalid=0 : Idle - ready for AR
  //   arready=0, rvalid=1 : Read data pending
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      arready <= 1'b1;
      rvalid  <= 1'b0;
      rdata   <= 32'b0;
      rresp   <= 2'b00;
    end else begin
      // AR channel handshake: capture read data, assert R response
      if (arvalid && arready) begin
        arready <= 1'b0;
        rdata   <= mem[araddr[7:0]];
        rresp   <= 2'b00;
        rvalid  <= 1'b1;
      end

      // R channel handshake: deassert response, return to idle
      if (rready && rvalid) begin
        rvalid  <= 1'b0;
        arready <= 1'b1;
      end
    end
  end

endmodule
