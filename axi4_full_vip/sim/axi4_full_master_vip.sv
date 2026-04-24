// AXI4 Full Master VIP
// Provides write and read transaction generation with support for bursts,
// IDs, and optional pause/backpressure generation

class Axi4FullMasterVIP #(
  int ADDR_WIDTH   = 32,
  int DATA_WIDTH   = 32,
  int ID_WIDTH     = 4,
  int LEN_WIDTH    = 8,
  int SIZE_WIDTH   = 3,
  int BURST_WIDTH  = 2,
  int LOCK_WIDTH   = 1,
  int CACHE_WIDTH  = 4,
  int PROT_WIDTH   = 3,
  int QOS_WIDTH    = 4,
  int REGION_WIDTH = 4,
  int STRB_WIDTH   = DATA_WIDTH / 8,
  int AWUSER_WIDTH = 1,
  int WUSER_WIDTH  = 1,
  int BUSER_WIDTH  = 1,
  int ARUSER_WIDTH = 1,
  int RUSER_WIDTH  = 1
);

  virtual axi4_full_if #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH),
    .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH),
    .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .STRB_WIDTH(STRB_WIDTH),
    .AWUSER_WIDTH(AWUSER_WIDTH), .WUSER_WIDTH(WUSER_WIDTH), .BUSER_WIDTH(BUSER_WIDTH),
    .ARUSER_WIDTH(ARUSER_WIDTH), .RUSER_WIDTH(RUSER_WIDTH)
  ).master vif;

  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;

  function new(
    virtual axi4_full_if #(
      .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
      .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH),
      .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH),
      .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .STRB_WIDTH(STRB_WIDTH),
      .AWUSER_WIDTH(AWUSER_WIDTH), .WUSER_WIDTH(WUSER_WIDTH), .BUSER_WIDTH(BUSER_WIDTH),
      .ARUSER_WIDTH(ARUSER_WIDTH), .RUSER_WIDTH(RUSER_WIDTH)
    ).master vif,
    string vip_name = "axi4_full_master_vip"
  );
    this.vif = vif;
    this.vip_name = vip_name;
    enable_pause_generator = 1'b0;
    min_pause_cycles = 0;
    max_pause_cycles = 0;
  endfunction

  function void configure_pause_generator(
    bit enable,
    int unsigned min_cycles = 0,
    int unsigned max_cycles = 0
  );
    enable_pause_generator = enable;
    min_pause_cycles = min_cycles;
    max_pause_cycles = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  task automatic apply_pause();
    int unsigned pause_cycles;
    begin
      while (!vif.aresetn) @(posedge vif.aclk);
      if (enable_pause_generator) begin
        pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
        repeat (pause_cycles) @(posedge vif.aclk);
      end
    end
  endtask

  // Write transaction: address, data, and response
  task write(
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   data,
    input  logic [STRB_WIDTH-1:0]   strb = '1,
    input  logic [ID_WIDTH-1:0]     id = '0,
    input  logic [LEN_WIDTH-1:0]    len = '0,      // Single beat
    input  logic [SIZE_WIDTH-1:0]   size = $clog2(STRB_WIDTH),
    input  logic [BURST_WIDTH-1:0]  burst = 2'b01, // INCR
    input  logic [PROT_WIDTH-1:0]   prot = 3'b000,
    output logic [1:0]              resp
  );
    bit aw_done;
    bit w_done;

    apply_pause();

    vif.awid      = id;
    vif.awaddr    = addr;
    vif.awlen     = len;
    vif.awsize    = size;
    vif.awburst   = burst;
    vif.awprot    = prot;
    vif.awcache   = 4'b0000;
    vif.awlock    = 1'b0;
    vif.awqos     = 4'b0000;
    vif.awregion  = 4'b0000;
    vif.awuser    = '0;
    vif.awvalid   = 1'b1;

    vif.wdata     = data;
    vif.wstrb     = strb;
    vif.wlast     = 1'b1;  // Single beat
    vif.wuser     = '0;
    vif.wvalid    = 1'b1;

    vif.bready    = 1'b1;

    aw_done = 1'b0;
    w_done  = 1'b0;

    while (!(aw_done && w_done)) begin
      @(posedge vif.aclk);
      if (!aw_done && vif.awvalid && vif.awready) begin
        aw_done = 1'b1;
        vif.awvalid = 1'b0;
      end
      if (!w_done && vif.wvalid && vif.wready) begin
        w_done = 1'b1;
        vif.wvalid = 1'b0;
      end
    end

    do begin
      @(posedge vif.aclk);
    end while (!(vif.bvalid && vif.bready));

    resp = vif.bresp;
    $display("[%0t] %s TX WRITE addr=%h data=%h strb=%h id=%0d len=%0d burst=%0d bresp=%0h",
             $time, vip_name, addr, data, strb, id, len, burst, resp);
    vif.bready = 1'b0;
  endtask

  // Read transaction
  task read(
    input  logic [ADDR_WIDTH-1:0]   addr,
    output logic [DATA_WIDTH-1:0]   data,
    output logic [1:0]              resp,
    input  logic [ID_WIDTH-1:0]     id = '0,
    input  logic [LEN_WIDTH-1:0]    len = '0,      // Single beat
    input  logic [SIZE_WIDTH-1:0]   size = $clog2(STRB_WIDTH),
    input  logic [BURST_WIDTH-1:0]  burst = 2'b01, // INCR
    input  logic [PROT_WIDTH-1:0]   prot = 3'b000
  );
    apply_pause();

    vif.arid      = id;
    vif.araddr    = addr;
    vif.arlen     = len;
    vif.arsize    = size;
    vif.arburst   = burst;
    vif.arprot    = prot;
    vif.arcache   = 4'b0000;
    vif.arlock    = 1'b0;
    vif.arqos     = 4'b0000;
    vif.arregion  = 4'b0000;
    vif.aruser    = '0;
    vif.arvalid   = 1'b1;
    vif.rready    = 1'b1;

    do begin
      @(posedge vif.aclk);
      if (vif.arvalid && vif.arready) begin
        vif.arvalid = 1'b0;
      end
    end while (!(vif.rvalid && vif.rready));

    data = vif.rdata;
    resp = vif.rresp;
    $display("[%0t] %s RX READ  addr=%h data=%h id=%0d len=%0d burst=%0d rresp=%0h",
             $time, vip_name, addr, data, id, len, burst, resp);
    vif.rready = 1'b0;
  endtask

endclass
