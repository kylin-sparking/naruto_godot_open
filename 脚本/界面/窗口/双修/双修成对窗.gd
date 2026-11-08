extends RefCounted
## 打坐时点「双修」那颗球开出来的**成对窗**：原版 `ShuangxiuWindow`（279×228 简介）
## + `SelectPlayerWindowInShuangxiuWindow`（292×279 选人列表）。逐件真值：`真值/窗口/双修选人窗.md`。
##
## 四条最容易做错的口径：
## ① **开窗的不是点击、是回帧**。链是 `ButtonsWindow.onClickShuangxiuBtn:161-173` 发事件 →
##    `UI.as:1236-1239 openShuangxiuWindow` 里 `Client.requestCharSearchInMap(4, null)`；
##    `Client.onCharSearchResult:5003-5010` 收到 type==4 那一帧才
##    `showShuangxiuWindow()` + `setData(行)` + `setEnabledBtn()` ⇒ 帧没回来之前屏幕上
##    不该出现半扇窗，也不该出现"空列表 + 一颗能点的开始双修"。
## ② **两扇是一组**。`UIMain2.showShuangxiuWindow:2346-2353` 调 `centerTwoWindow(简介, 选人)`
##    （`UIMain2.as:3159-3185`）：简介窗在**左**、选人窗在**右**、
##    中间 1 像素缝、两窗同一个 y、整体按 `279+292+1 = 572` 宽居中。
## ③ **拖选人窗要把简介窗一起带走**。原版把简介窗 reparent 成选人窗的子件
##    （`SelectPlayerWindowInShuangxiuWindow.as:36-55`，配套标志 `UIConfig.isShuangxiupane`），
##    这里改成"两扇同步位移"——屏幕上等价，不去动 CanvasLayer 的父子关系。
## ④ **两颗钮的语义是简介窗改写的**。`ShuangxiuWindow.setData:142-150` 把选人窗那两颗
##    `multifunctionalBtn` / `cancelBtn` 的文案换成「双修简介」/「开始双修」并挂上回调 ⇒
##    「开始双修」走 `HealHandler.requestToDoubleHeal`（**和头像菜单那一行同一条**：
##    40 像素闸 + 不够近先自动走过去），不是自己另发一发 86:3。

const 简介场景 := preload("res://场景/界面/窗口/双修/双修简介窗.tscn")
const 选人场景 := preload("res://场景/界面/窗口/双修/双修选人窗.tscn")
## 尺寸 = `ShuangxiuWindow.as:43-44`（279×228）与 `SelectPlayerWindow.as:370-371`（292×279）；
## 缝 1 像素 = `UIMain2.as:3173` 的 `_loc3_.width + _loc4_.width + 1`。
const 简介宽 := 279.0
const 简介高 := 228.0
const 选人宽 := 292.0
## 列表：`SelectPlayerWindow.as:47` pageSize=5、`:246` 行 y = `height*i + i*2`、
## `SelectPlayerWindowCell.as:35-38` 行高硬写 21 ⇒ 步距 23。
const 每页 := 5
const 行高 := 21.0
const 行步距 := 23.0
const 行底皮 := "res://素材/界面/原版窗口/通用控件/输入框.png"
const 选中皮 := "res://素材/界面/原版窗口/通用控件/选中条1.png"
## 行内列位 = `SelectPlayerWindowCell.as:86-101`（名 x=2 宽 137 / 等级 x=144 宽 44 / 职业 x=188 宽 58）。
## ⚠ 这一族**没有头像、没有家族、没有称号**：回帧里那三段解得出来，但原版 `setCellValue`
##    根本不读 ⇒ 不自作主张加列（`Client.as:4987-4996` 那七字段是**组队**那一支才拼的）。
const 列名 := [2.0, 137.0]
const 列级 := [144.0, 44.0]
const 列职 := [188.0, 58.0]
## `MWindow.as:27` `_startDragY = 29`：只有顶部 29 像素是拖动区，列表区不许吞点击。
const 拖动高 := 29.0
const 职业表 := preload("res://脚本/单例/职业.gd")

## 每个宿主各存自己那一组（`窗口管理` 一图一实例，不能串）。
static var _状态 := {}


static func _取(宿主: Node) -> Dictionary:
	if not _状态.has(宿主):
		_状态[宿主] = {"根": null, "选人": null, "简介": null, "行": [], "页": 0,
				"选中号": 0, "选中行": -1, "待开": false, "拖起点": Vector2.INF,
				"拖时位": Vector2.INF}
	return _状态[宿主]


