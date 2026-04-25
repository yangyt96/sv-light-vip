# I2S VIP

## Overview

`i2s_vip` is a lightweight I2S Verification IP written with SystemVerilog
classes and verified with VUnit. It follows the direct VIP-to-VIP style used by
`uart_vip`, `spi_vip`, and `i2c_vip`.

The VIP currently includes:

- A three-wire I2S interface: `bclk`, `ws`, and `sd`
- A transmitter VIP with `transmit`
- A receiver VIP with `receive`
- Stereo frame support with `WS=0` for left and `WS=1` for right
- MSB-first sample transfer with one I2S lead bit before each channel MSB
- Transaction timeout protection
- A self-checking VUnit testbench and ModelSim waveform setup

## Folder Structure

```text
i2s_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── i2s_if.sv
│   ├── i2s_rx_vip.sv
│   ├── i2s_tx_vip.sv
│   └── i2s_vip_pkg.sv
├── tb/
│   ├── i2s_vip_tb.do
│   ├── i2s_vip_tb.sv
│   └── run.py
```

## Main APIs

```systemverilog
tx_vip.transmit(left_sample, right_sample);
rx_vip.receive(left_sample, right_sample, frame_error);
```

## Running the Simulation

From the project root:

```bash
python3 i2s_vip/tb/run.py
```

With Docker:

```bash
docker run --rm -v "$PWD":/work -w /work/i2s_vip/tb modelsim:20.1 python3 run.py
```
