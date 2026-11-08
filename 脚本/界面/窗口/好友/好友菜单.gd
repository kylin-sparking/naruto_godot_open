extends Control

## 好友行菜单（原版 `MPopupMenu`，版式见真值 §6.4；项表见 §4）。
## 关键口径：
##   * `MARGIN=3`、项高 = 皮高 19、`bgWidth = max(钮宽) + 6`、二遍把项宽改成 `bgWidth − 6`；
##   * **空文本项 = 一条分隔线**（`MPM:187-189` 塞的是 `LineHPicF`），高 2、占位 `+3`；
##   * 底 `MPopupMenu_background`(590) 边距 5.75/4.75/9.75/11，尺寸再 **+4 宽 / +5 高**（`MPM:87-91`）；
##   * 项 = `MPopupMenuButtonF` **extends MButton（不是 MButton3）** ⇒ 没有 ±30/−40 亮度档，
##     up/over/down 三色被设成同一个（`MPM:179`）⇒ 悬停只换皮、不换字色。
## 只做美术：点项只发信号，动作交回 `好友窗口.gd` → 宿主。

signal 项点击(文本: String, 项: Dictionary)

const 底皮 := "res://素材/界面/原版窗口/通用控件/菜单底.png"		# tag590 39×83
const 项皮 := "res://素材/界面/原版窗口/通用控件/菜单按钮.png"		# tag585 47×19
const 项亮皮 := "res://素材/界面/原版窗口/通用控件/菜单按钮亮.png"	# 悬停皮（未证是否 tag585 的 over 帧，见真值 §8.4）
const 线皮 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"
const 边 := 3.0							# MPM:13 MARGIN
const 项高 := 19.0						# 皮高（MButton 族"高永远不变"，《度量表》§3.2:208）
const 线高 := 2.0
const 字色 := Color("#FCF49C")					# MPM:179 三态同色，取 up 档
## 项表（`FG:129-196` 按页签态 + 在线分支；文案是语言表原值，别改字）
const 项表 := {
	"好友": {"在线": ["查看", "对话", "密语", "组队", "看摊", "删除", "拉黑"], "离线": ["删除", "拉黑"]},
	"最近": {"在线": ["查看", "对话", "密语", "组队", "看摊", "删除", "拉黑"], "离线": ["删除", "拉黑"]},
	"仇人": {"在线": ["查看", "打探", "删除"], "离线": ["删除"]},
	"黑名单": {"在线": ["查看", "移除"], "离线": ["移除"]},
	"师徒": {"在线": ["查看", "对话", "密语", "组队", "看摊"], "离线": []},
}
const 赠花插位 := "删除"					# `FG:133-136` splice(len−2, 0, ZENGHUA)
const 交友插位 := 1						# `FG:148-151` 非好友时 splice(1, 0, 交友)

var _底: Panel
var _项们: Array[Control] = []
var _项: Dictionary = {}


func _init() -> void:
	name = "行菜单"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_底 = Panel.new()
	_底.name = "菜单底"
	_底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_底)


## 弹出（`FG:202-210`：先 setData，再延迟一帧按在线态重算项表并摆到鼠标处）。
func 弹出(页: Control, 页签: String, 项: Dictionary, 屏幕位: Vector2) -> void:
	var 在线: bool = bool(项.get("online", true))
	var 表: Array = 项表[页签]["在线" if 在线 else "离线"].duplicate()
	if 页签 == "好友" and 在线 and bool(项.get("flower_open", true)):
		表.insert(表.find(赠花插位), "赠花")
	if 页签 == "最近" and 在线 and not bool(项.get("is_friend", false)):
		表.insert(交友插位, "交友")
	弹出项(表, 屏幕位, 项)


## 按现成项表弹出。项可以是 `String`、`""`（分隔线），或 `{"name": …, "color": Color}`
## —— 最后一种对应原版 `MPM` 的 `{name, color}` 项（家族行的红色「弹劾族长 / 禅让族长」）。
func 弹出项(列表: Array, 屏幕位: Vector2, 上下文: Dictionary = {}) -> void:
	_项 = 上下文
	for 子 in get_children():
		if 子.name != "菜单底":
			子.queue_free()
	_项们.clear()
	if 列表.is_empty():
		visible = false
		return
	var 宽 := 0.0
	for 条 in 列表:
		宽 = maxf(宽, _字宽(_条名(条)) + 6.0)			# isScale9Grid ⇒ 钮宽 = 文字 + 6（《度量表》§3.2:202）
	var 盒 := 宽 + 6.0							# MPM:53-61 bgWidth = max(钮宽) + totalMargin(6)
	var 累 := 边
	for 条 in 列表:
		var 文 := _条名(条)
		if 文 == "":
			累 += 边
			var 线 := TextureRect.new()
			线.texture = load(线皮) as Texture2D
			线.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			线.stretch_mode = TextureRect.STRETCH_SCALE
			线.mouse_filter = Control.MOUSE_FILTER_IGNORE
			线.position = Vector2(floorf((盒 - (盒 - 6.0)) / 2.0) + 边, 累)
			线.size = Vector2(盒 - 6.0, 线高)
			add_child(线)
			累 += 线高 + 边						# MPM:78-82 累计 += 高 + 3
			continue
		var 钮 := Button.new()
		钮.name = 文
		钮.text = 文
		钮.flat = true
		钮.focus_mode = Control.FOCUS_NONE
		钮.add_theme_font_size_override("font_size", 12)
		钮.add_theme_color_override("font_color", _条色(条))
		钮.position = Vector2(边, 累)
		钮.size = Vector2(盒 - 6.0, 项高)				# MPM:76 二遍：项宽 = bgWidth − 6
		_贴皮(钮)
		钮.pressed.connect(_点.bind(文))
		add_child(钮)
		_项们.append(钮)
		累 += 项高 + 边							# MPM:50-51,78 钮 y = 累计 + 3、下一项累计 += 高 + 3
	_底.size = Vector2(盒 + 4.0, 累 + 6.0 - 边 + 5.0)		# MPM:85-91 底 = bgWidth×(累计+6)，590 号再 +4/+5
	global_position = 屏幕位		# Control.global_position 自己换算，别去碰 Window 的画布变换
	visible = true


func _条名(条: Variant) -> String:
	if 条 is Dictionary:
		return String((条 as Dictionary).get("name", ""))
	return String(条)


func _条色(条: Variant) -> Color:
	if 条 is Dictionary and (条 as Dictionary).has("color"):
		return 条["color"]
	return 字色


func _贴皮(钮: Button) -> void:
	for 态 in ["normal", "hover", "pressed"]:
		var 皮 := StyleBoxTexture.new()
		皮.texture = load(项亮皮 if 态 != "normal" and ResourceLoader.exists(项亮皮) else 项皮) as Texture2D
		for i in 4:
			皮.set("texture_margin_%s" % ["left", "top", "right", "bottom"][i], [2.25, 2, 2.5, 2.5][i])
		for i in 4:
			皮.set("content_margin_%s" % ["left", "top", "right", "bottom"][i], 0.0)
		钮.add_theme_stylebox_override(态, 皮)


func _点(文: String) -> void:
	visible = false							# MPM:120 派发后自毁
	项点击.emit(文, _项)


func _字宽(文: String) -> float:
	var 尺 := 0.0
	for i in 文.length():
		尺 += 12.0 if 文.unicode_at(i) > 0x2E80 else 6.0
	return 尺
