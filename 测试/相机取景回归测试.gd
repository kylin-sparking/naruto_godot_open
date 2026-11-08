extends SceneTree
## 世界相机取景回归门（2026-10-24，修「竞技场地图悬空」）。
##
## 判的是**地图比窗口小**那一档的钳制方向。原版 `Camera.as:120-131`（`gotoFocusObject`，
## `gotoFocusObjectCenter:43-55` 同一条）是**两条有先后**的钳制：
##     _loc2_ = Math.max(viewRect.left,  _loc2_);
##     _loc2_ = Math.min(viewRect.right - rect.width, _loc2_);    ← 后算的那条赢
## 图窄于舞台时 `right - width < left` ⇒ 结果落在 **right − width**：
## **远边（右/下）钉死在屏幕边上，空出来的一条全在上方/左方**。
##
## 我们原来写的是 `if left > right: 用地图中心` —— 居中把空档劈成"上、下各一条"，
## 于是矮图（竞技场 503000000 的 VR 只有 767 高，玩家窗口 1032 高）**整块平台悬在屏幕中间、
## 底下露出一条天空**，玩家看到的就是"地图悬空"。
##
## ★ 参照值一律**自己按 AS3 那两行算**，不问被测对象要（否则两边一起错就互相印证）。
##
## 跑法：Godot --headless --path . --script res://测试/相机取景回归测试.gd
##   退出码 0 = 全过；1 = 有红；2 = 前置条件不满足（量具自己拿不到视口尺寸）

const 相机脚本 := preload("res://脚本/地图/世界相机.gd")

## 竞技场 503000000 的视口矩形，从**地图数据现查**（不写死），出处 `数据/地图/竞技场/地图.json` 的 info
const 竞技场图数据 := "res://数据/地图/竞技场/地图.json"
## 用户实机那扇：1920×1032（全屏工作区）。这一档才会掉进"图比窗口矮"的退化分支。
const 用户窗宽 := 1920.0
const 用户窗高 := 1032.0
## 工程默认视口（也是跑批机上的那一档）—— 这一档竞技场比窗口高，走的是普通钳制，用来当对照
const 默认窗宽 := 960.0
const 默认窗高 := 560.0

var _判: Array = []
var _相: Camera2D = null
var _视口可用 := false


func _记(名: String, 过: bool) -> void:
	_判.append([名, 过])


func _读视口矩形(路: String) -> Rect2:
	var 档 := FileAccess.open(路, FileAccess.READ)
	if 档 == null:
		return Rect2()
	var 解 = JSON.parse_string(档.get_as_text().trim_prefix("﻿"))
	档.close()
	if not 解 is Dictionary:
		return Rect2()
	var 信: Dictionary = (解 as Dictionary).get("info", {})
	var 左 := float(信.get("VRLeft", 0))
	var 上 := float(信.get("VRTop", 0))
	var 右 := float(信.get("VRRight", 0))
	var 下 := float(信.get("VRBottom", 0))
	return Rect2(左, 上, 右 - 左, 下 - 上)


func _initialize() -> void:
	call_deferred("_跑")


## 原版那两行的等价式（作用在"视口左上角"上）：先 max 近边、再 min 远边。
## 这里刻意**独立重写一遍**（不调相机那段代码），否则测的就是它自己。
func _原版钳(近: float, 远减: float, 期望: float) -> float:
	var v := 期望
	v = maxf(近, v)
	v = minf(远减, v)
	return v


