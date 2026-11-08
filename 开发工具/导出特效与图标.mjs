import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

/// A2 特效与状态图标：按原版数据表 + 原版播放代码的原样，把 swf 里的逐帧位图/时间轴解出来，
/// 生成 素材/特效、素材/状态图标、数据/特效.json、数据/状态图标.json、数据/特效帧数核对.json。
///
/// 三类形态，每类各有真值来源（不猜、不手抄）：
///   ① 逐帧位图 = `Etc.effects`（58 键）：每帧给 {origin, value{className,swfName}, delay}，
///      帧是库里的独立 Bitmap，不是时间轴帧。
///   ② swf 时间轴 = `Etc.mcEffect`（18 键）：只给 frameCount，画面靠 swf 自己的 DefineSprite。
///   ③ 两张表都不提的 14 个 swf = `MCFromDatDefine.as:217-280` 的硬编码前缀链，
///      那里逐行写死了 frameCount 与 swfName（见下面的 硬链 表）。
///
/// 其它口径：
///   · 路径规则   ImgUtil.as:264-266  `SWF_PATH_HEAD + swfName.split("_")[0] + "/" + swfName + ".swf"`
///   · origin     ByteArrayImage.as:100-105 / CharacterItem.as:53-60  `bmp.x = -origin.x`
///   · 帧间隔     FrameQueueAnimation.as:106-123  `delay || 100`
///   · 时间轴步长 MCFromDatDefine.as:29/37  `_fps=100` → `_frameTime=1000/_fps`；:183 `% frameCount + 1`（1 起）
///   · 播完行为   MCFromDatDefine.as:184-195 `once` → 停住；Animation.as:116-160 不循环时停在最后一帧
///   · Buff 图标  `Buff` 表 7 子类 + `BuffWuPin` 表逐行 `icon.value.className`（静态位图，无动画）
///
/// 用法：node 开发工具/导出特效与图标.mjs [--客户端=<HYSJ>] [--ffdec=<ffdec-cli.exe>]
const 脚本目录 = path.dirname(fileURLToPath(import.meta.url));
const 项目目录 = path.resolve(脚本目录, "..");
const 参数 = Object.fromEntries(process.argv.slice(2).map((值) => {
  const [键, ...其余] = 值.replace(/^--/, "").split("=");
  return [键, 其余.join("=")];
}));

const 客户端根 = 参数.客户端 || process.env.NARUTO_GAME_ROOT
	|| path.join(项目目录, "..", "2.2.3");
const swf库 = path.resolve(参数.swf库 || path.join(客户端根, "www", "act_web_nya_208_isolated", "swf"));
const ffdec = path.resolve(参数.ffdec || process.env.FFDEC || "ffdec-cli.exe");
const 数据表 = path.resolve(参数.数据表
	|| process.env.NARUTO_DATA_JSON
	|| path.join(项目目录, "..", "原版源数据", "GameData.dat.json"));

const 出特效根 = path.join(项目目录, "素材", "特效");
const 出图标根 = path.join(项目目录, "素材", "状态图标");
const res = (绝对) => "res://" + path.relative(项目目录, 绝对).split(path.sep).join("/");

const 表 = JSON.parse(fs.readFileSync(数据表, "utf8").replace(/^﻿/, ""));

