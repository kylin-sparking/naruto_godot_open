extends SceneTree
## 无头量「智能托管打怪设置」窗里 10 枚下拉的**解算后**几何与项表。
##
## 为什么要单独一道：`OptionButton` 的可用文字宽 = 框宽 − 样式左右内边距 − 箭头图标宽
## − `h_separation`。上一轮 80 的框里「从大到小」只画得出「从大到」，就是被这套边距吃掉的，
## 而几何门只比框的 position/size ⇒ 门绿、屏幕缺字（量具读声明值、屏幕读解算值那一类）。
##
## 用法：Godot --headless --path . --script res://开发工具/量挂机下拉.gd

const 页名 := "挂机"
const 下拉表 := ["下拉生命药品", "下拉查克拉药品", "下拉拾取职业", "下拉拾取等级", "下拉拾取品质",
		"下拉自动忍术", "下拉自动宠物忍术", "下拉出售等级", "下拉出售职业", "下拉出售品质"]


func _initialize() -> void:
	call_deferred("_跑")


func _等帧(n: int) -> void:
	for _i in maxi(1, n):
		await process_frame


func _跑() -> void:
	root.size = Vector2i(960, 560)
	await _等帧(2)
	var 图: Node = (load("res://场景/生成/地图_101010000_烘焙.tscn") as PackedScene).instantiate()
	root.add_child(图)
	current_scene = 图
	await _等帧(6)
	var 管: Node = 图.get_node_or_null("窗口管理")
	管.call("打开", 页名)
	await _等帧(6)
	var 窗: Node = 管.call("取或建窗口", 页名) as Node
	var 页: Node = null
	if 窗 != null:
		页 = (窗 as Node).find_child("原版挂机设置内容", true, false)
	if 页 == null:
		print("取不到页面根。窗=", 窗.name if 窗 != null else "null",
				" 全局位=", str((窗 as Control).global_position) if 窗 != null else "",
				" 子件=", _名(窗) if 窗 != null else [])
		quit(1)
		return
	print("窗类=%s 页面根=%s 全局位=%s 尺寸=%s" % [(窗 as Node).get_class(), (页 as Node).name,
			str((页 as Control).get_global_position()), str((页 as Control).size)])
	for 名 in 下拉表:
		var 件 := (页 as Node).get_node_or_null(名) as OptionButton
		if 件 == null:
			print("查无 %s" % 名)
			continue
		var 皮: StyleBox = 件.get_theme_stylebox("normal") as StyleBox
		var 箭: Texture2D = 件.get_theme_icon("arrow") as Texture2D
		var 左 := 5 if 皮 == null else int(皮.content_margin_left)
		var 右 := 5 if 皮 == null else int(皮.content_margin_right)
		var 分: int = 件.get_theme_constant("h_separation")
		var 箭宽 := 0 if 箭 == null else 箭.get_width()
		var 可用: float = 件.size.x - float(左) - float(右) - float(箭宽) - float(分)
		var 项: Array = []
		for i in 件.item_count:
			项.append(件.get_item_text(i))
		print("%s 宽=%s 内边距=%d/%d 箭头=%d 间隔=%d 可用文字=%.0f 文=%s 项=%s" % [
				名, str(件.size.x), 左, 右, 箭宽, 分, 可用, 件.text, str(项)])
	quit(0)


func _名(n: Node) -> Array:
	var 出: Array = []
	if n == null:
		return 出
	for 子 in n.get_children():
		出.append(String((子 as Node).name))
	return 出
