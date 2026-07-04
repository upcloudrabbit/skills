---
name: source-code-read
description: >
  源码阅读与文档生成技能。使用子 agent（Agent 工具）进行重分析以减小主上下文占用，
  后台子 agent 并发上限固定为 3。检测源码项目是否已由 IDE 打开并存在 IDE MCP；
  可用时优先使用 IDE MCP 进行文件、索引、诊断、符号与搜索操作。从源码项目生成结构化 Markdown 文档。
  TRIGGER: 当用户输入 /source-code-read 时触发。
---

# Source Code Read — 源码阅读与文档生成 Skill

使用 **子 agent（Agent 工具）** 编排，将源码分析、文档生成等重操作委托给
独立的子 agent 执行，主 agent 只做路径确认、调度和结果汇总。

后台子 agent **最多同时运行 3 个**。任何并行任务都必须按 3 个一组分批启动，
前一批完成后再启动下一批，避免资源争抢和上下文结果混乱。

---

## 职责分工

| 角色 | 职责 | 做 | 不做 |
|------|------|----|------|
| **主 agent** | 编排与调度 | 解析指令、确定任务序列、启动子 agent、检查结果、输出最终文件清单 | Read/Edit/Write/Bash 等文件操作、代码分析、文档内容生成 |
| **子 agent** | 执行具体任务 | 环境检测、主题检测、日期命令设置、目录创建、源码分析、文档生成与修改、归档备份、摘要同步 | 调度决策、任务序列编排、跨任务传递上下文 |

所有子 agent 统一使用 `subagent_type: general-purpose`。
后台子 agent 并发数固定为 **3**，不得超过该上限。

---

## 指令总览

| 指令 | 功能 |
|------|------|
| `init` | 首次分析：归纳模块并生成完整文档 |
| `reinit` | 归档旧文档→按 `init` 标准重新整理 |
| `update` | 增量更新指定文档 |
| `byCase` | 按场景追溯源码，生成时序图和实现分析 |
| `help` | 输出简要帮助 |

---

## 通用规范

### 1. 主 agent 编排原则

```
用户指令 → 主 agent 解析 → [依次/并行启动子 agent] → 检查结果 → 汇总输出
```

- 每一步的**具体工作**（文件操作、命令执行、代码分析、内容生成）必须由子 agent 完成
- 主 agent 通过子 agent 返回的 JSON 结果传递上下文到下一步
- 关键步骤（环境检测、模块扫描）子 agent 失败则报错退出；非关键步骤失败则记录日志后继续
- 并行任务使用后台子 agent 时，**同一时间最多 3 个**；超过 3 个任务时按批次执行并等待批次完成

### 2. IDE MCP 访问策略

每次需要读取或索引源码前，先检测源码项目是否已通过 IDE 打开，并检查当前 MCP 中是否存在 IDE 提供的能力。

检测顺序：

1. 确认源码根目录 `_sourcePath`：优先使用用户指定路径；未指定时使用当前工作区/当前项目根目录。
2. 检查当前可用 MCP 工具或资源中是否存在 IDE 提供者，重点识别 workspace、diagnostics、file、search、symbols、definition、references、outline、index 等能力。
3. 通过 IDE MCP 获取已打开 workspace/project/root 信息，确认其中包含 `_sourcePath` 或与 `_sourcePath` 指向同一项目。
4. 路径匹配且至少一个 IDE MCP 操作成功时，标记 `hasIDE=true`，记录 `ideMcpProvider`、`ideWorkspacePath`、`ideCapabilities`。
5. 未发现 IDE MCP、IDE 未打开目标源码、路径不匹配或探测失败时，标记 `hasIDE=false`，记录失败原因。

访问优先级：

- `hasIDE=true` 时，源码读取、目录/文件列表、全文搜索、符号搜索、定义/引用跳转、诊断、项目索引、模块关系分析等操作必须优先使用 IDE MCP。
- `hasIDE=true` 时，不要直接用 Bash 扫描源码树、`grep`/`rg` 搜索源码、`find` 列目录或读取源码文件；只有 IDE MCP 缺少对应能力或单次调用失败时，才可使用文件系统工具兜底，并记录原因。
- `hasIDE=false` 时，允许使用文件系统工具进行静态分析；仍然禁止运行源码、编译、测试或启动服务。
- 文件系统兜底扫描时排除 `.git`、`node_modules`、`dist`、`build`、`target`、`out`、`.next`、`.gradle`、`.idea`、`.vscode`、`archive_*` 等低价值或生成目录，除非用户明确要求分析这些目录。
- Bash 允许用于执行本 skill 自带的 `scripts/theme.*`、`scripts/date.*`，以及没有 MCP 能力覆盖的归档/目录创建等文档输出操作。
- 子 agent 返回 JSON 时必须带上 `hasIDE`、`ideMcpProvider`、`ideWorkspacePath`、`ideCapabilities`、`ideFallbackReason`，供后续子 agent 继承访问策略。

