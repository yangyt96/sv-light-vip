class AxiStreamSlaveVIP;

  // handle to the interface
  virtual axi_stream_if.slave vif;

  // constructor
  function new(virtual axi_stream_if.slave vif);
    this.vif = vif;
  endfunction

  // API: pop_axi_stream
  task pop_axi_stream(output logic [vif.data_width-1:0] tdata,
                      output logic [vif.keep_width-1:0] tkeep,
                      output logic [vif.keep_width-1:0] tstrb,
                      output bit                       tlast,
                      output byte                      tid,
                      output byte                      tdest,
                      output int unsigned              tuser);
    // ready to accept data
    vif.tready <= 1'b1;

    // wait for valid data
    @(posedge vif.aclk);
    while (!vif.tvalid) @(posedge vif.aclk);

    // capture signals
    tdata = vif.tdata;
    tkeep = vif.tkeep;
    tstrb = vif.tstrb;
    tlast = vif.tlast;
    tid   = vif.tid;
    tdest = vif.tdest;
    tuser = vif.tuser;

    // handshake complete
    @(posedge vif.aclk);
    vif.tready <= 1'b0;
  endtask

endclass
