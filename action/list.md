# list

## 命令

```bash
/workspace-sync list
```

## 目标

列出当前可恢复的 workspace，并在列出后立刻引导用户选择一个继续恢复。

## 执行原则

- `list` 是低风险只读操作
- 默认优先本地缓存
- 本地结果不够用时，再补查远端
- 远端补查只做轻量操作：列目录、读 `manifest.json`
- 不要为 `list` 下载完整 workspace

## 执行步骤

### Step 1: 读取本地视图

按当前 backend 类型确定读取位置：

- **GitHub / GitLab**：遍历 `cache_dir` 下对应 clone 中的各 workspace 目录，读取 `manifest.json`
- **Local**：遍历 `local.path` 下各子目录的 `manifest.json`（`local.path` 本身即主存储，无单独 clone 缓存）
- **MinIO**：本地无缓存副本，直接跳到 Step 2 补查远端

每条提取：`name`、`version`、`updated_at`。

输出逻辑上的结果即可，不要求依赖仓库脚本。

### Step 2: 需要时补查远端

满足任一条件就补查远端：

- 本地缓存为空
- 用户说“没看到想要的名字”
- 用户说“完整列表”“远端列表”“重新查一下”

补查规则：

- GitHub / GitLab / MinIO：只列远端 workspace 名和 `manifest.json`
- Local backend：本地目录本身就是完整列表，不需要额外补查
- 同名 workspace 同时存在本地和远端时，优先显示远端版本信息

### Step 3: 展示并引导选择

输出时至少包含：

```text
1. feature-x     (v3, 2026-04-17T18:20:00+08:00)
2. bugfix-login  (v1, 2026-04-16T09:10:00+08:00)
```

列出后立即告诉用户：

- 回复序号或名称即可继续恢复
- 若还没看到想要的名字，可以要求“完整列表”或“远端列表”
- 只有用户明确表示“只是看看”时，才停在 `list`
