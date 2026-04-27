`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "apb_if.sv"
`include "apb_vip_pkg.sv"
`include "apb_mem_vip.sv"

module apb_mem_vip_tb;

  import vunit_pkg::*;
  import apb_vip_pkg::*;

  localparam int ADDR_WIDTH = 16;
  localparam int DATA_WIDTH = 32;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int PROT_WIDTH = 3;
  localparam int MEM_BYTES  = 4096;

  logic clk;
  logic rstn;

  apb_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH, PROT_WIDTH) apb_link(clk, rstn);

  ApbMasterVIP #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH, PROT_WIDTH) master_vip;

  // Hardware memory slave
  apb_mem_vip #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .STRB_WIDTH(STRB_WIDTH),
      .MEM_BYTES (MEM_BYTES)
  ) mem_vip (
      .pclk    (clk),
      .presetn (rstn),
      .paddr   (apb_link.paddr),
      .psel    (apb_link.psel),
      .penable (apb_link.penable),
      .pwrite  (apb_link.pwrite),
      .pwdata  (apb_link.pwdata),
      .pstrb   (apb_link.pstrb),
      .pprot   (apb_link.pprot),
      .prdata  (apb_link.prdata),
      .pready  (apb_link.pready),
      .pslverr (apb_link.pslverr)
  );

  // APB signal stability check
  bit apb_wait_q;
  logic [ADDR_WIDTH-1:0] apb_paddr_q;
  bit apb_pwrite_q;
  logic [DATA_WIDTH-1:0] apb_pwdata_q;
  logic [STRB_WIDTH-1:0] apb_pstrb_q;
  logic [PROT_WIDTH-1:0] apb_pprot_q;

  always_ff @(posedge clk) begin
    if (rstn && apb_wait_q && apb_link.psel && apb_link.penable && !apb_link.pready) begin
      assert(apb_link.paddr == apb_paddr_q) else $error("APB PADDR changed while waiting for PREADY");
      assert(apb_link.pwrite == apb_pwrite_q) else $error("APB PWRITE changed while waiting for PREADY");
      assert(apb_link.pprot == apb_pprot_q) else $error("APB PPROT changed while waiting for PREADY");
      if (apb_link.pwrite) begin
        assert(apb_link.pwdata == apb_pwdata_q) else $error("APB PWDATA changed while waiting for PREADY");
        assert(apb_link.pstrb == apb_pstrb_q) else $error("APB PSTRB changed while waiting for PREADY");
      end
    end

    apb_wait_q   <= rstn && apb_link.psel && apb_link.penable && !apb_link.pready;
    apb_paddr_q  <= apb_link.paddr;
    apb_pwrite_q <= apb_link.pwrite;
    apb_pwdata_q <= apb_link.pwdata;
    apb_pstrb_q  <= apb_link.pstrb;
    apb_pprot_q  <= apb_link.pprot;
  end

  // ========== Helper functions ==========

  function automatic logic [ADDR_WIDTH-1:0] build_addr(input int unsigned index);
    return ADDR_WIDTH'(16'h1000 + (index * STRB_WIDTH));
  endfunction

  function automatic logic [DATA_WIDTH-1:0] build_data(input int unsigned index);
    return DATA_WIDTH'(32'hCAFE_0000 ^ (index * 32'h0101_0011));
  endfunction

  function automatic logic [STRB_WIDTH-1:0] build_strb(input int unsigned index);
    logic [STRB_WIDTH-1:0] strb;
    begin
      strb = '0;
      for (int byte_idx = 0; byte_idx <= (index % STRB_WIDTH); byte_idx++) begin
        strb[byte_idx] = 1'b1;
      end
      return strb;
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

  // ========== Test tasks ==========

  task automatic run_mem_write(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] strb;
    logic [PROT_WIDTH-1:0] prot;
    bit slverr;

    addr = build_addr(index);
    data = build_data(index);
    strb = build_strb(index);
    prot = PROT_WIDTH'(index);

    master_vip.write(addr, data, strb, slverr, prot);
    assert(!slverr) else $error("APB mem write returned error at %0d", index);
  endtask

  task automatic run_mem_read_check(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] expected_data;
    logic [DATA_WIDTH-1:0] master_data;
    logic [STRB_WIDTH-1:0] strb;
    bit slverr;

    addr          = build_addr(index);
    strb          = build_strb(index);
    expected_data = apply_wstrb(build_data(index), strb);

    master_vip.read(addr, master_data, slverr, PROT_WIDTH'(index));
    assert(!slverr) else $error("APB mem read returned error at %0d", index);
    assert(master_data == expected_data)
      else $error("APB mem read data mismatch at %0d exp=%h got=%h", index, expected_data, master_data);
  endtask

  task automatic run_mem_write_pattern(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data;
    bit slverr;

    addr = build_addr(index);
    data = DATA_WIDTH'(32'hDEAD_0000 | index);

    master_vip.write(addr, data, '1, slverr, '0);
    assert(!slverr) else $error("APB mem pattern write returned error at %0d", index);
  endtask

  task automatic run_mem_read_check_pattern(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] expected_data;
    logic [DATA_WIDTH-1:0] master_data;
    bit slverr;

    addr          = build_addr(index);
    expected_data = DATA_WIDTH'(32'hDEAD_0000 | index);

    master_vip.read(addr, master_data, slverr, '0);
    assert(!slverr) else $error("APB mem pattern read returned error at %0d", index);
    assert(master_data == expected_data)
      else $error("APB mem pattern read data mismatch at %0d exp=%h got=%h", index, expected_data, master_data);
  endtask

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Reset generation
  initial begin
    rstn = 1'b0;
    #20 rstn = 1'b1;
  end

  // Initialize interface signals (master-side outputs only)
  initial begin
    apb_link.paddr = '0;
    apb_link.psel = 1'b0;
    apb_link.penable = 1'b0;
    apb_link.pwrite = 1'b0;
    apb_link.pwdata = '0;
    apb_link.pstrb = '0;
    apb_link.pprot = '0;
    // prdata, pready, pslverr are driven by mem_vip module
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      master_vip = new(apb_link.master, "master_vip");
      master_vip.idle();

      @(posedge rstn);
      @(posedge clk);
    end

    `TEST_CASE("Mem VIP Write-Read") begin
      for (int unsigned idx = 0; idx < 32; idx++) begin
        run_mem_write(idx);
      end
      for (int unsigned idx = 0; idx < 32; idx++) begin
        run_mem_read_check(idx);
      end
    end

    `TEST_CASE("Mem VIP Write-Read with Strobe") begin
      for (int unsigned idx = 0; idx < 16; idx++) begin
        run_mem_write(idx);
      end
      for (int unsigned idx = 0; idx < 16; idx++) begin
        run_mem_read_check(idx);
      end
    end

    `TEST_CASE("Mem VIP Cross-Check") begin
      for (int unsigned idx = 0; idx < 16; idx++) begin
        run_mem_write(idx);
      end
      for (int unsigned idx = 0; idx < 16; idx++) begin
        run_mem_write_pattern(idx);
      end
      for (int unsigned idx = 0; idx < 16; idx++) begin
        run_mem_read_check_pattern(idx);
      end
    end

    `TEST_CASE("Mem VIP Boundary Access") begin
      logic [ADDR_WIDTH-1:0] addr;
      logic [DATA_WIDTH-1:0] wr_data;
      logic [DATA_WIDTH-1:0] rd_data;
      bit slverr;

      addr    = '0;
      wr_data = 32'hAABBCCDD;
      master_vip.write(addr, wr_data, '1, slverr, '0);
      assert(!slverr) else $error("Mem VIP boundary write at 0 returned error");
      master_vip.read(addr, rd_data, slverr, '0);
      assert(!slverr) else $error("Mem VIP boundary read at 0 returned error");
      assert(rd_data == wr_data)
        else $error("Mem VIP boundary read at 0 mismatch exp=%h got=%h", wr_data, rd_data);

      addr    = ADDR_WIDTH'(MEM_BYTES - STRB_WIDTH);
      wr_data = 32'h11223344;
      master_vip.write(addr, wr_data, '1, slverr, '0);
      assert(!slverr) else $error("Mem VIP boundary write near end returned error");
      master_vip.read(addr, rd_data, slverr, '0);
      assert(!slverr) else $error("Mem VIP boundary read near end returned error");
      assert(rd_data == wr_data)
        else $error("Mem VIP boundary read near end mismatch exp=%h got=%h", wr_data, rd_data);

      addr    = ADDR_WIDTH'(MEM_BYTES + 16'h100);
      wr_data = 32'h55667788;
      master_vip.write(addr, wr_data, '1, slverr, '0);
      assert(!slverr) else $error("Mem VIP boundary write wrapped returned error");
      master_vip.read(addr, rd_data, slverr, '0);
      assert(!slverr) else $error("Mem VIP boundary read wrapped returned error");
      assert(rd_data == wr_data)
        else $error("Mem VIP boundary read wrapped mismatch exp=%h got=%h", wr_data, rd_data);
    end

    `TEST_CASE("Mem VIP Random Access Stress") begin
      logic [ADDR_WIDTH-1:0] addr;
      logic [DATA_WIDTH-1:0] wr_data;
      logic [DATA_WIDTH-1:0] rd_data;
      logic [STRB_WIDTH-1:0] strb;
      bit slverr;

      for (int unsigned iter = 0; iter < 64; iter++) begin
        addr    = ADDR_WIDTH'($urandom_range(16'h3FFF, 16'h0000));
        wr_data = DATA_WIDTH'($urandom);
        strb    = STRB_WIDTH'($urandom);
        if (strb == '0) strb = '1;  // Ensure at least one byte strobe

        master_vip.write(addr, wr_data, strb, slverr, '0);
        assert(!slverr) else $error("Mem VIP random write returned error at iter %0d", iter);

        master_vip.read(addr, rd_data, slverr, '0);
        assert(!slverr) else $error("Mem VIP random read returned error at iter %0d", iter);

        // Apply strobe mask to expected data
        for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
          if (!strb[byte_idx]) begin
            rd_data[8*byte_idx +: 8] = '0;
          end
        end
        wr_data = apply_wstrb(wr_data, strb);

        assert(rd_data == wr_data)
          else $error("Mem VIP random access mismatch at iter %0d addr=%h exp=%h got=%h strb=%h",
                      iter, addr, wr_data, rd_data, strb);
      end
      $display("[%0t] Mem VIP random access stress completed: 64 iterations", $time);
    end

    `TEST_CASE("Mem VIP Back-to-Back Transactions") begin
      logic [ADDR_WIDTH-1:0] addr;
      logic [DATA_WIDTH-1:0] wr_data;
      logic [DATA_WIDTH-1:0] rd_data;
      bit slverr;

      // Write then immediately read the same address (no idle between)
      for (int unsigned idx = 0; idx < 32; idx++) begin
        addr    = build_addr(idx);
        wr_data = build_data(idx);

        master_vip.write(addr, wr_data, '1, slverr, '0);
        assert(!slverr) else $error("Mem VIP b2b write returned error at %0d", idx);

        master_vip.read(addr, rd_data, slverr, '0);
        assert(!slverr) else $error("Mem VIP b2b read returned error at %0d", idx);
        assert(rd_data == wr_data)
          else $error("Mem VIP b2b mismatch at %0d exp=%h got=%h", idx, wr_data, rd_data);
      end
      $display("[%0t] Mem VIP back-to-back transactions completed: 32 iterations", $time);
    end

    `TEST_CASE("Mem VIP Initial State Zero") begin
      logic [ADDR_WIDTH-1:0] addr;
      logic [DATA_WIDTH-1:0] rd_data;
      bit slverr;

      // Verify memory is zero after initial reset (before any writes)
      for (int unsigned idx = 0; idx < 16; idx++) begin
        addr = build_addr(idx);
        master_vip.read(addr, rd_data, slverr, '0);
        assert(!slverr) else $error("Mem VIP initial-state read returned error at %0d", idx);
        assert(rd_data == '0)
          else $error("Mem VIP initial-state: memory not zero at %0d addr=%h got=%h",
                      idx, addr, rd_data);
      end
      $display("[%0t] Mem VIP initial state verified: 16 locations zero after reset", $time);
    end

    `TEST_CASE("Mem VIP Idle No Activity") begin
      logic [DATA_WIDTH-1:0] rd_data;
      bit slverr;
      int idle_cycles;

      // Keep bus idle for many cycles, verify no spurious activity
      master_vip.idle();
      idle_cycles = 0;
      repeat (100) begin
        @(posedge clk);
        idle_cycles++;
        // prdata should remain 0 when idle (mem_vip drives it)
        if (apb_link.prdata !== '0) begin
          $error("Mem VIP idle: unexpected prdata=%h at cycle %0d", apb_link.prdata, idle_cycles);
        end
      end
      $display("[%0t] Mem VIP idle no activity verified: %0d cycles with no spurious bus activity",
               $time, idle_cycles);
    end

  end

endmodule
