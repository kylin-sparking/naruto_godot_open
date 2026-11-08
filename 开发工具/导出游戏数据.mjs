import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const 脚本目录 = path.dirname(fileURLToPath(import.meta.url));
const 项目目录 = path.resolve(脚本目录, "..");
const 参数 = Object.fromEntries(process.argv.slice(2).map((value) => {
  const [key, ...rest] = value.replace(/^--/, "").split("=");
  return [key, rest.join("=")];
}));
const 默认数据源 = path.join(
  项目目录,
  "..",
  "NarutoWorld_Server_202607222145-master",
  "NarutoWorld_Server_202607222145-master",
  "data",
  "GameData.dat.json",
);
const 数据源 = path.resolve(参数.source || [
  path.join(项目目录, "..", "原版源数据", "GameData.dat.json"),
  默认数据源,
].find((文件) => fs.existsSync(文件)) || 默认数据源);
const 美术候选 = [
  process.env.NARUTO_ART_ROOT,
  path.join(项目目录, "..", "完整美术资源"),
  path.join(项目目录, "..", "..", "code", "火影世界服务端", "完整美术资源", "完整美术资源"),
].filter(Boolean);
const 美术源 = path.resolve(参数.assets || 美术候选.find((目录) => fs.existsSync(path.join(目录, "Tile"))) || 美术候选[0]);
// A3 起，`素材/原版直解/<分类>` 也是地图素材的来源之一（补齐原版素材.mjs 从原版 swf 现解）。
const 补充美术源列表 = [
  path.resolve(参数.extracted || path.join(项目目录, "..", "..", "code", "火影世界服务端", "swf-extracted-assets", "textures")),
  path.join(项目目录, "素材", "原版直解"),
];
const 只导出数据 = 参数["data-only"] === "true";

if (!fs.existsSync(数据源)) {
  throw new Error(`GameData 不存在：${数据源}\n请使用 --source=绝对路径 指定原版 data/GameData.dat.json`);
}

const 原始数据 = JSON.parse(fs.readFileSync(数据源, "utf8").replace(/^\uFEFF/, ""));
const 输出根目录 = path.join(项目目录, "数据");
fs.mkdirSync(输出根目录, { recursive: true });

const 写入JSON = (文件名, 内容) => {
  const 目标 = path.join(输出根目录, 文件名);
  fs.mkdirSync(path.dirname(目标), { recursive: true });
  fs.writeFileSync(目标, JSON.stringify(内容));
};

const 字符串表 = 原始数据.String || {};
const 取文本 = (分类, 编号) => {
  const 分类文本 = 字符串表[分类] || {};
  const 原始编号 = String(编号);
  const 数字编号 = /^\d+$/.test(原始编号) ? String(Number(原始编号)) : 原始编号;
  return 分类文本[原始编号] || 分类文本[数字编号] || {};
};
const 取名称 = (分类, 编号, 兜底 = "") => {
  const 文本 = 取文本(分类, 编号);
  return String(文本.name || 文本.mapName || 文本.desc || 兜底);
};

const 怪物 = {};
for (const [编号, 原型] of Object.entries(原始数据.Mob || {})) {
  const 信息 = 原型.info || {};
  怪物[编号] = {
    id: 编号,
    name: 取名称("Mob", 编号, 编号),
    level: Number(信息.level || 1),
    max_hp: Number(信息.maxHP || 1),
    max_mp: Number(信息.maxMP || 0),
    attack: Number(信息.atk || 0),
    defense: Number(信息.def || 0),
    critical: Number(信息.bsk || 0),
    avoidance: Number(信息.eva || 0),
    exp: Number(信息.exp || 0),
    speed: Number(信息.speed || 0),
    move_range: Number(信息.area || 0),
    first_attack: Number(信息.firstAttack || 0) !== 0,
    // ↓ 2026-10-01 补：怪物 AI（`com/mxw/roles/ai/`）要用的那几个字段。原先只导了
    //   `area`（= move_range）与 `firstAttack`，于是离线怪的巡逻/追击只能拿写死的 ±130 硬顶。
    //   字段名与语义照 AS3：`MobInfo.as` 的声明 + `MonsterParameter`/`AIParameter`/`FreeExecute`
    //   的读法（`area*100` 才是像素半径；`walkRate` 在 `MobInfo.getFromMobData()` 里
    //   为 0 时**兜底成 5**，这里照做，免得消费方各自再兜一次）。
    area_chase: Number(信息.areaChase || 0),
    area_y: Number(信息.areaY || 0),
    area_chase_y: Number(信息.areaChaseY || 0),
    walk_rate: Number(信息.walkRate || 0) || 5,
    can_jump: Number(信息.canJump || 0) !== 0,
    boss: Number(信息.boss || 0),
    ai: Number(信息.ai || 0),
    skill: 信息.skill || {},
    common_attack: String(信息.commonAttack || ""),
    link: String(信息.link || ""),
    // 固定伤害（`fixDamage`）：非 0 时这只怪打人的伤害**就是这个数**，不走公式
    // （服务端 `_apply_server_monster_damage()` 里 `elif definition.fixed_damage > 0` 那一支）。
    fix_damage: Number(信息.fixDamage || 0),
  };
}

