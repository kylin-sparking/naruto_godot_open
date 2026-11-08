extends Control
## 邀请托盘里的一格 = 原版 `CueGird`（`com/mxw/uifl/controls/CueGird.as`）。
## 逐件出处见 `真值/窗口/交易与邀请托盘.md` §⑧。本文件只画格、不管排队 ——
## 排队/去重/上限/补间全在 `邀请托盘.gd`（原版那边分别是 `CueManage` 与 `CueGird`）。
##
## 层栈（`init():139-204` 的 addChild 顺序）：命中底 → 图标 → 光晕。
## ⚠ 图标 **46×46 画在 (0,0)**，而命中盒只有 40×40 ⇒ 图标每边溢出 3px，
##   这不是 bug：原版就是这么叠的，别把图标缩进 40 里。

## 点了这一格。`流水号` 是 `CueGird.FLAG_ID` 那种**格自己的序号**（`:58,84-85`），
## 不是玩家号 —— 托盘按它找格、挪旁边那些格。
signal 被点击(类型: int, 流水号: int, 数据: Dictionary)
signal 悬停(类型: int, 显: bool)

const 命中边 := 40.0			# `GRID_CLICK_SIZE`（`:60`）
const 图标边 := 46.0
## 光晕就是装备格上那圈 `EquipAnimationF`，复用同一件（帧数据在 `数据/装备品质.json` 的「流光」）
const 品质流光 := preload("res://脚本/界面/组件/品质流光.gd")
const 品质表 := preload("res://脚本/单例/装备品质.gd")

## 命中底：`graphics.beginFill(0, 0.01)` + `drawRect(0,0,40,40)`（`:142-144`）。
## 0.01 的 alpha 看不见，但它让这一格有命中区（原版 Sprite 靠绘出的形状吃鼠标）。
const 命中底色 := Color(0.0, 0.0, 0.0, 0.01)

var 类型 := 0
var 流水号 := -1
var 数据: Dictionary = {}
var 图标路径 := ""
var 提示文字 := ""


func _init(类: int = 0, 号: int = -1, 数据字典: Dictionary = {}, 图标 := "", 提示 := "") -> void:
	类型 = 类
	流水号 = 号
	数据 = 数据字典
	图标路径 = 图标
	提示文字 = 提示
	custom_minimum_size = Vector2(命中边, 命中边)
	size = Vector2(命中边, 命中边)
	# `buttonMode = true`（`:83`）⇒ 手型光标
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var 底 := ColorRect.new()
	底.name = "命中底"
	底.color = 命中底色
	底.size = Vector2(命中边, 命中边)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(底)

	if not 图标路径.is_empty() and ResourceLoader.exists(图标路径):
		var 图 := TextureRect.new()
		图.name = "图标"
		图.texture = load(图标路径) as Texture2D
		## `normalizeIcon:166-190`：超过 40 就等比缩进 40，然后**居中**（x=(40−w)/2）。
		## 我们的图标天然 46×46 ⇒ 显示 40×40、落 (0,0)。之前直接按 46 画，等于把格子撑破，
		## 流光再怎么摆都对不上（用户 2026-10-25 第二次报"流光还是偏"）。
		var 图源 := 图.texture
		var 源尺 := 图源.get_size() if 图源 != null else Vector2(图标边, 图标边)
		var 缩 := 1.0
		if 源尺.x > 命中边 or 源尺.y > 命中边:
			缩 = minf(命中边 / 源尺.x, 命中边 / 源尺.y)
		var 显示尺 := 源尺 * 缩
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.stretch_mode = TextureRect.STRETCH_KEEP
		图.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(图)
		## ⚠ 顺序要紧：`expand_mode`/`stretch_mode` 一改就会重算最小尺寸，
		##   若先设 size 再改模式，size 会被**顶回纹理原始尺寸**（实测 40 被顶回 46）。
		##   ⇒ 进树之后再钉 size，并且同时把 `custom_minimum_size` 压到 0。
		图.custom_minimum_size = Vector2.ZERO
		图.size = 显示尺
		图.position = (Vector2(命中边, 命中边) - 显示尺) * 0.5

	# `gridAnimation = new EquipAnimationF()` @ (3,3)，mouseChildren/mouseEnabled = false（`:194-196`）
	var 光 := 品质流光.new()
	光.name = "光晕"
	## ⚠ `AnimatedSprite2D.centered` 默认 **true**（帧以节点原点为中心）⇒ 46×46 的流光帧
	##   摆在 (3,3) 会从 (−20,−20) 画起，整块甩到图标左上方外面（用户 2026-10-25 报的"流光偏了"）。
	##   改成左上角注册，再按**实际帧尺寸**把它居中盖在图标上 —— 帧换尺寸也不会再偏。
	光.centered = false
	# ⚠ 不给它设 `mouse_filter` —— `AnimatedSprite2D` 是 Node2D 不是 Control，
	# 根本没有这个属性（设了就是运行期报错、整格建不出来）。Node2D 本来也不吃 GUI 命中，
	# 等价于原版那句 `mouseEnabled = false`。
	add_child(光)
	光.播(品质表.流光帧集(), true)
	## `CueGird.as:243-251`：**硬编码 (3,3)**，帧 35×35（`数据/装备品质.json` 的「流光」尺寸）
	## ⇒ 3+35=38，右/下各余 2 —— 原版这个不对称就是这么来的，照搬，别再自己算居中。
	光.position = Vector2(3.0, 3.0)

	mouse_entered.connect(func() -> void: 悬停.emit(类型, true))
	mouse_exited.connect(func() -> void: 悬停.emit(类型, false))
	gui_input.connect(_收鼠标)


## 左键按下即算点中（原版是 `MouseEvent.CLICK`，`:89`）。
## 用按下不用 released：这一格点完**立刻自删**（`onClickHand:349-350`），
## 松手时节点已经不在了，release 事件根本回不来。
func _收鼠标(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton:
		var 键 := 事件 as InputEventMouseButton
		if 键.button_index == MOUSE_BUTTON_LEFT and 键.pressed:
			被点击.emit(类型, 流水号, 数据)
