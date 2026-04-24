`timescale 1ns/1ps

`include "vunit_defines.svh"
`include "axi4_stream_master_vip.sv"
`include "axi4_stream_slave_vip.sv"

module axi4_stream_dut_tb;

  import vunit_pkg::*;

  localparam int DATA_WIDTH                = 64;
  localparam int KEEP_WIDTH                = DATA_WIDTH / 8;
  localparam int BASIC_STIMULUS_COUNT      = 48;
  localparam int PAUSE_STIMULUS_COUNT      = 40;
  localparam int BP_STIMULUS_COUNT         = 40;
  localparam int CONTINUOUS_STIMULUS_COUNT = 64;

  logic clk;
  logic rstn;

  axi4_stream_if #(DATA_WIDTH, KEEP_WIDTH) s_axis_if(clk, rstn);
  axi4_stream_if #(DATA_WIDTH, KEEP_WIDTH) m_axis_if(clk, rstn);

  axi4_stream_dut #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH)
  ) dut (
    .aclk(clk),
    .aresetn(rstn),
    .s_axis_tdata (s_axis_if.tdata),
    .s_axis_tvalid(s_axis_if.tvalid),
    .s_axis_tready(s_axis_if.tready),
    .s_axis_tkeep (s_axis_if.tkeep),
    .s_axis_tstrb (s_axis_if.tstrb),
    .s_axis_tlast (s_axis_if.tlast),
    .s_axis_tid   (s_axis_if.tid),
    .s_axis_tdest (s_axis_if.tdest),
    .s_axis_tuser (s_axis_if.tuser),
    .m_axis_tdata (m_axis_if.tdata),
    .m_axis_tvalid(m_axis_if.tvalid),
    .m_axis_tready(m_axis_if.tready),
    .m_axis_tkeep (m_axis_if.tkeep),
    .m_axis_tstrb (m_axis_if.tstrb),
    .m_axis_tlast (m_axis_if.tlast),
    .m_axis_tid   (m_axis_if.tid),
    .m_axis_tdest (m_axis_if.tdest),
    .m_axis_tuser (m_axis_if.tuser)
  );

  AxiStreamMasterVIP #(DATA_WIDTH, KEEP_WIDTH) master;
  AxiStreamSlaveVIP  #(DATA_WIDTH, KEEP_WIDTH) slave;

  function automatic logic [DATA_WIDTH-1:0] build_tdata(int unsigned index);
    logic [DATA_WIDTH-1:0] value;
    int byte_idx;
    begin
      value = '0;
      for (byte_idx = 0; byte_idx < KEEP_WIDTH; byte_idx++) begin
        value[(byte_idx * 8) +: 8] = byte'((index * 13) + byte_idx);
      end
      return value;
    end
  endfunction

  function automatic logic [KEEP_WIDTH-1:0] build_byte_mask(int unsigned index);
    logic [KEEP_WIDTH-1:0] mask;
    int active_bytes;
    int byte_idx;
    begin
      mask = '0;
      active_bytes = (index % KEEP_WIDTH) + 1;
      for (byte_idx = 0; byte_idx < active_bytes; byte_idx++) begin
        mask[byte_idx] = 1'b1;
      end
      return mask;
    end
  endfunction

  task automatic run_transfer(input int unsigned index);
    logic [DATA_WIDTH-1:0] exp_tdata;
    logic [KEEP_WIDTH-1:0] exp_tkeep;
    logic [KEEP_WIDTH-1:0] exp_tstrb;
    bit                    exp_tlast;
    byte                   exp_tid;
    byte                   exp_tdest;
    int unsigned           exp_tuser;
    logic [DATA_WIDTH-1:0] rx_tdata;
    logic [KEEP_WIDTH-1:0] rx_tkeep;
    logic [KEEP_WIDTH-1:0] rx_tstrb;
    bit                    rx_tlast;
    byte                   rx_tid;
    byte                   rx_tdest;
    int unsigned           rx_tuser;

    exp_tdata = build_tdata(index);
    exp_tkeep = build_byte_mask(index);
    exp_tstrb = build_byte_mask(index + 1);
    exp_tlast = ((index % 8) == 7);
    exp_tid   = byte'(index);
    exp_tdest = byte'(8'h80 | (index & 'h7f));
    exp_tuser = 32'h8765_0000 | index;

    fork
      master.transmit(exp_tdata,
                             exp_tkeep,
                             exp_tstrb,
                             exp_tlast,
                             exp_tid,
                             exp_tdest,
                             exp_tuser);
      slave.receive(rx_tdata,
                           rx_tkeep,
                           rx_tstrb,
                           rx_tlast,
                           rx_tid,
                           rx_tdest,
                           rx_tuser);
    join

    assert(rx_tdata == exp_tdata) else $error("Data mismatch at stimulus %0d", index);
    assert(rx_tkeep == exp_tkeep) else $error("TKEEP mismatch at stimulus %0d", index);
    assert(rx_tstrb == exp_tstrb) else $error("TSTRB mismatch at stimulus %0d", index);
    assert(rx_tlast == exp_tlast) else $error("TLAST mismatch at stimulus %0d", index);
    assert(rx_tid == exp_tid) else $error("TID mismatch at stimulus %0d", index);
    assert(rx_tdest == exp_tdest) else $error("TDEST mismatch at stimulus %0d", index);
    assert(rx_tuser == exp_tuser) else $error("TUSER mismatch at stimulus %0d", index);

    @(posedge clk);
  endtask

  task automatic drive_stream(input int unsigned start_index,
                              input int unsigned transfer_count);
    int unsigned stimulus_idx;

    for (stimulus_idx = start_index;
         stimulus_idx < (start_index + transfer_count);
         stimulus_idx++) begin
      master.transmit(build_tdata(stimulus_idx),
                             build_byte_mask(stimulus_idx),
                             build_byte_mask(stimulus_idx + 1),
                             ((stimulus_idx % 8) == 7),
                             byte'(stimulus_idx),
                             byte'(8'h80 | (stimulus_idx & 'h7f)),
                             (32'h8765_0000 | stimulus_idx));
    end
  endtask

  task automatic monitor_continuous_stream(input int unsigned expected_count,
                                           output int unsigned observed_count,
                                           output int unsigned observed_last_count);
    int unsigned last_seen_tid;
    int unsigned last_seen_tlast_count;
    begin
      observed_count = 0;
      last_seen_tid = 0;
      last_seen_tlast_count = 0;
      m_axis_if.tready = 1'b1;

      while (observed_count < expected_count) begin
        @(posedge clk);
        if (m_axis_if.tvalid && m_axis_if.tready) begin
          observed_count++;
          last_seen_tid = m_axis_if.tid;
          if (m_axis_if.tlast) begin
            last_seen_tlast_count++;
          end
        end
      end

      observed_last_count = last_seen_tlast_count;
      assert(last_seen_tid == (expected_count - 1))
        else $error("Continuous stream last TID mismatch exp=%0d got=%0d",
                    expected_count - 1, last_seen_tid);
      m_axis_if.tready = 1'b0;
      @(posedge clk);
    end
  endtask

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rstn = 0;
    #20 rstn = 1;
  end

  initial begin
    s_axis_if.tvalid = 1'b0;
    s_axis_if.tdata  = '0;
    s_axis_if.tkeep  = '0;
    s_axis_if.tstrb  = '0;
    s_axis_if.tlast  = 1'b0;
    s_axis_if.tid    = '0;
    s_axis_if.tdest  = '0;
    s_axis_if.tuser  = '0;
    m_axis_if.tready = 1'b0;
  end

  `TEST_SUITE begin
    int unsigned stimulus_idx;
    int unsigned observed_count;
    int unsigned observed_tlast_count;

    master = new(s_axis_if.master, "master_vip");
    slave  = new(m_axis_if.slave, "slave_vip");

    @(posedge rstn);
    @(posedge clk);

    master.configure_pause_generator(1'b0);
    slave.configure_backpressure(1'b0);
    for (stimulus_idx = 0; stimulus_idx < BASIC_STIMULUS_COUNT; stimulus_idx++) begin
      run_transfer(stimulus_idx);
    end

    master.configure_pause_generator(1'b1, 1, 4);
    slave.configure_backpressure(1'b0);
    for (stimulus_idx = BASIC_STIMULUS_COUNT;
         stimulus_idx < (BASIC_STIMULUS_COUNT + PAUSE_STIMULUS_COUNT);
         stimulus_idx++) begin
      run_transfer(stimulus_idx);
    end

    master.configure_pause_generator(1'b0);
    slave.configure_backpressure(1'b1, 2, 6);
    for (stimulus_idx = (BASIC_STIMULUS_COUNT + PAUSE_STIMULUS_COUNT);
         stimulus_idx < (BASIC_STIMULUS_COUNT + PAUSE_STIMULUS_COUNT + BP_STIMULUS_COUNT);
         stimulus_idx++) begin
      run_transfer(stimulus_idx);
    end

    master.configure_pause_generator(1'b0);
    slave.configure_backpressure(1'b0);
    fork
      drive_stream(0, CONTINUOUS_STIMULUS_COUNT);
      monitor_continuous_stream(CONTINUOUS_STIMULUS_COUNT,
                                observed_count,
                                observed_tlast_count);
    join

    assert(observed_count == CONTINUOUS_STIMULUS_COUNT)
      else $error("Continuous stream count mismatch exp=%0d got=%0d",
                  CONTINUOUS_STIMULUS_COUNT, observed_count);
    assert(observed_tlast_count == (CONTINUOUS_STIMULUS_COUNT / 8))
      else $error("Continuous stream TLAST count mismatch exp=%0d got=%0d",
                  CONTINUOUS_STIMULUS_COUNT / 8, observed_tlast_count);
  end

endmodule
