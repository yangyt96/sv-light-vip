`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_full_if.sv"
`include "axi4_full_vip_pkg.sv"

module axi4_full_vip_tb;

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
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n=== AXI4 Full Slave VIP Testbench Started ===");
      $display("\n--- Test 1: Basic Write-Read ---");

      fork
        master_vip.write_req_single(
          .addr(32'h1000), .data(32'hDEADBEEF), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hDEADBEEF), .strb(4'hF), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Write response mismatch resp=%0h", resp);

      // Read back
      fork
        master_vip.read_req_single(.addr(32'h1000), .data(rd_data), .resp(resp), .id(4'd0));
        slave_vip.read_resp_single(.data(32'hDEADBEEF), .resp(2'b00));
      join

      assert(resp == 2'b00) else $error("Read response mismatch resp=%0h", resp);
      assert(rd_data == 32'hDEADBEEF)
        else $error("Read data mismatch exp=%h got=%h", 32'hDEADBEEF, rd_data);

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
        master_vip.write_req_burst(
          .addr(32'h2000), .data(wr_data), .strb(wr_strb),
          .id(4'd5), .burst(2'b01), .resp(wr_resp)
        );
        slave_vip.write_resp_burst(.data(wr_data), .strb(wr_strb), .resp(2'b00));
      join

      assert(wr_resp == 2'b00) else $error("Burst write response mismatch resp=%0h", wr_resp);

      // Read back - use separate array for slave to avoid race with master writing rd_data
      slave_rd_data = new[4];
      for (int i = 0; i < 4; i++) begin
        slave_rd_data[i] = wr_data[i];
      end
      fork
        master_vip.read_req_burst(
          .addr(32'h2000), .beat_count(4),
          .data(rd_data), .resp(rd_resp), .id(4'd5), .burst(2'b01)
        );
        slave_vip.read_resp_burst(.data(slave_rd_data), .resp(2'b00));
      join

      for (int i = 0; i < 4; i++) begin
        assert(rd_data[i] == wr_data[i])
          else $error("Burst data mismatch beat=%0d exp=%h got=%h", i, wr_data[i], rd_data[i]);
      end

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Slave Error Response")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 3: Slave Error Response (SLVERR) ---");

      // Write with SLVERR
      fork
        master_vip.write_req_single(
          .addr(32'h3000), .data(32'hBAD0C0DE), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hBAD0C0DE), .strb(4'hF), .resp(2'b10));
      join

      assert(resp == 2'b10) else $error("Expected SLVERR (2) but got resp=%0h", resp);

      // Read with SLVERR
      fork
        master_vip.read_req_single(.addr(32'h3000), .data(rd_data), .resp(resp), .id(4'd0));
        slave_vip.read_resp_single(.data('0), .resp(2'b10));
      join

      assert(resp == 2'b10) else $error("Expected SLVERR (2) on read but got resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Backpressure Write")
    begin
      logic [1:0] resp;

      $display("\n--- Test 4: Backpressure Write (AW stall 1-3, W stall 0-2) ---");

      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(0), .max_cycles(3)
      );

      fork
        master_vip.write_req_single(
          .addr(32'h4000), .data(32'hAABBCCDD), .strb(4'hF),
          .id(4'd1), .resp(resp)
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

      $display("\n--- Test 5: Backpressure Read (AR stall 2-5, R stall 1-3) ---");

      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(1), .max_cycles(5)
      );

      fork
        master_vip.read_req_single(.addr(32'h5000), .data(rd_data), .resp(resp), .id(4'd2));
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
      logic [ID_WIDTH-1:0]   rd_id;
      logic                  rd_last;
      logic                  rd_ruser;

      $display("\n--- Test 6: Multiple Outstanding Transactions ---");

      // Write 4 locations
      for (int i = 0; i < 4; i++) begin
        fork
          begin
            automatic int idx = i;
            master_vip.write_req_single(.addr(32'h6000 + idx*4), .data(32'h11111111 * (idx + 1)),
                                        .strb(4'hF), .id(idx[3:0]), .resp(wr_resp));
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
            master_vip.send_archn(.addr(32'h6000 + i*4), .id(i[3:0]));
          end
        end
        begin
          for (int i = 0; i < 4; i++) begin
            slave_vip.read_resp_single(.data(32'h11111111 * (i + 1)), .resp(2'b00));
          end
        end
        begin
          for (int i = 0; i < 4; i++) begin
            master_vip.recv_rchn(.data(rd_data[i]), .resp(rd_resp[i]), .id(rd_id), .last(rd_last), .user(rd_ruser));
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

      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(0), .max_cycles(3)
      );

      // Write
      wr_data = new[3];
      wr_strb = new[3];
      for (int i = 0; i < 3; i++) begin
        wr_data[i] = 32'hF0000000 + (i * 32'h00100100);
        wr_strb[i] = '1;
      end

      fork
        master_vip.write_req_burst(
          .addr(32'h7000), .data(wr_data), .strb(wr_strb),
          .id(4'd7), .burst(2'b01), .resp(wr_resp)
        );
        slave_vip.write_resp_burst(.data(wr_data), .strb(wr_strb), .resp(2'b00));
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
        master_vip.read_req_burst(
          .addr(32'h7000), .beat_count(3),
          .data(rd_data), .resp(rd_resp), .id(4'd7), .burst(2'b01)
        );
        slave_vip.read_resp_burst(.data(slave_rd_data), .resp(2'b00));
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

    `TEST_CASE("WRAP Burst via Slave VIP")
    begin
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [DATA_WIDTH-1:0] rd_data[];
      logic [DATA_WIDTH-1:0] slave_rd_data[];
      logic [1:0]            wr_resp;
      logic [1:0]            rd_resp[];

      $display("\n--- Test 8: WRAP Burst via Slave VIP (4 beats) ---");

      wr_data = new[4];
      wr_strb = new[4];
      rd_data = new[4];
      rd_resp = new[4];
      for (int i = 0; i < 4; i++) begin
        wr_data[i] = 32'hB0000000 + (i * 32'h00100100);
        wr_strb[i] = '1;
      end

      fork
        master_vip.write_req_burst(
          .addr(32'h8008), .data(wr_data), .strb(wr_strb),
          .id(4'd8), .burst(2'b10), .resp(wr_resp)  // WRAP
        );
        slave_vip.write_resp_burst(.data(wr_data), .strb(wr_strb), .resp(2'b00));
      join

      assert(wr_resp == 2'b00) else $error("WRAP burst write response mismatch resp=%0h", wr_resp);

      // Read back
      slave_rd_data = new[4];
      for (int i = 0; i < 4; i++) begin
        slave_rd_data[i] = wr_data[i];
      end
      fork
        master_vip.read_req_burst(
          .addr(32'h8008), .beat_count(4),
          .data(rd_data), .resp(rd_resp), .id(4'd8), .burst(2'b10)  // WRAP
        );
        slave_vip.read_resp_burst(.data(slave_rd_data), .resp(2'b00));
      join

      for (int i = 0; i < 4; i++) begin
        assert(rd_data[i] == wr_data[i])
          else $error("WRAP burst data mismatch beat=%0d exp=%h got=%h", i, wr_data[i], rd_data[i]);
      end

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("DECERR Response")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 9: DECERR Response (decode error) ---");

      // Write with DECERR
      fork
        master_vip.write_req_single(
          .addr(32'hF000), .data(32'hDEC0DE10), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hDEC0DE10), .strb(4'hF), .resp(2'b11));
      join

      assert(resp == 2'b11) else $error("Expected DECERR (3) but got resp=%0h", resp);

      // Read with DECERR
      fork
        master_vip.read_req_single(.addr(32'hF000), .data(rd_data), .resp(resp), .id(4'd0));
        slave_vip.read_resp_single(.data('0), .resp(2'b11));
      join

      assert(resp == 2'b11) else $error("Expected DECERR (3) on read but got resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("EXOKAY Response")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 10: EXOKAY Response (exclusive access) ---");

      // Write with EXOKAY
      fork
        master_vip.write_req_single(
          .addr(32'hA000), .data(32'hA5A5_5A5A), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hA5A5_5A5A), .strb(4'hF), .resp(2'b01));
      join

      assert(resp == 2'b01) else $error("Expected EXOKAY (1) but got resp=%0h", resp);

      // Read with EXOKAY
      fork
        master_vip.read_req_single(.addr(32'hA000), .data(rd_data), .resp(resp), .id(4'd0));
        slave_vip.read_resp_single(.data(32'hA5A5_5A5A), .resp(2'b01));
      join

      assert(resp == 2'b01) else $error("Expected EXOKAY (1) on read but got resp=%0h", resp);

      #(INTER_TRANSACTION_PAUSE);
    end

    // ============================================================
    // New Enhanced Test Cases (Test 11-16)
    // ============================================================

    `TEST_CASE("Boundary Address Write-Read")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 11: Boundary Address Write-Read (0x0000_0000 and 0xFFFF_FFF0) ---");

      // Lower boundary
      fork
        master_vip.write_req_single(
          .addr(32'h0000_0000), .data(32'hB0D1_CA5E), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hB0D1_CA5E), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Lower boundary write resp mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'h0000_0000), .data(rd_data), .resp(resp), .id(4'd0));
        slave_vip.read_resp_single(.data(32'hB0D1_CA5E), .resp(2'b00));
      join
      assert(rd_data == 32'hB0D1_CA5E)
        else $error("Lower boundary read data mismatch exp=%h got=%h", 32'hB0D1_CA5E, rd_data);

      // Upper boundary (aligned to 16-byte for 32-bit data)
      fork
        master_vip.write_req_single(
          .addr(32'hFFFF_FFF0), .data(32'hCAF1_B0D1), .strb(4'hF),
          .id(4'd1), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hCAF1_B0D1), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Upper boundary write resp mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'hFFFF_FFF0), .data(rd_data), .resp(resp), .id(4'd1));
        slave_vip.read_resp_single(.data(32'hCAF1_B0D1), .resp(2'b00));
      join
      assert(rd_data == 32'hCAF1_B0D1)
        else $error("Upper boundary read data mismatch exp=%h got=%h", 32'hCAF1_B0D1, rd_data);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Reset During Transaction")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 12: Reset During Transaction ---");

      // Complete a normal transaction first
      fork
        master_vip.write_req_single(
          .addr(32'h4000), .data(32'hDEAD_BEEF), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hDEAD_BEEF), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Pre-reset write resp mismatch resp=%0h", resp);

      // Assert reset, then release
      $display("  Asserting reset...");
      rstn = 1'b0;
      repeat (10) @(posedge clk);
      rstn = 1'b1;

      // Re-initialize slave VIP after reset (clear_outputs resets all signals)
      slave_vip.clear_outputs();
      repeat (5) @(posedge clk);

      $display("Reset completed, verifying clean recovery...");

      // Verify clean state after reset: do a fresh transaction
      fork
        master_vip.write_req_single(
          .addr(32'h5000), .data(32'hA5A5_A5A5), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hA5A5_A5A5), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Post-reset write response mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'h5000), .data(rd_data), .resp(resp), .id(4'd0));
        slave_vip.read_resp_single(.data(32'hA5A5_A5A5), .resp(2'b00));
      join
      assert(rd_data == 32'hA5A5_A5A5)
        else $error("Post-reset read data mismatch exp=%h got=%h", 32'hA5A5_A5A5, rd_data);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Random Burst Length and Size")
    begin
      logic [DATA_WIDTH-1:0] wr_data[];
      logic [STRB_WIDTH-1:0] wr_strb[];
      logic [DATA_WIDTH-1:0] rd_data[];
      logic [DATA_WIDTH-1:0] slave_rd_data[];
      logic [1:0]            wr_resp;
      logic [1:0]            rd_resp[];
      int unsigned           beat_count;
      int unsigned           burst_type;

      $display("\n--- Test 13: Random Burst Length and Size (3 iterations) ---");

      for (int iter = 0; iter < 3; iter++) begin
        beat_count = $urandom_range(1, 8);  // 1 to 8 beats
        burst_type = $urandom_range(0, 2);  // 0=FIXED, 1=INCR, 2=WRAP
        if (burst_type == 2) begin
          // WRAP requires power-of-2 beat count
          if (beat_count > 4) beat_count = 4;
          if (beat_count < 2) beat_count = 2;
          // Round down to power of 2
          beat_count = 2**($clog2(beat_count));
        end

        $display("  Iter %0d: beat_count=%0d burst=%0d", iter, beat_count, burst_type);

        wr_data = new[beat_count];
        wr_strb = new[beat_count];
        rd_data = new[beat_count];
        rd_resp = new[beat_count];
        for (int i = 0; i < beat_count; i++) begin
          wr_data[i] = 32'hA000_0000 + (iter * 32'h1000_0000) + (i * 32'h0101_0101);
          wr_strb[i] = '1;
        end

        fork
          master_vip.write_req_burst(
            .addr(32'h6000 + iter*32'h1000), .data(wr_data), .strb(wr_strb),
            .id(4'(iter)), .burst(2'(burst_type)), .resp(wr_resp)
          );
          slave_vip.write_resp_burst(.data(wr_data), .strb(wr_strb), .resp(2'b00));
        join
        assert(wr_resp == 2'b00)
          else $error("Random burst write resp mismatch iter=%0d resp=%0h", iter, wr_resp);

        // Read back
        slave_rd_data = new[beat_count];
        for (int i = 0; i < beat_count; i++) begin
          slave_rd_data[i] = wr_data[i];
        end
        fork
          master_vip.read_req_burst(
            .addr(32'h6000 + iter*32'h1000), .beat_count(beat_count),
            .data(rd_data), .resp(rd_resp), .id(4'(iter)), .burst(2'(burst_type))
          );
          slave_vip.read_resp_burst(.data(slave_rd_data), .resp(2'b00));
        join

        for (int i = 0; i < beat_count; i++) begin
          assert(rd_data[i] == wr_data[i])
            else $error("Random burst data mismatch iter=%0d beat=%0d exp=%h got=%h",
                       iter, i, wr_data[i], rd_data[i]);
        end
      end

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Out-of-Order ID Completion (Slave VIP)")
    begin
      logic [DATA_WIDTH-1:0] rd_data[3];
      logic [1:0]            rd_resp[3];
      logic [ID_WIDTH-1:0]   rd_id;
      logic                  rd_last;
      logic                  rd_ruser;
      logic [1:0]            wr_resp[3];

      $display("\n--- Test 14: Out-of-Order ID Completion ---");

      // Write 3 locations with different IDs
      for (int i = 0; i < 3; i++) begin
        fork
          begin
            automatic int idx = i;
            master_vip.write_req_single(.addr(32'h7000 + idx*4), .data(32'h1111_0000 + idx*32'h1111),
                                        .strb(4'hF), .id(idx[3:0]), .resp(wr_resp[idx]));
          end
          begin
            automatic int idx = i;
            slave_vip.write_resp_single(.data(32'h1111_0000 + idx*32'h1111), .strb(4'hF), .resp(2'b00));
          end
        join
        assert(wr_resp[i] == 2'b00) else $error("Write %0d response mismatch", i);
      end

      // Issue 3 outstanding reads with different IDs
      // Slave VIP will respond in-order (it's single-outstanding internally)
      // But we use channel-level API to demonstrate ID handling
      fork
        begin
          master_vip.send_archn(.addr(32'h7000), .beat_count(1), .id(4'd2));
          master_vip.send_archn(.addr(32'h7004), .beat_count(1), .id(4'd0));
          master_vip.send_archn(.addr(32'h7008), .beat_count(1), .id(4'd1));
        end
        begin
          // Slave responds in order of AR receipt
          slave_vip.read_resp_single(.data(32'h1111_0000), .resp(2'b00));
          slave_vip.read_resp_single(.data(32'h1111_1111), .resp(2'b00));
          slave_vip.read_resp_single(.data(32'h1111_2222), .resp(2'b00));
        end
        begin
          for (int i = 0; i < 3; i++) begin
            master_vip.recv_rchn(.data(rd_data[i]), .resp(rd_resp[i]), .id(rd_id), .last(rd_last), .user(rd_ruser));
            $display("  Received R id=%0d data=%h", rd_id, rd_data[i]);
          end
        end
      join

      for (int i = 0; i < 3; i++) begin
        assert(rd_resp[i] == 2'b00) else $error("Read %0d response mismatch resp=%0h", i, rd_resp[i]);
      end

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Max Backpressure Stress")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 15: Max Backpressure Stress (50-100 cycle stalls) ---");

      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(50), .max_cycles(100)
      );

      fork
        master_vip.write_req_single(
          .addr(32'h8000), .data(32'hDEAD_BEEF), .strb(4'hF),
          .id(4'd0), .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hDEAD_BEEF), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Stress write response mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'h8000), .data(rd_data), .resp(resp), .id(4'd0));
        slave_vip.read_resp_single(.data(32'hDEAD_BEEF), .resp(2'b00));
      join
      assert(rd_data == 32'hDEAD_BEEF)
        else $error("Stress read data mismatch exp=%h got=%h", 32'hDEAD_BEEF, rd_data);

      // Reset backpressure
      slave_vip.configure_backpressure();

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Consecutive Transactions Without Pause")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 16: Consecutive Transactions Without Pause (8 writes + 8 reads) ---");

      // 8 rapid-fire writes
      for (int i = 0; i < 8; i++) begin
        fork
          begin
            automatic int idx = i;
            master_vip.write_req_single(
              .addr(32'h9000 + idx*4), .data(32'hC0DE_CAFE + idx), .strb(4'hF),
              .id(idx[3:0]), .resp(resp)
            );
          end
          begin
            automatic int idx = i;
            slave_vip.write_resp_single(.data(32'hC0DE_CAFE + idx), .strb(4'hF), .resp(2'b00));
          end
        join
        assert(resp == 2'b00) else $error("Consecutive write %0d resp mismatch resp=%0h", i, resp);
      end

      // 8 rapid-fire reads
      for (int i = 0; i < 8; i++) begin
        fork
          begin
            automatic int idx = i;
            master_vip.read_req_single(.addr(32'h9000 + idx*4), .data(rd_data), .resp(resp), .id(idx[3:0]));
          end
          begin
            automatic int idx = i;
            slave_vip.read_resp_single(.data(32'hC0DE_CAFE + idx), .resp(2'b00));
          end
        join
        assert(rd_data == (32'hC0DE_CAFE + i))
          else $error("Consecutive read %0d data mismatch exp=%h got=%h", i, 32'hC0DE_CAFE + i, rd_data);
      end

      $display("  All 8 writes and 8 reads completed successfully");
    end
  end

endmodule
