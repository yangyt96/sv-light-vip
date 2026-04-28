// AXI4 Full Slave VIP
// Software class-based slave that provides backpressure and transaction monitoring.
// Can be used standalone or alongside axi4_full_mem_vip for test scenarios.
//
// Architecture follows symmetric channel-level API pattern as Axi4FullMasterVIP:
//   - recv_awchn() : Receive Write Address Channel (mirror of Master send_awchn)
//   - recv_wchn()  : Receive Write Data Channel  (mirror of Master send_wchn)
//   - send_bchn()  : Send Write Response Channel  (mirror of Master recv_bchn)
//   - recv_archn() : Receive Read Address Channel (mirror of Master send_archn)
//   - send_rchn()  : Send Read Data Channel (single beat, mirror of Master recv_rchn)
//
// High-level convenience tasks (symmetric with Master):
//   - write_resp_single() : recv_awchn + recv_wchn (1 beat) + send_bchn
//   - write_resp_burst()  : recv_awchn + recv_wchn (all beats) + send_bchn
//   - read_resp_single()  : recv_archn + send_rchn (1 beat)
//   - read_resp_burst()   : recv_archn + send_rchn (all beats, loop)
//
// Backpressure architecture (following Master's pattern):
//   - apply_stall() is called ONLY in high-level tasks, NOT in channel-level APIs
//   - This mirrors Master's apply_pause() placement in high-level tasks only
//
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
  bit enable_backpressure;
  int unsigned min_stall_cycles;
  int unsigned max_stall_cycles;
  int unsigned timeout_cycles;

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
    this.vif            = vif;
    this.vip_name       = vip_name;
    enable_backpressure = 1'b0;
    min_stall_cycles    = 0;
    max_stall_cycles    = 0;
    timeout_cycles      = 1000;
  endfunction

  // Configure backpressure for all channels
  function void configure_backpressure(bit enable = 1'b0, int unsigned min_cycles = 0,
                                       int unsigned max_cycles = 0);
    enable_backpressure = enable;
    min_stall_cycles = min_cycles;
    max_stall_cycles = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  task automatic apply_stall();
    int unsigned stall_cycles;
    if (enable_backpressure) begin
      stall_cycles = $urandom_range(max_stall_cycles, min_stall_cycles);
      repeat (stall_cycles) @(posedge vif.aclk);
    end
  endtask

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
    vif.awready <= 1'b0;
    vif.wready  <= 1'b0;
    vif.bid     <= '0;
    vif.bresp   <= 2'b00;
    vif.buser   <= '0;
    vif.bvalid  <= 1'b0;
    vif.arready <= 1'b0;
    vif.rid     <= '0;
    vif.rdata   <= '0;
    vif.rresp   <= 2'b00;
    vif.rlast   <= 1'b0;
    vif.ruser   <= '0;
    vif.rvalid  <= 1'b0;
  endtask

  // ============ Write Channel Tasks ============

  // Wait for and accept a write address (AW) transfer
  task automatic recv_awchn(output logic [ADDR_WIDTH-1:0] addr, output logic [ID_WIDTH-1:0] id,
                            output logic [LEN_WIDTH-1:0] len, output logic [SIZE_WIDTH-1:0] size,
                            output logic [BURST_WIDTH-1:0] burst,
                            output logic [PROT_WIDTH-1:0] prot);
    int unsigned cycles;

    wait_reset_release();

    vif.awready <= 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AWVALID", vip_name);
      end
    end while (!(vif.awvalid));

    // Capture address AFTER handshake. Master uses NBA to drive address
    // signals, which take effect in the NBA region. By waiting for awvalid
    // (which is also NBA-driven), we ensure all address signals are stable.
    addr  = vif.awaddr;
    id    = vif.awid;
    len   = vif.awlen;
    size  = vif.awsize;
    burst = vif.awburst;
    prot  = vif.awprot;

    $display("[%0t] %s RX AW addr=%h id=%0d len=%0d size=%0d burst=%0d", $time, vip_name, addr, id,
             len, size, burst);

    vif.awready <= 1'b0;
  endtask

  task automatic recv_wchn(output logic [DATA_WIDTH-1:0] data, output logic [STRB_WIDTH-1:0] strb,
                           output logic last);
    int unsigned cycles;

    cycles = 0;
    do begin
      vif.wready <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for WVALID", vip_name);
      end
    end while (!vif.wvalid);

    data = vif.wdata;
    strb = vif.wstrb;
    last = vif.wlast;

    $display("[%0t] %s RX W data=%h strb=%h last=%b", $time, vip_name, data, strb, last);

    vif.wready <= 1'b0;
    // @(posedge vif.aclk);
  endtask

  // Send write response (B)
  task automatic send_bchn(input logic [ID_WIDTH-1:0] id, input logic [1:0] resp = 2'b00);
    int unsigned cycles;

    vif.bid    <= id;
    vif.bresp  <= resp;
    vif.buser  <= '0;
    vif.bvalid <= 1'b1;

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
    // @(posedge vif.aclk);
  endtask

  // ─────────────────────────────────────────────
  // High-level Write: recv_awchn + recv_wchn (all beats) + send_bchn
  // Symmetric with Master's write_req_burst()
  // ─────────────────────────────────────────────
  task automatic write_resp_burst(ref logic [DATA_WIDTH-1:0] data[],
                                  ref logic [STRB_WIDTH-1:0] strb[],
                                  input logic [1:0] resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0] id;
    logic [LEN_WIDTH-1:0] len;
    logic [SIZE_WIDTH-1:0] size;
    logic [BURST_WIDTH-1:0] burst;
    logic [PROT_WIDTH-1:0] prot;
    int unsigned beat_count;
    logic [DATA_WIDTH-1:0] beat_data;
    logic [STRB_WIDTH-1:0] beat_strb;
    bit beat_last;

    apply_stall();
    recv_awchn(addr, id, len, size, burst, prot);
    beat_count = int'(len) + 1;

    data = new[beat_count];
    strb = new[beat_count];

    for (int i = 0; i < beat_count; i++) begin
      apply_stall();
      recv_wchn(beat_data, beat_strb, beat_last);
      data[i] = beat_data;
      strb[i] = beat_strb;
      if (beat_last && i < (beat_count - 1)) begin
        $warning("%s WLAST asserted early at beat %0d/%0d", vip_name, i, beat_count);
      end
    end

    if (!beat_last) begin
      $warning("%s WLAST not asserted at final beat %0d", vip_name, beat_count - 1);
    end

    apply_stall();
    send_bchn(id, resp);
  endtask

  // ─────────────────────────────────────────────
  // Single-beat Write: recv_awchn + recv_wchn (1 beat) + send_bchn
  // Symmetric with Master's write_req_single()
  // ─────────────────────────────────────────────
  task automatic write_resp_single(input logic [DATA_WIDTH-1:0] data,
                                   input logic [STRB_WIDTH-1:0] strb = '1,
                                   input logic [1:0] resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0] id;
    logic [LEN_WIDTH-1:0] len;
    logic [SIZE_WIDTH-1:0] size;
    logic [BURST_WIDTH-1:0] burst;
    logic [PROT_WIDTH-1:0] prot;
    logic [DATA_WIDTH-1:0] beat_data;
    logic [STRB_WIDTH-1:0] beat_strb;
    bit beat_last;

    apply_stall();
    recv_awchn(addr, id, len, size, burst, prot);
    apply_stall();
    recv_wchn(beat_data, beat_strb, beat_last);
    apply_stall();
    send_bchn(id, resp);
  endtask

  // ============ Read Channel Tasks ============

  // Wait for and accept a read address (AR) transfer
  task automatic recv_archn(output logic [ADDR_WIDTH-1:0] addr, output logic [ID_WIDTH-1:0] id,
                            output logic [LEN_WIDTH-1:0] len, output logic [SIZE_WIDTH-1:0] size,
                            output logic [BURST_WIDTH-1:0] burst,
                            output logic [PROT_WIDTH-1:0] prot);
    int unsigned cycles;

    wait_reset_release();

    vif.arready <= 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for ARVALID", vip_name);
      end
    end while (!(vif.arvalid));

    // Capture address AFTER handshake. Master uses NBA to drive address
    // signals, which take effect in the NBA region. By waiting for arvalid
    // (which is also NBA-driven), we ensure all address signals are stable.
    addr  = vif.araddr;
    id    = vif.arid;
    len   = vif.arlen;
    size  = vif.arsize;
    burst = vif.arburst;
    prot  = vif.arprot;

    $display("[%0t] %s RX AR addr=%h id=%0d len=%0d size=%0d burst=%0d", $time, vip_name, addr, id,
             len, size, burst);

    vif.arready <= 1'b0;
  endtask

  // Send read data (single beat) — symmetric with Master's recv_rchn (scalar)
  task automatic send_rchn(input logic [DATA_WIDTH-1:0] data, input logic [ID_WIDTH-1:0] id,
                           input logic [1:0] resp = 2'b00, input logic last = 1'b1);
    int unsigned cycles;

    vif.rid    <= id;
    vif.rdata  <= data;
    vif.rresp  <= resp;
    vif.rlast  <= last;
    vif.ruser  <= '0;
    vif.rvalid <= 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for RREADY", vip_name);
      end
    end while (!(vif.rready));

    $display("[%0t] %s TX R data=%h id=%0d resp=%0h last=%b", $time, vip_name, data, id, resp, last);

    vif.rvalid <= 0;
    // @(posedge vif.aclk);
  endtask

  // ─────────────────────────────────────────────
  // High-level Read: recv_archn + send_rchn (all beats, loop)
  // Symmetric with Master's read_req_burst()
  // ─────────────────────────────────────────────
  task automatic read_resp_burst(ref logic [DATA_WIDTH-1:0] data[],
                                 input logic [1:0] resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0] id;
    logic [LEN_WIDTH-1:0] len;
    logic [SIZE_WIDTH-1:0] size;
    logic [BURST_WIDTH-1:0] burst;
    logic [PROT_WIDTH-1:0] prot;
    int unsigned beat_count;

    apply_stall();
    recv_archn(addr, id, len, size, burst, prot);
    beat_count = int'(len) + 1;

    assert (data.size() >= beat_count)
    else
      $fatal(
          1,
          "%s respond_read_burst data array too short (need %0d, got %0d)",
          vip_name,
          beat_count,
          data.size()
      );

    for (int i = 0; i < beat_count; i++) begin
      apply_stall();
      send_rchn(data[i], id, resp, (i == (beat_count - 1)));
    end

  endtask

  // ─────────────────────────────────────────────
  // Single-beat Read: recv_archn + send_rchn (1 beat)
  // Symmetric with Master's read_req_single()
  // ─────────────────────────────────────────────
  task automatic read_resp_single(output logic [DATA_WIDTH-1:0] data,
                                  input logic [1:0] resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0] id;
    logic [LEN_WIDTH-1:0] len;
    logic [SIZE_WIDTH-1:0] size;
    logic [BURST_WIDTH-1:0] burst;
    logic [PROT_WIDTH-1:0] prot;
    int unsigned beat_count;

    apply_stall();
    recv_archn(addr, id, len, size, burst, prot);
    beat_count = int'(len) + 1;

    assert (beat_count == 1)
    else
      $fatal(
          1,
          "%s respond_read_single called but master requested %0d beats (use respond_read_burst)",
          vip_name,
          beat_count
      );

    apply_stall();
    send_rchn(data, id, resp, 1'b1);
  endtask

  // ============ Deprecated wrappers (backward compatible) ============

  // Deprecated: use write_resp_burst() instead
  task automatic expect_write_and_respond(ref logic [DATA_WIDTH-1:0] data[],
                                          ref logic [STRB_WIDTH-1:0] strb[],
                                          input logic [1:0] resp = 2'b00);
    write_resp_burst(data, strb, resp);
  endtask

  // Deprecated: use read_resp_burst() instead
  task automatic respond_read(ref logic [DATA_WIDTH-1:0] data[], input logic [1:0] resp = 2'b00);
    read_resp_burst(data, resp);
  endtask

  // Deprecated: use write_resp_burst()/write_resp_single() instead
  task automatic expect_write(output logic [ADDR_WIDTH-1:0] addr, ref logic [DATA_WIDTH-1:0] data[],
                              ref logic [STRB_WIDTH-1:0] strb[], output logic [ID_WIDTH-1:0] id,
                              output logic [LEN_WIDTH-1:0] len, output logic [SIZE_WIDTH-1:0] size,
                              output logic [BURST_WIDTH-1:0] burst,
                              output logic [PROT_WIDTH-1:0] prot);
    int unsigned                  beat_count;
    logic        [DATA_WIDTH-1:0] beat_data;
    logic        [STRB_WIDTH-1:0] beat_strb;
    bit                           beat_last;

    recv_awchn(addr, id, len, size, burst, prot);
    beat_count = int'(len) + 1;

    data = new[beat_count];
    strb = new[beat_count];

    for (int i = 0; i < beat_count; i++) begin
      recv_wchn(beat_data, beat_strb, beat_last);

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

endclass
