extends SceneTree

## 「道具真实事务」在线门（2026-10-01 背包/道具轮）。
## 钉的都是**本轮刚修的链**，走真实服务端（本地服务端夹具）：
##   · 使用：USE_ITEM(69) → 数量-1、服务端权威镜像回填；
##   · flags[3] 双语义（唯一布尔槽）：礼包类=整摞吃、药剂类=自动喝药请求
##     （满血不消耗只回取消包）。见下面第二步的行内长注——这条是**跑红之后**才读对的；
##     整摞礼包路径由离线门 `背包道具回归测试` ②b 钉。
##   · 拆分 ITEM_SPLIT(1332) → 两摞合计守恒、新摞占空格；
##   · 销毁 ITEM_MOVE(68) kind1 带件数 → 只扣件数；
##   · 换位 ITEM_MOVE(68) src:dst → 服务端**交换**（不是移动覆盖）；
##   · 绑定 ITEM_CHANGE(1040):9 → 服务端置不可交易、清格+同格重发；镜像的 can_trade
##     靠 `_parse_item_entry` 读回包第 7 段（2026-10-02 实装菜单「绑定」时补的解析）；
##     顺带钉 NeverBindItems 拒绑分支（16000053，服务端 :53341-53343 什么都不改）；
##   · 仓库存取 STORAGE(59) 3/2 → 背包↔仓库往返；
##   · 整理 ITEM_SORT(66) → 格位不重不漏 + 原有 id 不许少（只许多不许少——
##     任务奖励会异步到账，精确相等钉不住，见该步行内注）。
## 规矩（§3.65.4 一族）：新接的链必须有"真按钮 → 真协议 → 真服务端"的端到端用例。
## 由 `开发工具/跑在线用例.ps1 -用例 道具真实事务` 调（它起隔离夹具；**不能并行**）。

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _停(话: String) -> void:
	printerr("道具真实事务在线回归测试：中断 - " + 话)
	quit(1)

func _wait_until(条件: Callable, 毫秒: int = 8000) -> bool:
	var 期限 := 毫秒 / 50
	for _轮 in 期限:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())

func _inv() -> Array:
	return (root.get_node("/root/BackendConnection") as Node).authoritative_inventory

func _格(物品id: String) -> int:
	for 条 in _inv():
		if String((条 as Dictionary).get("id", "")) == 物品id:
			return int((条 as Dictionary).get("slot_index", 0))
	return 0

