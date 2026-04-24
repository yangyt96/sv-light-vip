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

  function new(
    virtual axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH).master vif,
    string vip_name = "axi4_lite_master_vip"
  );
    this.vif = vif;
    this.vip_name = vip_name;
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

  task automatic apply_pause();
    int unsigned pause_cycles;
    begin
      while (!vif.aresetn) @(posedge vif.aclk);
      if (enable_pause_generator) begin
        pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
        repeat (pause_cycles) @(posedge vif.aclk);
      end
    end
  endtask

  task write(input  logic [ADDR_WIDTH-1:0] addr,
             input  logic [DATA_WIDTH-1:0] data,
             input  logic [STRB_WIDTH-1:0] strb,
             output logic [1:0]            resp,
             input  logic [2:0]            prot = 3'b000);
    bit aw_done;
    bit w_done;

    apply_pause();

    vif.awaddr  = addr;
    vif.awprot  = prot;
    vif.awvalid = 1'b1;
    vif.wdata   = data;
    vif.wstrb   = strb;
    vif.wvalid  = 1'b1;
    vif.bready  = 1'b1;

    aw_done = 1'b0;
    w_done  = 1'b0;

    while (!(aw_done && w_done)) begin
      @(posedge vif.aclk);

      if (!aw_done && vif.awvalid && vif.awready) begin
        aw_done      = 1'b1;
        vif.awvalid  = 1'b0;
      end

      if (!w_done && vif.wvalid && vif.wready) begin
        w_done      = 1'b1;
        vif.wvalid  = 1'b0;
      end
    end

    do begin
      @(posedge vif.aclk);
    end while (!(vif.bvalid && vif.bready));

    resp = vif.bresp;
    $display("[%0t] %s TX WRITE addr=%h data=%h strb=%h prot=%0h bresp=%0h",
             $time, vip_name, addr, data, strb, prot, resp);
    vif.bready = 1'b0;
  endtask

  task read(input  logic [ADDR_WIDTH-1:0] addr,
            output logic [DATA_WIDTH-1:0] data,
            output logic [1:0]            resp,
            input  logic [2:0]            prot = 3'b000);
    apply_pause();

    vif.araddr  = addr;
    vif.arprot  = prot;
    vif.arvalid = 1'b1;
    vif.rready  = 1'b1;

    do begin
      @(posedge vif.aclk);
      if (vif.arvalid && vif.arready) begin
        vif.arvalid = 1'b0;
      end
    end while (!(vif.rvalid && vif.rready));

    data = vif.rdata;
    resp = vif.rresp;
    $display("[%0t] %s RX READ  addr=%h data=%h prot=%0h rresp=%0h",
             $time, vip_name, addr, data, prot, resp);
    vif.rready = 1'b0;
  endtask

endclass
