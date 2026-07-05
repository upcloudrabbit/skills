---
name: source-code-read
description: >
  源码阅读与文档生成技能。使用子 agent（Agent 工具）进行重分析以减小主上下文占用，
  后台子 agent 并发上限固定为 3。检测源码项目是否已由 IDE 打开并存在 IDE MCP；
  可用时优先使用 IDE MCP 进行文件、索引、诊断、符号与搜索操作。从源码项目生成结构化 Markdown 文档。
  文档按 5 类生成：工程目录（含概览/路线/索引）、工程概览、编译运行流程、模块文档、核心源码阅读文档，以及场景分析文档。
  TRIGGER: 当用户输入 /source-code-read 时触发。
---

# Source Code Read — 源码阅读与文档生成 Skill

使用 **子 agent（Agent 工具）** 编排，将源码分析、文档生成等重操作委托给
独立的子 agent 执行，主 agent 只做路径确认、调度和结果汇总。

后台子 agent **最多同时运行 3 个**。任何并行任务都必须按 3 个一组分批启动，
前一批完成后再启动下一批，避免资源争抢和上下文结果混乱。

---

## 读取顺序

1. 触发 `/source-code-read` 后，先解析用户输入中的指令：`init`、`reinit`、`update`、`byCase` 或 `help`。
2. 执行任意非 `help` 指令前，必须读取 [references/restrictions.md](references/restrictions.md) 和 [references/document-standards.md](references/document-standards.md)，并遵守其中的限制、章节标准和质量门禁。
3. 执行具体指令时，必须读取 [references/instruction-actions.md](references/instruction-actions.md) 的索引，再读取对应指令文件，并按该文件流程调度子 agent。
4. 只输出 `help` 时，可以只读取 [references/instructions/help.md](references/instructions/help.md)。

---

## 职责分工

| 角色 | 职责 | 做 | 不做 |
|------|------|----|------|
| **主 agent** | 编排与调度 | 解析指令、确定任务序列、启动子 agent、检查结果、输出最终文件清单 | Read/Edit/Write/Bash 等文件操作、代码分析、文档内容生成 |
| **子 agent** | 执行具体任务 | 环境检测、主题检测、日期命令设置、目录创建、源码分析、文档生成与修改、归档备份、工程目录同步 | 调度决策、任务序列编排、跨任务传递上下文 |

所有子 agent 统一使用 `subagent_type: general-purpose`。
后台子 agent 并发数固定为 **3**，不得超过该上限。

---

## 指令总览

| 指令 | 功能 | 详细说明 |
|------|------|----------|
| `init` | 首次分析：生成工程目录（目录+概览+路线+索引）、工程概览、编译运行流程、模块文档、核心源码阅读文档 | [references/instructions/init.md](references/instructions/init.md) |
| `reinit` | 归档现有文档到 `{_path}/archive_<时间戳>/` | [references/instructions/reinit.md](references/instructions/reinit.md) |
| `update` | 增量更新指定文档 | [references/instructions/update.md](references/instructions/update.md) |
| `byCase` | 按场景追溯源码，生成时序图和实现分析 | [references/instructions/bycase.md](references/instructions/bycase.md) |
| `help` | 输出简要帮助 | [references/instructions/help.md](references/instructions/help.md) |

---

## 核心硬约束

- 主 agent 不直接读取、修改、写入项目文件，也不直接执行 Bash 做具体工作；这些操作必须由子 agent 完成。
- 源码读取、搜索、索引、诊断、符号、定义/引用跳转优先使用 IDE MCP；仅在 IDE MCP 不可用或能力缺失时回退文件系统工具，并记录原因。
- 全程静态分析，禁止运行、编译、测试或启动被分析源码项目。
- 并行后台子 agent 同一时间最多 3 个。
- 子 agent 必须返回 JSON 结构化结果，避免把完整文档正文传回主上下文。
- 生成或整理文档时必须使用 [references/document-sections.md](references/document-sections.md) 的对应文档类型章节结构，不得自行改名、删减或重排必需章节。
- 各章节内容编写规范见 [references/document-content.md](references/document-content.md)。

完整限制见 [references/restrictions.md](references/restrictions.md)。
