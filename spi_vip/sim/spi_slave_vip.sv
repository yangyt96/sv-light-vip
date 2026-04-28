class SpiSlaveVIP #(
    int DATA_BITS = 8
);

  virtual spi_if.slave vif;
  string vip_name;
  int unsigned timeout_cycles;
  bit cpol;
  bit cpha;

  function new(virtual spi_if.slave vif, string vip_name = "spi_slave_vip");
    assert (DATA_BITS > 0)
    else $error("[%s] DATA_BITS=%0d must be > 0", vip_name, DATA_BITS);
    this.vif       = vif;
    this.vip_name  = vip_name;
    timeout_cycles = 3000;
    cpol           = 1'b0;
    cpha           = 1'b0;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  function void configure_mode(input bit cpol, input bit cpha);
    this.cpol = cpol;
    this.cpha = cpha;
  endfunction

  task automatic idle();
    vif.miso <= 1'b0;
  endtask

  // Wait for the clock edge where data is sampled (MOSI read by slave).
  // When cpol == cpha: sample on rising edge; when cpol != cpha: sample on falling edge.
  task automatic wait_sample_edge();
    if (cpol == cpha) begin
      @(posedge vif.sclk);
    end else begin
      @(negedge vif.sclk);
    end
  endtask

  // Wait for the clock edge where data is shifted out (MISO driven by slave).
  // When cpol == cpha: shift on falling edge; when cpol != cpha: shift on rising edge.
  task automatic wait_shift_edge();
    if (cpol == cpha) begin
      @(negedge vif.sclk);
    end else begin
      @(posedge vif.sclk);
    end
  endtask

  // API: full-duplex SPI transfer, MSB first.
  // Supports all 4 SPI modes based on configured CPOL/CPHA.
  //   Mode 0: CPOL=0, CPHA=0 - SCLK idle low,  sample on rising  edge, shift on falling edge
  //   Mode 1: CPOL=0, CPHA=1 - SCLK idle low,  sample on falling edge, shift on rising  edge
  //   Mode 2: CPOL=1, CPHA=0 - SCLK idle high, sample on falling edge, shift on rising  edge
  //   Mode 3: CPOL=1, CPHA=1 - SCLK idle high, sample on rising  edge, shift on falling edge
  task automatic transfer(input logic [DATA_BITS-1:0] tx_data,
                          output logic [DATA_BITS-1:0] rx_data);
    int unsigned cycles;

    rx_data = '0;

    cycles  = 0;
    while (!vif.rstn) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for SPI reset release", vip_name);
      end
    end
    cycles = 0;
    while (vif.cs_n !== 1'b1) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for SPI idle", vip_name);
      end
    end
    cycles = 0;
    while (vif.cs_n !== 1'b0) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for SPI chip-select", vip_name);
      end
    end

    if (cpha == 1'b0) begin
      // CPHA=0: output first data bit before first clock edge
      vif.miso <= tx_data[DATA_BITS-1];

      for (int bit_idx = DATA_BITS - 1; bit_idx >= 0; bit_idx--) begin
        wait_sample_edge();
        rx_data[bit_idx] = vif.mosi;

        if (bit_idx > 0) begin
          wait_shift_edge();
          vif.miso <= tx_data[bit_idx-1];
        end
      end
    end else begin
      // CPHA=1: shift out data on first edge, sample on second edge
      for (int bit_idx = DATA_BITS - 1; bit_idx >= 0; bit_idx--) begin
        if (bit_idx < (DATA_BITS - 1)) begin
          wait_shift_edge();
        end
        vif.miso <= tx_data[bit_idx];

        wait_sample_edge();
        rx_data[bit_idx] = vif.mosi;
      end
    end

    @(posedge vif.cs_n);
    vif.miso <= 1'b0;

    $display("[%0t] %s TX=%h RX=%h (CPOL=%0b CPHA=%0b)", $time, vip_name, tx_data, rx_data, cpol,
             cpha);
  endtask

endclass
