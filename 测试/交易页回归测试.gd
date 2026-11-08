extends SceneTree
## 交易族（原版 `TradeWindow2` + `CuePane/CueManage/CueGird` + `MDialog`）离线门。
## 逐件参照值手抄自 `真值/窗口/交易与邀请托盘.md` §①②③④⑤⑥⑦⑧⑨（AS3 行号都在那），
## **不从被测场景反查** —— 从场景反查 = 场景写错它也跟着错，那道门等于没判。
##
## 覆盖：① 下行帧逐条喂**真后端解析入口**（串由 `开发工具/出交易夹具.py` 反查服务端源码生成）
## ② 槽位语义（`0 = 我这侧 / 1 = 对方`，四条 setter 都验）③ 未知子命令 / 段数不够 ⇒ 状态不动
## ④ `335:3` 只加托盘格、**不开窗**；`335:22` 才开窗 ⑤ 交易窗逐件矩形 + 层序
## ⑥ 格内三件矩形与"空/有物"两态 ⑦ 宠物格两张图互斥 + 资质名 + 查看钮显隐
## ⑧ 金额四格带千分位、`335:9/8` 后归零 ⑨ 遮罩与「交易」钮的 enable 状态机
## ⑩ 托盘：首格 380、每格 −40、同类同 id 去重、师徒两类**不去重**（原版 switch 里没它们）、满 10 挡
## ⑪ 点格 ⇒ MDialog 确认弹逐件矩形（302×87、钮 77/186）+ 确定发 `119:4` / 取消发 `119:3`
## ⑫ 点「锁定」发 `119:9` 且只点亮自己那半、点「交易」发 `119:16`、点「取消」发 `119:10`
## ⑬ 拖背包 ⇒ `119:14:<背包槽>:<交易槽>`；绑过的 ⇒ 只出提示不发帧；落点已有物 ⇒ 不发帧
## ⑭ 上架模式下点背包 ⇒ 客户端算出空格号（不是原版那个会被服务端丢掉的 0）
## ⑮ 「输入金币/元宝」开金额子窗（交易档文案 + 币图换档 + 千分位）
## ⑯ 尺寸表一条 + `伴随背包` 里有「交易」+ 成交/取消两条把窗关掉。
##
## 跑法：`"godot" --path . --headless --script res://测试/交易页回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 夹具路径 := "res://数据/界面/交易夹具.json"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 交易窗 := preload("res://脚本/界面/窗口/交易/交易窗.gd")
const 托盘脚本 := preload("res://脚本/界面/邀请托盘.gd")
const 后端脚本 := preload("res://脚本/单例/后端连接.gd")
## ⚠ 量具里造"来源格"必须用**同一个格子脚本**（`格子归属`/`槽位号`/`物品id`
## 是 `可拖拽格.gd` 上的成员）：拿裸 `Button.new()` 去 `.set()` 会报"Invalid access to property"，
## 于是三条拖放判据全部假红——看着像页面的闸坏了，其实是夹具做的对象不对。
const 物品格脚本 := preload("res://脚本/界面/组件/物品格.gd")
## ⚠ 常量**不在属性表里** ⇒ `管理.get("伴随背包")` 拿到 null。要读常量只能通过
## preload 到的那份脚本访问，不能走实例 `get()`（这一条踩过一次假绿）。
const 管理脚本 := preload("res://脚本/界面/窗口管理.gd")

## §① 交易窗逐件（页局部 = AS3 − 29）
const 窗件 := {
	"内容底": [6.0, 10.0, 309.0, 412.0],		# `:478-483`（宽 = 321−12）
	"对方物品底": [11.0, 49.0, 147.0, 223.0],	# `:484-489`
	"我的物品底": [163.0, 49.0, 147.0, 223.0],	# `:490-495`
	"对方宠物底": [11.0, 276.0, 147.0, 48.0],	# `:496-501`
	"我的宠物底": [163.0, 276.0, 147.0, 48.0],	# `:502-507`
	"对方金币底": [51.0, 328.0, 101.0, 21.0],	# `:508-513`
	"对方元宝底": [51.0, 354.0, 101.0, 21.0],	# `:514-519`
	"我的金币底": [201.0, 328.0, 101.0, 21.0],	# `:520-525`
	"我的元宝底": [201.0, 354.0, 101.0, 21.0],	# `:526-531`
	"对方金币图": [54.0, 330.0, 17.0, 17.0],	# `:532-535`
	"我的元宝图": [204.0, 358.0, 19.0, 13.0],	# `:536-539`（入栈顺序就是 金币→我的元宝→我的金币→对方元宝）
	"我的金币图": [204.0, 330.0, 17.0, 17.0],	# `:540-543`
	"对方元宝图": [54.0, 358.0, 19.0, 13.0],	# `:544-547`
	"物品上架钮": [237.0, 23.0, 61.0, 22.0],	# `:364-365`
	"输入金币钮": [184.0, 378.0, 61.0, 22.0],	# `:366-367`
	"输入元宝钮": [245.0, 378.0, 61.0, 22.0],	# `:368-369`
	"宠物列表钮": [8.0, 426.0, 61.0, 22.0],		# `:370-371`
	"锁定物品钮": [74.0, 426.0, 61.0, 22.0],	# `:372-373`
	"交易钮": [235.0, 426.0, 37.0, 22.0],		# `:374-375`
	"取消钮": [277.0, 426.0, 37.0, 22.0],		# `:376-377`
	"对方名": [11.0, 11.0, 146.0, 18.0],		# `:173-174`（setLabel 里那个 −2）
	"我的物品": [163.0, 11.0, 73.0, 18.0],		# `:171-172`
	"对方金币标签": [14.0, 329.0, 41.0, 18.0],	# `:175-176`
	"对方元宝标签": [14.0, 353.0, 41.0, 18.0],	# `:177-178`
	"我的金币标签": [164.0, 329.0, 41.0, 18.0],	# `:179-180`
	"我的元宝标签": [164.0, 353.0, 41.0, 18.0],	# `:181-182`
	"对方金币值": [73.0, 329.0, 76.0, 18.0],	# `:183-184`
	"对方元宝值": [73.0, 355.0, 76.0, 18.0],	# `:185-186`
	"我的金币值": [223.0, 329.0, 76.0, 18.0],	# `:187-188`
	"我的元宝值": [223.0, 355.0, 76.0, 18.0],	# `:189-190`
	"提示": [11.0, 402.0, 299.0, 18.0],		# `:191-192`（宽 = background2.width − 10 = 299）
	"对方遮罩": [7.0, 10.0, 151.0, 408.0],		# `:193-199`
	"我的遮罩": [163.0, 10.0, 151.0, 408.0],	# `:200-206`
}
const 线y := [95.0, 138.0, 181.0, 224.0]	# `:548-563`（y = 格 y + 41）
## §② 交易格内三件（格内局部坐标；数量挂在格底下，见 `交易格.gd` 顶上那段注释）
const 格内件 := {"格": [0.0, 0.0, 40.0, 40.0], "数量": [0.0, 22.0, 30.0, 18.0],
				"名字": [44.0, 11.0, 97.0, 18.0]}
