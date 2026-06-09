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

## 指令总览

| 指令 | 功能 |
|------|------|
| `init` | 首次分析：归纳模块并生成完整文档 |
| `reinit` | 归档旧文档→按 `init` 标准重新整理 |
| `update` | 增量更新指定文档 |
| `byCase` | 按场景追溯源码，生成时序图和实现分析 |
| `help` | 输出简要帮助 |

---

## 系统主题检测

每次执行 init/reinit/update/byCase 指令前，主 agent 先执行系统主题检测，设置 Mermaid 主题变量 `_mermaidThemeInit`。

1. **执行检测命令**（兼容多平台，依次尝试，取第一个有输出的结果）：
   - Linux:   `gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null`
   - macOS:   `defaults read -g AppleInterfaceStyle 2>/dev/null`
   - Windows: `powershell -Command "(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme).AppsUseLightTheme"`

2. **判定并设置变量**：
   - 结果含 "dark" 或 "Dark" 或 "0" → `_mermaidThemeInit = "%%{init: {'theme':'dark'}}%%"`
   - 其他（含 "light"、"default"、"1"、空） → `_mermaidThemeInit = "%%{init: {'theme':'neutral'}}%%"`

设置完成后，后续所有生成文档中的 Mermaid 图**顶部都必须包含 `{_mermaidThemeInit}`**。

---

## 通用规范

### 画图约定

所有涉及画图场景，**统一优先使用 Mermaid**（GitHub/GitLab/VS Code 原生渲染）。

每个 Mermaid 代码块**必须在首行插入 `{_mermaidThemeInit}`** 以适配当前系统主题。

| 场景 | 优先使用 | 兜底 |
|------|----------|------|
| 类继承/接口实现 | `` ```mermaid `` + `{_mermaidThemeInit}` + classDiagram | 文本 UML |
| 调用流程/交互 | `` ```mermaid `` + `{_mermaidThemeInit}` + sequenceDiagram | 文字流程 |
| 状态流转 | `` ```mermaid `` + `{_mermaidThemeInit}` + stateDiagram-v2 | 文字状态表 |
| 流程图/算法逻辑 | `` ```mermaid `` + `{_mermaidThemeInit}` + flowchart | 步骤列表 |
| 架构/模块依赖 | `` ```mermaid `` + `{_mermaidThemeInit}` + graph | 层次列表 |
| 内存布局/结构体 | `` ```text `` 标注高/低地址 | — |

### 日期命令变量

定义会话变量 `_dateCmdFull` 和 `_dateCmdCompact`，主 agent 在每次执行指令前根据当前 OS 设置：

| 变量 | Linux/macOS | Windows |
|------|------------|---------|
| `_dateCmdFull`（文档时间戳） | `date '+%Y-%m-%d %H:%M'` | `powershell -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'"` |
| `_dateCmdCompact`（归档命名） | `date '+%Y%m%d%H%M%S'` | `powershell -Command "Get-Date -Format 'yyyyMMddHHmmss'"` |

所有 agent prompt 中使用 `{_dateCmdFull}` / `{_dateCmdCompact}` 引用日期命令，不再重复书写完整命令。

### 文档规范

- **日期**：文档顶部标注 `YYYY-MM-DD HH:mm` 格式的上次修改时间，**必须通过 `{_dateCmdFull}` 获取本地操作系统时间**，不得由 agent 自行推断
- **命名**：文档名用**中文**（术语表等保留原文的除外）
- **代码引用**：工程内用**相对路径**，工程外用**绝对路径**，文档末尾统一列出
- **概念解释**：每个概念含定义、作用、代码示例或使用场景
- **重点关注**：文档开头列出重点章节的 checkbox 列表
- **三维评估**：关键代码从三个维度分析——**好处**（为什么）、**替代方案**（其他方式及权衡）、**风险**（不这么实现的问题）
- **摘要同步**：新增/删除/改名文档或内容大改时，同步更新 `摘要.md` 的模块功能摘要表

---

## `init` — 首次文档生成

### 执行流程

1. **确认输出路径 `_path`**：
   - 新会话：询问用户绝对路径，如不存在则创建
   - 如路径下已有文件：列出文件列表，询问是否继续使用
   - 在本次会话中记住该路径（`reinit`/`update`/`byCase` 可沿用）

2. **环境检测** — 启动子 agent 检测项目信息：
   ```
   Agent:
     description: 检测项目环境
     subagent_type: general-purpose
     prompt: |
       检测当前项目环境信息：
       1) 检查 JetBrains IDE MCP 工具（ide_index_status 等）是否可用
       2) 获取项目名称（从项目元数据推断）
       3) 识别技术栈：语言、框架、构建工具、运行时
       4) 获取构建方式、环境要求
       5) 识别许可证（如有）
       如果 IDE 工具可用，优先通过 IDE 获取项目配置；否则回退到文件系统分析。
       返回 JSON 格式结果：{ projectName, techStack, buildMethod, language, license, hasIDE }
   ```
   从返回结果中提取项目名称、技术栈等信息。如果子 agent 未返回有效结果则报错退出。

