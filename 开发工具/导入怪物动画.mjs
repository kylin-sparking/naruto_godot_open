import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { 扫分类图, 源数据 } from "./素材源.mjs";

const 脚本目录 = path.dirname(fileURLToPath(import.meta.url));
const 项目目录 = path.resolve(脚本目录, "..");
const 参数 = Object.fromEntries(process.argv.slice(2).map((value) => {
  const [key, ...rest] = value.replace(/^--/, "").split("=");
  return [key, rest.join("=")];
}));
const 数据源 = 源数据(项目目录, 参数.source);
const 动画目录 = path.join(项目目录, "素材", "角色动画", "怪物");
const 元数据路径 = path.join(项目目录, "数据", "角色", "动画元数据.json");
const 素材索引路径 = path.join(项目目录, "数据", "角色", "动画素材索引.json");
const 怪物索引路径 = path.join(项目目录, "数据", "怪物动画索引.json");
const 缺失路径 = path.join(项目目录, "数据", "怪物素材缺失.json");

for (const 文件 of [数据源, 元数据路径]) {
  if (!fs.existsSync(文件)) throw new Error(`缺少数据文件：${文件}`);
}

const 原版数据 = 读JSON(数据源);
const 元数据 = 读JSON(元数据路径);
元数据.mob = {};
const 源素材 = 建立源素材索引();
const 怪物索引 = {};
const 缺失 = [];
const 待复制 = new Map();

for (const [编号, 怪物] of Object.entries(原版数据.Mob || {}).sort(([左], [右]) => 左.localeCompare(右))) {
  const 解析 = 解析动画来源(编号, 怪物);
  if (!解析) {
    缺失.push({ id: 编号, name: 怪物名称(编号), reason: "没有可解析的动画来源" });
    continue;
  }
  let 动作 = 规范动作(解析.定义, 解析.类型);
  let 帧缺失 = 找缺失帧(动作);

  // 4000016/17 的 Mob 元数据存在但对应图片缺包；petLink=104 是原数据给出的确定性回落来源。
  if (帧缺失.length > 0 && Number(怪物.info?.petLink || 0) > 0) {
    const 宠物编号 = String(怪物.info.petLink).padStart(8, "0");
    const 宠物定义 = 原版数据.Pet?.[宠物编号];
    if (宠物定义) {
      解析.类型 = "pet";
      解析.来源编号 = 宠物编号;
      解析.方式 = "petLink-fallback";
      解析.定义 = 宠物定义;
      动作 = 规范动作(宠物定义, "pet");
      帧缺失 = 找缺失帧(动作);
    }
  }

  if (帧缺失.length > 0 || Object.keys(动作).length === 0) {
    缺失.push({
      id: 编号,
      name: 怪物名称(编号),
      reason: "动画帧源文件不存在",
      source_kind: 解析.类型,
      source_id: 解析.来源编号,
      missing_frames: 帧缺失,
    });
    continue;
  }

  元数据.mob[编号] = 动作;
  怪物索引[编号] = {
    source_kind: 解析.类型,
    source_id: 解析.来源编号,
    resolution: 解析.方式,
  };
  for (const 类名 of 动作类名(动作)) 待复制.set(类名, 源素材[类名]);
}

fs.mkdirSync(动画目录, { recursive: true });
for (const [类名, 源文件] of 待复制) {
  const 信息 = 怪物索引[Object.keys(怪物索引).find((编号) => 动作类名(元数据.mob[编号]).includes(类名))];
  const 分类目录 = 信息?.source_kind === "pet" ? "忍犬" : "原版怪物";
  const 来源编号 = 类名.match(/^(?:Mob|Pet)_(\d+)_/)?.[1] || "unknown";
  const 目标目录 = path.join(动画目录, `${分类目录}_${来源编号}`);
  const 目标文件 = path.join(目标目录, path.basename(源文件));
  fs.mkdirSync(目标目录, { recursive: true });
  if (!fs.existsSync(目标文件) || !文件内容相同(源文件, 目标文件)) fs.copyFileSync(源文件, 目标文件);
}

const 动画素材索引 = {};
建立项目素材索引(path.join(项目目录, "素材", "角色动画"), 动画素材索引);
写JSON(元数据路径, 元数据);
写JSON(素材索引路径, 动画素材索引);
写JSON(怪物索引路径, 怪物索引);
写JSON(缺失路径, 缺失);

