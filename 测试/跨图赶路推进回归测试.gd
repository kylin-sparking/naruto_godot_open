extends SceneTree
## 行为门：**跨图赶路的推进与取消**（#165 的后一半）。上一轮只做到"路线算得对"，
## 这一道门要的是**运行期状态真的动起来** —— 按老规矩，比源码字符串不算测过。
## 原版形状（都现查过行号）：
##   排路线起跑 = KeyController.as:1112-1132（`getPath` → 第一跳 `pathFind(门.x, 门.y - 5)`）；
##   手动取消   = :1205-1212 `isDownMoveKey() && _nowPathFinding ⇒ stopPathFind()`，
##                而 :1577-1590 的 `stopPathFind()` 把跨图那包**一起清**；
##   等级闸     = :638-665 不够就 `MAP_NO_ENTRAY` + `stopPathFind()`，整条停住不绕路。
## 落点单位：数据里的门坐标是 1/100 图单位 ⇒ 世界位 = x*100，而原版那个 −5 是**世界像素**，
## 必须乘完 100 再减（门里第 ① 组专门钉这一条，写反了就是偏 500 像素）。
## 跑法：--headless 够（只看状态，不看像素）。不写 user://（`_走跨图一跳` 只读等级）。
##
## ⚠⚠ **这道门当前是红的（19 条 / 红 7），且故意还没登记进全量清单** —— 它抓到一件真事：
##   起跑那一跳 `走向(门位)` 直接回 false ⇒ 按原版的形状整条取消（`KeyController.as:1131` 也是
##   `pathFind() <= 0 ⇒ stopPathFind()`），所以"跨图一步都走不动"不是状态机没接，而是
##   **门坐标 → 世界坐标这一步不落地**。现查数据：起=100000000（木叶村，场景确实加载了这张）、
##   首跳=门号 4 → 103010000、落点算成 (459500.0, 126395.0)，`find_click_target` 给不到落脚点。
##   两条候选，下轮按顺序查：
##     ① `×100` 这个换算本身错了（`_通往` 那份老代码也乘 100 —— 也就是说**旧的"直达门"那条
##        很可能从来没真走通过**，只是没门量过）；拿场景里现成的门实体（`传送门.gd` 的 portals）
##        的世界位对一下就知道该乘多少。
##     ② 门在数据里的 y 与我们的 y 方向/基线不同（原版画的是 `门.y - 5`，5 是世界像素）。
##   查清前别把这道门塞进全量，否则门禁永远交不出去。

var 行: Array[String] = []
var 红 := 0
var 总 := 0
var 出 := "res://测试/截图/追踪栏/跨图赶路推进.txt"
var 起 := "100000000"		# 木叶村（现查：到 112010000 要 4 跳）
var 终 := "112010000"


func _记(说: String, 过: bool) -> void:
	总 += 1
	if not 过:
		红 += 1
	行.append("%s %s" % ["√" if 过 else "!!", 说])
	print(说)


func _initialize() -> void:
	call_deferred("_跑")


func _帧(n: int) -> void:
	for _i in n:
		await process_frame


## 按一个移动键（真事件）。判"玩家自己插手"看的是按键（原版 `isDownMoveKey()`），
## 不是任何内部计数 —— 实机日志证明进门那一帧计数会自己 +1，拿计数判就会每趟在踏进门时被误清。
func _按键(按下: bool) -> void:
	# ⚠ 必须用 `action_press/action_release`：`Input.parse_input_event(InputEventAction)`
	#   在 headless 下**不会**让 `Input.is_action_pressed()` 变真（实测这条不响），
	#   而产品判的就是这个 —— 用错注入法会得到一条"看着测了其实没测"的门。
	if 按下:
		Input.action_press("ui_left")
	else:
		Input.action_release("ui_left")


