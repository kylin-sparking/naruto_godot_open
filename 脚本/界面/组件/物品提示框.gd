extends Control

## 原版**物品提示框**（普通物品那套）。
##
## 真值来源
## --------
## 原版 `MToolTipItem.createToolTip(stage, 格子, ItemData)` 按物品类型分发，
## 普通物品走 `MToolTipDefault.createDefaultTip`（`com/mxw/uifl/base/controls/tips/MToolTipDefault.as`）。
## 它的版式**全是代码算的**（提示框没有自己的符号，`ToolTip_background` 只是那张底图）：
##
##   MToolTip.as:20       PADDING   = 8
##   MToolTipItem.as:18   MAX_WIDTH = 280
##   createDefaultTip     bgHeight 从 PADDING 起；每块摆在 `bgHeight + 5`，块高累加
##   末尾                底.width  = MAX_WIDTH + PADDING*2 - 3 = **293**
##                       底.height = bgHeight + PADDING
##
## 块序：标题(高 20, 14px 粗体白居中) → 等级需求 → 描述 → 分隔线 → 宝石属性 → 价格/绑定 → 过期。
## **图标框**（`MGrid_background` = 符号 172，40x40）摆在 **(170, 38)**：
## x 写死 170、y 是"标题之后"的 bgHeight(28) + 10 —— 它**不参与** bgHeight 累加。
##
## ⚠️ 底图符号 699 在 SWF 里**没有 scale9Grid**（查过 MainLib.xml 的 spriteId=699 标签），
## `ScaleSprite` 构造里读到的就是 null ⇒ 原版是**普通拉伸**，这里也照做（`expand_mode = 1`）。
##
## ⚠️ 等级那一行 `ITEM_DATA_BALANCE_TF_TEXT` = `"使用等级　%1级<br/>　<br/>　<br/>　"`
## 原文带**三行全角空格**，是原版真值不是笔误 —— 它把那一块撑成 4 行高，图标框就摆在它右边。
##
## 定位（`MToolTip.setLocation`）：`x = 鼠标x + 10`、`y = 鼠标y + 20`，
## 再钳进 `[0, 舞台宽 - 自身宽] × [0, 舞台高 - 自身高]`；高过 `舞台高-8` 时整体缩放。

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

const 内边距 := 8.0
const 最大宽 := 280.0
const 框宽 := 293.0            ## MAX_WIDTH + PADDING*2 - 3
const 块间距 := 5.0
const 行距 := 4.0
const 标题高 := 20.0
const 标题字号 := 14
const 正文字号 := 12
const 图标框尺寸 := 40.0
const 图标框位置 := Vector2(170.0, 38.0)

## 宝石段（`MToolTipDefault.as:132-151`）：**宝石类里除了秽章石（132 前缀）**都画。
## 两支共用一段版式，只有抬头与数值不同：
##   · 勾玉（131）：`MTOOTIP_STONE_GOUYU_PRORERTIES`（`en_US$message_properties.as:1700`）
##     + 绿字「技能名  +N层」—— 名字 = `StringTool.getSkillString(skill)`，层数 = `inlay.level`；
##   · 普通宝石（130）：`CN.MTOOTIP_STONE_PRORERTIES`（`:2067`）+ `StoneData.getAttributeDesc:89`
##     的「属性名　+数值」（白字；`ATTR_TYPE_NAMES` 由 `CN.ITEM_ATTR_NAME_*` 拼）。
## **不是** `stone_level` —— 勾玉加成层数从 6 级起就与宝石等级分叉
## （6 级 stoneLevel=6、level=7），所以数据列单独取 `inlay.level`（见 `开发工具/导出勾玉技能.py`）。
const 勾玉抬头 := "勾玉属性"
const 宝石抬头 := "宝石属性"
const 色_宝石抬头 := Color("8ea8d8")
const 色_勾玉值 := Color("00ff00")
const 色_宝石值 := Color.WHITE
## `StoneData.ATTR_TYPES`（`StoneData.as:16`）→ `ATTR_TYPE_NAMES`（`CN.ITEM_ATTR_NAME_*`）。
const 宝石词条名 := {
	"atk": "攻击", "def": "防御", "atkspeed": "攻击速度",
	"bsk": "暴击", "avd": "闪避", "maxhp": "生命值上限",
}

