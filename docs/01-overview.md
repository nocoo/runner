# 01 项目概览

Runner 是一个面向 macOS 的声明式任务调度器，使用 `launchd` 进行时间触发，并通过 `opencode` 执行 AI 任务。核心目标是用 JSON 配置完成任务编排，用文件化 API 提供可观测性与 Web 可视化。

## 关键概念

- 任务（Task）：描述一次可执行动作（`simple` 或 `agent`）
- 调度（Schedule）：基于 Cron 风格表达式的触发规则
- 执行记录（Run）：任务执行的状态与输出落盘
- 文件化 API：`data/*.json` 作为 Dashboard 的数据来源

## 阅读路径

- 功能与能力边界：`docs/02-features.md`
- 构建与运行：`docs/03-quickstart.md`
- 测试与质量：`docs/04-testing.md`
- 架构与数据流：`docs/05-architecture.md`