### 3. 子 agent 返回与状态传递

主 agent 只保存和传递结构化状态，不接收完整文件正文。所有子 agent 返回 JSON 时遵守以下约定：

- 必填字段：`status`、`filePath` 或 `affectedFiles`、`warnings`、`errors`。
- 源码相关任务附加：`hasIDE`、`ideFallbackReason`、`sourceRefs`、`optimizationSuggestions`。
- 文档相关任务附加：`updatedSections`、`needsSummaryUpdate`、`qualityChecks`。
- `warnings` 用于记录非阻断问题；`errors` 非空时主 agent 判断是否中断。
- 后续子 agent 只接收必要摘要、路径、变量和 JSON 结果，不传递完整文档正文，避免主上下文膨胀。

`qualityChecks` 至少包含：

```json
{
  "hasDate": true,
  "hasFocusSections": true,
  "hasCodeRefs": true,
  "mermaidChecked": true,
  "summarySynced": true
}
```

### 4. 优化建议

完成 `init`、`reinit`、`update` 或 `byCase` 后，如子 agent 在源码结构、文档结构或实现分析中发现明确优化点，最终输出可附加一个简短的“优化建议”小节。

优化建议要求：

- 只提出基于已分析证据的建议，避免泛泛而谈
- 每条建议说明目标位置、问题、建议动作和收益/风险
- 优先提出架构边界、模块职责、重复逻辑、错误处理、可测试性、性能瓶颈、文档缺口等可执行改进
- 控制在 1-5 条；没有明确优化点时不强行输出
- 不替代文件变更清单，放在完成清单之后

### 5. 画图约定

所有涉及画图场景，**统一优先使用 Mermaid**。每个 Mermaid 代码块**必须在首行插入 `{_mermaidThemeInit}`**。

#### Mermaid 主题——必须原样插入脚本结果

`_mermaidThemeInit` 的值由 `scripts/theme.sh` / `scripts/theme.ps1` 执行后返回（格式如 `%%{init: {"theme": "dark"}}%%`），**使用时必须直接粘贴脚本返回的原始字符串**，禁止对引号、花括号、百分号做任何转义、重包装或格式调整。脚本返回什么就插入什么，不做任何修改。

| 场景 | 优先使用 | 兜底 |
|------|----------|------|
| 类继承/接口实现 | `` ```mermaid `` + `{_mermaidThemeInit}` + classDiagram | 文本 UML |
| 调用流程/交互 | `` ```mermaid `` + `{_mermaidThemeInit}` + sequenceDiagram | 文字流程 |
| 状态流转 | `` ```mermaid `` + `{_mermaidThemeInit}` + stateDiagram-v2 | 文字状态表 |
| 流程图/算法逻辑 | `` ```mermaid `` + `{_mermaidThemeInit}` + flowchart | 步骤列表 |
| 架构/模块依赖 | `` ```mermaid `` + `{_mermaidThemeInit}` + graph | 层次列表 |
| 内存布局/结构体 | `` ```text `` 标注高/低地址 | — |

#### Mermaid 语法陷阱

子 agent 生成 Mermaid 图时注意以下常见问题：

- **特殊字符用引号包裹**：节点标签中含 `( )` `[ ]` `{ }` `"` `:` 等时，必须用双引号包裹，如 `class "User(Entity)"`
- **时序图参与者**：名称含空格/特殊字符时用引号包裹并用 `as` 起别名，如 `participant "API Gateway" as Gateway`
- **流程图节点转义**：特殊字符在节点定义处用引号，而非关系行，如 `A["节点(带括号)"]`
- **类图可见性标记**：`+` `-` `#` 必须紧跟属性/方法名，不能有空格
- **禁用 HTML 标签**：Mermaid 不支持 `<br/>` 等 HTML 标签，换行用 `\n` 或 `</br>`

#### Mermaid 语法校验

每次生成或修改 Mermaid 图后，**必须自行校验语法正确性**，直至渲染通过：

