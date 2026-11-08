import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

/// 用 ffdec 把「完整美术资源」包里没打出来的物品图标从原版 SWF 里补出来。
///
/// 为什么需要：`导入物品图标.mjs` 只认美术包里已经解好的 PNG
/// （命名口径 `<swf>.swf_<chid>_<className>.png`，chid 是 Flash 字符 id）。
/// 美术包漏了一批（多为服务端加的物品），SWF 库里有原件但没人解过。
///
/// 产物直接落在 `素材/物品/原版/<分类>/`，文件名沿用美术包口径，
/// 所以 `导入物品图标.mjs` 会把它当命中项收进索引 —— 不改动美术包本身。
///
/// 用法：
///   node 开发工具/补物品图标源.mjs [--swf库=<原版 swf 目录>] [--ffdec=ffdec-cli.exe]
const 脚本目录 = path.dirname(fileURLToPath(import.meta.url));
const 项目目录 = path.resolve(脚本目录, "..");
const 参数 = Object.fromEntries(process.argv.slice(2).map((value) => {
  const [key, ...rest] = value.replace(/^--/, "").split("=");
  return [key, rest.join("=")];
}));
const 素材库 = path.resolve(参数.swf库
	|| process.env.NARUTO_ASSET_SWF
	|| path.join(项目目录, "..", "2.2.3", "www/act_web_nya_208_isolated/swf"));
const ffdec = path.resolve(参数.ffdec || process.env.FFDEC || "ffdec-cli.exe");
const 输出根 = path.join(项目目录, "素材", "物品", "原版");

const 读JSON = (文件) => JSON.parse(fs.readFileSync(文件, "utf8").replace(/^﻿/, ""));
const 物品 = 读JSON(path.join(项目目录, "数据", "物品.json"));
const 缺失 = 读JSON(path.join(项目目录, "数据", "物品图标缺失.json"))
  .filter((条目) => 条目.reason === "源文件不存在");

// 多个物品常共用同一个图标 SWF（变身卡的 7 天/终极版指向同一张），按 分类+swf+类名 去重。
const 待补 = new Map();
for (const 条目 of 缺失) {
  const 定义 = 物品[条目.id] || {};
  const swf = String(定义.icon_swf || "");
  const 类名 = String(定义.icon_class || "");
  if (!条目.source_category || !swf || !类名) continue;
  const 键 = `${条目.source_category}/${swf}/${类名}`;
  if (!待补.has(键)) 待补.set(键, { 分类: 条目.source_category, swf, 类名, 物品: [] });
  待补.get(键).物品.push(条目.id);
}

const 临时根 = fs.mkdtempSync(path.join(os.tmpdir(), "naruto-icon-"));
let 成功 = 0;
const 无源 = [];
for (const 项 of 待补.values()) {
  const swf路径 = 找SWF(项.分类, 项.swf);
  if (!swf路径) { 无源.push(项); continue; }

  const 出目录 = path.join(临时根, `${项.分类}_${项.swf}`);
  fs.mkdirSync(出目录, { recursive: true });
  try {
    execFileSync(ffdec, ["-format", "image:png", "-export", "image", 出目录, swf路径],
      { stdio: "pipe", timeout: 120000 });
  } catch (错) {
    无源.push({ ...项, 原因: `ffdec 失败：${String(错.message).split("\n")[0]}` });
    continue;
  }
  // ffdec 的产物名是 `<chid>_<className>.png`；美术包口径要 `<swf>.swf_<chid>_<className>.png`。
  const 前缀 = `${项.swf}.swf_`;
  const 目标目录 = path.join(输出根, 项.分类);
  let 命中帧 = "";
  for (const 文件 of fs.readdirSync(出目录).sort()) {
    const 匹配 = /^(\d+)_(.+)\.png$/.exec(文件);
    if (!匹配 || 匹配[2] !== 项.类名) continue;
    命中帧 = `${前缀}${匹配[1]}_${项.类名}.png`;
    fs.mkdirSync(目标目录, { recursive: true });
    const 目标 = path.join(目标目录, 命中帧);
    if (!fs.existsSync(目标)) fs.copyFileSync(path.join(出目录, 文件), 目标);
    break;
  }
  if (!命中帧) 无源.push({ ...项, 原因: "SWF 里没有那个类名" });
  else 成功++;
}
fs.rmSync(临时根, { recursive: true, force: true });

console.log(`补图标：待补 ${待补.size} 个（覆盖 ${缺失.length} 条缺失），ffdec 导出成功 ${成功}，库里没有 ${无源.length}`);
const 按类 = {};
for (const 项 of 无源) 按类[项.分类] = (按类[项.分类] || 0) + 1;
console.log(`库里也没有的分类分布：${JSON.stringify(按类)}`);
for (const 项 of 无源.slice(0, 12)) {
  console.log(`  缺 ${项.分类}/${项.swf} → ${项.类名}（物品 ${项.物品.join(",")}）${项.原因 ? "：" + 项.原因 : ""}`);
}
console.log("下一步：node 开发工具/导入物品图标.mjs 重建索引");

function 找SWF(分类, swf) {
  const 目录 = path.join(素材库, 分类);
  if (!fs.existsSync(目录)) return "";
  const 直配 = path.join(目录, `${swf}.swf`);
  if (fs.existsSync(直配)) return 直配;
  for (const 文件 of fs.readdirSync(目录)) {
    if (文件.startsWith(`${swf}.swf`)) return path.join(目录, 文件);
  }
  return "";
}
