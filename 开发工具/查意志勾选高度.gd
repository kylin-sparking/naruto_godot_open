extends SceneTree
## 无头探针：`意志学习窗/锁定勾选` 这一枚 CheckBox 的矩形为什么从 27 高变成 19 高。
## 跑法：Godot --headless --path . --script res://开发工具/查意志勾选高度.gd

func _initialize() -> void:
	var 裸 := CheckBox.new()
	root.add_child(裸)
	print("裸 CheckBox 最小高 =", 裸.get_combined_minimum_size())
	裸.free()
	for 路 in ["res://场景/界面/窗口/遗址/意志背包窗口.tscn"]:
		if not ResourceLoader.exists(路):
			print("查无场景 ", 路)
			continue
		var 根 := (load(路) as PackedScene).instantiate() as Control
		root.add_child(根)
		await process_frame
		var 件 := _找(根, "锁定勾选")
		if 件 == null:
			print(路.get_file(), " 里查无 锁定勾选")
			根.queue_free()
			continue
		var c := 件 as CheckBox
		print("%s / %s 类=%s" % [路.get_file(), 件.name, 件.get_class()])
		print("   size=", 件.size, " 最小=", c.get_combined_minimum_size() if c != null else "?")
		if c != null:
			for 名 in ["checked", "unchecked"]:
				var 图 := c.get_theme_icon(名)
				print("   图标 %s = %s" % [名, "<无>" if 图 == null else str(图.get_size())])
			var 字 := c.get_theme_font("font")
			print("   字体高=", 0 if 字 == null else 字.get_height(c.get_theme_font_size("font_size")),
					" 字号=", c.get_theme_font_size("font_size"))
			print("   样式 normal=", str(c.get_theme_stylebox("normal")))
		根.queue_free()
		await process_frame
	quit(0)


func _找(节: Node, 名: String) -> Node:
	if 节.name == 名:
		return 节
	for 子 in 节.get_children():
		var 得 := _找(子, 名)
		if 得 != null:
			return 得
	return null
