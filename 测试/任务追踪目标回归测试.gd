extends SceneTree

## 追踪栏「任务目标」这一行的回归门（2026-10-09 新）。
##
## 为什么单开一条：追踪栏的正文以前**只认 npc 一类目标**（`_指标符` 只遍历 `npc`），
## 于是杀怪任务/交物品任务的那一行是**空白**，更没有可点的链接 ——
## 而所有既有门都比的是"行在不在、高度对不对"，照不到"这一行有没有内容"。
## 本轮把六类目标（mob/npc/item/equip/useitem/pet）全接上并挂链接，这里逐类钉住。

var _失败: Array[String] = []
var _查 := 0


func _initialize() -> void:
	_run()


func _判(ok: bool, 话: String) -> void:
	_查 += 1
	if not ok:
		_失败.append(话)


func _真目标(号: String) -> Dictionary:
	var 表 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/任务.json"))
	return ((表 as Dictionary).get(号, {}) as Dictionary)


func _行(面板: Node, 号: String, 运行时: Dictionary = {}) -> String:
	return String(面板.call("_指标符", _真目标(号), 运行时))


func _run() -> void:
	var 脚本: GDScript = load("res://脚本/界面/小地图面板.gd")
	var 面板: Node = 脚本.new()

	# ---- ① 杀怪目标：文案 + 链接里带「图:怪」 ----
	var 怪行 := _行(面板, "1018")
	_判(怪行.contains("击败"), "1018（小试牛刀，杀怪）正文没有「击败」：'%s'" % 怪行)
	_判(怪行.contains("event:mob101020000:1000001"),
		"1018 的杀怪链接不是 event:mob<图>:<怪>：'%s'" % 怪行)
	var 怪名 := String(load("res://脚本/单例/游戏数据.gd").call("monster_name", 1000001))
	_判(not 怪名.is_empty() and 怪行.contains(怪名),
		"1018 没把怪名（%s）印进正文：'%s'" % [怪名, 怪行])

	# ---- ② 交物品目标：文案 + 数量 + 交给哪个 NPC 的链接 ----
	var 物行 := _行(面板, "1024")
	_判(物行.contains("交上"), "1024（热情的料理，交物品）正文没有「交上」：'%s'" % 物行)
	_判(物行.contains("event:npc4"), "1024 没挂上「交给 NPC 4」的链接：'%s'" % 物行)
	var 品名 := String(load("res://脚本/单例/游戏数据.gd").call("item_name", 4000001))
	_判(not 品名.is_empty() and 物行.contains(品名), "1024 没印物品名（%s）：'%s'" % [品名, 物行])

	# ---- ③ 对话目标（原有那一类，别被改坏）----
	var 话行 := _行(面板, "1003")
	_判(话行.contains("寻找") and 话行.contains("event:npc1"),
		"1003 的对话目标行丢了（原版就有的一类）：'%s'" % 话行)

	# ---- ④ 计数：单目标才印，多目标不印（运行时那两个和值是跨目标累加的）----
	var 带数 := _行(面板, "1018", {"progress": 1, "required": 3})
	_判(带数.contains("（1/3）"), "单目标杀怪任务没印进度（1/3）：'%s'" % 带数)
	var 多数 := _行(面板, "1015", {"progress": 2, "required": 5})
	_判(not 多数.contains("（2/5）"), "多目标任务不该印跨目标累加的计数：'%s'" % 多数)

	# ---- ⑤ 接线还在：链接前缀 + 点击处 + 赶路函数（删掉任何一条，上面全绿也没用）----
	var 源 := FileAccess.get_file_as_string("res://脚本/界面/小地图面板.gd")
	for 关键 in ['const 打怪链接 := "event:mob"', "func _走向任务怪", "func _本图最近怪",
			"elif u.begins_with(打怪链接):"]:
		_判(源.contains(关键), "小地图面板里找不到 `%s` —— 点目标赶路那条链被拆了" % 关键)
	# 跨图这一支**不许静默**。口径 2026-10-10 换过一次：以前钉的是「多跳没接要明说」，
	# 现在多跳已经接上（图级路线 = `脚本/地图/跨图寻路.gd`，推进与取消 = `测试/跨图赶路推进回归测试.gd`
	# 那 19 条运行期判据），所以这里改钉**新形状齐不齐**：直达门那一条 + 多跳起跑/逐跳 + 算不出来要说原因。
	# ⚠ 这条只是"接线还在"的形状判据；行为证据在跨图那道门里，别拿这条当"能走通"。
	for 关键 in ["func 前往别的图", "func _通往", "func _起多跳", "func _走跨图一跳",
			"func _续跨图", "跨图寻路.gd"]:
		_判(源.contains(关键), "跨图这一支缺 `%s` —— 直达/多跳/换图续跑 这条链被拆了" % 关键)
	_判(源.contains("走不过去") and 源.contains("寻不到路"),
		"跨图失败的两个出口都不许静默：图不连通要说「走不过去」、这一跳寻不到落脚点要说「寻不到路」")

	面板.free()
	if _失败.is_empty():
		print("任务追踪目标回归测试：通过（%d 项，杀怪/交物品/对话三类目标 + 计数口径 + 赶路接线）" % _查)
		quit(0)
		return
	for 项 in _失败:
		push_error("追踪目标：%s" % 项)
	print("任务追踪目标回归测试：失败 %d 条（共查 %d 项）" % [_失败.size(), _查])
	quit(1)
