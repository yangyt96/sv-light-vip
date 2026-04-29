# SV-Light VIP 工作流程

> 基于 `axi4_lite_vip` 和 `axi4_full_vip` 开发过程的经验总结
>
> 角色: Roo — FPGA/ASIC RTL 验证工程师 (Code/Architect 模式)
> 语言: 简体中文 (zh-CN) — 与用户沟通语言
> Commit 语言: 英语 — 代码提交信息使用英语
>
> 版本: v2.8 — 新增蒸馏文档引用（`.agent/sv_light_vip_distill.md`）

---

## 核心原则

1. **Lightweight** — 保持 VIP 简洁，不引入不必要的复杂性
2. **对称架构** — Master/Slave API 保持对称（`send_*` ↔ `recv_*`）
3. **参考成熟实现** — 开发新 VIP 前先分析已有成熟 VIP（如 `axi4_full_vip`）的架构
4. **仿真验证必须** — 所有修改必须通过仿真验证
5. **代码质量门禁** — Lint + Format 必须通过
6. **用户确认设计** — 实现前先与用户确认设计方案，避免过度设计
7. **精确提交** — 只提交本次修改的文件，使用 `git add <file1> <file2>` 而非 `git add -A`
8. **AI 窗口可切换性** — 工作流文档是唯一"记忆载体"，任何 AI 窗口通过读取本文件即可无缝继续任务
9. **文档与代码同步** — 修改代码前/后必须同步更新 README 和 API 文档
10. **文档先行提交** — Phase 5 检查文档必要性，更新后再进入 Phase 6 提交

---

## 工作流程

### Phase 0: 任务确认与范围界定

```
输入: 用户需求
```

1. **读取项目文档** — 新 AI 窗口首先读取以下文档以建立上下文：
   - [`.agent/develop_workflow.md`](.agent/develop_workflow.md) — 本工作流文档（了解流程和规范）
   - [`.agent/sv_light_vip_distill.md`](.agent/sv_light_vip_distill.md) — VIP 知识蒸馏（快速了解项目架构、公共设计模式、VIP 元数据）
   - [`API_REFERENCE.md`](API_REFERENCE.md) — API 参考文档（了解所有 VIP 的 API 规范）
   - 目标 VIP 的 [`doc/README.md`](.) — 具体 VIP 的文档

2. **理解需求** — 明确用户想要什么（新 VIP？增强现有 VIP？修复？）

3. **确认范围** — 如果需求模糊，先提出具体方案让用户确认

4. **评估复杂度** — 判断是否需要切换到 Architect 模式进行设计

5. **输出**: 明确的任务范围和目标

> **经验教训**: 不要直接开始实现复杂功能。先提出方案让用户确认，避免过度设计。
> 例如: 用户说"增强 Mem VIP"，应先提出具体方案（如"只添加地址越界 DECERR"），
> 而不是直接添加复杂参数和状态机。

### Phase 1: 需求分析与架构学习

```
输入: 确认后的任务范围
```

1. **读取 API 参考文档** — 阅读 [`API_REFERENCE.md`](API_REFERENCE.md) 了解：
   - 所有 VIP 的统一 API 规范（`apply_pause()` / `wait_reset_release()` / `apply_stall()`）
   - Master/Slave 对称架构约定
   - 参数命名和默认值约定

2. **分析参考实现** — 阅读成熟 VIP（如 `axi4_full_vip`）的完整代码：
   - Interface（modport 定义）
   - Master/Slave 类架构（channel-level API + high-level API）
   - 背压/暂停机制
   - Package 组织
   - Testbench 结构
   - README 文档

3. **分析目标 VIP 当前状态** — 阅读目标 VIP 的所有文件：
   - 哪些组件已存在？
   - 哪些组件缺失？
   - 与参考实现的差距？

4. **输出**: 架构差异分析 + 待办清单

### Phase 2: 设计决策

```
输入: 架构分析结果
```

1. **确定 API 风格** — 保持与参考实现和 API_REFERENCE.md 一致：
   - Channel-level: `send_awchn()`, `recv_bchn()` 等
   - High-level: `write_req_single()`, `read_resp_single()` 等
   - 背压: `apply_pause()` / `apply_stall()` 只在 high-level 调用
   - 复位: `wait_reset_release()` 作为独立任务，在 high-level 入口调用

