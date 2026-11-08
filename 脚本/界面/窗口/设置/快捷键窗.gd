extends Control
## 快捷键设置窗控制器（原版 `KeyboardFrame` 的移植）。真值：`game-client/真值/窗口/设置.md` §8。
## 场景与期望由 `开发工具/生成快捷键窗.py` 同源生成（坐标 = 时间轴 JSON，格宽/可绑 = `键位表.json`，
## 方案文案 = `快捷键_补文案.json`）。**本文件不画任何一件的几何** —— 件的位置/尺寸/皮都在 .tscn 里。
##
## 只做 UI 与本地键位：绑完写 `session.game_settings["keybind_<语言键>"]` 并过 `快捷键.应用单个`
## （工程既有的 InputMap 出口）。原版"确定"还要发两条协议（`Client.requestKeyChange` +
## `CharacterConfig.synch`，见 §8）⇒ 这里只把 `快捷键窗|确定` 交回宿主既有动作出口，不自己发协议。
##
## 绑键方式照原版：**拖放**（`KF:708-729` 格↔列表位互绑），不是"点格后按新键"（本版本没那套监听）。

const 键表文件 := "res://数据/界面/键位表.json"
const 快捷键 := preload("res://脚本/单例/快捷键.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 皮钮底 := "res://素材/界面/原版窗口/设置/钮底.png"
const 皮钮选中 := "res://素材/界面/原版窗口/设置/钮底选中.png"

@export var 窗名 := "快捷键"

var _宿主: Node
var _会话: Node
var 槽: Array = []				# 31 条动作槽（position 0..30）
var 键反: Dictionary = {}			# keyId → 键名（恢复默认时用）
var _绑 := {}					# 语言键 → 键名（本窗工作副本，确定才落盘）
var _原绑 := {}					# 开窗时的快照，取消回滚用（KF:736-744）
var _方案 := 1					# KF:795-812 初值 selectedScheme = 1
var _改过 := false


func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	_会话 = null
	if 宿主 != null and 宿主.get("_session") != null:
		_会话 = 宿主.get("_session")
	else:
		_会话 = Engine.get_main_loop().root.get_node_or_null("GameSession")
	var 数: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(键表文件))
	槽 = 数.get("槽", [])
	for 键 in (数.get("表", {}) as Dictionary):
		键反[String((数["表"][键] as Dictionary).get("keyId", ""))] = String(键)
	_绑拖放()
	_绑钮()
	读回本地键位()


## 会话里既有的键位（`keybind_<语言键>`）→ 工作副本 + 刷新格上的牌。
func 读回本地键位() -> void:
	var 设: Dictionary = _会话.game_settings if (_会话 != null and "game_settings" in _会话) else {}
	_绑 = {}
	for 条 in 槽:
		var 键 := String(条["语言键"])
		# 会话里没存过 = 原版首次进游戏 ⇒ 用 KeyDef 的 defaultKeyId（生成器已把它烘进 .tscn）
		_绑[键] = String(设.get("keybind_" + 键, 键反.get(String(条["defaultKeyId"]), "")))
	_原绑 = _绑.duplicate(true)
	刷新()


## 每枚可绑格上的牌（`KeyboardCell.as:79-93 addIcon`）按当前绑定显隐 + 改字。
func 刷新() -> void:
	for 格 in get_children():
		if not (格 is NinePatchRect):
			continue
		var 牌 := 格.get_node_or_null("牌") as TextureRect
		if 牌 != null:
			牌.visible = false
			var 字 := 牌.get_node_or_null("牌字") as Label
			if 字 != null:
				字.text = ""
	for 条 in 槽:
		var 键名 := String(_绑.get(String(条["语言键"]), ""))
		if 键名.is_empty():
			continue
		var 格 := get_node_or_null("格" + 键名 + "Cell") as Control
		if 格 == null:
			continue
		var 牌: TextureRect = 格.get_node_or_null("牌") as TextureRect
		var 字: Label = null
		if 牌 != null:
			字 = 牌.get_node_or_null("牌字") as Label
		if 字 == null:
			continue		# canSet=false 的格原版不给绑
		牌.visible = true
		字.text = 牌文(String(条["文"]))


## `KeyboardShortcurIcon.as:31-44` 宋体分支：2 字前置一个换行、3 字前置一个全角空格。
func 牌文(名: String) -> String:
	if 名.length() == 2:
		return "\n" + 名
	if 名.length() == 3:
		return "　" + 名
	return 名


