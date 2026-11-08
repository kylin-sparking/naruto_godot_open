extends SceneTree

## 任务系统**在线全链**门（2026-10-09 新建）。
##
## 走玩家真会走的那条路，每一步都断言**服务端回帧**，不接受本地自证：
##   A 交付链：`1003 初醒`（进游戏自动接上，目标是"去见 NPC 1"）
##             → 对话 → **翻台词(NEXT)** → 服务端 `_finish_original_quest_dialog`
##             → 目标计数 + 交付发奖 → 经验从服务端回帧里涨、任务离开已接、`1006` 进可接。
##   B 接取链：可接列表里挑一条**发任务 NPC 在本图**的 → 对话 → 翻完 → 进已接。
##   C 放弃链：对 B 那条发 `104:3` → 退回可接。
##
## ⚠ 这条门的存在理由：**"翻台词"那一跳以前根本没接** —— 客户端只会发 MENU=2，
##    从不发 NEXT=1，于是所有带作者台词的 NPC 任务永远停在"进行中"，接也接不上、
##    交也交不掉；而旧的 `任务在线回归测试` 只比"两份列表等不等"，**照不到这一层**。

var _已接: Array = []
var _可接: Array = []
var _进度帧: Array = []
var _对话帧 := 0
var _列表次数 := 0
var _发现: Array[String] = []
## 右下角「获得提示」这一路真收到了几条（离线门是喂合成帧测的，这里要**真服务端**的那一份）。
var _提示: Array[String] = []
var _表 := {}
var _backend: Node
var _会话: Node
## 原端口：本门**只许**在夹具给的独立端口上跑（用户那台 18684 上是他自己的号）。
var _原端口 := -1


func _initialize() -> void:
	call_deferred("_run")


func _等(pred: Callable, 毫秒 := 6000) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if bool(pred.call()):
			return true
		await create_timer(0.05).timeout
	return false


func _条(id: String) -> Dictionary:
	for 条 in _已接:
		if String((条 as Dictionary).get("id", "")) == id:
			return 条 as Dictionary
	return {}


func _在可接(id: String) -> bool:
	for 条 in _可接:
		if String((条 as Dictionary).get("id", "")) == id:
			return true
	return false


func _NPC(模板: int) -> Dictionary:
	for 号 in _backend.map_npcs:
		var 状: Dictionary = _backend.map_npcs[号]
		if int(状.get("npc_id", -1)) == 模板:
			return 状
	return {}


## 玩家点一行的完整跳数：对话(54) → 点任务行(57:3:<任务id>) → 逐句翻(57:1) 直到不再回帧。
## 返回实际翻了几句（0 = 服务端压根没给这枚 NPC 开任务对话）。
func _走任务行(模板: int, 任务号: int) -> int:
	## 换图/建图那一瞬间 `map_npcs` 可能还没铺满（实测：同一次到达里 `_NPC(41)` 先有、
	## 隔一拍再查就没有）⇒ 先等它出现，别直接当"这枚 NPC 不在这张图"。
	if _NPC(模板).is_empty():
		await _等(func(): return not _NPC(模板).is_empty(), 2500)
	var 身 := _NPC(模板)
	if 身.is_empty():
		return -1
	## ⚠ 54 的第一段是**场上那具 NPC 的 object_id**，不是模板号。服务端
	## `_resolve_talk_npc` 先按 object_id 认、认不到才按模板号兜底 ⇒ 直接发模板号
	## 可能撞上"对象号恰好等于该模板号"的另一具 NPC（实测 1180 在波之国大桥：
	## 选任务行后只回默认对话、任务一步没推）。这里按 `map_npcs` 里那具实体的对象号发。
	var 对象号 := int(身.get("object_id", 0))
	_backend.request_npc_dialog(对象号 if 对象号 > 0 else 模板)
	await create_timer(0.4).timeout
	var 对话前 := _对话帧
	_backend.request_npc_selection(任务号)
	await create_timer(0.4).timeout
	var 翻 := 0
	while 翻 < 12:
		var 起点 := _对话帧
		_backend.request_npc_next()
		await create_timer(0.4).timeout
		if _对话帧 == 起点:
			break
		翻 += 1
	print("   （54 之后对话帧 %d，点行之后 %d，翻了 %d 句）" % [对话前, _对话帧, 翻])
	return 翻


