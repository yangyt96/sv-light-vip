# SV-Light VIP 知识蒸馏

> 版本: v1.0
> 用途: AI 快速理解 sv-light-vip 项目架构、公共设计模式和 VIP 元数据
> 关联文档: [`.agent/develop_workflow.md`](develop_workflow.md) — VIP 开发工作流
>          [`.agent/verification_workflow.md`](verification_workflow.md) — 验证工作流
>          [`API_REFERENCE.md`](../API_REFERENCE.md) — 完整 API 参考

---

## 1. 项目架构总览

### 1.1 核心理念

**Lightweight, class‑based SystemVerilog Verification IPs (UVM‑free)**

- 纯 SystemVerilog，基于 class，**无 UVM**（无 factory、无 phase、无 sequence）
- 每个 VIP 自包含：`sim/`（可复用组件）+ `tb/`（自检 testbench）+ `doc/`（文档）
- 所有 VIP 共享一致的设计模式和编码风格
- VUnit + ModelSim ASE 兼容

### 1.2 支持的 8 个 VIP

| VIP | 协议 | Master | Slave | Mem VIP (hw) | 关键特性 |
|-----|------|--------|-------|-------------|----------|
| [`apb_vip`](../apb_vip/) | APB | ✅ | ✅ | ✅ | 阻塞写/读、PREADY 背压、PSLVERR 注入、字节 strobe |
| [`axi4_lite_vip`](../axi4_lite_vip/) | AXI4-Lite | ✅ | ✅ | ✅ | 阻塞写/读、channel-level API、字节 strobe |
| [`axi4_full_vip`](../axi4_full_vip/) | AXI4-Full | ✅ | ✅ | ✅ | 单拍/突发、FIXED/INCR/WRAP、channel-level API |
| [`axi4_stream_vip`](../axi4_stream_vip/) | AXI4-Stream | ✅ | ✅ | ❌ | 发送/接收、TUSER/TID/TDEST/TKEEP/TSTRB |
| [`uart_vip`](../uart_vip/) | UART 8N1 | TX | RX | ❌ | 可配置波特率、奇偶校验、帧错误检测 |
| [`spi_vip`](../spi_vip/) | SPI | ✅ | ✅ | ❌ | 全双工、可配置 CPOL/CPHA |
| [`i2c_vip`](../i2c_vip/) | I2C | ✅ | ✅ | ❌ | 7-bit 地址、ACK/NACK、时钟拉伸、总线争用 |
| [`i2s_vip`](../i2s_vip/) | I2S 立体声 | TX | RX | ❌ | 立体声帧（L/R）、可配置采样位宽 |

### 1.3 文件组织规范

每个 VIP 遵循统一的目录结构：

```
vip_name/
├── doc/README.md          # VIP 专用文档
├── sim/
│   ├── vip_name_if.sv     # Interface（信号定义 + modport）
│   ├── vip_name_master_vip.sv  # Master 类（channel-level + high-level API）
│   ├── vip_name_slave_vip.sv   # Slave 类（对称 API + 背压）
│   ├── vip_name_mem_vip.sv     # 硬件 memory 模块（可选）
│   └── vip_name_vip_pkg.sv     # Package（`include` 所有类文件）
└── tb/
    ├── vip_name_vip_tb.sv       # 主 testbench
    ├── vip_name_mem_vip_tb.sv   # Mem VIP testbench（可选）
    ├── vip_name_tb.do           # ModelSim 波形配置（可选）
    └── run.py                   # VUnit 运行脚本
```

**编译顺序（依赖关系驱动）：**
1. Interface (`*_if.sv`) — 无依赖
2. 类文件 (`*_master_vip.sv`, `*_slave_vip.sv`) — 依赖 interface
3. Package (`*_vip_pkg.sv`) — `include` 所有类文件，最后编译

---

## 2. 公共设计模式

所有 VIP 共享以下设计模式，这是蒸馏的核心价值。

### 2.1 Pause Generator（Master 侧）

用于在事务之间插入随机延迟，模拟真实场景中的非连续传输。

