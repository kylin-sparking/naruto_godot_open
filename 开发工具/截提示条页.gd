extends SceneTree
## 提示条（原版 `MessageTipPane2` 任务两档）的**有头量具**：把条摆到真视口上拍三张 + 回读几何。
##
## 为什么必须**有头**：无头拿不到视口图像（工程里反复踩过）。
## 跑法：Godot --path . --script res://开发工具/截提示条页.gd
##
## 三张图各看一件事：
##   01_交付档.png   勾了「关闭自动提交任务」之后交付 ⇒ 条留在屏上、标题黄字、钮居中
##   02_长名变宽.png 任务名 12 字（《亲热天堂》送大礼（二））⇒ 底板跟着标题变宽、
##                   **左上角那朵云纹不许被拉长**（九宫格没生效一眼就能看出来）
##   03_环任务档.png 环任务即使没勾开关也**不自动点**（`isAutoQuestFun:392` 那条例外）
##
## ⚠ 本量具只建控件、不登录、不点设置 ⇒ 不碰 user://。

const 层脚本 := "res://脚本/界面/提示条面板.gd"
const 提示条 := preload("res://脚本/界面/提示条面板.gd")
const 出目录 := "res://测试/截图/提示条"
const 几何表 := "res://测试/截图/提示条/几何.txt"
const 小地图高 := 180.0

var 行: Array[String] = []


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_跑()


func _写() -> void:
	var f := FileAccess.open(几何表, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()


func _拍(名: String) -> void:
	root.get_texture().get_image().save_png(出目录 + "/" + 名 + ".png")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var S = load(层脚本)
	if S == null:
		行.append("!! 加载不到 " + 层脚本)
		_写()
		quit(1)
		return
	var 布 := CanvasLayer.new()
	布.layer = 5
	root.add_child(布)
	var 底 := ColorRect.new()
	底.color = Color(0.11, 0.10, 0.09, 1)
	底.size = Vector2(960, 560)
	布.add_child(底)
	var 层: Control = S.new()
	布.add_child(层)
	层.报小地图高(小地图高)
	await _帧(3)

	# ① 交付档（勾了开关那一支 ⇒ 看得见、等玩家点）
	层.显示(提示条.档交付, 1003, "初醒", false, false)
	await _帧(4)
	_拍("01_交付档")
	_量(层, "01 交付档")

	# ② 长名字 ⇒ 变宽，云纹不许拉长
	层.清空()
	await _帧(2)
	层.显示(提示条.档交付, 5047, "《亲热天堂》送大礼（二）", false, false)
	await _帧(4)
	_拍("02_长名变宽")
	_量(层, "02 长名变宽")

	# ③ 环任务 + 没勾开关 ⇒ 仍然显示（自动点那一支被 isLoopQuest 挡掉）
	层.清空()
	await _帧(2)
	层.显示(提示条.档接取, 8001, "每日修行", true, true)
	await _帧(4)
	_拍("03_环任务档")
	_量(层, "03 环任务档")
	_写()
	print("\n".join(行))
	quit(0)


func _量(层: Control, 说: String) -> void:
	var 存: Array = 层.get("_条")
	if 存.is_empty():
		行.append("!! %s：屏上没有条（该显示的那一档没出来）" % 说)
		return
	var d: Dictionary = 存[0]
	var 条: Control = d["节点"]
	var 题 := 条.get_node("标题") as Label
	var 钮 := 条.get_node("确定") as Button
	var 底 := 条.get_node("底板") as Panel
	var 关 := 条.get_node("关闭") as TextureButton
	var 皮 := 底.get_theme_stylebox("panel") as StyleBoxTexture
	行.append("%s｜条 %s @%s visible=%s" % [说, str(条.size), str(条.position), str(条.visible)])
	行.append("    标题「%s」%s 色%s" % [题.text, str(题.position), str(题.get_theme_color("font_color"))])
	行.append("    确定「%s」%s %s 手型=%s" % [钮.text, str(钮.position), str(钮.size),
			str(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)])
	行.append("    关闭 %s 皮=%s" % [str(关.position), String(关.texture_normal.resource_path)])
	行.append("    底板皮=%s 边距[%s, %s, %s, %s] 内缩[%s, %s, %s, %s]" % [
		String(皮.texture.resource_path).get_file(),
		str(皮.texture_margin_left), str(皮.texture_margin_right),
		str(皮.texture_margin_top), str(皮.texture_margin_bottom),
		str(皮.content_margin_left), str(皮.content_margin_right),
		str(皮.content_margin_top), str(皮.content_margin_bottom)])
