`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "i2c_if.sv"
`include "i2c_vip_pkg.sv"

module i2c_vip_tb;

  import vunit_pkg::*;
  import i2c_vip_pkg::*;

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

  // --- Backward-compatible single-byte tests ---

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

  task automatic run_wrong_address_write();
    logic [7:0] master_data;
    logic [7:0] slave_data;
    bit address_ack;
    bit data_ack;
    bit address_match;

    master_data = 8'hA5;

    fork
      master_vip.write_byte(SLAVE_ADDRESS ^ 7'h01, master_data, address_ack, data_ack);
      slave_vip.expect_write(slave_data, address_match);
    join

    assert(!address_ack) else $error("I2C wrong-address write unexpectedly ACKed address");
    assert(!data_ack) else $error("I2C wrong-address write unexpectedly ACKed data");
    assert(!address_match) else $error("I2C slave reported match for wrong address");

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

  // --- Multi-byte write test ---
  task automatic run_multi_byte_write();
    logic [7:0] m_data[];
    logic [7:0] s_data[];
    bit address_ack;
    bit data_acks[];
    bit address_match;

    m_data = new[3];
    m_data[0] = 8'hDE;
    m_data[1] = 8'hAD;
    m_data[2] = 8'hBE;

    fork
      master_vip.write_bytes(SLAVE_ADDRESS, m_data, address_ack, data_acks);
      slave_vip.expect_write_bytes(3, s_data, address_match);
    join

    assert(address_ack) else $error("I2C multi-byte write address NACK");
    assert(address_match) else $error("I2C multi-byte write address mismatch");
    assert(s_data.size() == 3) else $error("I2C multi-byte write count mismatch exp=3 got=%0d", s_data.size());
    assert(s_data[0] == 8'hDE && s_data[1] == 8'hAD && s_data[2] == 8'hBE)
      else $error("I2C multi-byte write data mismatch got=%h %h %h", s_data[0], s_data[1], s_data[2]);
    assert(data_acks.size() == 3 && data_acks[0] && data_acks[1] && data_acks[2])
      else $error("I2C multi-byte write data NACK");

    $display("[%0t] Multi-byte write PASSED", $time);
    #(INTER_TRANSACTION_PAUSE);
  endtask

  // --- Multi-byte read test ---
  task automatic run_multi_byte_read();
    logic [7:0] s_data[];
    logic [7:0] m_data[];
    bit address_ack;
    bit address_match;
    bit master_acks[];

    s_data = new[3];
    s_data[0] = 8'hCA;
    s_data[1] = 8'hFE;
    s_data[2] = 8'h42;
    m_data = new[3];

    fork
      master_vip.read_bytes(SLAVE_ADDRESS, m_data, address_ack);
      slave_vip.respond_read_bytes(3, s_data, address_match, master_acks);
    join

    assert(address_ack) else $error("I2C multi-byte read address NACK");
    assert(address_match) else $error("I2C multi-byte read address mismatch");
    assert(m_data.size() == 3 && m_data[0] == 8'hCA && m_data[1] == 8'hFE && m_data[2] == 8'h42)
      else $error("I2C multi-byte read data mismatch got=%h %h %h", m_data[0], m_data[1], m_data[2]);
    // Master ACKs first two bytes, NACKs last
    assert(master_acks[0] && master_acks[1] && !master_acks[2])
      else $error("I2C multi-byte read ACK pattern mismatch");

    $display("[%0t] Multi-byte read PASSED", $time);
    #(INTER_TRANSACTION_PAUSE);
  endtask

  // --- Clock stretching test ---
  task automatic run_clock_stretching();
    logic [7:0] m_data[];
    logic [7:0] s_data[];
    bit address_ack;
    bit data_acks[];
    bit address_match;

    m_data = new[1];
    m_data[0] = 8'h77;

    fork
      master_vip.write_bytes(SLAVE_ADDRESS, m_data, address_ack, data_acks);
      slave_vip.expect_write_bytes(1, s_data, address_match, .stretch_after_addr(50));
    join

    assert(address_ack) else $error("I2C clock-stretch write address NACK");
    assert(address_match) else $error("I2C clock-stretch write address mismatch");
    assert(s_data.size() == 1 && s_data[0] == 8'h77)
      else $error("I2C clock-stretch write data mismatch");

    $display("[%0t] Clock stretching PASSED", $time);
    #(INTER_TRANSACTION_PAUSE);
  endtask

  // --- Repeated start test ---
  task automatic run_repeated_start();
    logic [7:0] write_data[];
    logic [7:0] read_data[];
    logic [7:0] s_write_data[];
    logic [7:0] s_read_data[];
    bit w_addr_ack, r_addr_ack;
    bit w_data_acks[];
    bit w_address_match, r_address_match;
    bit r_master_acks[];

    write_data = new[2];
    write_data[0] = 8'h12;
    write_data[1] = 8'h34;
    s_read_data = new[2];
    s_read_data[0] = 8'h56;
    s_read_data[1] = 8'h78;

    // Write with repeated start, then read with repeated start
    fork
      begin
        master_vip.write_bytes(SLAVE_ADDRESS, write_data, w_addr_ack, w_data_acks, .use_repeated_start(1'b1));
      end
      slave_vip.expect_write_bytes(2, s_write_data, w_address_match);
    join

    assert(w_addr_ack) else $error("I2C repeated-start write address NACK");
    assert(w_address_match) else $error("I2C repeated-start write address mismatch");
    assert(s_write_data.size() == 2 && s_write_data[0] == 8'h12 && s_write_data[1] == 8'h34)
      else $error("I2C repeated-start write data mismatch");

    #(INTER_TRANSACTION_PAUSE);

    read_data = new[2];
    fork
      master_vip.read_bytes(SLAVE_ADDRESS, read_data, r_addr_ack, .use_repeated_start(1'b1));
      slave_vip.respond_read_bytes(2, s_read_data, r_address_match, r_master_acks);
    join

    assert(r_addr_ack) else $error("I2C repeated-start read address NACK");
    assert(r_address_match) else $error("I2C repeated-start read address mismatch");
    assert(read_data.size() == 2 && read_data[0] == 8'h56 && read_data[1] == 8'h78)
      else $error("I2C repeated-start read data mismatch");

    $display("[%0t] Repeated start PASSED", $time);
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
    i2c_link.master_scl_low = 1'b0;
    i2c_link.master_sda_low = 1'b0;
    i2c_link.slave_scl_low  = 1'b0;
    i2c_link.slave_sda_low  = 1'b0;
  end

  `TEST_SUITE begin
    int unsigned stimulus_idx;
    int unsigned observed_count;

    `TEST_SUITE_SETUP begin

      master_vip = new(i2c_link.master, "master_vip");
      slave_vip  = new(i2c_link.slave, SLAVE_ADDRESS, "slave_vip");
      master_vip.idle();
      slave_vip.idle();

      @(posedge rstn);
      @(posedge clk);
    end

    `TEST_CASE("SingleByteWriteRead") begin
      for (stimulus_idx = 0; stimulus_idx < STIMULUS_COUNT; stimulus_idx++) begin
        run_write(stimulus_idx);
        run_read(stimulus_idx);
      end
    end

    `TEST_CASE("WrongAddress") begin
      run_wrong_address_write();
    end

    `TEST_CASE("ContinuousReads") begin
      fork
        drive_reads(0, CONTINUOUS_TRANSFER_COUNT);
        monitor_reads(0, CONTINUOUS_TRANSFER_COUNT, observed_count);
      join

      assert(observed_count == CONTINUOUS_TRANSFER_COUNT)
        else $error("I2C continuous count mismatch exp=%0d got=%0d",
                    CONTINUOUS_TRANSFER_COUNT, observed_count);
    end

    `TEST_CASE("MultiByteWrite") begin
      run_multi_byte_write();
    end

    `TEST_CASE("MultiByteRead") begin
      run_multi_byte_read();
    end

    `TEST_CASE("ClockStretching") begin
      run_clock_stretching();
    end

    `TEST_CASE("RepeatedStart") begin
      run_repeated_start();
    end
  end

endmodule
