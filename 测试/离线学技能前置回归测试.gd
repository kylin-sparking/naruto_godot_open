extends SceneTree

## 离线学技能：`info.open` 的每一条前置都必须和在线档一致（§3.384）。
##
## 背景：离线 `游戏会话.learn_skill_from_book` 原来只判「等级 + 技能书」，
## 前置特别忍术 / 八门穴位 / 写轮眼 / 轮回六道 / 家族贡献全跳过 ⇒
## **同一本技能书离线能学、在线学不了**。修复照服务端 `_learn_skill` 的判定顺序
## （`fake_flash_server.py:51952-51962`：已学会 → 等级 → `_skill_requirement_error`
## `:52013-52061` → 扣书），提示文案逐字取服务端返回值。
##
## 钉的判据：
##   ① 拒绝时**不得扣书**（顺序错到扣书之后就是"白吞书"）
##   ② 八门口径 = 当前脉 `list_id*8` + 已贯通门数（`JingMaiSource.getThroughMaiNumber:210-249`）
##   ③ 号段 2020..2024 ↔ 轮回六道第 4..8 道（人间道/修罗道/饿鬼道/地狱道/外道，
##      `数据/原版杂项.json` 的 `LunHuiYan.stage4..8.skills` 就是这么排的）
##   ④ 没入家族时贡献按 0 算；入族后按 `contribution` 比
##   ⑤ 等级判定先于 open 前置（服务端同一顺序），普通忍术不被误拦
##
## 运行：Godot --headless --path . --script res://测试/离线学技能前置回归测试.gd

const TEST_SESSION := preload("res://测试/测试游戏会话.gd")

## `数据/经脉.json` list "0" 前八门的穴位数。**硬写**：期望值不能读被测代码用的同一张表。
const 首脉门尺寸 := [24, 21, 25, 26, 21, 21, 17, 26]

var _failures: Array[String] = []
var 断言 := 0
var _尾通知 := ""
var _成功 := false
var _秒 := 0.0


func _initialize() -> void:
	call_deferred("_run")


## 看门狗：门里任何一处运行期报错都会让 `_run` 半路断掉、`quit()` 永远轮不到。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 60.0:
		printerr("离线学技能前置回归测试：看门狗超时（60s）—— 中途崩了没走到汇总")
		quit(1)
		return true
	return false


