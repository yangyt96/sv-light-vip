// Simple AXI Stream Slave DUT for testing the Master VIP
// This DUT simply accepts and counts data transfers
module axis_slave_dut #(
    parameter int DATA_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,
    
    // AXI Stream Slave Port
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic                  s_axis_tlast,
    input  logic [DATA_WIDTH/8-1:0] s_axis_tstrb,
    input  logic [DATA_WIDTH/8-1:0] s_axis_tkeep,
    input  logic [3:0]            s_axis_tuser,
    
    // Status outputs for verification
    output logic [31:0]           transfer_count,
    output logic [31:0]           error_count,
    output logic [DATA_WIDTH-1:0] last_data
);
    
    // Simple slave - always ready
    assign s_axis_tready = 1'b1;

    // Count transfers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transfer_count <= 32'h0;
            error_count <= 32'h0;
            last_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                transfer_count <= transfer_count + 1;
                last_data <= s_axis_tdata;
                
                // Check for protocol violations (simple check)
                if (s_axis_tstrb == 0) begin
                    error_count <= error_count + 1;
                end
            end
        end
    end

endmodule // axis_slave_dut
