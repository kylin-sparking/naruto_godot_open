extends "res://脚本/界面/窗口/家族/家族子窗.gd"

const 文案 := preload("res://脚本/界面/窗口/好友/好友文案.gd")
const 子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")
const 表情钮场景 := preload("res://场景/界面/组件/聊天表情按钮.tscn")

## 好友私聊窗（原版 `FriendChatWindow` 262×330，自成一窗 ⇒ 子窗壳按 `有壳=false` 开）。
## 真值：`FriendsChat Window` = `FriendChatWindow.as`、行 = `FriendChat.as`、历史与收发 =
## `FriendChatManage.as`、过滤/表情 = `ChatUtil.as`。逐条出处写在下面各处。
##
## 口径摘要（都是原版字面量，别按手感改）：
##   * 标题 `FRIENDCHAT_WINDOW_TITLE`（"与%1对话中"）—— `FCW:132`；
##   * 消息行宽 **216**（`FC:12`），标题行高 20（`FC:28`），标题色 自 42306 / 他 26367（`FC:33-40`）；
##     正文白 `#ffffff`、紧贴标题下沿（`FC:44-46`）；
##   * 输入框 228×73 @(18,218)、上限 100（`FCW:78-87` + `ChatUtil.INPUT_MAX_CHARS`）；
##   * 表情面板 188×188、6×6、每格 24+5、左上 (8,8)（`FaceWindow2.as:65-87`），
##     弹在表情钮中心 ⇒ x = 230+18/2 = 239、y = 192−188+18/2 = 13（`FCW:117-119`）；
##   * 关窗：**有消息只清显示、留历史；一条都没有才把历史也清掉**（`FCW:249-258`）。
##     历史落在 `GameSession.好友私聊记录`（原版 `FriendChatManage._msgData` 的对应物），
##     所以关掉再开、或从别人那里切回来，都能重铺（`FCW:update`）。
##   * ENTER 发送、ESC 关窗（`FCW:227-241`）；发送前先过 `ChatUtil.filterStr`（`:338-348`）。

const 窗名值 := "好友私聊窗"
const 行宽 := 216.0
const 标题行高 := 20.0
const 字号 := 12
const 自己色 := Color(0.0, 0.6470588235294118, 0.25882352941176473)	# 42306 #00A542
const 他色 := Color(0.0, 0.4, 1.0)					# 26367 #0066FF
const 视口高 := 140.0
const 表情数 := 36
const 表情上限 := 5
const 表情面板位 := Vector2(239.0, 13.0)
const 表情面板尺寸 := Vector2(188.0, 188.0)
const 表情底皮 := "res://素材/界面/专用控件/聊天表情底.png"
const 脸皮 := "res://素材/界面/聊天/faces/face_%d.png"

var _会话: Node
var _后端: Node
var _对象号 := 0
var _对象名 := ""


func 装配(宿主: Node) -> void:
	_会话 = _取单例("GameSession", 宿主, "_session")
	_后端 = _取单例("BackendConnection", 宿主, "_backend")
	super.装配(宿主)
	var 框 := _输入()
	框.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	框.gui_input.connect(_输入事件)
	var 视 := get_node_or_null("消息视口") as Control
	if 视 != null:
		视.gui_input.connect(_视口滚轮)
	_建表情面板()
	_接追加()
	_改标题()
	_重铺()


## 打开指定的聊天对象。宿主（`功能窗口._好友对话`）在开窗后立刻调它。
func 设对象(号: int, 名: String) -> void:
	var 换人 := 号 != _对象号
	_对象号 = 号
	_对象名 = 名
	_改标题()
	if 换人:
		_输入().text = ""
	_重铺()
	_输入().grab_focus()


func _发动作(名: String) -> void:
	match 名:
		"关闭":
			_关()
		"发送钮":
			_发送()
		"表情钮":
			_翻表情面板()
		_:
			super._发动作(名)


## `FCW:249-258`：`_msgData.length == 0` 才 `closeChat`（连历史一起丢）；否则 `cleanChat`
## （只清显示，历史留到下次 `update()` 重铺）。
func _关() -> void:
	var 口 := _会话口()
	if _对象号 > 0 and 口 != null and 口.has_method("清好友私聊") and _记录().is_empty():
		口.call("清好友私聊", _对象号)
	子窗壳.关掉(_宿主, 窗名值)


