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

       【任务 3 — 模块扫描】
       扫描目录结构，识别主要模块/子系统。对每个模块给出中文名、路径、功能职责、核心文件（3-8 个）。
       hasIDE=true 时必须优先通过 IDE MCP 的 workspace/search/symbol/index 能力了解项目结构；只有缺少能力或调用失败时才回退文件系统扫描，并记录原因。
       文件系统兜底扫描时排除 .git、node_modules、dist、build、target、out、.next、.gradle、.idea、.vscode、archive_* 等目录。

       【任务 4 — 收集构建与运行信息】
       通过分析源码目录中的配置文件（如 package.json、pom.xml、build.gradle、Cargo.toml、go.mod、Makefile、CMakeLists.txt、Dockerfile 等）收集：
       - 编译构建方式（命令、工具链）
       - 运行方式（本地启动命令、Docker 配置）
       - 测试框架与测试目录（如有）
       - 核心依赖清单（语言、框架、中间件、数据库等）
       - 环境要求（OS、运行时版本、内存/磁盘）
       说明信息来自哪些配置文件。

       【任务 5 — 创建输出目录】
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
         "dependencies": [
           { "name": "依赖名", "version": "版本", "purpose": "用途" }
         ],
         "buildInfo": {
           "buildCommands": ["命令1", "命令2"],
           "runCommands": ["命令1"],
           "testCommands": ["命令1"],
           "buildOutput": "编译产物路径",
           "hasTests": true/false,
           "testFramework": "Jest/JUnit/...",
           "testDir": "tests/"
         },
         "envRequirements": {
           "os": "跨平台/Linux/macOS/Windows",
           "runtime": "Node 18+ / JDK 17 / ...",
           "dockerSupport": true/false
         },
         "warnings": [],
         "errors": []
       }
   ```
   如果子 agent 返回 null 或无效结果则报错退出。

3. **生成结构文档 + 第一轮模块文档（并行）** — 工程概览和编译运行流程与模块文档同时生成，最多 3 个并发：

   **3a. 生成工程概览.md：**

   ```
   Agent:
     description: 生成工程概览
     run_in_background: true
     prompt: |
       生成工程概览文档：{_path}/工程概览.md
       源码根目录：{_sourcePath}
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}

       先读取 source-code-read/references/document-sections.md 的"工程概览文档章节"确定章节结构，
       再读取 source-code-read/references/document-content.md 的"工程概览文档内容规范"确定各章节编写要求。
       必须保留工程概览文档标准中的全部章节标题和顺序。

       任务：
       1) 使用文件系统或 IDE MCP 扫描 {_sourcePath} 的目录树（深度 3-4 级，根据项目规模调整）。
          若 hasIDE=true，优先使用 IDE MCP 的 workspace 信息能力获取目录结构。
       2) 识别各级目录的作用：从顶层配置文件（README、package.json、pom.xml 等）获取项目描述。
       3) 生成目录树 Mermaid graph，每个节点标注职责简述。
       4) 为每一级目录写一段说明：存放什么文件，具体干什么。
       5) 如果子目录有对应的模块文档（参考 modules 列表），添加链接。

       输出严格遵循"工程概览文档标准"的结构。

       返回 JSON：
       {
         "filePath": "{_path}/工程概览.md",
         "status": "created",
         "hasIDE": true/false,
         "ideFallbackReason": "...或null",
         "qualityChecks": {
           "hasStandardSections": true,
           "hasDetailedAnalysis": true,
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

   **3b. 生成编译运行流程.md：**

   ```
   Agent:
     description: 生成编译运行流程
     run_in_background: true
     prompt: |
       生成编译运行流程文档：{_path}/编译运行流程.md
       源码根目录：{_sourcePath}
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}

       先读取 source-code-read/references/document-sections.md 的"编译运行流程文档章节"确定章节结构，
       再读取 source-code-read/references/document-content.md 的"编译运行流程文档内容规范"确定各章节编写要求。
       必须保留编译运行流程文档标准中的全部章节标题和顺序。

       已知项目信息：
       - 技术栈：{techStack}
       - 构建方式：{buildMethod}
       - 依赖：{dependencies}
       - 构建信息：{buildInfo}
       - 环境要求：{envRequirements}

       任务：
       1) 基于已知信息整理技术栈与依赖表格。
       2) 读取源码根目录下的关键构建配置文件（如 package.json、pom.xml、Dockerfile、Makefile、README 等），
          核实并填充详细的编译步骤、运行步骤、测试步骤。
       3) 如果 {buildInfo.hasTests} 为 true，详细写出测试编译和运行流程。
       4) 每步说明做什么以及对应命令。

       输出严格遵循"编译运行流程文档标准"的结构。

       返回 JSON：
       {
         "filePath": "{_path}/编译运行流程.md",
         "status": "created",
         "qualityChecks": {
           "hasStandardSections": true,
           "hasDetailedAnalysis": true,
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

   **3c. 同时启动第一轮模块文档（同步骤 4 格式，最多 3 个并发，若步骤 3a/3b 已达并发上限则排队）：**

   参见步骤 4 的模块文档生成模板，从 modules 列表中取前 N 个生成，N = 3 - (3a 和 3b 已占用的并发数)。

4. **模块文档生成（并行）** — 遍历 `modules`，最多 3 个并发启动后台子 agent（注意与步骤 3a/3b 合并不超过 3 个并发上限）：

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

       章节标准要求：
       - 必须读取并遵守 source-code-read/references/document-sections.md 的"模块文档章节"和
         source-code-read/references/document-content.md 的"模块文档内容规范"。
       - 必须保留模块文档标准中的全部章节标题和顺序；不适用章节保留标题并说明原因。
       - 每个核心章节必须包含源码证据、关键判断、数据/状态变化；不得只罗列文件名。
       - 关键实现必须包含三维评估：好处/替代方案/风险。
       - "代码引用索引"必须集中列出正文引用过的源码位置。
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
           "hasStandardSections": true,
           "hasDetailedAnalysis": true,
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

5. **等待所有后台子 agent 完成**（工程概览、编译运行流程和所有模块文档），汇总各文档创建状态和 `optimizationSuggestions`。

6. **（可选）生成核心源码阅读文档** — 对于 modules 中识别出的核心模块，用户确认后生成核心源码阅读文档。
   如果用户未指定具体模块，默认选择 modules 中 `keyFiles` 数量最多的核心模块生成。
   最多 3 个并发。

   ```
   Agent:
     description: 生成核心源码分析 - {模块名}
     run_in_background: true
     prompt: |
       生成核心源码阅读文档：{_path}/核心源码分析-{模块名}.md
       针对模块 "{模块名}"（{模块路径}）进行细致的源码阅读分析。

       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}
       IDE MCP 访问策略：hasIDE={hasIDE}, provider={ideMcpProvider}, workspace={ideWorkspacePath}, capabilities={ideCapabilities}, fallbackReason={ideFallbackReason}

       章节标准要求：
       - 必须读取并遵守 source-code-read/references/document-sections.md 的"核心源码阅读文档章节"和
         source-code-read/references/document-content.md 的"核心源码阅读文档内容规范"。
       - 必须保留核心源码阅读文档标准中的全部章节标题和顺序；不适用章节保留标题并说明原因。
       - 主线流程逐行解读引用具体源码行号。
       - 设计模式与架构决策必须包含三维评估。
       - "代码引用索引"必须集中列出正文引用过的源码位置。
       画图优先 Mermaid，首行插入 {_mermaidThemeInit}。

       参考模块文档：{_path}/{模块名}.md（已生成）。
       若 hasIDE=true，优先使用 IDE MCP 读取源码；仅在缺少能力或调用失败时回退文件系统工具。

       写入 {_path}/核心源码分析-{模块名}.md。

       返回 JSON：
       {
         "filePath": "{_path}/核心源码分析-{模块名}.md",
         "status": "created",
         "hasIDE": true/false,
         "ideFallbackReason": "...或null",
         "sourceRefs": ["相对路径1", "相对路径2"],
         "qualityChecks": {
           "hasStandardSections": true,
           "hasDetailedAnalysis": true,
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

   **等待所有核心源码分析子 agent 完成后继续。**

7. **生成 工程目录.md**（在所有文档生成完成后进行）：

   ```
   Agent:
     description: 生成工程目录
     prompt: |
       生成工程目录文档：{_path}/工程目录.md
       日期命令：{_dateCmdFull}
       Mermaid 主题：{_mermaidThemeInit}

       先读取 source-code-read/references/document-sections.md 的"工程目录文档章节"确定章节结构，
       再读取 source-code-read/references/document-content.md 的"工程目录文档内容规范"确定各章节编写要求。

       工程目录文档是融合了项目概览、阅读路线、文档索引和架构总览的入口文档。

       任务：
       1) 技术栈与项目概述：首段一句话说明当前应用做什么、使用什么技术。
          项目名称：{projectName}
          技术栈：{techStack}
       2) 重点关注：列出最重要的阅读入口、核心模块或关键场景，并说明原因。
       3) 阅读路线：按新手、维护者、排障者、扩展开发者给出阅读顺序。
       4) 扫描 {_path} 下所有 .md 文件（排除 archive_* 目录），按文档类型分组列出链接：
          - 工程概览（工程概览.md）
          - 编译运行流程（编译运行流程.md）
          - 模块文档（{模块名}.md 列表）
          - 核心源码阅读（核心源码分析-*.md 列表）
          - 场景分析（如果有）
       5) 模块功能摘要：表格列出模块、主要功能、核心入口、关键文档链接。
       6) 架构总览：使用 Mermaid graph，首行插入 {_mermaidThemeInit}，图后解释层次、依赖方向和关键耦合。
       7) 关键场景索引：列出场景文档（如有）。
       8) 写入文档维护记录。

       返回 JSON：
       {
         "filePath": "{_path}/工程目录.md",
         "status": "created",
         "qualityChecks": {
           "hasStandardSections": true,
           "hasDetailedAnalysis": false,
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

8. **输出结果**：
   ```
   init 完成：
     - 创建 工程目录.md（概览 + 路线 + 索引）
     - 创建 工程概览.md
     - 创建 编译运行流程.md
     - 创建 认证模块.md
     - 创建 核心引擎.md
     - 创建 核心源码分析-核心引擎.md

   优化建议：
     - 建议拆分 src/auth/AuthService.ts 中的认证与权限校验职责，降低后续扩展风险。
   ```

---

