#!/usr/bin/env node
// 导出装备三张基础库：品质 / 属性名 / 提示框文案。
//
// 为什么要有这个脚本（2026-09-26）：这些值原来**只存在于 AS3 字面量里**，
// Godot 侧是手抄进 `装备格.gd` / `装备提示框.gd` 的 const。手抄过一次就再也对不回源头，
// 而且已经错过一回（`资质色` 里四个十六进制第 3、4 位被抄反，见 装备提示框.gd:132 的更正记录）。
// 这里改成从反编译源**正则取**，值不落在脚本里。
//
// 两个客户端版本都要读，别只读一个：
//   2.2.3 优化版  品质 1..5，无神话
//   新前端资源包  品质 1..6，多 APTITUDE_MYTH
// 我们的服务端可能发 6，所以两张数组都存进表里，由读表方决定用哪个下标。
// 路径用环境变量 NARUTO_OLD_AS_ROOT / NARUTO_NEW_AS_ROOT / NARUTO_MAINLIB_SWF 覆盖。
//
// 用法：node 开发工具/导出装备品质.mjs

import fs from "node:fs";
import path from "node:path";

const 项目目录 = path.resolve(import.meta.dirname, "..");
const 旧根 = process.env.NARUTO_OLD_AS_ROOT
	|| path.join(项目目录, "..", "2.2.3", "map_extract/out/mainlib_as/scripts");
const 新根 = process.env.NARUTO_NEW_AS_ROOT || 旧根;
// 素材的出处就是这个客户端的库文件（读帧率用）。
const 客户端SWF = process.env.NARUTO_MAINLIB_SWF
	|| path.join(项目目录, "..", "2.2.3", "www/act_web_nya_208_isolated/asset/MainLib_plain.swf");
const 输出目录 = path.join(项目目录, "数据");

function 读(根, ...相对) {
	const p = path.join(根, ...相对);
	if (!fs.existsSync(p)) throw new Error(`找不到反编译源：${p}`);
	return fs.readFileSync(p, "utf8");
}

/** 抓 `名字:Array = [....]` 里的数组字面量，按逗号切成整数。 */
function 抓整数数组(源码, 名字) {
	const m = new RegExp(`${名字}:Array\\s*=\\s*\\[([0-9,\\s]*)\\]`).exec(源码);
	if (!m) throw new Error(`数组 ${名字} 没找到`);
	return m[1].split(",").map((s) => parseInt(s.trim(), 10)).filter((n) => !Number.isNaN(n));
}

/** 抓 `名字:Array = [A.X, A.Y, ...]` 这类**符号**数组，用常量表把每一项换成整数。 */
function 抓符号数组(源码, 名字, 常量表) {
	const m = new RegExp(`${名字}:Array = \\[([^\\]]*)\\]`).exec(源码);
	if (!m) throw new Error(`数组 ${名字} 没找到`);
	return m[1].split(",").map((s) => {
		const t = s.trim().replace(/^"|"$/g, "");
		if (/^\d+$/.test(t)) return parseInt(t, 10);
		const 键 = t.split(".").pop();
		if (!(键 in 常量表)) throw new Error(`${名字} 里的 ${t} 在常量表里查不到`);
		return 常量表[键];
	});
}

/** 抓 `public static const 名字:int = N;` 这类常量，返回 {名字: N}。 */
function 抓常量(源码, 前缀) {
	const out = {};
	const re = new RegExp(`public static (?:const|var) (${前缀}[A-Z0-9_]+)\\s*:\\s*(?:int|String)\\s*=\\s*([0-9]+)`, "g");
	let m;
	while ((m = re.exec(源码))) out[m[1]] = parseInt(m[2], 10);
	return out;
}

