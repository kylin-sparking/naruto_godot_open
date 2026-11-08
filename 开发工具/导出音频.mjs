#!/usr/bin/env node
// 导出原版音频：52 首地图 BGM + 22 条音效 + 2 条影分身音效，并生成 `数据/音效.json`。
//
// 为什么要有这个脚本（2026-09-26，模块 A1）：
//   `音频管理.gd` 原来找的是 `素材/音效/map_bgm.ogg` —— **这个文件从来不存在**，所以 BGM 恒为 0 首；
//   而 `素材/音效/attack.wav`/`hit.wav`/`portal.wav` 是 2026-09-21 自造的占位，原版没有这三个东西。
//   这里把真素材整批搬进来，音效名直接从反编译源 `SoundConstants.as` 正则取，不手抄清单。
//
// 真值出处（三条，都是本机实测）：
//   * BGM 清单 = 客户端 `mp3/` 目录本身（52 个：0..50 + default）；
//     选曲规则 = `com/mxw/game/world/World.as:932-1080`（`currentBGMChoices` 读地图 `info.bgm`，
//     `parseBGMChoices` 支持 `名@权重`、逗号/分号分隔、去重、空则 `default`）。
//   * 音效清单 = `com/mxw/common/sound/SoundConstants.as` 的 22 个 `SOUND_*` 常量；
//     每条按 `CocoJob`（100火/200水/300雷/400风）**精确匹配**，土遁 500 与转职细分 110+ 一律 null=不播
//     （`SoundConstants.GetMaiSound/GetSelectSound/GetBaoJiSound/GetDeadSound` 四个 switch）。
//   * 影分身 = `com/mxw/skills/effects/AbstractCloseAttackEffect.as:268` 直连
//     `audio/shadow-clone-summon.mp3` / `audio/shadow-clone-despawn.mp3`。
//
// 用法：node 开发工具/导出音频.mjs
//   可用环境变量：NARUTO_GAME_ROOT（客户端根）、FFDEC（ffdec-cli.exe 路径）

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import os from "node:os";

const 工程 = path.resolve(import.meta.dirname, "..");
const 客户端根 = process.env.NARUTO_GAME_ROOT || path.join(工程, "..", "2.2.3");
const Web根 = path.join(客户端根, "www/act_web_nya_208_isolated");
const AS3根 = process.env.NARUTO_AS_ROOT || path.join(工程, "..", "2.2.3", "map_extract/out/mainlib_as/scripts");
const ffdec = process.env.FFDEC || "ffdec-cli.exe";

const 出BGM = "素材/音效/BGM";
const 出音效 = "素材/音效";

function 必在(p, 说明) {
	if (!fs.existsSync(p)) throw new Error(`${说明}不存在：${p}`);
	return p;
}

/** 从 `SoundConstants.as` 取全部 `名字:String = "值"` 常量，并顺带取每个 switch 函数 的 职号→常量 分派。 */
function 读音效源() {
	const 源 = fs.readFileSync(必在(path.join(AS3根, "com/mxw/common/sound/SoundConstants.as"), "SoundConstants.as"), "utf8");
	const 名 = {};
	for (const m of 源.matchAll(/public static const (SOUND_\w+):String\s*=\s*"([^"]+)"/g)) 名[m[1]] = m[2];
	// `case CocoJob.NINJA_X: return SOUND_Y;` → { 符号键: { 职业系常量名: 音效常量名 } }
	const 分派 = {};
	for (const f of 源.matchAll(/public static function (Get\w+Sound)\(param1:int\) : String\s*\{(.*?)\n\s*\}/gs)) {
		const 表 = {};
		for (const m of f[2].matchAll(/case CocoJob\.(\w+):\s*return (SOUND_\w+);/g)) 表[m[1]] = m[2];
		分派[f[1]] = 表;
	}
	return { 名, 分派 };
}

