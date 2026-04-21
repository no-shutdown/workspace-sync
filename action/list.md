# list

## 命令

```bash
/workspace-sync list
```

## 作用

列出当前 backend 中已保存的 workspace。列出后立即引导用户选择一个继续恢复，但如果用户明确表示“只是看一下”，就停在列表，不进入 `pull`。

## 执行原则

- `list` 是低风险、只读操作。优先用最短路径返回结果。
- 优先读取本地缓存，不做 `git pull`、不发网络请求。
- 脚本是推荐实现，不是唯一实现。只要满足“本地缓存优先、无网络、输出 `name|version|updated_at`”这三个条件，就算符合 skill 语义。
- 不要因为 shell 类型、路径前缀、编码显示或 `HOME` 差异而卡住；遇到环境兼容问题时，直接切到等价 fallback。

## 执行步骤

### Step 1: 读取本地缓存

首选运行 `scripts/ws-list.sh` 的默认模式。

要求：

- 只读本地缓存
- 不触发 clone / pull / API 请求
- 输出格式固定为 `name|version|updated_at`

如果脚本运行成功，直接进入 Step 2。

### Step 1a: 脚本不可用时的 fallback

以下情况都算“脚本不可用”：

- shell 环境与脚本假设不一致，例如 Git Bash / WSL / MSYS 路径前缀不同
- `HOME`、`USERPROFILE`、技能安装目录或配置目录解析错误
- 终端编码显示异常，导致无法可靠读取脚本输出
- 脚本本身缺失，但本地缓存和 `manifest.json` 可直接读取

fallback 做法：

1. 根据 `config.json` 确定 backend 和缓存目录
2. 找到对应的本地缓存根目录
3. 遍历每个 workspace 目录下的 `manifest.json`
4. 提取：
   - `name`
   - `version`
   - `updated_at`
5. 组装成与脚本一致的逻辑结果

注意：

- 这是 `list` 的合法实现，不算“偏离 skill”
- 不要为了拘泥某条命令格式而放弃更直接的本地读取
- 不要因为第一次脚本失败，就放弃整个 `list`

### Step 1b: 本地缓存为空时再查远端

只有在本地缓存为空或不存在时，才进入这一步。

先明确告知用户“本地没有缓存”，再询问是否获取远端列表。用户确认后，才允许运行远端模式。

远端列表只用于列名称；除 MinIO 等必须读取 manifest 的场景外，不主动下载完整 workspace 内容。

### Step 2: 展示列表并立即给出下一步引导

将结果整理成编号列表：

```text
1. feature-x     (v3, 2026-04-17T18:20:00+08:00)
2. bugfix-login  (v1, 2026-04-16T09:10:00+08:00)

回复序号或 workspace 名称继续恢复；回复 q 只查看不恢复。
```

要求：

- 即使只有一个 workspace，也先展示，再由用户确认
- 不擅自进入 `pull`
- 如果用户明确表示“只是 list 一下”或回复 `q` / `cancel` / `quit`，就在这里停止

### Step 3: 解析用户选择，再进入 pull

只有当用户明确选择序号或精确名称时，才等价进入：

```bash
/workspace-sync pull <name>
```

选择无效时，明确报错并要求重新选择。
