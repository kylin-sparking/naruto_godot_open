extends RefCounted

## 套装四灯的**判定 + 悬停提示拼串**——唯一一份。
##
## 真值两块：
##   · 判定 `ItemFactory.isSameStage / isAllPurple / isFullStar / isFullStone`
##     + `getPurpleCount / getFullStarCount / getFullStoneCount`（`ItemFactory.as`，
##     谓词按**部位**排除时装/预炼/徽章 ⇒ "标准 12 槽的已装件"就是过滤后列表）；
##   · 拼串 `EquipPane.setSeriesIcon()`（`char/EquipPane.as:908-945`）。
##
## ⚠️ 原版的三处口径怪癖，全部照做、不"顺手修"：
##   1. **等阶灯的件数恒按 1** —— `sameStageCount` 声明后**从没有赋值**（初值 1），
##      所以等阶灯效果行的百分比永远是 `valueProb×1`；
##   2. 效果行的属性值求和扫的是**整包已装装备**（`getEffectText(…, _loc2_)`），
##      不是过滤后的 12 件 —— 徽章/神器那些也计入；
##   3. 未满 12 件的 2~4 号灯用 `TIP2` 模板（多"下阶状态/额外"两行），
##      满 12 件与等阶灯用 `TIP`；等阶灯永远用 `TIP`。
##
## 语言串来自 `数据/界面/套装提示_文案.json`（`开发工具/出套装提示文案.py` 导出，缺键报错）；
## 效果表在 `数据/装备基础属性.json` 的 `taozhuang`（含 `values` 表）。

const 文案表路径 := "res://数据/界面/套装提示_文案.json"
const 基础属性路径 := "res://数据/装备基础属性.json"
const 部位表 := preload("res://脚本/单例/装备部位.gd")
const 装备提示 := preload("res://脚本/界面/组件/装备提示框.gd")

## 系列内部名（`ItemFactory.SERIES_EQUIP_DAT_NAMES`），顺序=灯序。
const 系列名 := ["dengjie", "quanzi", "manxin", "manrong"]
## `SUB_ATTR_TYPE_EN_NAMES`（`:33`）—— 用于把 `taozhuang[*].type` 的英文名换成中文名。
const 属性英文名序 := ["money", "maxhp", "maxmp", "maxtp", "atk", "def", "bsk", "avd",
		"atkspeed", "wlkspeed", "skill_level", "atk_tate", "damage_reflect",
		"damage_reduce", "ignore_def", "anqi_trigger", "mob_exp"]
## 每个英文名对应的语言表键（`ItemFactory:35` 那行的组成；money 在原版就是**空名**）。
const 属性名键 := {
	"maxhp": "ITEM_ATTR_NAME_MAXHP", "maxmp": "ITEM_ATTR_NAME_MAXMP",
	"maxtp": "ITEM_ATTR_NAME_MAXTP", "atk": "ITEM_ATTR_NAME_ATK",
	"def": "ITEM_ATTR_NAME_DEF", "bsk": "ITEM_ATTR_NAME_BSK",
	"avd": "ITEM_ATTR_NAME_AVD", "atkspeed": "ITEM_ATTR_NAME_ATK_SPEED",
	"wlkspeed": "ITEM_ATTR_NAME_WLK_SPEED", "skill_level": "ITEMFACTORY_SKILL_LEVEL",
	"atk_tate": "ITEMFACTORY_ATK_TATE", "damage_reflect": "ITEMFACTORY_DAMAGE_REFLECT",
	"damage_reduce": "ITEMFACTORY_DAMAGE_REDUCE", "ignore_def": "ITEMFACTORY_IGNORE_DEF",
	"anqi_trigger": "ITEMFACTORY_ANQI_TRIGGER", "mob_exp": "ITEMFACTORY_MOB_EXP",
}
## `装备提示框.属性英文名` 的**同一份**反查（类型 int ↔ 英文名）。
const 类型到英文名 := {
	0: "money", 1: "maxhp", 2: "maxmp", 3: "maxtp", 4: "atk", 5: "def", 6: "bsk", 7: "avd",
	8: "atkspeed", 9: "wlkspeed", 10: "skill_level", 11: "atk_tate", 12: "damage_reflect",
	13: "damage_reduce", 14: "ignore_def", 15: "anqi_trigger", 25: "mob_exp",
}

