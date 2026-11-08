extends SceneTree
## 有头量具：把目标信息条**真的画到屏幕上**拍下来，出三张证据图
## ① 常态整条 ② 悬停那一颗钮（+30 那档）③ 菜单弹窗打开。
## 必须**不带 `--headless`** 跑（无头拿不到视口图像）。
##
## 跑法：`"godot" --path . --script res://开发工具/截目标信息条页.gd`

const 出目录 := "res://测试/截图/目标信息条"
const 条宽 := 232
const 条高 := 62
const 抬 := 4.0		## 头像区域那块整体往上偏 4，条用 offset_top=4 才落在屏幕 y=0

var 通过 := 0
var 失败 := 0


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	quit(1 if 失败 > 0 else 0)


func _跑() -> void:
	print("目标信息条有头量具开始")
	## 裸 `extends SceneTree` 跑起来的窗口是 **100×100**（不吃工程设置那 960×560），
	## 视口图也只有 100×100 ⇒ 条会被屏缘切掉、弹窗钳制框也不对。先自己把窗口撑开。
	root.size = Vector2i(960, 560)
	for i in 4:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	var 屏 := root.get_visible_rect().size
	print("视口 %dx%d" % [int(屏.x), int(屏.y)])
	var 件 := (load("res://场景/界面/头像面板.tscn") as PackedScene).instantiate()
	root.add_child(件)
	for i in 6:
		await process_frame
	var 会话 := root.get_node("GameSession")
	会话.call("select_map_character", {
			"name": "夕日光", "level_text": "LV.7", "hp": 650, "max_hp": 650,
			"mp": 130, "max_mp": 260, "type": 1, "char_id": 1002, "level": 7})
	for i in 60:
		await process_frame		# 蓝条那 0.5 秒补间要走完
	var 条 := 件.get_node("头像区域/选中人物信息") as Control
	_判(条.visible, "条显示出来了")
	var 位 := 条.get_global_rect()
	_判(absf(位.position.y) <= 1.0, "条贴在屏幕最上沿（实得 y=%.1f）" % 位.position.y)
	_判(absf(位.size.x - 条宽) <= 1.0 and absf(位.size.y - 条高) <= 1.0,
			"条 = %d×%d（实得 %.0f×%.0f）" % [条宽, 条高, 位.size.x, 位.size.y])
	await _拍(条, "整条")

	## 悬停那颗「加好友」：分两帧两跳（同一帧两条 MouseMotion 视口只按最后一条做拾取）
	var 钮 := 条.get_node("钮_加好友") as TextureButton
	var 钮心 := 钮.get_global_rect().get_center()
	var 起 := 钮心 + Vector2(0, 120)
	await _动(起)
	await _动(钮心)
	for i in 4:
		await process_frame
	_判(root.gui_get_hovered_control() == 钮,
			"鼠标真的落在「加好友」上（实得 %s）" % str(root.gui_get_hovered_control()))
	_判(String(钮.texture_normal.resource_path).ends_with("钮_加好友_悬停.png"),
			"悬停那一档换的是 +30 那张派生皮（实得 %s）" % 钮.texture_normal.resource_path)
	await _拍(条, "悬停加好友")
	var 常态皮 := 钮.texture_normal
	await _动(钮心 + Vector2(0, 120))
	for i in 4:
		await process_frame
	_判(钮.texture_normal != 常态皮 and String(钮.texture_normal.resource_path).ends_with("钮_加好友.png"),
			"移出后回到常态皮（实得 %s）" % 钮.texture_normal.resource_path)

	## 菜单弹窗
	var 会话2 := 会话
	会话2.call("select_map_character", {
			"name": "夕日光", "level_text": "LV.7", "hp": 650, "max_hp": 650,
			"mp": 130, "max_mp": 260, "type": 1, "char_id": 1002, "level": 7})
	(条.get_node("钮_菜单") as BaseButton).emit_signal("pressed")
	for i in 4:
		await process_frame
	var 菜单 := 条.get_node("目标菜单") as Control
	_判(菜单.visible, "点「菜单」弹窗开出来了")
	_判(absf(菜单.position.x - 141.0) < 0.6 and absf(菜单.position.y - 60.0) < 0.6,
			"弹窗挂在 (141,60) = 菜单钮正下方（实得 %s）" % 菜单.position)
	var 全 := root.get_texture().get_image()
	全.save_png(ProjectSettings.globalize_path(出目录) + "/弹窗.png")
	print("目标信息条有头量具：通过 %d，红 %d" % [通过, 失败])


func _动(位: Vector2) -> void:
	var 事 := InputEventMouseMotion.new()
	事.position = 位
	事.global_position = 位
	root.push_input(事, true)
	await process_frame


## 拍整屏 + 按条的矩形裁一份，再放大 6 倍（NEAREST）便于肉眼核像素。
func _拍(条: Control, 名: String) -> void:
	var 图 := root.get_texture().get_image()
	图.save_png(ProjectSettings.globalize_path(出目录) + "/屏幕_" + 名 + ".png")
	var 位 := 条.get_global_rect()
	var 左 := int(maxi(0, 位.position.x))
	var 上 := int(maxi(0, 位.position.y))
	var 宽 := mini(int(位.size.x), 图.get_width() - 左)
	var 高 := mini(int(位.size.y) + 60, 图.get_height() - 上)
	var 裁 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
	for y in 高:
		for x in 宽:
			裁.set_pixel(x, y, 图.get_pixel(左 + x, 上 + y))
	裁.save_png(ProjectSettings.globalize_path(出目录) + "/裁_" + 名 + ".png")
	裁.resize(宽 * 6, 高 * 6, Image.INTERPOLATE_NEAREST)
	裁.save_png(ProjectSettings.globalize_path(出目录) + "/六倍_" + 名 + ".png")
	print("拍了 %s：矩形 (%d,%d,%d,%d)" % [名, 左, 上, 宽, 高])