func _跑() -> void:
	_相 = 相机脚本.new() as Camera2D
	root.add_child(_相)
	# 视口尺寸要能改，否则"图比窗口矮"那一档根本测不到 —— 测不到就必须红着退出，不许静默跳过。
	root.size = Vector2i(int(用户窗宽), int(用户窗高))
	await process_frame
	await process_frame
	var 实视口: Vector2 = _相.get_viewport_rect().size
	_视口可用 = absf(实视口.x - 用户窗宽) <= 1.0 and absf(实视口.y - 用户窗高) <= 1.0
	_记("量具自检：视口能改到用户实机那一档 %dx%d（实测 %dx%d）" % [
			int(用户窗宽), int(用户窗高), int(实视口.x), int(实视口.y)], _视口可用)
	if not _视口可用:
		_收()
		return

	var 界 := _读视口矩形(竞技场图数据)
	_记("量具自检：从地图数据现查出竞技场的视口矩形（实测 %s，应为 P(28,0) S(1921,767)）" % str(界),
			界.position == Vector2(28, 0) and absf(界.size.x - 1921) <= 1 and absf(界.size.y - 767) <= 1)
	_相.set("map_bounds", 界)
	_相.set("zoom", Vector2.ONE)

	# ──  退化档（图比窗口矮）：判"地图下沿钉在屏幕底"，而不是"地图居中"
	#    期望（自己按 AS3 算）：视口顶边 = VRBottom − 窗高 = 767 − 1032 = −265 ⇒ 中心 = −265 + 516 = 251
	var 半高 := 用户窗高 * 0.5
	var 顶边 := _原版钳(界.position.y, 界.end.y - 用户窗高, 540.0 - 半高)
	var 期中 := 顶边 + 半高
	var 中: Vector2 = _相.call("_clamp_center_to_map", Vector2(450.0, 540.0 - 半高)) as Vector2
	_记("图比窗口矮 ⇒ **地图下沿钉在屏幕底**（中心 y=%.1f；原版 Camera.as:128-129 后算的 min 赢）" % 期中,
			absf(float(middle_y(中)) - 期中) <= 0.5)
	_记("退化档不许退化成「把地图居中」（居中会给 %.1f，那正是「平台悬在屏幕中间、底下露一条天空」）" % 界.get_center().y,
			absf(float(middle_y(中)) - 界.get_center().y) > 20.0)
	# 屏幕最下一格对应的世界 y 必须正好是地图下沿（这条直接对着"悬空"两个字）
	_记("这一档下屏幕最下沿 = 世界 y=%.0f = 地图 VRBottom（底下**没有**露空）" % 界.end.y,
			absf((float(middle_y(中)) + 半高) - 界.end.y) <= 0.5)

	# ── ② 横向：竞技场宽 1921、窗口 1920 ⇒ 不退化，走普通钳制（对照，防我把 min/max 写反）
	var 半宽 := 用户窗宽 * 0.5
	var 左期望 := _原版钳(界.position.x, 界.end.x - 用户窗宽, 450.0 - 半宽)
	_记("横向不退化时仍按普通钳制（左=%.1f 右=%.1f ⇒ 期望中心 x=%.1f，实测 %.1f）" % [
			界.position.x + 半宽, 界.end.x - 半宽, 左期望 + 半宽, float(middle_x(中))],
			absf(float(middle_x(中)) - (左期望 + 半宽)) <= 0.5)

	# ── ③ 对照档（默认 960×560）：竞技场比窗口高 ⇒ 两条都不退化，行为与改动前**逐字节相同**
	root.size = Vector2i(int(默认窗宽), int(默认窗高))
	await process_frame
	await process_frame
	var 实2: Vector2 = _相.get_viewport_rect().size
	if absf(实2.y - 默认窗高) > 1.0:
		_记("量具自检：视口改不回 %dx%d（实测 %dx%d）⇒ 对照档没测到" % [
				int(默认窗宽), int(默认窗高), int(实2.x), int(实2.y)], false)
	else:
		var 半2 := 默认窗高 * 0.5
		var 期2 := _原版钳(界.position.y + 半2, 界.end.y - 半2, 540.0)
		var 中2: Vector2 = _相.call("_clamp_center_to_map", Vector2(450.0, 540.0)) as Vector2
		_记("对照：默认窗口那一档竖直钳制没变（角色站 540 ⇒ 中心 y 期望 %.1f、实测 %.1f）" % [期2, float(middle_y(中2))],
				absf(float(middle_y(中2)) - 期2) <= 0.5)
		_记("对照：默认窗口下地图**上下都不露空**（视口跨度 560 < 图高 767）",
				float(middle_y(中2)) - 半2 >= 界.position.y - 0.5 and float(middle_y(中2)) + 半2 <= 界.end.y + 0.5)
	_收()


## 从 Vector2 里取分量。**不许写 `中.y`**：GDScript 里 `中` 是 Variant，点号取属性可以，
## 但 `get("y")` 对 Vector2 拿不到 ⇒ 一律走这里的显式转换（同一条坑记在 user 记忆）。
func middle_x(v: Variant) -> float:
	return float((v as Vector2).x)


func middle_y(v: Variant) -> float:
	return float((v as Vector2).y)


func _收() -> void:
	var 红 := 0
	for 一 in _判:
		if not bool(一[1]):
			红 += 1
		print("  %-4s  %s" % ["通过" if bool(一[1]) else "红", 一[0]])
	print("相机取景门：判 %d 条，红 %d 条" % [_判.size(), 红])
	quit(2 if not _视口可用 and _判.size() == 1 else (0 if 红 == 0 else 1))
