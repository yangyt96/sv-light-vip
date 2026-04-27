class I2SRxVIP #(
    int SAMPLE_WIDTH = 16
);

  virtual i2s_if.receiver vif;
  string vip_name;
  int unsigned timeout_cycles;

  function new(virtual i2s_if.receiver vif, string vip_name = "i2s_rx_vip");
    this.vif       = vif;
    this.vip_name  = vip_name;
    timeout_cycles = 1000;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  // API: receive one stereo I2S frame, MSB first.
  task automatic receive(output logic [SAMPLE_WIDTH-1:0] left_sample,
                         output logic [SAMPLE_WIDTH-1:0] right_sample, output bit frame_error);
    left_sample  = '0;
    right_sample = '0;
    frame_error  = 1'b0;

    begin
      int unsigned cycles;
      cycles = 0;
      while (!vif.rstn) begin
        @(posedge vif.clk);
        cycles++;
        if (cycles >= timeout_cycles) begin
          $fatal(1, "%s timed out waiting for I2S reset release", vip_name);
        end
      end
      cycles = 0;
      while (!(vif.bclk === 1'b0 && vif.ws === 1'b0)) begin
        @(posedge vif.clk);
        cycles++;
        if (cycles >= timeout_cycles) begin
          $fatal(1, "%s timed out waiting for I2S frame idle", vip_name);
        end
      end
    end

    @(posedge vif.bclk);
    if (vif.ws !== 1'b0) begin
      frame_error = 1'b1;
    end

    for (int bit_idx = SAMPLE_WIDTH - 1; bit_idx >= 0; bit_idx--) begin
      @(posedge vif.bclk);
      if (vif.ws !== 1'b0) begin
        frame_error = 1'b1;
      end
      left_sample[bit_idx] = vif.sd;
    end

    @(posedge vif.bclk);
    if (vif.ws !== 1'b1) begin
      frame_error = 1'b1;
    end

    for (int bit_idx = SAMPLE_WIDTH - 1; bit_idx >= 0; bit_idx--) begin
      @(posedge vif.bclk);
      if (vif.ws !== 1'b1) begin
        frame_error = 1'b1;
      end
      right_sample[bit_idx] = vif.sd;
    end

    $display("[%0t] %s RX left=%h right=%h frame_error=%0b", $time, vip_name, left_sample,
             right_sample, frame_error);
  endtask

endclass
