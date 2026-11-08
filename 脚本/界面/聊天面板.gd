extends CanvasLayer

## 原版聊天正文**整条链路都是 HTML**：`ChatPane.setMsg:1674` 拿 `ChatUtil.formatMessage`
## （那函数自己就在拼 `<font color="#…">`，`ChatUtil.as:105/137`）→ 存进记录 `"content"`（`:1679`）
## → `createMsgBox`（`:726`）→ `MTextSprite.set text` 里 **`textField.htmlText = …`**（`MTextSprite.as:83/93`）
## 交 Flash 渲染。服务端侧同理（`fake_flash_server.py:40252-40329 _rare_event_markup` 一层层包色）。
## 本工程 `RichTextLabel` 吃 BBCode、`<` 不是标签字符 ⇒ 每一句正文进聊天之前都要过
## `富文本.译文为BBCode` —— 见下面 `_正文`（真值 `真值/界面/聊天正文与通告位.md`）。
const 富文本 := preload("res://脚本/界面/富文本.gd")

# 频道命名与配色严格对齐原版 ChatType.CHANNELS / ChatUtil.CHANNEL_COLORS
const CHAT_TABS := ["综合", "普通", "私聊", "队伍", "家族", "世界"]
const CHAT_CHANNELS := ["普通", "私聊", "队伍", "家族", "世界", "喇叭"]
const CHAT_COLORS := {
	"综合": "#e0d995", "普通": "#ffffff", "私聊": "#da70d6", "队伍": "#87ceeb",
	"家族": "#00c957", "世界": "#ffd700", "喇叭": "#e15204",
	"系统": "#ffffff", "公告": "#ffffff",
}
# ChatUtil.CHARACTOR_COLOR —— 玩家名与频道前缀标签色
const CHAT_NAME_COLOR := "#b0e0e6"
# 页签文字色，对齐原版 MButton3.setAllStatsColor(14212326,15987700,14212326,14212326)
# （`ChatPane.as:246`）：up/down/disabled 0xD8DCE6、over 0xF3F3F4
const TAB_COLOR_NORMAL := Color("#d8dce6")
const TAB_COLOR_OVER := Color("#f3f3f4")
# MessagePosition 位掩码
## `MessagePosition.PUB_NOTICE`（`MessagePosition.as:6`）：**中部通告位，不进聊天记录**。
## 原版 `UI.as:339-354`：这一位按文案里有没有 `[JH]` 分流到 `addScrollAnnounce`（白字滚动条）
## 或 `addChengJIuAnnounce`（`[JH]` 先 `replace` 掉再画），另外**无条件**推一份进
## `selectInfoWindowNoticeData`（信息查询窗）。三条路**都没有** `chatPane.addMsg`。
## 本工程那两块面板还没移植（旧账见编年史 §3.239 F），所以这里只做「不进聊天」这一半 ——
## 同一条稀有事件服务端还会**另发一帧 `positions=4`（MISC）**（`fake_flash_server.py:40365-40370`），
## 那条才该上聊天记录，正文也就是玩家真正要看的那一句。
const POS_PUB_NOTICE := 1
const POS_MISC := 4
const POS_GENERAL := 8
const POS_WHISPER := 16
const POS_PARTY := 32
const POS_GUILD := 64
const POS_WORLD := 128
const POS_LABA := 256
## `MessagePosition.CHAR_NOTICE`（`MessagePosition.as:24`）：服务端的拒绝/告知位。
## 原版 `UI.as:375-377`（`onChatMessage` 里的 `CHAR_NOTICE` 那格）把它交给 `addNotice`
## —— **只出黄字浮动提示、不进聊天记录**，所以这条在本面板必须跳过（提示那份由
## `后端连接._handle_chat_text` 发到会话口子，再经 `_on_notification` 落成一条『系统』行）。
## 不跳过的话同一条拒绝会在聊天里出现两遍。
const POS_CHAR_NOTICE := 512
## 旧账（§3.239 F，别读成已做完）：`DYNAMIC_INFO(1024)` 原版给 `noticePnl.addNotice`、
## `COPY_NOTICE(2048)` 原版给 `addMidMessageRed`（`UI.as:378-382`），两块提示面板本工程都没移植
## ⇒ 这两个位现在照样落进 `_chat_messages`（只是各页按位过滤后看不到）。
## 要补的是那两块面板，不是在这里再多加一记 `return`。
# 各页签对应的位；综合页收所有频道
const TAB_POSITIONS := [POS_MISC, POS_GENERAL, POS_WHISPER, POS_PARTY, POS_GUILD, POS_WORLD]
const CHANNEL_POSITIONS := {
	"普通": POS_GENERAL, "私聊": POS_WHISPER, "队伍": POS_PARTY,
	"家族": POS_GUILD, "世界": POS_WORLD, "喇叭": POS_LABA,
	"系统": POS_MISC, "公告": POS_MISC,
}
const WORLD_CHANNEL_TIME_CD := 5000
const REPEAT_SEND_CD := 1000
const CHAT_INPUT_MAX_CHARS := 100	 # `ChatUtil.as:24 INPUT_MAX_CHARS`（旧值 40 是未证口径，已核 AS3）
const INSERT_FACE_MAX_COUNT := 5
const FACE_COUNT := 36
const DEFAULT_SHOW_CHAT_COUNT := 30
const RESIZE_HEIGHT := 200.0	 # `ChatPane.as:65` ^钮一步拉伸
const SPEAKER_MAX := 3		 # `ChatSpeakerPane.as:37 MAX_COUNT`
const SPEAKER_TTL_MS := 30000		 # `ChatSpeakerPane.as:49`
const FACE_PATH := "res://素材/界面/聊天/faces/face_%d.png"
# 原版 TextWithFace.FLAG 用 <font size='24'> 占位，表情原始尺寸也是 24×24
const FACE_RENDER_SIZE := 24
# 箭头按钮（隐藏/显示聊天）的底边留白，对齐 UIMain2 的 STAGE_HEIGHT - 66
const 箭头按钮留白 := 66.0
const CHAT_TIP_SEND_TOO_FAST := "请过 1 秒后再发言"
const CHAT_TIP_PUBLIC_CHAT_CD := "世界频道发言冷却时间尚未结束"
const CHAT_TIP_LABA_COUNT := "你背包中的喇叭不足！"

