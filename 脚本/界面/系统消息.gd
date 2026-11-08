extends CanvasLayer

## 左侧「系统消息」列 —— 原版左侧地图中部、聊天框上边那列活动倒计时（原版
## `UIMain2.as:4418-4420`：x=6，y 取聊天框上沿再抬 3×20，行从锚点往上叠）。
##
## 真机参照：`测试/基线/原版界面/原版_系统消息.png`（**该文件不在仓里**，
## 形制与数值一律以 `MCountDownTimeLabel.as` / `WeishoulaixiWindow.as` 为准）。
## 形如：
##   距尾兽来袭还有 89: 05: 31
##   距世界Boss刷新还有 02: 35: 31
##   距家族领域战开启还有 47: 35: 30
##   ▽ 仙法精华 （0/10）
##
## 数据来自服务端 1809:2 帧（见 `后端连接.gd` 的 `_handle_huodong_countdowns_text`），
## 每项只给一个**基准秒数**；原版这列是逐秒递减的，所以本地按帧到达时刻自己走秒，
## 不每帧问服务端。这与原版一致：服务端只在进游戏/活动变更时下发一次。
##
## 挂法与被删组件一致：CanvasLayer，layer = 110（高于技能栏/聊天面板的 100、
## 功能窗口的 80），挂在界面区域下。

# 活动时间按用户要求放大到 14px，不沿用原版 12px。
const 行高 := 21.0
const 字号 := 14
const 倒计时色 := Color("#00ff5a")
const 无数据提示 := ""

## 当前有效行数（行池只增不减，靠 visible 控制；外部读取用这个而不是 get_child_count）
var 可见行数 := 0

var _列表: Control
var _标题: Label
var _行池: Array[Label] = []
var _行数据: Array = []
var _会话: Node

func _ready() -> void:
	_列表 = get_node_or_null("界面区域/系统消息/消息列表") as Control
	_标题 = get_node_or_null("界面区域/系统消息/标题") as Label
	if _标题 != null:
		_标题.visible = false  # 原版这一列没有可见标题，节点树里有、画面上没有
	_会话 = get_tree().root.get_node_or_null("/root/GameSession")
	if _会话 != null:
		_会话.活动倒计时_changed.connect(_应用)
		_应用(_会话.活动倒计时)
		if _会话.get("in_game") == true:
			_会话.call("request_活动倒计时")

func _process(_delta: float) -> void:
	_刷新文字()
	_重排()


func _重排() -> void:
	var 聊天顶 := get_viewport().get_visible_rect().size.y - 266.0
	var 聊天 := get_tree().get_first_node_in_group("chat_panel")
	if 聊天 != null:
		var 内容 := 聊天.get("_chat_content") as Control
		if 内容 != null:
			var 底 := 内容.get_node_or_null("面板底") as Control
			if 底 != null:
				聊天顶 = 底.get_global_transform_with_canvas().origin.y
	# 原版 `UIMain2.as:4418`：x=6、y=STAGE_HEIGHT-66-chatHeight-3*20（聊天框上沿再抬 60），
	# 行从锚点往上叠（`WeishoulaixiWindow.doLayout`: y = -i * height）。
	var 界面 := get_node("界面区域") as Control
	界面.position = Vector2(6.0, 聊天顶 - 60.0)
	for i in 可见行数:
		_行池[i].position = Vector2(0.0, -i * 行高)

func _应用(rows: Array) -> void:
	_行数据.clear()
	for 项 in rows:
		if not (项 is Dictionary):
			continue
		_行数据.append({
			"描述": String(项.get("text", "")),
			"剩余": maxi(0, int(项.get("seconds", 0))),
			"基准": int(项.get("基准毫秒", Time.get_ticks_msec())),
		})
	_保证行数(_行数据.size())
	_刷新文字()

## 原版的秒数是 H: M: S 三段、每段两位左补零，段之间用 " : " 隔开。
static func 格式化(秒: int) -> String:
	var s := maxi(0, 秒)
	return "%02d: %02d: %02d" % [s / 3600, (s / 60) % 60, s % 60]

func _刷新文字() -> void:
	var 现在 := Time.get_ticks_msec()
	for i in _行数据.size():
		var 项: Dictionary = _行数据[i]
		var 剩余 := maxi(0, int(项["剩余"]) - (现在 - int(项["基准"])) / 1000)
		var 描述 := String(项["描述"])
		# 服务端给的已经是完整句子（"距X还有"），只在后面补原版格式的 H: M: S；
		# 带全角括号的那种（如"仙法精华（0/10）"）本身就是完整文案，原样显示。
		_行池[i].text = 描述 if 描述.contains("（") else "%s %s" % [描述, 格式化(剩余)]

func _保证行数(数量: int) -> void:
	while _行池.size() < 数量:
		var 行 := Label.new()
		行.name = "第%d行" % (_行池.size() + 1)
		行.add_theme_font_size_override("font_size", 字号)
		行.add_theme_color_override("font_color", 倒计时色)
		行.add_theme_constant_override("outline_size", 0)
		行.add_theme_constant_override("shadow_outline_size", 0)
		行.add_theme_constant_override("shadow_offset_x", 0)
		行.add_theme_constant_override("shadow_offset_y", 0)
		行.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		行.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		行.mouse_filter = Control.MOUSE_FILTER_IGNORE
		行.position = Vector2(0.0, -_行池.size() * 行高)
		行.size = Vector2(196.0, 行高)
		_列表.add_child(行)
		_行池.append(行)
	for i in _行池.size():
		_行池[i].visible = i < 数量
	可见行数 = 数量
	_重排()
