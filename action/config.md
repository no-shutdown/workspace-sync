# config

## 命令

```bash
/workspace-sync config
```

## 目标

重新配置当前生效的 `config.json`，并保留无关字段。

## 执行原则

- 只要用户明确提到重配 backend、token、bucket、本地目录，就进入本流程
- 即使当前配置完整，也允许重配
- 提问顺序复用 `references/setup.md`
- 不要一次性把所有问题抛给用户
- 先验证，再写入
- 只更新当前 backend 对应字段和 `backend`

## 执行步骤

### Step 1: 按 `references/setup.md` 逐项提问

按 backend 分支逐项收集参数：

- Local: 本地目录
- GitHub: token / repo / branch
- GitLab: host / token / project_path / branch / protocol
- MinIO: endpoint / access_key / secret_key / bucket / prefix / mc_alias

### Step 2: 即时验证

直接用标准命令或 API 验证：

- Local: 目录是否存在
- GitHub: 仓库是否存在且 token 可访问
- GitLab: API 是否能读到目标项目
- MinIO: `mc` 是否可用，bucket 是否存在

验证失败立即停止，不写配置。

### Step 3: 更新 `config.json`

写入前先备份：若文件已存在，执行 `cp "$CONFIG" "${CONFIG}.bak"`。

写入要求：

- 保留其他 backend 的备用配置
- 保留 `scan_roots`、`cache_dir`、`local_paths_file`
- 只替换当前选中 backend 的字段

如果这是用户显式执行的 `/workspace-sync config`，写完后汇报生效路径并结束。
如果是其他命令中途缺配置触发的，写完后继续原命令。
