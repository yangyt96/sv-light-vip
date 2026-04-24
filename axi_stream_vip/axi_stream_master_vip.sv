class AxiStreamMasterVIP #(
  int DATA_WIDTH = 32,
  int KEEP_WIDTH = DATA_WIDTH / 8
);

  // handle to the interface
  virtual axi_stream_if #(DATA_WIDTH, KEEP_WIDTH).master vif;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;

  // constructor
  function new(virtual axi_stream_if #(DATA_WIDTH, KEEP_WIDTH).master vif);
    this.vif = vif;
    enable_pause_generator = 1'b0;
    min_pause_cycles       = 0;
    max_pause_cycles       = 0;
  endfunction

  function void configure_pause_generator(bit enable,
                                          int unsigned min_cycles = 0,
                                          int unsigned max_cycles = 0);
    enable_pause_generator = enable;
    min_pause_cycles       = min_cycles;
    max_pause_cycles       = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  // API: push_axi_stream
  task push_axi_stream(logic [DATA_WIDTH-1:0] tdata,
                       logic [KEEP_WIDTH-1:0] tkeep,
                       logic [KEEP_WIDTH-1:0] tstrb,
                       bit                    tlast,
                       byte                   tid,
                       byte                   tdest,
                       int unsigned           tuser);
    int unsigned pause_cycles;

    while (!vif.aresetn) @(posedge vif.aclk);

    if (enable_pause_generator) begin
      pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
      repeat (pause_cycles) @(posedge vif.aclk);
    end

    // drive signals
    vif.tdata  <= tdata;
    vif.tkeep  <= tkeep;
    vif.tstrb  <= tstrb;
    vif.tlast  <= tlast;
    vif.tid    <= tid;
    vif.tdest  <= tdest;
    vif.tuser  <= tuser;

    // handshake
    vif.tvalid <= 1'b1;
    @(posedge vif.aclk);
    while (!vif.tready) @(posedge vif.aclk);
    vif.tvalid <= 1'b0;
  endtask

endclass
