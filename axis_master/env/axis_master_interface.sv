// AXI Stream Master Interface
// Implements the AXI Stream protocol as a master interface
`ifndef AXIS_MASTER_INTERFACE_SV
`define AXIS_MASTER_INTERFACE_SV

interface axis_master_interface #(
    parameter int DATA_WIDTH = `AXIS_DATA_WIDTH,
    parameter int ID_WIDTH = 0,
    parameter int DEST_WIDTH = 0
) (
    input logic clk,
    input logic rst_n
);

    // AXI Stream signals
    logic [DATA_WIDTH-1:0]   tdata;
    logic                    tvalid;
    logic                    tready;
    
    // Optional signals
    logic [DATA_WIDTH/8-1:0] tstrb;  // Byte strobes
    logic [DATA_WIDTH/8-1:0] tkeep;  // Byte enable
    logic                    tlast;  // Last transfer in burst
    logic [ID_WIDTH-1:0]     tid;    // ID, if enabled
    logic [DEST_WIDTH-1:0]   tdest;  // Destination, if enabled
    logic [3:0]              tuser;  // User-defined sideband

    // Modport for master (VIP driver)
    modport master (
        output tdata,
        output tvalid,
        output tstrb,
        output tkeep,
        output tlast,
        output tid,
        output tdest,
        output tuser,
        input  tready
    );

    // Modport for slave (DUT)
    modport slave (
        input  tdata,
        input  tvalid,
        input  tstrb,
        input  tkeep,
        input  tlast,
        input  tid,
        input  tdest,
        input  tuser,
        output tready
    );

    // Modport for monitor (passive observer)
    modport monitor (
        input tdata,
        input tvalid,
        input tready,
        input tstrb,
        input tkeep,
        input tlast,
        input tid,
        input tdest,
        input tuser
    );

endinterface

`endif // AXIS_MASTER_INTERFACE_SV