func _发送() -> void:
	var 框 := _输入()
	var 文 := _过滤(框.text)
	if 文.is_empty():
		return
	# `FCW:186` 的 `_loc2_.search(/\s*\S+/) != -1`：过滤完只剩空白也不发（但输入框照清）。
	if RegEx.create_from_string("\\s*\\S+").search(文) != null:
		var 口 := _会话口()
		if 口 != null and 口.has_method("记录好友私聊"):
			口.call("记录好友私聊", true, _对象号, _我的名字(), 文)
		if _后端 != null and _后端.has_method("request_friend_chat"):
			_后端.call("request_friend_chat", _对象号, 文)
	框.text = ""


## `ChatUtil.filterStr:338-348` 的逐句移植：两端**半角空格** → 去 `\r`/`\n` → 剥 `<...>` →
## 去掉**第一个**全角空格（`/　/` 没有 g）→ 表情规范化（有效 1..36 只留前 5 个、其余删空，
## 越界原样保留；`replaceFaceCount` 每次重来）。
## ⚠ 原版还有一道 `StringTool.replaceForbiddenName`（敏感词表来自 `ForbiddenNameS` 图像包）；
##    本工程没有那份词表，**不编词**，这一道先空着。
func _过滤(原文: String) -> String:
	var 文 := 原文.strip_edges()		# CN.trim 只去两端半角空格（`CN.as:2679`）
	文 = 文.replace("\r", "").replace("\n", "")
	文 = RegEx.create_from_string("<(.*?)>").sub(文, "", true)
	文 = 文.replace("　", "")
	return _规范表情(文)


func _规范表情(文: String) -> String:
	var 规 := RegEx.create_from_string("\\[f(\\d{1,2})\\]")
	var 出 := ""
	var 上 := 0
	var 数 := 0
	for 中 in 规.search_all(文):
		出 += 文.substr(上, 中.get_start() - 上)
		上 = 中.get_end()
		var 号 := int(中.get_string(1))
		if 号 > 0 and 号 <= 表情数:
			数 += 1
			出 += ("[f%d]" % 号) if 数 <= 表情上限 else ""
		else:
			出 += 中.get_string(0)
	出 += 文.substr(上)
	return 出


## `FC:51-72` 的标题 `名字 时:分:秒`；颜色按是不是自己。
func _建行(条: Dictionary) -> Control:
	var 自己 := bool(条.get("自己", false))
	var 行 := Control.new()
	行.name = "信"
	行.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 题 := Label.new()
	题.name = "题"
	题.position = Vector2.ZERO
	题.size = Vector2(行宽, 标题行高)
	题.add_theme_font_size_override("font_size", 字号)
	题.add_theme_color_override("font_color", 自己色 if 自己 else 他色)
	var 发 := String(条.get("名", ""))
	if 自己:
		var 我 := _我的名字()
		if not 我.is_empty():
			发 = 我
	题.text = "%s %s" % [发, _钟点(int(条.get("时", 0)))]
	var 体 := RichTextLabel.new()
	体.name = "体"
	体.position = Vector2(0, 标题行高)
	体.bbcode_enabled = true
	体.scroll_active = false
	体.fit_content = true
	体.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	体.mouse_filter = Control.MOUSE_FILTER_IGNORE
	体.add_theme_font_size_override("normal_font_size", 字号)
	体.add_theme_color_override("default_color", Color.WHITE)
	行.add_child(题)
	行.add_child(体)
	return 行


func _钟点(时: int) -> String:
	if 时 <= 0:
		return "00:00:00"
	# AS3 `new Date()` 取**本地**时；unix 秒是 UTC ⇒ 加本机时区偏差再取时分秒。
	var 偏 := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var 钟 := Time.get_time_dict_from_unix_time(时 + 偏)
	return "%02d:%02d:%02d" % [int(钟.hour), int(钟.minute), int(钟.second)]