/** 语言表：一行一条 `"KEY":"值"`，值里的 \n \u 之类按 Java 属性文件的写法转回来。 */
function 读语言表(根) {
	const 表 = new Map();
	for (const 行 of 读(根, "en_US$message_properties.as").split(/\r?\n/)) {
		const t = 行.trim();
		if (!t.startsWith('"')) continue;
		const i = t.indexOf('":"');
		if (i < 0) continue;
		const 键 = t.slice(1, i);
		let 值 = t.slice(i + 3);
		if (值.endsWith(",")) 值 = 值.slice(0, -1);
		if (值.endsWith('"')) 值 = 值.slice(0, -1);
		表.set(键, 值.replace(/\\n/g, "\n").replace(/\\r/g, "\r").replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16))).replace(/\\"/g, '"').replace(/\\'/g, "'"));
	}
	return 表;
}

const 色 = (n) => "#" + (n >>> 0).toString(16).padStart(6, "0").slice(-6);

/** 读 SWF 文件头的帧率（FWS/CWS/ZWS 头的前 8 字节格式一致，Rect 之后就是 frameRate）。 */
function 读帧率(swf路径) {
	const b = fs.readFileSync(swf路径).subarray(0, 24);
	if (b.length < 24) throw new Error(`SWF 头太短：${swf路径}`);
	const n = b[8] >> 4;
	const off = 9 + Math.ceil((4 + 4 * n) / 8);
	return b.readUInt16LE(off) / 256;
}

// ── 1. 品质表 ────────────────────────────────────────────────────────────
// 名字色有两套，**都是真的**：提示框（EqpData.APTITUDE_COLORS）和别处
// （EquipAptitudeType.EquipColors）只有紫色那档不一样（#ba01f9 vs #9102ff）。
const 提示框色 = {
	旧: 抓整数数组(读(旧根, "com/mxw/common/data/items/EqpData.as"), "APTITUDE_COLORS"),
	新: 抓整数数组(读(新根, "com/mxw/common/data/items/EqpData.as"), "APTITUDE_COLORS"),
};
const 通用色 = {
	旧: 抓整数数组(读(旧根, "com/mxw/data/enums/EquipAptitudeType.as"), "EquipColors"),
	新: 抓整数数组(读(新根, "com/mxw/data/enums/EquipAptitudeType.as"), "EquipColors"),
};
const 常量 = 抓常量(读(新根, "com/mxw/data/item/CocoEquip.as"), "APTITUDE_");

// 边框类名 ↔ 实际颜色是**交叉**的（`ItemWindowCell.showIcon` :239-252、
// `MToolTipZhuangBei.createEqpTipSprite` :158-168、新版的 `EquipAptitudeUtil.createAptitudeIcon`）：
//   常量 BLUE(2) → 类 EquipAptitudeGreenF、常量 GREEN(3) → 类 EquipAptitudeBlueF。
// 所以表里的「名」按 AS3 常量名（协议/日志里是这套），「框」「名字色」按实测颜色，
// 素材文件名也按实测颜色 —— 别再拿类名当颜色。
const 框类 = {
	2: "EquipAptitudeGreenF",
	3: "EquipAptitudeBlueF",
	4: "EquipAptitudePurpleF",
	5: "UISwf_EquipAptitudeIcon_EquipAptitudeOrangeF",
	6: "神话＝橙框裁彩虹渐变（新版专有）",
};
const 框素材 = {
	2: "res://素材/界面/装备品质/资质框_绿.png",
	3: "res://素材/界面/装备品质/资质框_蓝.png",
	4: "res://素材/界面/装备品质/资质框_紫.png",
	5: "res://素材/界面/装备品质/资质框_橙.png",
	6: "res://素材/界面/装备品质/资质框_神话.png",
};
// 颜色名给人看，值取自上面两套数组的实测十六进制，不是猜的。
const 颜色名 = { 1: "白", 2: "绿", 3: "蓝", 4: "紫", 5: "橙", 6: "金" };