1. **写入后立即校验**：将 Mermaid 代码块写入文件后，立即自行审查校验
2. **校验方式**：子 agent 根据 Mermaid 语法规范逐项检查生成的代码：
   - 检查特殊字符是否已用双引号包裹（`( ) [ ] { }` 等）
   - 检查参与者名称是否含空格，必要时用 `as` 起别名
   - 检查关系/连线语法是否正确（箭头方向、`-->` `->>` 等）
   - 检查 classDiagram/sequenceDiagram 等类型声明是否匹配实际语法
   - 检查时序图 participant 声明是否正确
   - 检查流程图节点定义是否完整
   - 确认首行已插入 `{_mermaidThemeInit}`（**必须原样插入脚本返回的原始字符串，禁止重转义**）
   - 时序图额外校验：检查是否使用 `Note over` 标注了步骤编号，并在图后附有步骤说明表
3. **修复与重试**：
   - 发现问题 → 定位原因 → 修复 → 重新校验
   - 循环直到校验通过，**最多重试 5 次**
   - 超限后使用兜底方案（文本 UML / 文字流程 / 步骤列表）替代
4. **常见失败原因排查**：
   - 特殊字符未引号包裹 → 加双引号
   - 节点 ID 含空格 → 改用驼峰或下划线
   - 关系语法错误（如缺少 `:`） → 检查箭头/连线格式
   - 缩进/换行问题 → 清理多余空白

#### 流程图步骤编号与说明

生成 `flowchart` 类型的 Mermaid 图时，必须遵守以下规范：

1. **节点编号**：流程图的每个步骤节点使用分层编号命名，用节点 ID 中的数字序号表达层级与顺序：

   | 层级 | 格式 | 示例 |
   |------|------|------|
   | 一级步骤 | `1` `2` `3` … | `1[解析请求]` |
   | 二级子步骤 | `1.1` `1.2` `2.1` … | `1.1[验证参数]` |
   | 三级子步骤 | `1.1.1` `1.1.2` … | `1.1.1[格式校验]` |

2. **步骤说明表**：在 Mermaid 代码块下方紧跟着一个步骤说明列表或表格，详细说明每一步在做什么：

   ````markdown
   ```mermaid
   {_mermaidThemeInit}
   flowchart LR
     1[解析请求] --> 1.1[验证参数]
     1.1 --> 1.2[执行逻辑]
     1.1 --> 1.3[降级处理]
     1.2 --> 2[返回结果]
   ```

   | 步骤 | 说明 |
   |------|------|
   | 1 解析请求 | 从 HTTP 请求中提取参数和 body，反序列化为内部结构体 |
   | 1.1 验证参数 | 校验必填字段、格式合法性，失败走 1.3 降级 |
   | 1.2 执行逻辑 | 调用核心业务逻辑处理请求 |
   | 1.3 降级处理 | 参数不合法时返回默认结果或错误码 |
   | 2 返回结果 | 将处理结果序列化为 JSON 并写入响应体 |
   ````

3. **说明内容要求**：每步说明应包含「做了什么」+「关键决策或边界条件」（如有），如失败分支、数据流向等

#### 时序图步骤编号与说明

生成 `sequenceDiagram` 类型的 Mermaid 图时，必须遵守以下规范：

1. **消息编号**：每条消息使用 `Note over ...: N. 步骤说明` 的方式在图上嵌入步骤编号，用法与流程图编号一致：

   | 层级 | 格式 | 示例 |
   |------|------|------|
   | 一级步骤 | `1.` `2.` `3.` … | `Note over A, B: 1. 发送请求` |
   | 二级子步骤 | `1.1` `1.2` `2.1` … | `Note over B, C: 2.1 校验参数` |

2. **步骤说明表**：在 Mermaid 代码块下方紧跟着一个步骤说明列表或表格，详细说明每一步在做什么：

   ````markdown
   ```mermaid
   {_mermaidThemeInit}
   sequenceDiagram
     participant Client as 客户端
     participant API as 网关
     participant Svc as 服务层
     participant DB as 数据库

     Client->>API: HTTP POST /api/v1/create
     Note over API: 1. 接收请求
     API->>Svc: 调用 CreateService
     Note over API, Svc: 1.1 协议转换
     Svc->>DB: INSERT INTO ...
     Note over Svc: 2. 持久化数据
     DB-->>Svc: 返回 ID
     Note over Svc: 2.1 处理返回值
     Svc-->>API: 返回结果
     Note over API: 3. 格式化响应
     API-->>Client: 201 Created
   ```

   | 步骤 | 说明 |
   |------|------|
   | 1 接收请求 | 网关解析 HTTP 请求，提取参数并反序列化 |
   | 1.1 协议转换 | 将 HTTP 请求转换为内部 RPC 调用格式 |
   | 2 持久化数据 | 将业务实体写入数据库，含事务处理 |
   | 2.1 处理返回值 | 将数据库返回的 ID 封装为领域对象 |
   | 3 格式化响应 | 将内部结构序列化为 HTTP 响应 JSON |
   ````