2. **确定文件结构** — 与参考实现保持目录一致：
   ```
   vip_name/
   ├── doc/README.md
   ├── sim/
   │   ├── vip_name_if.sv
   │   ├── vip_name_master_vip.sv
   │   ├── vip_name_slave_vip.sv    # (如需要)
   │   ├── vip_name_mem_vip.sv      # (如需要)
   │   └── vip_name_vip_pkg.sv
   └── tb/
       ├── vip_name_mem_vip_tb.sv   # (如需要)
       ├── vip_name_vip_tb.sv       # (如需要)
       ├── vip_name_tb.do           # (如需要)
       └── run.py
   ```

3. **输出**: 设计文档 + 文件创建/修改清单

### Phase 3: 实现

```
输入: 设计文档 + 文件清单
```

按以下顺序实现（依赖关系驱动）：

1. **Interface** (`*_if.sv`) — 信号定义 + master/slave modport
2. **Master VIP** (`*_master_vip.sv`) — channel-level + high-level API
3. **Slave VIP** (`*_slave_vip.sv`) — 对称 API + 背压
4. **Mem VIP** (`*_mem_vip.sv`) — 硬件 memory 模块（如需要）
5. **Package** (`*_vip_pkg.sv`) — `include` 所有类文件
6. **Testbenches** (`*_tb.sv`) — 测试用例
7. **Waveform** (`*_tb.do`) — ModelSim 波形配置
8. **run.py** — VUnit 测试注册
9. **README.md** — 完整文档

#### 实现要点

- **Slave VIP 背压架构**:
  - `apply_stall()` 只在 high-level task 中调用（`write_resp_single`, `read_resp_single`）
  - 不在 channel-level API（`recv_awchn`, `recv_wchn` 等）中调用
  - 这与 Master 的 `apply_pause()` 模式对称

- **Mem VIP 设计原则**:
  - 保持简单，只做一件事
  - 地址越界返回 DECERR（而不是添加复杂参数）
  - 不要过度参数化

- **Testbench 设计**:
  - 使用 `fork/join` 协调 Master 和 Slave
  - 每个测试用例独立验证一个功能点
  - 包含：基本功能、错误响应、背压、多事务、边界条件
  - 新增测试用例时，确保向后兼容（不影响现有测试）

- **SystemVerilog 语法注意**:
  - 数值字面量必须使用有效十六进制字符（0-9, a-f, A-F），不能使用 ASCII 助记符
    - ❌ `32'hRESET_OK` — 非法，`RESET_OK` 不是十六进制数字
    - ✅ `32'hC0DE_CAFE` — 合法
  - `output` 端口不能传递空参数 `.addr()`，必须声明局部变量传递
    - ❌ `slave.recv_awchn(.addr(), .prot())`
    - ✅ `slave.recv_awchn(.addr(tmp_addr), .prot(tmp_prot))`
  - **VIP 类内部参数在 testbench 中不可见**:
    - VIP 类内部定义的 `localparam`（如 `LEN_WIDTH`, `SIZE_WIDTH`）在 testbench 中不可见
    - 声明变量时必须使用具体位宽（如 `logic [7:0] tmp_len` 而非 `logic [LEN_WIDTH-1:0] tmp_len`）
    - 或从 VIP 类外部参数获取（如 `ID_WIDTH`, `ADDR_WIDTH` 是 testbench 的 `localparam`）
  - **VIP 类中 vif 信号驱动必须使用非阻塞赋值 (`<=`)**:
    - Virtual interface 是硬件信号的代理，驱动方式应与 RTL 一致
    - 所有通过 `vif.xxx` 驱动的信号必须使用 `<=`（非阻塞赋值）
    - ❌ `vif.pready = 1'b1;` — 阻塞赋值，可能导致竞争条件
    - ✅ `vif.pready <= 1'b1;` — 非阻塞赋值，时钟边沿同步更新
    - 此规则适用于所有 VIP（AXI4-Stream/Full/Lite、APB、SPI、I2C 等）
  - **Assertion 风格: 优先使用合并条件而非 `if` 嵌套**:
    - 当 assertion 需要条件判断时，使用逻辑运算符合并条件
    - ❌ `if (tkeep.size() > 0) assert (tkeep.size() >= beat_count);`
    - ✅ `assert (tkeep.size() == 0 || tkeep.size() >= beat_count);`
    - 合并条件更简洁，避免不必要的 `if` 嵌套

### Phase 4: 验证

```
输入: 实现完成的代码
```

