class UartRxVIP #(
  int CLKS_PER_BIT = 16,
  int DATA_BITS    = 8
);

  virtual uart_if.receiver vif;
  string vip_name;

  function new(virtual uart_if.receiver vif,
               string vip_name = "uart_rx_vip");
    this.vif = vif;
    this.vip_name = vip_name;
  endfunction

  task automatic wait_clocks(input int unsigned cycles);
    repeat (cycles) @(posedge vif.clk);
  endtask

  // API: receive one UART frame, 8N1 by default, LSB first.
  task receive(output logic [DATA_BITS-1:0] data,
               output bit framing_error);
    data = '0;
    framing_error = 1'b0;

    while (!vif.rstn) @(posedge vif.clk);

    while (vif.tx !== 1'b1) @(posedge vif.clk);
    @(negedge vif.tx);

    wait_clocks(CLKS_PER_BIT / 2);
    if (vif.tx !== 1'b0) begin
      framing_error = 1'b1;
    end

    for (int bit_idx = 0; bit_idx < DATA_BITS; bit_idx++) begin
      wait_clocks(CLKS_PER_BIT);
      data[bit_idx] = vif.tx;
    end

    wait_clocks(CLKS_PER_BIT);
    if (vif.tx !== 1'b1) begin
      framing_error = 1'b1;
    end

    $display("[%0t] %s RX data=%h framing_error=%0b",
             $time, vip_name, data, framing_error);
  endtask

endclass
