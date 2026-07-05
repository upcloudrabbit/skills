# Source Code Read 文档标准

本文档是文档标准的入口索引，指引到两个拆分文件：

| 文件 | 内容 | 用途 |
|------|------|------|
| [document-sections.md](document-sections.md) | 章节结构 | 每类文档的标题层级与章节顺序（必须使用的骨架） |
| [document-content.md](document-content.md) | 内容规范 | 各章节的编写内容要求、通用写作要求、质量门禁 |

---

## 使用方式

- **确定章节结构** → 读取 [document-sections.md](document-sections.md)，找到对应文档类型，按模板保留全部章节标题。
- **确定内容要求** → 读取 [document-content.md](document-content.md)，按对应章节的内容规范编写正文。
- **质量检查** → 保存前对照 [document-content.md 的章节质量门禁](document-content.md#章节质量门禁)逐项检查。

---

> 执行 `init`、`reinit`、`update`、`byCase` 时，只要会生成或修改文档，就必须同时读取本文档指向的两个文件。