func _绑钮() -> void:
	for 名 in ["钮确定", "钮取消", "钮全部重置", "钮全部消除", "钮保存方案"]:
		var 钮 := get_node_or_null(名) as TextureButton
		if 钮 != null:
			钮.pressed.connect(_点.bind(名))
	for i in range(1, 6):
		var 钮 := get_node_or_null("钮方案%d" % i) as TextureButton
		if 钮 != null:
			钮.pressed.connect(_选方案.bind(i))


## `KF:615-645` + `:300-307`。
## ⚠️ 原版**四枚**钮都是"先弹 `MDialog.showMessageDialog` 二次确认、OK 才动手"
##    （`:275` 确定 / `:306` 全部重置 / `:761` 全部消除 / `:851` 保存方案）。
##    2026-10-11：`输入确认弹.弹消息` 就是 `showMessageDialog` 的移植（早就在工程里、
##    一直没人调）⇒ 把**两枚破坏性的**（全部重置/全部消除）接上，文案逐字取语言表白皮书：
##      `KEYBOARD_TIP_ALL_RESET` = 「要返回到基本设定吗？」
##      `KEYBOARD_TIP_CANCEL_ALL_RESET` = 「要取消所有的设定吗？」
##    **另两枚没接**，各有理由、不是漏：`钮确定` 原版要先 `isChange()` 才问；
##    `钮保存方案` 的确认之后那一步（`hasKeyScheme/saveKeyScheme` 存档语义）**本身未收口**
##    （见 `功能窗口._show_guild_action` 里 `快捷键窗:` 那段注释），接了也是弹了没下文。
func _点(名: String) -> void:
	match 名:
		"钮确定":
			_落盘()
			交回("确定")
		"钮取消":
			_绑 = _原绑.duplicate(true)		# KF:736-744 纯 UI 回滚，不发协议
			_改过 = false
			刷新()
		"钮全部重置":
			_问一下("要返回到基本设定吗？", 恢复默认)	# KF:306 → cancelEdit（回 KeyDef 基本设定）
		"钮全部消除":
			_问一下("要取消所有的设定吗？", 清全部)	# KF:761 → cancelAll（抹掉所有绑定）
		"钮保存方案":
			交回("保存方案")			# KF:786-793 走 CharacterConfig.saveKeyScheme，不越界自己存


## 二次确认（`MDialog.showMessageDialog` 口径）：`弹消息` 的回调拿到 **1=确定 / 2=取消**。
## ⚠️ 拿不到遮罩（宿主不是功能窗口那系）就按老样子直接做 —— 别为了"确认"把功能吞掉。
func _问一下(正文: String, 动作: Callable) -> void:
	var 遮罩: Control = _宿主.get("_overlay") as Control if _宿主 != null else null
	if 遮罩 == null:
		动作.call()
		return
	确认弹.弹消息(遮罩, 正文, func(码: int) -> void:
		if 码 == 1:
			动作.call())


## 默认键位 = 各槽 `defaultKeyId` 对应的键名（`KeyDef.BASE_SHORTCUT_KEYS`）。
func 恢复默认() -> void:
	for 条 in 槽:
		_绑[String(条["语言键"])] = String(键反.get(String(条["defaultKeyId"]), ""))
	_改过 = true
	刷新()


func 清全部() -> void:
	for 条 in 槽:
		_绑[String(条["语言键"])] = ""
	_改过 = true
	刷新()


## `KF:814-836`：切方案 = 换 selected 态（MButton3 的 selectedUpSkin）；没存过方案的槽只报提示。
func _选方案(i: int) -> void:
	_方案 = i
	for k in range(1, 6):
		var 钮 := get_node_or_null("钮方案%d" % k) as TextureButton
		if 钮 == null:
			continue
		钮.texture_normal = load(皮钮选中 if k == i else 皮钮底) as Texture2D
		钮.set_meta("skin", (皮钮选中 if k == i else 皮钮底).trim_suffix(".png"))
	交回("方案%d" % i)


# ── 拖放绑定（KF:708-729）：列表槽拖到键格 = 绑；键格拖到列表槽 = 换绑
func _拖(类: String, 键: String, _位: Vector2) -> Variant:
	if 键.is_empty():
		return null
	return {"类": 类, "键": 键}


