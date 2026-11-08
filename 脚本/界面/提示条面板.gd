extends Control

## 原版 `MessageTipPane2`（右上角那块任务提示条）+ `UIMain2.showMessageTipPane2` 那一族。
##
## 本工程只接**任务两档**（11 接取 / 12 交付）——原版另有十余档（奖励/背包满/称号…），
## 那些档的入口在别的页，没到就先不建空壳。
##
## 为什么非做不可（2026-10-10 查实）：设置里那枚「关闭自动提交任务」在原版**不是**
## 「不走路」，而是「把提示条显示出来等你点确定」——`MessageTipPane2.as:386-427` 的
## `isAutoQuestFun()` 只有 `closeCommitQuest == false` 那一支才 `visible = false` +
## 自动 `__onOkClick(null)`；勾上那一支是 `visible = true` + `addChild(okBtn)`。
## 走路这个动作挂在 `__onOkClick` 上，**没有这块本体，那一档就没地方落**。
## 而且 `TYPE_ACCEPT_QUEST` 还有一条例外：**环任务即使没勾也不自动点**（`:392`），
## 所以默认设置下接日环/周环/家族任务也会弹这块 ⇒ 不做等于这两档全丢。

signal 确定点击(类型: int, 任务号: int)

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 底板皮 := 皮肤表.提示条底板
const 关闭皮 := 皮肤表.关闭按钮
## 那颗 X 的交互态状态机：`MWindowCloseBtnF`（symbol7）`extends MButton3` ⇒ 一族一张皮 +
## 运行时 `getLightFilter`（over +30 / down −40，`StyleUtil.as:7-12`）。Godot 侧只能预烘派生皮再换皮，
## `texture_hover`（松手仍亮）与 `modulate`（乘性）都不许用 —— 见 `脚本/界面/组件/原版三态钮.gd` 文件头。
const 三态皮 := preload("res://脚本/界面/组件/原版三态钮.gd")

## 档位号逐字照 `MessageTipPane2.as:61/63`
const 档接取 := 11
const 档交付 := 12

## 文案真值 = `en_US$message_properties.as`：
##   标题 :1089 DATA_TITLE_12「接受【%1】任务」/ :1087 DATA_TITLE_13「【%1】完成任务」
##   钮字 :761 DATA_BTNTEXT_12「前往任务地点」/ :760 DATA_BTNTEXT_13「回复任务」
## `%1` 由 `CN.replaceString` 换成任务名（`CN.as:5392-5405`），这里用 `%s` 表达同一件事。
## ⚠ 这两档**只有标题 + 钮**，正文 `contentText` 从头到尾没赋值（`setData:541-544`、
##   `onQuestDataReady:451-463`）⇒ 那块绿字提示文案（DATA_CONTENT_12/13）在任务档**不显示**。
const 标题表 := {档接取: "接受【%s】任务", 档交付: "【%s】完成任务"}
const 钮文表 := {档接取: "前往任务地点", 档交付: "回复任务"}
## 标题色 = `createTitleTF(param1, param2:uint = 16776960)` 的默认值（`:578`）= #FFFF00
const 标题色 := Color(1.0, 1.0, 0.0, 1.0)

## ── 版式：`MessageTipPane2.as:150-207` 的 `draw()` 逐行 ──────────────────
##   `_loc1_ = 27`（:162）
##   标题 y = 27（:170），随后 `_loc1_ += titleText.height + 5`（:171）
##   正文 y = _loc1_（:185），随后 `_loc1_ += contentText.height + 5`（:186）
##   钮   y = _loc1_（:190），随后 `_loc1_ += okBtn.height + 15`（:191）
##   `background.height = _loc1_`（:204）⇒ 整块高就是这么累加出来的
##   宽：任务档正文是空的 ⇒ 走 :167 那一支 `background.width = titleText.width + 20`
## 标题/正文的行高：TextFormat 没写 size（`createUI:323-327` 只给了 align/leading）
## ⇒ 取 Flash 默认 12px 宋体，单行 textHeight 实测 15（本工程既有口径，小地图面板.gd:40-43）；
##   正文是**空** TextField，autoSize 下只剩 TextField 自带的上下 2px 内缩 ⇒ 高 4
##   （同「盒高 = 15n + (n−1)·leading + 4」那条公式里 n=0 的情形）。
const 顶 := 27.0
const 标题高 := 15.0
const 正文高 := 4.0
const 件距 := 5.0
const 钮高 := 22.0
const 钮底距 := 15.0
const 标题富余 := 20.0
## `MButton3.as:383` `measure()`：`isScale9Grid == true ⇒ _width = tf.width + 6`
const 钮字富余 := 6.0
## `draw():205-206`（**覆盖** MWindow 那条 −6 / 标题Y+1）：`closeBtn.x = 宽 − 钮宽 − 5`、`y = 5`
const 关闭右距 := 5.0
const 关闭上距 := 5.0
## `UIMain2.as:2659-2660`：`x = STAGE_WIDTH − width`、`y = smallMapWindow.height + 70`
const 小地图下距 := 70.0

