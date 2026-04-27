// AXI4 Full Slave VIP
// Software class-based slave that provides backpressure and transaction monitoring.
// Can be used standalone or alongside axi4_full_mem_vip for test scenarios.
// Features:
//   - Backpressure on AW/W/AR channels (stall before ready)
//   - Backpressure on B/R channels (stall before valid)
//   - Write transaction capture (expect_write)
//   - Read transaction response (respond_read)
//   - Configurable response (OKAY/SLVERR/DECERR)

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
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .ID_WIDTH(ID_WIDTH),
      .LEN_WIDTH(LEN_WIDTH),
      .SIZE_WIDTH(SIZE_WIDTH),
      .BURST_WIDTH(BURST_WIDTH),
      .LOCK_WIDTH(LOCK_WIDTH),
      .CACHE_WIDTH(CACHE_WIDTH),
      .PROT_WIDTH(PROT_WIDTH),
      .QOS_WIDTH(QOS_WIDTH),
      .REGION_WIDTH(REGION_WIDTH),
      .STRB_WIDTH(STRB_WIDTH),
      .AWUSER_WIDTH(AWUSER_WIDTH),
      .WUSER_WIDTH(WUSER_WIDTH),
      .BUSER_WIDTH(BUSER_WIDTH),
      .ARUSER_WIDTH(ARUSER_WIDTH),
      .RUSER_WIDTH(RUSER_WIDTH)
  ).slave vif;

  string vip_name;
  int unsigned timeout_cycles;

  // Backpressure control for write address channel
  bit enable_aw_backpressure;
  int unsigned min_aw_stall;
  int unsigned max_aw_stall;

  // Backpressure control for write data channel
  bit enable_w_backpressure;
  int unsigned min_w_stall;
  int unsigned max_w_stall;

  // Backpressure control for read address channel
  bit enable_ar_backpressure;
  int unsigned min_ar_stall;
  int unsigned max_ar_stall;

  // Backpressure control for write response channel
  bit enable_b_backpressure;
  int unsigned min_b_stall;
  int unsigned max_b_stall;

  // Backpressure control for read data channel
  bit enable_r_backpressure;
  int unsigned min_r_stall;
  int unsigned max_r_stall;

  function new(
      virtual axi4_full_if #(
          .ADDR_WIDTH(ADDR_WIDTH),
          .DATA_WIDTH(DATA_WIDTH),
          .ID_WIDTH(ID_WIDTH),
          .LEN_WIDTH(LEN_WIDTH),
          .SIZE_WIDTH(SIZE_WIDTH),
          .BURST_WIDTH(BURST_WIDTH),
          .LOCK_WIDTH(LOCK_WIDTH),
          .CACHE_WIDTH(CACHE_WIDTH),
          .PROT_WIDTH(PROT_WIDTH),
          .QOS_WIDTH(QOS_WIDTH),
          .REGION_WIDTH(REGION_WIDTH),
          .STRB_WIDTH(STRB_WIDTH),
          .AWUSER_WIDTH(AWUSER_WIDTH),
          .WUSER_WIDTH(WUSER_WIDTH),
          .BUSER_WIDTH(BUSER_WIDTH),
          .ARUSER_WIDTH(ARUSER_WIDTH),
          .RUSER_WIDTH(RUSER_WIDTH)
      ).slave vif,
      string vip_name = "axi4_full_slave_vip");
    this.vif       = vif;
    this.vip_name  = vip_name;
    timeout_cycles = 1000;

    enable_aw_backpressure = 1'b0;
    min_aw_stall           = 0;
    max_aw_stall           = 0;

    enable_w_backpressure  = 1'b0;
    min_w_stall            = 0;
    max_w_stall            = 0;

    enable_ar_backpressure = 1'b0;
    min_ar_stall           = 0;
    max_ar_stall           = 0;

    enable_b_backpressure  = 1'b0;
    min_b_stall            = 0;
    max_b_stall            = 0;

    enable_r_backpressure  = 1'b0;
    min_r_stall            = 0;
    max_r_stall            = 0;
  endfunction

  // Configure backpressure for all channels
  function void configure_backpressure(
      bit enable_aw = 1'b0, int unsigned min_aw = 0, int unsigned max_aw = 0,
      bit enable_w  = 1'b0, int unsigned min_w  = 0, int unsigned max_w  = 0,
      bit enable_ar = 1'b0, int unsigned min_ar = 0, int unsigned max_ar = 0,
      bit enable_b  = 1'b0, int unsigned min_b  = 0, int unsigned max_b  = 0,
      bit enable_r  = 1'b0, int unsigned min_r  = 0, int unsigned max_r  = 0);
    enable_aw_backpressure = enable_aw;
    min_aw_stall           = min_aw;
    max_aw_stall           = (max_aw < min_aw) ? min_aw : max_aw;

    enable_w_backpressure  = enable_w;
    min_w_stall            = min_w;
    max_w_stall            = (max_w < min_w) ? min_w : max_w;

    enable_ar_backpressure = enable_ar;
    min_ar_stall           = min_ar;
    max_ar_stall           = (max_ar < min_ar) ? min_ar : max_ar;

    enable_b_backpressure  = enable_b;
    min_b_stall            = min_b;
    max_b_stall            = (max_b < min_b) ? min_b : max_b;

    enable_r_backpressure  = enable_r;
    min_r_stall            = min_r;
    max_r_stall            = (max_r < min_r) ? min_r : max_r;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  // Get stall cycles for a specific channel
  function automatic int unsigned get_aw_stall();
    if (enable_aw_backpressure) return $urandom_range(max_aw_stall, min_aw_stall);
    else return 0;
  endfunction

  function automatic int unsigned get_w_stall();
    if (enable_w_backpressure) return $urandom_range(max_w_stall, min_w_stall);
    else return 0;
  endfunction

  function automatic int unsigned get_ar_stall();
    if (enable_ar_backpressure) return $urandom_range(max_ar_stall, min_ar_stall);
    else return 0;
  endfunction

  function automatic int unsigned get_b_stall();
    if (enable_b_backpressure) return $urandom_range(max_b_stall, min_b_stall);
    else return 0;
  endfunction

  function automatic int unsigned get_r_stall();
    if (enable_r_backpressure) return $urandom_range(max_r_stall, min_r_stall);
    else return 0;
  endfunction

  task automatic wait_reset_release();
    int unsigned cycles;
    cycles = 0;
    while (!vif.aresetn) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4 reset release", vip_name);
      end
    end
  endtask

  // Clear all slave output signals to default state
  task automatic clear_outputs();
    vif.awready = 1'b0;
    vif.wready  = 1'b0;
    vif.bid     = '0;
    vif.bresp   = 2'b00;
    vif.buser   = '0;
    vif.bvalid  = 1'b0;
    vif.arready = 1'b0;
    vif.rid     = '0;
    vif.rdata   = '0;
    vif.rresp   = 2'b00;
    vif.rlast   = 1'b0;
    vif.ruser   = '0;
    vif.rvalid  = 1'b0;
  endtask

  // ============ Write Channel Tasks ============

  // Wait for and accept a write address (AW) transfer
  task automatic recv_awchn(
      output logic [  ADDR_WIDTH-1:0] addr,
      output logic [    ID_WIDTH-1:0] id,
      output logic [   LEN_WIDTH-1:0] len,
      output logic [  SIZE_WIDTH-1:0] size,
      output logic [ BURST_WIDTH-1:0] burst,
      output logic [  PROT_WIDTH-1:0] prot);
    int unsigned cycles;
    int unsigned stall;

    wait_reset_release();

    stall = get_aw_stall();
    repeat (stall) @(posedge vif.aclk);

    cycles = 0;
    while (!(vif.awvalid)) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AWVALID", vip_name);
      end
    end

    addr   = vif.awaddr;
    id     = vif.awid;
    len    = vif.awlen;
    size   = vif.awsize;
    burst  = vif.awburst;
    prot   = vif.awprot;
    vif.awready <= 1'b1;
    @(posedge vif.aclk);

    $display("[%0t] %s RX AW addr=%h id=%0d len=%0d size=%0d burst=%0d",
             $time, vip_name, addr, id, len, size, burst);

    vif.awready <= 1'b0;
    @(posedge vif.aclk);
  endtask

  // Wait for and accept a single write data (W) beat
  task automatic accept_write_data(
      output logic [DATA_WIDTH-1:0] data,
      output logic [STRB_WIDTH-1:0] strb,
      output bit                    last);
    int unsigned cycles;
    int unsigned stall;

    stall = get_w_stall();
    repeat (stall) @(posedge vif.aclk);

    cycles = 0;

    // Use while loop (check before wait) to avoid race condition in fork...join.
    // If master already has wvalid asserted, capture data immediately.
    while (!vif.wvalid) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for WVALID", vip_name);
      end
    end

    vif.wready = 1'b1;
    @(posedge vif.aclk);

    // Capture data combinatorially (immediately) after while loop exits.
    // In fork...join, master may update wdata on the same clock edge, so
    // we must capture before any NBA updates take effect.
    data = vif.wdata;
    strb = vif.wstrb;
    last = vif.wlast;

    // Use non-blocking assignment to release wready, ensuring master sees
    // the handshake in its while loop even in fork...join race.
    vif.wready <= 1'b0;
    @(posedge vif.aclk);

    $display("[%0t] %s RX W data=%h strb=%h last=%0b", $time, vip_name, data, strb, last);
  endtask

  // Wait for and accept a complete write burst (AW + all W beats)
  task automatic expect_write(
      output logic [  ADDR_WIDTH-1:0] addr,
      ref     logic [DATA_WIDTH-1:0]  data[],
      ref     logic [  STRB_WIDTH-1:0] strb[],
      output logic [    ID_WIDTH-1:0] id,
      output logic [   LEN_WIDTH-1:0] len,
      output logic [  SIZE_WIDTH-1:0] size,
      output logic [ BURST_WIDTH-1:0] burst,
      output logic [  PROT_WIDTH-1:0] prot);
    int unsigned beat_count;
    logic [DATA_WIDTH-1:0] beat_data;
    logic [STRB_WIDTH-1:0] beat_strb;
    bit                    beat_last;

    recv_awchn(addr, id, len, size, burst, prot);
    beat_count = int'(len) + 1;

    data = new[beat_count];
    strb = new[beat_count];

    $display("[%0t] debug slave 0 beat_count=%0d", $time, beat_count);

    for (int i = 0; i < beat_count; i++) begin
      accept_write_data(beat_data, beat_strb, beat_last);

      $display("[%0t] debug slave 1 itr=%0d", $time, i);

      data[i] = beat_data;
      strb[i] = beat_strb;
      if (beat_last && i < (beat_count - 1)) begin
        $warning("%s WLAST asserted early at beat %0d/%0d", vip_name, i, beat_count);
      end
    end

    if (!beat_last) begin
      $warning("%s WLAST not asserted at final beat %0d", vip_name, beat_count - 1);
    end
  endtask

  // Send write response (B)
  task automatic send_write_response(
      input logic [ID_WIDTH-1:0] id,
      input logic [1:0]          resp = 2'b00);
    int unsigned cycles;
    int unsigned stall;

    stall = get_b_stall();
    repeat (stall) @(posedge vif.aclk);

    vif.bid    = id;
    vif.bresp  = resp;
    vif.buser  = '0;
    vif.bvalid = 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for BREADY", vip_name);
      end
    end while (!(vif.bready));

    $display("[%0t] %s TX B id=%0d resp=%0h", $time, vip_name, id, resp);

    vif.bvalid <= 1'b0;
    @(posedge vif.aclk);
  endtask

  // Complete write transaction: expect write + send response
  task automatic expect_write_and_respond(
      ref logic [DATA_WIDTH-1:0] data[],
      ref logic [STRB_WIDTH-1:0] strb[],
      input logic [1:0]          resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [  ID_WIDTH-1:0] id;
    logic [ LEN_WIDTH-1:0] len;
    logic [SIZE_WIDTH-1:0] size;
    logic [BURST_WIDTH-1:0] burst;
    logic [  PROT_WIDTH-1:0] prot;

    expect_write(addr, data, strb, id, len, size, burst, prot);
    send_write_response(id, resp);
  endtask

  // ============ Read Channel Tasks ============

  // Wait for and accept a read address (AR) transfer
  task automatic recv_archn(
      output logic [  ADDR_WIDTH-1:0] addr,
      output logic [    ID_WIDTH-1:0] id,
      output logic [   LEN_WIDTH-1:0] len,
      output logic [  SIZE_WIDTH-1:0] size,
      output logic [ BURST_WIDTH-1:0] burst,
      output logic [  PROT_WIDTH-1:0] prot);
    int unsigned cycles;
    int unsigned stall;

    wait_reset_release();

    stall = get_ar_stall();
    repeat (stall) @(posedge vif.aclk);

    cycles = 0;
    while (!(vif.arvalid)) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for ARVALID", vip_name);
      end
    end

    addr  = vif.araddr;
    id    = vif.arid;
    len   = vif.arlen;
    size  = vif.arsize;
    burst = vif.arburst;
    prot  = vif.arprot;
    vif.arready = 1'b1;
    @(posedge vif.aclk);

    $display("[%0t] %s RX AR addr=%h id=%0d len=%0d size=%0d burst=%0d",
             $time, vip_name, addr, id, len, size, burst);

    vif.arready <= 1'b0;
    @(posedge vif.aclk);
  endtask

  task automatic send_rchn(
      input logic [DATA_WIDTH-1:0] data[],
      input logic [  ID_WIDTH-1:0] id,
      input logic [1:0]            resp = 2'b00);
    int unsigned beat_count;
    int unsigned beat_idx;
    int unsigned cycles;

    int unsigned stall;

    beat_count = data.size();
    assert (beat_count > 0)
    else $fatal(1, "%s send_rchn called with no data beats", vip_name);

    stall = get_r_stall();
    repeat (stall) @(posedge vif.aclk);

    vif.rdata  = data[0];
    vif.rid    = id;
    vif.rresp  = resp;
    vif.rlast  = (beat_count == 1);
    vif.ruser  = '0;
    vif.rvalid = 1'b1;

    beat_idx   = 0;
    cycles     = 0;

    while (beat_idx < beat_count) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4 write data handshakes", vip_name);
      end
      if (vif.rvalid && vif.rready) begin
        beat_idx++;
        if (beat_idx < beat_count) begin
          vif.rdata = data[beat_idx];
          vif.rlast = (beat_idx == (beat_count - 1));
        end else begin
          vif.rvalid = 1'b0;
          vif.rlast  = 1'b0;
        end
      end
    end

  endtask

  // Send a single read data (R) beat
  task automatic send_read_data(
      input logic [  ID_WIDTH-1:0] id,
      input logic [DATA_WIDTH-1:0] data,
      input logic [1:0]            resp = 2'b00,
      input bit                    last = 1'b1);
    int unsigned cycles;
    int unsigned stall;

    stall = get_r_stall();
    repeat (stall) @(posedge vif.aclk);

    vif.rid    = id;
    vif.rdata  = data;
    vif.rresp  = resp;
    vif.rlast  = last;
    vif.ruser  = '0;
    vif.rvalid = 1'b1;

    // Use while loop (check before wait) to avoid race condition in fork...join.
    // If master already has rready asserted, handshake completes immediately.
    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for RREADY", vip_name);
      end
    end while (!(vif.rvalid && vif.rready));

    $display("[%0t] %s TX R id=%0d data=%h resp=%0h last=%0b", $time, vip_name, id, data, resp, last);

    // Use non-blocking assignment to release rvalid, ensuring master sees
    // the handshake in its do...while loop even in fork...join race.
    vif.rvalid <= 1'b0;
    @(posedge vif.aclk);
  endtask

  // Complete read transaction: accept address + send all data beats
  task automatic respond_read(
      ref logic [DATA_WIDTH-1:0] data[],
      input logic [1:0]          resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [  ID_WIDTH-1:0] id;
    logic [ LEN_WIDTH-1:0] len;
    logic [SIZE_WIDTH-1:0] size;
    logic [BURST_WIDTH-1:0] burst;
    logic [  PROT_WIDTH-1:0] prot;
    int unsigned beat_count;

    recv_archn(addr, id, len, size, burst, prot);
    beat_count = int'(len) + 1;

    assert(data.size() >= beat_count)
    else $fatal(1, "%s respond_read data array too short (need %0d, got %0d)",
               vip_name, beat_count, data.size());

    // send_rchn(data, id, resp);

    for (int i = 0; i < beat_count; i++) begin
      send_read_data(id, data[i], resp, (i == (beat_count - 1)));
    end
  endtask

endclass
