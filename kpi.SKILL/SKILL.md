---
name: kpi
description: KPI 代码膨胀技能。使用子 agent（Agent 工具）编排以减小主上下文占用。TRIGGER: 当用户输入 /kpi 时。
---

# KPI — 代码膨胀 Skill

本 Skill 使用 **子 agent（Agent 工具）** 将类查找和代码修改委托给
独立的子 agent 执行。每个子 agent 拥有自己的上下文窗口，主 agent 仅做
调度与结果汇总，大幅减小主上下文占用。

---

## 参数

支持一个可选的正整数参数 `N`（1～3），表示要修改的类数量，默认为 1。

```
/kpi          # 修改 1 个类
/kpi 3        # 修改 3 个类
```

---

### 日期命令变量

定义会话变量 `_dateCmdMonth`，主 agent 每次执行前根据当前 OS 设置：

| 变量 | Linux/macOS | Windows |
|------|------------|---------|
| `_dateCmdMonth`（分支命名） | `` `date '+%Y%m'` `` | `` `powershell -Command "Get-Date -Format 'yyyyMM'"` `` |

所有 prompt 中使用 `{_dateCmdMonth}` 引用日期命令，不再重复书写完整命令。

---

## 执行流程

### 步骤 1：分支管理（主 agent 执行，轻量操作）

1. 获取当前日期，格式 `YYYYMM`，构造分支名 `{YYYYMM}_ai`。（**必须通过 `{_dateCmdMonth}` 获取**）
2. 检查分支是否存在：`git branch --list {YYYYMM}_ai`
   - **不存在**：`git checkout -b {YYYYMM}_ai master`
   - **已存在**：切换到该分支

### 步骤 2：查找候选类

启动一个子 agent 扫描项目，找到符合膨胀条件的类：

```
Agent:
  description: 查找候选类
  subagent_type: general-purpose
  prompt: |
    使用 IDE MCP 工具（ide_find_class、ide_find_file、ide_search_text、wc -l）
    或文件系统命令，查找当前项目中所有符合以下条件的 Java 类：
    1) 行数 > 300 行；
    2) 不是 interface；
    3) 不是 enum；
    4) 不是 POJO/纯数据类（方法数 ≤ 2、仅有 getter/setter/构造函数的类；
       有 @Service/@Component/@RestController 等业务注解的不算纯 POJO）；
    5) 至少有 1 个包含循环/条件分支/异常处理/IO/算法/外部调用的业务方法。
    确保查找覆盖面广——从项目根目录多个入口进入，避免只扫描固定目录。
    返回每个候选类的路径和行数，按行数降序排列。
    返回 JSON 格式结果：
    { candidates: [{ path, lineCount }] }
```

从结果中提取 `candidates` 列表。如果无候选类则报告用户并退出。

**洗牌随机选取** N 个类：将 `candidates` 数组随机打乱后取前 N 个。

### 步骤 3：膨胀代码（并行）

对每个选中的类，启动一个后台子 agent 独立膨胀：

```
Agent:
  description: 膨胀 {类路径}
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    读取并膨胀文件：{cls.path}（当前 {cls.lineCount} 行）

    读取文件内容，理解每个方法的实现功能。不要删除或修改原有逻辑结构——
    仅在其基础上增加实现复杂度。

    对每个方法，依次应用以下膨胀策略（优先选择增加行数最多的方式，可组合使用）：
    1) Lambda → 匿名类/循环展开：list.stream().map(x->f(x)) 展开为 for 循环+中间变量+新 ArrayList
    2) Stream 链拆解：每次 .filter()/.map() 拆成独立中间变量并逐行注释
    3) 三元表达式 → if-else 块：a?b:c 展开为完整 if-else，中间可加日志或断言
    4) 重复定义中间变量：int x = a+b → int t1=a; int t2=b; int x=t1+t2;
    5) 提取"看似合理"的辅助 private 方法，然后再调用它
    6) 增加空值检查：if(x==null){log.warn(...);return fallback;}
    7) 增加日志：关键步骤前后加 log.debug(...)
    8) 断言/前置条件：if(!condition)throw new IllegalArgumentException(...)
    9) 类型转换显式化：String s=obj.toString() → String s=String.valueOf(obj) 加判空
    10) 计算过程拆分：result=a*b+c/d → 多行 t1=a*b; t2=c/d; result=t1+t2;

    限制条件：
    - 修改后文件净增加行数 ≤ 500 行
    - 保持方法参数签名、返回值类型、可见性不变
    - 不要引入未使用的 import，不要删除原有 import
    - 编译必须通过（不需要保证逻辑等价）

    修改完成后保存文件。
    返回 JSON 格式结果：{ filePath, addedLines }
```

**等待所有后台子 agent 完成**，收集每个结果的 `filePath` 和 `addedLines`。

### 步骤 4：输出结果

收集所有后台子 agent 返回的 `{ filePath, addedLines }`，对每个结果输出一行：

```
{filePath} +{addedLines}
```

**不输出任何额外信息**（不要说明、不要解释、不要总结）。

示例输出（N=2）：
```
src/main/java/com/example/service/OrderService.java +187
src/main/java/com/example/controller/AuthController.java +92
```

---

## 上下文优化说明

| 阶段 | 执行者 | 上下文占用 |
|------|--------|-----------|
| 分支管理 | 主 agent | 极低（几条 git 命令） |
| 类查找 | 子 agent #1 | 独立上下文，返回结构化摘要 |
| 膨胀类 A | 子 agent #2 | 独立上下文，返回 {path, addedLines} |
| 膨胀类 B | 子 agent #3 | 独立上下文，返回 {path, addedLines} |
| 结果输出 | 主 agent | 极低（仅 N 行文本） |

即使 N=3、每个候选类上千行，主 agent 的上下文也只保存了每个类的
**路径 + 行数**（几十字节），而非文件内容。

---

## 注意事项

1. **IDE MCP 优先**：子 agent 查找文件时优先使用 `ide_find_class`、`ide_search_text` 等 IDE 工具。
2. **不运行源码**：只做静态修改，不要运行或测试源码。
3. **分支名固定**：`{YYYYMM}_ai`，不要添加其他后缀或前缀。
4. **随机性**：通过洗牌保证每次选择的随机性。连续两次 /kpi 应找到不同类。
5. **`run_in_background` 并发**：膨胀阶段使用 `run_in_background: true` 同时启动多个子 agent，每个膨胀互不干扰。
6. **子 agent 返回结构**：要求每个子 agent 返回 JSON 格式的结构化结果，避免返回完整文件内容占用上下文。
7. **子 agent 容错**：后台子 agent 可能因超时、工具不可用等原因返回 null 或无效结果。主 agent 应检查每个返回值，失败的任务记录日志后继续处理其余任务。查找阶段失败则报错退出，膨胀阶段失败则跳过该类继续处理其余类。