## 每条 = `{"节点": Control, "类型": int, "任务号": int, "块": Rect2}`。
## ⚠ 不用 `set_meta`：Godot 4 的 metadata 键要求合法标识符，中文键**静默存不进去**
##   （本工程踩过，见 flash-mbutton3-state-skins skill 第 5 步那条警告）。
var _条: Array = []
var _小地图高 := 0.0


func _init() -> void:
	name = "提示条层"
	## 层本身不吃鼠标（原版这些条是 `addChild` 在 content 上、旁边该点还是能点），
	## 每**一条**自己 `MOUSE_FILTER_STOP`。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 小地图那一块当前多高 ⇒ 决定 y。原版直接读 `smallMapWindow.height`，
## 而小地图可折叠 ⇒ 折叠态高度不同、提示条会跟着往上挪，这里保持同一口径。
func 报小地图高(高: float) -> void:
	_小地图高 = 高


func 条数() -> int:
	return _条.size()


## 对应 `UIMain2.showMessageTipPane2(类型, 数据)`（`:2627-2664`）。
## 返回 `{"自动点了": bool, "建了": bool}` —— 「自动点了」就是原版那次
## `__onOkClick(null)`，走路这件事统一从 `确定点击` 信号出去（玩家点/自动点同一份代码）。
func 显示(类型: int, 任务号: int, 任务名: String, 环任务: bool, 自动交接: bool) -> Dictionary:
	for 存 in _条:
		if int(存["类型"]) == 类型 and int(存["任务号"]) == 任务号:
			return {"自动点了": false, "建了": false}
	var 新 := _建一条(类型, 任务号, 任务名)
	add_child(新["节点"])
	_条.append(新)
	摆位()
	## `isAutoQuestFun()`（`:386-427`）：
	##   接取档 = 没勾「关闭自动提交」**且不是环任务** ⇒ 隐藏 + 自动点确定；
	##   交付档 = 没勾 ⇒ 隐藏 + 自动点确定（环任务那条例外只管接取档，交付档没有）。
	var 自动 := 自动交接 and not (类型 == 档接取 and 环任务)
	if 自动:
		(新["节点"] as Control).visible = false
		点确定(类型, 任务号)
		return {"自动点了": true, "建了": true}
	return {"自动点了": false, "建了": true}


## 对应 `UIMain2.removeQuestRightTips(类型, questId)`（`:2602-2620`）。
## 传 类型 = −1 ⇒ 两档都清（`QuestDataManager:130-131/374-375/706-707` 就是 11、12 各清一遍）。
func 移除任务提示(类型: int, 任务号: int) -> int:
	var 清 := 0
	var 留: Array = []
	for 存 in _条:
		var 同类型 := 类型 < 0 or int(存["类型"]) == 类型
		if 同类型 and int(存["任务号"]) == 任务号:
			(存["节点"] as Control).queue_free()
			清 += 1
		else:
			留.append(存)
	_条 = 留
	return 清


func 清空() -> void:
	for 存 in _条:
		(存["节点"] as Control).queue_free()
	_条.clear()


## 原版所有条都摆**同一个位置**（`:2659-2660` 没有堆叠偏移）⇒ 多条会重叠，
## 这是原版行为，别自作主张排成一列。
func 摆位() -> void:
	var 屏宽 := get_viewport().get_visible_rect().size.x
	for 存 in _条:
		var 块: Rect2 = 存["块"]
		(存["节点"] as Control).position = Vector2(屏宽 - 块.size.x, _小地图高 + 小地图下距)


## 给量具看的一条几何（不靠运行期节点树，直接按公式重算一遍给门比）。
static func 算块(类型: int, 任务名: String) -> Dictionary:
	var 标题文 := (标题表[类型] as String) % 任务名
	var 钮文 := 钮文表[类型] as String
	var 标题宽 := _字宽(标题文)
	var 钮宽 := _字宽(钮文) + 钮字富余
	var 块宽 := 标题宽 + 标题富余
	var 块高 := 顶 + 标题高 + 件距 + 正文高 + 件距 + 钮高 + 钮底距
	return {
		"标题文": 标题文, "钮文": 钮文,
		"宽": 块宽, "高": 块高, "标题宽": 标题宽,
		"标题位": Vector2(floori((块宽 - 标题宽) / 2.0), 顶),
		"钮位": Vector2(floori((块宽 - 钮宽) / 2.0), 顶 + 标题高 + 件距 + 正文高 + 件距),
		"钮宽": 钮宽,
	}


