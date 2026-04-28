// AXI4-Stream Slave VIP
// Provides recv_single (single beat) and recv_multi (multiple beats) APIs
// following the same send_*/recv_* channel API pattern as AXI4-Full/Lite VIPs.
//
// Architecture:
//   - recv_single() : Channel-level API - drive tready, wait for tvalid, capture signals
//   - recv_multi()   : High-level API - receives multiple beats via recv_single loop
//
// Backpressure architecture (following AXI4-Full Slave's pattern):
//   - apply_stall() is called ONLY in recv_multi(), NOT in recv_single()
//   - This mirrors Master's apply_pause() placement in high-level tasks only

class Axi4StreamSlaveVIP #(
    int DATA_WIDTH  = 32,
    int KEEP_WIDTH  = DATA_WIDTH / 8,
    int TID_WIDTH   = 8,
    int TDEST_WIDTH = 8,
    int TUSER_WIDTH = 32
);

  // handle to the interface
  virtual axi4_stream_if #(DATA_WIDTH, KEEP_WIDTH, TID_WIDTH, TDEST_WIDTH, TUSER_WIDTH).slave vif;
  string vip_name;
  bit enable_backpressure;
  int unsigned min_stall_cycles;
  int unsigned max_stall_cycles;
  int unsigned timeout_cycles;

  // constructor
  function new(
      virtual axi4_stream_if #(DATA_WIDTH, KEEP_WIDTH, TID_WIDTH, TDEST_WIDTH, TUSER_WIDTH).slave vif,
      string vip_name = "axi4_stream_slave_vip");
    this.vif            = vif;
    this.vip_name       = vip_name;
    enable_backpressure = 1'b0;
    min_stall_cycles    = 0;
    max_stall_cycles    = 0;
    timeout_cycles      = 1000;
  endfunction

  function void configure_backpressure(bit enable, int unsigned min_cycles = 0,
                                       int unsigned max_cycles = 0);
    enable_backpressure = enable;
    min_stall_cycles    = min_cycles;
    max_stall_cycles    = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  task automatic wait_reset_release();
    int unsigned cycles;
    cycles = 0;
    while (!vif.aresetn) begin
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for AXI-Stream reset release", vip_name);
      end
    end
  endtask

  // Clear all slave output signals to default state
  // Must be called after reset release before starting transactions
  task automatic clear_outputs();
    vif.tready <= 1'b0;
  endtask

  // Channel-level API: receive single beat
  // Drives tready, waits for tvalid handshake, captures all signals
  // Does NOT call apply_stall() - that is reserved for high-level tasks
  task automatic recv_single(
      output logic [DATA_WIDTH-1:0] tdata, output logic [KEEP_WIDTH-1:0] tkeep,
      output logic [KEEP_WIDTH-1:0] tstrb, output bit tlast, output logic [TID_WIDTH-1:0] tid,
      output logic [TDEST_WIDTH-1:0] tdest, output logic [TUSER_WIDTH-1:0] tuser);
    int unsigned cycles;

    wait_reset_release();

    cycles = 0;
    do begin
      vif.tready <= 1'b1;
      @(posedge vif.aclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for TVALID", vip_name);
      end
    end while (!(vif.tvalid && vif.tready));

    // capture signals
    tdata = vif.tdata;
    tkeep = vif.tkeep;
    tstrb = vif.tstrb;
    tlast = vif.tlast;
    tid   = vif.tid;
    tdest = vif.tdest;
    tuser = vif.tuser;
    $display("[%0t] %s RX tdata=%h tkeep=%h tstrb=%h tlast=%0b tid=%0h tdest=%0h tuser=%0h", $time,
             vip_name, tdata, tkeep, tstrb, tlast, tid, tdest, tuser);

    vif.tready <= 1'b0;
  endtask

  // High-level API: receive multi-beat burst until tlast is seen
  // Calls apply_stall() between beats when backpressure is enabled
  task automatic recv_multi(ref logic [DATA_WIDTH-1:0] tdata[], ref logic [KEEP_WIDTH-1:0] tkeep[],
                            ref logic [KEEP_WIDTH-1:0] tstrb[], ref bit tlast[],
                            ref logic [TID_WIDTH-1:0] tid[], ref logic [TDEST_WIDTH-1:0] tdest[],
                            ref logic [TUSER_WIDTH-1:0] tuser[]);
    int unsigned beat_idx;
    int unsigned max_beats;

    max_beats = tdata.size();
    assert (max_beats > 0)
    else $fatal(1, "%s recv_multi called with no data beats", vip_name);
    assert (tkeep.size() >= max_beats)
    else $fatal(1, "%s recv_multi tkeep array too short", vip_name);
    assert (tstrb.size() >= max_beats)
    else $fatal(1, "%s recv_multi tstrb array too short", vip_name);
    assert (tlast.size() >= max_beats)
    else $fatal(1, "%s recv_multi tlast array too short", vip_name);
    assert (tid.size() >= max_beats)
    else $fatal(1, "%s recv_multi tid array too short", vip_name);
    assert (tdest.size() >= max_beats)
    else $fatal(1, "%s recv_multi tdest array too short", vip_name);
    assert (tuser.size() >= max_beats)
    else $fatal(1, "%s recv_multi tuser array too short", vip_name);

    beat_idx = 0;
    do begin
      // apply stall between beats (not before first beat)
      if (enable_backpressure && beat_idx > 0) begin
        apply_stall();
      end
      recv_single(tdata[beat_idx], tkeep[beat_idx], tstrb[beat_idx], tlast[beat_idx], tid[beat_idx],
                  tdest[beat_idx], tuser[beat_idx]);
      beat_idx++;
      if (beat_idx > max_beats) begin
        $fatal(1, "%s recv_multi exceeded max_beats=%0d without seeing tlast", vip_name, max_beats);
      end
    end while (!tlast[beat_idx-1]);
  endtask

  // Internal: apply random stall cycles (used only in high-level tasks)
  task automatic apply_stall();
    int unsigned stall_cycles;
    stall_cycles = $urandom_range(max_stall_cycles, min_stall_cycles);
    repeat (stall_cycles) @(posedge vif.aclk);
  endtask

endclass