func _run() -> void:
	_backend = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _backend == null or _会话 == null:
		print("任务全链在线：缺单例，无法跑")
		quit(1)
		return
	_backend.quest_list_received.connect(func(a: Array, b: Array):
		_已接 = a
		_可接 = b
		_列表次数 += 1)
	_backend.quest_progress_received.connect(func(信: Dictionary): _进度帧.append(信))
	_backend.npc_dialog_received.connect(func(_a: int, _b: String): _对话帧 += 1)
	## 右下角「获得提示」：离线门是喂合成帧测的，这一路要**真服务端**发出来的那一份。
	if _backend.has_signal("获得提示"):
		_backend.connect("获得提示", func(文: String): _提示.append(文))
	_表 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/任务.json"))
	## ⚠ 端口必须由夹具给（`NARUTO_SERVER_PORT`），否则本门去连 18684 ——
	##   那是**用户自己**那台、跑的也是他的号（10-25 现查：18684 是 `.fixture-play` 的 python 服务端）。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 <= 0:
		print("任务全链在线：缺 NARUTO_SERVER_PORT（只许在夹具上跑，别连用户那台）")
		quit(2)
		return
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_backend.sync_character()
	if not await _等(func(): return bool(_backend.in_game), 15000):
		print("任务全链在线：没进游戏 %s - %s" % [_backend.status, _backend.detail])
		_还原端口()
		quit(1)
		return
	var 起点 := _列表次数
	await _等(func(): return _列表次数 >= 起点 + 2, 8000)
	print("进游戏：已接 %d / 可接 %d" % [_已接.size(), _可接.size()])

	# ================= A 交付链：1003 初醒 =================
	var 经验前 := int(_backend.authoritative_stats.get("exp", 0))
	var 有1003 := not _条("1003").is_empty()
	print("A 1003 开局：%s（条目=%s）" % ["进行中" if 有1003 else "不在已接", JSON.stringify(_条("1003"))])
	if not 有1003:
		_发现.append("A 服务端没把 1003 自动接上（`_start_automatic_original_quests` 只接 start_npc==0 的）")
	else:
		var 翻 := await _走任务行(1, 1003)
		if 翻 < 0:
			_发现.append("A 本图找不到交付 NPC（模板 1）")
		elif 翻 == 0:
			_发现.append("A 点了 1003 这行后服务端一句台词都没回（57:3 没被接住？）")
	# 翻没翻成都照实核对：翻不成时下面每条断言各自红，指得出断在哪一跳
		if not await _等(func(): return _条("1003").is_empty(), 6000):
			_发现.append("A 翻完对话后 1003 还在已接列表里（交付没生效）")
		var 经验后 := int(_backend.authoritative_stats.get("exp", 0))
		print("A 经验 %d → %d（1003 的 act.1.exp = 50）" % [经验前, 经验后])
		if 经验后 <= 经验前:
			_发现.append("A 交完任务经验没涨：服务端奖励没落到 authoritative_stats（或压根没发）")
		await create_timer(0.5).timeout
		if not _在可接("1006"):
			_发现.append("A 交完 1003 后 1006 没进可接（前置链断）")

	# ================= B 接取链：挑一条发任务 NPC 在本图的可接任务 =================
	var 选 := ""
	var 选模板 := -1
	for 条 in _可接:
		var id := String((条 as Dictionary).get("id", ""))
		if not _表.has(id):
			continue
		var 定: Dictionary = _表[id]
		选模板 = int((定.get("npc", {}) as Dictionary).get("0", -1))
		if 选模板 >= 0 and not _NPC(选模板).is_empty():
			选 = id
			break
	if 选 == "":
		_发现.append("B 可接列表里没有一条的发任务 NPC 在本图（本图 NPC 模板=%s，可接=%s）" % [
				_本图NPC(), _前若干(_可接)])
	else:
		print("B 试接 %s（发任务 NPC 模板 %d）" % [选, 选模板])
		var 翻B := await _走任务行(选模板, int(选))
		if 翻B < 0:
			_发现.append("B 本图找不到 %s 的发任务 NPC（模板 %d）" % [选, 选模板])
		if not await _等(func(): return not _条(选).is_empty(), 6000):
			_发现.append("B 翻完 %s 的对话后没进已接列表（START 没生效）" % 选)
		else:
			print("B 接成功：%s" % JSON.stringify(_条(选)))
			# ============ B2 接完之后往哪走（#144 = 原版 `getQuestPoint()`）============
			## 离线门用自造的定义表验算式；这里补的是**真服务端形状**那一条：
			## 刚接上的条目（`444:3` 折出来的，里面只有 id/状态/进度、没有目标字段）
			## 喂进算式，必须仍然算得出与静态定义一致的档 —— 否则会静默不赶路（10-09 那个根因）。
			var 板: Node = (load("res://脚本/界面/小地图面板.gd") as GDScript).new()
			var 定B: Dictionary = _表[选] as Dictionary
			var 目: Array = 板.call("_寻路目标", _条(选), 定B) as Array
			var 阶B: Variant = (定B.get("check", {}) as Dictionary).get("1", {})
			var 怪列: Array = []
			if 阶B is Dictionary:
				var 怪段: Variant = (阶B as Dictionary).get("mob", {})
				if 怪段 is Dictionary:
					for v in (怪段 as Dictionary).values():
						怪列.append(v)
				elif 怪段 is Array:
					怪列 = 怪段
			if 怪列.size() > 0:
				var 首怪: Dictionary = 怪列[0] as Dictionary
				var 对: bool = 目.size() == 3 and int(目[0]) == 2
				对 = 对 and int(目[1]) == int(首怪.get("id", 0))
				对 = 对 and int(目[2]) == int(首怪.get("map", 0))
				if not 对:
					_发现.append("B2 红：%s 有怪目标，算式应得 [2,%d,%d]，实得 %s" % [
							选, int(首怪.get("id", 0)), int(首怪.get("map", 0)), str(目)])
			elif not (目.size() == 3 and int(目[1]) > 0):
				_发现.append("B2 红：%s 算不出可走的目标（实得 %s）" % [选, str(目)])
			print("B2 %s 的自动赶路目标 = %s" % [选, str(目)])
			板.free()
			# ============ C 放弃链 ============
			if not _会话.forfeit_quest(选):
				_发现.append("C forfeit_quest('%s') 返回 false" % 选)
			elif not await _等(func(): return _条(选).is_empty() and _在可接(选), 6000):
				_发现.append("C 发了 104:3 之后 %s 没退回可接" % 选)
			else:
				print("C 放弃后 %s 退回可接" % 选)

	# ============ D 主线能一路推到哪（**只报数、不判红**：卡住的那一环往往是"要跨图"）============
	var 走过 := await _推链(14)
	print("D 主线推进 %d 步：%s" % [走过.size(), ", ".join(走过)])
	var 剩: Array[String] = []
	for 条 in _已接:
		剩.append(String((条 as Dictionary).get("id", "?")))
	print("D 结束时仍挂着：%s（卡住的那环通常是目标怪在别的图 —— 跨图赶路未接）" % ", ".join(剩))
	# ===== E 杀怪目标：跨图**一跳**进《浅滩森林》→ 打掉一只 1000001 → 看服务端推不推 1018 的进度帧 =====
	# 这一环是**整条链里唯一要真打怪**的：证明的不是"能不能打死"，而是
	# 「杀怪 → 服务端 `_advance_original_quests(MONSTER)` → 444 进度帧」这一段接没接上。
	var 原图 := int(_backend.authoritative_map_id)
	if _条("1018").is_empty():
		print("E 跳过：1018 没接到（D 步没推到那儿）")
	else:
		var 帧前 := _进度帧.size()
		if not _backend.request_portal_enter(1):
			_发现.append("E 发不出进门包（request_portal_enter(1) 返回 false）")
		elif not await _等(func(): return int(_backend.authoritative_map_id) == 101020000, 15000):
			_发现.append("E 进了门却没到《浅滩森林》，现在在 %s" % str(_backend.authoritative_map_id))
		else:
			print("E 已跨图到《浅滩森林》(101020000)，本图怪 %d 只" % _backend.map_monsters.size())
			var 打掉 := 0
			for 轮 in 90:
				var 号 := _挑一只(1000001)
				if 号 == 0:
					await create_timer(0.6).timeout
					continue
				for 刀 in 14:
					var 状: Dictionary = _backend.map_monsters.get(号, {})
					if 状.is_empty():
						打掉 += 1
						break
					_backend.send_movement(Vector2(float(状.get("x", 0)) - 12.0, float(状.get("y", 0))), 1)
					await create_timer(0.06).timeout
					_backend.request_basic_attack(号,
							Vector2(float(状.get("x", 0)), float(状.get("y", 0))),
							1 if 刀 % 2 == 0 else -1)
					await create_timer(0.24).timeout
				if 打掉 >= 3:
					break
			await create_timer(1.2).timeout
			print("E 打掉 %d 只；1018 条目=%s；新增进度帧 %d 条" % [
					打掉, JSON.stringify(_条("1018")), _进度帧.size() - 帧前])
			var 新帧: Array = _进度帧.slice(帧前)
			var 有1018 := false
			for 帧 in 新帧:
				if String((帧 as Dictionary).get("id", "")) == "1018":
					有1018 = true
			if 打掉 == 0:
				_发现.append("E 90 轮没打掉任何一只 1000001（本图刷怪太少/太远）")
			elif not 有1018:
				_发现.append("E 打掉了 %d 只怪，服务端却没推 1018 的进度帧（杀怪→任务推进那段断了）" % 打掉)
	# ============ F 打完怪再推一轮 ============
	## 1018 交掉才会接上 **1021（第一条带金币的主线：money=150 / exp=120）**，
	## 金币那一档在 D 那轮永远测不到。E 已经把人带到《浅滩森林》，而 1018 的交付 NPC
	## 在原来那张图 ⇒ 先按目标图反查一扇门回去（`request_map_change` 内部就是 `_find_portal_to_map`），
	## 再推一轮，产出同样进 R 那张表。
	if 原图 > 0 and int(_backend.authoritative_map_id) != 原图:
		if not _backend.request_map_change(原图, 0, 0):
			_发现.append("F 回不去原图 %d（本图没找到指向它的门）⇒ 金币那一档本轮没测到" % 原图)
		elif not await _等(func(): return int(_backend.authoritative_map_id) == 原图, 15000):
			_发现.append("F 发了换图包却没回到 %d，现在在 %s" % [原图, str(_backend.authoritative_map_id)])
		else:
			print("F 回到原图 %d" % 原图)
			## 换图后本图 NPC 是服务端**逐枚生成包**推来的，`authoritative_map_id` 先到、
			## NPC 列表后满 ⇒ 不等一下就等于"这张图没人"，`_推链` 会一条都不做（实测 F 推 0 步）。
			if not await _等(func(): return not _NPC(3).is_empty(), 10000):
				_发现.append("F 回图 10 秒还没等到交付 NPC 模板 3（本图 NPC=%s）⇒ 金币那一档没测到" % _本图NPC())
			var 挂: Array[String] = []
			for 条 in _已接:
				挂.append("%s(%s)" % [String((条 as Dictionary).get("id", "?")),
						"可交" if bool((条 as Dictionary).get("completed", false)) else "进行中"])
			print("F 开局已接：%s" % ", ".join(挂))
	var 走过F := await _推链(8)
	print("F 打完怪再推 %d 步：%s" % [走过F.size(), ", ".join(走过F)])
	print("进度帧 %d 条：%s" % [_进度帧.size(), JSON.stringify(_进度帧.slice(0, 3))])

	# ============ G 跨图续接（10-25）：主线在 F 之后卡住，多半是下一环的 NPC 在别的图 ============
	## 原版玩家点追踪栏那一行，客户端 `MOVETO_NPCMAP(4027)` 把人送到 NPC 所在图再自动对话
	## （`request_move_to_npc_map`，服务端 `handle_move_to_npc_map` 校验 NPC 在该图后 `_warp_to_map`
	##  + `auto_talk`）。本段就按同一条协议往前走，直到卡在**非 NPC 目标**（杀怪/买物/捕捉）为止。
	## ⚠ NPC 模板号 → 地图 用原版那张表（`原版富文本.NPC所在地图`，1..75 全有）。
	var 跨图次数 := 0
	var 卡在 := {}
	## 轮数是**安全网**，不是节拍：整条主线 131 环，一轮能推 1~4 步
	## （交+接+同图补目标），跑到最后大约要一百多轮。真卡住时下面的 break 会先收工。
	for 轮 in 600:
		var 点 := _下一个可动()
		if 点.is_empty():
			## 没有"换图找 NPC"能推进的事 ⇒ 卡住的多半是杀怪/买物/捕捉。
			## 先按目标类型补一次（杀怪/找 NPC 买）；补不动才收工。
			var 补 := await _补当前目标()
			if 补:
				走过.append_array(补)
				continue
			## ⚠ 补不动有两种：**真卡住**（还有已接未完成的主线）与**整条主线跑完了**
			## （1393 交完后再也找不到目标）。后者是正常收工，别记成红。
			var 还挂 := false
			for 序 in _主线序():
				var 条 := _条(序)
				if not 条.is_empty() and not bool((条 as Dictionary).get("completed", false)):
					还挂 = true
					break
			if 还挂:
				卡在 = {"原因": "当前目标补不动（见上一条）", "点": {}}
			else:
				print("G 主线：已接里没有未完成的主线任务，可接也没有能推的 ⇒ 全链跑完，正常收工")
			break
		var 图 := int(点.get("map", 0))
		var 号 := int(点.get("npc", 0))
		if 图 <= 0:
			卡在 = {"原因": "NPC %d 查不到所在地图" % 号, "点": 点}
			break
		if 图 == int(_backend.authoritative_map_id):
			## 同图的交/接本来该由 `_推链` 做；它推不动才是真的卡住（杀怪/买物/捕捉就在同图）。
			var 步1 := await _推链(4)
			if not 步1.is_empty():
				走过.append_array(步1)
				continue
			## 同图但这一环是**非 NPC 目标**（杀怪/收集/捕捉）⇒ 当场补，别当卡住收工。
			var 补 := await _补当前目标()
			if 补:
				走过.append_array(补)
				continue
			卡在 = {"原因": "同图动作推不动", "点": 点}
			break
		## 优先 MOVETO_NPCMAP（一步到 NPC 旁）；没有引路 NPC 或它没送到时，
		## `_传送到` 会按原版传送门 BFS 走过去（实测：101030000 没有 NPC，只能走门回 101010000）。
		if not await _传送到(图):
			卡在 = {"原因": "换图到 %d 失败（现在 %s）" % [图, str(_backend.authoritative_map_id)], "点": 点}
			break
		if not await _等(func(): return not _NPC(号).is_empty(), 10000):
			卡在 = {"原因": "到图 %d 后没等到 NPC %d（本图=%s）" % [图, 号, _本图NPC()], "点": 点}
			break
		var 步2 := await _推链(4)
		走过.append_array(步2)
		print("G 跨图 #%d → %d 找 NPC %d（%s），推了 %d 步：%s" % [
			跨图次数 + 1, 图, 号, String(点.get("动作", "")), 步2.size(), ", ".join(步2)])
		if 步2.is_empty():
			卡在 = {"原因": "到了 NPC %d 的图却推不动（动作=%s）" % [号, String(点.get("动作", ""))], "点": 点}
			break
		跨图次数 += 1
	print("G 跨图 %d 次；累计推进 %d 步" % [跨图次数, 走过.size()])
	if not 卡在.is_empty():
		print("G 卡在：%s；点=%s" % [String(卡在.get("原因", "")), JSON.stringify(卡在.get("点", {}))])
		_发现.append("G 主线卡在「%s」：%s" % [
			String((_表.get(String((卡在.get("点", {}) as Dictionary).get("id", "")), {}) as Dictionary).get("info", {}).get("name", "?")),
			String(卡在.get("原因", ""))])
	## 主线的**路标**：按链路顺序数已交到第几条（只报数，不判红）。
	var 交过 := {}
	for 步 in 走过:
		if String(步).begins_with("交"):
			交过[String(步).substr(1)] = true
	var 已交 := 0
	var 最高 := ""
	for 序 in _主线序():
		if 交过.has(序):
			已交 += 1
			最高 = 序
		else:
			break
	print("G 主线路标：连续交掉 %d 条（最高到 %s）" % [已交, 最高])

	print("右下角「获得提示」真收到 %d 条：%s" % [_提示.size(), " / ".join(_提示)])
	## 逐档点名：这一局里 经验 / 金币 / 道具 三档是不是**各**至少报了一条（少一档 = 那条 producer
	## 在真服务端下没通，光看条数看不出来）。
	## ⚠ **道具那一档只在"本局交付过带道具奖励的任务"时才要求**：整局都是经验/金币时
	## 一条「获得了」都不该出现 —— 旧写法按"每局必须有"判，会把正常局判红（实测 run8）。
	var 有物奖 := false
	for 行 in 奖表:
		if not (行["期物"] as Dictionary).is_empty():
			有物奖 = true
			break
	var 档表: Array = ["[color=#00cc33]经验 ", "[color=#00cc33]金币 "]
	if 有物奖:
		档表.append("获得了")
	for 档 in 档表:
		var 中 := 0
		for 条 in _提示:
			if (条 as String).contains(档):
				中 += 1
		if 中 == 0:
			_发现.append("「%s」这一档整局一条都没报（共 %d 条里 0 条）" % [档, _提示.size()])
		else:
			print("   其中含「%s」%d 条" % [档, 中])
	if _提示.is_empty():
		_发现.append("整局跑完一条「获得提示」都没收到 ⇒ 属性差值/背包那两条 producer 在**真服务端**下没通"
			+ "（离线门只喂了合成帧，照不到这一层）")
	_判奖()
	print("")
	if _发现.is_empty():
		print("任务全链在线回归测试：通过（交付发奖 / 前置链 / 对话接取 / 放弃 全部走服务端）")
		_backend.disconnect_backend()
		_还原端口()
		quit(0)
		return
	for 项 in _发现:
		push_error("全链：%s" % 项)
	print("任务全链在线回归测试：失败 %d 处 —— %s" % [_发现.size(), " | ".join(_发现)])
	_backend.disconnect_backend()
	_还原端口()
	quit(1)


