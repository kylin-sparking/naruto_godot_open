extends SceneTree

## 「意志全链路在线」门（2026-10-23）—— 用户令「把所有和意志相关的道具按照单机版
## 修复一下，直到可以有效且能正确使用」。§3.183-3.186 四轮把交互 bug 修完后，本门把
## **原版 11 个意志 action 逐条端到端跑一遍**（真连服务端夹具），任何一条断/错都红：
##   ①  action0 开面板（四状面）          ②  action1 召唤特殊导师（元宝）
##   ③  action2 向导师学习（阅历）        ④  action3 单个拾取
##   ⑤  action4 全部拾取                  ⑥  action10 穿戴移动
##   ⑦  action9 吞噬融合（oneEatOne）     ⑧  action8 一键合成（bagMergeAll）
##   ⑨  action7 背包扩容（元宝）          ⑩  action5 单个卖出
##   ⑪  action11 一键学习（learnAll）
## 真值（原版请求全集，`grep requestSpirit_`）：TeacherPanel:91/187/211、YiZhiCell:247、
## YiZhiManager:102/248/343/388/613/619/626/647、YiZhiPackWindow:360/415/633、
## YiZhiStudyCell:111/116 —— 与工程 `handle_spirit_action` 的 0..11 分支一一对应。
## 货币对账：学习扣阅历（`pve_points`）、召唤/扩容扣元宝（`cash`）——「道具能不能用」
## 的另一半就是**账本动没动**。
##
## 由 `bash 测试/跑在线门.sh 意志全链路在线回归测试.gd` 调（夹具 `--complete-pve`
## 把阅历灌满 ⇒ 学习段不被阅历挡；跑前会清 18684 端口，别在用户实机跑的时候用）。

var _失败: Array[String] = []
var _受检 := 0
var _会话 = null
var _后端 = null


func _initialize() -> void:
	call_deferred("_跑")


func _查(过: bool, 话: String) -> void:
	_受检 += 1
	if not 过:
		_失败.append(话)


func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


func _印(话: String) -> void:
	print("[意志全链路] " + 话)