1. **Lint 检查**:
   ```bash
   make lint
   ```
   - 修复所有 lint 错误（如 `case-missing-default`）

2. **Format 检查**:
   ```bash
   make format-check
   ```
   - 如有失败，运行 `make format` 自动修复

3. **仿真验证**:
   ```bash
   make test-<vip_name>
   ```
   - **始终使用 `make test-<vip_name>` 而非直接调用 `python3 <vip>/tb/run.py`**
   - 确认所有测试用例通过（P=全部, S=0, F=0）
   - 新增测试后，总测试数应增加，且原有测试不受影响

### Phase 5: 文档检查

```
输入: 验证通过的代码
输出: 文档更新决策（是否更新 README/doc/API_REFERENCE/repo_analysis）
```

在提交代码前，必须检查本次修改是否需要更新文档。

**检查清单**:

1. **判断是否需要更新文档** — 逐项检查以下变更类型：

  | 变更类型 | 需要更新的文档 | 检查方法 |
  |----------|---------------|---------|
  | 新增 API / 修改 API 签名 | [`API_REFERENCE.md`](API_REFERENCE.md) + 对应 VIP 的 [`doc/README.md`](.) | `git diff` 查看是否有 function/task 新增或参数变更 |
  | 新增 VIP | [`README.md`](README.md) + [`API_REFERENCE.md`](API_REFERENCE.md) | 检查是否有新目录 `*/sim/*_vip_pkg.sv` |
  | 修改事务流程/协议行为 | 对应 VIP 的 [`doc/README.md`](.) | 检查是否修改了 high-level task 的实现逻辑 |
  | 架构变更/改进记录 | 无需更新（项目分析已完成） | 所有计划改进项已完成 |
  | 纯代码风格/格式化 | 无需更新 | 仅修改缩进、空格、注释等 |
  | Bug 修复（不影响 API） | 无需更新 | 修复内部逻辑，对外接口不变 |
  | 新增测试用例 | 无需更新 | 测试文件不在文档范围内 |

2. **执行文档更新**（如有必要）:

  - **更新 [`README.md`](README.md)** — 新增 VIP 说明、功能列表变更、使用示例
  - **更新对应 VIP 的 [`doc/README.md`](.)** — API 变更说明、新增功能描述、使用示例更新
  - **更新 [`API_REFERENCE.md`](API_REFERENCE.md)** — 新增/修改的 API 签名、参数说明

3. **确认文档与代码一致**:
  - 文档中引用的 API 名称、参数、返回值必须与代码完全一致
  - 新增功能必须在文档中有对应说明
  - 删除的功能必须在文档中标记为已废弃或移除

### Phase 6: 提交

```
输入: 验证通过的代码 + 更新后的文档
```

**原则**:
- 只提交本次修改涉及的文件，不提交无关文件
- **文档必须先于代码提交前更新** — 确保 README 和 API 文档与代码同步

**步骤**:

1. **查看当前修改状态**:
  ```bash
  git status
  ```

2. **只添加本次修改的文件**（精确指定路径）:
  ```bash
  git add <path/to/file1.sv> <path/to/file2.sv> <path/to/doc/README.md> ...
  ```

3. **确认只包含预期文件**:
  ```bash
  git status
  ```

4. **提交**:
  ```bash
  git commit -m "[<type>](<scope>): <short description>

  - <bullet point 1>
  - <bullet point 2>
  ..."
  ```

**Commit message 规范**:

| 要求 | 说明 |
|------|------|
| 语言 | **英语** |
| 格式 | `[<type>](<scope>): <description>` |
| 首行 | 小写开头，不加句号，不超过 72 字符 |
| 正文 | 可选，bullet points 用 `- ` 开头，描述具体改动 |

**类型 (`type`)**:

| 类型 | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `[feat](spi): add quad-SPI support` |
| `enh` | 增强/改进 | `[enh](api): normalize API naming convention across all VIPs` |
| `fix` | 修复 | `[fix](apb): use non-blocking assignments for vif signals` |
| `doc` | 文档 | `[doc](repo_analysis): update 4.4 lint analysis conclusion` |
| `refactor` | 重构 | `[refactor](axi4_lite): move signal drive outside handshake loop` |
| `test` | 测试 | `[test](i2c): add bus conflict test` |
| `style` | 代码风格 | `[style](spi): fix indentation` |
| `format` | 格式化 | `[format]: run verible-verilog-format` |

