`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_lite_master_vip.sv"
`include "axi4_lite_mem_vip.sv"

module axi4_lite_dut_tb;

  import vunit_pkg::*;

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
  axi4_lite_mem_vip mem_vip (
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
    return (32'hABCD_0000 | index);
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

    master.write(addr, data, strb, master_resp);

    assert(master_resp == 2'b00) else $error("Write response mismatch at %0d", index);
  endtask

  task automatic run_read_transfer(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] expected_data;
    logic [DATA_WIDTH-1:0] master_data;
    logic [1:0]            master_resp;

    addr          = build_write_addr(index);
    expected_data = apply_wstrb(build_wdata(index), build_wstrb(index));

    master.read(addr, master_data, master_resp);

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

    master = new(s_axil_if.master, "axil_master_vip");

    @(posedge rstn);
    @(posedge clk);

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

endmodule