3. **说明内容要求**：每步说明应包含「谁做什么」+「关键决策或边界条件」（如有），如异步回调、失败分支、数据流向等。

4. **Note 与消息交替**：每条关键消息前后用 `Note over` 标注步骤序号，避免仅靠消息行文本承载编号。编号粒度以「一个逻辑步骤」为单位，不需每条消息都编号。

### 6. 文档规范

- **日期**：文档顶部标注 `YYYY-MM-DD HH:mm` 格式的上次修改时间，**必须通过操作系统日期命令获取**，不得由 agent 自行推断
- **命名**：文档名用**中文**（术语表等保留原文的除外）
- **代码引用**：工程内用**相对路径**，工程外用**绝对路径**，文档末尾统一列出
- **概念解释**：每个概念含定义、作用、代码示例或使用场景
- **重点关注**：文档开头列出重点章节
- **三维评估**：关键代码分析**好处**（为什么）、**替代方案**（其他方式及权衡）、**风险**（不这么实现的问题）
- **摘要同步**：新增/删除/改名文档或内容大改时，同步更新 `摘要.md` 的模块功能摘要表
- **质量门禁**：保存前检查日期、重点关注、代码引用、Mermaid 首行、步骤说明表、摘要同步标记；缺失则修复后再返回成功

### 7. 跨子 agent 变量

| 变量 | 含义 | 设置时机 | 获取方式 |
|------|------|----------|----------|
| `_sourcePath` | 源码项目根目录（绝对路径） | init 步骤 1 / 用户指定 | 用户确认或当前工作区 |
| `_path` | 文档输出目录（绝对路径） | init 步骤 1 | 用户确认 |
| `_ideAccess` | IDE MCP 访问策略与检测结果 | 每次需要读取源码前 | IDE MCP 访问策略检测 |
| `_runState` | 本次执行的结构化状态摘要 | 每个子 agent 完成后 | 子 agent JSON 返回 |
| `_mermaidThemeInit` | Mermaid 主题初始化字符串（含 dark/neutral 主题） | 每次指令执行前 | `scripts/theme.sh` / `scripts/theme.ps1` |
| `_dateCmdFull` | 文档时间戳命令（完整日期时间格式） | 每次指令执行前 | `scripts/date.sh` / `scripts/date.ps1` |
| `_dateCmdCompact` | 文档时间戳命令（紧凑格式，用于归档命名） | 每次指令执行前 | `scripts/date.sh` / `scripts/date.ps1` |

运行环境检测脚本时，先判断操作系统：
- **Linux / macOS**：运行 `scripts/theme.sh` + `scripts/date.sh`
- **Windows**：运行 `scripts/theme.ps1` + `scripts/date.ps1`

各脚本输出 JSON 片段，子 agent 合并后得到 `_mermaidThemeInit`、`_dateCmdFull`、
`_dateCmdCompact` 三个变量。

### 8. Prompt 转义注意事项

| 问题 | 规则 |
|------|------|
| **JSON 大括号冲突** | prompt 中 `{` `}` 需用 `{{` `}}` 转义，避免被模板引擎解析为变量 |
| **代码块嵌套** | prompt 内嵌代码块用缩进 `    ``` ` 替代 ` ``` ` 避免解析错误 |
| **注入变量检查** | `{_path}` `{_dateCmdFull}` 等可能含空格/引号/反斜杠，注入后用反引号包裹 |

---

## `init` — 首次文档生成

### 执行流程

1. **确认源码根目录 `_sourcePath` 与输出路径 `_path`**：
   - `_sourcePath`：优先使用用户指定的源码路径；未指定时使用当前工作区/当前项目根目录
   - `_path`：新会话询问用户绝对路径
   - 如路径下已有文件：列出文件列表，询问是否继续使用
   - 在同一会话中记住 `_sourcePath` 和 `_path`

