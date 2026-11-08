extends Control
## 随身摊位列表的一行（原版 `StallItemRenderer`，行 **220×50**）。
## 逐件真值 = `真值/窗口/随身摊位窗.md` §④（每条算式带 `StallItemRenderer.as` 行号）。
## 数据驱动的行 ⇒ 不进场景（同 `好友行.gd` 的做法）；本文件只做美术与"选中"，不碰协议。

signal 被点击(行: Dictionary)

const 行宽 := 220.0
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")		# autoload 名叫 `GameData`，页面一律本地 preload 后用中文别名（同 兑换商店窗.gd）
const 行高 := 50.0
const 格边 := 40.0						# SimpleItemCell = MGrid_background 原生 40×40（`:129-130`）
const 悬停皮 := "res://素材/界面/原版窗口/通用控件/选中条1.png"		# MSelected_background1 tag705
const 元宝底皮 := "res://素材/界面/原版窗口/通用控件/选中条.png"		# MSelected_background tag1144
const 输入框皮 := "res://素材/界面/原版窗口/通用控件/输入框.png"		# MTextInput_background tag437
const 物品格皮 := "res://素材/界面/原版窗口/通用控件/物品格.png"		# MGrid_background tag172
const 分隔线皮 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"	# LineHPicF tag133（`extends Sprite` ⇒ 整帧拉伸）
const 金币皮 := "res://素材/界面/原版窗口/通用控件/金币.png"			# MIconGoldCoinF 17×17
const 元宝皮 := "res://素材/界面/原版窗口/通用控件/元宝币.png"			# MIconGoldYuanBaoF 19×13
const 查看钮皮 := ["res://素材/界面/原版窗口/洗点/确定钮.png",
				"res://素材/界面/原版窗口/洗点/确定钮_悬停.png",
				"res://素材/界面/原版窗口/洗点/确定钮_按下.png"]
const 蓝 := Color(0.117647, 0.564706, 1, 1)		# 2003199 = #1E90FF（`:172` `_nameLabel.color`）
const 橙 := Color(1, 0.627451, 0, 1)			# UIConfig.UI_ORANGE = 16748800 = #FFA000
const 钮字色 := Color(0.988235, 0.956863, 0.611765, 1)	# MButton3._textColors[up] = #fcf49c

var 项: Dictionary = {}
var 选中 := false
var _条: NinePatchRect
var _元宝底: NinePatchRect
var _价: Array[Label] = []
var _图标: Array[TextureRect] = []
var _名字: Label
var _类型: Label
var _售价: Label
var _格: NinePatchRect
var _格图: TextureRect
var _角标: Label
var _查看: Button

## 行内那 13 件的矩形（页/行局部坐标，全按 §④ 的算式）⇒ 门直接读这张表，别在门里重抄一遍数字。
const 矩形 := {
	"分隔线": [0.0, 48.0, 220.0, 2.0],		# `:124-127` y = 50 − height(2)
	"悬停条": [0.0, 0.0, 220.0, 50.0],		# `:128-131`
	"价1底": [117.0, 2.0, 100.0, 21.0],		# `:133-139` setSize(100,21) @ (117,2)
	"价2底": [117.0, 24.0, 100.0, 21.0],		# `:140-146` @ (117,24)
	"价1文": [138.0, 5.0, 76.0, 18.0],		# textField.x = paddingLeft(21)、y = 3 ⇒ 117+21, 2+3
	"价2文": [138.0, 27.0, 76.0, 18.0],
	"金币": [120.0, 5.0, 17.0, 17.0],		# `:147-150` goldItem + (3,3)
	"元宝": [120.0, 26.0, 19.0, 13.0],		# `:152-155` yuanBaoItem + (3,2)
	"元宝底": [117.0, 24.0, 100.0, 21.0],		# `:157-164` 尺寸 = goldItem 的框、位置 = yuanBaoItem 的
	"物品格": [2.0, 4.0, 40.0, 40.0],		# `:165-168`
	"名字": [42.0, 12.0, 74.0, 20.0],		# `:169-175` x = 格 x + 格宽
	"类型": [42.0, 12.0, 74.0, 20.0],		# `:187-194` 与名字同格（货币档才两个都用到，见 填()）
	"售价": [117.0, 3.0, 100.0, 20.0],		# `:195-202` goldItem.x, `_goldIcon.y − 2`
	"查看钮": [42.0, 20.0, 37.0, 22.0],		# `:203-210` x = 名字.x、y = 20
}


