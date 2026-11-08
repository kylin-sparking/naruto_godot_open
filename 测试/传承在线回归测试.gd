extends SceneTree

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")

var _main
var _peer

## 断言失败的累积。
## ⚠️ 原来**一失败就 return**，于是后面那些模块从来没被验过 —— 实测这条用例一直卡在
##    「宝箱」那步，后面的 料理/结印/暗器/心法 **一次都没跑过**（2026-09-25 发现）。
##    改成攒起来、最后一起报。（登录/选角那种"没它就没法继续"的仍走 `_fail` 提前返回。）
var _失败: Array[String] = []


func _步(条件: bool, 消息: String) -> void:
	if not 条件:
		_失败.append(消息)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_id := int(OS.get_environment("NW_LEGACY_MAIN_ID"))
	var peer_id := int(OS.get_environment("NW_LEGACY_PEER_ID"))
	var first_slot := int(OS.get_environment("NW_LEGACY_FUSION_FIRST_SLOT"))
	var second_slot := int(OS.get_environment("NW_LEGACY_FUSION_SECOND_SLOT"))
	if min(main_id, peer_id, first_slot, second_slot) <= 0:
		_fail("夹具环境变量不完整")
		return

	_main = BACKEND_SCRIPT.new()
	_main.name = "LegacyOnlineMain"
	root.add_child(_main)
	_peer = BACKEND_SCRIPT.new()
	_peer.name = "LegacyOnlinePeer"
	root.add_child(_peer)
	# 两条连接必须用**不同账号**：服务端 enter_world 按账号踢会话
	# （sessions_by_account），同账号不可能同时在线两次——真实游戏里双修也是两个玩家。
	# 第二账号由夹具提供（NW_LEGACY_PEER_ACCOUNT/PASSWORD）。
	_main.connect_backend("naruto", "123456", false)
	_peer.connect_backend(
		OS.get_environment("NW_LEGACY_PEER_ACCOUNT"),
		OS.get_environment("NW_LEGACY_PEER_PASSWORD"),
		false,
	)
	if not await _wait_until(func(): return _main.authenticated and _peer.authenticated, 10000):
		_fail("两个真实后端连接未完成登录")
		return
	if not _main.select_character(main_id) or not _peer.select_character(peer_id):
		_fail("临时角色无法选择")
		return
	if not await _wait_until(func(): return _main.in_game and _peer.in_game, 10000):
		_fail("临时角色无法进入游戏")
		return
	_步(await _wait_until(func(): return _item_quantity(_main.authoritative_inventory, 12100000) == 20 and _item_quantity(_main.authoritative_inventory, 16000053) == 1, 5000), "服务端未下发夹具背包快照")

	_main.request_card_node(40, 0)
	_步(await _wait_until(func(): return int(_main.authoritative_card.get("node_id", -1)) == 0 and (_main.authoritative_card.get("items", []) as Array).size() == 5, 4000), "1392 未返回卡牌节点材料状态")
	_main.request_card_commit(40, 0)
	_步(await _wait_until(func(): return bool(_main.authoritative_card.get("committed", false)), 4000), "卡牌提交未由服务端原子扣除五种材料")
	_main.request_card_claim(40, 0)
	_步(await _wait_until(func(): return bool(_main.authoritative_card.get("claimed", false)) and int(_main.authoritative_stats.get("remainingAp", 0)) == 10, 4000), "卡牌 AP 奖励未由服务端一次性发放")

	_main.request_chest_open(10001)
	_步(await _wait_until(func(): return bool(_main.authoritative_chest.get("open", false)) and int(_main.authoritative_chest.get("action", -1)) == 3 and not (_main.authoritative_chest.get("items", []) as Array).is_empty(), 4000), "1826 未消耗钥匙并返回宝箱候选")
	var first_roll := _chest_signature(_main.authoritative_chest.get("items", []))
	_main.request_chest_close(10001)
	_步(await _wait_until(func(): return not bool(_main.authoritative_chest.get("open", true)), 4000), "宝箱关闭状态未确认")
	_main.request_chest_open(10001)
	_步(await _wait_until(func(): return bool(_main.authoritative_chest.get("open", false)) and int(_main.authoritative_chest.get("action", -1)) == 3, 4000), "宝箱无法重新打开")
	_步(not (_chest_signature(_main.authoritative_chest.get("items", [])) != first_roll), "宝箱重开后候选被重新随机")
	_main.request_chest_claim_all(10001)
	_步(await _wait_until(func(): return bool(_main.authoritative_chest.get("completed", false)), 4000), "宝箱全部领取未持久化完成状态")

	_main.request_buff_fusion(first_slot, second_slot)
	_步(await _wait_until(func(): return bool(_main.authoritative_buff_fusion.get("success", false)) and int(_main.authoritative_buff_fusion.get("item_id", 0)) == 15003016, 4000), "1822 未原子扣除双槽材料并发放原版料理")
	# 结印上行只有 byte 0（`requestJieYin_EatUp`）；`result` 帧只带 `result,addCount`，
	# 权威 `2318:0` 只带 `stage,count` ⇒ **精华余额只能从 STATS(22) 那一路看**，别在结印状态里编 `zq`。
	var zq_之前 := int(_main.authoritative_stats.get("zq", -1))
	_main.request_jieyin()
	_步(await _wait_until(func(): return int(_main.authoritative_jieyin.get("count", 0)) > 0, 4000), "2318 未持久化结印熟练度")
	_步(await _wait_until(func(): return int(_main.authoritative_stats.get("zq", zq_之前)) < zq_之前, 4000),
		"结印那一跳没由服务端扣除查克拉精华（STATS 22）")
	_main.request_shuriken(0, true)
	_步(await _wait_until(func(): return bool(_main.authoritative_anqi.get("open", false)), 4000), "1817 未持久化暗器启用状态")
	_main.request_shuriken(2, true)
	_步(await _wait_until(func(): return int(_main.authoritative_anqi.get("level", 0)) == 4 and int(_main.authoritative_anqi.get("master", 0)) == int(_main.authoritative_anqi.get("master_max", -1)), 5000), "暗器自动培养未消费材料并达到当前阶段上限")
	_main.request_xinfa_change(7)
	_步(await _wait_until(func(): return int(_main.authoritative_heal.get("xinfa_id", 0)) == 7, 4000), "心法切换未持久化")

	if int(_main.authoritative_map_id) != int(_peer.authoritative_map_id):
		_peer.request_map_change(int(_main.authoritative_map_id), int(_main.authoritative_position.x), int(_main.authoritative_position.y))
		_步(await _wait_until(func(): return int(_peer.authoritative_map_id) == int(_main.authoritative_map_id), 5000), "双修角色无法进入同一地图")
	_main.request_double_heal_invite(peer_id)
	_步(await _wait_until(func(): return int(_peer.authoritative_heal.get("pending_inviter_id", 0)) == main_id and int(_main.authoritative_heal.get("invited_character_id", 0)) == peer_id, 5000), "双修邀请未路由到目标在线会话")
	## 先走**拒绝**那一支（#260 之前只有 invite/accept/stop 三条在线跑过）：
	## 对面发 `86:5:<邀请者号>` ⇒ 服务端 `DOUBLE_DENY` 把挂着的那封申请 pop 掉，
	## 给**邀请方**回 `86:4:<拒绝者号>`、也给拒绝者自己回 `86:4:<邀请者号>` ⇒ 两侧 `denied_by` 都该是对方。
	_peer.request_double_heal_deny(main_id)
	_步(await _wait_until(func(): return int(_main.authoritative_heal.get("denied_by", 0)) == peer_id and int(_peer.authoritative_heal.get("denied_by", 0)) == main_id, 5000),
			"拒绝双修那一发没回到邀请方（`86:4`，实得 我=%s 对面=%s）" % [
				str(_main.authoritative_heal.get("denied_by", 0)), str(_peer.authoritative_heal.get("denied_by", 0))])
	## 第二步才叫判上"拒绝生效"：申请已经被消费掉 ⇒ 这时候再补一发**同意**，服务端查不到申请 ⇒
	## 两边都不许进入双修态。（只判"denied_by 到了"不证明申请被清；单判"没绑上"又是 0 比 0 空判。）
	_peer.request_double_heal_accept(main_id)
	_步(not await _wait_until(func(): return int(_main.authoritative_heal.get("state", 0)) == 2 or int(_peer.authoritative_heal.get("state", 0)) == 2, 2500),
			"拒绝之后再同意 ⇒ 两边都没绑上（服务端那条 `double_heal_invites` 已经被 pop）")
	## 重新邀请一次再走同意，保证下面那条"双方进入权威双修态"量的还是正路。
	_main.request_double_heal_invite(peer_id)
	_步(await _wait_until(func(): return int(_peer.authoritative_heal.get("pending_inviter_id", 0)) == main_id, 5000), "重新邀请没路由到对面")
	_peer.request_double_heal_accept(main_id)
	_步(await _wait_until(func(): return int(_main.authoritative_heal.get("state", 0)) == 2 and int(_peer.authoritative_heal.get("state", 0)) == 2 and int(_main.authoritative_heal.get("partner_id", 0)) == peer_id and int(_peer.authoritative_heal.get("partner_id", 0)) == main_id, 5000), "接受双修后双方未进入服务端权威状态")
	_main.request_heal_stop()
	_peer.request_heal_stop()
	_步(await _wait_until(func(): return int(_main.authoritative_heal.get("state", -1)) == 0 and int(_peer.authoritative_heal.get("state", -1)) == 0, 4000), "双修停止未同步双方状态")

	if _失败.is_empty():
		print("传承在线回归测试：通过（卡牌、宝箱防重抽、料理、结印、暗器、心法、双客户端双修）")
		_main.disconnect_backend()
		_peer.disconnect_backend()
		quit(0)
		return
	for 项 in _失败:
		push_error("传承在线回归测试：失败 - %s" % 项)
	print("传承在线回归测试：失败 %d 条 —— %s" % [_失败.size(), "; ".join(_失败)])
	_main.disconnect_backend()
	_peer.disconnect_backend()
	quit(1)

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())

func _item_quantity(items: Array, item_id: int) -> int:
	var total := 0
	for item in items:
		if item is Dictionary and int(item.get("id", 0)) == item_id:
			total += int(item.get("quantity", 0))
	return total

func _chest_signature(items: Array) -> String:
	var encoded: Array[String] = []
	for item in items:
		if item is Dictionary:
			encoded.append("%d:%d:%d" % [int(item.get("slot", -1)), int(item.get("item_id", 0)), int(item.get("quantity", 0))])
	return ",".join(encoded)

func _fail(message: String) -> void:
	push_error("传承在线回归测试：失败 - %s" % message)
	if _main != null:
		_main.disconnect_backend()
	if _peer != null:
		_peer.disconnect_backend()
	quit(1)
