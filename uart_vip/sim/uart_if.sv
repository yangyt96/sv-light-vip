interface uart_if(input logic clk,
                  input logic rstn);

  // UART line is idle high. One interface instance represents one serial link.
  logic tx;

  modport transmitter(input clk, rstn,
                      output tx);

  modport receiver(input clk, rstn, tx);

endinterface
