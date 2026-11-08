extends SceneTree

## 量「人物窗」三件事的现成量具（2026-10-25 用户实机报的三条）：
##   ① 写轮眼页左侧那列阶段钮有没有被原版那道「裁剪框」兜住（原版 VBox 90×200 带 mask）
##   ② 轮回六道页那一行 左箭头/阶段名/右箭头 的落点与尺寸
##   ③ 角色页那具人物到底是静态图还是在播待机
## 只报不改。跑法：Godot --headless --path . --script res://开发工具/量人物秘术页越界.gd

const 页表 := [[2, 0, "写轮眼"], [2, 1, "轮回六道"], [0, 0, "人物"]]

var _窗 = null


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _i in 5:
		await process_frame
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	会话.cultivation_states["写轮眼"] = {"stage": 3, "count": 40, "blessing": 0}
	会话.cultivation_states["轮回六道"] = {"stage": 3, "count": 2}
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	_窗 = 管理.call("取或建窗口", "人物")
	管理.call("打开", "人物")
	for _i in 4:
		await process_frame
	for 项 in 页表:
		_窗.call("_set_character_main_tab", int(项[0]))
		await process_frame
		_窗.call("_set_character_sub_tab", int(项[1]))
		for _i in 4:
			await process_frame
		var 名 := String(项[2])
		var 页 := _取子页(名)
		if 页 == null:
			print("### %s  取不到页面节点" % 名)
			continue
		print("### %s  页根尺寸 %s  子节点 %d" % [名, str(页.size), 页.get_child_count()])
		_走(页, 页, "")
	print("=== 完毕 ===")
	quit(0)


func _取子页(名: String) -> Control:
	var 内容 := _窗.get("_content") as Control
	if 内容 == null:
		return null
	var 页面 := 内容.find_child("原版人物窗口内容", true, false) as Control
	if 页面 == null:
		return null
	if 名 == "人物":
		return 页面.get_node_or_null("原版人物属性面板") as Control
	var 面板 := 页面.get_node_or_null("人物扩展页") as Panel
	return null if 面板 == null else 面板.get_node_or_null("%s内容" % 名) as Control


func _可见(c: Control) -> bool:
	var 节点: Node = c
	while 节点 is Control:
		if not (节点 as Control).visible:
			return false
		节点 = 节点.get_parent()
	return true


func _走(节: Node, 页: Control, 前缀: String) -> void:
	for 子在 in 节.get_children():
		if not (子在 is Control):
			continue
		var c := 子在 as Control
		var 路 := 前缀 + "/" + String(c.name)
		var r := c.get_global_rect()
		var 顶 := 页.get_global_position()
		var 相 := Rect2(r.position - 顶, r.size)
		var 裁 := ""
		var 祖: Node = c.get_parent()
		while 祖 != null and 祖 != 页:
			if 祖 is ScrollContainer:
				裁 = "在滚动区 %s 内" % String(祖.name)
				break
			if 祖 is Control and (祖 as Control).clip_contents:
				裁 = "被 %s 裁剪" % String(祖.name)
				break
			祖 = 祖.get_parent()
		var 出 := []
		if 相.position.x < -0.5: 出.append("左%.0f" % -相.position.x)
		if 相.position.y < -0.5: 出.append("上%.0f" % -相.position.y)
		if 相.end.x > 页.size.x + 0.5: 出.append("右%.0f" % (相.end.x - 页.size.x))
		if 相.end.y > 页.size.y + 0.5: 出.append("下%.0f" % (相.end.y - 页.size.y))
		var 文 := "%-46s %-28s %s" % [路, "%dx%d @(%+.0f,%+.0f)" % [相.size.x, 相.size.y, 相.position.x, 相.position.y],
				("越界 " + "/".join(出)) if not 出.is_empty() else "在页内"]
		if not _可见(c):
			文 += "  [隐藏]"
		if 裁 != "":
			文 += "  " + 裁
		if c is TextureRect:
			var t := (c as TextureRect).texture
			文 += "  图=%s 天然=%s 拉伸=%s" % [
				str(t.resource_path).get_file() if t != null else "null",
				str(t.get_size()) if t != null else "-", str(c.expand_mode)]
		if c is Button:
			var b := c as Button
			文 += "  钮文=%s 图标=%s 禁用=%s" % [b.text,
				str(b.icon.resource_path).get_file() if b.icon != null else "无", str(b.disabled)]
		if c is CanvasItem and not (c is Control):
			pass
		print(文)
		_走(c, 页, 路)

