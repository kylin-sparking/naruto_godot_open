import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { 扫分类图, 源数据 } from './素材源.mjs';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const clientDir = path.resolve(toolDir, '..');
const sourceData = 源数据(clientDir);
const outDir = path.join(clientDir, '素材', '角色动画', '玩家');
const metadataPath = path.join(clientDir, '数据', '角色', '动画元数据.json');
const indexPath = path.join(clientDir, '数据', '角色', '动画素材索引.json');

const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const data = readJson(sourceData);
const sourceByClass = new Map();
for (const { 文件名, 路径 } of 扫分类图(clientDir, 'Char')) {
  const match = 文件名.match(/_(Char_[^/]+?)\.png$/);
  if (!match) continue;
  if (!sourceByClass.has(match[1])) sourceByClass.set(match[1], { 文件名, 路径 });
}

const metadata = readJson(metadataPath);
metadata.character = {};
const index = {};
const missing = [];
let copied = 0;
for (const [id, definition] of Object.entries(data.M_Char || {})) {
  metadata.character[id] = definition;
  const targetDir = path.join(outDir, `原版角色_${id}`);
  fs.mkdirSync(targetDir, { recursive: true });
  const classNames = new Set();
  walkClassNames(definition, classNames);
  for (const className of classNames) {
    const source = sourceByClass.get(className);
    if (!source) { missing.push({ id, className }); continue; }
    const target = path.join(targetDir, source.文件名);
    fs.copyFileSync(source.路径, target);
    index[className] = `res://${path.relative(clientDir, target).split(path.sep).join('/')}`;
    copied += 1;
  }
}
fs.mkdirSync(path.dirname(metadataPath), { recursive: true });
fs.writeFileSync(metadataPath, JSON.stringify(metadata));
fs.writeFileSync(indexPath, JSON.stringify({ ...readJson(indexPath), ...index }));
fs.writeFileSync(path.join(clientDir, '数据', '角色', '角色动画缺失.json'), JSON.stringify(missing));
console.log(`角色动画导入完成：定义 ${Object.keys(metadata.character).length}，帧资源 ${copied}，缺失 ${missing.length}`);

function walkClassNames(value, output) {
  if (!value || typeof value !== 'object') return;
  if (typeof value.className === 'string') output.add(value.className);
  for (const child of Object.values(value)) walkClassNames(child, output);
}
