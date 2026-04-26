`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_full_if.sv"
`include "axi4_full_vip_pkg.sv"
`include "axi4_full_mem_vip.sv"

module axi4_full_vip_tb;

  import axi4_full_vip_pkg::*;

  localparam int ADDR_WIDTH   = 32;
  localparam int DATA_WIDTH   = 32;
  localparam int ID_WIDTH     = 4;
  localparam int STRB_WIDTH   = DATA_WIDTH / 8;
  localparam int MEM_BYTES    = 16384;

  logic clk;
  logic rstn;

  // Create interface instance
  axi4_full_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) axi_if (clk, rstn);

  // Memory VIP is the slave under test for the master VIP.
  axi4_full_mem_vip #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .MEM_BYTES(MEM_BYTES)
  ) mem_vip (
    .aclk             (clk),
    .aresetn          (rstn),
    .s_axi_awid       (axi_if.awid),
    .s_axi_awaddr     (axi_if.awaddr),
    .s_axi_awlen      (axi_if.awlen),
    .s_axi_awsize     (axi_if.awsize),
    .s_axi_awburst    (axi_if.awburst),
    .s_axi_awlock     (axi_if.awlock),
    .s_axi_awcache    (axi_if.awcache),
    .s_axi_awprot     (axi_if.awprot),
    .s_axi_awqos      (axi_if.awqos),
    .s_axi_awregion   (axi_if.awregion),
    .s_axi_awuser     (axi_if.awuser),
    .s_axi_awvalid    (axi_if.awvalid),
    .s_axi_awready    (axi_if.awready),
    .s_axi_wdata      (axi_if.wdata),
    .s_axi_wstrb      (axi_if.wstrb),
    .s_axi_wlast      (axi_if.wlast),
    .s_axi_wuser      (axi_if.wuser),
    .s_axi_wvalid     (axi_if.wvalid),
    .s_axi_wready     (axi_if.wready),
    .s_axi_bid        (axi_if.bid),
    .s_axi_bresp      (axi_if.bresp),
    .s_axi_buser      (axi_if.buser),
    .s_axi_bvalid     (axi_if.bvalid),
    .s_axi_bready     (axi_if.bready),
    .s_axi_arid       (axi_if.arid),
    .s_axi_araddr     (axi_if.araddr),
    .s_axi_arlen      (axi_if.arlen),
    .s_axi_arsize     (axi_if.arsize),
    .s_axi_arburst    (axi_if.arburst),
    .s_axi_arlock     (axi_if.arlock),
    .s_axi_arcache    (axi_if.arcache),
    .s_axi_arprot     (axi_if.arprot),
    .s_axi_arqos      (axi_if.arqos),
    .s_axi_arregion   (axi_if.arregion),
    .s_axi_aruser     (axi_if.aruser),
    .s_axi_arvalid    (axi_if.arvalid),
    .s_axi_arready    (axi_if.arready),
    .s_axi_rid        (axi_if.rid),
    .s_axi_rdata      (axi_if.rdata),
    .s_axi_rresp      (axi_if.rresp),
    .s_axi_rlast      (axi_if.rlast),
    .s_axi_ruser      (axi_if.ruser),
    .s_axi_rvalid     (axi_if.rvalid),
    .s_axi_rready     (axi_if.rready)
  );

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

  function automatic logic [DATA_WIDTH-1:0] build_data(input int unsigned index);
    return DATA_WIDTH'(32'hA500_1000 + (index * 32'h0001_0101));
  endfunction

  function automatic logic [DATA_WIDTH-1:0] apply_wstrb(
    input logic [DATA_WIDTH-1:0] old_data,
    input logic [DATA_WIDTH-1:0] new_data,
    input logic [STRB_WIDTH-1:0] strb
  );
    logic [DATA_WIDTH-1:0] result;
    begin
      result = old_data;
      for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
        if (strb[byte_idx]) begin
          result[(8 * byte_idx) +: 8] = new_data[(8 * byte_idx) +: 8];
        end
      end
      return result;
    end
  endfunction

  task automatic check_single_read(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] expected_data,
    input logic [ID_WIDTH-1:0]   id = '0
  );
    logic [DATA_WIDTH-1:0] read_data;
    logic [1:0]            resp;
    begin
      master_vip.read(.addr(addr), .data(read_data), .resp(resp), .id(id));
      assert(resp == 2'b00) else $error("Read response mismatch addr=%h resp=%0h", addr, resp);
      assert(read_data == expected_data)
        else $error("Read data mismatch addr=%h exp=%h got=%h", addr, expected_data, read_data);
    end
  endtask

  // Test stimulus
  `TEST_SUITE
  begin
    // Initialize master VIP
    master_vip = new(axi_if.master, "MASTER_VIP_0");
    master_vip.clear_outputs();
    master_vip.configure_pause_generator(.enable(1'b0));

    // Wait for reset
    wait(rstn);
    repeat (5) @(posedge clk);

    `TEST_CASE("Simple Write-Read")
    begin
      logic [1:0] resp;
      $display("\n=== AXI4 Full VIP Testbench Started ===");
      $display("\n--- Test 1: Simple Write-Read ---");

      master_vip.write(
        .addr(32'h1000),
        .data(32'hDEADBEEF),
        .strb(4'hF),
        .id(4'd0),
        .len(8'd0),
        .resp(resp)
      );
      assert(resp == 2'b00) else $error("Write response mismatch resp=%0h", resp);
      check_single_read(32'h1000, 32'hDEADBEEF, 4'd0);
    end

    `TEST_CASE("Multiple Write-Reads")
    begin
      logic [1:0] resp;
      $display("\n--- Test 2: Multiple Writes ---");
      for (int i = 0; i < 4; i++) begin
        master_vip.write(
          .addr(32'h2000 + (i * 4)),
          .data(32'h11223300 + i),
          .strb(4'hF),
          .id(i[3:0]),
          .resp(resp)
        );
        assert(resp == 2'b00) else $error("Write response mismatch index=%0d resp=%0h", i, resp);
        check_single_read(32'h2000 + (i * 4), 32'h11223300 + i, i[3:0]);
        repeat (2) @(posedge clk);
      end
    end

    `TEST_CASE("Partial Write Byte Mask")
    begin
      logic [1:0] resp;
      logic [DATA_WIDTH-1:0] expected_data;
      $display("\n--- Test 4: Partial Write (Byte 1-2) ---");
      master_vip.write(
        .addr(32'h3000),
        .data(32'hFFFF0000),
        .strb(4'hF),
        .id(4'd0),
        .resp(resp)
      );
      assert(resp == 2'b00) else $error("Initial write response mismatch resp=%0h", resp);
      master_vip.write(
        .addr(32'h3000),
        .data(32'h12345678),
        .strb(4'b0110),  // Only bytes 1 and 2
        .id(4'd0),
        .resp(resp)
      );
      assert(resp == 2'b00) else $error("Partial write response mismatch resp=%0h", resp);
      expected_data = apply_wstrb(32'hFFFF0000, 32'h12345678, 4'b0110);
      check_single_read(32'h3000, expected_data, 4'd0);
    end

    `TEST_CASE("INCR Burst Write-Read")
    begin
      logic [DATA_WIDTH-1:0] wr_data [];
      logic [STRB_WIDTH-1:0] wr_strb [];
      logic [DATA_WIDTH-1:0] rd_data [];
      logic [1:0]            rd_resp [];
      logic [1:0]            resp;

      $display("\n--- Test 5: INCR Burst Write-Read ---");
      wr_data = new[4];
      wr_strb = new[4];
      rd_data = new[4];
      rd_resp = new[4];
      for (int i = 0; i < 4; i++) begin
        wr_data[i] = build_data(i);
        wr_strb[i] = '1;
      end

      master_vip.write_burst(
        .addr(32'h4000),
        .data(wr_data),
        .strb(wr_strb),
        .id(4'd5),
        .burst(2'b01),
        .resp(resp)
      );
      assert(resp == 2'b00) else $error("INCR burst write response mismatch resp=%0h", resp);

      master_vip.read_burst(
        .addr(32'h4000),
        .beat_count(4),
        .data(rd_data),
        .resp(rd_resp),
        .id(4'd5),
        .burst(2'b01)
      );

      for (int i = 0; i < 4; i++) begin
        assert(rd_resp[i] == 2'b00) else $error("INCR burst read response mismatch beat=%0d", i);
        assert(rd_data[i] == wr_data[i])
          else $error("INCR burst data mismatch beat=%0d exp=%h got=%h", i, wr_data[i], rd_data[i]);
      end
    end

    `TEST_CASE("FIXED Burst Byte Mask")
    begin
      logic [DATA_WIDTH-1:0] wr_data [];
      logic [STRB_WIDTH-1:0] wr_strb [];
      logic [1:0]            resp;
      logic [DATA_WIDTH-1:0] expected_data;

      $display("\n--- Test 6: FIXED Burst Byte Mask ---");
      wr_data = new[3];
      wr_strb = new[3];
      wr_data[0] = 32'h000000AA; wr_strb[0] = 4'b0001;
      wr_data[1] = 32'h0000BB00; wr_strb[1] = 4'b0010;
      wr_data[2] = 32'h00CC0000; wr_strb[2] = 4'b0100;

      master_vip.write_burst(
        .addr(32'h5000),
        .data(wr_data),
        .strb(wr_strb),
        .id(4'd6),
        .burst(2'b00),
        .resp(resp)
      );
      assert(resp == 2'b00) else $error("FIXED burst write response mismatch resp=%0h", resp);

      expected_data = 32'h00CCBBAA;
      check_single_read(32'h5000, expected_data, 4'd6);
    end

    `TEST_CASE("Multiple Outstanding Writes")
    begin
      logic [1:0] resp[4];
      logic [31:0] data[1];
      logic [3:0]  strb[1];
      $display("\n--- Test 7: Multiple Outstanding Writes ---");
      fork
        begin
          master_vip.write_awchannel(.addr(32'h6000), .id(4'd0));
          master_vip.write_awchannel(.addr(32'h6004), .id(4'd1));
          master_vip.write_awchannel(.addr(32'h6008), .id(4'd2));
          master_vip.write_awchannel(.addr(32'h600C), .id(4'd3));
        end

        begin
          strb[0] = 4'hF;
          for(int i = 0; i < 4; i++) begin
            data[0] = 32'h11111111 * (i+1);
            master_vip.write_wchannel(.data(data), .strb(strb));
          end
        end

        begin
          master_vip.write_bchannel(.resp(resp[0]));
          master_vip.write_bchannel(.resp(resp[1]));
          master_vip.write_bchannel(.resp(resp[2]));
          master_vip.write_bchannel(.resp(resp[3]));
        end
      join
      
      for (int i = 0; i < 4; i++) begin
        assert(resp[i] == 2'b00) else $error("Outstanding write response mismatch id=%0d resp=%0h", i, resp[i]);
      end
      
      check_single_read(32'h6000, 32'h11111111, 4'd0);
      check_single_read(32'h6004, 32'h22222222, 4'd1);
      check_single_read(32'h6008, 32'h33333333, 4'd2);
      check_single_read(32'h600C, 32'h44444444, 4'd3);
    end

    `TEST_CASE("Multiple Outstanding Reads")
    begin
      logic [DATA_WIDTH-1:0] rd_data[4];
      logic [DATA_WIDTH-1:0] data[];
      logic [1:0] rd_resp[4];
      logic [1:0] resp[];
      data = new[1];
      resp = new[1];
      $display("\n--- Test 8: Multiple Outstanding Reads ---");
      
      master_vip.write(.addr(32'h6000), .data(32'h11111111), .resp(resp[0]));
      master_vip.write(.addr(32'h6004), .data(32'h22222222), .resp(resp[0]));
      master_vip.write(.addr(32'h6008), .data(32'h33333333), .resp(resp[0]));
      master_vip.write(.addr(32'h600C), .data(32'h44444444), .resp(resp[0]));

      fork

        begin
          master_vip.read_archannel(.addr(32'h6000), .id(4'd0));
          master_vip.read_archannel(.addr(32'h6004), .id(4'd1));
          master_vip.read_archannel(.addr(32'h6008), .id(4'd2));
          master_vip.read_archannel(.addr(32'h600C), .id(4'd3));
        end

        begin
          for(int i = 0; i < 4; i++) begin
            master_vip.read_rchannel(.data(data), .resp(resp), .id(i));
            rd_data[i] = data[0];
            rd_resp[i] = resp[0];
          end
        end

      join

      for (int i = 0; i < 4; i++) begin
        assert(rd_resp[i] == 2'b00) else $error("Outstanding read response mismatch id=%0d resp=%0h", i, rd_resp[i]);
      end
      
      assert(rd_data[0] == 32'h11111111) else $error("Outstanding read data mismatch id=0 exp=%h got=%h", 32'h11111111, rd_data[0]);
      assert(rd_data[1] == 32'h22222222) else $error("Outstanding read data mismatch id=1 exp=%h got=%h", 32'h22222222, rd_data[1]);
      assert(rd_data[2] == 32'h33333333) else $error("Outstanding read data mismatch id=2 exp=%h got=%h", 32'h33333333, rd_data[2]);
      assert(rd_data[3] == 32'h44444444) else $error("Outstanding read data mismatch id=3 exp=%h got=%h", 32'h44444444, rd_data[3]);
    end

    `TEST_CASE("Mixed Outstanding Read-Write")
    begin
      logic [1:0] wr_resp[2];
      logic [DATA_WIDTH-1:0] rd_data[2];
      logic [1:0] rd_resp[2];
      $display("\n--- Test 9: Mixed Outstanding Read-Write ---");

      // init mem
      master_vip.write(.addr(32'h6000), .data(32'h11111111), .strb(4'hF), .id(4'd0), .resp(wr_resp[0]));
      master_vip.write(.addr(32'h6004), .data(32'h22222222), .strb(4'hF), .id(4'd0), .resp(wr_resp[0]));

      // start test
      fork
        master_vip.write(.addr(32'h7000), .data(32'hAABBCCDD), .strb(4'hF), .id(4'd0), .resp(wr_resp[0]));
        master_vip.read(.addr(32'h6000), .data(rd_data[0]), .resp(rd_resp[0]), .id(4'd1));
      join
      fork
        master_vip.write(.addr(32'h7004), .data(32'h11223344), .strb(4'hF), .id(4'd2), .resp(wr_resp[1]));
        master_vip.read(.addr(32'h6004), .data(rd_data[1]), .resp(rd_resp[1]), .id(4'd3));
      join
      
      for (int i = 0; i < 2; i++) begin
        assert(wr_resp[i] == 2'b00) else $error("Mixed outstanding write response mismatch id=%0d resp=%0h", i, wr_resp[i]);
        assert(rd_resp[i] == 2'b00) else $error("Mixed outstanding read response mismatch id=%0d resp=%0h", i, rd_resp[i]);
      end
      
      assert(rd_data[0] == 32'h11111111) else $error("Mixed outstanding read data mismatch id=1 exp=%h got=%h", 32'h11111111, rd_data[0]);
      assert(rd_data[1] == 32'h22222222) else $error("Mixed outstanding read data mismatch id=3 exp=%h got=%h", 32'h22222222, rd_data[1]);
      
      check_single_read(32'h7000, 32'hAABBCCDD, 4'd0);
      check_single_read(32'h7004, 32'h11223344, 4'd2);
    end
  end

endmodule
