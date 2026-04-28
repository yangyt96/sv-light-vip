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

    // ============================================================
    // Enhanced Test Cases (方向3: 边界地址、随机 prot、复位行为等)
    // ============================================================

    `TEST_CASE("Boundary Address Write-Read")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 11: Boundary Address Write-Read ---");

      // Test address 0x0000_0000 (lower boundary)
      $display("  Writing to address 0x0000_0000");
      fork
        master_vip.write_req_single(
          .addr(32'h0000_0000), .data(32'hB0DAB0DA), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hB0DAB0DA), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Boundary write (0x0) response mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'h0000_0000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hB0DAB0DA), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Boundary read (0x0) response mismatch resp=%0h", resp);
      assert(rd_data == 32'hB0DAB0DA)
        else $error("Boundary read (0x0) data mismatch exp=%h got=%h", 32'hB0DAB0DA, rd_data);

      // Test address 0xFFFF_FFFC (upper boundary, word-aligned)
      $display("  Writing to address 0xFFFF_FFFC");
      fork
        master_vip.write_req_single(
          .addr(32'hFFFF_FFFC), .data(32'hCAFEBABE), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hCAFEBABE), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Boundary write (0xFFFF_FFFC) response mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'hFFFF_FFFC), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hCAFEBABE), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Boundary read (0xFFFF_FFFC) response mismatch resp=%0h", resp);
      assert(rd_data == 32'hCAFEBABE)
        else $error("Boundary read (0xFFFF_FFFC) data mismatch exp=%h got=%h", 32'hCAFEBABE, rd_data);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Random prot Values")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 12: Random prot Values (all 8 combinations) ---");

      // Test all 8 prot values (3'b000 through 3'b111)
      for (int p = 0; p < 8; p++) begin
        automatic logic [2:0] prot_val = p;
        automatic logic [31:0] wr_data = 32'hA000_0000 | (prot_val << 20);
        automatic logic [31:0] addr    = 32'hA000 + (prot_val * 4);

        $display("  Testing prot=%0b (0x%0h)", prot_val, prot_val);

        // Write with specific prot value
        fork
          master_vip.write_req_single(
            .addr(addr), .data(wr_data), .strb(4'hF),
            .resp(resp), .prot(prot_val)
          );
          slave_vip.write_resp_single(.data(wr_data), .strb(4'hF), .resp(2'b00));
        join
        assert(resp == 2'b00) else $error("prot=%0b write response mismatch resp=%0h", prot_val, resp);

        // Read with same prot value
        fork
          master_vip.read_req_single(.addr(addr), .data(rd_data), .resp(resp), .prot(prot_val));
          slave_vip.read_resp_single(.data(wr_data), .resp(2'b00));
        join
        assert(resp == 2'b00) else $error("prot=%0b read response mismatch resp=%0h", prot_val, resp);
        assert(rd_data == wr_data)
          else $error("prot=%0b read data mismatch exp=%h got=%h", prot_val, wr_data, rd_data);
      end

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Reset During Transaction")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 13: Reset During Transaction ---");

      // Start a write transaction, then assert reset mid-transaction
      fork
        begin
          // Master starts write
          master_vip.send_awchn(.addr(32'hC000), .prot(3'b000));
          // Wait a few cycles then assert reset
          repeat (3) @(posedge clk);
          rstn <= 1'b0;
          repeat (10) @(posedge clk);
          rstn <= 1'b1;
          repeat (5) @(posedge clk);
        end
        begin
          logic [ADDR_WIDTH-1:0] tmp_addr;
          logic [2:0]            tmp_prot;
          // Slave accepts AW, then reset hits
          slave_vip.recv_awchn(.addr(tmp_addr), .prot(tmp_prot));
          // Reset may occur here; slave should handle gracefully
        end
      join

      $display("  After reset recovery, perform a clean transaction");

      // After reset recovery, perform a clean transaction
      master_vip.clear_outputs();
      slave_vip.clear_outputs();

      fork
        master_vip.write_req_single(
          .addr(32'hC004), .data(32'hC0DE_CAFE), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hC0DE_CAFE), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Post-reset write response mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'hC004), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hC0DE_CAFE), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Post-reset read response mismatch resp=%0h", resp);
      assert(rd_data == 32'hC0DE_CAFE)
        else $error("Post-reset read data mismatch exp=%h got=%h", 32'hC0DE_CAFE, rd_data);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("All-Zeros and All-Ones Data Patterns")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 14: All-Zeros and All-Ones Data Patterns ---");

      // All-zeros data
      $display("  Testing all-zeros data pattern");
      fork
        master_vip.write_req_single(
          .addr(32'hD000), .data(32'h0000_0000), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'h0000_0000), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("All-zeros write response mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'hD000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'h0000_0000), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("All-zeros read response mismatch resp=%0h", resp);
      assert(rd_data == 32'h0000_0000)
        else $error("All-zeros read data mismatch exp=%h got=%h", 32'h0000_0000, rd_data);

      // All-ones data
      $display("  Testing all-ones data pattern");
      fork
        master_vip.write_req_single(
          .addr(32'hD004), .data(32'hFFFF_FFFF), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hFFFF_FFFF), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("All-ones write response mismatch resp=%0h", resp);

      fork
        master_vip.read_req_single(.addr(32'hD004), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hFFFF_FFFF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("All-ones read response mismatch resp=%0h", resp);
      assert(rd_data == 32'hFFFF_FFFF)
        else $error("All-ones read data mismatch exp=%h got=%h", 32'hFFFF_FFFF, rd_data);

      #(INTER_TRANSACTION_PAUSE);
    end

    `TEST_CASE("Max Backpressure Stress")
    begin
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            resp;

      $display("\n--- Test 15: Max Backpressure Stress (max_stall=100) ---");

      // Enable maximum backpressure
      slave_vip.configure_backpressure(
        .enable(1'b1), .min_cycles(50), .max_cycles(100)
      );

      // Write with heavy backpressure
      $display("  Write with heavy backpressure (50-100 cycle stalls)");
      fork
        master_vip.write_req_single(
          .addr(32'hE000), .data(32'hDEAD_BEEF), .strb(4'hF),
          .resp(resp)
        );
        slave_vip.write_resp_single(.data(32'hDEAD_BEEF), .strb(4'hF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Stress write response mismatch resp=%0h", resp);

      // Read with heavy backpressure
      $display("  Read with heavy backpressure (50-100 cycle stalls)");
      fork
        master_vip.read_req_single(.addr(32'hE000), .data(rd_data), .resp(resp));
        slave_vip.read_resp_single(.data(32'hDEAD_BEEF), .resp(2'b00));
      join
      assert(resp == 2'b00) else $error("Stress read response mismatch resp=%0h", resp);
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

      $display("\n--- Test 16: Consecutive Transactions Without Pause ---");

      // Rapid-fire 8 writes followed by 8 reads without inter-transaction delay
      $display("  Performing 8 consecutive writes without pause");
      for (int i = 0; i < 8; i++) begin
        automatic int idx = i;
        automatic logic [31:0] addr = 32'hF000 + idx * 4;
        automatic logic [31:0] data = 32'hF000_0000 + idx;

        fork
          master_vip.write_req_single(
            .addr(addr), .data(data), .strb(4'hF),
            .resp(resp)
          );
          slave_vip.write_resp_single(.data(data), .strb(4'hF), .resp(2'b00));
        join
        assert(resp == 2'b00) else $error("Consecutive write %0d response mismatch resp=%0h", i, resp);
      end

      $display("  Performing 8 consecutive reads without pause");
      for (int i = 0; i < 8; i++) begin
        automatic int idx = i;
        automatic logic [31:0] addr = 32'hF000 + idx * 4;
        automatic logic [31:0] exp_data = 32'hF000_0000 + idx;

        fork
          master_vip.read_req_single(.addr(addr), .data(rd_data), .resp(resp));
          slave_vip.read_resp_single(.data(exp_data), .resp(2'b00));
        join
        assert(resp == 2'b00) else $error("Consecutive read %0d response mismatch resp=%0h", i, resp);
        assert(rd_data == exp_data)
          else $error("Consecutive read %0d data mismatch exp=%h got=%h", i, exp_data, rd_data);
      end

      #(INTER_TRANSACTION_PAUSE);
    end
  end

endmodule
