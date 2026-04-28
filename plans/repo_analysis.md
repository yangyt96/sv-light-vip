# sv-light-vip 仓库分析报告

> 最后更新：2026-04-28
> 分析范围：全部 8 个 VIP（APB、AXI4-Lite、AXI4-Full、AXI4-Stream、UART、SPI、I2C、I2S）

---

## 一、总体评价

### 优点

1. **架构清晰统一**：每个 VIP 遵循 `if.sv` → `*_vip_pkg.sv` → `master/slave` 类的层次结构，学习成本低。
2. **轻量级定位明确**：纯 class-based，无 UVM 依赖，仅依赖 VUnit 做测试管理，符合"轻量级 VIP"定位。
3. **接口与实现分离**：`modport` 方向控制清晰，master/slave 通过 virtual interface 连接。
4. **测试覆盖合理**：每个 VIP 都有基本功能测试、连续传输测试、异常场景测试。
5. **CI 集成**：已配置 Verible lint + format 检查。
6. **Docker 支持**：提供 `modelsim:20.1` 和 `verible` 容器化环境，`run_all.py` 一键回归。

### 核心问题（符合轻量级定位的视角）

---

## 二、基础设施改进

### 2.1 修复 `clean.py` 的 Bug（低优先级） ❌ 已移除

`clean.py` 已被移除，其功能由 [`Makefile`](Makefile) 的 `make clean` 目标替代。`make clean` 使用 `find` 递归清理所有子目录中的 `vunit_out/`、`*.wlf`、`transcript` 等仿真产物。

### 2.2 完善 `clean.py` 功能（低优先级） ❌ 已移除

`clean.py` 已被移除，功能由 `make clean` 替代，无需额外完善。

### 2.3 完善 `.gitignore`（低优先级） ✅ 已完成

已添加：`*.wlf`、`transcript`、`*.vstf`、`*.vcd`、`sim_build/`、`*.jou`、`*.log`、`*.bak`、`*.swp`、`.DS_Store`、`Thumbs.db`、`.Xil/`、`.pytest_cache/`

### 2.4 统一代码风格（中优先级） ✅ 已完成

所有 VIP 已完成：
- `new()` 中成员变量赋值对齐
- `configure_pause_generator()` 中赋值对齐
- `apply_pause()` 中移除多余的 `begin...end` 包装
- timeout 统一为 3000 cycles（原值从 1000 到 20000 不等）
- 所有文件通过 Verible format 验证

### 2.5 增加参数化范围检查（低优先级） ✅ 已完成

已完成：在以下 7 个 VIP 的构造函数中添加了 `assert(...) else $error(...)` 检查：

| VIP | 检查 | 文件 |
|-----|------|------|
| SPI Master | `DATA_BITS > 0` | [`spi_master_vip.sv`](spi_vip/sim/spi_master_vip.sv:15) |
| SPI Slave | `DATA_BITS > 0` | [`spi_slave_vip.sv`](spi_vip/sim/spi_slave_vip.sv:11) |
| I2S TX | `SAMPLE_WIDTH > 0` | [`i2s_tx_vip.sv`](i2s_vip/sim/i2s_tx_vip.sv:13) |
| I2S RX | `SAMPLE_WIDTH > 0` | [`i2s_rx_vip.sv`](i2s_vip/sim/i2s_rx_vip.sv:9) |
| UART TX | `CLKS_PER_BIT >= 4` | [`uart_tx_vip.sv`](uart_vip/sim/uart_tx_vip.sv:15) |
| UART RX | `CLKS_PER_BIT >= 4` | [`uart_rx_vip.sv`](uart_vip/sim/uart_rx_vip.sv:12) |
| I2C Master | `HALF_SCL_CYCLES > 0` | [`i2c_master_vip.sv`](i2c_vip/sim/i2c_master_vip.sv:9) |

---

## 三、架构改进

### 3.1 统一 mem_vip 的包含方式（中优先级） ✅ 已完成

已在 [`apb_vip_pkg.sv`](apb_vip/sim/apb_vip_pkg.sv)、[`axi4_lite_vip_pkg.sv`](axi4_lite_vip/sim/axi4_lite_vip_pkg.sv)、[`axi4_full_vip_pkg.sv`](axi4_full_vip/sim/axi4_full_vip_pkg.sv) 中添加注释说明 mem_vip 是硬件模块而非 class，需要在 testbench 中直接 `include` 和实例化。

