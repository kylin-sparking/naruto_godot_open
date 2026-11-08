extends SceneTree

## 文字碰撞探针：量七个扩展页上**文字墨迹**两两相压的情况。
##
## 用法：Godot --headless --path . --script res://开发工具/文字碰撞探针.gd
## 为什么量墨迹不量盒子：Label/Button 的盒是排版锚，原版 Flash 的文字一样会画到盒外；
## 真正的问题只有**两行字的墨迹叠在一起**（看着糊/串行）。字号统一抬到 12 之后就靠这条判有没有压。

const 页表 := [
	[1, 0, "八门"], [1, 1, "柔拳"], [1, 2, "寄坏之术"],
	[2, 0, "写轮眼"], [2, 1, "轮回六道"],
	[0, 1, "手里剑"], [0, 2, "结印"],
]


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _i in 5:
		await process_frame
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	会话.cultivation_states["写轮眼"] = {"stage": 9, "count": 3, "blessing": 40}
	会话.cultivation_states["柔拳"] = {"stage": 5, "count": 7}
	会话.cultivation_states["轮回六道"] = {"stage": 4, "count": 2}
	会话.cultivation_states["结印"] = {"stage": 7, "count": 12}
	会话.cultivation_states["八门"] = {"list_id": 1, "total_points": 62, "exploded_total": 58,
		"shared_exp": 1000, "shared_exp_count": 7,
		"attrs": {"atk": 30, "def": 12, "bsk": 5, "avd": 8, "maxhp": 50, "maxmp": 20}}
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	var 窗 = 管理.call("取或建窗口", "人物") if 管理 != null else null
	if 窗 == null:
		print("拿不到人物窗")
		quit(1)
		return
	管理.call("打开", "人物")
	for _i in 4:
		await process_frame

	var 总压 := 0
	for 项: Array in 页表:
		窗.call("_set_character_main_tab", int(项[0]))
		await process_frame
		窗.call("_set_character_sub_tab", int(项[1]))
		for _i in 3:
			await process_frame
		var 页 := _取页(窗, String(项[2]))
		if 页 == null:
			print("!! %s 页没建出来" % String(项[2]))
			continue
		var 条 := 碰(页)
		总压 += 条.size()
		print("── %s：%d 处相压" % [String(项[2]), 条.size()])
		for 一 in 条.slice(0, 14):
			print("   " + String(一))
		if 条.size() > 14:
			print("   …（共 %d）" % 条.size())
	print("合计 %d 处" % 总压)
	quit(0)


func _取页(窗, 名: String) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	var 页面 := 内容.find_child("原版人物窗口内容", true, false) as Control
	var 面板 := 页面.get_node_or_null("人物扩展页") as Panel if 页面 != null else null
	return null if 面板 == null else 面板.get_node_or_null("%s内容" % 名) as Control


## 收下页内所有**可见**的文字节点，算出墨迹矩形，再两两比。
func 碰(页: Control) -> Array[String]:
	var 件: Array = []
	收(页, 件)
	var 报: Array[String] = []
	for i in 件.size():
		for j in range(i + 1, 件.size()):
			var a: Dictionary = 件[i]
			var b: Dictionary = 件[j]
			if _互含(a["节点"], b["节点"]):
				continue
			var 交: Rect2 = a["墨"].intersection(b["墨"])
			if 交.size.x > 2.0 and 交.size.y > 2.0:
				报.append("压 %.0fx%.0f  「%s」(%s号) × 「%s」(%s号)  @ %s" % [
					交.size.x, 交.size.y, String(a["文"]), str(a["号"]),
					String(b["文"]), str(b["号"]), String(a["名"])])
	return 报


func _互含(x: Node, y: Node) -> bool:
	var p := y.get_parent()
	while p != null:
		if p == x:
			return true
		p = p.get_parent()
	return false


func 收(节点: Node, 件: Array) -> void:
	for 子 in 节点.get_children():
		# ⚠️ 用 `is_visible_in_tree()` 而不是 `visible`：写轮眼/柔拳那几页有 12 套**同坐标**的
		#    阶段面板，靠祖先整块隐藏来切换 —— 只判自己那层会把 12 套全收进来，虚报几千处相压。
		if 子 is Control and (子 as Control).is_visible_in_tree():
			if 子 is Label:
				加(子 as Label, 件)
			elif 子 is Button:
				加钮(子 as Button, 件)
		收(子, 件)


func 加(标签: Label, 件: Array) -> void:
	if 标签.text.strip_edges().is_empty():
		return
	墨(标签, 标签.text, 标签.get_theme_font("font"), 标签.get_theme_font_size("font_size"),
			标签.horizontal_alignment, 标签.vertical_alignment, 件)


func 加钮(钮: Button, 件: Array) -> void:
	if 钮.text.strip_edges().is_empty():
		return
	墨(钮, 钮.text, 钮.get_theme_font("font"), 钮.get_theme_font_size("font_size"),
			钮.alignment, VERTICAL_ALIGNMENT_CENTER, 件)


## 墨迹矩形 = 按**每行最宽**算（`get_string_size` 整串量把 `\\n` 当一行，会把两行文字算成一行宽）。
func 墨(控件: Control, 文本: String, 字体: Font, 号: int, 横: int, 纵: int, 件: Array) -> void:
	if 字体 == null:
		return
	var 宽 := 0.0
	var 行 := 文本.split("\n")
	for 一 in 行:
		宽 = maxf(宽, 字体.get_string_size(一, HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x)
	var 高 := 字体.get_height(号) * float(行.size())
	var 盒 := Rect2(控件.global_position, 控件.size)
	var x := 盒.position.x
	if 横 == HORIZONTAL_ALIGNMENT_CENTER:
		x = 盒.position.x + (盒.size.x - 宽) / 2.0
	elif 横 == HORIZONTAL_ALIGNMENT_RIGHT:
		x = 盒.end.x - 宽
	var y := 盒.position.y
	if 纵 == VERTICAL_ALIGNMENT_CENTER:
		y = 盒.position.y + (盒.size.y - 高) / 2.0
	elif 纵 == VERTICAL_ALIGNMENT_BOTTOM:
		y = 盒.end.y - 高
	var 项 := {}
	项["节点"] = 控件
	项["墨"] = _裁剪到可见区(Rect2(x, y, 宽, 高), 控件)
	项["文"] = 文本.replace("\n", "↵")
	项["号"] = 号
	项["名"] = String(控件.name)
	件.append(项)


## ⚠️ `ScrollContainer` 会裁掉画在自己矩形外的子节点文字，而 `is_visible_in_tree()` 并不知道这件事。
##    写轮眼页那 12 枚阶段钮就在一个 77x204 的滚动框里 —— 不裁会把滚出可视区的行报成"压到属性面板"。
func _裁剪到可见区(墨迹: Rect2, 控件: Control) -> Rect2:
	var 结果 := 墨迹
	var 父 := 控件.get_parent()
	while 父 != null:
		if 父 is ScrollContainer:
			var 框: Rect2 = (父 as Control).get_global_visible_rect()
			结果 = 结果.intersection(框)
			if not 结果.has_area():
				return 结果
		父 = 父.get_parent()
	return 结果
