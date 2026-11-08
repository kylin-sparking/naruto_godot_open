extends RefCounted

## 英雄榜 = 原版 `com/mxw/uifl/controls/pvp/PvpRankWindow`（**380×400**，标题「英雄榜」）
## 加行渲染器 `PvpRankItemRenderer`（`CommonItemRenderer(320,23,null)` 四列 40/140/80/60）。
##
## 数据来自 `2306:9`（`_send_arena_heroes:29304-29325`，一行 5 段 = `PkHero.decode`：
## `排名&角色号&等级&名字&趋势`，≤100 行）。上行 `2306:4` = `PK_searchHeroPaiHang`。
##
## ★ 开窗时序照抄原版：`showPvpRankWindow:88-96` 是 `reverseDisplay` **之后**再
##   `if (windowMap[PVP_RANK_WINDOW]) PK_searchHeroPaiHang()` ⇒ 第一次点也会发（窗在那一步已经建好）。
##   所以"开窗即拉"放在 `渲染()` 的末尾，别改成先查后开。
##
## ★ 原版这扇**没有任何行内点击**（`PvpRankWindow` 只挂了 `onCloseBtnClick`，`List` 没接
##   `ITEM_CLICK`）⇒ 不做选中跳转、不做行菜单；`fl.controls.List` 那层选中高亮因此也不移植
##   （点了没功能，画出来反而多一版我们自己对不上的态）。
##
## 逐件坐标：`真值/窗口/竞技场.md` §15（页面局部 = AS3 − 29，`整框: true`）。

const 竞技场窗 := preload("res://脚本/界面/窗口/竞技场窗.gd")

const 行高 := 23.0				# `:39` list.rowHeight = 23；渲染器 `super(320,23,null)`
const 行宽 := 320.0
const 列宽 := [40.0, 140.0, 80.0, 60.0]		# `PvpRankItemRenderer.createItem` 四段
const 色白 := Color(1, 1, 1)			# UIConfig.UI_WHITE 16777215
const 色中 := Color(0.988235, 0.764706, 0.6)	# UIConfig.UI_ZHONG_SE 16565145 = #FCC399（名字那一列）
const 色绿 := Color(0, 1, 0)			# `:33` trend==0 ⇒ `<font color='#00ff00'>↑</font>`
const 色红 := Color(1, 0, 0)			# `:35` trend==1 ⇒ `#ff0000` ↓
const 色灰 := Color(0.8, 0.8, 0.8)		# `:37` 其余 ⇒ `#cccccc` -

static var 页: Control = null


static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	页 = 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 关 := 页.get_node("关闭钮") as TextureButton
	关.pressed.connect(_关.bind(宿主))
	关.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_装三态(关)
	填()
	## 开窗即拉（原版 `reverseDisplay` 之后那一支 `if` 恒真）
	var 后: Node = 宿主.get("_backend") as Node
	if 后 != null and 后.has_method("request_arena_heroes"):
		后.call("request_arena_heroes")
	return 页


static func _关(宿主: Node) -> void:
	宿主.call("close")


## `2306:9` 回来时由 `竞技场窗._刷英雄榜()` 喊（**原地重排行，不拆页**，同一族坑见 #312）。
static func 喂() -> void:
	填()


static func 填() -> void:
	if 页 == null or not is_instance_valid(页):
		return
	var 列 := 页.get_node("滚动区/行列") as Control
	for 子 in 列.get_children():
		列.remove_child(子)
		子.queue_free()
	var 榜: Array = 竞技场窗.英雄榜
	列.custom_minimum_size = Vector2(行宽, maxf(277.0, 榜.size() * 行高))
	列.size = 列.custom_minimum_size
	for 序 in 榜.size():
		列.add_child(_行(序, 榜[序] as Dictionary))


static func _行(序: int, 条: Dictionary) -> Control:
	var 行 := Control.new()
	行.name = "行%d" % (序 + 1)
	行.position = Vector2(0.0, 序 * 行高)
	行.size = Vector2(行宽, 行高)
	_格(行, 0, str(int(条.get("pkLevel", 0))), 色白)
	_格(行, 1, String(条.get("name", "")), 色中)
	_格(行, 2, str(int(条.get("charLevel", 0))), 色白)
	var 势 := int(条.get("trend", 2))
	if 势 == 0:
		_格(行, 3, "↑", 色绿)
	elif 势 == 1:
		_格(行, 3, "↓", 色红)
	else:
		_格(行, 3, "-", 色灰)
	return 行


static func _格(行: Control, 列号: int, 文: String, 色: Color) -> void:
	var 起 := 0.0
	for 序 in 列号:
		起 += 列宽[序]
	var 字 := Label.new()
	字.name = ["排名", "名字", "等级", "趋势"][列号]
	字.text = 文
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.position = Vector2(起, 0.0)
	字.size = Vector2(列宽[列号], 行高)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", 色)
	行.add_child(字)


## 关闭那颗 = `MButtonF`（本工程预烘的 钮底61 三档；`text = DIALOG_BTN_STOP_DIALOG`「关闭」）
static func _装三态(钮: TextureButton) -> void:
	钮.texture_hover = load("res://素材/界面/原版窗口/家族/钮底61_悬停.png") as Texture2D
	钮.texture_pressed = load("res://素材/界面/原版窗口/家族/钮底61_按下.png") as Texture2D
