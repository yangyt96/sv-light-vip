// AXI4-Lite Slave VIP
// Software class-based slave that provides backpressure and transaction monitoring.
// Can be used standalone or alongside axi4_lite_mem_vip for test scenarios.
//
// Architecture follows symmetric channel-level API pattern as Axi4LiteMasterVIP:
//   - recv_awchn() : Receive Write Address Channel (mirror of Master send_awchn)
//   - recv_wchn()  : Receive Write Data Channel  (mirror of Master send_wchn)
//   - send_bchn()  : Send Write Response Channel  (mirror of Master recv_bchn)
//   - recv_archn() : Receive Read Address Channel (mirror of Master send_archn)
//   - send_rchn()  : Send Read Data Channel       (mirror of Master recv_rchn)
//
// High-level convenience tasks (symmetric with Master):
//   - write_resp_single() : recv_awchn + recv_wchn + send_bchn
//   - read_resp_single()  : recv_archn + send_rchn
//
// Backpressure architecture (following Master's pattern):
//   - apply_stall() is called ONLY in high-level tasks, NOT in channel-level APIs
//   - This mirrors Master's apply_pause() placement in high-level tasks only
//
// Features:
//   - Backpressure on AW/W/AR channels (stall before ready)
//   - Backpressure on B/R channels (stall before valid)
//   - Write transaction capture (write_resp_single)
//   - Read transaction response (read_resp_single)
//   - Configurable response (OKAY/SLVERR/DECERR)

class Axi4LiteSlaveVIP #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32,
    int STRB_WIDTH = DATA_WIDTH / 8
);

  virtual axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH).slave vif;

  string vip_name;
  bit enable_backpressure;
  int unsigned min_stall_cycles;
  int unsigned max_stall_cycles;
  int unsigned timeout_cycles;

  function new(virtual axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH).slave vif,
               string vip_name = "axi4_lite_slave_vip");
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
    min_stall_cycles    = min_cycles;
    max_stall_cycles    = (max_cycles < min_cycles) ? min_cycles : max_cycles;
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
        $fatal(1, "%s timed out waiting for AXI4-Lite reset release", vip_name);
      end
    end
  endtask

  // Clear all slave output signals to default state
  task automatic clear_outputs();
    vif.awready <= 1'b0;
    vif.wready  <= 1'b0;
    vif.bresp   <= 2'b00;
    vif.bvalid  <= 1'b0;
    vif.arready <= 1'b0;
    vif.rdata   <= '0;
    vif.rresp   <= 2'b00;
    vif.rvalid  <= 1'b0;
  endtask

  // ============ Write Channel Tasks ============

  // Wait for and accept a write address (AW) transfer
  // Note: wait_reset_release() is called in high-level tasks, not here
  task automatic recv_awchn(output logic [ADDR_WIDTH-1:0] addr, output logic [2:0] prot);
    int unsigned cycles;

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
    addr = vif.awaddr;
    prot = vif.awprot;

    $display("[%0t] %s RX AW addr=%h prot=%0h", $time, vip_name, addr, prot);

    vif.awready <= 1'b0;
  endtask

  // Note: wait_reset_release() is called in high-level tasks, not here
  task automatic recv_wchn(output logic [DATA_WIDTH-1:0] data, output logic [STRB_WIDTH-1:0] strb);
    int unsigned cycles;

    vif.wready <= 1'b1;
    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for WVALID", vip_name);
      end
    end while (!(vif.wvalid));

    data = vif.wdata;
    strb = vif.wstrb;

    $display("[%0t] %s RX W data=%h strb=%h", $time, vip_name, data, strb);

    vif.wready <= 1'b0;
  endtask

  // Send write response (B)
  // Note: wait_reset_release() is called in high-level tasks, not here
  task automatic send_bchn(input logic [1:0] resp = 2'b00);
    int unsigned cycles;

    vif.bresp  <= resp;
    vif.bvalid <= 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for BREADY", vip_name);
      end
    end while (!(vif.bready));

    $display("[%0t] %s TX B resp=%0h", $time, vip_name, resp);

    vif.bvalid <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // High-level Write: recv_awchn + recv_wchn + send_bchn
  // Symmetric with Master's write_req_single()
  // ─────────────────────────────────────────────
  task automatic write_resp_single(input logic [DATA_WIDTH-1:0] data,
                                   input logic [STRB_WIDTH-1:0] strb = '1,
                                   input logic [1:0] resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [           2:0] prot;
    logic [DATA_WIDTH-1:0] beat_data;
    logic [STRB_WIDTH-1:0] beat_strb;

    wait_reset_release();
    apply_stall();
    recv_awchn(addr, prot);
    apply_stall();
    recv_wchn(beat_data, beat_strb);
    apply_stall();
    send_bchn(resp);

    if (beat_data !== data) begin
      $warning("%s write_resp_single data mismatch: expected %h, got %h", vip_name, data,
               beat_data);
    end
  endtask

  // ============ Read Channel Tasks ============

  // Wait for and accept a read address (AR) transfer
  // Note: wait_reset_release() is called in high-level tasks, not here
  task automatic recv_archn(output logic [ADDR_WIDTH-1:0] addr, output logic [2:0] prot);
    int unsigned cycles;

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
    addr = vif.araddr;
    prot = vif.arprot;

    $display("[%0t] %s RX AR addr=%h prot=%0h", $time, vip_name, addr, prot);

    vif.arready <= 1'b0;
  endtask

  // Send read data (single beat) — symmetric with Master's recv_rchn
  // Note: wait_reset_release() is called in high-level tasks, not here
  task automatic send_rchn(input logic [DATA_WIDTH-1:0] data, input logic [1:0] resp = 2'b00);
    int unsigned cycles;

    vif.rdata  <= data;
    vif.rresp  <= resp;
    vif.rvalid <= 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for RREADY", vip_name);
      end
    end while (!(vif.rready));

    $display("[%0t] %s TX R data=%h resp=%0h", $time, vip_name, data, resp);

    vif.rvalid <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // High-level Read: recv_archn + send_rchn
  // Symmetric with Master's read_req_single()
  // ─────────────────────────────────────────────
  task automatic read_resp_single(input logic [DATA_WIDTH-1:0] data,
                                  input logic [1:0] resp = 2'b00);
    logic [ADDR_WIDTH-1:0] addr;
    logic [           2:0] prot;

    wait_reset_release();
    apply_stall();
    recv_archn(addr, prot);
    apply_stall();
    send_rchn(data, resp);
  endtask

endclass
