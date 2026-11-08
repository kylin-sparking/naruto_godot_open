extends Control
## 十拳剑「改变外观」选择窗 —— 1:1 照 `LingQiFaceSelectWindow.as`（1170 行）。
##
## 打开时序（原版 `EquipPane.onClickPopupMenu` → `requestLingQiFaceList` →
## `LingQiFaceSelectWindow.showWindow(脸表, 色表)`）：**先发包、收到表才建窗**。
## 本窗被挂在 `功能窗口` 的遮罩层上，打开瞬间先铺暗层挡住底下，等 2081:4 回帧再建主体。
##
## 版式真值（行号均为 `LingQiFaceSelectWindow.as`）：
##   :56  WIN_WIDTH 760；:57 ITEM_HEIGHT 28；:58 PADDING 12；:59 COLUMN_GAP 20；
##   :60  SECTION_TITLE_HEIGHT 24；:61 COLOR_COLUMNS 2；:62 预览高 250；
##   :391 createChildren：底宽 760、标题 y=4、关钮 (760-25-7, 2)、列表 (12,28)；
##   :452 buildList：列宽 floor((760-24-40)/3)=232，列 x=0/252/504；
##        contentHeight = 三列最大；bottomY = 列表y + contentHeight + 14；
##        确定钮 x 居中、y=bottomY；底高 = bottomY + 钮高 + 12；
##   :527 左列 = 脸列表 + (外观预览 y=累计+42, 高 250)；
##   :626 中列 = 提示行 + 两列颜色行（行宽 floor((232-8)/2)=112）；
##   :681 右列 = 五项特效，行高 28；
##   :1008 脸行文案：未解锁追加 `  (需写轮眼N阶)`，色 #666666 且 disabled；
##   :1014 颜色行：底 #202020/0.55 圆角、12×12 色块、名字；
##   :1090 预览：身体取 `getCharAliveLookJustFace(stats.face)`，站姿，位置 (92,226)；
##   :1101 确定：只对**与当前不同**的项发包；:1121 destroy：未提交的改动要还原。
##
## ⚠ 特效不在协议里：原版只改 `UIConfig.lingQiEffect*Enabled` 这五个静态开关，
##   关窗时"有未提交改动 → 还原；否则应用"。本工程同口径（`灵器外观数据.gd`）。

const 外观数据 := preload("res://脚本/单例/灵器外观数据.gd")
const 灵器外观脚本 := preload("res://脚本/角色/灵器外观.gd")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")

const 窗宽 := 760.0
const 行高 := 28.0
const 内边距 := 12.0
const 列隙 := 20.0
const 节题高 := 24.0
const 色列数 := 2
const 预览高 := 250.0
const 列宽 := 232.0
const 暗色 := Color(0, 0, 0, 0.3)
const 分隔色 := Color8(0x66, 0x77, 0x88, 204)     # 6715272 / 0.8
const 节题色 := Color8(0xFF, 0xCC, 0x33)         # 16763955
const 提示色 := Color8(0xCC, 0xCC, 0xCC)         # 13421772
const 锁定色 := Color8(0x66, 0x66, 0x66)         # 6710886
const 底九宫 := 9.0
const 钮宽 := 30.0
const 钮高 := 22.0
const 关钮宽 := 25.0
const 关钮高 := 24.0
const 字体路径 := "res://素材/界面/simsun_原版.ttf"

static var _标题字体: FontVariation = null
static var _待开: Control = null

var _后端: Node = null
var _已建 := false
var _脸表: Array = []
var _色表: Array = []
var _原脸 := 0
var _原色 := 0
var _选脸 := 0
var _选色 := 0
var _原效果 := {}
var _脸已发 := false
var _色已发 := false
var _脸组: ButtonGroup = null
var _色组: ButtonGroup = null
var _预览身体: OriginalSprite = null
var _预览灵器: Node2D = null
var _主体: Control = null


