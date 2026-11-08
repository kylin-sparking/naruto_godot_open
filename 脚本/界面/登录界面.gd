extends Control

## 登录界面 —— **页面与交互由另一位开发者完成**（2026-09-25 接入，原是他一个独立工程
## `火影世界登录页_工程_20260925`，自带 `project.godot` 与导出预设）。
##
## ⚠️ **他的脚本只发信号、不碰协议**（与手里剑页/结印页同一条边界）：
##    对外 `login_requested` / `register_requested` 两个信号，其余一律不管。
##    所以**协议这一半由融合方接**，就是本文件下面标了「融合方补」的那一段。
##
## 搬过来的改动只有两类（其余与他原文件一致）：
##   * 素材路径 `res://素材/xxx` → `res://素材/界面/登录器/xxx`（按本项目 `素材/界面/` 的约定）；
##   * 页脚原来显示他写死的 `http://127.0.0.1:19280`（那是 **Nya 2.0.8 隔离版**的 HTTP 口，
##     与本项目无关，而且他从没真调用过），改成显示本项目实际连的后端地址。
##
## 登录成功后的**选角 / 创建角色**沿用旧的 `场景/界面/选角窗.tscn`（原登录界面改当覆盖层，
## 见 `_显示选角窗()`）—— 他的登录器只管登录表单，没有这一步。

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")

signal login_requested(username: String, password: String)
signal register_requested(username: String, password: String)

const VIDEO_PATH := "res://素材/界面/登录器/背景循环_1080p.ogv"
const BGM_PATH := "res://素材/界面/登录器/登录器BGM.mp3"
const ICON_ON := "res://素材/界面/登录器/音乐开.png"
const ICON_OFF := "res://素材/界面/登录器/音乐关.png"
const FONT_PATH := "res://素材/界面/登录器/中文字体.tres"
const GOLD := Color(0.91, 0.72, 0.30, 1)
const GOLD_LIGHT := Color(1.0, 0.87, 0.55, 1)
const INK := Color(0.93, 0.94, 1.0, 1)
const MIN_ACCOUNT := 4
const MIN_PASSWORD := 6
const ID_NEW := -100
const ID_DELETE := -101

@onready var _video: VideoStreamPlayer = $背景
@onready var _card: Control = $登录卡片
@onready var _account_input: LineEdit = $登录卡片/账号输入
@onready var _account_arrow: Button = $登录卡片/账号输入/账号箭头
@onready var _account_menu: PopupMenu = $登录卡片/账号输入/账号菜单
@onready var _password_input: LineEdit = $登录卡片/密码输入
@onready var _remember: CheckBox = $登录卡片/记住密码
@onready var _login_button: Button = $登录卡片/登录按钮
@onready var _register_button: Button = $登录卡片/注册按钮
@onready var _status: Label = $登录卡片/状态文字
@onready var _music_button: Button = $音乐按钮
@onready var _bgm: AudioStreamPlayer = $BGM
@onready var _footer: Label = $页脚
@onready var _popup: Control = $注册弹窗
@onready var _popup_panel: Control = $注册弹窗/面板
@onready var _popup_mask: ColorRect = $注册弹窗/遮罩
@onready var _popup_account: LineEdit = $注册弹窗/面板/账号输入
@onready var _popup_password: LineEdit = $注册弹窗/面板/密码输入
@onready var _popup_confirm: LineEdit = $注册弹窗/面板/确认输入
@onready var _popup_hint: Label = $注册弹窗/面板/提示文字
@onready var _popup_submit: Button = $注册弹窗/面板/提交按钮
@onready var _popup_cancel: Button = $注册弹窗/面板/取消按钮


var _backend: Node
var _选角窗: Control
var _注册器: HTTPRequest		# 注册走 HTTP（原版的注册本来就是网页那一条）

