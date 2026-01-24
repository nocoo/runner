# 🤖 Runner - 声明式任务调度器

基于时间的自动化任务调度器，通过 `opencode` 执行 AI 任务。

## ✨ 特性

| 特性 | 描述 |
|------|------|
| 📅 **Crontab 风格调度** | 支持 `*`, `N,M`, `N-M`, `*/N` 表达式 |
| 📝 **声明式配置** | JSON 定义任务和调度规则 |
| ✅ **配置校验** | 前置验证，错误提前发现 |
| 🔌 **文件系统 API** | JSON 数据文件，便于 Web UI 集成 |
| 🧪 **测试驱动** | 135 个 bats 测试 + 103 个 dashboard 测试 |
| 🔔 **通知集成** | 通过 task-notifier skill 发送执行通知 |
| ⏰ **launchd 集成** | macOS 原生定时任务支持（每分钟触发） |
| 🖥️ **Matrix Dashboard** | React + TypeScript 实时监控面板 |

## 🚀 冷启动指南 (Agent Bootstrap)

> 本节面向 AI Agent，提供完整的项目安装和配置流程。

### 1. 克隆项目

```bash
cd ~/workspace/personal
git clone https://github.com/nocoo/runner.git
cd runner
```

### 2. 安装依赖

```bash
# 运行时依赖
brew install jq

# opencode CLI (AI 任务执行器)
# 确保 opencode 已安装并可用
which opencode || echo "请先安装 opencode"

# Dashboard 依赖
cd dashboard && bun install && cd ..
```

### 3. 初始化数据文件

```bash
# 创建必要的数据目录和文件
./runner.sh api init
```

这会创建：
- `data/state.json` - 系统状态
- `data/tasks.json` - 任务定义
- `data/schedules.json` - 调度规则
- `data/runs/index.json` - 执行历史索引

### 4. 验证配置

```bash
# 验证任务和调度配置
./runner.sh validate

# 列出所有任务
./runner.sh list
```

### 5. 安装 launchd 定时任务

```bash
# 复制 plist 文件
cp com.runner.scheduler.plist ~/Library/LaunchAgents/

# 加载定时任务 (每分钟触发一次)
launchctl load ~/Library/LaunchAgents/com.runner.scheduler.plist

# 验证安装
launchctl list | grep runner
```

### 6. 启动 Dashboard (可选)

```bash
cd dashboard
bun run dev
# 访问 http://localhost:5173
```

### 7. 添加新任务

编辑 `data/tasks.json` 添加任务定义：

```json
{
  "id": "my_task",
  "type": "agent",
  "description": "任务描述",
  "timeout": 300,
  "prompt": "执行某个操作..."
}
```

编辑 `data/schedules.json` 添加调度规则：

```json
{
  "task": "my_task",
  "hour": 9,
  "minute": 0,
  "weekday": "*"
}
```

### 8. 手动测试任务

```bash
# 预览 prompt (不执行)
./runner.sh my_task --dry-run

# 执行任务
./runner.sh my_task

# 查看执行历史
./runner.sh api runs
```

## 📁 目录结构

```
runner/
├── runner.sh           # 主调度器脚本
├── VERSION             # 版本号
├── data/               # API 数据 (JSON)
│   ├── state.json      # 系统状态
│   ├── tasks.json      # 任务定义
│   ├── schedules.json  # 调度规则
│   └── runs/           # 执行记录
├── dashboard/          # React + TypeScript Web UI
│   ├── src/
│   │   ├── models/     # 类型定义和数据转换
│   │   ├── viewmodels/ # 状态管理 hooks
│   │   ├── ui/         # UI 组件库
│   │   └── pages/      # 页面组件
│   └── package.json
├── logs/               # 运行日志
└── tests/              # bats 测试
```

## 📖 CLI 使用

### 基本命令

```bash
# 列出所有任务
./runner.sh list

# 验证配置文件
./runner.sh validate

# 执行指定任务
./runner.sh morning_briefing

# 预览 prompt (不执行)
./runner.sh morning_briefing --dry-run

# 自动模式 (根据当前时间选择任务)
./runner.sh auto

# 详细输出
./runner.sh morning_briefing --verbose
```

### API 查询

```bash
# 获取任务列表
./runner.sh api tasks

# 获取调度规则
./runner.sh api schedules

# 获取执行历史
./runner.sh api runs

# 获取单次执行详情
./runner.sh api runs <uuid>

# 获取系统状态
./runner.sh api status
```

## ⚙️ 配置

### Crontab 风格表达式

支持以下调度表达式语法：

| 语法 | 含义 | 示例 |
|------|------|------|
| `*` | 任意值 | `hour: "*"` 每小时 |
| `N` | 精确值 | `hour: 9` 9点 |
| `N,M,O` | 列表 | `minute: "0,15,30,45"` |
| `N-M` | 范围 | `hour: "9-17"` 9点到17点 |
| `*/N` | 步进 | `minute: "*/10"` 每10分钟 |

### schedules.json

```json
[
  { "task": "morning_briefing", "hour": 9, "minute": 5, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 10, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 20, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 40, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 50, "weekday": "*" },
  { "task": "work_reminder", "hour": "9-17", "minute": 0, "weekday": "1-5" },
  { "task": "weekly_synthesis", "hour": 20, "minute": 0, "weekday": 0 }
]
```

