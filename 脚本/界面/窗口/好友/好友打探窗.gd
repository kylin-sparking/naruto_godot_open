extends "res://脚本/界面/窗口/家族/家族子窗.gd"

const 文案 := preload("res://脚本/界面/窗口/好友/好友文案.gd")
const 子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 三态钮 := preload("res://脚本/界面/组件/原版三态钮.gd")
const 灰度 := preload("res://脚本/界面/组件/禁用灰度.gdshader")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

## 好友页「打探」窗（原版 `MPromptWindow.popupDaTanPlayerWindow` 294×215，自成一窗 ⇒ 有壳=false）。
## 真值：`MPromptWindow.as:91-101,327-347,411-465`、`ItemCaiLiaoBox.as`、`SimpleItemCell.as`。
##
## 口径摘要：
##   * 橙色说明 `DATAN_PROMPT_3`（带乾坤密卷名），`MPW:95`；
##   * 材料盒 = `ItemCaiLiaoBox(60,64)`：40×40 格居中 (10,20)、数量角标 40×20 @(0,20) 右下白字、
##     购买钮 `btn_width_two`=37 宽 @(11.5, 63)；数量为 0 时**整格套灰度**（`ICLB:hasItem`）；
##   * 信息串三档（`MPW:327-347`）：code 0 = 线/名/图/座标（`floor(x/100)`）、
##     code 2 = 该玩家不在线、code 1 = 背包没有密卷；null / 其它 = 只报名字；
##   * **打探钮（OK）不关窗**（`MPW:155-162` `_viewType == 1` 时 return）；取消/右上角才关。
##   * 打探上行 = `127:10:<角色号>`（`FriendProcessor.requestFindEnemy:26-32`），回包走
##     `后端连接.find_enemy_result_received`。

const 窗名值 := "好友打探窗"
const 物品号 := 16000005			# `ImgUtil.getImg(Etc,"FindEnemy").itemid` = 乾坤密卷
const 盒宽 := 60.0
const 盒高 := 64.0
const 格宽 := 40.0
const 格高 := 40.0
const 买宽 := 37.0
const 买高 := 22.0
const 买皮 := "res://素材/界面/原版窗口/好友/钮底37.png"

var _会话: Node
var _后端: Node
var _对象: Dictionary = {}
var _名 := ""
var _号 := 0
var _图标: TextureRect
var _数量: Label
var _格子: Control


func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	_会话 = _取单例("GameSession", 宿主, "_session")
	_后端 = _取单例("BackendConnection", 宿主, "_backend")
	super.装配(宿主)
	_设字("标题", 文案.取("DATAN_WINDOW_TITLE"))
	_设字("打探钮/Label", 文案.取("DATAN_BUTTON_NAME"))
	_设字("取消钮/Label", 文案.取("COMMON_CANCEL"))
	var 说明 := get_node_or_null("橙说明") as RichTextLabel
	if 说明 != null:
		说明.text = 富文本.译文为BBCode(文案.取("DATAN_PROMPT_3").replace("%1", GAME_DATA.item_name(物品号)))
	_建材料盒()
	_接打探()
	_接背包()
	_刷材料格()
	_信息串(文案.取("DATA_INFOSTR_3").replace("%1", ""))


## 打开那一刻由宿主把**这一行的数据**交进来（`FW2:420-428` 的 `_loc6_` 五项）。
func 设对象(项: Dictionary) -> void:
	_对象 = 项.duplicate(true)
	_名 = String(项.get("name", ""))
	_号 = int(项.get("character_id", 0))
	_贴头像(int(项.get("face", 0)), int(项.get("gender", 0)))
	_信息串(文案.取("DATA_INFOSTR_3").replace("%1", _名))
	_红字("  ")


func _发动作(名: String) -> void:
	match 名:
		"关闭", "取消钮":
			子窗壳.关掉(_宿主, 窗名值)
		"打探钮":
			_打探()
		_:
			super._发动作(名)


func _打探() -> void:
	if _号 <= 0:
		_通知("打探：找不到这名玩家的数据")
		return
	if _后端 == null or not _后端.has_method("request_friend_find_enemy"):
		_通知("打探请求未发送（未连接服务端）")
		return
	if not bool(_后端.call("request_friend_find_enemy", _号)):
		_通知("打探请求未发送")


func _接打探() -> void:
	if _后端 == null or not _后端.has_signal("find_enemy_result_received"):
		return
	var 回 := Callable(self, "_收到打探")
	if not _后端.is_connected("find_enemy_result_received", 回):
		_后端.connect("find_enemy_result_received", 回)


## `MPW:327-347 updateDaTanView`：只有 0/1/2 三档有字；`param1 == null` 是"只报名字"。
func _收到打探(探: Dictionary) -> void:
	var 码 := int(探.get("errorCode", -1))
	match 码:
		0:
			var 文 := 文案.取("DATA_INFOSTR_1")
			文 = 文.replace("%1", str(int(探.get("channel", 0))))
			文 = 文.replace("%2", _名)
			文 = 文.replace("%3", str(GAME_DATA.map_name(int(探.get("map", 0)))))
			文 = 文.replace("%4", str(int(floor(float(探.get("x", 0)) / 100.0))))
			文 = 文.replace("%5", str(int(floor(float(探.get("y", 0)) / 100.0))))
			_信息串(文)
			_红字("  ")
		2:
			_信息串(文案.取("DATA_INFOSTR_2").replace("%1", _名))
			_红字(文案.取("DATAN_PROMPT_1"))
		1:
			_信息串(文案.取("DATA_INFOSTR_2").replace("%1", _名))
			_红字(文案.取("DATAN_PROMPT_2").replace("%1", GAME_DATA.item_name(物品号)))
		_:
			_信息串("")
			_红字("")


