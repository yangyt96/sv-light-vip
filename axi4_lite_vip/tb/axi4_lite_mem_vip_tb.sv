`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_lite_if.sv"
`include "axi4_lite_vip_pkg.sv"
`include "axi4_lite_mem_vip.sv"

module axi4_lite_mem_vip_tb;

  import vunit_pkg::*;
  import axi4_lite_vip_pkg::*;

  localparam int ADDR_WIDTH         = 16;
  localparam int DATA_WIDTH         = 32;
  localparam int STRB_WIDTH         = DATA_WIDTH / 8;
  localparam int WRITE_STIMULUS_CNT = 32;
  localparam int READ_STIMULUS_CNT  = 32;

  logic clk;
  logic rstn;

  axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH) s_axil_if(clk, rstn);

  Axi4LiteMasterVIP #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH) master;

  // Instantiate the memory VIP module - connect as slave to master's output
  axi4_lite_mem_vip #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .STRB_WIDTH(STRB_WIDTH)
  ) mem_vip (
    .aclk     (clk),
    .aresetn  (rstn),
    .awaddr   (s_axil_if.awaddr),
    .awprot   (s_axil_if.awprot),
    .awvalid  (s_axil_if.awvalid),
    .awready  (s_axil_if.awready),
    .wdata    (s_axil_if.wdata),
    .wstrb    (s_axil_if.wstrb),
    .wvalid   (s_axil_if.wvalid),
    .wready   (s_axil_if.wready),
    .bresp    (s_axil_if.bresp),
    .bvalid   (s_axil_if.bvalid),
    .bready   (s_axil_if.bready),
    .araddr   (s_axil_if.araddr),
    .arprot   (s_axil_if.arprot),
    .arvalid  (s_axil_if.arvalid),
    .arready  (s_axil_if.arready),
    .rdata    (s_axil_if.rdata),
    .rresp    (s_axil_if.rresp),
    .rvalid   (s_axil_if.rvalid),
    .rready   (s_axil_if.rready)
  );

  function automatic logic [ADDR_WIDTH-1:0] build_write_addr(int unsigned index);
    return ADDR_WIDTH'((((index * 5) + 1) * STRB_WIDTH));
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] build_read_addr(int unsigned index);
    return build_write_addr(index);
  endfunction

  function automatic logic [DATA_WIDTH-1:0] build_wdata(int unsigned index);
    return (DATA_WIDTH'(32'hABCD_0000) | DATA_WIDTH'(index));
  endfunction

  function automatic logic [STRB_WIDTH-1:0] build_wstrb(int unsigned index);
    logic [STRB_WIDTH-1:0] mask;
    int active_bytes;
    int idx;
    begin
      mask = '0;
      active_bytes = (index % STRB_WIDTH) + 1;
      for (idx = 0; idx < active_bytes; idx++) begin
        mask[idx] = 1'b1;
      end
      return mask;
    end
  endfunction

  function automatic logic [DATA_WIDTH-1:0] apply_wstrb(
    input logic [DATA_WIDTH-1:0] data,
    input logic [STRB_WIDTH-1:0] strb
  );
    logic [DATA_WIDTH-1:0] masked_data;
    begin
      masked_data = '0;
      for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
        if (strb[byte_idx]) begin
          masked_data[8 * byte_idx +: 8] = data[8 * byte_idx +: 8];
        end
      end
      return masked_data;
    end
  endfunction

  task automatic run_write_transfer(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] strb;
    logic [1:0]            master_resp;

    addr = build_write_addr(index);
    data = build_wdata(index);
    strb = build_wstrb(index);

    master.write_req_single(addr, data, strb, master_resp);

    assert(master_resp == 2'b00) else $error("Write response mismatch at %0d", index);
  endtask

  task automatic run_read_transfer(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] expected_data;
    logic [DATA_WIDTH-1:0] master_data;
    logic [1:0]            master_resp;

    addr          = build_write_addr(index);
    expected_data = apply_wstrb(build_wdata(index), build_wstrb(index));

    master.read_req_single(addr, master_data, master_resp);

    assert(master_resp == 2'b00) else $error("Read response mismatch at %0d", index);
    assert(master_data == expected_data) else $error("Read data mismatch at %0d", index);
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
    s_axil_if.awvalid = 1'b0;
    s_axil_if.awaddr  = '0;
    s_axil_if.awprot  = '0;
    s_axil_if.wvalid  = 1'b0;
    s_axil_if.wdata   = '0;
    s_axil_if.wstrb   = '0;
    s_axil_if.bready  = 1'b0;
    s_axil_if.arvalid = 1'b0;
    s_axil_if.araddr  = '0;
    s_axil_if.arprot  = '0;
    s_axil_if.rready  = 1'b0;

  end

  `TEST_SUITE begin
    int unsigned idx;
    logic [ADDR_WIDTH-1:0] prev_addr;

    `TEST_SUITE_SETUP begin
      master = new(s_axil_if.master, "axil_master_vip");

      @(posedge rstn);
      @(posedge clk);
    end

    `TEST_CASE("Write then Read") begin
      master.configure_pause_generator(1'b0);
      prev_addr = '0;
      for (idx = 0; idx < WRITE_STIMULUS_CNT; idx++) begin
        assert(build_write_addr(idx) != '0)
          else $error("Write address stayed at zero for index %0d", idx);
        if (idx > 0) begin
          assert(build_write_addr(idx) != prev_addr)
            else $error("Write address did not change at index %0d", idx);
        end
        run_write_transfer(idx);
        prev_addr = build_write_addr(idx);
      end

      master.configure_pause_generator(1'b1, 1, 3);
      prev_addr = '0;
      for (idx = 0; idx < READ_STIMULUS_CNT; idx++) begin
        assert(build_read_addr(idx) != '0)
          else $error("Read address stayed at zero for index %0d", idx);
        if (idx > 0) begin
          assert(build_read_addr(idx) != prev_addr)
            else $error("Read address did not change at index %0d", idx);
        end
        run_read_transfer(idx);
        prev_addr = build_read_addr(idx);
      end
    end

    `TEST_CASE("Out-of-Range Address DECERR") begin
      logic [1:0]            wr_resp;
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            rd_resp;

      $display("\n--- Out-of-Range Address DECERR Test ---");

      // Write to address beyond MEM_BYTES (1024 = 0x400)
      master.write_req_single(.addr(16'h1000), .data(32'hDEADBEEF), .strb(4'hF), .resp(wr_resp));
      assert(wr_resp == 2'b11) else $error("Expected DECERR (3) for out-of-range write, got resp=%0h", wr_resp);

      // Read from address beyond MEM_BYTES
      master.read_req_single(.addr(16'h1000), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b11) else $error("Expected DECERR (3) for out-of-range read, got resp=%0h", rd_resp);

      // Verify that in-range access still works after out-of-range access
      master.write_req_single(.addr(16'h0000), .data(32'h12345678), .strb(4'hF), .resp(wr_resp));
      assert(wr_resp == 2'b00) else $error("In-range write after DECERR should be OKAY, got resp=%0h", wr_resp);

      master.read_req_single(.addr(16'h0000), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b00) else $error("In-range read after DECERR should be OKAY, got resp=%0h", rd_resp);
      assert(rd_data == 32'h12345678)
        else $error("In-range read data mismatch exp=%h got=%h", 32'h12345678, rd_data);

      $display("Out-of-range DECERR test passed");
    end

    // ============================================================
    // Enhanced Test Cases (方向3: 边界地址、复位行为等)
    // ============================================================

    `TEST_CASE("Boundary Address Write-Read") begin
      logic [1:0]            wr_resp;
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            rd_resp;

      $display("\n--- Boundary Address Write-Read Test ---");

      // Test address 0x0000 (lower boundary, within MEM_BYTES)
      $display("  Writing to address 0x0000 (lower boundary)");
      master.write_req_single(.addr(16'h0000), .data(32'hB0DA_CAFE), .strb(4'hF), .resp(wr_resp));
      assert(wr_resp == 2'b00) else $error("Boundary write (0x0000) response mismatch resp=%0h", wr_resp);

      master.read_req_single(.addr(16'h0000), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b00) else $error("Boundary read (0x0000) response mismatch resp=%0h", rd_resp);
      assert(rd_data == 32'hB0DA_CAFE)
        else $error("Boundary read (0x0000) data mismatch exp=%h got=%h", 32'hB0DA_CAFE, rd_data);

      // Test address 0x03FC (MEM_BYTES-4 = 1020, last word-aligned in-range address)
      $display("  Writing to address 0x03FC (last in-range word)");
      master.write_req_single(.addr(16'h03FC), .data(32'hCAFE_BABE), .strb(4'hF), .resp(wr_resp));
      assert(wr_resp == 2'b00) else $error("Boundary write (0x03FC) response mismatch resp=%0h", wr_resp);

      master.read_req_single(.addr(16'h03FC), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b00) else $error("Boundary read (0x03FC) response mismatch resp=%0h", rd_resp);
      assert(rd_data == 32'hCAFE_BABE)
        else $error("Boundary read (0x03FC) data mismatch exp=%h got=%h", 32'hCAFE_BABE, rd_data);

      // Test address 0x0400 (first out-of-range address = MEM_BYTES)
      $display("  Writing to address 0x0400 (first out-of-range)");
      master.write_req_single(.addr(16'h0400), .data(32'hDEAD_BEEF), .strb(4'hF), .resp(wr_resp));
      assert(wr_resp == 2'b11) else $error("Expected DECERR for out-of-range write (0x0400), got resp=%0h", wr_resp);

      master.read_req_single(.addr(16'h0400), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b11) else $error("Expected DECERR for out-of-range read (0x0400), got resp=%0h", rd_resp);

      // Verify in-range access still works after boundary tests
      master.read_req_single(.addr(16'h0000), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b00) else $error("Post-boundary in-range read response mismatch resp=%0h", rd_resp);
      assert(rd_data == 32'hB0DA_CAFE)
        else $error("Post-boundary in-range read data mismatch exp=%h got=%h", 32'hB0DA_CAFE, rd_data);

      $display("Boundary address test passed");
    end

    `TEST_CASE("Reset During Transaction") begin
      logic [1:0]            wr_resp;
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            rd_resp;

      $display("\n--- Reset During Transaction Test ---");

      // First, write a known value to address 0x0100
      master.write_req_single(.addr(16'h0100), .data(32'hBEEF_CAFE), .strb(4'hF), .resp(wr_resp));
      assert(wr_resp == 2'b00) else $error("Pre-reset write response mismatch resp=%0h", wr_resp);

      // Assert reset for several cycles
      $display("  Asserting reset for 10 cycles");
      rstn = 1'b0;
      repeat (10) @(posedge clk);
      rstn = 1'b1;
      @(posedge clk);

      // After reset, the state machine is reset but memory retains data.
      // Verify the state machine recovers: write and read should work normally.
      $display("  Writing new value after reset recovery");
      master.write_req_single(.addr(16'h0200), .data(32'hCAFE_BEEF), .strb(4'hF), .resp(wr_resp));
      assert(wr_resp == 2'b00) else $error("Post-reset write response mismatch resp=%0h", wr_resp);

      master.read_req_single(.addr(16'h0200), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b00) else $error("Post-reset read-back response mismatch resp=%0h", rd_resp);
      assert(rd_data == 32'hCAFE_BEEF)
        else $error("Post-reset read-back data mismatch exp=%h got=%h", 32'hCAFE_BEEF, rd_data);

      // Verify pre-reset data is still intact (memory not zeroed by reset)
      master.read_req_single(.addr(16'h0100), .data(rd_data), .resp(rd_resp));
      assert(rd_resp == 2'b00) else $error("Pre-reset data read response mismatch resp=%0h", rd_resp);
      assert(rd_data == 32'hBEEF_CAFE)
        else $error("Pre-reset data should be preserved after reset, got %h", rd_data);

      $display("Reset during transaction test passed");
    end

    `TEST_CASE("Random prot Values") begin
      logic [1:0]            wr_resp;
      logic [DATA_WIDTH-1:0] rd_data;
      logic [1:0]            rd_resp;

      $display("\n--- Random prot Values Test ---");

      // Test all 8 prot values with in-range addresses
      for (int p = 0; p < 8; p++) begin
        automatic logic [2:0] prot_val = p;
        automatic logic [15:0] addr     = 16'h0200 + (p * 4);
        automatic logic [31:0] wr_data  = 32'h5000_0000 | (prot_val << 20);

        $display("  Testing prot=%0b (0x%0h) at addr=0x%0h", prot_val, prot_val, addr);

        master.write_req_single(.addr(addr), .data(wr_data), .strb(4'hF), .resp(wr_resp), .prot(prot_val));
        assert(wr_resp == 2'b00) else $error("prot=%0b write response mismatch resp=%0h", prot_val, wr_resp);

        master.read_req_single(.addr(addr), .data(rd_data), .resp(rd_resp), .prot(prot_val));
        assert(rd_resp == 2'b00) else $error("prot=%0b read response mismatch resp=%0h", prot_val, rd_resp);
        assert(rd_data == wr_data)
          else $error("prot=%0b read data mismatch exp=%h got=%h", prot_val, wr_data, rd_data);
      end

      $display("Random prot values test passed");
    end

  end

endmodule