func _重铺() -> void:
	var 容 := get_node_or_null("消息视口/消息容器") as Control
	if 容 == null:
		return
	for 子 in 容.get_children():
		容.remove_child(子)
		子.queue_free()
	var 累 := 0.0
	for 条 in _记录():
		var 行 := _建行(条)
		容.add_child(行)
		var 体 := 行.get_node("体") as RichTextLabel
		体.size = Vector2(行宽, 0.0)
		体.append_text(_正文(String((条 as Dictionary).get("文", ""))))
		var 高 := maxf(字号 + 6.0, 体.get_content_height())
		体.size = Vector2(行宽, 高)
		行.size = Vector2(行宽, 标题行高 + 高)
		行.position = Vector2(0.0, 累)
		累 += 行.size.y
	容.size = Vector2(行宽, 累)
	_贴底()


## AS3 `ScrollPane.verticalScrollPosition = maxVerticalScrollPosition`（`FCW:196`）。
func _贴底() -> void:
	var 容 := get_node_or_null("消息视口/消息容器") as Control
	var 视 := get_node_or_null("消息视口") as Control
	if 容 == null or 视 == null:
		return
	容.position.y = minf(0.0, 视.size.y - 容.size.y)


func _视口滚轮(事件: InputEvent) -> void:
	if not (事件 is InputEventMouseButton) or not (事件 as InputEventMouseButton).pressed:
		return
	var 按 := 事件 as InputEventMouseButton
	if 按.button_index != MOUSE_BUTTON_WHEEL_UP and 按.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var 容 := get_node_or_null("消息视口/消息容器") as Control
	var 视 := get_node_or_null("消息视口") as Control
	if 容 == null or 视 == null:
		return
	var 步 := 24.0 if 按.button_index == MOUSE_BUTTON_WHEEL_UP else -24.0
	容.position.y = clampf(容.position.y + 步, minf(0.0, 视.size.y - 容.size.y), 0.0)
	get_viewport().set_input_as_handled()


## `FCW:227-241`：ESC 关窗（原版 `escCloseWindow`）、ENTER 发送。
func _输入事件(事件: InputEvent) -> void:
	if not (事件 is InputEventKey) or not (事件 as InputEventKey).pressed:
		return
	var 键 := 事件 as InputEventKey
	if 键.echo:
		return
	if 键.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_关()
	elif 键.keycode == KEY_ENTER or 键.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_发送()


func _建表情面板() -> void:
	if get_node_or_null("表情面板") != null:
		return
	var 面板 := Control.new()
	面板.name = "表情面板"
	面板.position = 表情面板位
	面板.size = 表情面板尺寸
	面板.visible = false
	面板.mouse_filter = Control.MOUSE_FILTER_STOP
	var 底 := NinePatchRect.new()
	底.name = "表情底"
	底.set_anchors_preset(Control.PRESET_FULL_RECT)
	底.texture = load(表情底皮) as Texture2D
	for i in 4:
		底.set("patch_margin_%s" % ["left", "top", "right", "bottom"][i], [19, 15, 19, 15][i])
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面板.add_child(底)
	var 格 := GridContainer.new()
	格.name = "表情网格"
	格.position = Vector2(8.0, 8.0)
	格.columns = 6
	格.add_theme_constant_override("h_separation", 5)
	格.add_theme_constant_override("v_separation", 5)
	格.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面板.add_child(格)
	for 号 in range(1, 表情数 + 1):
		var 钮 := 表情钮场景.instantiate() as TextureButton
		钮.name = "f%d" % 号
		钮.texture_normal = load(脸皮 % 号) as Texture2D
		钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		钮.pressed.connect(_插表情.bind(号))
		格.add_child(钮)
	# `FaceWindow2.as:22` 挂的是**面板自己**的 ROLL_OUT（子件在矩形内不算离开）。
	面板.mouse_exited.connect(_收表情面板)
	add_child(面板)


func _翻表情面板() -> void:
	var 面板 := get_node_or_null("表情面板") as Control
	if 面板 != null:
		面板.visible = not 面板.visible


func _收表情面板() -> void:
	var 面板 := get_node_or_null("表情面板") as Control
	if 面板 != null:
		面板.visible = false