## 那颗球点下去。原版每次点都先把上一轮那一组关掉（`ButtonsWindow.as:167-169`），
## 再发一发搜索 —— 开窗交给回帧（`UI.as:1238`）。
static func 点球(宿主: Node) -> void:
	var 态 := _取(宿主)
	关掉(宿主)
	var 后 := _后端(宿主)
	if 后 == null or not bool(后.get("in_game")):
		_说话(宿主, "双修邀请需要在线")
		return
	态["待开"] = true
	## opCode **1282**、包体 `4:2` —— 第 1 段 searchType=4（双修这一族），第 2 段 mode=2 = **同屏可见玩家**
	## （服务端 `handle_char_search` 的 mode 2 走 `visible_peers`、不看名字；原版这一支
	##  `writeShort(0)` 而不是空串 ⇒ 包体**没有第三段**）。
	后.call("request_char_search", "", 2, 4)


## `1282` 回帧。只有"刚点过球"或"这一组已经开着"才归这里 ——
## 家族那侧按名字搜的是**另一个 searchType**（原版 `FamillyManager.as:897` 发 100）。
static func 回帧(宿主: Node, 结果: Array) -> void:
	var 态 := _取(宿主)
	if not bool(态["待开"]) and 态["根"] == null:
		return
	## 只认 searchType **4** 那一帧（`Client.as:5003` 的分支）。家族查玩家回的是 100，
	## 两边共用 `1282` 这一条 opcode ⇒ 不挡这一道就会互相把对方的列表刷掉。
	var 后 := _后端(宿主)
	if 后 != null and int(后.get("authoritative_char_search_类型")) != 4:
		return
	态["待开"] = false
	if 态["根"] == null:
		_建两扇(宿主, 态)
	填行(宿主, 结果)


static func 已开(宿主: Node) -> bool:
	return _取(宿主)["根"] != null


static func 关掉(宿主: Node) -> void:
	var 态 := _取(宿主)
	var 根: Node = 态["根"]
	if 根 != null and is_instance_valid(根):
		根.queue_free()
	态["根"] = null
	态["选人"] = null
	态["简介"] = null
	态["行"] = []
	态["页"] = 0
	态["选中号"] = 0
	态["选中行"] = -1
	态["待开"] = false
	态["拖起点"] = Vector2.INF
	态["拖时位"] = Vector2.INF


static func 取状态(宿主: Node) -> Dictionary:
	return _取(宿主)


## 成对摆位 = `UIMain2.as:3159-3185`：两窗同 y、简介在左、整体按 572 宽居中。
## ⚠ 视口宽**现查**：无头跑起来的窗口宽不等于工程设置那 960，写死常数会摆到屏外。
static func _建两扇(宿主: Node, 态: Dictionary) -> void:
	var 根 := Control.new()
	根.name = "双修成对"
	根.mouse_filter = Control.MOUSE_FILTER_IGNORE
	宿主.add_child(根)
	态["根"] = 根
	var 简介: Control = 简介场景.instantiate() as Control
	var 选人: Control = 选人场景.instantiate() as Control
	根.add_child(简介)
	根.add_child(选人)
	## 原版 `setDOShow(选人)` 在前、`setDOShow(简介)` 在后 ⇒ **简介窗压在选人窗之上**。
	根.move_child(简介, 1)
	根.move_child(选人, 0)
	态["简介"] = 简介
	态["选人"] = 选人
	var 屏 := 宿主.get_viewport().get_visible_rect().size
	var 总宽 := 简介宽 + 选人宽 + 1.0
	var 左 := maxf(0.0, floorf((float(屏.x) - 总宽) * 0.5))
	var 上 := maxf(0.0, floorf((float(屏.y) - 简介高) * 0.5))
	简介.position = Vector2(左, 上)
	选人.position = Vector2(左 + 简介宽 + 1.0, 上)
	简介.call("装配", 宿主)
	选人.call("装配", 宿主)
	_接钮(宿主, 态)
	选人.gui_input.connect(_拖选人.bind(宿主, 态))


