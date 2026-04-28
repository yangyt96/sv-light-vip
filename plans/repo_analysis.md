# sv-light-vip 仓库分析报告

> 最后更新：2026-04-27
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

### ✅ 已完成（22 项）

| 编号 | 项目 | 优先级 |
|------|------|--------|
| 2.3 | 完善 `.gitignore` | 低 |
| 2.4 | 统一代码风格 | 中 |
| 2.5 | 增加参数化范围检查 | 低 |
| 3.1 | 统一 mem_vip 包含方式 | 中 |
| 3.2 | 简化 AXI4-Full 参数传递 | 中 |
| 3.4 | APB Slave 增加 backpressure 支持 | 低 |
| 3.5 | I2C `tri1` 仿真警告分析 | 低 |
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
| 6.1 | API 快速参考文档 | 低 |
| 6.3 | README VIP 详细说明 | 低 |
| **5.11** | **AXI4-Lite Master VIP 重构（对齐 AXI4-Full 架构）** | **中** |

### 📋 待完成（3 项，按优先级排序）

| 编号 | 项目 | 优先级 |
|------|------|--------|
| 3.3 | AXI4-Stream DUT 移出 tb 目录 | 低 |
| 4.4 | Verible lint 规则优化 | 低 |
| 6.2 | 贡献指南 | 低 |

---

## 八、总结

经过全面重新审视，这个 repo 的整体质量良好，代码风格统一，测试覆盖合理。已完成 23 项改进，剩余 3 项待完成（均为低优先级）。`clean.py` 已被移除，其功能由 `make clean` 替代。

**新发现的问题**（与上次分析相比新增）：
1. 参数化范围检查缺失（2.5）
2. AXI4-Stream DUT 位置不当（3.3）
3. Verible lint 规则可优化（4.4）
4. AXI4-Full 缺少 Slave VIP（5.9）
5. README 缺少各 VIP 详细说明（6.3）
6. AXI4-Lite Master VIP 与 AXI4-Full Master VIP 架构不一致（5.11）

这些新发现的问题大多是低优先级的，不影响当前功能，但值得在后续迭代中逐步完善。
