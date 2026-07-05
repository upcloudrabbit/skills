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
       - 必须读取并遵守 source-code-read/references/document-sections.md 的”场景文档章节”和
         source-code-read/references/document-content.md 的”场景文档内容规范”。
       - 必须保留场景文档标准中的全部章节标题和顺序；不适用章节保留标题并说明原因。
       - 调用时序图必须使用 Mermaid sequenceDiagram，首行 {_mermaidThemeInit}，必须为每一步在 Note over 中标注步骤编号（如 `Note over API: 1. 接收请求`），图后附步骤说明段落，编号与 Note over 一一对应。
       - 分步骤源码追踪必须逐步解释调用者、被调用者、关键判断、输入输出、副作用，并引用源码位置。
       - 关键实现评估必须包含好处/替代方案/风险。

       保存到 {_path}/{场景名}.md。

       返回 JSON：
       {
         "filePath": "{_path}/{场景名}.md",
         "status": "created",
         "updatedSections": ["重点关注", "场景定义与边界", "入口、前置条件与触发方式", "参与模块与职责", "调用时序图", "分步骤源码追踪", "数据流、状态变化与副作用", "分支、异常与异步处理", "关键实现评估", "调试、验证与测试建议", "术语表", "代码引用索引"],
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

6. **同步工程目录**：在 {_path}/工程目录.md 的模块功能摘要表、文档清单和关键场景索引中新增此行文档记录。如已有则只更新描述。
7. **输出结果**：
   ```
   byCase 完成：
     - 创建 {场景名}.md（涉及 {N} 个模块，{M} 步调用）
     - 同步 工程目录.md

   优化建议：
     - 建议为 {场景名} 的失败分支补充幂等处理说明，避免重试导致状态不一致。
   ```

---