### 3.2 简化 AXI4-Full Master 的参数传递（中优先级） ✅ 已完成

[`axi4_full_master_vip.sv`](axi4_full_vip/sim/axi4_full_master_vip.sv) 的参数声明已从单行单参数改为紧凑的双列格式，减少了约 20 行重复代码。

### 3.3 将 AXI4-Stream DUT 移出 tb 目录（低优先级） ⏳ 待完成

**新发现**：[`axi4_stream_dut.sv`](axi4_stream_vip/tb/axi4_stream_dut.sv) 位于 `tb/` 目录下，但它是被测试的 DUT（Design Under Test），不是测试代码。建议：
- 创建 `axi4_stream_vip/dut/` 目录
- 将 `axi4_stream_dut.sv` 移入
- 更新 `run.py` 的 include 路径

### 3.4 新增：APB Slave 增加 backpressure 支持（低优先级） ✅ 已完成

**实现**：参考 AXI4-Stream Slave VIP 的 `configure_backpressure()` API，为 APB Slave VIP 增加了统一的 backpressure 接口。

**具体改动**：
- 移除 `ready_delay_cycles` 成员变量和 `configure_ready_delay()` 函数，统一使用 `configure_backpressure()`
- 新增 `enable_backpressure` / `min_stall_cycles` / `max_stall_cycles` 成员变量
- 新增 `configure_backpressure(bit enable, int unsigned min_cycles, int unsigned max_cycles)` 函数，与 AXI4-Stream Slave VIP API 命名一致
- 新增 `get_stall_cycles()` 函数，backpressure 启用时使用 `$urandom_range(max_stall_cycles, min_stall_cycles)`，禁用时返回 0
- `expect_write()` 和 `respond_read()` 使用 `get_stall_cycles()` 替代固定 `ready_delay_cycles`
- 测试用例全部改用 `configure_backpressure()`：`Basic Write-Read` 和 `Error Response` 使用 `configure_backpressure(1'b0)`（无延迟），`Fixed Ready Delay 3` 使用 `configure_backpressure(1'b1, 3, 3)`（固定 3 周期）
- 新增 3 个随机 backpressure 测试用例：`Backpressure Random 1-5`、`Backpressure Range 2-8`、`Backpressure Toggle`

**涉及文件**：
- [`apb_slave_vip.sv`](apb_vip/sim/apb_slave_vip.sv) — 核心修改
- [`apb_vip_tb.sv`](apb_vip/tb/apb_vip_tb.sv) — 测试用例更新

### 3.5 新增：I2C 接口使用 `tri1` 可能引起仿真警告（低优先级） ✅ 已完成

**分析**：[`i2c_if.sv`](i2c_vip/sim/i2c_if.sv:6) 使用 `tri1` 是 I2C 总线建模的标准做法（多驱动线 + 上拉）。ModelSim ASE 的 `(vlog-2186)` 警告实际来自 SVA 断言（`assert property`），而非 `tri1` 本身。`tri1` + `1'bz` 驱动是正确且标准的 I2C 建模方式，保留不变，仅添加注释说明。

### 3.6 新增：APB Master `apply_pause()` 分离 `wait_reset_release()`（中优先级） ✅ 已完成

**问题**：APB Master 的 `apply_pause()` 同时包含 `wait_reset_release()` 和随机暂停，导致：
- 每次调用 `apply_pause()` 都会等待复位释放，这在事务中间调用时是不必要的
- 无法单独调用 `wait_reset_release()` 或 `apply_pause()`

**修改**：
- [`apb_master_vip.sv`](apb_vip/sim/apb_master_vip.sv:48)：`apply_pause()` 只做随机暂停，不再包含 `wait_reset_release()`
- [`apb_master_vip.sv`](apb_vip/sim/apb_master_vip.sv:56)：新增独立的 `wait_reset_release()` task
- [`apb_master_vip.sv`](apb_vip/sim/apb_master_vip.sv:90)：`write()` 和 `read()` 开头先调用 `wait_reset_release()`，再调用 `apply_pause()`

### 3.7 新增：APB Slave `wait_access()` 移除 `wait_reset_release()`（中优先级） ✅ 已完成

**问题**：APB Slave 的 `wait_access()` 内部调用了 `wait_reset_release()`，导致每次等待 APB 访问前都会等待复位释放，这在复位后的事务中是不必要的。