var _session: Node
var _backend: Node
@onready var _chat_content: Control = get_node("聊天内容") as Control
@onready var _hide_button: TextureButton = get_node("隐藏聊天") as TextureButton
@onready var _show_button: TextureButton = get_node("显示聊天") as TextureButton
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _send_button: TextureButton
var _expand_button: TextureButton
var _channel_button: TextureButton
var _face_button: TextureButton
var _chat_scroll: Control
var _chat_scroll_up: TextureButton
var _chat_scroll_down: TextureButton
var _chat_scroll_thumb: TextureButton
var _chat_scroll_dragging := false
var _chat_scroll_drag_offset := 0.0
## 滚动模型：`消息窗口`（clip_contents）+ 内层 `消息区` 移位
## （RichTextLabel 在 scroll_active=false 时 `scroll_offset_y` 只读，且原版条在**左**、
## 用自带右条会顶出滚动条 ⇒ 自绘容器驱动，条皮=Scroll* 族）。
var _滚动偏移 := 0.0
var _可视高 := 144.0
## 自记鼠标全局位：`get_viewport().get_mouse_position()` 在合成 push_input 下不更新
## （见 project memory），悬停判定必须自己吃 motion 事件，量具才测得到。
var _鼠标位 := Vector2(-9999, -9999)
## 单格滚动量 = `lineScrollSize`（BaseScrollPane.as:48 defaultLineScrollSize=4、:314 赋给纵条）；
## 滚轮一格 = delta(3) × 4 = 12px（BaseScrollPane.as:100-104 handleWheel）。
var _滚行 := 4.0
var _chat_expanded := false
var _chat_tabs: Array[TextureButton] = []
var _channel_menu: Control
var _face_panel: Control
var _喇叭条: Control
var _喇叭列表: VBoxContainer
var _喇叭到期: Array[int] = []
## MButton3 三态（同小地图口径）：原版只给皮肤加 `getLightFilter(±30/−40)`，
## 文字另走 `_textColors`（`MButton3.as:520-528`），Godot 的 shader 会被子 Label 继承 ⇒ 烘图换皮。
var _态皮肤 := {
	"页签综合": ["聊天页签", "聊天页签_悬停", "聊天页签_按下"],
	"页签普通": ["聊天页签", "聊天页签_悬停", "聊天页签_按下"],
	"页签私聊": ["聊天页签", "聊天页签_悬停", "聊天页签_按下"],
	"页签队伍": ["聊天页签", "聊天页签_悬停", "聊天页签_按下"],
	"页签家族": ["聊天页签", "聊天页签_悬停", "聊天页签_按下"],
	"页签世界": ["聊天页签", "聊天页签_悬停", "聊天页签_按下"],
	"表情钮": ["聊天表情钮", "聊天表情钮_悬停", "聊天表情钮_按下"],
	"展开钮": ["聊天展开钮", "聊天展开钮_悬停", "聊天展开钮_按下"],
	"频道钮": ["聊天频道钮", "聊天频道钮_悬停", "聊天频道钮_按下"],
	"发送钮": ["聊天发送钮", "聊天发送钮_悬停", "聊天发送钮_按下"],
}
var _态实例: Dictionary = {}
var _皮目录 := "res://素材/界面/专用控件/%s.png"
var _selected_tab := 0
var _selected_channel := 4
## 已插进输入框的物品（原版 `ChatPane.showItems`）：最多 3 件、同 id 不重复、
## 同名的在片段里带数量。见 `insert_show_item`。
var _show_items: Array[Dictionary] = []
var _chat_messages: Array[Dictionary] = []
var _input_history: Array[String] = []
var _history_index := 0
var _last_world_send_msec := -5000
var _last_send_msec := -1000
var _msg_id := 0
var _tab_blink: Array[bool] = []
var _tab_blink_timer := 0.0
var _tab_blink_on := false
var _whisper_target := ""
var _chat_hidden := false
var _chat_tween: Tween

func _ready() -> void:
	transform = Transform2D.IDENTITY
	## 目标信息条那颗「私聊」钮（原版 `ChatEvent.CHECK_ONLINE`）要能找到这块聊天栏，
	## 但 HUD 与聊天栏在场景树里隔了好几层 ⇒ 用组名取（与 `player` 那一族同一个套路）。
	add_to_group("chat_panel")
	_session = get_node_or_null("/root/GameSession")
	_backend = get_node_or_null("/root/BackendConnection")
	_position_chat()
	_hide_button.pressed.connect(func(): _set_chat_hidden(true))
	_show_button.pressed.connect(func(): _set_chat_hidden(false))
	for 钮 in [_hide_button, _show_button]:
		钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_setup_chat()
	for 名 in ["滚动条/滚动上", "滚动条/滚动下", "滚动条/滑块"]:
		var 钮 := _chat_content.get_node_or_null(名) as Control
		if 钮 != null:
			钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _session != null:
		_session.notification_requested.connect(_on_notification)
	if _backend != null:
		_backend.chat_received.connect(_on_backend_chat)
		_backend.server_message_received.connect(_on_notification)

func _process(delta: float) -> void:
	_tab_blink_timer += delta
	if _tab_blink_timer >= 0.5:
		_tab_blink_timer = 0.0
		_tab_blink_on = not _tab_blink_on
		for tab_index in _tab_blink.size():
			if _tab_blink[tab_index] and tab_index < _chat_tabs.size():
				_chat_tabs[tab_index].modulate.a = 1.0 if _tab_blink_on else 0.4
			elif tab_index < _chat_tabs.size():
				_chat_tabs[tab_index].modulate.a = 1.0
		刷新喇叭()	# 30s 到期自清（`ChatSpeakerPane.as:296-317`），0.5s 粒度足够
	_刷新滚动条显隐()

## 鼠标是否落在整块聊天栏（含展开后的 chatBg）上。
func _悬停栏() -> bool:
	return _在聊天栏内(_鼠标位)

func _在聊天栏内(p: Vector2) -> bool:
	var 底 := _chat_content.get_node_or_null("面板底") as Control
	return 底 != null and 底.get_global_rect().has_point(p)

## 滚动条平时不显示（用户实机打回）：只有鼠标在栏上、且确有可滚量时才出条。
func _刷新滚动条显隐() -> void:
	if _chat_scroll == null:
		return
	var 要 := _悬停栏() and _滚动上限() > 0.0
	if _chat_scroll.visible != 要:
		_chat_scroll.visible = 要

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_鼠标位 = (event as InputEventMouseMotion).global_position
		_刷新滚动条显隐()	# 量具是同一帧推 motion 就点，显隐必须同步翻
	elif _chat_scroll_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_chat_scroll_dragging = false
		_sync_chat_scroll_thumb()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var 轮 := event as InputEventMouseButton
		if (轮.button_index == MOUSE_BUTTON_WHEEL_UP or 轮.button_index == MOUSE_BUTTON_WHEEL_DOWN) and _悬停栏():
			# 原版整块 chatScrollPane 挂 MOUSE_WHEEL（BaseScrollPane.as:329），滚一格 = 3 × lineScrollSize
			# 向上滚 = 看旧消息 = offset 减小（`_滚动偏移` 0=顶、上限=底）
			_滚像素((-12.0 if 轮.button_index == MOUSE_BUTTON_WHEEL_UP else 12.0) * float(轮.factor))
			get_viewport().set_input_as_handled()

# ⚠️ 这里原来有一枚 `is_input_focused()`（`_chat_input.has_focus()`），**零调用点**。
#    它想办的事（"焦点在输入框里就别吃按键"）2026-10-13 收进了 `玩家._键盘被文本占用()`
#    —— 那边是对**整个视口**判 `gui_get_focus_owner()`，聊天框、搜索框、改名框一起管；
#    玩家在 `脚本/角色/` 下、聊天面板在 `脚本/界面/` 下，反向依赖不该建。
#    ⚠ 别再往这儿加一份"只有聊天框算数"的判据（§3.116 死代码是陷阱）。

