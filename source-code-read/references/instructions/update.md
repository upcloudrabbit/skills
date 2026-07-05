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
       4) 必须读取 source-code-read/references/document-standards.md，并保持目标文档符合对应文档类型的标准章节
       5) 新增或修改内容必须补齐源码证据、关键判断、数据/状态变化、代码引用和三维评估
       6) 如果原文档章节不符合标准，至少修正本次涉及章节；大改时补齐全部标准章节
       7) 保存文件

       返回 JSON：
       {
         "filePath": "...",
         "status": "updated",
         "updatedSections": ["章节1"],
         "needsSummaryUpdate": true/false,
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

5. **按需同步工程目录**：

   如果 `needsSummaryUpdate` 为 true，启动子 agent 更新 {_path}/工程目录.md 的模块功能摘要表和文档清单。否则跳过。

6. **输出结果**：
   ```
   update 完成：
     - 更新 {targetDoc}.md
     - 同步 工程目录.md

   优化建议：
     - 建议在 {targetDoc}.md 增加关键入口的测试场景说明，降低后续维护成本。
   ```

---
