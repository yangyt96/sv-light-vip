`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "i2s_if.sv"
`include "i2s_vip_pkg.sv"

module i2s_vip_tb;

  import vunit_pkg::*;
  import i2s_vip_pkg::*;

  localparam int SAMPLE_WIDTH = 16;
  localparam int HALF_BCLK_CYCLES = 4;
  localparam int STIMULUS_COUNT = 48;
  localparam int CONTINUOUS_FRAME_COUNT = 32;
  localparam time INTER_TRANSACTION_PAUSE = 10us;

  logic clk;
  logic rstn;

  i2s_if i2s_link(clk, rstn);

  I2STxVIP #(SAMPLE_WIDTH, HALF_BCLK_CYCLES) tx_vip;
  I2SRxVIP #(SAMPLE_WIDTH)                   rx_vip;

  function automatic logic [SAMPLE_WIDTH-1:0] build_left(input int unsigned index);
    return SAMPLE_WIDTH'(16'h5000 ^ (index * 16'h0123));
  endfunction

  function automatic logic [SAMPLE_WIDTH-1:0] build_right(input int unsigned index);
    return SAMPLE_WIDTH'(16'hA000 ^ (index * 16'h0211));
  endfunction

  task automatic run_frame(input int unsigned index);
    logic [SAMPLE_WIDTH-1:0] exp_left;
    logic [SAMPLE_WIDTH-1:0] exp_right;
    logic [SAMPLE_WIDTH-1:0] rx_left;
    logic [SAMPLE_WIDTH-1:0] rx_right;
    bit frame_error;

    exp_left = build_left(index);
    exp_right = build_right(index);

    fork
      tx_vip.transmit(exp_left, exp_right);
      rx_vip.receive(rx_left, rx_right, frame_error);
    join

    assert(!frame_error) else $error("I2S frame error at stimulus %0d", index);
    assert(rx_left == exp_left)
      else $error("I2S left mismatch at stimulus %0d exp=%h got=%h", index, exp_left, rx_left);
    assert(rx_right == exp_right)
      else $error("I2S right mismatch at stimulus %0d exp=%h got=%h", index, exp_right, rx_right);

    #(INTER_TRANSACTION_PAUSE);
  endtask

  task automatic drive_frames(input int unsigned start_index,
                              input int unsigned frame_count);
    for (int unsigned idx = start_index; idx < (start_index + frame_count); idx++) begin
      tx_vip.transmit(build_left(idx), build_right(idx));
      #(INTER_TRANSACTION_PAUSE);
    end
  endtask

  task automatic monitor_frames(input int unsigned start_index,
                                input int unsigned frame_count,
                                output int unsigned observed_count);
    logic [SAMPLE_WIDTH-1:0] rx_left;
    logic [SAMPLE_WIDTH-1:0] rx_right;
    bit frame_error;

    observed_count = 0;
    for (int unsigned idx = start_index; idx < (start_index + frame_count); idx++) begin
      rx_vip.receive(rx_left, rx_right, frame_error);
      observed_count++;
      assert(!frame_error) else $error("I2S continuous frame error at stimulus %0d", idx);
      assert(rx_left == build_left(idx))
        else $error("I2S continuous left mismatch at stimulus %0d", idx);
      assert(rx_right == build_right(idx))
        else $error("I2S continuous right mismatch at stimulus %0d", idx);
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
    i2s_link.bclk = 1'b0;
    i2s_link.ws = 1'b0;
    i2s_link.sd = 1'b0;
  end

  `TEST_SUITE begin
    int unsigned observed_count;

    tx_vip = new(i2s_link.transmitter, "tx_vip");
    rx_vip = new(i2s_link.receiver, "rx_vip");
    tx_vip.idle();

    @(posedge rstn);
    @(posedge clk);

    for (int unsigned idx = 0; idx < STIMULUS_COUNT; idx++) begin
      run_frame(idx);
    end

    fork
      drive_frames(0, CONTINUOUS_FRAME_COUNT);
      monitor_frames(0, CONTINUOUS_FRAME_COUNT, observed_count);
    join

    assert(observed_count == CONTINUOUS_FRAME_COUNT)
      else $error("I2S continuous count mismatch exp=%0d got=%0d",
                  CONTINUOUS_FRAME_COUNT, observed_count);
  end

endmodule