static var _文案: Dictionary = {}
static var _效果表: Dictionary = {}

static func 文(键: String) -> String:
	if _文案.is_empty():
		var 原 = JSON.parse_string(FileAccess.get_file_as_string(文案表路径))
		if not (原 is Dictionary):
			push_error("套装提示：读不到 套装提示_文案.json（先跑 开发工具/出套装提示文案.py）")
			return ""
		_文案 = 原
	return String((_文案.get(键, {}) as Dictionary).get("文", ""))

static func 效果表() -> Dictionary:
	if _效果表.is_empty():
		var 原 = JSON.parse_string(FileAccess.get_file_as_string(基础属性路径))
		if not (原 is Dictionary):
			push_error("套装提示：读不到 装备基础属性.json")
			return {}
		_效果表 = (原 as Dictionary).get("taozhuang", {}) as Dictionary
	return _效果表

# ──────────────────────────── 判定（四灯 + 计数） ────────────────────────────

## 过滤列表：标准 12 槽的已装件（原版按部位排除时装/预炼/徽章，等价）。
## `装备表` = **看别人**时传进来的「他的已装表」（`位置 → 物品`，`后端连接._他人装备表`）。
## ⚠ 判据是 `is Dictionary`，**不是"空不空"**：他那扇一件没装时传的是**空表**，
## 按"空不空"判就会回落到**我的**装备 ⇒ 灯与计数变成我的。原版
## `EquipPane.as:872-877 setSeriesIcon`：`_isMyself` 为假时 `_loc2_ = param1`（他的数组）。
## 传 `null`（默认）才读 `会话.equipped_items`。
static func 已装(会话, 装备表: Variant) -> Dictionary:
	if 装备表 is Dictionary:
		return 装备表 as Dictionary
	return (会话.equipped_items as Dictionary) if 会话 != null else {}

static func 过滤列表(会话, 装备表: Variant = null) -> Array:
	var 列表: Array = []
	if 会话 == null and not (装备表 is Dictionary):
		return 列表
	var 表 := 已装(会话, 装备表)
	for 位 in 部位表.标准槽:
		var 物 = 表.get(位, null)
		if 物 is Dictionary and not (物 as Dictionary).is_empty():
			列表.append(物 as Dictionary)
	return 列表

static func 整列表(会话, 装备表: Variant = null) -> Array:
	var 列表: Array = []
	if 会话 == null and not (装备表 is Dictionary):
		return 列表
	for 物 in 已装(会话, 装备表).values():
		if 物 is Dictionary and not (物 as Dictionary).is_empty():
			列表.append(物 as Dictionary)
	return 列表

## `CocoEquip.getSubArrValue(类型)`（`CocoEquip.as:97-133`）：
## `(类型==基础类型 ? 基础+天生+强化 : 0) + Σ附加 + Σ镶嵌 + 刻印`。
static func 单件取值(装: Dictionary, 类型: int) -> int:
	var 值 := 0
	if 类型 == int(装.get("base_attr_type", 0)):
		值 += int(装.get("base_attr_value", 0)) + int(装.get("born_attr_value", 0)) \
				+ int(装.get("strength_value", 0))
	for 条 in (装.get("plus_attributes", []) as Array):
		if 条 is Dictionary and int(条.get("attribute_type", 条.get("sub_attr_type", -1))) == 类型:
			值 += int(条.get("attribute_value", 条.get("value", 0)))
	for 颗 in (装.get("inlays", []) as Array):
		if not (颗 is Dictionary):
			continue
		# 服务端字段名（`后端连接:2666/2879`）；`attr_type/attr_value` 兼容旧自造键
		var 石类 := int((颗 as Dictionary).get("attribute_type", (颗 as Dictionary).get("attr_type", -1)))
		if 石类 == 类型:
			值 += int((颗 as Dictionary).get("attribute_value", (颗 as Dictionary).get("attr_value", 0)))
	if int(装.get("carve_id", 0)) > 0 and int(装.get("carve_type", -1)) == 类型:
		值 += int(装.get("carve_value", 0))
	return 值

