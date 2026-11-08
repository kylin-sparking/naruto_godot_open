extends Control
## 摊位列表的一行（原版 `StallListItemRenderer`，行 **442×22**、`rowHeight = 22`）。
## 逐件真值 = `真值/窗口/摊位列表.md` §④（每条算式带 `StallListItemRenderer.as` 行号）。
## 数据驱动的行 ⇒ 不烘场景（同 `摊位行.gd` 的做法）；本文件只做美术与选中，不碰协议。

signal 被双击(行: Dictionary)
signal 被点击(行: Dictionary)

const 行宽 := 442.0
const 行高 := 22.0
const 悬停皮 := "res://素材/界面/原版窗口/通用控件/选中条1.png"		# MSelected_background1 tag705
const 白 := Color(1, 1, 1, 1)					# `cretateLabel` 的默认 16777215
const 绿 := Color(0, 1, 0, 1)					# `:132` 65280 = 0x00FF00（摊名）
const 蓝 := Color(0.117647, 0.564706, 1, 1)		# `:133` 2003199 = 0x1E90FF（出售人）

## `createItem():121-137` 的六格（`cretateLabel(宽, x, 色)` ⇒ `setSize(w,20)`、`setPosition(x,1)`）。
## ⚠ **第七个字段 `moneynum` 原版没画**（`:131-136` 只有六枚 label，语言表也只有六个列头）
## ⇒ 货币数量在列表里看不到，得进摊才看得见。照抄，别"顺手补一列"。
const 格 := [
	["序号", 50.0, 0.0, 白],
	["摊名", 118.0, 50.0, 绿],
	["出售人", 93.0, 168.0, 蓝],
	["等级", 50.0, 261.0, 白],
	["物品数", 65.0, 311.0, 白],
	["宠物数", 65.0, 376.0, 白],
]

var 项: Dictionary = {}
var 选中 := false
var _条: NinePatchRect
var _字: Array[Label] = []


func _init() -> void:
	name = "摊位列表行"
	size = Vector2(行宽, 行高)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	## `:125-130` `MSelected_background1` 宽设 430、高设 21、`addChildAt(...,0)`、初始 hidden。
	## ⚠ **430 不是 442** —— 行比底宽 12px 是原版自己的数（`setSize()` 全文空的，行不许撑、也不许缩）。
	_条 = NinePatchRect.new()
	_条.name = "选中底"
	_条.texture = load(悬停皮) as Texture2D
	_条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_条.position = Vector2.ZERO
	_条.size = Vector2(430.0, 21.0)
	## 边距 = 符号 705 的 `DefineScalingGridTag`（7 / 7.9 / 5.35 / 5.75，与 `摊位行.gd` 同一枚）。
	## ⚠ `patch_margin_*` 必须是 **int**，写 float 运行期直接报错、函数当场中止。
	_条.patch_margin_left = 7
	_条.patch_margin_right = 7
	_条.patch_margin_top = 5
	_条.patch_margin_bottom = 5
	_条.visible = false
	add_child(_条)
	for 格序 in 格.size():
		var 字 := Label.new()
		字.name = String(格[格序][0])
		字.position = Vector2(float(格[格序][2]), 1.0)
		字.size = Vector2(float(格[格序][1]), 20.0)
		字.add_theme_font_size_override("font_size", 12)	# `:83`
		字.add_theme_color_override("font_color", 格[格序][3])
		字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER	# `:84` align = "center"
		字.vertical_alignment = VERTICAL_ALIGNMENT_TOP			# Flash TextField 顶对齐（工程既有口径）
		字.clip_text = true
		字.text_overrun_behavior = 0		# OVERRUN_DISABLE：不缩字，靠 clip 裁在框里（= wordWrap=false）
		字.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(字)
		_字.append(字)
	mouse_entered.connect(func(): _条.visible = true)		# `:64-67` overHandler
	mouse_exited.connect(_移开)							# `:69-75` outHandler（选中那行不隐）


## `data` setter `:99-110` + `listData` setter `:57-62`。
## `序` = 页内序号（0 起）；原版序号那一格写的是 `currentPage * pageSize + index + 1`，
## 而 `currentPage` 是 **0 基**（`StallListWindow.as:82 _currentPage = 0`、`:111` 的 `> 0` 判首钮）。
func 填(行: Dictionary, 序: int, 页码: int) -> void:
	项 = 行
	_字[0].text = str(页码 * 11 + 序 + 1)
	_字[1].text = String(行.get("stall_name", ""))
	_字[2].text = String(行.get("player_name", ""))
	_字[3].text = str(int(行.get("player_level", 0)))
	_字[4].text = str(int(行.get("itemnum", 0)))
	_字[5].text = str(int(行.get("petnum", 0)))


func _移开() -> void:
	if not 选中:
		_条.visible = false


func 设选中(是: bool) -> void:
	选中 = 是
	_条.visible = 是


func _gui_input(事件: InputEvent) -> void:
	if not (事件 is InputEventMouseButton):
		return
	var 按 := 事件 as InputEventMouseButton
	if not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	## 双击 = `viewStallHandler`（`:250` 只给 `_list` 挂了 `ITEM_DOUBLE_CLICK`）⇒ 直接看摊，
	## 不等「查看摊位」那一下。单击仍旧要选（`:139` 的 `selectedItem` 从哪来）。
	## ⚠ 顺序：先 `被点击` 把选中落上，再判 `double_click` —— 反过来会让双击那一下
	## 选中的是**上一行**（Godot 的双击事件与第一次按下在同一次 `_gui_input` 之前到达）。
	被点击.emit(项)
	if 按.double_click:
		被双击.emit(项)
	get_viewport().set_input_as_handled()
