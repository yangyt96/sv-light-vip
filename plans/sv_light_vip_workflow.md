# SV-Light VIP 工作流程

> 基于 `axi4_lite_vip` 和 `axi4_full_vip` 开发过程的经验总结
>
> 角色: Roo — FPGA/ASIC RTL 验证工程师 (Code/Architect 模式)
> 语言: 简体中文 (zh-CN) — 与用户沟通语言
> Commit 语言: 英语 — 代码提交信息使用英语
>
> 版本: v2.1 — 新增 AXI4-Full 测试增强经验、复位测试陷阱、VIP 参数可见性、测试用例设计扩展

---

## 核心原则

1. **Lightweight** — 保持 VIP 简洁，不引入不必要的复杂性
2. **对称架构** — Master/Slave API 保持对称（`send_*` ↔ `recv_*`）
3. **参考成熟实现** — 开发新 VIP 前先分析已有成熟 VIP（如 `axi4_full_vip`）的架构
4. **仿真验证必须** — 所有修改必须通过仿真验证
5. **代码质量门禁** — Lint + Format 必须通过
6. **用户确认设计** — 实现前先与用户确认设计方案，避免过度设计
7. **精确提交** — 只提交本次修改的文件，使用 `git add <file1> <file2>` 而非 `git add -A`

---

## 工作流程

### Phase 0: 任务确认与范围界定

```
输入: 用户需求
```

1. **理解需求** — 明确用户想要什么（新 VIP？增强现有 VIP？修复？）
2. **确认范围** — 如果需求模糊，先提出具体方案让用户确认
3. **评估复杂度** — 判断是否需要切换到 Architect 模式进行设计
4. **输出**: 明确的任务范围和目标

> **经验教训**: 不要直接开始实现复杂功能。先提出方案让用户确认，避免过度设计。
> 例如: 用户说"增强 Mem VIP"，应先提出具体方案（如"只添加地址越界 DECERR"），
> 而不是直接添加复杂参数和状态机。

### Phase 1: 需求分析与架构学习

```
输入: 确认后的任务范围
```

1. **分析参考实现** — 阅读成熟 VIP（如 `axi4_full_vip`）的完整代码：
   - Interface（modport 定义）
   - Master/Slave 类架构（channel-level API + high-level API）
   - 背压/暂停机制
   - Package 组织
   - Testbench 结构
   - README 文档

2. **分析目标 VIP 当前状态** — 阅读目标 VIP 的所有文件：
   - 哪些组件已存在？
   - 哪些组件缺失？
   - 与参考实现的差距？

3. **输出**: 架构差异分析 + 待办清单

### Phase 2: 设计决策

```
输入: 架构分析结果
```

1. **确定 API 风格** — 保持与参考实现一致：
   - Channel-level: `send_awchn()`, `recv_bchn()` 等
   - High-level: `write_req_single()`, `read_resp_single()` 等
   - 背压: `apply_pause()` / `apply_stall()` 只在 high-level 调用

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
   - 确认所有测试用例通过（P=全部, S=0, F=0）
   - 新增测试后，总测试数应增加，且原有测试不受影响

### Phase 5: 提交

```
输入: 验证通过的代码
```

**原则**: 只提交本次修改涉及的文件，不提交无关文件。

```bash
# 1. 查看当前修改状态
git status

# 2. 只添加本次修改的文件（精确指定路径）
git add <path/to/file1.sv> <path/to/file2.sv> ...

# 例如:
# git add axi4_lite_vip/sim/axi4_lite_slave_vip.sv
# git add axi4_lite_vip/sim/axi4_lite_vip_pkg.sv
# git add axi4_lite_vip/tb/axi4_lite_vip_tb.sv
# git add axi4_lite_vip/doc/README.md

# 3. 确认只包含预期文件
git status

# 4. 提交
git commit -m "<type>(<scope>): <description>

- <change 1>
- <change 2>
...

All N/N tests passed, lint and format clean."
```

**不要使用**:
- `git add -A` — 添加所有文件（包括无关文件）
- `git add .` — 同上
- `git add -u` — 只更新已跟踪文件，但可能包含无关修改

**Commit message 格式** (参考项目 git log):
```
[type] short description

- bullet point details
...
```

| 类型 | 说明 |
|------|------|
| `[feat]` | 新功能 |
| `[enh]` | 增强/改进 |
| `[fix]` | 修复 |
| `[docs]` | 文档 |
| `[refactor]` | 重构 |
| `[test]` | 测试 |
| `[style]` | 代码风格 |
| `[format]` | 格式化 |

**Commit message 语言**: 使用英语（根据用户要求）

### Phase 6: 回顾与改进建议

```
输入: 提交完成的代码
```

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
- [ ] Lint 通过
- [ ] Format 通过
- [ ] 仿真全部通过

### 增强现有 VIP 时

- [ ] 向后兼容（默认参数保持原有行为）
- [ ] 新增测试用例验证新功能
- [ ] 不影响现有测试
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
