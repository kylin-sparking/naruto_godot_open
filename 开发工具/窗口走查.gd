extends SceneTree

## 真实鼠标走查：用**合成鼠标事件**按玩家的手去点、去拖，看窗口答不答应。
##
## 和 `测试/窗口行为契约体检.gd` 的分工：
##   * 契约体检（无头，进 `验证全部.ps1`）用 API 直驱 + 少量合成事件，管"逻辑答不答应"；
##   * 本走查（**必须有头**）全程走 `Viewport.push_input` 的真实鼠标路径，管"手上有没有"，
##     并且补上契约体检做不到的**真拖拽**（拖标题栏搬窗口）。
##
## ⚠️ 坐标一律**现算**，不写死常量 —— 项目吃过"按旧窗口位置发事件、全打到窗口外"的亏
##    （§3.16.9）。每次操作前重新取 `get_global_rect()`。
## ⚠️ 加载的是运行时真正加载的**烘焙场景**（`playable_scene_path()`）。
## ⚠️ **不能加 `--headless`**：无头下根视口只有 64x64，坐标全不对。
##
## 用法：
##   Godot --path . --script res://开发工具/窗口走查.gd -- [--地图=101010000] [--出目录=测试/截图/窗口走查]

const 地图资源 := preload("res://脚本/地图/地图资源.gd")

const 默认地图 := "101010000"
## 一帧里挪这么大，别一步跳到目标外 —— 原版拖拽起手就栽在"一步跨过格子"上。
const 拖动步长 := 16.0

var _失败: Array[String] = []
var _场景: Node = null
var _管理: Node = null
var _会话: Node = null
var _地图 := 默认地图
var _出目录 := "测试/截图/窗口走查"


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2:
			if 键值[0] == "--地图":
				_地图 = 键值[1]
			elif 键值[0] == "--出目录":
				_出目录 = 键值[1]
	call_deferred("_跑")


func _跑() -> void:
	if not await _建场景():
		_收尾()
		return
	await _截("开场")
	await _走查_点底栏开关()
	await _走查_真拖拽()
	await _走查_点谁谁在前()
	_收尾()


func _建场景() -> bool:
	var 路径: String = 地图资源.playable_scene_path(_地图)
	print("窗口走查：加载 ", 路径)
	if not 路径.contains("场景/生成/"):
		_失败.append("加载的不是烘焙场景（%s）—— 拿源场景验等于验了个假" % 路径)
		return false
	if root.get_visible_rect().size.x < 320.0:
		_失败.append("视口只有 %s，太小 —— 是不是加了 --headless？" % root.get_visible_rect().size)
		return false
	_场景 = (load(路径) as PackedScene).instantiate()
	root.add_child(_场景)
	_管理 = _场景.get_node_or_null("窗口管理")
	_会话 = root.get_node_or_null("GameSession")
	if _管理 == null or _会话 == null:
		_失败.append("场景里缺 `窗口管理` 或 `GameSession`")
		return false
	await _等帧(3)
	return true


# ── 甲：真鼠标点底栏开 / 关 ────────────────────────────────────────────

func _走查_点底栏开关() -> void:
	await _清场()
	var 点 := await _底栏按钮点("背包")
	if 点 == Vector2.INF:
		_失败.append("底栏「背包」按钮点不到（被别的窗盖住，或找不到）")
		return
	await _点击(点)
	await _截("点了背包")
	_检(_已开("背包"), "点底栏「背包」应打开背包")

	点 = await _底栏按钮点("背包")
	if 点 != Vector2.INF:
		await _点击(点)
		await _截("再点背包")
		_检(not _已开("背包"), "**再点一次同一按钮应关闭**（用户 2026-09-24 报的就是这条）")


# ── 乙：真拖拽（契约体检做不到的那条）────────────────────────────────