2. **启动初始化子 agent**（环境准备 + 项目分析合并为一个子 agent）：

   ```
   Agent:
     description: 初始化项目分析
     prompt: |
       执行以下任务并按 JSON 返回结果：

       【任务 1 — 运行环境检测脚本】
       先判断操作系统，再按平台运行对应的检测脚本：

       a) **判断 OS**：
          - Linux / macOS → 使用 .sh 脚本
          - Windows → 使用 .ps1 脚本

       b) **查找并运行脚本**：
          优先搜索 skill 安装目录下的 scripts/ 目录，回退搜索当前工作树。
          
          Linux/macOS 执行：
            bash <脚本路径>/theme.sh    → 解析 JSON 得 mermaidTheme / mermaidThemeInit
            bash <脚本路径>/date.sh     → 解析 JSON 得 dateCmdFull / dateCmdCompact
          
          Windows 执行：
            powershell -File <脚本路径>/theme.ps1  → 解析 JSON 得 mermaidTheme / mermaidThemeInit
            powershell -File <脚本路径>/date.ps1   → 解析 JSON 得 dateCmdFull / dateCmdCompact

       c) **脚本缺失或执行失败**：报错退出，所有环境变量必须由脚本提供，不设后备默认值。

       【任务 2 — 项目环境检测】
       源码根目录：{_sourcePath}
       1) **检测 IDE 打开状态与 IDE MCP**：
          - 检查当前 MCP 工具/资源中是否存在 IDE 提供者
          - 通过 IDE MCP 获取已打开 workspace/project/root
          - 确认已打开项目包含 {_sourcePath} 或与其为同一源码项目
          - 尝试一次轻量 IDE MCP 操作（如 workspace 信息、文件诊断、符号/索引查询）
          - 路径匹配且调用成功 → 标记 hasIDE=true，后续源码读取、搜索、索引、诊断、符号跳转优先使用 IDE MCP
          - 未发现 IDE MCP、IDE 未打开目标源码、路径不匹配或调用失败 → 标记 hasIDE=false，并记录 ideFallbackReason
       2) 获取项目名称、技术栈、构建方式、许可证。
          hasIDE=true 时优先通过 IDE MCP 获取；否则回退到文件系统分析。

       【任务 3 — 模块扫描】
       扫描目录结构，识别主要模块/子系统。对每个模块给出中文名、路径、功能职责、核心文件（3-8 个）。
       hasIDE=true 时必须优先通过 IDE MCP 的 workspace/search/symbol/index 能力了解项目结构；只有缺少能力或调用失败时才回退文件系统扫描，并记录原因。
       文件系统兜底扫描时排除 .git、node_modules、dist、build、target、out、.next、.gradle、.idea、.vscode、archive_* 等目录。

       【任务 4 — 创建输出目录】
       mkdir -p {_path}/images

       返回 JSON（必须严格匹配此结构）：
       {
         "status": "ok",
         "_mermaidThemeInit": "...",
         "_dateCmdFull": "...",
         "_dateCmdCompact": "...",
         "_sourcePath": "...",
         "projectName": "...", "techStack": "...", "buildMethod": "...",
         "language": "...", "license": "...", "hasIDE": true/false,
         "ideMcpProvider": "...或null",
         "ideWorkspacePath": "...或null",
         "ideCapabilities": ["workspace", "search", "symbols"],
         "ideFallbackReason": "...或null",
         "projectScale": "...", "totalFiles": 0,
         "modules": [
           { "name": "模块中文名", "path": "src/xxx", "description": "功能职责", "keyFiles": ["文件1", "文件2"] }
         ],
         "warnings": [],
         "errors": []
       }
   ```
   如果子 agent 返回 null 或无效结果则报错退出。