func _position_chat() -> void:
	# 聊天内容底边固定 STAGE−67（`UIMain2.as:4257` y=STAGE−266 + 高 199）；展开只把
	# 面板底/滚动区**向上长**（`ChatPane.as:353-383` chatBg.y−=200、height+=200），页签与输入行不动。
	_摆展开几何()
	if _chat_tween == null or not _chat_tween.is_running():
		_chat_content.position.x = -_chat_content.size.x - 2.0 if _chat_hidden else 1.0
	_position_toggle_buttons()

## 按 `_chat_expanded` 摆 chatBg/滚动区/喇叭条（展开 delta=200，收起 0）。
func _摆展开几何() -> void:
	var d := RESIZE_HEIGHT if _chat_expanded else 0.0
	var 底 := _chat_content.get_node_or_null("面板底") as NinePatchRect
	if 底 != null:
		底.position = Vector2(0.0, -d)
		底.size = Vector2(278.0, 199.0 + d)
	var 窗口 := _chat_content.get_node_or_null("消息窗口") as Control
	if 窗口 != null:
		窗口.position = Vector2(41.0, 7.0 - d)
		窗口.size = Vector2(250.0, 144.0 + d)
	_可视高 = 144.0 + d
	_滚动偏移 = clampf(_滚动偏移, 0.0, _滚动上限())
	_应用滚动()
	var 条 := _chat_content.get_node_or_null("滚动条") as Control
	if 条 != null:
		条.position = Vector2(26.0, 7.0 - d)
		条.size = Vector2(15.0, 144.0 + d)
	var 槽 := _chat_content.get_node_or_null("滚动条/滚动槽") as TextureRect
	if 槽 != null:
		槽.size = Vector2(15.0, 116.0 + d)
	var 下 := _chat_content.get_node_or_null("滚动条/滚动下") as TextureButton
	if 下 != null:
		下.position.y = 130.0 + d
	if _喇叭条 != null:
		_喇叭条.position.y = -26.0 - d

## 箭头按钮不随聊天展开移动：原版固定 y = STAGE_HEIGHT - 66、x = 1
func _position_toggle_buttons() -> void:
	for button: TextureButton in [_hide_button, _show_button]:
		if button == null:
			continue
		# 保留场景里美术标定的按钮尺寸，只重排位置
		var 宽 := button.offset_right - button.offset_left
		var 高 := button.offset_bottom - button.offset_top
		button.offset_left = 1.0
		button.offset_right = 1.0 + 宽
		button.offset_top = -箭头按钮留白
		button.offset_bottom = -箭头按钮留白 + 高

func _setup_chat() -> void:
	_chat_log = _chat_content.get_node_or_null("消息窗口/消息区") as RichTextLabel
	_chat_input = _chat_content.get_node_or_null("输入框") as LineEdit
	_send_button = _chat_content.get_node_or_null("发送钮") as TextureButton
	_expand_button = _chat_content.get_node_or_null("展开钮") as TextureButton
	_channel_button = _chat_content.get_node_or_null("频道钮") as TextureButton
	_face_button = _chat_content.get_node_or_null("表情钮") as TextureButton
	_chat_scroll = _chat_content.get_node_or_null("滚动条") as Control
	_chat_scroll_up = _chat_content.get_node_or_null("滚动条/滚动上") as TextureButton
	_chat_scroll_down = _chat_content.get_node_or_null("滚动条/滚动下") as TextureButton
	_chat_scroll_thumb = _chat_content.get_node_or_null("滚动条/滑块") as TextureButton
	_喇叭条 = _chat_content.get_node_or_null("喇叭条") as Control
	_喇叭列表 = _chat_content.get_node_or_null("喇叭条/喇叭列表") as VBoxContainer
	if _chat_log != null:
		_chat_log.meta_clicked.connect(_on_chat_meta_clicked)
	for index in CHAT_TABS.size():
		var tab := _chat_content.get_node_or_null("页签" + CHAT_TABS[index]) as TextureButton
		if tab == null:
			continue
		tab.pressed.connect(_select_chat_tab.bind(index))
		_chat_tabs.append(tab)
		_tab_blink.append(false)
		_绑三态(tab, tab.get_node_or_null("Label") as Label)
	if _send_button != null:
		_send_button.pressed.connect(_send_chat)
		_绑三态(_send_button)
	if _chat_input != null:
		_chat_input.text_submitted.connect(func(_text: String): _send_chat())
		_chat_input.gui_input.connect(_on_chat_input_gui_input)
	if _expand_button != null:
		_expand_button.toggled.connect(_set_chat_expanded)
		_绑三态(_expand_button)
	if _channel_button != null:
		_channel_button.pressed.connect(_toggle_channel_menu)
		_绑三态(_channel_button)
	if _face_button != null:
		_face_button.pressed.connect(_toggle_face_panel)
		_绑三态(_face_button)
	if _chat_scroll_up != null:
		_chat_scroll_up.pressed.connect(_scroll_chat.bind(-1))
	if _chat_scroll_down != null:
		_chat_scroll_down.pressed.connect(_scroll_chat.bind(1))
	if _chat_scroll_thumb != null:
		_chat_scroll_thumb.gui_input.connect(_on_chat_scroll_thumb_input)
	_bind_channel_menu()
	_bind_face_panel()
	_select_chat_tab(0)
	_update_channel_label()

func _select_chat_tab(index: int) -> void:
	_selected_tab = clampi(index, 0, CHAT_TABS.size() - 1)
	# 原版互斥 = **选中枚 disabled**（`ChatPane.as:873-880`：旧选中 enabled=true、新选中 false），
	# 灰皮走 `texture_disabled`（getGrayFilter 烘焙），不是 selectedUpSkin。
	for tab_index in _chat_tabs.size():
		_chat_tabs[tab_index].disabled = tab_index == _selected_tab
		_设三态(_chat_tabs[tab_index], 0)
	if _selected_tab < _tab_blink.size():
		_tab_blink[_selected_tab] = false
	# 切到非综合页时，同步下拉频道（原版 ChatPane.as:881-886 仅非综合页同步）
	if _selected_tab > 0:
		_selected_channel = _selected_tab - 1
		_update_channel_label()
	_render_chat_messages()
	if _chat_log != null:
		_chat_log.tooltip_text = "%s频道" % CHAT_TABS[_selected_tab]

func _bind_channel_menu() -> void:
	_channel_menu = _chat_content.get_node_or_null("频道菜单") as Control
	if _channel_menu == null:
		return
	var list := _channel_menu.get_node("频道列表") as VBoxContainer
	for index in mini(CHAT_CHANNELS.size(), list.get_child_count()):
		var button := list.get_child(index) as Button
		button.pressed.connect(_select_chat_channel.bind(index))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _toggle_channel_menu() -> void:
	if _channel_menu != null:
		_channel_menu.visible = not _channel_menu.visible
	if _face_panel != null:
		_face_panel.hide()