func _走查_真拖拽() -> void:
	await _清场()
	_管理.call("打开", "背包")
	await _等帧(3)
	var 窗 := _窗("背包")
	var 起 := _标题栏抓点(窗)
	if 起 == Vector2.INF:
		_失败.append("取不到背包的标题栏抓点")
		return
	var 起框 := _矩形("背包")

	_发移动(起)
	await _等帧(1)
	_发按下(起)
	await _等帧(2)
	var 目标 := 起 + Vector2(120.0, -70.0)
	var 步数 := int(maxf(1.0, ceil((目标 - 起).length() / 拖动步长)))
	for i in range(1, 步数 + 1):
		_发移动(起.lerp(目标, float(i) / 步数))
		await _等帧(1)
	await _等帧(1)
	_发松开(目标)
	await _等帧(4)
	await _截("拖完")

	var 终框 := _矩形("背包")
	var 实际 := 终框.position - 起框.position
	_检(实际.distance_to(Vector2(120.0, -70.0)) <= 3.0,
		"拖标题栏应把窗口搬走 (120,-70)，实际搬了 %s（起 %s 终 %s）" % [实际, 起框.position, 终框.position])

	# 拖过之后，关了再开应回到**拖动后**的位置（原版记位置那条）
	var 挪过 := 终框.position
	await _点底栏("背包")
	await _点底栏("背包")
	await _等帧(3)
	_检(_矩形("背包").position.distance_to(挪过) <= 2.0,
		"拖过之后关了再开应回到拖动后的位置 %s，实际 %s（差 %s）" % [
			挪过, _矩形("背包").position, _矩形("背包").position - 挪过])


# ── 丙：点谁谁在前 ────────────────────────────────────────────────────

func _走查_点谁谁在前() -> void:
	await _清场()
	_管理.call("打开", "人物")
	_管理.call("打开", "背包")
	await _等帧(3)
	_检(_最上层页名() == "背包", "后开的背包该在最上，实际最上是「%s」" % _最上层页名())

	# 把人物挪到左边露出一块，点它 —— 该提到最上
	_窗("人物").call("窗口偏移", Vector2(-120.0, -60.0))
	_窗("背包").call("窗口偏移", Vector2(120.0, 60.0))
	await _等帧(3)
	var 人物点 := _只属于("人物", "背包")
	if 人物点 == Vector2.INF:
		_失败.append("两窗错开后找不到只属于人物的点")
		return
	await _点击(人物点)
	await _截("点过人物")
	_检(_最上层页名() == "人物", "点人物露出来的那块应把它提到最上，实际最上是「%s」" % _最上层页名())
	_发移动(_重叠点("人物", "背包"))
	await _等帧(2)
	_检(_命中页名() == "人物", "人物提到最上后，重叠区该命中人物，实际命中「%s」" % _命中页名())


# ── 驱动 ──────────────────────────────────────────────────────────────

func _清场() -> void:
	_管理.call("全部关闭")
	_管理.set("_记住的位置", {})
	await _等帧(3)


func _点底栏(页名: String) -> void:
	_会话.call("request_feature", 页名)
	await _等帧(3)


## 按 tooltip 找底栏按钮，返回一个**真的能点到**的点。
##
## 不写死坐标（项目吃过亏）；"能不能点到"以 `gui_get_hovered_control()` 的真命中为准，
## 不信 rect、也不信 `find_children` 的顺序 ——「宠物」在场景里有两个同名按钮。
func _底栏按钮点(页名: String) -> Vector2:
	var 底栏 := _场景.get_node_or_null("技能面板/技能栏") as Control
	if 底栏 == null:
		return Vector2.INF
	for 节点 in 底栏.find_children("*", "BaseButton", true, false):
		var 按钮 := 节点 as BaseButton
		if 按钮 == null or 按钮.tooltip_text != 页名 or 按钮.disabled:
			continue
		if not 按钮.is_visible_in_tree():
			continue
		var r := 按钮.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var 点 := r.position + r.size * 0.5
		_发移动(点)
		await _等帧(2)
		var 命中 := root.gui_get_hovered_control()
		if 命中 != null and (命中 == 按钮 or 按钮.is_ancestor_of(命中)):
			return 点
		print("窗口走查：底栏「%s」的中心被 %s 压住，换下一个候选" % [
			页名, "null" if 命中 == null else 命中.get_path()])
	return Vector2.INF