## §③ 宠物格内四件
const 宠内件 := {"有宠图": [0.0, 0.0, 44.0, 44.0], "空宠图": [0.0, 0.0, 44.0, 44.0],
				"名字": [44.0, 4.0, 97.0, 18.0], "查看钮": [95.0, 20.0, 30.0, 22.0]}
## §⑨ 确认弹逐件（单行：panelHeight = 72 + 15×1 = 87）
const 弹件 := {"底": [0.0, 0.0, 302.0, 87.0], "内容底": [6.0, 6.0, 283.0, 37.0],
				"正文": [14.0, 14.0, 267.0, 23.0], "确定钮": [77.0, 52.0, 30.0, 22.0],
				"取消钮": [186.0, 52.0, 30.0, 22.0]}
## §⑧ 托盘：盒 800×50 @(80,100)；格 40×40；首格 380、步距 −40、入场起点 x=10
const 托盘框 := [80.0, 100.0, 800.0, 50.0]
const 未登记类型 := 7	# `CueGird.TYPE_EQUIPMENT_REPAIR`（装备修复）—— 图标表里没有它 ⇒ 加不进托盘
## ⚠ 别拿 5（家族邀请）/ 6（家族申请）当反例：1552:16 / 1552:8 服务端真发，托盘也都登记了图标。
## §① 页根下前 21 件的入栈顺序（AS3 `newBackground()` 的 addChild 序）
const 底层序 := ["内容底", "对方物品底", "我的物品底", "对方宠物底", "我的宠物底",
				"对方金币底", "对方元宝底", "我的金币底", "我的元宝底",
				"对方金币图", "我的元宝图", "我的金币图", "对方元宝图",
				"对方线1", "对方线2", "对方线3", "对方线4",
				"我的线1", "我的线2", "我的线3", "我的线4"]

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 夹: Dictionary = {}
var 窗交易: Node = null


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _结(名: String) -> void:
	跑完了 = true
	print("%s：通过 %d，红 %d" % [名, 通过, 失败])


## JSON 在 Windows 上可能被存成带 BOM 的 UTF-8，`JSON.parse_string` 见 BOM 整份失败
## （同 `随身摊位窗回归测试.gd:518`）。
static func 去BOM(文: String) -> String:
	return 文.replace("\ufeff", "")


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
		_结("交易页离线门")
	quit(1 if 失败 > 0 else 0)