## `ITEM_DATA_BALANCE_TF_TEXT`（`en_US$message_properties.as:2631`）
const 等级需求模板 := "使用等级　%s级\n　\n　\n　"
## `MTOOTIP_SALE_TOTAL_PRICE`(462) / `MTOOTIP_BUY_TOTAL_PRICE`(1002)
const 出售总价 := "出售总价　"
const 购买所需 := "购买所需金币　"
## `MTOOTIP_CANTRADE`(902) / `MTOOTIP_NOT_CANTRADE`(3315)
const 已绑定 := "[已绑定]"
const 未绑定 := "[未绑定]"
## `MTOOTIP_EXPIRATION`(641)
const 过期时间 := "过期时间："

const 色_超等级 := Color("ff0000")   ## baseInfo 在 reqLevel > 玩家等级 时套 <font color="#ff0000">
const 色_价格 := Color("00ff00")     ## setTextColor(priceText, 65280)
const 色_绑定 := Color("8ea8d8")     ## setTextColor(..., 9349336)
const 色_过期标题 := Color("8ea8d8")
const 色_过期时间 := Color("ff0000")

@onready var _底: TextureRect = $底
@onready var _标题: Label = $标题
@onready var _等级: Label = $等级
@onready var _描述: Label = $描述
@onready var _分隔线: TextureRect = $分隔线
@onready var _价格: Label = $价格
@onready var _绑定: Label = $绑定
@onready var _过期: Label = $过期
@onready var _图标框: TextureRect = $图标框
@onready var _图标: TextureRect = $图标框/图标

## 宝石段的两行**不在场景里**（同 `格子提示框` 的对比列先例）：只有宝石才需要，
## 建一次就复用；非宝石那一路把它们藏起来，避免上一件的残影。
var _宝石抬头: Label = null
var _宝石值: Label = null


## `物品id` 走 `游戏数据`（静态表 name/description/required_level…）。
## `实例` 是**这一件**的运行时字段（`can_trade` / `expiration`）—— 原版 `value` 是
## `ItemData` 实例，表数据与实例数据在同一个对象上，这里分开传。
## `存量` 是格子上的数量（价格按 `floor(price * 存量 / 3)` 算，见 `MToolTipDefault.as:158`）。
## `商店总价 < 0` 表示不在商店窗口里，不显示价格行（原版是查 `API.ui.content.shopWindow` 在不在）。
func 设置(物品id: String, 存量: int, 玩家等级: int,
		实例 := {}, 商店总价 := -1, 是购买价 := false) -> void:
	var 物品 := GAME_DATA.item(物品id)
	_图标.texture = GAME_DATA.item_icon(物品id)
	_设图标()

	_标题.text = String(物品.get("name", ""))

	var 需等级 := int(物品.get("required_level", 0))
	_等级.text = 等级需求模板 % str(需等级)
	_等级.add_theme_color_override("font_color",
		色_超等级 if 需等级 > 玩家等级 else Color.WHITE)

	var 描述 := String(物品.get("description", ""))
	_描述.text = 描述
	_描述.visible = not 描述.is_empty()

	_填宝石属性(物品id, 物品)

	var 价格文本 := ""
	if 商店总价 >= 0:
		价格文本 = (购买所需 + str(商店总价)) if 是购买价 \
			else (出售总价 + str(商店总价))
	_价格.text = 价格文本
	_价格.visible = not 价格文本.is_empty()

	# `ItemData.isShowCanTrade` 是**声明过的成员、默认 0**，所以 `hasOwnProperty` 恒真、
	# `0 != -1` 恒真 ⇒ 这一行**默认总是显示**；只有 `SkillStudyConditionPane.as:137`
	# （秘籍图案那处）显式设 -1 才藏。
	# 文案按 AS3 原文：`canTrade ? MTOOTIP_NOT_CANTRADE(未绑定) : MTOOTIP_CANTRADE(已绑定)`
	# （`MToolTipDefault.as:177`；`canTrade` = **可交易** ⇒ 可交易才显示「未绑定」）。
	_绑定.text = 未绑定 if bool(实例.get("can_trade", true)) else 已绑定
	_绑定.visible = int(实例.get("is_show_can_trade", 0)) != -1

	# 过期：原版按 `expiration`(秒) 显示倒计时或日期。
	var 过期秒 := int(实例.get("expiration", 0))
	_过期.visible = 过期秒 > 0
	if 过期秒 > 0:
		_过期.text = 过期时间 + _剩余时间(过期秒)

	_排版()