const NPC = {};
for (const 编号 of new Set([...Object.keys(原始数据.Npc || {}), ...Object.keys(字符串表.Npc || {})])) {
  const 文本 = 取文本("Npc", 编号);
  NPC[编号] = {
    id: 编号,
    name: String(文本.name || 编号),
    title: String(文本.func || ""),
    dialogue: String(文本.n0 || 文本.d0 || ""),
    service: String(文本.scriptName || ""),
  };
}

const 物品分类 = {
  ZhuangBei: "装备", XiaoHao: "消耗品", JiNengShu: "技能书", JiNengCanJuan: "技能残卷",
  FuZhuWuPin: "辅助物品", BuffWuPin: "增益物品", BaoShi: "宝石", LingQi: "灵器",
  CaiLiao: "材料", RenWuWuPin: "任务物品", TeShuWuPin: "特殊物品", LiBao: "礼包",
  HunJie: "魂戒", ShenQi: "神器", Pet: "宠物", Spirit: "意志",
};

/**
 * 原版 `addAttr` 是 `"atk:300;def:100;bsk:60"` 这种串。拆成 `{atk:300, def:100}` 是为了
 * 让提示框按原版的**插入顺序**渲染（Object 保序），同时 UI 不用每帧重解字符串。
 */
const 解析属性 = (原始) => {
  const 结果 = {};
  for (const 对 of String(原始 || "").split(";")) {
    const [键, 值] = 对.split(":");
    if (!键 || 值 === undefined) continue;
    const 数 = Number(值);
    结果[键.trim()] = Number.isFinite(数) ? 数 : 值.trim();
  }
  return 结果;
};