## 入口：由 `人物窗口.装备菜单选择` 的「改变外观」调。发包后等 `ling_qi_face_list_received`。
static func 弹出(遮罩: Control, 后端: Node) -> Control:
	if 遮罩 == null or 后端 == null:
		return null
	if _待开 != null and is_instance_valid(_待开):
		_待开.queue_free()
	# 不靠 `class_name` 全局注册（无头 `--check-only` 首次跑时类缓存里还没有它）。
	var 窗脚本: Script = load("res://脚本/界面/窗口/灵器外观选择窗.gd")
	if 窗脚本 == null:
		return null
	var 窗: Control = 窗脚本.new()
	窗.set("_后端", 后端)
	窗.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	窗.mouse_filter = Control.MOUSE_FILTER_STOP
	窗.z_index = 100
	遮罩.add_child(窗)
	# 先铺暗层：发包到回帧之间不让点击漏到底下的装备窗。
	窗.call("_铺暗层")
	if 后端.has_signal("ling_qi_face_list_received"):
		后端.connect("ling_qi_face_list_received", Callable(窗, "_收到脸表"), CONNECT_ONE_SHOT)
	if 后端.has_method("request_ling_qi_face_list"):
		后端.call("request_ling_qi_face_list")
	_待开 = 窗
	return 窗


func _铺暗层() -> void:
	var 暗 := ColorRect.new()
	暗.name = "暗层"
	暗.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	暗.color = 暗色
	# `PopUpMananger.onMaskView` 只清拖拽代理 ⇒ 点暗层不关窗。
	暗.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(暗)


func _收到脸表(脸表: Array, 色表: Array) -> void:
	if _已建:
		return
	_脸表 = 脸表
	_色表 = 色表
	_读当前值()
	_原脸 = _选脸
	_原色 = _选色
	_原效果 = 外观数据.快照()
	_建()
	_已建 = true


func _读当前值() -> void:
	var 脸 := 0
	var 色 := 0
	if _后端 != null:
		var 权 = _后端.get("authoritative_stats")
		if 权 is Dictionary and not (权 as Dictionary).is_empty():
			脸 = int((权 as Dictionary).get("lingFace", 0))
			色 = int((权 as Dictionary).get("lingQiColor", 0))
	if 脸 == 0 and is_inside_tree():
		var 会话 := get_node_or_null("/root/GameSession")
		if 会话 != null:
			var 身: Dictionary = 会话.call("自身外观")
			脸 = int(身.get("lingFace", 0))
			色 = int(身.get("lingQiColor", 0))
	_选脸 = 脸
	_选色 = 色


func _建() -> void:
	_主体 = Control.new()
	_主体.name = "主体"
	add_child(_主体)
	var 底 := Panel.new()
	底.name = "底"
	var 皮 := StyleBoxTexture.new()
	皮.texture = load("res://素材/界面/原版窗口/家族/弹窗底.png") as Texture2D
	for 边 in ["left", "right", "top", "bottom"]:
		皮.set("texture_margin_" + String(边), 底九宫)
	底.add_theme_stylebox_override("panel", 皮)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_主体.add_child(底)

	var 标 := Label.new()
	标.name = "标题"
	标.text = "灵器外观选择"
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", Color.WHITE)
	var 粗 := _粗体()
	if 粗 != null:
		标.add_theme_font_override("font", 粗)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	标.position = Vector2(0, 4)
	标.size = Vector2(窗宽, 18)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_主体.add_child(标)

	var 关 := TextureButton.new()
	关.name = "关钮"
	关.texture_normal = load("res://素材/界面/原版窗口/通用控件/关闭按钮.png") as Texture2D
	关.ignore_texture_size = true
	关.stretch_mode = TextureButton.STRETCH_SCALE
	关.position = Vector2(窗宽 - 关钮宽 - 7.0, 2.0)
	关.size = Vector2(关钮宽, 关钮高)
	关.focus_mode = Control.FOCUS_NONE
	关.pressed.connect(_关闭)
	_主体.add_child(关)

	var 列表 := Control.new()
	列表.name = "列表"
	列表.position = Vector2(内边距, 28.0)
	_主体.add_child(列表)

	var 左 := Control.new()
	左.name = "脸列"
	左.position = Vector2(0, 0)
	左.size = Vector2(列宽, 0)
	列表.add_child(左)
	var 中 := Control.new()
	中.name = "色列"
	中.position = Vector2(列宽 + 列隙, 0)
	中.size = Vector2(列宽, 0)
	列表.add_child(中)
	var 右 := Control.new()
	右.name = "特效列"
	右.position = Vector2((列宽 + 列隙) * 2.0, 0)
	右.size = Vector2(列宽, 0)
	列表.add_child(右)

	var 左高 := _建脸列(左)
	var 中高 := _建色列(中)
	var 右高 := _建特效列(右)
	var 内容高 := maxf(左高, maxf(中高, 右高))

	# 两条竖分隔线：x = 列宽 + 列隙/2、列宽*2 + 列隙*1.5，y=4，高 max(24, 内容高-8)。
	for x in [列宽 + 列隙 * 0.5, 列宽 * 2.0 + 列隙 * 1.5]:
		var 线 := ColorRect.new()
		线.position = Vector2(x, 4.0)
		线.size = Vector2(1.0, maxf(24.0, 内容高 - 8.0))
		线.color = 分隔色
		线.mouse_filter = Control.MOUSE_FILTER_IGNORE
		列表.add_child(线)

	var 底高 := 28.0 + 内容高 + 14.0 + 钮高 + 12.0
	var 确定 := _钮("确定", "确定")
	确定.position = Vector2((窗宽 - 钮宽) * 0.5, 28.0 + 内容高 + 14.0)
	确定.pressed.connect(_确定)
	_主体.add_child(确定)

	# 背景高度 = bottomY + 钮高 + 12（`:452-452` 最后三行）。
	底.size = Vector2(窗宽, 底高)
	_主体.size = Vector2(窗宽, 底高)
	# `PopUpMananger.centerWindow`：相对舞台（= 本层尺寸）居中。
	_主体.position = Vector2(
		roundf((size.x - 窗宽) * 0.5),
		roundf((size.y - 底高) * 0.5)
	)


