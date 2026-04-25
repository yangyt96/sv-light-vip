`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "i2c_master_vip.sv"
`include "i2c_slave_vip.sv"

module i2c_vip_tb;

  import vunit_pkg::*;

  localparam int HALF_SCL_CYCLES          = 25;
  localparam int STIMULUS_COUNT           = 32;
  localparam int CONTINUOUS_TRANSFER_COUNT = 24;
  localparam logic [6:0] SLAVE_ADDRESS    = 7'h52;
  localparam time INTER_TRANSACTION_PAUSE = 10us;

  logic clk;
  logic rstn;

  i2c_if i2c_link(clk, rstn);

  I2CMasterVIP #(HALF_SCL_CYCLES) master_vip;
  I2CSlaveVIP                     slave_vip;

  function automatic logic [7:0] build_master_data(input int unsigned index);
    return 8'((index * 8'h2D) ^ 8'h96);
  endfunction

  function automatic logic [7:0] build_slave_data(input int unsigned index);
    return 8'((index * 8'h19) ^ 8'hC5);
  endfunction

  task automatic run_write(input int unsigned index);
    logic [7:0] master_data;
    logic [7:0] slave_data;
    bit address_ack;
    bit data_ack;
    bit address_match;

    master_data = build_master_data(index);

    fork
      master_vip.write_byte(SLAVE_ADDRESS, master_data, address_ack, data_ack);
      slave_vip.expect_write(slave_data, address_match);
    join

    assert(address_ack) else $error("I2C write address NACK at stimulus %0d", index);
    assert(data_ack) else $error("I2C write data NACK at stimulus %0d", index);
    assert(address_match) else $error("I2C write slave address mismatch at stimulus %0d", index);
    assert(slave_data == master_data)
      else $error("I2C write data mismatch at stimulus %0d exp=%h got=%h",
                  index, master_data, slave_data);

    #(INTER_TRANSACTION_PAUSE);
  endtask

  task automatic run_read(input int unsigned index);
    logic [7:0] master_data;
    logic [7:0] slave_data;
    bit address_ack;
    bit address_match;
    bit master_ack;

    slave_data = build_slave_data(index);

    fork
      master_vip.read_byte(SLAVE_ADDRESS, master_data, address_ack);
      slave_vip.respond_read(slave_data, address_match, master_ack);
    join

    assert(address_ack) else $error("I2C read address NACK at stimulus %0d", index);
    assert(address_match) else $error("I2C read slave address mismatch at stimulus %0d", index);
    assert(!master_ack) else $error("I2C read expected final NACK at stimulus %0d", index);
    assert(master_data == slave_data)
      else $error("I2C read data mismatch at stimulus %0d exp=%h got=%h",
                  index, slave_data, master_data);

    #(INTER_TRANSACTION_PAUSE);
  endtask

  task automatic drive_reads(input int unsigned start_index,
                             input int unsigned transfer_count);
    logic [7:0] master_data;
    bit address_ack;

    for (int unsigned idx = start_index; idx < (start_index + transfer_count); idx++) begin
      master_vip.read_byte(SLAVE_ADDRESS, master_data, address_ack);
      assert(address_ack) else $error("I2C continuous read address NACK at stimulus %0d", idx);
      assert(master_data == build_slave_data(idx))
        else $error("I2C continuous read mismatch at stimulus %0d exp=%h got=%h",
                    idx, build_slave_data(idx), master_data);
      #(INTER_TRANSACTION_PAUSE);
    end
  endtask

  task automatic monitor_reads(input int unsigned start_index,
                               input int unsigned transfer_count,
                               output int unsigned observed_count);
    bit address_match;
    bit master_ack;

    observed_count = 0;
    for (int unsigned idx = start_index; idx < (start_index + transfer_count); idx++) begin
      slave_vip.respond_read(build_slave_data(idx), address_match, master_ack);
      observed_count++;
      assert(address_match) else $error("I2C continuous read slave address mismatch at stimulus %0d", idx);
      assert(!master_ack) else $error("I2C continuous read expected final NACK at stimulus %0d", idx);
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
    i2c_link.master_scl_low = 1'b0;
    i2c_link.master_sda_low = 1'b0;
    i2c_link.slave_scl_low  = 1'b0;
    i2c_link.slave_sda_low  = 1'b0;
  end

  `TEST_SUITE begin
    int unsigned stimulus_idx;
    int unsigned observed_count;

    master_vip = new(i2c_link.master, "master_vip");
    slave_vip  = new(i2c_link.slave, SLAVE_ADDRESS, "slave_vip");
    master_vip.idle();
    slave_vip.idle();

    @(posedge rstn);
    @(posedge clk);

    for (stimulus_idx = 0; stimulus_idx < STIMULUS_COUNT; stimulus_idx++) begin
      run_write(stimulus_idx);
      run_read(stimulus_idx);
    end

    fork
      drive_reads(0, CONTINUOUS_TRANSFER_COUNT);
      monitor_reads(0, CONTINUOUS_TRANSFER_COUNT, observed_count);
    join

    assert(observed_count == CONTINUOUS_TRANSFER_COUNT)
      else $error("I2C continuous count mismatch exp=%0d got=%0d",
                  CONTINUOUS_TRANSFER_COUNT, observed_count);
  end

endmodule
