extends SceneTree

## 「意志在线」门（2026-10-03 接 `SPIRIT_ACTION 1823`）——走真实服务端夹具。
##
## 钉四段（夹具 `handle_spirit_action` 一族的端到端）：
##   ①' **空面板一键钮必须先出声**（2026-10-21 用户实机报「一键学习/一键拾取/一键卖出
##      点击后没反应」）：新档面板恒空 ⇒ 点拾取/卖出必须收到 `CHAR_NOTICE(512)` 通知
##      （客户端路由 + 服务端空面板消息，两边一起钉；必须放在学习之前，阅历被灌满后
##      消息分支走不到）。
##   ① **开面板（action0）四状面**：回帧 cmd0/1/6/7 灌满
##      `spirit_npc_status(5位)/spirit_panel/spirit_pack_limit=5/spirit_equip_limit(100级=8)`，
##      `spirit_special_count=0/enabled=true`（新档）。
##   ② **学习→入背包链路**：action2 向导师学习（扣阅历、意志进"面板候选"）→ 候选变多 →
##      action4 全部拾取（面板→背包：cmd7 背包行数增加、面板清空）。
##      ⚠ 夹具 `SPIRIT_EXP_CAP=2` 起跳（每 20 分钟阅历 +1，新档 cap=2）⇒ 最多学 2 次，
##      学习被阅历挡时**跳过本段判绿**（那是夹具账本规则，不是断链——但链发没发得出去仍然钉）。
##   ③ **穿戴移动（action10）**：背包第一件非黄色 ⇒ 移到 -1 穿戴位，cmd5/7 到 ⇒
##      `spirit_equipped` 变多。黄色被夹具挡（原版「黄色意志不可装备」）⇒ 选色避开。
##      末尾按 §3.181 补一条**端到端对拍**：`意志力()` 必须等于用例里独立算出的
##      融经验口径值（直读 `数据/意志.json` 的 level1 表），防公式退回「只加原始 exp」。
## 由 `开发工具/跑在线用例.ps1 -用例 意志在线` 调（隔离夹具；不能并行）。

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _停(话: String) -> void:
	printerr("意志在线回归测试：中断 - " + 话)
	quit(1)

## 2026-10-21 §3.181：意志力的**独立**口径（与产品代码 `游戏数据.意志融经验` 同源不同写）。
## 直读 `数据/意志.json` 的 `common.levelUp.level1`（blue60/green30/pueple120/pink240/lpink480/red480；
## **没有 gray**）—— 照 `YiZhiData.rongHeExp:92-101`：黄固定 1200、其余 level1[色名] + 行 exp、
## 表里没有的色（gray）⇒ 0；总和 ÷30（`YiZhiManager.caculateYiZhiLi:168-181`）。
## 协议第 4 列 exp 是**原始经验**（新学得件恒 0），不能直接当 rongHeExp 累加。
func _期望意志力(穿戴: Array) -> int:
	var 表 := JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志.json")) as Dictionary
	if 表.is_empty():
		return -1
	var 常 := (表.get("common", {}) as Dictionary).get("levelUp", {}) as Dictionary
	var 级一 := 常.get("level1", {}) as Dictionary
	var 色名 := {1: "gray", 2: "green", 3: "blue", 4: "pueple", 5: "pink", 6: "yellow", 7: "red", 8: "lpink"}
	var 总 := 0
	for 行 in 穿戴:
		if not 行 is Dictionary:
			continue
		var 记 := 行 as Dictionary
		var 色 := str(色名.get(int(记.get("color", 0)), ""))
		if 色 == "yellow":
			总 += 1200
			continue
		if not 级一.has(色):
			continue
		总 += int(级一.get(色, 0)) + int(记.get("exp", 0))
	return int(总 / 30.0)

