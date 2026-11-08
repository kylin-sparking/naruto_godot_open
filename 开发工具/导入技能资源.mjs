import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { 扫分类图, 源数据 } from './素材源.mjs';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const clientDir = path.resolve(toolDir, '..');
const sourceData = 源数据(clientDir);
const outDir = path.join(clientDir, '素材', '技能');
const indexPath = path.join(clientDir, '数据', '技能素材索引.json');
const missingPath = path.join(clientDir, '数据', '技能素材缺失.json');
const metadataPath = path.join(clientDir, '数据', '技能动画元数据.json');
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const data = readJson(sourceData);
const byClass = new Map();
for (const { 文件名, 路径 } of 扫分类图(clientDir, 'Skill')) {
  const match = 文件名.match(/_(Skill_[^/]+?)\.png$/);
  if (match && !byClass.has(match[1])) byClass.set(match[1], { 文件名, 路径 });
}
const index = {};
const missing = [];
const metadata = {};
let containers = 0;
for (const [group, skills] of Object.entries(data.Skill || {})) {
  if (!skills || typeof skills !== 'object') continue;
  for (const [skillId, definition] of Object.entries(skills)) {
    containers += 1;
    const classes = new Set();
    walkClassNames(definition, classes);
    for (const className of classes) {
      const source = byClass.get(className);
      if (!source) { missing.push({ group, skillId, className }); continue; }
      const target = path.join(outDir, group, skillId, source.文件名);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(source.路径, target);
      index[className] = `res://${path.relative(clientDir, target).split(path.sep).join('/')}`;
    }
  }

  for (const [skillId, definition] of Object.entries(skills.skill || {})) {
    metadata[skillId] = definition;
  }
}
fs.mkdirSync(path.dirname(indexPath), { recursive: true });
fs.writeFileSync(indexPath, JSON.stringify(index));
fs.writeFileSync(missingPath, JSON.stringify(missing));
fs.writeFileSync(metadataPath, JSON.stringify(metadata));
console.log(`技能资源导入完成：主技能 ${Object.keys(metadata).length}，容器 ${containers}，索引 ${Object.keys(index).length}，缺失 ${missing.length}`);

function walkClassNames(value, output) {
  if (!value || typeof value !== 'object') return;
  if (typeof value.className === 'string') output.add(value.className);
  for (const child of Object.values(value)) walkClassNames(child, output);
}