/// 每个特效名怎么播：fps / 是否自走 / 是否单次 / 缩放。每一条都有调用点行号。
/// 没列在这里的，走 MCFromDatDefine 的字段默认（fps 100 → 10ms/帧、循环、由外层 tick 驱动）。
const 默认播法 = { 每帧ms: 10, 循环: true, 自走: false, 单次: false, 依据: "MCFromDatDefine.as:29/37/183（_fps=100、gotoAndStop 钉帧、%frameCount 循环）" };
const 播法 = {
  Effect_guaJiZhong: { fps: 40, 自走: true, 依据: "GuajiHandler.as:1074-1077 new MCFromDatDefine → autoTick=true, fps=40" },
  Effect_PathFindingTip: { fps: 40, 自走: true, 依据: "KeyController.as:785-788 autoTick=true, fps=40" },
  Effect_MaiExplode_0: { fps: 100, 自走: true, 单次: true, 依据: "ExplodeEffect.as:12 类名表 / :114-117 autoTick=true, fps=100, once=true" },
  Effect_MaiExplode_1: { fps: 100, 自走: true, 单次: true, 依据: "ExplodeEffect.as:12 / :114-117" },
  Effect_MaiExplode_2: { fps: 100, 自走: true, 单次: true, 依据: "ExplodeEffect.as:12 / :114-117" },
  Effect_BossGuanHuan: { fps: 40,
    缩放: [{ x: 168 / 76, y: 40 / 76, 依据: "Monster.as:1667-1671（boss==1 的怪）" },
      { x: 336 / 76, y: 80 / 76, 依据: "Monster.as:1663-1666（mobId 6000000/6000001）" },
      { x: -168 / 76, y: 40 / 76, alpha: 0.7, 依据: "Character.as:863-868（玩家神器光环，scaleX 取负＝镜像）" }],
    依据: "Monster.as:1661-1665 / Character.as:858-861（autoTick=false，由光环层 tick）" },
  Effect_BianYiGuanHuan: { fps: 40, 依据: "Monster.as:1655-1665（_loc2_==2 走这个名字）" },
  Effect_BellGuanHuan: { fps: 40, 缩放: [{ x: -224 / 180, y: 95 / 181.6, 依据: "Character.as:1351-1366 addBellAura；调用点 MuVsXiaoHandler.as:42" }],
    依据: "Character.as:1358-1363 autoTick=false, fps=40" },
  Effect_tutorial_cToPickup: { 死特效: "DropItemSprite.as:54 声明、:412/:426/:454/:486 每帧 tick，但从没赋值过 → 2.2.3 里不会出现在屏幕上；照原版转换出来，Godot 端同样不调用" },
  Effect_tutorial_aToAttack: { 死特效: "全盘 grep 零命中（除 dat 表自身）→ 同上" },
  Effect_itemBuble: { 死特效: "DropItemSprite.as:54 声明 / :412-486 tick，从未 new → 2.2.3 不显示；素材照转，运行期不接" },
};
/// NoBlue0 这类伤害数字：MCFromDatDefine 只做贴图容器，帧号 = 数字字符下标，从不逐帧推进。
for (const 色 of ["NoRed", "NoBlue", "NoCri", "NoViolet"]) for (const 尾 of ["0", "1"]) {
  播法[`${色}${尾}`] = {
    静态: true,
    帧表: "Flash 1 起的帧号 = dicts.indexOf(字符)：'0'..'9' → 帧 1..10，'miss' → 帧 11（ColorNumber.as:42/63/86）。Godot 0 起 → 序号 = 帧号-1（0..9，miss=10）",
    动效: "数字本身不动画；容器上浮 speed=100 px/s、alpha 每秒 -1（ColorNumber.as:32/110-118）",
    依据: "ColorNumber.as:62-66 new MCFromDatDefine(type) 后只设 frame，没有 autoTick/tick",
    例外: "只有 NoCri1/NoRed0/NoViolet0 的时间轴真有第 11 帧（MISS 字形）；其余 5 个 No* 只有 10 帧 → 原版对它们 gotoAndStop(11) 越界、停在当前帧。这是原版行为，照搬不修。",
  };
}
for (let 阶 = 1; 阶 <= 8; 阶++) {
  播法[`Effect_LianZhanGuanHuan_${阶}`] = { fps: 40, 缩放: [{ x: 139.6 / 109.5, y: 33 / 109.5, 依据: "Character.as:662-678 setLianzhanEffect" }],
    依据: "Character.as:669-671 名字按下标拼、fps=40、autoTick=false" };
}
for (const 色 of ["Huang", "Lan", "Zi", "Lv"]) {
  播法[`Effect_KuaFuShenQi_${色}`] = { fps: 40, 缩放: [{ x: -224 / 180, y: 95 / 181.6, 依据: "Character.as:869-872（非 BossGuanHuan 分支）" }],
    依据: "StringTool.as:108-112 从 ShenQi.info.aura 取名 → Character.as:852-874 addShenQiAura" };
}

function 播法of(名) {
  const 记 = 播法[名];
  const 每帧ms = 记 && 记.fps ? Math.round((1000 / 记.fps) * 100) / 100 : 默认播法.每帧ms;
  return {
    每帧ms,
    循环: 记 && 记.单次 ? false : 默认播法.循环,
    单次: !!(记 && 记.单次),
    自走: !!(记 && 记.自走),
    静态: !!(记 && 记.静态),
    ...(记 && 记.缩放 ? { 缩放: 记.缩放 } : {}),
    ...(记 && 记.帧表 ? { 帧表: 记.帧表, 动效: 记.动效, 例外: 记.例外 } : {}),
    依据: (记 && 记.依据) || 默认播法.依据,
  };
}

