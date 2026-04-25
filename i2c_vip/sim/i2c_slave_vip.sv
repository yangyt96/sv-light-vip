class I2CSlaveVIP;

  virtual i2c_if.slave vif;
  string vip_name;
  logic [6:0] address;

  function new(virtual i2c_if.slave vif,
               logic [6:0] address = 7'h52,
               string vip_name = "i2c_slave_vip");
    this.vif = vif;
    this.address = address;
    this.vip_name = vip_name;
  endfunction

  task automatic idle();
    vif.slave_scl_low = 1'b0;
    vif.slave_sda_low = 1'b0;
  endtask

  task automatic wait_start();
    while (!vif.rstn) @(posedge vif.clk);
    while (!(vif.scl === 1'b1 && vif.sda === 1'b1)) @(posedge vif.clk);
    do begin
      @(negedge vif.sda);
    end while (vif.scl !== 1'b1);
  endtask

  task automatic wait_stop();
    do begin
      @(posedge vif.sda);
    end while (vif.scl !== 1'b1);
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

  task automatic write_raw_byte(input logic [7:0] data);
    vif.slave_sda_low = !data[7];

    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      @(posedge vif.scl);
      if (bit_idx > 0) begin
        @(negedge vif.scl);
        vif.slave_sda_low = !data[bit_idx - 1];
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

  task automatic expect_write(output logic [7:0] data,
                              output bit address_match);
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

    $display("[%0t] %s WRITE addr=%h data=%h address_match=%0b",
             $time, vip_name, rx_address, data, address_match);
  endtask

  task automatic respond_read(input logic [7:0] data,
                              output bit address_match,
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

    $display("[%0t] %s READ  addr=%h data=%h address_match=%0b master_ack=%0b",
             $time, vip_name, rx_address, data, address_match, master_ack);
  endtask

endclass