3. **模块扫描** — 启动子 agent 扫描项目结构：
   ```
   Agent:
     description: 扫描项目模块
     subagent_type: general-purpose
     prompt: |
       扫描当前项目的目录结构，识别主要模块/子系统。对于每个模块：
       1) 给出中文模块名
       2) 标注对应源码目录
       3) 概括主要功能职责
       4) 列出该模块的核心文件（3-8 个关键文件）
       5) 评估项目规模（总文件数、代码行数估算）
       优先通过 IDE MCP 工具了解项目结构。
       返回 JSON 格式结果：
       { projectScale, totalFiles, modules: [{ name, path, description, keyFiles }] }
   ```
   从结果中提取 `modules` 列表。如果无有效模块则报错退出。

4. **创建输出目录**：主 agent 直接在 `_path` 执行 `mkdir -p {_path}/images` 创建目录及 `images/` 子目录。

5. **文档生成（并行）** — 为每个模块启动一个后台子 agent：
   遍历 `modules` 列表，对每个模块执行：
   ```
   Agent:
     description: 生成文档 - {模块名}
     subagent_type: general-purpose
     run_in_background: true
     prompt: |
       分析模块 "{模块名}"（目录：{模块路径}）并为它生成结构化文档。

       输出目录：{_path}
       文档命名：{模块名}.md（中文名）

       文档结构要求：
       - 顶部标注上次修改日期（YYYY-MM-DD HH:mm 格式），**日期必须通过 `{_dateCmdFull}` 获取，不得自行推断**
       - 包含"重点关注"章节（checkbox 列表）
       - 功能概述
       - 核心概念（每个概念：定义、作用、代码示例、三维评估）
       - 关键流程（使用 Mermaid 时序图/流程图，首行插入 `{_mermaidThemeInit}`）
       - 如有类继承关系，使用 Mermaid classDiagram（首行插入 `{_mermaidThemeInit}`）
       - 如有内存结构分析，标注高/低地址
       - 文件说明表（路径、职责、关键类/函数）
       - 引用代码索引（工程内用相对路径，外部用绝对路径）

       三维评估：对关键代码分析好处、替代方案、风险。

       画图优先使用 Mermaid：classDiagram / sequenceDiagram / flowchart / graph。每个 Mermaid 代码块首行插入 `{_mermaidThemeInit}`。

       先读取该目录下的源码文件，深入理解实现后再生成文档。
       关键文件参考：{模块的 keyFiles}
       完成后将文档写入 {_path}/{模块名}.md。
   ```
   记录每个后台子 agent 返回的信息。

6. **等待所有后台子 agent 完成**，汇总各模块的文档信息。

7. **生成 摘要.md** — 启动子 agent：
   ```
   Agent:
     description: 生成摘要
     subagent_type: general-purpose
     prompt: |
       读取 {_path} 目录下的所有 .md 文件，为该项目生成 摘要.md。

       文档位置：{_path}/摘要.md

       摘要.md 结构：
       # {项目名称} 源码阅读指南
       > 上次修改：通过 {_dateCmdFull} 获取

       ## 项目概览
       项目名称、技术栈、构建方式、项目规模、许可证

       ## 模块功能摘要
       | 模块/目录 | 主要功能 | 核心文件 | 文档链接 |
       （为每个已生成的文档创建一行）

       ## 源码阅读建议
       阅读顺序、重点章节、预备知识、调试技巧、扩展阅读

       ## 架构总览
       （使用 Mermaid graph 绘制模块依赖图，首行插入 `{_mermaidThemeInit}`）

       项目信息参考：名称={projectName}，技术栈={techStack}，构建={buildMethod}
   ```

8. **输出结果**：一行列出创建的文件，例如：
   ```
   init 完成：
     - 创建 认证模块.md
     - 创建 核心引擎.md
     - 创建 数据持久化.md
     - 创建 摘要.md
   ```

---

## `reinit` — 重新整理文档

### 执行流程

1. **确认输出路径**（同 `init`，可沿用会话内已有 `_path`）
2. **检查目录下是否有文档**：无文档则提示——`reinit` 需要已有文档为输入

