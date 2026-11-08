extends SceneTree

## 神奇技能符 15018001：宠物技能替换的整条使用链（§3.384）。
##
## 背景：物品双击原来直接走 `use_inventory_slot`，服务端按 jineng 收下 USE_ITEM 后
## 报文缺 `{petUid, oldskill, newskill}` ⇒ 只回「请选择要操作的宠物。」；离线则
## 被当成普通物品拒掉 —— **整条链根本不存在**。修复照原版：
##   `ItemWindow2.as:1056-1060`（`spec.type == "jineng"` ⇒ 弹替换窗）
##   → `PetSkillResetWindow.as:69-94`（三条提示与顺序）与 `:89-93`（报文形状）
##   → `PetSkillSelectWindow.as:64-72`（候选 = 宠物技能全表减尾兽 123..126，选完不关窗）
##
## 钉的判据：
##   ① `use_type == "jineng"` 才走替换窗（普通书不是）
##   ② 离线使用被拒绝、神奇技能符**不被消耗**
##   ③ 替换窗 444×423，自动选第一只宠，八个旧技能格按宠物技能填、新技能格空
##   ④ 三条提示的顺序与文案：没选宠 → 没选旧 → 没选新
##   ⑤ 查阅开选择窗：29 条候选（33 − 4 尾兽），选完回填「新技能」，确定后发
##      `确认替换(宠uid, 旧, 新)`（宿主再走 `use_pet_skill_symbol`）
##
## 运行：Godot --headless --path . --script res://测试/宠物技能替换回归测试.gd

const TEST_SESSION := preload("res://测试/测试游戏会话.gd")
const 替换窗脚本 := preload("res://脚本/界面/窗口/宠物技能替换窗.gd")
const 选择窗脚本 := preload("res://脚本/界面/窗口/宠物技能选择窗.gd")


## 替换窗只要宿主的 `_session`（取宠物）和 `_通知`（三条提示落点）。
class 宿主桩 extends Node:
	var _session: Node = null
	var 通知: Array[String] = []
	var 替换记录: Array = []

	func _通知(文本: String) -> void:
		通知.append(文本)


var _failures: Array[String] = []
var 断言 := 0
var _尾通知 := ""
var _秒 := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 60.0:
		printerr("宠物技能替换回归测试：看门狗超时（60s）—— 中途崩了没走到汇总")
		quit(1)
		return true
	return false


