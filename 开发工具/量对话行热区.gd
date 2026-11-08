## 真鼠标量具：NPC 对话窗那几行菜单，**哪些像素点得中、点了触发哪一行**。
## 起因：用户 2026-10-10 报「物品交易 / 离开 两行点击范围过小」。
## 静态读代码只会绕圈（Flash 的 `SelectionLalel` 命中区=图标+文字的实际像素，
## 而 Godot 的命中区=Control 矩形，两者不是一回事），所以只能量。
## 跑法：有头（--headless 拿不到视口拾取）
extends SceneTree

var 行: Array[String] = []
var 出 := "res://测试/截图/NPC对话/行热区.txt"
var 最近 := -999


func _initialize() -> void:
	call_deferred("_跑")


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _跑() -> void:
	var 场: Node = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(50)
	var 板: Node = null
	for 层 in root.get_children():
		板 = 层.find_child("小地图面板", true, false)
		if 板 != null:
			break
	if 板 == null:
		_记("找不到 小地图面板"); _收(); return
	## 走真路径：对话窗由 小地图面板 现建（`_对话`），不是烘在 HUD 里的节点
	## （第一版拿 find_child("原版NPC对话") 找到的是同名 TextureRect ⇒ 调用直接报错挂住）。
	板.call("show_npc_dialog", "00000015")
	await _帧(10)
	var 窗: Node = 板.get("_对话")
	if 窗 == null:
		_记("show_npc_dialog 之后 面板._对话 还是空"); _收(); return
	var 根: Control = 窗.call("根") as Control
	var 菜单: Control = 根.get_node_or_null("下格/菜单") as Control
	_记("菜单 全局=%s 尺寸=%s 裁=%s" % [str(菜单.global_position), str(菜单.size), str(菜单.clip_contents)])
	var 行们: Array = []
	for 子 in 菜单.get_children():
		var c := 子 as Control
		if c == null or not c.visible:
			continue
		行们.append(c)
		var 说 := "行 %s 全局=%s 尺寸=%s filter=%s" % [c.name, str(c.global_position), str(c.size), str(c.mouse_filter)]
		for 孙 in c.get_children():
			var s2 := 孙 as Control
			if s2 != null:
				说 += "\n    %s 全局=%s 尺寸=%s filter=%s" % [s2.name, str(s2.global_position), str(s2.size), str(s2.mouse_filter)]
		_记(说)
	# 真点：每行的「图标中心 / 文字中心 / 文字右侧空白 / 行上沿-3 / 行下沿+3」
	窗.行被点.connect(func(v): 最近 = int(v))
	_记("---- 逐点真按（看 最近 变成几）----")
	for i in 行们.size():
		var c: Control = 行们[i]
		var 文: Control = c.get_node("文字") as Control
		var 手: Control = c.get_node("手形") as Control
		var 点表 := {
			"手形心": 手.global_position + 手.size * 0.5,
			"文字心": 文.global_position + Vector2(20.0, 文.size.y * 0.5),
			"行内右空白": c.global_position + Vector2(c.size.x - 6.0, c.size.y * 0.5),
			"文字上沿-3": 文.global_position + Vector2(20.0, -3.0),
			"行上沿-3": c.global_position + Vector2(c.size.x * 0.5, -3.0),
			"行下沿+3": c.global_position + Vector2(c.size.x * 0.5, c.size.y + 3.0),
		}
		for 键 in ["手形心", "文字心", "行内右空白", "文字上沿-3", "行上沿-3", "行下沿+3"]:
			var 点: Vector2 = 点表[键]
			最近 = -999
			var 移 := InputEventMouseMotion.new()
			移.position = 点
			移.global_position = 点
			root.push_input(移)
			await _帧(2)
			var 拾: Control = root.gui_get_hovered_control()
			var 按 := InputEventMouseButton.new()
			按.position = 点
			按.global_position = 点
			按.button_index = MOUSE_BUTTON_LEFT
			按.pressed = true
			root.push_input(按)
			await _帧(1)
			按.pressed = false
			root.push_input(按)
			await _帧(2)
			_记("行%d %-10s (%.0f,%.0f) 拾到=%-8s 触发=%s" % [
					i + 1, 键, 点.x, 点.y,
					"(空)" if 拾 == null else String(拾.name),
					"无" if 最近 == -999 else str(最近)])
			窗.call("显示", 15, "小悟", "最新鲜的食材制作的料理，要选购点吗？",
					[["物品交易", 1], ["离开", -1]], [])
			await _帧(6)
	_收()


func _收() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	quit(0)
