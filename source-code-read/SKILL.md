---
name: source-code-read
description: >
  源码阅读与文档生成技能。使用子 agent（Agent 工具）进行重分析以减小主上下文占用。
  从源码项目生成结构化 Markdown 文档。
  TRIGGER: 当用户输入 /source-code-read，或提及"阅读源码"、"源码分析"、"code reading"、
  "document code"、"项目文档"，或要求你分析一个项目时触发。
---

# Source Code Read — 源码阅读与文档生成 Skill

使用 **子 agent（Agent 工具）** 编排，将源码分析、文档生成等重操作委托给
独立的子 agent 执行，主 agent 只做路径确认、调度和结果汇总。

---

## 职责分工

| 角色 | 职责 | 做 | 不做 |
|------|------|----|------|
| **主 agent** | 编排与调度 | 解析指令、确定任务序列、启动子 agent、检查结果、输出最终文件清单 | Read/Edit/Write/Bash 等文件操作、代码分析、文档内容生成 |
| **子 agent** | 执行具体任务 | 环境检测、主题检测、日期命令设置、目录创建、源码分析、文档生成与修改、归档备份、摘要同步 | 调度决策、任务序列编排、跨任务传递上下文 |

所有子 agent 统一使用 `subagent_type: general-purpose`。

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

### 2. 画图约定

所有涉及画图场景，**统一优先使用 Mermaid**。每个 Mermaid 代码块**必须在首行插入 `{_mermaidThemeInit}`**。

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

### 3. 文档规范

- **日期**：文档顶部标注 `YYYY-MM-DD HH:mm` 格式的上次修改时间，**必须通过操作系统日期命令获取**，不得由 agent 自行推断
- **命名**：文档名用**中文**（术语表等保留原文的除外）
- **代码引用**：工程内用**相对路径**，工程外用**绝对路径**，文档末尾统一列出
- **概念解释**：每个概念含定义、作用、代码示例或使用场景
- **重点关注**：文档开头列出重点章节的 checkbox 列表
- **三维评估**：关键代码分析**好处**（为什么）、**替代方案**（其他方式及权衡）、**风险**（不这么实现的问题）
- **摘要同步**：新增/删除/改名文档或内容大改时，同步更新 `摘要.md` 的模块功能摘要表

### 4. 跨子 agent 变量

| 变量 | 含义 | 设置时机 |
|------|------|----------|
| `_path` | 文档输出目录（绝对路径） | init 步骤 1 |
| `_mermaidThemeInit` | Mermaid 主题初始化 `%%{init:{'theme':'dark/neutral'}}%%` | 每次指令执行前 |
| `_dateCmdFull` | 文档时间戳命令，如 `date '+%Y-%m-%d %H:%M'` | 每次指令执行前 |
| `_dateCmdCompact` | 归档命名命令，如 `date '+%Y%m%d%H%M%S'` | 每次指令执行前 |

### 5. Prompt 转义注意事项

| 问题 | 规则 |
|------|------|
| **JSON 大括号冲突** | prompt 中 `{` `}` 需用 `{{` `}}` 转义，避免被模板引擎解析为变量 |
| **代码块嵌套** | prompt 内嵌代码块用缩进 `    ``` ` 替代 ` ``` ` 避免解析错误 |
| **注入变量检查** | `{_path}` `{_dateCmdFull}` 等可能含空格/引号/反斜杠，注入后用反引号包裹 |

---

## `init` — 首次文档生成

### 执行流程

1. **确认输出路径 `_path`**：
   - 新会话：询问用户绝对路径
   - 如路径下已有文件：列出文件列表，询问是否继续使用
   - 在同一会话中记住 `_path`