func _建脸列(列: Control) -> float:
	var 题 := _节标题("灵器外观", 列宽)
	列.add_child(题)
	var y := 节题高
	if _脸表.is_empty():
		var 空 := _普通文字("暂无可用外观", 提示色, 列宽)
		空.position = Vector2(0, y)
		列.add_child(空)
		return y + 24.0
	_脸组 = ButtonGroup.new()
	_脸组.allow_unpress = false
	for i in _脸表.size():
		var 行: Dictionary = _脸表[i]
		var 号 := int(行.get("id", 0))
		var 已解 := bool(行.get("unlocked", false))
		var 名 := str(行.get("name", ""))
		if not 已解:
			名 += "  (需写轮眼%d阶)" % int(行.get("required_stage", 0))
		var 勾 := CheckBox.new()
		勾.name = "脸_%d" % 号
		勾.text = 名
		勾.button_group = _脸组
		勾.toggle_mode = true
		勾.button_pressed = _选脸 == 号
		勾.disabled = not 已解
		勾.focus_mode = Control.FOCUS_NONE
		勾.clip_text = true
		勾.position = Vector2(0, y + 2.0)
		勾.size = Vector2(列宽, 24.0)
		if not 已解:
			勾.add_theme_color_override("font_disabled_color", 锁定色)
		else:
			勾.add_theme_color_override("font_color", Color.WHITE)
		勾.toggled.connect(_脸勾选.bind(号))
		列.add_child(勾)
		y += 行高
	y += 10.0
	var 预览 := _建预览(y + 42.0)
	列.add_child(预览)
	return y + 预览高


func _建色列(列: Control) -> float:
	列.add_child(_节标题("灵器颜色", 列宽))
	var 提示 := _普通文字("点击立即预览，点击确定后保存", 提示色, 列宽)
	提示.position = Vector2(0, 节题高 - 2.0)
	提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	列.add_child(提示)
	var y := 节题高 + 20.0
	if _色表.is_empty():
		var 空 := _普通文字("暂无可用颜色", 提示色, 列宽)
		空.position = Vector2(0, y)
		列.add_child(空)
		return y + 24.0
	_色组 = ButtonGroup.new()
	_色组.allow_unpress = false
	var 行宽 := floorf((列宽 - 8.0) / 色列数)
	for i in _色表.size():
		var 行: Dictionary = _色表[i]
		var 号 := int(行.get("id", 0))
		var 单元 := Control.new()
		单元.name = "色_%d" % 号
		单元.position = Vector2(i % 色列数 * 行宽, y + int(i / 色列数) * 行高)
		单元.size = Vector2(行宽, 行高)
		列.add_child(单元)
		# ⚠ 底色与色块都用 `ColorRect`，不搓 `StyleBoxFlat` —— 游戏内的面板皮肤只有一个事实来源
		#   （`原版皮肤表`），`UI资源回归测试` 扫到那个手绘面板类就红（例外只有登录页）。
		#   这两块本来也没有可对的皮肤：行底是半透明暗底、色块的颜色**来自协议**（`resolveColorPreview`），
		#   纯色片才是它们的原形。
		var 背 := ColorRect.new()
		背.name = "行底"
		背.position = Vector2(0, 2.0)
		背.size = Vector2(行宽 - 6.0, 22.0)
		背.color = Color8(0x20, 0x20, 0x20, 140)
		背.mouse_filter = Control.MOUSE_FILTER_IGNORE
		单元.add_child(背)
		var 色块 := ColorRect.new()
		色块.name = "色块"
		色块.position = Vector2(4.0, 7.0)
		色块.size = Vector2(12.0, 12.0)
		色块.color = _色块颜色(行)
		色块.mouse_filter = Control.MOUSE_FILTER_IGNORE
		单元.add_child(色块)
		var 勾 := CheckBox.new()
		勾.name = "勾_%d" % 号
		勾.text = str(行.get("name", ""))
		勾.button_group = _色组
		勾.toggle_mode = true
		勾.button_pressed = _选色 == 号
		勾.focus_mode = Control.FOCUS_NONE
		勾.position = Vector2(20.0, 2.0)
		勾.size = Vector2(行宽 - 22.0, 24.0)
		勾.clip_text = true
		勾.toggled.connect(_色勾选.bind(号))
		单元.add_child(勾)
	return y + int(ceilf(float(_色表.size()) / 色列数)) * 行高


