# Runner 文档入口 🚦

macOS 上的声明式任务调度器，通过 `launchd` 触发、`opencode` 执行 AI 任务。README 负责概览与导航，细节请阅读 `docs/`。

![Runner Dashboard](https://assets.lizheng.me/wp-content/uploads/2026/01/runner.png)

## 🧭 文档树

- `docs/01-overview.md`：项目概览与术语
- `docs/02-features.md`：主要功能与能力边界
- `docs/03-quickstart.md`：构建与运行（含 Dashboard 开发）
- `docs/04-testing.md`：测试流程与覆盖率目标
- `docs/05-architecture.md`：核心架构与数据流

## ✨ 主要功能

- 类 Cron 的调度表达式，支持 `*`、`N`、`N-M`、`N,M`、`*/N`
- JSON 声明式任务与调度配置
- Swift 原生二进制 + launchd 集成
- 基于文件的 API（`data/*.json`）供 Web UI 读取
- React + TypeScript Dashboard 实时监控
- 任务执行输出、运行记录与状态落盘

## 📁 主要目录结构

```
runner/
├── runner              # Swift 二进制
├── runner-swift/       # Swift 源码
├── data/               # JSON 文件 API
├── dashboard/          # React + TypeScript Web UI
├── launchd/            # launchd 配置
└── logs/               # 运行日志
```

## 📦 data 目录规范

- `data/tasks.json`：任务定义（JSON 数组），`executor` 支持 `shell`/`opencode`/`http`
- `data/schedules.json`：调度规则（JSON 数组），无 schedule 的任务为手动任务
- `data/state.json`：系统状态快照（Dashboard 读取）
- `data/runs/index.json`：运行索引（按时间倒序）
- `data/runs/<id>.json`：单次运行详情
- `data/runs/<id>.output`：单次运行输出
- `data/output/`：任务产出文件（由任务自身写入）

注意：`data/` 属于运行态目录，修改任务配置只改 `tasks.json`/`schedules.json`，不要手动编辑 `runs/` 下文件。

## 🧱 Swift 更新规范

- 任何 Swift 变更后必须重新构建 `runner` 二进制，否则 Dashboard 触发仍会使用旧版本
- 推荐流程：

```bash
cd runner-swift && swift build && cp .build/debug/Runner ../runner
```

- 变更影响到任务模型（如新增字段或 executor）时，同时更新：
  - `schemas/`（如有）
  - `docs/` 对应说明
  - Dashboard 类型（`dashboard/src/models/types.ts`）

## ⚡ 快速运行（开发）

```bash
# 构建 Swift 二进制
cd runner-swift && swift build && cp .build/debug/Runner ../runner

# 初始化数据文件
./runner init

# 启动调度
./runner auto
```

Dashboard 开发：

```bash
cd dashboard
bun install
bun run dev
```

## 🧪 测试与质量要求

- 单元测试目标覆盖率：**90%**
- Swift：`cd runner-swift && swift test`
- Dashboard：`cd dashboard && bun test --bail`
- Lint：`cd dashboard && bun run lint`
- SwiftLint：`cd runner-swift && swiftlint --config .swiftlint.yml`

## 🪝 Husky Hooks（团队共享）

本项目在根目录使用 Husky 统一管理 Git Hooks，禁止跳过测试。

- 安装：`bun install`
- 初始化 Hook：`bun run prepare`
- pre-commit：运行 Dashboard + Swift 单元测试
- pre-push：运行 Dashboard + Swift 单元测试与 lint（ESLint + SwiftLint）

手动执行命令：

- Dashboard UT：`cd dashboard && bun test --bail`
- Dashboard Lint：`cd dashboard && bun run lint`
- Swift UT：`cd runner-swift && swift test`
- SwiftLint：`cd runner-swift && swiftlint --config .swiftlint.yml`

## 📚 文档要求

- README 只做概览与导航，细节写入 `docs/`
- 变更代码时必须同步更新对应文档
- `docs/` 内文件按编号递进，命名风格：`NN-<topic>.md`
- 新文档必须从 README 链接进入

## 🧩 提交规范（给 Agent 看的）

- 原子化提交：一次提交只包含一个逻辑变更
- Conventional Commits：`<type>: <short description>`
- 文档与代码保持一致，改代码就改文档

## 🤖 给 Agent 的信息

- 主要功能：时间调度、任务执行、文件化 API、Dashboard 监控
- 主要目录：`runner-swift/`、`data/`、`dashboard/`、`launchd/`
- 开发流程：先构建 `runner`，再按需运行 `./runner auto` 或 Dashboard
- 测试与覆盖率目标：UT 覆盖率 90%，按上方命令执行
