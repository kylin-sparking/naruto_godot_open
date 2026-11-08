extends Control
## 设置页控制器（原版 `SystemConfigWindow` 423×424 的整框 1:1 移植）。
## 真值：`game-client/真值/窗口/设置.md` §1–§6；场景与期望由 `开发工具/生成设置场景.py` 同源生成。
##
## 只做美术与交互：勾选值全部写进工程既有的 `session.game_settings`（`_set_check`/`_set_slider` 出口），
## 一条协议都不新增。原版三枚页签里「快速键」**不是切页**，而是开关式弹独立窗
## （`SCW:264` → `UM2:3133-3146 setKeyboardWindowvisible`）⇒ 这里把动作交回宿主，由宿主开窗。

const 期望文件 := "res://数据/界面/设置页期望.json"

@export var 窗名 := "设置"

var _宿主: Node
var _会话: Node
var _页 := 0		# 0 = 系统设置、2 = 特殊设置（1 是「快速键」，走弹窗不占页）
var _音量 := {}


func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	_会话 = null
	if 宿主 != null and 宿主.get("_session") != null:
		_会话 = 宿主.get("_session")
	else:
		_会话 = Engine.get_main_loop().root.get_node_or_null("GameSession")
	_绑页签()
	_绑复选(层("层主页"), 表("复选"))
	_绑复选(层("层特页"), 表("特页复选"))
	_绑音量()
	_切页(_页)
	刷新()


func 层(名: String) -> Control:
	return get_node(名) as Control


var _期 := {}


func 表(键: String) -> Array:
	if _期.is_empty():
		var 取: Variant = JSON.parse_string(FileAccess.get_file_as_string(期望文件))
		_期 = 取 if typeof(取) == TYPE_DICTIONARY else {}
	var 值: Variant = _期.get(键, [])
	return (值 as Array) if typeof(值) == TYPE_ARRAY else []


func 设置() -> Dictionary:
	return _会话.game_settings if _会话 != null and "game_settings" in _会话 else {}


# ── 页签：选中那枚 `disabled = true` ⇒ 显示 selectedUpSkin 真皮（`MTabButton.as:35-39`，
#    本页 selectedUpSkin = tag 538，见 §2；不推灰度）。
func _绑页签() -> void:
	for i in 4:		# 4 = 3 枚原版页签 + 1 枚工程自加的「客户端」（期望表 页签 里就是 4 条）
		var 钮 := get_node(期望_页签(i)) as TextureButton
		if 钮 == null:
			continue
		钮.pressed.connect(_点页签.bind(i))
		钮.mouse_entered.connect(_设态.bind(钮, 1))
		钮.mouse_exited.connect(_设态.bind(钮, 0))
		钮.button_down.connect(_设态.bind(钮, 2))
		钮.button_up.connect(_设态.bind(钮, 0))		# MButton3.as:103-108 松手回 STATE_UP


func 期望_页签(i: int) -> String:
	var 列: Array = 表("页签")
	return String(列[i][0]) if i < 列.size() else ""


func _点页签(i: int) -> void:
	if i == 3:		# 第 4 枚**非原版**：本工程自加的「客户端」层（全屏/自动拾取/后端）
		_切页(3)
		return
	if i == 1:
		# 原版「快速键」= 开关式弹独立窗（`SCW:264` → `UM2:3133-3146 setKeyboardWindowvisible`），不切页
		# ⇒ 走工程既有的开窗信号（`窗口管理.打开或收起`，再点一次收起），不新发协议；
		#   会话不在时退化成把动作交回宿主，不静默吞点击。
		if _会话 != null and _会话.has_method("request_feature"):
			_会话.call("request_feature", "快捷键")
		elif _宿主 != null and _宿主.has_method("_show_guild_action"):
			_宿主.call("_show_guild_action", "设置页|页签:快速键")
		return
	_切页(0 if i == 0 else 2)


func _切页(页: int) -> void:
	_页 = 页
	_摆层()


## 三层的可见性**只有本页说了算**：`功能窗口._render_more_settings`（公共函数，老的单窗口换页用法
## 也在调）自己写了 `more.visible = true` ⇒ 宿主填完值后「客户端」层会直接压在系统设置页上
## （实机截图：音乐/音效面板标题、"100"、主机框、"立即同步"全浮在复选列表上）。
## ⇒ 宿主调完之后必须再调一次本方法把层收回来。
func _摆层() -> void:
	层("层主页").visible = _页 == 0
	层("层特页").visible = _页 == 2
	层("更多设置").visible = _页 == 3		# 非原版层，由 功能窗口._render_more_settings 填值
	for i in 4:
		var 名 := 期望_页签(i)
		if 名.is_empty():
			continue
		var 钮 := get_node(名) as TextureButton
		if 钮 != null:
			钮.disabled = (i == _页)
			_页签基线(钮)		# 上一枚可能停在悬停/按下档 ⇒ 换选中时把皮肤基线复位


func 重摆层() -> void:
	_摆层()


func _绑复选(父: Control, 列: Array) -> void:
	for 条 in 列:
		var 名 := String(条[0])
		var 项 := 父.get_node_or_null(名) as Control
		if 项 == null:
			push_error("设置页缺件：%s（重跑 开发工具/生成设置场景.py）" % 名)
			continue
		var 键 := String(条[5]) if 条.size() > 5 else ""
		var 写 := bool(条[6]) if 条.size() > 6 else true
		项.set_meta("key", 键)
		项.set_meta("on", 写)
		(项.get_node("点击区域") as Button).pressed.connect(_点复选.bind(项))