## 宝石那一段。判据 = 原版 `category == BaoShi && !ItemFactory.isItemAHuiZhangShi(id)`
## （`MToolTipDefault.as:132`；秽章石就是 132 前缀），再按前缀分两支。
## 勾玉的技能名同样走 `游戏数据.skill_text(号)`（= 原版 `StringTool.getSkillString` 查顶层
## `String.Skill`）；表里查不到名字时退回号码，不整段吞掉 —— "加哪条、加几层"比"名字对不对"更要紧。
func _填宝石属性(物品id: String, 物品: Dictionary) -> void:
	var 前缀 := 物品id.substr(0, 3)
	if String(物品.get("category", "")) != "宝石" or 前缀 == "132":
		_藏宝石块()
		return
	if 前缀 == "131":
		var 技能号 := int(物品.get("gouyu_skill", 0))
		var 层 := int(物品.get("gouyu_level", 0))
		if 技能号 <= 0 or 层 <= 0:
			_藏宝石块()
			return
		var 名 := String(GAME_DATA.skill_text(技能号).get("name", ""))
		if 名.is_empty():
			名 = str(技能号)
		_写宝石块(勾玉抬头, "%s  +%d层" % [名, 层], 色_勾玉值)
		return
	## `StoneData.getAttributeDesc:83-90`：`wzItem.type` 查 `ATTR_TYPES` 得中文名，
	## 再拼全角空格 + `+value`；type 为空时原版给空串（只剩抬头），这里直接收起。
	var 类型 := String(物品.get("stone_attr_type", ""))
	if not 宝石词条名.has(类型):
		_藏宝石块()
		return
	_写宝石块(宝石抬头, "%s　+%d" % [String(宝石词条名[类型]), int(物品.get("stone_attr_value", 0))],
		色_宝石值)


func _写宝石块(抬头: String, 值: String, 色: Color) -> void:
	_保证宝石块()
	_宝石抬头.visible = true
	_宝石值.visible = true
	_宝石抬头.text = 抬头
	_宝石值.text = 值
	_宝石值.add_theme_color_override("font_color", 色)


func _藏宝石块() -> void:
	if _宝石抬头 == null:
		return
	_宝石抬头.visible = false
	_宝石值.visible = false


func _保证宝石块() -> void:
	if _宝石抬头 != null:
		return
	_宝石抬头 = _新行("宝石抬头", 色_宝石抬头)
	_宝石值 = _新行("宝石值", 色_宝石值)


func _新行(名: String, 色: Color) -> Label:
	var 行 := Label.new()
	行.name = 名
	行.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	行.add_theme_font_size_override("font_size", 正文字号)
	行.add_theme_constant_override("line_spacing", int(行距))
	行.add_theme_color_override("font_color", 色)
	add_child(行)
	return 行


## 图标在 40x40 的框里居中。原版是 `icon.x = (iconGrid.width - icon.height) >> 1`
## （注意 x 也用的 height —— 图标都是 34x34 方图时两者等价，这里照抄原式）。
func _设图标() -> void:
	if _图标.texture == null:
		_图标框.visible = false
		return
	_图标框.visible = true
	var 边 := _图标.texture.get_size()
	_图标.size = 边
	var 偏移 := floorf((图标框尺寸 - 边.y) / 2.0)
	_图标.position = Vector2(偏移, 偏移)


