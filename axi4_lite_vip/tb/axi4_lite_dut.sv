module axi4_lite_dut #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int STRB_WIDTH = DATA_WIDTH / 8
) (
  input  logic                  aclk,
  input  logic                  aresetn,

  input  logic [ADDR_WIDTH-1:0] s_axil_awaddr,
  input  logic [2:0]            s_axil_awprot,
  input  logic                  s_axil_awvalid,
  output logic                  s_axil_awready,

  input  logic [DATA_WIDTH-1:0] s_axil_wdata,
  input  logic [STRB_WIDTH-1:0] s_axil_wstrb,
  input  logic                  s_axil_wvalid,
  output logic                  s_axil_wready,

  output logic [1:0]            s_axil_bresp,
  output logic                  s_axil_bvalid,
  input  logic                  s_axil_bready,

  input  logic [ADDR_WIDTH-1:0] s_axil_araddr,
  input  logic [2:0]            s_axil_arprot,
  input  logic                  s_axil_arvalid,
  output logic                  s_axil_arready,

  output logic [DATA_WIDTH-1:0] s_axil_rdata,
  output logic [1:0]            s_axil_rresp,
  output logic                  s_axil_rvalid,
  input  logic                  s_axil_rready,

  output logic [ADDR_WIDTH-1:0] m_axil_awaddr,
  output logic [2:0]            m_axil_awprot,
  output logic                  m_axil_awvalid,
  input  logic                  m_axil_awready,

  output logic [DATA_WIDTH-1:0] m_axil_wdata,
  output logic [STRB_WIDTH-1:0] m_axil_wstrb,
  output logic                  m_axil_wvalid,
  input  logic                  m_axil_wready,

  input  logic [1:0]            m_axil_bresp,
  input  logic                  m_axil_bvalid,
  output logic                  m_axil_bready,

  output logic [ADDR_WIDTH-1:0] m_axil_araddr,
  output logic [2:0]            m_axil_arprot,
  output logic                  m_axil_arvalid,
  input  logic                  m_axil_arready,

  input  logic [DATA_WIDTH-1:0] m_axil_rdata,
  input  logic [1:0]            m_axil_rresp,
  input  logic                  m_axil_rvalid,
  output logic                  m_axil_rready
);

  assign m_axil_awaddr  = s_axil_awaddr;
  assign m_axil_awprot  = s_axil_awprot;
  assign m_axil_awvalid = s_axil_awvalid;
  assign s_axil_awready = m_axil_awready;

  assign m_axil_wdata   = s_axil_wdata;
  assign m_axil_wstrb   = s_axil_wstrb;
  assign m_axil_wvalid  = s_axil_wvalid;
  assign s_axil_wready  = m_axil_wready;

  assign s_axil_bresp   = m_axil_bresp;
  assign s_axil_bvalid  = m_axil_bvalid;
  assign m_axil_bready  = s_axil_bready;

  assign m_axil_araddr  = s_axil_araddr;
  assign m_axil_arprot  = s_axil_arprot;
  assign m_axil_arvalid = s_axil_arvalid;
  assign s_axil_arready = m_axil_arready;

  assign s_axil_rdata   = m_axil_rdata;
  assign s_axil_rresp   = m_axil_rresp;
  assign s_axil_rvalid  = m_axil_rvalid;
  assign m_axil_rready  = s_axil_rready;

endmodule
