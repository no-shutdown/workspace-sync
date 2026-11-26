import { createHash } from 'node:crypto';
import MarkdownIt from 'markdown-it';

const markdown = new MarkdownIt();
export const escape = markdown.utils.escapeHtml;

export function digest(value, encoding = 'hex') {
  return createHash('sha256').update(value).digest(encoding);
}

export function pageId(file) {
  return `p-${digest(file).slice(0, 24)}`;
}

function headingId(text) {
  return text.normalize('NFC').toLowerCase().trim()
    .replace(/[^\p{L}\p{N}_ -]+/gu, '')
    .replace(/\s+/g, '-');
}

function hrefFor(note, fragment = '') {
  const id = pageId(note.file);
  return `#${id}${fragment ? '/' + encodeURIComponent(headingId(fragment)) : ''}`;
}

markdown.inline.ruler.before('link', 'wiki_link', (state, silent) => {
  const { pos, src } = state;
  if (src.slice(pos, pos + 2) !== '[[') return false;
  const end = src.indexOf(']]', pos + 2);
  if (end === -1 || end + 2 > state.posMax) return false;
  const inner = src.slice(pos + 2, end);
  if (!inner || /[\n\r\[\]]/.test(inner)) return false;
  if (!silent) state.push('wiki_link', '', 0).content = inner;
  state.pos = end + 2;
  return true;
});

markdown.renderer.rules.wiki_link = (tokens, index, _options, { model, note }) => {
  const [reference, label] = tokens[index].content.split('|', 2);
  const [file, fragment] = reference.trim().split('#', 2);
  const target = file ? model.resolve(note.file, file.trim()) : fragment && note;
  const text = escape(label?.trim() || reference.trim());
  if (!target) return `<span class="unresolved" title="当前工作区内找不到唯一目标">${text}</span>`;
  return `<a href="${escape(hrefFor(target, fragment))}">${text}</a>`;
};

markdown.renderer.rules.link_open = (tokens, index, options, { model, note }, renderer) => {
  const token = tokens[index];
  const href = token.attrGet('href') ?? '';
  if (/^(?:https?|mailto):/i.test(href)) {
    token.attrSet('target', '_blank');
    token.attrSet('rel', 'noopener noreferrer');
  } else {
    const [file, fragment = ''] = href.split('#', 2);
    const target = file ? model.resolve(note.file, file, false) : note;
    if (target) {
      let heading = fragment;
      try {
        heading = decodeURIComponent(fragment);
      } catch {
        // Keep a malformed fragment as text.
      }
      token.attrSet('href', hrefFor(target, heading));
    } else {
      token.attrs = [['class', 'unresolved'], ['title', '当前工作区内找不到目标']];
    }
  }
  return renderer.renderToken(tokens, index, options);
};

markdown.renderer.rules.image = (tokens, index) => {
  const alt = tokens[index].content;
  return `<span class="attachment">${escape(alt || '图片')}</span>`;
};

const renderFence = markdown.renderer.rules.fence;
markdown.renderer.rules.fence = (tokens, index, options, env, renderer) => {
  if (tokens[index].info.trim() !== 'mermaid') return renderFence(tokens, index, options, env, renderer);
  return `<figure class="diagram"><pre>${escape(tokens[index].content)}</pre></figure>\n`;
};

markdown.renderer.rules.heading_open = (tokens, index, options, { note, headings }, renderer) => {
  const text = tokens[index + 1].content;
  const key = headingId(text) || 'section';
  let id = key;
  for (let suffix = 2; headings.has(id); suffix++) id = `${key}-${suffix}`;
  headings.add(id);
  tokens[index].attrSet('id', `${pageId(note.file)}/${id}`);
  return renderer.renderToken(tokens, index, options);
};

function noteLink(note) {
  return `<a href="${hrefFor(note)}" data-page-link="${pageId(note.file)}">${escape(note.title)}</a>`;
}

const viewNames = ['架构地图', '开发任务', '开发路线', '系统联调'];
const groupNames = [
  ['图谱/节点/系统/', '系统'], ['图谱/节点/能力/', '能力'],
  ['图谱/节点/缺口/', '缺口'], ['图谱/节点/任务/', '任务'],
  ['图谱/说明/', '支撑记录'], ['图谱/候选/', '候选'],
  ['原始资料/', '原始资料'],
];

function navigation(model, paths) {
  const featured = paths.flatMap(file => model.notes.has(file) ? [model.notes.get(file)] : []);
  const listed = new Set(featured);
  const notes = [...model.notes.values()];
  const groups = groupNames.flatMap(([prefix, label]) => {
    const entries = notes.filter(note => note.file.startsWith(prefix));
    if (!entries.length) return [];
    entries.forEach(note => listed.add(note));
    return [[label, entries]];
  });
  const rest = notes.filter(note => !listed.has(note));
  if (rest.length) groups.push(['其他文档', rest]);
  return `<nav aria-label="工作区文档">
    <div class="featured">${featured.map(noteLink).join('')}</div>
    ${groups.map(([label, entries]) =>
      `<details><summary>${label}<span>${entries.length}</span></summary>${entries.map(noteLink).join('')}</details>`
    ).join('')}
  </nav>`;
}

function renderNote(note, model, initialPage) {
  const id = pageId(note.file);
  const detail = [note.data.type, note.data.status]
    .filter(value => typeof value === 'string' && value)
    .map(value => `<span class="tag">${escape(value)}</span>`).join('');
  const body = markdown.render(note.body, { model, note, headings: new Set() });
  return `<article id="${id}" data-title="${escape(note.title)}"${id === initialPage ? '' : ' hidden'}>
    <header class="page-header">
      <p class="page-path">${escape(note.file)}</p>
      ${detail ? `<div class="tags">${detail}</div>` : ''}
    </header>
    ${/^\s*#\s/.test(note.body) ? '' : `<h1>${escape(note.title)}</h1>`}
    ${body}
  </article>`;
}

export function renderWorkspace(workspace, model, { css, app, mermaid }, generatedAt = new Date()) {
  const paths = ['图谱/总览.md', ...viewNames.map(name => `图谱/视图/${name}.md`),
    '工作区.md', '图谱/索引.md', '图谱/日志.md'];
  const start = model.notes.get(paths[0]) ?? model.notes.get('工作区.md');
  const first = pageId(start.file);
  const body = Array.from(model.notes.values(), note => renderNote(note, model, first)).join('\n');
  const scripts = (body.includes('class="diagram"') ? [mermaid, app] : [app])
    .map(source => source.replace(/\r\n?/g, '\n'));
  const hashes = scripts.map(source => `'sha256-${digest(source, 'base64')}'`).join(' ');
  const name = escape(workspace.name);
  const updated = new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(generatedAt);
  return `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src ${hashes}; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'">
<title>${name} · workspace-sync</title>
<style>${css}</style>
</head>
<body>
<div class="layout">
  <aside class="sidebar">
    <p class="brand">workspace-sync</p>
    <a class="workspace-name" href="#${first}">${name}</a>
    ${navigation(model, paths)}
  </aside>
  <div class="content">
    <div class="topbar">
      <a href="#${first}">${name}</a>
      <span>生成于 <time datetime="${generatedAt.toISOString()}">${updated}</time></span>
    </div>
    <main data-initial="${first}">${body}</main>
  </div>
</div>
${scripts.map(source => `<script>${source}</script>`).join('\n')}
</body>
</html>
`;
}