func _件数(物品id: String) -> int:
	var 总 := 0
	for 条 in _inv():
		if String((条 as Dictionary).get("id", "")) == 物品id:
			总 += int((条 as Dictionary).get("quantity", 1))
	return 总

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if backend == null or 会话 == null:
		_停("缺单例")
		return
	backend.sync_character()
	if not await _wait_until(func(): return bool(backend.in_game) and not backend.authoritative_inventory.is_empty(), 12000):
		_停("进不了真实后端：%s - %s" % [backend.status, backend.detail])
		return
	if _件数("3000001") < 8:
		_停("夹具应预置拉面×20，实际 %d" % _件数("3000001"))
		return

	# —— 使用：-1 ——
	# ⚠️ 基线**先读再发**（第一版反过来：发完才读，若回包先到就把基线读小了，
	#    等待条件"再 -1"会去等一次根本不存在的消耗 —— 在线门的计时Race都长这样）。
	var 基 := _件数("3000001")
	var 铠格前 := _格("2010010")
	会话.call("use_inventory_item", "03000001")
	if not await _wait_until(func(): return _件数("3000001") == 基 - 1, 6000):
		_停("吃一碗拉面后镜像应 -1（现 %d，基 %d）" % [_件数("3000001"), 基])
		quit(1)
		return
	_查(_件数("3000001") == 基 - 1, "使用：数量应 -1")
	# 稳定格位（2026-10-01 B 的在线半句）：吃一摞之后，别的件格号一格都不许动 ——
	# 服务端是 map 键位，客户端镜像必须按 slot_index 落洞（`服务端同步.落位带洞`）。
	_查(铠格前 != 0 and _格("2010010") == 铠格前,
			"吃完拉面，轻藤兽铠的格号不许变（%d→%d）" % [铠格前, _格("2010010")])

	# —— flags[3] 的**双语义**（第一版把它当成"全部使用的数量位"，跑红才读明白）——
	# USE_ITEM 只有一个布尔槽（`PacketCreator.as:396-404` 的 param4），服务端按物品种类解释：
	#   · `definition.use_all` 的礼包类 → **整摞吃**（`fake_flash_server.py:50234-50246`）；
	#   · 回复类药剂 → 它是**自动喝药请求**（`:50374-50398`）：HP 不在阈值下就
	#     **不消耗**、只回取消包。拉面 use_all=False + 进场满血 ⇒ 真值行为 = 一件都不吃。
	# （菜单的「全部使用」本来也只出现在 use_all 件上 —— 药剂根本没这个入口，
	#   `filtrateItemMenu :520`；整摞路径在离线门 `背包道具回归测试` ②b 钉。）
	基 = _件数("3000001")
	会话.call("use_inventory_item", "03000001", true)
	await create_timer(0.8).timeout
	_查(_件数("3000001") == 基,
			"满血药剂的自动喝药请求不该消耗（flags[3] 双语义，:50395-50398；基 %d 现 %d）" % [基, _件数("3000001")])

	# —— 拆分：13 → 8+5 ——
	基 = _件数("3000001")
	_查(基 >= 8, "前置：件数够拆")
	if not bool(会话.call("split_inventory_item", _格("3000001"), 5)):
		_停("拆分请求没发出去")
		return
	var 成两摞 := func() -> bool:
		var 摞数 := 0
		for 条 in _inv():
			if String((条 as Dictionary).get("id", "")) == "3000001":
				摞数 += 1
		return 摞数 >= 2
	if not await _wait_until(成两摞, 8000):
		_停("拆分后背包里拉面应变成两摞")
		return
	_查(_件数("3000001") == 基, "拆分合计守恒（%d）" % 基)

	# —— 销毁 2 件 ——
	基 = _件数("3000001")
	会话.call("discard_item", "3000001", 2)
	if not await _wait_until(func(): return _件数("3000001") == 基 - 2, 8000):
		_停("销毁 2 件后应 -2（现 %d）" % _件数("3000001"))
		return
	_查(true, "销毁按件数扣")

	# —— 换位（拉面格 ↔ 轻藤兽铠格）：交换而不是覆盖 ——
	var 拉面格 := _格("3000001")
	var 铠格 := _格("2010010")
	if 拉面格 == 0 or 铠格 == 0:
		_停("换位用例缺件（拉面格=%d 铠格=%d）" % [拉面格, 铠格])
		return
	会话.call("move_inventory_items", 拉面格, 铠格)
	if not await _wait_until(func():
			return String(_格物(铠格).get("id", "")) == "3000001", 8000):
		_停("换位后目标格 %d 应是拉面（现为 %s）" % [铠格, String(_格物(铠格).get("id", ""))])
		return
	_查(String(_格物(拉面格).get("id", "")) == "2010010", "原格该拿到对面那件（交换语义）")

	# —— 绑定 ITEM_CHANGE(1040) 子命令 9（2026-10-02 实装菜单「绑定」）——
	# 夹具预置白色宝石 13000000（**BindItems 名单外** → 发放即 `can_trade=True`，
	# `fake_flash_server.py:47077-47080`）。这条要钉两件事：
	#   ① 真事务走得通：服务端置不可交易后**清格+同格重新下发**（:53344-53349）；
	#   ② 客户端镜像**读得到回包里的 can_trade**——`_parse_item_entry` 原来漏读 values[6]
	#     （服务端 common_fields 第 7 段），绑定件在线永远显示"可交易"、菜单去不掉「绑定」。
	#     这正是 §3.80.4-3 说的"钉不动"：当时缺的就是这件**可绑的种子件**，现在补上了。
	var 石格 := _格("13000000")
	if 石格 <= 0:
		_停("夹具应预置白色宝石 13000000（绑定用例的种子）")
		return
	_查(bool(_格物(石格).get("can_trade", true)), "预置宝石应可交易（BindItems 名单外）")
	会话.call("bind_inventory_slot", 石格)
	if not await _wait_until(func():
			var 条 := _格物(石格)
			return not 条.is_empty() and not bool(条.get("can_trade", true)), 8000):
		_停("绑定后格 %d 的镜像应转 can_trade=false（回包 ADD 第 7 段没读出来就是旧 bug）" % 石格)
		return
	_查(int(_格物(石格).get("quantity", 0)) == 1,
			"绑定只改交易性：件数与格号都不动（清格+同格重发，:53347-53348）")
	# 已绑再绑：服务端 `_bind_item_instance:47057` 静默、一个包都不发 → 状态不许翻回可交易。
	会话.call("bind_inventory_slot", 石格)
	await create_timer(0.8).timeout
	_查(not bool(_格物(石格).get("can_trade", true)), "已绑件重绑不许把状态翻回去")
	# NeverBindItems 拒绑（16000053 宝箱钥匙，夹具已预置 1 件）：服务端 :53341-53343
	# 回系统聊天、**什么都不改**——若镜像出现"清格重发"的痕迹（件没了）就是发错/判错。
	var 钥格 := _格("16000053")
	if 钥格 <= 0:
		_停("夹具应预置宝箱钥匙 16000053（禁绑用例的种子）")
		return
	_查(bool(_格物(钥格).get("can_trade", true)), "前置：宝箱钥匙初始可交易")
	会话.call("bind_inventory_slot", 钥格)
	await create_timer(1.2).timeout
	_查(bool(_格物(钥格).get("can_trade", true)),
			"NeverBindItems 的件服务端拒绑后镜像该原样（仍可交易）")

	# —— 点券/金币礼包：使用 → 服务端 `_use_authored_gift_item` 尾部 `_send_stats` ——
	# 这一步是**用户实机报的那条**（用点券道具、点券不加、商城背包都不变）。
	# 根因：`_handle_stats_text` 的 names 表原来只到 27（gold），**CASH_BIND=30 被静默丢弃**，
	# 服务端确实发了 `30&数量`、客户端扔掉 —— 登记 30→cashBind 之后才会落进 `player_stats.cash_bind`。
	# 金币礼包走的是 MONEY=27（**早就登记**），所以金币本来就通；这条正好当**对照**：
	# 若金币涨、点券不涨 = names[30] 又被人删了；两个都不涨 = 发放链断了（不是解析）。
	# ⚠️ 基线先读再发（同族 race 规矩）；发放是**增量**（服务端把权威 cash_bind 整体推来，
	# 断言用"严格变大 + 涨了预期数额"，别钉绝对值——充值活动/别的来源会动它）。
	var 券基 := int(会话.player_stats.get("cash_bind", 0))
	var 金基 := int(会话.player_stats.get("gold", 0))
	var 券格 := _格("11000156")
	var 金格 := _格("11000241")
	if 券格 <= 0 or 金格 <= 0:
		_停("夹具应预置点券礼包 11000156 与金币礼包 11000241（使用族用例的种子）")
		return
	# 一件「388点券」：consume 1 → coupon_money += 388 → `_send_stats({CASH_BIND})`。
	会话.call("use_inventory_item", "11000156")
	if not await _wait_until(func():
			return int(会话.player_stats.get("cash_bind", 0)) >= 券基 + 388, 8000):
		_停("用一件 388 点券礼包后 cash_bind 应至少 +%d（基 %d 现 %d）——"
				% [388, 券基, int(会话.player_stats.get("cash_bind", 0))]
				+ "十有八九是 `_handle_stats_text` 的 names[30] 又被删了（点券静默丢弃）")
		return
	_查(true, "使用点券礼包：字段号 30（CASH_BIND）落进 cash_bind（+≥388）")
	_查(_件数("11000156") == 2, "点券礼包用一件应剩两件（3→2）")
	# 金币大礼包（money_reward=20000）：走 MONEY=27，本来就该通，当发放链没断的旁证。
	会话.call("use_inventory_item", "11000241")
	if not await _wait_until(func():
			return int(会话.player_stats.get("gold", 0)) >= 金基 + 20000, 8000):
		_停("用金币礼包后 gold 应至少 +%d（基 %d 现 %d）——发放链断了"
				% [20000, 金基, int(会话.player_stats.get("gold", 0))])
		return
	_查(true, "使用金币礼包：MONEY(27) 落进 gold（+≥20000，证明发放链没断）")
	# 礼包 contents（11000241 送 11000242 + 16000010×10）：证明"发物品"那半条也在。
	_查(_格("11000242") > 0 and _格("16000010") > 0,
			"金币礼包的 contents 应进背包（11000242 与 16000010 都在）")

	# —— 宝石镶嵌/摘除：ITEM_CHANGE(1040) 子命令 1/2（2026-10-02 实装镶嵌窗）——
	# `request_inlay(装备格, 宝石格)` / `request_uninlay(装备格, 孔号)`；服务端
	# `_inlay_equipment_stone:54233`（限属性/孔数上限，回 EQUIP_INLAY_INFO + 清格重发装备）、
	# `_remove_equipment_stone:54290`（宝石退回背包）。夹具种了长太刀(1010023,10星紫)与白色宝石(13000000)。
	var 装格 := _格("1010023")
	var 镶嵌石格 := _格("13000000")
	if 装格 <= 0 or 镶嵌石格 <= 0:
		_停("夹具应预置长太刀 1010023 与白色宝石 13000000（镶嵌用例的种子）")
		return
	var 装前: Array = _格物(装格).get("inlays", [])
	var 石前 := _件数("13000000")
	会话.call("inlay_stone", 装格, 镶嵌石格)
	if not await _wait_until(func(): return ( _格物(装格).get("inlays", []) as Array).size() > 装前.size(), 8000):
		# 服务端可能因"这类宝石不能镶嵌在该装备上"拒了 —— 停机并把装备/宝石报出来，好换一对。
		_停("镶嵌后装备 inlays 应 +1（装备=长太刀 1010023 宝石=白色 13000000，"
				+ "若被服务端按属性制拒则是**种子不匹配**，换一对：现 inlays=%s）"
				% str(_格物(装格).get("inlays", [])))
		return
	_查(true, "镶嵌：装备 inlays +1（回包 EQUIP_INLAY_INFO / 清格重发装备链）")
	_查(_件数("13000000") == 石前 - 1, "镶嵌消耗 1 颗宝石（%d→%d）" % [石前, _件数("13000000")])
	# ⭐ 提示框读的是**会话镜像**（`会话.inventory`，经 `落位带洞`），不是 backend 的权威清单 ——
	#   这条专门钉"镶嵌后装备提示框能看到镶嵌属性"的数据前提（用户 2026-10-02 报"提示框里没有镶嵌信息"）。
	var 会话装: Dictionary = 会话._占用条(会话.inventory, 装格)
	_查((会话装.get("inlays", []) as Array).size() >= 1
			and int((会话装.get("inlays", []) as Array)[0].get("stone_id", 0)) > 0,
			"会话镜像里的装备也该带 inlays（含 stone_id）——提示框 `_建镶嵌块` 读的就是它：实际 %s"
			% str(会话装.get("inlays", [])))
	# ⭐ 装备帧**尾部那四段**（原版 `CocoEquip.decode` 的 specialAttrList / specialLevel /
	#    specialEffectType / afterimageFlag）：文本桥 `_encode_item_payload` 补、客户端解析
	#    成 `special_attributes / special_level / special_effect_type / afterimage_flag`。
	#    这条**钉的是服务端真在发**（只有客户端侧的 parse 断言挡不住服务端漏发 ——
	#    客户端按"不足 33 段就当老帧"处理，服务端少发只会静默缺键）。
	#    变身卡互换窗的「特性」栏与装备提示框的特性段都靠它。
	var 会话装2: Dictionary = 会话._占用条(会话.inventory, 装格)
	_查(会话装2.has("special_attributes") and 会话装2.has("special_level")
			and 会话装2.has("special_effect_type") and 会话装2.has("afterimage_flag"),
			"装备帧尾部四段该解析出四个键（服务端 `_encode_item_payload` 漏发就会缺键）：实际 %s"
			% str(会话装2.keys()))
	# 摘除第 0 孔
	var 装中: Array = _格物(装格).get("inlays", [])
	会话.call("uninlay_stone", 装格, 0)
	if not await _wait_until(func(): return (_格物(装格).get("inlays", []) as Array).size() < 装中.size(), 8000):
		_停("摘除后装备 inlays 应 -1（_remove_equipment_stone:54290）")
		return
	_查(true, "摘除：装备 inlays 回退 1")
	_查(_件数("13000000") == 石前, "摘除把宝石退回背包（%d，回到镶嵌前）" % _件数("13000000"))

	# —— 宝石合成：ITEM_CHANGE(1040) 子命令 0（2026-10-03 实装「宝石工艺」窗的合成页）——
	# 真值 `_merge_equipment_stone:54052-54127`：一次请求按 `batches = quantity // 3` 把整摞所有
	# 完整三颗批**一起结算**，每批按 `merge.level{目标级}.prob` 掷一次，成功批把 `inlay.next`
	# 发 1 颗（继承 can_trade）；满级/不足 3 颗各有一句**服务端原话**
	# （`_send_character_notice` → 聊天帧 `1536:1:512:`）。
	# ⚠️ 失败那句"退还 1 颗"是**真退**：失败批回收两颗、退一颗回原堆叠（原版
	#   `EQUIP_STONE_COMPOSITE_DESCS_1`"合成失败则回收两颗宝石，退还一颗宝石"），
	#   所以 1042 的"剩余" = 余料 + 失败批数。
	# ⚠️ 顺序：**幸运合成先跑**（每发只吃 3 颗），普通合成放最后 —— 它一发放会把整摞吃干。
	var 合成回包: Array[Dictionary] = []
	var 合成话: Array[String] = []
	var 收合成包: Callable = func(_码: int, 果: Dictionary):
		if String(果.get("kind", "")) == "stone_merge":
			合成回包.append(果)
	# 2026-10-21：这两句话服务端走 `_send_system_chat` ⇒ `CHAR_NOTICE(512)` 帧。
	# 原来听 `chat_received` 是**搭错车**——512 不匹配任何聊天页签位，面板根本不渲染；
	# 现在客户端把 512 路由到 `notification_requested`（原版 `UI.as:376-377` 的
	# `addNotice` 等价物），改听那个信号：既拿到文案，也顺带钉住客户端路由没坏。
	var 收合成话: Callable = func(文: String):
		if 文 == "该宝石已达到最高等级。" or 文 == "合成需要三个同等级宝石。":
			合成话.append(文)
	backend.item_change_result_received.connect(收合成包)
	会话.notification_requested.connect(收合成话)
	var 满级格 := _格("13000009")
	var 两颗格 := _格("13020000")
	if 满级格 <= 0 or 两颗格 <= 0:
		_停("夹具应预置 13000009（满级种子）与 13020000×2（不足3 种子）")
		return
	# 1) 满级闸（直接走会话方法 —— 客户端 UI 在开门前就被"不开窗"那条拦了，钉不到服务端这句）
	会话.call("merge_stone", 满级格)
	if not await _wait_until(func(): return 合成话.size() >= 1, 6000):
		_停("满级宝石该收到「该宝石已达到最高等级。」")
		return
	_查(合成话[0] == "该宝石已达到最高等级。", "满级原话逐字（:54078，实际 %s）" % [合成话])
	_查(_件数("13000009") == 3, "满级被拒一颗都不许扣")
	# 2) 不足 3 颗
	会话.call("merge_stone", 两颗格)
	if not await _wait_until(func(): return 合成话.size() >= 2, 6000):
		_停("两颗同级宝石该收到「合成需要三个同等级宝石。」")
		return
	_查(合成话[1] == "合成需要三个同等级宝石。", "不足3原话逐字（:54081，实际 %s）" % [合成话])
	_查(_件数("13020000") == 2, "不足3被拒一颗都不许扣")

	# —— 宝石**幸运**合成：ITEM_CHANGE 子命令 **31**（原版 `StoneLuckyCompositeWindow`）——
	# 2026-10-11 §3.100 实装。真值：原版那页说明 `EQUIP_STONE_LUCKY_DESC` + 原版常量
	# （幸运符 `16000556` / 最多 **20** 张 / 每张 **+3%**，物品表那句描述与它逐字吻合）。
	# 与普通合成**共用同一条 1042 回包**（9 个 int = 成功/退还/剩余 三组），所以只钉三件事：
	#   ① 一次吃掉 3 颗；失败真退 1 颗回原堆叠（镜像净 -2，与动作 0 同口径，见上面那段行内注）；
	#   ② 幸运符按张数扣、且**夹在 20 张**（夹具给 40 张）；
	#   ③ **20 张时必定成功** —— `min(100, 80 + 20*3) = 100`，这是能**确定性**验"每张 +3%"的那一发。
	var 符基 := _件数("16000556")
	_查(符基 >= 40, "夹具应预置宝石幸运符 16000556（实际 %d）" % 符基)
	var 幸运回包: Array[Dictionary] = []
	var 收幸运: Callable = func(_码: int, 果: Dictionary):
		if String(果.get("kind", "")) == "stone_merge":
			幸运回包.append(果)
	backend.item_change_result_received.connect(收幸运)
	# ① 0 张：照样能合、幸运符一颗不动
	var 幸格 := _格("13010000")
	if 幸格 > 0 and _件数("13010000") >= 3:
		var 前0 := _件数("13010000")
		幸运回包.clear()
		backend.request_merge_stone_lucky(幸格, 0)
		if await _wait_until(func(): return not 幸运回包.is_empty(), 8000):
			var 果0: Dictionary = 幸运回包[0]
			var 成功0 := int(果0.get("success_count", 0)) == 1
			_查(int(果0.get("left_count", -1)) == 前0 - 3 + (0 if 成功0 else 1),
				"幸运合成 0 张：left_count 应为扣 3 退 1 后的件数（前 %d，%s）" % [前0, str(果0)])
			_查(_件数("13010000") == 前0 - 3 + (0 if 成功0 else 1),
				"幸运合成 0 张：失败真退 1 颗（前 %d → 现 %d）" % [前0, _件数("13010000")])
			_查(_件数("16000556") == 符基, "0 张不该扣幸运符（现 %d）" % _件数("16000556"))
		else:
			_停("幸运合成（0 张）没等到 1042 回包")
			return
	# ② 20 张：**必定成功**（80+60 夹到 100）+ 扣掉 20 张
	var 幸格2 := _格("13010000")
	if 幸格2 > 0 and _件数("13010000") >= 3:
		var 前1 := _件数("13010000")
		var 产1 := _件数("13010001")
		var 符1 := _件数("16000556")
		幸运回包.clear()
		backend.request_merge_stone_lucky(幸格2, 20)
		if await _wait_until(func(): return not 幸运回包.is_empty(), 8000):
			var 果1: Dictionary = 幸运回包[0]
			_查(int(果1.get("success_count", 0)) == 1,
				"20 张时成功率 min(100,80+20*3)=100 ⇒ **必定成功**（实际 %s）" % str(果1))
			_查(int(果1.get("left_count", -1)) == 前1 - 3, "20 张那发同样只吃 3 颗（%s）" % str(果1))
			_查(_件数("13010001") == 产1 + 1, "成功产物进背包（13010001：%d→%d）" % [产1, _件数("13010001")])
			_查(_件数("16000556") == 符1 - 20, "扣掉 20 张幸运符（%d→%d）" % [符1, _件数("16000556")])
		else:
			_停("幸运合成（20 张）没等到 1042 回包")
			return
	# ③ 夹到上限：手里只剩 20 张时再要 20 张 ⇒ 正好扣 20（不是 40）；一张不剩时再要 20 ⇒ 扣 0 且不报错
	var 符2 := _件数("16000556")
	if 符2 > 0:
		var 幸格3 := _格("13010000")
		if 幸格3 > 0 and _件数("13010000") >= 3:
			幸运回包.clear()
			backend.request_merge_stone_lucky(幸格3, 20)
			if await _wait_until(func(): return not 幸运回包.is_empty(), 8000):
				_查(_件数("16000556") == maxi(0, 符2 - 20),
					"张数夹到手里的实数（%d→%d，要 20）" % [符2, _件数("16000556")])
			else:
				_停("幸运合成（夹上限那发）没等到 1042 回包")
				return
		var 幸格4 := _格("13010000")
		if _件数("16000556") == 0 and 幸格4 > 0 and _件数("13010000") >= 3:
			幸运回包.clear()
			backend.request_merge_stone_lucky(幸格4, 20)
			if await _wait_until(func(): return not 幸运回包.is_empty(), 8000):
				_查(_件数("16000556") == 0, "一张都没有时不扣、也不报错（现 %d）" % _件数("16000556"))
			else:
				_停("幸运合成（无符那发）没等到 1042 回包")
				return
	backend.item_change_result_received.disconnect(收幸运)

	# ④ 真事务：一次请求把整摞所有完整三颗批一起结算（`batches = quantity // 3`），每批按
	#    prob=80%（1级→2级）掷一次；成功批进 1 颗 next，失败批退 1 颗回原堆叠。
	#    60 颗 = 20 批 ⇒ 至少一成功必现、至少一失败 98.8% 现；失败分支的**确定性**钉子在
	#    `测试/料理宝石结算回归测试.py`（forced rolls），这里钉线上回包与镜像的批量自洽。
	var 成格 := _格("13010000")
	var 成基 := _件数("13010000")
	if 成格 <= 0 or 成基 < 3:
		_停("夹具应预置黄色宝石(1级) 13010000（合成事务的种子），实际 %d" % 成基)
		return
	var 产基 := _件数("13010001")
	var 批 := 成基 / 3
	合成回包.clear()
	会话.call("merge_stone", 成格)
	if not await _wait_until(func(): return not 合成回包.is_empty(), 8000):
		_停("普通合成没等到 1042 回包")
		return
	var 果: Dictionary = 合成回包[0]
	var 成 := int(果.get("success_count", 0))
	var 败 := int(果.get("failed_count", 0))
	var 预期后 := 成基 - 3 * 批 + 败
	# 1042 排在背包镜像包**之后**发（:54114-54126），收到它时清格/更新/新增都已落到位
	_查(成 + 败 == 批, "回包成功+退还=整摞批数（%d+%d vs %d，%s）" % [成, 败, 批, str(果)])
	_查(成 > 0, "%d 批里至少一成功（全败概率 0.2^%d）" % [批, 批])
	_查(int(果.get("left_count", -1)) == 预期后,
			"left_count=扣 3*批、失败每批退 1（前 %d 批 %d 败 %d ⇒ %d，%s）" % [成基, 批, 败, 预期后, str(果)])
	_查(_件数("13010000") == 预期后, "背包剩 %d（前 %d，批 %d，败 %d）" % [预期后, 成基, 批, 败])
	_查(_件数("13010001") == 产基 + 成, "产物数=成功批数（基 %d + 成 %d，现 %d）" % [产基, 成, _件数("13010001")])
	_查(int(果.get("success_item_id", 0)) == 13010001 and int(果.get("success_level", 0)) == 2,
			"产物=链上那颗 next（13010001，级 2；fields[3] 是 `get_stone_inlay()[0]`=等级）")
	if 败 > 0:
		_查(int(果.get("failed_item_id", 0)) == 13010000 and int(果.get("failed_level", 0)) == 1,
				"失败位带的是**原那颗**（id+级）")
		_查(_件数("13020000") == 2 and _件数("13000009") == 3, "普通合成不该碰别的摞")
	backend.item_change_result_received.disconnect(收合成包)
	会话.notification_requested.disconnect(收合成话)

	# —— 仓库存取：存 6 拉面 → 取回 ——
	# ⚠️ 取仓直查 `backend.authoritative_storage`（330 的 flag4 推条会更新它）：
	#    原版没有"客户端请求开仓"的包（330 是服务端→客户端），走 `会话.withdraw_item`
	#    要先有 `会话.storage` 镜像，而那条同步链归 NPC 开窗流程 —— 门只管协议，
	#    不去替 UI 补握手。
	基 = _件数("3000001")
	会话.call("deposit_item", "3000001", 6)
	if not await _wait_until(func(): return _件数("3000001") == 基 - 6, 8000):
		_停("存仓后背包拉面应 -6（现 %d）" % _件数("3000001"))
		return
	_查(_仓里有("3000001"), "仓库镜像（330:4 推条）应见到拉面")
	var 仓格 := _仓格("3000001")
	基 = _件数("3000001")
	backend.request_storage_take_item(仓格, 6)
	if not await _wait_until(func(): return _件数("3000001") == 基 + 6, 8000):
		_停("取回后背包拉面应 +6（仓格 %d）" % 仓格)
		return
	_查(true, "存取往返成环")

	# —— 忍具兑换（§3.119）：六种八咫镜碎片各 1 ⇒ 一件八咫镜（`RENJU 2082` 动作 3）——
	# 这条**只能在线验**：离线门只钉了"点钮发不发 + 前置拦不拦"，
	# **帧的动作号/字段序对不对它照不到**（§3.118 就是这么被在线腿抓到一个字段错位的）。
	var 碎 := ["16000278", "16000279", "16000280", "16000281", "16000282", "16000283"]
	var 兑换前: Dictionary = {}
	var 碎片够 := true
	for id in 碎:
		兑换前[id] = _件数(id)
		if int(兑换前[id]) < 1:
			碎片够 = false
	if not 碎片够:
		_停("夹具没预置六种八咫镜碎片（%s）" % str(兑换前))
		return
	var 产前 := _件数("65000001")
	backend.request_renju_combine()
	var 兑换成 := await _wait_until(func():
		for id in 碎:
			if _件数(id) != int(兑换前[id]) - 1:
				return false
		return _件数("65000001") == 产前 + 1, 8000)
	if not 兑换成:
		_停("忍具兑换没生效：碎片前值 %s、产物 65000001 %d→%d"
			% [str(兑换前), 产前, _件数("65000001")])
		return
	_查(true, "六碎片各扣 1、进一件八咫镜 65000001（服务端 `handle_renju` COMBINE）")

	# —— 十拳剑兑换（§3.119）：六种十拳剑碎片各 1 ⇒ 十拳剑 20100001（`LING 2081` 动作 3）——
	# 与上面忍具那条同一个道理：**动作号/字段序只能在线验**。
	# 原版那一跳是 `LingEquipProcessor.requestLingEquipHeCheng`（byte 3 + 两个 int 0）。
	var 剑碎 := ["16000110", "16000111", "16000112", "16000113", "16000114", "16000115"]
	var 剑前: Dictionary = {}
	var 剑够 := true
	for id in 剑碎:
		剑前[id] = _件数(id)
		if int(剑前[id]) < 1:
			剑够 = false
	if not 剑够:
		_停("夹具没预置六种十拳剑碎片（%s）" % str(剑前))
		return
	var 剑产前 := _件数("20100001")
	backend.request_ling_equip_combine()
	var 剑成 := await _wait_until(func():
		for id in 剑碎:
			if _件数(id) != int(剑前[id]) - 1:
				return false
		return _件数("20100001") == 剑产前 + 1, 8000)
	if not 剑成:
		_停("十拳剑兑换没生效：碎片前值 %s、产物 20100001 %d→%d"
			% [str(剑前), 剑产前, _件数("20100001")])
		return
	_查(true, "六碎片各扣 1、进一件十拳剑 20100001（服务端 `_combine_ling_qi` COMBINE）")

	# —— 整理：格位不重不漏 + **原有 id 一件不许少** ——
	# ⚠️ 不能钉"逐 id 精确相等"：吃拉面会推进 USE_ITEM 任务，任务奖励在门跑的过程中
	# 异步到账（实测第一版就被"拉面 +6 / 15020001 +495"污染过 —— 那是**任务发放**，
	# 不是整理造件）。整理的本职是"重排不减件"，就按这个断：**只许多不许少**。
	var 总前: Dictionary = {}
	for 条 in _inv():
		总前[String((条 as Dictionary).get("id", ""))] = int((条 as Dictionary).get("quantity", 1))
	backend.request_item_sort(0)
	await create_timer(1.0).timeout
	var 格位 := {}
	var 不合法 := 0
	for 条 in _inv():
		var 格号 := int((条 as Dictionary).get("slot_index", 0))
		if 格位.has(格号) or 格号 <= 0:
			不合法 += 1
		格位[格号] = true
		if int((条 as Dictionary).get("quantity", 1)) <= 0:
			不合法 += 1
	_查(不合法 == 0, "整理后格位应不重不漏且件数>0（违规 %d）" % 不合法)
	var 少了 := ""
	for 键 in 总前:
		if _件数(键) < int(总前[键]):
			少了 += " %s:%d→%d" % [键, int(总前[键]), _件数(键)]
	_查(少了.is_empty(), "整理不许减件（少了%s）" % 少了)
	if _失败.is_empty():
		print("道具真实事务在线回归测试：通过（%d 条断言：使用/flags双语义/拆分/销毁/换位/绑定/点券金币礼包/宝石镶嵌摘除/宝石合成/宝石幸运合成/存取往返/整理）" % _受检)
	backend.disconnect_backend()
	if _失败.is_empty():
		quit(0)
		return
	for 项 in _失败:
		printerr("道具真实事务在线回归测试：" + 项)
	quit(1)

func _格物(格号: int) -> Dictionary:
	for 条 in _inv():
		if int((条 as Dictionary).get("slot_index", 0)) == 格号:
			return 条 as Dictionary
	return {}

func _仓里有(物品id: String) -> bool:
	return _仓格(物品id) != 0

func _仓格(物品id: String) -> int:
	for 条 in (root.get_node("/root/BackendConnection") as Node).authoritative_storage:
		if String((条 as Dictionary).get("id", "")) == 物品id:
			return int((条 as Dictionary).get("slot_index", 0))
	return 0
