extends "res://脚本/界面/窗口/家族/家族子窗.gd"

const 文案 := preload("res://脚本/界面/窗口/好友/好友文案.gd")
const 子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 职业 := preload("res://脚本/单例/职业.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

## 好友页「添加好友」的选人窗（原版 `SelectPlayerWindow` 292×279，自成一窗 ⇒ 有壳=false）。
## 真值：`SelectPlayerWindow.as` + `SelectPlayerWindowCell.as` + `FriendTabLink.onAddHand:69-76`
## + `Client.onCharSearchResult` 的 type 1 分支。几何由 `开发工具/生成好友场景.py` 按 SPEC 出，
## 这里只补**运行期才有的**东西：结果行、分页、选中条、按钮启停、搜索/加好友两条出口。
##
## 口径摘要（都是原版字面量）：
##   * 每页 5 行（`SPW:47 pageSize`），行 y = `21*i + 2*i`（`SPW:255-257`）；
##   * 行内三列：名 137 宽 `#1e90ff` 粗体居中（`SPWC:104-106`）、等级 44 宽 `#0fffff` + 发光
##     （`SPWC:109-116`）、职业 58 宽 `#0fffff` 粗体居中（`SPWC:107-108`）；
##   * 行悬停条 265×19 @(0,1)、外层选中条 265×19 @(0, 23*i)（`SPWC:97-101` / `SPW:418-423`），
##     选中条在 AS3 里是**最后 addChild** 的（画在行上），这里靠 `move_child` 到末位还原；
##   * 搜索 → `Client.requestCharSearch(searchType, name)` = `1282:<searchType>:1:<名字>`，
##     发完 `destroy()`（清行/清页码/藏选中条），**窗不关**（`SPW:288-296`）；
##   * 回包 type 1 才归这扇窗（`Client.onCharSearchResult`），空结果只禁用两钮（`SPW:353-368`）；
##   * 多功能钮在加好友档 = `FRIEND_ADD`，空名字只提示 `FRIEND_TIP_INPUT_CHAR_NAME`（`FTL:74-90`）；
##   * 查看资料 → `API.ui.clickCharacter`（`SPW:314-317`）⇒ 宿主 `_查看角色资料`。

const 窗名值 := "好友选人窗"
const 每页行数 := 5
const 行座差 := 23.0			# `SPW:255` y = height(21)*i + i*2
const 行宽 := 265.0
const 行高 := 21.0
const 选中皮 := "res://素材/界面/原版窗口/通用控件/选中条1.png"
const 行底皮 := "res://素材/界面/原版窗口/通用控件/输入框.png"
## `SPWC:104` 2003199 / `SPWC:111,108` 1048575
const 名色 := Color(0.11764705882352941, 0.56470588235294118, 1.0)
const 值色 := Color(0.0, 1.0, 1.0)
const 字体路径 := "res://素材/界面/simsun_原版.ttf"
const 粗体量 := 0.8
const 搜索类型 := 1			# `FTL:73` searchType = 1（好友搜索）
## 九宫边距：选中条 = 好友行同源（`好友行.gd`）；行底 = 场景「输入框底」同源
const 选中边 := [7.0, 5.35, 7.9, 5.75]
const 行底边 := [6.0, 5.0, 7.0, 6.0]

static var _粗体: FontVariation = null

var _会话: Node
var _后端: Node
var _数据: Array[Dictionary] = []
var _页 := 1
var _总页 := 0
var _选中项: Dictionary = {}
var _加好友 := true


func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	_会话 = _取单例("GameSession", 宿主, "_session")
	_后端 = _取单例("BackendConnection", 宿主, "_backend")
	super.装配(宿主)
	var 输入 := get_node_or_null("名输入") as LineEdit
	if 输入 != null:
		输入.text_submitted.connect(_按回车)
	var 条 := get_node_or_null("选中条") as Control
	if 条 != null:
		条.visible = false
		# AS3 `SPW:245` 是 `cellContainer.addChild(curSelectCell)` —— 选中条排在行之后（画在上面）。
		# 场景里它排在行容器之前，不挪就会被行底整个盖掉。
		move_child(条, get_child_count() - 1)
	_铺文案()
	_接搜索()


func 设添加好友() -> void:
	_加好友 = true
	_设按钮字("多功能钮", 文案.取("FRIEND_ADD"))


func _铺文案() -> void:
	_设字("标题", 文案.取("SELCET_PLAYER_WINDOW_TITLE"))
	_设字("名标签", 文案.取("PLAYER_NAME"))
	_设字("结果标签", 文案.取("SEARCH_RESULTS"))
	_设字("表头一", 文案.取("GAME_PLAYER_NAME"))
	_设字("表头二", 文案.取("CHARACTOR_LEVEL"))
	_设字("表头三", 文案.取("CHARACTOR_JOB"))
	_设字("模糊提示", 文案.取("SEARCH_MOHU"))
	_设按钮字("搜索钮", 文案.取("TROOP_SEARCH_BTN"))
	_设按钮字("查看资料钮", 文案.取("TROOP_SHOW_CHAR_INFO_BTN"))
	_设按钮字("取消钮", 文案.取("COMMON_CANCEL"))
	_设按钮字("多功能钮", 文案.取("FRIEND_ADD") if _加好友 else 文案.取("MULTIFUNCTIONAL"))


func _设字(节名: String, 文: String) -> void:
	var 节 := get_node_or_null(节名) as Label
	if 节 != null and not 文.is_empty():
		节.text = 文


func _设按钮字(节名: String, 文: String) -> void:
	var 节 := get_node_or_null(节名 + "/Label") as Label
	if 节 != null and not 文.is_empty():
		节.text = 文


func _发动作(名: String) -> void:
	match 名:
		"关闭", "取消钮":
			_关闭()
		"搜索钮":
			_搜索()
		"上一页钮":
			_翻页(-1)
		"下一页钮":
			_翻页(1)
		"查看资料钮":
			_查看资料()
		"多功能钮":
			_多功能()
		_:
			super._发动作(名)


func _按回车(_文: String) -> void:
	_搜索()


## `SPW:288-296`：发 SELECT_PLAYER → destroy()。destroy 只清数据，**窗还在**（关窗是取消/右上角）。
func _搜索() -> void:
	_清空()
	_启用(false)
	var 名 := ""
	var 输入 := get_node_or_null("名输入") as LineEdit
	if 输入 != null:
		名 = 输入.text
	if _后端 == null or not _后端.has_method("request_char_search"):
		_通知("搜索请求未发送（未连接服务端）")
		return
	_后端.call("request_char_search", 名, 1, 搜索类型)


func _接搜索() -> void:
	if _后端 == null or not _后端.has_signal("char_search_received"):
		return
	var 回 := Callable(self, "_收到搜索")
	if not _后端.is_connected("char_search_received", 回):
		_后端.connect("char_search_received", 回)


## `Client.onCharSearchResult`：只有 type == 本窗的 searchType 才归这里。
func _收到搜索(结果: Array) -> void:
	var 类: Variant = _后端.get("authoritative_char_search_类型")
	if int(类) != 搜索类型:
		return
	_数据.clear()
	for 条 in 结果:
		if 条 is Dictionary:
			_数据.append((条 as Dictionary).duplicate(true))
	if _数据.is_empty():
		_清空()
		_启用(false)
		return
	_页 = 1
	_总页 = maxi(1, ceili(float(_数据.size()) / float(每页行数)))
	_更新页码()
	_铺页()


func _清空() -> void:
	var 列 := get_node_or_null("行容器") as Control
	if 列 != null:
		for 子 in 列.get_children():
			列.remove_child(子)
			子.queue_free()
	var 条 := get_node_or_null("选中条") as Control
	if 条 != null:
		条.visible = false
	var 页 := get_node_or_null("页码") as Label
	if 页 != null:
		页.text = ""
	_数据.clear()
	_选中项 = {}
	_页 = 1
	_总页 = 0


func _更新页码() -> void:
	var 页 := get_node_or_null("页码") as Label
	if 页 != null:
		页.text = "%d/%d" % [_页, _总页]


func _翻页(步: int) -> void:
	var 新 := _页 + 步
	if 新 < 1 or 新 > _总页 or _总页 == 0:
		return
	_页 = 新
	_更新页码()
	_铺页()


## SPW:initCellCount：本页最多 5 行，重建后**默认选中第一行**。
func _铺页() -> void:
	var 列 := get_node_or_null("行容器") as Control
	if 列 == null or _数据.is_empty():
		return
	for 子 in 列.get_children():
		列.remove_child(子)
		子.queue_free()
	var 起 := (_页 - 1) * 每页行数
	var 数 := mini(每页行数, _数据.size() - 起)
	for i in 数:
		var 行 := _建行(_数据[起 + i], i)
		列.add_child(行)
	_选(_数据[起], 0)


func _建行(项: Dictionary, 局序: int) -> Control:
	var 行 := Control.new()
	行.name = "行%d" % 局序
	行.position = Vector2(0.0, 行座差 * 局序)
	行.size = Vector2(行宽, 行高)
	行.mouse_filter = Control.MOUSE_FILTER_STOP
	行.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var 底 := NinePatchRect.new()
	底.name = "行底"
	底.position = Vector2.ZERO
	底.size = Vector2(行宽, 行高)			# `SPWC:89-92` 265×21
	底.texture = load(行底皮) as Texture2D
	for i in 4:
		底.set("patch_margin_%s" % ["left", "top", "right", "bottom"][i], 行底边[i])
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.add_child(底)
	var 悬 := NinePatchRect.new()
	悬.name = "悬停条"
	悬.position = Vector2(0.0, 1.0)			# `SPWC:96-101`
	悬.size = Vector2(行宽, 19.0)
	悬.texture = load(选中皮) as Texture2D
	for i in 4:
		悬.set("patch_margin_%s" % ["left", "top", "right", "bottom"][i], 选中边[i])
	悬.mouse_filter = Control.MOUSE_FILTER_IGNORE
	悬.visible = false
	行.add_child(悬)
	行.add_child(_建名(项))
	行.add_child(_建列("等级", Vector2(144.0, 2.0), Vector2(44.0, 18.0),
			str(int(项.get("level", 1))), 值色, true))
	行.add_child(_建列("职业", Vector2(188.0, 2.0), Vector2(58.0, 18.0),
			职业.取(int(项.get("job", 0))), 值色, true))
	行.mouse_entered.connect(func() -> void: 悬.visible = true)		# `SPWC:148-150`
	行.mouse_exited.connect(func() -> void: 悬.visible = false)		# `SPWC:143-146`
	行.gui_input.connect(_行输入.bind(项, 局序))
	return 行


func _建名(项: Dictionary) -> Label:
	return _建列("名", Vector2(2.0, 2.0), Vector2(137.0, 18.0),
			String(项.get("name", "")), 名色, true)

func _建列(节名: String, 位: Vector2, 尺: Vector2, 文: String, 色: Color, 粗: bool) -> Label:
	var 列 := Label.new()
	列.name = 节名
	列.position = 位
	列.size = 尺
	列.text = 文
	列.add_theme_font_size_override("font_size", 12)
	列.add_theme_color_override("font_color", 色)
	列.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	列.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	列.clip_text = true
	列.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if 粗:
		var 字 := 取粗体()
		if 字 != null:
			列.add_theme_font_override("font", 字)
	if 节名 == "等级":
		# `SPWC:116` `filters = BaseUtil.getGlowFilter()` ⇒ 规则那档 2px 黑描边
		列.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
		列.add_theme_color_override("font_outline_color", 皮肤表.文字规则_描边色)
	return 列


static func 取粗体() -> FontVariation:
	if _粗体 != null:
		return _粗体
	var 底 := load(字体路径) as FontFile
	if 底 == null:
		push_error("好友选人窗字体查无：%s" % 字体路径)
		return null
	var 粗 := FontVariation.new()
	粗.base_font = 底
	粗.variation_embolden = 粗体量
	_粗体 = 粗
	return 粗


func _行输入(事件: InputEvent, 项: Dictionary, 局序: int) -> void:
	if not (事件 is InputEventMouseButton):
		return
	var 按 := 事件 as InputEventMouseButton
	if not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	_选(项, 局序)
	get_viewport().set_input_as_handled()


func _选(项: Dictionary, 局序: int) -> void:
	_选中项 = 项
	var 条 := get_node_or_null("选中条") as Control
	var 列 := get_node_or_null("行容器") as Control
	if 条 != null and 列 != null:
		条.position = 列.position + Vector2(0.0, 行座差 * 局序)
		条.visible = true
	_启用(true)


func _启用(开: bool) -> void:
	for 节名 in ["查看资料钮", "多功能钮"]:
		var 钮 := get_node_or_null(节名) as TextureButton
		if 钮 != null:
			钮.disabled = not 开
	重画钮态()


## `SPW:314-317` → `API.ui.clickCharacter(playerId)`；宿主已有这条出口就走宿主的。
func _查看资料() -> void:
	var 号 := int(_选中项.get("character_id", 0))
	if 号 <= 0:
		return
	if _宿主 != null and _宿主.has_method("_查看角色资料"):
		_宿主.call("_查看角色资料", 号)
	elif _后端 != null and _后端.has_method("request_char_full_info"):
		_后端.call("request_char_full_info", 号)


## `FTL:74-90` `__confirmAddFriend`：空名字只提示；否则把**这一行的数据**交回宿主，
## 宿主走 `127:1:<编号>`（`A1` 已经把"已是好友只提示"那道闸放在那里）。
func _多功能() -> void:
	if _选中项.is_empty():
		return
	var 名 := String(_选中项.get("name", ""))
	if 名.is_empty():
		_通知(文案.取("FRIEND_TIP_INPUT_CHAR_NAME"))
		return
	if _加好友:
		if _宿主 != null and _宿主.has_method("_好友菜单动作"):
			_宿主.call("_好友菜单动作", "好友:交友", _选中项)
			return
		var 号 := int(_选中项.get("character_id", 0))
		if _后端 != null and _后端.has_method("request_friend_add"):
			_后端.call("request_friend_add", 号)


func _关闭() -> void:
	子窗壳.关掉(_宿主, 窗名值)


func _通知(文: String) -> void:
	if _宿主 != null and _宿主.has_method("_通知"):
		_宿主.call("_通知", 文)
		return
	if _会话 != null and _会话.has_signal("notification_requested"):
		_会话.emit_signal("notification_requested", 文)


func _取单例(名: String, 宿主: Node, 字段: String) -> Node:
	var 值: Variant = 宿主.get(字段) if 宿主 != null else null
	if 值 is Node:
		return 值 as Node
	return get_node_or_null("/root/" + 名)
