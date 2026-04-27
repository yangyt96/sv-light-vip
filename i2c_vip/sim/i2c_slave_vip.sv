class I2CSlaveVIP;

  virtual i2c_if.slave vif;
  string vip_name;
  logic [6:0] address;
  int unsigned timeout_cycles;

  function new(virtual i2c_if.slave vif, logic [6:0] address = 7'h52,
               string vip_name = "i2c_slave_vip");
    this.vif       = vif;
    this.address   = address;
    this.vip_name  = vip_name;
    timeout_cycles = 3000;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  task automatic idle();
    vif.slave_scl_low = 1'b0;
    vif.slave_sda_low = 1'b0;
  endtask

  // Stretch SCL low for a given number of system clock cycles
  task automatic stretch_scl(input int unsigned cycles);
    vif.slave_scl_low = 1'b1;
    repeat (cycles) @(posedge vif.clk);
    vif.slave_scl_low = 1'b0;
  endtask

  task automatic wait_start();
    int unsigned cycles;
    bit prev_sda;

    cycles = 0;
    while (!vif.rstn) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for I2C reset release", vip_name);
      end
    end
    cycles = 0;
    while (!(vif.scl === 1'b1 && vif.sda === 1'b1)) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for I2C idle bus", vip_name);
      end
    end
    cycles   = 0;
    prev_sda = vif.sda;
    do begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for I2C start condition", vip_name);
      end
      if ((prev_sda === 1'b1) && (vif.sda === 1'b0) && (vif.scl === 1'b1)) begin
        break;
      end
      prev_sda = vif.sda;
    end while (1);
  endtask

  task automatic wait_stop();
    int unsigned cycles;
    bit prev_sda;

    cycles   = 0;
    prev_sda = vif.sda;
    do begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for I2C stop condition", vip_name);
      end
      if ((prev_sda === 1'b0) && (vif.sda === 1'b1) && (vif.scl === 1'b1)) begin
        break;
      end
      prev_sda = vif.sda;
    end while (1);
  endtask

  task automatic read_raw_byte(output logic [7:0] data);
    data = '0;
    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      @(posedge vif.scl);
      data[bit_idx] = vif.sda;
    end
  endtask

  task automatic send_ack(input bit ack);
    @(negedge vif.scl);
    vif.slave_sda_low = ack;
    @(posedge vif.scl);
    @(negedge vif.scl);
    vif.slave_sda_low = 1'b0;
  endtask

  // Send ACK with optional clock stretching
  task automatic send_ack_stretch(input bit ack, input int unsigned stretch_cycles = 0);
    @(negedge vif.scl);
    vif.slave_sda_low = ack;
    if (stretch_cycles > 0) begin
      stretch_scl(stretch_cycles);
    end
    @(posedge vif.scl);
    @(negedge vif.scl);
    vif.slave_sda_low = 1'b0;
  endtask

  task automatic write_raw_byte(input logic [7:0] data);
    vif.slave_sda_low = !data[7];

    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      @(posedge vif.scl);
      if (bit_idx > 0) begin
        @(negedge vif.scl);
        vif.slave_sda_low = !data[bit_idx-1];
      end
    end

    @(negedge vif.scl);
    vif.slave_sda_low = 1'b0;
  endtask

  task automatic receive_ack(output bit ack);
    @(posedge vif.scl);
    ack = (vif.sda === 1'b0);
    @(negedge vif.scl);
  endtask

  // API: single-byte write (backward compatible)
  task automatic expect_write(output logic [7:0] data, output bit address_match);
    logic [7:0] address_byte;
    logic [6:0] rx_address;
    bit rw_bit;

    wait_start();
    read_raw_byte(address_byte);
    rx_address = address_byte[7:1];
    rw_bit = address_byte[0];
    address_match = (rx_address == address) && (rw_bit == 1'b0);
    send_ack(address_match);

    read_raw_byte(data);
    send_ack(address_match);
    wait_stop();

    $display("[%0t] %s WRITE addr=%h data=%h address_match=%0b", $time, vip_name, rx_address, data,
             address_match);
  endtask

  // API: single-byte read (backward compatible)
  task automatic respond_read(input logic [7:0] data, output bit address_match,
                              output bit master_ack);
    logic [7:0] address_byte;
    logic [6:0] rx_address;
    bit rw_bit;

    wait_start();
    read_raw_byte(address_byte);
    rx_address = address_byte[7:1];
    rw_bit = address_byte[0];
    address_match = (rx_address == address) && (rw_bit == 1'b1);
    send_ack(address_match);

    write_raw_byte(data);
    receive_ack(master_ack);
    wait_stop();

    $display("[%0t] %s READ  addr=%h data=%h address_match=%0b master_ack=%0b", $time, vip_name,
             rx_address, data, address_match, master_ack);
  endtask

  // API: multi-byte write with optional clock stretching after address ACK
  // Reads exactly byte_count data bytes, then waits for stop.
  task automatic expect_write_bytes(input int unsigned byte_count, output logic [7:0] data[],
                                    output bit address_match,
                                    input int unsigned stretch_after_addr = 0);
    logic [7:0] address_byte;
    logic [6:0] rx_address;
    bit rw_bit;

    wait_start();
    read_raw_byte(address_byte);
    rx_address = address_byte[7:1];
    rw_bit = address_byte[0];
    address_match = (rx_address == address) && (rw_bit == 1'b0);

    if (stretch_after_addr > 0) begin
      send_ack_stretch(address_match, stretch_after_addr);
    end else begin
      send_ack(address_match);
    end

    data = new[byte_count];
    for (int unsigned i = 0; i < byte_count; i++) begin
      read_raw_byte(data[i]);
      send_ack(address_match);
    end

    wait_stop();

    $display("[%0t] %s WRITE_BYTES addr=%h count=%0d address_match=%0b", $time, vip_name,
             rx_address, byte_count, address_match);
  endtask

  // API: multi-byte read with optional clock stretching after address ACK
  // Sends byte_count data bytes. Master ACKs all but the last (NACK on last).
  task automatic respond_read_bytes(input int unsigned byte_count, input logic [7:0] data[],
                                    output bit address_match, output bit master_acks[],
                                    input int unsigned stretch_after_addr = 0);
    logic [7:0] address_byte;
    logic [6:0] rx_address;
    bit rw_bit;
    bit mack;

    wait_start();
    read_raw_byte(address_byte);
    rx_address = address_byte[7:1];
    rw_bit = address_byte[0];
    address_match = (rx_address == address) && (rw_bit == 1'b1);

    if (stretch_after_addr > 0) begin
      send_ack_stretch(address_match, stretch_after_addr);
    end else begin
      send_ack(address_match);
    end

    master_acks = new[byte_count];
    for (int unsigned i = 0; i < byte_count; i++) begin
      write_raw_byte(data[i]);
      receive_ack(mack);
      master_acks[i] = mack;
    end

    wait_stop();

    $display("[%0t] %s READ_BYTES addr=%h count=%0d address_match=%0b", $time, vip_name,
             rx_address, byte_count, address_match);
  endtask

endclass