const 物品 = {};
const 礼包奖励 = {};
for (const [分类, 中文分类] of Object.entries(物品分类).sort(([左], [右]) => 左.localeCompare(右))) {
  for (const [编号, 原型] of Object.entries(原始数据[分类] || {})) {
    if (!/^\d+$/.test(编号)) continue;
    const 信息 = 原型.info || {};
    const 图标 = 信息.icon?.value || {};
    const 文本 = 取文本(分类, 编号);
    // 90000000..90000003 仅是原版 getMesoPic() 使用的地面货币外观，
    // 没有 info 或文字定义，不属于背包物品模板。
    if (Object.keys(信息).length === 0 && Object.keys(文本).length === 0) continue;
    const 定义 = {
      id: 编号,
      name: String(文本.name || 信息.name || 原型.name || 编号),
      description: String(文本.desc || 文本.info || ""),
      category: 中文分类,
      source_category: 分类,
      price: Number(信息.price || 0),
      required_level: Number(信息.reqLevel || 0),
      stack_max: Number(信息.slotMax || 1),
      icon_class: String(图标.className || ""),
      icon_swf: String(图标.swfName || ""),
    };
    // 提示框要用的原版字段，**只在有值时才写**，免得 2699 条里塞一堆 0 把表撑肥。
    // `attributes` 是原版 `addAttr`。⚠️ 它**不是**提示框上那些攻防数值的来源：装备基础值走
    // `Etc.EquipSystem.basic[类型][stageN]`（见 装备基础属性.json）+ 服务端下发的实例属性
    // (`CocoEquip`)，`addAttr` 原版只用于徽章/灵石进阶预览（`ItemFactory.as:745-792`）。
    // 原版 `getArrrTypeIndex` 只认 atk/def/maxhp/avd、其余落到 MONEY 是个 bug，这里不照抄、原样保留。
    // `mlsource`/`face` 客户端零引用，故意不导。
    if (文本.detaildesc) 定义.detail_description = String(文本.detaildesc);
    if (信息.addAttr) 定义.attributes = 解析属性(信息.addAttr);
    if (Number(信息.reqJob)) 定义.required_job = Number(信息.reqJob);
    if (Number(信息.next)) 定义.next_id = String(信息.next);
    if (Number(信息.stage)) 定义.stage = Number(信息.stage);
    if (Number(信息.timeLimit)) 定义.time_limit = Number(信息.timeLimit);
    物品[编号] = 定义;
    // 礼包的奖励表一条就有 1~3 KB，全塞进 物品.json 会把启动时要解析的主表撑到几 MB，
    // 所以单拆一张 礼包奖励.json，只有开礼包界面时才读。
    if (分类 === "LiBao" && 原型.spec?.params) {
      const 参数 = 原型.spec.params;
      const 钱 = 参数.money || {};
      const 按职业 = {};
      for (const [职业号, 组] of Object.entries(参数.items || {})) {
        // 外层键 = **职业号**（0 通用，100/200/300/400/500…见 CocoJob）；界面只取 `0` + 自己职业两组
        // 顺序拼接（`ChoiceLibaoWindow.as:206-230`）。内层键 = 槽位序号，所以拆成数组。
        按职业[职业号] = Object.entries(组 || {})
          .sort((左, 右) => Number(左[0]) - Number(右[0]))
          .map(([, 项], 序号) => ({
            slot: 序号,
            item_id: String(项.id ?? ""),
            count: Number(项.count ?? 1),
            bind: Number(项.bind ?? 0),
            star: Number(项.star ?? 0),
            aptitude: Number(项.aptitude ?? 0),
          }));
      }
      礼包奖励[编号] = {
        // 名字按原版语义写死，别留 cash/point 这种会读反的键（`SelectGiftWindow.as:153-233`）：
        // cash=元宝、point=金币、cashbind=绑定元宝、itemid=要扣的道具（客户端从不读）。
        cost: {
          yuanbao: Number(钱.cash || 0),
          gold: Number(钱.point || 0),
          bound_yuanbao: Number(钱.cashbind || 0),
          cost_item_id: String(钱.itemid || ""),
        },
        broadcast: String(参数.pubstr || ""),
        rewards_by_job: 按职业,
      };
    }
  }
}

const 技能 = {};
for (const [职业组, 组数据] of Object.entries(原始数据.Skill || {})) {
  for (const [编号, 原型] of Object.entries(组数据.skill || {})) {
    const 信息 = 原型.info || {};
    const 描述 = 信息.desc || {};
    const 攻击 = 信息.type_attack?.effect || {};
    const 消耗 = 信息.consume || {};
    const 冷却 = 信息.cool_down || {};
    const 图标 = 原型.icon?.value || {};
    技能[编号] = {
      id: 编号,
      job_group: 职业组,
      name: String(描述.name || 描述.desc || 取名称("Skill", 编号, 编号)),
      description: String(描述.skillDesc || 描述.desc || ""),
      range: Number(描述.range || 0),
      target: Number(描述.target || 0),
      skill_type: Number(描述.skillType || 0),
      damage: Number(攻击.valueBase || 攻击.damageBase || 0),
      damage_growth: Number(攻击.valueLevel || 攻击.damageLevel || 0),
      mp_cost: Number(消耗.mpBase || 消耗.mp || 消耗["1"] || 0),
      cooldown: Number(冷却.cdBase || 冷却.cd || 1.12),
      icon_class: String(图标.className || ""),
      icon_swf: String(图标.swfName || ""),
    };
  }
}

const 地图名 = {};
const 地图源 = {};
for (const 分类 of ["Map1", "Map4", "Map5"]) {
  for (const [编号, 地图] of Object.entries(原始数据[分类] || {})) {
    地图名[编号] = 取名称("Map", 编号);
    地图源[编号] = 地图;
  }
}

