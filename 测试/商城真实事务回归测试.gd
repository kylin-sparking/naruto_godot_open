extends SceneTree

## ⚠️ 2026-09-26 改：原版商城的真表是抓包 `2.2.3/tools/nya_208_cash_catalog.json`，
## 里面**没有 3000001（拉面）** —— 那是我们先前按"GameData 分区"重建出来的假货架。
## 换成抓包分类 0 的第一件：sn=100 / 物品 16000180（改名卡，原价 8888 → 现价 3456，打折+热卖）。
const ITEM_ID := 16000180

var _catalog_events: Array[Dictionary] = []
var _item_info := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	if backend == null:
		_fail("缺少后端连接单例")
		return
	backend.cash_shop_received.connect(func(items: Array, total: int, source: String): _catalog_events.append({"items": items.duplicate(true), "total": total, "source": source}))
	backend.cash_item_info_received.connect(func(item: Dictionary): _item_info = item.duplicate(true))
	backend.sync_character()
	if not await _wait_until(func(): return backend.in_game and not backend.authoritative_inventory.is_empty(), 10000):
		_fail("无法进入真实后端：%s - %s" % [backend.status, backend.detail])
		return

	if not backend.request_cash_money() or not await _wait_until(func(): return int(backend.authoritative_stats.get("cash", -1)) >= 0, 3000):
		_fail("服务端未返回 1073 点券")
		return
	# ⚠️ 背包格数**只从进图 CHAR_INFO 那份权威值读**，不许再用 1084 "查"：
	#   1084 是**申请扩充**这个动作（服务端 `handle_bag_capacity_extend`），发一次就
	#   要么广播"扩充背包需要N个扩充密卷"、要么**真扣密卷把背包 +30 格**。
	#   2026-10-21 用户实机报的"进商城就提示要 162 个密卷"就是客户端把它当查询用了。
	if int(backend.authoritative_bag_capacity) <= 0:
		_fail("CHAR_INFO 没下发背包格数（authoritative_bag_capacity=%d）" % int(backend.authoritative_bag_capacity))
		return
	await create_timer(0.1).timeout
	if not backend.request_cash_shop_category(1, 0, 29):
		_fail("商城分类请求未发送")
		return
	if not await _wait_until(func(): return _has_source("category"), 5000):
		_fail("服务端未返回 1074 分类目录")
		return

	# 搜索词用商品名而不是编号：服务端 handle_cash_search 像原版客户端一样按
	# `keyword in definition.name` 匹配，传编号会搜不到（编号能搜是原一键端 C# 服务的便利，
	# 本机 Python 服务端没有这个行为）。其余断言不变。
	var game_data := root.get_node_or_null("GameData")
	var item_name := "" if game_data == null else String(game_data.item_name(str(ITEM_ID)))
	if item_name.is_empty() or not backend.request_cash_shop_search(item_name, -1, 0, 29):
		_fail("商城搜索请求未发送")
		return
	if not await _wait_until(func(): return not _find_catalog_item(ITEM_ID).is_empty(), 5000):
		_fail("服务端 1075 搜索没有返回目标商品")
		return
	var product := _find_catalog_item(ITEM_ID)
	if int(product.get("price", 0)) <= 0 or String(product.get("name", "")).is_empty():
		_fail("真实商城商品缺少价格或物品定义")
		return

	await create_timer(0.1).timeout
	if not backend.request_cash_item_info(int(product.get("sn", 0))):
		_fail("商城详情请求未发送")
		return
	if not await _wait_until(func(): return int(_item_info.get("item_id", 0)) == ITEM_ID, 4000):
		_fail("服务端 1079 没有返回目标商品详情")
		return

	await create_timer(0.1).timeout
	var cash_before := int(backend.authoritative_stats.get("cash", 0))
	var quantity_before := _item_quantity(backend.authoritative_inventory, ITEM_ID)
	if not backend.request_cash_shop_buy(int(product.get("sn", 0)), 1):
		_fail("真实商城购买请求未发送")
		return
	if not await _wait_until(func(): return int(backend.authoritative_stats.get("cash", 0)) == cash_before - int(product.price) and _item_quantity(backend.authoritative_inventory, ITEM_ID) == quantity_before + 1, 5000):
		_fail("购买未由服务端同时扣除点券并增加权威背包物品")
		return

	# ---- 礼金品（`is_lijin`）扣的是**点券**（`coupon_money`），不是元宝 ----
	# ⚠️ 2026-10-16 用户实机报"购买后点券、元宝不减少"钉出来的缺口：
	#    服务端买完只回 `handle_cash_money`（= 1073，**只带元宝** `cash_money`），
	#    礼金品扣的那笔 `coupon_money` **没有任何回帧** ⇒ 客户端「点券」栏永远不刷新。
	#    已让 `handle_cash_shopping` 在同一行补发 `_send_stats({CASH_BIND})`；这里钉住它。
	# 直接按 **sn** 买（服务端 `_cash_row_by_sn` 是全局查，与客户端当前加载了哪一页无关）
	# ⇒ 不必依赖"这一页里恰好有礼金品"。
	# 取值出处：`服务端/runtime/tools/nya_208_cash_catalog.json`（base64 打包，按 `NYA208_CASH_ROW_STRUCT`
	# 解出来）里 116 行有 29 行是礼金品；`sn=1012` = 物品 `16000004`（扩充密卷）、现价 **10**、`is_lijin=1`。
	# ⚠️ 这件就是玩家"扩充"那扇窗点「购买」买到的东西。
	const 礼金sn := 1012
	const 礼金物 := 16000004
	const 礼金价 := 10
	# ⚠️ 判据取**会话的 `player_stats.cash_bind`** —— 那才是界面读的那一项
	#   （背包「商城点券」行 / 商城页都读它）。`authoritative_stats` 里那笔落在 `cashBind`
	#   这个**中转键**上（`_handle_stats_text` 的字段表 → `服务端会话同步` 再映射到 `cash_bind`），
	#   拿 `authoritative_stats.get("cash_bind")` 去判会**恒 0**（我第一版就这么写错了）。
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_fail("缺少 GameSession 单例")
		return
	var 券前 := int((会话.get("player_stats") as Dictionary).get("cash_bind", 0))
	var 礼金物前 := _item_quantity(backend.authoritative_inventory, 礼金物)
	# 第三参 = **钱包选择器**（原版 `BuyEqpWindow.as:353` 的 `shopType`：0 元宝 / 1 点券）。
	# 礼金品在界面上默认勾的就是「点券」⇒ 这里必须传 1，才能同时钉住
	# 「客户端把选择器带进报文」和「夹具按选择器扣 `coupon_money`」这两条（2026-10-17 #17）。
	if not backend.request_cash_shop_buy(礼金sn, 1, 1):
		_fail("礼金品购买请求未发送")
		return
	if not await _wait_until(func(): return _item_quantity(backend.authoritative_inventory, 礼金物) == 礼金物前 + 1, 5000):
		_fail("礼金品买了但背包没入账")
		return
	if not await _wait_until(func(): return int((会话.get("player_stats") as Dictionary).get("cash_bind", 0)) == 券前 - 礼金价, 3000):
		_fail("礼金品扣的是点券，但服务端没把新的点券推回客户端（player_stats.cash_bind 停在 %d，应为 %d）"
			% [int((会话.get("player_stats") as Dictionary).get("cash_bind", 0)), 券前 - 礼金价])
		return

	# ---- 会话那层的转发（`游戏会话.buy_shop_item` 第三参 `用点券`，2026-10-17 #17）----
	# 离线门钉不到这一支：`_online_backend()` 按 `/root/BackendConnection` + `in_game` 找**真人单例**，
	# 而离线门用的是 `测试/测试后端连接.gd` 那份替身 ⇒ 恒 null、只会落本地 `_purchase_product`。
	# 货架里塞一行 `sn=1012 / id=16000004` ⇒ 走的正是界面那条「按 id 在货架里找」的第一支。
	# ⚠️ `shop_catalog` 是 `Array[Dictionary]`（**带类型**）⇒ 不能用 `set("shop_catalog", [ ... ])`：
	#    无类型字面量过不了类型校验，货架没换、`buy_shop_item` 找不到那一行、直接 return false（实测撞过）。
	#    这里走**直连属性**赋值，两边都用 `Array[Dictionary]` 局部变量。
	var 原货架: Array[Dictionary] = 会话.shop_catalog
	var 礼金货架: Array[Dictionary] = [{"id": "16000004", "sn": 礼金sn, "price": 礼金价, "name": "扩充密卷"}]
	会话.shop_catalog = 礼金货架
	var 券前二 := int((会话.get("player_stats") as Dictionary).get("cash_bind", 0))
	var 入账二 := _item_quantity(backend.authoritative_inventory, 礼金物) + 1
	if not 会话.buy_shop_item("16000004", 1, true):
		会话.shop_catalog = 原货架
		_fail("会话按点券买礼金品没发出请求（`buy_shop_item` 返回 false）")
		return
	if not await _wait_until(func(): return _item_quantity(backend.authoritative_inventory, 礼金物) == 入账二 and int((会话.get("player_stats") as Dictionary).get("cash_bind", 0)) == 券前二 - 礼金价, 5000):
		var 实测二 := int((会话.get("player_stats") as Dictionary).get("cash_bind", 0))
		会话.shop_catalog = 原货架
		_fail("会话/夹具这一环没按「点券」扣：买第二件礼金品后点券停在 %d，应为 %d（选择器被丢就恒按元宝扣）"
			% [实测二, 券前二 - 礼金价])
		return
	会话.shop_catalog = 原货架

	# ---- 夹具按**报文里的选择器**扣钱，不再按 `is_lijin` 猜（#17 的夹具那一半）----
	# 还是那件礼金品，这次**选元宝**付 —— 原版买得到：`BuyEqpWindow.as:226` 那句
	# `ybCheckBox.enabled = false` 只在**非礼金**分支里，礼金品的元宝勾选是**可用**的
	# （`WaiGuaHandler.as:229/233` 也是两条都发：够 bandMoney 才发 1，否则发 0）。
	# 修之前夹具把首字段当**货架分类**读（买一次还会顺手把 `active_cash_category_id` 切走），
	# 扣哪笔全看 `is_lijin` ⇒ 这两条必红。
	var 元宝前 := int(backend.authoritative_stats.get("cash", 0))
	var 券前三 := int((会话.get("player_stats") as Dictionary).get("cash_bind", 0))
	var 入账三 := _item_quantity(backend.authoritative_inventory, 礼金物) + 1
	if not backend.request_cash_shop_buy(礼金sn, 1, 0):
		_fail("选元宝买礼金品的请求没发出去")
		return
	if not await _wait_until(func(): return _item_quantity(backend.authoritative_inventory, 礼金物) == 入账三 and int(backend.authoritative_stats.get("cash", 0)) == 元宝前 - 礼金价, 5000):
		_fail("选元宝付没扣到 `cash_money`（元宝停在 %d，应为 %d）—— 夹具还在按 `is_lijin` 猜钱包"
			% [int(backend.authoritative_stats.get("cash", 0)), 元宝前 - 礼金价])
		return
	await create_timer(0.3).timeout
	var 券后三 := int((会话.get("player_stats") as Dictionary).get("cash_bind", 0))
	if 券后三 != 券前三:
		_fail("选元宝付却动了点券（%d → %d）：选择器被读反了" % [券前三, 券后三])
		return

	print("商城真实事务回归测试：通过（目录/搜索/详情/容量、元宝扣款、**礼金品扣点券并回帧**、"
			+ "**会话把钱包选择器带到报文**、**夹具按选择器扣（礼金品也能选元宝）**、背包入账）")
	backend.disconnect_backend()
	quit(0)

func _has_source(source: String) -> bool:
	for event in _catalog_events:
		if String(event.get("source", "")) == source:
			return true
	return false

func _find_catalog_item(item_id: int) -> Dictionary:
	for event in range(_catalog_events.size() - 1, -1, -1):
		for item in _catalog_events[event].get("items", []):
			if item is Dictionary and int(item.get("item_id", 0)) == item_id:
				return item
	return {}

func _item_quantity(items: Array, item_id: int) -> int:
	var total := 0
	for item in items:
		if item is Dictionary and int(item.get("id", 0)) == item_id:
			total += int(item.get("quantity", 0))
	return total

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())

func _fail(message: String) -> void:
	push_error("商城真实事务回归测试：失败 - %s" % message)
	quit(1)