func _bind_face_panel() -> void:
	_face_panel = _chat_content.get_node_or_null("表情面板") as Control
	if _face_panel == null:
		return
	# 原版点表情或鼠标移出整窗即关（`FaceWindow2.as:22,81-99`）。
	# ⚠ 只挂 `表情面板` 自己的 mouse_exited：`表情底` 与 `表情网格` 是兄弟，
	# 挂底的 mouse_exited 会在鼠标从底移到格子的瞬间把面板关掉（用户实机打回 bug1）。
	var 底 := _face_panel.get_node_or_null("表情底") as Control
	if 底 != null:
		底.mouse_filter = Control.MOUSE_FILTER_STOP
	_face_panel.mouse_exited.connect(_收表情面板)
	var grid := _face_panel.get_node("表情网格") as GridContainer
	for face_index in mini(FACE_COUNT, grid.get_child_count()):
		var face_id := face_index + 1
		var button := grid.get_child(face_index) as TextureButton
		var path := FACE_PATH % face_id
		if ResourceLoader.exists(path):
			button.texture_normal = load(path) as Texture2D
		button.pressed.connect(_insert_chat_face.bind(face_id))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _收表情面板() -> void:
	if _face_panel != null and _face_panel.visible:
		_face_panel.hide()

func _toggle_face_panel() -> void:
	if _face_panel == null:
		return
	if _face_panel.visible:
		_face_panel.hide()
		return
	# 原版弹在鼠标处向上开（`UIMain2.as:4058-4062`）。运行期鼠标只在表情钮上，
	# 等价于**锚在表情钮**：x=钮右缘−面板宽、y=页签顶−面板高（不读 get_local_mouse_position，
	# 那是 OS 光标、合成事件改不动它，量具会飘）。
	if _face_button != null:
		_face_panel.position = Vector2(
			_face_button.position.x + _face_button.size.x - _face_panel.size.x,
			_face_button.position.y - _face_panel.size.y)
	_face_panel.show()
	if _channel_menu != null:
		_channel_menu.hide()

func _select_chat_channel(index: int) -> void:
	_selected_channel = clampi(index, 0, CHAT_CHANNELS.size() - 1)
	if _chat_input != null:
		_chat_input.text = "/" if CHAT_CHANNELS[_selected_channel] == "私聊" else ""
		_chat_input.caret_column = _chat_input.text.length()
		_chat_input.grab_focus()
	_update_channel_label()
	if _channel_menu != null:
		_channel_menu.hide()

func _update_channel_label() -> void:
	if _channel_button == null:
		return
	var label := _channel_button.get_node_or_null("Label") as Label
	if label != null:
		label.text = CHAT_CHANNELS[_selected_channel]

## 复刻 ChatUtil.formatMessage：『频道』+ 玩家名链接 + 说 + ：正文
## is_self 为真时用「你说」；私聊另有「你对X说」/「X对你说」两种句式。
func _format_chat_message(channel: String, speaker: String, body: String, is_self: bool, target: String = "") -> String:
	var channel_color: String = String(CHAT_COLORS.get(channel, "#ffffff"))
	var prefix := "[color=%s]『%s』[/color]" % [channel_color, channel]
	var middle := ""
	if channel == "系统" or channel == "公告":
		# 系统/公告没有发言人，标签用玩家名色，正文纯白
		return "[color=%s]『%s』[/color][color=#ffffff]%s[/color]" % [CHAT_NAME_COLOR, channel, _正文(body)]
	if is_self and channel == "私聊":
		middle = "[color=#ffffff]你对%s[color=#ffffff]说[/color][/color]" % _name_link(target)
	elif is_self:
		middle = "[color=#ffffff]你说[/color]"
	elif channel == "私聊":
		middle = "%s[color=#ffffff]对你说[/color]" % _name_link(speaker)
	else:
		middle = "%s[color=#ffffff]说[/color]" % _name_link(speaker)
	var text := "[color=%s]：%s[/color]" % [channel_color, _正文(body)]
	return prefix + middle + text

## 正文进聊天之前的**唯一一道口子**：服务端 HTML → BBCode，再换表情。
##
## 顺序固定「先翻译、后表情」：`[fN]` 只有**我们自己**的输入链路会插（服务端发的 HTML 里没有），
## 放最后换 ⇒ 生成的 `[img=…]` 不会再进一遍剥标签的兜底。⚠ 那步兜底的正则是
## `<[a-zA-Z/][^>]*>`，只管尖括号、本来吃不掉方括号的 `[img=…]` ⇒ 这条是**不变量**、不是"倒过来就坏"，
## 谁调换顺序门里那条字面钉会红，先想清楚再动。
##
## 为什么必须有这一道：用户 2026-10-21 报的 2.3「写轮眼突破那条系统消息把 `font color` 当正文显示」。
## 服务端那条（`fake_flash_server.py:52917` 文案 + `:40252 _rare_event_markup` 上色）逐字是
## `<font color="#ffff00"><font color="#00ff00">木叶英雄</font>成功将【<font color="#ff5498">写轮眼</font>】`
## `进阶至<font color="#00ff00">3阶</font>！</font>` —— 外层黄、人名绿、【】内粉、数字绿。
## BBCode 里 `<` 不是标签字符 ⇒ 不过这一道就是**整串原样上屏**，玩家看见的就是尖括号里的英文。
func _正文(原文: String) -> String:
	return _parse_chat_faces(富文本.译文为BBCode(原文))

## 玩家名做成可点击链接（原版 <a href="event:player|名字"><u>名字</u></a>）
func _name_link(player_name: String) -> String:
	return "[color=%s][url=player|%s][u]%s[/u][/url][/color]" % [CHAT_NAME_COLOR, player_name, player_name]

## 把 [fN] 替换成真实表情图，超过 5 个的丢弃（对齐 ChatUtil.replaceFace）
func _parse_chat_faces(text: String) -> String:
	var regex := RegEx.create_from_string("\\[f(\\d{1,2})\\]")
	var result := ""
	var cursor := 0
	var count := 0
	for found in regex.search_all(text):
		result += text.substr(cursor, found.get_start() - cursor)
		cursor = found.get_end()
		var face_id := int(found.get_string(1))
		if face_id < 1 or face_id > FACE_COUNT:
			result += found.get_string(0)
			continue
		count += 1
		if count > INSERT_FACE_MAX_COUNT:
			continue
		var path := FACE_PATH % face_id
		if ResourceLoader.exists(path):
			result += "[img=%dx%d]%s[/img]" % [FACE_RENDER_SIZE, FACE_RENDER_SIZE, path]
		else:
			result += found.get_string(0)
	result += text.substr(cursor)
	return result

## 按 MessagePosition 位掩码归页：综合页显示全部，其余页只显示自己的位
func _push_chat_message(channel: String, bbcode: String, position: int = -1) -> void:
	_msg_id += 1
	var pos := position
	if pos < 0:
		pos = int(CHANNEL_POSITIONS.get(channel, POS_GENERAL))
	_chat_messages.append({
		"record_id": _msg_id,
		"channel": channel,
		"position": pos,
		"bbcode": bbcode,
	})
	if _chat_messages.size() > DEFAULT_SHOW_CHAT_COUNT:
		_chat_messages.pop_front()
	_flag_tab_blink(pos)
	_render_chat_messages()