## `FCW:171-198`：当前 `[fN]` 已有 5 个就不再插（判数用 `facePattern` 原文匹配，
## 原版那段"剔除越界"的循环条件写反了 `_loc5_ < 1 && _loc5_ > FACE_COUNT`、永不生效 ⇒ 计数就是匹配数）。
## 插入的串 = `"[" + faceId + "]"`，faceId 取按钮名（`FaceWindow2.as:84`）⇒ `[fN]`。
func _插表情(号: int) -> void:
	var 框 := _输入()
	var 数 := 0
	for _中 in RegEx.create_from_string("\\[f\\d+\\]").search_all(框.text):
		数 += 1
	if 数 < 表情上限:
		框.insert_text_at_caret("[f%d]" % 号)
	_收表情面板()
	框.grab_focus()


## 正文显示：服务端 HTML → BBCode，再把 `[fN]` 换成 24×24 表情图（正文不设 5 个上限——
## 上限只在**发送过滤**那一道；收进来的原文照显示）。
func _正文(文: String) -> String:
	var 换 := 富文本.译文为BBCode(文)
	var 规 := RegEx.create_from_string("\\[f(\\d{1,2})\\]")
	var 出 := ""
	var 上 := 0
	for 中 in 规.search_all(换):
		出 += 换.substr(上, 中.get_start() - 上)
		上 = 中.get_end()
		var 号 := int(中.get_string(1))
		var 路 := 脸皮 % 号
		if 号 >= 1 and 号 <= 表情数 and ResourceLoader.exists(路):
			出 += "[img=24x24]%s[/img]" % 路
		else:
			出 += 中.get_string(0)
	出 += 换.substr(上)
	return 出


func _输入() -> TextEdit:
	var 框 := get_node_or_null("输入") as TextEdit
	if 框 == null:
		# 场景缺件是生成器/场景坏了，别在这里造第二个（造了就和 SPEC 脱钩）
		push_error("好友私聊窗：场景缺「输入」节点")
		return TextEdit.new()
	return 框


func _改标题() -> void:
	var 题 := get_node_or_null("标题") as Label
	if 题 == null or _对象名.is_empty():
		return
	题.text = 文案.取("FRIENDCHAT_WINDOW_TITLE").replace("%1", _对象名)


## 历史落在会话里后，谁来通知本窗追加？—— `GameSession.好友私聊追加(对端)`。
## 这样"收信 → 落库 → 通知重铺"只有一条链，窗口不需要自己去连 `chat_received`
## （关着的窗也不该替它记账）。
func _接追加() -> void:
	# 与 `_记录()` 同一条口径：宿主递进来的会话只要具备历史能力就用它，
	# 否则回落到 autoload。原来写死 `/root/GameSession` —— 回归递假会话时
	# 收信信号永远到不了这扇窗（历史上的一条假绿通道）。
	var 口 := _会话口()
	if 口 == null or not 口.has_signal("好友私聊追加"):
		return
	var 回 := Callable(self, "_收到追加")
	if not 口.is_connected("好友私聊追加", 回):
		口.connect("好友私聊追加", 回)


func _收到追加(对端: int) -> void:
	if 对端 == _对象号 and is_inside_tree():
		_重铺()


func _记录() -> Array:
	var 口 := _会话口()
	if 口 == null or not 口.has_method("取好友私聊"):
		return []
	var 取: Variant = 口.call("取好友私聊", _对象号)
	return 取 if typeof(取) == TYPE_ARRAY else []


## 历史口：宿主那份会话优先（回归可以用假会话换口径），但假宿主那份没有这套方法 ⇒
## 回落到真 autoload。判据是**能力**而不是"是不是 null"，不然假会话会把历史吃成空表。
func _会话口() -> Object:
	if _会话 != null and _会话.has_method("取好友私聊") and _会话.has_method("记录好友私聊"):
		return _会话
	return get_node_or_null("/root/GameSession")


func _我的名字() -> String:
	var 名 := ""
	if _后端 != null:
		var 统: Variant = _后端.get("authoritative_stats")
		if typeof(统) == TYPE_DICTIONARY:
			名 = String((统 as Dictionary).get("name", ""))
	if 名.is_empty() and _会话 != null:
		var 档: Variant = _会话.get("player_stats")
		if typeof(档) == TYPE_DICTIONARY:
			名 = String((档 as Dictionary).get("name", ""))
	return 名


func _取单例(名: String, 宿主: Node, 字段: String) -> Node:
	var 值: Variant = 宿主.get(字段) if 宿主 != null else null
	if 值 is Node:
		return 值 as Node
	return get_node_or_null("/root/" + 名)
