# config

## 命令

```bash
/workspace-sync config
```

## 作用

重新配置 workspace-sync 的本地 `config.json`。这不是一次性的安装动作，而是一个长期可重复执行的重配置入口。

## 执行原则

- 只要用户明确提到“重配”“改 backend”“改 token”“改 bucket”“重新配置”，就进入本流程。
- 即使当前 `config.json` 已经完整，也允许重新配置，不要把它限制成“首次安装专用”。
- `config` 与首次配置必须复用同一套问题顺序、同一套验证规则、同一套写入方式。
- 写入时只更新当前选择 backend 对应的字段和 `backend` 本身；其他字段一律保留，避免覆盖用户已有的 `scan_roots`、`cache_dir`、`local_paths_file` 或其他 backend 备用配置。
- 验证失败时直接报错并停下，不写入半成品配置。

## 执行步骤

### Step 1: 复用首次配置流程

读取 `references/setup.md`，按其中的顺序逐项提问并收集参数。不要一次性把所有问题都抛给用户。

### Step 2: 调用配置脚本写入并验证

根据 backend 调用：

```bash
bash "$WS_SKILL_DIR/scripts/ws-config.sh" <backend> ...
```

脚本会：

- 校验 backend 必填项
- 验证目录 / 仓库 / bucket 是否可用
- 更新当前实际生效的 `config.json`
- 保留无关配置字段

### Step 3: 完成后停止，或继续原请求

如果这是用户显式执行的 `/workspace-sync config`，配置完成后只需要确认保存成功并告知当前生效配置路径。

如果这是因为其他命令发现配置缺失而中途进入的配置流程，则在保存成功后继续执行原命令。
