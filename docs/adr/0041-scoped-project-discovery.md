# 限定 push 的项目发现范围

---
status: accepted
---

push 默认只采集当前 workspace 已关联的项目。若当前 cwd 是一个尚未关联的代码项目，可以作为候选展示给用户确认；除当前 cwd 外，不扫描本地其他仓库，也不静默扩大 workspace 的项目范围。

## Consequences

- workspace 的项目集合由图谱关联控制，而不是由本机目录偶然决定。
- 新项目加入 workspace 需要显式确认，之后才能参与自动采集和恢复。
- 采集流程应清楚区分“已关联项目”和“待确认候选”。
