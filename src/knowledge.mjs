import fs from 'node:fs';
import path from 'node:path';
import { parse } from 'yaml';

const files = path.posix;
const frontmatter = /^\uFEFF?---[ \t]*\r?\n([\s\S]*?)^---[ \t]*(?:\r?\n|$)/m;

function splitNote(text) {
  const header = frontmatter.exec(text);
  if (header?.index !== 0) return { data: {}, body: text };
  let data;
  try {
    data = parse(header[1], { maxAliasCount: 20 });
  } catch {
    data = {};
  }
  return { data: data ?? {}, body: text.slice(header[0].length) };
}

function safePath(root, file, kind) {
  const parts = file.split('/');
  if (parts.some(part => !part || part.startsWith('.') || /[\\:\x00-\x1f]/.test(part))) {
    throw new Error('无效路径：' + file);
  }
  let resolved = root;
  for (const [index, part] of parts.entries()) {
    resolved = path.join(resolved, part);
    const stat = fs.lstatSync(resolved, { throwIfNoEntry: false });
    const expected = index === parts.length - 1 ? kind : 'directory';
    if (!stat || (expected === 'directory' ? !stat.isDirectory() : !stat.isFile())) {
      throw new Error('无效路径：' + file);
    }
  }
  return resolved;
}

export function selectWorkspace(root, folder, expectedId) {
  if (folder.includes('/')) throw new Error('工作区必须是知识库的一级目录');
  const metadata = safePath(root, `${folder}/工作区.md`, 'file');
  const { data } = splitNote(fs.readFileSync(metadata, 'utf8'));
  if (typeof data.workspace_id !== 'string' || !data.workspace_id.trim() ||
      (expectedId !== undefined && expectedId !== data.workspace_id)) {
    throw new Error('工作区 ID 缺失或不匹配');
  }
  return {
    id: data.workspace_id,
    folder,
    name: typeof data.name === 'string' && data.name.trim() ? data.name : folder,
  };
}

function walk(root, folder) {
  const absolute = folder ? safePath(root, folder, 'directory') : root;
  const results = [];
  for (const entry of fs.readdirSync(absolute, { withFileTypes: true })) {
    if (entry.name.startsWith('.') || /[\\:\x00-\x1f]/.test(entry.name)) continue;
    const file = files.join(folder, entry.name);
    if (entry.isDirectory()) results.push(...walk(root, file));
    else if (entry.isFile() && file.endsWith('.md')) results.push(file);
  }
  return results.sort((a, b) => a.localeCompare(b, 'zh-CN'));
}

function noteAt(root, file) {
  const text = fs.readFileSync(safePath(root, file, 'file'), 'utf8');
  const { data, body } = splitNote(text);
  const stem = files.basename(file, '.md');
  return { file, data, body, stem, title: typeof data.title === 'string' ? data.title : stem };
}

function withoutExtension(value) {
  return value.replace(/\.md$/i, '').normalize('NFC');
}

export function loadWorkspace(root, workspace) {
  const directory = safePath(root, workspace.folder, 'directory');
  const notes = new Map();
  const paths = new Map();
  const aliases = new Map();
  for (const name of walk(directory, '')) {
    const note = noteAt(directory, name);
    notes.set(name, note);
    const key = withoutExtension(name);
    paths.set(key, paths.has(key) ? null : note);
    const values = Array.isArray(note.data.aliases) ? note.data.aliases : [note.data.aliases];
    const keys = new Set([note.stem, note.data.id, ...values]
      .filter(value => typeof value === 'string' && value)
      .map(withoutExtension));
    for (const alias of keys) aliases.set(alias, aliases.has(alias) ? null : note);
  }

  function resolve(source, target, wiki = true) {
    if (!target || target.startsWith('/') || target.includes('\\')) return null;
    let decoded;
    try {
      decoded = wiki ? target : decodeURIComponent(target);
    } catch {
      return null;
    }
    if (decoded.startsWith('/') || decoded.includes('\\')) return null;
    if (!wiki || decoded.startsWith('./') || decoded.startsWith('../')) {
      return paths.get(withoutExtension(files.join(files.dirname(source), decoded))) ?? null;
    }
    if (decoded.includes('/')) {
      const scoped = decoded.startsWith(`${workspace.folder}/`) ? decoded.slice(workspace.folder.length + 1) : decoded;
      const normalized = files.normalize(scoped);
      return paths.get(withoutExtension(normalized)) ??
        paths.get(withoutExtension(files.join(files.dirname(source), decoded))) ?? null;
    }
    return aliases.get(withoutExtension(decoded)) ?? null;
  }

  return { notes, resolve };
}
