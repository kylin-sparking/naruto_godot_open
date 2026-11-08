extends SceneTree

## 一键出售**真实事务**回归门（2026-10-17 巡检 #18 的在线那一半）。
##
## 病根（离线门照不到的那半）：客户端原来把「一键出售」当"卖 1~30 格"发
## （`request_npc_shop_one_key_sell(起始格, 结束格, 品质)` 三个参数，品质那格还是写死 0）
## ⇒ 服务端 `_request_fields` 拿到的字段数不够 ⇒ 整条落进 `handle_npc_shop` 的 else ⇒ **恒回 SHOP_ERROR(32)**，
## 玩家点确定什么都没卖出去。真值是 `PacketCreator.getNPCShopOnekeySellRequestPacket:102-111`
## 的 `writeByte(5)` + **4 个 writeInt**（等级/星级/品质上限 + `QuickSaleWindow.as:18-22` 的目标位图）。
##
## 这条门用**四步矩阵**把四个字段逐个钉在真服务端上 —— 每步只动一个变量，
## 哪个字段被丢了、哪一位没生效，红的是哪一句就写得清：
##
##   步 A `20/3/3/1`（只勾装备）   ⇒ 30 格之后的小太刀**全卖**（#18 的 headline：扩容格卖得到）
##                                  鬼丸刀 reqLevel 40 > 20 ⇒ **留下**（等级档真的到了夹具）
##                                  残卷 / 玉链**留下**（位图 2、4 关掉时不该动它们）
##   步 B `20/3/3/3`（+残卷）      ⇒ 怪力残卷卖掉、**奥义残卷留下**（TIPS 第 4 条）
##   步 C `20/3/3/7`（+玉链）      ⇒ 稻荷玉链卖掉（reqLevel 45、夹具发时 aptitude 置 0 ⇒ 非紫未镶嵌，TIPS 第 3 条）
##   步 D `40/3/3/1`（抬等级档）   ⇒ 鬼丸刀卖掉（40 ≤ 40，边界值）
##   全程   长太刀**一次都没卖**   ⇒ 夹具把它预置成 10 星紫装 ⇒ 星级档最高才 6、品质档最高才 3（TIPS 第 1、2 条）
##
## 每步都先钉**确认码 == 8（SELL_SUCCESS）**再看金币涨幅：只等金币的话，
## "被服务端整条拒掉"会伪装成"没卖到"，正是 #18 当时的表现。
##
## ⚠ 种子：这条要夹具按 `--items` **整张换掉**默认背包（`开发工具/跑在线用例.ps1` 的 `$夹具额外`）。
##   30 件小太刀是**垫格子的**：装备类发放**不叠摞**（`gm_admin._add_offline_item` 里 `equipment is not None`
##   直接跳过叠摞支），所以 30 条 `1010013:1` 占 30 格 ⇒ 后面那五件真材料必然落在 **30 格之后**。
##   缺料 / 材料没落到 30 格外 ⇒ 门自己会红并说"是夹具没发"，不许静默放行。
##   ⚠️ 判"缺料"之前必须先**等镜像落稳**：背包是分块下发的（`_handle_inventory_snapshot` 收齐
##     `fields[1]` 块才一次性 assign），48 格的种子包第一版这里 raced 过一次（红成"夹具没发 1010033"）。
##
## 反向对照（2026-10-17，四条全红过、跑完逐条 `cp` 还原并核对字节数）：
##   R3 客户端退回旧三位报文 ⇒ A「确认码 32」；R1 夹具忽略目标位图 ⇒ B「金币没涨」；
##   R2 夹具忽略等级档 ⇒ A「等级档 20 没管住 reqLevel 40」；R4 去掉奥义例外 ⇒ B「奥义残卷被吃掉」。
##
## 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 一键出售`

const 小太刀 := 1010013		# reqLevel 1；发放默认 aptitude 2(绿)、0 星 ⇒ 该卖
const 鬼丸刀 := 1010033		# reqLevel 40 ⇒ 等级档 20 留、40 卖（边界）
const 长太刀 := 1010023		# `seed_forge_ready_weapon` 预置成 10 星紫装 ⇒ 任何时候都不该卖
const 怪力残卷 := 8000001	# section JiNengCanJuan、配方目标《怪力》⇒ 勾残卷才卖
const 奥义残卷 := 8000033	# 《朝孔雀》= 八门遁甲神秘奥义禁术 ⇒ 永远不卖（TIPS 第 4 条）
const 玉链 := 1200010		# 稻荷玉链（EquipS1、type 前缀 120、reqLevel 45）⇒ 勾玉链才卖