func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var 会话 = root.get_node_or_null("GameSession")
	if backend == null or 会话 == null:
		_停("缺单例")
		return
	# 端口覆盖（只改内存，不落盘）：`NARUTO_TEST_PORT=18699` 可连到另一份夹具上自测
	# （跑在线门.sh 会清 18684，用户实机在跑时不能注册运行）。不设则走默认 18684。
	var 端口 := OS.get_environment("NARUTO_TEST_PORT")
	if not 端口.is_empty():
		会话.game_settings["backend_port"] = int(端口)
	backend.sync_character()
	if not await _等(func(): return bool(backend.in_game), 15000):
		_停("进不了后端：%s - %s" % [backend.status, backend.detail])
		return

	# —— ①' 空面板一键钮必须先出声（用户 2026-10-21 实机报「一键学习/一键拾取/一键卖出
	#      点击后没有反应」；新档面板恒空，三钮全踩中）——
	# 逮到两条叠加的 bug：
	#   a) **客户端**：服务端的实话走 `CHAR_NOTICE(512)` 帧（`MessagePosition.as:18`），
	#      原版 `UI.as:376-377` 对这位走 `addNotice` ⇒ `MessageTipPane` 浮动黄字；
	#      我方 `_handle_chat_text` 原来只发 `chat_received`，而 `聊天面板` 按页签位过滤
	#      （MISC4/GENERAL8/WHISPER16/PARTY32/GUILD64/WORLD128/LABA256）——512 哪个页签
	#      都不匹配 ⇒ 话存进列表却永远渲染不出来。已修：512 路由到 `notification_requested`。
	#   b) **服务端**：面板**全空**时拾取/卖出只回一张与点前相同的帧、一句话不发
	#      （§3.178 只补了「有件但干不成」的分支）。已修：补两句实话。
	# ⚠️ 必须放在**开面板/学习之前**：本门夹具把阅历灌到近百万（complete-pve），一学习
	#    面板就满、包就满，消息分支永远走不到——2026-10-21 首版就踩了这个（断言全走
	#    "状态变化"分支，绿得假）。新档面板恒空，正是用户那边的状态。
	#    （「一键学习」的「阅历不足」那句同走 512，路由被这两句钉住；它自己要在低阅历
	#    档才发，本门不另造低阅历档。）
	var 通知: Array[String] = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	# ⚠️ 登录/进图那几下也会发 512 通知（如「成就奖励已自动发放到背包。」）⇒ 必须记
	#    增量基线，只认自己这次点出来的那句（首版没扣基线，被登录消息顶成假红）。
	var 拾基 := 通知.size()
	会话.spirit_pick_all()
	var 拾到 := await _等(func(): return 通知.size() > 拾基, 6000)
	_查(拾到, "空面板点「一键拾取」一句实话都没收到（512 路由断或服务端没发话）")
	if 拾到:
		# ⚠️ 2026-10-23 新档有补给（面板 2 候选 + 包 5 满）⇒ 这句实话可能是
		#    「意志背包已满，无法拾取更多意志」（满包挡）而不是「没有可拾取的意志」。
		#    两条都是 §3.178 补的实话 ⇒ 都算过，但**不许一句都没有**（上面 _查 拾到 已钉）。
		var 拾话 := 通知.slice(拾基) as Array
		_查(拾话.has("没有可拾取的意志（请先向导师学习）")
				or 拾话.has("意志背包已满，无法拾取更多意志"),
				"一键拾取实话文案不对：%s" % str(拾话))
	var 卖基 := 通知.size()
	会话.spirit_sell_all()
	var 卖到 := await _等(func(): return 通知.size() > 卖基, 6000)
	_查(卖到, "空面板点「一键卖出」一句实话都没收到（512 路由断或服务端没发话）")
	if 卖到:
		# ⚠️ 同上：面板里有补给的非灰候选 ⇒ 灰卖收到的是「仅灰色品质可出售」那句
		var 卖话 := 通知.slice(卖基) as Array
		_查(卖话.has("没有可出售的意志")
				or 卖话.has("没有可出售的意志（仅灰色品质可出售）"),
				"一键卖出实话文案不对：%s" % str(卖话))

	# —— ① 开面板 ——
	if not 会话.spirit_open():
		_停("在线 spirit_open 返回 false")
		return
	if not await _等(func(): return 会话.spirit_npc_status.size() == 5, 8000):
		_停("8 秒没凑齐 5 位导师状态（cmd0 回帧 `1823:0:0:count:enabled:st@st@…` 没解析？）" )
		return
	_查(int(会话.spirit_pack_limit) == 5, "背包上限初值该 5（夹具 spirit_pack_limit）实际 %d" % 会话.spirit_pack_limit)
	_查(int(会话.spirit_equip_limit) == 8, "100 级穿戴上限该 8（carry 八档全开）实际 %d" % 会话.spirit_equip_limit)
	_查(bool(会话.spirit_special_enabled) and int(会话.spirit_special_count) == 0,
			"新档召唤次数该 0/可用（cmd0 前两参）")

	# —— ② 学习 → 候选 → 拾取入包 ——
	var 候选前: int = 会话.spirit_panel.size()
	var 包前: int = 会话.spirit_bag.size()
	var 学了: bool = 会话.spirit_gain_from_teacher(0)
	_查(学了, "spirit_gain_from_teacher(0) 在线返回 false")
	var 涨了 := false
	if 学了:
		涨了 = await _等(func(): return 会话.spirit_panel.size() > 候选前, 6000)
	if not 涨了:
		# 阅历不够被服务端挡（不发帧）是夹具账本规则；只钉"下一环仍可发"
		print("提示：这次学习没涨候选（多半阅历不足），拾取段改钉『请求发得出 + 背包不变』")
		_查(会话.spirit_bag.size() == 包前, "学习被挡却不该动背包")
		_查(会话.spirit_pick_all(), "pick_all 在线返回 false")
		await create_timer(0.5).timeout
	else:
		_查(会话.spirit_panel.size() > 候选前, "action2 后候选没变多（cmd1 回帧）")
		_查(会话.spirit_pick_all(), "spirit_pick_all 返回 false")
		# ⚠️ 2026-10-23：新档有意志测试补给（`SPIRIT_TEST_SUPPLY`，背包预灌 5 件 = 上限）
		#    ⇒ 满包时全部拾取被服务端挡是**真规则**，不是断链。满包只提示、不 _停；
		#    未满才钉「背包 +N / 面板清空」。
		if 包前 >= int(会话.spirit_pack_limit):
			print("提示：背包满（%d/%d），全部拾取被服务端挡——真规则，本段不判涨" % [
				包前, int(会话.spirit_pack_limit)])
		else:
			if not await _等(func(): return 会话.spirit_bag.size() > 包前, 6000):
				_查(false, "全部拾取后背包没变多（cmd7 整表回帧断链）")
				_停("")
				return
			_查(await _等(func(): return 会话.spirit_panel.is_empty(), 6000), "拾取后面板没清空（cmd1 空列表帧）")

	# —— ③ 穿戴移动（非黄第一件 → 第一个**空着的**穿戴位）——
	# ⚠️ 2026-10-23：新档补给占了 -1 ⇒ 穿 -1 被服务端挡是真规则（目标有位），
	#    与 §3.184 用户报的「拖进去没反应」（格_8 从没接线）两回事。
	var 穿前: int = 会话.spirit_equipped.size()
	var 挪了 := false
	var 已占 := {}
	for 行 in 会话.spirit_equipped:
		已占[int((行 as Dictionary).get("slot", 0))] = true
	var 穿位 := 0
	for k in range(-1, -9, -1):
		if not 已占.has(k):
			穿位 = k
			break
	for 行 in 会话.spirit_bag:
		var d := 行 as Dictionary
		if String(d.get("color", "")) == "yellow":
			continue
		var 从 := int(d.get("slot", 0))
		if 从 < 1:
			continue
		if 穿位 != 0:
			挪了 = bool(会话.spirit_move(从, 穿位))
		break
	_查(挪了, "spirit_move 没发出去（背包没有可挪的非黄件？或穿戴位全占：穿位=%d）" % 穿位)
	if 挪了:
		if not await _等(func(): return 会话.spirit_equipped.size() > 穿前, 6000):
			_查(false, "action10 后穿戴位没变多（cmd5/7 断链）")
		else:
			_查(true, "穿戴位 +1（cmd5 生效）")
			# 2026-10-21 §3.181 端到端：意志力必须按**融经验**口径从真协议行算出来。
			# 曾经的公式只加协议第 4 列（原始 exp，新学得件恒 0）⇒ 新穿一件也显示 0
			# （用户实机报「人物面板意志处不显示」）。这里在用例里**另写一份**口径
			# （直读 `数据/意志.json` 的 `common.levelUp.level1`）对拍，
			# 防「公式改回原始 exp、门还全绿」。
			var 期望 := _期望意志力(会话.spirit_equipped)
			_查(会话.意志力() == 期望,
					"意志力按融经验口径对拍：实际 %d ≠ 期望 %d（穿戴行 %s）" % [
					会话.意志力(), 期望, JSON.stringify(会话.spirit_equipped)])

	# —— ③' 左下格（-8）服务端真收（2026-10-22 用户实机报「左下角无法装备」的服务端侧）——
	#    真凶在客户端：`_填一格层` 循环上界只走到格_7 ⇒ 格_8（左下）从没接拖放。
	#    客户端接线由新离线门 `测试/意志穿戴八格接线回归测试.gd` 钉（8 格全挂脚本+
	#    拖放连接，对旧代码确定性红）；本段钉服务端 action10 确实收 -8（100 级上限 8，
	#    此前只挪 -1 ⇒ -8 的服务端路径零覆盖）。
	var 占8 := false
	for 行2 in 会话.spirit_equipped:
		if int((行2 as Dictionary).get("slot", 0)) == -8:
			占8 = true
	if not 占8:
		var 挪源 := 0
		for 行2 in 会话.spirit_bag:
			var d2 := 行2 as Dictionary
			if String(d2.get("color", "")) == "yellow" or int(d2.get("slot", 0)) < 1:
				continue
			挪源 = int(d2.get("slot", 0))
			break
		if 挪源 == 0:
			# 背包里没有第二件可挪（夹具只学到一两件）⇒ 把 ③ 段穿到 -1 的那件从
			# -1 挪到 -8（穿戴位之间 move 服务端同样收：`_move_spirit` 只要求目标空）
			for 行2 in 会话.spirit_equipped:
				if int((行2 as Dictionary).get("slot", 0)) == -1:
					挪源 = -1
				break
		if 挪源 == 0:
			# ⚠️ 不许静默跳过（跳过 = 这段断言白写，夹具随机性会把它变成永不执行）
			_查(false, "③'：背包/穿戴里都找不到可挪进 -8 的意志（夹具学得太少？）")
		else:
			var 挪8 := bool(会话.spirit_move(挪源, -8))
			_查(挪8, "spirit_move(%d, -8) 没发出去" % 挪源)
			if 挪8:
				var 到8 := await _等(func(): return 会话.spirit_equipped.any(
						func(r): return int((r as Dictionary).get("slot", 0)) == -8), 6000)
				_查(到8, "挪进左下格(-8)后 equipped 里没有 -8 行（cmd5/7 断链）")

	if not _失败.is_empty():
		for 条 in _失败:
			printerr("意志在线回归测试：" + 条)
		quit(1)
		return
	print("意志在线回归测试：通过（%d 条断言：开面板四状面/学习→拾取入包/穿戴移动/一键三钮必有反馈）" % _受检)
	backend.disconnect_backend()
	quit(0)