func _init() -> void:
	name = "摊位行"
	custom_minimum_size = Vector2(行宽, 行高)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_件("分隔线", 分隔线皮, TextureRect.STRETCH_SCALE)
	_条 = _九宫格("悬停条", 悬停皮, [7.0, 7.9, 5.35, 5.75])	# 边距顺序 [left, right, top, bottom]
	_条.visible = false
	_九宫格("价1底", 输入框皮, [6.0, 7.0, 5.0, 6.0])
	_九宫格("价2底", 输入框皮, [6.0, 7.0, 5.0, 6.0])
	_价.append(_文("价1文", Color.WHITE))
	_价.append(_文("价2文", Color.WHITE))
	_图标.append(_件("金币", 金币皮, TextureRect.STRETCH_KEEP_ASPECT_CENTERED))
	_图标.append(_件("元宝", 元宝皮, TextureRect.STRETCH_KEEP_ASPECT_CENTERED))
	_元宝底 = _九宫格("元宝底", 元宝底皮, [9.0, 8.0, 5.0, 5.0])
	_元宝底.visible = false
	_格 = _九宫格("物品格", 物品格皮, [9.0, 6.0, 9.0, 6.0])
	_格图 = TextureRect.new()
	_格图.name = "图标"
	_格图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_格图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_格图.stretch_mode = TextureRect.STRETCH_SCALE
	_格图.position = Vector2.ZERO
	_格图.size = Vector2(格边, 格边)
	_格.add_child(_格图)
	_角标 = Label.new()
	_角标.name = "数量"
	_角标.position = Vector2(0.0, 20.0)		# `SimpleItemCell.as:139` setPosition(0,20)
	_角标.size = Vector2(40.0, 20.0)			# `:138` setSize(40,20)
	_角标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT	# `:143`
	_角标.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_角标.add_theme_font_size_override("font_size", 12)
	_角标.add_theme_color_override("font_color", Color.WHITE)	# `:137` color = 16777215
	_角标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_格.add_child(_角标)
	_名字 = _文("名字", 蓝)
	_类型 = _文("类型", 蓝)
	_类型.visible = false
	_售价 = _文("售价", 橙)
	_售价.visible = false
	_查看 = Button.new()
	_查看.name = "查看钮"
	_查看.position = Vector2(矩形["查看钮"][0], 矩形["查看钮"][1])
	_查看.size = Vector2(矩形["查看钮"][2], 矩形["查看钮"][3])
	_查看.text = "查看"						# CN.MAIL_EXAMINE
	_查看.focus_mode = Control.FOCUS_NONE
	_查看.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_查看.add_theme_font_size_override("font_size", 12)
	for 槽 in ["normal", "hover", "pressed"]:
		var 皮 := StyleBoxTexture.new()
		皮.texture = load(查看钮皮[{"normal": 0, "hover": 1, "pressed": 2}[槽]])
		_查看.add_theme_stylebox_override(槽, 皮)
	_查看.visible = false
	add_child(_查看)
	mouse_entered.connect(func(): _条.visible = true)		# `:246-249` ROLL_OVER
	mouse_exited.connect(_移开)					# `:86-92` ROLL_OUT（选中那行不隐）


func _移开() -> void:
	if not 选中:
		_条.visible = false


