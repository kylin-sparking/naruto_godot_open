extends Node2D

## A2 自检 ②：代表性特效**实机播放**。
##
## 为什么要有这个：`数据/特效.json` 的帧数/帧间隔是表里的真值，但"表对"不等于"放出来对"——
## 丢帧、闪烁、循环不回绕、单次特效回头重播，都只有真跑起来才看得见。
##
## 覆盖三种形态（各挑真值不同的代表）：
##   逐帧位图   levelUp 22帧×100ms、heal 6帧×400ms、portalPV 8帧×250ms、portalPH 7帧×250ms
##   swf 时间轴 Effect_guaJiZhong 40帧×25ms（循环）、Effect_MaiExplode_0 58帧×10ms（**单次**）
##
## 判据（可判真伪的，不是"看着还行"）：
##   · 不丢帧：每帧间隔 ≥ 屏幕一帧(16.7ms) 的特效，整段里每一帧都得出现过
##   · 顺序对：去掉重复后帧号只能 +1 或回绕到 0，出现别的跳变就是闪烁/乱序
##   · 循环对：循环类特效必须真的回绕过
##   · 单次对：MaiExplode 走完必须停在末帧不再动（MCFromDatDefine.as:184-195）
##
## 跑法（必须带窗口，不能 --headless）：
##   godot --path . --scene res://测试/特效/特效回放.tscn

const EFFECT_PLAYER := preload("res://脚本/表现/特效播放器.gd")

const 输出目录 := "res://测试/输出"
const 播放秒数 := 4.0
const 钉帧清单 := [["portalPV", 3], ["levelUp", 10], ["Effect_guaJiZhong", 20]]

const 特效清单 := [
	{"名": "levelUp", "位置": Vector2(170, 470)},
	{"名": "heal", "位置": Vector2(470, 470)},
	{"名": "portalPV", "位置": Vector2(760, 500)},
	{"名": "portalPH", "位置": Vector2(960, 470)},
	{"名": "Effect_guaJiZhong", "位置": Vector2(230, 700)},
	{"名": "Effect_MaiExplode_0", "位置": Vector2(620, 700)},
]

var _播放器 := {}
var _轨迹 := {}
var _标签 := []
var _起始 := 0
var _已过 := 0.0
var _截图时刻 := [0.8, 2.4]
var _阶段 := "播放"
var _校准次数 := 0
var _失败数 := 0

func _ready() -> void:
	# 窗口只能在第一帧撑大，之后再改会被合成器忽略（本机实测）
	get_window().size = Vector2i(1120, 800)
	var 背景 := ColorRect.new()
	背景.color = Color(0.07, 0.08, 0.10)
	背景.offset_right = 1120.0
	背景.offset_bottom = 800.0
	add_child(背景)
	for 项 in 特效清单:
		var 名 := String(项["名"])
		if not EFFECT_PLAYER.has_effect(名):
			_失败("表里没有 " + 名)
			continue
		var 播放器 = EFFECT_PLAYER.new()
		add_child(播放器)
		播放器.position = 项["位置"]
		if not 播放器.play(名):
			_失败("播放失败 " + 名)
			continue
		_播放器[名] = 播放器
		_轨迹[名] = []
		var 标签 := Label.new()
		标签.text = "%s（%d 帧）" % [名, EFFECT_PLAYER.frame_count_of(名)]
		标签.position = Vector2(项["位置"].x - 90.0, 项["位置"].y + 12.0)
		标签.add_theme_font_size_override("font_size", 12)
		add_child(标签)
		_标签.append(标签)
	_起始 = Time.get_ticks_msec()

## 开局重启一次计时：引擎第一帧的 delta 是窗口初始化的耗时（本机实测 ~130ms），
## 拿它当游戏时间会让所有特效一上来就跳过好几帧，把"速率对不上"误报成真错。
## 所以第 2 个 _process 上重放一遍 play()（elapsed_ms 归零），从第 3 帧起才采样。
func _校准() -> void:
	_校准次数 += 1
	if _校准次数 == 2:
		for 名 in _播放器:
			_播放器[名].play(名)
			_轨迹[名] = []
		_起始 = Time.get_ticks_msec()
		return
	_已过 = float(Time.get_ticks_msec() - _起始) / 1000.0

func _process(delta: float) -> void:
	_校准()
	if _校准次数 < 3 or _阶段 != "播放":
		return
	for 名 in _播放器:
		_轨迹[名].append({"ms": _已过 * 1000.0, "帧": _播放器[名].frame_index})
	if not _截图时刻.is_empty() and _已过 >= float(_截图时刻[0]):
		var 时刻 = _截图时刻.pop_front()
		_截图("特效实机播放_%s" % str(时刻))
	if _已过 >= 播放秒数:
		_阶段 = "收尾中"
		_判定()
		_钉帧序列()

## 逐个把代表帧钉住截图：证明"这一帧画出来的东西"和表里那张原图一致（不裁、不糊、不错位）。
## 标签必须收起来 —— 它会盖在特效上，开发工具/出特效与图标对照图.py 要拿这块像素和原图逐像素比。
func _钉帧序列() -> void:
	for 标签 in _标签:
		标签.visible = false
	for 项 in 钉帧清单:
		var 名 := String(项[0])
		var 帧号 := int(项[1])
		if not _播放器.has(名):
			continue
		for 其它 in _播放器:
			_播放器[其它].visible = (其它 == 名)
		_播放器[名].hold(帧号)
		await get_tree().process_frame
		await get_tree().process_frame
		_截图("特效钉帧_%s_%d" % [名, 帧号])
	_收尾()

