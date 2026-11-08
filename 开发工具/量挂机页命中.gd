## 真鼠标量具：挂机设置页（664×492）在**有状态帧打进来**的时候还点不点得动、还刷不刷得动。
## 为什么要它（用户 2026-10-19 实机报「页面所有内容我无法点击」，而 395 条离线门全绿）：
## 那道门把 `_点勾`/`_选档` **直接调一遍**判状态变，从没把鼠标打到件上；我第一版量具离线
## 一次就点中 —— 因为**离线没有每秒几十发的 39/40/1808 状态帧**。真机上
## `功能窗口.gd:401`（`hang_changed`）与 383（`player_stats_changed`）等一连串都连到
## `_refresh_current()` → `_flush_refresh()` → `_render_page()`，而 `_render_page()` 开头把
## `_content` 的 children 全部 `remove_child + queue_free` ⇒ **按下记在旧节点、抬起落到重建出来的
## 新节点**，`BaseButton.pressed` 永远不发。修前实测就是下面第 ② 条那种红。
## 跑法（**不能加 --headless**，无头拿不到视口拾取）：
##   godot --path . --script res://开发工具/量挂机页命中.gd
extends SceneTree

var 行: Array[String] = []
var 红 := 0
var 点过 := {}
var 会: Node
var 场: Node


func _initialize() -> void:
	call_deferred("_跑")


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _判(对: bool, s: String) -> void:
	if 对:
		_记("ok   " + s)
	else:
		红 += 1
		_记("红   " + s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _名(件: Node) -> String:
	if 件 == null or not is_instance_valid(件):
		return "〈已释放〉"
	return String((件 as Node).name)


## 一发"服务端状态帧"的最小等价物：会里那些 `_on_backend_*` 最后就是 emit 这两个信号。
func _灌一帧() -> void:
	会.settings_changed.emit(会.game_settings.duplicate(true))
	会.hang_changed.emit((会.hang_state as Dictionary).duplicate(true))


func _页() -> Control:
	return 场.find_child("原版挂机设置内容", true, false) as Control


func _跑() -> void:
	场 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(60)
	会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_判(false, "找不到 /root/GameSession ⇒ 后面全部判不了")
		_收()
		return
	## 与游戏里那颗「挂机」球同一个入口（`技能面板.gd:769`）
	会.call("request_feature", "挂机")
	await _帧(20)
	var 页 := _页()
	if 页 == null:
		_判(false, "request_feature(\"挂机\") 之后页面根节点没建出来")
		_收()
		return
	var 旧号 := 页.get_instance_id()
	_记("页面根：%s  实例号=%d" % [String(页.get_path()), 旧号])

	## ── ① 这页标了"自刷"，状态帧来了**不许把它拆掉**（拆了就是"整页点不动"的根因）──
	_灌一帧()
	await _帧(6)
	var 现页 := _页()
	_判(现页 != null and 现页.get_instance_id() == 旧号,
			"灌一发状态帧之后页面实例必须还是同一个（实得 %s，原 %d）" % [
			str(现页.get_instance_id()) if 现页 != null else "〈查无〉", 旧号])
	if 现页 == null:
		_判(false, "页面没了 ⇒ 后面两条等于没判")
		_收()
		return

	## ── ② 真机时序的点击：按下 → 灌一帧 → 抬起 ──
	## 只挑两枚勾：`钮开始` 一点就 `_宿主.close()`（原版 `startGuaJi:557` 收窗）+ 真开挂机，
	## 机制同一条，没必要在量具里动存档。
	for 路径 in ["复选拾取总开关/点击区域", "复选生命阈值/点击区域"]:
		## 每一轮**重新找一次页面**：修坏的时候那一发状态帧会把 `页` 本身拆掉，
		## 拿旧引用调方法 = `previously freed instance` ⇒ GDScript 没有 try/except，
		## 整条协程静默终止、后面几条根本没跑，进程还挂在那里不 quit。
		var 现: Control = _页()
		if 现 == null:
			_判(false, "%s 这一轮开跑前页面已被拆掉/查无 ⇒ 这条明着记红，不许静默跳过" % 路径)
			continue
		页 = 现
		var 件: Node = 页.get_node_or_null(路径)
		if 件 == null or not (件 is BaseButton):
			_判(false, "%s 查无或不是 Button ⇒ 这一条等于没判" % 路径)
			continue
		var 控 := 件 as BaseButton
		var 心: Vector2 = 控.global_position + (控 as Control).size * 0.5
		点过[路径] = 0
		控.pressed.connect(_按过.bind(路径))
		var 移 := InputEventMouseMotion.new()
		移.position = 心
		移.global_position = 心
		root.push_input(移)
		await _帧(3)
		var 按 := InputEventMouseButton.new()
		按.position = 心
		按.global_position = 心
		按.button_index = MOUSE_BUTTON_LEFT
		按.pressed = true
		root.push_input(按)
		await _帧(2)
		_灌一帧()						# ← 真机上就是这一发把节点拆掉的
		await _帧(2)
		var 抬 := InputEventMouseButton.new()
		抬.position = 心
		抬.global_position = 心
		抬.button_index = MOUSE_BUTTON_LEFT
		抬.pressed = false
		root.push_input(抬)
		await _帧(4)
		_判(int(点过[路径]) > 0 and is_instance_valid(件),
				"%s 在「按下→状态帧→抬起」时序下 pressed 要被叫到且件不能被拆（实得 %d 次、活着=%s）" % [
				路径, int(点过[路径]), str(is_instance_valid(件))])
		_记("  点完这一枚之后页面实例=%s（原 %d）" % [
				str(页.get_instance_id()) if is_instance_valid(页) else "〈已释放〉", 旧号])

	## ── ③ "不拆页"不等于"刷不动"：灌一发 1283 回帧，那枚勾的显形必须跟着翻 ──
	页 = _页()
	if 页 == null:
		_判(false, "第三条开跑前页面查无 ⇒ 这条没判")
		_收()
		return
	var 标 := (页.get_node("复选拾取总开关") as Control).get_node("标记") as CanvasItem
	var 原 := 标.visible
	会.挂机配置_changed.emit({"autoCollect": not 原})
	await _帧(4)
	_判(标.visible == (not 原),
			"灌一发 1283 配置（autoCollect 取反）之后『拾取总开关』的标记要从 %s 翻到 %s（实得 %s）" % [
			str(原), str(not 原), str(标.visible)])
	会.挂机配置_changed.emit({"autoCollect": 原})		# 还原，别把状态留给后面的门
	await _帧(2)
	_收()


func _按过(路径: String) -> void:
	点过[路径] = int(点过.get(路径, 0)) + 1


func _收() -> void:
	var 路 := "user://挂机页命中量具.txt"
	var f := FileAccess.open(路, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	_记("红 %d 项 → %s" % [红, 路])
	quit(0 if 红 == 0 else 1)