const 品质 = {};
for (const [名, 值] of Object.entries(常量)) {
	const 档 = 值;
	品质[String(档)] = {
		名: 名.replace("APTITUDE_", "").toLowerCase(),
		颜色名: 颜色名[档] ?? null,
		名字色: 色(提示框色.新[档] ?? 提示框色.旧[档] ?? 0),
		名字色_别处: 色(通用色.新[档] ?? 通用色.旧[档] ?? 0),
		边框类: 框类[档] ?? "",
		边框: 框素材[档] ?? "",
		// 流光只给紫、橙两档（`ItemWindowCell.as:259` / `EquipmentWindowCell.as:138`：
		// `aptitude == PURPLE || aptitude == ORANGE`）。
		// ⚠️ 神话(6) **不用同一套流光**：新版 `EquipAptitudeUtil.createEquipAnimationByItem`
		// 只对 `isMythRainbowItem` 的灵花装给另一个符号 `ZBLingHuaBreathGlowF`，2.2.3 版根本没有 6 档。
		有流光: 档 === 4 || 档 === 5,
		仅新版: 档 >= 6,
	};
}

const 品质表 = {
	说明: "装备资质（品质）。下标是协议里的 aptitude 原值；1(白) 与 0 原版不画框。",
	出处: {
		常量: "com/mxw/data/item/CocoEquip.as",
		名字色: "com/mxw/common/data/items/EqpData.as APTITUDE_COLORS",
		名字色_别处: "com/mxw/data/enums/EquipAptitudeType.as EquipColors",
		边框与流光: "com/mxw/uifl/controls/cell/ItemWindowCell.as:237-267（装备格同 :118-143，提示框 MToolTipZhuangBei.as:155-182）",
	},
	最大档: Math.max(...Object.values(常量)),
	品质,
	// 灵气（十拳剑，id 前缀 20）不看 aptitude，恒定粉框 + 流光。
	// 出处 `ItemWindowCell.addLingQiitemAnima` :169-188。
	灵气: {
		边框类: "EquipAptitudePinkF",
		边框: "res://素材/界面/装备品质/资质框_灵气.png",
		有流光: true,
	},
	// 实测尺寸：五张框都是 42×42，且贴图铺满画布（alpha 包围盒 = 0,0,42,42），注册点就是环的左上角。
	边框尺寸: [42, 42],
	// 偏移两套：格子里加在**格子**上（左上角外扩 1px），提示框里加在**图标**上（外扩 3px）。
	// 两处差 4px，正好等于格子里图标相对格子左上角的位置 (3,3) —— 同一套素材、同一个注册点。
	边框偏移: { 格子: [-1, -1], 提示框: [-3, -3] },
	// 流光 ffdec 原始导出是 117×115，但 49 帧的**可见像素全在中间 35×35**（alpha 包围盒
	// (41,39)-(75,73)），四周是 DefineSprite 粗包围盒留下的空边（多半是蒙版/滤镜的外扩）。
	// 库里已按包围盒把 49 帧统一裁成 35×35，未裁的原始导出留在
	// `../原版源数据/素材原始导出备份/装备品质流光_117x115/`（重导素材时直接覆盖回来即可）。
	// 裁完之后**注册点正好是裁后画布的左上角**，原版那两组偏移就能照抄：
	// `KeyboardCell.setDefaultSkill :163` 的 `width == 40 ? 3 : (width - 34) >> 1` 就是
	// 34×34 图标在 40×40 底板里的左上角（同 `ItemWindowCell.drawIcon :404` 的居中公式），
	// 也就是说格子把流光放在**图标左上角**，35×35 的环正好套住 34×34 的图标（四周各出 0.5px）。
	// 提示框给 (1,1) 是原版自己的口径：那里环比图标内收 1px，和框的 -3 依然差 4px。
	流光: {
		目录: "res://素材/界面/装备品质/流光/",
		// ffdec 把 DefineSprite 115 的 65 帧全导出来了，但时间轴在第 49 帧就跳回 17，
		// 50..65 原版永远到不了（那几帧最大 alpha 只有 2~22，几乎全透），所以库里只留 1..49。
		帧数: 49,
		尺寸: [35, 35],
		// 裁切前的原始画布与内容包围盒，留着好让人复核这一步（也是重导素材时的裁剪依据）。
		原始画布: [117, 115],
		原始内容框: [41, 39, 76, 74],
		// `EquipAnimationF.addFrameScript(48, frame49)` → 第 49 帧跳回第 17 帧，
		// 所以 1..16 是进场，17..49 是循环段。
		循环起始帧: 17,
		循环结束帧: 49,
		// ⚠️ 2026-10-01 更正：播放速度**不是**文件头帧率。Flash 里库符号被 add 进舞台后，
		//    时间轴按**舞台帧率**逐 tick 推进，游戏把舞台钉死在 60
		//    （`Engine.as:13` `STAGE_FRAME_RATE = 60`、`World.as:226` `stage.frameRate = 60`）。
		//    原来记成头帧率 14 ⇒ 我们按 14fps 放 60fps 素材：一圈 2.4 秒还带 judder
		//    （14 不整除 60，一帧摊 4.3 个 vsync tick）——用户报的"流转不流畅"就是这个。
		// 帧率 = 舞台 60（真值，见上面一段）。2026-10-01 插曲：实机看过 60 后试调过 40
		// （"稍微慢一点点"），当天用户拍板**回到 60，"暂定60,以后再说"**——
		// 要再试慢档就改这里（候选 30，整数分频；40 不整除 60 理论上有 1.5tick 摊派）。
		// 无论怎么调，都别调回 14——那不是播放速度，那是文件头。
		帧率: 60,
		头帧率参考: 读帧率(客户端SWF),
		偏移: { 格子: [3, 3], 提示框: [1, 1] },
	},
};

