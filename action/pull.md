# pull

## 命令

```bash
/workspace-sync pull <workspace-name>
```

## 目标

下载并恢复指定 workspace，同时把摘要重新呈现给用户，便于立即继续工作。

## 执行步骤

### Step 1: 校验名称与配置

- 按 `SKILL.md` 的 `validate_ws_name` 校验 `WS_NAME`
- 读取当前生效 `config.json`
- 配置缺失时，转入 `references/setup.md`

### Step 2: 先比较本地缓存与远端

优先读取本地缓存的 `manifest.json`。
如果 backend 支持轻量远端查询，再读取远端 `manifest.json` 的 `version` / `updated_at`。

决策规则：

- 本地无、远端有：下载远端
- 本地有、远端无：从本地缓存恢复，并明确说明是 `local_only`
- 本地和远端都有，远端更新：下载远端
- 本地和远端都有，本地相同或更新：优先保守处理，先向用户说明版本关系再决定是否强制覆盖
- 两边都没有：报错停止

### Step 3: 恢复 workspace 基础文件

恢复：

- `manifest.json`
- `summary.md`
- `conversation.jsonl`（若存在）

### Step 4: 恢复项目代码位置

对 `manifest.projects` 中的每个项目：

1. 优先查 `local-paths.json`
2. 再在 `scan_roots` 下扫描 git 仓库并按规范化 remote 精确匹配
3. 唯一命中时自动采用，并写回 `local-paths.json`
4. 多个候选时让用户选
5. 没有候选时再问用户本地路径

恢复前先做校验：

- 目标目录必须是 git 仓库
- `remote.origin.url` 规范化后必须和记录匹配
- 本地工作区如果有未提交改动，则跳过该项目，不强制覆盖

恢复动作：

- 切到记录的分支
- 尝试 checkout 到记录的 `HEAD`
- 失败时标记为 `skipped_head_missing`

### Step 5: 导入 portable skill states

读取各 skill 的 `workspace-sync.contract.json`：

- `sync_paths`：直接恢复对应路径
- `import_command`：仅在 contract 明确要求时，调用该 skill 自己的命令

结果单独汇报为：

- `restored`
- `skipped`
- `missing`
- `deferred`

### Step 6: 重新呈现上下文

不要只说“恢复成功”，必须把 `summary.md` 中最重要的信息重新讲给用户：

- 整体目标
- 背景与约束
- 讨论脉络
- 关键决策
- 每个项目的当前停点
- 下一步最具体动作

如果某些项目因为本地脏工作区、路径未解析或 `HEAD` 缺失而未恢复完整，必须明确提示：

- 摘要仅能作为参考
- 当前代码现场和摘要可能不完全一致

### Step 7: 给出衔接动作

根据 `summary.md` 的“下一步”，主动提出一个具体衔接动作，不要要求用户再手打一遍 `/workspace-sync` 命令。
