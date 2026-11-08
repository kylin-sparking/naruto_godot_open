extends SceneTree

## 离线门：HUD「任务追踪」的长列表能不能滚（2026-10-26 用户实机报「任务列表没办法滑动，
## 看不到任务完成交付的 NPC」）。
##
## 原版 `QuestTrackerWindow.as:166-177` 把 `_list` 塞进 **fl.containers.ScrollPane**
## （横向 off、宽 = 面板宽−5），`:385-391` 再把面板高压到 `MAX_HEIGHT=180` ⇒ 列表超过
## 158 高时由 ScrollPane 滚动。本工程原来把 `任务内容区` 建成普通 Control + clip_contents，
## 只裁不滚 —— 长列表后面的任务（以及它的交付 NPC）永远看不到。
##
## 判据（全部运行期，不看源码字符串）：
##   ① 任务内容区必须是 ScrollContainer，且内容确实超高；
##   ② 滚轮能改变 scroll_vertical；
##   ③ 整段重建（收到任务帧）后滚动位置不归零 —— 否则玩家刚滚到交付 NPC 就被顶回顶部；
##   ④ 内容区宽仍锁在 170（原生 19px 滚动条一旦占位会把宽撑到 185、越出 175 宽的面板）。
##
## 跑法：Godot --headless --path . --script res://测试/任务追踪滚动回归测试.gd

var 行: Array[String] = []
var 出 := "res://测试/截图/追踪栏/任务追踪滚动.txt"
var 总 := 0
var 红 := 0


func _记(过: bool, 说: String) -> void:
	总 += 1
	if not 过:
		红 += 1
		行.append("  !! " + 说)
	else:
		行.append("  √ " + 说)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 会 := root.get_node_or_null("GameSession")
	if 会 == null:
		_记(false, "缺 GameSession")
		_收(); return
	var 表 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/任务.json"))
	var 列: Array[Dictionary] = []
	if 表 is Dictionary:
		for id in 表.keys():
			var 条 = 表[id]
			if not (条 is Dictionary):
				continue
			if String((条.get("info", {}) as Dictionary).get("type", "")) != "trunk":
				continue
			列.append({"id": String(id), "completed": false,
				"目标进度": [{"kind": "mob", "key": "1000001", "curr": 1, "count": 3}]})
	列.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	会.accepted_quests = 列
	var 空: Array[Dictionary] = []
	会.available_quests = 空
	var 板: Node = (load("res://场景/界面/小地图面板.tscn") as PackedScene).instantiate()
	root.add_child(板)
	await _帧(5)
	板.set("_quest_expanded", true)
	板.call("_refresh_quest_list")
	板.call("_刷新追踪高度")
	await _帧(5)
	var 区 := 板.find_child("任务内容区", true, false)
	var 列表 := 板.find_child("任务列表", true, false) as VBoxContainer
	_记(区 is ScrollContainer, "任务内容区是 ScrollContainer（原版是 ScrollPane；实得 %s）"
			% (区.get_class() if 区 != null else "null"))
	if not (区 is ScrollContainer) or 列表 == null:
		_收(); return
	var 滚 := 区 as ScrollContainer
	_记(列表.get_child_count() == 列.size(),
			"131 条主线全建了行（实得 %d）" % 列表.get_child_count())
	## 标题的名字/等级必须回落到定义表（运行期条目只有 id/状态/进度）：
	## 以前 `定.get("name")` 取不到（名字在 `定.info.name`）⇒ 全显示「[0](主线)任务」。
	var 题们: Array[String] = []
	for 行 in 列表.get_children():
		if 行.get_child_count() > 0 and 行.get_child(0) is Label:
			题们.append((行.get_child(0) as Label).text)
	var 攻城 := ""
	for t in 题们:
		if t.contains("攻城之战"):
			攻城 = t
	_记(攻城 == "[50](主线)攻城之战",
			"1270 的追踪标题是 [50](主线)攻城之战（实得 %s）" % (攻城 if not 攻城.is_empty() else "无"))
	_记(not 攻城.ends_with("任务") and not 攻城.begins_with("[0]"),
			"标题不再落到「[0]…任务」的占位值")
	var 内容高 := 列表.get_combined_minimum_size().y
	_记(内容高 > 滚.size.y + 20.0,
			"列表确实超高（内容 %.0f > 视口 %.0f）" % [内容高, 滚.size.y])
	var 前 := 滚.scroll_vertical
	var 点 := 滚.get_global_rect().get_center()
	root.warp_mouse(点)
	await _帧(2)
	for i in 3:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		ev.position = 点
		ev.global_position = 点
		root.push_input(ev)
		await _帧(2)
	_记(滚.scroll_vertical > 前, "滚轮能滚（%d → %d）" % [前, 滚.scroll_vertical])
	滚.scroll_vertical = 120
	await _帧(2)
	板.call("_refresh_quest_list")
	await _帧(6)
	_记(滚.scroll_vertical == 120,
			"任务帧到达、列表整段重建后滚动位置还在 120（实得 %d）" % 滚.scroll_vertical)
	_记(滚.size.x <= 170.5,
			"内容区宽仍锁 170（不能被滚动条撑成 185 越出面板；实得 %.1f）" % 滚.size.x)
	_收()


func _收() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	print("任务追踪滚动回归：共 %d 条，红 %d 条" % [总, 红])
	for s in 行:
		if s.begins_with("  !!"):
			printerr(s)
	quit(0 if 红 == 0 else 1)