const 地图视觉签名 = (地图) => {
  const 内容 = { back: 地图.back || {}, layers: {} };
  for (const [层号, 层] of Object.entries(地图)) {
    if (!/^\d+$/.test(层号)) continue;
    内容.layers[层号] = { info: 层.info || {}, tile: 层.tile || {}, obj: 层.obj || {} };
  }
  return JSON.stringify(内容);
};
const 地图原型编号 = {};
for (const 编号 of Object.keys(地图源).sort()) {
  if (地图名[编号] || !编号.endsWith("001")) continue;
  const 原型编号 = String(Number(编号) - 1);
  if (!地图源[原型编号] || !地图名[原型编号]) continue;
  if (地图视觉签名(地图源[编号]) !== 地图视觉签名(地图源[原型编号])) continue;
  地图原型编号[编号] = 原型编号;
  地图名[编号] = 地图名[原型编号];
}
for (const 编号 of Object.keys(地图源)) {
  if (!地图名[编号]) 地图名[编号] = 编号;
}

/**
 * 导出的源是**原版**数据，而现有表里可能已经有服务端/本机自己加的行
 * （例：怪 2200027【修罗道】只存在于服务端包，原版 `Mob` 段里没有，但 `String.Mob` 里有名字）。
 * 直接重写主表会把它们静默删掉，所以先搬到 `数据_扩展/`——那边 `游戏数据.gd` 会合并并覆盖主表。
 */
const 保留原有行 = (文件名, 新表) => {
  const 主表路径 = path.join(输出根目录, 文件名);
  if (!fs.existsSync(主表路径)) return;
  const 读 = (路径) => JSON.parse(fs.readFileSync(路径, "utf8").replace(/^﻿/, ""));
  const 旧表 = 读(主表路径);
  const 扩展路径 = path.join(项目目录, "数据_扩展", 文件名);
  const 扩展 = fs.existsSync(扩展路径) ? 读(扩展路径) : {};
  let 搬移 = 0;
  for (const [编号, 定义] of Object.entries(旧表)) {
    if (编号 in 新表 || 编号 in 扩展) continue;
    扩展[编号] = 定义;
    搬移++;
  }
  if (!搬移) return;
  fs.mkdirSync(path.dirname(扩展路径), { recursive: true });
  fs.writeFileSync(扩展路径, JSON.stringify(扩展));
  console.log(`原版没有的行已保留到 数据_扩展/${文件名}：${搬移} 条`);
};

/**
 * 原版 GameData 里还有一批分区，**过去没有任何脚本读它们**，所以对应窗口只能吃
 * `离线示例数据.gd` 或脚本里写死的占位值（任务/成就/活动/经脉/师徒/VIP/公告/增益状态/宝箱）。
 *
 * 字段名**照原版**（口径同 `装备打造.json`）：翻译过的键名是我对 AS3 的二次猜测，
 * 出问题最难查；原版键至少能 grep 回源码。
 *
 * 故意没导的分区：`M_Char`(118 条角色/怪物动画时间轴, 933 KB)、`Back`/`Obj`/`Tile`/`UIBmp`
 * (素材符号定义)、`BangHui`(帮会外观动画) —— 那些属于素材/动画管线，不是数据表。
 */
const 杂项 = { ...(原始数据.Etc || {}) };
delete 杂项.EquipSystem;
const 原样导出 = {
  "任务.json": 原始数据.Quest,
  "成就.json": 原始数据.ChengJiu,
  "活动.json": 原始数据.Huodong,
  "经脉.json": 原始数据.Mai,
  "意志.json": 原始数据.Spirit,
  "师徒.json": 原始数据.Tutor,
  "VIP.json": 原始数据.Vip,
  "公告.json": 原始数据.GongGao,
  "增益状态.json": 原始数据.Buff,
  "宝箱.json": 原始数据.BaoXiang,
  "宝盒.json": 原始数据.Box,
  "卡片.json": 原始数据.Card,
  // 忍具段（13 条，带 addAttr）没进 物品.json：它的 icon 指向 `LingQi_*`，
  // 按分类目录找图的图标管线会全判缺失，先原样留着。
  "忍具.json": 原始数据.RenJu,
  // `JinghuaCost` 段外还套了一层同名键，人物页要的是 等级→精华价 的平表。
  "精华消耗.json": (原始数据.JinghuaCost || {}).JinghuaCost,
  "装备基础属性.json": (原始数据.Etc || {}).EquipSystem,
  "原版杂项.json": 杂项,
};
for (const [文件名, 表] of Object.entries(原样导出)) {
  if (表 && Object.keys(表).length > 0) 写入JSON(文件名, 表);
  else console.warn(`原版分区为空，跳过 ${文件名}`);
}

