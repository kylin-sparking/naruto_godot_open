extends SceneTree

## 伊鲁卡三窗回归门（2026-10-04 深夜）：兑换商店 + 变身卡属性互换 + 变身卡特性互换。
##
## 盯的是**只有跑起来才看得见**的四类事：
##   ① 落地页真开得出（点菜单行 → 页根在、标题/尺寸对）；
##   ② 兑换商店的格子**按原版公式摆**（5 列 × (130+5)、行 200+6；格内 11 件的层序与坐标），
##      以及**没数据时不许假造**：没有行 ⇒ 列表必须是空的 + 状态行说清为什么空
##      （⚠ 2026-10-04 补：状态行在场景里是 `visible=false`，所以断言的是**它真的显形**，不只是 text 对）；
##      再加一条**1820 原始二进制回帧的整条回环**（字节序 → 会话表 → 页面格子），见 `_量兑换回帧`；
##   ③ 互换窗那**五支客户端校验**逐字（`onSwapDropA/B` 全不发帧，属可搬的客户端行为）
##      与「请放入两张变身卡 / 材料不足」两支；
##   ④ 两模的几何差：`_loc4_` 310 / 410 ⇒ 确认钮 y = 368 / 468，特性四件只在特殊版存在。
##
## ⚠ 三条硬口径：`push_input` 前钉 `root.size`；改状态与断言之间隔帧；
##   本门**不发任何协议**（`request_exchange_list` 那条走的是测试后端实例，不是真 socket；
##   兑换/交换/确认三支都只落状态行），也不点原生钮 ⇒ 不落 `user://玩家数据.json`。
##
## 运行：Godot --headless --path . --script res://测试/伊鲁卡三窗回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页表 := ["兑换商店", "变身卡属性互换", "变身卡特性互换"]
## 只为「1820 原始回帧 → 会话表 → 页面」那条回环用（它是个不连线的后端实例）。
const TEST_BACKEND := preload("res://测试/测试后端连接.gd")

var 帧 := 0
var 阶段 := 0
var 场景: Node
var 管: Node
var 红数 := 0
## 假后端：只收不连，用来**看兑换请求到底发没发**（§3.121）。
class 假后端:
	extends Node
	var in_game := true
	var 兑换: Array = []

	func request_exchange(sn: int) -> bool:
		兑换.append(sn)
		return true


## 拖放载荷里的"来源格"：落点件只从它身上读 `槽位号`（同 `可拖拽格` 的约定）。
class 假来源格:
	extends Control
	var 槽位号 := 0


var 日志: Array[String] = []
var 夹具: Array = []


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


func _窗(页名: String) -> Node:
	return 管._窗口们.get(页名) as Node


func _页根(页名: String) -> Control:
	var 窗 := _窗(页名)
	if 窗 == null:
		return null
	var 出: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			出 = 子 as Control
	return 出			# **取最后一个**：直接调 `_render_*(行)` 追加的那一页在最后


func _文(件: Node) -> String:
	if 件 is RichTextLabel:
		return (件 as RichTextLabel).text
	if 件 is Label:
		return (件 as Label).text
	return "<不是文本件>"


func _initialize() -> void:
	call_deferred("_跑")


func _读夹具() -> void:
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/兑换商店_夹具.json"))
	夹具 = ((解 as Dictionary).get("行", []) as Array).duplicate(true)


func _跑() -> void:
	root.size = Vector2i(960, 560)
	_读夹具()
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	_量兑换空态()
	await _量兑换有数据()
	await _量兑换回帧()
	await _量互换(false)
	await _量互换(true)
	收尾("")


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


## ── ①② 兑换商店 ────────────────────────────────────────────────────────────

func _量兑换空态() -> void:
	日志.append("=== 兑换商店：没有行的时候（没连后端 / 回帧未到 ⇒ 不许假造数据）===")
	管.call("打开", "兑换商店")
	var 窗 := _窗("兑换商店")
	_记(窗 != null, "落地页「兑换商店」开出来了")
	if 窗 == null:
		return
	var 页 := _页根("兑换商店")
	_记(页 != null and String(页.name) == "原版兑换商店内容", "页根 = %s" % (页.name if 页 != null else "无"))
	_记(窗._status.text.find("1820") >= 0, "空态要把原因写在状态行，实测 %s" % 窗._status.text)
	# ⚠ 这一条是本轮补的：那个标签在 `功能窗口.tscn:79` 是 `visible = false`，而全工程没人把它设回可见
	#   ⇒ 上一版只断 `.text` 是**假绿**（文字对、玩家看不见）。现在断的是"看得见"。
	_记(窗._status.visible, "状态行**真的显形**（写文案才显形那条口子生效；以前它恒 visible=false）")
	_记((页.get_node("兑换列表/兑换列表_内容") as Control).get_child_count() == 0,
			"没数据 ⇒ 内容里**一个格子都不许有**")
	_记(_文(页.get_node("说明")).find("免费兑换顶级物品") >= 0
			and _文(页.get_node("说明")).find("[color=#ff0000]") >= 0,
			"说明行是**两色 BBCode**（原版嵌套 font），实测 %s" % _文(页.get_node("说明")))
	_记(absf((页.get_node("兑换列表") as Control).size.x - 688.0) < 0.6,
			"滚动区 688 宽（`ScrollPane` = background3.width−10 = 688），实测 %.1f"
			% (页.get_node("兑换列表") as Control).size.x)


