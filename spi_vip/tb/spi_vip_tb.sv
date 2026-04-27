`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "spi_if.sv"
`include "spi_vip_pkg.sv"

module spi_vip_tb;

  import vunit_pkg::*;
  import spi_vip_pkg::*;

  localparam bit TEST_CPOL = 0;
  localparam bit TEST_CPHA = 0;

  localparam int DATA_BITS                  = 8;
  localparam int HALF_SCLK_CYCLES           = 4;
  localparam int STIMULUS_COUNT             = 56;
  localparam int CONTINUOUS_TRANSFER_COUNT  = 48;
  localparam time INTER_TRANSACTION_PAUSE   = 10us;

  logic clk;
  logic rstn;

  spi_if spi_link(clk, rstn);

  SpiMasterVIP #(DATA_BITS, HALF_SCLK_CYCLES) master_vip;
  SpiSlaveVIP  #(DATA_BITS)                   slave_vip;

  function automatic logic [DATA_BITS-1:0] build_master_data(input int unsigned index);
    return DATA_BITS'((index * 8'h31) ^ 8'h5A);
  endfunction

  function automatic logic [DATA_BITS-1:0] build_slave_data(input int unsigned index);
    return DATA_BITS'((index * 8'h17) ^ 8'hC3);
  endfunction

  task automatic run_transfer(input int unsigned index);
    logic [DATA_BITS-1:0] master_tx;
    logic [DATA_BITS-1:0] slave_tx;
    logic [DATA_BITS-1:0] master_rx;
    logic [DATA_BITS-1:0] slave_rx;

    master_tx = build_master_data(index);
    slave_tx  = build_slave_data(index);

    fork
      master_vip.transfer(master_tx, master_rx);
      slave_vip.transfer(slave_tx, slave_rx);
    join

    assert(master_rx == slave_tx)
      else $error("SPI master RX mismatch at stimulus %0d exp=%h got=%h",
                  index, slave_tx, master_rx);
    assert(slave_rx == master_tx)
      else $error("SPI slave RX mismatch at stimulus %0d exp=%h got=%h",
                  index, master_tx, slave_rx);

    #(INTER_TRANSACTION_PAUSE);
  endtask

  task automatic drive_master(input int unsigned start_index,
                              input int unsigned transfer_count);
    logic [DATA_BITS-1:0] rx_data;

    for (int unsigned idx = start_index; idx < (start_index + transfer_count); idx++) begin
      master_vip.transfer(build_master_data(idx), rx_data);
      assert(rx_data == build_slave_data(idx))
        else $error("SPI continuous master RX mismatch at stimulus %0d exp=%h got=%h",
                    idx, build_slave_data(idx), rx_data);
      #(INTER_TRANSACTION_PAUSE);
    end
  endtask

  task automatic monitor_slave(input int unsigned start_index,
                               input int unsigned transfer_count,
                               output int unsigned observed_count);
    logic [DATA_BITS-1:0] rx_data;

    observed_count = 0;
    for (int unsigned idx = start_index; idx < (start_index + transfer_count); idx++) begin
      slave_vip.transfer(build_slave_data(idx), rx_data);
      observed_count++;
      assert(rx_data == build_master_data(idx))
        else $error("SPI continuous slave RX mismatch at stimulus %0d exp=%h got=%h",
                    idx, build_master_data(idx), rx_data);
    end
  endtask

  // Test: CS de-asserted mid-transfer (abnormal condition)
  // Master starts a transfer but de-asserts CS before all bits are clocked.
  // The slave should detect CS going high and abort.
  task automatic run_cs_abort();
    logic [DATA_BITS-1:0] master_tx;
    logic [DATA_BITS-1:0] slave_tx;
    logic [DATA_BITS-1:0] master_rx;
    logic [DATA_BITS-1:0] slave_rx;
    bit slave_aborted;

    master_tx = 8'hA5;
    slave_tx  = 8'h5A;

    fork
      // Master: start transfer but force CS high after a few bits
      begin
        int unsigned cycles;
        cycles = 0;
        while (!rstn) begin
          @(posedge clk);
          cycles++;
          if (cycles >= 10000) $fatal(1, "master timeout waiting for reset release");
        end
        @(posedge clk);

        spi_link.cs_n = 1'b0;

        // Drive only 4 bits (half a frame), then abort
        for (int bit_idx = DATA_BITS - 1; bit_idx >= DATA_BITS / 2; bit_idx--) begin
          if (TEST_CPHA == 1'b0) begin
            spi_link.mosi = master_tx[bit_idx];
            repeat (HALF_SCLK_CYCLES) @(posedge clk);
            spi_link.sclk = ~TEST_CPOL;
            repeat (HALF_SCLK_CYCLES) @(posedge clk);
            spi_link.sclk = TEST_CPOL;
          end else begin
            spi_link.sclk = ~TEST_CPOL;
            spi_link.mosi = master_tx[bit_idx];
            repeat (HALF_SCLK_CYCLES) @(posedge clk);
            spi_link.sclk = TEST_CPOL;
            repeat (HALF_SCLK_CYCLES) @(posedge clk);
          end
        end

        // Abort: de-assert CS mid-transfer
        #1;
        spi_link.cs_n = 1'b1;
        spi_link.mosi = 1'b0;
        spi_link.sclk = TEST_CPOL;

        $display("[%0t] SPI CS aborted mid-transfer", $time);
      end
      // Slave: should detect CS going high and exit
      begin
        slave_aborted = 1'b0;
        fork
          slave_vip.transfer(slave_tx, slave_rx);
          begin
            // Wait for CS to go high (abort condition)
            @(posedge spi_link.cs_n);
            slave_aborted = 1'b1;
          end
        join_any
        // If slave finished transfer before abort, that's also acceptable
        // (depends on timing). The key is no crash/hang.
      end
    join

    $display("[%0t] SPI CS abort test completed, slave_aborted=%0b", $time, slave_aborted);
    #(INTER_TRANSACTION_PAUSE);
  endtask

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rstn = 1'b0;
    #20 rstn = 1'b1;
  end

  initial begin
    spi_link.sclk = 1'b0;
    spi_link.cs_n = 1'b1;
    spi_link.mosi = 1'b0;
    spi_link.miso = 1'b0;
  end

  `TEST_SUITE begin
    int unsigned stimulus_idx;
    int unsigned observed_count;
    bit test_cpol;
    bit test_cpha;

    `TEST_SUITE_SETUP begin
      master_vip = new(spi_link.master, "master_vip");
      slave_vip  = new(spi_link.slave, "slave_vip");

      @(posedge rstn);
      @(posedge clk);

      test_cpol = TEST_CPOL;
      test_cpha = TEST_CPHA;

      master_vip.configure_mode(test_cpol, test_cpha);
      slave_vip.configure_mode(test_cpol, test_cpha);
      master_vip.idle();
      slave_vip.idle();

      // Set initial sclk to match CPOL idle state
      spi_link.sclk = test_cpol;

      $display("=== SPI Mode - CPOL=%0b, CPHA=%0b ===", test_cpol, test_cpha);

    end

    `TEST_CASE("SingleTransfers") begin
        for (stimulus_idx = 0; stimulus_idx < STIMULUS_COUNT; stimulus_idx++) begin
          run_transfer(stimulus_idx);
        end
    end

    `TEST_CASE("ContinuousTransfers") begin
      fork
        drive_master(0, CONTINUOUS_TRANSFER_COUNT);
        monitor_slave(0, CONTINUOUS_TRANSFER_COUNT, observed_count);
      join

      assert(observed_count == CONTINUOUS_TRANSFER_COUNT)
        else $error("SPI continuous count mismatch exp=%0d got=%0d",
                    CONTINUOUS_TRANSFER_COUNT, observed_count);
    end

    `TEST_CASE("CSAbortMidTransfer") begin
      run_cs_abort();
    end
  end

endmodule