3. **文档生成（并行）** — 遍历 `modules`，最多 3 个并发启动后台子 agent：

   ```
   Agent:
     description: 生成文档 - {模块名}
     run_in_background: true
     prompt: |
       分析模块 "{模块名}"（{模块路径}）并生成结构化文档。

       输出目录：{_path}
       文档命名：{模块名}.md（中文名）
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}
       IDE MCP 访问策略：hasIDE={hasIDE}, provider={ideMcpProvider}, workspace={ideWorkspacePath}, capabilities={ideCapabilities}, fallbackReason={ideFallbackReason}

       文档结构要求：
       - 上次修改：YYYY-MM-DD HH:mm（通过 {_dateCmdFull} 获取）
       - 重点关注
       - 功能概述
       - 核心概念（定义、作用、代码示例、三维评估）
       - 关键流程（Mermaid 图，首行 {_mermaidThemeInit}）
       - 类继承关系（Mermaid classDiagram）
       - 文件说明表（路径、职责、关键类/函数）
       - 引用代码索引（工程内相对路径，外部绝对路径）

       三维评估：好处/替代方案/风险。
       画图优先 Mermaid，首行插入 {_mermaidThemeInit}。

       先读取源码深入理解，关键文件参考：{keyFiles}。
       若 hasIDE=true，源码读取、搜索、索引、诊断、符号/引用跳转必须优先使用 IDE MCP；只有 IDE MCP 缺少能力或调用失败时才可回退文件系统工具，并在返回 JSON 中说明原因。
       写入 {_path}/{模块名}.md。

       完成后返回 JSON：
       {
         "filePath": "{_path}/{模块名}.md",
         "status": "created",
         "hasIDE": true/false,
         "ideFallbackReason": "...或null",
         "sourceRefs": ["相对路径1", "相对路径2"],
         "qualityChecks": {
           "hasDate": true,
           "hasFocusSections": true,
           "hasCodeRefs": true,
           "mermaidChecked": true,
           "summarySynced": false
         },
         "optimizationSuggestions": [
           { "target": "相对路径或文档章节", "problem": "问题", "action": "建议动作", "benefitOrRisk": "收益或风险" }
         ],
         "warnings": [],
         "errors": []
       }
   ```

4. **等待所有后台子 agent 完成**，汇总各模块文档创建状态和 `optimizationSuggestions`。

5. **生成 摘要.md**：

   ```
   Agent:
     description: 生成摘要
     prompt: |
       读取 {_path} 下所有 .md 文件，生成 摘要.md（{_path}/摘要.md）。
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}

       结构：
       # {projectName} 源码阅读指南
       > 上次修改：通过 {_dateCmdFull} 获取

       ## 项目概览
       名称、技术栈、构建方式、规模、许可证

       ## 模块功能摘要
       | 模块/目录 | 主要功能 | 核心文件 | 文档链接 |

       ## 源码阅读建议
       阅读顺序、重点章节、预备知识、调试技巧、扩展阅读

       ## 架构总览
       Mermaid graph，首行 {_mermaidThemeInit}

       返回 JSON：
       {
         "filePath": "{_path}/摘要.md",
         "status": "created",
         "moduleCount": 0,
         "qualityChecks": {
           "hasDate": true,
           "hasFocusSections": true,
           "hasCodeRefs": true,
           "mermaidChecked": true,
           "summarySynced": true
         },
         "warnings": [],
         "errors": []
       }
   ```

6. **输出结果**：
   ```
   init 完成：
     - 创建 认证模块.md
     - 创建 核心引擎.md
     - 创建 摘要.md

   优化建议：
     - 建议拆分 src/auth/AuthService.ts 中的认证与权限校验职责，降低后续扩展风险。
   ```

---

## `reinit` — 重新整理文档

### 执行流程

1. **确认输出路径**（可沿用 `_path`）
2. **检查目录下是否有文档**：无文档则提示需先有文档
3. **启动环境子 agent**（运行 `scripts/theme.sh`/`theme.ps1` + `date.sh`/`date.ps1` 获取 `_mermaidThemeInit` `_dateCmdFull` `_dateCmdCompact`；如果后续需要读取源码，同步执行 IDE MCP 访问策略检测）

4. **归档备份 + 扫描现有文档**：

   ```
   Agent:
     description: 归档并扫描文档
     prompt: |
       在 {_path} 下执行以下任务并按 JSON 返回结果：

       【归档备份】
       1) 时间戳：{_dateCmdCompact}
       2) 创建 {_path}/archive_<时间戳>/
       3) 将所有 .md 复制到归档目录，images/ 也一并复制
       注意：这是备份，不移动或删除原文件。

       【扫描现有文档】
       扫描 {_path} 下所有 .md（排除 archive_* 目录），读取内容分析结构。

       返回 JSON：
       {
         "status": "ok",
         "archivePath": "...", "fileCount": 0, "summaryExists": true/false,
         "docs": [
           { "path": "认证模块.md", "title": "认证模块", "sections": ["功能概述", "核心概念"] }
         ],
         "warnings": [],
         "errors": []
       }
   ```