/// ffdec 一次解一整个目录：image → `<出>/<名>.swf/<chid>_<className>.png`；
/// sprite → `<出>/<名>.swf/DefineSprite_<chid>_<className>/<n>.png`
function 批量导出(子目录, 类型) {
  const 源 = path.join(swf库, 子目录);
  const 出 = fs.mkdtempSync(path.join(os.tmpdir(), `naruto-a2-${子目录}-`));
  execFileSync(ffdec, ["-format", `${类型}:png`, "-export", 类型 === "sprite" ? "sprite" : "image", 出, 源],
    { stdio: "pipe", timeout: 900000 });
  const 结果 = new Map();
  for (const swf名 of fs.readdirSync(出)) {
    const 前缀 = swf名.replace(/\.swf$/i, "");
    if (前缀.endsWith("[1]")) continue; // 库里的重名副本，不是新素材
    const 目 = path.join(出, swf名);
    if (!fs.statSync(目).isDirectory()) continue;
    结果.set(前缀, fs.readdirSync(目).map((f) => ({ 文件: f, 路径: path.join(目, f) })));
  }
  return { 出, 结果 };
}

/// PNG 头部（IHDR）读宽高，不依赖图像库。
function PNG信息(文件) {
  const b = fs.readFileSync(文件);
  return { 宽: b.readUInt32BE(16), 高: b.readUInt32BE(20) };
}

const 位图包 = 批量导出("Effect", "image");
const 时间轴包 = 批量导出("Effect", "sprite");
const Buff包 = 批量导出("Buff", "image");
const BuffWuPin包 = 批量导出("BuffWuPin", "image");

const 特效 = {};
const 核对 = [];
const 失败 = [];
let 贴图数 = 0;

function 落位图(swfName, 类名, 目标目录) {
  const 清单 = 位图包.结果.get(swfName);
  if (!清单) return { 错: `swf 库里没有 Effect/${swfName}.swf` };
  const 命中 = 清单.find((项) => new RegExp(`^(\\d+)_${类名}\\.png$`).test(项.文件));
  if (!命中) return { 错: `${swfName}.swf 里没有类名 ${类名}` };
  fs.mkdirSync(目标目录, { recursive: true });
  const 目标 = path.join(目标目录, `${类名}.png`);
  fs.copyFileSync(命中.路径, 目标);
  贴图数++;
  const { 宽, 高 } = PNG信息(目标);
  return { 好: { 贴图: res(目标), 宽, 高 } };
}

// ── ① Etc.effects：逐帧位图 ────────────────────────────────────────────
function 收序列(键, 帧表) {
  const 帧清单 = Object.keys(帧表).filter((k) => /^\d+$/.test(k))
    .sort((a, b) => Number(a) - Number(b)).map((k) => 帧表[k]);
  const 类名集 = new Set();
  const swf集 = new Set();
  const 帧s = [];
  帧清单.forEach((帧, i) => {
    const v = 帧.value;
    if (!v || !v.className) { // 原版就有的“空帧”：只有 delay 不画东西（如 maiTong* 末尾那 10 秒）
      帧s.push({ 序号: i, 类名: null, 贴图: "", 停留ms: 帧.delay ?? 100, 原点: [帧.origin?.x ?? 0, 帧.origin?.y ?? 0] });
      return;
    }
    类名集.add(v.className);
    swf集.add(v.swfName);
    const r = 落位图(v.swfName, v.className, path.join(出特效根, v.swfName));
    if (r.错) { 失败.push({ 键, 类名: v.className, 原因: r.错 }); return; }
    帧s.push({ 序号: i, 类名: v.className, 贴图: r.好.贴图, 宽: r.好.宽, 高: r.好.高,
      停留ms: 帧.delay ?? 100, 原点: [帧.origin?.x ?? 0, 帧.origin?.y ?? 0] });
  });
  特效[键] = { 形态: "逐帧位图", 播法: { 帧间隔: "逐帧读 delay，缺省 100ms（FrameQueueAnimation.as:119）" },
    帧: 帧s, 出处: `Etc.effects.${键}` };
  const 有图 = 帧s.filter((f) => f.类名).length;
  核对.push({ 项: 键, 形态: "逐帧位图", 表里帧数: 帧清单.length, 有图帧数: 有图,
    导出成功: 帧s.filter((f) => f.贴图).length, 用到类名: 类名集.size, swf: [...swf集].join("|"),
    判定: 有图 === 帧s.filter((f) => f.贴图).length ? "ok" : "不符" });
}

