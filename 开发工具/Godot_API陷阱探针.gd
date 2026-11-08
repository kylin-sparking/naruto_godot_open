extends SceneTree

## 逐条复验「疑似 API 陷阱」，**只认本机 build 的实测结果**。
##
## 为什么要有它：另一位开发者交来的技能包里有一张 4.7.**2** 的 API 差异表
## （`其他开发者提供/Qoder技能合集_火影Flash转Godot/skills/godot-cli-verify-harness/references/api-deltas-4.7.2.md`），
## 而本机跑的是 4.7.**1** —— 那张表**不能照抄**。这里把它的每一条拿到本机重打一遍，
## 结果落进 `开发工具/Godot API 陷阱.md`。
##
## ⚠️ 表的用法（照抄对方那条）：「表里没写」≠「存在」，「表里写了」也要复验 ——
##    升版或换机之后重跑本探针即可。
##
## 运行：
##   Godot --headless --path . --script res://开发工具/Godot_API陷阱探针.gd


func _initialize() -> void:
	print("引擎：", Engine.get_version_info().string, "  （本表只对本 build 有效）")
	print("")

	_查方法("VideoStreamPlayer", ["get_video_size", "get_playback_position"])
	_查属性("VideoStreamPlayer", ["centered"])
	_查方法("LineEdit", ["grab_release_focus"])
	_查属性("LineEdit", ["clip_text"])
	_查方法("PopupMenu", ["popup_at_position"])
	_查属性("StyleBoxFlat", ["gradient"])
	_查方法("Gradient", ["from_colors"])
	_查属性("AnimatedTexture", ["fps", "loop"])
	_查属性("AnimatedTexture", ["frames", "speed_scale"])
	_查属性含("AnimatedTexture", "duration")
	_查方法("RegEx", ["match", "search"])
	_查属性("Button", ["vertical_alignment", "icon_display_policy"])
	_查属性("Label", ["font_flags"])
	_查属性("TextureRect", ["region_enabled", "region_rect"])
	_查属性("TextureButton", ["region_enabled"])

	# 静态 vs 实例：DirAccess 的两个建目录名字很像，调错是**解析期**就死
	print("— DirAccess —")
	print("  make_dir_recursive_absolute 静态可调: ",
		ClassDB.class_has_method("DirAccess", "make_dir_recursive_absolute", true))
	print("  make_dir_exists_absolute    静态可调: ",
		ClassDB.class_has_method("DirAccess", "make_dir_exists_absolute", true))

	# CompressedTexture2D.get_resource_path()：文档里有、build 里没有
	_查方法("CompressedTexture2D", ["get_resource_path"])

	# ClassDB.class_get_property_list 的第二个参数是 **no_inheritance**（不是 inherited）
	var 本类 := ClassDB.class_get_property_list("Button", true).size()
	var 全部 := ClassDB.class_get_property_list("Button", false).size()
	print("— ClassDB.class_get_property_list —")
	print("  Button 传 true（只本类）%d 条 / 传 false（含继承）%d 条 ⇒ 第二参是 no_inheritance" % [本类, 全部])

	# CheckBox 继承 Button？（主题污染的根源）
	print("— CheckBox 的继承 —")
	print("  CheckBox is Button: ", ClassDB.is_parent_class("CheckBox", "Button"))

	quit(0)


func _查方法(类: String, 名单: Array) -> void:
	for 名 in 名单:
		print("%-20s %-26s %s" % [类, 名 + "()", "有" if ClassDB.class_has_method(类, 名) else "**没有**"])


func _查属性(类: String, 名单: Array) -> void:
	var 有 := {}
	for 项 in ClassDB.class_get_property_list(类, false):
		有[String(项.get("name", ""))] = true
	for 名 in 名单:
		print("%-20s %-26s %s" % [类, 名, "有" if 有.has(名) else "**没有**"])


func _查属性含(类: String, 片段: String) -> void:
	var 命中: Array[String] = []
	for 项 in ClassDB.class_get_property_list(类, false):
		var 名 := String(项.get("name", ""))
		if 名.contains(片段):
			命中.append(名)
	print("%-20s 含「%s」的属性 %d 个: %s" % [类, 片段, 命中.size(), 命中.slice(0, 4)])