**修改**：
- [`apb_slave_vip.sv`](apb_vip/sim/apb_slave_vip.sv:75)：`wait_access()` 不再调用 `wait_reset_release()`，只等待 APB 访问条件
- `wait_reset_release()` 由 testbench 在 `TEST_SUITE_SETUP` 中显式调用

---

## 四、测试与 CI

### 4.1 增加回归测试脚本（中优先级） ✅ 已完成

[`run_all.py`](run_all.py) 已创建，支持：
- 一键运行所有 8 个 VIP 回归测试
- `--list` 列出可用 VIP
- `--gui` 启动 ModelSim GUI
- ASCII-safe 输出标记，兼容 Docker 环境
- Docker 回归已验证：8/8 ALL PASSED

### 4.2 增加 Makefile（低优先级） ✅ 已完成

**实现**：创建了 [`Makefile`](Makefile)，提供以下目标：
- `make lint` — 运行 Verible lint（默认 Docker）
- `make format` — 运行 Verible format（默认 Docker）
- `make format-check` — 检查格式（默认 Docker）
- `make test` — 运行所有回归（默认 Docker ModelSim）
- `make test-<vip>` — 运行单个 VIP 测试（默认 Docker）
- `make list` — 列出可用 VIP 测试目标
- `make clean` — 清理所有仿真产物（含子目录）
- `make help` — 显示帮助

支持 `DOCKER=0` 切换到本地执行，以及 `VERIBLE_IMAGE`/`MODELSIM_IMAGE` 变量覆盖 Docker 镜像。

### 4.3 CI 改进（中优先级） ✅ 已完成

已完成以下改进：
- 从 [`verible.yml`](.github/workflows/verible.yml) 中删除了 `continue-on-error: true` 注释
- CI 仅检查 `*/sim/*.sv` 文件（tb 文件需要 `vunit_defines.svh`，Docker 镜像中不可用）
- [`vunit.yml`](.github/workflows/vunit.yml) 已使用 `python3 run_all.py` 运行回归测试

### 4.4 新增：Verible lint 规则优化（低优先级） ⏳ 待完成

**新发现**：[`.rules.verible_lint`](.rules.verible_lint) 中禁用了 20+ 条规则。建议：
- 审查被禁用的规则是否确实不需要
- 例如 `-explicit-begin` 被禁用，但统一风格后可以考虑启用
- `-signal-name-style` 被禁用，可以考虑启用以强制命名规范

---

## 五、各 VIP 专项改进建议

### 5.1 UART VIP — 增加 baud rate 配置（中优先级） ✅ 无需修改

已通过 `CLKS_PER_BIT` 参数支持，无需修改。

### 5.2 UART VIP — 增加奇偶校验支持（低优先级） ✅ 已完成

已为 [`uart_tx_vip.sv`](uart_vip/sim/uart_tx_vip.sv) 和 [`uart_rx_vip.sv`](uart_vip/sim/uart_rx_vip.sv) 添加：
- `parity_mode` 成员变量（0=none, 1=odd, 2=even）
- `configure_parity()` 配置函数
- `compute_parity()` 奇偶计算函数
- TX 在 stop bit 前插入校验位
- RX 采样校验位并输出 `parity_error`
- 测试用例：OddParity（32 帧）、EvenParity（32 帧）

### 5.3 I2C VIP — 增加总线冲突检测（低优先级） ✅ 已完成

已在 [`i2c_if.sv`](i2c_vip/sim/i2c_if.sv) 中添加两个 SVA 断言：
- `ap_sda_contention`：检测 SDA 同时被 master 和 slave 拉低
- `ap_scl_contention`：检测 SCL 同时被 master 和 slave 拉低

### 5.4 SPI VIP — 增加 CS 异常测试（低优先级） ✅ 已完成

已在 [`spi_vip_tb.sv`](spi_vip/tb/spi_vip_tb.sv) 中添加 `run_cs_abort()` 任务，测试 CS 在传输中途被撤销的场景。在所有 4 种 SPI 模式下运行。

### 5.5 AXI4-Stream VIP — 增加 TUSER/TID/TDEST 测试覆盖（低优先级） ✅ 已完成

已在 [`axi4_stream_vip_tb.sv`](axi4_stream_vip/tb/axi4_stream_vip_tb.sv) 中添加 `SidebandSignals` 测试用例，验证边界值（全 0、全 1、交替模式）。