## 首帧前**同步**预热 `功能窗口.tscn`（用户 2026-10-25 报「选角色登录游戏有点慢」）。
##
## 实测（真登录界面 / headless）：点角色 → 地图可走 **4.7 秒**，其中
## `change_scene_to_file` 同步加载烘焙地图 **4.15 秒**；这 4.15 秒里 **2.7 秒**
## 是 `窗口管理.gd` 经 `preload` 拖进来的 `功能窗口.tscn`（451KB 脚本 + 104 个
## preload 的编译链）。`窗口管理.gd` 已改成第一次开窗才 `load()`（窗口本来就是
## 懒建的），地图那一跳因此只剩 **1.6 秒**（小地图/头像/技能/聊天面板 + 地图脚本）。
##
## 为什么在**主线程**、而且放在首帧前：
##   * 试过 `ResourceLoader.load_threaded_request` 在登录界面后台预热，**必须放弃**：
##     GDScript 不能在加载工作线程里编译 —— 实测线程与主线程并发加载脚本后，
##     `功能窗口.gd` 的 preload 链被撕成十几条 `Parse Error: Could not preload
##     resource file …`，最后 `Failed to load script`，进游戏后**所有功能窗口都打不开**。
##   * 主线程同步加载 2.7 秒放首帧前 = 启动窗口晚出 2.7 秒，不会在玩家点完角色 /
##     点开第一个面板时再卡；只 `load` PackedScene、不实例化，不碰任何会话状态。
const 功能窗口预热路 := "res://场景/界面/功能窗口.tscn"


func _ready() -> void:
	_apply_theme()
	_setup_video()
	_setup_bgm()
	_setup_form()
	_setup_backend()
	if not ResourceLoader.has_cached(功能窗口预热路):
		load(功能窗口预热路)


func _setup_video() -> void:
	_video.stream = load(VIDEO_PATH)
	_video.expand = false
	_video.loop = true
	_video.play()
	_resize_video.call_deferred()
	resized.connect(_resize_video)


func _resize_video() -> void:
	var natural := _natural_video_size()
	if natural == Vector2.ZERO:
		return
	_video.size = natural
	var cover: float = maxf(size.x / natural.x, size.y / natural.y)
	_video.scale = Vector2(cover, cover)
	_video.position = (size - natural * cover) * 0.5


func _natural_video_size() -> Vector2:
	var tex := _video.get_video_texture()
	if tex != null:
		return tex.get_size()
	return Vector2(1920.0, 1080.0)


func _setup_bgm() -> void:
	_bgm.stream = load(BGM_PATH)
	_bgm.finished.connect(func(): _bgm.play())
	_refresh_music_button()
	if not AccountStore.bgm_muted:
		_bgm.play()


func _refresh_music_button() -> void:
	var muted: bool = AccountStore.bgm_muted
	_music_button.icon = load(ICON_OFF) if muted else load(ICON_ON)
	_music_button.tooltip_text = "背景音乐：已关闭，点击开启" if muted else "背景音乐：播放中，点击关闭"
	_music_button.modulate = Color(0.6, 0.56, 0.5) if muted else Color(0.96, 0.81, 0.51)


