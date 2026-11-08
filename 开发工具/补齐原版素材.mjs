import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

/**
 * A3 补齐：把 `数据/素材缺失查证.json` 里结论为「可补」的符号，用 ffdec 从**原版客户端 swf**
 * 直接解成 PNG，落进 `素材/原版直解/<分类>/<库名>.swf_<chid>_<类名>.png`。
 *
 * 为什么要它：6 份"缺失"清单的导入器一律只扫二手 `完整美术资源` PNG 包的文件名，
 * 包没打全就报「源文件不存在」。原版 swf 里其实有原件（实测 164 项里 92 项有）。
 *
 * 命名沿用美术包口径（`<库名>.swf_<chid>_<类名>.png`），所以各导入器只要把
 * `素材/原版直解/<分类>` 当成第二个包根来扫就能收进索引 —— 不改包、不改包里的任何东西。
 *
 * 前置：先跑 `python 开发工具/查证素材缺失.py` 生成 `数据/素材缺失查证.json`（该报告是派生物，不进仓库）。
 *
 * 用法：node 开发工具/补齐原版素材.mjs [--ffdec=ffdec-cli.exe] [--only=物品图标,地图素材]
 */
const 脚本目录 = path.dirname(fileURLToPath(import.meta.url));
const 项目目录 = path.resolve(脚本目录, "..");
const 参数 = Object.fromEntries(process.argv.slice(2).map((值) => {
  const [键, ...其余] = 值.replace(/^--/, "").split("=");
  return [键, 其余.join("=")];
}));
const ffdec = path.resolve(参数.ffdec || process.env.FFDEC || "ffdec-cli.exe");
const 查证路径 = path.join(项目目录, "数据", "素材缺失查证.json");
if (!fs.existsSync(查证路径)) {
  throw new Error(`缺少 ${查证路径}\n先跑 python 开发工具/查证素材缺失.py 生成。`);
}
const 查证 = JSON.parse(fs.readFileSync(查证路径, "utf8"));
const 直解根 = path.join(项目目录, "素材", "原版直解");
const 清单路径 = path.join(项目目录, "数据", "原版直解清单.json");
const 只跑 = 参数.only ? 参数.only.split(",") : null;

if (!fs.existsSync(ffdec)) throw new Error(`找不到 ffdec：${ffdec}`);

// 分类 = 库文件所在的原版目录名，直接由源文件路径反推，不猜。
const 分类of = (源文件) => path.basename(path.dirname(源文件));
// 每个 swf 只解一次：一个库里往往躺着几十张要补的图（水之国地图块、基底特效都是这样）。
const 待解 = new Map();
for (const 条目 of 查证.条目) {
  if (条目.结论 !== "可补") continue;
  if (只跑 && !只跑.includes(条目.清单)) continue;
  if (!待解.has(条目.源文件)) 待解.set(条目.源文件, []);
  待解.get(条目.源文件).push(条目);
}

