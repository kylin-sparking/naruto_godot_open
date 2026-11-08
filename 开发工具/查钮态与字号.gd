extends SceneTree
## 无头探针：右页三颗原版钮（Button 主题族）在 Godot 里**每个态槽实际解算到哪张皮**，
## 以及左页数字（LineEdit）解算到的字号。只读，不写盘、不建窗。
## 跑法：Godot --headless --path . --script res://开发工具/查钮态与字号.gd

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")


func _desc(s: StyleBox) -> String:
	if s == null:
		return "null"
	var 尾 := "空"
	if s is StyleBoxTexture:
		var t := (s as StyleBoxTexture).texture
		尾 = "贴图=%s modulate=%s" % [
			("<无>" if t == null else t.resource_path.get_file()),
			str((s as StyleBoxTexture).modulate_color)]
	elif s is StyleBoxFlat:
		尾 = "纯色=%s" % str((s as StyleBoxFlat).bg_color)
	return "%s %s" % [s.get_class(), 尾]


func _initialize() -> void:
	var 钮 := Button.new()
	var 值 := LineEdit.new()
	root.add_child(钮)
	root.add_child(值)
	print("全局主题 =", str(root.theme))
	print("皮肤表登记的按钮 =", 皮肤表.按钮.get_file(), " / 按下 =", 皮肤表.按钮按下.get_file())
	for 槽 in ["normal", "hover", "hover_pressed", "pressed", "focus", "disabled"]:
		var 有 := false
		if root.theme != null:
			有 = root.theme.has_stylebox(槽, "Button")
		print("Button/%-13s 主题里有=%-5s 解算=%s" % [槽, str(有), _desc(钮.get_theme_stylebox(槽))])
	print("钮.draw_mode 枚举值: NORMAL=%d HOVER=%d PRESSED=%d HOVER_PRESSED=%d DISABLED=%d" % [
		BaseButton.DRAW_NORMAL, BaseButton.DRAW_HOVER, BaseButton.DRAW_PRESSED,
		BaseButton.DRAW_HOVER_PRESSED, BaseButton.DRAW_DISABLED])
	print("LineEdit 字号 =", 值.get_theme_font_size("font_size"))
	var 字 := Label.new()
	root.add_child(字)
	print("Label 字号 =", 字.get_theme_font_size("font_size"))
	字.free()
	钮.free()
	值.free()
	quit(0)