3. **归档备份** — 启动子 agent 归档现有文档：
   ```
   Agent:
     description: 归档现有文档
     subagent_type: general-purpose
     prompt: |
       归档 {_path} 下的文档文件：
       1) 生成时间戳：`{_dateCmdCompact}`
       2) 创建归档目录：{_path}/archive_<时间戳>/
       3) 将 {_path} 下所有 .md 文件复制到归档目录中
       4) 如果有 images/ 子目录也一并复制
       注意：这是备份操作，不要移动或删除原文件。
       返回 JSON 格式结果：{ archivePath, fileCount }
   ```
   从结果中提取 `archivePath` 和 `fileCount`。如果备份失败则报错退出。

4. **扫描已有文档** — 启动子 agent 读取现存文档：
   ```
   Agent:
     description: 扫描现有文档
     subagent_type: general-purpose
     prompt: |
       扫描 {_path} 下的所有 .md 文件（排除 archive_* 目录）。
       读取每个文件的内容，分析结构和覆盖范围。
       返回每个文件的路径及主要章节标题列表。
       返回 JSON 格式结果：
       { docs: [{ path, title, sections }] }
   ```
5. **重新整理（并行）** — 对每个文档（排除 `摘要.md`）启动后台子 agent 整理：
   遍历 `docs` 列表，对每个文档执行：
   ```
   Agent:
     description: 整理文档 - {文档标题}
     subagent_type: general-purpose
     run_in_background: true
     prompt: |
       重新整理文档：{_path}/{文档路径}

       读取当前文件内容，按照以下标准重新整理：

       整理要求：
       1) 分类归入正确章节：功能概述、核心概念、关键流程、文件说明等
       2) 补充缺失元素：
          - 缺失的概念补充定义和代码示例
          - 缺失的代码引用路径补充完整
          - 关键代码补充三维评估（好处/替代方案/风险）
       3) 完善结构：
          - 补充文档顶部的"重点关注"checkbox 章节
          - 更新"上次修改"日期为当前时间（**必须通过 `{_dateCmdFull}` 获取**）
          - 确保文档名为中文（术语表等特殊文档除外）
          - 补全或修复 Mermaid 图（每个图首行必须插入 `{_mermaidThemeInit}`）
       4) 不丢失任何原有有效信息
       5) 原有内容如有错误，保留原文基础上标注修正建议

       完成修改后保存文件。
   ```
   记录每个后台子 agent 返回的信息。

6. **等待所有后台子 agent 完成**。

7. **重构 摘要.md** — 启动子 agent：
   ```
   Agent:
     description: 重构摘要
     subagent_type: general-purpose
     prompt: |
       读取 {_path} 下所有已整理完成的 .md 文件（排除 archive_* 目录），
       重新生成 摘要.md（{_path}/摘要.md）。

       摘要.md 结构：
       # 项目源码阅读指南
       > 上次修改：通过 {_dateCmdFull} 获取

       ## 项目概览
       （如原 摘要.md 中有项目概览信息则保留）

       ## 模块功能摘要
       | 模块 | 主要功能 | 核心文件 | 文档链接 |

       ## 源码阅读建议

       ## 架构总览
       （使用 Mermaid graph，首行插入 `{_mermaidThemeInit}`）

       若原有 摘要.md 中的某些信息在整理后不再准确，按最新状态更新。
   ```

8. **输出结果**：
   ```
   reinit 完成（原始文档已归档至 {archivePath}）：
     - 更新 文档1.md
     - 更新 摘要.md
   ```

---

## `update` — 增量更新

### 执行流程

1. **确认输出路径**（可沿用会话内 `_path`）
2. **解析用户需求**：明确目标文档、目标章节、变更内容
3. **更新目标文档** — 启动子 agent 读取并修改目标文档：
   ```
   Agent:
     description: 更新文档 - {targetDoc}
     subagent_type: general-purpose
     prompt: |
       更新文档 {_path}/{targetDoc}.md。

       需求：
       {changes 内容}

       操作规范：
       1) 读取当前文档内容
       2) 定位到目标章节并执行变更（新增/修改/删除）
       3) 更新文档顶部的"上次修改"日期为当前时间（**必须通过 `{_dateCmdFull}` 获取**）
       4) 所有新增的图优先使用 Mermaid 绘制（每个 Mermaid 代码块首行插入 `{_mermaidThemeInit}`）
       5) 新增的概念需包含定义、作用、代码示例和三维评估

       保存修改后的文件。
       返回 JSON 格式结果：{ filePath, updatedSections: [...], needsSummaryUpdate: bool }
   ```
   从结果中提取 `needsSummaryUpdate` 判断是否需要更新摘要。

4. **按需同步摘要.md** — 如果 `needsSummaryUpdate` 为 true，启动子 agent：
   ```
   Agent:
     description: 同步摘要
     subagent_type: general-purpose
     prompt: |
       根据变更更新 {_path}/摘要.md 的"模块功能摘要"表。
       变更内容：{changes}
       （如涉及新增/删除文档则增删表行，如内容大改则更新对应描述）
   ```
   否则跳过此步。

