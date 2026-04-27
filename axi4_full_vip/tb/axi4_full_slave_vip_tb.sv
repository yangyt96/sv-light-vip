`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_full_if.sv"
`include "axi4_full_vip_pkg.sv"

module axi4_full_slave_vip_tb;

  import axi4_full_vip_pkg::*;

  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int ID_WIDTH   = 4;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam time INTER_TRANSACTION_PAUSE = 100ns;

  logic clk;
  logic rstn;

  // Create interface instance
  axi4_full_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) axi_if (clk, rstn);

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 100MHz
  end

  // Reset generation
  initial begin
    rstn = 1'b0;
    repeat (5) @(posedge clk);
    rstn = 1'b1;
  end

  // VIP instances
  Axi4FullMasterVIP #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) master_vip;

  Axi4FullSlaveVIP #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) slave_vip;

  function automatic logic [DATA_WIDTH-1:0] build_data(input int unsigned index);
    return DATA_WIDTH'(32'hA500_1000 + (index * 32'h0001_0101));
  endfunction

  // Test stimulus
  `TEST_SUITE
  begin
    // Initialize VIPs
    master_vip = new(axi_if.master, "MASTER_VIP_0");
    slave_vip  = new(axi_if.slave,  "SLAVE_VIP_0");

    master_vip.clear_outputs();
    slave_vip.clear_outputs();
    master_vip.configure_pause_generator(.enable(1'b0));

    // Wait for reset
    wait(rstn);
    repeat (5) @(posedge clk);

    `TEST_CASE("Basic Write-Read")
    begin
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [DATA_WIDTH-1:0] rd_data[];
      logic [DATA_WIDTH-1:0] slave_rd_data[];
      logic [1:0]            resp;

      $display("\n=== AXI4 Full Slave VIP Testbench Started ===");
      $display("\n--- Test 1: Basic Write-Read ---");

      wr_data = new[1];
      wr_strb = new[1];
      rd_data = new[1];
      wr_data[0] = 32'hDEADBEEF;
      wr_strb[0] = 4'hF;

      fork
        master_vip.write_burst(
          .addr(32'h1000), .data(wr_data), .strb(wr_strb),
          .id(4'd0), .resp(resp)
        );
        slave_vip.expect_write_and_respond(.data(wr_data), .strb(wr_strb), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Write response mismatch resp=%0h", resp);

      // Read back - use separate array for slave to avoid race with master writing rd_data
      slave_rd_data = new[1];
      slave_rd_data[0] = 32'hDEADBEEF;
      fork
        master_vip.read(.addr(32'h1000), .data(rd_data[0]), .resp(resp), .id(4'd0));
        slave_vip.respond_read(.data(slave_rd_data), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Read response mismatch resp=%0h", resp);
      assert(rd_data[0] == 32'hDEADBEEF)
        else $error("Read data mismatch exp=%h got=%h", 32'hDEADBEEF, rd_data[0]);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Burst Write-Read")
    begin
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [DATA_WIDTH-1:0] rd_data[];
      logic [DATA_WIDTH-1:0] slave_rd_data[];
      logic [1:0]            wr_resp;
      logic [1:0]            rd_resp[];

      $display("\n--- Test 2: Burst Write-Read (4 beats) ---");

      wr_data = new[4];
      wr_strb = new[4];
      rd_data = new[4];
      rd_resp = new[4];
      for (int i = 0; i < 4; i++) begin
        wr_data[i] = build_data(i);
        wr_strb[i] = '1;
      end

      fork
        master_vip.write_burst(
          .addr(32'h2000), .data(wr_data), .strb(wr_strb),
          .id(4'd5), .burst(2'b01), .resp(wr_resp)
        );
        slave_vip.expect_write_and_respond(.data(wr_data), .strb(wr_strb), .resp(2'b00));
      join

      assert(wr_resp == 2'b00) else $error("Burst write response mismatch resp=%0h", wr_resp);

      // Read back - use separate array for slave to avoid race with master writing rd_data
      slave_rd_data = new[4];
      for (int i = 0; i < 4; i++) begin
        slave_rd_data[i] = wr_data[i];
      end
      fork
        master_vip.read_burst(
          .addr(32'h2000), .beat_count(4),
          .data(rd_data), .resp(rd_resp), .id(4'd5), .burst(2'b01)
        );
        slave_vip.respond_read(.data(slave_rd_data), .resp(2'b00));
      join

      for (int i = 0; i < 4; i++) begin
        assert(rd_data[i] == wr_data[i])
          else $error("Burst data mismatch beat=%0d exp=%h got=%h", i, wr_data[i], rd_data[i]);
      end

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Slave Error Response")
    begin
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [DATA_WIDTH-1:0] rd_data[];
      logic [DATA_WIDTH-1:0] slave_rd_data[];
      logic [1:0]            resp;

      $display("\n--- Test 3: Slave Error Response (SLVERR) ---");

      wr_data = new[1];
      wr_strb = new[1];
      rd_data = new[1];
      wr_data[0] = 32'hBAD0C0DE;
      wr_strb[0] = 4'hF;

      // Write with SLVERR
      fork
        master_vip.write_burst(
          .addr(32'h3000), .data(wr_data), .strb(wr_strb),
          .id(4'd0), .resp(resp)
        );
        slave_vip.expect_write_and_respond(.data(wr_data), .strb(wr_strb), .resp(2'b10));
      join

      assert(resp == 2'b10) else $error("Expected SLVERR (2) but got resp=%0h", resp);

      // Read with SLVERR - use separate array for slave
      slave_rd_data = new[1];
      slave_rd_data[0] = '0;
      fork
        master_vip.read(.addr(32'h3000), .data(rd_data[0]), .resp(resp), .id(4'd0));
        slave_vip.respond_read(.data(slave_rd_data), .resp(2'b10));
      join

      assert(resp == 2'b10) else $error("Expected SLVERR (2) on read but got resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Backpressure Write")
    begin
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [1:0]            resp;

      $display("\n--- Test 4: Backpressure Write (AW stall 1-3, W stall 0-2) ---");

      slave_vip.configure_backpressure(
        .enable_aw(1'b1), .min_aw(1), .max_aw(3),
        .enable_w(1'b1),  .min_w(0),  .max_w(2)
      );

      wr_data = new[1];
      wr_strb = new[1];
      wr_data[0] = 32'hAABBCCDD;
      wr_strb[0] = 4'hF;

      fork
        master_vip.write_burst(
          .addr(32'h4000), .data(wr_data), .strb(wr_strb),
          .id(4'd1), .resp(resp)
        );
        slave_vip.expect_write_and_respond(.data(wr_data), .strb(wr_strb), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Backpressure write response mismatch resp=%0h", resp);

      // Reset backpressure
      slave_vip.configure_backpressure();

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Backpressure Read")
    begin
      logic [DATA_WIDTH-1:0] rd_data[];
      logic [DATA_WIDTH-1:0] slave_rd_data[];
      logic [1:0]            resp;

      $display("\n--- Test 5: Backpressure Read (AR stall 2-5, R stall 1-3) ---");

      slave_vip.configure_backpressure(
        .enable_ar(1'b1), .min_ar(2), .max_ar(5),
        .enable_r(1'b1),  .min_r(1),  .max_r(3)
      );

      // Use separate array for slave to avoid race with master writing rd_data
      slave_rd_data = new[1];
      slave_rd_data[0] = 32'h12345678;

      fork
        master_vip.read(.addr(32'h5000), .data(rd_data[0]), .resp(resp), .id(4'd2));
        slave_vip.respond_read(.data(slave_rd_data), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Backpressure read response mismatch resp=%0h", resp);
      assert(rd_data[0] == 32'h12345678)
        else $error("Backpressure read data mismatch exp=%h got=%h", 32'h12345678, rd_data[0]);

      // Reset backpressure
      slave_vip.configure_backpressure();

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Multiple Outstanding Transactions")
    begin
      logic [1:0]            wr_resp;
      logic [DATA_WIDTH-1:0] rd_data[4];
      logic [1:0]            rd_resp[];
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [DATA_WIDTH-1:0] rd_buf[];

      $display("\n--- Test 6: Multiple Outstanding Transactions ---");

      // Write 4 locations
      for (int i = 0; i < 4; i++) begin
        wr_data = new[1];
        wr_strb = new[1];
        wr_data[0] = 32'h11111111 * (i + 1);
        wr_strb[0] = 4'hF;

        fork
          begin
            automatic int idx = i;
            master_vip.write(.addr(32'h6000 + idx*4), .data(wr_data[0]), .strb(4'hF),
                             .id(idx[3:0]), .resp(wr_resp));
          end
          begin
            automatic int idx = i;
            slave_vip.expect_write_and_respond(.data(wr_data), .strb(wr_strb), .resp(2'b00));
          end
        join
        assert(wr_resp == 2'b00) else $error("Outstanding write %0d response mismatch", i);
      end

      // Read back with outstanding AR requests
      rd_buf = new[1];
      rd_resp = new[1];
      fork
        begin
          for (int i = 0; i < 4; i++) begin
            master_vip.read_archannel(.addr(32'h6000 + i*4), .id(i[3:0]));
          end
        end
        begin
          for (int i = 0; i < 4; i++) begin
            automatic logic [DATA_WIDTH-1:0] slave_rd_buf[];
            slave_rd_buf = new[1];
            slave_rd_buf[0] = 32'h11111111 * (i + 1);
            slave_vip.respond_read(.data(slave_rd_buf), .resp(2'b00));
          end
        end
        begin
          for (int i = 0; i < 4; i++) begin
            master_vip.read_rchannel(.data(rd_buf), .resp(rd_resp), .id(i));
            rd_data[i] = rd_buf[0];
          end
        end
      join

      for (int i = 0; i < 4; i++) begin
        assert(rd_data[i] == (32'h11111111 * (i + 1)))
          else $error("Outstanding read data mismatch id=%0d exp=%h got=%h",
                     i, 32'h11111111 * (i + 1), rd_data[i]);
      end

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Mixed Backpressure All Channels")
    begin
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [DATA_WIDTH-1:0] rd_data[];
      logic [DATA_WIDTH-1:0] slave_rd_data[];
      logic [1:0]            wr_resp;
      logic [1:0]            rd_resp[];

      $display("\n--- Test 7: Mixed Backpressure All Channels ---");

      // Enable backpressure on all channels
      slave_vip.configure_backpressure(
        .enable_aw(1'b1), .min_aw(1), .max_aw(4),
        .enable_w(1'b1),  .min_w(0),  .max_w(2),
        .enable_ar(1'b1), .min_ar(1), .max_ar(3),
        .enable_b(1'b1),  .min_b(0),  .max_b(2),
        .enable_r(1'b1),  .min_r(1),  .max_r(3)
      );

      // Write
      wr_data = new[3];
      wr_strb = new[3];
      for (int i = 0; i < 3; i++) begin
        wr_data[i] = 32'hF0000000 + (i * 32'h00100100);
        wr_strb[i] = '1;
      end

      fork
        master_vip.write_burst(
          .addr(32'h7000), .data(wr_data), .strb(wr_strb),
          .id(4'd7), .burst(2'b01), .resp(wr_resp)
        );
        slave_vip.expect_write_and_respond(.data(wr_data), .strb(wr_strb), .resp(2'b00));
      join

      assert(wr_resp == 2'b00) else $error("Mixed backpressure write response mismatch resp=%0h", wr_resp);

      // Read back - use separate array for slave to avoid race
      slave_rd_data = new[3];
      for (int i = 0; i < 3; i++) begin
        slave_rd_data[i] = wr_data[i];
      end
      rd_data = new[3];
      rd_resp = new[3];
      fork
        master_vip.read_burst(
          .addr(32'h7000), .beat_count(3),
          .data(rd_data), .resp(rd_resp), .id(4'd7), .burst(2'b01)
        );
        slave_vip.respond_read(.data(slave_rd_data), .resp(2'b00));
      join

      for (int i = 0; i < 3; i++) begin
        assert(rd_data[i] == wr_data[i])
          else $error("Mixed backpressure data mismatch beat=%0d exp=%h got=%h",
                     i, wr_data[i], rd_data[i]);
      end

      // Reset backpressure
      slave_vip.configure_backpressure();

      #(INTER_TRANSACTION_PAUSE);
    end
  end

endmodule
