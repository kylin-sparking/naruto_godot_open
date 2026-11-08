## 点怪「走过去打」这条命令**走的是真寻路**，不是直线朝 x 挪。
##
## 真值：原版 `Monster.onMouseSelect():727` → `targetHandler.setCurTarget(this, true)` →
## `Character.toAttackAnemy` → `GuajiHandler` 的 A*（§3.56.17 / §3.61.4-A4）。
## 我们的实现：`玩家.开始自动接近(怪)` → `_冲选中目标` → `_维持接近路线` → 已有的 `走向()`
## （`click_move_*` + `自动寻路.plan()`），走路/爬梯/跳跃/下落四类动作都由它派。
##
## 为什么值得单独钉一条：这条路以前是「朝目标的 x 直线走」——同层平台看不出差别，
## 怪在上一层/下一层时，直线走会撞在墙根上永远够不着（也不去爬梯子）。
## 门里断言的是**路线本身**（`auto_actions` / `click_target_fh_id`），不是"走了几步"，
## 免得被地形细节带成偶发红。
extends SceneTree

var _failures: Array[String] = []
var _checked := 0
## 判满钉子：正常走到头**至少**判到这里（不含"跨平台那一条"，它在同平台时按原文打一行说明）。
## 协程被运行期报错打断时后面的 `_check` 一个都不会跑、末行照样能打"通过" —— 本工程已经栽过很多次，
## 所以条数不够直接算红。
const 应判满 := 18

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _finish() -> void:
	if _checked < 应判满:
		_failures.append("本门应判满 %d 条，实得 %d 条 ⇒ 中间被运行期报错打断了，末行的『通过』不作数"
				% [应判满, _checked])
	if _failures.is_empty():
		print("怪物接近寻路回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	## 红项一律带 `红：` 前缀、末行**红的时候也打一条**（与 `测试/挂机行为回归测试.gd` 同形状）：
	## 变异实测要靠"末行在不在"区分『门跑完了但红』与『门被运行期报错打断』，
	## 末行只在绿的时候打 ⇒ 变异体把这一条打断，门就永远只报"末行没打到"。
	for failure in _failures:
		print("红：" + failure)
	print("怪物接近寻路回归测试：判 %d 条，红 %d 条" % [_checked, _failures.size()])
	quit(1)

func _run() -> void:
	## ── 夹具先把"舞台"钉成设计尺寸 ────────────────────────────────────
	## 原版这条闸量的是 `Config.STAGE_WIDTH × STAGE_HEIGHT`（`DisplayUtil.as:170`，出厂 960×560
	## = `Config.as:176-178`）。Godot 里对应物 = 视口尺寸；**无头 `--script` 下根 Window 只有
	## 64×64**（实测 `get_visible_rect().size = (64.0, 64.0)`），镜头又按视口宽把自己居中在
	## 32 像素 ⇒ 玩家屏幕位 (32,160)、怪在 (313,387) ⇒ 全部算"舞台外" ⇒ `能攻` 恒假 ⇒
	## `_冲选中目标` 开头那一闸天天走 `_放掉追击`（10-20 这 4 条红的根子，量具问题不是逻辑问题）。
	## `测试/挂机行为回归测试.gd:77` 早就钉过同一颗钉（"无头视口默认 64×64，先钉成设计尺寸"），
	## 这两道门漏了它。参照值本门自己从工程配置算，不向被测对象要。
	var 设计 := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width")),
			float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	root.size = Vector2i(int(设计.x), int(设计.y))
	await process_frame
	_check(Vector2(root.size) == 设计,
			"夹具：无头舞台要钉成工程设计的 %s（实得 %s）—— 不钉的话 `能攻` 里的 `outOfStage` "
			% [str(设计), str(root.size)] + "量的是 64×64 的假视口，本门整段变成假红")

	var scene := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for _frame in 12:
		await process_frame
	var player := scene.get_node_or_null("Player")
	var life_root := scene.get_node_or_null("LifeRoot")
	var footholds := scene.get_node_or_null("Footholds")
	if player == null or life_root == null or footholds == null:
		_check(false, "地图场景缺少 Player / LifeRoot / Footholds")
		_finish()
		return
	_check(player.has_method("开始自动接近"), "玩家应实现 开始自动接近")
	_check(player.has_method("走向"), "玩家应实现 走向")

	var 玩家脚点 := String(player.get("current_fh_id"))
	_check(玩家脚点 != "", "玩家应站在某个脚点上（否则本条无从判起）")

	# 挑一只**还没进命中盒**的怪：进了盒的那只在命令生效的当帧就出招，不会排路线。
	var 目标: Node2D = null
	var 目标脚点 := ""
	for actor in life_root.get("_entities") as Array:
		var 怪 := actor as Node2D
		if 怪 == null or String(怪.get("kind")) != "m" or not bool(怪.get("alive")):
			continue
		var 落点: Dictionary = footholds.call("find_click_target", 怪.global_position)
		if float(落点.get("y", INF)) == INF:
			continue
		var 盒: Rect2 = player.call("攻击矩形")
		if (life_root.call("get_enemies_in_rect", 盒) as Array).has(怪):
			continue
		目标 = 怪
		目标脚点 = String(落点.get("id", ""))
		if 目标 != null and 目标脚点 != 玩家脚点:
			break   # 优先要跨平台的那只——它才是"直线走够不着"的样本
	if 目标 == null:
		_check(false, "地图里应有一只不在攻击盒内的怪可供接近")
		_finish()
		return

	## 前提钉子（2026-10-20 这 4 条红就是缺它才说不清是谁的锅）：`_冲选中目标` 开头那一道
	## `SkillExecute.moveToAttack():84` + `SkillHandler.canAttack:451`(`outOfStage`) 的闸，
	## 判的是 `_托管.能攻(目标)`。这只怪此刻必须算"能攻"，否则"排不出路线"到底是
	## 闸错了还是寻路错了根本分不开。
	var 托管: Node = player.get("_托管")
	_check(托管 != null, "夹具：玩家节点下应挂着 挂机托管（`_冲选中目标` 的那道闸挂在它身上）")
	if 托管 != null:
		_check(托管.has_method("能攻"), "夹具：挂机托管 应实现 能攻（原版 `SkillHandler.canAttack:443`）")
		if 托管.has_method("能攻"):
			_check(bool(托管.call("能攻", 目标)),
					"前提：挑中这一只要算『能攻』（四条按原序：没咬上别人 / 在舞台内 / 不是宠物怪 / 有身体盒且活着）")

	player.call("开始自动接近", 目标)
	_check(player.get("自动接近目标") == 目标, "开始自动接近 应把目标记进 自动接近目标")
	# 命令起手会 cancel 一次旧路线；给两帧让它跑一遍 `_维持接近路线`。
	for _frame in 3:
		await process_frame

	_check(not bool(player.get("出手中")), "接近途中不应已经出招（目标在盒外）")
	_check(String(player.get("click_target_fh_id")) == 目标脚点,
			"接近路线的终点应是目标脚下的脚点（期望 %s，实际 %s）"
			% [目标脚点, String(player.get("click_target_fh_id"))])
	var 路线: Array = player.get("auto_actions")
	_check(not 路线.is_empty(), "接近命令应排出一条非空路线（以前这条路是空的：直线走不排队）")
	_check(bool(player.get("click_move_active")), "路线排出来后 click_move_active 应为真")

	var 跨平台 := 目标脚点 != "" and 目标脚点 != 玩家脚点
	var 有地形动作 := false
	for action in 路线:
		if String((action as Dictionary).get("type", "")) in ["climb", "jump", "drop"]:
			有地形动作 = true
	if 跨平台:
		_check(有地形动作, "目标在另一块平台上时，路线里应有 climb/jump/drop（直线走够不着的那种）")
	else:
		print("怪物接近寻路回归测试：本图选中的怪与玩家同平台（%s），跨平台那条断言本轮没验" % 目标脚点)

	# 玩家自己一动 → 命令立刻取消（§3.56.17 的口径），但选中目标保留。
	player.call("cancel_auto_path")
	player.set("自动接近目标", null)
	_check(not bool(player.get("click_move_active")), "取消命令后不应还留着路线")

	## 阳性对照（上面那条"前提：能攻"必须有人证它不是恒真）：把同一只怪搬到舞台之外，
	## `能攻` 就得翻成假 —— 原版 `SkillHandler.canAttack:451` + `DisplayUtil.outOfStage:152-185`。
	## 这一条红 ⇒ 那道闸整条失效（挂机又会去追看不见的怪）；它绿而"前提"那条也绿，才算判到东西。
	if 托管 != null and 托管.has_method("能攻"):
		var 舞台内位: Vector2 = 目标.global_position
		目标.global_position = 舞台内位 + Vector2(9000.0, 0.0)
		_check(not bool(托管.call("能攻", 目标)),
				"阳性对照：把这只怪搬到舞台外 ⇒ 能攻 必须变假（实得还是真 ⇒ `outOfStage` 那道闸恒真、"
				+ "上面那条『前提』等于没判）")
		目标.global_position = 舞台内位			# 搬回来，下面两条还要用这只怪

	## ── 10-20 补的两条：本轮改的正是 `_在画面内` 的两个**取量**，改错了得有门说 ──
	## ① `DisplayUtil.as:161-169`：`if (param1.width > 0) getRect(stage) else new Rectangle(localToGlobal(0,0), 2, 2)`
	##    ⇒ 这一帧没有墨迹盒时原版退化成**它原点处一枚 2×2 的点盒**，**不是**"在舞台外"；
	##    "这只没有 `outerBodyRect` 所以打不了"是 `SkillHandler.canAttack:455-458` 那一档判的
	##    （`_loc3_ = Boolean(param1["outerBodyRect"]) && !isDie`）⇒ 两条各判各的：
	##    画面内要真、能攻要假。以前这两档被并成一条"盒为空就算画面外"。
	var 精灵: Node = 目标.get_node_or_null("Sprite")
	_check(精灵 != null, "夹具：这只怪节点下要挂着 Sprite（`_怪物体型盒` 从它取逐帧 lt/rb 墨迹盒）")
	if 精灵 != null and 托管 != null:
		var 原动作: Variant = 精灵.get("action")
		var 原站位: Vector2 = 目标.global_position
		## 退化那一支用的是**它自己那个点**（`localToGlobal(0,0)` = 脚底注册点），站位太靠边
		## 就会量到舞台外去（本图这只怪的脚点正好压在镜头下沿外面 1 像素）⇒ 先把这只搬到
		## **玩家自己脚下**（镜头一定把它框在舞台里），退化成 2×2 之后必然在画面内，这才判得干净。
		目标.global_position = (player as Node2D).global_position
		精灵.set("action", "_这一档不存在_")		# `当前身体矩形()` 查不到 lt/rb ⇒ 回空 Rect2
		_check(bool(托管.call("_在画面内", 目标)),
				"没有墨迹盒的怪仍要算在画面内（原版那支退化成原点处 2×2 点盒，`DisplayUtil.as:165-169`；"
				+ "写成『盒取不到就算舞台外』这一条会红）")
		_check(not bool(托管.call("能攻", 目标)),
				"但『没有 outerBodyRect』那一档照样要把这只判成打不了"
				+ "（`SkillHandler.canAttack:455-458` ⇒ 本工程 `能攻` 最后一行；实得能攻=真 就是把两档并掉了一档）")
		精灵.set("action", 原动作)
		目标.global_position = 原站位

	## ② 舞台矩形那把尺的**原版下限**（`Game.as:76-95 onResizeHand`：宽 < `STAGE_MIN_WIDTH=600`
	##    补成 600、高 < `STAGE_MIN_HEIGHT=400` 补成 400，`Config.as:184-186`）——
	##    窗口再小，原版量出去的那把尺最短就是 600×400，不跟着视口缩。
	##    无头门禁的 64×64 就落在这条下限之下，所以这条同时也是"上面那些判据为什么不拿裸视口量"的根。
	if 托管 != null:
		var 正常窗 := root.size
		root.size = Vector2i(64, 64)
		await process_frame
		var 量到的舞台: Rect2 = 托管.call("_舞台矩形")
		_check(量到的舞台.size == Vector2(600.0, 400.0),
				"视口退化到 64×64 时舞台矩形要按原版下限回 600×400（`Game.as:88-95` 夹 STAGE_MIN、"
				+ "`Config.as:184-186`），实得 %s ⇒ 跟着裸视口缩就是本轮那 6 条红的形状" % str(量到的舞台))
		root.size = 正常窗

	_finish()