func _量兑换有数据() -> void:
	日志.append("=== 兑换商店：喂 2.2.3 捕获目录的 12 行 ⇒ 格子几何 / 灰化 / 按钮三支 ===")
	管.call("全部关闭")
	# ⚠️ 关过之后**必须重新打开**：`push_input` 那套真鼠标只落在**可见**的控件上，
	#    窗口藏着时点了等于没点（这一支从来没量到过，就是卡在这儿 —— 见 §3.121）。
	管.call("打开", "兑换商店")
	if 夹具.size() == 0:
		_记(false, "夹具读不到 ⇒ 这一大段**没量到**（不是通过）")
		return
	# ⚠️ **先把首行的材料塞进背包再渲染**：否则每一行都是"不够" ⇒ 钮全禁用 ⇒
	#    下面「点了要发 1820」那一支**根本量不到**（老版本门就是这么假绿的：它自己在日志里
	#    写"没量到（不是通过）"，可整门照样报"通过"）。只写内存、不落盘。
	var 窗 := _窗("兑换商店")
	var 会话: Node = (窗 as Node).get("_session")
	if 会话 != null and 夹具.size() > 0:
		for 项 in ((夹具[0] as Dictionary).get("needItems", []) as Array):
			# ⚠️ JSON 的数是 float ⇒ 必须 `str(int(...))`（`str(1210242.0)` 会让 `int()` 得 0）
			(会话.get("inventory") as Array).append({
				"id": str(int((项 as Dictionary).get("itemid", 0))),
				"quantity": int((项 as Dictionary).get("count", 0))})
	窗.call("_render_exchange_shop", 夹具)
	await _等(3)
	var 页 := _页根("兑换商店")
	var 内容 := 页.get_node("兑换列表/兑换列表_内容") as Control
	_记(内容.get_child_count() == 夹具.size(), "格子数 == 行数（%d），实测 %d" % [夹具.size(), 内容.get_child_count()])
	var 首 := 内容.get_child(0) as Control
	var 二 := 内容.get_child(1) as Control
	_记(首.position == Vector2(2, 4), "第 1 格 @(2,4)（`x=2+col*(130+5)`、`y=4+row*(200+6)`）实测 %s" % str(首.position))
	_记(二.position == Vector2(137, 4), "第 2 格 @(137,4)（列距 135）实测 %s" % str(二.position))
	_记(内容.get_child(5).position == Vector2(2, 210), "第 6 格换行 @(2,210) 实测 %s" % str(内容.get_child(5).position))
	_记(首.size == Vector2(130, 200), "格 130×200（`cellWidth/cellHeight`）实测 %s" % str(首.size))
	_记(首.get_child(0).name == "边框" and 首.get_child(1).name == "目标标题"
			and 首.get_child(2).name == "主格" and 首.get_child(3).name == "材料标题",
			"层序照 `createUi` :197-210：边框 → 目标标题 → 主格 → 材料标题（实 %s）"
			% ", ".join(首.get_children().map(func(x): return String(x.name))))
	var 主 := 首.get_node("主格") as TextureRect
	_记(主.position == Vector2(45, 22), "主格 @((130−40)/2, 22)（doLayout :136-137）实测 %s" % str(主.position))
	_记(主.get_child_count() > 0 and String(主.get_child(0).name) == "图标",
			"图标是格底的**子件**（`__showIcon` addChild 进格 :72-76），实 %s"
			% (主.get_child(0).name if 主.get_child_count() > 0 else "格内没件"))
	var 料数: int = (夹具[0] as Dictionary).get("needItems", []).size()
	var 容 := 首.get_node("材料格") as Control
	_记(容.get_child_count() == 料数, "材料格 %d 枚（sn=%s）" % [料数, str((夹具[0] as Dictionary).get("sn"))])
	_记(容.get_child(1).position == Vector2(41, 0),
			"材料格横距 1 ⇒ 第 2 枚 @41（`width*(i mod rowCount)+…hgap`，rowCount=3）实测 %s"
			% str(容.get_child(1).position))
	var 缺料 := false
	var 缺料首行 := false
	for j in 料数:
		var 项: Dictionary = (夹具[0] as Dictionary)["needItems"][j]
		if int(窗._背包数量(int(项["itemid"]))) < int(项["count"]):
			缺料 = true
			缺料首行 = true
			_记(容.get_child(j).material != null,
					"材料不足的那枚（%s 要 %d）挂了灰度材质（`setFilters(拥有>=需求)` :404）"
					% [str(项["itemid"]), int(项["count"])])
	if not 缺料:
		日志.append("  -- 这一行材料全都够 ⇒ 灰化那一支**没量到**（不是通过）")
	var 钮 := 首.get_node("兑换钮") as TextureButton
	var 题 := 钮.get_node("钮字") as Label
	_记(钮.position == Vector2(25, 170) and 钮.size == Vector2(80, 22),
			"兑换钮 80×22 @((130−80)/2,170)（:226-235）实测 %s %s" % [str(钮.position), str(钮.size)])
	_记(String(钮.texture_normal.resource_path).ends_with("兑换钮.png"),
			"三档是**预烘皮**（80×22 整帧拉伸）：%s" % String(钮.texture_normal.resource_path).get_file())
	_记(题.text == "兑换" or 题.text == "已兑", "钮字取 BTN_TEXT / BTN_TEXT_2，实测 %s" % 题.text)
	_记(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "钮是手型")
	# 原版 `setExchageBtnEnabled` 最后一支：**材料不齐 ⇒ 钮直接禁用**（:170-173），
	# 禁用件不吃鼠标 ⇒ 那一支的正确断言是"点不动"，不是"点了没回显"。
	_记(钮.disabled == 缺料首行,
			"首行材料%s ⇒ 钮 disabled=%s（:170-173 齐才可用）" % ["不齐" if 缺料首行 else "齐", str(钮.disabled)])
	var 可点: Array = []
	for c in 内容.get_children():
		var t := (c as Control).get_node_or_null("兑换钮") as TextureButton
		if t != null and not t.disabled:
			可点.append(t)
	if 可点.is_empty():
		日志.append("  -- 12 行里没有一枚材料齐的 ⇒ 「点了要发 1820」那一支**没量到**（不是通过）")
	else:
		窗._show_hint("")		# 清空也走这条口子（它才管显形）
		await _点((可点[0] as Control).get_global_rect().get_center())
		_记(窗._status.text.find("服务端结算") >= 0,
				"点齐料那颗 ⇒ 离线那口话是「要在服务端结算」（§3.121 之前写死的「本工程未接」是假的），实测 %s" % 窗._status.text)
		# ★ 真发：装个假后端看它到底发没发（§3.121）
		var 假 := 假后端.new()
		窗.set("_backend", 假)
		窗._show_hint("")
		await _点((可点[0] as Control).get_global_rect().get_center())
		_记(假.兑换.size() == 1 and 假.兑换[0] > 0,
			"在线点齐料那颗 ⇒ 真发 request_exchange(sn)，实测 %s" % str(假.兑换))
		窗.set("_backend", null)