### 5.6 I2S VIP — 增加测试覆盖（低优先级） ✅ 已完成

已在 [`i2s_vip_tb.sv`](i2s_vip/tb/i2s_vip_tb.sv) 中添加：
- `BoundaryValues`：5 种边界模式（全 0、全 1、交替 0xAAAA/0x5555、仅左声道、仅右声道）
- `DifferentBclkRate`：使用 `HALF_BCLK_CYCLES=2` 的不同 BCLK 频率测试

### 5.7 APB VIP — 增加 mem_vip 测试覆盖（低优先级） ✅ 已完成

已在 [`apb_mem_vip_tb.sv`](apb_vip/tb/apb_mem_vip_tb.sv) 中添加：
- `Mem VIP Random Access Stress`：64 次随机地址/数据/strobe 写-读校验
- `Mem VIP Back-to-Back Transactions`：32 次连续写后连续读
- `Mem VIP Initial State Zero`：验证复位后内存为零
- `Mem VIP Idle No Activity`：验证 100 个空闲周期无异常活动

### 5.8 新增：I2C Slave 时钟拉伸测试可增强（低优先级） ✅ 已完成

**实现**：增强了 I2C 时钟拉伸测试覆盖：
- `ClockStretching10`：短拉伸 10 周期
- `ClockStretching50`：中等拉伸 50 周期（原测试）
- `ClockStretching200`：长拉伸 200 周期
- `ClockStretchMultiByte`：3 字节写 + 时钟拉伸 50 周期组合
- `ClockStretchRead`：读操作 + 时钟拉伸 50 周期（使用 `respond_read_bytes`）

### 5.9 新增：AXI4-Full 缺少 Slave VIP（低优先级） ✅ 已完成

**新发现**：AXI4-Full 只有 Master VIP，没有独立的 Slave VIP。当前测试依赖 [`axi4_full_mem_vip.sv`](axi4_full_vip/sim/axi4_full_mem_vip.sv) 作为 slave，但这是一个硬件模块，不是 class-based VIP。如果需要测试 DUT 的 AXI4-Full master 接口，需要一个 class-based Slave VIP。

**实现**：创建了 [`axi4_full_slave_vip.sv`](axi4_full_vip/sim/axi4_full_slave_vip.sv)，提供：
- `recv_awchn` / `recv_wchn` / `send_bchn`：写通道事务处理
- `expect_write` / `expect_write_and_respond`：完整写事务
- `recv_archn` / `send_rchn`：读通道事务处理
- `respond_read`：完整读事务
- `configure_backpressure`：全局 backpressure 控制（AW/W/AR 通道 stall，B/R 通道 stall）
- `configure_timeout`：可配置超时
- 7 个测试用例（Basic Write-Read, Burst Write-Read, Slave Error Response, Backpressure Write, Backpressure Read, Multiple Outstanding Transactions, Mixed Backpressure All Channels）
- 15/15 ALL PASSED（含原 8 个 master 测试）

### 5.10 新增：APB 测试中 `apb_wait_q` 初始值为 X（低优先级） ✅ 已完成

**新发现**：在 [`apb_vip_tb.sv`](apb_vip/tb/apb_vip_tb.sv:27) 和 [`apb_mem_vip_tb.sv`](apb_vip/tb/apb_mem_vip_tb.sv:48) 中，`apb_wait_q` 及相关 pipeline 寄存器（`apb_paddr_q`、`apb_pwdata_q`、`apb_pstrb_q`、`apb_pprot_q`）在复位期间为 X。虽然 `bit` 类型默认值为 0，但 `logic` 类型信号初始为 X，可能引起仿真不确定性。

**修改内容**：在 `always_ff @(posedge clk)` 中添加了 `if (!rstn)` 复位分支，将所有 pipeline 寄存器在复位时清零。这确保了仿真开始时所有信号都有确定值，同时兼容 ModelSim 的 `always_ff` 单驱动源规则。

### 5.11 新增：AXI4-Lite Master VIP 重构（对齐 AXI4-Full 架构）（中优先级） ✅ 已完成

