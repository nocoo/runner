# 🤖 Runner - 声明式任务调度器

基于时间的自动化任务调度器，通过 `opencode` 执行 AI 任务。

## ✨ 特性

| 特性 | 描述 |
|------|------|
| 📅 **Crontab 风格调度** | 支持 `*`, `N,M`, `N-M`, `*/N` 表达式 |
| 📝 **声明式配置** | YAML 定义调度规则，Markdown 定义任务 prompt |
| ✅ **配置校验** | 前置验证，错误提前发现 |
| 🔌 **文件系统 API** | JSON 数据文件，便于 Web UI 集成 |
| 🧪 **测试驱动** | 121 个 bats 测试用例，覆盖核心功能 |
| 🔔 **通知集成** | 通过 task-notifier skill 发送执行通知 |
| ⏰ **launchd 集成** | macOS 原生定时任务支持 |

## 📁 目录结构

```
runner/
├── runner.sh           # 主调度器脚本
├── tasks.yaml          # 任务配置 + 调度规则
├── VERSION             # 版本号
├── schemas/            # JSON Schema 定义
├── tasks/              # 任务 prompt 模板 (*.md)
├── data/               # API 数据 (JSON)
│   ├── state.json      # 系统状态
│   ├── tasks.json      # 任务列表
│   ├── schedules.json  # 调度规则
│   └── runs/           # 执行记录
├── logs/               # 运行日志
└── tests/              # bats 测试
```

## 🚀 快速开始

### 依赖安装

```bash
# 运行时依赖
brew install jq yq

# 测试依赖
brew tap bats-core/bats-core
brew install bats-core bats-assert bats-support
npm install -g ajv-cli
```

### 基本使用

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

### tasks.yaml

```yaml
# 调度规则
schedules:
  # 每天 9:05
  - task: morning_briefing
    hour: 9
    minute: 5
    weekday: "*"

  # 每10分钟 (心跳)
  - task: heartbeat
    hour: "*"
    minute: 0
    weekday: "*"
  - task: heartbeat
    hour: "*"
    minute: 10
    weekday: "*"
  # ... (0, 10, 20, 30, 40, 50)

  # 工作日 9-17 点整点
  - task: work_reminder
    hour: "9-17"
    minute: 0
    weekday: "1-5"

  # 周日 20:00
  - task: weekly_synthesis
    hour: 20
    minute: 0
    weekday: 0

# 任务元数据
tasks:
  morning_briefing:
    description: "每日早报"
    timeout: 300

  heartbeat:
    description: "心跳检测"
    timeout: 30

  xray_hourly:
    description: "X-Ray 数据采集"
    timeout: 600
    workdir: /path/to/xray   # 可选：指定工作目录
```

### 任务 Prompt (tasks/*.md)

每个任务对应一个 Markdown 文件，定义要传给 `opencode run` 的 prompt。

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
| **总计** | **121** | |

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
