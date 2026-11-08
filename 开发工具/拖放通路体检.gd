extends SceneTree

## 拖放通路体检 —— 用**合成鼠标事件**走 Godot 真实的 gui 拖放通路，
## 量出"哪种控件能当拖拽源、哪种能当落点"。
##
## 为什么要有这个工具（2026-09-22）：
##   装备格里**空格是 `disabled = true`**（`人物窗口.gd` 渲染时设的），而空格恰恰是
##   最需要能落下的目标 —— 「往空格穿装备」。Godot 的 `BaseButton.disabled` 会不会
##   连 `_can_drop_data` / `_drop_data` 一起挡掉？文档没写、源码不好查。
##   按 §0.0d「不确定就去量」，这里直接**量**：拿**真的** `物品格.tscn` / `装备格.tscn`
##   当源和落点，合成一次完整拖放，看谁收到了 `拖放` 信号。
##
## **对照组**：`启用物品格` 是背包模块已经在用的那条路（空格子也能当落点）。
##   它收到 = 这套合成手法有效，其余各行才有意义；它没收到 = 测的是工具不是控件，
##   结论一律作废（见 §0.0d「验证环节本身不可靠」）。
##
## 用法（**不能加 --headless**：需要真实视口收发鼠标事件）：
##   Godot --path . --script res://开发工具/拖放通路体检.gd

const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
const 装备格场景 := preload("res://场景/界面/组件/装备格.tscn")

const 源位置 := Vector2(60, 60)
const 图标尺寸 := Vector2(40, 40)
## 拖拽源那件物品的 id。**必须与下面"对的槽"的槽位号对得上**：
## 01010013 是武器（`装备部位.位置` = 武器 = -1）。见 `测试/装备部位在线回归测试.gd`。
const 源物品id := "01010013"
const 对的槽 := -1        # 武器
const 错的槽 := -6        # 忍鞋 —— 武器落在这一格必须被拒（原版 `part` 不匹配 → 静默丢下）

## 每个目标：名字 → [位置, 是不是 disabled, 归属, 槽位号]
const 目标表 := [
	["启用物品格", Vector2(160, 60), false, "背包", 7],  # ← 对照组：背包模块已在用的那条路
	["禁用物品格", Vector2(240, 60), true, "背包", 8],
	["启用装备格", Vector2(320, 60), false, "装备", 对的槽],
	["禁用装备格", Vector2(400, 60), true, "装备", 对的槽],
	["装备格_错槽", Vector2(480, 60), false, "装备", 错的槽],  # ← 必须**收不到**
]

var _台: Control = null
var _源: Button = null
## 落点名 → 有没有收到 `拖放`。用普通字典而不是 `set_meta`：
## Godot 的 meta 名要求是合法标识符，中文键会被拒（`Invalid metadata identifier`）。
var _收到 := {}
## 每一趟拖拽：[目标名, 源格收到过 mouse_entered, 源格收到过 mouse_exited]
var _离开记录: Array = []
var _源进过 := false
var _源出来过 := false

func _initialize() -> void:
	_跑()

func _跑() -> void:
	await process_frame
	await process_frame
	_搭台()
	for _序号 in 4:
		await process_frame
	var 结果 := {}
	for 条 in 目标表:
		结果[条[0]] = await _拖一次(条)
	_报结论(结果)
	quit(0)

## 搭一个只有源和四个目标的极小场景。**用真的组件场景**，不自造替身。
func _搭台() -> void:
	_台 = Control.new()
	_台.name = "台"
	_台.size = Vector2(560, 200)
	root.add_child(_台)

	_源 = 物品格场景.instantiate() as Button
	_源.name = "源"
	_源.position = 源位置
	_源.icon = _占位图标()
	_源.set("格子归属", "背包")
	_源.set("槽位号", 3)
	_源.set("物品id", 源物品id)
	_源.set("可拖拽", true)
	# 源格的悬停进出 —— 物品提示框就是挂在这两个信号上的
	_源.mouse_entered.connect(func(): _源进过 = true)
	_源.mouse_exited.connect(func(): _源出来过 = true)
	_台.add_child(_源)

	for 条 in 目标表:
		var 格: Button = (装备格场景.instantiate() as Button) if String(条[3]) == "装备" else (物品格场景.instantiate() as Button)
		格.name = String(条[0])
		格.position = 条[1]
		格.icon = _占位图标()
		# 装备格在改动前后属性不一定齐（`可拖拽` 是这一轮才加的），缺就记下来、
		# 别让它把整条体检打断 —— "没有这个属性"本身就是一条要看的结论。
		var 是装备格 := String(条[3]) == "装备"
		_设(格, "格子归属", 条[3])
		_设(格, "槽位号", int(条[4]))
		_设(格, "物品id", "")
		# 按**生产里的真实配置**填：物品格是可拖拽源，装备格只接不吐（原版起拖端是死代码）。
		_设(格, "可拖拽", not 是装备格)
		格.disabled = 条[2]
		_收到[格.name] = false
		if 格.has_signal("拖放"):
			var 名 := 格.name
			格.connect("拖放", func(_源格: Button, _目标格: Button, _物品id: String) -> void:
				_收到[名] = true
			)
		_台.add_child(格)