**适用 VIP：** APB Master、AXI4-Lite Master、AXI4-Full Master、AXI4-Stream Master、UART TX、SPI Master、I2S TX

```systemverilog
// 启用随机暂停（0-10 周期延迟）
vip.configure_pause_generator(1, 0, 10);

// 禁用暂停
vip.configure_pause_generator(0);
```

**实现模式：**
```systemverilog
function void configure_pause_generator(
    bit enable,
    int unsigned min_cycles = 0,
    int unsigned max_cycles = 0
);
    pause_enable = enable;
    pause_min    = min_cycles;
    pause_max    = max_cycles;
endfunction

task apply_pause();
    if (pause_enable) begin
        int delay = $urandom_range(pause_max, pause_min);
        repeat (delay) @(posedge vif.clk);
    end
endtask
```

**调用位置：** 只在 high-level API 中调用（如 `write_req()`、`read_req()`），不在 channel-level API 中调用。

### 2.2 Backpressure（Slave 侧）

用于在响应中插入随机等待周期，模拟 Slave 的忙状态。

**适用 VIP：** APB Slave、AXI4-Lite Slave、AXI4-Full Slave、AXI4-Stream Slave

```systemverilog
// 启用随机背压（1-5 周期延迟）
vip.configure_backpressure(1, 1, 5);

// 禁用背压
vip.configure_backpressure(0);
```

**实现模式：**
```systemverilog
function void configure_backpressure(
    bit enable = 0,
    int unsigned min_cycles = 0,
    int unsigned max_cycles = 0
);
    stall_enable = enable;
    stall_min    = min_cycles;
    stall_max    = max_cycles;
endfunction

task apply_stall();
    if (stall_enable) begin
        int delay = $urandom_range(stall_max, stall_min);
        repeat (delay) @(posedge vif.clk);
    end
endtask
```

**调用位置：** 只在 high-level API 中调用（如 `write_resp_single()`、`read_resp_single()`），不在 channel-level API 中调用。这与 Master 的 `apply_pause()` 对称。

### 2.3 Timeout 机制

所有 VIP 都支持可配置的超时机制，防止仿真死锁。

```systemverilog
// 设置超时周期数
vip.configure_timeout(5000);  // 5000 时钟周期后超时
```

**实现模式：**
```systemverilog
function void configure_timeout(int unsigned cycles);
    timeout_cycles = cycles;
endfunction

task wait_ready();
    fork
        begin
            repeat (timeout_cycles) @(posedge vif.clk);
            $fatal(1, "[%s] TIMEOUT: waited %0d cycles", name, timeout_cycles);
        end
        begin
            @(posedge vif.pready);
        end
    join_any;
    disable fork;
endtask
```

### 2.4 clear_outputs

将所有驱动的输出信号初始化为默认状态（零或空闲状态）。在复位后必须调用。

```systemverilog
vip.clear_outputs();
```

### 2.5 wait_reset_release

等待复位信号释放（`rst` 或 `rst_n` 变为有效电平）。

```systemverilog
vip.wait_reset_release();
```

### 2.6 Master/Slave 对称架构

Master 和 Slave 的 API 保持对称：

| Master API | Slave API | 说明 |
|-----------|-----------|------|
| `send_awchn()` | `recv_awchn()` | 写地址通道 |
| `send_wchn()` | `recv_wchn()` | 写数据通道 |
| `recv_bchn()` | `send_bchn()` | 写响应通道 |
| `send_archn()` | `recv_archn()` | 读地址通道 |
| `recv_rchn()` | `send_rchn()` | 读数据通道 |
| `write_req_single()` | `write_resp_single()` | 单拍写（high-level） |
| `read_req_single()` | `read_resp_single()` | 单拍读（high-level） |

---

## 3. VIP 注册表（元数据）

### 3.1 组件列表