## 非当前页收到私聊/队伍/家族消息时，页签闪动提示（原版 ShandongBtnF）
func _flag_tab_blink(position: int) -> void:
	if position != POS_WHISPER and position != POS_PARTY and position != POS_GUILD:
		return
	var tab_index := TAB_POSITIONS.find(position)
	if tab_index < 0 or tab_index == _selected_tab or tab_index >= _tab_blink.size():
		return
	_tab_blink[tab_index] = true

func _render_chat_messages() -> void:
	if _chat_log == null:
		return
	# 原版**没有「综合=全显示」合并机制**（真值 §4）：消息按 position 只进一个包，
	# 综合包只收 MISC（系统/公告）。旧实现把综合当全频道合并是自造的，已按 AS3 改回。
	var want: int = int(TAB_POSITIONS[_selected_tab])
	_chat_log.clear()
	var first := true
	for item in _chat_messages:
		var pos := int(item.get("position", POS_GENERAL))
		# 喇叭消息进综合页，但不属于任何单频道页
		if want >= 0 and pos != want:
			continue
		if not first:
			_chat_log.append_text("\n")
		_chat_log.append_text(String(item.get("bbcode", "")))
		first = false
	var 全高 := maxf(_可视高, float(_chat_log.get_content_height()))
	var 在底 := _滚动偏移 >= _滚动上限() - 1.0
	_chat_log.size.y = 全高
	_滚动偏移 = clampf(_滚动偏移, 0.0, _滚动上限())
	if 在底:
		_滚动偏移 = _滚动上限()	# 跟底（原版 updateChatScrollPane：一直在底部就贴底）
	_应用滚动()
	call_deferred("_sync_chat_scroll_thumb")

func _滚像素(px: float) -> void:
	if _chat_log == null:
		return
	_滚动偏移 = clampf(_滚动偏移 + px, 0.0, _滚动上限())
	_应用滚动()
	_sync_chat_scroll_thumb()

func _scroll_chat(line_delta: int) -> void:
	_滚像素(float(line_delta) * _滚行)

func _滚动上限() -> float:
	if _chat_log == null:
		return 0.0
	return maxf(0.0, _chat_log.size.y - _可视高)

func _应用滚动() -> void:
	if _chat_log == null:
		return
	_chat_log.position.y = -_滚动偏移

func _on_chat_scroll_thumb_input(event: InputEvent) -> void:
	if _chat_scroll_thumb == null or _chat_scroll == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_chat_scroll_dragging = event.pressed
		if event.pressed:
			_chat_scroll_drag_offset = event.position.y
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _chat_scroll_dragging:
		var track_top := 14.0
		var track_end := _chat_scroll.size.y - 14.0
		var track_bottom := track_end - _chat_scroll_thumb.size.y
		var pointer_y := _chat_scroll.get_local_mouse_position().y - _chat_scroll_drag_offset
		var thumb_y := clampf(pointer_y, track_top, maxf(track_top, track_bottom))
		_chat_scroll_thumb.position.y = thumb_y
		_同步滑块底()
		var 上限 := _滚动上限()
		if track_bottom > track_top:
			var ratio := (thumb_y - track_top) / (track_bottom - track_top)
			_滚动偏移 = lerpf(0.0, 上限, clampf(ratio, 0.0, 1.0))
			_应用滚动()
		get_viewport().set_input_as_handled()

## 滑块视觉是 `滑块底`（NinePatchRect，九宫格 6/9.25），`滑块` 只是同矩形热区。
func _同步滑块底() -> void:
	var 底 := _chat_scroll.get_node_or_null("滑块底") as NinePatchRect if _chat_scroll != null else null
	if 底 != null:
		底.position = _chat_scroll_thumb.position
		底.size = _chat_scroll_thumb.size
		底.visible = _chat_scroll_thumb.visible

func _sync_chat_scroll_thumb() -> void:
	if _chat_log == null or _chat_scroll == null or _chat_scroll_thumb == null or _chat_scroll_dragging:
		return
	# 轨道 14..(高−14)：上下箭头各 14（`ScrollBar.as:278-283 setSize(15,14)`）
	var track_top := 14.0
	var track_end := _chat_scroll.size.y - 14.0
	var track_height := maxf(1.0, track_end - track_top)
	var 全高 := maxf(_可视高, _chat_log.size.y)
	var 上限 := _滚动上限()
	# `ScrollBar.as:145-154`：thumb 高 = max(13, 页/内容 × 轨道)，无可滚量 ⇒ 隐藏
	var thumb_height := clampf(track_height * _可视高 / 全高, 13.0, track_height)
	_chat_scroll_thumb.visible = 上限 > 0.0
	_chat_scroll_thumb.size = Vector2(15.0, thumb_height)
	var track_bottom := track_end - thumb_height
	var ratio := 0.0 if 上限 <= 0.0 else clampf(_滚动偏移 / 上限, 0.0, 1.0)
	_chat_scroll_thumb.position = Vector2(0.0, lerpf(track_top, maxf(track_top, track_bottom), ratio))
	_同步滑块底()
	_chat_scroll_up.disabled = 上限 <= 0.0 if _chat_scroll_up != null else false
	_chat_scroll_down.disabled = 上限 <= 0.0 if _chat_scroll_down != null else false

func _on_chat_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	## 原版 `__onKeyDown:815-831`（焦点在输入框那一支）：ESC ⇒ `API.resetFocus()` 放出焦点；
	## **正文为空**时 ENTER / 左 / 右 也放出焦点 —— 非空的 ENTER 才交给 `text_submitted` 去发。
	## ⚠ 必须在下面那条"没有历史记录就 return"之前判：一次没发过言的玩家按 ESC 也该退得出输入框。
	if key.keycode == KEY_ESCAPE or (_chat_input.text.is_empty() and (
			key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
			or key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT)):
		_chat_input.release_focus()
		get_viewport().set_input_as_handled()
		return
	if _input_history.is_empty():
		return
	if key.keycode == KEY_UP:
		_history_index = wrapi(_history_index - 1, 0, _input_history.size())
	elif key.keycode == KEY_DOWN:
		_history_index = wrapi(_history_index + 1, 0, _input_history.size())
	else:
		return
	_chat_input.text = _input_history[_history_index]
	_chat_input.caret_column = _chat_input.text.length()
	get_viewport().set_input_as_handled()