/** CocoJob 的五个职号（`CocoJob.as:6-14`）—— 从源里取，不写死数字。 */
function 读职号表() {
	const 源 = fs.readFileSync(必在(path.join(AS3根, "com/mxw/data/enums/CocoJob.as"), "CocoJob.as"), "utf8");
	const 表 = {};
	for (const m of 源.matchAll(/public static const (NINJA_\w+):int\s*=\s*(\d+)/g)) 表[m[1]] = parseInt(m[2], 10);
	return 表;
}

function 拷(源, 标) {
	fs.mkdirSync(path.dirname(标), { recursive: true });
	fs.copyFileSync(源, 标);
}

/** 用一个 ffdec 能跑的子进程把 swf 里的音效解出来；返回 名字 → 临时文件路径。 */
function 解音效库(swf路径, 工作目录) {
	fs.rmSync(工作目录, { recursive: true, force: true });
	fs.mkdirSync(工作目录, { recursive: true });
	execFileSync(ffdec, ["-export", "sound", 工作目录, swf路径], { stdio: "pipe" });
	const 出 = {};
	for (const f of fs.readdirSync(工作目录)) {
		// ffdec 命名是 `<DefineSound id>_<类名>.mp3`；`-1.wav` 是每个库里那个 44 字节的空壳，丢掉。
		const m = /^-?\d+_(.+)\.(mp3|wav)$/i.exec(f);
		if (!m) continue;
		if (m[1] === "-1") continue;
		出[m[1]] = path.join(工作目录, f);
	}
	return 出;
}

/** 扫我们的地图数据，只为核对覆盖率。
 *  ⚠️ 地图的 bgm **不写进表** —— 原版就是运行时读地图自己的 `info.bgm`
 *  （`World.as:999 PicTool.getMapObject(id).info.bgm`），再抄一份进 JSON 就是第二个真相源。 */
function 数地图BGM() {
	const 分布 = {};
	const 根 = "数据/地图";
	if (!fs.existsSync(根)) throw new Error(`地图数据目录不存在：${根}`);
	let 张数 = 0;
	for (const 目录 of fs.readdirSync(根)) {
		const f = path.join(根, 目录, "地图.json");
		if (!fs.existsSync(f)) continue;
		张数++;
		const bgm = (JSON.parse(fs.readFileSync(f, "utf8")).info || {}).bgm;
		const 键 = bgm === undefined ? "null" : String(bgm);
		分布[键] = (分布[键] || 0) + 1;
	}
	return { 张数, 分布 };
}

const { 名: 音效常量, 分派 } = 读音效源();
const 职号 = 读职号表();
const 音效名集 = new Set(Object.values(音效常量));
if (音效名集.size !== Object.keys(音效常量).length) throw new Error("SoundConstants 里有重复值");

// ---- 1) BGM：整目录照搬，一个不落下 ----
const BGM源目录 = 必在(path.join(Web根, "mp3"), "客户端 mp3 目录");
const BGM清单 = fs.readdirSync(BGM源目录).filter((f) => f.toLowerCase().endsWith(".mp3")).sort();
for (const f of BGM清单) 拷(path.join(BGM源目录, f), path.join(出BGM, f));

// default 与 2 内容相同是原版事实（`World.as:300` 空 bgm 落到 "default"），这里只做记录不做合并。
function md5(p) {
	return crypto.createHash("md5").update(fs.readFileSync(p)).digest("hex");
}
const 同内容 = {};
{
	const 指纹 = {};
	for (const f of BGM清单) {
		const h = md5(path.join(BGM源目录, f));
		(指纹[h] ||= []).push(f);
	}
	for (const g of Object.values(指纹)) if (g.length > 1) 同内容[g.join("=")] = g.length;
}