func _点复选(项: Control) -> void:
	var 键 := String(项.get_meta("key"))
	var 新 := not (项.get_node("标记") as CanvasItem).visible
	if 键.is_empty():
		return
	_写(键, 新 if bool(项.get_meta("on")) else not 新)
	_刷复选()


func _写(键: String, 值: Variant) -> void:
	if 值 is float and _宿主 != null and _宿主.has_method("_set_slider"):
		_宿主.call("_set_slider", 值, 键)		# 功能窗口.gd:3453 既有出口
		return
	if _宿主 != null and _宿主.has_method("_set_check"):
		_宿主.call("_set_check", 值, 键)		# 功能窗口.gd 既有出口（写 session.game_settings）
	# ⚠️ 这里原来是 `has_method("set_game_setting")` —— **游戏会话里没有这个方法**
	#   （真名 `update_setting`，`游戏会话.gd:1721`）⇒ 这一支恒 false，永远落到最后那句
	#   "只写本地字典、不落盘也不广播"。当前够不着（宿主 `功能窗口` 有 `_set_check`/`_set_slider`），
	#   但那就是一颗"以后换了宿主、设置看着写了其实没落"的雷（2026-10-13 改名对齐）。
	elif _会话 != null and _会话.has_method("update_setting"):
		_会话.call("update_setting", 键, 值)
	else:
		设置()[键] = 值


# ── 音量条（SCW:286-325）：轨道 170×6、滑块 x = v·170、文字「<名> <round(v·100)>%」
func _绑音量() -> void:
	for 条 in 表("音量"):
		var 名 := String(条[0])
		var 行 := 层("层特页").get_node_or_null(名) as Control
		if 行 == null:
			continue
		var 键 := "music_volume" if 名.contains("音乐") else "sound_volume"
		行.set_meta("key", 键)
		行.gui_input.connect(_拖音量.bind(行))


func _拖音量(事: InputEvent, 行: Control) -> void:
	if not (事 is InputEventMouseButton) and not (事 is InputEventMouseMotion):
		return
	var 键 := String(行.get_meta("key"))
	var 值 := clampf(事.position.x / 170.0, 0.0, 1.0)
	if (事 is InputEventMouseButton) and not (事 as InputEventMouseButton).pressed:
		return
	_音量[键] = 值
	_写(键, 值)
	_刷音量()


func 刷新() -> void:
	_刷复选()
	_刷音量()


func _刷复选() -> void:
	var 设 := 设置()
	for 父名 in ["层主页", "层特页"]:
		var 父 := 层(父名)
		for 子 in 父.get_children():
			if not (子 is Control) or not String(子.name).begins_with("复选"):
				continue
			var 键 := String(子.get_meta("key")) if 子.has_meta("key") else ""
			if 键.is_empty():
				continue
			var 值 := bool(设.get(键, not bool(子.get_meta("on"))))
			(子.get_node("标记") as CanvasItem).visible = 值 if bool(子.get_meta("on")) else not 值


func _刷音量() -> void:
	var 设 := 设置()
	for 条 in 表("音量"):
		var 行 := 层("层特页").get_node_or_null(String(条[0])) as Control
		if 行 == null:
			continue
		var 键 := String(行.get_meta("key"))
		var 值 := float(_音量.get(键, 设.get(键, 1.0)))
		(行.get_node("钮滑块") as Control).position = Vector2(值 * 170.0 - 7.0, 18.0)
		(行.get_node("文标签") as Label).text = "%s %d%%" % [String(条[1]), int(round(值 * 100.0))]


## MButton3 / MTabButton 一族的三态：`MTabButton.as:16-32` 不换图、只把
## `StyleUtil.skinFilters`（`StyleUtil.as:7-12` up 0 / over +30 / down −40）加在**同一张皮**上，
## 而 Godot 的 TextureButton 没有"给贴图加色矩阵"这条挂法 ⇒ 按工程既有口径（底栏十钮 =
## `技能面板.gd:_设三态`）**换 `texture_normal` 本身**，派生皮由 `开发工具/生成页签态图.py` 预烘。
##
## ⚠ 别改用 `texture_hover/texture_pressed`：`MButton3.as:103-108 mouseUpHandler` 松手回的是
##   **STATE_UP 而不是 OVER**（鼠标停在上面也不再亮，要移出去再进来）。texture_hover 做不到这个形状。
## ⚠ 选中那一枚不吃鼠标也不加亮：原版 `MTabButton.as:34-38` `set enabled(v){ selected = !v }`
##   ⇒ 选中枚 `enabled=false`，`updateState()` 走 DISABLED 分支、滤镜取 `skinFilters[STATE_UP]` = 0。
const 态后缀 := ["", "_悬停", "_按下", "_灰"]


func _设态(钮: TextureButton, 态: int) -> void:
	if 钮 == null or 钮.disabled:
		return
	var 主干 := String(钮.get_meta("skin"))
	if 主干.is_empty():
		return
	var 路 := 主干 + String(态后缀[态]) + ".png"
	if not ResourceLoader.exists(路):
		return		# 没烘过这一档就停在当前皮，别把钮画成空贴图
	钮.texture_normal = load(路) as Texture2D


## 换选中枚时把皮肤基线复位：上一枚可能停在悬停/按下档，`disabled` 只改显示不改 `texture_normal`。
func _页签基线(钮: TextureButton) -> void:
	var 主干 := String(钮.get_meta("skin"))
	if 主干.is_empty() or not ResourceLoader.exists(主干 + ".png"):
		return
	钮.texture_normal = load(主干 + ".png") as Texture2D
