## `reinit` — 归档现有文档

### 执行流程

1. **确认输出路径**（可沿用 `_path`）
2. **检查目录下是否有文档**：无文档则提示需先有文档
3. **启动环境子 agent**（运行 `scripts/theme.sh`/`theme.ps1` + `date.sh`/`date.ps1` 获取 `_mermaidThemeInit` `_dateCmdFull` `_dateCmdCompact`）

4. **归档备份**：

   ```
   Agent:
     description: 归档现有文档
     prompt: |
       在 {_path} 下执行以下任务：

       1) 时间戳：{_dateCmdCompact}
       2) 创建 {_path}/archive_<时间戳>/
       3) 将所有 .md 复制到归档目录，images/ 也一并复制
       注意：这是备份，不移动或删除原文件。

       返回 JSON：
       {
         "status": "ok",
         "archivePath": "...",
         "fileCount": 0,
         "warnings": [],
         "errors": []
       }
   ```

5. **输出结果**：
   ```
   reinit 完成：
     - 归档 {fileCount} 个文件至 {archivePath}
     - 如需重新生成文档，请运行 init 指令
   ```

---
