# UART VIP

## Overview

`uart_vip` is a lightweight UART Verification IP written with SystemVerilog
classes and verified with VUnit. It follows the same class-based style as
`axi4_stream_vip`, but the transmitter and receiver can be connected directly
through a UART interface without a DUT.

The VIP currently includes:

- A single-wire UART interface
- A transmitter VIP with `transmit`
- A receiver VIP with `receive`
- 8N1 frame support, LSB first
- Transaction logging to the simulator CLI
- A VUnit testbench with exact frame checks, a constant 10 us inter-frame gap,
  and continuous frame coverage

## Folder Structure

```text
uart_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── uart_if.sv
│   ├── uart_rx_vip.sv
│   └── uart_tx_vip.sv
├── tb/
│   ├── uart_vip_tb.do
│   └── uart_vip_tb.sv
└── run.py
```

## Main Components

### `uart_if.sv`

Defines the shared UART serial line and modports:

- `transmitter`: drives `tx`
- `receiver`: samples `tx`

The UART line is idle high.

### `UartTxVIP`

The transmitter VIP is a class-based UART source.

Main API:

```systemverilog
tx_vip.transmit(data);
```

### `UartRxVIP`

The receiver VIP is a class-based UART sink.

Main API:

```systemverilog
rx_vip.receive(data, framing_error);
```

The receiver waits for a start bit, samples each data bit in the middle of the
bit period, and reports a framing error if the start or stop bit is invalid.

Basic UART has no ready/valid handshake, so this receiver does not provide
backpressure. Hardware flow control such as RTS/CTS can be modeled as an
optional extension if needed.

## Running the Simulation

From the project root:

```bash
python3 uart_vip/tb/run.py
```

With the provided Docker image:

```bash
docker run --rm -v "$PWD":/work -w /work/uart_vip/tb modelsim:20.1 python3 run.py
```