func _setup_form() -> void:
	# ⚠️ **融合方改**：原来显示 `AccountStore.server_url`（他写死的 `http://127.0.0.1:19280`）——
	#    那是 **Nya 2.0.8 隔离版**的 HTTP 口，本项目用的是 18684（TCP）/18680（HTTP）；
	#    而且他那个变量**只用来显示、从没真调用过**。这里改成显示**实际连的后端**。
	var 设置: Dictionary = GameSession.game_settings
	_footer.text = "服务器：%s:%d    版本：%s" % [
		String(设置.get("backend_host", "127.0.0.1")),
		int(设置.get("backend_port", 18684)),
		Engine.get_version_info().get("string", ""),
	]
	# ⚠️ **融合方补（2026-10-09）**：注册**不是没有后端** —— 原版注册从来不走游戏服
	#    （走网页：`HYSJ/www/register.php`、`static_flash_http.py:557` 的
	#    `/api/account/register` → `ACCOUNT_SERVICE.register`）。本工程把这一条挂在
	#    本地服务端的控制台口上（`开发工具/GM控制台服务.py`），所以钮**要显出来**，
	#    点击走 HTTP（`_on_register_requested`），不碰游戏套接字。
	_register_button.visible = true
	_popup.visible = false
	# ⚠️ **融合方补（2026-09-25，按用户实机反馈改过一版）**：登录卡片**开局就要有内容**。
	#
	#    他的登录器是"**账号记忆**"：`_fill_account()` 只在**你从下拉里挑一条**时才填，
	#    开局两个框是空的。而旧登录界面一直是**预填**的（开箱即用），用户按老习惯用 ——
	#    实测反馈原话："打开看不到之前的账号信息，需要重新输入"。
	#
	#    第一版我只在**一条账号都没有**时预填，于是"存过账号之后反而不填了"，正好反了。
	#    现在：**有存过的账号就用第一条预填**（等价于开局替用户点一次下拉里的第一项，
	#    走的就是他自己的 `_fill_account()`，密码与「记住密码」勾选一并带出来）；
	#    **一条都没有**才用设置里的默认账号兜底。
	if not AccountStore.accounts.is_empty():
		_fill_account(String((AccountStore.accounts[0] as Dictionary).get("username", "")))
	else:
		_account_input.text = String(设置.get("backend_account", ""))
		_password_input.text = String(设置.get("backend_password", ""))
	_account_arrow.pressed.connect(_open_account_menu)
	_account_menu.id_pressed.connect(_on_account_menu_pressed)
	_music_button.pressed.connect(_on_music_pressed)
	_login_button.pressed.connect(_on_login_pressed)
	_password_input.text_submitted.connect(func(_t: String): _on_login_pressed())
	_register_button.pressed.connect(_open_register_popup)
	_popup_cancel.pressed.connect(_close_register_popup)
	_popup_submit.pressed.connect(_submit_register)
	_popup_mask.gui_input.connect(_on_popup_mask_input)
	for field in [_popup_account, _popup_password, _popup_confirm]:
		field.text_submitted.connect(func(_t: String): _submit_register())


func _apply_theme() -> void:
	var t := Theme.new()
	t.default_font = load(FONT_PATH)
	t.default_font_size = 17
	for type: StringName in [&"Label", &"Button", &"LineEdit", &"OptionButton", &"CheckBox", &"PopupMenu"]:
		t.set_color(&"font_outline_color", type, Color(0, 0, 0, 1))
		t.set_constant(&"font_outline_size", type, 3)
		t.set_color(&"font_shadow_color", type, Color(0, 0, 0, 0))
		t.set_constant(&"font_shadow_offset", type, 0)

	t.set_color(&"font_color", &"Label", INK)
	t.set_color(&"font_color", &"LineEdit", INK)
	t.set_color(&"font_placeholder_color", &"LineEdit", Color(1, 1, 1, 0.38))
	t.set_color(&"caret_color", &"LineEdit", GOLD)
	t.set_color(&"selection_color", &"LineEdit", Color(0.62, 0.44, 0.12, 0.55))
	t.set_stylebox(&"normal", &"LineEdit", _input_box(false))
	t.set_stylebox(&"focus", &"LineEdit", _input_box(true))
	t.set_stylebox(&"read_only", &"LineEdit", _input_box(false))

	t.set_color(&"font_color", &"Button", Color(0.14, 0.10, 0.03, 1))
	t.set_color(&"font_hover_color", &"Button", Color(0.10, 0.07, 0.02, 1))
	t.set_color(&"font_pressed_color", &"Button", Color(0.18, 0.13, 0.05, 1))
	t.set_color(&"font_focus_color", &"Button", Color(0.10, 0.07, 0.02, 1))
	t.set_stylebox(&"normal", &"Button", _gold_box(Color(0.80, 0.55, 0.14), Color(1.0, 0.87, 0.55, 0.85)))
	t.set_stylebox(&"hover", &"Button", _gold_box(Color(0.94, 0.70, 0.22), Color(1.0, 0.93, 0.70)))
	t.set_stylebox(&"pressed", &"Button", _gold_box(Color(0.52, 0.34, 0.06), Color(0.75, 0.58, 0.24)))
	t.set_stylebox(&"disabled", &"Button", _gold_box(Color(0.20, 0.19, 0.23), Color(0.35, 0.33, 0.38, 0.6)))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())

	t.set_color(&"font_color", &"CheckBox", INK)
	t.set_color(&"font_pressed_color", &"CheckBox", INK)
	t.set_color(&"font_focus_color", &"CheckBox", INK)
	t.set_color(&"font_hover_color", &"CheckBox", Color.WHITE)
	t.set_color(&"font_disabled_color", &"CheckBox", Color(0.52, 0.52, 0.60, 1))
	t.set_color(&"checked", &"CheckBox", GOLD)
	t.set_color(&"unchecked", &"CheckBox", Color(0.58, 0.58, 0.66, 1))
	t.set_color(&"hovered", &"CheckBox", GOLD_LIGHT)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		t.set_stylebox(state, &"CheckBox", StyleBoxEmpty.new())

	t.set_color(&"font_color", &"PopupMenu", INK)
	t.set_color(&"font_hover_color", &"PopupMenu", GOLD_LIGHT)
	t.set_color(&"font_disabled_color", &"PopupMenu", Color(0.52, 0.52, 0.60, 1))
	t.set_stylebox(&"panel", &"PopupMenu", _menu_box())
	t.set_stylebox(&"hover", &"PopupMenu", _menu_hover())
	t.set_stylebox(&"separator", &"PopupMenu", _menu_separator())
	self.theme = t

	_card.add_theme_stylebox_override("panel", _panel_box(Color(0.05, 0.05, 0.10, 0.82)))
	_popup_panel.add_theme_stylebox_override("panel", _panel_box(Color(0.05, 0.05, 0.10, 0.96)))
	_music_button.add_theme_stylebox_override("normal", _circle_box(Color(0.07, 0.07, 0.13, 0.72), Color(0.91, 0.72, 0.30, 0.45)))
	_music_button.add_theme_stylebox_override("hover", _circle_box(Color(0.15, 0.14, 0.24, 0.88), Color(1.0, 0.87, 0.55, 0.85)))
	_music_button.add_theme_stylebox_override("pressed", _circle_box(Color(0.04, 0.04, 0.08, 0.95), Color(0.62, 0.47, 0.16, 0.9)))