## ── 奖励到账核对（#171）────────────────────────────────────────────
## 每条**真交付掉**的任务记一行：`数据/任务.json` 的 `act["1"]` 期望 vs 服务端回帧实得。
## 判据故意用"至少到账"而不是"精确相等"：经验会被升级消耗掉、金币会被途中拾取加进去，
## 拿等号判会把环境噪声判成红；但**期望 > 0 而实得 0** 就是漏发，那一条必须红。
## D / F 共用：反复「能交就交、能接就接」把主线往前推，返回走过的步。
## 每交掉一条就顺手记一行奖励核对（`_记奖`）⇒ 这条链推得越远，#171 的证据越厚。
func _推链(轮数: int) -> Array[String]:
	var 走过: Array[String] = []
	for 轮 in 轮数:
		var 动过 := false
		# 先交：已接里能交的（交付 NPC 在本图）
		for 条 in _已接.duplicate():
			var id := String((条 as Dictionary).get("id", ""))
			if not _表.has(id):
				continue
			var 交 := int((( _表[id] as Dictionary).get("npc", {}) as Dictionary).get("1", 0))
			if 交 <= 0:
				continue
			if _NPC(交).is_empty():
				await _等(func(): return not _NPC(交).is_empty(), 1500)
			if _NPC(交).is_empty():
				continue
			var 奖前 := _快照()
			## 以前这里写的是 `completed ⇒ continue`，等于把**最该交的那批**跳过了
			## ⇒ 1018（杀怪攒满的）永远交不掉，金币那一档（1021 money=150）也就永远测不到。
			## 攒满没攒满都先走玩家那条路：54 开对话 → 57:3 点这一行 → 逐句翻。
			await _走任务行(交, int(id))
			await create_timer(0.4).timeout
			if _条(id).is_empty():
				走过.append("交" + id)
				动过 = true
				await _记奖(id, 奖前)
			elif bool((条 as Dictionary).get("completed", false)):
				## 翻完还没提交 ⇒ 补一次「站到交付 NPC 旁点『完成任务』」
				## （`QUEST_ACTION 2` = `游戏会话.claim_quest_reward`，与对话窗那颗钮同一个入口；
				##   服务端 `handle_quest_action` 要求 活跃NPC == 交付NPC，上面那句 54 已经把它设好）
				_会话.claim_quest_reward(id)
				await create_timer(0.8).timeout
				if _条(id).is_empty():
					走过.append("交" + id)
					动过 = true
					await _记奖(id, 奖前)
		# 再接：可接里发任务 NPC 在本图的
		for 条 in _可接.duplicate():
			var id2 := String((条 as Dictionary).get("id", ""))
			if not _表.has(id2) or not _条(id2).is_empty():
				continue
			var 发 := int(((_表[id2] as Dictionary).get("npc", {}) as Dictionary).get("0", 0))
			if 发 <= 0:
				continue
			if _NPC(发).is_empty():
				await _等(func(): return not _NPC(发).is_empty(), 1500)
			if _NPC(发).is_empty():
				continue
			await _走任务行(发, int(id2))
			await create_timer(0.4).timeout
			if not _条(id2).is_empty():
				走过.append("接" + id2)
				动过 = true
		if not 动过:
			break
	return 走过