| VIP | 组件 | 类型 | 源文件 |
|-----|------|------|--------|
| `apb_vip` | `ApbMasterVIP` | class | [`apb_master_vip.sv`](../apb_vip/sim/apb_master_vip.sv) |
| | `ApbSlaveVIP` | class | [`apb_slave_vip.sv`](../apb_vip/sim/apb_slave_vip.sv) |
| | `apb_mem_vip` | hw_module | [`apb_mem_vip.sv`](../apb_vip/sim/apb_mem_vip.sv) |
| `axi4_lite_vip` | `Axi4LiteMasterVIP` | class | [`axi4_lite_master_vip.sv`](../axi4_lite_vip/sim/axi4_lite_master_vip.sv) |
| | `Axi4LiteSlaveVIP` | class | [`axi4_lite_slave_vip.sv`](../axi4_lite_vip/sim/axi4_lite_slave_vip.sv) |
| | `axi4_lite_mem_vip` | hw_module | [`axi4_lite_mem_vip.sv`](../axi4_lite_vip/sim/axi4_lite_mem_vip.sv) |
| `axi4_full_vip` | `Axi4FullMasterVIP` | class | [`axi4_full_master_vip.sv`](../axi4_full_vip/sim/axi4_full_master_vip.sv) |
| | `Axi4FullSlaveVIP` | class | [`axi4_full_slave_vip.sv`](../axi4_full_vip/sim/axi4_full_slave_vip.sv) |
| | `axi4_full_mem_vip` | hw_module | [`axi4_full_mem_vip.sv`](../axi4_full_vip/sim/axi4_full_mem_vip.sv) |
| `axi4_stream_vip` | `Axi4StreamMasterVIP` | class | [`axi4_stream_master_vip.sv`](../axi4_stream_vip/sim/axi4_stream_master_vip.sv) |
| | `Axi4StreamSlaveVIP` | class | [`axi4_stream_slave_vip.sv`](../axi4_stream_vip/sim/axi4_stream_slave_vip.sv) |
| `uart_vip` | `UartTxVIP` | class | [`uart_tx_vip.sv`](../uart_vip/sim/uart_tx_vip.sv) |
| | `UartRxVIP` | class | [`uart_rx_vip.sv`](../uart_vip/sim/uart_rx_vip.sv) |
| `spi_vip` | `SpiMasterVIP` | class | [`spi_master_vip.sv`](../spi_vip/sim/spi_master_vip.sv) |
| | `SpiSlaveVIP` | class | [`spi_slave_vip.sv`](../spi_vip/sim/spi_slave_vip.sv) |
| `i2c_vip` | `I2CMasterVIP` | class | [`i2c_master_vip.sv`](../i2c_vip/sim/i2c_master_vip.sv) |
| | `I2CSlaveVIP` | class | [`i2c_slave_vip.sv`](../i2c_vip/sim/i2c_slave_vip.sv) |
| `i2s_vip` | `I2STxVIP` | class | [`i2s_tx_vip.sv`](../i2s_vip/sim/i2s_tx_vip.sv) |
| | `I2SRxVIP` | class | [`i2s_rx_vip.sv`](../i2s_vip/sim/i2s_rx_vip.sv) |

### 3.2 参数默认值

| VIP | 参数 | 类型 | 默认值 | 说明 |
|-----|------|------|--------|------|
| `apb_vip` | `ADDR_WIDTH` | int | 16 | 地址总线宽度 |
| | `DATA_WIDTH` | int | 32 | 数据总线宽度 |
| `axi4_lite_vip` | `ADDR_WIDTH` | int | 32 | 地址总线宽度 |
| | `DATA_WIDTH` | int | 32 | 数据总线宽度 |
| `axi4_full_vip` | `ID_WIDTH` | int | 4 | ID 总线宽度 |
| | `ADDR_WIDTH` | int | 32 | 地址总线宽度 |
| | `DATA_WIDTH` | int | 32 | 数据总线宽度 |
| `axi4_stream_vip` | `DATA_WIDTH` | int | 64 | 数据总线宽度 |
| | `KEEP_WIDTH` | int | 8 | TKEEP 宽度 (= DATA_WIDTH/8) |
| `uart_vip` | `CLKS_PER_BIT` | int | 8 | 每 bit 时钟周期数（>= 4） |
| | `PARITY_MODE` | int | 0 | 0=none, 1=odd, 2=even |
| `spi_vip` | `DATA_BITS` | int | 8 | 每传输数据位数（> 0） |
| | `CPOL` | int | 0 | 时钟极性（0=idle low, 1=idle high） |
| | `CPHA` | int | 0 | 时钟相位（0=leading, 1=trailing） |
| `i2c_vip` | `HALF_SCL_CYCLES` | int | 25 | 半 SCL 周期时钟数（> 0） |
| `i2s_vip` | `SAMPLE_WIDTH` | int | 16 | 音频采样位宽（> 0） |