## ── 2026-10-04 补：1820 列表回帧的**整条回环**（字节序 → 会话表 → 页面格子）────────────
##
## 为什么值得钉：服务端这条回帧**不是 AMF3 文本**，是原始二进制
## （`_send_exchange_recipe_list` → `send_original_packet`，`fake_flash_server.py:26291/13217`），
## 字段序只有 AS3 `ExchangeItem.decode`（`data/exchange/ExchangeItem.as:53-80`）说了算 ——
## 差一个字节整页就是空的，而且**不报错**。所以这里自己按那个布局造帧、喂进解码器、
## 再要求页面真的长出 12 个格子。
func _量兑换回帧() -> void:
	日志.append("=== 兑换商店：1820 原始回帧解码（字节序照 ExchangeItem.decode）===")
	if 夹具.size() == 0:
		_记(false, "夹具读不到 ⇒ 这一大段**没量到**（不是通过）")
		return
	var 假 := TEST_BACKEND.new()
	root.add_child(假)
	假.set("in_game", true)
	假.call("_handle_original_frame", _兑换列表原始帧(夹具))
	var 表: Array = 假.get("authoritative_exchange")
	_记(表.size() == 夹具.size(), "回帧 %d 行 ⇒ 会话表 %d 行" % [夹具.size(), 表.size()])
	if 表.is_empty():
		假.queue_free()
		return
	var 头: Dictionary = (夹具[0] as Dictionary)
	var 会: Dictionary = 表[0]
	_记(int(会.get("sn", -1)) == int(头["sn"]) and int(会.get("item_id", -1)) == int(头["targetItemid"])
			and int(会.get("quantity", -1)) == int(头["targetQuantity"]),
			"第 1 行的 sn/目标编号/数量 落位正确，实测 sn=%s item=%s qty=%s"
			% [str(会.get("sn")), str(会.get("item_id")), str(会.get("quantity"))])
	_记(int(会.get("total_limit", -1)) == int(头["totalCountLimit"])
			and int(会.get("character_limit", -1)) == int(头["singleCountLimit"])
			and int(会.get("exchange_count", -1)) == int(头["exchangeCount"])
			and int(会.get("single_exchanged", -1)) == int(头["singleExchanged"])
			and int(会.get("rest_time", -1)) == int(头["restTime"])
			and bool(会.get("time_limited", true)) == bool(头["isTimeLimited"]),
			"六个计数 + 限时位**逐个对号**（错位就会串成「总数=个人数」那种静默假数据）")
	var 料: Array = 会.get("need_items", [])
	_记(料.size() == (头["needItems"] as Array).size()
			and int((料[0] as Dictionary).get("item_id", -1)) == int((头["needItems"] as Array)[0]["itemid"])
			and int((料[0] as Dictionary).get("quantity", -1)) == int((头["needItems"] as Array)[0]["count"]),
			"材料条数与第 1 枚 (编号,数量) 对号（%d 枚）" % 料.size())
	# ⚠ **逐行逐字段**比，不是只比第 1 行：夹具第 1 行的六个计数**全是 0**，
	#   只比它的话"把两个字段读串位"照样绿（本轮差点就这么交了）。
	var 错位: Array[String] = []
	for i in 表.size():
		var 实: Dictionary = 表[i]
		var 期: Dictionary = 夹具[i]
		var 对 = {
			"sn": 期["sn"], "item_id": 期["targetItemid"], "quantity": 期["targetQuantity"],
			"total_limit": 期["totalCountLimit"], "character_limit": 期["singleCountLimit"],
			"exchange_count": 期["exchangeCount"], "single_exchanged": 期["singleExchanged"],
			"rest_time": 期["restTime"],
		}
		for 键 in 对:
			if int(实.get(键, -1)) != int(对[键]):
				错位.append("第%d行 %s 实=%s 应=%s" % [i, 键, str(实.get(键)), str(对[键])])
		if bool(实.get("time_limited", not bool(期["isTimeLimited"]))) != bool(期["isTimeLimited"]):
			错位.append("第%d行 time_limited 错位" % i)
	_记(错位.is_empty(), "12 行 × 9 个字段**逐个**等于夹具（%s）"
			% ("全等" if 错位.is_empty() else "；".join(错位.slice(0, 4))))
	# 会话表 → 页面：`_render_exchange_shop([])` 里那条 `_在线行(宿主)` 才是"游戏里真走的通路"
	var 窗 := _窗("兑换商店")
	var 原: Variant = 窗.get("_backend")
	窗.set("_backend", 假)
	窗.call("_render_exchange_shop", [])
	await _等(3)
	var 页 := _页根("兑换商店")
	var 内容 := 页.get_node("兑换列表/兑换列表_内容") as Control
	_记(内容.get_child_count() == 表.size(),
			"**不喂夹具**、只靠回帧 ⇒ 页面自己长出 %d 个格子，实测 %d" % [表.size(), 内容.get_child_count()])
	var 图标 := (内容.get_child(0).get_node("主格/图标") as TextureRect)
	var 该有 := String(游戏数据().item_icon_path(int(头["targetItemid"])))
	_记(String(图标.texture.resource_path) == 该有,
			"第 1 格里的图标 = 回帧那个目标编号的图标（%s vs %s）"
			% [String(图标.texture.resource_path).get_file(), 该有.get_file()])
	窗.set("_backend", 原)
	假.queue_free()


