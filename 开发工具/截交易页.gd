extends SceneTree
## 交易窗 + 两枚金额子窗的有头实拍量具（用户 10-16 报的四处走样都要在这几张图上看得见）。
##
## 用法（**不能加 --headless**，无头拿不到视口图像）：
##   "godot" --path . --script res://开发工具/截交易页.gd -- --出目录=res://测试/截图/交易页
##
## 口径：下行帧一律喂**真后端解析入口** `_handle_bridge_text`（不手造状态），
## 金额子窗靠**真鼠标点**「输入金币/输入元宝」开出来（不许用 `emit()` 演一遍）。

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 夹具路径 := "res://数据/界面/交易夹具.json"
const 后端脚本 := preload("res://脚本/单例/后端连接.gd")
const 品质表 := preload("res://脚本/单例/装备品质.gd")
## ⚠ `GAME_DATA` 是 `后端连接.gd` 里的 **const** ⇒ 实例 `get("GAME_DATA")` 拿到 null
## （常量不在属性表里，这一条在交易门上已经踩过一次）⇒ 要用就直接 preload 那份脚本。
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

var _出 := "res://测试/截图/交易页"
var _帧 := 0
var _步 := 0
var _管理: Node = null
var _夹: Dictionary = {}


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			_出 = 键值[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_出))
	var 文 := FileAccess.get_file_as_string(夹具路径)
	_夹 = JSON.parse_string(文.replace("\ufeff", "")) as Dictionary
	if _夹 == null:
		push_error("夹具读不到：" + 夹具路径)
		quit(1)
		return
	root.size = Vector2i(960, 560)
	var 后 = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("authoritative_trade", 后端脚本._空交易状态())
	_管理 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(_管理)


func _喂(原文: String) -> void:
	root.get_node("BackendConnection").call("_handle_bridge_text", 原文)


func _窗():
	return _管理.call("取窗口", "交易")


func _页():
	var 窗 = _窗()
	if 窗 == null:
		return null
	var 内容 = 窗.get("_content")
	if 内容 == null:
		return null
	for 子 in (内容 as Control).get_children():
		if String(子.name) == "原版交易内容":
			return 子
	return null


func _存(名: String, 图: Image) -> void:
	var 路 := _出 + "/" + 名 + ".png"
	图.save_png(路)
	print("存 ", 路, " ", 图.get_width(), "x", 图.get_height())


func _裁(名: String, 框: Rect2, 放大 := 3) -> void:
	var 全 := root.get_texture().get_image()
	var x := clampi(int(floorf(框.position.x)), 0, 全.get_width() - 1)
	var y := clampi(int(floorf(框.position.y)), 0, 全.get_height() - 1)
	var w := mini(int(ceilf(框.size.x)), 全.get_width() - x)
	var h := mini(int(ceilf(框.size.y)), 全.get_height() - y)
	var 片 := 全.get_region(Rect2i(x, y, w, h))
	_存(name_带(名, ""), 片)
	if 放大 > 1:
		var 大 := 片.duplicate()
		大.resize(w * 放大, h * 放大, Image.INTERPOLATE_NEAREST)
		_存(name_带(名, "_%dx" % 放大), 大)


func name_带(名: String, 尾: String) -> String:
	return 名 + 尾


func _点(件: Control) -> void:
	var 屏: Vector2 =件.get_global_rect().position + 件.size * 0.5
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	root.push_input(移)
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	root.push_input(按)
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	root.push_input(放)
	await process_frame
	await process_frame


func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 < 10:
		return false
	match _步:
		0:
			var 原: Dictionary = _夹["原文"] as Dictionary
			for 键 in ["开始", "我方放物", "对方放物", "我方金币", "对方金币", "我方元宝", "对方元宝"]:
				_喂(String(原[键]))
			_步 = 1
		1:
			if _页() == null:
				print("交易页没开出来")
				quit(1)
				return true
			var 紫 := _挑紫装()
			(_页().get_node("我的格1") as Control).call("填", 紫)
			print("塞进我的格1 的夹具件：", 紫)
			_步 = 2
		2:
			var 页 = _页()
			_存("整屏", root.get_texture().get_image())
			var 框: Rect2 = (页 as Control).get_global_rect()
			print("页全局矩形：", 框)
			_裁("交易窗", 框, 2)
			_裁("币行", Rect2(框.position + Vector2(0, 316), Vector2(框.size.x, 68)), 5)
			_裁("分隔线区", Rect2(框.position + Vector2(0, 40), Vector2(框.size.x + 130, 240)), 2)
			_裁("格1", Rect2(框.position + Vector2(163, 50), Vector2(150, 48)), 8)
			_步 = 3
		3:
			_步 = 4
			_弹()
		_:
			return false
	return false


## ⚠ `_process` 里**不能 await** —— 一 await 就返回 null，下一步会被反复重入。
## 弹窗这一段单独一条协程，靠 `_步` 挡住主循环。
func _弹() -> void:
	var 页 = _页()
	await _点(页.get_node("输入金币钮") as Control)
	_裁("金币弹窗", (页.get_node("交易金额窗") as Control).get_global_rect(), 4)
	print("第一枪后标题：", (页.get_node("交易金额窗/标题") as Label).text)
	var 宝钮 := 页.get_node("输入元宝钮") as Control
	print("输入元宝钮 屏幕矩形：", 宝钮.get_global_rect())
	await _点(宝钮)
	print("第二枪后标题：", (页.get_node("交易金额窗/标题") as Label).text)
	_裁("元宝弹窗", (页.get_node("交易金额窗") as Control).get_global_rect(), 4)
	print("截交易页：完")
	quit(0)


## 挑一件带资质流光的夹具件（只喂不点 ⇒ 不落存档）。资质档按 `数据/装备品质.json` 里有流光的那档给。
func _挑紫装() -> Dictionary:
	var 档号 := 4
	for 键 in (品质表.表().get("品质", {}) as Dictionary):
		var 条 := (品质表.表()["品质"] as Dictionary)[键] as Dictionary
		if bool(条.get("有流光", false)):
			档号 = int(条.get("号", 键))
			break
	var 后 = root.get_node("BackendConnection")
	var 包: Array = 后.get("authoritative_inventory") as Array
	print("背包镜像件数：", 包.size())
	for 件 in 包:
		var 条 := 件 as Dictionary
		var 图 := String(条.get("icon", ""))
		if not 图.is_empty() and ResourceLoader.exists(图):
			var 挑 := 条.duplicate(true)
			挑["aptitude"] = 档号
			挑["quantity"] = 3
			return 挑
	## 无头/离线时后端镜像是空的，背包画的是**会话**那份 ⇒ 两处都要找，别只查一处就下结论。
	var 会 = root.get_node_or_null("GameSession")
	if 会 != null:
		var 会包: Array = 会.get("inventory") as Array
		print("会话背包件数：", 会包.size())
		for 件 in 会包:
			var 条 := 件 as Dictionary
			var 图 := String(条.get("icon", ""))
			if not 图.is_empty() and ResourceLoader.exists(图):
				var 挑 := 条.duplicate(true)
				挑["aptitude"] = 档号
				挑["quantity"] = 3
				return 挑
	return {"id": "20000001", "name": "紫装夹具", "quantity": 3, "aptitude": 档号,
			"icon": String(游戏数据.item_icon_path("20000001"))}
