import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const command = fileURLToPath(new URL('../src/html.mjs', import.meta.url));
const folder = '数据导入迭代';
const overview = '图谱/总览.md';
const rootTask = '图谱/节点/任务/任务-开发总任务.md';

function fixture(context) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-sync-test-'));
  context.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const root = path.join(temporary, 'knowledge');
  const cache = path.join(temporary, 'cache');
  const env = { ...process.env, XDG_CACHE_HOME: cache, LOCALAPPDATA: cache };
  function note(relative, text) {
    const file = path.join(root, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, text);
  }
  note(`${folder}/工作区.md`, '---\nworkspace_id: ws-import\nname: 数据导入\n---\n# 工作区\n');
  note('其他迭代/工作区.md', '---\nworkspace_id: ws-other\nname: 其他迭代\n---\n# 其他空间专有信息');
  function generate(directory = folder, id = 'ws-import') {
    return spawnSync(process.execPath, [command, '--root', root, '--workspace', directory, '--workspace-id', id], {
      env, encoding: 'utf8',
    });
  }
  return { root, cache, note, generate };
}

test('renders only the selected workspace with safe Markdown and linked views', context => {
  const { root, cache, note, generate } = fixture(context);
  note(`${folder}/${overview}`, [
    '# 迭代总览',
    '[[task-root|主任务]] [定位](节点/任务/任务-开发总任务.md#验收标准)',
    '[[其他迭代/工作区|外部工作区]] [[未知页面|未知]]',
    '`[[task-root]]`',
    '<script>alert(1)</script>',
  ].join('\n\n'));
  note(`${folder}/${rootTask}`, '---\nid: task-root\ntype: 任务\nstatus: 进行中\n---\n# 开发总任务\n## 验收标准\n');
  note(`${folder}/图谱/视图/架构地图.md`, '# 架构地图\n\n```mermaid\nflowchart TB\n  A --> B\n```\n');
  if (process.platform !== 'win32') {
    fs.symlinkSync(path.join(root, '其他迭代', '工作区.md'), path.join(root, folder, 'workspace-symlink.md'));
  }
  const result = generate();
  assert.equal(result.status, 0, result.stderr);
  const output = result.stdout.trim();
  assert.ok(output.startsWith(cache + path.sep), output);
  const html = fs.readFileSync(output, 'utf8');
  assert.match(html, /<h1[^>]*>迭代总览<\/h1>/);
  const taskHref = /href="(#[^"]+)">主任务<\/a>/.exec(html)?.[1];
  assert.ok(taskHref);
  assert.ok(html.includes(`href="${taskHref}/${encodeURIComponent('验收标准')}">定位`));
  assert.match(html, /class="unresolved"[^>]*>未知<\/span>/);
  assert.doesNotMatch(html, /其他空间专有信息|workspace-symlink\.md|<script>alert/);
  assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.match(html, /<code>\[\[task-root\]\]<\/code>/);
  assert.match(html, /<figure class="diagram">/);
});

test('republishes the same file after Markdown changes and a workspace rename', context => {
  const { root, note, generate } = fixture(context);
  note(`${folder}/${overview}`, '# 第一份内容\n');
  const first = generate();
  assert.equal(first.status, 0, first.stderr);
  const output = first.stdout.trim();
  assert.match(fs.readFileSync(output, 'utf8'), /第一份内容/);
  const newFolder = '新名称';
  fs.renameSync(path.join(root, folder), path.join(root, newFolder));
  note(`${newFolder}/${overview}`, '# 第二份内容\n');
  const rejected = generate(newFolder, 'wrong-id');
  assert.equal(rejected.status, 1);
  assert.match(fs.readFileSync(output, 'utf8'), /第一份内容/);
  const second = generate(newFolder);
  assert.equal(second.status, 0, second.stderr);
  assert.equal(second.stdout.trim(), output);
  assert.match(fs.readFileSync(output, 'utf8'), /第二份内容/);
});