func _gold_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := _tinted(8)
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.shadow_color = Color(0, 0, 0, 0.40)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	return box


func _panel_box(fill: Color) -> StyleBoxFlat:
	var box := _tinted(14)
	box.bg_color = fill
	box.border_color = Color(0.91, 0.72, 0.30, 0.34)
	box.set_border_width_all(1)
	box.shadow_color = Color(0, 0, 0, 0.50)
	box.shadow_size = 20
	box.shadow_offset = Vector2(0, 8)
	return box


func _input_box(focused: bool) -> StyleBoxFlat:
	var box := _tinted(6)
	box.bg_color = Color(0.02, 0.02, 0.05, 0.78)
	box.border_color = GOLD if focused else Color(0.91, 0.72, 0.30, 0.26)
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _circle_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := _tinted(20)
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _menu_box() -> StyleBoxFlat:
	var box := _tinted(8)
	box.bg_color = Color(0.06, 0.06, 0.11, 0.97)
	box.border_color = Color(0.91, 0.72, 0.30, 0.45)
	box.set_border_width_all(1)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 5)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _menu_hover() -> StyleBoxFlat:
	var box := _tinted(5)
	box.bg_color = Color(0.91, 0.72, 0.30, 0.20)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


func _menu_separator() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = Color(0.91, 0.72, 0.30, 0.28)
	line.thickness = 1
	return line


