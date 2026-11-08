extends SceneTree

## 成就福袋（`SuccessWindow`）整条链回归门 —— 2026-10-24，用户实机报修 #74「福袋道具功能未实装」。
##
## 病根（七处，缺一环都表现为"双击没反应"）：
##   ① `后端连接.request_fudai_*` 发的是自造的 `"0"`/`"1:%d"→select`，服务端
##      `handle_fudai` 走到 `if action != 3: return` 静默丢弃（`服务端/runtime/tools/fake_flash_server.py:31929`）；
##   ② `_parse_fudai_*` 挂过 `fields.size() < 9` 那道假格式闸 ⇒ 真帧（6 段 / 4 段）全被丢；
##   ③ `功能窗口._use_item` 缺 `是福袋类` 那一支 ⇒ 15008001 掉进 `use_inventory_slot`，
##      在线发一条服务端不认的 USE_ITEM、离线只回一句提示；
##   ④ `fudai_state_received` 挂在通用 `_on_reward_state_received` 列表里 ⇒ **全工程没有任何一处**开这扇窗；
##   ⑤ `_置钮态(2)` 把「领奖」一起关死 ⇒ 跑完灯也点不动；
##   ⑥ 窗本身不存在；
##   ⑦ `游戏数据.福袋类型` 里 `String(整型 Variant)` 是**非法构造** ⇒ 整句 SCRIPT ERROR、
##      函数返回 null ⇒ ①~⑥ 全修完、拦截支依然恒假（§3.261 探针逮到）。
##
## 本门钉的十五段（坐标/文案真值 = `2.2.3/.../success/SuccessWindow.as` + `SuccessWindowCell.as`，
## 协议真值 = `FudaiProcessor.as` + 上面那份夹具；跑马灯帧数是**实测**不是推的）：
##   A 表与判据：`宝盒.fudai` = 1/5/6/7 ↔ 15008001/05/06/07，且 **15008005 硬排除**；
##     `福袋物品号` 必须回整数形状的串（`.0` 那条是 float 解析回归）。
##   B 离线：只发一句诚实提示，**不吃件、不开窗、不发包**。
##   C 在线双击：只发一条 `1286 "1:格位"`，**从不发 USE_ITEM**、不吃件、**不开窗**（窗是回帧开的）。
##   D `1289:1:1:` 回帧：建窗 + 登台 + 居中 (343,127) + 标题=物品名 + 16 候选进格 + 三态闸 state1。
##   E 版式逐坐标（274×306 / 黄底 / 子面板 / 奖品字 child 0 / 两处 5px 不对称 / 钮 37×22 / 勾 109×20 / 选中环 46×46@−3,−3）。
##   F 点「开始」⇒ `1286 "2"`。
##   G `1289:2:2:落点` ⇒ 跑马灯：帧 = `_总步 + 64`、恰好定在 `cellArr[落点]`、奖品格抄该格、领奖开。
##   H 点「领奖」⇒ `1286 "3"` + `isDelay` 1000ms 防连点 + 清选中 + 还有一只就清奖品格。
##   I 背包满闸：`占用 >= 总格数` ⇒ 只播「背包已经满了」、两支都不发包。
##   J 「开奖后自动领奖」：定格后再数 6 帧自己领。
##   K 「领奖后自动开始」：包里有同种 ⇒ 立即 `1286 "2"`；没了 ⇒ 只摘帧、不发包、奖品格图标留着。
##   L 关窗 = `isDestroy` ⇒ `queue_free` ⇒ 下一条 `1289:1` **重造一扇并重新居中**（不是显影旧枚）。
##   M `1289:2` 而窗不存在 ⇒ 什么都不做（不替玩家开空窗）。
##   N 越界落点 ⇒ 不演、领奖钮仍被 `:349` 那一句关掉（不骗玩家说中奖了）。
##   O 链尾 `1289:1:0:-:-:1`：`setData:252` 的 `if(param1)` ⇒ **状态 0 不调 `_置钮态`**，钮留在上一档；
##     外加 gained 非空那一腿直接填奖品格。
##
## ⚠️ 本门会 `_save_local_state()` 落盘 user:// ⇒ 开场文件快照、收尾按字节还原（§3.76.1）。
## ⚠️ 窗挂在 `功能窗口._overlay` 上 ⇒ 开场钉 `root.size`（无头视口，居中算式读它）。
## ⚠️ **`_overlay` 里同时只能活一扇**：每条腿开头 `await _关窗()`，且**每扇窗的子件引用都要现取**
##    —— 上一轮的 `开始钮/领奖钮/奖品格` 跟着旧实例一起 free，拿旧引用判 = 拿假绿。
## ⚠️ 跑马灯那几条腿**从 `设落点` 到推完不许 `await`**：Timer 挂在树上，一 await 它自己补几拍，
##    帧数就不是 `_总步 + 64` 了（探针里那句 "Unable to start the timer…" 是窗不在树上才报的）。
##
## 运行：Godot --headless --path . --script res://测试/成就福袋回归测试.gd