## 标题栏上适合下手的点：靠左、避开关闭按钮（`功能窗口.tscn` 的注释说明拖动区要排在关闭按钮之前）。
func _标题栏抓点(窗: Node) -> Vector2:
	var 主窗 := 窗.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		return Vector2.INF
	var r := 主窗.get_global_rect()
	var 关 := 窗.get_node_or_null("遮罩/主窗口/关闭按钮") as Control
	var 右界 := r.end.x - 12.0
	if 关 != null and 关.visible:
		右界 = minf(右界, 关.get_global_rect().position.x - 8.0)
	var x := clampf(r.position.x + r.size.x * 0.35, r.position.x + 8.0, 右界)
	return Vector2(x, r.position.y + 14.0)


func _发移动(位置: Vector2) -> void:
	var 事件 := InputEventMouseMotion.new()
	事件.position = 位置
	事件.global_position = 位置
	事件.relative = Vector2(4, 0)
	事件.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(事件)


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


func _点击(位置: Vector2) -> void:
	_发移动(位置)
	await _等帧(1)
	_发按下(位置)
	await _等帧(2)
	_发松开(位置)
	await _等帧(3)


func _等帧(帧数: int) -> void:
	for _序号 in maxi(1, 帧数):
		await process_frame


func _截(名字: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _出目录))
	root.get_texture().get_image().save_png("res://%s/%s.png" % [_出目录, 名字])


# ── 探针 ──────────────────────────────────────────────────────────────

func _窗(页名: String) -> Node:
	return _管理.call("取窗口", 页名)


func _已开(页名: String) -> bool:
	var 窗 := _窗(页名)
	return 窗 != null and bool(窗.call("已打开"))


func _矩形(页名: String) -> Rect2:
	var 窗 := _窗(页名)
	if 窗 == null:
		return Rect2()
	var 主窗 := 窗.get_node_or_null("遮罩/主窗口") as Control
	return 主窗.get_global_rect() if 主窗 != null else Rect2()


func _最上层页名() -> String:
	var 最后 := ""
	var 最高 := -9999
	for 键 in (_管理.get("_窗口们") as Dictionary):
		var 窗 := _管理.get("_窗口们")[键] as Node
		if 窗 == null or not bool(窗.call("已打开")):
			continue
		if int(窗.layer) > 最高:
			最高 = int(窗.layer)
			最后 = String(键)
	return 最后


func _命中页名() -> String:
	var 命中 := root.gui_get_hovered_control()
	if 命中 == null:
		return "（无命中）"
	for 键 in (_管理.get("_窗口们") as Dictionary):
		var 窗 := _管理.get("_窗口们")[键] as Node
		if 窗 != null and (命中 == 窗 or 窗.is_ancestor_of(命中)):
			return String(键)
	return "（非窗口）"


func _只属于(甲: String, 乙: String) -> Vector2:
	var 甲框 := _矩形(甲)
	var 乙框 := _矩形(乙)
	for y in range(int(甲框.position.y) + 6, int(甲框.end.y) - 6, 40):
		for x in range(int(甲框.position.x) + 6, int(甲框.end.x) - 6, 40):
			var 点 := Vector2(x, y)
			if not 乙框.has_point(点):
				return 点
	return Vector2.INF


func _重叠点(甲: String, 乙: String) -> Vector2:
	var 交 := _矩形(甲).intersection(_矩形(乙))
	return 交.position + 交.size * 0.5 if 交.size.x > 4.0 and 交.size.y > 4.0 else Vector2.INF


func _检(条件: bool, 说明: String) -> void:
	if 条件:
		print("窗口走查：√ ", 说明)
	else:
		_失败.append(说明)


func _收尾() -> void:
	if _场景 != null and is_instance_valid(_场景):
		_场景.queue_free()
		_场景 = null
	await _等帧(2)
	if _失败.is_empty():
		print("窗口走查：通过")
		quit(0)
		return
	for 项 in _失败:
		push_error("窗口走查：失败 - %s" % 项)
	quit(1)
