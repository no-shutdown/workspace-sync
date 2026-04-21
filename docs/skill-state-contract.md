# Skill State Contract

`workspace-sync` 不为任何 skill 做专用适配。

如果一个 skill 需要把自己的工作现场状态纳入跨设备同步，就必须在自己的 skill 目录下提供：

```text
workspace-sync.contract.json
```

放置位置：

```text
<当前 CLI 状态目录>/skills/<skill-name>/workspace-sync.contract.json
```

## 目标

这个契约只解决两件事：

- 告诉 `workspace-sync` 哪些状态允许跨设备迁移
- 告诉 `workspace-sync` 这些状态该如何导出和导入

它不负责：

- 猜 skill 的私有目录结构
- 扫描缓存目录
- 判断哪些文件“看起来像状态”
- 为 skill 做兼容性适配

## 两种模式

优先级：

1. `sync_paths`
2. `export_command` / `import_command`

也就是说，大多数 skill 应该先尝试 `sync_paths`，只有确实需要转换逻辑时才写脚本。

### 模式一：`sync_paths`（推荐）

直接声明要同步的相对路径，`workspace-sync` 负责复制、打包和恢复。

```json
{
  "contract_version": 1,
  "skill": "sdd",
  "states": [
    {
      "name": "project-state",
      "scope": "project",
      "portability": "portable",
      "sync_paths": [
        ".sdd/specs",
        ".sdd/tasks/current.json"
      ]
    }
  ]
}
```

适用于：

- 固定文件路径复制
- 固定目录同步
- 不需要路径转换、重建索引、schema 迁移的大多数场景

### 模式二：`export_command` / `import_command`

只有在确实需要自定义逻辑时才使用，例如：

- 绝对路径转相对路径
- schema 升级
- 索引重建
- 精细过滤文件

```json
{
  "contract_version": 1,
  "skill": "example-skill",
  "states": [
    {
      "name": "project-state",
      "scope": "project",
      "portability": "portable",
      "export_command": "./scripts/export-workspace-state.sh",
      "import_command": "./scripts/import-workspace-state.sh"
    }
  ]
}
```

注意：

- 这里的脚本属于**目标 skill 自己**
- `workspace-sync` 仓库本身不再提供通用 runner 脚本
- `stdout` 只能输出结果 JSON；日志必须写到 `stderr`

## 契约格式

最小可用示例：

```json
{
  "contract_version": 1,
  "skill": "example-skill",
  "description": "同步项目工作现场，不同步本机缓存和运行态",
  "states": [
    {
      "name": "project-state",
      "description": "项目级工作现场",
      "scope": "project",
      "portability": "portable",
      "sync_paths": [
        ".example/specs",
        ".example/current.json"
      ]
    },
    {
      "name": "daemon-cache",
      "description": "本机缓存和运行态",
      "scope": "global",
      "portability": "nonportable"
    }
  ]
}
```

兼容性规则：

- `contract_version` 当前固定为 `1`
- 未识别字段应忽略，不应导致失败

## 字段约束

### 顶层字段

必需：

- `contract_version`
- `skill`
- `states`

推荐：

- `description`

### `states[]`

每个 state 必须包含：

- `name`
- `scope`
- `portability`

推荐包含：

- `description`

当 `portability=portable` 时，必须额外提供以下之一：

- `sync_paths`
- `export_command` + `import_command`

两者同时存在时，优先 `export_command` / `import_command`。

当 `portability=nonportable` 时：

- 不应再提供 `sync_paths`
- 不应再提供 `export_command` / `import_command`

## 语义规则

### `scope`

- `project`: 绑定某个项目工作区
- `global`: 绑定当前设备上的 skill 全局状态

### `portability`

- `portable`: 可以跨设备恢复
- `nonportable`: 只适合留在本机

## 什么适合标记为 `portable`

- 跨设备恢复后仍然有意义
- 不依赖本机进程状态
- 不依赖本机绝对路径
- 不包含不应跨设备复制的敏感凭证
- 丢失后会影响工作现场恢复，而不只是影响性能

## 什么应标记为 `nonportable`

- `pid`
- `lock`
- `sock`
- `tmp`
- daemon 运行态
- 认证缓存
- 机器绑定绝对路径缓存
- 纯性能缓存

## `workspace-sync` 实际会做什么

它只会：

- 读取 `workspace-sync.contract.json`
- 对 `portable` 状态执行 `sync_paths` 或目标 skill 自己声明的命令
- 记录导出与恢复状态

它不会：

- 解读导出包内部结构
- 替你迁移 skill 私有目录
- 猜测哪些文件该恢复

## manifest 中的记录建议

```json
{
  "skill": "example-skill",
  "state": "project-state",
  "scope": "project",
  "portability": "portable",
  "project": "demo-app",
  "status": "exported",
  "artifacts": [
    "skill-states/example-skill/demo-app-project-state/manifest.json",
    "skill-states/example-skill/demo-app-project-state/state.tgz"
  ]
}
```

常见状态值：

- `exported`
- `restored`
- `skipped`
- `missing`
- `deferred`
- `not_exported`

## 示例

参考：

- [`templates/workspace-sync.contract.example.json`](../templates/workspace-sync.contract.example.json)
- [`examples/sdd/workspace-sync.contract.json`](../examples/sdd/workspace-sync.contract.json)
- [`examples/sdd/scripts/export-workspace-state.sh`](../examples/sdd/scripts/export-workspace-state.sh)
- [`examples/sdd/scripts/import-workspace-state.sh`](../examples/sdd/scripts/import-workspace-state.sh)

其中：

- 模板默认示范 `sync_paths`
- `examples/sdd/scripts/` 仅用于展示“确实需要自定义导出/导入逻辑时脚本应该长什么样”
