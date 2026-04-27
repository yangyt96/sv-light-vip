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

    `TEST_SUITE_SETUP begin
      tx_vip = new(i2s_link.transmitter, "tx_vip");
      rx_vip = new(i2s_link.receiver, "rx_vip");
      tx_vip.idle();

      @(posedge rstn);
      @(posedge clk);
    end

    `TEST_CASE("SingleFrames") begin
      for (int unsigned idx = 0; idx < STIMULUS_COUNT; idx++) begin
        run_frame(idx);
      end
    end

    `TEST_CASE("ContinuousFrames") begin
      fork
        drive_frames(0, CONTINUOUS_FRAME_COUNT);
        monitor_frames(0, CONTINUOUS_FRAME_COUNT, observed_count);
      join

      assert(observed_count == CONTINUOUS_FRAME_COUNT)
        else $error("I2S continuous count mismatch exp=%0d got=%0d",
                    CONTINUOUS_FRAME_COUNT, observed_count);
    end

    `TEST_CASE("BoundaryValues") begin
      logic [SAMPLE_WIDTH-1:0] exp_left;
      logic [SAMPLE_WIDTH-1:0] exp_right;
      logic [SAMPLE_WIDTH-1:0] rx_left;
      logic [SAMPLE_WIDTH-1:0] rx_right;
      bit frame_error;

      // Test all-zeros
      exp_left  = '0;
      exp_right = '0;
      fork
        tx_vip.transmit(exp_left, exp_right);
        rx_vip.receive(rx_left, rx_right, frame_error);
      join
      assert(!frame_error) else $error("I2S boundary: frame error on all-zeros");
      assert(rx_left == exp_left)
        else $error("I2S boundary: left mismatch on all-zeros exp=%h got=%h", exp_left, rx_left);
      assert(rx_right == exp_right)
        else $error("I2S boundary: right mismatch on all-zeros exp=%h got=%h", exp_right, rx_right);
      #(INTER_TRANSACTION_PAUSE);

      // Test all-ones
      exp_left  = '1;
      exp_right = '1;
      fork
        tx_vip.transmit(exp_left, exp_right);
        rx_vip.receive(rx_left, rx_right, frame_error);
      join
      assert(!frame_error) else $error("I2S boundary: frame error on all-ones");
      assert(rx_left == exp_left)
        else $error("I2S boundary: left mismatch on all-ones exp=%h got=%h", exp_left, rx_left);
      assert(rx_right == exp_right)
        else $error("I2S boundary: right mismatch on all-ones exp=%h got=%h", exp_right, rx_right);
      #(INTER_TRANSACTION_PAUSE);

      // Test alternating 0xAAAA / 0x5555
      exp_left  = SAMPLE_WIDTH'({8'hAA, 8'hAA});
      exp_right = SAMPLE_WIDTH'({8'h55, 8'h55});
      fork
        tx_vip.transmit(exp_left, exp_right);
        rx_vip.receive(rx_left, rx_right, frame_error);
      join
      assert(!frame_error) else $error("I2S boundary: frame error on alternating");
      assert(rx_left == exp_left)
        else $error("I2S boundary: left mismatch on alternating exp=%h got=%h", exp_left, rx_left);
      assert(rx_right == exp_right)
        else $error("I2S boundary: right mismatch on alternating exp=%h got=%h", exp_right, rx_right);
      #(INTER_TRANSACTION_PAUSE);

      // Test left-only (right=0)
      exp_left  = SAMPLE_WIDTH'(16'hDEAD);
      exp_right = '0;
      fork
        tx_vip.transmit(exp_left, exp_right);
        rx_vip.receive(rx_left, rx_right, frame_error);
      join
      assert(!frame_error) else $error("I2S boundary: frame error on left-only");
      assert(rx_left == exp_left)
        else $error("I2S boundary: left mismatch on left-only exp=%h got=%h", exp_left, rx_left);
      assert(rx_right == exp_right)
        else $error("I2S boundary: right mismatch on left-only exp=%h got=%h", exp_right, rx_right);
      #(INTER_TRANSACTION_PAUSE);

      // Test right-only (left=0)
      exp_left  = '0;
      exp_right = SAMPLE_WIDTH'(16'hBEEF);
      fork
        tx_vip.transmit(exp_left, exp_right);
        rx_vip.receive(rx_left, rx_right, frame_error);
      join
      assert(!frame_error) else $error("I2S boundary: frame error on right-only");
      assert(rx_left == exp_left)
        else $error("I2S boundary: left mismatch on right-only exp=%h got=%h", exp_left, rx_left);
      assert(rx_right == exp_right)
        else $error("I2S boundary: right mismatch on right-only exp=%h got=%h", exp_right, rx_right);

      $display("[%0t] I2S boundary values test completed: 5 patterns", $time);
    end

    `TEST_CASE("DifferentBclkRate") begin
      I2STxVIP #(SAMPLE_WIDTH, 2) fast_tx;
      I2SRxVIP #(SAMPLE_WIDTH)    fast_rx;
      logic [SAMPLE_WIDTH-1:0] exp_left;
      logic [SAMPLE_WIDTH-1:0] exp_right;
      logic [SAMPLE_WIDTH-1:0] rx_left;
      logic [SAMPLE_WIDTH-1:0] rx_right;
      bit frame_error;

      fast_tx = new(i2s_link.transmitter, "fast_tx");
      fast_rx = new(i2s_link.receiver, "fast_rx");
      fast_tx.idle();

      @(posedge clk);

      // Test with faster BCLK (HALF_BCLK_CYCLES=2 instead of 4)
      for (int unsigned idx = 0; idx < 8; idx++) begin
        exp_left  = build_left(idx + 100);
        exp_right = build_right(idx + 100);

        fork
          fast_tx.transmit(exp_left, exp_right);
          fast_rx.receive(rx_left, rx_right, frame_error);
        join

        assert(!frame_error) else $error("I2S fast BCLK: frame error at %0d", idx);
        assert(rx_left == exp_left)
          else $error("I2S fast BCLK: left mismatch at %0d exp=%h got=%h", idx, exp_left, rx_left);
        assert(rx_right == exp_right)
          else $error("I2S fast BCLK: right mismatch at %0d exp=%h got=%h", idx, exp_right, rx_right);

        #(INTER_TRANSACTION_PAUSE);
      end
      $display("[%0t] I2S different BCLK rate test completed: 8 frames at HALF_BCLK_CYCLES=2", $time);
    end
  end

endmodule
