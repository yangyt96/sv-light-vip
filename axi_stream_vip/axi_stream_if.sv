interface axi_stream_if #(parameter data_width = 32,
                          parameter keep_width = data_width/8)
                         (input logic aclk,
                          input logic aresetn);

  // core signals
  logic [data_width-1:0] tdata;
  logic                  tvalid;
  logic                  tready;

  // optional signals
  logic [keep_width-1:0] tkeep;   // byte qualifiers
  logic [keep_width-1:0] tstrb;   // byte strobes
  logic                  tlast;   // end of packet/frame
  logic [7:0]            tid;     // stream id
  logic [7:0]            tdest;   // destination routing
  logic [31:0]           tuser;   // user-defined sideband

  // modports for direction control
  modport master (input  tready,
                  output tvalid, tdata, tkeep, tstrb, tlast, tid, tdest, tuser);

  modport slave  (input  tvalid, tdata, tkeep, tstrb, tlast, tid, tdest, tuser,
                  output tready);

endinterface