for (const [键, 值] of Object.entries(表.Etc.effects)) {
  const 首 = 值[Object.keys(值)[0]];
  if (首 && 首.value) 收序列(键, 值);
  else for (const [子, 子表] of Object.entries(值)) 收序列(`${键}/${子}`, 子表); // bgFlags、chest 是两级
}

// ── ②+③ swf 自带时间轴（Etc.mcEffect 与 MCFromDatDefine 前缀链同一条路）──
function 收时间轴(键, swfName, 类名, frameCount, 出处) {
  const 目标目录 = path.join(出特效根, swfName, 类名);
  const 源 = 时间轴包.结果.get(swfName) || [];
  const 目录项 = 源.find((项) => 项.文件.endsWith(`_${类名}`)
    && fs.existsSync(项.路径) && fs.statSync(项.路径).isDirectory());
  if (!目录项) {
    // frameCount==1 的图标在库里常是单张 Bitmap 而非 Sprite → image 导出里找
    const r = 落位图(swfName, 类名, path.join(出特效根, swfName));
    if (r.错) { 失败.push({ 键, 类名, 原因: `${swfName}.swf 里找不到 ${类名} 的时间轴，也没有单张位图（${r.错}）` }); return; }
    特效[键] = { 形态: "静态图标", 帧: [{ 序号: 0, 类名, 贴图: r.好.贴图, 宽: r.好.宽, 高: r.好.高, 原点: [0, 0] }], 出处 };
    核对.push({ 项: 键, 形态: "静态图标", 表里帧数: frameCount, 时间轴实有帧数: 1, 落盘帧数: 1,
      判定: frameCount === 1 ? "ok" : "不符", 依据: "库里是单张 Bitmap 不是 Sprite，image 导出直接命中" });
    return;
  }
  const 全部帧 = fs.readdirSync(目录项.路径).filter((f) => /^\d+\.png$/.test(f))
    .map((f) => Number(f.replace(/\.png$/, ""))).sort((a, b) => a - b);
  // frameCount==1 的静态图标：原版取模恒为 1，只钉第 1 帧 → 也只落第 1 帧，别把没人看的时间轴帧搬进工程
  const 取用 = frameCount === 1 ? 全部帧.slice(0, 1) : 全部帧;
  const 取用集 = new Set(取用.map((n) => `${n}.png`));
  fs.mkdirSync(目标目录, { recursive: true });
  for (const f of fs.readdirSync(目标目录)) if (/^\d+\.png$/.test(f) && !取用集.has(f)) fs.rmSync(path.join(目标目录, f)); // 清掉上一次多落的帧
  const 帧s = [];
  for (const n of 取用) {
    const f = `${n}.png`;
    fs.copyFileSync(path.join(目录项.路径, f), path.join(目标目录, f));
    const { 宽, 高 } = PNG信息(path.join(目标目录, f));
    帧s.push({ 序号: n - 1, 帧号: n, 贴图: res(path.join(目标目录, f)), 宽, 高, 原点: [0, 0] });
    贴图数++;
  }
  const 播 = 播法of(类名);
  const 形态 = frameCount === 1 ? "静态图标" : "swf 时间轴";
  if (frameCount === 1) {
    特效[键] = { 形态, 帧: 帧s, 出处, 备注: `表里 frameCount=1 → %frameCount 恒为 1，原版只钉第 1 帧（MCFromDatDefine.as:183）；该时间轴实有 ${全部帧.length} 帧，多出来的不搬` };
  } else {
    特效[键] = { 形态, 播法: 播, 帧: 帧s, 出处 };
  }
  const 判定 = 全部帧.length < frameCount ? "不符"
    : 播.例外 ? "例外"
    : 全部帧.length === frameCount ? "ok" : "多帧";
  核对.push({ 项: 键, 形态, 表里帧数: frameCount, 时间轴实有帧数: 全部帧.length, 落盘帧数: 帧s.length, 判定,
    依据: 播.依据, ...(播.例外 ? { 说明: 播.例外 } : {}) });
}