static func _接钮(宿主: Node, 态: Dictionary) -> void:
	var 选人: Control = 态["选人"]
	var 简介: Control = 态["简介"]
	## ⚠ 这些钮在场景里是 **TextureButton**：它继承 `BaseButton`、不是 `Button` 的子类，
	## 写 `as Button` 会静默转成 null ⇒ 后面取 `pressed` 当场崩，两扇开了却没接线。
	(选人.get_node("关钮") as BaseButton).pressed.connect(关掉.bind(宿主))
	## 简介窗那颗关钮**只关简介**：原版 `ShuangxiuWindow` 没重写 `onCloseBtnClick` ⇒
	## 走 `MWindow` 基类那一支，不联动；反过来选人窗关会带关简介（`SelectPlayerWindow.remove():271-274`）。
	(简介.get_node("关钮") as BaseButton).pressed.connect(func() -> void: 简介.visible = false)
	(选人.get_node("搜索钮") as BaseButton).pressed.connect(func() -> void: _按名字搜(宿主, 态))
	(选人.get_node("查看资料钮") as BaseButton).pressed.connect(func() -> void: _查资料(宿主, 态))
	(选人.get_node("多功能钮") as BaseButton).pressed.connect(func() -> void: _显简介(宿主, 态))
	(选人.get_node("取消钮") as BaseButton).pressed.connect(func() -> void: _开始双修(宿主, 态))
	(选人.get_node("上一页钮") as BaseButton).pressed.connect(func() -> void: _翻页(宿主, 态, -1))
	(选人.get_node("下一页钮") as BaseButton).pressed.connect(func() -> void: _翻页(宿主, 态, 1))
	## 三态（悬停 +30 / 按下 −40 / 禁用灰）与四档字色**不在这里接**：那两扇的场景根挂的是
	## 共用壳 `家族子窗.gd`，它按 `metadata/skin` 已经接好了 `mouse_entered/exited/down/up`
	## 与手型光标（`装配` 就在上面 `_建两扇` 里调过）。这里再连一遍 = 两条闸互相顶掉，
	## 拔掉其中一条门还看不出来（10-18 变异实测就是这么露馅的）。
	_按钮态(宿主, 态)


static func 填行(宿主: Node, 结果: Array) -> void:
	var 态 := _取(宿主)
	if 态["选人"] == null:
		return
	态["行"] = 结果
	态["页"] = 0
	态["选中号"] = 0
	态["选中行"] = -1
	(态["选人"].get_node("选中条") as Control).visible = false
	重画行(宿主)
	_按钮态(宿主, 态)


static func 重画行(宿主: Node) -> void:
	var 态 := _取(宿主)
	if 态["选人"] == null:
		return
	var 容 := 态["选人"].get_node("行容器") as Control
	for 子 in 容.get_children():
		容.remove_child(子)
		子.free()		# 这些行都是运行期 new 出来的裸节点，没挂在场景里 ⇒ 直接 free
	var 行们: Array = 态["行"]
	var 起: int = int(态["页"]) * 每页
	for i in range(起, mini(起 + 每页, 行们.size())):
		容.add_child(_建行(宿主, 态, i, 行们[i] as Dictionary))
	var 总页 := maxi(1, int(ceilf(float(行们.size()) / float(每页))))
	(态["选人"].get_node("页码") as Label).text = \
		"%d/%d" % [int(态["页"]) + 1, 总页] if 行们.size() > 0 else ""


static func _建行(宿主: Node, 态: Dictionary, 序: int, 档: Dictionary) -> Control:
	var 行 := Control.new()
	行.name = "行_%d" % 序
	行.position = Vector2(0.0, 行步距 * float(序 - int(态["页"]) * 每页))
	行.size = Vector2(265.0, 行高)
	行.mouse_filter = Control.MOUSE_FILTER_STOP
	行.add_child(_图("底", 行底皮, Vector2.ZERO, Vector2(265.0, 行高)))
	var 亮 := _图("悬停", 选中皮, Vector2(0.0, 1.0), Vector2(265.0, 19.0))
	亮.visible = false
	行.add_child(亮)
	## 悬停高亮 = `SelectPlayerWindowCell.as:102-103`（ROLL_OVER 显示 / ROLL_OUT 隐藏），
	## 而**被选中的那一行**由那根共享的 `curSelectCell` 压着 ⇒ 悬停条让开选中行，别叠两条。
	行.mouse_entered.connect(func() -> void: 亮.visible = int(态["选中行"]) != 序)
	行.mouse_exited.connect(func() -> void: 亮.visible = false)
	行.gui_input.connect(_点行.bind(宿主, 态, 序, int(档.get("character_id", 0))))
	_加字(行, "名", 列名, String(档.get("name", "")), Color("#1e96ff"))
	_加字(行, "等级", 列级, str(int(档.get("level", 0))), Color("#0fffff"))
	_加字(行, "职业", 列职, 职业表.取(int(档.get("job", 0))), Color("#0fffff"))
	return 行


