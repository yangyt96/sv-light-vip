`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_lite_master_vip.sv"
`include "axi4_lite_slave_vip.sv"

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
  axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH) m_axil_if(clk, rstn);

  axi4_lite_dut #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) dut (
    .aclk         (clk),
    .aresetn      (rstn),
    .s_axil_awaddr(s_axil_if.awaddr),
    .s_axil_awprot(s_axil_if.awprot),
    .s_axil_awvalid(s_axil_if.awvalid),
    .s_axil_awready(s_axil_if.awready),
    .s_axil_wdata (s_axil_if.wdata),
    .s_axil_wstrb (s_axil_if.wstrb),
    .s_axil_wvalid(s_axil_if.wvalid),
    .s_axil_wready(s_axil_if.wready),
    .s_axil_bresp (s_axil_if.bresp),
    .s_axil_bvalid(s_axil_if.bvalid),
    .s_axil_bready(s_axil_if.bready),
    .s_axil_araddr(s_axil_if.araddr),
    .s_axil_arprot(s_axil_if.arprot),
    .s_axil_arvalid(s_axil_if.arvalid),
    .s_axil_arready(s_axil_if.arready),
    .s_axil_rdata (s_axil_if.rdata),
    .s_axil_rresp (s_axil_if.rresp),
    .s_axil_rvalid(s_axil_if.rvalid),
    .s_axil_rready(s_axil_if.rready),
    .m_axil_awaddr(m_axil_if.awaddr),
    .m_axil_awprot(m_axil_if.awprot),
    .m_axil_awvalid(m_axil_if.awvalid),
    .m_axil_awready(m_axil_if.awready),
    .m_axil_wdata (m_axil_if.wdata),
    .m_axil_wstrb (m_axil_if.wstrb),
    .m_axil_wvalid(m_axil_if.wvalid),
    .m_axil_wready(m_axil_if.wready),
    .m_axil_bresp (m_axil_if.bresp),
    .m_axil_bvalid(m_axil_if.bvalid),
    .m_axil_bready(m_axil_if.bready),
    .m_axil_araddr(m_axil_if.araddr),
    .m_axil_arprot(m_axil_if.arprot),
    .m_axil_arvalid(m_axil_if.arvalid),
    .m_axil_arready(m_axil_if.arready),
    .m_axil_rdata (m_axil_if.rdata),
    .m_axil_rresp (m_axil_if.rresp),
    .m_axil_rvalid(m_axil_if.rvalid),
    .m_axil_rready(m_axil_if.rready)
  );

  Axi4LiteMasterVIP #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH) master;
  Axi4LiteSlaveVIP  #(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH) slave;

  function automatic logic [ADDR_WIDTH-1:0] build_addr(int unsigned index);
    return logic'(index * STRB_WIDTH);
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

  function automatic logic [DATA_WIDTH-1:0] build_rdata(int unsigned index);
    return (32'h1234_0000 | (index * 3));
  endfunction

  task automatic run_write_transfer(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] strb;
    logic [1:0]            master_resp;
    logic [ADDR_WIDTH-1:0] slave_addr;
    logic [DATA_WIDTH-1:0] slave_data;
    logic [STRB_WIDTH-1:0] slave_strb;
    logic [2:0]            slave_prot;

    addr = build_addr(index);
    data = build_wdata(index);
    strb = build_wstrb(index);

    fork
      master.write(addr, data, strb, master_resp);
      slave.handle_write(slave_addr, slave_data, slave_strb, slave_prot, 2'b00);
    join

    assert(master_resp == 2'b00) else $error("Write response mismatch at %0d", index);
    assert(slave_addr == addr) else $error("Write address mismatch at %0d", index);
    assert(slave_data == data) else $error("Write data mismatch at %0d", index);
    assert(slave_strb == strb) else $error("Write strobe mismatch at %0d", index);
    assert(slave_prot == 3'b000) else $error("Write prot mismatch at %0d", index);
  endtask

  task automatic run_read_transfer(input int unsigned index);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] expected_data;
    logic [DATA_WIDTH-1:0] master_data;
    logic [1:0]            master_resp;
    logic [ADDR_WIDTH-1:0] slave_addr;
    logic [2:0]            slave_prot;

    addr          = build_addr(index + WRITE_STIMULUS_CNT);
    expected_data = build_rdata(index);

    fork
      master.read(addr, master_data, master_resp);
      slave.handle_read(slave_addr, slave_prot, expected_data, 2'b00);
    join

    assert(master_resp == 2'b00) else $error("Read response mismatch at %0d", index);
    assert(master_data == expected_data) else $error("Read data mismatch at %0d", index);
    assert(slave_addr == addr) else $error("Read address mismatch at %0d", index);
    assert(slave_prot == 3'b000) else $error("Read prot mismatch at %0d", index);
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

    m_axil_if.awready = 1'b0;
    m_axil_if.wready  = 1'b0;
    m_axil_if.bresp   = '0;
    m_axil_if.bvalid  = 1'b0;
    m_axil_if.arready = 1'b0;
    m_axil_if.rdata   = '0;
    m_axil_if.rresp   = '0;
    m_axil_if.rvalid  = 1'b0;
  end

  `TEST_SUITE begin
    int unsigned idx;

    master = new(s_axil_if.master, "axil_master_vip");
    slave  = new(m_axil_if.slave, "axil_slave_vip");

    @(posedge rstn);
    @(posedge clk);

    master.configure_pause_generator(1'b0);
    slave.configure_backpressure(1'b0);
    for (idx = 0; idx < WRITE_STIMULUS_CNT; idx++) begin
      run_write_transfer(idx);
    end

    master.configure_pause_generator(1'b1, 1, 3);
    slave.configure_backpressure(1'b1, 1, 3);
    for (idx = 0; idx < READ_STIMULUS_CNT; idx++) begin
      run_read_transfer(idx);
    end
  end

endmodule
