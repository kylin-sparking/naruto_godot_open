extends SceneTree

## 有头证据：任务窗口当前长什么样（524×396，居中摆）。
## 只用于取证，不做判据；出 整屏 + 窗口裁图 + 4 倍放大。

const 出目录 := "res://测试/截图/任务窗1025"

func _initialize() -> void:
	_跑()

func _跑() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	root.size = Vector2i(960, 560)
	await process_frame
	var 背 := ColorRect.new()
	背.color = Color(0.20, 0.30, 0.20)
	背.size = Vector2(960, 560)
	root.add_child(背)
	var 窗 := (load("res://场景/界面/窗口/任务/任务窗口.tscn") as PackedScene).instantiate() as Control
	窗.position = Vector2(218, 82)
	root.add_child(窗)
	await process_frame
	await process_frame
	窗.call("刷新")
	await process_frame
	await process_frame
	var 图 := root.get_texture().get_image()
	图.save_png(ProjectSettings.globalize_path(出目录.path_join("整屏.png")))
	var 裁 := 图.get_region(Rect2i(218, 82, 524, 396))
	裁.save_png(ProjectSettings.globalize_path(出目录.path_join("任务窗.png")))
	裁.resize(524 * 2, 396 * 2, Image.INTERPOLATE_NEAREST)
	裁.save_png(ProjectSettings.globalize_path(出目录.path_join("任务窗2x.png")))
	## 空态（原版 drawTreeNow 那条居中蓝字）单拍一张：列表为空时才有，正常样本拍不到。
	窗.call("_刷新空提示", true)
	await process_frame
	var 空图 := root.get_texture().get_image().get_region(Rect2i(218, 82, 524, 396))
	空图.resize(524 * 2, 396 * 2, Image.INTERPOLATE_NEAREST)
	空图.save_png(ProjectSettings.globalize_path(出目录.path_join("任务窗_空态2x.png")))
	print("任务窗截图 →", ProjectSettings.globalize_path(出目录))
	quit(0)
