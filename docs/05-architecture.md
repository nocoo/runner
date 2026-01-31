# 05 架构与数据流

## 系统概览

```mermaid
flowchart TB
    subgraph macOS[macOS 系统层]
        launchd[launchd\n系统调度器]
    end

    subgraph Runner[Runner 核心 Swift]
        CLI[CLI 入口\nrunner auto/run/list]
        Monitor[Monitor\n僵尸任务检测]
        Scheduler[Scheduler\n时间匹配引擎]
        Executor[Executor\n任务执行器]
        Storage[Storage\nJSON 持久化]
    end

    subgraph Data[数据层 File API]
        tasks[tasks.json\n任务定义]
        schedules[schedules.json\n调度规则]
        state[state.json\n系统状态]
        runs[runs/\n执行记录]
    end

    subgraph External[外部依赖]
        opencode[opencode\nAI Agent]
        shell[Shell 命令]
    end

    subgraph Dashboard[Web 控制台]
        ViteAPI[Vite 插件 API]
        ViewModels[ViewModels]
        UI[UI 组件]
    end

    launchd -->|定时触发| CLI
    CLI --> Monitor
    CLI --> Scheduler
    Scheduler --> Executor
    Executor --> Storage
    Executor -->|opencode executor| opencode
    Executor -->|shell executor| shell

    Storage <-->|读写| tasks
    Storage <-->|读写| schedules
    Storage <-->|读写| state
    Storage <-->|读写| runs

    ViteAPI <-->|读取| Data
    ViteAPI --> ViewModels
    ViewModels --> UI
```

## 目录结构

```
data/
├── tasks.json
├── schedules.json
├── state.json
└── runs/
    ├── index.json
    ├── <uuid>.json
    └── <uuid>.output
```

## 核心组件

- Scheduler：匹配当前时间与 Cron 表达式
- Executor：生成并执行脚本，记录运行结果
- Storage：读取与写入 JSON 数据文件
- Monitor：检查并处理中断的任务
