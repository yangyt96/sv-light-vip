// axi4_lite_mem_vip.sv
// Hardware memory module (NOT a software class).
// Must be `included and instantiated directly in the testbench.
// Simple AXI4-Lite memory slave with byte-addressed storage.
// Parameterized for ADDR_WIDTH, DATA_WIDTH, and STRB_WIDTH

`timescale 1ns / 1ps

module axi4_lite_mem_vip #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8,
    parameter int MEM_BYTES  = 1024
) (
    input  logic                  aclk,
    input  logic                  aresetn,
    input  logic [ADDR_WIDTH-1:0] awaddr,
    input  logic [           2:0] awprot,
    input  logic                  awvalid,
    output logic                  awready,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic [STRB_WIDTH-1:0] wstrb,
    input  logic                  wvalid,
    output logic                  wready,
    output logic [           1:0] bresp,
    output logic                  bvalid,
    input  logic                  bready,
    input  logic [ADDR_WIDTH-1:0] araddr,
    input  logic [           2:0] arprot,
    input  logic                  arvalid,
    output logic                  arready,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic [           1:0] rresp,
    output logic                  rvalid,
    input  logic                  rready
);

  // Byte-addressed memory storage
  byte unsigned mem[MEM_BYTES];

  // Write address latch (captured during AW handshake for use during W handshake)
  logic [ADDR_WIDTH-1:0] wr_addr;

  // Address index helper
  function automatic int unsigned mem_index(input logic [ADDR_WIDTH-1:0] addr);
    return int'(addr % MEM_BYTES);
  endfunction

  // Read a word from byte-addressed memory
  function automatic logic [DATA_WIDTH-1:0] read_word(input logic [ADDR_WIDTH-1:0] addr);
    logic [DATA_WIDTH-1:0] data;
    begin
      data = '0;
      for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
        data[(8*byte_idx)+:8] = mem[mem_index(addr+byte_idx)];
      end
      return data;
    end
  endfunction

  // Write a word to byte-addressed memory with byte strobes
  task automatic write_word(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                            input logic [STRB_WIDTH-1:0] strb);
    for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
      if (strb[byte_idx]) begin
        mem[mem_index(addr+byte_idx)] = data[(8*byte_idx)+:8];
      end
    end
  endtask

  // Initialize memory
  initial begin
    for (int i = 0; i < MEM_BYTES; i++) begin
      mem[i] = '0;
    end
  end

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
        write_word(wr_addr, wdata, wstrb);
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
      rdata   <= '0;
      rresp   <= 2'b00;
    end else begin
      // AR channel handshake: capture read data, assert R response
      if (arvalid && arready) begin
        arready <= 1'b0;
        rdata   <= read_word(araddr);
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