**范围 (`scope`)** — 可选，表示修改的模块或文件：
- VIP 名：`apb`、`spi`、`i2c`、`uart`、`i2s`、`axi4_lite`、`axi4_full`、`axi4_stream`
- 通用：`api`、`docs`、`ci`、`workflow`、`repo_analysis`

**不要使用**:
- `git add -A` — 添加所有文件（包括无关文件）
- `git add .` — 同上
- `git add -u` — 只更新已跟踪文件，但可能包含无关修改

**提交后**: 主动询问用户"下一步做什么"，列出可选方向供用户选择。

### Phase 7: 流程反思

```
输入: 本次任务完成后的经验
```

每次任务完成后，先反思工作流程本身是否有改进空间，再提出 VIP 改进建议：

1. **流程效率** — 是否有不必要的步骤？是否可以合并或简化？
2. **遗漏检查** — 本次任务中是否遇到了 workflow 未覆盖的问题？
3. **工具使用** — 是否有更好的工具或方法可以提升效率？
4. **沟通模式** — 与用户的沟通是否顺畅？是否有误解可以避免？
5. **错误模式** — 本次任务中犯了哪些错误？如何防止再次发生？
6. **输出**: workflow 更新（如有发现）

> **经验**: 每次任务都是改进 workflow 的机会。将新发现的陷阱、模式、最佳实践
> 及时补充到文档中，形成正向循环。

### Phase 8: 回顾与改进建议

```
输入: 提交完成的代码 + 流程反思结果
```

在流程反思之后，基于经验提出 VIP 的改进方向：

1. 对比参考实现，列出当前 VIP 的改进方向
2. 按优先级排序（P0/P1/P2/P3）
3. 每个方向包含：标题、描述、难度、影响评估
4. 让用户选择下一步

**改进建议格式**:
```
### P<N>: <标题>
- **描述**: <具体做什么>
- **难度**: 低/中/高
- **影响**: 低/中/高 — <对项目价值的提升>
```

---

## 检查清单

### 创建新 VIP 时

- [ ] Interface 有 master 和 slave modport
- [ ] Master VIP 有 channel-level + high-level API
- [ ] Slave VIP 有对称 API + 背压
- [ ] Package 包含所有类文件
- [ ] Mem VIP（如需要）保持简单
- [ ] Testbench 覆盖基本功能 + 错误 + 背压 + 边界
- [ ] run.py 注册所有 testbench
- [ ] README 有完整文档
- [ ] API_REFERENCE.md 已更新（如有新增 API）
- [ ] Lint 通过
- [ ] Format 通过
- [ ] 仿真全部通过

### 增强现有 VIP 时

- [ ] 向后兼容（默认参数保持原有行为）
- [ ] 新增测试用例验证新功能
- [ ] 不影响现有测试
- [ ] README 已同步更新
- [ ] API_REFERENCE.md 已同步更新（如有 API 变更）
- [ ] Lint + Format + 仿真全部通过

### 测试用例设计检查

- [ ] 基本功能测试（正常读写）
- [ ] 错误响应测试（SLVERR, DECERR, EXOKAY）
- [ ] 背压测试（轻/中/重）
- [ ] 边界地址测试（0x0000, 0xFFFF...FFFC）
- [ ] 边界数据测试（全0, 全1）
- [ ] 随机 prot 测试（所有 8 种组合）
- [ ] 复位行为测试（事务中复位、复位后恢复）
- [ ] 连续事务测试（无间隔流水线）
- [ ] 多事务并发测试（outstanding transactions）
- [ ] **AXI4-Full 特有**:
  - [ ] 4KB burst 边界跨越测试（INCR burst 跨越 0x1000 边界）
  - [ ] 随机 burst 长度和类型（FIXED/INCR/WRAP, 1-16 beats）
  - [ ] WRAP burst 在 memory 边界（地址对齐到 wrap 边界）
  - [ ] 乱序 ID 完成（多个 outstanding 请求使用不同 ID）
  - [ ] 最大背压压力测试（50-100 cycle 延迟）

---

### 文件同步检查

- [ ] `.do` 波形文件同步更新（模块名、信号路径）
- [ ] `README.md` 同步更新（API 名称、文件结构、测试用例）
- [ ] `run.py` 同步更新（如有新增 testbench）

---

## AI 窗口切换指南