**实现**：将 AXI4-Lite Master VIP 重构为与 AXI4-Full Master VIP 一致的 channel-level API 架构：
- 新增 `send_awchn()` / `send_wchn()` / `recv_bchn()` / `send_archn()` / `recv_rchn()` 五个 channel-level API
- 新增 `write_req_single()` / `read_req_single()` 高层面包任务
- 新增 `clear_outputs()` 方法
- `apply_pause()` 仅在高层面包任务中调用，不在 channel-level API 中调用
- 新增 AXI4-Lite Slave VIP（class-based），与 Master 对称的 channel-level API

### 5.12 新增：APB Master/Slave 添加 `clear_outputs()` 方法（中优先级） ✅ 已完成

**实现**：为 APB Master 和 Slave 添加了 `clear_outputs()` 方法，用于在复位释放后将所有输出信号驱动到默认状态：
- [`apb_master_vip.sv`](apb_vip/sim/apb_master_vip.sv:37)：驱动 `paddr/psel/penable/pwrite/pwdata/pstrb/pprot` 到默认值
- [`apb_slave_vip.sv`](apb_vip/sim/apb_slave_vip.sv:62)：驱动 `prdata/pready/pslverr` 到默认值
- [`apb_vip_tb.sv`](apb_vip/tb/apb_vip_tb.sv)：在 `TEST_SUITE_SETUP` 中复位释放后调用 `clear_outputs()`

### 5.13 新增：其他 VIP 添加 `clear_outputs()` 方法（中优先级） ✅ 已完成

**实现**：为 SPI/I2C/UART/I2S VIP 添加了 `clear_outputs()` 方法：

| VIP | 文件 | 输出信号 |
|-----|------|----------|
| SPI Master | [`spi_master_vip.sv`](spi_vip/sim/spi_master_vip.sv:63) | `sclk <= cpol`, `cs_n <= 1'b1`, `mosi <= 1'b0` |
| SPI Slave | [`spi_slave_vip.sv`](spi_vip/sim/spi_slave_vip.sv:31) | `miso <= 1'b0` |
| I2C Master | [`i2c_master_vip.sv`](i2c_vip/sim/i2c_master_vip.sv:22) | `master_scl_low <= 1'b0`, `master_sda_low <= 1'b0` |
| I2C Slave | [`i2c_slave_vip.sv`](i2c_vip/sim/i2c_slave_vip.sv:21) | `slave_scl_low <= 1'b0`, `slave_sda_low <= 1'b0` |
| UART TX | [`uart_tx_vip.sv`](uart_vip/sim/uart_tx_vip.sv:57) | `serial_data <= 1'b1` |
| I2S TX | [`i2s_tx_vip.sv`](i2s_vip/sim/i2s_tx_vip.sv:36) | `bclk <= 1'b0`, `ws <= 1'b0`, `sd <= 1'b0` |

UART RX 和 I2S RX 是只读 VIP（无输出信号），无需添加。

### 5.14 新增：APB Master/Slave 事务方法末尾调用 `idle()` 替代手动清零（低优先级） ✅ 已完成

**实现**：在 APB Master 和 Slave 的事务方法末尾使用 `idle()` 替代手动信号清零，减少代码重复：

| 文件 | 方法 | 修改前 | 修改后 |
|------|------|--------|--------|
| [`apb_master_vip.sv`](apb_vip/sim/apb_master_vip.sv:113) | `write()` | 4 行手动清零 | `idle()` |
| [`apb_master_vip.sv`](apb_vip/sim/apb_master_vip.sv:138) | `read()` | 2 行手动清零 | `idle()` |
| [`apb_slave_vip.sv`](apb_vip/sim/apb_slave_vip.sv:107) | `expect_write()` | 2 行手动清零 | `idle()` |
| [`apb_slave_vip.sv`](apb_vip/sim/apb_slave_vip.sv:129) | `respond_read()` | 3 行手动清零 | `idle()` |

### 5.15 新增：AXI4-Lite Master 信号驱动优化（中优先级） ✅ 已完成

**实现**：将 AXI4-Lite Master 的 4 个 channel API 中的信号驱动移到 handshake 循环外，与 AXI4-Full Master 的 `send_archn()` 模式一致：
- `send_awchn()`：`awaddr/awprot/awvalid` 在 `do...while` 前驱动
- `send_wchn()`：`wdata/wstrb/wvalid` 在 `do...while` 前驱动
- `recv_bchn()`：`bready` 在 `do...while` 前驱动
- `recv_rchn()`：`rready` 在 `do...while` 前驱动

---

## 六、文档改进