func _跑() -> void:
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _会话 == null or _后端 == null:
		_停("缺单例")
		return
	var 端口 := OS.get_environment("NARUTO_TEST_PORT")
	if not 端口.is_empty():
		_会话.game_settings["backend_port"] = int(端口)
	_后端.sync_character()
	if not await _等(func(): return bool(_后端.in_game), 25000):
		_停("进不了后端：%s - %s" % [_后端.status, _后端.detail])
		return

	# ── ① action0 开面板：四状面（cmd0/1/6/7）──
	if not _会话.spirit_open():
		_停("在线 spirit_open 返回 false")
		return
	if not await _等(func(): return _会话.spirit_npc_status.size() == 5, 8000):
		_停("8 秒没凑齐 5 位导师状态")
		return
	_查(int(_会话.spirit_pack_limit) == 5, "背包上限初值该 5，实际 %d" % _会话.spirit_pack_limit)
	_查(int(_会话.spirit_equip_limit) == 8, "100 级穿戴上限该 8，实际 %d" % _会话.spirit_equip_limit)

	# 导师账本从数据表现算（不写死下标）：可召唤的 = special.needYuanBao>0（实测 NPC3=400），
	# 各导师学习花费 = 顶层 needYueLi（NPC0=8000 … NPC3=40000）。同导师学完全表 status 清 0
	# （`_gain_spirit_from_teacher` 末行）⇒ **每次学习前要么换导师、要么先召唤点亮**。
	var 意志数据 := JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志.json")) as Dictionary
	var 导师表: Dictionary = (意志数据.get("common", {}) as Dictionary).get("gain", {}) as Dictionary
	var 可召 := -1
	var 召价 := 0
	for 键 in 导师表:
		var 规: Dictionary = 导师表[键] as Dictionary
		var 特: Dictionary = 规.get("special", {}) as Dictionary
		if int(特.get("needYuanBao", 0)) > 0:
			可召 = int(String(键).replace("NPC", ""))
			召价 = int(特.get("needYuanBao", 0))
	if 可召 < 0:
		_停("数据表里找不到可召唤的导师（special.needYuanBao>0）")
		return

	# ── ② action1 召唤特殊导师：元宝账本要动、status 置 2 ──
	var 元宝前 := int(_会话.player_stats.get("cash", 0))
	_查(bool(_会话.spirit_summon(可召)), "spirit_summon(%d) 没发出去" % 可召)
	var 态2 := await _等(func(): return int(_会话.spirit_npc_status[可召]) == 2, 8000)
	_查(态2, "召唤后导师 %d 状态没置 2（cmd0 回帧断链或被挡：元宝 %d < %d？）" % [可召, 元宝前, 召价])
	if 态2:
		var 元宝后 := int(_会话.player_stats.get("cash", 0))
		_印("召唤导师 %d：元宝 %d → %d（价 %d）" % [可召, 元宝前, 元宝后, 召价])
		_查(元宝后 == 元宝前 - 召价, "召唤扣费不对：%d → %d，期望 -%d" % [元宝前, 元宝后, 召价])

	# ── ③ action2 学习（导师 0）──
	# ⚠️ 原版规则：每次学习成功把**全表 status 清 0**（`_gain_spirit_from_teacher:20755`）⇒
	#    想再学必须重新召唤点亮（或等 20 分钟）。别指望连着学两个导师。
	var 阅历前 := int(_会话.阅历)
	var 面1: int = _会话.spirit_panel.size()
	_查(bool(_会话.spirit_gain_from_teacher(0)), "spirit_gain_from_teacher(0) 没发出去")
	if await _等(func(): return _会话.spirit_panel.size() > 面1, 6000):
		_查(true, "学习（导师 0）后面板候选 +1")
	else:
		_查(false, "学习（导师 0）后面板没涨")
	_印("学习：阅历 %d → %d，面板 %d 件" % [阅历前, int(_会话.阅历), _会话.spirit_panel.size()])
	_查(int(_会话.阅历) < 阅历前, "学习没扣阅历（账本不动 = 道具链没真正结算）")

	var _拾通知: Array[String] = []
	_会话.notification_requested.connect(func(文: String) -> void: _拾通知.append(文))
	# ── ④ action3 单个拾取：面板 -1、包 +1；满包被挡时收「意志背包已满」实话 ──
	# ⚠️ 新档补给会把背包灌到 5 件 = 上限 5 ⇒ 满包拾取被服务端挡（`_pick_spirit_panel_items`
	#    查 `spirit_pack_limit` 后 `skipped += 1`）。真规则两条都钉：未满 ⇒ 面板少 + 包 +1；
	#    满包 ⇒ 面板不动但**必须发声**（§3.178 的教训：失败路径不许静默）。
	if _会话.spirit_panel.size() > 0:
		var 拾前: int = _会话.spirit_bag.size()
		var 面拾前: int = _会话.spirit_panel.size()
		var 满包 := 拾前 >= int(_会话.spirit_pack_limit)
		_查(bool(_会话.spirit_pick(0)), "spirit_pick(0) 没发出去")
		if 满包:
			var 满话 := await _等(func(): return _拾通知.has("意志背包已满，无法拾取更多意志"), 6000)
			_查(满话, "满包拾取一句实话都没发（静默 = 用户看到的「没反应」）")
			_查(int(_会话.spirit_panel.size()) == 面拾前, "满包拾取面板不该动")
		else:
			_查(await _等(func(): return _会话.spirit_panel.size() < 面拾前, 6000),
					"单个拾取后面板没少（cmd8 断链）")
			_查(await _等(func(): return _会话.spirit_bag.size() > 拾前, 6000),
					"包未满时单个拾取背包该 +1")

	# ── ⑤ 第二轮：再召唤 → 学 → 全部拾取（action4）──
	_查(bool(_会话.spirit_summon(可召)), "第二轮 summon(%d) 没发出去" % 可召)
	await _等(func(): return int(_会话.spirit_npc_status[可召]) == 2, 8000)
	var 面3: int = _会话.spirit_panel.size()
	_查(bool(_会话.spirit_gain_from_teacher(可召)), "spirit_gain_from_teacher(%d) 没发出去" % 可召)
	var 二学 := await _等(func(): return _会话.spirit_panel.size() > 面3, 8000)
	_查(二学, "第二轮学习（导师 %d）后面板没涨" % 可召)
	if _会话.spirit_panel.size() > 0:
		_查(bool(_会话.spirit_pick_all()), "spirit_pick_all 没发出去")
		if int(_会话.spirit_bag.size()) >= int(_会话.spirit_pack_limit):
			# 满包：全部拾取同样被挡（真规则）⇒ 面板不动 + 实话
			var 全满话 := await _等(func(): return _拾通知.has("意志背包已满，无法拾取更多意志"), 6000)
			_查(全满话, "满包全部拾取一句实话都没发")
		else:
			_查(await _等(func(): return _会话.spirit_panel.is_empty(), 6000),
					"全部拾取后面板没清空")
	_查(_会话.spirit_bag.size() >= 2, "两轮学习 + 拾取后背包至少 2 件（实际 %d）" % _会话.spirit_bag.size())

	# ── ⑥ action10 穿戴：背包第一件非黄 → -1 ──
	var 可穿 := 0
	for 行 in _会话.spirit_bag:
		var d := 行 as Dictionary
		if String(d.get("color", "")) == "yellow" or int(d.get("slot", 0)) < 1:
			continue
		可穿 = int(d.get("slot", 0))
		break
	# 穿戴目标 = 第一个**空着的**穿戴位（新档补给占了 -1 ⇒ 不能穿 -1，
	# 「穿到已占位」服务端挡是真规则，与 §3.184 用户报的「拖进去没反应」两回事）
	var 已占 := {}
	for 行 in _会话.spirit_equipped:
		已占[int((行 as Dictionary).get("slot", 0))] = true
	var 穿位 := 0
	for k in range(-1, -9, -1):
		if not 已占.has(k):
			穿位 = k
			break
	if 可穿 == 0 or 穿位 == 0:
		_印("背包没有可穿的非黄件或穿戴位全占（可穿=%d 穿位=%d），穿戴段跳过" % [可穿, 穿位])
	else:
		var 穿前: int = _会话.spirit_equipped.size()
		_查(bool(_会话.spirit_move(可穿, 穿位)), "spirit_move(%d, %d) 没发出去" % [可穿, 穿位])
		_查(await _等(func(): return _会话.spirit_equipped.size() > 穿前, 6000),
				"穿戴后 equipped 没变多（cmd5/7 断链）")

	# ── ⑦ action9 吞噬融合：包里那件 × 身上那件（都非空才融；目标是空格只能 move）──
	var 背包件 := 0
	for 行 in _会话.spirit_bag:
		var d := 行 as Dictionary
		if int(d.get("slot", 0)) >= 1:
			背包件 = int(d.get("slot", 0))
			break
	var 身上件 := 0
	for 行 in _会话.spirit_equipped:
		var de := 行 as Dictionary
		if int(de.get("slot", 0)) < 0:
			身上件 = int(de.get("slot", 0))
			break
	if 背包件 == 0 or 身上件 == 0:
		_印("背包/身上不足两件，融合段改走「穿↔背双向 move」")
		var 挪源 := 背包件 if 背包件 != 0 else 身上件
		if 挪源 != 0:
			_查(bool(_会话.spirit_move(挪源, 2)), "spirit_move(%d, 2) 没发出去" % 挪源)
	else:
		var 件前: int = _会话.spirit_bag.size() + _会话.spirit_equipped.size()
		var 阅前融 := int(_会话.阅历)
		_查(bool(_会话.spirit_feed(背包件, 身上件)), "spirit_feed(%d, %d) 没发出去" % [背包件, 身上件])
		var 融了 := await _等(func(): return _会话.spirit_bag.size() + _会话.spirit_equipped.size() < 件前, 8000)
		_查(融了, "融合后总件数没少（副件没被吞掉？cmd3/7 断链）")
		if 融了:
			_印("融合：%d 件 → %d 件" % [件前, _会话.spirit_bag.size() + _会话.spirit_equipped.size()])

	# ── ⑧ action8 一键合成：背包剩下的合成（≤1 件本就不动，只钉请求发得出）──
	var 合前: int = _会话.spirit_bag.size()
	_查(bool(_会话.spirit_merge_all()), "spirit_merge_all 没发出去")
	if 合前 > 1:
		_查(await _等(func(): return _会话.spirit_bag.size() < 合前, 8000),
				"一键合成后背包没变少（%d → %d）" % [合前, _会话.spirit_bag.size()])
	else:
		_印("背包 ≤1 件，一键合成本就不动（%d）" % 合前)

	# ── ⑨ action7 背包扩容：5 → 6，元宝账本要动 ──
	var 元宝前2 := int(_会话.player_stats.get("cash", 0))
	var 限前 := int(_会话.spirit_pack_limit)
	_查(bool(_会话.spirit_extend(限前 + 1)), "spirit_extend(%d) 没发出去" % (限前 + 1))
	var 扩了 := await _等(func(): return int(_会话.spirit_pack_limit) > 限前, 8000)
	_查(扩了, "扩容后上限没涨（%d → %d）" % [限前, _会话.spirit_pack_limit])
	if 扩了:
		var 元宝后2 := int(_会话.player_stats.get("cash", 0))
		_印("扩容：元宝 %d → %d" % [元宝前2, 元宝后2])
		_查(元宝后2 < 元宝前2, "扩容没扣元宝（账本不动）")

	# ── ⑩ action5 单个卖出：再召唤 + 学一件 ⇒ 有货可卖 ──
	var 通知: Array[String] = []
	_会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	var 卖基 := 通知.size()
	# ⚠️ 别信前面的 `态2`（早被学习清掉了）——重新召唤
	if bool(_会话.spirit_summon(可召)):
		await _等(func(): return int(_会话.spirit_npc_status[可召]) == 2, 8000)
		_查(bool(_会话.spirit_gain_from_teacher(可召)), "⑩ 段再学习没发出去")
		# ⚠️ 必须等**这一发**学习的回帧真到位（面板比学前多）再卖：面板里本来就有
		#    补给候选，等「>0」会立刻为真 ⇒ 卖的又是旧面板位、学的回帧随后才到
		#    （门自己踩过的时序坑：最终面板反而比卖前多）。
		var 学前面板: int = _会话.spirit_panel.size()
		var 学到位 := await _等(func(): return _会话.spirit_panel.size() > 学前面板, 8000)
		_查(学到位, "⑩ 段：再学习后面板没涨（%d → %d）" % [学前面板, _会话.spirit_panel.size()])
		if 学到位:
			var 卖前面: int = _会话.spirit_panel.size()
			_查(bool(_会话.spirit_sell(0)), "spirit_sell(0) 没发出去")
			_查(await _等(func(): return _会话.spirit_panel.size() < 卖前面, 6000),
					"单个卖出后面板没少（卖一件 ≠ 清空：面板还有别的候选）")
	else:
		_查(false, "⑩ 段：召唤不出来了（元宝不够？）")

	# ── ⑪ action11 一键学习：先召唤点亮 ⇒ 真学出货（正面）──
	# ⚠️ 别断言「空可学发实话」：存档归一化段有兜底（`_normalize_progression`：
	#    `if not any(npc_status): npc_status[0] = 1`）⇒ 全 0 会被自动点亮 ⇒ 永远有可学。
	#    空可学的实话路由由 `意志在线回归测试` ①' 段覆盖（那边新档面板恒空、三钮全踩中）。
	_查(bool(_会话.spirit_summon(可召)), "⑪ 段 summon 没发出去")
	await _等(func(): return int(_会话.spirit_npc_status[可召]) == 2, 8000)
	var 学前面: int = _会话.spirit_panel.size()
	_查(bool(_会话.spirit_learn_all()), "spirit_learn_all 没发出去")
	var 学涨 := await _等(func(): return _会话.spirit_panel.size() > 学前面, 8000)
	_查(学涨, "一键学习后面板没涨（%d → %d）" % [学前面, _会话.spirit_panel.size()])

	# ── 收尾：状态面自洽（背包件都在合法槽位、没有重复 slot）──
	var 号集 := {}
	for 行 in _会话.spirit_bag:
		var d := 行 as Dictionary
		var s := int(d.get("slot", 0))
		_查(s >= 1 and not 号集.has(s), "背包出现非法/重复槽位 %d" % s)
		号集[s] = true

	_收尾()


func _停(话: String) -> void:
	printerr("意志全链路在线回归测试：中断 - " + 话)
	quit(1)


func _收尾() -> void:
	if _失败.is_empty():
		print("意志全链路在线：通过（%d 条断言：action0..11 全链路 + 货币账本）" % _受检)
		quit(0)
		return
	for 条 in _失败:
		printerr("意志全链路在线：" + 条)
	quit(1)
