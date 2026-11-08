extends RefCounted

## 战报窗 = 原版 `PvpZhanBaoWindow`（MWindow，底板 `FamillyPopupWindowSkin` **天然 216×134、不拉伸**）。
## 两个入口：右下角托盘那枚「战报」格被点（`PvpManager.clickGridHandler:81-86`）、
## 以及主窗战报行里点那句链接文字弹出的菜单（`showMenu` ⇒ 同一份正文）。
##
## 版式照 AS3 字面（`PvpZhanBaoWindow.as:44-58`）：
##   底板 = 家族弹窗皮**原尺寸**（这里没像 `PvpResultWindow:39-40` 那样写 width/height）
##   标题 `PVP_ZHANBAO_TITLE`「战报」
##   正文 `TextArea2` `(10,25)` 尺寸 `204×70`、`hasGlow = true`
##   确定 `MButtonF` `x = (216 − w)/2`、`y = 134 − h − 12 = 100`，点它 = `onCloseBtnClick`
##   正文里那句是**链接**（`:60 addEventListener(TextEvent.LINK)`）⇒ 点它在鼠标处弹「查看资料」菜单
##
## ★ 和结算弹层同一个理由：**自己一层 CanvasLayer(400)**，不挂进某一扇窗的 `遮罩`
##   —— 托盘那一格随时可点，那时候可能一扇竞技场窗都没开着。
##   同一时刻只留一枚；`收起()` 先脱树再 `queue_free`（口径同 `竞技场结算弹.gd`，那里写了为什么）。

const 底宽 := 216.0				# 家族弹窗皮天然宽（`background` 没被改尺寸）
const 底高 := 134.0				# 天然高
const 九宫边 := 9.0
const 正文位 := Vector2(10.0, 25.0)		# `:50`
const 正文宽 := 204.0			# `:51` setSize(204,70)
const 正文高 := 70.0
const 钮宽 := 61.0
const 钮高 := 22.0
const 钮底隙 := 12.0				# `:56` `background.height − h − 12`
const 白 := Color(1, 1, 1)
const 暗色 := Color(0, 0, 0, 0.5)
const 层号 := 400

static var 当前: CanvasLayer = null


## `生命` = 当前地图的 `LifeRoot`；`正文` = `竞技场窗.战报文本(条, 自己号)` 那份 BBCode。
static func 弹出(生命: Node, 正文: String) -> CanvasLayer:
	if 生命 == null or not is_instance_valid(生命) or 生命.get_parent() == null:
		return null
	收起()
	var 层 := CanvasLayer.new()
	层.name = "竞技场战报层"
	层.layer = 层号
	生命.get_parent().add_child(层)
	var 遮罩层 := Control.new()
	遮罩层.name = "战报"
	遮罩层.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩层.mouse_filter = Control.MOUSE_FILTER_STOP
	层.add_child(遮罩层)
	var 暗 := ColorRect.new()
	暗.name = "暗层"
	暗.set_anchors_preset(Control.PRESET_FULL_RECT)
	暗.color = 暗色
	暗.mouse_filter = Control.MOUSE_FILTER_STOP
	遮罩层.add_child(暗)
	var 主体 := Control.new()
	主体.name = "主体"
	主体.size = Vector2(底宽, 底高)
	主体.position = Vector2(floorf((遮罩层.size.x - 底宽) / 2.0), floorf((遮罩层.size.y - 底高) / 2.0))
	遮罩层.add_child(主体)
	主体.add_child(_底())
	var 标 := Label.new()
	标.name = "标题"
	标.text = "战报"						# `:48` `PVP_ZHANBAO_TITLE`
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.set_anchors_preset(Control.PRESET_TOP_WIDE)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", 白)
	主体.add_child(标)
	var 文 := RichTextLabel.new()
	文.name = "正文"
	文.bbcode_enabled = true
	文.scroll_active = false
	文.position = 正文位
	文.size = Vector2(正文宽, 正文高)
	文.add_theme_font_size_override("normal_font_size", 12)
	文.add_theme_color_override("default_color", 白)
	文.add_theme_constant_override("line_separation", 2)
	文.text = 正文
	主体.add_child(文)
	主体.add_child(_确定())
	当前 = 层
	return 层


static func 收起() -> void:
	if is_instance_valid(当前):
		var 旧 := 当前
		当前 = null
		if 旧.get_parent() != null:
			旧.get_parent().remove_child(旧)
		旧.queue_free()
	当前 = null


static func _底() -> Control:
	var 底 := Panel.new()
	底.name = "底"
	var 皮 := StyleBoxTexture.new()
	皮.texture = load("res://素材/界面/原版窗口/家族/弹窗底.png") as Texture2D
	for 边 in ["left", "right", "top", "bottom"]:
		皮.set("texture_margin_" + String(边), 九宫边)
	底.add_theme_stylebox_override("panel", 皮)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	底.size = Vector2(底宽, 底高)
	return 底


static func _确定() -> Control:
	var 钮 := TextureButton.new()
	钮.name = "确定钮"
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	钮.texture_normal = load("res://素材/界面/原版窗口/家族/钮底61.png") as Texture2D
	钮.texture_hover = load("res://素材/界面/原版窗口/家族/钮底61_悬停.png") as Texture2D
	钮.texture_pressed = load("res://素材/界面/原版窗口/家族/钮底61_按下.png") as Texture2D
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.size = Vector2(钮宽, 钮高)
	钮.position = Vector2(floorf((底宽 - 钮宽) / 2.0), 底高 - 钮高 - 钮底隙)
	钮.pressed.connect(收起)
	var 字 := Label.new()
	字.name = "文字"
	字.text = "确定"						# `COMMON_OK`
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.set_anchors_preset(Control.PRESET_FULL_RECT)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", 白)
	钮.add_child(字)
	return 钮