var 奖表: Array = []


func _快照() -> Dictionary:
	var 背 := {}
	for 物 in _backend.authoritative_inventory:
		var 号 := String((物 as Dictionary).get("id", ""))
		背[号] = int(背.get(号, 0)) + int((物 as Dictionary).get("quantity", 0))
	return {"exp": int(_backend.authoritative_stats.get("exp", 0)),
			"gold": int(_backend.authoritative_stats.get("gold", 0)),
			"level": int(_backend.authoritative_stats.get("level", 0)), "背": 背}


## 表里期望的道具（含职业过滤）。原版口径 `QuestInfoData.getEncourage:271-292`：
## **没写 job 这个键**才是不限职业；写了 job 就必须等于玩家职业（服务端
## `fake_flash_server.py:56646` 的 `reward.job in (0, 职业)` 与它一致）。
func _期望道具(定: Dictionary) -> Dictionary:
	var a := _act1(定)
	var 职 := int(_backend.authoritative_stats.get("job", 0))
	var 出 := {}
	for 组 in ["item", "equip"]:
		var 段 = a.get(组)
		if not (段 is Dictionary):
			continue
		for v in (段 as Dictionary).values():
			if not (v is Dictionary):
				continue
			var d: Dictionary = v
			if d.has("job") and int(d.get("job", 0)) != 0 and int(d["job"]) != 职:
				continue
			var 号 := str(int(d.get("id", 0)))
			出[号] = int(出.get(号, 0)) + int(d.get("count", 1))
	return 出