func _tinted(radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	box.anti_aliasing_size = 1.6
	return box


func _open_account_menu() -> void:
	_account_menu.add_theme_font_size_override("font_size", 17)
	_account_menu.add_theme_constant_override("v_separation", 7)
	_account_menu.add_theme_constant_override("h_separation", 10)
	_account_menu.clear()
	var names := AccountStore.account_names()
	for i in names.size():
		_account_menu.add_item(names[i], i)
	if names.is_empty():
		_account_menu.add_item("暂无已保存的账号", -1)
		_account_menu.set_item_disabled(0, true)
	else:
		_account_menu.add_separator()
		_account_menu.add_item("输入新账号…", ID_NEW)
		_account_menu.add_item("删除该账号", ID_DELETE)
	_account_menu.reset_size()
	var 锚点 := Rect2i(_account_input.get_global_rect().position, Vector2i(_account_input.size))
	_account_menu.popup(锚点)
	# popup() 只按 rect 定位、宽度仍按内容自适应，所以弹出后还要再拉一次宽度。
	_account_menu.size = Vector2i(int(_account_input.size.x), _account_menu.size.y)


func _on_account_menu_pressed(id: int) -> void:
	if id < 0 and id != ID_NEW and id != ID_DELETE:
		return
	match id:
		ID_NEW:
			_account_input.text = ""
			_password_input.text = ""
			_account_input.grab_focus()
		ID_DELETE:
			var account := _account_input.text.strip_edges()
			if AccountStore.index_of(account) < 0:
				_set_status("这个账号没有保存过", Color(1.0, 0.55, 0.45))
				return
			AccountStore.forget(account)
			_password_input.text = ""
			_set_status("已从本机删除：%s" % account, Color(0.7, 1.0, 0.75))
		_:
			if id >= 0 and id < AccountStore.accounts.size():
				_fill_account(String(AccountStore.accounts[id].get("username", "")))


func _fill_account(username: String) -> void:
	var saved := AccountStore.peek_password(username)
	_account_input.text = username
	_password_input.text = saved
	_remember.set_pressed_no_signal(not saved.is_empty())
	_account_input.release_focus()


func _on_music_pressed() -> void:
	AccountStore.bgm_muted = not AccountStore.bgm_muted
	AccountStore.save_config()
	_refresh_music_button()
	if AccountStore.bgm_muted:
		_bgm.stop()
	else:
		_bgm.play()


func _on_login_pressed() -> void:
	var username := _account_input.text.strip_edges()
	var password := _password_input.text
	if username.is_empty() or password.is_empty():
		_set_status("请输入账号和密码", Color(1.0, 0.55, 0.45))
		return
	if _remember.button_pressed:
		AccountStore.remember(username, password)
	else:
		AccountStore.forget(username)
	_set_status("正在连接服务器…", Color(0.85, 0.9, 1.0))
	login_requested.emit(username, password)


func _open_register_popup() -> void:
	_popup.visible = true
	_popup_account.text = _account_input.text
	_popup_password.text = ""
	_popup_confirm.text = ""
	_set_hint("")
	_popup_account.grab_focus()


func _close_register_popup() -> void:
	_popup.visible = false


func _on_popup_mask_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_close_register_popup()


func _submit_register() -> void:
	var username := _popup_account.text.strip_edges()
	var password := _popup_password.text
	var confirm := _popup_confirm.text
	if username.is_empty() or password.is_empty() or confirm.is_empty():
		_set_hint("账号、密码、确认密码都要填")
		return
	if username.length() < MIN_ACCOUNT:
		_set_hint("账号至少 %d 个字符" % MIN_ACCOUNT)
		return
	if password.length() < MIN_PASSWORD:
		_set_hint("密码至少 %d 个字符" % MIN_PASSWORD)
		return
	if password != confirm:
		_set_hint("两次输入的密码不一致")
		return
	if AccountStore.index_of(username) >= 0:
		_set_hint("这个账号本机已保存过，请直接登录")
		return
	register_requested.emit(username, password)
	_account_input.text = username
	_password_input.text = ""
	_set_status("注册请求已提交，等待服务器返回", Color(0.7, 1.0, 0.75))
	_close_register_popup()


func _set_hint(text: String) -> void:
	_popup_hint.text = text
	_popup_hint.visible = not text.is_empty()


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _popup.visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		_close_register_popup()
		accept_event()


# ─────────────────────────────────────────────────────────────────────────────
# 融合方补：接游戏后端。他与前几页（手里剑/结印）守的是同一条边界 ——
# **只管 UI、只发信号、不碰协议**，所以协议这一半在这里接。
# ─────────────────────────────────────────────────────────────────────────────

func _setup_backend() -> void:
	_backend = get_node_or_null("/root/BackendConnection")
	_选角窗 = get_node_or_null("选角窗")
	if _backend == null:
		_set_status("找不到 BackendConnection 单例", Color(1.0, 0.55, 0.45))
		return
	login_requested.connect(_on_login_requested)
	register_requested.connect(_on_register_requested)
	_backend.connection_status_changed.connect(_on_backend_status)
	_backend.login_status_received.connect(_on_login_status)
	_backend.character_list_received.connect(_on_character_list)
	_backend.entered_game.connect(_on_entered_game)


func _on_login_requested(username: String, password: String) -> void:
	_backend.connect_backend(username, password, false)


## 注册走**本地服务端的控制台口**（原版就是网页注册，游戏 TCP 从来没有这一号）。
## 地址从设置的 `backend_url` 里取 origin（`http://127.0.0.1:18680/ruffle.html` → `…:18680`），
## 所以改了端口/主机只要那一栏跟着改就行，不在这里另立一份配置。
func _注册地址() -> String:
	var 网址 := String(GameSession.game_settings.get("backend_url",
			"http://127.0.0.1:18680/ruffle.html"))
	var 起 := 网址.find("://")
	var 尾 := 网址.find("/", 起 + 3) if 起 >= 0 else -1
	var 根 := 网址 if (起 < 0 or 尾 < 0) else 网址.substr(0, 尾)
	return 根 + "/api/account/register"


func _on_register_requested(username: String, password: String) -> void:
	if _注册器 == null:
		_注册器 = HTTPRequest.new()
		add_child(_注册器)
		_注册器.request_completed.connect(_于注册回帧)
	_set_status("正在注册 %s …" % username, Color(0.85, 0.9, 1.0))
	# ⚠ 4.7 的 `HTTPRequest.request()`：第 3 参是 **int 方法号**（常量在 `HTTPClient` 上，
	#    `HTTPRequest.METHOD_POST` 在这个版本里查无此成员），第 4 参是 **String** 正文。
	var 错 := _注册器.request(_注册地址(), ["Content-Type: application/json"],
			HTTPClient.METHOD_POST, JSON.stringify({"username": username, "password": password}))
	if 错 != OK:
		_set_status("注册请求发不出去（错误 %d）" % 错, Color(1.0, 0.55, 0.45))


func _于注册回帧(结果: int, 状态码: int, _头: PackedStringArray, 体: PackedByteArray) -> void:
	var 绿 := Color(0.7, 1.0, 0.75)
	var 红 := Color(1.0, 0.55, 0.45)
	if 结果 != HTTPRequest.RESULT_SUCCESS:
		_set_status("注册失败：连不上本地服务端（结果 %d / HTTP %d）—— "
			% [结果, 状态码] + "先用「启动游戏.bat」把服务端和 GM 控制台一起起来", 红)
		return
	var 解 = JSON.parse_string(体.get_string_from_utf8())
	if not (解 is Dictionary):
		_set_status("注册失败：服务端回的不是 JSON（HTTP %d）" % 状态码, 红)
		return
	if not bool(解.get("ok", false)):
		# 服务端给的是**人话**（"账号已存在" / "账号需为 3-32 位…" / "密码需为 6-128 位"），
		# 直接照抄，别在这儿再编一套校验口径 —— 两边各判一次必然对不上。
		_set_status("注册失败：%s" % String(解.get("error", "服务端没给原因")), 红)
		return
	var 账: Dictionary = 解.get("account", {}) as Dictionary
	_account_input.text = String(账.get("username", _account_input.text))
	_password_input.text = ""
	# ⚠ Godot 的 JSON 把所有数字解成 **float** ⇒ 直接 str() 会给玩家看 "账号 id=4.0"。
	_set_status("注册成功（账号 id=%d）—— 输入密码后点「进入游戏」" % int(账.get("id", 0)), 绿)


func _on_backend_status(status: String, detail: String) -> void:
	if status in ["连接失败", "未连接", "离线"]:
		_set_status("%s — %s" % [status, detail], Color(1.0, 0.55, 0.45))
	else:
		_set_status("%s — %s" % [status, detail], Color(0.85, 0.9, 1.0))


func _on_login_status(login_status: int) -> void:
	# 1 = 该账号**还没有角色** ⇒ 开原版那扇「创建角色」窗（MainCreateChar.swf 那一套）。
	if login_status == 1:
		_开创角窗()
	elif login_status != 0:
		_set_status("登录失败（状态码 %d）" % login_status, Color(1.0, 0.55, 0.45))


func _on_character_list(characters: Array, max_characters: int) -> void:
	# 空号服务端回的是**只带 maxChars 的一条 jylx:10**（`{"jylx":10,"maxChars":1}`）
	# ⇒ 列表长度为 0。这一支也要开创角窗：`loginStatus` 那一条不一定先到。
	if characters.is_empty():
		_开创角窗()
		return
	if _刚建好角:
		## 建角之后服务端还会推一份角色列表（选角/进图那两步各一次）—— 这时候列表已经没玩家的事了，
		## 再弹选角窗就是"建完角还要再登录一次"那条抱怨的来源。原版此处只有 loading。
		return
	_显示选角窗()
	if _选角窗 != null:
		# 复用选角窗自己的建列表逻辑（它的脚本原来就是这个活）。
		_选角窗.call("_on_character_list_received", characters, max_characters)


var _创角窗: Control
## 刚建好角 ⇒ 这一局**不再弹选角窗**。
## 原版那条链是 `LoginServClient.onAddNewCharacterEntry:439-449`（`Config.sendPlayerCreated()`
## + `callBack.onCharCreated()`）→ `MainLoader.onCharCreated():265-282`（拆创角窗、挂"正在登录服务器"
## 的 loading）→ `oncheckLoginStatus:1190-1207` 走 `loadVersion` **直接进游戏**。
## 中间没有任何一步要玩家再点一次角色 —— 用户 2026-10-10 报的"纯多余"就是本工程多弹了一下。
var _刚建好角 := false


## 开原版那扇「创建角色」窗（`场景/界面/窗口/创建角色/创建角色窗.tscn`，249×410 居中 + 满屏渐变背景）。
##
## ⚠ 以前这一步只是把旧选角窗的占位面板切出来（一个名字输入 + 一个职业下拉），
##    原版那一整扇（四格职业/性别、随机、渐变名标签、进入游戏、转圈、弹框、悬停说明）
##    根本没做过 —— 所以注册完的新账号进不去游戏（用户 2026-10-09 报的那条）。
func _开创角窗() -> void:
	if _创角窗 != null and is_instance_valid(_创角窗):
		_创角窗.visible = true
		return
	var 包 = load("res://场景/界面/窗口/创建角色/创建角色窗.tscn")
	if 包 == null:
		_set_status("创建角色窗场景打不开", Color(1.0, 0.55, 0.45))
		return
	_创角窗 = 包.instantiate() as Control
	if _创角窗 == null:
		_set_status("创建角色窗实例化失败", Color(1.0, 0.55, 0.45))
		return
	add_child(_创角窗)
	_创角窗.move_child(_创角窗, get_child_count() - 1)
	_创角窗.建好角了.connect(func(_号: int):
		_刚建好角 = true
		if _创角窗 != null and is_instance_valid(_创角窗):
			_创角窗.visible = false
		## 选角窗一并压住：建角回帧之后 `后端连接` 会自己选人、发进图包，
		## 这里露出来就是让玩家多点一次（原版那一步是 loading 文字，不是选角窗）。
		if _选角窗 != null:
			_选角窗.visible = false
		_set_status("正在登录服务器…", Color(0.85, 0.9, 1.0)))
	_card.visible = false
	if _选角窗 != null:
		_选角窗.visible = false


func _on_entered_game(_character_id: int) -> void:
	# 与旧登录界面同一条路：进图加载**烘焙场景**（`playable_scene_path()`），不是源场景。
	get_tree().change_scene_to_file(
		MAP_RESOURCES.playable_scene_path(String(GameSession.current_map_id)))


## 显示选角/创建覆盖层。
##
## ⚠️ 选角窗（`场景/界面/选角窗.tscn`，旧登录界面改的）自带 `背景`/`遮罩`/`标题` ——
##    那是当年当**整屏登录页**用的。现在它只是盖在他的登录器上的一层，
##    他的登录器自带 1080p 视频背景，所以这三样要让路，只留中间那个窗体。
##    登录卡片同步收起（不然两层表单叠在一起）。
func _显示选角窗() -> void:
	if _选角窗 == null:
		return
	for 名 in ["背景", "遮罩", "标题"]:
		var 节点 := _选角窗.get_node_or_null(名) as CanvasItem
		if 节点 != null:
			节点.visible = false
	_选角窗.visible = true
	_card.visible = false