func _run() -> void:
	var session := TEST_SESSION.new()
	root.add_child(session)
	await process_frame
	session.notification_requested.connect(func(文案: String) -> void: _尾通知 = 文案)
	# 样品技能书各一本；等级抬到全部样品门槛之上（最高 3203=70）。
	session.player_stats["level"] = 70
	var 书表: Array[String] = [
		"06000016", "06000046", "06000054", "06000055",
		"06000057", "06000059", "06000063", "06000130", "06000131",
	]
	for i in 书表.size():
		session.inventory.append({"id": 书表[i], "quantity": 1, "slot_index": i + 1})

	# —— ① 八门穴位下限（3201 reqMai=5）——
	_置八门(session, 0, 4)
	_学(session, "3201")
	_check(not _成功, "贯通 4 门时 3201（需 5 门）应被拒绝")
	_check(_尾通知 == "需要开通 5 个八门穴位。", "3201 拒绝文案应逐字对齐服务端，实际：%s" % _尾通知)
	_check(_书还在(session, "06000054"), "被拒绝时不得消耗 3201 的技能书")
	_check(not _已学(session, "0003201"), "被拒绝时不得加入已学列表")
	_置八门(session, 0, 5)
	_学(session, "3201")
	_check(_成功, "贯通 5 门后 3201 应能学习")
	_check(_已学(session, "0003201"), "学成的忍术应进入已学列表")
	_check(not _书还在(session, "06000054"), "学会后应消耗技能书")

	# —— ② 八门口径里的 listId*8（3202 reqMai=8）——
	_置八门(session, 0, 7)
	_学(session, "3202")
	_check(not _成功, "首脉贯通 7 门时 3202（需 8 门）应被拒绝")
	_check(_尾通知 == "需要开通 8 个八门穴位。", "3202 拒绝文案不符，实际：%s" % _尾通知)
	_check(_书还在(session, "06000055"), "被拒绝时不得消耗 3202 的技能书")
	_置八门(session, 1, 0)
	_学(session, "3202")
	_check(_成功, "listId=1 时一门未开也应算贯通 8 门（服务端 listId*8）")

	# —— ③ 写轮眼阶数（3204 reqXielunyan=4）——
	session.cultivation_states["写轮眼"] = {"stage": 3}
	_学(session, "3204")
	_check(not _成功, "写轮眼 3 阶时 3204（需 4 阶）应被拒绝")
	_check(_尾通知 == "需要写轮眼达到 4 阶。", "3204 拒绝文案不符，实际：%s" % _尾通知)
	_check(_书还在(session, "06000057"), "被拒绝时不得消耗 3204 的技能书")
	session.cultivation_states["写轮眼"] = {"stage": 4}
	_学(session, "3204")
	_check(_成功, "写轮眼 4 阶且有书时 3204 应能学习")

	# —— ④ 轮回六道号段映射（2020=人间道，2024=外道）——
	session.cultivation_states["轮回六道"] = {"stage": 3}
	_学(session, "2020")
	_check(not _成功, "轮回 3 阶时 2020（人间道，需 4 阶）应被拒绝")
	_check(_尾通知 == "需要先解锁轮回六道的人间道。", "2020 拒绝文案不符，实际：%s" % _尾通知)
	_check(_书还在(session, "06000059"), "被拒绝时不得消耗 2020 的技能书")
	session.cultivation_states["轮回六道"] = {"stage": 7}
	_学(session, "2024")
	_check(not _成功, "轮回 7 阶时 2024（外道，需 8 阶）应被拒绝")
	_check(_尾通知 == "需要先解锁轮回六道的外道。", "2024 拒绝文案不符，实际：%s" % _尾通知)
	_check(_书还在(session, "06000063"), "被拒绝时不得消耗 2024 的技能书")
	session.cultivation_states["轮回六道"] = {"stage": 8}
	_学(session, "2020")
	_check(_成功, "轮回 8 阶时 2020 应能学习")
	_学(session, "2024")
	_check(_成功, "轮回 8 阶时 2024 应能学习")

	# —— ⑤ 家族贡献（3110 reqBangGong=100）——
	session.guild = {"joined": false, "contribution": 500}
	_学(session, "3110")
	_check(not _成功, "未入家族时即使 contribution 有值也应拒绝 3110（按 0 算）")
	_check(_尾通知 == "需要家族贡献 100。", "3110 拒绝文案不符，实际：%s" % _尾通知)
	_check(_书还在(session, "06000046"), "被拒绝时不得消耗 3110 的技能书")
	session.guild = {"joined": true, "contribution": 99}
	_学(session, "3110")
	_check(not _成功, "入族贡献 99 时 3110（需 100）应被拒绝")
	session.guild = {"joined": true, "contribution": 100}
	_学(session, "3110")
	_check(_成功, "入族贡献 100 时 3110 应能学习")

	# —— ⑥ 前置特别忍术（9031←9030；服务端 `_project_skill_prerequisite:43906`）——
	_学(session, "9031")
	_check(not _成功, "未学前置 9030 时 9031（多重影分身）应被拒绝")
	_check(_尾通知 == "请先学习前置特别忍术。", "9031 拒绝文案不符，实际：%s" % _尾通知)
	_check(_书还在(session, "06000131"), "被拒绝时不得消耗 9031 的技能书")
	_学(session, "9030")
	_check(_成功, "9030（影分身）无前置，应能学习")
	_学(session, "9031")
	_check(_成功, "学会 9030 后 9031 应能学习")

	# —— ⑦ 已学会判定先于前置（服务端 `_learn_skill:51953-51955`）——
	_置八门(session, 0, 0)
	_学(session, "9031")
	_check(not _成功, "重复学习 9031 应被拒绝")
	_check(_尾通知 == "该忍术已经学会", "已学会文案不符，实际：%s" % _尾通知)

	# —— ⑧ 等级判定先于 open 前置（服务端 `_learn_skill:51956-51959`）——
	session.player_stats["level"] = 69
	_学(session, "3203")
	_check(not _成功, "69 级学 3203（需 70 级）应被拒绝")
	_check(_尾通知 == "需要达到 70 级才能学习。", "等级文案不符，实际：%s" % _尾通知)
	session.player_stats["level"] = 70

	# —— ⑨ 普通忍术不被误拦（1002001 怪力：无 open 前置）——
	session.guild = {}
	session.cultivation_states.clear()
	_学(session, "1002001")
	_check(_成功, "无前置的普通忍术应能正常学习")

	if _failures.is_empty():
		print("离线学技能前置回归测试：通过（%d 条断言）" % 断言)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## 备好八门状态：`list_id` 当前脉，`已开门数` 只对首脉（尺寸表按 list 0 硬写）。
func _置八门(session, list_id: int, 已开门数: int) -> void:
	var exploded := {}
	for i in mini(已开门数, 首脉门尺寸.size()):
		exploded[i] = 首脉门尺寸[i]
	session.cultivation_states["八门"] = {"list_id": list_id, "exploded": exploded}


func _学(session, 编号: String) -> void:
	_尾通知 = ""
	_成功 = bool(session.learn_skill_from_book(编号))


func _已学(session, 编号: String) -> bool:
	for 技能 in session.learned_skills:
		if String(技能.get("id", "")) == 编号:
			return true
	return false


func _书还在(session, 书id: String) -> bool:
	for 物品 in session.inventory:
		if String(物品.get("id", "")).pad_zeros(8) == 书id and int(物品.get("quantity", 0)) > 0:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	断言 += 1
	if not condition:
		_failures.append(message)