## 原版 `ChatPane.as:835-848`（`__onKeyDown` 的 else 支，= 焦点**不在**聊天框时）：
## 舞台级 ENTER ⇒ `API.resetFocus(this.inputTextField)` 把光标抢进聊天框；
## （那一格里还有一句「焦点在商城搜索框 ⇒ 改成 __search()」—— Godot 这边不用照抄：
## 别的 LineEdit 拿到 ENTER 会在自己的 `_gui_input` 里 `accept_event()`，事件根本走不到这里，
## 所以「焦点在哪」这道分叉是**天然成立**的，写出来反而是自造的判据。ESC 关窗同理归 `窗口管理`。）
## ⚠ 折叠态（`_chat_hidden`）先展开再抢焦点：原版输入框始终在台上，本工程的
## `聊天内容` 折叠时整块滑到屏幕外，直接抢焦点等于把光标藏到看不见的地方。
func _unhandled_key_input(event: InputEvent) -> void:
	var 键 := event as InputEventKey
	if 键 == null or not 键.pressed or 键.echo:
		return
	if 键.keycode != KEY_ENTER and 键.keycode != KEY_KP_ENTER:
		return
	if _chat_input == null:
		return
	if _chat_hidden:
		_set_chat_hidden(false)
	_chat_input.grab_focus()
	# ⚠ `accept_event()` 是 **Control** 上的方法，本脚本 `extends CanvasLayer` ⇒ 直接调会解析期就报
	#   "Function accept_event() not found in base self"（整个脚本挂掉）。走视口那份。
	get_viewport().set_input_as_handled()

func _insert_chat_face(face_id: int) -> void:
	if _chat_input == null:
		return
	var face_count := _chat_input.text.count("[f")
	if face_count >= 5:
		_chat_input.tooltip_text = "一条消息最多插入 5 个表情"
		return
	_chat_input.insert_text_at_caret("[f%d]" % face_id)
	if _face_panel != null:
		_face_panel.hide()
	_chat_input.grab_focus()

## ── MButton3 三态（同小地图口径：换 `texture_normal`，不用 texture_hover/shader）──
## 原版 `mouseUpHandler`（`MButton3.as:103-108`）松手回 **UP 而不是 OVER**，
## Godot 的 `texture_hover` 做不到；shader 又会被子 Label 继承（文字该换色不该变亮）。
func _绑三态(钮: TextureButton, 文字: Label = null) -> void:
	_态实例[钮] = {"态": 0, "文字": 文字}
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.mouse_entered.connect(_设三态.bind(钮, 1))
	钮.mouse_exited.connect(_设三态.bind(钮, 0))
	钮.button_down.connect(_设三态.bind(钮, 2))
	# 松手回 `STATE_UP`（`MButton3.as:103-108` mouseUpHandler 字面如此）。
	# 页签"点完一直保持按下样"不是靠这个：`MTabButton.set enabled()` 里 `selected = !enabled`
	# ⇒ 选中那枚换 `selectedUpSkin`（= symbol210 真皮，见 场景 texture_disabled），其余枚回常态。
	钮.button_up.connect(_设三态.bind(钮, 0))
	_设三态皮肤(钮)

func _设三态皮肤(钮: TextureButton, 组名: String = "") -> void:
	var 组: Array = _态皮肤.get(钮.name if 组名.is_empty() else 组名, [])
	if 组.is_empty():
		push_error("钮 %s 没登记三态皮肤：悬停/按下不会反馈" % 钮.name)
		return
	if not _态实例.has(钮):
		_绑三态(钮)
	_态实例[钮]["皮肤"] = 组
	_设三态(钮, int(_态实例[钮]["态"]))

func _设三态(钮: TextureButton, 态: int) -> void:
	if not _态实例.has(钮):
		return
	var 实例: Dictionary = _态实例[钮]
	实例["态"] = 态
	var 组: Array = 实例.get("皮肤", [])
	if 组.is_empty():
		return
	var 文字: Label = 实例.get("文字")
	if 钮.disabled:
		# 选中枚 = disabled：皮由 `texture_disabled`（symbol210 真皮）出，这里只把字色按
		# `ChatPane.as:246 setAllStatsColor(up,over,down,disabled)` 的 disabled 档钉回 #D8DCE6，
		# 否则会停在悬停那档的 #F3F3F4。
		if 文字 != null:
			文字.add_theme_color_override("font_color", TAB_COLOR_NORMAL)
		return
	# 三档各回各皮（`StyleUtil.as:8-12` skinFilters up 0 / over +30 / down −40）
	钮.texture_normal = load(_皮目录 % String(组[态])) as Texture2D
	if 文字 != null:
		文字.add_theme_color_override("font_color", TAB_COLOR_OVER if 态 == 1 else TAB_COLOR_NORMAL)

## ── 喇叭条（`ChatSpeakerPane.as`：独立浮条、上限 3 条、30s 自清，不进消息列表）──
func _push_speaker(bbcode: String) -> void:
	if _喇叭条 == null or _喇叭列表 == null:
		return
	var 行 := RichTextLabel.new()
	行.name = "喇叭%d" % (_喇叭列表.get_child_count() + 1)
	行.bbcode_enabled = true
	行.custom_minimum_size = Vector2(272, 18)
	行.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.add_theme_font_size_override("normal_font_size", 12)
	行.add_theme_color_override("default_color", Color("#e15204"))
	行.append_text(bbcode)
	_喇叭列表.add_child(行)
	while _喇叭列表.get_child_count() > SPEAKER_MAX:
		var 旧 := _喇叭列表.get_child(0)
		_喇叭列表.remove_child(旧)
		旧.queue_free()
	_喇叭条.visible = true
	_喇叭条.size.y = 6.0 + 18.0 * _喇叭列表.get_child_count()
	_喇叭条.position.y = -_喇叭条.size.y - 1.0 - (RESIZE_HEIGHT if _chat_expanded else 0.0)
	_喇叭到期.append(Time.get_ticks_msec() + SPEAKER_TTL_MS)
	刷新喇叭()

func 刷新喇叭() -> void:
	if _喇叭条 == null:
		return
	var 现在 := Time.get_ticks_msec()
	while not _喇叭到期.is_empty() and _喇叭到期[0] <= 现在:
		_喇叭到期.pop_front()
		if _喇叭列表.get_child_count() > 0:
			var 旧 := _喇叭列表.get_child(0)
			_喇叭列表.remove_child(旧)
			旧.queue_free()
	if _喇叭列表.get_child_count() == 0:
		_喇叭条.visible = false
	else:
		_喇叭条.size.y = 6.0 + 18.0 * _喇叭列表.get_child_count()
		_喇叭条.position.y = -_喇叭条.size.y - 1.0 - (RESIZE_HEIGHT if _chat_expanded else 0.0)

func _set_chat_expanded(expanded: bool) -> void:
	_chat_expanded = expanded
	_摆展开几何()
	# 原版不旋转皮（`ChatPane.as:353-383` 只 ±200 拉伸 chatBg/滚动区，页签与输入行不动；
	# selectedUpSkin 有无第二张皮在符号内、未证 ⇒ 两态同皮）
	if _expand_button != null:
		_expand_button.tooltip_text = "收起" if expanded else "展开"
	call_deferred("_sync_chat_scroll_thumb")