for (const [键, 值] of Object.entries(表.Etc.mcEffect)) {
  收时间轴(键, 值.swfName, 值.className, 值.frameCount, `Etc.mcEffect.${键}`);
}

// ── ③ MCFromDatDefine.as:217-280 硬编码前缀链：两张 dat 表都不提的那 14 个 swf ──
const 硬链 = [
  { 前缀: "Effect_PaiHangBang", swfName: "Effect_PaiHangBang", frameCount: 1, 行: "MCFromDatDefine.as:220-227",
    不转原因: "死链：全盘没有任何地方构造 Effect_PaiHangBang* 这个特效名（PicTool.as:178/338、RankWindowManager.as:114 读的是 Etc.PaiHangBang 表，走的是另一条路）→ 原版没有的不许加" },
  { 前缀: "Effect_RenShuJingJie", swfName: "Effect_RenShuJingJie", frameCount: 1, 行: "MCFromDatDefine.as:228-235",
    名字: [0, 1, 2, 3, 4, 5, 6].map((n) => `Effect_RenShuJingJie_${n}`), 名字依据: "PicTool.as:257-261 getRenShuJingJieIcon：param1 先 clamp 到 0..6 再拼名" },
  { 前缀: "minimap_", swfName: "Effect_mapHelper", frameCount: 1, 行: "MCFromDatDefine.as:236-243",
    名字: ["portal", "user", "friend", "mob", "mobBoss", "mobJingYing", "npc", "startnpc", "questing", "endnpc", "party", "partymaster"]
      .map((n) => `minimap_${n}_skin`).concat(["minimap_flag_redSkin", "minimap_flag_blueSkin", "minimap_flag_yellowSkin"]),
    名字依据: "SmallMapHelper.as:10-32 十二个 CLASS_*_SKIN 常量 + SmallMapHandler.as:215/218/221 三个旗子" },
  { 前缀: "Effect_PathFindingTip", swfName: "Effect_PathFindingTip", frameCount: 40, 行: "MCFromDatDefine.as:244-251",
    名字: ["Effect_PathFindingTip"] },
  { 前缀: "Effect_EliteMob_", swfName: "Effect_EliteMob", frameCount: 1, 行: "MCFromDatDefine.as:252-259",
    名字: ["Atk", "Bsk", "Def", "Avd", "Hp", "Money", "Violent"].map((n) => `Effect_EliteMob_${n}`),
    名字依据: "PicTool.as:616-650 getEliteMobIcon 的 switch 七个分支，别的 SubAttrType 返回 null" },
  { 前缀: "Effect_KuaFuShenQi_", swfName: "Effect_KuaFuShenQi", frameCount: 80, 行: "MCFromDatDefine.as:260-267",
    名字: [...new Set(Object.values(表.ShenQi || {}).map((行) => 行?.info?.aura).filter((n) => typeof n === "string" && n.startsWith("Effect_KuaFuShenQi_")))],
    名字依据: "ShenQi 表 info.aura（StringTool.as:108-112 读的就是这个字段）" },
  { 前缀: "Effect_LianZhanGuanHuan", swfName: null, frameCount: 80, 行: "MCFromDatDefine.as:268-275",
    名字: [1, 2, 3, 4, 5, 6, 7, 8].map((n) => `Effect_LianZhanGuanHuan_${n}`),
    名字依据: "Character.as:669 按连胜阶数拼名；swf 库里正好这 8 个文件（swfName 等于特效名，每个阶数一份 swf）" },
];
const 链外说明 = [];
for (const 链 of 硬链) {
  if (链.不转原因) { 链外说明.push({ 项: 链.前缀, 处置: "不转", 依据: 链.行, 原因: 链.不转原因 }); continue; }
  for (const 名 of 链.名字) {
    const swfName = 链.swfName || 名; // PathFindingTip / LianZhan 的 swfName 就是特效名本身
    收时间轴(名, swfName, 名, 链.frameCount, `${链.行}（Etc.mcEffect 没有这个键，帧数写死在 AS3 里）`);
    if (特效[名]) 特效[名].名字依据 = 链.名字依据;
  }
}