## 造一帧服务端形态的 1820 列表回帧：`>HH`(校验和,sid) + `<H`opcode + `<Bi` + 每行 `<iBi6iB4i` + 需求 `<2i`×n。
## 客户端不验校验和（见 `后端连接.gd::_handle_original_frame` 的注释），所以头前 4 字节填 0 也照样收。
func _兑换列表原始帧(行: Array) -> PackedByteArray:
	var 体 := PackedByteArray()
	体.resize(5)
	体[0] = 0
	体.encode_s32(1, 行.size())
	for 条v in 行:
		var 条: Dictionary = 条v
		var 料: Array = 条.get("needItems", [])
		var n := 体.size()
		体.resize(n + 50 + 料.size() * 8)
		体.encode_s32(n, int(条["sn"]))
		体[n + 4] = 1 if bool(条.get("isTimeLimited", false)) else 0
		体.encode_s32(n + 5, int(条.get("restTime", 0)))
		体.encode_s32(n + 9, int(条.get("totalCountLimit", 0)))
		体.encode_s32(n + 13, int(条.get("singleCountLimit", 0)))
		体.encode_s32(n + 17, int(条.get("exchangeCount", 0)))
		体.encode_s32(n + 21, int(条.get("singleExchanged", 0)))
		体.encode_s32(n + 25, int(条["targetItemid"]))
		体.encode_s32(n + 29, int(条.get("targetQuantity", 1)))
		体[n + 33] = 1 if bool(条.get("targetBind", false)) else 0
		体.encode_s32(n + 34, int(条.get("needJinBi", 0)))
		体.encode_s32(n + 38, int(条.get("needLiJin", 0)))
		体.encode_s32(n + 42, int(条.get("needYuanBao", 0)))
		体.encode_s32(n + 46, 料.size())
		var j := n + 50
		for 项v in 料:
			var 项: Dictionary = 项v
			体.encode_s32(j, int(项["itemid"])); j += 4
			体.encode_s32(j, int(项["count"])); j += 4
	var 帧 := PackedByteArray()
	帧.resize(6 + 体.size())
	帧.encode_u16(4, 1820)
	for i in 体.size():
		帧[6 + i] = 体[i]
	return 帧


