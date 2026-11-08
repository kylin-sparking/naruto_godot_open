extends SceneTree
## 只做一件事：把改过的人物窗场景 load + instantiate 出来，确认
## 新加的 `他人信息面板` 那 17 个节点在、矩形对、贴图取到了（不判版式，版式归几何门）。
func _initialize() -> void:
	var 包 := load("res://场景/界面/窗口/人物/人物窗口.tscn") as PackedScene
	if 包 == null:
		print("红：场景 load 不出来")
		quit(1); return
	var 页 := 包.instantiate() as Control
	root.add_child(页)
	var 块 := 页.get_node_or_null("原版人物属性面板/他人信息面板") as Control
	if 块 == null:
		print("红：他人信息面板 这个节点不在")
		quit(1); return
	var 数 := 0
	for 名 in ["忍术境界名", "忍术境界槽", "忍术境界值", "八门进度名", "八门进度槽", "八门进度值",
			"成就进度名", "成就进度槽", "成就进度值", "条下分隔线", "密语钮", "交易钮", "加友钮", "组队钮"]:
		var n := 块.get_node_or_null(名)
		if n == null:
			print("红：缺件 %s" % 名)
			数 += 1
			continue
		var r: Rect2 = (n as Control).get_rect()
		print("  %-12s %s" % [名, str(r)])
	var 钮 := 块.get_node("密语钮") as TextureButton
	print("密语钮贴图：%s 悬停：%s" % [str(钮.texture_normal), str(钮.texture_hover)])
	var 条 := 块.get_node("忍术境界槽") as ProgressBar
	var 皮: StyleBoxTexture = 条.get_theme_stylebox("background") as StyleBoxTexture
	print("忍术境界槽底图：%s" % (str(皮.texture.resource_path) if 皮 != null else "取不到"))
	quit(1 if 数 > 0 else 0)
