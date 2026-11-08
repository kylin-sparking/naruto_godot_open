#!/usr/bin/env node
// 导出「装备库」—— 每件装备一行的合并表，把散在四处的装备真值拼到一起。
//
// 为什么要拼（2026-09-26）：同一件装备的信息原来分在四个地方，
// 谁要用装备都得自己 join 一遍，join 错一处就静默显示错数值：
//   1. 原版 GameData.dat 的 ZhuangBei 段  → face(外观)/mlsource/price/reqJob/reqLevel/next/stage/timeLimit/addAttr
//   2. 数据/物品.json                     → 名字、描述、图标引用（通用物品字段，**这里不重复存**）
//   3. 数据/物品装备元数据.json            → type_name(EquipA..L)/base_attr_*/max_endure/position
//   4. 原版各奖励表（礼包/宝箱/任务/特殊物品）→ 这件装备被发出来时**固定是什么品质**
// 本表只存**装备专有**字段；名字/图标一律回 物品.json 查，免得两处各存一份再对不上。
//
// 品质这一列要看清：原版 ZhuangBei 段**没有** aptitude 字段（632 行一个都没有），
// 品质是实例数据 —— 服务端发装备时才带上。表里能拿到的只有「哪个来源把这件装备发成什么品质」，
// 所以叫「品质来源」，573 件里只有几十件查得到，查不到就是空数组，**不要当默认值用**。
//
// 用法：node 开发工具/导出装备库.mjs

import fs from "node:fs";

const 源 = "../原版源数据/GameData.dat.json";
const 物品 = JSON.parse(fs.readFileSync("数据/物品.json", "utf8"));
const 元数据 = JSON.parse(fs.readFileSync("数据/物品装备元数据.json", "utf8")).物品;
const 装备基础 = JSON.parse(fs.readFileSync("数据/装备基础属性.json", "utf8"));
const 补 = fs.existsSync("数据_扩展/物品.json") ? JSON.parse(fs.readFileSync("数据_扩展/物品.json", "utf8")) : {};
const d = JSON.parse(fs.readFileSync(源, "utf8"));

const 八位 = (v) => String(v).padStart(8, "0");

/** `addAttr: "atk:666;def:222"` → {atk:666, def:222}。 */
function 解属性串(s) {
	const out = {};
	for (const 段 of String(s || "").split(";")) {
		const i = 段.indexOf(":");
		if (i <= 0) continue;
		const 值 = Number(段.slice(i + 1));
		out[段.slice(0, i)] = Number.isNaN(值) ? 段.slice(i + 1) : 值;
	}
	return out;
}

// ④ 品质来源：递归找 `{id, aptitude}` 成对出现的节点（奖励清单都是这个形状）。
const 品质来源 = new Map();
function 走(节点, 路径) {
	if (Array.isArray(节点)) {
		节点.forEach((v, i) => 走(v, `${路径}[${i}]`));
		return;
	}
	if (!节点 || typeof 节点 !== "object") return;
	if (节点.id !== undefined && typeof 节点.aptitude === "number") {
		const 键 = 八位(节点.id);
		if (!品质来源.has(键)) 品质来源.set(键, []);
		品质来源.get(键).push({
			来源: 路径.replace(/^\$\[?\d*\]?\.?/, "").split(/[./[]/)[0],
			品质: 节点.aptitude,
			星级: 节点.star ?? 0,
			数量: 节点.count ?? 1,
		});
		return;
	}
	for (const [k, v] of Object.entries(节点)) 走(v, `${路径}.${k}`);
}
for (const [段, 节点] of Object.entries(d)) if (段 !== "GameData") 走(节点, 段);

const 表 = {};
let 无元数据 = 0;
for (const [原始id, 记录] of Object.entries(d.ZhuangBei)) {
	const id = 八位(原始id);
	const info = 记录.info ?? 记录;
	const 元 = 元数据[id] ?? 元数据[原始id] ?? null;
	if (!元) 无元数据++;
	const 物 = 物品[id] ?? 物品[原始id] ?? 补[id] ?? null;
	表[id] = {
		类型: id.slice(0, 2) === "01" ? "玩家装备" : id.slice(0, 2) === "02" ? "宠物装备" : "其他",
		部位模板: 元 ? 元.type_name : "",
		面板位置: 元 ? 元.position : -1,
		阶: info.stage ?? (元 ? 元.stage : 0),
		基础属性类型: 元 ? 元.base_attr_type : -1,
		基础属性值: 元 ? 元.base_attr_value : 0,
		最大耐久: 元 ? 元.max_endure : 0,
		需求职业: info.reqJob ?? 0,
		需求等级: info.reqLevel ?? 0,
		进阶目标: info.next ? 八位(info.next) : "",
		外观: info.face ?? 0,
		时限: info.timeLimit ?? 0,
		材料来源: info.mlsource ?? 0,
		原价: info.price ?? 0,
		附加属性: 解属性串(info.addAttr),
		固定属性: 物 && 物.attributes ? 物.attributes : {},
		品质来源: 品质来源.get(id) ?? [],
	};
	if (info.canyingeff) 表[id].参悟效果 = info.canyingeff;
}

const 模板名 = Object.keys(装备基础.basic);
const 输出 = {
	说明: "装备库：每件装备一行的装备专有字段。名字/描述/图标查 数据/物品.json，"
		+ "每阶基础属性与梦幻值上限查 数据/装备基础属性.json（按 部位模板+阶 join）。",
	出处: {
		字段: "原版 GameData.dat 的 ZhuangBei 段（导出见 开发工具/导出原版源.py）",
		部位模板与耐久: "数据/物品装备元数据.json（Etp.Item 段）",
		品质来源: "原版各奖励表里 {id, aptitude, star} 成对项（礼包/宝箱/任务/特殊物品）",
	},
	部位模板: 模板名,
	统计: {
		装备数: Object.keys(表).length,
		有元数据: Object.keys(表).length - 无元数据,
		无元数据: 无元数据,
		有品质来源: Object.values(表).filter((r) => r.品质来源.length > 0).length,
	},
	装备: 表,
};

fs.writeFileSync("数据/装备库.json", JSON.stringify(输出, null, 1) + "\n", "utf8");
const s = 输出.统计;
console.log(`写出 数据/装备库.json：${s.装备数} 件（有元数据 ${s.有元数据}，缺 ${s.无元数据}），能查到固定品质的 ${s.有品质来源} 件`);
