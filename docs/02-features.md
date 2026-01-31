# 02 主要功能

## 调度与执行

- Cron 风格表达式：`*`、`N`、`N-M`、`N,M`、`*/N`
- 任务执行方式：
  - `shell`：直接执行 shell 命令
  - `opencode`：调用 `opencode` 执行 AI prompt
- 触发规则：无 schedule 的任务仅手动触发，有 schedule 的任务按时间自动触发

## 配置与验证

- JSON 声明式配置：`tasks.json`、`schedules.json`
- 执行前配置验证，提前暴露错误

## 可观测性

- 运行记录、输出与状态文件落盘
- `data/` 目录作为文件化 API 提供给 Dashboard

## Dashboard

- React + TypeScript 实时监控
- 任务列表、调度展示、运行历史与趋势
