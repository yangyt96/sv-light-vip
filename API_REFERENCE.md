# API Reference

Quick reference for all VIP APIs in `sv-light-vip`.

---

## Table of Contents

- [APB VIP](#apb-vip)
- [AXI4-Lite VIP](#axi4-lite-vip)
- [AXI4-Full VIP](#axi4-full-vip)
- [AXI4-Stream VIP](#axi4-stream-vip)
- [UART VIP](#uart-vip)
- [SPI VIP](#spi-vip)
- [I2C VIP](#i2c-vip)
- [I2S VIP](#i2s-vip)

---

## APB VIP

### Master VIP — [`apb_master_vip.sv`](apb_vip/sim/apb_master_vip.sv)

| Method | Description |
|--------|-------------|
| `write(addr, data, strb, slverr, prot)` | APB write transaction |
| `read(addr, data, slverr, prot)` | APB read transaction |
| `configure_pause_generator(enable, min_cycles, max_cycles)` | Configure random delay between transactions |
| `configure_timeout(cycles)` | Set transaction timeout |

### Slave VIP — [`apb_slave_vip.sv`](apb_vip/sim/apb_slave_vip.sv)

| Method | Description |
|--------|-------------|
| `expect_write(addr, data, strb, prot, slverr)` | Expect an APB write, optionally inject error |
| `respond_read(read_data, addr, prot, slverr)` | Respond to an APB read, optionally inject error |
| `configure_backpressure(enable, min_cycles, max_cycles)` | Configure PREADY stall (random delay) |
| `configure_timeout(cycles)` | Set transaction timeout |

### Memory VIP (hardware module) — [`apb_mem_vip.sv`](apb_vip/sim/apb_mem_vip.sv)

| Parameter | Description |
|-----------|-------------|
| `ADDR_WIDTH` | Address bus width |
| `DATA_WIDTH` | Data bus width |
| `STRB_WIDTH` | Byte strobe width |
| `MEM_BYTES` | Memory depth in bytes |

Synthesizable APB slave with byte-addressed storage, zero-wait-state response, and `PSTRB` support.

---

## AXI4-Lite VIP

### Master VIP — [`axi4_lite_master_vip.sv`](axi4_lite_vip/sim/axi4_lite_master_vip.sv)

#### High-level APIs

| Method | Description |
|--------|-------------|
| `write(addr, data, strb, resp, prot)` | AXI4-Lite write transaction (AW + W + B) |
| `read(addr, data, resp, prot)` | AXI4-Lite read transaction (AR + R) |

#### Channel-level APIs (fine-grained control)

| Method | Description |
|--------|-------------|
| `send_awchn(addr, prot)` | Send write address |
| `send_wchn(data, strb)` | Send write data |
| `recv_bchn(resp)` | Receive write response |
| `send_archn(addr, prot)` | Send read address |
| `recv_rchn(data, resp)` | Receive read data |

#### Configuration

| Method | Description |
|--------|-------------|
| `configure_pause_generator(enable, min_cycles, max_cycles)` | Configure random delay between transactions |
| `configure_timeout(cycles)` | Set transaction timeout |
| `clear_outputs()` | Initialize all driven signals to zero |

### Memory VIP (hardware module) — [`axi4_lite_mem_vip.sv`](axi4_lite_vip/sim/axi4_lite_mem_vip.sv)

| Parameter | Description |
|-----------|-------------|
| `ADDR_WIDTH` | Address bus width |
| `DATA_WIDTH` | Data bus width |
| `STRB_WIDTH` | Byte strobe width |
| `MEM_BYTES` | Memory depth in bytes |

Synthesizable AXI4-Lite slave with byte-addressed storage and `WSTRB` support.

---

## AXI4-Full VIP

### Master VIP — [`axi4_full_master_vip.sv`](axi4_full_vip/sim/axi4_full_master_vip.sv)

#### High-level APIs

| Method | Description |
|--------|-------------|
| `write(addr, data, strb, id, len, size, burst, prot, resp)` | Single-beat write transaction |
| `read(addr, data, resp, id, len, size, burst, prot)` | Single-beat read transaction |
| `write_burst(addr, data[], strb[], id, size, burst, prot, resp)` | Burst write transaction |
| `read_burst(addr, beat_count, data[], resp[], id, size, burst, prot)` | Burst read transaction |

#### Channel-level APIs (fine-grained control)

| Method | Description |
|--------|-------------|
| `send_awchn(addr, beat_count, id, size, burst, prot)` | Send write address |
| `send_wchn(data[], strb[])` | Send write data (all beats) |
| `recv_bchn(resp)` | Receive write response |
| `send_archn(addr, beat_count, id, size, burst, prot)` | Send read address |
| `recv_rchn(data[], resp[], id)` | Receive read data (all beats) |

#### Configuration

| Method | Description |
|--------|-------------|
| `configure_pause_generator(enable, min_cycles, max_cycles)` | Configure random delay between transactions |
| `configure_timeout(cycles)` | Set transaction timeout |

### Slave VIP — [`axi4_full_slave_vip.sv`](axi4_full_vip/sim/axi4_full_slave_vip.sv)

| Method | Description |
|--------|-------------|
| `recv_awchn(addr, beat_count, id, size, burst, prot)` | Receive write address |
| `recv_wchn(data[], strb[])` | Receive write data (all beats) |
| `send_bchn(resp)` | Send write response |
| `recv_archn(addr, beat_count, id, size, burst, prot)` | Receive read address |
| `send_rchn(data[], resp[], id)` | Send read data (all beats) |
| `configure_backpressure(enable, min_cycles, max_cycles)` | Configure random stall on all channels |
| `configure_timeout(cycles)` | Set transaction timeout |

### Memory VIP (hardware module) — [`axi4_full_mem_vip.sv`](axi4_full_vip/sim/axi4_full_mem_vip.sv)

| Parameter | Description |
|-----------|-------------|
| `ID_WIDTH` | ID bus width |
| `ADDR_WIDTH` | Address bus width |
| `DATA_WIDTH` | Data bus width |
| `STRB_WIDTH` | Byte strobe width |
| `MEM_BYTES` | Memory depth in bytes |

Synthesizable AXI4-Full slave with byte-addressed storage, burst address progression (`FIXED`/`INCR`/`WRAP`), and `WSTRB` support.

---

## AXI4-Stream VIP

### Master VIP — [`axi4_stream_master_vip.sv`](axi4_stream_vip/sim/axi4_stream_master_vip.sv)

| Method | Description |
|--------|-------------|
| `transmit(tdata, tkeep, tstrb, tlast, tid, tdest, tuser)` | Transmit a stream packet |
| `configure_pause_generator(enable, min_cycles, max_cycles)` | Configure random TVALID de-assertion |

### Slave VIP — [`axi4_stream_slave_vip.sv`](axi4_stream_vip/sim/axi4_stream_slave_vip.sv)

| Method | Description |
|--------|-------------|
| `receive(tdata, tkeep, tstrb, tlast, tid, tdest, tuser)` | Receive a stream packet |
| `configure_backpressure(enable, min_cycles, max_cycles)` | Configure random TREADY de-assertion |

---

## UART VIP

### Transmitter — [`uart_tx_vip.sv`](uart_vip/sim/uart_tx_vip.sv)

| Method | Description |
|--------|-------------|
| `transmit(data)` | Transmit a byte (8N1, LSB first) |
| `configure_pause_generator(enable, min_cycles, max_cycles)` | Configure random inter-frame delay |
| `configure_timeout(cycles)` | Set transaction timeout |

### Receiver — [`uart_rx_vip.sv`](uart_vip/sim/uart_rx_vip.sv)

| Method | Description |
|--------|-------------|
| `receive(data, framing_error)` | Receive a byte, report framing error |
| `configure_timeout(cycles)` | Set transaction timeout |

### Parameters

| Parameter | Description | Valid Range |
|-----------|-------------|-------------|
| `CLKS_PER_BIT` | Clock cycles per UART bit period | >= 4 |
| `PARITY_MODE` | Parity configuration (0=none, 1=odd, 2=even) | 0-2 |

---

## SPI VIP

### Master — [`spi_master_vip.sv`](spi_vip/sim/spi_master_vip.sv)

| Method | Description |
|--------|-------------|
| `transfer(tx_data, rx_data)` | Full-duplex SPI transfer |
| `configure_pause_generator(enable, min_cycles, max_cycles)` | Configure random inter-transfer delay |
| `configure_timeout(cycles)` | Set transaction timeout |

### Slave — [`spi_slave_vip.sv`](spi_vip/sim/spi_slave_vip.sv)

| Method | Description |
|--------|-------------|
| `transfer(tx_data, rx_data)` | Full-duplex SPI transfer |
| `configure_timeout(cycles)` | Set transaction timeout |

### Parameters

| Parameter | Description | Valid Range |
|-----------|-------------|-------------|
| `DATA_BITS` | Number of data bits per transfer | > 0 |
| `CPOL` | Clock polarity (0=idle low, 1=idle high) | 0 or 1 |
| `CPHA` | Clock phase (0=leading edge, 1=trailing edge) | 0 or 1 |

---

## I2C VIP

### Master — [`i2c_master_vip.sv`](i2c_vip/sim/i2c_master_vip.sv)

| Method | Description |
|--------|-------------|
| `write_byte(address, data, address_ack, data_ack)` | Write a byte to a slave |
| `read_byte(address, data, address_ack)` | Read a byte from a slave |
| `configure_timeout(cycles)` | Set transaction timeout |

### Slave — [`i2c_slave_vip.sv`](i2c_vip/sim/i2c_slave_vip.sv)

| Method | Description |
|--------|-------------|
| `expect_write(data, address_match)` | Expect a write byte from master |
| `respond_read(data, address_match, master_ack)` | Respond with a read byte |
| `configure_timeout(cycles)` | Set transaction timeout |

### Parameters

| Parameter | Description | Valid Range |
|-----------|-------------|-------------|
| `HALF_SCL_CYCLES` | Clock cycles for half SCL period | > 0 |

---

## I2S VIP

### Transmitter — [`i2s_tx_vip.sv`](i2s_vip/sim/i2s_tx_vip.sv)

| Method | Description |
|--------|-------------|
| `transmit(left_sample, right_sample)` | Transmit stereo frame |
| `configure_pause_generator(enable, min_cycles, max_cycles)` | Configure random inter-frame delay |
| `configure_timeout(cycles)` | Set transaction timeout |

### Receiver — [`i2s_rx_vip.sv`](i2s_vip/sim/i2s_rx_vip.sv)

| Method | Description |
|--------|-------------|
| `receive(left_sample, right_sample, frame_error)` | Receive stereo frame |
| `configure_timeout(cycles)` | Set transaction timeout |

### Parameters

| Parameter | Description | Valid Range |
|-----------|-------------|-------------|
| `SAMPLE_WIDTH` | Audio sample width in bits | > 0 |

---

## Common Configuration Patterns

### Pause Generator (Master-side)

Used by: APB Master, AXI4-Lite Master, AXI4-Full Master, AXI4-Stream Master, UART TX, SPI Master, I2S TX

```systemverilog
vip.configure_pause_generator(1, 0, 10);  // Random delay 0-10 cycles between transactions
vip.configure_pause_generator(0);          // Disable (no delay)
```

### Backpressure (Slave-side)

Used by: APB Slave, AXI4-Full Slave, AXI4-Stream Slave

```systemverilog
vip.configure_backpressure(1, 1, 5);       // Random stall 1-5 cycles
vip.configure_backpressure(0);             // Disable (no stall)
```

### Timeout

Used by: All VIPs

```systemverilog
vip.configure_timeout(5000);               // 5000 clock cycles before timeout
```
