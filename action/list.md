# list

## 命令

```bash
/workspace-sync list
```

## 作用

列出当前 backend 中已保存的 workspace。列出后立即引导用户选择一个继续恢复，但如果用户明确表示“只是看一下”，就停在列表，不进入 `pull`。

## 执行原则

- `list` 是低风险、只读操作。优先用最短路径返回结果。
- 默认优先读取本地缓存，不做 `git pull`。
- 当本地缓存里没有用户想要的 workspace，或者用户明确表示“想不起名字了”“给我完整列表”“查远端列表”时，立刻切换到“补全发现”模式，而不是让用户卡在本地缓存。
- 远端补全只允许做轻量查询：列目录、读取 `manifest.json`；不要下载完整 workspace。
- 脚本是推荐实现，不是唯一实现。只要满足“本地优先、远端补全仅做轻量查询、输出 `name|version|updated_at`”这三个条件，就算符合 skill 语义。
- 不要因为 shell 类型、路径前缀、编码显示或 `HOME` 差异而卡住；遇到环境兼容问题时，直接切到等价 fallback。

## 执行步骤

### Step 1: 先读本地缓存

首选运行 `scripts/ws-list.sh` 的默认模式：

```bash
bash "$WS_SKILL_DIR/scripts/ws-list.sh"
```

要求：

- 只读本地缓存
- 不触发 clone / pull
- 输出格式固定为 `name|version|updated_at`

如果返回正常列表，先展示给用户，再进入 Step 2。

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
4. 提取 `name`、`version`、`updated_at`
5. 组装成与脚本一致的 `name|version|updated_at`

注意：

- 这是 `list` 的合法实现，不算“偏离 skill”
- 不要因为某条命令格式不兼容，就放弃更直接的本地读取
- 不要因为第一次脚本失败，就放弃整个 `list`

### Step 1b: 本地列表不够用时，补查远端完整列表

满足任一条件就进入这一步：

- 本地缓存为空或不存在
- 用户说“列表里没有我要的”
- 用户说“我想不起 workspace 名字”
- 用户明确要求“完整列表”“远端列表”“重新查一下”

优先运行：

```bash
bash "$WS_SKILL_DIR/scripts/ws-list.sh" --discover
```

要求：

- 对 GitHub / GitLab：先保留本地缓存结果，再补充远端独有的 workspace
- 同名 workspace 如本地与远端都存在，优先展示远端 `manifest` 的版本和时间
- 对 MinIO：直接读取远端轻量列表
- 对 Local backend：仍然只读本地目录
- 不下载完整 workspace 内容，只允许列目录和读取 `manifest.json`

如果脚本不可用，可以直接用 backend 对应的轻量 API 做等价实现，然后按名字去重。

### Step 2: 展示列表，并主动给出下一步入口

将结果整理成编号列表：

```text
1. feature-x     (v3, 2026-04-17T18:20:00+08:00)
2. bugfix-login  (v1, 2026-04-16T09:10:00+08:00)

回复序号或 workspace 名称继续恢复；
如果还没看到想要的名字，可以直接说“完整列表”或“远端列表”。
回复 q 只查看不恢复。
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
