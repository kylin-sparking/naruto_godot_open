// A1 交用户证据：音效清单对照表
// 用法：node 开发工具/音效对照表.mjs
// 将「原版客户端目录里的音频」与「Godot 素材/音效/ 里的成品」逐条对账，输出 markdown。
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const 工程 = path.resolve(import.meta.dirname, "..");
const 客户端根 = process.env.NARUTO_GAME_ROOT || path.join(工程, "..", "2.2.3");
const Web根 = path.join(客户端根, "www/act_web_nya_208_isolated");
const AS3根 = process.env.NARUTO_AS3_ROOT || path.join(客户端根, "map_extract/out/mainlib_as/scripts");
const 数据 = JSON.parse(fs.readFileSync(path.join(工程, "数据/音效.json"), "utf8"));
const BGM源目录 = path.join(Web根, "mp3");
const 音效库目录 = path.join(Web根, "swf/Sound");
const 分身源目录 = path.join(Web根, "audio");
const 出BGM = path.join(工程, "素材/音效/BGM");
const 出音效 = path.join(工程, "素材/音效");

const md5 = (p) => crypto.createHash("md5").update(fs.readFileSync(p)).digest("hex").slice(0, 8);
const kb = (p) => Math.round(fs.statSync(p).size / 1024);
const 有 = (p) => fs.existsSync(p);

// 地图对某首 BGM 的引用数：**直接读每张地图自己的 info.bgm**（原版 World.as:999 就是读这个），
// 不走 音效.json 里的第二真相源。按 原版 parseBGMChoices 的分隔符与 `名@权重` 拆开。
const 索引 = JSON.parse(fs.readFileSync(path.join(工程, "数据/地图索引.json"), "utf8"));
const 地图列表 = [];
{
	const 根 = path.join(工程, "数据/地图");
	for (const 目录 of fs.readdirSync(根).sort()) {
		const f = path.join(根, 目录, "地图.json");
		if (!有(f)) continue;
		const bgm = (JSON.parse(fs.readFileSync(f, "utf8")).info || {}).bgm;
		地图列表.push({ 目录, bgm: bgm === undefined || bgm === null ? "" : String(bgm) });
	}
}
const 引用数 = {};
for (const { bgm } of 地图列表) {
	const 池 = [];
	for (const 项 of bgm.split(/[,;|]/)) {
		const m = 项.trim().match(/^(.+?)@([1-9][0-9]*)$/);
		if (m) for (let i = 0; i < Number(m[2]); i++) 池.push(m[1]);
		else if (项.trim()) 池.push(项.trim());
	}
	for (const 名 of new Set(池)) 引用数[名] = (引用数[名] || 0) + 1;
}
const 索引名 = new Set(Object.values(索引).map(String));

const 行 = [];
const push = (s) => 行.push(s);

push("# A1 音频系统 · 音效清单对照表");
push("");
push(`- 原版客户端：\`${Web根}\``);
push(`- Godot 成品：\`${path.join(工程, "素材/音效")}\``);
push(`- 生成时间：${new Date().toLocaleString("zh-CN")}`);
push("");