static func 全装取值(整列表: Array, 类型: int) -> int:
	var 总 := 0
	for 装 in 整列表:
		总 += 单件取值(装 as Dictionary, 类型)
	return 总

## 原版 `getInlayState`：`<5 槽`假；正好 5 颗颗 ≥6；>5 槽最多容一颗 <6。
static func 镶嵌状态(嵌: Array) -> bool:
	if 嵌.size() < 5:
		return false
	var 低 := 0
	for 颗 in 嵌:
		# ⚠️ 服务端镶嵌条目里宝石等级是 **`stone_level`**（`后端连接:2666`；装备格角标 :101 读的就是它）。
		#    旧 `_套装满融` 读 `"level"` ⇒ **在线满融灯永远不亮**（键不存在一律 0）。这里两个键都认。
		var 级 := int((颗 as Dictionary).get("stone_level", (颗 as Dictionary).get("level", 0))) if 颗 is Dictionary else int(颗)
		if 级 < 6:
			if 嵌.size() == 5:
				return false
			低 += 1
			if 低 > 1:
				return false
	return true

static func 装备阶数(物: Dictionary) -> int:
	var 元 := 装备提示._物品元(str(物.get("id", "")))
	return int(元.get("stage", 物.get("stage", 0)))

## 四灯亮灭（`setSeriesIcon:918-921`：过滤列表**满 12 件**才逐条判）。
static func 四灯(会话, 装备表: Variant = null) -> Array:
	var 列表 := 过滤列表(会话, 装备表)
	if 列表.size() != 12:
		return [false, false, false, false]
	var 首阶 := 装备阶数(列表[0])
	var 同阶 := 首阶 > 0
	for 物 in 列表:
		if 装备阶数(物) != 首阶:
			同阶 = false
	var 全紫 := true
	var 满星 := true
	var 满融 := true
	for 物 in 列表:
		var 资 := int(物.get("aptitude", 0))
		if 资 != 4 and 资 != 5:
			全紫 = false
		if int(物.get("strengthen", 0)) < 10:
			满星 = false
		if not 镶嵌状态(物.get("inlays", []) as Array):
			满融 = false
	return [同阶, 全紫, 满星, 满融]

## 三个计数（`purpleCount / fullStarCount / fullStoneCount`，整包逐件判、不套满 12）。
static func 计数(会话, 装备表: Variant = null) -> Dictionary:
	var 紫 := 0
	var 星 := 0
	var 融 := 0
	for 物 in 过滤列表(会话, 装备表):
		var 资 := int(物.get("aptitude", 0))
		if 资 == 4 or 资 == 5:
			紫 += 1
		if int(物.get("strengthen", 0)) >= 10:
			星 += 1
		if 镶嵌状态(物.get("inlays", []) as Array):
			融 += 1
	return {"紫": 紫, "星": 星, "融": 融}

# ──────────────────────────── 拼串 ────────────────────────────

## JS 的 `Number + ""` 口径：整数值不带 `.0`。
static func 数转文(v) -> String:
	var f := float(v)
	return str(int(round(f))) if is_equal_approx(f, round(f)) else str(f)

## 原版 `indexOf('.')` 截断：`整数部分 + "." + 一位小数`（`"1.75"→"1.7"`；无小数点原样）。
static func 截小数(s: String) -> String:
	var 点 := s.find(".")
	return s if 点 < 0 else s.substr(0, 点) + s.substr(点, 2)

