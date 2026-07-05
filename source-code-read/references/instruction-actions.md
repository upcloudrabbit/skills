# Source Code Read 指令索引

本文档只说明 `/source-code-read` 每条指令做什么，以及应读取哪个独立指令文件。
执行任意具体指令时，先读取 [restrictions.md](restrictions.md) 和 [document-standards.md](document-standards.md)，再读取下表对应文件。

---

## 指令总览

| 指令 | 做什么 | 详细流程 |
|------|--------|----------|
| `init` | 首次分析源码项目，识别模块并生成工程目录、工程概览、编译运行流程、模块文档、核心源码阅读文档等完整文档集。 | [instructions/init.md](instructions/init.md) |
| `reinit` | 归档现有文档到 `{_path}/archive_<时间戳>/`。归档后如需重新生成文档，请执行 init 指令。 | [instructions/reinit.md](instructions/reinit.md) |
| `update` | 根据用户指定目标，对已有文档执行增量更新，并在需要时同步 `工程目录.md`。 | [instructions/update.md](instructions/update.md) |
| `byCase` | 按具体业务/技术场景静态追溯源码调用链，生成场景分析文档并同步工程目录。 | [instructions/bycase.md](instructions/bycase.md) |
| `help` | 输出 `/source-code-read` 的简要命令帮助。 | [instructions/help.md](instructions/help.md) |