2. **启动初始化子 agent**（环境准备 + 项目分析合并为一个子 agent）：

   ```
   Agent:
     description: 初始化项目分析
     prompt: |
       执行以下任务并按 JSON 返回结果：

       【任务 1 — 系统主题检测】
       检测当前系统主题并生成 Mermaid 主题变量：
       - Linux:   gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null
       - macOS:   defaults read -g AppleInterfaceStyle 2>/dev/null
       - Windows: powershell -Command "(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme).AppsUseLightTheme"
       结果含 "dark" 或 "0" → _mermaidThemeInit = "%%{init: {'theme':'dark'}}%%"
       其他 → _mermaidThemeInit = "%%{init: {'theme':'neutral'}}%%"

       【任务 2 — 日期命令设置】
       Linux/macOS → _dateCmdFull = "date '+%Y-%m-%d %H:%M'", _dateCmdCompact = "date '+%Y%m%d%H%M%S'"
       Windows → _dateCmdFull = "powershell -Command \"Get-Date -Format 'yyyy-MM-dd HH:mm'\"", _dateCmdCompact = "powershell -Command \"Get-Date -Format 'yyyyMMddHHmmss'\""

       【任务 3 — 项目环境检测】
       检查 IDE MCP 工具是否可用；获取项目名称、技术栈、构建方式、许可证。
       优先通过 IDE MCP 工具获取；否则回退到文件系统分析。

       【任务 4 — 模块扫描】
       扫描目录结构，识别主要模块/子系统。对每个模块给出中文名、路径、功能职责、核心文件（3-8 个）。
       优先通过 IDE MCP 工具了解项目结构。

       【任务 5 — 创建输出目录】
       mkdir -p {_path}/images

       返回 JSON（必须严格匹配此结构）：
       {
         "_mermaidThemeInit": "...",
         "_dateCmdFull": "...",
         "_dateCmdCompact": "...",
         "projectName": "...", "techStack": "...", "buildMethod": "...",
         "language": "...", "license": "...", "hasIDE": true/false,
         "projectScale": "...", "totalFiles": 0,
         "modules": [
           { "name": "模块中文名", "path": "src/xxx", "description": "功能职责", "keyFiles": ["文件1", "文件2"] }
         ]
       }
   ```
   如果子 agent 返回 null 或无效结果则报错退出。

3. **文档生成（并行）** — 遍历 `modules`，每模块启动一个后台子 agent：

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

       文档结构要求：
       - 上次修改：YYYY-MM-DD HH:mm（通过 {_dateCmdFull} 获取）
       - "重点关注"checkbox 列表
       - 功能概述
       - 核心概念（定义、作用、代码示例、三维评估）
       - 关键流程（Mermaid 图，首行 {_mermaidThemeInit}）
       - 类继承关系（Mermaid classDiagram）
       - 文件说明表（路径、职责、关键类/函数）
       - 引用代码索引（工程内相对路径，外部绝对路径）

       三维评估：好处/替代方案/风险。
       画图优先 Mermaid，首行插入 {_mermaidThemeInit}。

       先读取源码深入理解，关键文件参考：{keyFiles}。
       写入 {_path}/{模块名}.md。
   ```

4. **等待所有后台子 agent 完成**，汇总各模块文档创建状态。

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
   ```

6. **输出结果**：
   ```
   init 完成：
     - 创建 认证模块.md
     - 创建 核心引擎.md
     - 创建 摘要.md
   ```

---

## `reinit` — 重新整理文档

### 执行流程

1. **确认输出路径**（可沿用 `_path`）
2. **检查目录下是否有文档**：无文档则提示需先有文档
3. **启动环境子 agent**（同 init 步骤 2 的任务 1-2，返回 `_mermaidThemeInit` `_dateCmdFull` `_dateCmdCompact`）

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
         "archivePath": "...", "fileCount": 0, "summaryExists": true/false,
         "docs": [
           { "path": "认证模块.md", "title": "认证模块", "sections": ["功能概述", "核心概念"] }
         ]
       }
   ```

5. **文档整理（并行）** — 对 `docs` 中每个文档（排除 `摘要.md`）启动后台子 agent：

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
       3) 完善结构（补充"重点关注"checkbox、更新日期为 {_dateCmdFull}、修复 Mermaid 图）
       4) 不丢失任何原有有效信息
       5) 原有错误保留原文并标注修正建议

       完成后保存文件。
   ```

