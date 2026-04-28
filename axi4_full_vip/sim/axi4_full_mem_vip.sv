// axi4_full_mem_vip.sv
// Hardware memory module (NOT a software class).
// Must be `included and instantiated directly in the testbench.
// Simple single-outstanding AXI4 slave with byte-addressed storage and burst support.

`timescale 1ns / 1ps

module axi4_full_mem_vip #(
    parameter int ADDR_WIDTH   = 32,
    parameter int DATA_WIDTH   = 32,
    parameter int ID_WIDTH     = 4,
    parameter int LEN_WIDTH    = 8,
    parameter int SIZE_WIDTH   = 3,
    parameter int BURST_WIDTH  = 2,
    parameter int LOCK_WIDTH   = 1,
    parameter int CACHE_WIDTH  = 4,
    parameter int PROT_WIDTH   = 3,
    parameter int QOS_WIDTH    = 4,
    parameter int REGION_WIDTH = 4,
    parameter int STRB_WIDTH   = DATA_WIDTH / 8,
    parameter int AWUSER_WIDTH = 1,
    parameter int WUSER_WIDTH  = 1,
    parameter int BUSER_WIDTH  = 1,
    parameter int ARUSER_WIDTH = 1,
    parameter int RUSER_WIDTH  = 1,
    parameter int MEM_BYTES    = 16384
) (
    input logic aclk,
    input logic aresetn,

    input  logic [    ID_WIDTH-1:0] s_axi_awid,
    input  logic [  ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [   LEN_WIDTH-1:0] s_axi_awlen,
    input  logic [  SIZE_WIDTH-1:0] s_axi_awsize,
    input  logic [ BURST_WIDTH-1:0] s_axi_awburst,
    input  logic [  LOCK_WIDTH-1:0] s_axi_awlock,
    input  logic [ CACHE_WIDTH-1:0] s_axi_awcache,
    input  logic [  PROT_WIDTH-1:0] s_axi_awprot,
    input  logic [   QOS_WIDTH-1:0] s_axi_awqos,
    input  logic [REGION_WIDTH-1:0] s_axi_awregion,
    input  logic [AWUSER_WIDTH-1:0] s_axi_awuser,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    input  logic [ DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [ STRB_WIDTH-1:0] s_axi_wstrb,
    input  logic                   s_axi_wlast,
    input  logic [WUSER_WIDTH-1:0] s_axi_wuser,
    input  logic                   s_axi_wvalid,
    output logic                   s_axi_wready,

    output logic [   ID_WIDTH-1:0] s_axi_bid,
    output logic [            1:0] s_axi_bresp,
    output logic [BUSER_WIDTH-1:0] s_axi_buser,
    output logic                   s_axi_bvalid,
    input  logic                   s_axi_bready,

    input  logic [    ID_WIDTH-1:0] s_axi_arid,
    input  logic [  ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [   LEN_WIDTH-1:0] s_axi_arlen,
    input  logic [  SIZE_WIDTH-1:0] s_axi_arsize,
    input  logic [ BURST_WIDTH-1:0] s_axi_arburst,
    input  logic [  LOCK_WIDTH-1:0] s_axi_arlock,
    input  logic [ CACHE_WIDTH-1:0] s_axi_arcache,
    input  logic [  PROT_WIDTH-1:0] s_axi_arprot,
    input  logic [   QOS_WIDTH-1:0] s_axi_arqos,
    input  logic [REGION_WIDTH-1:0] s_axi_arregion,
    input  logic [ARUSER_WIDTH-1:0] s_axi_aruser,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    output logic [   ID_WIDTH-1:0] s_axi_rid,
    output logic [ DATA_WIDTH-1:0] s_axi_rdata,
    output logic [            1:0] s_axi_rresp,
    output logic                   s_axi_rlast,
    output logic [RUSER_WIDTH-1:0] s_axi_ruser,
    output logic                   s_axi_rvalid,
    input  logic                   s_axi_rready
);

  localparam logic [1:0] AXI_RESP_OKAY = 2'b00;
  localparam logic [1:0] AXI_BURST_FIXED = 2'b00;
  localparam logic [1:0] AXI_BURST_INCR = 2'b01;
  localparam logic [1:0] AXI_BURST_WRAP = 2'b10;

  byte unsigned                   mem            [MEM_BYTES];

  logic         [   ID_WIDTH-1:0] wr_id;
  logic         [ ADDR_WIDTH-1:0] wr_addr;
  logic         [ SIZE_WIDTH-1:0] wr_size;
  logic         [BURST_WIDTH-1:0] wr_burst;
  int unsigned                    wr_beats_total;
  int unsigned                    wr_beat_count;
  bit                             wr_active;

  logic         [   ID_WIDTH-1:0] rd_id;
  logic         [ ADDR_WIDTH-1:0] rd_addr;
  logic         [ SIZE_WIDTH-1:0] rd_size;
  logic         [BURST_WIDTH-1:0] rd_burst;
  int unsigned                    rd_beats_total;
  int unsigned                    rd_beat_count;
  bit                             rd_active;

  logic         [ ADDR_WIDTH-1:0] next_addr;

  function automatic int unsigned beat_bytes(input logic [SIZE_WIDTH-1:0] size);
    int unsigned bytes;
    begin
      bytes = 1 << size;
      if (bytes > STRB_WIDTH) begin
        bytes = STRB_WIDTH;
      end
      return bytes;
    end
  endfunction

  function automatic int unsigned mem_index(input logic [ADDR_WIDTH-1:0] addr);
    return int'(addr % MEM_BYTES);
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] next_burst_addr(
      input logic [ADDR_WIDTH-1:0] addr, input logic [SIZE_WIDTH-1:0] size,
      input logic [BURST_WIDTH-1:0] burst, input int unsigned beats_total);
    int unsigned bytes_per_beat;
    int unsigned wrap_bytes;
    logic [ADDR_WIDTH-1:0] wrap_base;
    logic [ADDR_WIDTH-1:0] next_addr;
    begin
      bytes_per_beat = beat_bytes(size);
      next_addr = addr;

      if (burst == AXI_BURST_INCR) begin
        next_addr = addr + bytes_per_beat;
      end else if (burst == AXI_BURST_WRAP) begin
        wrap_bytes = bytes_per_beat * beats_total;
        wrap_base  = (addr / wrap_bytes) * wrap_bytes;
        next_addr  = addr + bytes_per_beat;
        if (next_addr >= (wrap_base + wrap_bytes)) begin
          next_addr = wrap_base;
        end
      end

      return next_addr;
    end
  endfunction

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

  task automatic write_word(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                            input logic [STRB_WIDTH-1:0] strb);
    for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
      if (strb[byte_idx]) begin
        mem[mem_index(addr+byte_idx)] = data[(8*byte_idx)+:8];
      end
    end
  endtask

  initial begin
    for (int i = 0; i < MEM_BYTES; i++) begin
      mem[i] = '0;
    end
  end

  assign s_axi_awready = (!wr_active && !s_axi_bvalid);
  assign s_axi_wready  = wr_active;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // s_axi_awready  <= 1'b0;
      // s_axi_wready   <= 1'b0;
      s_axi_bid      <= '0;
      s_axi_bresp    <= AXI_RESP_OKAY;
      s_axi_buser    <= '0;
      s_axi_bvalid   <= 1'b0;
      wr_id          <= '0;
      wr_addr        <= '0;
      wr_size        <= '0;
      wr_burst       <= AXI_BURST_INCR;
      wr_beats_total <= 0;
      wr_beat_count  <= 0;
      wr_active      <= 1'b0;
    end else begin

      if (s_axi_awvalid && s_axi_awready) begin
        wr_id          <= s_axi_awid;
        wr_addr        <= s_axi_awaddr;
        wr_size        <= s_axi_awsize;
        wr_burst       <= s_axi_awburst;
        wr_beats_total <= int'(s_axi_awlen) + 1;
        wr_beat_count  <= 0;
        wr_active      <= 1'b1;
      end

      if (s_axi_wvalid && s_axi_wready) begin
        write_word(wr_addr, s_axi_wdata, s_axi_wstrb);

        if ((wr_beat_count == (wr_beats_total - 1)) || s_axi_wlast) begin
          s_axi_bid    <= wr_id;
          s_axi_bresp  <= AXI_RESP_OKAY;
          s_axi_buser  <= '0;
          s_axi_bvalid <= 1'b1;
          wr_active    <= 1'b0;
        end else begin
          wr_addr       <= next_burst_addr(wr_addr, wr_size, wr_burst, wr_beats_total);
          wr_beat_count <= wr_beat_count + 1;
        end
      end

      if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  assign s_axi_arready = (!rd_active && !s_axi_rvalid);
  assign next_addr = next_burst_addr(rd_addr, rd_size, rd_burst, rd_beats_total);

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_rid      <= '0;
      s_axi_rdata    <= '0;
      s_axi_rresp    <= AXI_RESP_OKAY;
      s_axi_rlast    <= 1'b0;
      s_axi_ruser    <= '0;
      s_axi_rvalid   <= 1'b0;
      rd_id          <= '0;
      rd_addr        <= '0;
      rd_size        <= '0;
      rd_burst       <= AXI_BURST_INCR;
      rd_beats_total <= 0;
      rd_beat_count  <= 0;
      rd_active      <= 1'b0;
    end else begin

      if (s_axi_arvalid && s_axi_arready) begin
        rd_id          <= s_axi_arid;
        rd_addr        <= s_axi_araddr;
        rd_size        <= s_axi_arsize;
        rd_burst       <= s_axi_arburst;
        rd_beats_total <= int'(s_axi_arlen) + 1;
        rd_beat_count  <= 0;
        rd_active      <= 1'b1;

        s_axi_rid      <= s_axi_arid;
        s_axi_rdata    <= read_word(s_axi_araddr);
        s_axi_rresp    <= AXI_RESP_OKAY;
        s_axi_ruser    <= '0;
        s_axi_rlast    <= (s_axi_arlen == '0);
        s_axi_rvalid   <= 1'b1;
      end else if (s_axi_rvalid && s_axi_rready) begin
        if (rd_beat_count == (rd_beats_total - 1)) begin
          s_axi_rvalid <= 1'b0;
          s_axi_rlast  <= 1'b0;
          rd_active    <= 1'b0;
        end else begin
          rd_addr       <= next_addr;
          rd_beat_count <= rd_beat_count + 1;
          s_axi_rid     <= rd_id;
          s_axi_rdata   <= read_word(next_addr);
          s_axi_rresp   <= AXI_RESP_OKAY;
          s_axi_rlast   <= ((rd_beat_count + 1) == (rd_beats_total - 1));
          s_axi_rvalid  <= 1'b1;
        end
      end
    end
  end

endmodule
