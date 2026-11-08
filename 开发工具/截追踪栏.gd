extends SceneTree

## 有头取证：主界面右侧「任务追踪栏」当前长什么样（离线默认已接 1003）。
## 只截图，不做判据。

const 出目录 := "res://测试/截图/追踪栏1025"

func _initialize() -> void:
	_跑()

func _跑() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	root.size = Vector2i(960, 560)
	await process_frame
	var 图 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	for i in 30:
		await process_frame
	var 整 := root.get_texture().get_image()
	整.save_png(ProjectSettings.globalize_path(出目录.path_join("整屏.png")))
	# 右侧 300 宽、上半屏；另存 3 倍
	var 裁 := 整.get_region(Rect2i(660, 0, 300, 300))
	裁.save_png(ProjectSettings.globalize_path(出目录.path_join("右侧.png")))
	裁.resize(300 * 3, 300 * 3, Image.INTERPOLATE_NEAREST)
	裁.save_png(ProjectSettings.globalize_path(出目录.path_join("右侧3x.png")))
	print("追踪栏截图 →", ProjectSettings.globalize_path(出目录))
	quit(0)
