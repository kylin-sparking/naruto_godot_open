extends SceneTree

## 有头量具（不是门禁）：把"打坐时角色身上那圈光环 + 周围四颗球"拍成两张实机图。
## 跑：Godot --path . --script res://开发工具/截打坐图.gd
## ⚠ 不能加 --headless —— 无头拿不到视口图像。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 出 := "res://测试/截图/打坐/"


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _拍(名: String) -> void:
	var 图 := root.get_texture().get_image()
	var 全 := Image.create(图.get_width(), 图.get_height(), false, Image.FORMAT_RGBA8)
	全.copy_from(图)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出))
	全.save_png(出 + 名)
	print("拍 → %s%s (%d x %d)" % [出, 名, 图.get_width(), 图.get_height()])


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	var 景: Node = (load(地图场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
	await _帧(40)
	var 们 := get_nodes_in_group("player")
	if 们.size() == 0:
		print("!!红 拿不到玩家"); quit(1); return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)
	await _帧(6)
	_拍("站姿_没有球.png")

	玩.call("toggle_practise")
	await _帧(8)
	print("is_practising=%s  光环=%s  四颗球visible=%s" % [
		玩.get("is_practising"),
		玩.get_node_or_null("打坐光环") != null,
		(景.get_node_or_null("技能面板/打坐四钮") as Control).visible if 景.get_node_or_null("技能面板/打坐四钮") != null else "<查无>"])
	_拍("打坐_光环与四颗球.png")

	# 再等 12 秒过那道坎，拍"起气"那一圈的第 1 帧（那一帧最大、往上冒）
	var 环 := 玩.get_node_or_null("打坐光环")
	if 环 != null:
		环.set("_剩毫秒", 1.0)
		await _帧(4)
		print("光环状态：", 环.call("状态"))
		_拍("打坐_光环第1帧.png")

	玩.call("toggle_practise")
	await _帧(8)
	_拍("起身_又没了.png")
	quit(0)