func _可放(到哪: String, 数据: Variant) -> bool:
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 类 := String((数据 as Dictionary).get("类", ""))
	return (到哪 == "格" and 类 == "槽") or (到哪 == "列格" and 类 == "格")


func _放格(键名: String, _位: Vector2, 数据: Variant) -> void:
	if typeof(数据) != TYPE_DICTIONARY or String((数据 as Dictionary).get("类", "")) != "槽":
		return
	绑(String((数据 as Dictionary)["键"]), 键名)


func _放列(槽键: String, _位: Vector2, 数据: Variant) -> void:
	if typeof(数据) != TYPE_DICTIONARY or String((数据 as Dictionary).get("类", "")) != "格":
		return
	绑(槽键, String((数据 as Dictionary)["键"]))


## 一键一动作、一动作一键：`KF:415-438` 落点前先 `setSingleBaseKeyData(旧动作位)` 把
## 该格上原动作摘掉、再 `removeSingleBaseKeyData(拖来的槽位)` 把该动作从原格摘掉。
## 两条合起来 = 任何时刻一个键最多一个动作、一个动作最多一个键 ⇒ 在唯一的入口 `绑()` 里做。
func 绑(槽键: String, 键名: String) -> void:
	if 槽键.is_empty() or 键名.is_empty():
		return
	for 条 in 槽:
		if String(条["语言键"]) != 槽键 and String(_绑.get(String(条["语言键"]), "")) == 键名:
			_绑[String(条["语言键"])] = ""
	_绑[槽键] = 键名
	_改过 = true
	刷新()


func 解绑(槽键: String) -> void:
	if 槽键.is_empty():
		return
	_绑[槽键] = ""
	_改过 = true
	刷新()


func 取绑(槽键: String) -> String:
	return String(_绑.get(槽键, ""))


func _落盘() -> void:
	if _会话 == null or not ("game_settings" in _会话):
		return
	var 设: Dictionary = _会话.game_settings
	for 条 in 槽:
		var 键 := String(条["语言键"])
		var 键名 := String(_绑.get(键, ""))
		设["keybind_" + 键] = 键名
		var 码 := _键码(键名)
		if 码 != -1:
			快捷键.应用单个(键, 码)
	_原绑 = _绑.duplicate(true)
	_改过 = false


func _键码(键名: String) -> int:
	match 键名:
		"":
			return -1
		"Space":
			return KEY_SPACE
		"Enter":
			return KEY_ENTER
		"Tab":
			return KEY_TAB
		"ESC":
			return KEY_ESCAPE
		"Shift":
			return KEY_SHIFT
		"Ctrl":
			return KEY_CTRL
		"Alt":
			return KEY_ALT
		_:
			if 键名.length() == 1:
				return int(键名.to_upper()[0])
			if 键名.begins_with("F") and 键名.length() <= 3:
				return KEY_F1 + 键名.substr(1).to_int() - 1
			return -1


func 交回(动作: String) -> void:
	if _宿主 != null and _宿主.has_method("_show_guild_action"):
		_宿主.call("_show_guild_action", "快捷键窗|" + 动作)


func 有改动() -> bool:
	return _改过


## 把 .tscn 里烘好的件接上拖放钩子（生成器只落几何与皮，钩子在装配时接）。
func _绑拖放() -> void:
	for 列 in get_children():
		if not 列.has_meta("slot"):
			continue
		var 号 := int(列.get_meta("slot"))
		if 号 < 0 or 号 >= 槽.size():
			continue
		var 槽键 := String(槽[号]["语言键"])
		列.set_meta("slotkey", 槽键)		# 中文 meta 键 Godot 会丢 ⇒ 用 ASCII
		# 三钩子按**每个节点**转发（原版 MSPRITE_DOWN/UP 走 DragManager，KF:136-142）
		列.set_drag_forwarding(_拖.bind("槽", 槽键), _可放.bind("列格"), _放列.bind(槽键))
	for 格 in get_children():
		if not 格.has_meta("canset") or not bool(格.get_meta("canset")):
			continue		# KF:100-105 只有 canSet 的格才挂监听
		var 键 := String(格.get_meta("key", ""))
		if 键.is_empty():
			continue
		格.set_drag_forwarding(_拖.bind("格", 键), _可放.bind("格"), _放格.bind(键))