func _信息串(html: String) -> void:
	var 节 := get_node_or_null("信息串") as RichTextLabel
	if 节 != null:
		节.text = 富文本.译文为BBCode(html)


func _红字(html: String) -> void:
	var 节 := get_node_or_null("红字") as RichTextLabel
	if 节 != null:
		节.text = 富文本.译文为BBCode(html)


func _贴头像(脸: int, 性别: int) -> void:
	var 位 := get_node_or_null("头像") as Control
	if 位 == null:
		return
	for 子 in 位.get_children():
		位.remove_child(子)
		子.queue_free()
	var 像 := OriginalSprite.portrait("character", 角色造型.造型号(脸, 性别))
	if 像 == null:
		return
	var 图 := TextureRect.new()
	图.name = "头像图"
	图.position = Vector2.ZERO
	图.size = 位.size
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	图.texture = 像
	位.add_child(图)


## `MPW:459-463`：`ItemCaiLiaoBox(true)` 60×64，`itemCell` 用乾坤密卷、开购买钮。
func _建材料盒() -> void:
	var 盒 := get_node_or_null("材料盒") as Control
	if 盒 == null:
		return
	盒.custom_minimum_size = Vector2(盒宽, 盒高)
	_格子 = Control.new()
	_格子.name = "物品格"
	_格子.position = Vector2((盒宽 - 格宽) / 2.0, 20.0)		# `ICLB:86-89`
	_格子.size = Vector2(格宽, 格高)
	_格子.mouse_filter = Control.MOUSE_FILTER_IGNORE
	盒.add_child(_格子)
	_图标 = TextureRect.new()
	_图标.name = "图标"
	_图标.position = Vector2.ZERO
	_图标.size = Vector2(格宽, 格高)
	_图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_图标.texture = GAME_DATA.item_icon(物品号)
	_格子.add_child(_图标)
	_数量 = Label.new()
	_数量.name = "数量"
	_数量.position = Vector2(0.0, 20.0)			# `SimpleItemCell.as:141-146`
	_数量.size = Vector2(格宽, 20.0)
	_数量.add_theme_font_size_override("font_size", 12)
	_数量.add_theme_color_override("font_color", Color.WHITE)
	# `SimpleItemCell.as:141-146` 数量白字 + 规则那档 2px 黑描边（`BaseUtil.getGlowFilter()`）
	_数量.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
	_数量.add_theme_color_override("font_outline_color", 皮肤表.文字规则_描边色)
	_数量.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_数量.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_数量.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_格子.add_child(_数量)
	var 买 := TextureButton.new()
	买.name = "购买"
	买.set_script(三态钮)
	买.texture_normal = load(买皮) as Texture2D
	买.ignore_texture_size = true
	买.focus_mode = Control.FOCUS_NONE
	买.position = Vector2((盒宽 - 买宽) / 2.0, 格高 + 20.0 + 3.0)	# `ICLB:96-98`
	买.size = Vector2(买宽, 买高)
	买.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var 字 := Label.new()
	字.set_anchors_preset(Control.PRESET_FULL_RECT)
	字.text = 文案.取("SHOP_BUY")
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	买.add_child(字)
	买.pressed.connect(_点购买)
	盒.add_child(买)


func _点购买() -> void:
	# `ICLB:44-52 buyHandler` → `CashShopWindowEvent.REQUEST_CASH_ITEM_INFO(id)`
	if _宿主 != null and _宿主.has_method("请求商城商品"):
		_宿主.call("请求商城商品", str(物品号))
		return
	if _后端 != null and _后端.has_method("request_cash_item_info"):
		_后端.call("request_cash_item_info", 物品号)


func _接背包() -> void:
	if _会话 == null or not _会话.has_signal("inventory_changed"):
		return
	var 回 := Callable(self, "_收到背包")
	if not _会话.is_connected("inventory_changed", 回):
		_会话.connect("inventory_changed", 回)


func _收到背包(_项: Array) -> void:
	_刷材料格()


## `ICLB:57-65 hasItem()`：有则清滤镜、无则整格 `Style.getDisableFilter()`（换灰度材质）。
func _刷材料格() -> void:
	if _格子 == null:
		return
	var 数 := _背包数量(物品号)
	if _数量 != null:
		_数量.text = str(数) if 数 > 0 else ""
	var 材: Material = null
	if 数 <= 0:
		var 灰 := ShaderMaterial.new()
		灰.shader = 灰度
		材 = 灰
	if _图标 != null:
		_图标.material = 材
	if _数量 != null:
		_数量.material = 材


func _背包数量(号: int) -> int:
	if _会话 == null:
		return 0
	var 包: Variant = _会话.get("inventory")
	if typeof(包) != TYPE_ARRAY:
		return 0
	var 总 := 0
	for 条 in 包:
		if 条 is Dictionary and int((条 as Dictionary).get("id", 0)) == 号:
			总 += int((条 as Dictionary).get("quantity", 0))
	return 总


func _设字(节名: String, 文: String) -> void:
	var 节 := get_node_or_null(节名) as Label
	if 节 != null and not 文.is_empty():
		节.text = 文


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
