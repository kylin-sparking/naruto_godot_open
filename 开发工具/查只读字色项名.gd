extends SceneTree
## 无头探针：只读 LineEdit 的**字色主题项到底叫什么**。
## 为什么要有它：主题项名写错**不会报错**，`get_color("错名")` 照样返回自己塞进去的值 ⇒
## 门照绿、屏幕上一点没变（10-20 实测：写 `font_read_only` 后数字最高仍是 (107,107,107)）。
## 跑法：Godot --headless --path . --script res://开发工具/查只读字色项名.gd

func _initialize() -> void:
	var 框 := LineEdit.new()
	框.editable = false
	root.add_child(框)
	var 题: Theme = ThemeDB.get_project_theme()
	print("项目主题 =", "<无>" if 题 == null else str(题.resource_path))
	for 名 in ["font_color", "font_readonly_color", "font_read_only", "font_placeholder_color"]:
		var 在题 := false
		if 题 != null:
			在题 = 题.has_color(名, "LineEdit")
		print("%-22s 项目主题里有=%-5s 解算=%s" % [名, str(在题), str(框.get_theme_color(名))])
	print("默认主题里 LineEdit 的字色项 =", ThemeDB.get_default_theme().get_color_list("LineEdit"))
	框.free()
	quit(0)
