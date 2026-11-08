extends SceneTree

## 离线门：**世界相机必须把画面落在整数屏幕像素上**（任何窗口尺寸，含奇数高/宽）。
##
## 为什么单独成一道门（2026-10-13）：用户报"打坐的八卦阵在全屏时会飘，恢复默认分辨率就不飘"。
## 查到底的根因不在打坐素材，而在相机取整口径：
##     屏幕位 = 世界 − 相机 + 视口/2
## 旧写法是 `_clamp_center_to_map(期望中心).round()` —— 按**世界像素**取整。一旦**视口宽或高是奇数**
## （"带标题栏的全屏/最大化窗口"客户区尺寸经常是奇数），`视口/2` 带 .5 ⇒ 每个世界像素被推到两个
## 屏幕像素正中间 ⇒ Nearest 采样逐帧在两者之间取整 ⇒ **整幅画面（尤其八卦阵那种细亮线）看着在抖**。
## 实测对照（`开发工具/查全屏抖不抖.gd`）：
##     老写法 + 960×560 → 画布偏移 (-39.0, 100.0)、屏幕位小数 0.00  → 不抖
##     老写法 + 961×561 → 画布偏移 (-39.5,  99.5)、屏幕位小数 0.50  → **抖**
##     新写法（先减半视口再取整）→ 两档小数全 0.00 → 不抖
## ⇒ 这条对**整个世界**都成立，不只打坐 ⇒ 所以钉成一道独立的门，别让它悄悄退回老写法。
##
## ⚠ **故意不进 `验证全部.ps1` 的 testsBase64 全量清单**：那份清单是统一用 `--headless` 跑的，
##   而无头下改 `root.size` 视口并不跟着变 ⇒ 三档视口会是同一档、判据恒真 = **假绿**。
##   要收进全量，得先给跑批加"有头门"这一类（别的有头量具同理都在外面）。
## 跑：Godot --path . --script res://测试/相机屏幕像素对齐回归测试.gd
## ⚠ **不能加 --headless**：无头下改 `root.size` 视口并不跟着变（实测"视口图永远是工程设置那个尺寸"）
##   ⇒ 三档视口全变成同一档，这道门等于没判。带看门狗，超时自己 quit。
## ⚠ 只读不改存档（本门不点任何按钮、不落盘）。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"

var 条 := 0
var 红 := 0
var 日志 := PackedStringArray()
var 起毫秒 := 0
var 拍数 := 0


func _看门狗() -> void:
	拍数 += 1
	if Time.get_ticks_msec() - 起毫秒 > 90000:
		print("!! 看门狗超时（%d 帧）⇒ 强制退出，绝不挂死" % 拍数)
		for s in 日志:
			print(s)
		print("结论：判 %d 条 / 红 %d 条（未跑完）" % [条, 红])
		quit(2)


func _判(过: bool, 说: String) -> void:
	条 += 1
	if 过:
		日志.append("ok  " + 说)
	else:
		红 += 1
		日志.append("!!红 " + 说)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


## 小数部分（0 = 正好落在像素上；0.5 = 落在两像素正中）
func _小(a: float) -> float:
	var v := fposmod(a, 1.0)
	return minf(v, 1.0 - v)


## 递归找第一个 Camera2D。⚠ 别用 `find_all_children()` —— 这一版 Godot 里它不存在，
## 运行时报 "Nonexistent function" 会让整段判据**静默不跑**（判 0 条、退出码却像"没红"）。
func _找相机(从: Node) -> Camera2D:
	for c in 从.get_children():
		if c is Camera2D:
			return c as Camera2D
		var 深 := _找相机(c)
		if 深 != null:
			return 深
	return null


func _initialize() -> void:
	起毫秒 = Time.get_ticks_msec()
	process_frame.connect(_看门狗)
	_跑()


func _跑() -> void:
	var 景: Node = (load(地图场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
	var 们: Array = get_nodes_in_group("player")
	var 试 := 0
	while 们.size() == 0 and 试 < 600:
		await _帧(10)
		们 = get_nodes_in_group("player")
		试 += 10
	if 们.size() == 0:
		_判(false, "拿不到玩家（等了 %d 帧）⇒ 本门一条都没判成" % 试)
		_收尾()
		return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)
	await _帧(20)
	var 机: Camera2D = _找相机(景)
	_判(机 != null, "地图场景里有 Camera2D（没有本门判不了）")
	if 机 == null:
		_收尾()
		return

	# ── 两档视口：偶数（默认）与**奇数**（用户那种带栏全屏的等效情形）────────────
	for 尺 in [Vector2i(960, 560), Vector2i(961, 561), Vector2i(1023, 767)]:
		root.size = 尺
		await _帧(25)		# 等相机 _physics_process 重算 + 视口真的变了
		var 实得: Vector2i = root.size
		var ct: Transform2D = root.get_viewport().get_canvas_transform()
		var 屏: Vector2 = ct * 玩.global_position
		var 说 = "视口 %s（实得 %s，宽%s 高%s）⇒ 角色注册点屏幕位 %s 的小数 = (%.2f,%.2f) 必须是 0" % [
			尺, 实得, "奇" if 实得.x % 2 == 1 else "偶", "奇" if 实得.y % 2 == 1 else "偶",
			屏, _小(屏.x), _小(屏.y)]
		_判(实得 == 尺, "视口真的切到了 %s（切不动 = 这一档白测）" % 尺)
		_判(_小(屏.x) < 0.01 and _小(屏.y) < 0.01, 说)
		_判(_小(ct.origin.x) < 0.01 and _小(ct.origin.y) < 0.01,
				"视口 %s 画布偏移 %s 也必须落在整数上（.5 = 整幅画面被推到两像素正中 ⇒ 抖）" % [
					尺, ct.origin])
	# ── 钉"口径"本身：相机位置的小数必须等于半视口的小数（这才叫对齐到屏幕网格）──
	root.size = Vector2i(961, 561)
	await _帧(20)
	var 半 := Vector2(root.size.x * 0.5, root.size.y * 0.5)
	_判(absf(_小(机.global_position.x) - _小(半.x)) < 0.01
			and absf(_小(机.global_position.y) - _小(半.y)) < 0.01,
			"相机位置 %s 的小数 == 半视口 %s 的小数 ⇒ 取整落在**屏幕像素网格**上（老写法是 0，会红）" % [
				机.global_position, 半])
	root.size = Vector2i(960, 560)
	_收尾()


func _收尾() -> void:
	for s in 日志:
		print(s)
	print("结论：判 %d 条 / 红 %d 条" % [条, 红])
	quit(1 if 红 > 0 else 0)