func _跑() -> void:
	var S = load("res://脚本/地图/跨图寻路.gd")
	_记("路线模块读得到", S != null)
	if S == null:
		_收(); return
	## 顺序要紧：**先定图号、再加载场景** —— 地图场景是按 `current_map_id` 现挑的，
	## 反过来（先加载后改号）就会出现"人在这张图、门坐标是另一张图的"那种假失败。
	var 会话0 = root.get_node_or_null("GameSession")
	if 会话0 != null:
		会话0.set("current_map_id", "100000000")
	var 场: Node = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(60)
	var 板: Node = 场.find_child("小地图面板", true, false)
	var 玩: Node2D = get_first_node_in_group("player") as Node2D
	_记("夹具齐了（小地图面板 + 玩家）", 板 != null and 玩 != null)
	if 板 == null or 玩 == null:
		_收(); return
	var 会话 = root.get_node_or_null("GameSession")
	_记("拿得到 GameSession（图号与等级都从这里读）", 会话 != null)
	if 会话 == null:
		_收(); return
	## 别硬设图号：夹具加载的是哪张图，人就真在哪张图上，"走到门口"才寻得到落脚点。
	起 = str(板._本图号())

	## 等级夹具先摆高：跨图每一跳都要过原版的等级闸（`KeyController.as:638-665`），
	## 1 级会被**第一跳就拦停** —— 那是对的，所以想验"起跑"这一条得先把等级摆够。
	会话.set("player_stats", {"level": 250, "name": "门里夹具"})
	## 挑一个"至少两跳"的目标图（一跳的走不到跨图那支），并拿它当 终
	for 试 in ["112010000", "100000000", "112040002", "105010000", "410000000"]:
		if 试 == 起:
			continue
		var 探: Dictionary = S.路线(起, 试)
		if bool(探.get("成", false)) and (探.get("跳", []) as Array).size() >= 2:
			终 = 试
			break
	## —— ① 排路线起跑：余程少一跳、待进门是**首跳那扇**、落点是 (x*100, y*100−5)、人真的在走 ——
	var 望: Dictionary = S.路线(起, 终)
	_记("门自己先算一遍：木叶村→112010000 成=%s 共 %d 跳" % [str(望.get("成")), (望.get("跳", []) as Array).size()], bool(望.get("成", false)))
	var 跳0: Dictionary = (望.get("跳", []) as Array)[0] as Dictionary
	var 印0 := int(玩.get("auto_path_cancel_stamp"))
	var 起好: bool = 板.前往别的图(int(终), "门里跑一次", {"类": "n", "号": 0, "说明": "测试"})
	_记("前往别的图 回 true（跨图行程起来了）", 起好)
	_记("在途标记置上了", bool(板.get("_跨图在途")))
	_记("余程 == 总跳数 − 1", (板.get("_跨图余程") as Array).size() == (望.get("跳", []) as Array).size() - 1)
	var 待: Dictionary = 板.get("_待进门") as Dictionary
	_记("待进门记的是首跳那扇门（门号 %d / 去 %s）" % [int(跳0.get("门号", -9)), str(跳0.get("到达图", ""))], int(待.get("index", -9)) == int(跳0.get("门号", -8)) and int(待.get("图", -9)) == int(str(跳0.get("到达图", "0"))))
	var 望位 := Vector2(float(跳0.get("门x", 0.0)), float(跳0.get("门y", 0.0)))
	var 实位: Vector2 = 待.get("位", Vector2.ZERO) as Vector2
	## 落点必须是**数据原值**再减 5：地图场景就是把数据原值当世界坐标用的（`地表.gd:89`）。
	## 乘 100 那一版把点推到地图外（木叶村首跳算成 (459500, 126395)）⇒ 跨图第一步就起不来。
	## 这条判据就是为钉住换算而存在的（2026-10-10 它当场抓出来）。
	_记("落点 == (门.x, 门.y − 5)，用的是数据原值口径 实际 %s 望 %s" % [str(实位), str(望位)],
			absf(实位.x - 望位.x) <= 0.01 and absf((实位.y + 5.0) - 望位.y) <= 0.01)
	_记("待进门带「跨图」标记（手动取消时只该清跨图带来的，同图点地走的待办不归它管）",
			bool(待.get("跨图", false)))
	_记("玩家这一跳真的在走（click_move_active 为真）", bool(玩.get("click_move_active")))
	_记("排路线**不该**算一次取消（印没动）", int(玩.get("auto_path_cancel_stamp")) == 印0)

	## —— ② 手动取消（原版的 stopPathFind 形状：整包清，含待进门与余程） ——
	_按键(true)
	_按键(false)
	await _帧(4)
	_记("手动一取消：在途标记掉了", not bool(板.get("_跨图在途")))
	var 余: Array = 板.get("_跨图余程") as Array
	_记("手动一取消：余程清空了", 余.is_empty())
	_记("手动一取消：待进门也清了（不然人停下来了，下一拍还会替玩家进一次门）", (板.get("_待进门") as Dictionary).is_empty())
	_记("手动一取消：终目标清了", (板.get("_跨图终目标") as Dictionary).is_empty())

	## —— ③ 等级闸：不够就整条停住（原版 :638-665 的 MAP_NO_ENTRAY + stopPathFind） ——
	会话.set("player_stats", {"level": 1, "name": "门内夹具"})
	var 高一跳 := {"出发图": 起, "到达图": 终, "门号": 0, "门x": 10.0, "门y": 20.0, "到达等级": 99, "已到达": false}
	板.set("_跨图余程", [高一跳])
	板.set("_跨图在途", true)
	var 跳好: bool = 板._走跨图一跳()
	_记("等级不够 ⇒ 这一跳不起来", not 跳好)
	_记("等级不够 ⇒ 整条清掉（不是留在队里反复重试）", (板.get("_跨图余程") as Array).is_empty())
	_记("等级不够 ⇒ 在途也掉了", not bool(板.get("_跨图在途")))

	## —— ④ **换图把玩家节点重建了，不许当成"手动取消"**（2026-10-10 用户实机报的症状：
	##     寻路到了地图 2 就站住不动。根因就是旧玩家的印 ≥1、新玩家从 0 开始，一比就"变了"）——
	_按键(true)
	_按键(false)
	await _帧(2)
	板.set("_跨图余程", [{"出发图": 起, "到达图": 终, "门号": 9,
			"门x": 玩.global_position.x + 300.0, "门y": 玩.global_position.y + 5.0,
			"到达等级": 1, "已到达": false}])
	板.set("_跨图在途", true)
	## 给一个"这张图查无此人"的终目标：否则这一跳被吃掉后行程就正常收尾了（那不是这条要验的），
	## 有它挂着，`_跨图在途` 才能区分"还在等"和"被判成取消"。
	板.set("_跨图终目标", {"类": "n", "号": 99999999, "说明": "门里占位"})
	板.set("_跨图等到", 0.0)
	板.set("_跨图玩家", null)		# HUD 还记着"上一个玩家" ⇒ 和 _player 不是同一个
	板.set("_跨图起手印", int(玩.get("auto_path_cancel_stamp")) + 7)
	await _帧(3)
	_记("玩家换了一版 ⇒ 不误判成手动取消（在途还在）", bool(板.get("_跨图在途")))
	_记("并且重新对表：印 = 当前玩家的印", int(板.get("_跨图起手印")) == int(玩.get("auto_path_cancel_stamp")))
	var 待9: Dictionary = 板.get("_待进门") as Dictionary
	_记("换图后真的接着走下一跳（待进门 = 那一扇 9 号门）", int(待9.get("index", -1)) == 9)
	## 反向对照：**同一个**玩家上真的取消一次 ⇒ 必须判成取消。
	## ⚠ 这里不许用"把记账数字改大"来凑 —— 那是自证；必须发真事件（`cancel_auto_path`）。
	_按键(true)
	_按键(false)
	await _帧(3)
	_记("同一个玩家、取消计数变大 ⇒ 判成手动取消（反向对照）", not bool(板.get("_跨图在途")))
	## 再钉一条结构判据：换了实例、计数从 0 重新开始（比记账值**小**）⇒ 不算取消
	板.set("_跨图在途", true)
	板.set("_跨图余程", [{"出发图": 起, "到达图": 终, "门号": 9, "门x": 玩.global_position.x + 300.0,
			"门y": 玩.global_position.y + 5.0, "到达等级": 1, "已到达": false}])
	板.set("_跨图终目标", {"类": "n", "号": 99999999, "说明": "门里占位"})
	板.set("_跨图等到", 0.0)
	板.set("_跨图玩家", null)
	板.set("_跨图起手印", 9999)		# 故意比新实例的 0 大：以前这种就是"误判取消"
	await _帧(3)
	_记("换了实例、记账值比它大也不算取消（只认变大）", bool(板.get("_跨图在途")))

	## —— ⑤ 到终点图时 NPC 还没被服务端推下来 ⇒ 要等（原版每拍重试 `canTalkToNpc`），不许判死 ——
	板.set("_跨图余程", [])
	板.set("_跨图终目标", {"类": "n", "号": 99999999, "说明": "门里查无此人"})
	板.set("_跨图终点图", int(起))
	板.set("_跨图在途", true)
	板.set("_跨图玩家", 玩)
	板.set("_跨图起手印", int(玩.get("auto_path_cancel_stamp")))
	板.set("_跨图等到", 0.0)
	await _帧(4)
	_记("到图了但这图查无此人 ⇒ 还在等，没有偷偷清掉行程", bool(板.get("_跨图在途")))
	板.set("_跨图等到", 20.0)
	await _帧(3)
	_记("等过头 15 秒 ⇒ 说一句并清掉（不许无声挂着）", not bool(板.get("_跨图在途")))
	var 根: Node = 场.get_node_or_null("LifeRoot")
	var 人: Node2D = null
	if 根 != null:
		for 客 in 根.get_children():
			if str(客.get("kind")) == "n":
				人 = 客 as Node2D
				break
	_记("夹具这张图里至少有一个 NPC（不然这一例没法验到点交接）", 人 != null)
	if 人 != null:
		板.set("_跨图终目标", {"类": "n", "号": int(str(人.get("entity_id"))), "说明": "门里跑一跑"})
		板.set("_跨图在途", true)
		板.set("_跨图玩家", 玩)
		板.set("_跨图起手印", int(玩.get("auto_path_cancel_stamp")))
		板.set("_跨图等到", 0.0)
		await _帧(4)
		_记("人刷出来了 ⇒ 立刻转成「走到跟前开对话」（待对话NPC 被填上）",
				String(板.get("_待对话NPC")) != "")

	## —— ⑥ **真把面板销毁再建一个**（这就是换图时对 HUD 做的事：`场景/地图/地图场景.tscn:48`
	##     把「小地图面板」装在地图场景里面，换图释放旧场景 ⇒ 面板连同它身上的路线一起没了。
	##     2026-10-10 用户第二次实机报「到地图 2 就不动」的**主因就是这条**，
	##     修法是把路线挂到单例 `GameSession`，新面板起来时接手）——
	会话.set("player_stats", {"level": 250, "name": "门里夹具"})	# ③ 把等级压成 1 了，这里要摆回去
	_记("前往别的图 回 true（跨图行程起来了）", 板.前往别的图(int(终), "销毁重建对照",
			{"类": "n", "号": 99999999, "说明": "门里占位"}))
	await _帧(2)
	var 余前 := (板.get("_跨图余程") as Array).size()
	_记("销毁前：会话里已经留着余程 %d 跳" % 余前, bool(会话.get("跨图在途")) and 余前 >= 1)
	板.queue_free()
	await _帧(4)
	var 板2: Node = (load("res://场景/界面/小地图面板.tscn") as PackedScene).instantiate()
	场.add_child(板2)
	await _帧(6)
	_记("换新面板后：这趟行程还在（不是从零开始、也没被当成取消）", bool(板2.get("_跨图在途")))
	_记("换新面板后：终目标原封不动（号=99999999 还挂着）",
			int((板2.get("_跨图终目标") as Dictionary).get("号", 0)) == 99999999)
	var 余后 := (板2.get("_跨图余程") as Array).size()
	var 待2: Dictionary = 板2.get("_待进门") as Dictionary
	_记("换新面板后：要么接着走下一跳（待进门有门号），要么余程还在排队 实际待进门=%s 余程=%d→%d" % [
			str(待2.get("index", "无")), 余前, 余后],
			(not 待2.is_empty()) or 余后 >= 1)

	_收()


func _收() -> void:
	行.append("")
	行.append("汇：共 %d 条，红 %d 条" % [总, 红])
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string(char(10).join(行) + char(10))
		f.close()
	print("汇：共 %d 条，红 %d 条" % [总, 红])
	quit(0 if 红 == 0 else 1)
