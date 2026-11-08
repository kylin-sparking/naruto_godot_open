extends SceneTree

## 「秘笈合成在线」门（2026-10-03 接 `CAN_JUAN_ACTION 1352`）——走真实服务端夹具。
##
## 钉四段：
##   ① **真事务到成功为止**：每发 `会话.合成秘笈(格, 0)` → 捕 `can_juan_result`，
##      夹具一发吃 3 条残卷 + 100 精华、成功回 `1352:0:1` 并 `_add_inventory_item(6000026)`。
##      **每发都按结果核对消耗**（成功 −3、失败 −2 = 夹具 `max(0, need-1)` 口径），
##      直到见到一发成功（种子 60 条 = 20 发，单发 25% ⇒ 一直不中的概率 0.75^20≈0.3%）。
##   ② **产物进包**：成功那发后 `6000026` 出现在 `session.inventory`。
##   ③ **精华随扣**：每发后 `player_stats.zq` 比上一发少 100（`_send_stats({ZQ=22})`）。
##   ④ **服务端校验兜底**：直接发一个不存在的 unique_id → 必回 `0`、分毫不动
##      （残卷数与 zq 都不变）——页面四步预校验挡不住的路，由服务端挡。
## ⚠ 几率值**这条门钉不了**（回帧只有成功/失败，观测不到概率）——
##   2026-10-11 §3.101 已把服务端那处**写死的 base=30 改成读表**（`Etc.CanJuanHeCheng.prob` = 25），
##   从此客户端显示的就是服务端掷的那套。**回归防线放在离线门 `源码健全性回归测试`**
##   （钉住服务端那句 `base_probability = _authored_probability` 不被改回写死）。
## 由 `开发工具/跑在线用例.ps1 -用例 秘笈合成` 调（隔离夹具；不能并行）。

const 残卷 := "08000011"
const 产物 := 6000026
const 需条 := 3
const 扣精华 := 100

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _停(话: String) -> void:
	printerr("秘笈合成在线回归测试：中断 - " + 话)
	quit(1)

func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())

## 按**数值**比 id（§3.61 的"整数形态 vs 八位补零"病根，两种都认）。
func _找行(会话, id号: int) -> Dictionary:
	for 件 in 会话.inventory:
		if typeof(件) == TYPE_DICTIONARY and int(String((件 as Dictionary).get("id", "0"))) == id号:
			return 件 as Dictionary
	return {}

func _条数(会话, id号: int) -> int:
	return int(_找行(会话, id号).get("quantity", 0))

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var 会话 = root.get_node_or_null("GameSession")
	if backend == null or 会话 == null:
		_停("缺单例")
		return
	backend.sync_character()
	if not await _等(func(): return bool(backend.in_game) and _条数(会话, 8000011) >= 需条 * 2, 15000):
		_停("进不了后端或没种残卷（inventory=%s）" % str(会话.inventory.size()))
		return

	# 结果帧捕获（会话转发信号；页没开也能捕——门测协议端到端，UI 由离线门钉）
	var 最新: Array = []
	会话.can_juan_result.connect(func(s: bool): 最新.append(s))

	var 行 := _找行(会话, 8000011)
	var 格: int = int(行.get("slot_index", 0))
	if 格 <= 0:
		_停("残卷行没有 slot_index（§3.82 不变量被绕开？）：%s" % str(行))
		return
	var 见过成功 := false
	var 发数 := 0
	while 发数 < 20 and not 见过成功:
		发数 += 1
		var 前条 := _条数(会话, 8000011)
		var 前精华 := int(会话.player_stats.get("zq", 0))
		最新.clear()
		if not 会话.合成秘笈(格, 0):
			_停("第 %d 发：在线 request 返回 false（unique_id 缺失或没连上后端）" % 发数)
			return
		if not await _等(func(): return not 最新.is_empty(), 6000):
			_停("第 %d 发：6 秒没等到 1352 结果帧（dispatch `OP_CAN_JUAN_ACTION` 支没跑？）" % 发数)
			return
		if not is_instance_valid(会话):
			return
		var 成功: bool = bool(最新[0])
		# 等消耗帧进包（32/34 帧在结果帧前后到，按数量稳定判定）
		var 期望条 := 前条 - (需条 if 成功 else 需条 - 1)
		if not await _等(func(): return _条数(会话, 8000011) == 期望条, 6000):
			_查(false, "第 %d 发（成功=%s）后残卷该 %d→%d，实际 %d —— 夹具消耗口径：成功吃 %d、失败留 1" % [
					发数, str(成功), 前条, 期望条, _条数(会话, 8000011), 需条])
			return
		if int(会话.player_stats.get("zq", 0)) != 前精华 - 扣精华:
			_查(false, "第 %d 发精华该 -100（%d→%d 实际 %d）" % [发数, 前精华,
					前精华 - 扣精华, int(会话.player_stats.get("zq", 0))])
			return
		if 成功:
			见过成功 = true
			_查(_条数(会话, 产物) > 0, "成功那发后产物秘笈 %d 没进包" % 产物)
	_查(见过成功, "%d 发都没掷出成功（0.7^%d 小概率事件或回帧坏了）" % [发数, 发数])

	# —— ④ 服务端校验兜底：不存在的 unique_id 必拒且分毫不动 ——
	var 条前 := _条数(会话, 8000011)
	var 精华前 := int(会话.player_stats.get("zq", 0))
	最新.clear()
	backend.request_can_juan_compose(987654321, 0)
	if not await _等(func(): return not 最新.is_empty(), 6000):
		_停("假 unique_id 请求 6 秒没等到回帧（夹具拒绝也该回 `1352:0:0`）")
		return
	_查(bool(最新[0]) == false, "不存在的 unique_id 竟然回了成功？")
	_查(_条数(会话, 8000011) == 条前 and int(会话.player_stats.get("zq", 0)) == 精华前,
			"被拒的请求仍动了包/精华（夹具校验没兜住）")

	if not _失败.is_empty():
		for 条 in _失败:
			printerr("秘笈合成在线回归测试：" + 条)
		quit(1)
		return
	print("秘笈合成在线回归测试：通过（%d 条断言；%d 发见成功，消耗/精华/产物/假id拒绝全对上）" % [_受检, 发数])
	backend.disconnect_backend()
	quit(0)
