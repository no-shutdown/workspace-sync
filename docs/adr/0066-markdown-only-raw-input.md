# 第一版 raw 只编译 Markdown 文档

---
status: accepted
---

第一版编译器递归读取当前 workspace `raw/` 目录中的 `.md` 文件；这些文档可以自由书写，不要求固定章节或 frontmatter。图片、PDF 和其他附件可以存在或被 Markdown 引用，但不作为第一版自动图谱编译的直接输入。

## Consequences

- 规划工具只需生成普通 Markdown 即可接入。
- 编译器的输入边界明确，避免第一版同时承担多种文件解析器。
- 后续扩展附件输入时需要新增来源和提炼规则，不改变 raw 不可覆盖原则。
