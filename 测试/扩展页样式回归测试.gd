extends SceneTree

## 描边数值**从皮肤表读、不写死**（见 §3.41.3）：它是规则、不是不变量。
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

## 七个扩展页的**样式不被宿主脚本冲掉**。
##
## 背景（2026-09-25）：`人物窗口.统一页面字号()` 原来是**一刀切**版 —— 递归给扩展页下
## 所有 Label / RichTextLabel / Button 套默认样式，把页面作者在 `.tscn` 里调好的配色与尺寸
## 全冲掉。后果：
##   * 颜色：写轮眼 191 处、柔拳 105 处、寄坏 15 处、轮回六道 58 处 `font_color` **全是非白色**，
##     也就是这四页的配色 **100% 被冲成米白** `#f5ead6`；
##   * 尺寸：`_configure_standard_button` 会写 `custom_minimum_size = (57, 22)`
##     （`脚本/界面/窗口/界面皮肤.gd`），弹窗里的 40x40 小方钮被撑大、顶出面板。
##
## 覆盖发生在**宿主脚本**里，页面侧无法自救 —— 所以这条只能靠这里的回归钉住。
##
## 断言是**属性式**的（不写死具体控件）：凡是"场景里已经设过"的样式，
## 过一遍 `统一页面字号()` 之后必须**一个字节都没变**。
##
## 用法：
##   Godot --headless --path . --script res://测试/扩展页样式回归测试.gd

const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 页面目录 := "res://场景/界面/窗口/人物/页面/"
const 七页 := ["八门页", "手里剑页", "写轮眼页", "结印页", "柔拳页", "寄坏之术页", "轮回六道页"]
const 米白 := Color("#f5ead6")