func _set_chat_hidden(hidden: bool) -> void:
	if _chat_hidden == hidden:
		return
	_chat_hidden = hidden
	if _chat_tween != null and _chat_tween.is_valid():
		_chat_tween.kill()
	_hide_button.visible = false
	_show_button.visible = false
	var target_x := -_chat_content.size.x - 2.0 if hidden else 1.0
	_chat_tween = create_tween()
	_chat_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_chat_tween.tween_property(_chat_content, "position:x", target_x, 0.5)
	_chat_tween.finished.connect(_finish_chat_slide)

func _finish_chat_slide() -> void:
	_hide_button.visible = not _chat_hidden
	_show_button.visible = _chat_hidden

func _send_chat() -> void:
	if _chat_input == null or _chat_log == null:
		return
	var message := _chat_input.text.strip_edges()
	if message.is_empty():
		return
	var channel: String = String(CHAT_CHANNELS[_selected_channel])
	if channel == "私聊":
		var separator := message.find(" ")
		if not message.begins_with("/") or separator <= 1 or separator >= message.length() - 1:
			_set_chat_tip("私聊格式：/玩家名 消息", channel)
			return
	if channel == "喇叭":
		# 客户端无背包数据，喇叭道具不足按原版给提示后拦截
		if _session == null or int(_session.player_stats.get("laba_count", 0)) <= 0:
			_set_chat_tip(CHAT_TIP_LABA_COUNT, CHAT_TABS[_selected_tab])
			return
	if channel == "世界":
		var world_now := Time.get_ticks_msec()
		if _last_world_send_msec > 0 and world_now - _last_world_send_msec < WORLD_CHANNEL_TIME_CD:
			_set_chat_tip(CHAT_TIP_PUBLIC_CHAT_CD, channel)
			return
		_last_world_send_msec = world_now
	# 全频道 1 秒防刷屏（原版 checkTime）
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_send_msec < REPEAT_SEND_CD:
		_set_chat_tip(CHAT_TIP_SEND_TOO_FAST, channel)
		return
	_last_send_msec = now_msec
	var player_name := String(_session.player_stats.get("name", "忍者")) if _session != null else "忍者"
	var body := message
	var target := ""
	if channel == "私聊":
		var separator := message.find(" ")
		target = message.substr(1, separator - 1)
		_whisper_target = target
		body = message.substr(separator + 1)
	var sent_online := false
	if _backend != null and bool(_backend.in_game):
		var message_type: int = int({"普通": 3, "私聊": 4, "队伍": 5, "家族": 6, "世界": 7, "喇叭": 8}.get(channel, 3))
		sent_online = _backend.request_chat(body, message_type, 0, target)
		if not sent_online:
			_set_chat_tip("消息发送失败，服务器连接不可用", channel)
			return
	else:
		var bbcode := _format_chat_message(channel, player_name, body, true, target)
		if channel == "喇叭":
			_push_speaker(bbcode)	# 原版喇叭不进消息列表，走独立浮条（`ChatPane.as:1659-1664`）
		else:
			_push_chat_message(channel, bbcode)
	_input_history.append(message)
	if _input_history.size() > DEFAULT_SHOW_CHAT_COUNT:
		_input_history.pop_front()
	_history_index = _input_history.size()
	# 私聊保留 "/对象 " 前缀，方便连续对话（原版行为）
	_chat_input.text = "/%s " % _whisper_target if channel == "私聊" and _whisper_target != "" else ""
	_chat_input.caret_column = _chat_input.text.length()
	_chat_input.grab_focus()

## 目标信息条那颗「私聊」钮（原版 `_whisper():360-365` 发 `ChatEvent.CHECK_ONLINE`）与
## 好友行菜单的私聊档共用：**不发包**，只做三件事 —— 切到「私聊」频道、预填 `/名字 `、抢焦点。
func 开始私聊(玩家名: String) -> void:
	if 玩家名.is_empty():
		return
	_selected_channel = CHAT_CHANNELS.find("私聊")
	_whisper_target = 玩家名
	_set_chat_hidden(false)
	if _chat_input != null:
		_chat_input.text = "/%s " % 玩家名
		_chat_input.caret_column = _chat_input.text.length()
		_chat_input.grab_focus()
	_update_channel_label()

func _on_backend_chat(message: Dictionary) -> void:
	# `CHAR_NOTICE` 不进聊天记录（原版只 `addNotice`，见上面常量那条注释）——
	# 提示已经由 `后端连接._handle_chat_text` 发到会话口子、经 `_on_notification` 落成一条，
	# 这里再收一遍就是同句拒绝出现两遍。
	var 位 := int(message.get("positions", POS_GENERAL))
	if 位 == POS_CHAR_NOTICE:
		return
	# `PUB_NOTICE` 同样不进聊天（原版 `UI.as:339-354` 只喂中部通告与信息查询窗）。
	# 服务端每条稀有事件都**成对**发 `positions=1` 和 `=4`（`fake_flash_server.py:40365-40370`），
	# 1 那帧还多带一个 `[JH]` 前缀 —— 不跳过就会在聊天里出现两遍，其中一遍还糊着字面 `[JH]`。
	# 通告条本身没移植（§3.239 F 旧账），4 那帧已经把同一句话带上聊天了，信息不丢。
	if 位 == POS_PUB_NOTICE:
		return
	var type := int(message.get("type", 3))
	var channel := String({1: "系统", 2: "公告", 3: "普通", 4: "私聊", 5: "队伍", 6: "家族", 7: "世界", 8: "喇叭"}.get(type, "普通"))
	var target := String(message.get("target_name", ""))
	var 发言人 := String(message.get("name", "忍者"))
	## 「是不是我说的」按原版算：**帧里的名字 == 我自己的名字**
	## （`UI.as:363/366/373` 那个第五参 `param1.charName == DataCenter.getInstance().stats.name`）。
	## 这里曾硬写成 `true` ⇒ 别人私聊我，我屏上显示成「你对XXX说」（用户 10-17 实机报的 bug2，
	## 9cb038e 修过；10-22 那次 `-X ours` 合并（074dd89）把它连同"在线门没挂号"一起埋了回来 —— §3.255）。
	## 服务端对自己那一发会原样回显（名字 = 我的名字），所以"我说"那档仍然成立，不靠硬编码。
	## ⚠ "我的名字"**不能只取 `GameSession.player_stats`**：那是全局的，双号在线门里会被对面那份连接盖掉
	## ⇒ 一律取**这条连接自己的权威属性**（`authoritative_stats.name`），全局那份只当兜底。
	var 我的名字 := ""
	if _backend != null:
		我的名字 = String((_backend.get("authoritative_stats") as Dictionary).get("name", ""))
	if 我的名字.is_empty() and _session != null:
		我的名字 = String((_session.player_stats as Dictionary).get("name", ""))
	var 是我说的 := not 我的名字.is_empty() and 发言人 == 我的名字
	var bbcode := _format_chat_message(channel, 发言人, String(message.get("message", "")), 是我说的, target)
	if channel == "喇叭":
		_push_speaker(bbcode)
		return
	## 旧账：`GENERAL(8)` 那一路原版**除了**进普通页，还会在说话人头顶冒一个话泡
	## （`UI.as:367-369` 里那句 `_loc3_.speakWords(param1.text)`，`_loc3_` = 名字对上的人物）。
	## 本工程没移植话泡 ⇒ 玩家发在普通频道时「综合页不显示 + 头顶不冒泡」双重静默，
	## 只会觉得"发消息没反应"（用户 2026-10-23 报修 13 的 C 类成因，门 `测试/聊天面板回归测试.gd` 钉着）。
	_push_chat_message(channel, bbcode, int(message.get("positions", CHANNEL_POSITIONS.get(channel, POS_GENERAL))))