func _建特效列(列: Control) -> float:
	列.add_child(_节标题("灵器特效", 列宽))
	var 项 := [
		["呼吸明暗", "呼吸明暗"],
		["外发辉光", "外发辉光"],
		["斜向流光", "斜向流光"],
		["边缘星闪", "边缘星闪"],
		["雾化底辉", "雾化底辉"],
	]
	var y := 节题高
	for 对 in 项:
		var 名 := str(对[0])
		var 勾 := CheckBox.new()
		勾.name = 名
		勾.text = 名
		勾.toggle_mode = true
		勾.button_pressed = _取效果(名)
		勾.focus_mode = Control.FOCUS_NONE
		勾.position = Vector2(0, y + 2.0)
		勾.size = Vector2(列宽, 24.0)
		勾.toggled.connect(_特效勾选.bind(名))
		列.add_child(勾)
		y += 行高
	return y


func _建预览(y: float) -> Control:
	var 区 := Control.new()
	区.name = "预览"
	区.position = Vector2(0, y)
	区.size = Vector2(列宽, 预览高)
	区.add_child(_节标题("外观预览", 列宽))
	var 框 := Panel.new()
	框.name = "预览框"
	框.position = Vector2(0, 节题高)
	框.size = Vector2(列宽 - 4.0, 预览高 - 节题高)
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 预览区那块"框"在原版是现搓的圆角描边矩形 ⇒ 本工程换成皮肤表里的**子面板**（窗口内的小面板），
	# 不搓手绘面板皮（`UI资源回归测试` 的手绘面板闸）。
	var 皮 := StyleBoxTexture.new()
	皮.texture = load("res://素材/界面/原版窗口/通用控件/子面板.png") as Texture2D
	for 边 in ["left", "right", "top", "bottom"]:
		皮.set("texture_margin_" + 边, 6.0)
	框.add_theme_stylebox_override("panel", 皮)
	区.add_child(框)

	var 层 := Node2D.new()
	层.name = "预览层"
	层.position = Vector2(0, 节题高)
	区.add_child(层)
	var 身: Dictionary = {}
	if is_inside_tree():
		var 会话 := get_node_or_null("/root/GameSession")
		if 会话 != null:
			身 = 会话.call("自身外观")
	var 号 := 角色造型.造型号(int(身.get("face", 0)), int(身.get("gender", 0)))
	_预览身体 = OriginalSprite.new()
	_预览身体.name = "身体"
	_预览身体.position = Vector2(92.0, 226.0)
	层.add_child(_预览身体)
	if not _预览身体.configure("character", 号, "stand"):
		# 原版 `getCharAliveLookJustFace` 拿不到就不建预览（catch 掉）⇒ 灵器层也不该无身体单飘。
		_预览身体.visible = false
		return 区
	_预览灵器 = 灵器外观脚本.new() as Node2D
	_预览灵器.name = "灵器"
	_预览灵器.position = Vector2(92.0, 226.0)
	层.add_child(_预览灵器)
	_预览灵器.call("绑定", _预览身体)
	_预览灵器.call("设外观", _选脸, _选色)
	return 区


func _刷新预览() -> void:
	if _预览灵器 != null and is_instance_valid(_预览灵器):
		_预览灵器.call("设外观", _选脸, _选色)


