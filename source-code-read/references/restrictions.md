# Source Code Read 限制与通用规范

本文档集中存放 `/source-code-read` 的限制、通用规范、质量门禁和跨子 agent 状态约定。
执行任意非 `help` 指令前必须读取本文档。

---

## 目录

- [通用规范](#通用规范)
- [注意事项](#注意事项)
- 文档章节与内容标准见 [document-standards.md](document-standards.md)。

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
  "hasStandardSections": true,
  "hasDetailedAnalysis": true,
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
   - 时序图额外校验：检查每一步是否都有 `Note over` 标注步骤编号，并在图后附有步骤说明段落（格式：'序号 步骤名：简要说明'）
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

2. **步骤说明段落**：在 Mermaid 代码块下方紧跟着一段文字说明，按步骤阶段分组，每段用 "序号范围" 开头描述该阶段整体做了什么：

   ````markdown
   ```mermaid
   {_mermaidThemeInit}
   flowchart LR
     1[解析请求] --> 1.1[验证参数]
     1.1 --> 1.2[执行逻辑]
     1.1 --> 1.3[降级处理]
     1.2 --> 2[返回结果]
   ```

   1-2 请求处理：从 HTTP 请求中提取参数并反序列化，验证必填字段和格式合法性，合法则执行业务逻辑，不合法则降级返回默认结果或错误码。

   3 响应返回：将处理结果序列化为 JSON 并写入响应体。
   ````

3. **说明内容要求**：每段说明应包含该阶段整体做了什么、涉及哪些步骤、关键决策或边界条件（如有），如失败分支、数据流向等

#### 时序图步骤编号与说明

生成 `sequenceDiagram` 类型的 Mermaid 图时，必须遵守以下规范：

1. **消息编号**：每条消息使用 `Note over ...: N. 步骤说明` 的方式在图上嵌入步骤编号，用法与流程图编号一致：

   | 层级 | 格式 | 示例 |
   |------|------|------|
   | 一级步骤 | `1.` `2.` `3.` … | `Note over A, B: 1. 发送请求` |
   | 二级子步骤 | `1.1` `1.2` `2.1` … | `Note over B, C: 2.1 校验参数` |

2. **步骤说明段落**：在 Mermaid 代码块下方紧跟着一段文字说明，按步骤阶段分组，每段用 "序号范围" 开头描述该阶段整体做了什么：

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

   1-2 请求接入与转换：网关接收 HTTP 请求并解析参数，将请求转换为内部 RPC 格式后转发到服务层。

   3-4 数据持久化与响应：服务层将业务实体写入数据库，封装返回的 ID，网关将结果序列化为 JSON 响应返回给客户端。
   ````

3. **说明内容要求**：每段说明应包含该阶段整体做了什么、涉及哪些参与者、关键决策或边界条件（如有），如异步回调、失败分支、数据流向等。

4. **每步必编号与 Note**：时序图中**每一步骤都必须有 `Note over` 标注编号**，不允许仅靠消息行文本承载编号。编号粒度以「一个逻辑步骤」为单位，每条 `->>` 消息前后都需有对应的 `Note over`。编号必须与下方的步骤说明段落中的编号一一对应。

5. **Note 描述要求**：`Note over` 中的描述内容必须包含步骤编号 + 简短的步骤名（如 `Note over API: 1. 接收请求`），且步骤名与下方段落中的描述一致。

### 6. 文档规范

- **日期**：文档顶部标注 `YYYY-MM-DD HH:mm` 格式的上次修改时间，**必须通过操作系统日期命令获取**，不得由 agent 自行推断
- **命名**：文档名用**中文**（术语表等保留原文的除外）
- **文档类型**：支持 6 种文档类型，每种有独立的章节结构定义：
  - **工程目录**：入口索引，含概览、路线、文档清单、架构总览、维护记录
  - **工程概览**：目录结构图与目录说明
  - **编译运行流程**：技术栈、依赖、构建/运行/测试流程
  - **模块文档**：模块级源码分析
  - **核心源码阅读**：深入逐行源码解读
  - **场景文档**：按场景追溯源码分析
- **标准章节**：所有文档类型必须使用 [document-sections.md](document-sections.md) 定义的对应章节顺序与章节标题；章节不适用时保留标题并说明原因
- **代码引用**：工程内用**相对路径**，工程外用**绝对路径**，文档末尾统一列出
- **概念解释**：每个概念含定义、作用、代码示例或使用场景
- **重点关注**：文档开头列出重点关注的章节，不应为空泛列表
- **三维评估**：关键代码分析**好处**（为什么）、**替代方案**（其他方式及权衡）、**风险**（不这么实现的问题）
- **工程目录同步**：新增/删除/改名文档或内容大改时，同步更新 `工程目录.md` 的文档清单、模块功能摘要表和关键场景索引
- **质量门禁**：保存前检查标准章节、细致分析、日期、重点关注、代码引用、Mermaid 首行、步骤编号与说明对应、工程目录同步标记；缺失则修复后再返回成功。工程目录和工程概览等结构文档可适当放宽部分门禁项

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
## 注意事项

1. **主 agent 零文件操作**：主 agent 不得直接调用 Read/Edit/Write/Bash 等工具，所有文件操作、命令执行必须委托给子 agent。
2. **IDE MCP 访问优先**：读取或索引源码前，先确认目标源码已由 IDE 打开且当前 MCP 存在 IDE 提供者。检测通过后，文件读取、搜索、索引、诊断、符号、定义/引用跳转必须优先使用 IDE MCP；只有缺少能力或调用失败时才回退文件系统工具，并记录原因。
3. **绝不运行源码**：全程静态分析，不执行任何编译或运行命令。
4. **输出简洁**：非 `help` 指令执行完成后，先输出文件变更清单；如发现明确优化点，可追加简短优化建议。
5. **`_path` 记忆**：会话中 `init` 设定的 `_path` 可被 `reinit`/`update`/`byCase` 沿用。
6. **归档保留**：`reinit` 生成的归档目录执行后保留，不会自动删除；不影响原文档。
7. **`run_in_background` 并发硬约束**：可并行任务（文档生成、整理）使用后台子 agent 批量执行，同一时间最多 3 个后台子 agent。不得一次性启动超过 3 个，剩余任务等待当前批次完成后再继续。
8. **子 agent 返回结构**：要求返回 JSON 结构化结果，避免完整文件内容占用上下文。
9. **子 agent 容错**：后台子 agent 可能返回 null 或无效结果。主 agent 应检查返回值，失败任务记录日志后继续其余任务。关键步骤失败则报错退出。