## 系统提示走 setTip：『频道』标签 + 白色正文，喇叭频道不提示
## 把一件物品插进聊天输入框（原版 `ChatPane.insertShowItem`，`ChatPane.as:1423`）。
## 三条分支照抄：
##   1) 已经插了 3 件以上 → 提示 `ITEM_INFO_WINDOW_MAX_THREE`「最多插入三个物品」
##   2) 同一件已经插过   → 提示 `ITEM_INFO_WINDOW_INSERTED`「该物品已经插入到聊天输入框」
##   3) 否则：已插过**同名**的就在名字后带上已插数量 —— `【名】` / `【名(2)】`，
##      再按 `ChatUtil.INPUT_MAX_CHARS(100)` 校验长度后插到光标处
func insert_show_item(item_id: String, item_name: String) -> void:
	if _chat_input == null or item_name.is_empty():
		return
	if _show_items.size() > 2:
		_set_chat_tip("最多插入三个物品", _当前频道名())
		return
	for 已插 in _show_items:
		if String(已插.get("id", "")) == item_id:
			_set_chat_tip("该物品已经插入到聊天输入框", _当前频道名())
			return
	var 同名数 := 0
	for 已插 in _show_items:
		if String(已插.get("name", "")) == item_name:
			同名数 += 1
	var 片段 := "【%s(%d)】" % [item_name, 同名数] if 同名数 > 0 else "【%s】" % item_name
	# ⚠️ 原版上限是 `ChatUtil.INPUT_MAX_CHARS = 100`；
	# 本客户端的 `CHAT_INPUT_MAX_CHARS` 是 40（另一处口径，待与聊天模块一起核）——
	# 这里用客户端自己的常量，免得插进去超出实际输入框。
	var 上限 := CHAT_INPUT_MAX_CHARS
	if _chat_input.text.length() + 片段.length() > 上限:
		return
	_show_items.append({"id": item_id, "name": item_name})
	# 插到光标处（原版 `ChatUtil.insertString`）
	var 光标 := _chat_input.caret_column
	_chat_input.text = _chat_input.text.substr(0, 光标) + 片段 + _chat_input.text.substr(光标)
	_chat_input.caret_column = 光标 + 片段.length()
	_chat_input.grab_focus()


func _当前频道名() -> String:
	if _selected_channel < 0 or _selected_channel >= CHAT_CHANNELS.size():
		return "综合"
	return String(CHAT_CHANNELS[_selected_channel])


func _set_chat_tip(text: String, channel: String) -> void:
	if channel == "喇叭":
		return
	var position := int(CHANNEL_POSITIONS.get(channel, POS_GENERAL))
	var bbcode := "[color=%s]『%s』[/color][color=#ffffff]%s[/color]" % [CHAT_NAME_COLOR, channel, text]
	_push_chat_message(channel, bbcode, position)

func _on_notification(message: String) -> void:
	# 这条也过同一道口子：`CHAR_NOTICE`(512) 那份提示文案同样是服务端发的 HTML
	# （`后端连接._handle_chat_text` 原样转过来），不过一遍就会把标签当正文显示。
	var bbcode := "[color=%s]『系统』[/color][color=#ffffff]%s[/color]" % [CHAT_NAME_COLOR, _正文(message)]
	_push_chat_message("系统", bbcode, POS_MISC)

## 玩家名点击弹出操作菜单（原版 getClickCharPopupMenuItems）
func _on_chat_meta_clicked(meta: Variant) -> void:
	var meta_str := String(meta)
	if not meta_str.begins_with("player|"):
		return
	var player_name := meta_str.substr(7)
	if player_name == "":
		return
	_show_player_popup(player_name)

func _show_player_popup(player_name: String) -> void:
	var popup := PopupMenu.new()
	popup.name = "PlayerContextMenu"
	popup.add_item("加为好友", 0)
	popup.add_item("加入黑名单", 1)
	popup.add_item("私聊", 2)
	popup.add_item("邀请入队", 3)
	popup.add_item("查看资料", 4)
	popup.add_item("邀请交易", 5)
	popup.add_item("邀请入家族", 6)
	popup.add_item("选为摊位", 7)
	popup.add_item("发送求婚", 8)
	popup.id_pressed.connect(func(id: int):
		_handle_player_action(player_name, id)
		popup.queue_free()
	)
	add_child(popup)
	popup.popup_centered()

func _handle_player_action(player_name: String, action_id: int) -> void:
	match action_id:
		0:
			_set_chat_tip("已添加好友" if _session.add_friend(player_name) else "无法重复添加好友", CHAT_TABS[_selected_tab])
		1:
			_set_chat_tip("已加入黑名单" if _session.block_player(player_name) else "该玩家已在黑名单中", CHAT_TABS[_selected_tab])
		2: # 私聊
			_selected_channel = CHAT_CHANNELS.find("私聊")
			_whisper_target = player_name
			if _chat_input != null:
				_chat_input.text = "/%s " % player_name
				_chat_input.caret_column = _chat_input.text.length()
				_chat_input.grab_focus()
			_update_channel_label()
		3:
			_set_chat_tip("已邀请入队" if _session.invite_team_member(player_name) else "队伍已满或玩家已在队伍中", CHAT_TABS[_selected_tab])
		4:
			_session.request_feature("人物")
			_session.notification_requested.emit("正在查看 %s 的公开资料（离线数据）" % player_name)
		5:
			_session.create_social_request("交易", player_name)
		6:
			## 聊天右键这一行在原版是**同一发**，不是另一条路：`ChatSpeakerPane.as:144` /
			## `ChatPane.as:1149` / `SearchPlayerWindow.as:59` 三处都转 `FamillyManager.invateToJoinFamilly`
			## → `1552:19:<对方角色号>`。原来这里只 `_session.create_social_request("家族邀请", …)`
			## = 纯本地记账（写存档、发一句"已发送"，对面一个像素都不变）⇒ 改成真发帧。
			## 名字 ⇒ 角色号按**同屏表** `map_players` 解析；解析不到或不在线 ⇒ 说话，不发空号帧去演成功。
			var 发上了 := false
			if _backend != null and bool(_backend.get("in_game")):
				发上了 = bool(_backend.call("request_family_invite_by_name", player_name))
			if 发上了:
				_set_chat_tip("已向 %s 发送入族邀请" % player_name, CHAT_TABS[_selected_tab])
			else:
				_set_chat_tip("族邀要在线发，且对方得在你这片屏幕里", CHAT_TABS[_selected_tab])
		7:
			_session.select_stall_owner(player_name)
		8:
			_session.create_social_request("求婚", player_name)