func _记奖(id: String, 前: Dictionary) -> void:
	## 等一拍的理由：`_send_stats` 与背包增量帧排在交付那批帧**之后**，
	## 立刻取快照会拿到"钱还没到账"的假零 —— 那是量具错，不是服务端错。
	await create_timer(0.6).timeout
	var 定: Dictionary = _表.get(id, {})
	var a := _act1(定)
	var 后 := _快照()
	var 期物 := _期望道具(定)
	var 实物 := {}
	for 号 in 期物.keys():
		实物[号] = int(后["背"].get(号, 0)) - int(前["背"].get(号, 0))
	## ⚠ 收集类任务**会把交上去的物品吃掉**（1024 交 1 个拉面、奖励 20 个 ⇒ 净增 19）。
	## 判"漏发"之前要把任务消耗加回去，否则天天报假红。
	var 消耗 := _任务消耗物(定)
	for 号 in 消耗.keys():
		实物[号] = int(实物.get(号, 0)) + int(消耗[号])
	奖表.append({"id": id, "期exp": int(a.get("exp", 0)), "实exp": int(后["exp"]) - int(前["exp"]),
			"级前": int(前["level"]), "级后": int(后["level"]),
			"期gold": int(a.get("money", 0)), "实gold": int(后["gold"]) - int(前["gold"]),
			"期物": 期物, "实物": 实物, "消耗": 消耗})


## 任务完成时**要交出去**的物品（`check[1]` 的 item/equip/useitem 目标 × count）。
func _任务消耗物(定: Dictionary) -> Dictionary:
	var c1 = (定.get("check", {}) as Dictionary).get("1", {})
	var 出 := {}
	if not (c1 is Dictionary):
		return 出
	for 键 in ["item", "equip", "useitem"]:
		for o in _取列((c1 as Dictionary).get(键, {})):
			if not (o is Dictionary):
				continue
			var 号 := int((o as Dictionary).get("id", 0))
			if 号 <= 0:
				continue
			## ⚠ 键必须是**字符串**：`_快照` 与 `_期望道具` 都用 `str(物品号)` 作键。
			##   这里写 int 会另开一个 int 键 ⇒ `实物` 里同一个物品出现两行（JSON 里同名），
			##   而 `_判奖` 按字符串键取值只看到没补偿的那份（1024 拉面 19/20 就是这么来的）。
			出[str(号)] = int(出.get(str(号), 0)) + maxi(1, int((o as Dictionary).get("count", 1)))
	return 出


## `act` 段有两层：`{"0": 接取时给, "1": 完成时给}`，**只有 "1" 有内容**（全表 214 条实测，
## "0" 一律是 {}）。取法要一层层判类型 —— GDScript 的 `or` 返回 bool，不能当 Python 用。
func _act1(定: Dictionary) -> Dictionary:
	var 段 = 定.get("act")
	if not (段 is Dictionary):
		return {}
	var 二 = (段 as Dictionary).get("1")
	return 二 if 二 is Dictionary else {}


func _判奖() -> void:
	print("R 奖励到账核对（交付 %d 条）：" % 奖表.size())
	for 行 in 奖表:
		print("   %s exp %d→+%d（升级 %d→%d）gold +%d（期望 %d）道具 %s 实得 %s" % [
			String(行["id"]), int(行["期exp"]), int(行["实exp"]), int(行["级前"]), int(行["级后"]),
			int(行["实gold"]), int(行["期gold"]), JSON.stringify(行["期物"]), JSON.stringify(行["实物"])])
		if int(行["期exp"]) > 0 and int(行["实exp"]) <= 0 and int(行["级后"]) <= int(行["级前"]):
			_发现.append("R %s 表里写经验 %d，交付后既没涨经验也没升级" % [行["id"], int(行["期exp"])])
		if int(行["期gold"]) > 0 and int(行["实gold"]) < int(行["期gold"]):
			_发现.append("R %s 表里写金币 %d，实得只涨 %d（漏发或没落到 gold 这条 stat）" % [
					行["id"], int(行["期gold"]), int(行["实gold"])])
		for 号 in (行["期物"] as Dictionary).keys():
			if int((行["实物"] as Dictionary).get(号, 0)) < int((行["期物"] as Dictionary)[号]):
				_发现.append("R %s 奖励道具 %s 期望进背包 %d，实得 %d" % [
						行["id"], 号, int((行["期物"] as Dictionary)[号]),
						int((行["实物"] as Dictionary).get(号, 0))])


