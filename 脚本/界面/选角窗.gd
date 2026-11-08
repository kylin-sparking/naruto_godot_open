extends Control


@onready var login_panel: Control = %登录面板
@onready var character_panel: Control = %选角面板
@onready var account_input: LineEdit = %账号输入
@onready var password_input: LineEdit = %密码输入
@onready var login_button: Button = %登录按钮
@onready var status_label: Label = %状态文字
@onready var character_list: VBoxContainer = %角色列表

var backend: Node

func _ready() -> void:
	backend = get_node("/root/BackendConnection")
	_load_login_defaults()
	backend.connection_status_changed.connect(_on_connection_status_changed)
	backend.login_status_received.connect(_on_login_status_received)
	backend.character_list_received.connect(_on_character_list_received)
	login_button.pressed.connect(_submit_login)
	account_input.text_submitted.connect(func(_value): password_input.grab_focus())
	password_input.text_submitted.connect(func(_value): _submit_login())
	_show_login()

func _load_login_defaults() -> void:
	var settings: Dictionary = GameSession.game_settings
	account_input.text = String(settings.get("backend_account", "a33047518511@gmail.com"))
	password_input.text = String(settings.get("backend_password", "123456"))

func _submit_login() -> void:
	var account := account_input.text.strip_edges()
	if account.is_empty() or password_input.text.is_empty():
		status_label.text = "请输入账号和密码"
		return
	login_button.disabled = true
	backend.connect_backend(account, password_input.text, false)

func _on_connection_status_changed(status: String, detail: String) -> void:
	status_label.text = "%s  %s" % [status, detail]
	if status in ["连接失败", "未连接"]:
		login_button.disabled = false

func _on_login_status_received(login_status: int) -> void:
	if login_status == 1:
		_叫登录层开创角窗()
	elif login_status != 0:
		login_button.disabled = false

func _on_character_list_received(characters: Array, max_characters: int) -> void:
	for child in character_list.get_children():
		child.queue_free()
	if characters.is_empty():
		_叫登录层开创角窗()
		return
	for character in characters:
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 54)
		button.text = "%s    %d级" % [character.get("name", ""), int(character.get("level", 1))]
		button.pressed.connect(_select_character.bind(int(character.get("id", 0))))
		character_list.add_child(button)
	%创建角色按钮.disabled = characters.size() >= max_characters
	_show_characters()

func _select_character(character_id: int) -> void:
	status_label.text = "正在进入游戏..."
	backend.select_character(character_id)

## ⚠ 「创建角色」不再在这里开 —— 原版那一扇在 `场景/界面/窗口/创建角色/创建角色窗.tscn`，
##    由 `登录界面.gd:_开创角窗()` 在 loginStatus==1 或角色列表为空时开。
## 「创建角色」这一步**不在本窗里做**。原版那一扇是独立素材包 MainCreateChar.swf
## 里的 249×410 整窗（四格职业/性别 + 随机 + 渐变名标签 + 进入游戏 + 转圈 + 弹框 + 悬停说明），
## 场景在 `场景/界面/窗口/创建角色/创建角色窗.tscn`，由父层 `登录界面.gd:_开创角窗()` 开。
## 本窗只负责选角，遇到"这号没角色"就往上叫一声。
func _叫登录层开创角窗() -> void:
	var 父 := get_parent()
	if 父 != null and 父.has_method("_开创角窗"):
		父.call("_开创角窗")
		visible = false

func _show_login() -> void:
	login_panel.visible = true
	character_panel.visible = false
	account_input.grab_focus()

func _show_characters() -> void:
	login_panel.visible = false
	character_panel.visible = true

