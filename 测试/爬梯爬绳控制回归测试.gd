## 爬梯 / 爬绳：爬到顶端那一下是**上跳**（原版 `KeyController.tick():1441-1449`）。
## 本门钉的是**用户 2026-10-31 第三条口径**：爬顶那一跳**保留左右移动**，但**带惯性**
## （不是 §3.321 那种逐帧直写走速，也不是锁到落地）—— 按 `走速 / 0.15s` 的斜率渐加速。
##
## 原版真值（`KeyController.tick()`）：
##   · `:1441-1449`：ROPE/LADDER 只要 `!grounded` 就翻成 JUMP（`climbing=false`，速度原样保留）
##     —— 爬到顶越过绳端就是这一支，所以顶上的那一下是**跳**；攀爬时 `x` 一直是 0 ⇒ 原地直上。
##     ⚠ 竖直速度**有意偏离**：原版保留的 `climbSpeed = 125 × walkSpeedFactor`
##     （`AbstractPhysicObject.as:600`）带移动速度属性 ⇒ 爬顶高度随移速涨；本工程按用户
##     2026-10-31 口径钉成「普通起跳高度 + 基础速度那一跳的高度」= √(666² + 175²) ≈ 688.608
##     （175 是属性 100 的原版口径），**不吃 live `climb_speed`**，见 ①b 腿。
##   · `:1375-1395`：JUMP 档左右键**只改 direction**，不写水平速度。**爬顶这一跳有意偏离**：
##     用户要求它能左右动，只是要"渐加速"而不是瞬间满速。
##   · `:1396-1408`：JUMP 且 `grounded` ⇒ STAND，`setVelocity({x:0})`。
##   · `:1414-1440`：绳/梯上「跳+左/右」离开 ⇒ JUMP，`setVelocity({x:±walkSpeed, y:-jumpSpeed/2})`。
##
## 本工程要钉住的三件事：
##   ① 爬顶脱开后是 JUMP 态（`跳起中` + `爬顶跳中`），**竖直起跳速度 = √(起跳² + 175²)**
##      （普通起跳 + 基础爬跳；不吃移速，用户 2026-10-31 口径），左右键**能**动，但**第一帧
##      只加一小截**、约 0.15 秒才到走速（含「跳上绳再爬」把起跳锁带上来的那一趟）；
##   ①c 爬顶这一跳的**上升高度**与普通起跳对账：二者只差「基础速度那一跳」≈ 7.7 像素；
##   ② 从梯上「跳+方向」离开必须当场带 ±走速（§3.320 锁空中控制后曾被漏成原地直上）；
##   ③ **普通跳跃不许**沾这条：起跳后左右只改朝向、横向速度不动（`:1375-1395` 原版）。
extends SceneTree

const 地图路 := "res://场景/地图/地图场景.tscn"
const 帧 := 1.0 / 60.0

var _失败: Array[String] = []
var _条数 := 0
var _已收尾 := false
var _秒 := 0.0
var _玩: Node = null
var _梯: Dictionary = {}
var _图: Node = null
var _爬顶升高 := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _process(delta: float) -> bool:
	if _已收尾:
		return false
	_秒 += delta
	if _秒 > 90.0:
		printerr("爬梯爬绳控制回归测试：超时 90 秒，判红")
		quit(1)
		return true
	return false

func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)

func _收键() -> void:
	for 键 in ["ui_left", "ui_right", "ui_up", "ui_down", "jump"]:
		Input.action_release(键)

## 把玩家**硬摆**到绳上（climbing 真），绕开吸附与上一段留下的状态。
func _摆上(顶: float, y: float, 跳起中: bool) -> void:
	_收键()
	_玩.set("climbing", true)
	_玩.set("自动爬梯中", false)
	_玩.set("click_move_active", false)
	_玩.set("position", Vector2(float(_梯.x), y))
	_玩.set("velocity", Vector2(0.0, -float(_玩.get("climb_speed"))))
	_玩.set("on_ground", false)
	_玩.set("current_fh_id", "")
	_玩.set("跳起中", 跳起中)
	_玩.set("ladder_cooldown", 0.0)
	_玩.set("jump_was_pressed", false)