## `bgHeight` 累加（照 `createDefaultTip` 的顺序与增量）。
func _排版() -> void:
	var 字号行高 := _单行高(正文字号)
	var y := 内边距
	_标题.size = Vector2(最大宽, 标题高)
	y += 标题高

	_等级.size = Vector2(最大宽, _文字高(_等级.text, 正文字号))
	_等级.position = Vector2(内边距, y + 块间距)
	y += 块间距 + _等级.size.y

	if _描述.visible:
		# Label 开着 autowrap，先给宽度再量高，量出来的才是折行后的高。
		_描述.size = Vector2(最大宽, 0.0)
		_描述.size = Vector2(最大宽, _文字高(_描述.text, 正文字号))
		_描述.position = Vector2(内边距, y + 块间距)
		y += 块间距 + _描述.size.y

	_分隔线.size = Vector2(最大宽, _分隔线.texture.get_height() if _分隔线.texture else 2.0)
	_分隔线.position = Vector2(内边距, y + 块间距)
	y += 块间距 + _分隔线.size.y

	# 宝石段：抬头一行 + 值行一行，两行之间是普通行距（原版同一个文本域）。
	if _宝石抬头 != null and _宝石抬头.visible:
		var 首行 := y + 块间距
		_宝石抬头.size = Vector2(最大宽, 字号行高)
		_宝石抬头.position = Vector2(内边距, 首行)
		_宝石值.size = Vector2(最大宽, 字号行高)
		_宝石值.position = Vector2(内边距, 首行 + 字号行高 + 行距)
		y = 首行 + 字号行高 * 2.0 + 行距

	# 价格与绑定在原版是**同一个文本框**里的两行（`priceText + "<br/>" + 绑定`），
	# 所以它们之间是普通行距，不是块间距。
	var 行数 := (1 if _价格.visible else 0) + (1 if _绑定.visible else 0)
	if 行数 > 0:
		var 首行y := y + 块间距
		var 第几行 := 0
		for 行 in [_价格, _绑定]:
			if not 行.visible:
				continue
			行.size = Vector2(最大宽, 字号行高)
			行.position = Vector2(内边距, 首行y + 第几行 * (字号行高 + 行距))
			第几行 += 1
		y += 块间距 + 行数 * 字号行高 + (行数 - 1) * 行距

	if _过期.visible:
		_过期.size = Vector2(最大宽, 字号行高)
		_过期.position = Vector2(内边距, y + 块间距)
		y += 块间距 + _过期.size.y

	_图标框.position = 图标框位置
	_图标框.size = Vector2(图标框尺寸, 图标框尺寸)

	var 框高 := y + 内边距
	_底.size = Vector2(框宽, 框高)
	size = Vector2(框宽, 框高)


## `MToolTip.setLocation`：贴在鼠标右下，再钳进舞台内；比舞台还高就整体缩放。
func 贴到鼠标(鼠标位置: Vector2, 舞台尺寸: Vector2) -> void:
	scale = Vector2.ONE
	if size.y > 舞台尺寸.y - 8.0:
		var 比 := (舞台尺寸.y - 8.0) / size.y
		scale = Vector2(比, 比)
	var 位置 := 鼠标位置 + Vector2(10.0, 20.0)
	位置.x = clampf(位置.x, 0.0, maxf(0.0, 舞台尺寸.x - size.x * scale.x))
	位置.y = clampf(位置.y, 0.0, maxf(0.0, 舞台尺寸.y - size.y * scale.y))
	position = 位置


func _字体() -> Font:
	return _等级.get_theme_font("font")


func _单行高(字号: int) -> float:
	return _字体().get_height(字号)


## 按 `Font.get_multiline_string_size` 量折行后的高，再补上 Godot 的 line_spacing
## （原版是 TextFormat.leading = 4，等价）。
func _文字高(文本: String, 字号: int) -> float:
	var 排版宽 := 最大宽
	var 尺寸 := _字体().get_multiline_string_size(
		文本, HORIZONTAL_ALIGNMENT_LEFT, 排版宽, 字号)
	var 单行 := _单行高(字号)
	var 行数 := 1 if 单行 <= 0.0 else int(round(尺寸.y / 单行))
	行数 = maxi(行数, 1)
	return 尺寸.y + 行距 * (行数 - 1)


func _剩余时间(过期秒: int) -> String:
	var 剩 := 过期秒 - int(Time.get_unix_time_from_system())
	if 剩 <= 0:
		return Time.get_datetime_string_from_unix_time(过期秒, true).substr(0, 10)
	var 天 := 剩 / 86400
	var 时 := (剩 % 86400) / 3600
	var 分 := (剩 % 3600) / 60
	var 秒 := 剩 % 60
	if 天 > 0:
		return "%d天%d小时" % [天, 时]
	if 时 > 0:
		return "%d小时%d分" % [时, 分]
	return "%d分%d秒" % [分, 秒]