6. **等待所有后台子 agent 完成**。
7. **重构 摘要.md**（同 init 摘要生成，参考原始 摘要.md 保留项目概览信息）。
8. **输出结果**：
   ```
   reinit 完成（原始文档已归档至 {archivePath}）：
     - 更新 文档1.md
     - 更新 摘要.md
   ```

---

## `update` — 增量更新

### 执行流程

1. **确认输出路径**（可沿用 `_path`）
2. **解析用户需求**：明确目标文档、目标章节、变更内容
3. **启动环境子 agent**（同 reinit 步骤 3）
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
       { "filePath": "...", "updatedSections": ["章节1"], "needsSummaryUpdate": true/false }
   ```

5. **按需同步摘要**：

   如果 `needsSummaryUpdate` 为 true，启动子 agent 更新 {_path}/摘要.md 的模块功能摘要表。否则跳过。

6. **输出结果**：
   ```
   update 完成：
     - 更新 {targetDoc}.md
     - 同步 摘要.md
   ```

---

## `byCase` — 按场景追溯源码

### 执行流程

1. **确认输出路径**（可沿用 `_path`）
2. **理解场景**：让用户描述具体场景，明确涉及模块和入口点
3. **启动环境子 agent**（同 reinit 步骤 3）
4. **追溯源码**：

   ```
   Agent:
     description: 追溯源码 - {场景前 20 字}
     prompt: |
       追溯源码实现：{scenario}

       溯源要求：
       1) 理解场景范围、模块、入口点、边界条件
       2) 从入口点逐层追溯调用链路
       3) 使用 IDE MCP 工具或文件搜索工具追溯
       4) 绝不运行源码——全程静态分析
       5) 记录完整调用栈和关键实现位置
       6) 识别核心参与者（模块/类/函数）
       {entryPoints ? '已知入口点：' + entryPoints : ''}

       返回 JSON：
       {
         "participants": [{ "name": "...", "role": "..." }],
         "callSteps": [{ "from": "...", "to": "...", "action": "...", "fileRef": "...", "isAsync": false }],
         "keyCodeSnippets": [{ "title": "...", "filePath": "...", "description": "..." }],
         "involvedModules": ["模块1"]
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
       ## 调用时序图（Mermaid sequenceDiagram，首行 {_mermaidThemeInit}）
       ## 核心源码解读（逐行注释 + 三维评估）
       ## 术语表

       保存到 {_path}/{场景名}.md。
   ```

6. **同步摘要**：在 {_path}/摘要.md 的模块功能摘要表中新增此行文档记录。如已有则只更新描述。
7. **输出结果**：
   ```
   byCase 完成：
     - 创建 {场景名}.md（涉及 {N} 个模块，{M} 步调用）
     - 同步 摘要.md
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
2. **IDE MCP 优先**：子 agent 分析源码时优先使用 IDE MCP 工具。
3. **绝不运行源码**：全程静态分析，不执行任何编译或运行命令。
4. **输出简洁**：非 `help` 指令执行完成后，只输出文件变更清单，不做延伸说明。
5. **`_path` 记忆**：会话中 `init` 设定的 `_path` 可被 `reinit`/`update`/`byCase` 沿用。
6. **归档保留**：`reinit` 生成的归档目录执行后保留，不会自动删除。
7. **`run_in_background` 并发**：可并行任务（文档生成、整理）使用后台子 agent 同时执行。模块 >10 时每批 5-8 个并发，避免资源争抢。
8. **子 agent 返回结构**：要求返回 JSON 结构化结果，避免完整文件内容占用上下文。
9. **子 agent 容错**：后台子 agent 可能返回 null 或无效结果。主 agent 应检查返回值，失败任务记录日志后继续其余任务。关键步骤失败则报错退出。
10. **reinit 中断风险**：按"先归档再整理"顺序执行，若整理阶段中断，归档目录已存在但部分文档未更新。可对比 `archive_*` 与当前文档手动处理。