5. **文档整理（并行）** — 对 `docs` 中每个文档（排除 `摘要.md`），最多 3 个并发启动后台子 agent：

   ```
   Agent:
     description: 整理文档 - {文档标题}
     run_in_background: true
     prompt: |
       重新整理文档：{_path}/{文档路径}
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}

       读取当前内容，按以下标准整理：
       1) 分类归入正确章节（功能概述、核心概念、关键流程、文件说明等）
       2) 补充缺失元素（概念定义、代码示例、代码引用、三维评估）
       3) 完善结构（补充重点关注、更新日期为 {_dateCmdFull}、修复 Mermaid 图）
       4) 不丢失任何原有有效信息
       5) 原有错误保留原文并标注修正建议

       完成后保存文件，并返回 JSON：
       {
         "filePath": "{_path}/{文档路径}",
         "status": "updated",
         "updatedSections": ["..."],
         "qualityChecks": {
           "hasDate": true,
           "hasFocusSections": true,
           "hasCodeRefs": true,
           "mermaidChecked": true,
           "summarySynced": false
         },
         "optimizationSuggestions": [
           { "target": "相对路径或文档章节", "problem": "问题", "action": "建议动作", "benefitOrRisk": "收益或风险" }
         ],
         "warnings": [],
         "errors": []
       }
   ```

6. **等待所有后台子 agent 完成**，汇总文档整理状态和 `optimizationSuggestions`。
7. **重构 摘要.md**（同 init 摘要生成，参考原始 摘要.md 保留项目概览信息）。
8. **输出结果**：
   ```
   reinit 完成（原始文档已归档至 {archivePath}）：
     - 更新 文档1.md
     - 更新 摘要.md

   优化建议：
     - 建议补齐 核心引擎.md 的异常分支说明，方便后续排查失败链路。
   ```

---

## `update` — 增量更新

### 执行流程

1. **确认输出路径**（可沿用 `_path`）
2. **解析用户需求**：明确目标文档、目标章节、变更内容
3. **启动环境子 agent**（运行 `scripts/` 下 `.sh`/`.ps1` 脚本获取变量；如果本次更新需要读取源码，同步执行 IDE MCP 访问策略检测）
4. **更新目标文档**：

   ```
   Agent:
     description: 更新文档 - {targetDoc}
     prompt: |
       更新文档 {_path}/{targetDoc}.md。
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}

       需求：{changes}

       操作规范：
       1) 读取当前文档，定位目标章节执行变更
       2) 更新日期为当前时间（通过 {_dateCmdFull} 获取）
       3) 新增图用 Mermaid，首行 {_mermaidThemeInit}
       4) 新增概念含定义、作用、代码示例、三维评估
       5) 保存文件

       返回 JSON：
       {
         "filePath": "...",
         "status": "updated",
         "updatedSections": ["章节1"],
         "needsSummaryUpdate": true/false,
         "qualityChecks": {
           "hasDate": true,
           "hasFocusSections": true,
           "hasCodeRefs": true,
           "mermaidChecked": true,
           "summarySynced": false
         },
         "optimizationSuggestions": [
           { "target": "相对路径或文档章节", "problem": "问题", "action": "建议动作", "benefitOrRisk": "收益或风险" }
         ],
         "warnings": [],
         "errors": []
       }
   ```

5. **按需同步摘要**：

   如果 `needsSummaryUpdate` 为 true，启动子 agent 更新 {_path}/摘要.md 的模块功能摘要表。否则跳过。

6. **输出结果**：
   ```
   update 完成：
     - 更新 {targetDoc}.md
     - 同步 摘要.md

   优化建议：
     - 建议在 {targetDoc}.md 增加关键入口的测试场景说明，降低后续维护成本。
   ```

---

## `byCase` — 按场景追溯源码

### 执行流程

1. **确认输出路径**（可沿用 `_path`）
2. **理解场景**：让用户描述具体场景，明确涉及模块和入口点
3. **启动环境子 agent**（运行 `scripts/` 下 `.sh`/`.ps1` 脚本获取变量，并执行 IDE MCP 访问策略检测）
4. **追溯源码**：

   ```
   Agent:
     description: 追溯源码 - {场景前 20 字}
     prompt: |
       追溯源码实现：{scenario}
       IDE MCP 访问策略：hasIDE={hasIDE}, provider={ideMcpProvider}, workspace={ideWorkspacePath}, capabilities={ideCapabilities}, fallbackReason={ideFallbackReason}

       溯源要求：
       1) 理解场景范围、模块、入口点、边界条件
       2) 从入口点逐层追溯调用链路
       3) hasIDE=true 时优先使用 IDE MCP 的搜索、索引、符号、定义、引用、诊断能力追溯；仅在缺少能力或调用失败时回退文件搜索工具，并记录原因
       4) 绝不运行源码——全程静态分析
       5) 记录完整调用栈和关键实现位置
       6) 识别核心参与者（模块/类/函数）
       {entryPoints ? '已知入口点：' + entryPoints : ''}

       返回 JSON：
       {
         "participants": [{ "name": "...", "role": "..." }],
         "callSteps": [{ "from": "...", "to": "...", "action": "...", "fileRef": "...", "isAsync": false }],
         "keyCodeSnippets": [{ "title": "...", "filePath": "...", "description": "..." }],
         "involvedModules": ["模块1"],
         "hasIDE": true/false,
         "ideFallbackReason": "...或null",
         "sourceRefs": ["相对路径1", "相对路径2"],
         "optimizationSuggestions": [
           { "target": "相对路径或文档章节", "problem": "问题", "action": "建议动作", "benefitOrRisk": "收益或风险" }
         ],
         "warnings": [],
         "errors": []
       }
   ```

