interface i2c_if (
    input logic clk,
    input logic rstn
);

  tri1  scl;
  tri1  sda;

  logic master_scl_low;
  logic master_sda_low;
  logic slave_scl_low;
  logic slave_sda_low;

  assign scl = master_scl_low ? 1'b0 : 1'bz;
  assign scl = slave_scl_low ? 1'b0 : 1'bz;
  assign sda = master_sda_low ? 1'b0 : 1'bz;
  assign sda = slave_sda_low ? 1'b0 : 1'bz;

  // Bus contention detection: both master and slave driving SDA low simultaneously
  ap_sda_contention :
  assert property (@(posedge clk) disable iff (!rstn) !(master_sda_low && slave_sda_low))
  else $error("I2C bus contention: both master and slave driving SDA low");

  // Bus contention detection: both master and slave driving SCL low simultaneously
  ap_scl_contention :
  assert property (@(posedge clk) disable iff (!rstn) !(master_scl_low && slave_scl_low))
  else $error("I2C bus contention: both master and slave driving SCL low");

  modport master(input clk, rstn, scl, sda, output master_scl_low, master_sda_low);

  modport slave(input clk, rstn, scl, sda, output slave_scl_low, slave_sda_low);

endinterface