## 数据 → 画面（`data` setter `:236-244` → `drawItem():270-351` + `dolayout():255-263`）。
## 三档：类型 3 = 宠物、类型 10 = 货币、其余 = 物品/装备。
func 填(行: Dictionary) -> void:
	项 = 行
	var 种 := int(行.get("kind", 0))
	var 段: PackedStringArray = String(行.get("payload", "")).split("&")
	if 种 == 10:
		_填货币(段)
	elif 种 == 3:
		_填宠物(段)
	else:
		_填物品(段)
		## `:313-314` 只有非货币档才把这两个价直接印进两格（货币档那格由 `_填货币` 写）。
		_价[0].text = str(int(行.get("point_price", 0)))
		_价[1].text = str(int(行.get("cash_price", 0)))
	# `:315-322` 只有"要元宝"的挂牌才在那格下面铺一层 选中条 当底；`:345` 货币档恒不铺。
	_元宝底.visible = 种 != 10 and int(行.get("cash_price", 0)) > 0


func _清三件() -> void:
	_名字.visible = true
	_类型.visible = false
	_售价.visible = false
	_查看.visible = false
	_名字.position = Vector2(矩形["名字"][0], 矩形["名字"][1])
	_名字.size = Vector2(矩形["名字"][2], 矩形["名字"][3])
	_名字.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_角标.text = ""


func _填物品(段: PackedStringArray) -> void:
	_清三件()
	_图标[0].visible = true
	_图标[1].visible = true
	## `_encode_item_payload` 段序：`族&物品号&槽&数量&0&0&可交易&主人&0&唯一号&…`（服务端 `:50832-50843`）
	## ⇒ 名字/图标/角标三样全按**物品号**查，与背包那条链同一个口径。
	var 号 := int(段[1]) if 段.size() > 1 else 0
	var 数 := int(段[3]) if 段.size() > 3 else 1
	_名字.text = 游戏数据.item_name(号)
	_角标.text = str(数) if 数 > 1 else ""
	_格图.texture = null
	var 路 := 游戏数据.item_icon_path(号)
	if 路 != "" and ResourceLoader.exists(路):
		var 图 := load(路) as Texture2D
		_格图.texture = 图
		var 寸 := 图.get_size()
		_格图.position = Vector2(roundf((格边 - 寸.x) / 2.0), roundf((格边 - 寸.y) / 2.0))
		_格图.size = 寸


func _填宠物(段: PackedStringArray) -> void:
	_清三件()
	_图标[0].visible = true
	_图标[1].visible = true
	## `_encode_pet` 段序：`宠物号&位置&1&0&0&可交易&主人&0&唯一号&主人角色号&宠物名&等级&…`
	var 种 := int(段[0]) if 段.size() > 0 else 0
	_名字.text = String(段[10]) if 段.size() > 10 else ""
	## `:284-285` 宠物档把名字框放宽到 84、并把 y 挪到 0（给下面那颗「查看」钮让位）。
	_名字.size = Vector2(84.0, 20.0)
	_名字.position = Vector2(矩形["名字"][0], 0.0)
	_角标.text = "1"							# `:291` `_itemIcon.label = "1"`（恒 1，不是数量）
	_查看.visible = true
	_格图.texture = OriginalSprite.portrait("pet", str(种))
	_格图.position = Vector2(2.0, 2.0)			# `PortraitHead(true, 40−4, 40−4)` ⇒ 36×36 居中在 (2,2)
	_格图.size = Vector2(36.0, 36.0)


