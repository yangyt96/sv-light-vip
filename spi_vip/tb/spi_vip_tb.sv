`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "spi_if.sv"
`include "spi_vip_pkg.sv"

module spi_vip_tb;

  import vunit_pkg::*;
  import spi_vip_pkg::*;

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

    master_vip = new(spi_link.master, "master_vip");
    slave_vip  = new(spi_link.slave, "slave_vip");
    master_vip.idle();
    slave_vip.idle();

    @(posedge rstn);
    @(posedge clk);

    for (stimulus_idx = 0; stimulus_idx < STIMULUS_COUNT; stimulus_idx++) begin
      run_transfer(stimulus_idx);
    end

    fork
      drive_master(0, CONTINUOUS_TRANSFER_COUNT);
      monitor_slave(0, CONTINUOUS_TRANSFER_COUNT, observed_count);
    join

    assert(observed_count == CONTINUOUS_TRANSFER_COUNT)
      else $error("SPI continuous count mismatch exp=%0d got=%0d",
                  CONTINUOUS_TRANSFER_COUNT, observed_count);
  end

endmodule
