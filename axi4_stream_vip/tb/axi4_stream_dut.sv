module axi4_stream_dut #(
  parameter DATA_WIDTH = 32,
  parameter KEEP_WIDTH = DATA_WIDTH/8,
  parameter TID_WIDTH = 8,
  parameter TDEST_WIDTH = 8,
  parameter TUSER_WIDTH = 32
)(
  input  logic                   aclk,
  input  logic                   aresetn,

  // AXI-Stream slave (input)
  input  logic [DATA_WIDTH-1:0]  s_axis_tdata,
  input  logic                   s_axis_tvalid,
  output logic                   s_axis_tready,
  input  logic [KEEP_WIDTH-1:0]  s_axis_tkeep,
  input  logic [KEEP_WIDTH-1:0]  s_axis_tstrb,
  input  logic                   s_axis_tlast,
  input  logic [TID_WIDTH-1:0]   s_axis_tid,
  input  logic [TDEST_WIDTH-1:0] s_axis_tdest,
  input  logic [TUSER_WIDTH-1:0] s_axis_tuser,

  // AXI-Stream master (output)
  output logic [DATA_WIDTH-1:0]  m_axis_tdata,
  output logic                   m_axis_tvalid,
  input  logic                   m_axis_tready,
  output logic [KEEP_WIDTH-1:0]  m_axis_tkeep,
  output logic [KEEP_WIDTH-1:0]  m_axis_tstrb,
  output logic                   m_axis_tlast,
  output logic [TID_WIDTH-1:0]   m_axis_tid,
  output logic [TDEST_WIDTH-1:0] m_axis_tdest,
  output logic [TUSER_WIDTH-1:0] m_axis_tuser
);

  // One-stage AXI Stream pipeline.
  // Data is accepted whenever the output register is empty or the current beat
  // is consumed in the same cycle.
  assign s_axis_tready = !m_axis_tvalid || m_axis_tready;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      m_axis_tdata  <= '0;
      m_axis_tvalid <= 1'b0;
      m_axis_tkeep  <= '0;
      m_axis_tstrb  <= '0;
      m_axis_tlast  <= 1'b0;
      m_axis_tid    <= '0;
      m_axis_tdest  <= '0;
      m_axis_tuser  <= '0;
    end else begin
      if (s_axis_tready) begin
        m_axis_tvalid <= s_axis_tvalid;

        if (s_axis_tvalid) begin
          m_axis_tdata  <= s_axis_tdata;
          m_axis_tkeep  <= s_axis_tkeep;
          m_axis_tstrb  <= s_axis_tstrb;
          m_axis_tlast  <= s_axis_tlast;
          m_axis_tid    <= s_axis_tid;
          m_axis_tdest  <= s_axis_tdest;
          m_axis_tuser  <= s_axis_tuser;
        end
      end
    end
  end

endmodule
