extends RefCounted
## 家族令牌窗（**捐书籍**）——原版 `ZhuGongLingWindow`。
##
## 玩法：把背包里的**家族书籍**拖进 格0..5，点「确定」捐进族贡仓库（**捐了取不回**）。
##
## 判定表终于是有来源的了：`GameData.BangHui.cost.contri.item[*].id`（五种书，
## 实测 16000022..16000026），走 `游戏数据.family_contribution_books()`。
## ⚠️ 本轮以前这里写着"判定表在服务端下发的 `dat/BangHui/cost.dat` 里、离线包没有" ——
##    **那个结论是错的**：同一份表在 `GameData.dat` 里就有（用户 2026-10-01 点出来的）。
##    `ImgManager` 那份运行时数据只是**另一条投递路径**，不是唯一来源。
##
## 协议：`确定` → `requestBanghuiContribution([{itemid, count, position}…])`
## （原版 `ZGL.as:44-56`）—— 就是我方 `request_guild_donate`，**itemId>0 即捐物品**。
## 服务端 `_handle_family_contribution` 对任意 `itemId>0` 都收，每本给 5 点贡献。

const 可拖拽格 := preload("res://脚本/界面/组件/可拖拽格.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

const 格前缀 := "令牌格"
const 每格尺寸 := Vector2(40.0, 40.0)


static func 填(页: Control, 宿主: Node) -> void:
	if 页 == null or String(页.name) != "家族令牌窗":
		return
	_建格(页, 宿主)


## 六格按场景里 `格0..5` 的矩形摆（**不另抄一份坐标**），格子是叠在它上面的可拖拽钮。
static func _建格(页: Control, 宿主: Node) -> void:
	for i in 6:
		var 背景 := 页.get_node_or_null("格%d" % i) as Control
		if 背景 == null:
			continue
		var 名 := "%s%d" % [格前缀, i]
		var 格 := 页.get_node_or_null(名) as Button
		if 格 == null:
			格 = Button.new()
			格.name = 名
			格.set_script(可拖拽格)
			格.flat = true
			格.focus_mode = Control.FOCUS_NONE
			格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			# 只接不吐：原版这一格没有起拖端（`dropItemHandler` 只处理落下）。
			格.set("可拖拽", false)
			格.set("格子归属", "家族令牌")
			格.add_child(_图标())
			格.add_child(_数量())
			页.add_child(格)
		格.position = 背景.position
		格.size = 背景.size
		格.set("槽位号", i)
		# 每次开窗都重连会撞 "already connected"（见背包窗口那条注释）
		for 连 in 格.get_signal_connection_list("拖放"):
			格.拖放.disconnect(连["callable"])
		格.拖放.connect(_落下.bind(格, 页, 宿主))


static func _图标() -> TextureRect:
	var 图 := TextureRect.new()
	图.name = "图标"
	图.position = Vector2(4.0, 4.0)
	图.size = Vector2(32.0, 32.0)
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_SCALE
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return 图


static func _数量() -> Label:
	var 字 := Label.new()
	字.name = "数量"
	字.position = Vector2(20.0, 22.0)
	字.size = Vector2(18.0, 16.0)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	字.add_theme_font_size_override("font_size", 12)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return 字


## 落下（原版 `dropItemHandler`，`ZGL.as:86-108`）。三条判定照抄：
## ① 只认背包来的；② 物品必须在 `cost.contri` 那五种书里，否则提示「很抱歉，不能贡献该物品！」；
## ③ **同一叠只能放一格**（原版按背包 `position` 去重）。
static func _落下(来源格: Button, 目标格: Button, 物品id: String, 格: Button, 页: Control, 宿主: Node) -> void:
	if 来源格 == null or str(来源格.get("格子归属")) != "背包":
		return
	var 号 := int(物品id)
	if not 游戏数据.family_contribution_books().has(号):
		提示(宿主, "很抱歉，不能贡献该物品！")
		return
	var 背包位 := int(来源格.get("槽位号"))
	if _已被别的格收下(页, 格, 背包位):
		return
	var 件数 := _背包件数(宿主, 背包位)
	if 件数 <= 0:
		return
	格.set_meta("item_id", 号)
	格.set_meta("bag_slot", 背包位)
	格.set_meta("count", 件数)
	(格.get_node("图标") as TextureRect).texture = 游戏数据.item_icon(号)
	(格.get_node("数量") as Label).text = str(件数) if 件数 > 1 else ""


## 同一叠书已经躺在别的格子里 ⇒ 原版直接 `return`（`ZGL.as:96-99`），不提示。
static func _已被别的格收下(页: Control, 自己: Button, 背包位: int) -> bool:
	for i in 6:
		var 格 := 页.get_node_or_null("%s%d" % [格前缀, i]) as Button
		if 格 != null and 格 != 自己 and int(格.get_meta("bag_slot", -1)) == 背包位:
			return true
	return false


## 件数从**权威背包**取（`会话.inventory` 下标 = 格位−1），不从格子上的标签取 ——
## 标签在件数为 1 时是空串（背包窗口就是这么写的）。
static func _背包件数(宿主: Node, 背包位: int) -> int:
	var 会话 = 宿主.get("_session") if 宿主 != null else null
	if 会话 == null:
		return 0
	var 背包: Array = 会话.inventory
	var 下标 := 背包位 - 1
	if 下标 < 0 or 下标 >= 背包.size():
		return 0
	return int((背包[下标] as Dictionary).get("quantity", 0))


## 收「确定」时该捐什么：每格一条 `[itemid, count]`（原版 `clickOkBtnHandler`，
## `ZGL.as:44-56` 把 `_keyPosition` 里的行全推出去；空格子不参与）。
static func 收取行(页: Control) -> Array:
	var 出: Array = []
	if 页 == null:
		return 出
	for i in 6:
		var 格 := 页.get_node_or_null("%s%d" % [格前缀, i]) as Button
		if 格 == null or not 格.has_meta("item_id"):
			continue
		var 件数 := int(格.get_meta("count", 0))
		if 件数 > 0:
			出.append([int(格.get_meta("item_id", 0)), 件数])
	return 出


## 捐完清场（成功与否都清 —— 原版 `onResult(true)` 才 `destroy()`，这里由宿主决定）。
static func 清空(页: Control) -> void:
	if 页 == null:
		return
	for i in 6:
		var 格 := 页.get_node_or_null("%s%d" % [格前缀, i]) as Button
		if 格 == null:
			continue
		for 键 in ["item_id", "bag_slot", "count"]:
			if 格.has_meta(键):
				格.remove_meta(键)
		(格.get_node("图标") as TextureRect).texture = null
		(格.get_node("数量") as Label).text = ""


static func 提示(宿主: Node, 文本: String) -> void:
	var 会话 = 宿主.get("_session") if 宿主 != null else null
	if 会话 != null and 会话.has_signal("notification_requested"):
		会话.notification_requested.emit(文本)
