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

  function new(
    virtual axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH).slave vif,
    string vip_name = "axi4_lite_slave_vip"
  );
    this.vif = vif;
    this.vip_name = vip_name;
    enable_backpressure = 1'b0;
    min_stall_cycles    = 0;
    max_stall_cycles    = 0;
  endfunction

  function void configure_backpressure(bit enable,
                                       int unsigned min_cycles = 0,
                                       int unsigned max_cycles = 0);
    enable_backpressure = enable;
    min_stall_cycles    = min_cycles;
    max_stall_cycles    = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  task automatic apply_stall();
    int unsigned stall_cycles;
    begin
      if (enable_backpressure) begin
        stall_cycles = $urandom_range(max_stall_cycles, min_stall_cycles);
        repeat (stall_cycles) @(posedge vif.aclk);
      end
    end
  endtask

  task handle_write(output logic [ADDR_WIDTH-1:0] addr,
                    output logic [DATA_WIDTH-1:0] data,
                    output logic [STRB_WIDTH-1:0] strb,
                    output logic [2:0]            prot,
                    input  logic [1:0]            resp = 2'b00);
    bit aw_done;
    bit w_done;

    while (!vif.aresetn) @(posedge vif.aclk);

    vif.awready = 1'b0;
    vif.wready  = 1'b0;
    vif.bresp   = resp;
    vif.bvalid  = 1'b0;

    apply_stall();

    vif.awready = 1'b1;
    vif.wready  = 1'b1;

    aw_done = 1'b0;
    w_done  = 1'b0;

    while (!(aw_done && w_done)) begin
      @(posedge vif.aclk);

      if (!aw_done && vif.awvalid && vif.awready) begin
        addr       = vif.awaddr;
        prot       = vif.awprot;
        aw_done    = 1'b1;
        vif.awready = 1'b0;
      end

      if (!w_done && vif.wvalid && vif.wready) begin
        data      = vif.wdata;
        strb      = vif.wstrb;
        w_done    = 1'b1;
        vif.wready = 1'b0;
      end
    end

    apply_stall();

    vif.bresp  = resp;
    vif.bvalid = 1'b1;
    do begin
      @(posedge vif.aclk);
    end while (!(vif.bvalid && vif.bready));
    $display("[%0t] %s RX WRITE addr=%h data=%h strb=%h prot=%0h bresp=%0h",
             $time, vip_name, addr, data, strb, prot, resp);
    vif.bvalid = 1'b0;
  endtask

  task handle_read(output logic [ADDR_WIDTH-1:0] addr,
                   output logic [2:0]            prot,
                   input  logic [DATA_WIDTH-1:0] data,
                   input  logic [1:0]            resp = 2'b00);
    while (!vif.aresetn) @(posedge vif.aclk);

    vif.arready = 1'b0;
    vif.rdata   = data;
    vif.rresp   = resp;
    vif.rvalid  = 1'b0;

    apply_stall();

    vif.arready = 1'b1;
    do begin
      @(posedge vif.aclk);
    end while (!(vif.arvalid && vif.arready));

    addr       = vif.araddr;
    prot       = vif.arprot;
    vif.arready = 1'b0;

    apply_stall();

    vif.rdata  = data;
    vif.rresp  = resp;
    vif.rvalid = 1'b1;
    do begin
      @(posedge vif.aclk);
    end while (!(vif.rvalid && vif.rready));
    $display("[%0t] %s TX READ  addr=%h data=%h prot=%0h rresp=%0h",
             $time, vip_name, addr, data, prot, resp);
    vif.rvalid = 1'b0;
  endtask

endclass