func _判定() -> void:
	print("A2 特效实机自检 —— 播放 %.1fs" % 播放秒数)
	for 项 in 特效清单:
		var 名 := String(项["名"])
		if not _轨迹.has(名):
			continue
		var 轨迹: Array = _轨迹[名]
		var 帧数 := EFFECT_PLAYER.frame_count_of(名)
		var 序列 := []
		for 采样 in 轨迹:
			var 帧 := int(采样["帧"])
			if 序列.is_empty() or int(序列.back()) != 帧:
				序列.append(帧)
		var 单帧ms := _每帧ms(名)
		var 播放器 = _播放器[名]
		var 单次 := bool(播放器.entry.get("播法", {}).get("单次", false))
		# ① 不丢帧：只有间隔不短于屏幕一帧的特效才有资格要求全帧覆盖
		#    （每帧 10ms 的特效在 60fps 屏幕上本来就只能抽到一半 —— 原版同理，它也是按时间取帧）
		var 不同帧 := {}
		for 帧 in 序列:
			不同帧[int(帧)] = true
		if 单帧ms >= 16.0:
			var 缺 := []
			for i in 帧数:
				if not 不同帧.has(i):
					缺.append(i)
			if not 缺.is_empty():
				_失败("%s 没出现过的帧：%s" % [名, str(缺)])
				continue
		# ② 顺序对：帧号只能往前走，唯一允许的"倒退"是末帧→0 回绕
		var 乱序 := []
		for i in range(1, 序列.size()):
			var 前 := int(序列[i - 1])
			var 后 := int(序列[i])
			if 后 < 前 and not (后 == 0 and 前 == 帧数 - 1):
				乱序.append("%d→%d" % [前, 后])
		if not 乱序.is_empty():
			_失败("%s 帧序倒退（闪烁/乱序）：%s" % [名, str(乱序)])
			continue
		# ③ 速率对：整段"往前走了多少帧"÷"走了多少墙钟时间"，应当≈ 1/每帧ms。
		#    用**整段聚合**而不是逐次间隔的中位数：25ms/帧 的特效在 60Hz 屏幕上，
		#    单次间隔只能落在 16.7ms 的整数倍上（0.67 倍、1.33 倍…），中位数天生抖出界 ——
		#    2026-09-26 就被这样误判过一次 0.72。聚合量把量化误差平均掉了。
		var 跳变 := []
		var 上一个 := -1
		for 采样 in 轨迹:
			var 帧号 := int(采样["帧"])
			if 帧号 != 上一个:
				跳变.append({"ms": float(采样["ms"]), "帧": 帧号})
				上一个 = 帧号
		var 前进帧 := 0
		var 前进ms := 0.0
		for i in range(1, 跳变.size()):
			var a := int(跳变[i - 1]["帧"])
			var b := int(跳变[i]["帧"])
			if b <= a:
				continue
			前进帧 += b - a
			前进ms += float(跳变[i]["ms"]) - float(跳变[i - 1]["ms"])
		if 前进帧 >= 5:
			var 比值 := 前进ms / (float(前进帧) * 单帧ms)
			if 比值 < 0.8 or 比值 > 1.25:
				_失败("%s 播放速率与表不符：整段走了 %d 帧用了 %.0fms，是 每帧 %.0fms 的 %.2f 倍" % [名, 前进帧, 前进ms, 单帧ms, 比值])
				continue
		# ④ 循环 / 单次
		var 回绕 := 0
		for i in range(1, 序列.size()):
			if int(序列[i]) == 0 and int(序列[i - 1]) == 帧数 - 1:
				回绕 += 1
		if 单次:
			if int(序列.back()) != 帧数 - 1 or not bool(播放器.done):
				_失败("%s 是单次特效，应停在第 %d 帧（实际 %s，done=%s）" % [名, 帧数 - 1, str(序列.back()), str(播放器.done)])
				continue
			if 回绕 > 0:
				_失败("%s 单次特效却回绕了 %d 次" % [名, 回绕])
				continue
			print("  PASS %s：%d/%d 帧、单次走完停在末帧 %d 不回头（每帧 %.0fms）" % [名, 不同帧.size(), 帧数, 序列.back(), 单帧ms])
		elif 回绕 < 1:
			_失败("%s 在这段里没回绕过（循环失效？）" % 名)
			continue
		else:
			print("  PASS %s：%d/%d 帧、回绕 %d 次、每帧 %.0fms" % [名, 不同帧.size(), 帧数, 回绕, 单帧ms])

func _每帧ms(名: String) -> float:
	var 条目: Dictionary = _播放器[名].entry
	if String(条目.get("形态", "")) == "逐帧位图":
		return float(条目.帧[0].get("停留ms", 100))
	return float(条目.get("播法", {}).get("每帧ms", 10.0))

func _截图(基础名: String) -> void:
	var 图像 := get_viewport().get_texture().get_image()
	图像.save_png("%s/%s.png" % [输出目录, 基础名])
	print("  截图 -> 测试/输出/%s.png" % 基础名)

func _收尾() -> void:
	var 文件 := FileAccess.open("%s/特效播放轨迹.json" % 输出目录, FileAccess.WRITE)
	if 文件 != null:
		文件.store_string(JSON.stringify(_轨迹))
		文件.close()
	if _失败数 == 0:
		print("A2 特效实机自检：全部通过")
		get_tree().quit(0)
	else:
		print("A2 特效实机自检：%d 项不通过" % _失败数)
		get_tree().quit(1)

func _失败(消息: String) -> void:
	_失败数 += 1
	print("  FAIL " + 消息)