## `getEffectText`（`ItemFactory.as:710-745`）/`getNextEffectText`（`:426-463`）。
## `下一阶=true` 时套 `values[件数+1]`（等阶系列与满 12 时按原版返回空串）。
static func 效果文本(系列: String, 件数: int, 整列表: Array, 下一阶 := false) -> String:
	var 表: Dictionary = 效果表()
	if 表.is_empty():
		return ""
	if 下一阶 and (系列 == 系列名[0] or 件数 >= 12):
		return ""
	var 组 = 表.get(系列, null)
	if not (组 is Dictionary):
		return ""
	var 用件数 := 件数 + 1 if 下一阶 else 件数
	var 出 := ""
	var 序 := 0
	while 序 < 10:
		var 条 = (组 as Dictionary).get(str(序), null)
		if not (条 is Dictionary):
			break
		var 百分比: String
		if 系列 == 系列名[0]:
			# 原版 `valueProb * param2`；等阶的 param2=`sameStageCount` **恒 1**（怪癖①）
			百分比 = str(int(条.get("valueProb", 0)) * (件数 if not 下一阶 else 件数 + 1))
		else:
			百分比 = 数转文((表.get("values", {}) as Dictionary).get(str(用件数), 0)) if 用件数 > 0 else "0"
		百分比 = 截小数(百分比)
		var 英文 := String(条.get("type", ""))
		var 名 := "" if 英文 == "money" else 属性中文名(英文)
		var 类型 := -1
		for t in 类型到英文名:
			if String(类型到英文名[t]) == 英文:
				类型 = int(t)
		var 附加 := 0
		if 类型 >= 0:
			附加 = int(float(全装取值(整列表, 类型)) * (float(百分比) / 100.0))
		出 += "%s%s%%  +%d<br/>" % [名, 百分比, 附加]
		序 += 1
	return 出

static func 属性中文名(英文: String) -> String:
	var 键名 := String(属性名键.get(英文, ""))
	return 文(键名) if 键名 != "" else ""

static func 替串(模板: String, 参: Array) -> String:
	var 出 := 模板
	for i in 参.size():
		出 = 出.replace("%%%d" % (i + 1), str(参[i]))
	return 出

## 拼第 `灯`（0..3）枚灯的悬停 HTML（含灯亮灭、TIP/TIP2 的选择）。
## `列表`/`计数结果` 允许调用方传现成的，省得重复算。
static func 提示html(灯: int, 会话, 装备表: Variant = null) -> String:
	if 灯 < 0 or 灯 > 3:
		return ""
	var 亮 := 四灯(会话, 装备表)
	var 数 := 计数(会话, 装备表)
	var 整 := 整列表(会话, 装备表)
	var 件数: int = [1, int(数["紫"]), int(数["星"]), int(数["融"])][灯]   # 等阶=永远 1（怪癖①）
	var 名 := 文("EQUIPMENT_SERIES_DATA_NAME_%d" % (灯 + 1))
	var 述 := 文("EQUIPMENT_SERIES_DATA_DESC_%d" % (灯 + 1))
	var 状态: String
	if 灯 == 0:
		状态 = 文("EQUIPMENT_SERIES_TIP_ACTIVE") if bool(亮[0]) else 文("EQUIPMENT_SERIES_TIP_UNACTIVE")
	else:
		状态 = 文("EQUIP_PANE_YIJIHUO") if 件数 == 12 \
				else 替串(文("EQUIP_PANE_JIHUO_ZHONG_RED"), [件数])
	var 效 := 效果文本(系列名[灯], 件数, 整)
	if 灯 == 0 or 件数 == 12:
		return 替串(文("EQUIPMENT_SERIES_TIP"), [名, 状态, 述, 效])
	var 灰 := 替串(文("EQUIP_PANE_JIHUO_ZHONG_GRAY"), [件数 + 1])
	var 下 := 效果文本(系列名[灯], 件数, 整, true)
	return 替串(文("EQUIPMENT_SERIES_TIP2"), [名, 状态, 述, 效, 灰, 下])
