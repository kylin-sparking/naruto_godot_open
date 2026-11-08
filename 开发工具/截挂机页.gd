extends SceneTree
## 截「挂机设置」整窗（有头跑，`--headless` 拿不到视口图像）。
## 用法：Godot --path . --script res://开发工具/截挂机页.gd
## 产物：res://测试/截图/挂机页.png（960×560 整屏，含窗壳与背景）。

func _initialize() -> void:
	call_deferred("_跑")


func _等帧(n: int) -> void:
	for _i in maxi(1, n):
		await process_frame


func _跑() -> void:
	root.size = Vector2i(960, 560)
	await _等帧(2)
	var 路径 := "res://场景/生成/地图_101010000_烘焙.tscn"
	var 包 := load(路径) as PackedScene
	if 包 == null:
		print("加载失败：", 路径)
		quit(1)
		return
	var 图 := 包.instantiate()
	root.add_child(图)
	current_scene = 图
	await _等帧(10)
	var 管 = 图.get_node_or_null("窗口管理")
	if 管 == null:
		print("场景里没有 窗口管理")
		quit(1)
		return
	管.call("打开", "挂机")
	await _等帧(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://测试/截图"))
	var 图2 := root.get_texture().get_image()
	图2.save_png("res://测试/截图/挂机页.png")
	print("已存 res://测试/截图/挂机页.png 尺寸=", 图2.get_size())
	## 页面根在屏幕上的位置 = 裁图配准用的原点（AS3 窗口坐标 (x,y) → 屏幕 (148+x, 34+y)）。
	## 逐件解算几何另有无头量具 开发工具/量挂机下拉.gd，别在有头探针里判。
	var 窗: Node = 管.call("取或建窗口", "挂机")
	if 窗 != null:
		var 内: Node = 窗.find_child("原版挂机设置内容", true, false)
		if 内 != null:
			print("页面根全局位=", (内 as Control).get_global_position())
	quit(0)
