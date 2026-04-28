class I2CMasterVIP #(
    int HALF_SCL_CYCLES = 25
);

  virtual i2c_if.master vif;
  string vip_name;
  bit enable_pause_generator;
  int unsigned min_pause_cycles;
  int unsigned max_pause_cycles;
  int unsigned timeout_cycles;

  function new(virtual i2c_if.master vif, string vip_name = "i2c_master_vip");
    assert (HALF_SCL_CYCLES > 0)
    else $error("[%s] HALF_SCL_CYCLES=%0d must be > 0", vip_name, HALF_SCL_CYCLES);
    this.vif               = vif;
    this.vip_name          = vip_name;
    enable_pause_generator = 1'b0;
    min_pause_cycles       = 0;
    max_pause_cycles       = 0;
    timeout_cycles         = 3000;
  endfunction

  function void configure_pause_generator(bit enable, int unsigned min_cycles = 0,
                                          int unsigned max_cycles = 0);
    enable_pause_generator = enable;
    min_pause_cycles       = min_cycles;
    max_pause_cycles       = (max_cycles < min_cycles) ? min_cycles : max_cycles;
  endfunction

  function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
  endfunction

  task automatic apply_pause();
    int unsigned pause_cycles;
    if (enable_pause_generator) begin
      pause_cycles = $urandom_range(max_pause_cycles, min_pause_cycles);
      repeat (pause_cycles) @(posedge vif.clk);
    end
  endtask

  // Clear all master output signals to default state
  task automatic clear_outputs();
    vif.master_scl_low <= 1'b0;
    vif.master_sda_low <= 1'b0;
  endtask

  task automatic idle();
    vif.master_scl_low <= 1'b0;
    vif.master_sda_low <= 1'b0;
  endtask

  task automatic wait_half_scl();
    repeat (HALF_SCL_CYCLES) @(posedge vif.clk);
  endtask

  task automatic release_scl();
    int unsigned cycles;

    vif.master_scl_low <= 1'b0;
    cycles = 0;
    do begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for I2C SCL release", vip_name);
      end
    end while (vif.scl !== 1'b1);
  endtask

  task automatic start_condition();
    vif.master_sda_low <= 1'b0;
    vif.master_scl_low <= 1'b0;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    vif.master_sda_low <= 1'b1;
    wait_half_scl();
    vif.master_scl_low <= 1'b1;
    wait_half_scl();
  endtask

  // Repeated start: SDA goes high-to-low while SCL is high
  task automatic repeated_start_condition();
    vif.master_sda_low <= 1'b0;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    vif.master_sda_low <= 1'b1;
    wait_half_scl();
    vif.master_scl_low <= 1'b1;
    wait_half_scl();
  endtask

  task automatic stop_condition();
    vif.master_sda_low <= 1'b1;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    vif.master_sda_low <= 1'b0;
    wait_half_scl();
  endtask

  task automatic write_bit(input bit bit_value);
    vif.master_sda_low <= !bit_value;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    vif.master_scl_low <= 1'b1;
    wait_half_scl();
  endtask

  task automatic read_bit(output bit bit_value);
    vif.master_sda_low <= 1'b0;
    wait_half_scl();
    release_scl();
    wait_half_scl();
    bit_value = vif.sda;
    vif.master_scl_low <= 1'b1;
    wait_half_scl();
  endtask

  task automatic write_raw_byte(input logic [7:0] data, output bit ack);
    bit ack_bit;

    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      write_bit(data[bit_idx]);
    end

    read_bit(ack_bit);
    ack = !ack_bit;
  endtask

  task automatic read_raw_byte(output logic [7:0] data, input bit ack);
    bit bit_value;

    data = '0;
    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      read_bit(bit_value);
      data[bit_idx] = bit_value;
    end

    write_bit(!ack);
  endtask

  task automatic wait_reset_release();
    int unsigned cycles;
    cycles = 0;
    while (!vif.rstn) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles >= timeout_cycles) begin
        $fatal(1, "%s timed out waiting for I2C reset release", vip_name);
      end
    end
    @(posedge vif.clk);
  endtask

  // API: single-byte write (backward compatible)
  task automatic send_byte(input logic [6:0] address, input logic [7:0] data,
                           output bit address_ack, output bit data_ack);
    wait_reset_release();
    start_condition();
    write_raw_byte({address, 1'b0}, address_ack);
    write_raw_byte(data, data_ack);
    stop_condition();

    $display("[%0t] %s WRITE addr=%h data=%h address_ack=%0b data_ack=%0b", $time, vip_name,
             address, data, address_ack, data_ack);
  endtask

  // API: single-byte read (backward compatible)
  task automatic recv_byte(input logic [6:0] address, output logic [7:0] data,
                           output bit address_ack);
    wait_reset_release();
    start_condition();
    write_raw_byte({address, 1'b1}, address_ack);
    read_raw_byte(data, 1'b0);
    stop_condition();

    $display("[%0t] %s READ  addr=%h data=%h address_ack=%0b", $time, vip_name, address, data,
             address_ack);
  endtask

  // API: multi-byte write with optional repeated start
  // When use_repeated_start=1, a repeated start is sent instead of start+stop around the address phase.
  task automatic send_bytes(input logic [6:0] address, input logic [7:0] data[],
                            output bit address_ack, output bit data_acks[],
                            input bit use_repeated_start = 1'b0);
    bit ack;

    wait_reset_release();
    data_acks = new[data.size()];

    if (use_repeated_start) begin
      repeated_start_condition();
    end else begin
      start_condition();
    end

    write_raw_byte({address, 1'b0}, address_ack);

    for (int unsigned i = 0; i < data.size(); i++) begin
      write_raw_byte(data[i], ack);
      data_acks[i] = ack;
    end

    stop_condition();

    $display("[%0t] %s WRITE_BYTES addr=%h count=%0d address_ack=%0b", $time, vip_name, address,
             data.size(), address_ack);
  endtask

  // API: multi-byte read with optional repeated start
  // NACK is sent on the last byte; all preceding bytes are ACKed.
  task automatic recv_bytes(input logic [6:0] address, ref logic [7:0] data[],
                            output bit address_ack, input bit use_repeated_start = 1'b0);
    wait_reset_release();

    if (use_repeated_start) begin
      repeated_start_condition();
    end else begin
      start_condition();
    end

    write_raw_byte({address, 1'b1}, address_ack);

    for (int unsigned i = 0; i < data.size(); i++) begin
      read_raw_byte(data[i], (i < data.size() - 1));
    end

    stop_condition();

    $display("[%0t] %s READ_BYTES addr=%h count=%0d address_ack=%0b", $time, vip_name, address,
             data.size(), address_ack);
  endtask

endclass
