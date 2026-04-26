`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "uart_if.sv"
`include "uart_vip_pkg.sv"

module uart_vip_tb;

  import vunit_pkg::*;
  import uart_vip_pkg::*;

  localparam int CLKS_PER_BIT            = 16;
  localparam int DATA_BITS               = 8;
  localparam int STIMULUS_COUNT          = 56;
  localparam int CONTINUOUS_FRAME_COUNT  = 48;
  localparam time INTER_TRANSACTION_PAUSE = 10us;

  logic clk;
  logic rstn;

  uart_if uart_link(clk, rstn);

  UartTxVIP #(CLKS_PER_BIT, DATA_BITS) tx_vip;
  UartRxVIP #(CLKS_PER_BIT, DATA_BITS) rx_vip;

  function automatic logic [DATA_BITS-1:0] build_data(input int unsigned index);
    return DATA_BITS'((index * 8'h25) ^ 8'hA6);
  endfunction

  task automatic run_frame(input int unsigned index);
    logic [DATA_BITS-1:0] exp_data;
    logic [DATA_BITS-1:0] rx_data;
    bit framing_error;

    exp_data = build_data(index);

    fork
      tx_vip.transmit(exp_data);
      rx_vip.receive(rx_data, framing_error);
    join

    assert(!framing_error) else $error("UART framing error at stimulus %0d", index);
    assert(rx_data == exp_data)
      else $error("UART data mismatch at stimulus %0d exp=%h got=%h", index, exp_data, rx_data);

    #(INTER_TRANSACTION_PAUSE);
  endtask

  task automatic drive_frames(input int unsigned start_index,
                              input int unsigned frame_count);
    for (int unsigned idx = start_index; idx < (start_index + frame_count); idx++) begin
      tx_vip.transmit(build_data(idx));
      #(INTER_TRANSACTION_PAUSE);
    end
  endtask

  task automatic monitor_frames(input int unsigned start_index,
                                input int unsigned frame_count,
                                output int unsigned observed_count);
    logic [DATA_BITS-1:0] rx_data;
    logic [DATA_BITS-1:0] exp_data;
    bit framing_error;

    observed_count = 0;
    for (int unsigned idx = start_index; idx < (start_index + frame_count); idx++) begin
      rx_vip.receive(rx_data, framing_error);
      exp_data = build_data(idx);
      observed_count++;
      assert(!framing_error) else $error("UART continuous framing error at stimulus %0d", idx);
      assert(rx_data == exp_data)
        else $error("UART continuous mismatch at stimulus %0d exp=%h got=%h", idx, exp_data, rx_data);
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
    uart_link.serial_data = 1'b1;
  end

  `TEST_SUITE begin
    int unsigned stimulus_idx;
    int unsigned observed_count;

    `TEST_SUITE_SETUP begin
      tx_vip = new(uart_link.transmitter, "tx_vip");
      rx_vip = new(uart_link.receiver, "rx_vip");
      tx_vip.idle();

      @(posedge rstn);
      @(posedge clk);
    end

    `TEST_CASE("SingleFrames") begin
      for (stimulus_idx = 0; stimulus_idx < STIMULUS_COUNT; stimulus_idx++) begin
        run_frame(stimulus_idx);
      end
    end

    `TEST_CASE("ContinuousFrames") begin
      fork
        drive_frames(0, CONTINUOUS_FRAME_COUNT);
        monitor_frames(0, CONTINUOUS_FRAME_COUNT, observed_count);
      join

      assert(observed_count == CONTINUOUS_FRAME_COUNT)
        else $error("UART continuous count mismatch exp=%0d got=%0d",
                    CONTINUOUS_FRAME_COUNT, observed_count);
    end
  end

endmodule
