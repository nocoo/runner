# 04 测试与质量

## 目标

- 单元测试覆盖率目标：**90%**
- 任何功能变更必须同时更新对应文档

## Swift

```bash
cd runner-swift
swift test
```

## Dashboard

```bash
cd dashboard
bun test --coverage
```

## Lint

```bash
cd dashboard
bun run lint
```

## 提交要求

- 原子化提交：一次提交只包含一个逻辑变更
- 采用 Conventional Commits：`<type>: <short description>`