// ── 2. 属性名表 ──────────────────────────────────────────────────────────
const 工厂旧 = 读(旧根, "com/mxw/common/data/items/ItemFactory.as");
const 属性类型常量 = 抓常量(读(旧根, "com/mxw/data/attribute/SubAttrType.as"), "");
const 属性id = 抓符号数组(工厂旧, "SUB_ATTR_TYPES", 属性类型常量);
const 属性英文 = new RegExp("SUB_ATTR_TYPE_EN_NAMES:Array = \\[([^\\]]*)\\]").exec(工厂旧)[1]
	.split(",").map((s) => s.trim().replace(/^"|"$/g, ""));
// NAMES 里每一项是 CN.XXX 或 LangUtil.get("XXX")，两种写法都取键名去语言表查。
const 名字键 = new RegExp("SUB_ATTR_TYPE_NAMES:Array = \\[([^\\]]*)\\]").exec(工厂旧)[1]
	.split(",").map((s) => {
		const t = s.trim();
		const g = /LangUtil\.get\("([^"]+)"\)/.exec(t) || /CN\.([A-Z0-9_]+)/.exec(t);
		return g ? g[1] : "";
	});
if (!(属性id.length === 属性英文.length && 属性id.length === 名字键.length)) {
	throw new Error(`三个数组长度不齐：${属性id.length}/${属性英文.length}/${名字键.length}`);
}
const 语言 = 读语言表(旧根);
const 属性 = {};
属性id.forEach((id, i) => {
	属性[String(id)] = { 中文: 语言.get(名字键[i]) ?? "", 英文: 属性英文[i], 键: 名字键[i] };
});
// `ANTI_SEAL_PET=24` 不在上面三个数组里，原版走单独一条「特殊属性」分支。
属性["24"] = { 中文: "", 英文: "anti_seal_pet", 键: "ITEMFACTORY_ANQI_SEAL_PET", 特殊: true };

const 属性表 = {
	说明: "属性类型 id → 显示名。id 就是协议里的 subAttrType/baseAttrType。",
	出处: "com/mxw/common/data/items/ItemFactory.as:30-34 + com/mxw/data/attribute/SubAttrType.as",
	百分比: [12, 13],
	属性,
};