func _填货币(段: PackedStringArray) -> void:
	_清三件()
	## 负载 = `是否金币!金币数!元宝数`（服务端 `:25787-25791`，`!` 已在后端还原成 `&`）
	var 是金币 := int(段[0]) if 段.size() > 0 else 0
	var 金币数 := int(段[1]) if 段.size() > 1 else 0
	var 元宝数 := int(段[2]) if 段.size() > 2 else 0
	_名字.text = str(金币数) if 是金币 == 1 else str(元宝数)
	## `:343-344` 价的两格：金币槽清空，另一个槽写"要用哪种币付"。
	_价[0].text = ""
	_价[1].text = str(元宝数) if 是金币 == 1 else str(金币数)
	_类型.text = "游戏金币" if 是金币 == 1 else "商城元宝"		# ITMEWINDOW_MONEY / ITMEWINDOW_YUANBAO
	_类型.visible = true
	_售价.visible = true
	_售价.text = "售价："						# SALE_LABEL（值自带冒号）
	## `:346-347` 两枚币只露一枚：卖的是金币 ⇒ 价栏用元宝币图标，反之用金币图标。
	_图标[0].visible = 是金币 != 1
	_图标[1].visible = 是金币 == 1
	## `dolayout():255-263`：类型行顶到 y=6、名字行挪到它下面（y=26）、金币图标跟着元宝图标 y。
	_类型.position = Vector2(矩形["类型"][0], 6.0)
	_名字.position = Vector2(矩形["名字"][0], 26.0)
	_图标[0].position = Vector2(矩形["金币"][0], 矩形["元宝"][1])
	## 货币档那格画的是 UISwf 里的整枚钱币（34×34 居中），本工程未导该符号 ⇒ 只留空网格。
	_格图.texture = null
	_角标.text = ""


## 只画一条矩形件（不参与交互）。
func _件(名: String, 皮: String, 拉伸: int) -> TextureRect:
	var 面 := TextureRect.new()
	面.name = 名
	面.texture = load(皮) as Texture2D
	面.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	面.stretch_mode = 拉伸
	面.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 尺: Array = 矩形[名]
	面.position = Vector2(尺[0], 尺[1])
	面.size = Vector2(尺[2], 尺[3])
	add_child(面)
	return 面


## 九宫格件（Flash 的 ScaleSprite）。边距顺序 [left, right, top, bottom] = `原版皮肤表.gd` 的 九宫格 表。
## ⚠ 属性名必须是 `patch_margin_*`，而且**是整数**：本机 4.7 的 `NinePatchRect` 没有
## `texture_margin_*` 这个属性（`.tscn` 里写它 = 静默不生效；脚本里直接赋值 = 运行期报错、函数当场中止），
## `patch_margin_*` 收到 float 会报 `Invalid assignment ... value of type 'float'` ⇒ 一律 `int()` 再写。
func _九宫格(名: String, 皮: String, 边: Array) -> NinePatchRect:
	var 面 := NinePatchRect.new()
	面.name = 名
	面.texture = load(皮) as Texture2D
	面.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 尺: Array = 矩形[名]
	面.position = Vector2(尺[0], 尺[1])
	面.size = Vector2(尺[2], 尺[3])
	面.patch_margin_left = int(边[0])
	面.patch_margin_right = int(边[1])
	面.patch_margin_top = int(边[2])
	面.patch_margin_bottom = int(边[3])
	add_child(面)
	return 面


func _文(名: String, 色: Color) -> Label:
	var 字 := Label.new()
	字.name = 名
	var 尺: Array = 矩形[名]
	字.position = Vector2(尺[0], 尺[1])
	字.size = Vector2(尺[2], 尺[3])
	字.add_theme_font_size_override("font_size", 12)		# ScrollTextField `_textFormat.size = 12`
	字.add_theme_color_override("font_color", 色)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	字.vertical_alignment = VERTICAL_ALIGNMENT_TOP		# Flash TextField 顶对齐（工程既有口径）
	字.clip_text = true
	字.text_overrun_behavior = 0		# TextServer.OVERRUN_DISABLE：不缩字、不加省略号，靠 clip 裁在框里（= Flash 的 wordWrap=false）
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(字)
	return 字


## 选中态（`List.selectedIndex` 那一档）：与悬停共用同一张底，但移开不许隐。
func 设选中(是: bool) -> void:
	选中 = 是
	_条.visible = 是


func _gui_input(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton:
		var 按 := 事件 as InputEventMouseButton
		if 按.button_index == MOUSE_BUTTON_LEFT and 按.pressed:
			被点击.emit(项)
			get_viewport().set_input_as_handled()