### 3.3 源文件列表

每个 VIP 的 `sim/` 目录包含以下源文件（按编译顺序）：

```python
# 通用模式
source_files = [
    VipSourceFile("*_if.sv",       is_interface=True),   # 1. Interface
    VipSourceFile("*_master_vip.sv"),                      # 2. Master 类
    VipSourceFile("*_slave_vip.sv"),                       # 3. Slave 类（如有）
    VipSourceFile("*_vip_pkg.sv",  is_package=True),       # 4. Package（最后）
]
```

### 3.4 接口信号定义

#### APB Interface (`apb_if`)

| 信号 | 方向 | 宽度 |
|------|------|------|
| `paddr` | input | ADDR_WIDTH |
| `psel` | input | 1 |
| `penable` | input | 1 |
| `pwrite` | input | 1 |
| `pwdata` | input | DATA_WIDTH |
| `pstrb` | input | STRB_WIDTH |
| `pprot` | input | PROT_WIDTH |
| `prdata` | output | DATA_WIDTH |
| `pready` | output | 1 |
| `pslverr` | output | 1 |

#### AXI4-Lite Interface (`axi4_lite_if`)

| 信号 | 方向 | 宽度 |
|------|------|------|
| `aclk` | input | 1 |
| `aresetn` | input | 1 |
| `awaddr` | input | ADDR_WIDTH |
| `awprot` | input | 3 |
| `awvalid` | input | 1 |
| `awready` | output | 1 |
| `wdata` | input | DATA_WIDTH |
| `wstrb` | input | STRB_WIDTH |
| `wvalid` | input | 1 |
| `wready` | output | 1 |
| `bresp` | output | 2 |
| `bvalid` | output | 1 |
| `bready` | input | 1 |
| `araddr` | input | ADDR_WIDTH |
| `arprot` | input | 3 |
| `arvalid` | input | 1 |
| `arready` | output | 1 |
| `rdata` | output | DATA_WIDTH |
| `rresp` | output | 2 |
| `rvalid` | output | 1 |
| `rready` | input | 1 |

#### AXI4-Full Interface (`axi4_full_if`)

包含 AXI4-Lite 的所有信号，外加：

| 信号 | 方向 | 宽度 |
|------|------|------|
| `awid` | input | ID_WIDTH |
| `awlen` | input | 8 |
| `awsize` | input | 3 |
| `awburst` | input | 2 |
| `awlock` | input | 1 |
| `awcache` | input | 4 |
| `awqos` | input | 4 |
| `awregion` | input | 4 |
| `awuser` | input | AWUSER_WIDTH |
| `wlast` | input | 1 |
| `wuser` | input | WUSER_WIDTH |
| `bid` | output | ID_WIDTH |
| `buser` | output | BUSER_WIDTH |
| `arid` | input | ID_WIDTH |
| `arlen` | input | 8 |
| `arsize` | input | 3 |
| `arburst` | input | 2 |
| `arlock` | input | 1 |
| `arcache` | input | 4 |
| `arqos` | input | 4 |
| `arregion` | input | 4 |
| `aruser` | input | ARUSER_WIDTH |
| `rid` | output | ID_WIDTH |
| `rlast` | output | 1 |
| `ruser` | output | RUSER_WIDTH |

#### AXI4-Stream Interface (`axi4_stream_if`)