// ── 3. 提示框文案 ────────────────────────────────────────────────────────
const 文案键 = [
	"MTOOTIP_ENDURE", "MTOOTIP_MAX_ENDURE", "MTOOTIP_BASS_ARRT", "MTOOTIP_PLUS_ARRT",
	"MTOOTIP_PLUS_ARRT_1", "MTOOTIP_SPECIAL_ARRT", "MTOOTIP_INLAY_ARRT",
	"MTOOTIP_ITEM_CHUANSHUO_SHUXING", "MTOOTIP_MANTIANSHENG", "MTOOTIP_TIANSHENG",
	"MTOOTIP_INNATENESS", "MTOOTIP_STRENGH", "MTOOTIP_STRENGH_LEVEL", "MTOOTIP_MANXING",
	"MTOOTIP_MANMENGHUAN_ZHI", "MTOOTIP_ZUIDA_KETISHENG_DEMENGHUANZHI", "MTOOTIP_ITEM_ZHUI",
	"MTOOTIP_ITEM_QIANCHUI_BAILIAN", "MTOOTIP_ITEM_E_WAI_JIAYIXING", "MTOOTIP_IS_STATE_POSUI",
	"MTOOTIP_USE_CASHSHOP", "MTOOTIP_USE_DUAN_ZAO_ZHI_CHUI", "MTOOTIP_USE_XUIFU_POSUI",
	"MTOOTIP_NOT_CANTRADE", "MTOOTIP_CANTRADE", "MTOOTIP_EXPIRATION", "MTOOTIP_LEVEL",
	"MTOOTIP_REPLEVEL", "MTOOTIP_SALE_TOTAL_PRICE", "MTOOTIP_BUY_TOTAL_PRICE",
	"MTOOL_MIYIN_SHUXING", "MTOOL_ZUIDA", "MTOOL_TIPITEM_CENG", "EQUIPMENT_ALREADY",
	"ITEMFACTORY_ANQI_SEAL_PET",
];
const 部位键 = ["EQUIPMENT_EQUIP_A", "EQUIPMENT_EQUIP_B", "EQUIPMENT_EQUIP_C", "EQUIPMENT_EQUIP_D",
	"EQUIPMENT_EQUIP_E", "EQUIPMENT_EQUIP_F", "EQUIPMENT_EQUIP_G", "EQUIPMENT_EQUIP_H",
	"EQUIPMENT_EQUIP_I", "EQUIPMENT_EQUIP_J", "EQUIPMENT_EQUIP_K", "EQUIPMENT_EQUIP_L",
	"EQUIPMENT_EQUIP_SZ", "EQUIPMENT_EQUIP_S1", "EQUIPMENT_EQUIP_HZ", "EQUIPMENT_EQUIP_HJ",
	"EQUIPMENT_EQUIP_LINGQI", "KUNCHONG_FENLEI",
	"PET_EQUIP_STRS_1", "PET_EQUIP_STRS_2", "PET_EQUIP_STRS_3", "PET_EQUIP_STRS_4", "PET_EQUIP_STRS_5"];
const 缺 = [];
const 取 = (k) => { const v = 语言.get(k); if (v === undefined) 缺.push(k); return v ?? ""; };
const 文案表 = {
	说明: "装备提示框文案 + 部位显示名。**逐字**取自原版语言表，含里面带的 <font>/<br/> 标记。",
	出处: "en_US$message_properties.as（经 com/mxw/common/gameCommon/language/CN.as 转发）",
	文案: Object.fromEntries(文案键.map((k) => [k, 取(k)])),
	部位: Object.fromEntries(部位键.map((k) => [k, 取(k)])),
};

fs.mkdirSync(输出目录, { recursive: true });
const 写 = (名, obj) => {
	fs.writeFileSync(path.join(输出目录, 名), JSON.stringify(obj, null, 1) + "\n", "utf8");
	console.log(`写出 数据/${名}`);
};
写("装备品质.json", 品质表);
写("装备属性名.json", 属性表);
写("装备文案.json", 文案表);
console.log(`品质 ${Object.keys(品质).length} 档，属性 ${Object.keys(属性).length} 条，文案 ${文案键.length}+${部位键.length} 条`
	+ (缺.length ? `，语言表缺键：${缺.join(",")}` : ""));