static func _图(名: String, 皮: String, 位: Vector2, 尺: Vector2) -> TextureRect:
	var 图 := TextureRect.new()
	图.name = 名
	图.texture = load(皮) as Texture2D
	图.ignore_texture_size = true
	图.stretch_mode = TextureRect.STRETCH_SCALE
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	图.position = 位
	图.size = 尺
	return 图


static func _加字(行: Control, 名: String, 列: Array, 文: String, 色: Color) -> void:
	var 字 := Label.new()
	字.name = 名
	字.position = Vector2(float(列[0]), 2.0)
	字.size = Vector2(float(列[1]), 18.0)
	字.text = 文
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", 色)
	行.add_child(字)


static func _点行(事件: InputEvent, 宿主: Node, 态: Dictionary, 序: int, 号: int) -> void:
	if not (事件 is InputEventMouseButton) or not (事件 as InputEventMouseButton).pressed \
			or (事件 as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	态["选中行"] = 序
	态["选中号"] = 号
	## 全窗只有**一根**选中条（`SelectPlayerWindow.as:418-423` 的 `curSelectCell`），
	## 点行只是把它平移到那一行上（`:253-254`、`:355-356`）⇒ 不许每行各建一根。
	var 选人: Control = 态["选人"]
	var 条 := 选人.get_node("选中条") as Control
	条.visible = true
	条.position = Vector2(12.0, 108.0 + 行步距 * float(序 - int(态["页"]) * 每页))
	for 子 in (选人.get_node("行容器") as Control).get_children():
		var 亮 := 子.get_node_or_null("悬停") as Control
		if 亮 != null:
			亮.visible = false
	_按钮态(宿主, 态)
	宿主.get_viewport().set_input_as_handled()


## `setEnabledBtn():455-466` + `setData():330-346`：
## 「双修简介」那颗**无条件**可点；「开始双修」只在**有行**时可点；
## 「查看资料」要选中了人才可点（原版 `curCharObj` 为空时那颗是 disable 的）。
static func _按钮态(宿主: Node, 态: Dictionary) -> void:
	var 选人: Control = 态["选人"]
	var 行们: Array = 态["行"]
	var 有行 := 行们.size() > 0
	(选人.get_node("多功能钮") as BaseButton).disabled = false
	(选人.get_node("取消钮") as BaseButton).disabled = not 有行
	(选人.get_node("查看资料钮") as BaseButton).disabled = int(态["选中号"]) <= 0
	(选人.get_node("上一页钮") as BaseButton).disabled = int(态["页"]) <= 0
	(选人.get_node("下一页钮") as BaseButton).disabled = (int(态["页"]) + 1) * 每页 >= 行们.size()
	## 改完 `disabled` **必须叫壳按当前态重画**：这一族的禁用档是换皮换来的，
	## 而 Godot 不会为 `disabled` 变化发任何信号 ⇒ 不重画就会把上一档（悬停/按下）留在钮上，
	## 看起来"禁用了却还能点"。
	选人.call("重画钮态")


static func _翻页(宿主: Node, 态: Dictionary, 向: int) -> void:
	var 新页: int = int(态["页"]) + 向
	if 新页 < 0 or 新页 * 每页 >= (态["行"] as Array).size():
		return
	态["页"] = 新页
	态["选中行"] = -1
	态["选中号"] = 0
	(态["选人"].get_node("选中条") as Control).visible = false
	重画行(宿主)
	_按钮态(宿主, 态)


## 输入框 + 「搜索」= 原版派发 `SelectPlayerWindowEvent.SELECT_PLAYER`（带 `playerName`
## 与**同一个** searchType）⇒ `UI.as:242-245 onSearchPlayer` 发 `1282:4:1:<名字>`
## （mode 1 = 按名字搜全服）。回帧还是 type 4 ⇒ 同一组窗换一批行。
static func _按名字搜(宿主: Node, 态: Dictionary) -> void:
	var 后 := _后端(宿主)
	if 后 == null:
		return
	var 名 := String((态["选人"].get_node("名输入") as LineEdit).text).strip_edges()
	后.call("request_char_search", 名, 1, 4)


## 「查看资料」= 原版 `SelectPlayerWindow.as:325-328` 的 `API.ui.clickCharacter(playerId)`
## ⇒ 上行 `94:0`，开窗的是回帧 `58:0`（`窗口管理._on_他人详细信息`）。
static func _查资料(宿主: Node, 态: Dictionary) -> void:
	var 号 := int(态["选中号"])
	var 后 := _后端(宿主)
	if 号 <= 0 or 后 == null:
		return
	后.call("request_char_full_info", 号)


## 「双修简介」那颗 = `ShuangxiuWindow.__shuangxiuJianjie:108-117`：
## `reverseDisplay` 把简介窗提到最上层，再**重新贴回选人窗左边**
## （`x = 选人窗.x − 279`、y 齐平 —— 这一步的缝是 **0 像素**，与初开那 1 像素不同，原版字面写的）。
static func _显简介(宿主: Node, 态: Dictionary) -> void:
	var 简介: Control = 态["简介"]
	var 选人: Control = 态["选人"]
	var 根: Control = 态["根"]
	if 简介 == null or 选人 == null or 根 == null:
		return
	简介.visible = true
	根.move_child(简介, 根.get_child_count() - 1)
	简介.position = Vector2(选人.position.x - 简介宽, 选人.position.y)


## 「开始双修」= 选中那一行的号，交给地图那一侧的同一条闸
## （`HealHandler.requestToDoubleHeal:374-395`：已在双修 / 不在本场景 / 不够近先自动走过去）。
static func _开始双修(宿主: Node, 态: Dictionary) -> void:
	var 号 := int(态["选中号"])
	var 后 := _后端(宿主)
	if 号 <= 0 or 后 == null or not bool(后.get("in_game")):
		_说话(宿主, "双修邀请需要在线")
		return
	var 地图 := _地图(宿主)
	if 地图 == null or not 地图.has_method("请求双修"):
		_说话(宿主, "双修邀请需要先进图")		# 拿不到场景就什么都不发，别演一次"成功"
		return
	var 话 := String(地图.call("请求双修", 号))
	if not 话.is_empty():
		_说话(宿主, 话)
		return
	关掉(宿主)


## 那条闸在场景里的 `LifeRoot`（挂 `地图实体.gd`）上 —— 与 `头像面板.gd:404` 同一个落点。
## ⚠ **不要用 `玩家.get_parent()` 猜**：玩家不一定直接挂在 LifeRoot 下面。
## （10-18 离线门那份假地图正是照"玩家他爹"这个猜测造的 ⇒ 门全绿，而**在线门一跑就红**：
## 点了「开始双修」什么都没发。假夹具的形状必须来自产品代码的查法，不能来自我对代码的假设。）
static func _地图(宿主: Node) -> Node:
	return 宿主.get_tree().root.find_child("LifeRoot", true, false)


## 按住选人窗顶部 29 像素拖 = 两扇一起走（见文件头③）。
static func _拖选人(事件: InputEvent, 宿主: Node, 态: Dictionary) -> void:
	var 选人: Control = 态["选人"]
	var 简介: Control = 态["简介"]
	if 选人 == null:
		return
	if 事件 is InputEventMouseButton:
		var 按 := 事件 as InputEventMouseButton
		if 按.button_index != MOUSE_BUTTON_LEFT:
			return
		if not 按.pressed:
			态["拖起点"] = Vector2.INF
			态["拖时位"] = Vector2.INF
			return
		if 按.position.y < 拖动高:
			态["拖起点"] = 按.global_position
			态["拖时位"] = 选人.position
		return
	if 事件 is InputEventMouseMotion and 态["拖起点"] != Vector2.INF:
		var 移 := (事件 as InputEventMouseMotion).global_position - (态["拖起点"] as Vector2)
		选人.position = (态["拖时位"] as Vector2) + 移
		if 简介 != null:
			简介.position = Vector2(选人.position.x - 简介宽, 选人.position.y)


static func _后端(宿主: Node) -> Node:
	return 宿主.get_node_or_null("/root/BackendConnection")


static func _说话(宿主: Node, 话: String) -> void:
	var 会 := 宿主.get_node_or_null("/root/GameSession")
	if 会 != null and 会.has_signal("notification_requested"):
		会.notification_requested.emit(话)