func _建一条(类型: int, 任务号: int, 任务名: String) -> Dictionary:
	var 几 := 算块(类型, 任务名)
	var 块宽 := float(几["宽"])
	var 块高 := float(几["高"])
	var 条 := Control.new()
	条.name = "提示条"
	条.size = Vector2(块宽, 块高)
	条.mouse_filter = Control.MOUSE_FILTER_STOP

	var 底 := Panel.new()
	底.name = "底板"
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	底.size = Vector2(块宽, 块高)
	底.add_theme_stylebox_override("panel", _九宫格(底板皮))
	条.add_child(底)

	## 层序照 `createUI:334-336`（background → closeBtn → contentText）
	## 再 `createTitleTF` / `createOkBtn` 各自 addChild ⇒ 标题、钮在最上面。
	var 关 := TextureButton.new()
	## `set_script` 要在**设皮之前**：状态机在 `_ready()`（= `add_child` 那一刻）抄常态皮当主干，
	## 皮晚设一步就抄不到 ⇒ 它认定"这颗没有可换的皮"，整条静默不接（不报错，看着像悬停没做）。
	关.set_script(三态皮)
	关.name = "关闭"
	关.texture_normal = load(关闭皮) as Texture2D
	关.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND		# `MButton3.init()` `:135`
	关.focus_mode = Control.FOCUS_NONE
	var 关宽 := 关.texture_normal.get_size().x
	关.size = Vector2(关宽, 关.texture_normal.get_size().y)
	关.position = Vector2(块宽 - 关宽 - 关闭右距, 关闭上距)
	关.pressed.connect(_点关闭.bind(类型, 任务号))
	条.add_child(关)

	var 题 := Label.new()
	题.name = "标题"
	题.mouse_filter = Control.MOUSE_FILTER_IGNORE
	题.add_theme_color_override("font_color", 标题色)
	题.add_theme_font_size_override("font_size", 12)
	题.text = String(几["标题文"])
	题.size = Vector2(float(几["标题宽"]), 标题高)
	题.position = 几["标题位"] as Vector2
	条.add_child(题)

	var 钮 := Button.new()
	钮.name = "确定"
	钮.text = String(几["钮文"])
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.size = Vector2(float(几["钮宽"]), 钮高)
	## `:189` 的 `background.width - okBtn.width >> 1` 是 AS3 的**整除**
	## （`>>` 优先级低于 `-`）⇒ 用 floori 而不是 round。
	钮.position = 几["钮位"] as Vector2
	钮.pressed.connect(点确定.bind(类型, 任务号))
	条.add_child(钮)
	return {"节点": 条, "类型": 类型, "任务号": 任务号, "块": Rect2(0, 0, 块宽, 块高)}


## 玩家点「确定」与原版那次自动 `__onOkClick(null)` **共用这一个入口**。
func 点确定(类型: int, 任务号: int) -> void:
	## `__onOkClick` 末尾无条件 `onCloseBtnClick(null)`（`:306`）⇒ 点完自己收掉。
	移除任务提示(类型, 任务号)
	确定点击.emit(类型, 任务号)


func _点关闭(类型: int, 任务号: int) -> void:
	## X 只派发 `CLOSE_PANE`（`MessageTipPane2.as:144-148`），**不走** `__onOkClick`
	## ⇒ 关掉它不会走路。这条是「勾了关闭自动交接、又不想跑」的唯一出口。
	移除任务提示(类型, 任务号)


func _九宫格(路: String) -> StyleBoxTexture:
	var 皮 := StyleBoxTexture.new()
	皮.texture = load(路) as Texture2D
	var 边: Array = 皮肤表.九宫格[路]
	## 本工程 九宫格 表四条的顺序是 [左, 右, 上, 下]（见 原版皮肤表.gd 那张表）
	皮.texture_margin_left = float(边[0])
	皮.texture_margin_right = float(边[1])
	皮.texture_margin_top = float(边[2])
	皮.texture_margin_bottom = float(边[3])
	## content_margin **必须显式写 0**：不写会取 texture_margin，把件顶到四条边距那么宽
	## （本工程踩过两次，见 开发工具/生成创建角色场景.py 的 九宫格块 注释）。
	for 项 in ["left", "top", "right", "bottom"]:
		皮.set("content_margin_%s" % 项, 0.0)
	return 皮


## Flash 12px 的字宽：中日韩全角 12、其余半角 6（同 好友菜单.gd:117-121 那份口径）。
static func _字宽(文: String) -> float:
	var 尺 := 0.0
	for i in 文.length():
		if 文.unicode_at(i) > 0x2E80:
			尺 += 12.0
		else:
			尺 += 6.0
	return 尺
