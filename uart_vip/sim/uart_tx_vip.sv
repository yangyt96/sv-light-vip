class UartTxVIP #(
  int CLKS_PER_BIT = 16,
  int DATA_BITS    = 8
);

  virtual uart_if.transmitter vif;
  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;

  function new(virtual uart_if.transmitter vif,
               string vip_name = "uart_tx_vip");
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

  task automatic idle();
    vif.tx = 1'b1;
  endtask

  task automatic apply_pause();
    int unsigned pause_cycles;
    begin
      while (!vif.rstn) @(posedge vif.clk);
      if (enable_pause_generator) begin
        pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
        repeat (pause_cycles) @(posedge vif.clk);
      end
    end
  endtask

  task automatic drive_bit(input bit bit_value);
    vif.tx = bit_value;
    repeat (CLKS_PER_BIT) @(posedge vif.clk);
  endtask

  // API: transmit one UART frame, 8N1 by default, LSB first.
  task transmit(input logic [DATA_BITS-1:0] data);
    apply_pause();
    @(posedge vif.clk);

    drive_bit(1'b0);
    for (int bit_idx = 0; bit_idx < DATA_BITS; bit_idx++) begin
      drive_bit(data[bit_idx]);
    end
    drive_bit(1'b1);

    $display("[%0t] %s TX data=%h", $time, vip_name, data);
  endtask

endclass