// ---- 1) BGM ----
const 源BGM = fs.readdirSync(BGM源目录).filter((f) => f.toLowerCase().endsWith(".mp3")).sort();
const 转BGM = fs.readdirSync(出BGM).filter((f) => f.toLowerCase().endsWith(".mp3")).sort();
push(`## 1. BGM（原版 ${源BGM.length} 首 → 转出 ${转BGM.length} 首）`);
push("");
push("| 原版 `mp3/` | 原版大小 | Godot 成品 | 成品大小 | MD5 一致 | 被地图引用 |");
push("|---|---|---|---|---|---|");
let bgm齐 = 0, bgm异 = 0;
for (const f of 源BGM) {
	const 目 = path.join(出BGM, f);
	const 名 = f.replace(/\.mp3$/i, "");
	const 一致 = 有(目) && md5(path.join(BGM源目录, f)) === md5(目);
	if (有(目)) bgm齐++; else bgm异++;
	push(`| ${f} | ${kb(path.join(BGM源目录, f))} KB | ${有(目) ? f : "**缺失**"} | ${有(目) ? kb(目) + " KB" : "-"} | ${一致 ? "✓" : "✗"} | ${引用数[名] || 0} |`);
}
const 多出的 = 转BGM.filter((f) => !源BGM.includes(f));
push("");
push(`- 原版有、成品缺：**${bgm异} 首**${bgm异 === 0 ? "（全部转出）" : ""}`);
push(`- 成品里多出的（原版没有）：${多出的.length ? 多出的.join(", ") : "0 个"}`);
const 重复 = Object.entries(数据.BGM.内容重复 || {});
if (重复.length) push(`- 原版内容重复（MD5 相同，非移植引入）：${重复.map(([k, v]) => `${k}（${v} 份相同）`).join("；")}`);
const 没人用 = 源BGM.map((f) => f.replace(/\.mp3$/i, "")).filter((名) => !引用数[名]);
push(`- \`mp3/\` 里存在、但**没有任何地图声明**的编号：**${没人用.length} 首**（${没人用.slice(0, 6).join(", ")}${没人用.length > 6 ? " …" : ""}）—— 这是原版数据本身如此：\`World.as:999\` 只按每张图的 \`info.bgm\` 取曲，没声明的编号在 Flash 端也永远不播。素材仍按「原版有的不许少」全量转出。`);
push(`- 选曲规则出处：${数据.BGM.规则.选项}`);
push("");

