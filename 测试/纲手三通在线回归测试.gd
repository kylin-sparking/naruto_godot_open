extends SceneTree

## 「纲手三通在线」门（2026-10-04，用户"服务端也要做到打通没有问题"）——走真实服务端夹具。
##
## 钉的是**原版那条完整链**，一环都不许走本地捷径：
##   ① `54` 对话纲手(template 18) → 328 回帧带 menu 段
##      （断「挑战副本&12 / 挑战精英副本&30」在 `last_npc_dialog.menu` 里——菜单只认服务端，
##       这是"客户端不许自造菜单表"的反向钉）。
##   ② `57:2:12` → 服务端 `_send_copy_history` 回 **817:0** → 会话 copy_history/total 灌上
##      （`copy_changed` 信号到过 = 小地图"等回帧再开窗"的落地条件成立）。
##   ③ `57:2:30` → 服务端推 **1828:0** → `hero_state_changed`；断 maxEnter=3、
##      首格 copyId 20001 在今日账里（新档 0 次）。
##   ④ `1828:1:20001` 进本 → 切图帧把 `authoritative_map_id` 换到 462010000；
##      再 `request_hero_info()` 拉 1828/0 → **20001 的今日次数变 1**
##      （扣次数是服务端账本，客户端只跟帧 ⇒ 这条同时钉"进本真改了状态"）。
## 由 `开发工具/跑在线用例.ps1 -用例 纲手三通` 调（隔离夹具；不能并行）。

const 纲手模板 := 18
const 木叶村 := 100000000
const 纲手格 := 100022		# 木叶村地图数据里纲手的 object_id(template 18 全图唯一)
const 精英首格 := 20001
const 精英首图 := 462010000

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _停(话: String) -> void:
	printerr("纲手三通在线回归测试：中断 - " + 话)
	quit(1)

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
	backend.sync_character()
	if not await _等(func(): return bool(backend.in_game), 15000):
		_停("进不了后端：%s - %s" % [backend.status, backend.detail])
		return

	# —— ⓪ 纲手在木叶村(100000000),首图(集会之地)没有她。
	#      `54:18` 在服务端 `_resolve_talk_npc` 会走到"旧 active 兜底"命中别的 NPC——
	#      必须真人到场 + 用 object_id 精确对话(2026-10-04 探针实锤:本图 npcs 无 tmpl18)。
	if int(backend.authoritative_map_id) != 木叶村:
		if not backend.request_map_change(木叶村, 0, 0):
			_停("跳木叶村的传送门没找到(request_map_change 反查失败)")
			return
		if not await _等(func(): return int(backend.authoritative_map_id) == 木叶村, 10000):
			_停("10 秒没切到木叶村")
			return
	if not await _等(func(): return (backend.map_npcs as Dictionary).has(纲手格), 8000):
		_停("木叶村的 NPC 帧里没有纲手(object_id=%d)" % 纲手格)
		return

	# —— ① 54 开对话,328 回帧带纲手菜单 ——
	var 对话帧: Array = []
	backend.npc_dialog_received.connect(func(_id: int, _m: String): 对话帧.append(_id))
	if not backend.request_npc_talk(纲手格):
		_停("request_npc_talk 在线返回 false")
		return
	if not await _等(func(): return not 对话帧.is_empty(), 8000):
		_停("8 秒没收到 328 对话帧（54 链断）")
		return
	var 菜单: Array = (backend.last_npc_dialog as Dictionary).get("menu", []) as Array
	var 有副本 := false
	var 有精英 := false
	for 项 in 菜单:
		var 对 := 项 as Array
		if 对.size() == 2 and String(对[0]) == "挑战副本" and int(对[1]) == 12:
			有副本 = true
		if 对.size() == 2 and String(对[0]) == "挑战精英副本" and int(对[1]) == 30:
			有精英 = true
	_查(有副本 and 有精英, "纲手 328 帧 menu 缺那两行（实际 %s）—— 菜单必须来自服务端" % str(菜单))

	# —— ② 57:2:12 → 817/0 → copy_changed ——
	var 副本帧到了 := [false]
	会话.copy_changed.connect(func(_s: Dictionary): 副本帧到了[0] = true)
	if not backend.request_npc_menu_action(12):
		_停("request_npc_menu_action(12) 返回 false")
		return
	if not await _等(func(): return 副本帧到了[0], 8000):
		_停("点了「挑战副本」8 秒没等到 817/0（服务端 COPY 菜单分支或 dispatch 支断）")
		return
	_查(int(会话.copy_total_count) >= 1 and (会话.copy_history as Dictionary).size() >= 1,
			"817/0 到了但账没灌上（total=%s hist=%s）" % [str(会话.copy_total_count), str(会话.copy_history)])

	# —— ③ 57:2:30 → 1828:0 → hero_state_changed ——
	if not backend.request_npc_menu_action(30):
		_停("request_npc_menu_action(30) 返回 false")
		return
	if not await _等(func(): return bool(会话.hero_state_loaded), 8000):
		_停("点了「挑战精英副本」8 秒没等到 1828/0")
		return
	_查(int(会话.hero_max_enter) == 3, "精英每日上限该 3（实际 %d）" % int(会话.hero_max_enter))
	_查((会话.hero_entries as Dictionary).has(精英首格),
			"进入列表没有 copyId %d（布局与 Etc.Hero 同源，帧里必有个数）" % 精英首格)
	_查(int((会话.hero_entries as Dictionary).get(精英首格, -1)) == 0,
			"新档首格今日次数该 0（实际 %s）" % str(会话.hero_entries.get(精英首格)))

	# —— ④ 1828:1:20001 进本 → 切图 → 再拉 1828/0 次数变 1 ——
	if not 会话.request_hero_enter(精英首格):
		_停("request_hero_enter 在线返回 false")
		return
	if not await _等(func(): return int(backend.authoritative_map_id) == 精英首图, 8000):
		_停("进本 8 秒没切到副本图 %d（当前 %s）" % [精英首图, str(backend.authoritative_map_id)])
		return
	await _等(func(): return 会话.request_hero_info() == true, 2000)
	if not await _等(func(): return int((会话.hero_entries as Dictionary).get(精英首格, 0)) >= 1, 8000):
		_查(false, "进本后重拉 1828/0，20001 的今日次数没变 1（服务端扣账或回帧断）")
	else:
		_查(true, "进本真扣了今日次数（服务端账本闭环）")

	if not _失败.is_empty():
		for 条 in _失败:
			printerr("纲手三通在线回归测试：" + 条)
		quit(1)
		return
	print("纲手三通在线回归测试：通过（%d 条断言：54菜单/817账/1828账/进本切图扣次）" % _受检)
	backend.disconnect_backend()
	quit(0)