### 6.1 增加 API 快速参考（低优先级） ✅ 已完成

已完成：创建了 [`API_REFERENCE.md`](API_REFERENCE.md)，包含所有 8 个 VIP 的完整 API 表格，涵盖：

- 所有主/从/收发器的 task API（带参数说明）
- 配置方法（`configure_pause_generator`、`configure_backpressure`、`configure_timeout`）
- 参数化范围说明
- 通用配置模式示例代码

### 6.2 增加贡献指南（低优先级） ⏳ 待完成

建议创建 `CONTRIBUTING.md`，包含：
- 如何添加新 VIP（模板）
- 代码风格要求（Verible format）
- 测试要求（至少 2 个测试用例）
- PR 流程

### 6.3 新增：README 中缺少各 VIP 的详细说明（低优先级） ✅ 已完成

已完成：
- [`README.md`](README.md) 的 VIP 表格增加了 `Components` 和 `Features` 列，详细列出每个 VIP 的组件和功能
- 增加了 Makefile 使用说明
- 所有 8 个 VIP 的 [`doc/README.md`](apb_vip/doc/README.md) 已更新，包含：
  - 完整的 API 表格（主/从/收发器）
  - 配置方法说明
  - 参数化范围表
  - 测试用例汇总表

---

## 七、完成状态汇总

### ✅ 已完成（28 项）

| 编号 | 项目 | 优先级 |
|------|------|--------|
| 2.3 | 完善 `.gitignore` | 低 |
| 2.4 | 统一代码风格 | 中 |
| 2.5 | 增加参数化范围检查 | 低 |
| 3.1 | 统一 mem_vip 包含方式 | 中 |
| 3.2 | 简化 AXI4-Full 参数传递 | 中 |
| 3.4 | APB Slave 增加 backpressure 支持 | 低 |
| 3.5 | I2C `tri1` 仿真警告分析 | 低 |
| 3.6 | APB Master `apply_pause()` 分离 `wait_reset_release()` | 中 |
| 3.7 | APB Slave `wait_access()` 移除 `wait_reset_release()` | 中 |
| 4.1 | 增加回归测试脚本 | 中 |
| 4.2 | 增加 Makefile | 低 |
| 4.3 | CI 改进 | 中 |
| 5.1 | UART baud rate 配置 | 中 |
| 5.2 | UART 奇偶校验支持 | 低 |
| 5.3 | I2C 总线冲突检测 | 低 |
| 5.4 | SPI CS 异常测试 | 低 |
| 5.5 | AXI4-Stream 侧信道测试 | 低 |
| 5.6 | I2S 测试覆盖增强 | 低 |
| 5.7 | APB mem_vip 测试覆盖 | 低 |
| 5.8 | I2C 时钟拉伸测试增强 | 低 |
| 5.9 | AXI4-Full Slave VIP | 低 |
| 5.10 | APB 测试 `apb_wait_q` 初始化 | 低 |
| 5.11 | AXI4-Lite Master VIP 重构（对齐 AXI4-Full 架构） | 中 |
| 5.12 | APB Master/Slave 添加 `clear_outputs()` 方法 | 中 |
| 5.13 | 其他 VIP (SPI/I2C/UART/I2S) 添加 `clear_outputs()` | 中 |
| 5.14 | APB Master/Slave 事务方法末尾调用 `idle()` | 低 |
| 5.15 | AXI4-Lite Master 信号驱动优化 | 中 |
| 6.1 | API 快速参考文档 | 低 |
| 6.3 | README VIP 详细说明 | 低 |

### 📋 待完成（3 项，按优先级排序）

| 编号 | 项目 | 优先级 |
|------|------|--------|
| 3.3 | AXI4-Stream DUT 移出 tb 目录 | 低 |
| 4.4 | Verible lint 规则优化 | 低 |
| 6.2 | 贡献指南 | 低 |

### 🔮 未来改进建议（Phase 7 遗留，未实现）

以下改进建议在 Phase 7 中识别但未实现，按功能类别分组：

#### I 组：API 命名规范化（中优先级）

**核心原则**：根据 VIP 是否发送 address，统一 API 命名 convention：

