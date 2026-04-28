// AXI4-Lite Master VIP
// Provides write and read transaction generation with support for
// optional pause/backpressure generation
//
// Architecture follows the same channel-level API pattern as AXI4-Full Master VIP:
//   - send_awchn() : Write Address Channel
//   - send_wchn()  : Write Data Channel
//   - recv_bchn()  : Write Response Channel
//   - send_archn() : Read Address Channel
//   - recv_rchn()  : Read Data Channel
//
// High-level convenience tasks:
//   - write() : send_awchn + send_wchn + recv_bchn
//   - read()  : send_archn + recv_rchn

class Axi4LiteMasterVIP #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32,
    int STRB_WIDTH = DATA_WIDTH / 8
);

  virtual axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH).master vif;
  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;
  int unsigned timeout_cycles;

  function new(virtual axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH).master vif,
               string vip_name = "axi4_lite_master_vip");
    this.vif               = vif;
    this.vip_name          = vip_name;
    enable_pause_generator = 1'b0;
    min_pause_cycles       = 0;
    max_pause_cycles       = 0;
    timeout_cycles         = 1000;
  endfunction

  function void configure_pause_generator(bit enable, int unsigned min_cycles = 0,
                                          int unsigned max_cycles = 0);
    enable_pause_generator = enable;
    min_pause_cycles       = min_cycles;
    max_pause_cycles       = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  // Wait for reset release and optionally insert random pause cycles
  task automatic apply_pause();
    int unsigned pause_cycles;
    int unsigned cycles;

    cycles = 0;
    while (!vif.aresetn) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4-Lite reset release", vip_name);
      end
    end
    if (enable_pause_generator) begin
      pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
      repeat (pause_cycles) @(posedge vif.aclk);
    end
  endtask

  // Initialize all driven signals to their default values
  task automatic clear_outputs();
    vif.awaddr  <= '0;
    vif.awprot  <= '0;
    vif.awvalid <= 1'b0;
    vif.wdata   <= '0;
    vif.wstrb   <= '0;
    vif.wvalid  <= 1'b0;
    vif.bready  <= 1'b0;
    vif.araddr  <= '0;
    vif.arprot  <= '0;
    vif.arvalid <= 1'b0;
    vif.rready  <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // Write Address Channel (AW)
  // ─────────────────────────────────────────────
  task automatic send_awchn(
      input logic [ADDR_WIDTH-1:0] addr,
      input logic [           2:0] prot = 3'b000);
    int unsigned cycles;

    apply_pause();

    cycles = 0;
    do begin
      vif.awaddr  <= addr;
      vif.awprot  <= prot;
      vif.awvalid <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4-Lite write address handshake", vip_name);
      end
    end while (!(vif.awready));

    $display("[%0t] %s TX AW addr=%h prot=%0h", $time, vip_name, addr, prot);

    vif.awvalid <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // Write Data Channel (W)
  // ─────────────────────────────────────────────
  task automatic send_wchn(
      input logic [DATA_WIDTH-1:0] data,
      input logic [STRB_WIDTH-1:0] strb = '1);
    int unsigned cycles;

    apply_pause();

    cycles = 0;
    do begin
      vif.wdata  <= data;
      vif.wstrb  <= strb;
      vif.wvalid <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4-Lite write data handshake", vip_name);
      end
    end while (!(vif.wready));

    vif.wvalid <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // Write Response Channel (B)
  // ─────────────────────────────────────────────
  task automatic recv_bchn(output logic [1:0] resp);
    int unsigned cycles;

    apply_pause();

    cycles = 0;
    do begin
      vif.bready <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4-Lite write response", vip_name);
      end
    end while (!(vif.bvalid));

    resp = vif.bresp;
    $display("[%0t] %s RX B bresp=%0h", $time, vip_name, resp);

    vif.bready <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // High-level Write (AW + W + B)
  // ─────────────────────────────────────────────
  task write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
             input logic [STRB_WIDTH-1:0] strb = '1, output logic [1:0] resp,
             input logic [2:0] prot = 3'b000);

    send_awchn(addr, prot);
    send_wchn(data, strb);
    recv_bchn(resp);

    $display("[%0t] %s TX WRITE addr=%h data=%h strb=%h prot=%0h bresp=%0h", $time, vip_name, addr,
             data, strb, prot, resp);
  endtask

  // ─────────────────────────────────────────────
  // Read Address Channel (AR)
  // ─────────────────────────────────────────────
  task automatic send_archn(
      input logic [ADDR_WIDTH-1:0] addr,
      input logic [           2:0] prot = 3'b000);
    int unsigned cycles;

    apply_pause();

    vif.araddr  <= addr;
    vif.arprot  <= prot;
    vif.arvalid <= 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4-Lite read address handshake", vip_name);
      end
    end while (!(vif.arready));

    $display("[%0t] %s TX AR addr=%h prot=%0h", $time, vip_name, addr, prot);

    vif.arvalid <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // Read Data Channel (R)
  // ─────────────────────────────────────────────
  task automatic recv_rchn(output logic [DATA_WIDTH-1:0] data, output logic [1:0] resp);
    int unsigned cycles;

    apply_pause();

    cycles = 0;
    do begin
      vif.rready <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4-Lite read data", vip_name);
      end
    end while (!(vif.rvalid));

    data = vif.rdata;
    resp = vif.rresp;

    vif.rready <= 1'b0;
  endtask

  // ─────────────────────────────────────────────
  // High-level Read (AR + R)
  // ─────────────────────────────────────────────
  task read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data,
            output logic [1:0] resp, input logic [2:0] prot = 3'b000);

    send_archn(addr, prot);
    recv_rchn(data, resp);

    $display("[%0t] %s RX READ  addr=%h data=%h prot=%0h rresp=%0h", $time, vip_name, addr, data,
             prot, resp);
  endtask

endclass