| 信号 | 方向 | 宽度 |
|------|------|------|
| `aclk` | input | 1 |
| `aresetn` | input | 1 |
| `tdata` | input | DATA_WIDTH |
| `tkeep` | input | KEEP_WIDTH |
| `tstrb` | input | KEEP_WIDTH |
| `tuser` | input | TUSER_WIDTH |
| `tdest` | input | TDEST_WIDTH |
| `tid` | input | TID_WIDTH |
| `tlast` | input | 1 |
| `tvalid` | input | 1 |
| `tready` | output | 1 |

#### UART Interface (`uart_if`)

| 信号 | 方向 | 宽度 |
|------|------|------|
| `clk` | input | 1 |
| `rst` | input | 1 |
| `serial_data` | inout | 1 |

#### SPI Interface (`spi_if`)

| 信号 | 方向 | 宽度 |
|------|------|------|
| `clk` | input | 1 |
| `rst` | input | 1 |
| `sclk` | input | 1 |
| `cs` | input | 1 |
| `mosi` | input | 1 |
| `miso` | output | 1 |

#### I2C Interface (`i2c_if`)

| 信号 | 方向 | 宽度 |
|------|------|------|
| `clk` | input | 1 |
| `rst` | input | 1 |
| `scl` | inout | 1 |
| `sda` | inout | 1 |
| `master_scl_low` | input | 1 |
| `master_sda_low` | input | 1 |
| `slave_scl_low` | input | 1 |
| `slave_sda_low` | input | 1 |

#### I2S Interface (`i2s_if`)

| 信号 | 方向 | 宽度 |
|------|------|------|
| `clk` | input | 1 |
| `rst` | input | 1 |
| `bclk` | input | 1 |
| `ws` | input | 1 |
| `sd` | output | 1 |

---

## 4. Python 包集成

### 4.1 安装

```bash
pip install -e .                     # 从 repo 根目录可编辑安装
pip install -r requirements.txt      # 安装 MCP 依赖（可选）
```

### 4.2 VUnit 集成

```python
from sv_light_vip import add_vip_to_vunit, add_vip_sources
from vunit import VUnit

vu = VUnit.from_argv()
lib = vu.add_library("work")

# 添加单个 VIP
add_vip_to_vunit(vu, lib, "apb_vip")

# 或添加多个 VIP
add_vip_sources(vu, lib, ["apb_vip", "uart_vip", "i2c_vip"])
```

### 4.3 查询 VIP 元数据

```python
from sv_light_vip import list_vips, get_vip_info, get_vip_path

# 列出所有 VIP
for vip in list_vips():
    print(f"{vip.name}: {vip.description}")

# 获取详细信息
info = get_vip_info("apb_vip")
print(f"Path: {get_vip_path(info.name)}")
for comp in info.components:
    print(f"  Component: {comp.name} ({comp.comp_type})")
```

### 4.4 Python 包 API

| 函数 | 说明 |
|------|------|
| `list_vips()` | 返回所有 VIP 的 `VipInfo` 对象列表 |
| `get_vip_info(name)` | 获取指定 VIP 的 `VipInfo` |
| `get_vip_path(name)` | 获取 VIP 根目录绝对路径 |
| `get_vip_sim_path(name)` | 获取 VIP `sim/` 目录绝对路径 |
| `add_vip_to_vunit(vu, lib, name)` | 将 VIP 源文件添加到 VUnit 库 |
| `add_vip_sources(vu, lib, names)` | 批量添加多个 VIP 到 VUnit 库 |

---

## 5. MCP Server

### 5.1 启动

```bash
# stdio 模式（用于 Claude Desktop、Cursor 等）
python mcp_server/server.py

# SSE 模式（用于 Web 端工具）
python mcp_server/server.py --transport sse --port 8000
```

### 5.2 可用工具

