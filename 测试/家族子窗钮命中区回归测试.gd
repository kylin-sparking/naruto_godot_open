extends SceneTree
## 家族子窗「钮的命中区」回归门（离线）。
##
## 抓的是什么：**按钮的点击矩形装不下它的字**。
## 生成器（`开发工具/生成家族子窗.py`）给每颗钮烘的是**写死的宽度**，而 `Label` 是撑满按钮的；
## 标签一长，文字就画到按钮矩形之外 —— 玩家点的是凸出去的那截字，而命中判定只在矩形里，
## 表现是"看得见、点不动"。
##
## 实例：家族旗帜窗底部三颗钮原来写死 57×22，而「安插本族旗帜」「修复族旗血量」各 6 个字
## （12px 宋体 ≈72px）⇒ 用户 2026-10-09 报的"说明资讯/安插本族旗帜/修复族旗血量 都无法点击"。
##
## ⚠️ 为什么必须单独立一条门：所有用例和探针走的是 `钮.pressed.emit()`，
## **绕过了命中测试** ⇒ 这种几何 bug 一律照不出来，只有几何断言能抓。
##
## 用法：Godot --headless --path . --script res://测试/家族子窗钮命中区回归测试.gd

## 默认只扫家族子窗（用户报的那批）。`-- <目录>` 可以改扫别的目录做排查，
## 例如 `-- res://场景/界面/窗口/` 扫全工程界面（那时 FAIL 数量只当线索看，不一定都是 bug）。
const 默认目录 := "res://场景/界面/窗口/家族/"
## 家族旗帜窗底部三颗钮的宽度是**运行时**由 `家族旗帜填充._摆底部钮` 撑开的
## （场景里那三颗的写死宽度本来就不对），所以量之前要先跑一遍那个布局 ——
## 这样门验的是"玩家实际会看到的那一版"，而不是场景的原始值。
const 运行时布局 := {"家族旗帜窗": "res://脚本/界面/窗口/家族/家族旗帜填充.gd"}
const 主题 := "res://素材/界面/原版主题.tres"

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	# 子窗场景**不带主题**（继承自上层），所以量文字前必须给树挂上原版主题，
	# 否则 `get_theme_font` 拿到的是 Godot 默认字体、量出来的宽度全不对。
	var 主题资源 := load(主题) as Theme
	if 主题资源 == null:
		print("家族子窗钮命中区回归测试：FAIL 1 条")
		print("  !! 取不到主题 %s" % 主题)
		quit(1)
		return
	root.theme = 主题资源

	var 参 := OS.get_cmdline_user_args()
	var 场景目录: String = String(参[0]) if 参.size() > 0 else 默认目录
	print("扫的目录 = %s" % 场景目录)
	var 文件们 := DirAccess.get_files_at(场景目录)
	var 扫过 := 0
	for 文件 in 文件们:
		var 名 := String(文件)
		if not 名.ends_with(".tscn") or 名.contains(".bak"):
			continue
		var 路 := 场景目录 + 名
		var 包 := load(路) as PackedScene
		if 包 == null:
			continue
		扫过 += 1
		var 场 := 包.instantiate() as Control
		root.add_child(场)
		await process_frame
		await process_frame
		var 短名 := 名.trim_suffix(".tscn")
		if 运行时布局.has(短名):
			(load(String(运行时布局[短名])) as GDScript).call("_摆底部钮", 场)
			await process_frame
		_查窗(短名, 场)
		场.queue_free()
		await process_frame
	print("扫过 %d 个家族子窗场景" % 扫过)
	if _失败.is_empty():
		print("家族子窗钮命中区回归测试：通过（每颗带字的钮，点击矩形都装得下它的字）")
		quit(0)
		return
	for 条 in _失败:
		print("  !! " + 条)
	print("家族子窗钮命中区回归测试：FAIL %d 条" % _失败.size())
	quit(1)


func _查窗(窗名: String, 场: Node) -> void:
	for 钮 in _找钮(场):
		var 字 := 钮.get_node_or_null("Label") as Label
		if 字 == null or String(字.text).is_empty():
			continue
		var 字体 := 字.get_theme_font("font")
		var 字号 := 字.get_theme_font_size("font_size")
		var 文字宽 := 字体.get_string_size(String(字.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
		# 留 1px 容差（量字与实际排版会有半像素差）
		if 钮.size.x + 1.0 < 文字宽:
			_失败.append("%s / %s：「%s」要 %.0fpx，钮只有 %.0fpx ⇒ 文字凸出按钮外，点它是点不中的"
				% [窗名, 钮.name, 字.text, 文字宽, 钮.size.x])


func _找钮(节点: Node) -> Array[TextureButton]:
	var 出: Array[TextureButton] = []
	for 子 in 节点.get_children():
		if 子 is TextureButton:
			出.append(子 as TextureButton)
		出.append_array(_找钮(子))
	return 出
