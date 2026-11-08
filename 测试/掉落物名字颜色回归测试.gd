## 掉落物名字的颜色。
##
## 真值 `DropItemSprite.render()`：`var _loc1_:uint = 16777215;`（白）是初值，
## **只有神器那一条支**把它换成 `EquipAptitudeType.getEquipColor(PURPLE)`（`:326`）。
## `EquipColors = [0, 16777215, 589593, 40191, 9503487, 16773120, 16769131]`
## 的第 4 项（PURPLE=4）= **9503487 = 0x9102FF**。
##
## ⚠️ 普通装备的品质色**不上名字** —— 那一支（`:346-356`）是给**图标**套 `GlowFilter`。
## 这条门也要把它钉住：蓝/绿/紫的装备，名字**仍然是白的**。
extends SceneTree

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _近色(实际: Color, 期望: Color) -> bool:
	return absf(实际.r - 期望.r) < 0.01 and absf(实际.g - 期望.g) < 0.01 and absf(实际.b - 期望.b) < 0.01

func _统计(定义: Dictionary) -> String:
	var 按类 := {}
	for id in 定义:
		var 类 := String((定义[id] as Dictionary).get("category", ""))
		按类[类] = int(按类.get(类, 0)) + 1
	var 行: Array[String] = []
	for 类 in 按类:
		行.append("%s×%d" % [类, 按类[类]])
	return ", ".join(行)

func _run() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _frame in 12:
		await process_frame

	# ⚠️ `地图场景.tscn` 的**根节点是 `地图根节点`**，掉落物归它下面的 `LifeRoot` 管 ——
	#    第一版我对着场景根调，脚本直接报错 ⇒ `_finish()` 没跑到 ⇒ **`quit()` 没被调，
	#    进程就挂在那儿不退出**（排查时很容易误当成"卡死"）。
	var 生怪根 := 场景.get_node_or_null("LifeRoot")
	if 生怪根 == null:
		_check(false, "地图场景里没有 LifeRoot")
		_finish()
		return
	# 从数据里现找样本，不写死 id
	var 表: Dictionary = GAME_DATA.取表("物品")
	var 神器id := ""
	var 普通id := ""
	for id in 表:
		var 类 := String((GAME_DATA.item(id) as Dictionary).get("category", ""))
		if 类 == "神器" and 神器id.is_empty():
			神器id = String(id)
		elif 类 == "装备" and 普通id.is_empty():
			普通id = String(id)
		if not 神器id.is_empty() and not 普通id.is_empty():
			break
	if 神器id.is_empty() or 普通id.is_empty():
		_check(false, "数据里找不到神器/装备样本（神器=%s 装备=%s）" % [神器id, 普通id])
		_finish()
		return
	_check(String((GAME_DATA.item(神器id) as Dictionary).get("category", "")) == "神器",
			"样本 %s 应该是神器" % 神器id)

	# ① 纯函数：神器紫、装备白、金币白
	var 紫 := Color(0x91 / 255.0, 0x02 / 255.0, 0xFF / 255.0)
	_check(_近色(生怪根.call("_掉落名字颜色", {"item_id": 神器id}), 紫),
			"神器掉落的名字应为 #9102FF（实际 %s）" % 生怪根.call("_掉落名字颜色", {"item_id": 神器id}))
	_check(_近色(生怪根.call("_掉落名字颜色", {"item_id": 普通id}), Color.WHITE),
			"普通装备的名字**仍是白的**（品质色只做图标辉光，不上名字）")
	_check(_近色(生怪根.call("_掉落名字颜色", {"item_id": 5, "is_meso": true}), Color.WHITE),
			"金币的名字是白的")

	# ② 端到端：真建一个掉落物节点，看名字标签实际拿到的字色
	for 用例 in [[神器id, 紫, "神器"], [普通id, Color.WHITE, "装备"]]:
		var 节点: Node2D = 生怪根.call("_create_drop_node", {
			"item_id": 用例[0], "x": 0, "y": 0, "is_meso": false, "item_name": "测试",
		}, 999)
		生怪根.add_child(节点)
		var 名 := 节点.get_node_or_null("DropName") as Label
		_check(名 != null, "掉落物应带 DropName")
		if 名 != null:
			_check(_近色(名.get_theme_color("font_color"), 用例[1]),
					"%s 的名字标签字色应是 %s（实际 %s）" % [用例[2], 用例[1], 名.get_theme_color("font_color")])
		_check(名 != null and 名.text == "测试", "掉落物名字文案应取自 item_name")
		节点.queue_free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("掉落物名字颜色回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)
