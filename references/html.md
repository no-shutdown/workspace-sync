# 本地 HTML 导出

HTML 是当前 workspace 的只读快照。导出器只从配置的知识库目录读取目标 workspace 的 Markdown，独立于用于维护 Markdown 的文件或 Obsidian CLI 接口。导出在本机同步执行，默认浏览器直接读取 `file://` 页面。

## 安装与调用

需要 Node.js 22.12 或更新版本。在 skill 的安装目录或源码仓库根目录执行一次：

```sh
npm ci --ignore-scripts --omit=dev
```

正常使用 `/workspace-sync html [工作区名称]`。也可以直接调用：

```sh
npm run html -- --root "/path/to/dev-knowledge" --workspace "数据导入迭代" --open
```

省略 `--root` 时读取 skill 目录的 `config.json` 中的 `repository.path`。底层命令的 `--workspace` 是目录名。会话命令还必须传入已验证的 `--workspace-id`。省略 `--open` 只更新文件并打印路径。

## 生成与刷新

- `html` 根据本地 Markdown 立即生成并打开页面。
- `compile` 在自身成功后执行同一导出命令，省略 `--open`。即使 Markdown 无变更，也应尝试导出。导出失败单独报告，已经完成的 Markdown 变更、提交和健康检查结果继续有效。
- 同一本地知识库路径与稳定 workspace ID 对应同一个本机缓存 `index.html`，目录改名后路径仍然有效。导出通过原子替换更新文件；失败前已存在的完整页面可继续打开。HTML 缓存不进入知识库 Git 提交，也不参与 Obsidian 浏览或编辑。
- 已打开的页面在下次浏览器刷新时读取该文件。直接改动 Markdown 或执行 `pull` 后可以执行 `html` 重新生成。
- 快照内置样式、交互和 Mermaid 渲染资源，打开时无需联网。支持工作区内 Wiki 链接、Markdown 页面链接和标题定位。图片、嵌入附件和 Obsidian 插件视图以文本或原始 Markdown 形式展示。
