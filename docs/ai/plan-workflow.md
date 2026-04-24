# Plan 流程

## 何时需要 Plan

- 2 步以上的实现任务
- 涉及多文件/多模块的改动
- 架构决策或方案选择不明确时

不需要 Plan：单文件修改、typo 修复、配置微调

## 流程步骤

### 1. 调研（Explore）

并行启动 explore/librarian 收集上下文，自己同时直接读取关键文件。不要重复搜索已委托给 explore/librarian 的内容。

### 2. 设计（Brainstorm）

产出设计方案，包含：
- 问题描述
- 方案选项（至少 2 个）+ 推荐
- 架构图 / 文件变更清单
- 约束和取舍

**必须获得用户批准后才能进入实现。**

### 3. 计划（Write Plan）

将设计细化为 bite-sized 任务，每个任务包含：
- 精确的文件路径
- 完整代码（不写"添加验证"，写具体代码）
- 测试命令和预期输出
- 提交指令

保存到 `docs/plans/YYYY-MM-DD-<topic>.md`。

### 4. 实现（Execute）

按计划逐任务执行，每个任务完成后：
- 运行测试验证
- 提交 commit

### 5. 归档确认 ⚠️

**Plan 完成后必须询问用户：**

> "Plan 已完成。是否将 `docs/plans/` 下的计划文档归档到 `docs/archive/plans/`？"

- 用户确认 → `mv docs/plans/*.md docs/archive/plans/` → 提交 `chore: archive ...`
- 用户拒绝 → 保留在 `docs/plans/` 不动

**不要自动归档。必须询问。**

## 文件路径约定

| 用途 | 路径 |
|------|------|
| 活跃计划 | `docs/plans/YYYY-MM-DD-<topic>.md` |
| 设计文档 | `docs/plans/YYYY-MM-DD-<topic>-design.md` |
| 归档位置 | `docs/archive/plans/YYYY-MM-DD-<topic>.md` |

## 与 AGENTS.md 的关系

- `AGENTS.md` = 项目级全局上下文（读什么、怎么跑、避坑指南）
- `docs/ai/` = AI 工作流程参考（commit 规范、plan 流程等）
- 两者互补，不重复
