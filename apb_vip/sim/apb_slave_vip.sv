class ApbSlaveVIP #(
    int ADDR_WIDTH = 16,
    int DATA_WIDTH = 32,
    int STRB_WIDTH = DATA_WIDTH / 8,
    int PROT_WIDTH = 3
);

  virtual apb_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH, PROT_WIDTH).slave vif;
  string vip_name;
  int unsigned ready_delay_cycles;
  int unsigned timeout_cycles;

  function new(virtual apb_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH, PROT_WIDTH).slave vif,
               string vip_name = "apb_slave_vip");
    this.vif = vif;
    this.vip_name = vip_name;
    ready_delay_cycles = 0;
    timeout_cycles = 1000;
  endfunction

  function void configure_ready_delay(int unsigned cycles);
    ready_delay_cycles = cycles;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  task automatic wait_reset_release();
    int unsigned cycles;
    cycles = 0;
    while (!vif.presetn) begin
      @(posedge vif.pclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for APB reset release", vip_name);
      end
    end
  endtask

  task automatic idle();
    vif.prdata  = '0;
    vif.pready  = 1'b0;
    vif.pslverr = 1'b0;
  endtask

  task automatic wait_access(input bit expect_write);
    int unsigned cycles;

    wait_reset_release();
    cycles = 0;
    do begin
      @(posedge vif.pclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for APB %s access", vip_name,
               expect_write ? "write" : "read");
      end
    end while (!(vif.psel && vif.penable && (vif.pwrite == expect_write)));
  endtask

  task automatic expect_write(output logic [ADDR_WIDTH-1:0] addr,
                              output logic [DATA_WIDTH-1:0] data,
                              output logic [STRB_WIDTH-1:0] strb,
                              output logic [PROT_WIDTH-1:0] prot, input bit slverr = 1'b0);
    wait_access(1'b1);
    addr = vif.paddr;
    data = vif.pwdata;
    strb = vif.pstrb;
    prot = vif.pprot;

    repeat (ready_delay_cycles) @(posedge vif.pclk);
    vif.pslverr = slverr;
    vif.pready  = 1'b1;
    @(posedge vif.pclk);
    @(negedge vif.pclk);
    vif.pready  = 1'b0;
    vif.pslverr = 1'b0;

    $display("[%0t] %s WRITE addr=%h data=%h strb=%h slverr=%0b", $time, vip_name, addr, data,
             strb, slverr);
  endtask

  task automatic respond_read(input logic [DATA_WIDTH-1:0] read_data,
                              output logic [ADDR_WIDTH-1:0] addr,
                              output logic [PROT_WIDTH-1:0] prot, input bit slverr = 1'b0);
    wait_access(1'b0);
    addr = vif.paddr;
    prot = vif.pprot;

    repeat (ready_delay_cycles) @(posedge vif.pclk);
    vif.prdata  = read_data;
    vif.pslverr = slverr;
    vif.pready  = 1'b1;
    @(posedge vif.pclk);
    @(negedge vif.pclk);
    vif.pready  = 1'b0;
    vif.pslverr = 1'b0;
    vif.prdata  = '0;

    $display("[%0t] %s READ  addr=%h data=%h slverr=%0b", $time, vip_name, addr, read_data, slverr);
  endtask

endclass
