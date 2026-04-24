// AXI4 Full Slave VIP
// Provides write and read request handling with support for bursts,
// IDs, and optional backpressure generation

class Axi4FullSlaveVIP #(
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
  ).slave vif;

  string vip_name;
  bit enable_backpressure;
  int unsigned min_stall_cycles;
  int unsigned max_stall_cycles;

  function new(
    virtual axi4_full_if #(
      .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
      .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH),
      .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH),
      .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .STRB_WIDTH(STRB_WIDTH),
      .AWUSER_WIDTH(AWUSER_WIDTH), .WUSER_WIDTH(WUSER_WIDTH), .BUSER_WIDTH(BUSER_WIDTH),
      .ARUSER_WIDTH(ARUSER_WIDTH), .RUSER_WIDTH(RUSER_WIDTH)
    ).slave vif,
    string vip_name = "axi4_full_slave_vip"
  );
    this.vif = vif;
    this.vip_name = vip_name;
    enable_backpressure = 1'b0;
    min_stall_cycles = 0;
    max_stall_cycles = 0;
  endfunction

  function void configure_backpressure(
    bit enable,
    int unsigned min_cycles = 0,
    int unsigned max_cycles = 0
  );
    enable_backpressure = enable;
    min_stall_cycles = min_cycles;
    max_stall_cycles = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  task automatic apply_stall();
    int unsigned stall_cycles;
    begin
      if (enable_backpressure) begin
        stall_cycles = $urandom_range(max_stall_cycles, min_stall_cycles);
        repeat (stall_cycles) @(posedge vif.aclk);
      end
    end
  endtask

  // Handle write transaction
  task handle_write(
    output logic [ADDR_WIDTH-1:0]   addr,
    output logic [DATA_WIDTH-1:0]   data,
    output logic [STRB_WIDTH-1:0]   strb,
    output logic [ID_WIDTH-1:0]     id,
    output logic [LEN_WIDTH-1:0]    len,
    output logic [SIZE_WIDTH-1:0]   size,
    output logic [BURST_WIDTH-1:0]  burst,
    output logic [PROT_WIDTH-1:0]   prot,
    input  logic [1:0]              resp = 2'b00
  );
    bit aw_done;
    bit w_done;

    while (!vif.aresetn) @(posedge vif.aclk);

    vif.awready = 1'b0;
    vif.wready  = 1'b0;
    vif.bresp   = resp;
    vif.bvalid  = 1'b0;

    apply_stall();

    vif.awready = 1'b1;
    vif.wready  = 1'b1;

    aw_done = 1'b0;
    w_done  = 1'b0;

    while (!(aw_done && w_done)) begin
      @(posedge vif.aclk);

      if (!aw_done && vif.awvalid && vif.awready) begin
        addr    = vif.awaddr;
        id      = vif.awid;
        len     = vif.awlen;
        size    = vif.awsize;
        burst   = vif.awburst;
        prot    = vif.awprot;
        aw_done = 1'b1;
        vif.awready = 1'b0;
      end

      if (!w_done && vif.wvalid && vif.wready) begin
        data    = vif.wdata;
        strb    = vif.wstrb;
        w_done  = 1'b1;
        vif.wready = 1'b0;
      end
    end

    apply_stall();

    vif.bid    = id;
    vif.bresp  = resp;
    vif.buser  = '0;
    vif.bvalid = 1'b1;
    do begin
      @(posedge vif.aclk);
    end while (!(vif.bvalid && vif.bready));
    $display("[%0t] %s RX WRITE addr=%h data=%h strb=%h id=%0d len=%0d burst=%0d bresp=%0h",
             $time, vip_name, addr, data, strb, id, len, burst, resp);
    vif.bvalid = 1'b0;
  endtask

  // Handle read transaction
  task handle_read(
    output logic [ADDR_WIDTH-1:0]   addr,
    output logic [ID_WIDTH-1:0]     id,
    output logic [LEN_WIDTH-1:0]    len,
    output logic [SIZE_WIDTH-1:0]   size,
    output logic [BURST_WIDTH-1:0]  burst,
    output logic [PROT_WIDTH-1:0]   prot,
    input  logic [DATA_WIDTH-1:0]   data,
    input  logic [1:0]              resp = 2'b00
  );
    while (!vif.aresetn) @(posedge vif.aclk);

    vif.arready = 1'b0;
    vif.rdata   = data;
    vif.rresp   = resp;
    vif.rvalid  = 1'b0;

    apply_stall();

    vif.arready = 1'b1;
    do begin
      @(posedge vif.aclk);
    end while (!(vif.arvalid && vif.arready));

    addr    = vif.araddr;
    id      = vif.arid;
    len     = vif.arlen;
    size    = vif.arsize;
    burst   = vif.arburst;
    prot    = vif.arprot;
    vif.arready = 1'b0;

    apply_stall();

    vif.rid    = id;
    vif.rdata  = data;
    vif.rresp  = resp;
    vif.rlast  = 1'b1;  // Single beat
    vif.ruser  = '0;
    vif.rvalid = 1'b1;
    do begin
      @(posedge vif.aclk);
    end while (!(vif.rvalid && vif.rready));
    $display("[%0t] %s TX READ  addr=%h data=%h id=%0d len=%0d burst=%0d rresp=%0h",
             $time, vip_name, addr, data, id, len, burst, resp);
    vif.rvalid = 1'b0;
  endtask

endclass