| 工具 | 说明 |
|------|------|
| `list_vips` | 列出所有可用 VIP 及其组件 |
| `get_vip_info` | 获取 VIP 详细信息（组件、参数、路径） |
| `get_vip_api` | 获取 VIP 组件的方法签名 |
| `get_vip_interface` | 获取接口信号定义 |
| `generate_testbench` | 生成 SystemVerilog testbench 模板 |
| `generate_run_py` | 生成 VUnit `run.py` 脚本 |

### 5.3 Roo Code MCP 配置

```json
{
  "mcpServers": {
    "sv-light-vip": {
      "command": "python",
      "args": ["/path/to/sv-light-vip/mcp_server/server.py"]
    }
  }
}
```

---

## 6. 常见陷阱与最佳实践

### 6.1 SystemVerilog 语法注意

1. **数值字面量必须使用有效十六进制字符**（0-9, a-f, A-F），不能使用 ASCII 助记符
   - ❌ `32'hRESET_OK` — 非法
   - ✅ `32'hC0DE_CAFE` — 合法

2. **`output` 端口不能传递空参数**，必须声明局部变量
   - ❌ `slave.recv_awchn(.addr(), .prot())`
   - ✅ `slave.recv_awchn(.addr(tmp_addr), .prot(tmp_prot))`

3. **VIP 类内部参数在 testbench 中不可见**
   - VIP 类内部的 `localparam`（如 `LEN_WIDTH`）在 testbench 中不可见
   - 声明变量时必须使用具体位宽（如 `logic [7:0] tmp_len`）

4. **vif 信号驱动必须使用非阻塞赋值 (`<=`)**
   - ❌ `vif.pready = 1'b1;` — 阻塞赋值，可能导致竞争条件
   - ✅ `vif.pready <= 1'b1;` — 非阻塞赋值

5. **Assertion 优先使用合并条件而非 `if` 嵌套**
   - ❌ `if (tkeep.size() > 0) assert (tkeep.size() >= beat_count);`
   - ✅ `assert (tkeep.size() == 0 || tkeep.size() >= beat_count);`

### 6.2 设计原则

1. **保持 lightweight** — 不引入不必要的复杂性
2. **对称架构** — Master/Slave API 保持对称（`send_*` ↔ `recv_*`）
3. **向后兼容** — 新增功能时默认参数保持原有行为
4. **Mem VIP 保持简单** — 只做一件事，不要过度参数化
5. **背压只在 high-level API 中调用** — `apply_stall()` 不在 channel-level API 中调用

### 6.3 复位注意事项

1. **Mem VIP 的复位只重置状态机，不清零 memory 内容**
2. **复位后 slave VIP 必须调用 `clear_outputs()`** 恢复信号状态
3. **不要在复位期间让 master 等待 slave 响应**，会导致 `$fatal` 超时

---

## 7. 快速参考

### 7.1 创建新 VIP 的步骤

1. 创建 Interface（`*_if.sv`）— 信号定义 + master/slave modport
2. 创建 Master VIP（`*_master_vip.sv`）— channel-level + high-level API
3. 创建 Slave VIP（`*_slave_vip.sv`）— 对称 API + 背压
4. 创建 Mem VIP（`*_mem_vip.sv`）— 硬件 memory 模块（可选）
5. 创建 Package（`*_vip_pkg.sv`）— `include` 所有类文件
6. 创建 Testbench（`*_tb.sv`）— 测试用例
7. 创建 run.py — VUnit 测试注册
8. 更新 README 和 API_REFERENCE.md

### 7.2 运行命令

```bash
make test              # 运行所有 VIP（Docker）
make test-<vip_name>   # 运行单个 VIP
make list              # 列出可用 VIP
make lint              # Verible lint
make format            # Verible format
make format-check      # 检查格式化
make clean             # 清理仿真输出
DOCKER=0 make test     # 本地运行（无 Docker）
```

### 7.3 Commit 规范

```
[<type>](<scope>): <description>

- <bullet point 1>
- <bullet point 2>
```

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `enh` | 增强/改进 |
| `fix` | 修复 |
| `doc` | 文档 |
| `refactor` | 重构 |
| `test` | 测试 |
| `style` | 代码风格 |
| `format` | 格式化 |
