// apb_mem_vip.sv
// Hardware memory module (NOT a software class).
// Must be `included and instantiated directly in the testbench.
// Simple APB memory slave with byte-addressed storage.
// Parameterized for ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH, and MEM_BYTES

`timescale 1ns / 1ps

module apb_mem_vip #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8,
    parameter int MEM_BYTES  = 4096
) (
    input  logic                  pclk,
    input  logic                  presetn,
    input  logic [ADDR_WIDTH-1:0] paddr,
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [DATA_WIDTH-1:0] pwdata,
    input  logic [STRB_WIDTH-1:0] pstrb,
    input  logic [           2:0] pprot,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pready,
    output logic                  pslverr
);

  // Byte-addressed memory storage
  byte unsigned mem[MEM_BYTES];

  // Address index helper
  function automatic int unsigned mem_index(input logic [ADDR_WIDTH-1:0] addr);
    return int'(addr % MEM_BYTES);
  endfunction

  // Read a word from byte-addressed memory
  function automatic logic [DATA_WIDTH-1:0] read_word(input logic [ADDR_WIDTH-1:0] addr);
    logic [DATA_WIDTH-1:0] data;
    begin
      data = '0;
      for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
        data[(8*byte_idx)+:8] = mem[mem_index(addr+byte_idx)];
      end
      return data;
    end
  endfunction

  // Write a word to byte-addressed memory with byte strobes
  task automatic write_word(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                            input logic [STRB_WIDTH-1:0] strb);
    for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
      if (strb[byte_idx]) begin
        mem[mem_index(addr+byte_idx)] = data[(8*byte_idx)+:8];
      end
    end
  endtask

  // Initialize memory
  initial begin
    for (int i = 0; i < MEM_BYTES; i++) begin
      mem[i] = '0;
    end
  end

  // APB slave state machine
  //
  // APB transfer sequence:
  //   IDLE: psel=0
  //   SETUP: psel=1, penable=0  (address phase)
  //   ACCESS: psel=1, penable=1  (data phase) -> pready=1 completes transfer
  //
  // State machine:
  //   IDLE -> (psel=1 & !penable) -> SETUP -> (penable=1) -> ACCESS -> IDLE
  //
  // Zero-wait-state operation: pready=1 in ACCESS phase on first cycle.

  typedef enum logic [1:0] {
    ST_IDLE  = 2'b00,
    ST_WRITE = 2'b01,
    ST_READ  = 2'b10
  } state_t;

  state_t state, next_state;
  logic [ADDR_WIDTH-1:0] latched_addr;
  logic [DATA_WIDTH-1:0] latched_wdata;
  logic [STRB_WIDTH-1:0] latched_strb;

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (psel && !penable) begin
          if (pwrite) begin
            next_state = ST_WRITE;
          end else begin
            next_state = ST_READ;
          end
        end
      end

      ST_WRITE: begin
        if (psel && penable) begin
          next_state = ST_IDLE;
        end
      end

      ST_READ: begin
        if (psel && penable) begin
          next_state = ST_IDLE;
        end
      end

      default: begin
        next_state = ST_IDLE;
      end
    endcase
  end

  // Sequential logic
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      state         <= ST_IDLE;
      latched_addr  <= '0;
      latched_wdata <= '0;
      latched_strb  <= '0;
      prdata        <= '0;
      pready        <= 1'b0;
      pslverr       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        ST_IDLE: begin
          pready  <= 1'b0;
          pslverr <= 1'b0;

          if (psel && !penable) begin
            // Latch address/control in SETUP phase
            latched_addr  <= paddr;
            latched_wdata <= pwdata;
            latched_strb  <= pstrb;

            if (!pwrite) begin
              // For read: provide data immediately for ACCESS phase
              prdata <= read_word(paddr);
            end
          end
        end

        ST_WRITE: begin
          if (psel && penable) begin
            // ACCESS phase - perform write
            write_word(latched_addr, latched_wdata, latched_strb);
            pready  <= 1'b1;
            pslverr <= 1'b0;
          end
        end

        ST_READ: begin
          if (psel && penable) begin
            // ACCESS phase - data already provided, assert ready
            pready  <= 1'b1;
            pslverr <= 1'b0;
          end
        end

        default: begin
          pready  <= 1'b0;
          pslverr <= 1'b0;
        end
      endcase
    end
  end

endmodule
