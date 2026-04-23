// AXI Stream Master VIP Defines
`ifndef AXIS_MASTER_DEFINES_SVH
`define AXIS_MASTER_DEFINES_SVH

// Default data width for AXI Stream
`ifndef AXIS_DATA_WIDTH
  `define AXIS_DATA_WIDTH 8
`endif

// Maximum data width
`define AXIS_MAX_DATA_WIDTH 128

// Enable features
`define AXIS_ENABLE_TSTRB
`define AXIS_ENABLE_TLAST
`define AXIS_ENABLE_TKEEP

`endif // AXIS_MASTER_DEFINES_SVH
