extends Control

## 好友列表的一行（原版 `FriendItemRenderer` 族，行高 23 = `FG:96` rowHeight）。
## 几何来自 `开发工具/生成好友场景.py` 的 `模板行`（同真值 §2）；运行期按数据建行 ⇒ 不进场景。
## 只做美术：点击/双击只发信号，动作由 `好友窗口.gd` 交回宿主，不碰协议。

signal 点击(项: Dictionary, 屏幕位: Vector2)
signal 双击(项: Dictionary)

const 行宽 := 265.0
const 选中皮 := "res://素材/界面/原版窗口/通用控件/选中条1.png"		# tag705，逐像素已核同源
const 灰度 := preload("res://脚本/界面/组件/禁用灰度.gdshader")	# 与意志页头像同一份 getDisableFilter 近似
const 职业 := preload("res://脚本/单例/职业.gd")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const 文案 := preload("res://脚本/界面/窗口/好友/好友文案.gd")
const 列位 := [[25, 2, 90], [115, 2, 75], [190, 2, 55]]		# FI:142-156（仇人态列二 x 多 10，见 填()）
const 列色 := Color(1, 1, 1, 1)					# FI:23 TEXT_COLOR = #FFFFFF

var _项: Dictionary = {}
var _条: NinePatchRect
var _列: Array[Label] = []


func _init() -> void:
	custom_minimum_size = Vector2(行宽, 23.0)
	size = custom_minimum_size
	_条 = NinePatchRect.new()
	_条.name = "选中条"
	_条.position = Vector2(2.0, 1.0)				# FI:173-174
	_条.size = Vector2(246.0, 23.0)				# FI:177 background.width = 246
	_条.texture = load(选中皮) as Texture2D
	for i in 4:
		_条.set("patch_margin_%s" % ["left", "top", "right", "bottom"][i], [7, 5.35, 7.9, 5.75][i])
	_条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_条.visible = false
	add_child(_条)
	var 头 := TextureRect.new()
	头.name = "头像"							# FI:82-89 PortraitHead 20×20 @ (15,13)
	头.position = Vector2(15.0, 13.0)
	头.size = Vector2(20.0, 20.0)
	头.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	头.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	头.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(头)
	for i in 3:
		var 列 := Label.new()
		列.name = ["名列", "列二", "列三"][i]
		列.position = Vector2(列位[i][0], 列位[i][1])
		列.size = Vector2(列位[i][2], 20.0)
		列.add_theme_font_size_override("font_size", 12)
		列.add_theme_color_override("font_color", 列色)
		列.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_CENTER
		列.clip_text = true
		列.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(列)
		_列.append(列)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _条.visible = true)		# FI:67-70 ROLL_OVER
	mouse_exited.connect(func(): _条.visible = false)		# FI:120-126 ROLL_OUT（未选中则隐）
	gui_input.connect(_输入)


## `data` setter（FI:72-113）：头像按 face、三列按页签态取不同字段、离线整行套灰度滤镜。
func 填(项: Dictionary, 页签: String, _序: int) -> void:
	_项 = 项
	var 名 := String(项.get("name", ""))
	_列[0].text = 名
	if bool(项.get("couple", false)):				# FI:92 羁绊前缀（文案自带【】；AS3 是黄色，Label 不支持分段着色）
		_列[0].text = 文案.取("FRIEND_FUQI") + 名
	var 仇 := 页签 == "仇人"
	_列[1].text = str(int(项.get("level", 1)))			# 好友/仇人：列二 = 等级（FI:98 / EI:134-138）
	_列[2].text = str(int(项.get("intimacy", 0)))		# 好友=亲密度、仇人=仇恨度
	if 页签 == "黑名单" or 页签 == "最近":			# OtherItemRenderer：列二=职业、列三=等级（OI:138-152）
		_列[1].text = 职业.取(int(项.get("job", 0)))
		_列[2].text = str(int(项.get("level", 1)))
	if 仇:
		_列[1].position.x = 125.0					# EI:138 列二 x = 名右 + 10
		_列[2].position.x = 180.0					# EI:142 列三 = 列二右
	var 头 := get_node("头像") as TextureRect
	头.texture = OriginalSprite.portrait("character",
		角色造型.造型号(int(项.get("face", 0)), int(项.get("gender", 0))))
	# FI:104-111 离线 = `filters = Style.getDisableFilter()`。**挂在行上没用**：
	# 行本身不画东西，Godot 的 CanvasItem 材质不会自动给子节点继承 ⇒ 必须逐件套
	# （意志页那颗头像也是同样的做法：材质落在真正绘制的那个 CanvasItem 上）。
	var 材: Material = null
	if not bool(项.get("online", true)):
		var 灰 := ShaderMaterial.new()
		灰.shader = 灰度
		材 = 灰
	for 子 in get_children():
		(子 as CanvasItem).material = 材


func _输入(事件: InputEvent) -> void:
	if not (事件 is InputEventMouseButton) or not (事件 as InputEventMouseButton).pressed:
		return
	var 按 := 事件 as InputEventMouseButton
	if 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if 按.double_click:
		双击.emit(_项)
	else:
		点击.emit(_项, get_global_mouse_position())
	get_viewport().set_input_as_handled()