func _脸勾选(按下: bool, 号: int) -> void:
	if not 按下:
		return
	_选脸 = 号
	_刷新预览()


func _色勾选(按下: bool, 号: int) -> void:
	if not 按下:
		return
	_选色 = 号
	_刷新预览()


func _特效勾选(按下: bool, 名: String) -> void:
	_写效果(名, 按下)
	_刷新预览()


func _确定() -> void:
	if _选脸 != _原脸:
		_脸已发 = true
		if _后端 != null and _后端.has_method("request_ling_qi_change_face"):
			_后端.call("request_ling_qi_change_face", _选脸)
	if _选色 != _原色:
		_色已发 = true
		if _后端 != null and _后端.has_method("request_ling_qi_change_color"):
			_后端.call("request_ling_qi_change_color", _选色)
	_关闭()


func _关闭() -> void:
	# `destroy:1121-1129` 的布尔式：只要**有没提交的改动**就把四类选择与特效全还原。
	var 没提脸 := not _脸已发 and _选脸 != _原脸
	var 没提色 := not _色已发 and _选色 != _原色
	if 没提脸 or 没提色:
		_选脸 = _原脸
		_选色 = _原色
		外观数据.恢复(_原效果)
		_刷新预览()
	# 提交了/没改动 ⇒ 当前静态开关就是窗口里勾的值（勾选时已经写进去了）。
	if _待开 == self:
		_待开 = null
	queue_free()


## 色块预览：`resolveColorPreview`（`:982-1004`）＝ clamp(int(mul*90+offset),0,255) 三通道。
static func _色块颜色(行: Dictionary) -> Color:
	var r := int(clampf(float(行.get("red_mul", 1.0)) * 90.0 + float(行.get("red_offset", 0)), 0.0, 255.0))
	var g := int(clampf(float(行.get("green_mul", 1.0)) * 90.0 + float(行.get("green_offset", 0)), 0.0, 255.0))
	var b := int(clampf(float(行.get("blue_mul", 1.0)) * 90.0 + float(行.get("blue_offset", 0)), 0.0, 255.0))
	return Color8(r, g, b)


static func _取效果(名: String) -> bool:
	match 名:
		"呼吸明暗": return 外观数据.呼吸明暗
		"外发辉光": return 外观数据.外发辉光
		"斜向流光": return 外观数据.斜向流光
		"边缘星闪": return 外观数据.边缘星闪
		"雾化底辉": return 外观数据.雾化底辉
	return false


static func _写效果(名: String, 值: bool) -> void:
	match 名:
		"呼吸明暗": 外观数据.呼吸明暗 = 值
		"外发辉光": 外观数据.外发辉光 = 值
		"斜向流光": 外观数据.斜向流光 = 值
		"边缘星闪": 外观数据.边缘星闪 = 值
		"雾化底辉": 外观数据.雾化底辉 = 值


static func _粗体() -> FontVariation:
	if _标题字体 == null:
		var 底字 := load(字体路径) as FontFile
		if 底字 != null:
			_标题字体 = FontVariation.new()
			_标题字体.base_font = 底字
			_标题字体.variation_embolden = 0.8
	return _标题字体


func _节标题(文字: String, 宽: float) -> Label:
	var 标 := Label.new()
	标.name = "节题_" + 文字
	标.text = 文字
	标.position = Vector2(0, 0)
	标.size = Vector2(宽, 节题高)
	标.add_theme_font_size_override("font_size", 13)
	标.add_theme_color_override("font_color", 节题色)
	var 粗 := _粗体()
	if 粗 != null:
		标.add_theme_font_override("font", 粗)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return 标


func _普通文字(文字: String, 色: Color, 宽: float) -> Label:
	var 标 := Label.new()
	标.text = 文字
	标.size = Vector2(宽, 20.0)
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", 色)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return 标


func _钮(节点名: String, 文字: String) -> TextureButton:
	var 钮 := TextureButton.new()
	钮.name = 节点名
	钮.texture_normal = load("res://素材/界面/原版窗口/家族/钮底61.png") as Texture2D
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_SCALE
	钮.position = Vector2.ZERO
	钮.size = Vector2(钮宽, 钮高)
	钮.focus_mode = Control.FOCUS_NONE
	var 字 := Label.new()
	字.name = "Label"
	字.text = 文字
	字.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_font_size_override("font_size", 12)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	钮.add_child(字)
	return 钮