5. **输出结果**：
   ```
   update 完成：
     - 更新 {targetDoc}.md（更新了 {updatedSections}）
     - 同步 摘要.md
   ```

---
## `byCase` — 按场景追溯源码

### 执行流程

1. **确认输出路径**（可沿用会话内 `_path`）
2. **理解场景**：让用户描述具体场景/概念，明确涉及模块和入口点
3. **追溯源码** — 启动子 agent 从入口追溯调用链路：
   ```
   Agent:
     description: 追溯源码 - {场景描述前 20 字}
     subagent_type: general-purpose
     prompt: |
       追溯源码实现：{scenario}

       溯源要求：
       1) 理解场景范围：涉及哪些模块、关键入口点、边界条件
       2) 从入口点出发，逐层追溯源码调用链路
       3) 使用 IDE MCP 工具（ide_find_references、ide_call_hierarchy 等）或文件搜索工具追溯
       4) 绝不运行项目源码——全程静态分析
       5) 记录完整调用栈和关键实现位置
       6) 识别核心参与者（模块/类/函数）
       {entryPoints ? '已知入口点：' + entryPoints : ''}

       返回 JSON 格式结果：
       { participants: [{ name, role }], callSteps: [{ from, to, action, fileRef, isAsync }], keyCodeSnippets: [{ title, filePath, description }], involvedModules: [...] }
   ```
   如果未找到匹配的源码链路则报告用户并退出。

4. **生成场景文档** — 启动子 agent：
   ```
   Agent:
     description: 生成场景文档
     subagent_type: general-purpose
     prompt: |
       生成场景分析文档：{_path}/{场景名}.md

       场景：{scenario}

       文档结构：
       # 场景分析：{场景名}
       > 上次修改：通过 {_dateCmdFull} 获取

       ## 场景描述
       （用户提供的场景说明）

       ## 涉及模块
       | 模块 | 角色 |
       （列出全部涉及模块）

       ## 调用时序图
       （使用 Mermaid sequenceDiagram，首行插入 `{_mermaidThemeInit}`，标注同步/异步、关键说明）

       ## 核心源码解读
       对关键代码进行逐行注释解读，每段代码后跟三维评估（好处/替代方案/风险）

       ## 术语表

       画图约定：优先使用 Mermaid 时序图（首行插入 `{_mermaidThemeInit}`），关键路径添加 Note over。

       代码引用：工程内使用相对路径，外部使用绝对路径。

       参与者和调用步骤来自溯源结果。
       保存文档到 {_path}/{场景名}.md。
   ```

5. **输出结果**：
   ```
   byCase 完成：
     - 创建 {场景名}.md（涉及 {N} 个模块，{M} 步调用）
   ```

---

## `help` — 查看帮助

输出简要指令说明：

```
/source-code-read init      — 首次分析项目并生成完整文档
/source-code-read reinit    — 归档后重新整理已有文档
/source-code-read update    — 增量更新指定文档
/source-code-read byCase    — 按场景追溯源码并生成分析文档
/source-code-read help      — 查看本帮助
```

---

## 注意事项

1. **IDE MCP 优先**：子 agent 分析源码时优先使用 IDE MCP 工具。
2. **绝不运行源码**：全程静态分析，不执行任何编译或运行命令。
3. **输出简洁**：非 `help` 指令执行完成后，只输出文件变更清单，不做延伸说明。
4. **`_path` 记忆**：同一会话中 `init` 设定的 `_path` 可被 `reinit`/`update`/`byCase` 沿用。
5. **归档保留**：`reinit` 生成的归档目录在执行后保留，不会自动删除。
6. **`run_in_background` 并发**：文档生成、重新整理等可并行任务使用 `run_in_background: true` 启动多个子 agent 同时执行，完成后汇总结果。若模块较多（>10），应分批启动，每批 5-8 个 agent 并发，避免资源争抢。
7. **子 agent 返回结构**：要求每个子 agent 返回 JSON 格式的结构化结果，避免返回完整文件内容占用上下文。
8. **子 agent 容错**：后台子 agent 可能因超时、工具不可用等原因返回 null 或无效结果。主 agent 应检查每个返回值，失败的任务记录日志后继续处理其余任务，避免单点失败阻塞全流程。关键步骤（环境检测、模块扫描）失败则报错退出。
9. **reinit 中断风险**：reinit 按"先归档再整理"顺序执行，若整理阶段中断，归档目录已存在但文档可能未全部更新。中断后可检查 `archive_*` 目录与当前文档的差异，手动整理未更新部分。
