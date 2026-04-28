class ApbMasterVIP #(
    int ADDR_WIDTH = 16,
    int DATA_WIDTH = 32,
    int STRB_WIDTH = DATA_WIDTH / 8,
    int PROT_WIDTH = 3
);

  virtual apb_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH, PROT_WIDTH).master vif;
  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;
  int unsigned timeout_cycles;

  function new(virtual apb_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH, PROT_WIDTH).master vif,
               string vip_name = "apb_master_vip");
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

  // Clear all master output signals to default state
  task automatic clear_outputs();
    vif.paddr   <= '0;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.pwdata  <= '0;
    vif.pstrb   <= '0;
    vif.pprot   <= '0;
  endtask

  // Apply random pause only (no reset wait — call wait_reset_release() separately)
  task automatic apply_pause();
    int unsigned pause_cycles;
    if (enable_pause_generator) begin
      pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
      repeat (pause_cycles) @(posedge vif.pclk);
    end
  endtask

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

  task automatic wait_ready();
    int unsigned cycles;
    cycles = 0;
    do begin
      @(posedge vif.pclk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for PREADY", vip_name);
      end
    end while (!vif.pready);
  endtask

  task automatic idle();
    vif.paddr   <= '0;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.pwdata  <= '0;
    vif.pstrb   <= '0;
    vif.pprot   <= '0;
  endtask

  task automatic write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                       input logic [STRB_WIDTH-1:0] strb = '1, output bit slverr,
                       input logic [PROT_WIDTH-1:0] prot = '0);
    wait_reset_release();
    apply_pause();

    vif.paddr   <= addr;
    vif.pwrite  <= 1'b1;
    vif.pwdata  <= data;
    vif.pstrb   <= strb;
    vif.pprot   <= prot;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;

    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    wait_ready();

    slverr = vif.pslverr;
    $display("[%0t] %s WRITE addr=%h data=%h strb=%h slverr=%0b", $time, vip_name, addr, data,
             strb, slverr);

    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.pstrb   <= '0;
  endtask

  task automatic read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data,
                      output bit slverr, input logic [PROT_WIDTH-1:0] prot = '0);
    wait_reset_release();
    apply_pause();

    vif.paddr   <= addr;
    vif.pwrite  <= 1'b0;
    vif.pwdata  <= '0;
    vif.pstrb   <= '0;
    vif.pprot   <= prot;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;

    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    wait_ready();

    data   = vif.prdata;
    slverr = vif.pslverr;
    $display("[%0t] %s READ  addr=%h data=%h slverr=%0b", $time, vip_name, addr, data, slverr);

    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask

endclass