func _前若干(列: Array) -> String:
	var 出: Array[String] = []
	for i in mini(12, 列.size()):
		出.append(String((列[i] as Dictionary).get("id", "?")))
	return ", ".join(出)


func _本图NPC() -> String:
	var 出: Array[String] = []
	for 号 in _backend.map_npcs:
		出.append(str((_backend.map_npcs[号] as Dictionary).get("npc_id")))
	return ", ".join(出)


func _挑一只(模板: int) -> int:
	for 号 in _backend.map_monsters:
		if int((_backend.map_monsters[号] as Dictionary).get("monster_id", 0)) == 模板:
			return int(号)
	return 0


## 主线链路（只取 `info.type == "trunk"`，按 id 升序；表里的前置链天然就是这条序）。
func _主线序() -> Array[String]:
	var 出: Array[String] = []
	for 号 in _表.keys():
		var 定: Dictionary = _表[号]
		var info = 定.get("info")
		if info is Dictionary and String((info as Dictionary).get("type", "")) == "trunk":
			出.append(String(号))
	出.sort_custom(func(a, b): return int(a) < int(b))
	return 出


## NPC 模板号 → 所在地图。原版那张 1..75 的表在 `原版富文本.NPC所在地图`（别另抄一份）。
const 富文本 := preload("res://素材/界面/任务界面/脚本/原版富文本.gd")

func _NPC图(模板: int) -> int:
	if 模板 <= 0:
		return 0
	return int(富文本._所在地图("%08d" % 模板))


## 下一件**能靠换图推进**的事：可交 → 找 NPC 目标 → 可接。
## 找不到就返回空（此时卡住的必然是杀怪/买物/捕捉这类要在本图做的目标）。
func _下一个可动() -> Dictionary:
	for 序 in _主线序():
		var 条 := _条(序)
		if 条.is_empty():
			continue
		var 定: Dictionary = _表.get(序, {})
		if bool(条.get("completed", false)):
			var 交 := int((定.get("npc", {}) as Dictionary).get("1", 0))
			if 交 > 0:
				return {"动作": "交", "id": 序, "npc": 交, "map": _NPC图(交)}
		## 已接但没完成：目标里有 npc 的，去那枚 NPC 那里。
		## ⚠ **已经说过话的那枚要跳过** —— 否则在它身上原地打转，后面那几档杀怪/收集
		## 永远轮不到（实测 1204「玉碎梦破」：找 43 的目标已达成、还差 4 只形态怪，
		## 自动机却一直把「找 43」当下一件事，推链推不动就收工）。
		var c1 = (定.get("check", {}) as Dictionary).get("1", {})
		if c1 is Dictionary:
			for n in _取列((c1 as Dictionary).get("npc", {})):
				var 号 := int((n as Dictionary).get("id", 0))
				if 号 <= 0:
					continue
				if _目标已够(条, "npc", 号, maxi(1, int((n as Dictionary).get("count", 1)))):
					continue
				return {"动作": "找", "id": 序, "npc": 号, "map": _NPC图(号)}
	for 序 in _主线序():
		if _在可接(序):
			var 定2: Dictionary = _表.get(序, {})
			var 发 := int((定2.get("npc", {}) as Dictionary).get("0", 0))
			if 发 > 0:
				return {"动作": "接", "id": 序, "npc": 发, "map": _NPC图(发)}
	return {}


## 这条 444 条目上的某个目标是否已经攒够（进度键 = `kind:key`，见 `_当前目标`）。
func _目标已够(条: Dictionary, 类: String, 号: int, 需: int) -> bool:
	for p in (条.get("目标进度", []) as Array):
		if not (p is Dictionary):
			continue
		if String((p as Dictionary).get("kind", "")) != 类:
			continue
		if int(String((p as Dictionary).get("key", "0"))) != 号:
			continue
		return int((p as Dictionary).get("curr", 0)) >= 需
	return false


func _取列(值: Variant) -> Array:
	if 值 is Dictionary:
		var 出: Array = []
		for k in (值 as Dictionary).keys():
			出.append((值 as Dictionary)[k])
		return 出
	if 值 is Array:
		return 值
	return []


func _还原端口() -> void:
	if _会话 == null or _原端口 < 0:
		return
	var 设置 = _会话.get("game_settings")
	if 设置 is Dictionary:
		(设置 as Dictionary)["backend_port"] = _原端口


## 地图 → 一枚在该图的 NPC 模板（`MOVETO_NPCMAP` 需要"目标图里有这枚 NPC"才肯传）。
## 数据同源：`数据/界面/NPC所在地图.json`（从地图 life 现扫）。
static var _反查表: Dictionary = {}

func _该图的NPC(图: int) -> int:
	if _反查表.is_empty():
		var 原 := FileAccess.get_file_as_string("res://数据/界面/NPC所在地图.json")
		var 解析 = JSON.parse_string(原)
		if 解析 is Dictionary:
			for 键 in ((解析 as Dictionary).get("表", {}) as Dictionary):
				for m in ((解析 as Dictionary)["表"][键] as Array):
					var 号 := int(m)
					if 号 > 0 and not _反查表.has(号):
						_反查表[号] = int(String(键))
	return int(_反查表.get(图, 0))


## 当前第一条已接主线的**第一个未完成目标**（按 mob/item/equip/useitem/pet/npc 顺序）。
func _当前目标() -> Dictionary:
	for 序 in _主线序():
		var 条 := _条(序)
		if 条.is_empty() or bool(条.get("completed", false)):
			continue
		var 定: Dictionary = _表.get(序, {})
		var c1 = (定.get("check", {}) as Dictionary).get("1", {})
		if not (c1 is Dictionary):
			continue
		## 运行期进度：`444:3` 折出 `目标进度: [{kind,key,curr,count}]`
		var 进度 := {}
		for p in (条.get("目标进度", []) as Array):
			if p is Dictionary:
				进度["%s:%s" % [String((p as Dictionary).get("kind", "")), String((p as Dictionary).get("key", ""))]] = p
		for 键 in ["mob", "item", "equip", "useitem", "pet"]:
			for o in _取列((c1 as Dictionary).get(键, {})):
				if not (o is Dictionary):
					continue
				var 号 := int((o as Dictionary).get("id", 0))
				if 号 <= 0:
					continue
				var 需 := maxi(1, int((o as Dictionary).get("count", 1)))
				var 有 := 0
				var p2 = 进度.get("%s:%d" % [键, 号])
				if p2 is Dictionary:
					有 = int((p2 as Dictionary).get("curr", 0))
				if 有 >= 需:
					continue
				return {
					"quest": 序, "kind": 键, "id": 号, "count": 需, "curr": 有,
					"map": int((o as Dictionary).get("map", 0)),
					"npc": int((o as Dictionary).get("npc", 0)),
					"mob": int((o as Dictionary).get("mob", 0)),
				}
	return {}


