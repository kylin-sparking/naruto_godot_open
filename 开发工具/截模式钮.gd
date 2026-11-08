extends SceneTree

## 有头证据：头像下那颗战斗模式钮（原版 `CharactorInfoPane._pvpBtn`）与它点开的四行菜单
## （原版 `PKModePane2`）。跑法（不能加 --headless，要视口图像）：
##   Godot --path . --script res://开发工具/截模式钮.gd
## 出图落在 测试/截图/战斗模式钮/：四档各一张、悬停一张、菜单一张、点行后一张。

const 地图场景 := "res://场景/地图/地图场景.tscn"
const 出目录 := "res://测试/截图/战斗模式钮"


func _initialize() -> void:
	call_deferred("_跑")


func _图() -> Image:
	return root.get_texture().get_image()


func _裁(区: Rect2, 名: String, 倍: int = 6) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	var 视 := Rect2(0, 0, _图().get_width(), _图().get_height())
	var 实 := 区.intersection(视)
	if 实.size.x < 1 or 实.size.y < 1:
		print("  跳过（裁到框外）", 名, " ", 区)
		return
	var 块: Image = _图().get_region(Rect2i(int(实.position.x), int(实.position.y),
			int(实.size.x), int(实.size.y)))
	块.resize(int(实.size.x) * 倍, int(实.size.y) * 倍, Image.INTERPOLATE_NEAREST)
	块.save_png(ProjectSettings.globalize_path(出目录 + "/" + 名))
	print("  saved ", 出目录 + "/" + 名, "  ", 块.get_width(), "x", 块.get_height())


func _移(心: Vector2) -> void:
	var 事 := InputEventMouseMotion.new()
	事.position = 心
	事.global_position = 心
	root.push_input(事)
	await process_frame
	await process_frame


func _点(件: Control) -> void:
	var 心 :=件.get_global_rect().get_center()
	await _移(心)
	for 按 in [true, false]:
		var 事 := InputEventMouseButton.new()
		事.button_index = MOUSE_BUTTON_LEFT
		事.pressed = 按
		事.position = 心
		事.global_position = 心
		root.push_input(事)
		await process_frame
	await _移(心 + Vector2(400, 200))


func _跑() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		print("缺 GameSession")
		quit(1)
		return
	root.size = Vector2(960, 560)
	var 场景 := (load(地图场景) as PackedScene).instantiate()
	root.add_child(场景)
	await create_timer(0.8).timeout
	var 钮 := 场景.get_node_or_null("头像面板/头像区域/角色状态/StatusToggle") as TextureButton
	if 钮 == null:
		print("找不到模式钮")
		quit(1)
		return
	for 档 in [1, 2, 3, 4]:
		会话.hud_state["pk_mode"] = 档
		会话.hud_state_changed.emit(会话.hud_state)
		await create_timer(0.12).timeout
		_裁(钮.get_global_rect().grow(3.0), "钮_%d.png" % 档)
	# 悬停档（真鼠标移上去 = MButton3 的 +30 派生皮）
	await _移(钮.get_global_rect().get_center())
	_裁(钮.get_global_rect().grow(3.0), "钮_悬停.png")
	# 点开四行菜单
	await _点(钮)
	await create_timer(0.15).timeout
	var 菜单 := 场景.get_node_or_null("头像面板/头像区域/角色状态/PK模式菜单") as Control
	if 菜单 == null:
		print("点了没出菜单")
		quit(1)
		return
	_裁(菜单.get_global_rect().grow(2.0), "菜单.png", 3)
	# 点「全体」那一行 ⇒ 菜单收、钮皮换成全体
	await _点(菜单.get_node("模式行4") as Control)
	await create_timer(0.15).timeout
	_裁(钮.get_global_rect().grow(3.0), "钮_点行后.png")
	_裁(场景.get_node("头像面板/头像区域/角色状态").get_global_rect().grow(2.0), "整块头像.png", 3)
	print("完成")
	quit(0)
