# workspace-sync

一个用于 Claude Code / Codex 类 CLI 的 workspace 同步 skill，用来在多台设备之间恢复工作上下文。

当前版本的设计重点是：

- 同步上下文，而不是搬运脏代码
- 让模型按文档直接执行，而不是依赖一堆仓库内脚本
- skill-state 优先走 `sync_paths`，只有确实需要时才保留自定义脚本

## 这个 skill 同步什么

- `summary.md`
- `conversation.jsonl`
- 工作空间 `manifest.json`
- 涉及项目的 `remote / upstream / branch / head`
- 其他 skill 明确声明为 `portable` 的状态

## 这个 skill 不同步什么

- 本地未提交改动
- 已提交但未 push 的提交
- `.gitignore` 忽略文件
- 设备绑定缓存、锁、tmp、daemon 状态
- 未声明或声明为 `nonportable` 的 skill 状态

## 典型命令

```bash
/workspace-sync push feature-x
/workspace-sync pull feature-x
/workspace-sync list
/workspace-sync config
/workspace-sync clean feature-x
```

## 现在的实现方式

这个仓库不再把运行时逻辑堆在根目录 `scripts/` 里。

模型执行 `push / pull / list / config / clean` 时，应直接依据：

- [SKILL.md](./SKILL.md)
- [`action/push.md`](./action/push.md)
- [`action/pull.md`](./action/pull.md)
- [`action/list.md`](./action/list.md)
- [`action/config.md`](./action/config.md)
- [`action/clean.md`](./action/clean.md)
- [`references/`](./references/)

也就是说：

- 常规 git / 文件系统 / HTTP API / `mc` 操作直接做
- 不依赖仓库自带辅助脚本
- 遇到环境差异时，优先切回更直接的等价实现

## 当前边界

为了避免“上下文恢复了，但代码现场其实不一致”的误导，默认采用保守规则：

- `push` 前项目必须干净
- 当前分支必须有 upstream
- 本地与 upstream 必须同步
- 不满足任一条件时，停止 `push`

推荐日常流程：

1. 在当前设备把相关项目提交并 push
2. 执行 `/workspace-sync push <name>`
3. 在另一台设备执行 `/workspace-sync pull <name>`
4. 继续工作

## 配置

安装后默认配置路径：

```text
<当前 CLI 状态目录>/skills/workspace-sync/config.json
```

示例见 [`templates/config.json.example`](./templates/config.json.example)。

支持四种 backend：

- Local
- GitHub
- GitLab
- MinIO

配置流程见 [`references/setup.md`](./references/setup.md)。

## 仓库结构

```text
workspace-sync/
├── SKILL.md
├── README.md
├── action/
│   ├── clean.md
│   ├── config.md
│   ├── list.md
│   ├── pull.md
│   └── push.md
├── docs/
│   └── skill-state-contract.md
├── examples/
│   └── sdd/
│       ├── workspace-sync.contract.json
│       └── scripts/
├── references/
│   ├── backend-interface.md
│   ├── github.md
│   ├── gitlab.md
│   ├── local.md
│   ├── minio.md
│   └── setup.md
├── templates/
│   ├── config.json.example
│   └── workspace-sync.contract.example.json
├── install.sh
└── uninstall.sh
```

说明：

- 根目录不再提供运行时 `scripts/`
- `examples/sdd/scripts/` 只是给其他 skill 的自定义导出/导入脚本示例
- `templates/workspace-sync.contract.example.json` 默认示范 `sync_paths` 写法

## skill-state contract

文档见 [`docs/skill-state-contract.md`](./docs/skill-state-contract.md)。

当前建议：

1. 优先用 `sync_paths`
2. 只有确实需要路径转换、重建索引、schema 迁移时，才给 skill 自己写 `export_command` / `import_command`
3. `workspace-sync` 本身只负责编排，不理解目标 skill 的私有格式

一个 `sync_paths` 示例：

```json
{
  "contract_version": 1,
  "skill": "example-skill",
  "states": [
    {
      "name": "project-state",
      "scope": "project",
      "portability": "portable",
      "sync_paths": [
        ".example/specs",
        ".example/current.json"
      ]
    }
  ]
}
```

## 安装

```bash
git clone https://github.com/<your-username>/workspace-sync
cd workspace-sync
./install.sh
```

默认会安装到当前 CLI 状态目录下的：

```text
<state-root>/skills/workspace-sync
```

首次安装且目标目录没有 `config.json` 时，会自动从模板初始化一份。

## 卸载

```bash
./uninstall.sh
```