var _失败: Array[String] = []
var _窗口: Node = null


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 窗场景 := load("res://场景/界面/功能窗口.tscn") as PackedScene
	_窗口 = 窗场景.instantiate()
	root.add_child(_窗口)
	await process_frame

	var 总被保住的颜色 := 0
	var 总被保住的尺寸 := 0
	for 页名 in 七页:
		var 包 := load(页面目录 + 页名 + ".tscn") as PackedScene
		if 包 == null:
			_失败.append("%s 场景加载不了" % 页名)
			continue
		var 页面 := 包.instantiate() as Control
		root.add_child(页面)
		await process_frame
		var 快照 := _快照(页面)
		人物窗口脚本.统一页面字号(_窗口, 页面)
		await process_frame
		var 结果 := _比对(页面, 快照, 页名)
		总被保住的颜色 += int(结果["保色"])
		总被保住的尺寸 += int(结果["保尺寸"])
		root.remove_child(页面)
		页面.queue_free()

	# 这一条是**防呆**：如果哪天有人把函数改回一刀切，上面的"保住"计数会掉到 0，
	# 但断言本身是"没被改坏"，所以还要单独确认**确实有东西被保住**。
	if 总被保住的颜色 == 0:
		_失败.append("七个页面里没有任何一处场景配色被保住 —— 是不是又变回一刀切了？")
	if 总被保住的尺寸 == 0:
		_失败.append("七个页面里没有任何一个按钮的自定义尺寸被保住 —— 同上")

	# 附加需求 A（2026-09-25）：八门页 182 处纯白字 → 米白 + 黑色 3px 描边。
	# 这条**在 .tscn 文本层面查** —— 它要的是一次性的批量改写，不是运行期行为，
	# 所以不放进上面那套实例化比对里。
	var 八门文本 := FileAccess.get_file_as_string("res://场景/界面/窗口/人物/页面/八门页.tscn")
	if 八门文本.is_empty():
		_失败.append("八门页.tscn 读不出来")
	else:
		var 剩纯白 := 0
		var 有描边 := 0
		var 关阴影 := 0
		var 有阴影 := 0
		for 行 in 八门文本.split("
"):
			var 去空 := 行.strip_edges()
			if 去空 == "theme_override_colors/font_color = Color(1, 1, 1, 1)":
				剩纯白 += 1
			elif 去空 == "theme_override_constants/outline_size = %d" % 皮肤表.文字规则_描边数值:
				有描边 += 1
			elif 去空 == "theme_override_colors/font_shadow_color = Color(0, 0, 0, 0)":
				关阴影 += 1
			elif 去空 == "theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)":
				有阴影 += 1
		if 剩纯白 != 0:
			_失败.append("八门页还剩 %d 处纯白 font_color（需求 A 要求全部换成米白+描边）" % 剩纯白)
		# 2026-09-26：原断言写死「有描边 == 182」。182 是当时 .tscn 的行数，**不是不变量** ——
		# 对方重做八门页（+490 行）后变成 209，一条真需求被一个会漂的数字顶红。
		# 改成钉**成对关系**：每处 `outline_size = 3` 旁边必须有一处 `font_shadow_color = (0,0,0,0)`，
		# 实测 209/209（手里剑页 31/31、结印页 65/65 同形）。只改了一半的 Label 会被这条抓住。
		if 有描边 != 关阴影:
			_失败.append("八门页 3px 描边 %d 处、关阴影 %d 处 —— 两者必须成对（只改一半的 Label）"
				% [有描边, 关阴影])
		if 有描边 < 182:
			_失败.append("八门页带 3px 描边的节点只剩 %d 处，少于 2026-09-25 定下的 182（页面被删节点了？）"
				% 有描边)
		if 有阴影 != 0:
			_失败.append("八门页还剩 %d 处不透明的黑色阴影（应统一成透明）" % 有阴影)

	if _失败.is_empty():
		print("扩展页样式回归测试：通过（保住场景配色 %d 处、自定义按钮尺寸 %d 个）" % [总被保住的颜色, 总被保住的尺寸])
		quit(0)
		return
	for 项 in _失败:
		push_error("扩展页样式回归测试：失败 - %s" % 项)
	quit(1)


## 遍历整棵子树，记下**场景里已经设过**的样式。
## 只记"非空"的 —— 没设过的本来就该由宿主补默认值，不算"被冲掉"。
func _快照(节点: Node, 出 := {}) -> Dictionary:
	for 子 in 节点.get_children():
		if 子 is Label:
			var 标签 := 子 as Label
			var 色: Variant = 标签.get("theme_override_colors/font_color")
			var 号: Variant = 标签.get("theme_override_font_sizes/font_size")
			if 色 != null or 号 != null:
				出[标签.get_path()] = {"色": 色, "号": 号}
		elif 子 is RichTextLabel:
			var 富 := 子 as RichTextLabel
			var 号2: Variant = 富.get("theme_override_font_sizes/normal_font_size")
			if 号2 != null:
				出[富.get_path()] = {"号": 号2}
		elif 子 is Button:
			var 钮 := 子 as Button
			var 尺: Variant = 钮.get("custom_minimum_size")
			if 尺 != null and (尺 as Vector2) != Vector2.ZERO:
				出[钮.get_path()] = {"尺寸": 尺}
		_快照(子, 出)
	return 出


func _比对(节点: Node, 快照: Dictionary, 页名: String) -> Dictionary:
	var 保色 := 0
	var 保尺寸 := 0
	_比对递归(节点, 快照, 页名)
	for 键 in 快照:
		if 快照[键].has("色") or 快照[键].has("号"):
			保色 += 1
		if 快照[键].has("尺寸"):
			保尺寸 += 1
	return {"保色": 保色, "保尺寸": 保尺寸}


func _比对递归(节点: Node, 快照: Dictionary, 页名: String) -> void:
	for 子 in 节点.get_children():
		var 路 := 子.get_path()
		if 快照.has(路):
			var 记: Dictionary = 快照[路]
			if 子 is Label:
				var 标签 := 子 as Label
				# ⚠️ 只在**场景设过**时才比：设成 null 的项，宿主补默认值是**本意**
				# （"只缺哪项补哪项"），不算被改。
				if 记.has("色") and 记["色"] != null:
					var 现在: Variant = 标签.get("theme_override_colors/font_color")
					if 现在 != 记["色"]:
						_失败.append("%s 的 %s 颜色被改了：场景 %s → 现在 %s" % [页名, 路, 记["色"], 现在])
				if 记.has("号") and 记["号"] != null:
					var 号: Variant = 标签.get("theme_override_font_sizes/font_size")
					if 号 != 记["号"]:
						_失败.append("%s 的 %s 字号被改了：场景 %s → 现在 %s" % [页名, 路, 记["号"], 号])
			elif 子 is RichTextLabel:
				var 富 := 子 as RichTextLabel
				if 记.has("号") and 记["号"] != null:
					var 号2: Variant = 富.get("theme_override_font_sizes/normal_font_size")
					if 号2 != 记["号"]:
						_失败.append("%s 的 %s 富文本字号被改了：场景 %s → 现在 %s" % [页名, 路, 记["号"], 号2])
			elif 子 is Button:
				var 钮 := 子 as Button
				if 记.has("尺寸") and (记["尺寸"] as Vector2) != Vector2.ZERO and 钮.custom_minimum_size != (记["尺寸"] as Vector2):
					_失败.append("%s 的按钮 %s 尺寸被改了：场景 %s → 现在 %s" % [
						页名, 路, 记["尺寸"], 钮.custom_minimum_size])
		_比对递归(子, 快照, 页名)
