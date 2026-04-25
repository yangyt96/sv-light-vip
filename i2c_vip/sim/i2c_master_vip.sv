class I2CMasterVIP #(
  int HALF_SCL_CYCLES = 25
);

  virtual i2c_if.master vif;
  string vip_name;

  function new(virtual i2c_if.master vif,
               string vip_name = "i2c_master_vip");
    this.vif = vif;
    this.vip_name = vip_name;
  endfunction

  task automatic idle();
    vif.master_scl_low = 1'b0;
    vif.master_sda_low = 1'b0;
  endtask

  task automatic wait_half_scl();
    repeat (HALF_SCL_CYCLES) @(posedge vif.clk);
  endtask

  task automatic release_scl();
    vif.master_scl_low = 1'b0;
    do begin
      @(posedge vif.clk);
    end while (vif.scl !== 1'b1);
  endtask

  task automatic start_condition();
    vif.master_sda_low = 1'b0;
    vif.master_scl_low = 1'b0;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    vif.master_sda_low = 1'b1;
    wait_half_scl();
    vif.master_scl_low = 1'b1;
    wait_half_scl();
  endtask

  task automatic stop_condition();
    vif.master_sda_low = 1'b1;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    vif.master_sda_low = 1'b0;
    wait_half_scl();
  endtask

  task automatic write_bit(input bit bit_value);
    vif.master_sda_low = !bit_value;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    vif.master_scl_low = 1'b1;
    wait_half_scl();
  endtask

  task automatic read_bit(output bit bit_value);
    vif.master_sda_low = 1'b0;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    bit_value = vif.sda;
    vif.master_scl_low = 1'b1;
    wait_half_scl();
  endtask

  task automatic write_raw_byte(input logic [7:0] data,
                                output bit ack);
    bit ack_bit;

    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      write_bit(data[bit_idx]);
    end

    read_bit(ack_bit);
    ack = !ack_bit;
  endtask

  task automatic read_raw_byte(output logic [7:0] data,
                               input bit ack);
    bit bit_value;

    data = '0;
    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      read_bit(bit_value);
      data[bit_idx] = bit_value;
    end

    write_bit(!ack);
  endtask

  task automatic write_byte(input  logic [6:0] address,
                            input  logic [7:0] data,
                            output bit address_ack,
                            output bit data_ack);
    while (!vif.rstn) @(posedge vif.clk);
    @(posedge vif.clk);

    start_condition();
    write_raw_byte({address, 1'b0}, address_ack);
    write_raw_byte(data, data_ack);
    stop_condition();

    $display("[%0t] %s WRITE addr=%h data=%h address_ack=%0b data_ack=%0b",
             $time, vip_name, address, data, address_ack, data_ack);
  endtask

  task automatic read_byte(input  logic [6:0] address,
                           output logic [7:0] data,
                           output bit address_ack);
    while (!vif.rstn) @(posedge vif.clk);
    @(posedge vif.clk);

    start_condition();
    write_raw_byte({address, 1'b1}, address_ack);
    read_raw_byte(data, 1'b0);
    stop_condition();

    $display("[%0t] %s READ  addr=%h data=%h address_ack=%0b",
             $time, vip_name, address, data, address_ack);
  endtask

endclass
