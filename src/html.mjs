import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import { parseArgs } from 'node:util';
import { loadWorkspace, selectWorkspace } from './knowledge.mjs';
import { digest, renderWorkspace } from './render.mjs';

const require = createRequire(import.meta.url);
const skillDirectory = fileURLToPath(new URL('../', import.meta.url));

const usage = `用法：
  node src/html.mjs --workspace "<工作区目录名>" [--workspace-id "<稳定 ID>"] [--root "<知识库路径>"] [--open]

--root 省略时读取 skill 目录下的 config.json。
默认只导出 HTML 并打印文件路径。使用 --open 在默认浏览器打开。
`;

function expandHome(location) {
  if (location.startsWith('~/') || location.startsWith('~\\')) {
    return path.join(os.homedir(), location.slice(2));
  }
  return location;
}

function configuredRoot() {
  const config = JSON.parse(fs.readFileSync(path.join(skillDirectory, 'config.json'), 'utf8'));
  if (typeof config.repository?.path !== 'string' || !config.repository.path.trim()) {
    throw new Error('config.json 缺少 repository.path，请先配置知识库');
  }
  return path.resolve(skillDirectory, expandHome(config.repository.path));
}

function cacheDirectory() {
  if (process.platform === 'win32') return process.env.LOCALAPPDATA || os.homedir();
  if (process.env.XDG_CACHE_HOME && path.isAbsolute(process.env.XDG_CACHE_HOME)) return process.env.XDG_CACHE_HOME;
  if (process.platform === 'darwin') return path.join(os.homedir(), 'Library', 'Caches');
  return path.join(os.homedir(), '.cache');
}

function exportHtml(values) {
  const root = fs.realpathSync(values.root ? expandHome(values.root) : configuredRoot());
  const workspace = selectWorkspace(root, values.workspace, values['workspace-id']);
  const model = loadWorkspace(root, workspace);
  const assets = {
    css: fs.readFileSync(path.join(skillDirectory, 'assets/viewer.css'), 'utf8'),
    app: fs.readFileSync(path.join(skillDirectory, 'assets/viewer.js'), 'utf8'),
    mermaid: fs.readFileSync(require.resolve('@mermaid-js/tiny'), 'utf8'),
  };
  const html = renderWorkspace(workspace, model, assets);
  const key = digest(JSON.stringify([root, workspace.id]));
  const output = path.join(cacheDirectory(), 'workspace-sync', 'html', key, 'index.html');
  fs.mkdirSync(path.dirname(output), { recursive: true, mode: 0o700 });
  const temporary = path.join(path.dirname(output), `.${randomUUID()}.tmp`);
  try {
    fs.writeFileSync(temporary, html, { flag: 'wx', mode: 0o600 });
    fs.renameSync(temporary, output);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
  return output;
}

function openBrowser(file) {
  const url = pathToFileURL(file).href;
  const commands = {
    darwin: ['open', [url]],
    win32: ['rundll32.exe', ['url.dll,FileProtocolHandler', url]],
  };
  const [command, args] = commands[process.platform] ?? ['xdg-open', [url]];
  const result = spawnSync(command, args, { stdio: 'ignore', windowsHide: true });
  if (result.error || result.status !== 0) throw new Error('浏览器打开失败，可手动打开上面的 HTML 文件');
}

try {
  const { values } = parseArgs({
    options: {
      workspace: { type: 'string' },
      'workspace-id': { type: 'string' },
      root: { type: 'string' },
      open: { type: 'boolean' },
      help: { type: 'boolean' },
    },
  });
  if (values.help) {
    console.log(usage);
  } else {
    if (!values.workspace) throw new Error('请提供 --workspace "<工作区目录名>"');
    const output = exportHtml(values);
    console.log(output);
    if (values.open) openBrowser(output);
  }
} catch (error) {
  console.error('workspace-sync html: ' + error.message);
  process.exitCode = 1;
}
