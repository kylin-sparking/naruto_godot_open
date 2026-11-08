extends SceneTree
## 创建角色窗的**有头量具**：把窗摆到真视口上，拍四张状态图 + 打一份几何表。
##
## 为什么必须**有头**：无头拿不到视口图像（工程里反复踩过）。
## 跑法：Godot --path . --script res://开发工具/截创角页.gd
##
## 四张图就是"自己验收"要看的东西：
##   01_常态.png   开窗第一帧（原版 ADDED_TO_STAGE 就随机选了一格 ⇒ 应有一格是橙框）
##   02_选中3.png  点第 3 格之后（橙框应该跳到第 3 格）
##   03_悬停1.png  鼠标停在第 1 格上（未选中才会变亮 + 应浮出职业说明）
##   04_弹框.png   空名字点「进入游戏」⇒ 该弹"角色名不能为空"

const 场景路 := "res://场景/界面/窗口/创建角色/创建角色窗.tscn"
const 出目录 := "res://测试/截图/创角"
const 几何 := "res://测试/截图/创角/几何.txt"

var 行: Array[String] = []


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_跑()


func _写(文: String) -> void:
	var f := FileAccess.open(文, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()


func _拍(节: Node, 名: String) -> void:
	var 图 := root.get_texture().get_image()
	图.save_png(出目录 + "/" + 名 + ".png")


func _跑() -> void:
	root.size = Vector2i(960, 540)
	var 包 = load(场景路)
	if 包 == null:
		_写("场景打不开")
		quit(1); return
	var 窗: Node = 包.instantiate()
	root.add_child(窗)
	await _帧(20)
	# ⚠ `_ready` 里那句 随机选格() 让「常态」每跑一次选中的格子都不一样（本轮实测：01 与 02
	#    两张图**逐字节相同** —— 那次随机正好抽到格3，等于第二张没拍到任何东西）。证据图要能
	#    重跑必同、两两必须不同 ⇒ 先把选中格钉成格1（顺手把随机出来的悬停提示收掉）。
	窗.call("_选中", 窗.get_node("窗口/职业格1"))
	窗.call("_灭提示")
	await _帧(4)
	行.append("根节点=%s 类=%s 尺寸=%s" % [窗.name, 窗.get_class(), str(窗.size)])
	var 内: Node = 窗.get_node_or_null("窗口")
	行.append("窗口 相对根 = %s  尺寸 = %s" % [str(内.position), str(内.size)])
	for c in 内.get_children():
		行.append("  %-10s %-16s pos=%-16s size=%-14s %s" % [
			c.name, c.get_class(), str(c.position), str(c.size), _皮(c)])
	_拍(窗, "01_常态")

	# 点第 3 格
	var 格3: Control = 内.get_node("职业格3")
	var 心3 := 格3.global_position + 格3.size * 0.5
	_移到(心3)
	await _帧(3)
	_点(格3, 心3)
	await _帧(6)
	_拍(窗, "02_选中3")
	行.append("点格3 之后：格1 texture_normal=%s 格3 texture_normal=%s" % [
		_纹(内.get_node("职业格1")), _纹(格3)])

	# 悬停第 1 格（未选中才会变亮）
	var 格1: Control = 内.get_node("职业格1")
	var 心1 := 格1.global_position + 格1.size * 0.5
	_移到(心1)
	await _帧(6)
	_拍(窗, "03_悬停1")
	行.append("悬停格1：格1 texture_hover=%s 提示可见=%s" % [
		_纹(格1, true), str((_提示(窗)) != null and _提示(窗).visible)])

	# 空名字点进入游戏 ⇒ 弹框
	var 输入: LineEdit = 内.get_node("角色名输入")
	输入.text = ""
	var 进: Control = 内.get_node("进入游戏")
	_点(进, 进.global_position + 进.size * 0.5)
	await _帧(10)
	_拍(窗, "04_弹框")
	行.append("空名点进入游戏：弹框在不在=%s" % str(_有弹框(窗)))
	_写(几何)
	quit(0)


func _提示(窗: Node) -> Node:
	for c in 窗.get_parent().get_children():
		if String(c.name) == "创角悬停提示":
			return c
	return null


func _有弹框(窗: Node) -> bool:
	for c in 窗.get_parent().get_children():
		if String(c.name) == "创角弹框":
			return true
	return false


func _纹(钮: Node, 悬停 := false) -> String:
	var 路: String = ""
	if 悬停:
		路 = String((钮 as TextureButton).texture_hover.resource_path)
	else:
		路 = String((钮 as TextureButton).texture_normal.resource_path)
	return 路.get_file()


func _皮(节: Node) -> String:
	if 节 is TextureButton:
		return "normal=" + _纹(节)
	if 节 is TextureRect:
		var t = (节 as TextureRect).texture
		return "图=" + (String(t.resource_path).get_file() if t != null else "-")
	return ""


func _移到(位: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = 位
	m.global_position = 位
	root.push_input(m)


func _点(节: Control, 位: Vector2) -> void:
	_移到(位)
	var p := InputEventMouseButton.new()
	p.button_index = MOUSE_BUTTON_LEFT
	p.pressed = true
	p.position = 位
	p.global_position = 位
	root.push_input(p)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = 位
	u.global_position = 位
	root.push_input(u)