保留原有行("怪物.json", 怪物);
保留原有行("NPC.json", NPC);
保留原有行("物品.json", 物品);
保留原有行("技能.json", 技能);
保留原有行("地图名.json", 地图名);

写入JSON("怪物.json", 怪物);
写入JSON("NPC.json", NPC);
写入JSON("物品.json", 物品);
写入JSON("礼包奖励.json", 礼包奖励);
写入JSON("技能.json", 技能);
写入JSON("地图名.json", 地图名);

const 清理目录名 = (value) => String(value).replace(/[<>:"/\\|?*]/g, "_").trim();
const 名称数量 = Object.values(地图名).reduce((result, value) => {
  result[value] = (result[value] || 0) + 1;
  return result;
}, {});
const 地图目录名 = {};
for (const 编号 of Object.keys(地图源).sort()) {
  const 名称 = 清理目录名(地图名[编号]);
  地图目录名[编号] = 名称数量[地图名[编号]] > 1 ? `${名称}_${编号}` : 名称;
}
写入JSON("地图索引.json", 地图目录名);

const 当前地图目录 = new Set(Object.values(地图目录名));
const 旧地图目录候选 = new Set();
for (const [编号, 名称] of Object.entries(地图名)) {
  旧地图目录候选.add(清理目录名(名称));
  旧地图目录候选.add(编号);
  旧地图目录候选.add(`地图 ${编号}`);
}
for (const 目录名 of 当前地图目录) 旧地图目录候选.delete(目录名);

const 清理旧地图目录 = (根目录, 校验数据) => {
  if (!fs.existsSync(根目录)) return 0;
  let 已清理 = 0;
  for (const 条目 of fs.readdirSync(根目录, { withFileTypes: true })) {
    if (!条目.isDirectory() || !旧地图目录候选.has(条目.name)) continue;
    const 目录 = path.join(根目录, 条目.name);
    if (校验数据) {
      const 地图文件 = path.join(目录, "地图.json");
      if (!fs.existsSync(地图文件)) continue;
      try {
        const 地图编号 = String(JSON.parse(fs.readFileSync(地图文件, "utf8").replace(/^\uFEFF/, "")).mapId || "");
        if (!地图源[地图编号]) continue;
      } catch {
        continue;
      }
    }
    fs.rmSync(目录, { recursive: true, force: true });
    已清理++;
  }
  return 已清理;
};

const 已清理数据目录 = 清理旧地图目录(path.join(输出根目录, "地图"), true);
if (已清理数据目录 > 0) console.log(`清理旧地图数据目录：${已清理数据目录}`);

const 取数字层 = (地图) => Object.keys(地图).filter((key) => /^\d+$/.test(key)).sort((a, b) => Number(a) - Number(b));
const 取首帧 = (定义) => {
  if (!定义 || typeof 定义 !== "object") return {};
  if (定义.origin) return 定义;
  const 帧编号 = Object.keys(定义).filter((key) => /^\d+$/.test(key)).sort((a, b) => Number(a) - Number(b))[0];
  return 帧编号 === undefined ? {} : 定义[帧编号];
};

const 地图引用 = new Map();
const 注册引用 = (逻辑名, 地图编号, 类型) => {
  if (!地图引用.has(逻辑名)) 地图引用.set(逻辑名, { 地图编号, 类型 });
};

for (const 编号 of Object.keys(地图源).sort()) {
  const 地图 = 地图源[编号];
  const 目录 = path.join(输出根目录, "地图", 地图目录名[编号]);
  fs.mkdirSync(目录, { recursive: true });
  const 地图主体 = { mapId: 编号 };
  for (const key of ["foothold", "info", "back", "ladderRope", "life", "portal", "miniMap", "reactor", "seat", "item"]) {
    if (地图[key] !== undefined) 地图主体[key] = 地图[key];
  }
  const 地图块 = [];
  const 物件 = [];
  for (const 层号 of 取数字层(地图)) {
    const 层 = 地图[层号] || {};
    const 图块集 = String(层.info?.tS || "");
    for (const 原始图块 of Object.values(层.tile || {})) {
      const 定义 = 原始数据.Tile?.[图块集]?.[原始图块.u]?.[String(原始图块.no)] || {};
      const 原点 = 定义.origin || {};
      const 逻辑名 = `Tile_${图块集}_${原始图块.u}_${Number(原始图块.no)}`;
      地图块.push({ layer: Number(层号), tS: 图块集, ...原始图块, ox: Number(原点.x || 0), oy: Number(原点.y || 0) });
      注册引用(逻辑名, 编号, "地图块");
    }
    for (const 原始物件 of Object.values(层.obj || {})) {
      const 定义 = 原始数据.Obj?.[原始物件.oS]?.[原始物件.l0]?.[原始物件.l1]?.[String(原始物件.l2)] || {};
      const 首帧 = 取首帧(定义);
      const 原点 = 首帧.origin || {};
      const 逻辑名 = `Obj_${原始物件.oS}_${原始物件.l0}_${原始物件.l1}_${Number(原始物件.l2)}`;
      物件.push({ layer: Number(层号), x: Number(原始物件.x || 0), y: Number(原始物件.y || 0), z: Number(原始物件.z || 0), flip: Boolean(原始物件.f || 原始物件.flip), oS: String(原始物件.oS || ""), l0: String(原始物件.l0 || ""), l1: String(原始物件.l1 || ""), l2: String(原始物件.l2 || "0"), ox: Number(原点.x || 0), oy: Number(原点.y || 0) });
      注册引用(逻辑名, 编号, "地图物件");
    }
  }
  for (const 背景 of Object.values(地图.back || {})) {
    注册引用(`Back_${背景.bS}_back_${Number(背景.no)}`, 编号, "背景");
  }
  注册引用(`Map_${编号}_miniMap_canvas`, 编号, "小地图");
  fs.writeFileSync(path.join(目录, "地图.json"), JSON.stringify(地图主体));
  fs.writeFileSync(path.join(目录, "地图块.json"), JSON.stringify(地图块));
  fs.writeFileSync(path.join(目录, "物件.json"), JSON.stringify(物件));
}

if (!只导出数据) {
  if (!fs.existsSync(美术源)) throw new Error(`完整美术资源不存在：${美术源}`);

  /**
   * **先回收、后清理**：`完整美术资源`（ffdec 的 image 导出）并不是全集 ——
   * `Tile_*_bsc_*`、个别 `Back_*` 只在早先那份逐帧导出包里有，而那份包已经不在了。
   * 直接把美术源换成 E 盘重导，会把已经躺在 `素材/地图` 里的图变成"缺失"（实测 9 → 73）。
   * 所以先把项目里现存的素材按逻辑名建索引，源里查不到时用它兜底。
   * 旧副本（`--recovered=dir,dir`）也吃进来，用来救上一轮被改名清掉的地图。
   */
  const 回收索引 = new Map();
  const 登记回收 = (类型, 逻辑名, 路径) => {
    if (!回收索引.has(逻辑名)) 回收索引.set(逻辑名, { 类型, 路径 });
  };
  const 回收候选 = String(参数.recovered || path.join(项目目录, "素材", "地图"))
    .split(",").map((段) => 段.trim()).filter((段) => 段 && fs.existsSync(段));
  const 目录名反查 = {};
  for (const [编号, 目录名] of Object.entries(地图目录名)) 目录名反查[目录名] = 编号;
  for (const 根 of 回收候选) {
    for (const 条目 of fs.readdirSync(根, { withFileTypes: true })) {
      if (!条目.isDirectory()) continue;
      const 地图目录 = path.join(根, 条目.name);
      for (const [子目录, 类型] of [["地图块", "地图块"], ["背景", "背景"]]) {
        const 目录 = path.join(地图目录, 子目录);
        if (!fs.existsSync(目录)) continue;
        for (const 文件 of fs.readdirSync(目录)) {
          if (文件.endsWith(".png")) 登记回收(类型, 文件.slice(0, -4), path.join(目录, 文件));
        }
      }
      const 单图 = path.join(地图目录, "小地图.png");
      if (fs.existsSync(单图)) {
        const 编号 = 目录名反查[条目.name] || (/^\d+$/.test(条目.name) ? 条目.name : "");
        if (编号) 登记回收("小地图", `Map_${编号}_miniMap_canvas`, 单图);
      }
      const 小目录 = path.join(地图目录, "小地图");
      if (fs.existsSync(小目录)) {
        for (const 文件 of fs.readdirSync(小目录)) {
          if (文件.endsWith(".png")) 登记回收("小地图", 文件.slice(0, -4), path.join(小目录, 文件));
        }
      }
      const 物件根 = path.join(地图目录, "地图物件");
      if (!fs.existsSync(物件根)) continue;
      for (const 物件 of fs.readdirSync(物件根, { withFileTypes: true })) {
        if (物件.isDirectory() && !回收索引.has(物件.name)) {
          回收索引.set(物件.name, { 类型: "地图物件", 路径: path.join(物件根, 物件.name) });
        }
      }
    }
  }

  const 已清理素材目录 = 清理旧地图目录(path.join(项目目录, "素材", "地图"), false);
  if (已清理素材目录 > 0) console.log(`清理旧地图素材目录：${已清理素材目录}`);
  const 分类目录 = ["Tile", "Obj", "Back", "Map"];
  const 资源索引 = new Map();
  for (const 分类 of 分类目录) {
    const 目录 = path.join(美术源, 分类);
    for (const 文件名 of fs.readdirSync(目录)) {
      if (!文件名.toLowerCase().endsWith(".png") || 文件名.includes("[1]")) continue;
      const 匹配 = 文件名.match(/\.swf_\d+_(.+)\.png$/);
      if (!匹配) continue;
      const 逻辑名 = 匹配[1];
      if (!资源索引.has(逻辑名)) 资源索引.set(逻辑名, []);
      资源索引.get(逻辑名).push(path.join(目录, 文件名));
    }
  }
  for (const 补充源 of 补充美术源列表) {
    if (!fs.existsSync(补充源)) continue;
    // 直解包按分类分目录，只吃地图相关的四类；老的 swf-extracted-assets 是扁平的，整棵扫。
    const 待扫描 = path.basename(补充源) === "原版直解"
      ? 分类目录.map((分类) => path.join(补充源, 分类)).filter((目录) => fs.existsSync(目录))
      : [补充源];
    while (待扫描.length > 0) {
      const 目录 = 待扫描.pop();
      for (const 条目 of fs.readdirSync(目录, { withFileTypes: true })) {
        const 绝对路径 = path.join(目录, 条目.name);
        if (条目.isDirectory()) {
          待扫描.push(绝对路径);
          continue;
        }
        if (!条目.name.toLowerCase().endsWith(".png")) continue;
        // 两种命名都认：ffdec 裸导出 `23_Tile_x_bsc_4.png`，直解包 `Tile_x.swf_23_Tile_x_bsc_4.png`。
        const 匹配 = 条目.name.match(/\.swf_\d+_(.+)\.png$/i) || 条目.name.match(/^\d+_(.+)\.png$/);
        if (!匹配) continue;
        const 逻辑名 = 匹配[1];
        if (!资源索引.has(逻辑名)) 资源索引.set(逻辑名, []);
        const 文件列表 = 资源索引.get(逻辑名);
        if (!文件列表.includes(绝对路径)) 文件列表.push(绝对路径);
      }
    }
  }
  const 已复制 = new Set();
  const 素材索引 = {};
  const 缺失明细 = [];
  let 缺失 = 0;
  let 回收命中 = 0;
  for (const [逻辑名, 引用] of 地图引用) {
    if (已复制.has(逻辑名)) continue;
    var 源条目 = [];
    if (引用.类型 === "地图物件") {
      for (const [资源名, 文件列表] of 资源索引) {
        if (资源名.startsWith(`${逻辑名}_`)) {
          for (const 文件 of 文件列表) 源条目.push({ 资源名, 文件 });
        }
      }
      源条目.sort((a, b) => a.资源名.localeCompare(b.资源名, "zh-CN", { numeric: true }));
    } else {
      源条目 = (资源索引.get(逻辑名) || []).map((文件) => ({ 资源名: 逻辑名, 文件 }));
    }
    if (源条目.length === 0) {
      if (引用.类型 === "小地图" && 地图原型编号[引用.地图编号]) {
        const 原型逻辑名 = `Map_${地图原型编号[引用.地图编号]}_miniMap_canvas`;
        const 原型资源 = 素材索引[`小地图/${原型逻辑名}`];
        if (原型资源) {
          素材索引[`小地图/${逻辑名}`] = 原型资源;
          已复制.add(逻辑名);
          continue;
        }
      }
      if (回收索引.has(逻辑名)) {
        const 回收 = 回收索引.get(逻辑名);
        if (回收.类型 === 引用.类型) {
          const 地图素材根 = path.join(项目目录, "素材", "地图", 地图目录名[引用.地图编号]);
          let 目标;
          if (引用.类型 === "地图物件") {
            目标 = path.join(地图素材根, "地图物件", 逻辑名);
            fs.mkdirSync(目标, { recursive: true });
            for (const 帧 of fs.readdirSync(回收.路径)) {
              if (!帧.endsWith(".png")) continue;
              const 落点 = path.join(目标, 帧);
              if (!fs.existsSync(落点)) fs.copyFileSync(path.join(回收.路径, 帧), 落点);
            }
          } else {
            目标 = path.join(地图素材根,
              引用.类型 === "地图块" ? path.join("地图块", 逻辑名)
                : 引用.类型 === "背景" ? path.join("背景", 逻辑名) : "小地图") + ".png";
            fs.mkdirSync(path.dirname(目标), { recursive: true });
            if (!fs.existsSync(目标)) fs.copyFileSync(回收.路径, 目标);
          }
          素材索引[`${引用.类型}/${逻辑名}`] = `res://${path.relative(项目目录, 目标).split(path.sep).join("/")}`;
          已复制.add(逻辑名);
          回收命中++;
          continue;
        }
      }
      if (引用.类型 !== "小地图") console.warn(`缺少地图素材：${逻辑名}`);
      缺失明细.push({ logical_name: 逻辑名, type: 引用.类型, map_id: 引用.地图编号 });
      缺失++;
      continue;
    }
    const 地图素材根 = path.join(项目目录, "素材", "地图", 地图目录名[引用.地图编号]);
    let 目标文件;
    if (引用.类型 === "地图物件") {
      const 目标目录 = path.join(地图素材根, "地图物件", 逻辑名);
      fs.mkdirSync(目标目录, { recursive: true });
      for (const 条目 of 源条目) {
        const 帧文件 = path.join(目标目录, `${条目.资源名}.png`);
        if (!fs.existsSync(帧文件)) fs.copyFileSync(条目.文件, 帧文件);
      }
      目标文件 = 目标目录;
    } else {
      const 相对目标 = 引用.类型 === "地图块" ? path.join("地图块", 逻辑名)
        : 引用.类型 === "背景" ? path.join("背景", 逻辑名) : "小地图";
      目标文件 = path.join(地图素材根, `${相对目标}.png`);
      fs.mkdirSync(path.dirname(目标文件), { recursive: true });
      if (!fs.existsSync(目标文件)) fs.copyFileSync(源条目[0].文件, 目标文件);
    }
    const res路径 = `res://${path.relative(项目目录, 目标文件).split(path.sep).join("/")}`;
    素材索引[`${引用.类型}/${逻辑名}`] = res路径;
    已复制.add(逻辑名);
  }
  写入JSON("地图素材索引.json", 素材索引);
  写入JSON("地图素材缺失.json", 缺失明细);
  console.log(`地图素材：引用 ${地图引用.size}，复制/复用 ${已复制.size}（其中从已导入素材回收 ${回收命中}），缺失 ${缺失}`);
}

console.log(`数据导出完成：怪物 ${Object.keys(怪物).length}，NPC ${Object.keys(NPC).length}，物品 ${Object.keys(物品).length}，技能 ${Object.keys(技能).length}，地图 ${Object.keys(地图源).length}`);