func _点(位: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	root.push_input(移)
	await _等(2)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位
	按.global_position = 位
	root.push_input(按)
	await _等(2)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 位
	放.global_position = 位
	root.push_input(放)
	await _等(3)


## ── ③④ 两模互换 ─────────────────────────────────────────────────────────────

func _量互换(特殊: bool) -> void:
	var 页名 := "变身卡特性互换" if 特殊 else "变身卡属性互换"
	var 基 := 410 if 特殊 else 310
	日志.append("=== %s（%s，_loc4_=%d）===" % [页名, "特殊模式" if 特殊 else "普通模式", 基])
	管.call("全部关闭")	# 上一扇（兑换商店 720 宽）还开着会盖住这一扇的钮
	管.call("打开", 页名)
	var 窗 := _窗(页名)
	if 窗 == null:
		_记(false, "%s 没开出来" % 页名)
		return
	await _等(3)
	var 页 := _页根(页名)
	_记(_文(页.get_node("说明")) == ("放入两张变身卡，只交换特性属性，其他属性保持不变" if 特殊
			else "放入两张变身卡，交换基础属性和附加属性"),
			"说明文案按模式取（:586 两支），实测 %s" % _文(页.get_node("说明")))
	_记(absf((页.get_node("分隔线二") as Control).position.y - float(基 - 29)) < 0.6,
			"分隔线二 y=%d（页面坐标 = AS3 y − 29）实测 %.1f" % [基 - 29, (页.get_node("分隔线二") as Control).position.y])
	_记(absf((页.get_node("确认钮") as Control).position.y - float((495 if 特殊 else 395) - 27 - 29)) < 0.6,
			"确认钮 y = 窗高−22−BORDER_GAP(5) 再抬 29，实测 %.1f" % (页.get_node("确认钮") as Control).position.y)
	var 钮 := 页.get_node("确认钮") as Button
	_记(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "确认交换是手型")
	_记(_文(页.get_node("数量行")).find("【研究所凭证】") >= 0 and _文(页.get_node("数量行")).find("当前拥有：") >= 0,
			"消耗行逐字照 `:1729`，实测 %s" % _文(页.get_node("数量行")))
	# ⚠ 整行里「【研究所凭证】」那一截**恒绿**（:1729 写死的），所以只能量**数字那一截**的颜色
	var 消串 := _文(页.get_node("数量行"))
	var 尾 := 消串.substr(消串.find("当前拥有："))
	_记((尾.find("[color=#00FF00]") >= 0) == (int(窗._背包数量(16000555)) > 0),
			"拥有数 >0 绿 / =0 红（同一条 :1728），背包 %d、那一截 %s"
			% [int(窗._背包数量(16000555)), 尾])
	if 特殊:
		_记(_文(页.get_node("特性A")) == "[color=#999999]放入变身卡后显示特性属性[/color]",
				"特殊版有特性文本框且初始是灰字提示（:717），实测 %s" % _文(页.get_node("特性A")))
	else:
		_记(页.get_node_or_null("特性A") == null, "普通版**根本没有**特性文本框（:664 置 null），不是隐藏")
	# 五支校验 + 收下
	var 态: Dictionary = 页.get_meta("swap_state")
	var 互换 := load("res://脚本/界面/窗口/变身卡互换窗.gd")
	_记(String(互换.放入(态, "卡格A", {"id": "16000110", "position": 1})) == "只能放入变身卡",
			"非 121 段 ⇒ 「只能放入变身卡」（:1879）")
	_记(String(互换.放入(态, "卡格A", {"id": "1210252", "position": 0})) == "请先将变身卡卸下到背包再操作",
			"position<=0 ⇒ 「请先将变身卡卸下到背包再操作」（:1884）")
	_记(String(互换.放入(态, "卡格A", {"id": "1210252", "position": 1, "expiration": 7}))
			== ("有期限的变身卡无法交换特性属性" if 特殊 else "有期限的变身卡无法交换属性"),
			"expiration>0 ⇒ 分模式那句（:1889-1892）")
	if 特殊:
		_记(String(互换.放入(态, "卡格A", {"id": "1210252", "position": 1, "reforge_time": 3})) == "",
				"特殊版**不查** reforgeTime（:1895 `!_swapSpecialMode` 才判）⇒ 收下")
		互换.取出(态, "卡格A")
	else:
		_记(String(互换.放入(态, "卡格A", {"id": "1210252", "position": 1, "reforge_time": 3}))
				== "此变身卡已交换过属性，无法再次交换", "普通版 reforgeTime>0 ⇒ 那句（:1895-1898）")
	_记(String(互换.放入(态, "卡格A", {"id": "1210252", "position": 1})) == "", "合法卡 ⇒ 收下")
	_记(页.get_node("卡格A/卡格A_格/卡格A_名").visible == false,
			"收下后 nameField 藏掉（`SimpleItemCell` 有 itemData 就不显名字）")
	# `showSwapCardIcon`（:1732-1767）：容器里**两件** —— 角色立绘（`CharacterSprite`@(65,120)）
	# 与名字（`MGlowLabel` 橙 130×20 center @(0,135)）。2026-10-13 §3.142 才把立绘补上，
	# 此前只有名字 ⇒ 断言从"只有一枚"改成"两件各在"。
	var 立绘容 := 页.get_node("立绘A")
	var 有兽 := false
	var 兽高 := 0.0
	var 卡名 := ""
	for 子 in 立绘容.get_children():
		if 子 is OriginalSprite:
			有兽 = true
			兽高 = (子 as OriginalSprite).当前贴图高度()
		elif 子 is Label:
			卡名 = (子 as Label).text
	_记(卡名 == 游戏数据().item_name("1210252"),
			"立绘容器里摆卡名（:1759-1766，MGlowLabel 橙 130×20 center @(0,135)），实测「%s」" % 卡名)
	_记(有兽, "立绘容器里该有**角色精灵**（§3.142：`装备库.外观` 当 `face` 交给 `原始动画精灵`）")
	_记(兽高 > 0.0, "角色精灵该**真加载出帧**（`configure` 成功≠画得出；实测站姿高 %.1f）" % 兽高)

	# —— 交换演出（§3.143）：遮罩 / 程序化特效层 / 进度条 / `Timer(33,60)` ——
	# ⚠️ 闪电用 `randf()` ⇒ **逐像素不可验**，这里只钉**结构 + 按进度走**（步进直接调帧函数，
	#    不依赖真实计时器的抖动）。
	互换.开始交换演出(态)
	await process_frame
	var 遮 := 页.get_node("动画遮罩") as Control
	var 效 := 页.get_node("特效层") as Control
	var 计 := 页.get_node_or_null("交换演出计时") as Timer
	_记(遮.visible, "演出开始 ⇒ 动画遮罩该显形（原版 `_swapMaskLayer`）")
	_记(效.get_script() == load("res://脚本/界面/组件/交换特效.gd"), "特效层该挂上程序化闪电脚本")
	_记(计 != null and not 计.is_stopped(), "该起一枚 `Timer`（原版 `Timer(33,60)`）")
	_记(not (页.get_node("确认钮") as Button).visible, "演出期间确认钮该藏（原版 `:1983-1986`）")
	var 条 := 页.get_node_or_null("通用进度条") as Control
	_记(条 != null and is_equal_approx(条.position.x, 120.0), "进度条该摆在 AS3 (120, param1-30) 换算来的位置")
	# 走到一半
	for _i in range(30):
		互换.演出一帧(态)
	_记(is_equal_approx(float(效.get("进度")), 0.5), "第 30/60 帧 ⇒ 特效进度该是 0.5，实测 %s" % str(效.get("进度")))
	# ⚠️ 先判空再取 —— 进度条没建出来时 `条.get(...)` 会**空指针崩而不红**（§3.137 那形状）。
	var 裁 := (条.get("裁窗") as Control) if 条 != null else null
	_记(裁 != null and is_equal_approx(裁.size.x, 20.0 + 140.0 * 0.5),
			"进度条裁窗该长到 20+140*50%%=90，实测 %s" % (("%.1f" % 裁.size.x) if 裁 != null else "（没进度条）"))
	# 走完
	for _i in range(30):
		互换.演出一帧(态)
	await process_frame
	_记(not (页.get_node("动画遮罩") as Control).visible, "演出收尾 ⇒ 遮罩该收掉")
	_记((页.get_node("确认钮") as Button).visible, "演出收尾 ⇒ 确认钮该回来")
	_记(页.get_node_or_null("交换演出计时") == null, "演出收尾 ⇒ 计时器该回收")
	_记(String(互换.放入(态, "卡格B", {"id": "1210253", "position": 1})) == "不能放入相同的变身卡",
			"与另一格同 position ⇒ 那句（:1900-1903）")
	# 原版 `UIMain2.as:580 setDOShow2(_itemFrame, true)` + `:694-697` 的摆位 ⇒ 这扇**连着背包开**
	_记(管._窗口们.get("背包") != null, "开互换窗要连背包一起开（原版 :580 显式开 _itemFrame）")

	# —— 从背包装入（§3.140 接）：两枚卡格挂了落点件 + 真拖放路径走通 ——
	var 放入件 := load("res://脚本/界面/组件/变身卡放入格.gd")
	_记(页.get_node("卡格A/卡格A_格").get_script() == 放入件, "卡格A 的格没挂落点件（§3.140）")
	_记(页.get_node("卡格B/卡格B_格").get_script() == 放入件, "卡格B 的格没挂落点件（§3.140）")
	_记(放入件.可收("1210252") and 放入件.可收("01210252"),
			"121 段该收（七位 1210252 / 八位 01210252 两种写法都要认）")
	_记(not 放入件.可收("16000110") and not 放入件.可收("12100050"),
			"非 121 段不该收（16000110 与 12100050「写轮眼卡」那种）")
	# 真拖放：把背包里那张卡拖到卡格B（走 `_can_drop_data`/`_drop_data`，不是直接调 `放入`）
	var 会 = 窗._session
	var 背包快照: Array = (会.inventory as Array).duplicate(true)
	会.inventory.clear()
	会.inventory.append({"id": "1210253", "name": "变身卡", "quantity": 1, "slot_index": 1})
	await process_frame
	互换.取出(态, "卡格A")
	互换.取出(态, "卡格B")
	var 源 := 假来源格.new()
	源.槽位号 = 1
	var 载荷 := {"归属": "背包", "物品id": "1210253", "来源格": 源}
	var 格B := 页.get_node("卡格B/卡格B_格") as Control
	_记(bool(格B.call("_can_drop_data", Vector2.ZERO, 载荷)), "卡格B 该接受 121 段拖来的卡")
	_记(not bool(格B.call("_can_drop_data", Vector2.ZERO,
			{"归属": "背包", "物品id": "16000110", "来源格": 源})), "卡格B 不该接受非 121 段")
	格B.call("_drop_data", Vector2.ZERO, 载荷)
	await process_frame
	_记(not (态["B"] as Dictionary).is_empty(), "拖放后 B 格该收下那件卡（落料 → 放入）")
	_记(页.get_node("卡格B/卡格B_格/卡格B_名").visible == false, "拖放后 B 格的 nameField 该藏掉")
	会.inventory.assign(背包快照)
	var 主盒: Rect2 = (窗.get_node("遮罩/主窗口") as Control).get_global_rect()
	var 包盒: Rect2 = (管._窗口们.get("背包") as Node).get_node("遮罩/主窗口").get_global_rect()
	# 原版 `:3170-3171` 是「主窗按自己高度居中、伙伴 y = 主.y」。2026-10-31 起背包 556 高
	# （10 行一屏全露）⇒ 跟着这扇（395/495）居中会垂出下沿，所以背包单独夹进屏内
	# （y = 560-556 = 4），**顶边不再平齐**（有意偏离，见 `窗口管理.成对摆位`）。
	# 期望值写死：主窗 82 / 32，背包 4。
	var 主应 := floorf((560.0 - (495.0 if 特殊 else 395.0)) * 0.5)
	_记(absf(主盒.position.y - 主应) <= 0.6,
			"主窗按自己高度居中（(560-%d)/2 = %.0f），实测 %.1f"
			% [495 if 特殊 else 395, 主应, 主盒.position.y])
	_记(absf(包盒.position.y - 4.0) <= 0.6 and 包盒.end.y <= 560.5,
			"背包（556 高）夹到屏内 y = 4、底 %.1f 不出屏，实测 y %.1f"
			% [包盒.end.y, 包盒.position.y])
	_记(absf(包盒.position.x - (主盒.end.x + 1.0)) <= 6.0,
			"背包贴在主窗右侧（:696 x = 窗.x + 420 + 10；工程口径是 +1）：%.1f vs %.1f"
			% [包盒.position.x, 主盒.end.x + 1.0])
	窗._show_hint("")
	await _点(钮.get_global_rect().get_center())
	var 命中 := 窗.get_viewport().gui_get_hovered_control()
	if 窗._status.text == "":
		# 2026-10-04 这条一度只是"如实记没量到"：当时 `窗口管理.重排层级` 给每扇窗的局部层是
		# 1..N，而 GUI 拾取比的就是这个数（聊天/技能面板是 100）⇒ 窗**画**在底栏之上、命中却被底栏吃掉。
		# 2026-10-06 已就地修（改成 `HUD基 110 + i + 1`），实测这两次真点都落到了件上
		# ⇒ 于是这里从"记一条没量到"**升成硬判据**：再为空就是层序又被人改回去 / 有别的东西挡住点击。
		_记(false, "确认钮 (%.0f,%.0f) 真点下去**状态行还是空** ⇒ 命中通路被挡（层序回归？实命中 %s）"
				% [钮.get_global_rect().get_center().x, 钮.get_global_rect().get_center().y, str(命中)])
	互换.点确认(态)		# 兜住分支文案那一条（真点成了也会再走一次同一条分支，无副作用）
	_记(窗._status.text == "请放入两张变身卡" or 窗._status.text.find("材料不足") >= 0
			or 窗._status.text.find("未接") >= 0,
			"点确认必落那三支之一（:1954-1965），实测 %s" % 窗._status.text)
	if 特殊:
		# 特性栏的真源是**帧里那四段**（原版 `CocoEquip.decode` 的 `specialAttrList / specialLevel /
		# specialEffectType / afterimageFlag`，文本桥在装备段尾部补、客户端解析成
		# `special_attributes / special_level / special_effect_type / afterimage_flag`）。
		# ⚠️ 2026-10-13 修：这条断言原来喂的是 `special_attrs / special_effect / afterimage`
		#   —— **三个全工程没人写的键**，于是把"有特性的卡也显示「无特性属性」"钉成了期望；
		#   而且逐条要**按类型号查表**印名字（原版 `getSwapAttrName:721-729`），
		#   原来读 `name/type/value` ⇒ 真给了数据也会印成「属性0：+0」。
		互换.取出(态, "卡格B")
		互换.放入(态, "卡格B", {"id": "1210253", "position": 2,
			"special_attributes": [{"attribute_type": 4, "attribute_value": 5},
					{"attribute_type": 5, "attribute_value": 3}],
			"special_effect_type": 1, "afterimage_flag": 0})
		var 串 := String(互换.特性文案(态["B"]))
		_记(串.find("[color=#ffffff]攻击：[/color][color=#00ff00]+5%") >= 0
				and 串.find("[color=#ffffff]防御：[/color][color=#00ff00]+3%") >= 0
				and 串.find("传说特性：") >= 0 and 串.find("攻击时回复自身2%血量") >= 0,
				"特性文案 = 逐条按类型号查表 + 传说特性橙（:762-780），实测 %s" % 串)
		_记(_文(页.get_node("特性B")) == 串, "文本框跟着刷（编辑器=运行期同一条文案）")
		# 另外两态：有卡没特性 ⇒ 「无特性属性」；没卡 ⇒ 灰字提示（`:717`/`:760`）
		互换.取出(态, "卡格B")
		互换.放入(态, "卡格B", {"id": "1210253", "position": 2})
		_记(String(互换.特性文案(态["B"])) == "[color=#ffffff]无特性属性[/color]",
				"有卡但没特性 ⇒ 「无特性属性」（:760），实测「%s」" % 互换.特性文案(态["B"]))
		互换.取出(态, "卡格B")
		_记(_文(页.get_node("特性B")) == "[color=#999999]放入变身卡后显示特性属性[/color]",
				"取出 ⇒ 回灰字提示（:717），实测「%s」" % _文(页.get_node("特性B")))
	互换.取出(态, "卡格A")
	_记(页.get_node("卡格A/卡格A_格/卡格A_名").visible == true, "取出后「放入」回来了（:1847）")


func 游戏数据() -> Object:
	return load("res://脚本/单例/游戏数据.gd")


func 收尾(致命: String) -> void:
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	for 一 in 日志:
		print(一)
	print("伊鲁卡三窗回归：%s（红 %d 项）" % ["通过" if 红数 == 0 else "不通过", 红数])
	quit(1 if 红数 > 0 else 0)
