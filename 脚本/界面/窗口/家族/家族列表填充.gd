extends RefCounted
const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")
const 职业表 := preload("res://脚本/单例/职业.gd")
## 家族子窗里**「查询玩家」窗**的行填充 + 选中/分页控制器
## （原版 `SearchPlayerWindow`，`SearchPlayerWindow.as` + `SearchPlayerItemRenderer.as`）。
##
## 数据 = `BackendConnection.authoritative_char_search`（`1282` 回包，服务端
## `handle_char_search` 的 8 字段行）。开窗**不发**搜索：原版要先输名字点「搜索」
## （`SearchPlayerWindow.as:77-84`），回帧到了 `setData` 才把按钮放开、把页码打回 1
## （`:218-226`）。
##
## 分工（2026-11 调整）：
##   * 家族**成员管理窗** ⇒ `家族成员填充.gd`（9 列排序/筛选/分页/行菜单/勾选）
##   * 家族**贡献窗**     ⇒ `家族贡献填充.gd`（9 列排序/分页/库存格）
##   * 家族**列表窗**     ⇒ `家族列表窗.gd`（自己建可选行）
##   * 本文件只留**查询玩家窗**。`_列位` 仍在这里：上面三个渲染器都拿它量表头几何。
##
## 原版几何（`SearchPlayerItemRenderer.as:20-42`）：行宽 260、高 23；名字 135（`UI_BLUE`）、
## 等级 53、门派 60；名字文本 = `[<channelId>线]<名>`。每页 5 条（`rowNum = 5`，
## `setData` 里也是 5），首/末页钮**隐藏**（`firstAndLastBtnVisible = false`）——
## 场景里本来就只画了上一页/下一页两颗。

## 行高：`SearchPlayerItemRenderer.as:20` `super(260,23)`
const 行高 := 23.0
## 每页条数：`SearchPlayerWindow.as:110` `rowNum = 5` + `:223` `reset(len, 5)`
const 每页 := 5
## 行选中底：与成员窗/列表窗同一张皮（原版 `CommonListSkin` 的高亮条）
const 行选中底皮 := "res://素材/界面/原版窗口/家族/行选中底.png"
const 选中底边 := {"左": 7.0, "上": 5.35, "右": 7.9, "下": 5.75}
## 名字列 `UIConfig.UI_BLUE`（`SearchPlayerItemRenderer.as:28`）；其余 `cretateLabel`
## 不传色 = `UI_WHITE`（`CommonItemRenderer.as:99`）
const 名列蓝 := Color("#1e90ff")
const 文字色 := Color.WHITE
const 空提示色 := Color("#a9957f")


static func 填(页: Control, 宿主: Node) -> void:
	# ⚠️ 只填自己这扇窗：`家族子窗壳.切换` 开**每一扇**子窗都会把七个填充器全跑一遍。
	#    成员窗已归 `家族成员填充.gd`，这里再伸手就会互相覆盖（2026-10-15 那次的教训）。
	if 页 == null or 宿主 == null or String(页.name) != "家族搜索窗":
		return
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
	if 后端 != null and 后端.has_signal("char_search_received") and not 页.has_meta("sr_hooked"):
		页.set_meta("sr_hooked", true)
		家族页回调.挂(页, 后端.char_search_received, func(_结果: Array) -> void:
			# 只认家族这一条（searchType 100，原版 `Client.as:5012` 的分支）⇒
			# 双修选人窗（4）的回帧不该把这张列表刷掉。
			if int(后端.get("authoritative_char_search_类型")) == 100:
				页.set_meta("sr_page", 1)		# `setData` → `reset` 打回第 1 页
				设搜索中(页, false)
				刷新(页, 宿主))
	# 开窗先按手上已有的结果画一次（原版窗是每次新建，这里窗会复用）。
	刷新(页, 宿主)


