extends SceneTree

## #184 的**有头**量具：把底栏精华容器在「展开 / 收起」两态各截一张屏，自己用眼睛对一遍。
## ⚠ 不能加 `--headless`（无头拿不到视口图像）。
## 跑法：godot --path . --script res://开发工具/截精华两态.gd

const 出 := "res://测试/截图/精华容器/"
const 面板场景 := "res://场景/界面/技能面板.tscn"
const 上限 := 500000

var 日志: Array[String] = []
var 判 := 0
var 红 := 0
var 收 := false


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1
	_写()


func _步(说: String) -> void:
	日志.append("· " + 说)


func _写() -> void:
	var f := FileAccess.open(出 + "两态.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _看门狗() -> void:
	var 截止 := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < 截止:
		if 收:
			return
		await create_timer(0.2).timeout
	if 收:
		return
	_判(false, "看门狗：90 秒没收尾")
	_尾()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(出)
	call_deferred("_跑")
	call_deferred("_看门狗")


func _截(名: String) -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null:
		_步("拿不到视口图（是不是加了 --headless？）")
		return
	图.save_png(出 + 名 + ".png")
	_步("存了 " + 名 + "（视口 %d×%d）" % [图.get_width(), 图.get_height()])


func _跑() -> void:
	root.size = Vector2i(960, 560)
	await _帧(2)
	var 会: Node = root.get_node_or_null("GameSession")
	_判(会 != null, "拿得到 GameSession")
	if 会 == null:
		_尾()
		return
	会.player_stats["zq"] = int(上限 * 0.5)
	var 景: Node = (load(面板场景) as PackedScene).instantiate()
	root.add_child(景)
	await _帧(12)
	var 栏 := 景.get_node_or_null("技能栏") as Control
	var 箭头 := 栏.get_node_or_null("ChakraCoreArrow") as TextureButton if 栏 != null else null
	var 收起 := 栏.get_node_or_null("精华收起") as Control if 栏 != null else null
	_判(箭头 != null and 收起 != null, "两态的节点都拿得到")
	# 底下垫一层纯色，免得透明处看不出裁图
	await _帧(6)
	_截("实机_展开")
	_判(收起 != null and not 收起.visible, "截第一张时确实是展开态")
	var 位 := 箭头.get_global_rect().get_center()
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.position = 位
	按.global_position = 位
	按.pressed = true
	root.push_input(按)
	await _帧(2)
	按.pressed = false
	root.push_input(按)
	await _帧(10)
	_截("实机_收起")
	_判(收起 != null and 收起.visible and not 箭头.get_parent().get_node("BreathContainer").visible,
			"截第二张时已经翻成收起态（球那一层让位给细条）")
	_尾()


func _尾() -> void:
	if 收:
		return
	收 = true
	_写()
	for 行 in 日志:
		print(行)
	print("精华两态量具：判 %d 条 / 红 %d 条" % [判, 红])
	quit(0 if 红 == 0 else 1)