| VIP 类别 | 包含 VIP | 特点 | Master API 命名 | Slave API 命名 |
|----------|----------|------|-----------------|----------------|
| **地址类** (address-based) | APB, AXI4-Lite, AXI4-Full | 发送 address | `write_req_*()` / `read_req_*()` | `write_resp_*()` / `read_resp_*()` |
| **数据流类** (data-stream) | AXI4-Stream, SPI, I2C, UART, I2S | 不发送 address | `send_*()` / `recv_*()` | `send_*()` / `recv_*()` |

**当前 API 命名现状**：

| VIP | Master API | Slave API | 问题 |
|-----|-----------|-----------|------|
| **APB** | `write()` / `read()` | `expect_write()` / `respond_read()` | 地址类，但未用 `write_req/read_req` 命名 |
| **AXI4-Lite** | `write_req_single()` / `read_req_single()` | `write_resp_single()` / `read_resp_single()` | ✅ 已符合地址类 convention |
| **AXI4-Full** | `write_req_single()` / `read_req_single()` / `write_req_burst()` / `read_req_burst()` | `write_resp_single()` / `read_resp_single()` / `write_resp_burst()` / `read_resp_burst()` | ✅ 已符合地址类 convention |
| **AXI4-Stream** | `send_single()` / `send_multi()` | `recv_single()` / `recv_multi()` | ✅ 已符合数据流类 convention |
| **SPI** | `transfer()` | `transfer()` | 数据流类，但未用 `send/recv` 命名 |
| **I2C** | `write_byte()` / `read_byte()` / `write_bytes()` / `read_bytes()` | `expect_write()` / `respond_read()` / `expect_write_bytes()` / `respond_read_bytes()` | 数据流类，但未用 `send/recv` 命名 |
| **UART** | `transmit()` | `receive()` | 数据流类，但未用 `send/recv` 命名 |
| **I2S** | `transmit()` | `receive()` | 数据流类，但未用 `send/recv` 命名 |

**建议的 API 重命名映射**：

| VIP | 当前 API | 建议新 API | 说明 |
|-----|---------|-----------|------|
| **APB Master** | `write()` | `write_req()` | 地址类，对齐 AXI4-Lite/Full |
| **APB Master** | `read()` | `read_req()` | 地址类，对齐 AXI4-Lite/Full |
| **APB Slave** | `expect_write()` | `write_resp()` | 地址类，对齐 AXI4-Lite/Full |
| **APB Slave** | `respond_read()` | `read_resp()` | 地址类，对齐 AXI4-Lite/Full |
| **SPI Master** | `transfer()` | `send_recv()` | 数据流类，全双工 send+recv |
| **SPI Slave** | `transfer()` | `send_recv()` | 数据流类，全双工 send+recv |
| **I2C Master** | `write_byte()` / `write_bytes()` | `send_byte()` / `send_bytes()` | 数据流类 |
| **I2C Master** | `read_byte()` / `read_bytes()` | `recv_byte()` / `recv_bytes()` | 数据流类 |
| **I2C Slave** | `expect_write()` / `expect_write_bytes()` | `recv_byte()` / `recv_bytes()` | 数据流类 |
| **I2C Slave** | `respond_read()` / `respond_read_bytes()` | `send_byte()` / `send_bytes()` | 数据流类 |
| **UART TX** | `transmit()` | `send_frame()` | 数据流类 |
| **UART RX** | `receive()` | `recv_frame()` | 数据流类 |
| **I2S TX** | `transmit()` | `send_frame()` | 数据流类 |
| **I2S RX** | `receive()` | `recv_frame()` | 数据流类 |

**向后兼容策略**：
- 保留旧 API 作为别名（调用新 API），标记为 `// DEPRECATED: use send_frame() instead`
- 测试用例逐步迁移到新 API
- 在下一个大版本中移除旧 API

#### F 组：为其他 VIP 添加 `idle()` 方法（低优先级）

| 编号 | 项目 | 说明 |
|------|------|------|
| F1 | AXI4-Lite Slave 添加 `idle()` | 已有 `clear_outputs()`，缺少 `idle()` 方法 |
| F2 | AXI4-Full Master 添加 `idle()` | 已有 `clear_outputs()`，缺少 `idle()` 方法 |
| F3 | AXI4-Full Slave 添加 `idle()` | 已有 `clear_outputs()`，缺少 `idle()` 方法 |
| F4 | AXI4-Stream Master 添加 `idle()` | 已有 `clear_outputs()`，缺少 `idle()` 方法 |
| F5 | AXI4-Stream Slave 添加 `idle()` | 已有 `clear_outputs()`，缺少 `idle()` 方法 |

