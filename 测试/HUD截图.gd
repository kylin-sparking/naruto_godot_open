extends SceneTree

var _frames := 0


func _initialize() -> void:
	var scene := load("res://场景/地图/地图场景.tscn") as PackedScene
	if scene == null:
		push_error("地图场景.tscn 加载失败")
		quit(1)
		return
	get_root().add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 20:
		return false
	var viewport_texture := get_root().get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动不支持视口截图")
		return true
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动未返回视口图像")
		return true
	var error := image.save_png("res://测试/截图_HUD.png")
	print("HUD 截图保存结果=", error, " 尺寸=", image.get_size())
	return true