### tasks.json

```json
[
  {
    "id": "morning_briefing",
    "type": "agent",
    "description": "每日早报",
    "timeout": 300,
    "prompt": "生成今日早报..."
  },
  {
    "id": "heartbeat",
    "type": "agent",
    "description": "心跳检测",
    "timeout": 30,
    "prompt": "系统心跳检测"
  },
  {
    "id": "clock",
    "type": "simple",
    "description": "整点报时",
    "timeout": 10,
    "command": "say '整点报时'"
  }
]
```

## ✅ 配置校验

运行 `validate` 命令检查配置文件：

```bash
./runner.sh validate
```

校验内容：
- 必填字段：`task`, `hour`, `weekday`, `description`, `timeout`
- Crontab 表达式语法和值范围
- 任务引用存在性
- Prompt 文件存在性
- Workdir 目录存在性

## ⏰ launchd 定时任务

### 安装

```bash
cp ~/Library/LaunchAgents/com.runner.scheduler.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.runner.scheduler.plist
```

### 卸载

```bash
launchctl unload ~/Library/LaunchAgents/com.runner.scheduler.plist
rm ~/Library/LaunchAgents/com.runner.scheduler.plist
```

### 查看状态

```bash
launchctl list | grep runner
```

### 手动触发

```bash
launchctl start com.runner.scheduler
```

## 🧪 测试

```bash
# 运行所有测试
bats tests/*.bats

# 运行特定测试文件
bats tests/crontab.bats

# 详细输出
bats --verbose-run tests/*.bats
```

### 测试覆盖

**Bash 测试 (bats)**

| 测试文件 | 测试数 | 覆盖内容 |
|---------|-------|---------|
| crontab.bats | 36 | Crontab 表达式匹配 |
| validation.bats | 18 | 配置校验 |
| routing.bats | 12 | 时间路由逻辑 |
| api.bats | 10 | API 输出 |
| errors.bats | 11 | 错误处理 |
| execution.bats | 5 | 任务执行流程 |
| logging.bats | 6 | 日志记录 |
| cli.bats | 6 | CLI 参数解析 |
| dryrun.bats | 4 | dry-run 模式 |
| schema.bats | 6 | JSON Schema 验证 |
| workdir.bats | 5 | 工作目录切换 |
| **总计** | **135** | |

**Dashboard 测试 (bun:test)**

| 测试文件 | 覆盖率 | 覆盖内容 |
|---------|-------|---------|
| transforms.test.ts | 97.57% | 数据转换、Cron 表达式 |
| validators.test.ts | 100% | 数据校验 |
| api.test.ts | 100% | API 调用 |
| date.test.ts | 100% | 日期工具函数 |
| format.test.ts | 100% | 格式化工具函数 |
| useStatusVM.test.ts | 100% | 状态管理 |
| **总计** | **103 测试, 94% 覆盖率** | |

## 🌐 Dashboard

Matrix 风格的实时监控面板，基于 React + TypeScript + Vite。

### 功能

- **实时时钟** - 北京时间显示，Matrix 风格动画
- **任务列表** - 查看所有任务和调度规则
- **执行历史** - 分页浏览执行记录，点击查看详情
- **活动热力图** - 30 天执行活动可视化
- **趋势图表** - 24 小时执行趋势
- **即将执行** - 未来 8 个任务倒计时
- **自动刷新** - 文件变化时自动更新（开发模式）
- **Matrix Rain** - 背景数字雨动画效果

### 启动

```bash
cd dashboard
bun install
bun run dev
```

访问 http://localhost:5173

### 测试

```bash
cd dashboard
bun test              # 运行测试
bun test --coverage   # 运行测试并生成覆盖率报告
```

## 🔔 通知

通过 [task-notifier](https://github.com/nocoo/skill-task-notifier) skill 发送通知：

- ✅ 任务成功：Bark 推送 + 系统通知 + 声音
- ❌ 任务失败：错误通知

禁用通知：
```bash
RUNNER_SKIP_NOTIFY=1 ./runner.sh morning_briefing
```

## 🌐 Web UI 集成

Runner 使用文件系统 API，便于 Web UI 读取：

```
data/
├── state.json           # GET /api/status
├── tasks.json           # GET /api/tasks
├── schedules.json       # GET /api/schedules
└── runs/
    ├── index.json       # GET /api/runs
    └── <uuid>.json      # GET /api/runs/:id
```

可以使用任意静态文件服务器托管 `data/` 目录。

## 📋 环境变量

| 变量 | 描述 | 默认值 |
|------|------|--------|
| `RUNNER_CONFIG_FILE` | 配置文件路径 | `./tasks.yaml` |
| `RUNNER_TASKS_DIR` | 任务目录 | `./tasks` |
| `RUNNER_DATA_DIR` | 数据目录 | `./data` |
| `RUNNER_SKIP_NOTIFY` | 禁用通知 | - |
| `RUNNER_MOCK_HOUR` | 模拟小时 (测试用) | - |
| `RUNNER_MOCK_MINUTE` | 模拟分钟 (测试用) | - |
| `RUNNER_MOCK_WEEKDAY` | 模拟星期 (测试用) | - |

## 📄 License

MIT
