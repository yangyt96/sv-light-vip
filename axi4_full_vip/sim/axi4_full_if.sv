// AXI4 Full Interface
// Implements AXI4 full protocol with write address, write data, write response,
// read address, and read data channels with full feature support

interface axi4_full_if #(
  parameter int ADDR_WIDTH    = 32,
  parameter int DATA_WIDTH    = 32,
  parameter int ID_WIDTH      = 4,
  parameter int LEN_WIDTH     = 8,
  parameter int SIZE_WIDTH    = 3,
  parameter int BURST_WIDTH   = 2,
  parameter int LOCK_WIDTH    = 1,
  parameter int CACHE_WIDTH   = 4,
  parameter int PROT_WIDTH    = 3,
  parameter int QOS_WIDTH     = 4,
  parameter int REGION_WIDTH  = 4,
  parameter int STRB_WIDTH    = DATA_WIDTH / 8,
  parameter int AWUSER_WIDTH  = 1,
  parameter int WUSER_WIDTH   = 1,
  parameter int BUSER_WIDTH   = 1,
  parameter int ARUSER_WIDTH  = 1,
  parameter int RUSER_WIDTH   = 1
) (
  input logic aclk,
  input logic aresetn
);

  // ============ Write Address Channel (AW) ============
  logic [ID_WIDTH-1:0]      awid;        // Write address ID
  logic [ADDR_WIDTH-1:0]    awaddr;      // Write address
  logic [LEN_WIDTH-1:0]     awlen;       // Burst length (0-255)
  logic [SIZE_WIDTH-1:0]    awsize;      // Burst size (2^size bytes)
  logic [BURST_WIDTH-1:0]   awburst;     // Burst type (0=FIXED, 1=INCR, 2=WRAP)
  logic [LOCK_WIDTH-1:0]    awlock;      // Atomic access
  logic [CACHE_WIDTH-1:0]   awcache;     // Cache policy
  logic [PROT_WIDTH-1:0]    awprot;      // Protection type
  logic [QOS_WIDTH-1:0]     awqos;       // Quality of Service
  logic [REGION_WIDTH-1:0]  awregion;    // Region identifier
  logic [AWUSER_WIDTH-1:0]  awuser;      // User sideband signals
  logic                     awvalid;     // Write address valid
  logic                     awready;     // Write address ready

  // ============ Write Data Channel (W) ============
  logic [DATA_WIDTH-1:0]    wdata;       // Write data
  logic [STRB_WIDTH-1:0]    wstrb;       // Write strobes (byte enables)
  logic                     wlast;       // Last transfer in burst
  logic [WUSER_WIDTH-1:0]   wuser;       // User sideband signals
  logic                     wvalid;      // Write data valid
  logic                     wready;      // Write data ready

  // ============ Write Response Channel (B) ============
  logic [ID_WIDTH-1:0]      bid;         // Write response ID
  logic [1:0]               bresp;       // Write response (0=OKAY, 1=EXOKAY, 2=SLVERR, 3=DECERR)
  logic [BUSER_WIDTH-1:0]   buser;       // User sideband signals
  logic                     bvalid;      // Write response valid
  logic                     bready;      // Write response ready

  // ============ Read Address Channel (AR) ============
  logic [ID_WIDTH-1:0]      arid;        // Read address ID
  logic [ADDR_WIDTH-1:0]    araddr;      // Read address
  logic [LEN_WIDTH-1:0]     arlen;       // Burst length (0-255)
  logic [SIZE_WIDTH-1:0]    arsize;      // Burst size (2^size bytes)
  logic [BURST_WIDTH-1:0]   arburst;     // Burst type (0=FIXED, 1=INCR, 2=WRAP)
  logic [LOCK_WIDTH-1:0]    arlock;      // Atomic access
  logic [CACHE_WIDTH-1:0]   arcache;     // Cache policy
  logic [PROT_WIDTH-1:0]    arprot;      // Protection type
  logic [QOS_WIDTH-1:0]     arqos;       // Quality of Service
  logic [REGION_WIDTH-1:0]  arregion;    // Region identifier
  logic [ARUSER_WIDTH-1:0]  aruser;      // User sideband signals
  logic                     arvalid;     // Read address valid
  logic                     arready;     // Read address ready

  // ============ Read Data Channel (R) ============
  logic [ID_WIDTH-1:0]      rid;         // Read data ID
  logic [DATA_WIDTH-1:0]    rdata;       // Read data
  logic [1:0]               rresp;       // Read response (0=OKAY, 1=EXOKAY, 2=SLVERR, 3=DECERR)
  logic                     rlast;       // Last transfer in burst
  logic [RUSER_WIDTH-1:0]   ruser;       // User sideband signals
  logic                     rvalid;      // Read data valid
  logic                     rready;      // Read data ready

  // Master modport
  modport master (
    input  aclk, aresetn,
    // Write Address
    output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser, awvalid,
    input  awready,
    // Write Data
    output wdata, wstrb, wlast, wuser, wvalid,
    input  wready,
    // Write Response
    input  bid, bresp, buser, bvalid,
    output bready,
    // Read Address
    output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arregion, aruser, arvalid,
    input  arready,
    // Read Data
    input  rid, rdata, rresp, rlast, ruser, rvalid,
    output rready
  );

  // Slave modport
  modport slave (
    input  aclk, aresetn,
    // Write Address
    input  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser, awvalid,
    output awready,
    // Write Data
    input  wdata, wstrb, wlast, wuser, wvalid,
    output wready,
    // Write Response
    output bid, bresp, buser, bvalid,
    input  bready,
    // Read Address
    input  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arregion, aruser, arvalid,
    output arready,
    // Read Data
    output rid, rdata, rresp, rlast, ruser, rvalid,
    input  rready
  );

endinterface