## 合成**一次完整拖放**：按下 → 一串移动（越过 Godot 的拖拽起步阈值）→ 停在目标上 → 松手。
## 返回 true 表示目标收到了 `拖放`。每次只测一个目标，避免一次拖拽只能落一处。
func _拖一次(条: Array) -> bool:
	var 目标 := _台.get_node_or_null(String(条[0])) as Button
	if 目标 == null:
		return false
	_收到[目标.name] = false
	_源进过 = false
	_源出来过 = false
	_发按下(源位置)
	await process_frame
	for 序号 in range(1, 13):
		_发移动(源位置.lerp(条[1], 序号 / 12.0))
		await process_frame
	_发松开(条[1])
	for _序号 in 3:
		await process_frame
	# 起拖之后源格有没有收到"鼠标离开"——**物品提示框挂在它上面**，
	# 收不到就会一直挂着（截拖拽穿装备.gd 里那块深色就是它，见那里的 _查点）。
	_离开记录.append([String(条[0]), _源进过, _源出来过])
	return bool(_收到.get(目标.name, false))

## 合成事件一律走 `Viewport.push_input`，**不用 `Input.parse_input_event`**：
## 后者只喂 `Input` 单例、要等主循环 flush，而且不改 `Input` 内部的按键状态，
## 视口的拖放判定拿到的 `button_mask` 是空的 —— 实测对照组一个都收不到（2026-09-22）。
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

## `button_mask` 必须带上左键 —— 视口就是靠它判断"现在是不是按着在拖"。
func _发移动(位置: Vector2) -> void:
	var 事件 := InputEventMouseMotion.new()
	事件.position = 位置
	事件.global_position = 位置
	事件.relative = Vector2(8, 0)
	事件.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(事件)

## 只在属性确实存在时设 —— 装备格在改动前没有 `可拖拽` 这些成员，
## 直接 `set()` 会刷一屏错误、把真正的结论淹掉。
func _设(对象: Object, 属性: String, 值: Variant) -> void:
	if 属性 in 对象:
		对象.set(属性, 值)

func _占位图标() -> Texture2D:
	var 图 := PlaceholderTexture2D.new()
	图.size = 图标尺寸
	return 图

func _报结论(结果: Dictionary) -> void:
	var 对照: bool = bool(结果.get("启用物品格", false))
	print("拖放通路体检：对照组（启用物品格）收到 = ", 对照)
	for 条 in 目标表:
		print("  [%s] disabled=%s → 收到拖放 = %s" % [条[0], 条[2], 结果.get(条[0], false)])
	if not 对照:
		print("拖放通路体检：⚠️ 对照组没收到 —— 说明**合成手法本身**没走通，上面各行不作数")
		return
	# 装备格还多一条：**槽不匹配必须被拒**。这是原版 `EquipPane.onItemUp` 的核心判定
	# （`getItemEquipPosition(id) == target.part`），错了会往服务端发一条穿错槽的报文。
	var 错槽: bool = bool(结果.get("装备格_错槽", false))
	print("  [装备格_错槽] 槽位号=%d（武器 %s 落在这儿）→ 收到拖放 = %s" % [错的槽, 源物品id, 错槽])
	if 错槽:
		print("拖放通路体检：⚠️ **槽不匹配也接了** —— `装备格._can_drop_data` 的 part 判定没生效")
	else:
		print("拖放通路体检：槽不匹配 —— 正确地被拒（与原版一致：静默丢下）")
	# 结论**分开看**：能不能落是组件自己的事，disabled 只是其中一个变量。
	# 拿"启用/禁用"这一对（同一个组件）比，才量得出 disabled 有没有影响。
	for 前缀 in ["物品格", "装备格"]:
		var 启用: bool = bool(结果.get("启用%s" % 前缀, false))
		var 禁用: bool = bool(结果.get("禁用%s" % 前缀, false))
		if 启用 and 禁用:
			print("拖放通路体检：%s —— disabled **不影响**落点" % 前缀)
		elif not 启用 and not 禁用:
			print("拖放通路体检：%s —— 压根没有落点能力（组件还没实现拖放），与本体检的 disabled 变量无关" % 前缀)
		elif 启用 and not 禁用:
			print("拖放通路体检：%s —— disabled **会挡掉**落点" % 前缀)
		else:
			print("拖放通路体检：%s —— 禁用能落、启用反倒不能，可疑，要查" % 前缀)
	print("--- 拖拽时源格的悬停进出 ---")
	for 条 in _离开记录:
		print("  拖向[%s]：源格 mouse_entered=%s mouse_exited=%s" % 条)
	print("拖放通路体检：完毕")