// ── Buff / BuffWuPin 图标：每张就是一张静态位图 ─────────────────────────
function 落图标(包, swfName, 类名, 目标目录) {
  const 清单 = 包.get(swfName);
  if (!清单) return { 错: `swf 库里没有 ${swfName}.swf` };
  const 命中 = 清单.find((项) => new RegExp(`^(\\d+)_${类名}\\.png$`).test(项.文件));
  if (!命中) return { 错: `${swfName}.swf 里没有 ${类名}` };
  fs.mkdirSync(目标目录, { recursive: true });
  const 目标 = path.join(目标目录, `${类名}.png`);
  fs.copyFileSync(命中.路径, 目标);
  贴图数++;
  const { 宽, 高 } = PNG信息(目标);
  return { 好: { 贴图: res(目标), 宽, 高 } };
}

const 图标 = {};
const 图标核对 = [];
for (const [子类, 行表] of Object.entries(表.Buff)) {
  for (const [键, 行] of Object.entries(行表)) {
    const v = 行.icon && 行.icon.value;
    const 记 = { 子类, 键, 名称: 行.buffName || "", 说明: 行.buffDesc || "" };
    if (!v) { 记.贴图 = ""; 记.备注 = "原版这行没有 icon，不是缺图"; 图标[`${子类}/${键}`] = 记; 图标核对.push({ 项: `${子类}/${键}`, 结果: "原版无图标" }); continue; }
    const r = 落图标(Buff包.结果, v.swfName, v.className, path.join(出图标根, v.swfName));
    if (r.错) { 失败.push({ 键: `${子类}/${键}`, 原因: r.错 }); continue; }
    Object.assign(记, { 贴图: r.好.贴图, 类名: v.className, swf: v.swfName, 宽: r.好.宽, 高: r.好.高,
      原点: [行.icon.origin?.x ?? 0, 行.icon.origin?.y ?? 0] });
    图标[`${子类}/${键}`] = 记;
    图标核对.push({ 项: `${子类}/${键}`, 结果: `ok ${r.好.宽}×${r.好.高}`, 类名: v.className });
  }
}
const 物品Buff图标 = {};
for (const [id, 行] of Object.entries(表.BuffWuPin)) {
  const v = 行.info && 行.info.icon && 行.info.icon.value;
  if (!v) { 失败.push({ 键: `BuffWuPin/${id}`, 原因: "dat 里没有 icon 字段" }); continue; }
  const r = 落图标(BuffWuPin包.结果, v.swfName, v.className, path.join(出图标根, v.swfName));
  if (r.错) { 失败.push({ 键: `BuffWuPin/${id}`, 原因: r.错 }); continue; }
  物品Buff图标[id] = { 贴图: r.好.贴图, 类名: v.className, swf: v.swfName, 宽: r.好.宽, 高: r.好.高,
    原点: [行.info.icon.origin?.x ?? 0, 行.info.icon.origin?.y ?? 0] };
}

// ── 库里还有、但三处真值都不提的 swf：只登记，不转换 ────────────────────
const 表内swf = new Set();
for (const 值 of Object.values(特效)) {
  for (const 帧 of 值.帧) {
    const m = /res:\/\/素材\/特效\/([^/]+)\//.exec(帧.贴图 || "");
    if (m) 表内swf.add(m[1]);
  }
}
const 库内 = fs.readdirSync(path.join(swf库, "Effect")).filter((f) => /\.swf$/i.test(f))
  .map((f) => f.replace(/\.swf$/i, ""));
const 未收录 = [...new Set(库内)].filter((f) => !表内swf.has(f)).sort();