func _矩形(件: Control) -> Array:
	return [件.offset_left, 件.offset_top,
			件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


## 页上取件。⚠ 返回类型故意留**空**（不写 `as Control`）：交易格/宠物格那些脚本上
## 有自定义成员（`名字`/`格`/`是空的()`），声明成 Control 之后 GDScript 按 Control 的接口判、
## 编译期就报"找不到成员"。这里要的是鸭子类型，不是静态类型。
func _件(父: Node, 路径: String):
	return 父.get_node(路径)


func _标(父: Node, 路径: String) -> Label:
	return 父.get_node(路径) as Label


## ⚠ **每取一次现算一次**：`功能窗口._render_page()` 是把 `_content` 的子件先摘掉再派发
## 的，所以每一帧回帧之后手里那个 `页` 就成了"即将 free 的旧页"——
## 攥着它继续断言 = 下一句就是"已释放对象"、整道门半路死（实测一次红换成一片红）。
func 页现取() -> Control:
	return _找页(窗交易, "原版交易内容")


func _找页(窗: Node, 名: String) -> Control:
	var 内容 = 窗.get("_content")
	if 内容 == null:
		return null
	for 子 in (内容 as Control).get_children():
		if String(子.name) == 名:
			return 子 as Control
	return null


## 喂一条原文给**真后端**（解析那半边永远走真代码，假后端只接管出帧）。
func _喂(原文: String) -> void:
	root.get_node("BackendConnection").call("_handle_bridge_text", 原文)


## 真鼠标点一下某个件。**无头门三条硬口径**（工程里实测过，缺一条就"点了静默没反应"）：
## ① 先钉 `root.size`；② 点击之前先发一次 `InputEventMouseMotion`；
## ③ `position` 与 `global_position` 都要写、按下还要带 `button_mask`。
## 坐标必须是**屏幕坐标** ⇒ 走 `get_global_rect()`。
func _点后(件: Control) -> void:
	var 屏: Vector2 = 件.get_global_rect().position + Vector2(
			min(10.0, 件.size.x * 0.5), min(10.0, 件.size.y * 0.5))
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	root.push_input(移)
	await process_frame
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	root.push_input(按)
	await process_frame
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	root.push_input(放)
	await process_frame
	await process_frame
	await process_frame


## 假后端：**只接管出帧那半边**。字段名与真后端同名 ⇒ 页面里 `后.get("…")` 照原样读得到。
## ⚠ 不要在这里覆写 `get()`（Godot 会当成覆写 `Object.get` ⇒ 整个脚本 parse 失败）。
class 假后 extends Node:
	var character_id := 1001
	var authoritative_trade: Dictionary = {}
	var authoritative_stats := {"money": 250000, "cash": 80}
	## ⚠ 这里**不能**写成 `Array[Dictionary]`：门里赋的是普通 Array，
	## 类型化数组赋值会被静默丢掉（工程里那条"类型化数组 set() 静默丢"的同一个坑），
	## 报错反而是在下一句才现形。真后端那侧读的也只是 `.get(...)` 出来的数组。
	var authoritative_inventory: Array = []
	var 发过: Array = []

	func _记(话: String) -> bool:
		发过.append(话)
		return true

	func request_trade_accept(号: int) -> bool:
		return _记("119:4:%d" % 号)

	func request_trade_decline(号: int) -> bool:
		return _记("119:3:%d" % 号)

	func request_trade_lock() -> bool:
		return _记("119:9")

	func request_trade_exit() -> bool:
		return _记("119:10")

	func request_trade_confirm() -> bool:
		return _记("119:16")

	func request_trade_offer_money(数: int) -> bool:
		return _记("119:15:%d" % 数)

	func request_trade_offer_cash(数: int) -> bool:
		return _记("119:13:%d" % 数)

	func request_trade_put_item(背包槽: int, 交易槽: int) -> bool:
		if 背包槽 <= 0 or 交易槽 < 1 or 交易槽 > 5:
			return false
		return _记("119:14:%d:%d" % [背包槽, 交易槽])

	## 与真后端同一套算式（第一个空格 1..5，满则 0）。
	func 交易空格() -> int:
		var 格表: Dictionary = authoritative_trade.get("my_items", {})
		for 槽 in range(1, 6):
			if not 格表.has(槽):
				return 槽
		return 0


func _跑() -> void:
	print("交易页离线门开始")
	await process_frame
	夹 = JSON.parse_string(去BOM(FileAccess.get_file_as_string(夹具路径))) as Dictionary
	_判(夹 != null and not 夹.is_empty(),
			"夹具读得到（先跑 `python 开发工具/出交易夹具.py`，它自带服务端段序反查）")
	if 夹 == null or 夹.is_empty():
		_结("交易页离线门")
		return
	root.size = Vector2i(960, 560)		# ⚠ 不钉视口，无头 push_input 拿不到 GUI 命中
	var 后 = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("authoritative_trade", 后端脚本._空交易状态())
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame

	var 原: Dictionary = 夹["原文"] as Dictionary
	var 他号 := int(夹["他号"])
	var 他名 := String(夹["他名"])
	var 盘 = 管理.get_node("邀请托盘")
	var 弹 = 管理.get_node("模态确认弹层/模态确认弹")

	# ── A. 邀请：只加托盘格，不开窗 ─────────────────────────────────
	_喂(String(原["邀请"]))
	_判(盘.数量() == 1, "`335:3` 让托盘多了一格（实得 %d）" % 盘.数量())
	var 第一格 = 盘.最后一格()
	_判(第一格 != null and int(第一格.数据.get("id", 0)) == 他号,
			"那一格带的就是这条邀请的 {id,name}（实得 %s）" % 第一格.数据)
	窗交易 = 管理.call("取窗口", "交易") as Node
	_判(窗交易 == null or not bool(窗交易.call("已打开")),
			"只收到邀请时**交易窗不该开**（原版 `Client.as:6391-6398` 只 addMsg）")

	# ── B. 成交开始：`335:22` ⇒ 开窗 ────────────────────────────────
	_喂(String(原["开始"]))
	窗交易 = 管理.call("取窗口", "交易") as Node
	if 窗交易 == null:
		_判(false, "`335:22` 没把交易窗开出来 ⇒ 后面的判据无从跑起")
		_结("交易页离线门")
		return
	for i in 3:
		await process_frame
	var 页 := _找页(窗交易, "原版交易内容")
	if 页 == null:
		_判(false, "交易窗开出来了但**页没建出来**（`原版交易内容`）")
		_结("交易页离线门")
		return
	_判(true, "`335:22` ⇒ 页建出来了")
	_判(_标(页现取(), "对方名").text == 他名, "对方名 = 帧里另一侧的名字（实得「%s」）" % _标(页现取(), "对方名").text)

	# ── C. 逐件矩形 + 层序 ────────────────────────────────────────
	for 名 in 窗件:
		var 实 := _矩形(_件(页现取(), 名) as Control)
		_判(_近(实, 窗件[名]), "%s 框 = %s（实得 %s）" % [名, 窗件[名], 实])
	for i in 4:
		for 侧 in ["对方", "我的"]:
			var 名 := "%s线%d" % [侧, i + 1]
			var 期 := [(14.0 if 侧 == "对方" else 167.0), 线y[i], 132.0, 2.0]
			var 实 := _矩形(_件(页现取(), 名) as Control)
			_判(_近(实, 期), "%s 框 = %s（实得 %s）" % [名, 期, 实])
	for i in 5:
		for 侧 in ["对方", "我的"]:
			var 名 := "%s格%d" % [侧, i + 1]
			var 期 := [(17.0 if 侧 == "对方" else 166.0), 54.0 + 43.0 * float(i), 141.0, 40.0]
			var 实 := _矩形(_件(页现取(), 名) as Control)
			_判(_近(实, 期), "%s 框 = %s（实得 %s）" % [名, 期, 实])
	_判(_近(_矩形(_件(页现取(), "对方宠物格") as Control), [14.0, 278.0, 141.0, 44.0]),
			"对方宠物格 @(14,278) 141×44（实得 %s）" % str(_矩形(_件(页现取(), "对方宠物格") as Control)))
	_判(_近(_矩形(_件(页现取(), "我的宠物格") as Control), [166.0, 278.0, 141.0, 44.0]),
			"我的宠物格 @(166,278)（实得 %s）" % str(_矩形(_件(页现取(), "我的宠物格") as Control)))
	var 子名: Array = []
	for 子 in 页现取().get_children():
		子名.append(String(子.name))
	_判(子名.slice(0, 底层序.size()) == 底层序,
			"页根下前 %d 件的入栈顺序照 AS3 addChild（实得 %s）" % [底层序.size(), 子名.slice(0, 底层序.size())])
	_判(子名.find("我的遮罩") > 子名.find("交易钮") and 子名.find("对方遮罩") > 子名.find("提示"),
			"两块红遮罩是**最后**入栈的（盖在钮与文字之上）")
	_判(int(页现取().size.x) == 321 and int(页现取().size.y) == 454,
			"页根 = 321×454（483 − 29）（实得 %s）" % str(页现取().size))

	# ── D. 格内三件 + 空/有物两态 ─────────────────────────────────
	var 样格 = _件(页现取(), "我的格3")
	var 内路 := {"格": "格", "数量": "格/数量", "名字": "名字"}
	for 名 in 格内件:
		var 实 := _矩形(_件(样格, 内路[名]) as Control)
		_判(_近(实, 格内件[名]), "格内 %s 框 = %s（实得 %s）" % [名, 格内件[名], 实])
	_判(样格.是空的(), "开局十格全空（`removeData` 的空态）")
	_喂(String(原["我方放物"]))
	_喂(String(原["对方放物"]))
	for i in 2:
		await process_frame
	var 态: Dictionary = 后.get("authoritative_trade") as Dictionary
	var 放了: Dictionary = 态["my_items"] as Dictionary
	_判(放了.has(2) and not 放了.has(3),
			"`335:5:0:负载` 的**负载第 3 段 = 交易槽** ⇒ 落第 2 格（实得键 %s）" % str(放了.keys()))
	var 我的2 = _件(页现取(), "我的格2")
	_判(not 我的2.是空的(), "第 2 格画上了东西")
	_判(我的2.名字.text == "熊皮", "格内名字 = 负载解出来的物品名（实得「%s」）" % 我的2.名字.text)
	_判(我的2.数量.text == "5", "数量 5 ⇒ 角标写字（`count > 1` 才写）")
	_判(_件(页现取(), "对方格3").名字.text == "裂开的蛇皮",
			"`335:5:1:` 落在**对方**那侧第 3 格（实得「%s」）" % _件(页现取(), "对方格3").名字.text)
	_判(_件(页现取(), "我的格2").格.icon != null, "格里有图标贴图（`PicTool.getItemPic` 的等价物）")
	_喂(String(原["我方取回"]))
	for i in 2:
		await process_frame
	态 = 后.get("authoritative_trade") as Dictionary
	_判(not (态["my_items"] as Dictionary).has(2), "`335:21` 把那格解掉了")
	_判(_件(页现取(), "我的格2").是空的(), "格清回去是**真空**（图标/名字/数量都没了）")

	# ── E. 金额四格（千分位）+ 槽位语义 ────────────────────────────
	for 名 in ["我方金币", "对方金币", "我方元宝", "对方元宝"]:
		_喂(String(原[名]))
	for i in 2:
		await process_frame
	态 = 后.get("authoritative_trade") as Dictionary
	_判(int(态["my_money"]) == 200000 and int(态["other_money"]) == 1500,
			"金币按槽分边（my=%s other=%s）" % [态["my_money"], 态["other_money"]])
	_判(int(态["my_cash"]) == 30 and int(态["other_cash"]) == 5,
			"元宝按槽分边（my=%s other=%s）" % [态["my_cash"], 态["other_cash"]])
	_判(_标(页现取(), "我的金币值").text == "200,000",
			"金币值过千带千分位（`formatNumber`，实得「%s」）" % _标(页现取(), "我的金币值").text)
	_判(_标(页现取(), "对方元宝值").text == "5", "没过千就**不加逗号**（实得「%s」）" % _标(页现取(), "对方元宝值").text)
	# 坏帧出口：段数不够 / 未知子命令 ⇒ 状态一律不动
	var 冻结: Dictionary = (后.get("authoritative_trade") as Dictionary).duplicate(true)
	_喂("335:4:0")
	_喂("335:99:1:2")
	_喂("335:5:0:1&2&3")
	for i in 2:
		await process_frame
	_判(str((后.get("authoritative_trade") as Dictionary)["my_money"]) == str(冻结["my_money"]),
			"少段的 `335:4` 整条丢掉（不许把半条当成 0 写进状态）")
	_判((后.get("authoritative_trade") as Dictionary)["my_items"] == (冻结["my_items"] as Dictionary),
			"未知子命令与解不出来的负载都不改状态")

	# ── F. 宠物格：两图互斥 + 31 段负载解得出 ────────────────────────
	_喂(String(原["我方放宠"]))
	for i in 2:
		await process_frame
	态 = 后.get("authoritative_trade") as Dictionary
	_判(not (态["my_pet"] as Dictionary).is_empty(),
			"31 段的宠物负载解出来了（`_parse_pet_fields` 要 ≥31 段）")
	var 宠格 = _件(页现取(), "我的宠物格")
	_判(_件(宠格, "空宠图").visible == false and _件(宠格, "有宠图").visible,
			"有宠时**隐占位图、显格底**（`:55-56`）")
	_判(_标(宠格, "名字").text == "蜃(卓越)", "宠物名 = `名(资质名)`（实得「%s」）" % _标(宠格, "名字").text)
	_判(_件(宠格, "查看钮").visible, "查看钮只在有宠时露（`:64`）")
	var 宠路 := {"有宠图": "有宠图", "空宠图": "空宠图", "名字": "名字", "查看钮": "查看钮"}
	for 名 in 宠内件:
		var 实 := _矩形(_件(宠格, 宠路[名]) as Control)
		_判(_近(实, 宠内件[名]), "宠物格 %s 框 = %s（实得 %s）" % [名, 宠内件[名], 实])
	_判(_矩形(_件(宠格, "有宠图/头像") as Control) == [2.0, 2.0, 40.0, 40.0],
			"头像 40×40 摆在 44×44 格底正中（PortraitHead 注册点在中心）")
	_喂(String(原["对方放宠"]))
	for i in 2:
		await process_frame
	_判(String(_件(页现取(), "对方宠物格").名字.text).begins_with("蛤龙"), "对方那侧的宠物也按槽分对了")

	# ── G. 遮罩与「交易」钮的状态机 ────────────────────────────────
	_判(_件(页现取(), "我的遮罩").visible == false and _件(页现取(), "对方遮罩").visible == false,
			"两块遮罩初始都是隐的（`:207`）")
	_判((_件(页现取(), "交易钮") as Button).disabled, "交易钮初始 disable（`:170`）")
	var 假 = 假后.new()
	假.authoritative_trade = 后.get("authoritative_trade")
	窗交易.set("_backend", 假)
	await _点后(_件(页现取(), "锁定物品钮") as Control)
	_判(假.发过 == ["119:9"], "点「锁定物品」只发 `119:9`（实发 %s）" % str(假.发过))
	_判(_件(页现取(), "我的遮罩").visible, "自己点了锁定 ⇒ 只点亮自己那半")
	_判(_件(页现取(), "对方遮罩").visible == false, "对方那半要等 `335:7`，不许自己点")
	_判((_件(页现取(), "交易钮") as Button).disabled, "只有一块遮罩亮 ⇒ 交易钮还是 disable")
	_判((_件(页现取(), "物品上架钮") as Button).disabled and (_件(页现取(), "锁定物品钮") as Button).disabled,
			"锁定后 上架/锁定 两颗都 disable（`:446`）")
	_喂(String(原["双方锁定"]))
	for i in 3:
		await process_frame
	_判(_件(页现取(), "对方遮罩").visible, "`335:7` ⇒ 对方那半遮罩显")
	_判((_件(页现取(), "交易钮") as Button).disabled == false, "两块都亮 ⇒ 交易钮 enable（`setTradeBtnEnabled`）")
	假.发过 = []
	await _点后(_件(页现取(), "交易钮") as Control)
	_判(假.发过 == ["119:16"], "点「交易」只发 `119:16`（实发 %s）" % str(假.发过))

	# ── H. 拖背包 ⇒ `119:14` 的三道闸 ────────────────────────────
	假.authoritative_inventory = [
		{"slot_index": 7, "id": "10000001", "name": "熊皮", "quantity": 5, "can_trade": true},
		{"slot_index": 8, "id": "10000009", "name": "绑定的护额", "quantity": 1, "can_trade": false},
	]
	var 目标 = _件(页现取(), "我的格1").格
	_判(目标.格子归属 == "交易" and int(目标.槽位号) == 1,
			"我这侧第 1 格认领了落点（归属=交易、槽=1，实得「%s」%s）" % [目标.格子归属, 目标.槽位号])
	_判(_件(页现取(), "对方格1").格.格子归属 == "",
			"对方那五格**不是**落点（原版只给 myCellArr 挂 MSPRITE_UP）")
	_判(_件(页现取(), "我的格1").格.可拖拽 == false, "交易格只接不吐（原版交易格从不建拖拽代理）")
	var 源 := 物品格脚本.new()
	源.set("格子归属", "背包")
	源.set("槽位号", 7)
	源.set("物品id", "10000001")
	假.发过 = []
	_件(页现取(), "我的格1").落到.emit(1, {"来源格": 源, "目标格": 目标, "物品id": "10000001"})
	for i in 2:
		await process_frame
	_判(假.发过 == ["119:14:7:1"],
			"背包→交易格发 `119:14:<背包槽>:<交易槽>`（实发 %s）" % str(假.发过))
	_喂(String(原["我方放物"]))		# 让第 2 格真的占上（真后端的状态机推一帧，不靠假后端猜）
	for i in 2:
		await process_frame
	页 = _找页(窗交易, "原版交易内容")
	假.authoritative_trade = 后.get("authoritative_trade")
	假.发过 = []
	_件(页现取(), "我的格2").落到.emit(2, {"来源格": 源, "目标格": _件(页现取(), "我的格2").格,
			"物品id": "10000001"})
	for i in 2:
		await process_frame
	_判(假.发过.is_empty(), "落点格已经有东西 ⇒ 不许发帧（原版 `!getCellValue()` 那一闸）")
	var 绑 := 物品格脚本.new()
	绑.set("格子归属", "背包")
	绑.set("槽位号", 8)
	绑.set("物品id", "10000009")
	假.发过 = []
	_件(页现取(), "我的格4").落到.emit(4, {"来源格": 绑, "目标格": null, "物品id": "10000009"})
	for i in 2:
		await process_frame
	_判(假.发过.is_empty(), "绑过的物品 ⇒ 只出提示不发帧（`IS_NOT_ITEM_TRADE`）")
	_判(String(窗交易.get("_status").text).find("不能交易") >= 0,
			"绑定那条要有话说，不许静默（实得「%s」）" % 窗交易.get("_status").text)
	var 外 := 物品格脚本.new()
	外.set("格子归属", "商城")
	外.set("槽位号", 3)
	假.发过 = []
	_件(页现取(), "我的格5").落到.emit(5, {"来源格": 外, "目标格": null, "物品id": "x"})
	for i in 2:
		await process_frame
	_判(假.发过.is_empty(), "来源不是背包 ⇒ 不发帧（`dragSource == ITEM_WINDOW` 那一闸）")

	# ── I. 上架模式点背包 ⇒ 客户端算空格号 ──────────────────────────
	交易窗.上架模式 = true
	假.发过 = []
	var 假态: Dictionary = (后.get("authoritative_trade") as Dictionary).duplicate(true)
	假态["my_items"] = {1: {}, 2: {}}
	假.authoritative_trade = 假态
	var 空格 := int(假.call("交易空格"))
	_判(空格 == 3, "已有 1、2 两格 ⇒ 该发第 3 格（实得 %d）" % 空格)
	假.request_trade_put_item(7, 空格)
	_判(假.发过 == ["119:14:7:3"],
			"上架模式那条点 = `119:14:7:3`，**不是**会被服务端丢掉的 `:0`（实发 %s）" % str(假.发过))
	假态["my_items"] = {1: {}, 2: {}, 3: {}, 4: {}, 5: {}}
	_判(int(假.call("交易空格")) == 0, "五格全满 ⇒ 算不出空格（上层据此给提示、不发帧）")
	交易窗.上架模式 = false

	# ── J. 输入金币/元宝 ⇒ 金额子窗（交易档）───────────────────────
	假.authoritative_trade = 后.get("authoritative_trade")
	假.发过 = []
	await _点后(_件(页现取(), "输入金币钮") as Control)
	var 额窗 := _件(页现取(), "交易金额窗") as Control
	_判(额窗.visible, "点「输入金币」把金额子窗开出来了")
	_判(_标(额窗, "标题").text == "交易金币", "标题 = TRADK_MONEY_TITLE（实得「%s」）" % _标(额窗, "标题").text)
	_判(_标(额窗, "下标签").text == "你希望交易多少金币?",
			"下标签原文带半角问号（实得「%s」）" % _标(额窗, "下标签").text)
	_判(_件(额窗, "金币图标").position.y == 59.0, "金币档的币图 y = 59（`setPng`）")
	_判(String((_件(额窗, "金币图标") as TextureRect).texture.resource_path).ends_with("金币.png"),
			"金币档用的是 `金币.png`")
	_判(_标(额窗, "持有金额").text == "250,000",
			"持有金额过千带逗号（实得「%s」）" % _标(额窗, "持有金额").text)
	(_额窗数量(额窗)).text = "1200"
	额窗.call("_确定")
	for i in 2:
		await process_frame
	_判(假.发过 == ["119:15:1200"], "金额子窗回来 ⇒ `119:15:<数>`（实发 %s）" % str(假.发过))
	_判(额窗.visible == false, "发完子窗自己关")
	假.发过 = []
	await _点后(_件(页现取(), "输入元宝钮") as Control)
	_判(_标(额窗, "标题").text == "交易元宝", "元宝档标题换对了")
	_判(_件(额窗, "金币图标").position.y == 61.0, "元宝档的币图 y = **61**（不是 59）")
	_判(String((_件(额窗, "金币图标") as TextureRect).texture.resource_path).ends_with("元宝币.png"),
			"元宝档换的是 `元宝币.png`（19×13 那张）")
	(_额窗数量(额窗)).text = "12"
	额窗.call("_确定")
	for i in 2:
		await process_frame
	_判(假.发过 == ["119:13:12"], "元宝档回来 ⇒ `119:13:<数>`（实发 %s）" % str(假.发过))

	# ── K. 托盘：排队 / 去重 / 上限 / 点格弹确认弹 ──────────────────
	_判(_件(管理, "邀请托盘").position.x == 80.0 and _件(管理, "邀请托盘").position.y == 100.0,
			"托盘盒 @(80,100) = (STAGE_WIDTH−800)>>1（实得 %s）" % _件(管理, "邀请托盘").position)
	_判(_近(_矩形(盘 as Control), 托盘框), "托盘盒 800×50（实得 %s）" % str(_矩形(盘 as Control)))
	盘.清空()
	_判(盘.数量() == 0 and float(盘.get("_下一x")) == 380.0,
			"清空后下一格回到 380（`delMsg` 里空表那条）")
	var 甲: Control = 盘.加消息(托盘脚本.类型交易, {"id": 111, "name": "甲"})
	_判(甲 != null and float(甲.position.x) == 10.0 and 甲.modulate.a < 0.05,
			"新格入场从 x=10、alpha=0 起补间（实得 x=%s a=%s）" % [甲.position.x, 甲.modulate.a])
	_判(float(盘.get("_下一x")) == 340.0, "下一格的 x 每来一格减 40（实得 %s）" % 盘.get("_下一x"))
	_判(盘.加消息(托盘脚本.类型交易, {"id": 111, "name": "甲"}) == null,
			"同类同 id **不加第二格**（`checkExist` 的 TYPE_TRADE 分支）")
	盘.加消息(托盘脚本.类型交易, {"id": 222, "name": "乙"})
	_判(盘.数量() == 2, "换了个人就再加一格")
	盘.加消息(托盘脚本.类型推荐徒弟, {"id": 777})
	盘.加消息(托盘脚本.类型推荐徒弟, {"id": 777})
	_判(盘.数量() == 4, "师徒两类原版**不在去重表里** ⇒ 同 id 也各算一格（实得 %d）" % 盘.数量())
	_判(盘.加消息(未登记类型, {"id": 1}) == null, "没登记图标的类型一律不进托盘（装备修复服务端没有对应帧）")
	while 盘.数量() < 10:
		盘.加消息(托盘脚本.类型交易, {"id": 9000 + 盘.数量()})
	_判(盘.数量() == 10, "补到 10 格")
	_判(盘.加消息(托盘脚本.类型交易, {"id": 12345}) == null, "第 11 格被挡（`getDicLength() < 10`）")
	盘.清空()
	## ⚠ 注入口要在**弹被打开之前**换好 —— 确认弹的确定/取消回调是 `窗口管理` 在打开那一刻
	## 抓的闭包（`_发帧后端()` 已经求过值了），事后再换 `出帧后端` 追不上这一次。
	管理.set("出帧后端", 假)
	## ⚠ 托盘格的**真鼠标点击**得让交易窗先让开：托盘是 `窗口管理`（CanvasLayer）的
	## **第一个子节点**、功能窗随后入栈 ⇒ 窗一律盖在托盘之上（`真值/窗口/交易与邀请托盘.md:311`；
	## 原版 `UIMain2.as:4292` 也是 cuePane 先入、窗后覆盖）。交易窗左缘若压到格子的
	## 点击点，点击就被窗吃掉、这扇门假红。这一段只测托盘的点击回调，与窗是否可见无关，
	## 所以点前藏、点完放回。
	var 交易原显 := (窗交易 as CanvasLayer).visible
	(窗交易 as CanvasLayer).visible = false
	var 那格: Control = 盘.加消息(托盘脚本.类型交易, {"id": 他号, "name": 他名})
	await _点后(那格 as Control)
	_判(弹.visible, "点格 ⇒ 弹 MDialog 确认弹")
	_判(盘.数量() == 0, "点完那格**自删**（`onClickHand` 的 destroy + delMsg）")
	for 名 in 弹件:
		var 实 := _矩形(_件(弹, "主体/" + 名) as Control)
		_判(_近(实, 弹件[名]), "确认弹 %s 框 = %s（实得 %s）" % [名, 弹件[名], 实])
	_判(String(_件(弹, "主体/正文").text).find("请求与你交易！") > 0,
			"正文 = TRADE_USER_INFO_BTN_TRADE_INVITE 换名后的原文（实得「%s」）" % _件(弹, "主体/正文").text)
	_判((_件(弹, "主体/确定钮") as Button).text == "确定"
			and (_件(弹, "主体/取消钮") as Button).text == "取消",
			"两颗钮的文字 = COMMON_OK / COMMON_CANCEL")
	## 三档皮 + 字色 + 手型**烘在 `.tscn` 的 `theme_override_*`**（`UI资源回归测试` 不许
	## 在 `.gd` 里现造 StyleBox）⇒ 这里按**运行期实际取到的那张图**判，皮丢了门要红，
	## 不能只看「场景里写过一行 override」。参照路径是手抄的真值，不向被测对象要。
	for 钮名 in ["确定钮", "取消钮"]:
		var 钮 := _件(弹, "主体/" + 钮名) as Button
		for 档 in [["normal", "钮底30.png"], ["hover", "钮底30_悬停.png"],
				["pressed", "钮底30_按下.png"]]:
			var 皮 := 钮.get_theme_stylebox(String(档[0])) as StyleBoxTexture
			var 得 := "" if 皮 == null or 皮.texture == null else str(皮.texture.resource_path)
			_判(得.ends_with(String(档[1])),
					"%s 的 %s 档 = 好友/%s（实得「%s」）" % [钮名, 档[0], 档[1], 得])
		## `.tscn` 里颜色写的是 6 位小数（0.988235），`Color("fcf49c")` 是 252/255 的全精度
		## ⇒ 只能按 8bit 量级比，写 `==` 会因文本精度掉零头而假红。
		var 色 := 钮.get_theme_color("font_color")
		var 差 := maxf(maxf(absf(色.r * 255.0 - 252.0), absf(色.g * 255.0 - 244.0)),
				absf(色.b * 255.0 - 156.0))
		_判(差 <= 1.0, "%s 的字色 = MButtonF 那三档共用的 #fcf49c（实得 %s）" % [钮名, 色])
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 是手型光标" % 钮名)
	假.发过 = []
	await _点后(_件(弹, "主体/取消钮") as Control)
	_判(假.发过 == ["119:3:%d" % 他号], "点「取消」发 `119:3:<邀请者号>`（实发 %s）" % str(假.发过))
	_判(弹.visible == false, "点完弹自己收起")
	假.发过 = []
	var 又格: Control = 盘.加消息(托盘脚本.类型交易, {"id": 他号, "name": 他名})
	await _点后(又格 as Control)
	await _点后(_件(弹, "主体/确定钮") as Control)
	_判(假.发过 == ["119:4:%d" % 他号], "点「确定」发 `119:4:<邀请者号>`（实发 %s）" % str(假.发过))
	(窗交易 as CanvasLayer).visible = 交易原显

	# ── L. 取消 / 成交 两条回帧把窗关掉 ────────────────────────────
	假.发过 = []
	await _点后(_件(页现取(), "取消钮") as Control)
	_判(假.发过 == ["119:10"], "点「取消」发 `119:10`（实发 %s）" % str(假.发过))
	_喂(String(原["取消"]))
	for i in 3:
		await process_frame
	假.authoritative_trade = 后.get("authoritative_trade")
	_判(bool(窗交易.call("已打开")) == false,
			"`335:9:0` ⇒ 窗关掉（关窗由下行驱动，不在点击处 close）")
	_判(bool((后.get("authoritative_trade") as Dictionary).get("active", true)) == false,
			"取消后状态回到空（`removeData` 的等价物）")
	## ⚠ 这里**不能再拿 `页`** —— 窗一关，`_content` 下那页就进了 `queue_free` 队列，
	## 再拿它是"已释放对象"（运行期直接报 Invalid type，整道门半路死）。要看空态就重开一次。
	## ⚠ 重开之前要把窗的后端**换回真后端**：`_render_trade` 读的是 `宿主._backend` 那份状态，
	## 而假后端手里还攥着**上一个**字典（`335:9/22` 是整体换新字典，不是原地改）⇒
	## 它读到的是"还没成交"的空态，页就不建了。出帧断言这一段已经跑完，不需要假后端了。
	窗交易.set("_backend", 后)
	_喂(String(原["开始"]))
	for i in 3:
		await process_frame
	窗交易 = 管理.call("取窗口", "交易") as Node
	var 页2 := 页现取()
	if 页2 == null:
		_判(false, "取消后再来一条 `335:22` ⇒ 窗重新开得出")
		_结("交易页离线门")
		return
	_判(true, "取消后再来一条 `335:22` ⇒ 窗重新开得出")
	_判(_标(页现取(), "我的金币值").text == "0" and _标(页现取(), "我的元宝值").text == "0"
			and _标(页现取(), "对方名").text == 他名,
			"重开一次金额全回 0、对方名重新灌（实得金「%s」宝「%s」名「%s」）"
			% [_标(页现取(), "我的金币值").text, _标(页现取(), "我的元宝值").text, _标(页现取(), "对方名").text])
	_判(_件(页现取(), "我的格1").是空的() and _件(页现取(), "我的格2").是空的(),
			"重开一次格子是空的（`removeData` 那一条）")
	窗交易.set("_backend", 假)
	_喂(String(原["成交"]))
	for i in 3:
		await process_frame
	_判(bool(窗交易.call("已打开")) == false, "`335:8` ⇒ 成交完成也关窗")

	# ── M. 尺寸表 + 成对摆位登记 ──────────────────────────────────
	var 尺寸 := JSON.parse_string(去BOM(FileAccess.get_file_as_string(尺寸表路径))) as Dictionary
	var 条: Dictionary = 尺寸.get("交易", {}) as Dictionary
	_判(int(条.get("宽", 0)) == 321 and int(条.get("高", 0)) == 483 and bool(条.get("整框", false)),
			"尺寸表：交易 = 321×483 整框（实得 %s）" % 条)
	_判(String(条.get("标题", "")) == "交易", "标题 = TRADE_WINDOW_TITLE「交易」")
	_判(管理脚本.伴随背包.has("交易"),
			"原版 `setTradeWindowVisible` 是 centerTwoWindow(交易, 背包) ⇒ 必须连背包")
	_判(管理脚本.居中弹.has("交易") == false, "交易窗是普通可拖窗，不进居中弹")
	_判(管理.get_node_or_null("邀请托盘") != null
			and 管理.get_node_or_null("模态确认弹层/模态确认弹") != null,
			"托盘与确认弹是 `窗口管理.tscn` 里的**固定节点**（编辑器看得见，不是运行期 new 出来的）")
	_结("交易页离线门")


## 金额子窗里那个输入框（`数量`）。走 `get_node` 拿 LineEdit，别在门上写死类型链。
func _额窗数量(额窗: Control) -> LineEdit:
	return 额窗.get_node("数量") as LineEdit
