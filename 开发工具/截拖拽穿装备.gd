extends SceneTree

## 拖拽穿装备：**真机**截图（不是组件级体检，见 `拖放通路体检.gd`）。
##
## 打开背包窗 + 人物窗，用**合成鼠标事件**走 Godot 真实的拖放通路，把背包里那件武器
## 拖到人物面板的「武器」格上，中途与落下后各截一张：
##
##   拖拽途中.png —— 对**拖拽预览**：半透明、居中在光标下、**只有图标**（六层覆盖层不跟着走）
##   穿装备后.png —— 对**穿上之后**的装备格（图标 + 覆盖层 + 格子名隐藏）
##
## 用法（**不能加 --headless**：要真视口）：
##   Godot --path . --script res://开发工具/截拖拽穿装备.gd [-- --出目录=res://测试/截图/拖拽穿装备]
##
## ⚠️ 合成事件必须走 `Viewport.push_input`，`button_mask` 要带左键 ——
##    用 `Input.parse_input_event` 走不通（对照组一个都收不到），理由写在 `拖放通路体检.gd` 里。

## 离线示例背包里的武器（`脚本/单例/离线示例数据.gd` 的 inventory 第一条）。
## `装备部位.位置("01010011")` 的前四位是 101 → 武器槽（-1）。
const 武器id := "01010011"
const 武器格节点名 := "武器"

var _出目录 := "res://测试/截图/拖拽穿装备"
var _场景: Node = null
var _人物窗: Node = null
var _背包窗: Node = null
var _截图数 := 0


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			_出目录 = 键值[1]
	_跑()


func _跑() -> void:
	var 场景脚本 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场景脚本 == null:
		push_error("无法加载地图场景")
		quit(1)
		return
	_场景 = 场景脚本.instantiate()
	root.add_child(_场景)
	# 场景树激活、autoload 就位都要等几帧（同 `截窗口页.gd` 的那条注意）
	for _序号 in 10:
		await process_frame

	if not DirAccess.dir_exists_absolute(_出目录):
		DirAccess.make_dir_recursive_absolute(_出目录)

	var 窗口管理 := _场景.get_node_or_null("窗口管理")
	if 窗口管理 == null:
		push_error("地图场景里没有 窗口管理")
		quit(1)
		return
	# 先开人物窗、再开背包窗 —— 窗口按已开数量错开，后开的在下层右侧，
	# 两者不叠在一起才拖得成（原版也是两个独立窗口并排）。
	窗口管理.call("打开", "人物")
	窗口管理.call("打开", "背包")
	_人物窗 = 窗口管理.call("取窗口", "人物")
	_背包窗 = 窗口管理.call("取窗口", "背包")
	for _序号 in 4:
		await process_frame

	var 源格 := _找背包里的武器格()
	var 目标格 := _找武器槽()
	if 源格 == null or 目标格 == null:
		push_error("找不到源格或目标格（源=%s 目标=%s）" % [源格, 目标格])
		quit(1)
		return
	await _报提示框("刚开窗")
	var 源心 := _中心(源格)
	var 目标心 := _中心(目标格)
	print("截拖拽穿装备：源格 %s 中心=%s ；武器槽 %s 中心=%s" % [源格.name, 源心, 目标格.name, 目标心])

	_发按下(源心)
	await process_frame
	for 序号 in range(1, 13):
		_发移动(源心.lerp(目标心, 序号 / 12.0))
		await process_frame
	# 停在目标格正中偏上一点，让预览与格子同框
	_发移动(目标心)
	await process_frame
	await _报提示框("拖动中")
	await _抓图("拖拽途中")

	_发松开(目标心)
	for _序号 in 6:
		await process_frame
	await _报提示框("松手后")
	await _抓图("穿装备后")
	await _查点("穿装备后", Vector2(640.0, 250.0))

	print("截拖拽穿装备：共 %d 张，目录 %s" % [_截图数, _出目录])
	quit(0)


## 两个提示框的可见性。它们的**场景根节点默认 `visible = true`**（`.tscn` 里没写
## `visible = false`），全靠悬停进出回调去开关 —— 所以「没人悬停时它们是不是关着」
## 是个必须单独盯的状态，不能只看截图。
func _报提示框(标签: String) -> void:
	await process_frame
	var 行: Array[String] = []
	for 名 in ["物品提示框", "装备提示框"]:
		for 窗 in [_背包窗, _人物窗]:
			var 框 := 窗.find_child(名, true, false) as Control
			if 框 != null:
				行.append("%s@%s visible=%s" % [名, 窗.name, 框.visible])
	print("提示框状态[%s]：%s" % [标签, "  ".join(行)])