5. **生成场景文档**：

   ```
   Agent:
     description: 生成场景文档
     prompt: |
       生成场景分析文档：{_path}/{场景名}.md
       场景：{scenario}
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}

       数据来源：
       - 参与者：{participants}
       - 调用步骤：{callSteps}

       文档结构：
       # 场景分析：{场景名}
       > 上次修改：通过 {_dateCmdFull} 获取

       ## 场景描述
       ## 涉及模块（| 模块 | 角色 |）
       ## 调用时序图（Mermaid sequenceDiagram，首行 {_mermaidThemeInit}，使用 Note over 标注步骤编号并附步骤说明表）
       ## 核心源码解读（逐行注释 + 三维评估）
       ## 术语表

       保存到 {_path}/{场景名}.md。

       返回 JSON：
       {
         "filePath": "{_path}/{场景名}.md",
         "status": "created",
         "updatedSections": ["场景描述", "涉及模块", "调用时序图", "核心源码解读", "术语表"],
         "qualityChecks": {
           "hasDate": true,
           "hasFocusSections": true,
           "hasCodeRefs": true,
           "mermaidChecked": true,
           "summarySynced": false
         },
         "warnings": [],
         "errors": []
       }
   ```

6. **同步摘要**：在 {_path}/摘要.md 的模块功能摘要表中新增此行文档记录。如已有则只更新描述。
7. **输出结果**：
   ```
   byCase 完成：
     - 创建 {场景名}.md（涉及 {N} 个模块，{M} 步调用）
     - 同步 摘要.md

   优化建议：
     - 建议为 {场景名} 的失败分支补充幂等处理说明，避免重试导致状态不一致。
   ```

---

## `help` — 查看帮助

```
/source-code-read init      — 首次分析项目并生成完整文档
/source-code-read reinit    — 归档后重新整理已有文档
/source-code-read update    — 增量更新指定文档
/source-code-read byCase    — 按场景追溯源码并生成分析文档
/source-code-read help      — 查看本帮助
```

---

## 注意事项

1. **主 agent 零文件操作**：主 agent 不得直接调用 Read/Edit/Write/Bash 等工具，所有文件操作、命令执行必须委托给子 agent。
2. **IDE MCP 访问优先**：读取或索引源码前，先确认目标源码已由 IDE 打开且当前 MCP 存在 IDE 提供者。检测通过后，文件读取、搜索、索引、诊断、符号、定义/引用跳转必须优先使用 IDE MCP；只有缺少能力或调用失败时才回退文件系统工具，并记录原因。
3. **绝不运行源码**：全程静态分析，不执行任何编译或运行命令。
4. **输出简洁**：非 `help` 指令执行完成后，先输出文件变更清单；如发现明确优化点，可追加简短优化建议。
5. **`_path` 记忆**：会话中 `init` 设定的 `_path` 可被 `reinit`/`update`/`byCase` 沿用。
6. **归档保留**：`reinit` 生成的归档目录执行后保留，不会自动删除。
7. **`run_in_background` 并发硬约束**：可并行任务（文档生成、整理）使用后台子 agent 批量执行，同一时间最多 3 个后台子 agent。不得一次性启动超过 3 个，剩余任务等待当前批次完成后再继续。
8. **子 agent 返回结构**：要求返回 JSON 结构化结果，避免完整文件内容占用上下文。
9. **子 agent 容错**：后台子 agent 可能返回 null 或无效结果。主 agent 应检查返回值，失败任务记录日志后继续其余任务。关键步骤失败则报错退出。
10. **reinit 中断风险**：按"先归档再整理"顺序执行，若整理阶段中断，归档目录已存在但部分文档未更新。可对比 `archive_*` 与当前文档手动处理。
