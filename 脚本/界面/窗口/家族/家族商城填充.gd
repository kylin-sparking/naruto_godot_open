extends RefCounted
## 家族商城商品区的数据填充与购买动作。
## 商品、价格、贡献余额全部来自服务端 1552:23 / 1552:20，客户端不本地扣除。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")

static func 填(页: Control, 宿主: Node) -> void:
	if 页 == null or 宿主 == null or String(页.name) != "家族商城窗":
		return
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
	if 后端 != null and 后端.has_signal("guild_shop_received") and not 页.has_meta("guild_shop_hooked"):
		页.set_meta("guild_shop_hooked", true)
		家族页回调.挂(页, 后端.guild_shop_received, func(_items: Array, _contribution: int) -> void: 填(页, 宿主))
	var 表: Array = (后端.get("authoritative_guild_shop") if 后端 != null else []) as Array
	var 容器 := 页.get_node_or_null("区商品区") as Control
	if 容器 == null:
		return
	for 子 in 容器.get_children():
		子.queue_free()
	var x := 4.0
	var y := 4.0
	for index in 表.size():
		var 商品 := 表[index] as Dictionary
		var 卡 := _建卡(商品, 页, 宿主)
		卡.position = Vector2(x, y)
		容器.add_child(卡)
		x += 174.0
		if (index + 1) % 3 == 0:
			x = 4.0
			y += 96.0
	var 贡献 := 0
	if 后端 != null:
		贡献 = int((后端.get("authoritative_guild") as Dictionary).get("contribution", 0))
	var 余额 := 页.get_node_or_null("输入贡值") as LineEdit
	if 余额 != null:
		余额.text = str(贡献)

static func _建卡(商品: Dictionary, 页: Control, 宿主: Node) -> Control:
	var 卡 := Panel.new()
	卡.custom_minimum_size = Vector2(166.0, 88.0)
	卡.size = Vector2(166.0, 88.0)
	var 图标 := TextureRect.new()
	图标.position = Vector2(6.0, 8.0)
	图标.size = Vector2(42.0, 42.0)
	图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图标.texture = 游戏数据.item_icon(int(商品.get("item_id", 0)))
	图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	卡.add_child(图标)
	var 名 := Label.new()
	名.position = Vector2(52.0, 8.0)
	名.size = Vector2(108.0, 22.0)
	名.text = 游戏数据.item_name(int(商品.get("item_id", 0)))
	名.clip_text = true
	卡.add_child(名)
	var 数量 := Label.new()
	数量.position = Vector2(52.0, 32.0)
	数量.size = Vector2(108.0, 18.0)
	数量.text = "数量：%d" % int(商品.get("count", 0))
	数量.add_theme_color_override("font_color", Color("#00ff00"))
	卡.add_child(数量)
	var 购买 := Button.new()
	购买.position = Vector2(6.0, 59.0)
	购买.size = Vector2(154.0, 23.0)
	购买.text = "购买  %d贡值" % int(商品.get("price", 0))
	购买.pressed.connect(func() -> void:
		if 宿主 != null and 宿主.has_method("_show_guild_action"):
			宿主.call("_show_guild_action", "家族商城窗:购买商品:%d" % int(商品.get("item_id", 0)))
	)
	卡.add_child(购买)
	return 卡