> 本工作流文档是项目唯一的"记忆载体"。当 AI 窗口需要切换时，新窗口通过以下步骤快速恢复上下文。

### 新 AI 窗口接入步骤

1. **读取本工作流文档** — 了解完整流程、规范、检查清单
2. **读取项目文档**:
   - [`.agent/sv_light_vip_distill.md`](.agent/sv_light_vip_distill.md) — VIP 知识蒸馏（快速建立项目架构认知）
   - [`API_REFERENCE.md`](API_REFERENCE.md) — API 规范
3. **读取当前 Phase 的输入** — 每个 Phase 开头有 `输入:` 标记，明确需要什么
4. **查看 git log** — 了解最近的提交历史：
   ```bash
   git log --oneline -10
   ```
5. **查看当前修改状态**（如有未提交的修改）:
   ```bash
   git status
   git diff --stat
   ```
6. **从当前 Phase 继续** — 根据工作流中的 Phase 定义，执行下一步操作

### 各 Phase 的上下文恢复要点

| Phase | 恢复要点 |
|-------|----------|
| Phase 0 | 读取 API_REFERENCE.md + repo_analysis.md + 目标 VIP 的 README |
| Phase 1 | 读取 API_REFERENCE.md + 参考实现的完整代码 |
| Phase 2 | 读取设计决策记录（如有） |
| Phase 3 | 读取目标 VIP 的当前代码 + 设计文档 |
| Phase 4 | 运行 `make lint` / `make format-check` / `make test-<vip_name>` |
| Phase 5 | 检查文档必要性，更新 README/doc/API_REFERENCE/repo_analysis |
| Phase 6 | 检查 `git status` + 更新 README/API 文档 + 提交 |
| Phase 7 | 查看本次任务的 git log + 反思 |
| Phase 8 | 查看 API_REFERENCE.md + 对比参考实现 |

---

## 常见陷阱

1. **过度设计** — 不要给 Mem VIP 加太多参数，保持 lightweight
2. **背压位置错误** — `apply_stall()` 只在 high-level task 中调用
3. **遗漏 Package** — 新类必须在 Package 中 `include`
4. **遗漏 run.py** — 新 testbench 必须在 run.py 中注册
5. **文档滞后** — README 必须与代码同步更新
6. **仿真跳过** — 所有修改必须跑仿真验证
7. **无效十六进制字面量** — 使用 `32'hC0DE_CAFE` 而非 `32'hMNEMONIC`
8. **output 端口空参数** — 必须声明局部变量传递，不能使用 `.addr()`
9. **git add -A** — 应精确指定文件，避免提交无关修改
10. **未确认设计直接实现** — 复杂功能应先提方案让用户确认
11. **Mem VIP 复位语义** — Mem VIP 的复位只重置状态机，不清零 memory 内容。测试复位行为时应验证状态机恢复而非 memory 清零
12. **复位后 slave VIP 状态丢失** — 复位后 slave VIP 的 `clear_outputs()` 必须被调用以恢复信号状态（`wready`, `arready` 等被清零）。否则后续事务会因 slave 不响应而超时
13. **复位期间事务超时** — 不要在复位期间让 master 等待 slave 响应（如 `send_wchn` 等待 `wready`），这会导致 `$fatal` 超时。正确做法：先完成或放弃当前事务，再复位，复位后重新初始化
14. **VIP 类内部参数不可见** — 在 testbench 中声明变量时，不能使用 VIP 类内部的 `localparam`（如 `LEN_WIDTH`），必须使用具体位宽（`logic [7:0]`）
15. **vif 信号使用阻塞赋值 (`=`)** — 在 VIP 类中通过 virtual interface 驱动信号时，必须使用非阻塞赋值 (`<=`)。阻塞赋值 (`=`) 可能导致竞争条件和时序错误。所有 VIP（AXI4-Stream/Full/Lite、APB、SPI、I2C 等）的 class 方法中，`vif.xxx = value` 都应改为 `vif.xxx <= value`
16. **Assertion 使用 `if` 嵌套** — 当 assertion 需要条件判断时，应使用逻辑运算符合并条件，而非 `if` 嵌套。`assert (cond1 || cond2)` 比 `if (cond1) assert (cond2)` 更简洁清晰
17. **直接调用 `run.py` 而非 `make test-*`** — 项目提供统一的 Makefile 入口，应始终使用 `make test-<vip_name>` 运行仿真，而非直接调用 `python3 <vip>/tb/run.py`