const 特效数据 = {
  说明: "原版特效贴图与时间轴。生成物，别手改；改逻辑请改 开发工具/导出特效与图标.mjs。",
  真值: {
    帧序列: "Etc.effects（58 键）逐帧给 className/swfName/delay/origin —— 帧是库里的独立 Bitmap",
    时间轴: "Etc.mcEffect（18 键）只给 frameCount，画面靠 swf 自己的 DefineSprite",
    前缀链: "两张表都不提的 14 个 swf：帧数写死在 MCFromDatDefine.as:217-280，名字来自各调用点（见每条的 名字依据）",
    路径规则: "ImgUtil.as:264-266 SWF_PATH_HEAD + swfName.split('_')[0] + '/' + swfName + '.swf'",
    原点语义: "CharacterItem.as:53-60 / ByteArrayImage.as:100-105：贴图 x = -origin.x, y = -origin.y",
    帧间隔: "FrameQueueAnimation.as:119：delay || 100",
    时间轴步长: "MCFromDatDefine.as:29/37/183：默认 _fps=100 → 10ms/帧，frame = 累计ms/每帧ms % frameCount + 1（1 起，gotoAndStop 钉帧）",
    播完: "MCFromDatDefine.as:184-195 once → _actionEnd+pause；Animation.as:116-160 不循环时停在最后一帧，不回头",
    静态: "frameCount=1 → 取模恒为 1，原版只画第 1 帧（排行帮/忍术境界/精英怪/小地图标记）",
    空帧: "帧里只有 delay 没有 value = 原版就不画东西（如 maiTong* 最后一帧 10000ms），不是缺图",
  },
  数量: Object.keys(特效).length,
  特效,
  链外说明,
  未收录,
  未收录说明: "这些 swf 在库里有，但 Etc.effects / Etc.mcEffect / MCFromDatDefine 前缀链三处都不提它 → 帧数与播放方式没有真值，先不转。其中 effect.swf 是 UI 皮肤库（与 asset/effect.swf 同 md5 032f45dd13249e0fd4279e38e656fb80，由 MainLoader.as:760 载入，16 个类名全是控件皮肤），不是特效，永久排除。",
};
const 图标数据 = {
  说明: "原版 Buff 状态图标。生成物，别手改；改逻辑请改 开发工具/导出特效与图标.mjs。",
  真值: {
    来源: "Buff 表逐行读 icon.value.className（不是拼字符串）+ BuffWuPin 表 info.icon",
    形态: "每个图标就是一张静态位图：ByteArrayImage.as:89-92 走 getBitmapDataFromClassName，没有动画",
    格子: "BuffCell.as:65-71 格 40×40、图标画在 (3,3)，冷却遮罩是唯一的动效 GirdCool(0,0.4,40,10,false)",
    面板: "BuffPane.as:81-93：≤18 个时 6 列、间距 41；超过改 3 列",
  },
  数量: Object.keys(图标).length + Object.keys(物品Buff图标).length,
  表: 图标,
  物品Buff: 物品Buff图标,
};

fs.mkdirSync(path.join(项目目录, "数据"), { recursive: true });
fs.writeFileSync(path.join(项目目录, "数据", "特效.json"), JSON.stringify(特效数据, null, 2) + "\n");
fs.writeFileSync(path.join(项目目录, "数据", "状态图标.json"), JSON.stringify(图标数据, null, 2) + "\n");
fs.writeFileSync(path.join(项目目录, "数据", "特效帧数核对.json"), JSON.stringify({ 特效: 核对, 图标: 图标核对, 失败 }, null, 2) + "\n");

for (const 包 of [位图包, 时间轴包, Buff包, BuffWuPin包]) fs.rmSync(包.出, { recursive: true, force: true });

const 形态计 = (名) => Object.values(特效).filter((v) => v.形态 === 名).length;
const 不符 = 核对.filter((r) => r.判定 === "不符");
const 例外 = 核对.filter((r) => r.判定 === "例外");
const 多帧 = 核对.filter((r) => r.判定 === "多帧");
console.log(`特效条目 ${特效数据.数量}（逐帧位图 ${形态计("逐帧位图")} / swf 时间轴 ${形态计("swf 时间轴")} / 静态图标 ${形态计("静态图标")}），图标 ${图标数据.数量}，落盘贴图 ${贴图数} 张`);
console.log(`帧数核对：${核对.length} 项，ok ${核对.length - 不符.length - 例外.length - 多帧.length}，不符 ${不符.length}，例外 ${例外.length}，多帧 ${多帧.length}${不符.length ? " " + JSON.stringify(不符) : ""}${多帧.length ? " 多帧项 " + JSON.stringify(多帧.map((r) => `${r.项}:${r.表里帧数}/${r.时间轴实有帧数}`)) : ""}`);
console.log(`导出失败 ${失败.length}${失败.length ? "：" + JSON.stringify(失败.slice(0, 10)) : ""}`);
console.log(`三处真值都不提的 swf ${未收录.length} 个：${未收录.join(", ")}`);