## 按当前结果重画当前页。`sr_page` 由调用方（回帧/翻页）维护。
static func 刷新(页: Control, 宿主: Node) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	var 结果 := _结果(宿主)
	var 总 := maxi(1, int(ceilf(float(结果.size()) / float(每页))))
	页.set_meta("sr_page", clampi(int(页.get_meta("sr_page", 1)), 1, 总))
	var 页号 := int(页.get_meta("sr_page", 1))
	var 起 := (页号 - 1) * 每页
	_渲染(页, 结果.slice(起, mini(结果.size(), 起 + 每页)))
	_同步分页(页, 总)


static func _结果(宿主: Node) -> Array:
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection") if 宿主 != null else null
	if 后端 == null:
		return []
	# 类型不对（上一发是双修选人）就别把别人的结果当自己的
	if int(后端.get("authoritative_char_search_类型")) != 100:
		return []
	return (后端.get("authoritative_char_search") as Array).duplicate()


## 整页重建（原版 `updateCurrentPage`：整表换 dataProvider ⇒ 选中态跟着清）。
static func _渲染(页: Control, 页行: Array) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	页.set_meta("sr_rows", 页行)
	页.set_meta("sr_selected", -1)
	页.set_meta("sr_hover", -1)
	for 子 in 容器.get_children():
		容器.remove_child(子)
		子.queue_free()
	if 页行.is_empty():
		_空提示(容器)
		return
	# 表头几何量一次存 meta；行 Label 的 x 要减掉容器原点（表头量的是页坐标）
	if not 页.has_meta("sr_cols"):
		页.set_meta("sr_cols", _列位(页, "列查询", 3))
	var 列位: Array = 页.get_meta("sr_cols") as Array
	var 宽 := 容器.size.x
	var 起 := 容器.position.x
	for i in 页行.size():
		var 记: Dictionary = 页行[i] as Dictionary
		var 行 := Control.new()
		行.name = "行%d" % (i + 1)
		行.size = Vector2(宽, 行高)
		行.position = Vector2(0.0, i * 行高)
		行.mouse_filter = Control.MOUSE_FILTER_STOP
		行.set_meta("row_index", i)
		容器.add_child(行)
		var 底 := NinePatchRect.new()
		底.name = "选中底"
		底.texture = load(行选中底皮) as Texture2D
		底.size = Vector2(宽, 行高)
		底.patch_margin_left = float(选中底边["左"])
		底.patch_margin_top = float(选中底边["上"])
		底.patch_margin_right = float(选中底边["右"])
		底.patch_margin_bottom = float(选中底边["下"])
		底.mouse_filter = Control.MOUSE_FILTER_IGNORE
		底.visible = false
		行.add_child(底)
		行.mouse_entered.connect(_悬停.bind(页, 行, true))
		行.mouse_exited.connect(_悬停.bind(页, 行, false))
		# ⚠️ 形参顺序 `(事件, 页, 序)`：`bind` 的参数追加在信号参数之后
		行.gui_input.connect(_点行.bind(页, i))
		var 值 := [
			"[%d线]%s" % [int(记.get("line", -1)), String(记.get("name", "-"))],
			str(int(记.get("level", 0))),
			职业表.取(int(记.get("job", 300))),
		]
		for c in 列位.size():
			var 字 := Label.new()
			字.name = "列%d" % c
			字.position = Vector2(float(列位[c]["x"]) - 起, 2.0)
			字.size = Vector2(float(列位[c]["w"]), 19.0)
			字.text = String(值[c]) if c < 值.size() else "-"
			字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			字.mouse_filter = Control.MOUSE_FILTER_IGNORE
			字.add_theme_font_size_override("font_size", 12)
			字.add_theme_color_override("font_color", 名列蓝 if c == 0 else 文字色)
			行.add_child(字)


## 当前选中的一条（没选 ⇒ 空字典）。原版按钮都是 `if(_list.selectedItem)` 才发请求。
static func 选中(页: Control) -> Dictionary:
	if 页 == null:
		return {}
	var 行们: Array = 页.get_meta("sr_rows", []) as Array
	var 序 := int(页.get_meta("sr_selected", -1))
	if 序 < 0 or 序 >= 行们.size():
		return {}
	return 行们[序] as Dictionary