## 补一个非 NPC 目标：杀怪 / 找 NPC 买 / 捕捉。成功返回 ["打X只…"] 之类，失败返回空。
func _补当前目标() -> Array[String]:
	var 目标 := _当前目标()
	if 目标.is_empty():
		print("G 补目标：没有可补的已接主线目标")
		return []
	var 类 := String(目标.get("kind", ""))
	var 图 := int(目标.get("map", 0))
	var 怪 := int(目标.get("id", 0))
	var 缺 := maxi(1, int(目标.get("count", 1)) - int(目标.get("curr", 0)))
	print("G 补目标：任务 %s 目标 %s:%d 还差 %d（图=%d npc=%d 源怪=%d）" % [
		String(目标.get("quest", "")), 类, 怪, 缺, 图, int(目标.get("npc", 0)), int(目标.get("mob", 0))])
	match 类:
		"mob":
			if 图 <= 0:
				print("G 补目标：杀怪目标没写地图")
				return []
			return await _去杀(图, 怪, 缺)
		"item", "equip", "useitem":
			var 卖 := int(目标.get("npc", 0))
			if 卖 > 0:
				return await _去买(卖, 怪, 缺)
			var 源 := int(目标.get("mob", 0))
			if 源 > 0 and 图 > 0:
				return await _去杀(图, 源, 缺, 怪)
			print("G 补目标：物品 %d 既没有 NPC 也没写源怪/图" % 怪)
			return []
		"pet":
			if 图 <= 0:
				print("G 补目标：捕捉目标没写地图")
				return []
			return await _去捕(图, 怪)
		_:
			print("G 补目标：这一档（%s）还不会补" % 类)
			return []


## 传送到某图（借该图的一枚 NPC 走 `MOVETO_NPCMAP`；没有 NPC 的图按**原版传送门**走）。
func _传送到(图: int) -> bool:
	if 图 <= 0 or int(_backend.authoritative_map_id) == 图:
		return true
	var 引路 := _该图的NPC(图)
	if 引路 > 0:
		## MOVETO 偶尔会被服务端静默忽略（实测 105020000→105030000 一次没送到）；
		## 再发一次，仍不送就改走原版传送门 BFS —— 别一次失败就整条链收工。
		for 试 in 2:
			if not _backend.request_move_to_npc_map(引路, 图, 0, false, false):
				print("G 传送到 %d：发不出包" % 图)
				break
			if await _等(func(): return int(_backend.authoritative_map_id) == 图, 12000):
				await _等(func(): return not _NPC(引路).is_empty(), 8000)
				return true
			print("G 传送到 %d：第 %d 次 MOVETO 12 秒没到（现在 %s）" % [
				图, 试 + 1, str(_backend.authoritative_map_id)])
			await create_timer(0.6).timeout
		print("G 传送到 %d：MOVETO 没送到，改走门" % 图)
	if await _走门(图):
		return true
	## 长会话偶发"包发得出去、服务端不再回任何帧"（整段 TCP 半死：同一跳换个新会话就过）。
	## 重连一次再试 —— 与玩家掉线重进同一条路，不跳步、不改服务端。
	print("G 传送到 %d：MOVETO 与门户都没反应 ⇒ 重连后再试一次" % 图)
	_backend.disconnect_backend()
	await create_timer(0.5).timeout
	_backend.sync_character()
	if not await _等(func(): return bool(_backend.in_game), 20000):
		print("G 传送到 %d：重连没进游戏（%s - %s）" % [图, str(_backend.status), str(_backend.detail)])
		return false
	await _等(func(): return not _已接.is_empty(), 8000)
	if 引路 > 0:
		if _backend.request_move_to_npc_map(引路, 图, 0, false, false) and await _等(
				func(): return int(_backend.authoritative_map_id) == 图, 12000):
			await _等(func(): return not _NPC(引路).is_empty(), 8000)
			return true
	return await _走门(图)


## 地图传送门表：map → [{id, target}]。口径 = `数据/地图/*/地图.json` 的 `portal` 段
## （`pn` 名 / `tm` 目标图 / 键就是原版 `request_portal_enter` 要的编号）。
static var _门表: Dictionary = {}

func _建门表() -> void:
	if not _门表.is_empty():
		return
	var 目 := DirAccess.open("res://数据/地图")
	if 目 == null:
		return
	目.list_dir_begin()
	while true:
		var 名 := 目.get_next()
		if 名.is_empty():
			break
		if not 目.current_is_dir() or 名.begins_with("."):
			continue
		var 路 := "res://数据/地图/%s/地图.json" % 名
		if not FileAccess.file_exists(路):
			continue
		var 解 = JSON.parse_string(FileAccess.get_file_as_string(路))
		if not (解 is Dictionary):
			continue
		var mid := int((解 as Dictionary).get("mapId", 0))
		var ps = (解 as Dictionary).get("portal")
		var 列: Array = []
		if ps is Dictionary:
			for 键 in (ps as Dictionary):
				var p = (ps as Dictionary)[键]
				if p is Dictionary and int((p as Dictionary).get("tm", 0)) > 0:
					列.append({"id": int(键), "target": int((p as Dictionary)["tm"])})
		if mid > 0:
			_门表[mid] = 列
	目.list_dir_end()


