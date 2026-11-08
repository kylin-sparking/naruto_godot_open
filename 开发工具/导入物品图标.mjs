import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { 分类目录 } from "./素材源.mjs";

const 脚本目录 = path.dirname(fileURLToPath(import.meta.url));
const 项目目录 = path.resolve(脚本目录, "..");
const 参数 = Object.fromEntries(process.argv.slice(2).map((value) => {
  const [key, ...rest] = value.replace(/^--/, "").split("=");
  return [key, rest.join("=")];
}));
const 物品数据路径 = path.resolve(参数.items || path.join(项目目录, "数据", "物品.json"));
const 输出目录 = path.join(项目目录, "素材", "物品", "原版");
const 索引路径 = path.join(项目目录, "数据", "物品图标索引.json");
const 缺失路径 = path.join(项目目录, "数据", "物品图标缺失.json");

if (!fs.existsSync(物品数据路径)) throw new Error(`物品数据不存在：${物品数据路径}`);

const 物品 = JSON.parse(fs.readFileSync(物品数据路径, "utf8").replace(/^\uFEFF/, ""));
const 索引 = {};
const 缺失 = [];
const 已复制 = new Set();
const 分类文件缓存 = new Map();

for (const [编号, 定义] of Object.entries(物品).sort(([左], [右]) => 左.localeCompare(右))) {
  const 分类 = String(定义.source_category || "");
  const swf = String(定义.icon_swf || "");
  const 类名 = String(定义.icon_class || "");
  if (!分类 || !swf || !类名) {
    缺失.push({ id: 编号, name: String(定义.name || 编号), source_category: 分类, reason: "图标定义为空" });
    continue;
  }

  // swf 与 className 必须精确一致；帧号由原 SWF 决定，不能假定图标总在第 1 帧。
  // 前缀精确包含 ".swf_"，因此不会命中 "[1].swf_" 解包重复项。
  const 源文件 = 查找图标文件(分类, swf, 类名);
  if (!源文件) {
    缺失.push({
      id: 编号,
      name: String(定义.name || 编号),
      source_category: 分类,
      reason: "源文件不存在",
      expected_file: `${分类}/${swf}.swf_*_${类名}.png`,
    });
    continue;
  }
  const 文件名 = path.basename(源文件);

  const 目标目录 = path.join(输出目录, 分类);
  const 目标文件 = path.join(目标目录, 文件名);
  fs.mkdirSync(目标目录, { recursive: true });
  // 缓存必须按**目标文件**记：同一张图标会被多个 source_category 的物品引用
  // （如 16000555 的 icon 其实住在 LiBao 库，但它的 source_category 是 FuZhuWuPin）。
  // 按源文件去重的话，第二个分类号会跳过复制、却照样写索引 —— 索引就指向一条没落盘的路径。
  if (!已复制.has(目标文件)) {
    if (源文件 !== 目标文件 && (!fs.existsSync(目标文件) || !文件内容相同(源文件, 目标文件))) {
      fs.copyFileSync(源文件, 目标文件);
    }
    已复制.add(目标文件);
  }
  索引[编号] = `res://${path.relative(项目目录, 目标文件).split(path.sep).join("/")}`;
}

fs.mkdirSync(path.dirname(索引路径), { recursive: true });
fs.writeFileSync(索引路径, JSON.stringify(索引));
fs.writeFileSync(缺失路径, JSON.stringify(缺失));

const 无定义 = 缺失.filter((条目) => 条目.reason === "图标定义为空").length;
const 真缺失 = 缺失.length - 无定义;
console.log(
  `物品图标导入完成：物品 ${Object.keys(物品).length}，命中 ${Object.keys(索引).length}，` +
  `复制 ${已复制.size}，无定义 ${无定义}，源文件缺失 ${真缺失}`,
);

function 文件内容相同(左路径, 右路径) {
  const 左 = fs.statSync(左路径);
  const 右 = fs.statSync(右路径);
  if (左.size !== 右.size) return false;
  return fs.readFileSync(左路径).equals(fs.readFileSync(右路径));
}

function 查找图标文件(分类, swf, 类名) {
  // 先找美术包（含 A3 的原版直解包），再找输出目录本身 —— 美术包漏掉的那批由 补物品图标源.mjs
  // 用 ffdec 直接从原版 SWF 解出来落在输出目录里，文件名沿用同一口径，所以这里认得。
  const 前缀 = `${swf}.swf_`;
  const 后缀 = `_${类名}.png`;
  for (const 根 of 图标候选目录(分类, swf)) {
    if (!fs.existsSync(根)) continue;
    if (!分类文件缓存.has(根)) 分类文件缓存.set(根, fs.readdirSync(根).sort());
    for (const 文件名 of 分类文件缓存.get(根)) {
      if (!文件名.startsWith(前缀) || !文件名.endsWith(后缀)) continue;
      const 帧号 = 文件名.slice(前缀.length, 文件名.length - 后缀.length);
      if (/^\d+$/.test(帧号)) return path.join(根, 文件名);
    }
  }
  return "";
}

/**
 * 图标该去哪些目录找。
 * 关键：库归哪个目录由 **swf 名首段**决定（`ImgUtil.as:264-266`），不是物品的 `source_category` ——
 * 实测有 FuZhuWuPin 的物品指向 `LiBao_11000440_info`，只按 source_category 找就永远报"源文件不存在"。
 */
function 图标候选目录(分类, swf) {
  const 出 = [];
  const 加 = (名) => {
    if (!名) return;
    try { 出.push(...分类目录(项目目录, 名, 参数.assets)); } catch { /* 那个分类任何包都没有 */ }
  };
  加(分类);
  加(String(swf || "").split("_")[0]);
  出.push(path.join(输出目录, 分类));
  return [...new Set(出)];
}