func _run() -> void:
	var session := TEST_SESSION.new()
	root.add_child(session)
	await process_frame
	# `游戏会话._init` 会灌 `OFFLINE_DATA` 的默认背包/宠物 ⇒ 先按格位覆盖，别 append。
	while session.inventory.size() < 2:
		session.inventory.append({})
	session.inventory[0] = {"id": "15018001", "quantity": 1, "slot_index": 1}
	session.inventory[1] = {"id": "06000016", "quantity": 1, "slot_index": 2}
	var 宠物表: Array[Dictionary] = [{
		"unique_id": 77, "name": "赤丸", "item_id": 0, "aptitude": 1, "level": 12,
		"skills": [{"id": 101, "level": 2}, {"id": 102, "level": 1}],
		"equipment": [],
	}]
	session.pets.assign(宠物表)

	# —— ① 只认 use_type == "jineng" ——
	_check(session.是技能符(1), "神奇技能符（use_type=jineng）应被识别为技能符")
	_check(not session.是技能符(2), "普通技能书不应被识别为技能符")
	_check(not session.是技能符(99), "空格位不应被识别为技能符")

	# —— ② 离线使用：拒绝且不扣件 ——
	session.notification_requested.connect(func(文案: String) -> void: _尾通知 = 文案)
	_check(not session.use_pet_skill_symbol(1, 77, 101, 102), "离线使用神奇技能符应被拒绝")
	_check(_尾通知.find("未连接服务器") >= 0 and _尾通知.find("神奇技能符") >= 0,
		"离线拒绝文案应点名「神奇技能符」，实际：%s" % _尾通知)
	_check(int(session.inventory[0].get("quantity", 0)) == 1, "离线被拒绝时不得消耗神奇技能符")

	# —— ③ 有宠：窗口版式与自动选中 ——
	var 宿主 := 宿主桩.new()
	宿主._session = session
	root.add_child(宿主)
	var 窗 := 替换窗脚本.new() as Control
	宿主.add_child(窗)
	窗.确认替换.connect(func(宠物uid: int, 旧技能: int, 新技能: int) -> void:
		宿主.替换记录 = [宠物uid, 旧技能, 新技能])
	窗.call("打开", 宿主)
	_check(窗.visible, "替换窗打开后应可见")
	_check(窗.size == Vector2(444.0, 423.0), "替换窗尺寸应为 444×423，实际 %s" % 窗.size)
	_check(窗.get_node_or_null("确定重置") != null, "替换窗应有「确定重置」")
	_check(窗.get_node_or_null("查阅") != null, "替换窗应有「查阅」")
	var 格0 := 窗.get_node_or_null("技能格_0") as Button
	var 格1 := 窗.get_node_or_null("技能格_1") as Button
	var 格2 := 窗.get_node_or_null("技能格_2") as Button
	var 新格 := 窗.get_node_or_null("新技能格") as Button
	_check(格0 != null and 格1 != null and 格2 != null and 新格 != null, "应有八个旧技能格与新技能格")
	if 格0 == null or 格1 == null or 格2 == null or 新格 == null:
		_收尾(); return
	_check(int(格0.get_meta("skill_id", 0)) == 101 and not 格0.disabled, "第一个技能格应填宠物技能 101 且可点")
	_check(int(格1.get_meta("skill_id", 0)) == 102, "第二个技能格应填宠物技能 102")
	_check(格2.disabled and int(格2.get_meta("skill_id", 0)) == 0, "没有第三技能的格应禁用且为空")
	var 新格图标 := 新格.get_node("图标") as TextureRect
	_check(新格图标.texture == null, "打开时新技能格应为空")

	# —— ④ 提示顺序：没选旧 → 没选新（宠物已自动选中）——
	var 确定 := 窗.get_node("确定重置") as Button
	确定.pressed.emit()
	_check(_尾(宿主) == "请选择您要重置的技能", "未选旧技能应先提示选旧技能，实际：%s" % _尾(宿主))
	格0.pressed.emit()
	确定.pressed.emit()
	_check(_尾(宿主) == "请选择您要重置该技能的技能", "未选新技能应提示选新技能，实际：%s" % _尾(宿主))

	# —— ⑤ 查阅 → 候选 29 条（33 − 尾兽 4）→ 选 102 → 确定发信号 ——
	(窗.get_node("查阅") as Button).pressed.emit()
	var 选择窗 := 窗.get_node_or_null("宠物技能选择窗") as Control
	_check(选择窗 != null, "点「查阅」应开宠物技能选择窗")
	if 选择窗 == null:
		_收尾(); return
	_check(选择窗.size == Vector2(444.0, 423.0), "选择窗尺寸应为 444×423，实际 %s" % 选择窗.size)
	var 行容器 := 选择窗.get_node_or_null("列表/行容器") as Node
	_check(行容器 != null, "选择窗应有列表容器")
	if 行容器 == null:
		_收尾(); return
	_check(行容器.get_child_count() == 29, "候选应为 33−4=29 条，实际 %d" % 行容器.get_child_count())
	for 尾兽 in [123, 124, 125, 126]:
		_check(行容器.get_node_or_null("行_%d" % 尾兽) == null, "尾兽技能 %d 不应出现在候选里" % 尾兽)
	var 行102 := 行容器.get_node_or_null("行_102")
	_check(行102 != null, "候选里应有技能 102")
	if 行102 == null:
		_收尾(); return
	(行102.get_node("选择") as Button).pressed.emit()
	_check(选择窗.visible, "选完技能后选择窗不应自动关闭（原版 selectedSkillHandler 不关窗）")
	_check(not String(新格.tooltip_text).is_empty(), "选完技能后新技能格应有说明 tooltip")
	确定.pressed.emit()
	_check(宿主.替换记录 == [77, 101, 102],
		"确定重置应发 确认替换(宠uid, 旧, 新)，实际 %s" % [宿主.替换记录])
	(窗.get_node("关闭") as Button).pressed.emit()
	_check(not 窗.visible, "点关闭后替换窗应隐藏")

	# —— ⑥ 没宠：第一条提示 ——
	var 空宿主 := 宿主桩.new()
	空宿主._session = session
	root.add_child(空宿主)
	var 空会话 := TEST_SESSION.new()
	空会话.pets.clear()		# `_init` 会灌默认宠物，这条专门验「没选宠」
	root.add_child(空会话)
	await process_frame
	空宿主._session = 空会话
	var 空窗 := 替换窗脚本.new() as Control
	空宿主.add_child(空窗)
	空窗.call("打开", 空宿主)
	(空窗.get_node("确定重置") as Button).pressed.emit()
	_check(_尾(空宿主) == "请选择您需要重置技能的宠物",
		"没有宠物时应先提示选宠物，实际：%s" % _尾(空宿主))

	# —— ⑦ 选择窗静态清单与说明文案 ——
	var 候选: Array[int] = 选择窗脚本.候选技能()
	_check(候选.size() == 29, "候选技能() 应为 29 条，实际 %d" % 候选.size())
	_check(候选.has(101) and 候选.has(208), "候选应含 101 与 208")
	_check(not 候选.has(123) and not 候选.has(126), "候选不应含尾兽技能")
	var 说明出战 := String(选择窗脚本.说明(101))
	var 说明附身 := String(选择窗脚本.说明(201))
	_check(说明出战.find("【推荐出战宠物学习】") >= 0, "101 应推荐出战：%s" % 说明出战)
	_check(说明附身.find("【推荐附身宠物学习】") >= 0, "201 应推荐附身：%s" % 说明附身)
	_check(说明出战.find("[color=#1e90ff]") >= 0 and 说明出战.find("#ffffff") >= 0
			and 说明出战.find("#00ff00") >= 0, "说明应按 AS3 上色：%s" % 说明出战)

	_收尾()


func _尾(宿主: 宿主桩) -> String:
	return 宿主.通知[-1] if not 宿主.通知.is_empty() else ""


func _收尾() -> void:
	if _failures.is_empty():
		print("宠物技能替换回归测试：通过（%d 条断言）" % 断言)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	断言 += 1
	if not condition:
		_failures.append(message)