## 按门户 BFS 走：返回是否到了目标图。
func _走门(图: int) -> bool:
	_建门表()
	var 起 := int(_backend.authoritative_map_id)
	if not _门表.has(起):
		print("G 走门：当前图 %d 没有门户表" % 起)
		return false
	## BFS 记前驱（图 → [上一图, 用的门编号]）
	var 前 := {起: []}
	var 队: Array[int] = [起]
	var 找到 := false
	while not 队.is_empty() and not 找到:
		var 当: int = 队.pop_front()
		for e in (_门表.get(当, []) as Array):
			var 下 := int((e as Dictionary).get("target", 0))
			if 下 <= 0 or 前.has(下):
				continue
			前[下] = [当, int((e as Dictionary).get("id", 0))]
			队.append(下)
			if 下 == 图:
				找到 = true
				break
	if not 找到:
		print("G 走门：从 %d 没有门户路径到 %d" % [起, 图])
		return false
	## 回溯成 hops
	var 路: Array = []
	var 步 := 图
	while 步 != 起:
		var p: Array = 前[步]
		路.push_front({"from": int(p[0]), "portal": int(p[1]), "to": 步})
		步 = int(p[0])
	for h in 路:
		var 门 := int((h as Dictionary)["portal"])
		var 到 := int((h as Dictionary)["to"])
		if not _backend.request_portal_enter(门):
			print("G 走门：发不出进门包 %d（%d→%d）" % [门, int((h as Dictionary)["from"]), 到])
			return false
		if not await _等(func(): return int(_backend.authoritative_map_id) == 到, 15000):
			print("G 走门：进门后 15 秒没到 %d（现在 %s）" % [到, str(_backend.authoritative_map_id)])
			return false
		await create_timer(0.6).timeout
	return true


## 打怪（`掉物>0` 时同时把该怪掉的物品**捡起来**，直到背包里够 `缺` 个）。
func _去杀(图: int, 怪: int, 缺: int, 掉物: int = 0) -> Array[String]:
	if not await _传送到(图):
		return []
	var 打 := 0
	var 捡 := 0
	## 打满一轮还不死的对象号：多半是客户端残留的**已死怪**（死亡帧没收到），
	## 服务端对它的攻击一律忽略；死盯着它会让整段 150 秒一刀无效（实测 1210）。
	var 跳过 := {}
	var 期限 := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < 期限:
		if 掉物 > 0:
			捡 = _背包数量(掉物)
			if 捡 >= 缺:
				break
		elif 打 >= 缺:
			break
		var 号 := 0
		for k in _backend.map_monsters:
			if 跳过.has(int(k)):
				continue
			if int((_backend.map_monsters[k] as Dictionary).get("monster_id", 0)) == 怪:
				号 = int(k)
				break
		if 号 == 0:
			## 当前列表里没有可打的（都跳过了或没刷出来）⇒ 清空跳过表、等下一波刷新
			跳过.clear()
			await create_timer(0.5).timeout
			continue
		var 死了 := false
		for 刀 in 10:
			var 状: Dictionary = _backend.map_monsters.get(号, {})
			if 状.is_empty():
				死了 = true
				break
			_backend.send_movement(Vector2(float(状.get("x", 0)) - 12.0, float(状.get("y", 0))), 1)
			await create_timer(0.06).timeout
			_backend.request_basic_attack(号, Vector2(float(状.get("x", 0)), float(状.get("y", 0))), 1 if 刀 % 2 == 0 else -1)
			await create_timer(0.24).timeout
		if 死了:
			打 += 1
		else:
			跳过[号] = true
		await create_timer(0.3).timeout
		if 掉物 > 0:
			## 掉落物要**走到附近再拾取**（服务端按距离判）；同帧连续拾取只发一个，逐枚间隔。
			for oid in (_backend.map_drops as Dictionary).keys().duplicate():
				var d: Dictionary = _backend.map_drops.get(oid, {})
				if d.is_empty() or int(d.get("item_id", 0)) != 掉物:
					continue
				_backend.send_movement(Vector2(float(d.get("x", 0)) - 8.0, float(d.get("y", 0))), 1)
				await create_timer(0.1).timeout
				_backend.request_pickup(int(oid))
				await create_timer(0.12).timeout
	await create_timer(0.8).timeout
	if 掉物 > 0:
		if _背包数量(掉物) < 缺:
			print("G 打怪：%d 秒内只捡到 %d/%d 个 %d（杀了 %d 只 %d）" % [150, _背包数量(掉物), 缺, 掉物, 打, 怪])
			return []
		return ["打%d只%d并捡%d" % [打, 怪, 掉物]]
	if 打 == 0:
		print("G 打怪：150 秒一只 %d 都没打掉" % 怪)
		return []
	return ["打%d只%d" % [打, 怪]]


func _背包数量(物品: int) -> int:
	var 和 := 0
	for 物 in _backend.authoritative_inventory:
		if int((物 as Dictionary).get("id", 0)) == 物品:
			和 += int((物 as Dictionary).get("quantity", 0))
	return 和


## 去 NPC 处买任务物品（先开对话让服务端确认 active NPC，再发买）。
func _去买(模板: int, 物品: int, 数量: int) -> Array[String]:
	var 图 := _NPC图(模板)
	if not await _传送到(图):
		return []
	if _NPC(模板).is_empty():
		await _等(func(): return not _NPC(模板).is_empty(), 8000)
	_backend.request_npc_dialog(模板)
	await create_timer(0.5).timeout
	var 前 := 0
	for 物 in _backend.authoritative_inventory:
		if int((物 as Dictionary).get("id", 0)) == 物品:
			前 += int((物 as Dictionary).get("quantity", 0))
	_backend.request_npc_shop_buy(物品, 数量)
	await create_timer(0.8).timeout
	var 后 := 0
	for 物 in _backend.authoritative_inventory:
		if int((物 as Dictionary).get("id", 0)) == 物品:
			后 += int((物 as Dictionary).get("quantity", 0))
	if 后 <= 前:
		print("G 买物：NPC %d 处买 %d 没到账（%d→%d）" % [模板, 物品, 前, 后])
		return []
	return ["买%d个%d" % [后 - 前, 物品]]


## 捕捉通灵兽（原版点宠物读条 → `PET_CATCH`）。
func _去捕(图: int, 宠物: int) -> Array[String]:
	if not await _传送到(图):
		return []
	var 期限 := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < 期限:
		for 号 in _backend.map_monsters:
			var 状: Dictionary = _backend.map_monsters[号]
			if int(状.get("monster_id", 0)) == 4000000 or String(状.get("kind", "")) in ["pet", "p"]:
				_backend.request_pet_catch(int(号))
				await create_timer(1.5).timeout
				return ["捕%d" % 宠物]
		await create_timer(0.5).timeout
	print("G 捕捉：30 秒没找到可捕的宠物")
	return []

