## 行为量具：**走到跟前自动开对话**到底成不成立（时机契约 + 木叶村失落秋千真走）。
## 为什么要它：`任务标记刷新与距离闸` 那道门只比源码字符串，证明不了运行期会弹框 ——
## 上一轮我把"取距离闸"写成去 current_scene 找 `地图实体._能对话`，那个节点没这方法，
## 于是 `has_method` 恒假 ⇒ 走到跟前也不弹（用户当天第二条实机反馈），门却一路绿。
## 2026-10-26 又逮到一条：兑现条件错用「停 + 纵差<50」，而失落秋千挂在脚点上方 51px，
## 永远差 1 像素 ⇒ 点追踪栏走过去后静默不弹（用户实机"卡在失落秋千"）。
## 现在按原版 `KeyController.as:212`：只看**路线走完**（`玩家.auto_path_arrive_stamp`），距离不参与。
## 登记在离线门清单里（`跑全部离线门.py` 只跑 `res://测试/` 下的门，所以放这儿）。
## 跑法：--headless 就够（不看像素，只看状态变化）。
extends SceneTree

var 行: Array[String] = []
var 出 := "res://测试/截图/追踪栏/到点自动开对话.txt"
var _原地图 := ""
var _会话: Node


func _initialize() -> void:
	call_deferred("_跑")


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _跑() -> void:
	## 用**真出问题的那张图**跑：木叶村的失落秋千（NPC 33）挂在 y=431、脚下平台 482，
	## 纵差 51 ≥ `canPlayerTalkToMe` 的 50 —— 2026-10-26 用户实机就是卡在这里。
	_会话 = root.get_node_or_null("GameSession")
	if _会话 != null:
		_原地图 = str(_会话.get("current_map_id"))
		_会话.set("current_map_id", "100000000")
	var 场: Node = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(90)
	var 板: Node = 场.find_child("小地图面板", true, false)
	var 玩: Node2D = get_first_node_in_group("player") as Node2D
	if 板 == null or 玩 == null:
		_记("缺 小地图面板 或 玩家"); _收(); return
	var 根: Node = 场.get_node_or_null("LifeRoot")
	var 人: Node2D = null
	if 根 != null:
		for 客 in 根.get("_entities") as Array:
			if not is_instance_valid(客):
				continue
			var 谁 := 客 as Node2D
			if 谁 != null and str(谁.get("kind")) == "n" and int(str(谁.get("entity_id"))) == 33:
				人 = 谁
				break
	if 人 == null:
		_记("木叶村里没有 NPC 33（失落秋千）—— 数据或生成链断了"); _收(); return
	var 号 := str(int(人.get("entity_id")))
	var 原位: Vector2 = 玩.global_position
	var 人位: Vector2 = 人.global_position
	var 足: Node = 场.get_node_or_null("Footholds")
	var 落: Dictionary = 足.call("find_click_target", 人位) if 足 != null else {}
	var 脚y := float(落.get("y", INF))
	_记("秋千=%s 秋千位=%s 点它的落脚点=%s（纵差 %.0f）" % [
			号, str(人位), str(落), absf(脚y - 人位.y)])
	## 判据 = **路线真的走完**（原版 `KeyController.as:212` 的路径关节走完那一支），
	## 不是"停下来时离得够近"。先按印模拟四档时机契约：
	##   · 远处/近处 × 走完/被打断 —— 走完才弹，打断一律安静取消；
	##   · 走的时候（路线没停）更不许弹。
	var 远 := 人位 + Vector2(600.0, 0.0)
	var 近 := 人位 + Vector2(20.0, 0.0)
	var 过 := 0
	var 次表 := [
		["远处·走完", 远, false, true],
		["远处·被打断", 远, false, false],
		["近处·走完", 近, false, true],
		["近处·打断", 近, false, false],
		["走的时候不弹", 远, true, false],
	]
	for 次 in 次表:
		var 名: String = 次[0]
		var 位: Vector2 = 次[1]
		var 在走: bool = bool(次[2])
		var 走完: bool = bool(次[3])
		var 该弹 := 走完
		## 「弹了」只能看**对话窗真的开出来了没有**：
		## 「兑现对话」和「被打断后安静取消」都会把 _待对话NPC 清成空，拿它当判据必然把
		## 后者误记成前者（第一版就这么假红过一次：远处+已停 明明没弹，却记成"弹了"）。
		var 前次 := int(板.get("到点对话次数"))
		玩.global_position = 位
		var 起点印 := int(玩.get("auto_path_arrive_stamp"))
		玩.set("click_move_active", 在走)
		板.set("_待对话起点印", 起点印)
		板.set("_待对话NPC", 号)
		if 走完:
			玩.set("auto_path_arrive_stamp", 起点印 + 1)
		await _帧(10)
		var 弹了 := int(板.get("到点对话次数")) > 前次	## 只数"真兑现了几次"，与"安静取消"分得开
		var 欠着 := String(板.get("_待对话NPC")) == 号
		_记("%s ⇒ 兑现=%s 欠着=%s（期望 %s）%s" % [
				名, str(弹了), str(欠着), str(该弹), "" if 弹了 == 该弹 else "  ← 红"])
		if 弹了 != 该弹:
			过 += 1
	## ⑤ 真走：人站在秋千正下方（脚 y=482）点前往 —— 原版零长路线也算"关节走完"，必须弹。
	var 前次5 := int(板.get("到点对话次数"))
	玩.global_position = Vector2(人位.x, 脚y)
	await _帧(5)
	板.call("前往NPC", 33, false)
	var 弹5 := false
	for i in 240:
		await process_frame
		if int(板.get("到点对话次数")) > 前次5:
			弹5 = true
			break
	_记("正下方（脚 y=%.0f，秋千 y=%.0f）点前往 ⇒ 兑现=%s（期望 true）%s" % [
			脚y, 人位.y, str(弹5), "" if 弹5 else "  ← 红"])
	if not 弹5:
		过 += 1
	## ⑥ 真走：同一条平台上、离 354px 处点前往 —— 走完整条路线后才弹。
	var 前次6 := int(板.get("到点对话次数"))
	玩.global_position = Vector2(人位.x - 354.0, 脚y)
	await _帧(5)
	板.call("前往NPC", 33, false)
	var 弹6 := false
	for i in 600:
		await process_frame
		if int(板.get("到点对话次数")) > 前次6:
			弹6 = true
			break
	_记("远处走 354px 点前往 ⇒ 兑现=%s 人物=%s（期望 true）%s" % [
			str(弹6), str(玩.global_position), "" if 弹6 else "  ← 红"])
	if not 弹6:
		过 += 1
	人.global_position = 人位
	玩.global_position = 原位
	_记("判据：走完才弹（距离不参与）；打断一律安静取消；秋千（纵差 51）正下方与远处都必须弹")
	_记("注：本门测的是「什么时候兑现」这条时机契约；对话框**画出来长什么样**不在这里判（无头取不到那个节点）")
	_记("结果 %s" % ("通过" if 过 == 0 else "红（%d 项不符）" % 过))
	_收()


func _有对话窗(场: Node) -> bool:
	## 从 root 整棵树里找，别只盯 地图场景 那一支 —— 对话窗是挂在窗口层（CanvasLayer）下的，
	## 按固定节点名找第一版就漏了（近处+已停 明明兑现了，探针却说"没弹"）。
	var 栈: Array = [root]
	while not 栈.is_empty():
		var n: Node = 栈.pop_back()
		for 子 in n.get_children():
			if String(子.name).contains("对话"):
				var c := 子 as CanvasItem
				if c == null or c.is_visible_in_tree():
					return true
			栈.append(子)
	return false


func _收() -> void:
	if _会话 != null and not _原地图.is_empty():
		_会话.set("current_map_id", _原地图)
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	## 退出码只认自己打的那行总结（以前拿 行[3]/[4]/[5] 猜下标，结论是"通过"却退出码 1 —— 跑批会把一条绿门当成红）。
	var 结 := ""
	for s in 行:
		if s.begins_with("结果 "):
			结 = s
	quit(0 if 结 == "结果 通过" else 1)