const 窗场景 := "res://场景/界面/功能窗口.tscn"
const 会话路径 := "/root/GameSession"
const 后端路径 := "/root/BackendConnection"

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 福袋窗脚本 := preload("res://脚本/界面/窗口/福袋窗.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 门存档快照 := preload("res://测试/门存档快照.gd")

const 福袋号 := "15008001"
const 环格数 := 16
## 候选只用 `数据/物品.json` 里真存在的号（探针实测有图标）：空条目查不到定义 ⇒ 提示框与图标全成哑巴。
const 候选号: Array[String] = ["15003001", "08000001", "13100001", "01010013"]

var _失败: Array[String] = []
var _受检 := 0
var _快照: Dictionary = {}
var _文件前 := {}
var _秒 := 0.0
var _提示: Array[String] = []

var _会话 = null
var _场: Node = null
var _遮罩层: Control = null
var _假: Node = null
var _存容量 := 0


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		_收尾()
		printerr("成就福袋回归测试：看门狗超时（90s）—— 中途崩了没走到收尾，已强制还原快照")
		quit(1)
		return true
	return false


func _查(过: bool, 文: String) -> void:
	_受检 += 1
	if not 过:
		_失败.append(文)
		print("!! " + 文)


func _件(物品id: String, 件数: int, 补丁 := {}) -> Dictionary:
	var 条 := {"id": 物品id, "name": 物品id, "category": "特殊物品",
			"quantity": 件数, "price": 0,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"}
	条.merge(补丁, true)
	return 条


## 一条真帧条目（`_parse_item_entry:5317-5334` 的十段：type id slot qty price · canTrade · · unique）。
func _条(号: String, 格: int, 件: int) -> String:
	return "0&%s&%d&%d&0&0&1&0&0&%d" % [号, 格, 件, 900 + 格]


## 16 条候选串：第 `序` 条 = 循环取的真实物品号、件数 = 序 + 1（⇒ 落点 7 那格件数 8，能钉 `_设件数`）。
func _候选串() -> String:
	var 串: Array[String] = []
	for 序 in 环格数:
		串.append(_条(候选号[序 % 候选号.size()], 序, 序 + 1))
	return "@".join(串)


## 喂一帧**真的** `1289:1:<state>:<gained|->:<候选@连接>:<type>`（走 `_handle_fudai_text` 全解析，不手搓字典）。
func _发状态帧(状态: int, 已得: String, 候选: String, 类型: int) -> void:
	_假.call("_handle_fudai_text", PackedStringArray(
		["1289", "1", str(状态), 已得, 候选, str(类型)]))


func _发落点帧(状态: int, 落点: int) -> void:
	_假.call("_handle_fudai_text", PackedStringArray(["1289", "2", str(状态), str(落点)]))


## 开一扇新窗（回帧 → 建件 → 登台），等两帧让 `set_deferred` 的居中落地。
func _开窗(状态: int = 1, 已得: String = "-", 类型: int = 1) -> Control:
	_发状态帧(状态, 已得, _候选串(), 类型)
	await process_frame
	await process_frame
	return _窗()


func _窗() -> Control:
	var 窗 := _遮罩层.get_node_or_null("福袋窗") as Control
	if 窗 != null and 窗.is_queued_for_deletion():
		return null
	return 窗


## 把 `_overlay` 里的福袋窗摘干净（`隐藏()` 是 `queue_free`，要等帧才真没了）。
func _关窗() -> void:
	var 窗 := _窗()
	if 窗 != null:
		窗.call("隐藏")
		await process_frame
		await process_frame


func _环格们(窗: Control) -> Array:
	return 窗.get("_格们") as Array


func _钮(窗: Control, 名: String) -> Button:
	return 窗.get(名) as Button


## 同帧连调 `_滴答()` 把跑马灯推完（中途不 await，见头注释 ⚠）。
func _跑完(窗: Control, 上限: int = 400) -> int:
	var 帧 := 0
	while 帧 < 上限 and int(窗.get("_已走")) < int(窗.get("_总步")):
		窗.call("_滴答")
		帧 += 1
	return 帧


func _上行(内容: String) -> int:
	var 次 := 0
	for 求 in (_假.sent_requests as Array):
		if int((求 as Dictionary).opcode) == 1286 and String((求 as Dictionary).content) == 内容:
			次 += 1
	return 次


func _全部上行() -> Array[String]:
	var 出: Array[String] = []
	for 求 in (_假.sent_requests as Array):
		出.append("%d:%s" % [int((求 as Dictionary).opcode), String((求 as Dictionary).content)])
	return 出


## 造鼠标事件直投 `gui_input`（headless 没有真鼠标，坐标得由事件自带）。
func _鼠标键(位: Vector2, 按下: bool) -> InputEventMouseButton:
	var 事 := InputEventMouseButton.new()
	事.button_index = MOUSE_BUTTON_LEFT
	事.pressed = 按下
	事.position = 位
	事.global_position = 位
	return 事


func _鼠标动(位: Vector2) -> InputEventMouseMotion:
	var 事 := InputEventMouseMotion.new()
	事.position = 位
	事.global_position = 位
	事.button_mask = MOUSE_BUTTON_MASK_LEFT
	return 事


func _run() -> void:
	root.size = Vector2i(960, 560)
	_会话 = root.get_node(会话路径)
	var 后端: Node = root.get_node(后端路径)
	# `_背包总格数` 那条链**先看服务端的权威值**（读的是自动单例，不是注入进窗的假后端），
	# 无头里没有服务端 ⇒ 它必须是 0，`common_slots` 那一档才轮得到；I 段还要临时把它拧成 1。
	_存容量 = int(后端.authoritative_bag_capacity)
	后端.authoritative_bag_capacity = 0
	_快照 = {
		"player_stats": (_会话.player_stats as Dictionary).duplicate(true),
		"inventory": (_会话.inventory as Array).duplicate(true),
		"storage": (_会话.storage as Array).duplicate(true),
		"equipped_items": (_会话.equipped_items as Dictionary).duplicate(true),
	}
	_会话.notification_requested.connect(func(文: String) -> void: _提示.append(文))

	_场 = (load(窗场景) as PackedScene).instantiate()
	root.add_child(_场)
	await process_frame
	await process_frame
	_遮罩层 = _场.get("_overlay") as Control
	if _遮罩层 == null:
		_查(false, "功能窗口没有 _overlay ⇒ 开窗这条路没法测")
		_收尾()
		quit(1)
		return
	_假 = 测试后端.new()
	_假.name = "假后端"
	root.add_child(_假)
	_假.in_game = true
	_场.set("_backend", _假)
	# `_ready` 里那条 `fudai_state_received.connect(_收到福袋帧)` 连的是自动单例；
	# 这里把**假后端的同名信号**也接到同一个处理函数上 ⇒ 走的还是工程那条腿。
	_假.fudai_state_received.connect(_场._收到福袋帧)

	_会话.player_stats["level"] = 100
	_会话.player_stats["job"] = 300
	_会话.player_stats["common_slots"] = 90

	# ══ A 表与判据 ══
	var 表: Dictionary = 游戏数据.取表("宝盒").get("fudai", {}) as Dictionary
	_查(表.size() == 4, "宝盒.fudai 该有 4 条（1/5/6/7），实测 %d" % 表.size())
	_查(游戏数据.福袋类型(福袋号) == 1,
		"福袋类型(15008001) ≠ 1（= 0 就是拦截支恒假，#74 的最后一环 ⑦）")
	_查(游戏数据.福袋类型("15008006") == 6, "福袋类型(15008006) ≠ 6")
	_查(游戏数据.福袋类型("15008007") == 7, "福袋类型(15008007) ≠ 7")
	_查(游戏数据.福袋类型("15008005") == 0,
		"15008005（战备物品箱）必须是 0：`StringTool.isFuDaiLeiItemByID:721` 第一行硬排除")
	for 号 in ["15008002", "15008003", "15008004"]:
		_查(游戏数据.福袋类型(号) == 0,
			"%s 是《亲热天堂》宝书，不是福袋族（该走 17/18 那支，不该被这扇窗截走）" % 号)
	_查(游戏数据.福袋类型("15003001") == 0, "攻击药剂不该被判成福袋")
	# ⚠️ 逐字钉死：`数据/宝盒.json` 的数字被 Godot 解析成 **float**，
	#    少一层 `str(int(…))` 就会回 `"15008001.0"` ⇒ 下游拿它查 `物品.json` 一律落空。
	_查(游戏数据.福袋物品号(1) == 福袋号,
		"福袋物品号(1) 实测 [%s]（必须是整数形状的串，不能带 .0）" % 游戏数据.福袋物品号(1))
	_查(游戏数据.福袋物品号(6) == "15008006" and 游戏数据.福袋物品号(7) == "15008007",
		"福袋物品号(6/7) 不对：[%s] [%s]" % [游戏数据.福袋物品号(6), 游戏数据.福袋物品号(7)])
	_查(游戏数据.福袋物品号(9) == "", "查不到的类型该回空串，实测 [%s]" % 游戏数据.福袋物品号(9))

	# ══ B 离线：只提示，不吃件、不开窗、不发包 ══
	# ⚠️ 这一条腿对"漏接福袋支"那种突变**天生不敏感**：`_开福袋` 和 `use_inventory_slot`
	#    给离线玩家的是**同一句**诚实话（`游戏会话.gd:838`）⇒ 判拦截支有没有接上要看 C 段的上行，
	#    这里只钉"离线不许自造掷骰、不许吃件、不许凭空开一扇没数据的窗"。
	_假.in_game = false
	_会话.inventory = _会话.落位带洞([_件(福袋号, 2, {"slot_index": 1})])
	_假.sent_requests.clear()
	_提示.clear()
	_查(bool(_会话.call("是福袋类", 1)), "包里第 1 格是 15008001，`是福袋类(1)` 却为假")
	_场.call("_use_item", 1)
	await process_frame
	_查(_假.sent_requests.is_empty(), "离线双击福袋却发了 %d 条包" % _假.sent_requests.size())
	_查(_提示.size() == 1 and _提示[0].contains("要在服务端结算（离线不模拟）")
			and _提示[0].contains("成就福袋"),
		"离线那句提示不对，实得 %s" % str(_提示))
	_查(int(_会话.格位物品(1).get("quantity", 0)) == 2,
		"离线双击把福袋吃了（件是服务端 action 1 里扣的）")
	_查(_窗() == null, "离线就把福袋窗开出来了（窗只由 `1289:1` 开）")

	# ══ C 在线双击：只发 1286 "1:1"，不发 USE_ITEM、不吃件、不开窗 ══
	_假.in_game = true
	_假.sent_requests.clear()
	_提示.clear()
	_场.call("_use_item", 1)
	await process_frame
	_查(_全部上行() == ["1286:1:1"],
		"双击福袋只该发一条 `1286 \"1:格位\"`（`FudaiProcessor.requestFudaiOpen:216-222`），实得 %s"
		% str(_全部上行()))
	_查(int(_会话.格位物品(1).get("quantity", 0)) == 2,
		"发请求就把福袋吃了（件是服务端 action 1 里扣的）")
	_查(_窗() == null, "双击就把窗开了 —— 原版是回帧才 `reverseDisplay`")

	# ══ D 回帧建窗 ══
	var 窗 := await _开窗()
	_查(窗 != null and 窗.visible, "`1289:1:1:` 没把福袋窗开出来（④：曾经全工程没有一处消费者）")
	if 窗 == null:
		_收尾()
		quit(1)
		return
	_查(String(窗.name) == "福袋窗", "窗名不对：[%s]（`_收到福袋帧` 按这个名字找旧枚）" % 窗.name)
	_查(窗.size == Vector2(274, 306), "窗尺寸 %s ≠ 274×306" % str(窗.size))
	# 居中 = `MWindow.setLocationCenter` 的 `floor((舞台 − 自身) / 2)`。
	_查(窗.global_position == Vector2(343, 127),
		"首次登台没摆到舞台正中：%s ≠ (343,127)（floor((960−274)/2), floor((560−306)/2)）"
			% str(窗.global_position))
	# ══ D2 标题带拖动（2026-10-29 用户报修「成就福袋面板不能拖拽移动」）══
	# 真值：`SuccessWindow extends MWindow`、`isDrag` 默认 true、`_startDragY = 29`
	# ⇒ 顶部 29px 按下能拖，钳位 = `Rectangle(0, 0, 960-274, 560-30)`。
	# 修前这扇窗是纯脚本 Control 直接挂 `遮罩`，一格拖动都没接（点哪都不动）。
	var 拖区 := 窗.get_node_or_null("拖动区") as Control
	_查(拖区 != null, "福袋窗缺「拖动区」子节点 ⇒ 整扇窗拖不动（`MWindow.as:229` 顶部 29px）")
	if 拖区 != null:
		_查(拖区.position == Vector2.ZERO and 拖区.size == Vector2(274, 29),
			"拖动区该贴顶 274×29（`MWindow.as:229`），实测 %s / %s"
				% [str(拖区.position), str(拖区.size)])
		_查(拖区.mouse_filter == Control.MOUSE_FILTER_STOP, "拖动区不吃鼠标（filter=%d）" % 拖区.mouse_filter)
		var 起 := 窗.global_position
		拖区.gui_input.emit(_鼠标键(起 + Vector2(10, 10), true))
		拖区.gui_input.emit(_鼠标动(起 + Vector2(110, 60)))
		_查(窗.global_position == 起 + Vector2(100, 50),
			"标题带拖动没跟手：%s ≠ %s" % [str(窗.global_position), str(起 + Vector2(100, 50))])
		拖区.gui_input.emit(_鼠标键(起 + Vector2(110, 60), false))
		拖区.gui_input.emit(_鼠标动(起 + Vector2(500, 400)))
		_查(窗.global_position == 起 + Vector2(100, 50),
			"松开左键后窗还跟着鼠标走（缺 release 闸）：%s" % str(窗.global_position))
		# 钳位：左上 (0,0)、右下 (960-274, 560-30) = (686,530) —— 原版 `startDrag` 的矩形。
		拖区.gui_input.emit(_鼠标键(起 + Vector2(110, 60), true))
		拖区.gui_input.emit(_鼠标动(Vector2(-500, -500)))
		_查(窗.global_position == Vector2(0, 0), "左上钳位不对：%s ≠ (0,0)" % str(窗.global_position))
		拖区.gui_input.emit(_鼠标动(Vector2(3000, 3000)))
		_查(窗.global_position == Vector2(686, 530),
			"右下钳位该是 (960-274, 560-30) = (686,530)，实测 %s" % str(窗.global_position))
		拖区.gui_input.emit(_鼠标键(Vector2(3000, 3000), false))
		# 摆回居中位：后面的腿都不该受这次拖动影响。
		窗.set("global_position", Vector2(343, 127))
	_查((窗.get_node("标题") as Label).text == "成就福袋",
		"标题不是物品名（`setData:247` 用 `getItemString(currItemID)` 覆盖构造里的 CN 标题），实得 [%s]"
			% (窗.get_node("标题") as Label).text)
	var 格们 := _环格们(窗)
	var 奖品格 := 窗.get("_奖品格") as Button
	# ⚠️ `_建格` 是环格与奖品格**共用**的工厂 ⇒ `_格们` = 16 环格 + 末位奖品格 = 17。
	#    环格序 0..15 与 `_格条`（只 resize 到 16）同序；奖品格永远排最后，
	#    所以 `_摆选中` 的 16 个亮位不会点到它。
	_查(格们.size() == 环格数 + 1, "环格 16 枚 + 奖品格该共 17 枚，实测 %d" % 格们.size())
	_查(格们[环格数] == 奖品格, "`_格们` 末位不是奖品格（`_填格`/`_清奖品格` 的分工就乱了）")
	for 序 in mini(格们.size(), 环格数):
		var 格 := 格们[序] as Button
		_查(格.position == 福袋窗脚本.环位[序],
			"第 %d 格不在 %s（上排末位 216、右列 221 那处 5px 不对称是原版的，不许\"对齐\"）"
				% [序, str(福袋窗脚本.环位[序])])
		_查(格.icon != null, "第 %d 格没填上候选图标" % 序)
		_查(String(格.get("物品id")) == 候选号[序 % 候选号.size()],
			"第 %d 格的物品号 = [%s]，与候选不符" % [序, String(格.get("物品id"))])
		_查((格.get_node("数量") as Label).text == ("" if 序 == 0 else str(序 + 1)),
			"第 %d 格件数不对（`setItemCount:432-438` 只有 >1 才写字）：[%s]"
				% [序, (格.get_node("数量") as Label).text])
	# ⚠️ 候选的镜像挂在窗自己的 `_格条` 上，**不挂格子**（`可拖拽格` 没这个属性，`格.set` 会 Invalid set）。
	var 格条: Array = 窗.get("_格条") as Array
	_查(格条.size() == 环格数, "`_格条` 没与 16 格同序扩容 ⇒ `setAwardData` 无处抄")
	_查(String((格条[7] as Dictionary).get("id", "")) == 候选号[7 % 4], "`_格条[7]` 不是候选第 7 条")
	# 三态闸 state 1 = 已开出：开始开、领奖关。
	var 开始钮 := _钮(窗, "_开始钮")
	var 领奖钮 := _钮(窗, "_领奖钮")
	_查(not 开始钮.disabled, "state=1 时「开始」该亮（`setBtnEnabled:322-327`）")
	_查(领奖钮.disabled, "state=1 时「领奖」该关")
	_查(奖品格.icon == null, "gained=\"-\" 却把奖品格填上了（AS3 先 new 再 decode 恒真，文本桥用空/非空当真假）")

	# ══ E 版式逐坐标 ══
	_查(窗.get_child(0).name == "奖品字",
		"「奖 品」不是第 0 个子件 —— 原版构造函数先 addChild 它、背景随后才进 `init()`，"
		+ "所以它画在三层背景**底下**靠半透明透出（不许顺手提到最上层）")
	_查((窗.get_node("奖品字") as Label).text == "奖 品", "奖品字文案不对（`UI_29`，中间一个空格）")
	_查((窗.get_node("奖品字") as Label).position == Vector2(88, 117), "奖品字不在 (88,117)")
	var 黄底 := 窗.get_node("黄底") as Panel
	_查(黄底.position == Vector2(6, 39) and 黄底.size == Vector2(262, 263),
		"黄底不在 (6,39) 262×263（`background.width − 12`）")
	var 面板 := 窗.get_node("子面板") as NinePatchRect
	_查(面板.position == Vector2(64, 100) and 面板.size == Vector2(139, 138),
		"子面板不在 (64,100) 139×138（`MPane_background`）")
	_查(面板.texture != null,
		"子面板没挂 `通用控件/子面板.png`（主题里没注册这档变体 ⇒ 只能 NinePatchRect 上真图）")
	_查(面板.patch_margin_left == 8 and 面板.patch_margin_right == 7
			and 面板.patch_margin_top == 7 and 面板.patch_margin_bottom == 7,
		"子面板 patch margin ≠ 8/7/7/7（⚠️ 这四条是 **int** 属性，收 float 整条建件中止）")
	_查(奖品格.position == Vector2(84, 133), "奖品格不在 (84,133)（`awardIocn`）")
	_查(开始钮.position == Vector2(147, 128) and 领奖钮.position == Vector2(147, 152),
		"两枚钮不在 (147,128)/(147,152)")
	_查(开始钮.size == Vector2(37, 22) and 领奖钮.size == Vector2(37, 22),
		"钮尺寸 %s ≠ 37×22（`UIConfig.btn_width_two` + `MButton3:275` 取 upSkin 原生高）")
	_查(开始钮.text == "开始" and 领奖钮.text == "领奖", "两枚钮文案不对")
	var 勾领取 := 窗.get("_勾领取") as CheckBox
	var 勾开始 := 窗.get("_勾开始") as CheckBox
	_查(勾领取.position == Vector2(82, 180) and 勾开始.position == Vector2(82, 201),
		"两枚勾不在 (82,180)/(82,201)")
	# ⚠️ 宽按原版 `MCheckBoxF`（`isScale9Grid = false`）钉死 109；高 = **皮高 19**
	#    （`MCheckBox.as:81-82` `_height = upSkin.height`，`通用控件/复选框未选.png` 原生 19×19）。
	#    10-25 前这里钉的是"≥20"，因为主题的 `CheckBox` 漏声明 `hover_pressed` ⇒ 引擎兜底空盒的
	#    4 像素四边边距把最小高顶到 27，脚本压不下来，只能退而求其次钉下限（`素材/界面/原版皮肤表.gd`
	#    的 CheckBox 段）。补上空盒后地板回到皮高，两行的间距 21 又 > 19 ⇒ 直接钉死 19，
	#    重叠那一档由 `测试/勾选框几何回归测试.gd` 的行距腿一起管。
	_查(勾领取.size.x == 109.0 and 勾开始.size.x == 109.0,
		"两枚勾的宽 ≠ 109（实测 %s / %s）" % [str(勾领取.size), str(勾开始.size)])
	_查(勾领取.size.y == 19.0 and 勾开始.size.y == 19.0,
		"两枚勾的高 ≠ 皮肤高 19（实测 %s / %s；21 的行距配 19 的框正好不咬，长回 27 就重叠）"
				% [str(勾领取.size), str(勾开始.size)])
	_查(勾领取.text == "开奖后自动领奖" and 勾开始.text == "领奖后自动开始", "两枚勾文案不对")
	_查(not 勾领取.button_pressed and not 勾开始.button_pressed, "两枚勾构造期就该没勾上")
	_查((格们[0].get_node("选中") as Control).position == Vector2(-3, -3)
			and (格们[0].get_node("选中") as Control).size == Vector2(46, 46),
		"选中环不在 (−3,−3) 46×46（`Mc_YellowIcon` 的摆位）")
	_查((格们[0].get_node("选中") as Control).get_child_count() == 4,
		"选中环该是四条 2px ColorRect 拼的（素材缺失，同 `活动窗口._补藏宝格子`）")
	_查(not (格们[0].get_node("选中") as Control).visible, "state=1 还没开演时选中环不该亮")
	var 数量 := 格们[0].get_node("数量") as Label
	_查(数量.offset_left == 2.0 and 数量.offset_top == 22.0 and 数量.offset_right == 39.0
			and 数量.offset_bottom == 40.0,
		"`SuccessWindowCell.tf` 的几何被背包格的 (1,24) 顶掉了")
	_查(数量.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "件数不是右对齐")
	_查(not bool(格们[0].get("可拖拽")), "福袋环格参与拖拽了（AS3 只有 `buttonMode`，不接拖拽）")

	# ══ F 点「开始」⇒ 1286 "2" ══
	_假.sent_requests.clear()
	开始钮.pressed.emit()
	await process_frame
	_查(_上行("2") == 1 and _上行("3") == 0 and _上行("1:1") == 0,
		"点「开始」只该发一条 `1286 \"2\"`（`requestFudaiStart:146-151` 不带格位），实得 %s"
			% str(_全部上行()))

	# ══ G 落点帧 ⇒ 跑马灯（这一段从设落点到推完**不 await**）══
	_假.sent_requests.clear()
	_发落点帧(2, 7)
	_查(领奖钮.disabled,
		"`setTakeData:349` 无条件关领奖 —— 刚开演领奖钮就亮着是假的（玩家还没中）")
	_查((格们[0].get_node("选中") as Control).visible, "开演第 0 帧该亮 `cellArr[0]`")
	var 总步 := int(窗.get("_总步"))
	_查(总步 == 55 or 总步 == 71,
		"`total = rnd(3,4)·16 + index`（`MathAD.rnd` 两端闭区间 ⇒ 圈数只会是 3 或 4），实测 %d" % 总步)
	_查(int(窗.get("_均步")) == 总步 - 14, "`averageCount = total − 7 − 7` 算式不对")
	var 帧 := _跑完(窗)
	_查(帧 == 总步 + 64,
		"跑马灯帧数 %d ≠ 总步(%d) + 64（加速 37 + 中间 均步+1 + 减速 40，实测口径）" % [帧, 总步])
	_查(int(窗.get("_亮格")) == 7, "跑完没定在 `cellArr[落点]`，亮的是第 %d 格" % int(窗.get("_亮格")))
	_查(String(奖品格.get("物品id")) == 候选号[7 % 4],
		"奖品格抄错了格：[%s] ≠ 候选第 7 条 %s" % [String(奖品格.get("物品id")), 候选号[7 % 4]])
	_查((奖品格.get_node("数量") as Label).text == "8",
		"奖品格件数不是候选第 7 条的 8，实得 [%s]" % (奖品格.get_node("数量") as Label).text)
	_查(not 领奖钮.disabled, "跑完灯「领奖」还关着（⑤：玩家中奖却点不动）")
	_查(_假.sent_requests.is_empty(), "跑马灯自己发包了 —— 中途只演，不发请求")

	# ══ H 领奖：1286 "3" + 防连点 + 清选中 + 还剩一只就清奖品格 ══
	_假.sent_requests.clear()
	领奖钮.pressed.emit()
	await process_frame
	_查(_上行("3") == 1, "点「领奖」只该发一条 `1286 \"3\"`（`requestFudaiGain:123-128`），实得 %s"
		% str(_全部上行()))
	_查(领奖钮.disabled, "领完「领奖」钮该关掉（`onClickTakeBtn` 末尾）")
	_查(int(窗.get("_亮格")) == -1 and int(窗.get("_已走")) == 0,
		"领奖没清选中、没把 `nowindex` 打回 0")
	_查(奖品格.icon == null,
		"包里还剩 1 只 15008001（`背包同名件数` = 2 > 0）却没 `cleanAwardData()`")
	_查((奖品格.get_node("数量") as Label).text == "", "清奖品格没连件数一起清")
	# `takeBtn.isDelay = true`（`:153`）= 1000ms 内第二发被 `stopImmediatePropagation` 吃掉。
	_假.sent_requests.clear()
	领奖钮.pressed.emit()
	await process_frame
	_查(_假.sent_requests.is_empty(),
		"领奖钮的 1000ms 防连点没生效（`MButton3.delayClickHandler:568-579`）")
	await _关窗()

	# ══ I 背包满闸：两支都只播那一句、都不发包 ══
	root.get_node(后端路径).authoritative_bag_capacity = 1
	_会话.inventory = _会话.落位带洞([_件(福袋号, 1, {"slot_index": 1})])
	窗 = await _开窗()
	_查(窗 != null, "背包满时 `1289:1` 也该开窗（原版只在点钮那两闸拦）")
	if 窗 != null:
		_假.sent_requests.clear()
		_提示.clear()
		_钮(窗, "_开始钮").pressed.emit()
		await process_frame
		_查(_假.sent_requests.is_empty(), "背包满了却还发「开始」请求（`isPackgeFull` 那支该 return）")
		_查(_提示.size() == 1 and _提示[0] == "背包已经满了",
			"背包满那句文案不对（`SUCCESS_WINDOW_PACK_FULL`），实得 %s" % str(_提示))
		_提示.clear()
		_钮(窗, "_领奖钮").pressed.emit()
		await process_frame
		_查(_提示.size() == 1 and _提示[0] == "背包已经满了", "领奖那支也要过同一道满包闸")
		_查(_假.sent_requests.is_empty(), "满包时领奖还发了包")
	await _关窗()
	root.get_node(后端路径).authoritative_bag_capacity = 0

	# ══ J 「开奖后自动领奖」：定格后再数 6 帧自己领 ══
	_会话.inventory = _会话.落位带洞([_件(福袋号, 1, {"slot_index": 1})])
	窗 = await _开窗()
	_查(窗 != null, "自动领奖那条腿没能开窗")
	if 窗 != null:
		(窗.get("_勾领取") as CheckBox).set_pressed_no_signal(true)
		_假.sent_requests.clear()
		_发落点帧(2, 3)
		_跑完(窗)
		_查(int(窗.get("_延演")) == 0, "勾了自动领奖却没挂 `yanshi_yingqu`（`enterFrame:418-421`）")
		_查(_假.sent_requests.is_empty(), "第 0 帧就领奖了（原版数到 `> 5` 才点）")
		for _i in 5:
			窗.call("_滴答")
		_查(_上行("3") == 0, "第 5 帧还不该点领奖（`yanshi_yingqu:440-448` 判的是 `> 5`）")
		窗.call("_滴答")
		_查(_上行("3") == 1, "第 6 帧没自动发领奖，实得 %s" % str(_全部上行()))
		_查(int(窗.get("_延演")) == -1,
			"点完没摘 `yanshi_yingqu`（原版 `removeEventListener`，留着会一帧领一次）")
	await _关窗()

	# ══ K 「领奖后自动开始」：还剩一只 ⇒ 立即 1286 "2" ══
	_会话.inventory = _会话.落位带洞([_件(福袋号, 2, {"slot_index": 1})])
	窗 = await _开窗()
	if 窗 != null:
		(窗.get("_勾开始") as CheckBox).set_pressed_no_signal(true)
		窗.set("_领奖上次点", -1.0)		# 防连点是墙钟，门里同一毫秒会自己把自己吃掉
		_假.sent_requests.clear()
		_发落点帧(2, 5)
		_跑完(窗)
		_查(_上行("3") == 0, "没勾「开奖后自动领奖」却自己领了")
		_钮(窗, "_领奖钮").pressed.emit()
		await process_frame
		_查(_上行("3") == 1 and _上行("2") == 1,
			"勾了「领奖后自动开始」且包里还剩 1 只 ⇒ `automatismStart:489-504` 该紧接着点开始，实得 %s"
				% str(_全部上行()))
	await _关窗()
	# 包里一只福袋都没有 ⇒ 只摘帧、不发包，且**只关钮**、奖品格图标留着。
	_会话.inventory = _会话.落位带洞([_件("15003001", 3, {"slot_index": 1})])
	窗 = await _开窗()
	if 窗 != null:
		(窗.get("_勾开始") as CheckBox).set_pressed_no_signal(true)
		窗.set("_领奖上次点", -1.0)
		_假.sent_requests.clear()
		_发落点帧(2, 5)
		_跑完(窗)
		var 礼格 := 窗.get("_奖品格") as Button
		var 钮 := _钮(窗, "_领奖钮")
		钮.pressed.emit()
		await process_frame
		_查(_上行("2") == 0, "包里一只福袋都没有了还自动发「开始」（原版只 `_停滴答()`）")
		_查(礼格.icon != null,
			"`背包同名件数` = 0 时原版**只关钮**、奖品格图标留着（清了就是自作主张）")
	await _关窗()

	# ══ L 关窗 = 作废实例 ⇒ 下一条 1289:1 重造并重新居中 ══
	_会话.inventory = _会话.落位带洞([_件(福袋号, 1, {"slot_index": 1})])
	窗 = await _开窗()
	if 窗 != null:
		窗.set("global_position", Vector2(111, 22))		# 模拟玩家拖动
		(窗.get_node("关闭") as Button).pressed.emit()
		await process_frame
		_查(_窗() == null,
			"点 X 后实例没作废（`isDestroy` 继承基类的 true ⇒ `queue_free`，不是隐藏复用）")
		var 新窗 := await _开窗()
		_查(新窗 != null and 新窗 != 窗,
			"下一条 `1289:1` 没重造新枚（旧版是显影旧枚 ⇒ 玩家拖哪儿停哪儿）")
		if 新窗 != null:
			_查(新窗.global_position == Vector2(343, 127),
				"重造那一轮没重新居中：%s ≠ (343,127)" % str(新窗.global_position))
			await _关窗()

	# ══ M `1289:2` 而窗不存在 ⇒ 什么都不做 ══
	_发落点帧(2, 4)
	await process_frame
	_查(_窗() == null,
		"没有窗的时候收到落点帧替玩家开了一扇空窗（`onShowFudaiGainItemInfo:4575-4581` 只在窗已存在时演）")

	# ══ N 越界落点 ⇒ 不演、领奖钮仍被 `:349` 关掉 ══
	窗 = await _开窗()
	if 窗 != null:
		var 钮2 := _钮(窗, "_领奖钮")
		_发落点帧(2, 16)
		_查(钮2.disabled, "`setTakeData:349` 那句关钮在越界守卫**之前**，越界也得关")
		_查(int(窗.get("_亮格")) != 16, "越界落点还去点亮第 16 格（原版这里死循环；这边按\"什么都不演\"收）")
		_发落点帧(2, -1)
		_查(钮2.disabled and int(窗.get("_亮格")) == -1, "负落点也没演、也没留亮格")
		_查(int(窗.get("_延演")) == -1, "越界那条腿不该挂上 `yanshi_yingqu`")
		await _关窗()

	# ══ O 链尾 `1289:1:0:-:-:1`：状态 0 不调 `_置钮态`，钮留在上一档 ══
	窗 = await _开窗()
	if 窗 != null:
		var 开 := _钮(窗, "_开始钮")
		var 领 := _钮(窗, "_领奖钮")
		_查(not 开.disabled and 领.disabled, "state=1 那档就该「开始亮、领奖关」")
		_发状态帧(0, "-", "-", 1)
		await process_frame
		_查(not 开.disabled,
			"链尾那条 state=0 把「开始」关掉了 —— `setData:252` 的 `if(param1)` 压根不调 "
			+ "`setBtnEnabled(0)`，钮要留在上一档（原版如此，不是漏调）")
		_查(领.disabled, "state=0 却把「领奖」点亮了（没有奖可领）")
		# gained 非空那一腿：`1289:1:1:<条目>:…:1` ⇒ 奖品格直接填上。
		_发状态帧(1, _条("13100001", 0, 2), _候选串(), 1)
		await process_frame
		var 礼 := 窗.get("_奖品格") as Button
		_查(String(礼.get("物品id")) == "13100001" and (礼.get_node("数量") as Label).text == "2",
			"gained 非空那一腿没把已得件填进奖品格（实得 id=[%s] 数量=[%s]）"
				% [String(礼.get("物品id")), (礼.get_node("数量") as Label).text])
		await _关窗()

	# ══ P 状态 2 那一档：`setBtnEnabled:328-333` = 开始关、**领奖开** ══
	# 这条腿是突变逮出来的（§3.261）：把 `2:` 那一档的领奖改成 `disabled = true`（就是 #74 的⑤），
	# 其余十四条腿**全绿** —— 因为 `设落点` 紧接着就无条件关领奖、跑完又是 `_走格子` 直接开，
	# 两处都绕过了 `_置钮态`。只有真帧 `1289:1:2:<已得>:…` 这条路能把它照出来。
	窗 = await _开窗(2, _条("15003001", 0, 1), 1)
	if 窗 != null:
		_查(_钮(窗, "_开始钮").disabled, "state=2（待停止）时「开始」该关")
		_查(not _钮(窗, "_领奖钮").disabled,
			"state=2 时「领奖」该开（⑤：曾经两枚一起关，玩家中了奖却点不动）")
		_查(String((窗.get("_奖品格") as Button).get("物品id")) == "15003001",
			"state=2 那条真帧没把已得件摆上奖品格")
		# 勾了「开奖后自动领奖」⇒ `设数据:271-277` 当场点领奖（不是等玩家再点一次）。
		await _关窗()
		窗 = await _开窗()
		(窗.get("_勾领取") as CheckBox).set_pressed_no_signal(true)
		_假.sent_requests.clear()
		_发状态帧(1, _条("15003001", 0, 1), _候选串(), 1)
		await process_frame
		_查(_上行("3") == 1,
			"勾了自动领奖、`setData` 收到非空 gained 那一腿该当场点领奖（`:271-273`），实得 %s"
				% str(_全部上行()))
		await _关窗()

	_假.in_game = false
	_场.queue_free()
	_假.queue_free()
	await process_frame
	_收尾()
	if _失败.is_empty():
		print(("成就福袋回归测试：通过（表 4 条 + 15008005 硬排除 + 物品号无 .0 / 离线只提示不吃件 / "
				+ "在线双击只发 1286 1:格位 不发 USE_ITEM / 1289:1 才建窗并居中 (343,127) / "
				+ "标题带拖动跟手·松开即停·钳位 (0,0)..(686,530) / "
				+ "274×306 全套坐标 / 跑马灯帧 = 总步+64 且定在落点 / 领奖 1286 3 + 1000ms 防连点 / "
				+ "满包那句「背包已经满了」不发包 / 自动领奖第 6 帧 / 自动开始两条腿 / "
				+ "关窗作废重造 / 落点帧不代开空窗 / state=0 保留上一档）"))
		quit(0)
	else:
		print("成就福袋回归测试：失败 %d 项（共 %d 项）" % [_失败.size(), _受检])
		quit(1)


func _收尾() -> void:
	var 后端: Node = root.get_node_or_null(后端路径)
	if 后端 != null:
		后端.authoritative_bag_capacity = _存容量
	if not _快照.is_empty():
		var 会话 = root.get_node_or_null(会话路径)
		if 会话 != null:
			会话.player_stats = _快照["player_stats"]
			(会话.inventory as Array).assign(_快照["inventory"] as Array)
			(会话.storage as Array).assign(_快照["storage"] as Array)
			会话.equipped_items = _快照["equipped_items"]
			会话.call("_save_local_state")
	门存档快照.全还原(_文件前)
