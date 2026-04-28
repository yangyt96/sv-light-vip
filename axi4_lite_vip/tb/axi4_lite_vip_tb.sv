`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_lite_if.sv"
`include "axi4_lite_vip_pkg.sv"

module axi4_lite_vip_tb;

  import axi4_lite_vip_pkg::*;

  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam time INTER_TRANSACTION_PAUSE = 100ns;

  logic clk;
  logic rstn;

  // Create interface instance
  axi4_lite_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
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
  Axi4LiteMasterVIP #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) master_vip;

  Axi4LiteSlaveVIP #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) slave_vip;

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
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n=== AXI4-Lite Slave VIP Testbench Started ===");
      $display("\n--- Test 1: Basic Write-Read ---");

      fork
        master_vip.write_req_single(
          .addr(32'h1000), .data(32'hDEADBEEF), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hDEADBEEF), .strb(4'hF), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Write response mismatch resp=%0h", resp);

      // Read back
      fork
        master_vip.read_req_single(.addr(32'h1000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hDEADBEEF), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Read response mismatch resp=%0h", resp);
      assert(rd_data == 32'hDEADBEEF)
        else $error("Read data mismatch exp=%h got=%h", 32'hDEADBEEF, rd_data);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Slave Error Response")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 2: Slave Error Response (SLVERR) ---");

      // Write with SLVERR
      fork
        master_vip.write_req_single(
          .addr(32'h2000), .data(32'hBAD0C0DE), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hBAD0C0DE), .strb(4'hF), .resp(2'b10));
      join

      assert(resp == 2'b10) else $error("Expected SLVERR (2) but got resp=%0h", resp);

      // Read with SLVERR
      fork
        master_vip.read_req_single(.addr(32'h2000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data('0), .resp(2'b10));
      join

      assert(resp == 2'b10) else $error("Expected SLVERR (2) on read but got resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Backpressure Write")
    begin
      logic [1:0] resp;

      $display("\n--- Test 3: Backpressure Write (AW stall 1-3, W stall 0-2) ---");

      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(0), .max_cycles(3)
      );

      fork
        master_vip.write_req_single(
          .addr(32'h3000), .data(32'hAABBCCDD), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hAABBCCDD), .strb(4'hF), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Backpressure write response mismatch resp=%0h", resp);

      // Reset backpressure
      slave_vip.configure_backpressure();

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Backpressure Read")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 4: Backpressure Read (AR stall 2-5, R stall 1-3) ---");

      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(1), .max_cycles(5)
      );

      fork
        master_vip.read_req_single(.addr(32'h4000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'h12345678), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Backpressure read response mismatch resp=%0h", resp);
      assert(rd_data == 32'h12345678)
        else $error("Backpressure read data mismatch exp=%h got=%h", 32'h12345678, rd_data);

      // Reset backpressure
      slave_vip.configure_backpressure();

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Multiple Outstanding Transactions")
    begin
      logic [1:0]            wr_resp;
      logic [DATA_WIDTH-1:0] rd_data[4];
      logic [1:0]            rd_resp[4];

      $display("\n--- Test 5: Multiple Outstanding Transactions ---");

      // Write 4 locations
      for (int i = 0; i < 4; i++) begin
        fork
          begin
            automatic int idx = i;
            master_vip.write_req_single(.addr(32'h5000 + idx*4), .data(32'h11111111 * (idx + 1)),
                                        .strb(4'hF), .resp(wr_resp));
          end
          begin
            automatic int idx = i;
            slave_vip.write_resp_single(.data(32'h11111111 * (idx + 1)), .strb(4'hF), .resp(2'b00));
          end
        join
        assert(wr_resp == 2'b00) else $error("Outstanding write %0d response mismatch", i);
      end

      // Read back with outstanding AR requests
      fork
        begin
          for (int i = 0; i < 4; i++) begin
            master_vip.send_archn(.addr(32'h5000 + i*4));
          end
        end
        begin
          for (int i = 0; i < 4; i++) begin
            slave_vip.read_resp_single(.data(32'h11111111 * (i + 1)), .resp(2'b00));
          end
        end
        begin
          for (int i = 0; i < 4; i++) begin
            master_vip.recv_rchn(.data(rd_data[i]), .resp(rd_resp[i]));
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

    `TEST_CASE("DECERR Response")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 6: DECERR Response (decode error) ---");

      // Write with DECERR
      fork
        master_vip.write_req_single(
          .addr(32'h6000), .data(32'hDEC0DE10), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hDEC0DE10), .strb(4'hF), .resp(2'b11));
      join

      assert(resp == 2'b11) else $error("Expected DECERR (3) but got resp=%0h", resp);

      // Read with DECERR
      fork
        master_vip.read_req_single(.addr(32'h6000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data('0), .resp(2'b11));
      join

      assert(resp == 2'b11) else $error("Expected DECERR (3) on read but got resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("EXOKAY Response")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 7: EXOKAY Response (exclusive access) ---");

      // Write with EXOKAY
      fork
        master_vip.write_req_single(
          .addr(32'h7000), .data(32'hA5A5_5A5A), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hA5A5_5A5A), .strb(4'hF), .resp(2'b01));
      join

      assert(resp == 2'b01) else $error("Expected EXOKAY (1) but got resp=%0h", resp);

      // Read with EXOKAY
      fork
        master_vip.read_req_single(.addr(32'h7000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hA5A5_5A5A), .resp(2'b01));
      join

      assert(resp == 2'b01) else $error("Expected EXOKAY (1) on read but got resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Mixed Backpressure All Channels")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 8: Mixed Backpressure All Channels ---");

      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(0), .max_cycles(3)
      );

      // Write with backpressure
      fork
        master_vip.write_req_single(
          .addr(32'h8000), .data(32'hF0F0F0F0), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hF0F0F0F0), .strb(4'hF), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Mixed backpressure write response mismatch resp=%0h", resp);

      // Read with backpressure
      fork
        master_vip.read_req_single(.addr(32'h8000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hF0F0F0F0), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Mixed backpressure read response mismatch resp=%0h", resp);
      assert(rd_data == 32'hF0F0F0F0)
        else $error("Mixed backpressure read data mismatch exp=%h got=%h", 32'hF0F0F0F0, rd_data);

      // Reset backpressure
      slave_vip.configure_backpressure();

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Channel-Level Write with prot")
    begin
      logic [1:0] resp;

      $display("\n--- Test 9: Channel-Level Write with prot ---");

      fork
        begin
          master_vip.send_awchn(.addr(32'h9000), .prot(3'b001));
          master_vip.send_wchn(.data(32'hAABBCCDD), .strb(4'hF));
          master_vip.recv_bchn(.resp(resp));
        end
        begin
          slave_vip.write_resp_single(.data(32'hAABBCCDD), .strb(4'hF), .resp(2'b00));
        end
      join

      assert(resp == 2'b00) else $error("Channel-level write response mismatch resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Channel-Level Read with prot")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 10: Channel-Level Read with prot ---");

      fork
        begin
          master_vip.send_archn(.addr(32'h9000), .prot(3'b001));
          master_vip.recv_rchn(.data(rd_data), .resp(resp));
        end
        begin
          slave_vip.read_resp_single(.data(32'hAABBCCDD), .resp(2'b00));
        end
      join

      assert(resp == 2'b00) else $error("Channel-level read response mismatch resp=%0h", resp);
      assert(rd_data == 32'hAABBCCDD)
        else $error("Channel-level read data mismatch exp=%h got=%h", 32'hAABBCCDD, rd_data);

      #(INTER_TRANSACTION_PAUSE);
    end
  end

endmodule
