# SPI VIP

## Overview

`spi_vip` is a lightweight SPI Verification IP written with SystemVerilog
classes and verified with VUnit. It follows the same direct VIP-to-VIP style as
`uart_vip`, so the master and slave VIPs can be connected through a shared SPI
interface without a DUT.

The VIP currently includes:

- A four-wire SPI interface: `sclk`, `cs_n`, `mosi`, and `miso`
- A master VIP with `transfer`
- A slave VIP with `transfer`
- SPI mode 0 behavior by default: `CPOL=0`, `CPHA=0`
- MSB-first full-duplex transfers
- Transaction logging to the simulator CLI
- A VUnit testbench with exact transfer checks, a constant 10 us inter-transfer
  gap, and continuous transfer coverage

## Folder Structure

```text
spi_vip/
├── doc/
│   └── README.md
├── sim/
│   ├── spi_if.sv
│   ├── spi_master_vip.sv
│   └── spi_slave_vip.sv
├── tb/
│   ├── spi_vip_tb.do
│   └── spi_vip_tb.sv
└── run.py
```

## Main Components

### `spi_if.sv`

Defines the shared SPI signals and modports:

- `master`: drives `sclk`, `cs_n`, and `mosi`; samples `miso`
- `slave`: samples `sclk`, `cs_n`, and `mosi`; drives `miso`

### `SpiMasterVIP`

The master VIP controls chip select and serial clock.

Main API:

```systemverilog
master_vip.transfer(tx_data, rx_data);
```

### `SpiSlaveVIP`

The slave VIP waits for `cs_n` assertion, samples `mosi`, and shifts response
data on `miso`.

Main API:

```systemverilog
slave_vip.transfer(tx_data, rx_data);
```

## Running the Simulation

From the project root:

```bash
python3 spi_vip/tb/run.py
```

With the provided Docker image:

```bash
docker run --rm -v "$PWD":/work -w /work/spi_vip/tb modelsim:20.1 python3 run.py
```