// ---- 2) 音效：9 个 Sound_*.swf 解出 22 条 ----
const 音效库目录 = 必在(path.join(Web根, "swf/Sound"), "swf/Sound 目录");
const 临时 = fs.mkdtempSync(path.join(os.tmpdir(), "hysj-sound-"));
const 解出 = {};
const 来源库 = {};
for (const f of fs.readdirSync(音效库目录)) {
	if (!/^Sound_\w+\.swf$/i.test(f)) continue; // `Sound_XXX[1].swf` 是重复副本，跳过
	const 表 = 解音效库(path.join(音效库目录, f), path.join(临时, path.basename(f, ".swf")));
	for (const [n, p] of Object.entries(表)) {
		if (解出[n]) throw new Error(`音效 ${n} 在两个库里都出现：${f}`);
		解出[n] = p;
		来源库[n] = f;
	}
}
const 差1 = [...音效名集].filter((n) => !解出[n]);
const 差2 = Object.keys(解出).filter((n) => !音效名集.has(n));
if (差1.length || 差2.length) {
	fs.rmSync(临时, { recursive: true, force: true });
	throw new Error(`SoundConstants 与 swf 解出的音效不一致\n  只在常量表：${差1}\n  只在 swf：${差2}`);
}
for (const [n, p] of Object.entries(解出)) 拷(p, path.join(出音效, `${n}.mp3`));
fs.rmSync(临时, { recursive: true, force: true });

// ---- 3) 影分身两条 mp3 ----
const 分身目录 = 必在(path.join(Web根, "audio"), "audio 目录");
const 分身清单 = fs.readdirSync(分身目录).filter((f) => f.toLowerCase().endsWith(".mp3"));
for (const f of 分身清单) 拷(path.join(分身目录, f), path.join(出音效, f));

// ---- 4) 表 ----
const 音效 = {};
for (const [常量, 名] of Object.entries(音效常量).sort((a, b) => a[1].localeCompare(b[1]))) {
	音效[名] = { 文件: `res://${出音效}/${名}.mp3`, 库文件: 来源库[名], 常量: 常量 };
}
const 按职业 = {};
for (const [函数, 表] of Object.entries(分派)) {
	按职业[函数] = Object.fromEntries(
		Object.entries(表).map(([系, 常量]) => [职号[系] ?? `?${系}`, 音效常量[常量]])
	);
}
const 地图核对 = 数地图BGM();

const 表 = {
	说明: "原版音频库。生成物，别手改；改逻辑请改 开发工具/导出音频.mjs。",
	BGM: {
		目录: `res://${出BGM}`,
		数量: BGM清单.length,
		清单: BGM清单.map((f) => f.replace(/\.mp3$/i, "")),
		内容重复: 同内容,
		选曲真值: "地图的 bgm **不抄进本表**：原版就是运行时读地图自己的 info.bgm（World.as:999），这里只留核对用的分布统计",
		地图核对,
		规则: {
			选项: "World.as:1091 parseBGMChoices —— 逗号/竖线/分号分隔，`名@权重` 把名字重复入池，去重，全空则 default",
			防重复: "World.as:947-977 同图连续切歌时，若上首是出现次数最多且独享最多，则把它剔出本次随机池",
			淡切: "World.as:1021/1050 beginBGMFade+advanceBGMFade：先淡出到 0 换轨，再淡入到设置音量；跨图换图不淡切",
			播完: "World.as:1085 onBGMComplete → playBGM() 重选一首",
		},
	},
	音效: { 目录: `res://${出音效}`, 数量: Object.keys(音效).length, 表: 音效, 按职业: 按职业,
		职业系真值: "CocoJob.as:6-14 + SoundConstants 四个 Get*Sound 的 switch：**精确匹配** 100/200/300/400，其余（含土遁 500、转职细分 110+）返回 null = 不播",
		无调用点的: Object.keys(音效).filter((n) => /Select|MesoPickup/.test(n)),
	},
	影分身: { 目录: `res://${出音效}`, 清单: 分身清单, 出处: "AbstractCloseAttackEffect.as:268" },
};

fs.mkdirSync("数据", { recursive: true });
fs.writeFileSync("数据/音效.json", JSON.stringify(表, null, 2) + "\n");

console.log(`BGM ${BGM清单.length} 首 → ${出BGM}/`);
console.log(`音效 ${Object.keys(音效).length} 条 + 影分身 ${分身清单.length} 条 → ${出音效}/`);
console.log(`地图 ${地图核对.张数} 张，info.bgm 取值分布：${JSON.stringify(地图核对.分布)}`);
console.log(`内容重复的 BGM：${JSON.stringify(同内容)}`);
