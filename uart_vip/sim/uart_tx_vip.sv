class UartTxVIP #(
    int CLKS_PER_BIT = 16,
    int DATA_BITS    = 8
);

  virtual uart_if.transmitter vif;
  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;
  int unsigned timeout_cycles;
  // Parity configuration: 0=none, 1=odd, 2=even
  int unsigned parity_mode;

  function new(virtual uart_if.transmitter vif, string vip_name = "uart_tx_vip");
    this.vif               = vif;
    this.vip_name          = vip_name;
    enable_pause_generator = 1'b0;
    min_pause_cycles       = 0;
    max_pause_cycles       = 0;
    timeout_cycles         = 3000;
    parity_mode            = 0;
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

  // Configure parity: 0=none, 1=odd, 2=even
  function void configure_parity(int unsigned mode);
    if (mode > 2) begin
      $error("%s invalid parity mode %0d (0=none, 1=odd, 2=even)", vip_name, mode);
    end else begin
      parity_mode = mode;
    end
  endfunction

  // Compute parity bit: 1=odd, 2=even
  function automatic bit compute_parity(input logic [DATA_BITS-1:0] data);
    if (parity_mode == 1) begin
      return ~(^data);  // odd parity
    end else begin
      return ^data;  // even parity
    end
  endfunction

  task automatic idle();
    vif.serial_data = 1'b1;
  endtask

  task automatic drive_bit(input bit bit_value);
    vif.serial_data = bit_value;
    repeat (CLKS_PER_BIT) @(posedge vif.clk);
  endtask

  // API: transmit one UART frame, 8N1 by default, LSB first.
  task transmit(input logic [DATA_BITS-1:0] data);
    int unsigned cycles;
    int unsigned pause_cycles;

    cycles = 0;
    while (!vif.rstn) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for UART reset release", vip_name);
      end
    end
    @(posedge vif.clk);

    // Start bit
    drive_bit(1'b0);

    // Data bits (LSB first)
    for (int bit_idx = 0; bit_idx < DATA_BITS; bit_idx++) begin
      drive_bit(data[bit_idx]);
      // Optional pause between bits
      if (enable_pause_generator && bit_idx < DATA_BITS - 1) begin
        pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
        repeat (pause_cycles) @(posedge vif.clk);
      end
    end

    // Parity bit (if enabled)
    if (parity_mode > 0) begin
      drive_bit(compute_parity(data));
    end

    // Stop bit
    drive_bit(1'b1);

    $display("[%0t] %s TX data=%h parity=%0d", $time, vip_name, data, parity_mode);
  endtask

endclass
