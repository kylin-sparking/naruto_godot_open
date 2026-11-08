extends SceneTree
# 家族子窗运行期截图器（有头跑）：把 15 个 SPEC 生成的子窗逐个铺在客户端真实底片上截图，
# 出 `测试/截图/家族子窗/<窗名>_运行期.png`，并校两件事：
#   ① `装配()` 全程不报错；② 每颗 TextureButton 运行期都有皮（丢皮 = 白框）。
# 用法（不能加 --headless）：Godot --path . --script res://开发工具/截家族子窗.gd

const 目录 := "res://场景/界面/窗口/家族/"
const 期望目录 := "res://数据/界面/"
const 出图 := "res://测试/截图/家族子窗/"
const 底片 := "res://测试/截图/A3_木叶村_整机位.png"
const 留帧 := 9

var _帧 := 0
var _表: Array = []
var _序 := 0					# 正在处理的窗（0..n-1）
var _根: Control
var _背: TextureRect
var _红 := 0


func _initialize() -> void:
	var 名单 := Array(DirAccess.get_files_at(期望目录))
	名单.sort()
	for 名 in 名单:
		var 文件 := String(名)
		if 文件.begins_with("家族子窗_") and 文件.ends_with(".json"):
			var f := FileAccess.open(期望目录.path_join(文件), FileAccess.READ)
			var 期: Dictionary = JSON.parse_string(f.get_as_text())
			f.close()
			_表.append([文件.trim_prefix("家族子窗_").trim_suffix(".json"), 期])
	DirAccess.make_dir_recursive_absolute(出图)
	root.size = Vector2i(680, 520)


func _process(_d: float) -> bool:
	_帧 += 1
	var 上帧 := _帧 - 留帧 * (_序 + 1)
	if 上帧 == 0:						# 该窗的第一帧：建场景、铺底片、装配
		_建()
		return false
	if 上帧 == 留帧 - 1:				# 该窗的最后一帧：截图、放掉
		var 图 := root.get_texture().get_image()
		图.save_png(出图.path_join(_表[_序][0] + "_运行期.png"))
		var 空 := 0
		for 子 in _根.get_children():
			if 子 is TextureButton and (子 as TextureButton).texture_normal == null:
				空 += 1
		print("   %-14s %s" % [_表[_序][0], "✓" if 空 == 0 else "%d 颗钮没皮" % 空])
		_红 += 空
		_根.free()
		_背.free()
		_序 += 1
	if _序 >= _表.size():
		print("家族子窗截图：%d 窗，红 %d" % [_表.size(), _红])
		quit(1 if _红 > 0 else 0)
		return true
	return false


func _建() -> void:
	var 窗名: String = _表[_序][0]
	var 期: Dictionary = _表[_序][1]
	var 尺: Array = 期["内容"]
	root.size = Vector2i(int(尺[0]) + 24, int(尺[1]) + 24)
	_背 = TextureRect.new()			# 底片垫在最下：像素参照要的是压在客户端同一张底图上
	if ResourceLoader.exists(底片):
		_背.texture = load(底片) as Texture2D
		_背.expand_mode = 1
		_背.stretch_mode = 0
	root.add_child(_背)
	_根 = (load(目录.path_join(窗名 + ".tscn")) as PackedScene).instantiate() as Control
	_根.position = Vector2(12.0, 12.0)
	root.add_child(_根)
	_根.call("装配", load("res://测试/假家族宿主.gd").new())