## 把"某个屏幕点下面压着哪些可见控件"按**树的先后**打出来（后面的画在上面）。
## 出现来路不明的方块时用它，别靠看图猜（§0.0d 第 1 条）。
func _查点(标签: String, 点: Vector2) -> void:
	print("--- %s：点 %s 下面的可见控件（自上而下画，末行在最上层）---" % [标签, 点])
	var 命中: Array[String] = []
	_收集(_场景, 点, 命中, "")
	for 行 in 命中:
		print("  ", 行)


## ⚠️ 递归**必须无条件**往下走：窗口根节点是普通 Node（不是 CanvasItem），
## 第一版把递归写进了 `if 画布 != null` 里，于是整棵窗口子树都没被查到，
## 只剩一个 Sky —— 差点据此得出"那块东西不是控件"的错误结论。
## ⚠️ 判可见必须用 `is_visible_in_tree()`，**不是 `visible`**。
## `visible` 只是节点自己的开关，父节点关掉时它照样是 true —— 第一版就是栽在这儿：
## 那条"深色块 = 物品提示框"的结论是假的，提示框其实关着（见 `_报提示框` 的输出）。
func _收集(节点: Node, 点: Vector2, 命中: Array[String], 路径: String) -> void:
	var 这里 := "%s/%s" % [路径, 节点.name]
	var 画布 := 节点 as CanvasItem
	if 画布 != null and 画布.is_visible_in_tree():
		var 控件 := 节点 as Control
		if 控件 != null:
			if 控件.get_global_rect().has_point(点):
				命中.append("%s rect=%s" % [这里, 控件.get_global_rect()])
		elif _是可见图元(节点):
			命中.append("%s（非 Control 的 CanvasItem）" % 这里)
	for 子 in 节点.get_children():
		_收集(子, 点, 命中, 这里)


func _是可见图元(节点: Node) -> bool:
	return 节点 is Node2D


## 背包里那件武器的格子。背包的格子在 `格子容器/物品格_<序号>`，
## 哪一格装着 `武器id` 由格子自己的 `物品id` 说了算（渲染时填的）。
func _找背包里的武器格() -> Button:
	var 容器 := _背包窗.find_child("格子容器", true, false)
	if 容器 == null:
		return null
	for 节点 in 容器.get_children():
		var 格 := 节点 as Button
		if 格 != null and String(格.get("物品id")) == 武器id:
			return 格
	return null


## 人物面板上的「武器」装备格。
func _找武器槽() -> Button:
	var 装备栏 := _人物窗.find_child("装备栏", true, false)
	if 装备栏 == null:
		return null
	return 装备栏.get_node_or_null(武器格节点名) as Button


func _中心(控件: Control) -> Vector2:
	return 控件.get_global_position() + 控件.size * 0.5


## 合成事件一律走 `Viewport.push_input`，`button_mask` 带左键。
func _发按下(位置: Vector2) -> void:
	var 事件 := InputEventMouseButton.new()
	事件.button_index = MOUSE_BUTTON_LEFT
	事件.pressed = true
	事件.button_mask = MOUSE_BUTTON_MASK_LEFT
	事件.position = 位置
	事件.global_position = 位置
	root.push_input(事件)


func _发松开(位置: Vector2) -> void:
	var 事件 := InputEventMouseButton.new()
	事件.button_index = MOUSE_BUTTON_LEFT
	事件.pressed = false
	事件.button_mask = 0
	事件.position = 位置
	事件.global_position = 位置
	root.push_input(事件)


func _发移动(位置: Vector2) -> void:
	var 事件 := InputEventMouseMotion.new()
	事件.position = 位置
	事件.global_position = 位置
	事件.relative = Vector2(8, 0)
	事件.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(事件)


func _抓图(名称: String) -> void:
	await process_frame
	var 图像 := root.get_texture().get_image()
	if 图像 == null:
		push_error("视口图像为空（不能加 --headless）")
		return
	图像.save_png("%s/%s.png" % [_出目录, 名称])
	_截图数 += 1
	print("截拖拽穿装备：已存 %s" % 名称)