const 出格材料 := [鬼丸刀, 怪力残卷, 玉链]	# 这三件必须落在第 30 格之后（#18 的现场）

var _确认: Array[int] = []
var _原端口 := -1


## 镜像里六类种子都在、小太刀够 20 摞、三件关键材料出了 30 格。
func _种子齐(backend: Node) -> bool:
	var items: Array = backend.authoritative_inventory
	for 件 in [小太刀, 鬼丸刀, 长太刀, 怪力残卷, 奥义残卷, 玉链]:
		if _件数(items, 件) <= 0:
			return false
	if _件数(items, 小太刀) < 20:
		return false
	for 件 in 出格材料:
		if _格(items, 件) <= 30:
			return false
	return true


## 等不到稳定态时把原因说清（缺料 / 没出 30 格），不许含糊成"连不上服务端"。
func _报种子问题(backend: Node) -> void:
	var items: Array = backend.authoritative_inventory
	for 件 in [小太刀, 鬼丸刀, 长太刀, 怪力残卷, 奥义残卷, 玉链]:
		if _件数(items, 件) <= 0:
			_fail("夹具没发种子材料 %d（跑在线用例.ps1 的 `--items` 那一条；镜像现有 %d 格）" % [件, items.size()])
			return
	if _件数(items, 小太刀) < 20:
		_fail("小太刀只有 %d 摞（垫格子要 30 摞），30 格之后那支照不到" % _件数(items, 小太刀))
		return
	for 件 in 出格材料:
		if _格(items, 件) <= 30:
			_fail("种子材料 %d 落在第 %d 格，没到 30 格之后 ⇒ 这一支照不到「扩容后的格子卖不到」" % [件, _格(items, 件)])
			return
	_fail("种子状态判不出来（镜像 %d 格）" % items.size())


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	if backend == null:
		_fail("缺少后端连接单例")
		return
	# ⚠️ **必须自己把端口指到夹具**：客户端只认 `game_settings.backend_port`（缺省 18684 会连到
	#    用户自己那台，测的就不是夹具）—— 独立端口的门都这一段（§3.180 那条口径）。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18710
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		var 设置: Dictionary = 会话.get("game_settings")
		_原端口 = int(设置.get("backend_port", -1))
		设置["backend_port"] = 口
		print("连夹具端口 %d" % 口)
	backend.shop_transaction_received.connect(func(code: int) -> void: _确认.append(code))
	backend.sync_character()
	if not await _wait_until(func(): return backend.in_game and not backend.authoritative_inventory.is_empty(), 10000):
		_fail("无法进入真实后端：%s - %s" % [backend.status, backend.detail])
		return
	if not await _wait_until(func(): return int(backend.authoritative_stats.get("gold", -1)) >= 0, 3000):
		_fail("服务端没把金币推下来（每步卖完都靠它的增量认账）")
		return

	# ---- 前置：种子齐不齐、有没有真落到 30 格之后 ----
	# ⚠️ 背包是**分块**下发的（`_handle_inventory_snapshot` 收齐 `fields[1]` 块才一次性 assign），
	#    48 格的种子包不能"看一眼就判缺料"⇒ 先等镜像落到稳定态，等不到再说清缺哪一件。
	if not await _wait_until(func() -> bool: return _种子齐(backend), 8000):
		_报种子问题(backend)
		return

	# ---- 步 A：只勾装备。等级档要真的传到夹具（鬼丸刀留下），格子位置不再是限制 ----
	var 鬼丸前 := _件数(backend.authoritative_inventory, 鬼丸刀)
	if not await _卖(backend, 20, 3, 3, 1, "A"):
		return
	if _件数(backend.authoritative_inventory, 小太刀) != 0:
		_fail("A：30 格之后还留着 %d 摞小太刀 —— 老 bug 就是只卖 1~30 格"
				% _件数(backend.authoritative_inventory, 小太刀))
		return
	if _件数(backend.authoritative_inventory, 鬼丸刀) != 鬼丸前:
		_fail("A：等级档 20 没管住 reqLevel 40 的鬼丸刀（卖出说明那三个上限被夹具忽略了）")
		return
	if _件数(backend.authoritative_inventory, 怪力残卷) == 0 or _件数(backend.authoritative_inventory, 玉链) == 0:
		_fail("A：目标位图只给 1（装备），残卷 / 玉链不该被卖掉")
		return

	# ---- 步 B：位图加残卷（2）⇒ 普通残卷卖、奥义残卷留 ----
	if not await _卖(backend, 20, 3, 3, 1 | 2, "B"):
		return
	if _件数(backend.authoritative_inventory, 怪力残卷) != 0:
		_fail("B：勾了残卷却没卖《怪力》残卷（位图 2 没读到，或 section 判据没对上）")
		return
	if _件数(backend.authoritative_inventory, 奥义残卷) == 0:
		_fail("B：《朝孔雀》是奥义残卷，TIPS 第 4 条说不卖，却被一键出售吃掉了")
		return

	# ---- 步 C：位图加玉链（4）⇒ 玉链卖；等级档 20 依然管不住 reqLevel 40 的鬼丸刀 ----
	if not await _卖(backend, 20, 3, 3, 1 | 2 | 4, "C"):
		return
	if _件数(backend.authoritative_inventory, 玉链) != 0:
		_fail("C：勾了玉链却没卖稻荷玉链（位图 4 没读到，或 EquipS1/type 120 判据没对上）")
		return

	# ---- 步 D：只把等级档抬到 40（鬼丸刀 reqLevel 正好 40）⇒ 它该卖掉，位图收回 1 ----
	if not await _卖(backend, 40, 3, 3, 1, "D"):
		return
	if _件数(backend.authoritative_inventory, 鬼丸刀) != 0:
		_fail("D：等级档抬到 40 还是没卖 reqLevel 40 的鬼丸刀")
		return
	if _件数(backend.authoritative_inventory, 长太刀) == 0 \
			or _件数(backend.authoritative_inventory, 奥义残卷) == 0:
		_fail("终局：长太刀（10 星紫装，TIPS 第 1、2 条）或奥义残卷被卖掉了一件")
		return

	print("一键出售真实事务回归测试：通过（四个字段逐个钉死：等级档 / 目标位图 1|2|4 / "
			+ "30 格之后照得到 / 奥义残卷与 10 星紫装留下 / 每步确认码 8 + 金币上涨）")
	_还原端口()
	backend.disconnect_backend()
	quit(0)


