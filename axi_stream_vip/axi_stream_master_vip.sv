class AxiStreamMasterVIP;

  // handle to the interface
  virtual axi_stream_if.master vif;

  // constructor
  function new(virtual axi_stream_if.master vif);
    this.vif = vif;
  endfunction

  // API: push_axi_stream
  task push_axi_stream(logic [vif.data_width-1:0] tdata,
                       logic [vif.keep_width-1:0] tkeep,
                       logic [vif.keep_width-1:0] tstrb,
                       bit                        tlast,
                       byte                       tid,
                       byte                       tdest,
                       int unsigned               tuser);
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
