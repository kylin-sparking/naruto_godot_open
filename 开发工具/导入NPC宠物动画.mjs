import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { 扫分类图, 源数据 } from './素材源.mjs';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const clientDir = path.resolve(toolDir, '..');
const dataPath = 源数据(clientDir);
const metadataPath = path.join(clientDir, '数据', '角色', '动画元数据.json');
const assetIndexPath = path.join(clientDir, '数据', '角色', '动画素材索引.json');
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const data = readJson(dataPath);
const metadata = readJson(metadataPath);
const assetIndex = readJson(assetIndexPath);

const results = [];
results.push(importKind('Npc', 'npc', '非玩家角色', data.Npc || {}));
results.push(importKind('Pet', 'pet', '宠物', Object.fromEntries(Object.entries(data.Pet || {}).filter(([id]) => id !== 'common'))));
fs.writeFileSync(metadataPath, JSON.stringify(metadata));
fs.writeFileSync(assetIndexPath, JSON.stringify(assetIndex));
for (const result of results) {
  fs.writeFileSync(path.join(clientDir, '数据', '角色', `${result.label}动画缺失.json`), JSON.stringify(result.missing));
  console.log(`${result.label}动画导入完成：定义 ${result.definitions}，帧 ${result.copied}，缺失 ${result.missing.length}`);
}

function importKind(sourceName, metadataKey, label, definitions) {
  const sourceByClass = new Map();
  // 扫分类图按"二手包 → 原版直解包"排序，先到先得；本分类直解包里没有时它只返回二手包。
  for (const { 文件名, 路径 } of 扫分类图(clientDir, sourceName)) {
    const match = 文件名.match(new RegExp(`_(${sourceName}_[^/]+?)\\.png$`));
    if (match && !sourceByClass.has(match[1])) sourceByClass.set(match[1], { 文件名, 路径 });
  }
  metadata[metadataKey] = {};
  const missing = [];
  let copied = 0;
  for (const [id, definition] of Object.entries(definitions)) {
    metadata[metadataKey][id] = normalizeDefinition(definition, metadataKey);
    const classes = new Set();
    walkClassNames(definition, classes);
    for (const className of classes) {
      const source = sourceByClass.get(className);
      if (!source) { missing.push({ id, className }); continue; }
      const target = path.join(clientDir, '素材', '角色动画', label, `${label}_${id}`, source.文件名);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(source.路径, target);
      assetIndex[className] = `res://${path.relative(clientDir, target).split(path.sep).join('/')}`;
      copied += 1;
    }
  }
  return { label, definitions: Object.keys(definitions).length, copied, missing };
}

function normalizeDefinition(definition, kind) {
  if (kind !== 'pet') return definition;
  const result = { ...definition };
  if (definition.stand0) result.stand = definition.stand0;
  if (definition.attack) result.attack1 = definition.attack;
  return result;
}

function walkClassNames(value, output) {
  if (!value || typeof value !== 'object') return;
  if (typeof value.className === 'string') output.add(value.className);
  for (const child of Object.values(value)) walkClassNames(child, output);
}