// ---- 2) 音效 ----
const 源库 = fs.readdirSync(音效库目录).filter((f) => /^Sound_\w+\.swf$/i.test(f)).sort();
const 副本 = fs.readdirSync(音效库目录).filter((f) => !/^Sound_\w+\.swf$/i.test(f)).sort();
push(`## 2. 音效（原版 ${源库.length} 个 \`swf/Sound/Sound_*.swf\` → 转出 ${Object.keys(数据.音效.表).length} 条 mp3）`);
push("");
push("| 音效名 | 来源库 (swf) | 原版常量 | Godot 成品 | 成品大小 | 原版调用点（grep 1898 个 .as 得到） |");
push("|---|---|---|---|---|---|");
const 常量源 = fs.readFileSync(path.join(AS3根, "com/mxw/common/sound/SoundConstants.as"), "utf8");
// 原版调用点：在 1898 个 .as 里找 `SoundConstants.<常量>` 的引用（SoundConstants.as 自身除外），
// 以及四个 `Get*Sound` 分派函数的调用点（它们决定 22 条里的 12 条职业系音）。不手抄清单。
const 直调 = {};
const 分派调用 = {};
const 走 = (d) => {
	for (const e of fs.readdirSync(d, { withFileTypes: true })) {
		const p = path.join(d, e.name);
		if (e.isDirectory()) { 走(p); continue; }
		if (!e.name.endsWith(".as") || e.name === "SoundConstants.as") continue;
		const t = fs.readFileSync(p, "utf8");
		const 相 = path.relative(AS3根, p).replace(/\\/g, "/") + ":";
		for (const m of t.matchAll(/SoundConstants\.(SOUND_\w+)/g)) (直调[m[1]] ||= new Set()).add(相 + t.slice(0, m.index).split("\n").length);
		for (const m of t.matchAll(/SoundConstants\.(Get\w+Sound)\(/g)) (分派调用[m[1]] ||= new Set()).add(相 + t.slice(0, m.index).split("\n").length);
	}
};
走(AS3根);
const 常量名 = Object.fromEntries(Object.entries(数据.音效.表).map(([n, 项]) => [n, 项.常量]));
const 调用点 = (名) => {
	const 直 = [...(直调[常量名[名]] || [])].slice(0, 2);
	if (直.length) return 直.join("、");
	const 分派 = Object.entries(数据.音效.按职业).find(([, 表]) => Object.values(表).includes(名));
	if (!分派) return "**原版无调用点**";
	const 站 = [...(分派调用[分派[0]] || [])].slice(0, 2);
	return 站.length ? `${站.join("、")} → ${分派[0]}(playerJob)` : `**${分派[0]} 本身无调用点**`;
};
let 音齐 = 0;
for (const [名, 项] of Object.entries(数据.音效.表)) {
	const 目 = path.join(工程, 项.文件.replace("res://", ""));
	if (有(目)) 音齐++;
	push(`| ${名} | ${项.库文件} | ${项.常量} | ${有(目) ? path.basename(目) : "**缺失**"} | ${有(目) ? kb(目) + " KB" : "-"} | ${调用点(名)} |`);
}
const 有调用 = Object.keys(数据.音效.表).filter((n) => !调用点(n).includes("**")).length;
push("");
push(`- 原版 ${源库.length} 个库共解出 ${Object.keys(数据.音效.表).length} 条，成品存在 ${音齐} 条。`);
push(`- 每条的「原版常量」都能在 \`SoundConstants.as\` 里找到：${Object.values(数据.音效.表).every((项) => 常量源.includes(项.常量)) ? "是" : "否"}`);
if (副本.length) push(`- 目录里另有的非 \`Sound_*.swf\` 文件（重复副本，未参与导出）：${副本.join(", ")}`);
push(`- 原版有调用点 **${有调用}** 条 / 无调用点 **${Object.keys(数据.音效.表).length - 有调用}** 条（\`Select_*\` 四条 + \`MesoPickup\`，本次在 1898 个 .as 里逐条 grep 复核：它们只出现在 \`SoundConstants.as\` 的常量声明里，\`GetSelectSound\` 也只有定义没人调）。无调用点的照样转出、不接调用 = 与原版行为一致。`);
push(`- **Godot 端当前 \`play_effect\`/\`play_job_effect\` 调用点为 0 处**（\`grep -rn play_effect 脚本/\` 只剩三条注释，是 2026-09-26 删自造音时留下的）。原版那 ${有调用} 条的触发点全在 角色/怪物/技能效果/KeyController 里 —— 属战斗与技能模块的接线活，不在 A1 范围，本模块只交付「素材 + 播放器 + 按地图 BGM 自动播」。`);
push(`- 职业系分派真值：${数据.音效.职业系真值}`);
push("");

// ---- 3) 影分身 ----
const 源分身 = fs.readdirSync(分身源目录).filter((f) => f.toLowerCase().endsWith(".mp3")).sort();
push(`## 3. 影分身音效（原版 \`audio/\` ${源分身.length} 首）`);
push("");
push("| 原版 `audio/` | 原版大小 | Godot 成品 | MD5 一致 | 出处 |");
push("|---|---|---|---|---|");
for (const f of 源分身) {
	const 目 = path.join(出音效, f);
	push(`| ${f} | ${kb(path.join(分身源目录, f))} KB | ${有(目) ? f : "**缺失**"} | ${有(目) && md5(path.join(分身源目录, f)) === md5(目) ? "✓" : "✗"} | ${数据.影分身.出处} |`);
}
push("");

// ---- 4) 地图选曲覆盖 ----
const 图数 = 地图列表.length;
const 空值 = 地图列表.filter((m) => !m.bgm.trim());
const 未命中 = 地图列表.filter((m) =>
	m.bgm.split(/[,;|]/).map((s) => s.trim().split("@")[0]).filter(Boolean)
		.some((名) => 名 !== "default" && !源BGM.includes(`${名}.mp3`)));
const 不在索引 = 地图列表.filter((m) => !索引名.has(m.目录));
const 不在目录 = [...索引名].filter((n) => !地图列表.some((m) => m.目录 === n));
const 未命中目录 = 未命中.map((m) => `${m.目录}=${m.bgm}`);
const 列表 = (a, n = 12) => a.slice(0, n).join(", ") + (a.length > n ? ` …共 ${a.length} 个` : "");
push(`## 4. 按地图选曲覆盖`);
push("");
push(`- 真值来源：\`数据/地图/<图名>/地图.json\` 的 \`info.bgm\`，与原版 \`World.as:999\` 同源，不经 \`数据/音效.json\``);
push(`- 有 \`地图.json\` 的地图目录 **${图数}** 个；\`数据/地图索引.json\` **${Object.keys(索引).length}** 张（去重名 ${索引名.size}）`);
push(`- 目录有、索引里没有：**${不在索引.length}** 个 → ${列表(不在索引.map((m) => m.目录))}（属 A3 地图数据缺口，与音频无关）`);
push(`- 索引有、目录里没有：**${不在目录.length}** 个${不在目录.length ? " → " + 列表(不在目录) : ""}`);
push(`- 原版没写 bgm → 运行时回落 \`default.mp3\`：**${空值.length}** 张${空值.length ? " → " + 列表(空值.map((m) => m.目录)) : ""}`);
push(`- 候选名在 \`mp3/\` 里找不到的：**${未命中.length}** 张${未命中.length ? " → " + 列表(未命中目录) : ""}`);
push(`- 原版 info.bgm 取值分布：${JSON.stringify(数据.BGM.地图核对.分布)}`);
push(`- 淡切 / 防重复 / 播完重选：${数据.BGM.规则.淡切} ｜ ${数据.BGM.规则.防重复} ｜ ${数据.BGM.规则.播完}`);

// ---- 5) 与模块自检清单的出入（不粉饰）----
push(`## 5. 与 \`移植模块清单.md\` A1 自检清单的出入`);
push("");
push(`- 清单第 ③ 条写的是「**攻击 / 受击 / 传送门** 三类音效实机可听」，但原版**没有这三个东西**：`);
push(`  - \`SoundConstants.as\` 22 个常量里没有 Attack/Hit/Portal 任何一个（上面 1898 个 .as 全量 grep 为空）；`);
push(`  - 原版有声音、且真有调用点的对应物是 \`Sound_Mai_*\`（出脉）、\`Sound_BaoJi_*\`（暴击）、\`Sound_Dead_*\`（死亡）、\`Sound_Pouf\`（怪物出场/攻击烟雾）、\`Sound_Movement_Jump/Land\`（跳/落地）、\`Sound_ShouLiJian\`（手里剑技能）、\`Sound_CommonSkill_Flash\`（位移技）—— 共 17 条，逐条调用点见上表第 2 节最后一列。`);
push(`  → 本表按**原版的 22 条**逐条录音验峰，不按清单那句写死的三个名字。`);
push(`- 清单第 ④ 条「设置里的音量开关生效」已验：静音时 BGM 落到 -80 dB、静音对照段峰值 1（满量程 32767）。见 \`测试/输出/A1自检原始输出.txt\` 第 ④ 行。`);
push(`- 接线时的两个原版坑（真值已取，别踩）：`);
push(`  1. 出脉与死亡两音原版都有门槛 —— \`Character.as:320\`（出脉）与 \`Character.as:763\`（死亡）都包在 \`if (!API.dataCenter.nowEquipShiZhuang)\` 里：**穿着时装时这两声不播**。`);
push(`  2. 职业系是**精确匹配** 100/200/300/400，土遁 500 与 110+ 转职细分一律 \`null\` = 不播（\`SoundConstants.as\` 四个 switch）；不要"找不到就播火的"。`);
push("");

fs.writeFileSync(path.join(工程, "测试/输出/音效清单对照表.md"), 行.join("\n") + "\n", "utf8");
console.log(`已写出 测试/输出/音效清单对照表.md`);
console.log(`BGM 原版 ${源BGM.length} / 成品齐 ${bgm齐} / 缺 ${bgm异} ｜ 音效 ${Object.keys(数据.音效.表).length} 条 成品齐 ${音齐} ｜ 分身 ${源分身.length} ｜ 地图 ${图数} 未命中 ${未命中.length}`);