#### G 组：统一 `apply_pause()` 分离 `wait_reset_release()`（中优先级）

| 编号 | 项目 | 说明 |
|------|------|------|
| G1 | AXI4-Lite Master `apply_pause()` 分离 | 当前 `apply_pause()` 仍包含 `wait_reset_release()`，与 APB Master 不一致 |
| G2 | AXI4-Full Master `apply_pause()` 分离 | 当前 `apply_pause()` 仍包含 `wait_reset_release()`，与 APB Master 不一致 |
| G3 | SPI Master/Slave 分离 `wait_reset_release()` | `apply_pause()` 和 `transfer()` 中内联了复位等待 |
| G4 | UART TX `transmit()` 分离 `wait_reset_release()` | 内联了复位等待 |
| G5 | I2S TX `transmit()` 分离 `wait_reset_release()` | 内联了复位等待 |

#### H 组：事务方法末尾调用 `idle()`（低优先级）

| 编号 | 项目 | 说明 |
|------|------|------|
| H1 | SPI Master `transfer()` 末尾调用 `idle()` | 末尾手动清零 `cs_n/mosi` |
| H2 | SPI Slave `transfer()` 末尾调用 `idle()` | 末尾手动清零 `miso` |
| H3 | I2C Master 事务末尾调用 `idle()` | 无显式清理 |
| H4 | I2C Slave 事务末尾调用 `idle()` | 无显式清理 |
| H5 | UART TX `transmit()` 末尾调用 `idle()` | 无显式清理 |
| H6 | I2S TX `transmit()` 末尾调用 `idle()` | 末尾手动清零 `ws/sd` |
| H7 | AXI4-Lite Master/Slave 事务末尾调用 `idle()` | 无 `idle()` 方法 |
| H8 | AXI4-Full Master/Slave 事务末尾调用 `idle()` | 无 `idle()` 方法 |
| H9 | AXI4-Stream Master/Slave 事务末尾调用 `idle()` | 无 `idle()` 方法 |

---

## 八、总结

经过全面重新审视，这个 repo 的整体质量良好，代码风格统一，测试覆盖合理。已完成 **28 项**改进，剩余 **3 项**待完成（均为低优先级）。`clean.py` 已被移除，其功能由 `make clean` 替代。

**Phase 7 新增改进（5 项）**：
1. **功能 C**：AXI4-Lite Master 信号驱动优化（5.15）
2. **功能 A+B**：APB VIP `clear_outputs()` + `apply_pause()` 分离（3.6, 3.7, 5.12）
3. **功能 E**：其他 VIP 添加 `clear_outputs()`（5.13）
4. **功能 D1+D2**：APB Master/Slave 事务方法末尾调用 `idle()`（5.14）
5. **功能 D3**：AXI4-Stream Slave 已有 `clear_outputs()` — 确认

**未来改进方向**（按优先级排序）：
1. **I 组**：API 命名规范化（中优先级，14 项）— 根据是否发送 address 统一 `write_req/read_req` vs `send/recv` convention
2. **G 组**：统一 `apply_pause()` 分离 `wait_reset_release()`（5 项，中优先级）
3. **F 组**：为 AXI4-Lite/Full/Stream VIP 添加 `idle()` 方法（5 项，低优先级）
4. **H 组**：事务方法末尾调用 `idle()`（9 项，低优先级）

**新发现的问题**（与上次分析相比新增）：
1. 参数化范围检查缺失（2.5）
2. AXI4-Stream DUT 位置不当（3.3）
3. Verible lint 规则可优化（4.4）
4. AXI4-Full 缺少 Slave VIP（5.9）
5. README 缺少各 VIP 详细说明（6.3）
6. AXI4-Lite Master VIP 与 AXI4-Full Master VIP 架构不一致（5.11）
7. APB Master `apply_pause()` 包含 `wait_reset_release()`（3.6）
8. 其他 VIP 缺少 `clear_outputs()`（5.13）
9. APB Master/Slave 事务方法末尾手动清零（5.14）
10. AXI4-Lite Master 信号驱动位置可优化（5.15）
11. API 命名不统一：地址类 vs 数据流类 VIP 使用混合命名风格（I 组）

这些新发现的问题大多是低优先级的，不影响当前功能，但值得在后续迭代中逐步完善。
