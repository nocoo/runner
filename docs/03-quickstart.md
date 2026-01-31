# 03 构建与运行

## 依赖

- macOS
- Swift 5.9+
- Bun

## 构建 Runner

```bash
cd runner-swift
swift build
cp .build/debug/Runner ../runner
```

## 初始化数据

```bash
./runner init
```

## 运行方式

```bash
# 手动执行
./runner run <task>

# 自动调度
./runner auto
```

## Dashboard 开发

```bash
cd dashboard
bun install
bun run dev
```

默认地址：`http://localhost:7009`