const link数量 = Object.values(怪物索引).filter((值) => 值.resolution === "link").length;
const pet数量 = Object.values(怪物索引).filter((值) => String(值.resolution).startsWith("petLink")).length;
console.log(
  `怪物动画导入完成：覆盖 ${Object.keys(怪物索引).length}/1199，` +
  `link ${link数量}，petLink ${pet数量}，唯一帧 ${待复制.size}，缺失 ${缺失.length}`,
);

function 解析动画来源(编号, 怪物) {
  const 自带动作 = 动作键(怪物);
  if (自带动作.length > 0) return { 类型: "mob", 来源编号: 编号, 方式: "self", 定义: 怪物 };
  const link = 怪物.info?.link;
  if (link !== undefined && 原版数据.Mob?.[String(link)]) {
    return { 类型: "mob", 来源编号: String(link), 方式: "link", 定义: 原版数据.Mob[String(link)] };
  }
  const petLink = Number(怪物.info?.petLink || 0);
  const 宠物编号 = String(petLink).padStart(8, "0");
  if (petLink > 0 && 原版数据.Pet?.[宠物编号]) {
    return { 类型: "pet", 来源编号: 宠物编号, 方式: "petLink", 定义: 原版数据.Pet[宠物编号] };
  }
  return null;
}

function 规范动作(定义, 类型) {
  if (类型 === "mob") return Object.fromEntries(动作键(定义).map((键) => [键, 定义[键]]));
  const 动作 = {};
  if (定义.stand0) 动作.stand = 定义.stand0;
  if (定义.move) 动作.move = 定义.move;
  if (定义.attack) 动作.attack1 = 定义.attack;
  if (定义.jump) 动作.jump = 定义.jump;
  // 宠物原数据没有受击/死亡帧；用静止首帧保留可见反馈，战斗角色会负责飘字和死亡隐藏。
  const 静止首帧 = 定义.stand0?.["0"];
  if (静止首帧) {
    动作.hit1 = { "0": { ...静止首帧, delay: 240 } };
    动作.die1 = { "0": { ...静止首帧, delay: 800 } };
  }
  return 动作;
}

function 动作键(定义) {
  return Object.keys(定义 || {}).filter((键) => !["info", "skills"].includes(键));
}

function 动作类名(动作) {
  const 结果 = [];
  for (const 帧集 of Object.values(动作)) {
    for (const 帧 of Object.values(帧集 || {})) {
      const 视觉 = 帧.body || 帧;
      const 类名 = String(视觉?.value?.className || "");
      if (类名) 结果.push(类名);
    }
  }
  return [...new Set(结果)];
}

function 找缺失帧(动作) {
  return 动作类名(动作).filter((类名) => !源素材[类名]);
}

function 建立源素材索引() {
  const 结果 = {};
  for (const 分类 of ["Mob", "Pet"]) {
    // 扫分类图已按"二手包 → 原版直解包"排好序，先到先得：直解包只补二手包缺的帧。
    for (const { 文件名, 路径 } of 扫分类图(项目目录, 分类, 参数.assets)) {
      const 匹配 = 文件名.match(/\.swf_\d+_(.+)\.png$/);
      if (匹配 && !结果[匹配[1]]) 结果[匹配[1]] = 路径;
    }
  }
  return 结果;
}

function 建立项目素材索引(目录, 结果) {
  if (!fs.existsSync(目录)) return;
  for (const 条目 of fs.readdirSync(目录, { withFileTypes: true })) {
    const 完整路径 = path.join(目录, 条目.name);
    if (条目.isDirectory()) {
      建立项目素材索引(完整路径, 结果);
      continue;
    }
    if (!条目.name.endsWith(".png") || 条目.name.includes("[1]")) continue;
    const 匹配 = 条目.name.match(/\.swf_\d+_((?:Char|Npc|Mob|Pet)_.+)\.png$/);
    if (!匹配) continue;
    结果[匹配[1]] = `res://${path.relative(项目目录, 完整路径).split(path.sep).join("/")}`;
  }
}

function 怪物名称(编号) {
  const 文本 = 原版数据.String?.Mob?.[编号] || 原版数据.String?.Mob?.[String(Number(编号))] || {};
  return String(文本.name || 编号);
}

function 文件内容相同(左路径, 右路径) {
  const 左 = fs.statSync(左路径);
  const 右 = fs.statSync(右路径);
  return 左.size === 右.size && fs.readFileSync(左路径).equals(fs.readFileSync(右路径));
}

function 读JSON(文件) {
  return JSON.parse(fs.readFileSync(文件, "utf8").replace(/^\uFEFF/, ""));
}

function 写JSON(文件, 内容) {
  fs.mkdirSync(path.dirname(文件), { recursive: true });
  fs.writeFileSync(文件, JSON.stringify(内容));
}