static func _点行(事件: InputEvent, 页: Control, 序: int) -> void:
	if not (事件 is InputEventMouseButton):
		return
	var 按 := 事件 as InputEventMouseButton
	if not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	页.set_meta("sr_selected", 序)
	_重画亮(页)


## 悬停信号没有参数，bind 的三个就是全部实参 ⇒ (页, 行, 进)。
static func _悬停(页: Control, 行: Control, 进: bool) -> void:
	if not is_instance_valid(行) or not is_instance_valid(页):
		return
	页.set_meta("sr_hover", int(行.get_meta("row_index", -1)) if 进 else -1)
	_重画亮(页)


static func _重画亮(页: Control) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	var 选: int = int(页.get_meta("sr_selected", -1))
	var 悬: int = int(页.get_meta("sr_hover", -1))
	for 子 in 容器.get_children():
		if not (子 is Control):
			continue
		var 行 := 子 as Control
		var 序: int = int(行.get_meta("row_index", -1))
		if 序 < 0:
			continue
		var 底 := 行.get_node_or_null("选中底") as NinePatchRect
		if 底 != null:
			底.visible = 序 == 选 or 序 == 悬


static func 翻页(页: Control, 宿主: Node, 目标: String) -> void:
	if 页 == null or 宿主 == null:
		return
	var 总 := maxi(1, int(ceilf(float(_结果(宿主).size()) / float(每页))))
	var 现 := clampi(int(页.get_meta("sr_page", 1)), 1, 总)
	match 目标:
		"上一页": 页.set_meta("sr_page", maxi(1, 现 - 1))
		"下一页": 页.set_meta("sr_page", mini(总, 现 + 1))
		"首页": 页.set_meta("sr_page", 1)
		"末页": 页.set_meta("sr_page", 总)
		_: return
	刷新(页, 宿主)


## 搜索在途时禁用「搜索」（`SearchPlayerWindow.as:81` `enabled = false`），
## 回帧 `setData` 再放开（`:220`）。纹理钮的禁用档是换皮换来的 ⇒ 叫宿主重画一遍。
static func 设搜索中(页: Control, 中: bool) -> void:
	if 页 == null:
		return
	var 钮 := 页.get_node_or_null("钮搜索") as TextureButton
	if 钮 != null:
		钮.disabled = 中
	页.call("重画钮态")


static func _同步分页(页: Control, 总: int) -> void:
	var 页号 := int(页.get_meta("sr_page", 1))
	var 页码 := 页.get_node_or_null("分页短分页/页码") as Label
	if 页码 != null:
		页码.text = "%d/%d" % [页号, 总]
	var 上 := 页.get_node_or_null("分页短分页/上一页") as TextureButton
	if 上 != null:
		上.disabled = 页号 <= 1
	var 下 := 页.get_node_or_null("分页短分页/下一页") as TextureButton
	if 下 != null:
		下.disabled = 页号 >= 总


## 从表头节点量列位：返回 [{x, w}, …]。
## 两种命名：成员窗是 `列成员0..N`（每个即一列），列表窗是 `表头/<标题名>`。
## ⚠️ 贡献窗/成员窗也 preload 本文件用这一格 ⇒ 别删、别改签名。
static func _列位(页: Control, 前缀: String, 列数: int, 名单 := []) -> Array:
	var 出: Array = []
	if 名单.is_empty():
		for i in 列数:
			var 钮 := 页.get_node_or_null(前缀 + str(i)) as Control
			出.append({"x": 钮.position.x, "w": 钮.size.x} if 钮 != null else {"x": 0.0, "w": 100.0})
	else:
		for 名 in 名单:
			var 钮 := 页.get_node_or_null(前缀 + String(名)) as Control
			出.append({"x": 钮.position.x, "w": 钮.size.x} if 钮 != null else {"x": 0.0, "w": 100.0})
	return 出


static func _空提示(容器: Control) -> void:
	var 提示 := Label.new()
	提示.name = "空提示"
	提示.size = Vector2(容器.size.x, 行高)
	提示.text = "暂无查询结果"
	提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	提示.add_theme_color_override("font_color", 空提示色)
	容器.add_child(提示)