const 临时根 = fs.mkdtempSync(path.join(os.tmpdir(), "a3-"));
const 渲染根列表 = [];
const 结果 = fs.existsSync(清单路径) ? JSON.parse(fs.readFileSync(清单路径, "utf8")) : {};
let 解出 = 0;
let 缺符号 = 0;
for (const [源文件, 条目列表] of 待解) {
  const 库名 = path.basename(源文件, ".swf");
  const 分类 = 分类of(源文件);
  const 导出目录 = path.join(临时根, 分类, 库名);
  fs.mkdirSync(导出目录, { recursive: true });
  // ffdec 吃相对 POSIX 路径会静默不产出，必须给 Windows 绝对路径。
  try {
    execFileSync(ffdec, ["-format", "image:png", "-export", "image",
      导出目录.replace(/\\/g, "/"), 源文件.replace(/\\/g, "/")],
    { stdio: ["ignore", "pipe", "pipe"] });
  } catch (错误) {
    // ffdec 对个别库会以非 0 退出（多半是库里某个 tag 它自己报警），但图照样解出来了 ——
    // 判成败的唯一标准是"要补的符号有没有落到磁盘上"，不是它的退出码。
    console.warn(`ffdec 非 0 退出：${库名} —— ${String(错误.stderr || 错误.message).split("\n").slice(-2).join(" / ")}`);
  }

  const 扫产出 = () => {
    const 表 = new Map();
    for (const 名 of fs.existsSync(导出目录) ? fs.readdirSync(导出目录) : []) {
      if (!名.endsWith(".png")) continue;
      const 匹配 = 名.match(/^(\d+)_(.+)\.png$/);
      if (匹配) 表.set(匹配[2], { chid: Number(匹配[1]), 类名: 匹配[2], 文件名: 名 });
    }
    return 表;
  };
  // 地图物件的"一个逻辑名"其实是一串帧（Obj_x_0、Obj_x_1…），清单里记的是前缀，要整族收。
  // 前缀规则只给地图物件用 —— 别处按前缀收会串图（`Tile_a_bsc_3` 会连 `Tile_a_bsc_30` 一起捞走）。
  const 对得上 = (产出, 条目) => {
    const 精确 = 产出.get(条目.类名);
    if (精确) return [精确];
    if (!(条目.清单 === "地图素材" && 条目.名称 === "地图物件")) return [];
    return [...产出.values()].filter((产) => 产.类名.startsWith(`${条目.类名}_`));
  };
  let 产出 = 扫产出();
  let 待直解 = 条目列表.filter((条目) => 对得上(产出, 条目).length === 0);
  if (待直解.length > 0) {
    // ffdec 的 image 导出解不了 DefineBitsLossless2（它会弹交互重试），这类位图自己解 swf tag。
    try {
      execFileSync("python", [path.join(脚本目录, "swf位图直解.py"), 源文件, 导出目录], { stdio: ["ignore", "pipe", "pipe"] });
    } catch (错误) {
      console.warn(`直解器失败：${库名} —— ${String(错误.stderr || 错误.message).split("\n").slice(-1)[0]}`);
    }
    产出 = 扫产出();
  }
  const 落点目录 = path.join(直解根, 分类);
  fs.mkdirSync(落点目录, { recursive: true });
  for (const 条目 of 条目列表) {
    const 产物列表 = 对得上(产出, 条目);
    if (产物列表.length === 0) {
      // 位图导出解不了的，剩下两种可能：矢量绘制，或**动画元件**（DefineSprite，多帧）。
      // 后者压成单图就是简化，所以整族帧落盘，台账里标明形态。
      const 帧 = 解动画元件(源文件, 条目.类名);
      if (帧) {
        const 目录名 = `${库名}.swf_${帧.chid}_${条目.类名}`;
        const 目标目录 = path.join(落点目录, 目录名);
        fs.mkdirSync(目标目录, { recursive: true });
        for (const [序号, 源帧] of 帧.帧列表.entries()) {
          fs.copyFileSync(源帧, path.join(目标目录, `${序号}.png`));
        }
        结果[条目.类名] = {
          清单: 条目.清单, 键: 条目.键, 源swf: 源文件, 库名, 分类, chid: 帧.chid,
          形态: `动画元件（${帧.帧列表.length} 帧 DefineSprite，非位图，不能压成单图）`,
          落点: `res://素材/原版直解/${分类}/${目录名}/`,
        };
        解出++;
        console.warn(`动画元件：${分类}/${库名}.swf 的 ${条目.类名} 是 ${帧.帧列表.length} 帧 DefineSprite，整族帧已落盘`);
        continue;
      }
      缺符号++;
      console.warn(`解不出：${分类}/${库名}.swf 里没有位图符号 ${条目.类名}（库里它是矢量/元件，不是位图）`);
      continue;
    }
    for (const 产 of 产物列表) {
      const 类名 = 产.类名 || 条目.类名;
      const 目标名 = `${库名}.swf_${产.chid}_${类名}.png`;
      const 目标 = path.join(落点目录, 目标名);
      fs.copyFileSync(path.join(导出目录, 产.文件名), 目标);
      const 字节 = fs.readFileSync(目标);
      结果[类名] = {
        清单: 条目.清单, 键: 条目.键, 源swf: 源文件, 库名, 分类, chid: 产.chid,
        字节: 字节.length, 宽: 字节.readUInt32BE(16), 高: 字节.readUInt32BE(20),
        落点: `res://素材/原版直解/${分类}/${目标名}`,
      };
      解出++;
    }
  }
}
fs.rmSync(临时根, { recursive: true, force: true });
for (const 目录 of 渲染根列表) fs.rmSync(目录, { recursive: true, force: true });
fs.writeFileSync(清单路径, JSON.stringify(结果, null, 1));
console.log(`补齐完成：本次解出 ${解出} 张、解不出 ${缺符号} 张；台账累计 ${Object.keys(结果).length} 条 → ${清单路径}`);

/**
 * 用 ffdec 的 sprite 渲染把**动画元件**（DefineSprite）整族帧解出来。
 * `-export image` 只导位图字典，动画元件拿不到；`-export sprite` 会把库里每个元件
 * 渲染成 `DefineSprite_<chid>_<类名>/<帧号>.png`。
 * 返回 null 表示库里确实没有这个类名的元件。
 */
function 解动画元件(源文件, 类名) {
  const 渲染目录 = fs.mkdtempSync(path.join(os.tmpdir(), "a3-sprite-"));
  try {
    execFileSync(ffdec, ["-export", "sprite", 渲染目录.replace(/\\/g, "/"), 源文件.replace(/\\/g, "/")],
      { stdio: ["ignore", "pipe", "pipe"] });
  } catch (错误) {
    console.warn(`ffdec sprite 非 0 退出：${类名} —— ${String(错误.stderr || 错误.message).split("\n").slice(-2).join(" / ")}`);
  }
  const 后缀 = `_${类名}`;
  const 目录 = fs.readdirSync(渲染目录)
    .find((名) => 名.startsWith("DefineSprite_") && (名.endsWith(后缀) || 名 === `DefineSprite_${类名}`));
  if (!目录) { fs.rmSync(渲染目录, { recursive: true, force: true }); return null; }
  const chid = Number(目录.match(/^DefineSprite_(\d+)/)[1]);
  const 帧列表 = fs.readdirSync(path.join(渲染目录, 目录))
    .filter((名) => /^\d+\.png$/.test(名))
    .sort((左, 右) => Number(左.split(".")[0]) - Number(右.split(".")[0]))
    .map((名) => path.join(渲染目录, 目录, 名));
  if (帧列表.length === 0) { fs.rmSync(渲染目录, { recursive: true, force: true }); return null; }
  渲染根列表.push(渲染目录);
  return { chid, 帧列表 };
}
