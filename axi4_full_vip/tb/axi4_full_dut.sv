// Simple AXI4 Full DUT
// A basic memory controller that responds to AXI4 write and read requests

module axi4_full_dut #(
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
  parameter int RUSER_WIDTH  = 1
) (
  input  logic aclk,
  input  logic aresetn,

  // Write Address Channel
  input  logic [ID_WIDTH-1:0]      s_axi_awid,
  input  logic [ADDR_WIDTH-1:0]    s_axi_awaddr,
  input  logic [LEN_WIDTH-1:0]     s_axi_awlen,
  input  logic [SIZE_WIDTH-1:0]    s_axi_awsize,
  input  logic [BURST_WIDTH-1:0]   s_axi_awburst,
  input  logic [LOCK_WIDTH-1:0]    s_axi_awlock,
  input  logic [CACHE_WIDTH-1:0]   s_axi_awcache,
  input  logic [PROT_WIDTH-1:0]    s_axi_awprot,
  input  logic [QOS_WIDTH-1:0]     s_axi_awqos,
  input  logic [REGION_WIDTH-1:0]  s_axi_awregion,
  input  logic [AWUSER_WIDTH-1:0]  s_axi_awuser,
  input  logic                     s_axi_awvalid,
  output logic                     s_axi_awready,

  // Write Data Channel
  input  logic [DATA_WIDTH-1:0]    s_axi_wdata,
  input  logic [STRB_WIDTH-1:0]    s_axi_wstrb,
  input  logic                     s_axi_wlast,
  input  logic [WUSER_WIDTH-1:0]   s_axi_wuser,
  input  logic                     s_axi_wvalid,
  output logic                     s_axi_wready,

  // Write Response Channel
  output logic [ID_WIDTH-1:0]      s_axi_bid,
  output logic [1:0]               s_axi_bresp,
  output logic [BUSER_WIDTH-1:0]   s_axi_buser,
  output logic                     s_axi_bvalid,
  input  logic                     s_axi_bready,

  // Read Address Channel
  input  logic [ID_WIDTH-1:0]      s_axi_arid,
  input  logic [ADDR_WIDTH-1:0]    s_axi_araddr,
  input  logic [LEN_WIDTH-1:0]     s_axi_arlen,
  input  logic [SIZE_WIDTH-1:0]    s_axi_arsize,
  input  logic [BURST_WIDTH-1:0]   s_axi_arburst,
  input  logic [LOCK_WIDTH-1:0]    s_axi_arlock,
  input  logic [CACHE_WIDTH-1:0]   s_axi_arcache,
  input  logic [PROT_WIDTH-1:0]    s_axi_arprot,
  input  logic [QOS_WIDTH-1:0]     s_axi_arqos,
  input  logic [REGION_WIDTH-1:0]  s_axi_arregion,
  input  logic [ARUSER_WIDTH-1:0]  s_axi_aruser,
  input  logic                     s_axi_arvalid,
  output logic                     s_axi_arready,

  // Read Data Channel
  output logic [ID_WIDTH-1:0]      s_axi_rid,
  output logic [DATA_WIDTH-1:0]    s_axi_rdata,
  output logic [1:0]               s_axi_rresp,
  output logic                     s_axi_rlast,
  output logic [RUSER_WIDTH-1:0]   s_axi_ruser,
  output logic                     s_axi_rvalid,
  input  logic                     s_axi_rready
);

  // Simple memory (4KB)
  localparam int MEM_SIZE = 4096;
  logic [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];

  // Initialize memory with test pattern
  initial begin
    for (int i = 0; i < MEM_SIZE; i++) begin
      memory[i] = 32'h0A0B0C0D + (i << 8);
    end
  end

  // Write Address and Data handling
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_awready <= 1'b0;
      s_axi_wready  <= 1'b0;
      s_axi_bvalid  <= 1'b0;
      s_axi_bid     <= '0;
      s_axi_bresp   <= 2'b00;
    end else begin
      // Simple write handling: always ready
      s_axi_awready <= 1'b1;
      s_axi_wready  <= 1'b1;

      // Respond with write response
      if (s_axi_awvalid && s_axi_awready) begin
        s_axi_bid <= s_axi_awid;
      end

      if (s_axi_wvalid && s_axi_wready && !s_axi_bvalid) begin
        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= 2'b00;  // OKAY
        // Write to memory with byte enable
        for (int i = 0; i < STRB_WIDTH; i++) begin
          if (s_axi_wstrb[i]) begin
            memory[s_axi_awaddr[11:2] + i] <= s_axi_wdata[8*i +: 8];
          end
        end
      end

      if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  // Read Address and Data handling
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_arready <= 1'b0;
      s_axi_rvalid  <= 1'b0;
      s_axi_rid     <= '0;
      s_axi_rdata   <= '0;
      s_axi_rresp   <= 2'b00;
      s_axi_rlast   <= 1'b0;
    end else begin
      // Simple read handling: always ready
      s_axi_arready <= 1'b1;

      // Respond with read data
      if (s_axi_arvalid && s_axi_arready && !s_axi_rvalid) begin
        s_axi_rvalid <= 1'b1;
        s_axi_rid    <= s_axi_arid;
        s_axi_rdata  <= memory[s_axi_araddr[11:2]];
        s_axi_rresp  <= 2'b00;  // OKAY
        s_axi_rlast  <= 1'b1;   // Single beat
      end

      if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

endmodule