func _步(n: int) -> void:
	for _i in n:
		_玩._physics_process(帧)

func _位() -> Vector2:
	return _玩.get("position") as Vector2

func _速() -> Vector2:
	return _玩.get("velocity") as Vector2

func _run() -> void:
	_图 = (load(地图路) as PackedScene).instantiate()
	root.add_child(_图)
	for _i in 20:
		await physics_frame
	_玩 = get_first_node_in_group("player")
	if _玩 == null:
		_断言(false, "场景里没有玩家，本门判不了")
		_finish()
		return
	_玩.set_physics_process(false)
	var 梯根 = _玩.get("ladder_root")
	if 梯根 == null:
		_断言(false, "玩家上没有 ladder_root")
		_finish()
		return
	## 挑一把够长的攀爬物：短于 40 像素的测不出「爬上去」这一路。
	for l in 梯根.get("ladders"):
		if float(l.y2) - float(l.y1) > 40.0:
			_梯 = l.duplicate()
			break
	_断言(not _梯.is_empty(), "这张图至少要有一把 40 像素以上的梯子/绳")
	if _梯.is_empty():
		_finish()
		return
	var 顶 := float(_梯.y1)
	var 走 := float(_玩.get("move_speed"))
	_断言(走 > 0.0, "走路速度应 > 0，实得 %s" % str(走))

	# ── ① 普通上爬到顶（此前没跳过）：进入空中 JUMP 态，竖直速度 = √(666² + 175²) ──
	_摆上(顶, 顶 - 10.0, false)
	_步(2)
	_断言(not bool(_玩.get("climbing")), "爬到顶应脱离攀爬态")
	_断言(not bool(_玩.get("on_ground")), "爬顶起跳途中不应已落地")
	## 竖直速度是「普通起跳 + 基础速度那一跳」：√(666² + 175²) ≈ 688.608，**不许**跟着
	## `climb_speed`（移动速度属性）涨（用户 2026-10-31 口径；175 = `CLIMB_SPEED 125 × 1.4`）。
	## 脱开那一帧起已经过重力（`Physics.GRAVITY_ACC = 2000`）⇒ 两帧后期望 688.608 − 2 × 2000/60。
	var 期望vy := -(688.608 - 2000.0 * 帧 * 2.0)
	_断言(absf(_速().y - 期望vy) < 0.5,
			"爬顶那一下的竖直速度应为 −688.608（两帧重力后 %.2f），实得 %.2f" % [期望vy, _速().y])
	_断言(absf(_速().x) < 0.01,
			"爬顶那一跳的初始水平速度应原样保留（攀爬时 x=0），实得 %s" % str(_速()))
	_断言(bool(_玩.get("跳起中")) and bool(_玩.get("爬顶跳中")),
			"爬到顶要进 JUMP 档并标记爬顶跳（跳起中/爬顶跳中 都应为 true），实得 %s/%s"
			% [str(_玩.get("跳起中")), str(_玩.get("爬顶跳中"))])

	# ── ①b 高度**不跟移速**：攀爬速度抬到 481.25（属性 275 档）再爬一次，竖直速度不变 ──
	var 原爬速 := float(_玩.get("climb_speed"))
	_玩.set("climb_speed", 481.25)
	_摆上(顶, 顶 - 10.0, false)
	_步(2)
	_断言(absf(_速().y - 期望vy) < 0.5,
			"攀爬速度 481.25 时爬顶竖直速度也应仍是 %.2f（继承 climb_speed 会到 −547.92，高度随移速涨），实得 %.2f"
			% [期望vy, _速().y])
	_玩.set("climb_speed", 原爬速)

	# ── ①c 高度对账：爬顶上升 = 普通起跳那一份 + 基础速度那一跳那一份 ───────────
	## 连续口径 105.34 + 7.66 ≈ 113 px；离散积分实测约 112.9（旧口径 175 只升 ~6.25）。
	_摆上(顶, 顶 - 10.0, false)
	var 最高 := 顶
	for _i in 60:
		_步(1)
		最高 = minf(最高, _位().y)
		if float(_速().y) >= 0.0:
			break
	_爬顶升高 = 顶 - 最高
	_断言(_爬顶升高 > 108.0 and _爬顶升高 < 118.0,
			"爬顶那一跳应升约 113 px（普通起跳 105 + 基础爬跳 7.6），实得 %.2f（旧口径 175 只有 ~6）"
			% _爬顶升高)

	# ── ② 起跳途中按左右：能动，但按 `走速/0.15s` 渐加速（不是逐帧直写满速）──────
	## 为了把横向斜坡与重力解耦（不关心此刻在上升还是下落），这一段临时把重力关掉，
	## 量完立刻恢复；落地那一段（③）用的是恢复后的真重力。
	var 原重力 := float(_玩.get("gravity"))
	_玩.set("gravity", 0.0)
	var 步进 := 走 / 0.15 / 60.0		# 一帧该加多少（1/60 秒 × 加速度）
	var x0 := _位().x
	Input.action_press("ui_right")
	_步(1)
	_断言(absf(_速().x - 步进) < 1.0,
			"按右第 1 帧应只加 %.1f（渐加速），实得 %.2f" % [步进, _速().x])
	_步(5)
	_断言(absf(_速().x - 步进 * 6.0) < 1.0,
			"按住右 6 帧应到 %.1f（约 2/3 走速），实得 %.2f" % [步进 * 6.0, _速().x])
	_步(3)
	_断言(absf(_速().x - 走) < 1.0,
			"按住右 9 帧（0.15s）应到满走速 %.2f，实得 %.2f" % [走, _速().x])
	var dx := _位().x - x0
	_断言(dx > 1.0 and dx < 走 * 9.0 / 60.0 * 0.8,
			"这 9 帧位移应明显小于瞬间满速的 %.1f 像素，实得 dx=%.3f"
			% [走 * 9.0 / 60.0, dx])
	_断言(int(_玩.get("facing")) == 1, "按右朝向应为右")
	Input.action_release("ui_right")
	Input.action_press("ui_left")
	_步(1)
	_断言(_速().x > 走 * 0.5,
			"改按左第 1 帧不许瞬间反向（渐加速：先刹再反），实得 %.2f" % _速().x)
	_步(9)
	_断言(_速().x < 0.0,
			"继续按左到 10 帧应已越过 0（往左加速），实得 %.2f" % _速().x)
	_断言(int(_玩.get("facing")) == -1, "朝向要跟着左键改")
	_断言(not bool(_玩.get("on_ground")),
			"这一段必须全程在空中，否则「能横移」是落地后白测")
	_玩.set("gravity", 原重力)
	_收键()

	# ── ③ 落地：一切照常（落点由落脚判定吸附，之后能正常走）─────────────────
	var 落帧 := 0
	while 落帧 < 240 and not bool(_玩.get("on_ground")):
		_步(1)
		落帧 += 1
	_断言(bool(_玩.get("on_ground")), "爬顶起跳应在 240 帧内落回平台（实得 %d 帧）" % 落帧)
	_断言(not bool(_玩.get("跳起中")), "落地必须清掉 JUMP 锁（跳起中 回到 false）")
	var x2 := _位().x
	Input.action_press("ui_right")
	_步(10)
	_收键()
	_断言(_位().x > x2 + 5.0, "落地后按右应恢复走路（实得 dx=%.3f）" % (_位().x - x2))

	# ── ④ 从绳/梯上「跳+右」离开：当场给 +走速，之后不许再翻向 ─────────────────
	_摆上(顶, (顶 + float(_梯.y2)) * 0.5, false)
	Input.action_press("jump")
	Input.action_press("ui_right")
	_步(1)
	_收键()
	_断言(not bool(_玩.get("climbing")), "「跳+方向」应离开攀爬态")
	_断言(bool(_玩.get("跳起中")), "跳离绳/梯应进 JUMP 态")
	_断言(absf(_速().x - 走) < 0.01,
			"跳离时水平速度应当场定为 +走速（tick:1414-1440），实得 %s" % str(_速()))
	_断言(_速().y < -100.0, "跳离应带向上的 −跳速/2，实得 %s" % str(_速()))
	Input.action_press("ui_left")
	_步(6)
	_收键()
	_断言(absf(_速().x - 走) < 0.01,
			"跳离后改按左键不许翻向（JUMP 无空中控制），实得 %s" % str(_速()))
	_断言(int(_玩.get("facing")) == -1, "但朝向要跟着左键改")

	# ── ⑤ 跳上去再爬（带着 跳起中 上来）到顶：照样进爬顶跳，照样能渐加速横移 ──────
	_摆上(顶, 顶 - 10.0, true)
	_步(2)
	_断言(not bool(_玩.get("climbing")) and not bool(_玩.get("on_ground")),
			"带 跳起中 爬到顶也应脱开攀爬、还在空中")
	_断言(bool(_玩.get("跳起中")) and bool(_玩.get("爬顶跳中")),
			"两条上爬路径到顶都必须进爬顶跳（跳起中/爬顶跳中 都应为 true），实得 %s/%s"
			% [str(_玩.get("跳起中")), str(_玩.get("爬顶跳中"))])
	Input.action_press("ui_right")
	_步(3)
	_断言(absf(_速().x - 步进 * 3.0) < 1.0,
			"带 跳起中 上来的那趟，按右 3 帧应到 %.1f（渐加速，不是满速 %.1f），实得 %.2f"
			% [步进 * 3.0, 走, _速().x])
	_收键()

	# ── ⑥ 普通跳跃不许沾这条：起跳后左右只改朝向、横向速度不动（原版 :1375-1395）─
	_收键()
	_步(120)
	_断言(bool(_玩.get("on_ground")), "普通跳跃那一段的前置：得先站回地面")
	if bool(_玩.get("on_ground")):
		var 跳前y := _位().y
		Input.action_press("jump")
		_步(1)
		Input.action_release("jump")
		_断言(not bool(_玩.get("on_ground")) and not bool(_玩.get("爬顶跳中")),
				"普通起跳应离开地面且不进爬顶跳（爬顶跳中 应为 false），实得 %s"
				% str(_玩.get("爬顶跳中")))
		var x5 := _位().x
		Input.action_press("ui_right")
		_步(10)
		_收键()
		_断言(absf(_速().x) < 0.01 and absf(_位().x - x5) < 0.01,
				"普通跳跃中按右不许平移（只有爬顶那一跳能横移），实得 vx=%.2f dx=%.3f"
				% [_速().x, _位().x - x5])
		_断言(int(_玩.get("facing")) == 1, "但朝向照旧跟着右键改")
		## ⑥b 与 ①c 对账：爬顶跳的上升高度 = 普通起跳 + 基础速度那一跳（连续口径差 ≈ 7.66 px）。
		var 最低y := 跳前y
		for _i in 40:
			_步(1)
			最低y = minf(最低y, _位().y)
			if float(_速().y) >= 0.0:
				break
		var 普通跳高 := 跳前y - 最低y
		var 高差 := _爬顶升高 - 普通跳高
		_断言(高差 > 4.0 and 高差 < 9.0,
				"爬顶跳应比普通起跳高约 7.7 px（普通 %.2f / 爬顶 %.2f，实差 %.2f）"
				% [普通跳高, _爬顶升高, 高差])

	_finish()

func _finish() -> void:
	_已收尾 = true
	_收键()
	if _玩 != null and is_instance_valid(_玩):
		_玩.set_physics_process(true)
	if _图 != null:
		_图.queue_free()
	if _失败.is_empty():
		print("爬梯爬绳控制回归测试：通过（%d 条断言）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr("红：" + 条)
	print("爬梯爬绳控制回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
