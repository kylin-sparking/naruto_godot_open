extends Control
## 原版 `MDialog`（`com/mxw/uifl/base/controls/MDialog.as`）的消息档
## = `showMessageDialog(…, OK|CANCEL)`。逐件出处见 `真值/窗口/交易与邀请托盘.md` §⑨。
##
## 三条最容易自造的地方：
## 1. 它 **不是 MWindow**（`MDialog.as:17 extends Sprite`）⇒ 没有标题栏、没有关闭叉，
##    底板用的是自己那张 `MDilog_bgSkin`（MainLib 符号 184），**不是** `窗口边框`。
## 2. 高度是**算出来的**，不是设计期值：`panelHeight = 正文盒底 + BOTTOM_HEIGHT(50)`，
##    而正文盒底 = `14 + (15n + 8)` ⇒ **单行 = 302×87**，两行 = 302×102。
##    写死一个高度 = 两行文案时把字裁掉。
## 3. 两颗钮的 x 是**绝对**的：确定 77、取消 186（`:421` / `:486`）——
##    原版只有"只有一颗时才居中"（`:228-238`），两颗都在时不居中。别排成居中的 HBox。

## 三块皮的来源（`MDilog_bgSkin` 302×134 / `MYellow_background` / `好友/钮底30` 三档）
## 与两颗钮的字色 `#fcf49c`、手型光标都**烘在 `.tscn` 里** —— 工程有条门
## （`UI资源回归测试.gd`）禁止在 `.gd` 里现造 StyleBox 去压全局主题。

## §⑨ 的常量（后面括号是 AS3 行号）
const 窗宽 := 302.0				# `:341` bg1.width
const 内容间隙 := 6.0			# `:345` bg2.x = bg2.y
const 内容宽 := 283.0			# `:346`
const 文字x := 14.0				# `:522` = bg2.x + CONTENT_GAP(8)
const 文字y := 14.0				# `:523`
const 文字宽 := 267.0			# `:515` = CONTENT_WIDTH(283) − 8×2
const 文字加高 := 8.0			# `:411` textArea.height = textHeight + 8
const 底部高 := 50.0				# `:34` BOTTOM_HEIGHT
const 边框间隙 := 5.0			# UIConfig.BORDER_GAP
const 钮下留 := 8.0				# `:207` 里的 `- 8`
const 钮宽 := 30.0
const 钮高 := 22.0
const 确定x := 77.0				# `:421`
const 取消x := 186.0				# `:486`
const 底边距 := [28, 30, 33, 33]	# DefineScalingGridTag(184) 左/右/上/下（上下原生 33.5 ⇒ 取整）
const 行盒 := 15.0				# Flash 宋体 12px 行盒（工程既有口径）

@onready var _主体: Control = $主体
@onready var _底: NinePatchRect = $主体/底
@onready var _内容: NinePatchRect = $主体/内容底
@onready var _文字: RichTextLabel = $主体/正文
@onready var _确定: Button = $主体/确定钮
@onready var _取消: Button = $主体/取消钮

var _确认回调 := Callable()
var _取消回调 := Callable()


func _ready() -> void:
	$暗层.gui_input.connect(_收暗层)
	_确定.pressed.connect(_点确认)
	_取消.pressed.connect(_点取消)
	visible = false


## 弹出。`正文` 必须是**已经翻成 BBCode** 的串（原版这里喂的是 htmlText）。
## `取消回调` 留空 = 没有「取消」这一档（原版 `showMessageBox` 只有 OK 时就是单钮，
## 且那颗钮改成居中 —— 收花托盘那一格走的就是这一档，`MarryTableManager.xianhuaHandler:279`）。
func 弹出(正文: String, 确认文字: String, 确认回调: Callable,
		取消文字 := "取消", 取消回调 := Callable()) -> void:
	_确认回调 = 确认回调
	_取消回调 = 取消回调
	_文字.text = 正文
	var 行数 := _量行数()
	var 盒高 := 行盒 * float(行数) + 文字加高
	var 内容高 := 文字y + 盒高
	var 窗高 := 内容高 + 底部高
	_主体.size = Vector2(窗宽, 窗高)
	# `PopUpMananger.centerWindow` ⇒ 舞台里居中；奇偶差用 floorf（同 `_弹出确认` 的口径）
	var 舞台 := get_viewport().get_visible_rect().size
	_主体.position = Vector2(floorf((舞台.x - 窗宽) * 0.5), floorf((舞台.y - 窗高) * 0.5))
	_底.size = Vector2(窗宽, 窗高)
	_内容.position = Vector2(内容间隙, 内容间隙)
	_内容.size = Vector2(内容宽, 内容高)
	_文字.size = Vector2(文字宽, 盒高)
	var 钮y := 窗高 - 钮高 - 边框间隙 - 钮下留
	## 单钮档要**居中**（`MDialog:228-238`：只有"不是同时有确定和取消"时才重摆 x，
	## 而 OK 单独那颗是 `(DIALOG_WIDTH − 钮宽)/2`）。两钮档保持 77 / 186 那两个绝对值。
	var 钮x := 确定x
	if not _取消回调.is_valid():
		钮x = (窗宽 - 钮宽) * 0.5
	_确定.position = Vector2(钮x, 钮y)
	_确定.size = Vector2(钮宽, 钮高)
	_确定.text = 确认文字
	_取消.position = Vector2(取消x, 钮y)
	_取消.size = Vector2(钮宽, 钮高)
	_取消.text = 取消文字
	_取消.visible = _取消回调.is_valid()
	visible = true


## 行数按**真实字体**量：Flash 那边是 `wordWrap` 折行后的 `textHeight`，
## 这里用同一折行宽（267）量墨迹高再除以行盒、四舍五入取整行。
## ⚠ 只借它的**行数**，高度一律按 Flash 行盒 15 算（Godot 这套 SimSun 量得 13，
##   直接拿 13n 会把面板越算越矮 —— 见 `文字提示框.gd` 同一段换算注释）。
func _量行数() -> int:
	var 纯 := _文字.get_parsed_text()
	var 字体 := _文字.get_theme_font("normal_font")
	var 单行 := 字体.get_height(12)
	var 量 := 字体.get_multiline_string_size(纯, HORIZONTAL_ALIGNMENT_LEFT, 文字宽, 12)
	return 1 if 单行 <= 0.0 else maxi(1, int(round(量.y / 单行)))


func 收起() -> void:
	visible = false


func 高度() -> float:
	return _主体.size.y


func _点确认() -> void:
	var 回调 := _确认回调
	收起()
	if 回调.is_valid():
		回调.call()


func _点取消() -> void:
	var 回调 := _取消回调
	收起()
	if 回调.is_valid():
		回调.call()


## 点遮罩：原版 modal 只挡不关（`showMessageDialog` 的 cancel 只有点「取消」才发）
## ⇒ 这里什么都不做，只把事件吃掉，免得穿透到下面的窗口。
func _收暗层(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