## 发一键出售并等**确认码 + 金币涨幅**双证据。任何一环不对就当场红并回 false
## （`quit()` 只排到帧尾，调用方必须自己 `return`，否则同一轮会重复红第二遍）。
func _卖(backend: Node, 等级: int, 星级: int, 品质: int, 目标: int, 步: String) -> bool:
	var 金前 := int(backend.authoritative_stats.get("gold", 0))
	_确认.clear()
	if not backend.request_npc_shop_one_key_sell(等级, 星级, 品质, 目标):
		_fail("%s：一键出售请求没发出去（%d/%d/%d/位图%d）" % [步, 等级, 星级, 品质, 目标])
		return false
	if not await _wait_until(func(): return not _确认.is_empty(), 4000):
		_fail("%s：%d/%d/%d/位图%d 发出去了，服务端没回 58 确认帧" % [步, 等级, 星级, 品质, 目标])
		return false
	var 码 := int(_确认[_确认.size() - 1])
	if 码 != 8:
		_fail("%s：服务端确认码 %d（8=卖出成功，32=商店出错 —— #18 那版报文少一个字段就是恒 32）" % [步, 码])
		return false
	if not await _wait_until(func(): return int(backend.authoritative_stats.get("gold", -1)) > 金前, 4000):
		_fail("%s：确认卖出成功但金币没涨（金前 %d，现 %d）"
				% [步, 金前, int(backend.authoritative_stats.get("gold", -1))])
		return false
	await create_timer(0.3).timeout
	return true


func _件数(items: Array, item_id: int) -> int:
	var total := 0
	for item in items:
		if item is Dictionary and int(item.get("id", 0)) == item_id:
			total += int(item.get("quantity", 0))
	return total


func _格(items: Array, item_id: int) -> int:
	var 最高 := 0
	for item in items:
		if item is Dictionary and int(item.get("id", 0)) == item_id:
			最高 = max(最高, int(item.get("slot_index", 0)))
	return 最高


func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())


## 借来的端口要还回去（红也一样还），否则用户明天开的客户端会连到 18710 上。
func _还原端口() -> void:
	if _原端口 < 0:
		return
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		(会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
	_原端口 = -1


func _fail(message: String) -> void:
	_还原端口()
	push_error("一键出售真实事务回归测试：失败 - %s" % message)
	quit(1)
