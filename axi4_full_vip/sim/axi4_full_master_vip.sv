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

  // Virtual interface handle
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
  ).master vif;

  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;
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
      ).master vif,
      string vip_name = "axi4_full_master_vip");
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
    min_pause_cycles = min_cycles;
    max_pause_cycles = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  task automatic apply_pause();
    int unsigned pause_cycles;
    int unsigned cycles;

    cycles = 0;
    while (!vif.aresetn) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4 reset release", vip_name);
      end
    end
    if (enable_pause_generator) begin
      pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
      repeat (pause_cycles) @(posedge vif.aclk);
    end
  endtask

  task automatic clear_outputs();
    vif.awid     <= '0;
    vif.awaddr   <= '0;
    vif.awlen    <= '0;
    vif.awsize   <= '0;
    vif.awburst  <= '0;
    vif.awlock   <= '0;
    vif.awcache  <= '0;
    vif.awprot   <= '0;
    vif.awqos    <= '0;
    vif.awregion <= '0;
    vif.awuser   <= '0;
    vif.awvalid  <= 1'b0;
    vif.wdata    <= '0;
    vif.wstrb    <= '0;
    vif.wlast    <= 1'b0;
    vif.wuser    <= '0;
    vif.wvalid   <= 1'b0;
    vif.bready   <= 1'b0;
    vif.arid     <= '0;
    vif.araddr   <= '0;
    vif.arlen    <= '0;
    vif.arsize   <= '0;
    vif.arburst  <= '0;
    vif.arlock   <= '0;
    vif.arcache  <= '0;
    vif.arprot   <= '0;
    vif.arqos    <= '0;
    vif.arregion <= '0;
    vif.aruser   <= '0;
    vif.arvalid  <= 1'b0;
    vif.rready   <= 1'b0;
  endtask

  // Write transaction: address, data, and response
  task write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
             input logic [STRB_WIDTH-1:0] strb = '1, input logic [ID_WIDTH-1:0] id = '0,
             input logic [LEN_WIDTH-1:0] len = '0,  // Single beat
             input logic [SIZE_WIDTH-1:0] size = $clog2(STRB_WIDTH),
             input logic [BURST_WIDTH-1:0] burst = 2'b01,  // INCR
             input logic [PROT_WIDTH-1:0] prot = 3'b000, output logic [1:0] resp);
    logic [DATA_WIDTH-1:0] burst_data[1];
    logic [STRB_WIDTH-1:0] burst_strb[1];
    begin
      burst_data[0] = data;
      burst_strb[0] = strb;
      write_burst(addr, burst_data, burst_strb, id, size, burst, prot, resp);
    end
  endtask

  // Write Address Channel - Send write address phase
  task send_awchn(
      input logic [ADDR_WIDTH-1:0] addr, input int unsigned beat_count = 1,
      input logic [ID_WIDTH-1:0] id = '0, input logic [SIZE_WIDTH-1:0] size = $clog2(STRB_WIDTH),
      input logic [BURST_WIDTH-1:0] burst = 2'b01, input logic [PROT_WIDTH-1:0] prot = 3'b000);
    int unsigned cycles;

    assert (beat_count > 0)
    else $fatal(1, "%s send_awchn called with beat_count=0", vip_name);

    apply_pause();

    cycles = 0;
    do begin
      vif.awid     <= id;
      vif.awaddr   <= addr;
      vif.awlen    <= LEN_WIDTH'(beat_count - 1);
      vif.awsize   <= size;
      vif.awburst  <= burst;
      vif.awprot   <= prot;
      vif.awcache  <= 4'b0000;
      vif.awlock   <= 1'b0;
      vif.awqos    <= 4'b0000;
      vif.awregion <= 4'b0000;
      vif.awuser   <= '0;
      vif.awvalid  <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4 write address handshake", vip_name);
      end
    end while (!(vif.awready));

    $display("[%0t] %s TX AW addr=%h beats=%0d id=%0d burst=%0d", $time, vip_name, addr,
             beat_count, id, burst);

    vif.awvalid <= 1'b0;
  endtask

  // Write Data Channel - Send write data phase
  task send_wchn(input logic [DATA_WIDTH-1:0] data[], input logic [STRB_WIDTH-1:0] strb[]);
    int unsigned beat_count;
    int unsigned beat_idx;
    int unsigned cycles;

    beat_count = data.size();
    assert (beat_count > 0)
    else $fatal(1, "%s send_wchn called with no data beats", vip_name);
    assert (strb.size() >= beat_count)
    else $fatal(1, "%s send_wchn strb array too short", vip_name);

    apply_pause();


    for (beat_idx = 0; beat_idx < beat_count; beat_idx++) begin
      cycles = 0;
      do begin
        cycles++;
        vif.wdata  <= data[beat_idx];
        vif.wstrb  <= strb[beat_idx];
        vif.wlast  <= (beat_idx == (beat_count - 1));
        vif.wuser  <= '0;
        vif.wvalid <= 1'b1;
        @(posedge vif.aclk);
        if (cycles >= timeout_cycles) begin
          $fatal(1, "%s timed out waiting for AXI4 write data handshakes", vip_name);
        end
      end while (!vif.wready);
    end

    vif.wvalid <= 1'b0;

    $display("[%0t] %s TX W beats=%0d", $time, vip_name, beat_count);
  endtask

  // Write Response Channel - Receive write response phase
  task recv_bchn(output logic [1:0] resp);
    int unsigned cycles;

    apply_pause();

    cycles = 0;
    do begin
      vif.bready <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4 write response", vip_name);
      end
    end while (!vif.bvalid);

    $display("[%0t] %s RX B bresp=%0h", $time, vip_name, resp);

    resp = vif.bresp;
    vif.bready <= 1'b0;
    // @(posedge vif.aclk);
  endtask

  task write_burst(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data[],
                   input logic [STRB_WIDTH-1:0] strb[], input logic [ID_WIDTH-1:0] id = '0,
                   input logic [SIZE_WIDTH-1:0] size = $clog2(STRB_WIDTH),
                   input logic [BURST_WIDTH-1:0] burst = 2'b01,
                   input logic [PROT_WIDTH-1:0] prot = 3'b000, output logic [1:0] resp);
    int unsigned beat_count;

    beat_count = data.size();
    assert (beat_count > 0)
    else $fatal(1, "%s write_burst called with no data beats", vip_name);
    assert (strb.size() >= beat_count)
    else $fatal(1, "%s write_burst strb array too short", vip_name);

    // Call the three channel APIs in sequence
    send_awchn(addr, beat_count, id, size, burst, prot);
    send_wchn(data, strb);
    recv_bchn(resp);
  endtask

  // Read transaction
  task read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data,
            output logic [1:0] resp, input logic [ID_WIDTH-1:0] id = '0,
            input logic [LEN_WIDTH-1:0] len = '0,  // Single beat
            input logic [SIZE_WIDTH-1:0] size = $clog2(STRB_WIDTH),
            input logic [BURST_WIDTH-1:0] burst = 2'b01,  // INCR
            input logic [PROT_WIDTH-1:0] prot = 3'b000);
    logic [DATA_WIDTH-1:0] burst_data[];
    logic [1:0] burst_resp[];
    begin
      burst_data = new[1];
      burst_resp = new[1];
      read_burst(addr, 1, burst_data, burst_resp, id, size, burst, prot);
      data = burst_data[0];
      resp = burst_resp[0];
    end
  endtask

  // Read Address Channel - Send read address phase
  task send_archn(
      input logic [ADDR_WIDTH-1:0] addr, input int unsigned beat_count = 1,
      input logic [ID_WIDTH-1:0] id = '0, input logic [SIZE_WIDTH-1:0] size = $clog2(STRB_WIDTH),
      input logic [BURST_WIDTH-1:0] burst = 2'b01, input logic [PROT_WIDTH-1:0] prot = 3'b000);
    int unsigned cycles;

    assert (beat_count > 0)
    else $fatal(1, "%s send_archn called with beat_count=0", vip_name);

    apply_pause();

    vif.arid     <= id;
    vif.araddr   <= addr;
    vif.arlen    <= LEN_WIDTH'(beat_count - 1);
    vif.arsize   <= size;
    vif.arburst  <= burst;
    vif.arprot   <= prot;
    vif.arcache  <= 4'b0000;
    vif.arlock   <= 1'b0;
    vif.arqos    <= 4'b0000;
    vif.arregion <= 4'b0000;
    vif.aruser   <= '0;
    vif.arvalid  <= 1'b1;

    cycles = 0;
    do begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI4 read address handshake", vip_name);
      end
    end while (!(vif.arready));

    vif.arvalid <= 1'b0;

    $display("[%0t] %s TX AR addr=%h beats=%0d id=%0d burst=%0d", $time, vip_name, addr,
             beat_count, id, burst);
  endtask

  // Read Data Channel - Receive read data phase
  task recv_rchn(ref logic [DATA_WIDTH-1:0] data[], ref logic [1:0] resp[],
                 input logic [ID_WIDTH-1:0] id = '0);
    int unsigned beat_count;
    int unsigned beat_idx;
    int unsigned cycles;

    beat_count = data.size();
    assert (beat_count > 0)
    else $fatal(1, "%s recv_rchn called with no data beats", vip_name);
    assert (resp.size() >= beat_count)
    else $fatal(1, "%s recv_rchn resp array too short", vip_name);

    apply_pause();

    vif.rready <= 1;
    for (beat_idx = 0; beat_idx < beat_count; beat_idx++) begin
      cycles = 0;
      do begin
        @(posedge vif.aclk);
        cycles++;
        if (cycles >= timeout_cycles) begin
          $fatal(1, "%s timed out waiting for AXI4 read data", vip_name);
        end
      end while (!vif.rvalid);
      data[beat_idx] = vif.rdata;
      resp[beat_idx] = vif.rresp;
      assert (vif.rid == id)
      else $error("%s read ID mismatch exp=%0d got=%0d", vip_name, id, vif.rid);
      assert (vif.rlast == (beat_idx == (beat_count - 1)))
      else $error("%s rlast mismatch beat=%0d beats=%0d", vip_name, beat_idx, beat_count);
    end

    $display("[%0t] %s RX R beats=%0d id=%0d", $time, vip_name, beat_count, id);

    vif.rready <= 0;
    // @(posedge vif.aclk);

  endtask

  task read_burst(
      input logic [ADDR_WIDTH-1:0] addr, input int unsigned beat_count,
      ref logic [DATA_WIDTH-1:0] data[], ref logic [1:0] resp[], input logic [ID_WIDTH-1:0] id = '0,
      input logic [SIZE_WIDTH-1:0] size = $clog2(STRB_WIDTH),
      input logic [BURST_WIDTH-1:0] burst = 2'b01, input logic [PROT_WIDTH-1:0] prot = 3'b000);

    assert (beat_count > 0)
    else $fatal(1, "%s read_burst called with no beats", vip_name);

    // Call the two channel APIs in sequence
    send_archn(addr, beat_count, id, size, burst, prot);
    recv_rchn(data, resp, id);
  endtask

endclass
