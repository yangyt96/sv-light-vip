class I2STxVIP #(
    int SAMPLE_WIDTH = 16,
    int HALF_BCLK_CYCLES = 4
);

  virtual i2s_if.transmitter vif;
  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;
  int unsigned timeout_cycles;

  function new(virtual i2s_if.transmitter vif, string vip_name = "i2s_tx_vip");
    assert (SAMPLE_WIDTH > 0)
    else $error("[%s] SAMPLE_WIDTH=%0d must be > 0", vip_name, SAMPLE_WIDTH);
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

  // Clear all transmitter output signals to default state
  task automatic clear_outputs();
    vif.bclk <= 1'b0;
    vif.ws   <= 1'b0;
    vif.sd   <= 1'b0;
  endtask

  task automatic idle();
    vif.bclk <= 1'b0;
    vif.ws   <= 1'b0;
    vif.sd   <= 1'b0;
  endtask

  task automatic wait_half_bclk();
    repeat (HALF_BCLK_CYCLES) @(posedge vif.clk);
  endtask

  task automatic drive_bit(input bit value);
    vif.sd <= value;
    wait_half_bclk();
    vif.bclk <= 1'b1;
    wait_half_bclk();
    vif.bclk <= 1'b0;
  endtask

  // API: transmit one stereo I2S frame, MSB first.
  // WS=0 is left, WS=1 is right. Each channel has one lead bit before the MSB.
  task automatic transmit(input logic [SAMPLE_WIDTH-1:0] left_sample,
                          input logic [SAMPLE_WIDTH-1:0] right_sample);
    int unsigned cycles;
    int unsigned pause_cycles;

    cycles = 0;
    while (!vif.rstn) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for I2S reset release", vip_name);
      end
    end
    @(posedge vif.clk);

    vif.ws <= 1'b0;
    drive_bit(1'b0);
    for (int bit_idx = SAMPLE_WIDTH - 1; bit_idx >= 0; bit_idx--) begin
      drive_bit(left_sample[bit_idx]);
      // Optional pause between bits
      if (enable_pause_generator && bit_idx > 0) begin
        pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
        repeat (pause_cycles) @(posedge vif.clk);
      end
    end

    vif.ws <= 1'b1;
    drive_bit(1'b0);
    for (int bit_idx = SAMPLE_WIDTH - 1; bit_idx >= 0; bit_idx--) begin
      drive_bit(right_sample[bit_idx]);
      // Optional pause between bits
      if (enable_pause_generator && bit_idx > 0) begin
        pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
        repeat (pause_cycles) @(posedge vif.clk);
      end
    end

    vif.ws <= 1'b0;
    vif.sd <= 1'b0;

    $display("[%0t] %s TX left=%h right=%h", $time, vip_name, left_sample, right_sample);
  endtask

endclass
