## 跳跃 / 下+跳跃穿台 —— 落点与"掉到地平线以下"回归门（用户 2026-10-30 报）。
##
## 原版真值：
##   · `KeyController.tick():1275-1297` 只在 STAND/WALK/SIT0 三档写水平速度；JUMP 那一档
##     （`:1375-1395`）**只改朝向** ⇒ 起跳后没有空中控制，横向速度停在起跳那一下：
##     `jumpRight/LeftTarget():488/1623` 给 ±walkSpeed、`jumpUpTarget():626` 给 0、
##     `jumpDownTarget():1592-1601`（下+跳穿台）恒为 `x:0, y:0`；落地 `:1396-1408` 清 x。
##   · `AbstractPhysicObject.checkAbyss():722-736`（`Character.as:2565-2571` 每帧在
##     `applyVelocity` 之后调）：x 夹回 `[minX+2, maxX-2]` 并清水平速度，y 夹到这一列的
##     `getLowestYByX(x)`（最低水平地面，见 `地表.最低地面y()`）⇒ 原版掉不到地平线以下。
##
## 本工程旧行为（两条根因）：每帧 `velocity.x = dir × move_speed`（空中也照写）、
## 穿台只在禁寻路图清 x，且**没有 checkAbyss** ⇒ 空中按方向键 / 带方向穿台会飘出平台边，
## 再一路掉出地图底边。门的层次：
##   ① JUMP 无空中控制（站着跳 / 走着跳 / 穿台三支，含朝向仍可改）；
##   ② 落地当帧清 x；③ 自动寻路空中转向这个**有意例外**仍然有效；
##   ④ 真实地图上探针量到的翻车点逐点落得住；⑤ checkAbyss 夹回的最低地面；
##   ⑥ 竖直端面是**单向墙**：从平台沿下方起跳横向离台，不许被端面假挡（2026-10-31 报）；
##   ⑦ 斜坡落点按**整帧位移扫掠**求交：一帧内脚已穿过坡面，也要落在坡上（2026-11-02 报）；
##   ⑧ 站着走出小平台尽头必须离地下落（2026-11-02 报「移动到尽头不会下落，必须跳跃」）。
extends SceneTree

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 语义图 := "101010000"		# 终结谷浅滩：段 36 是 2280 长的平地，适合跑语义
const 翻车图 := "403000000"		# 命运之抉择：探针量到的三个翻车点在这张图
const 沿台图 := "100000000"		# 木叶村：71 高台的右端面 72 正好压在 52 台上方
const 帧 := 1.0 / 60.0

var _失败: Array[String] = []
var _条数 := 0
var _已收尾 := false
var _秒 := 0.0
var _场景: Node = null
var _玩: Node = null
var _地表: Node = null

func _initialize() -> void:
	call_deferred("_run")

## 门里崩了不会报红、只会挂死 ⇒ 看门狗兜底。
func _process(delta: float) -> bool:
	_秒 += delta
	if not _已收尾 and _秒 > 120.0:
		printerr("跳跃穿台落点回归测试：看门狗超时（120s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false

func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)

func _run() -> void:
	if not await _载图(语义图):
		_finish()
		return

	var 走 := float(_玩.get("move_speed"))
	_断言(走 > 0.0, "走路速度应 > 0，实得 %s" % str(走))

	var 长段 := _长平台()
	if 长段.is_empty():
		_断言(false, "%s 找不到长平地，语义断言无法进行" % 语义图)
		_finish()
		return
	var 中点 := (float(长段.x1) + float(长段.x2)) * 0.5

	# ── ①a 站着起跳：jumpUpTarget:626 ⇒ x = 0，空中按右键不产生位移 ──────────
	_站上(长段, 中点)
	_按跳()
	_断言(_速度().y < -600.0, "起跳该给竖向 −跳速，实得 %s" % str(_速度()))
	_断言(absf(_速度().x) < 0.01, "站着起跳横向速度应为 0（jumpUpTarget:626），实得 %s" % str(_速度()))
	var 跳x := _位置().x
	Input.action_press("ui_right")
	_步(10)
	Input.action_release("ui_right")
	_断言(absf(_速度().x) < 0.01 and absf(_位置().x - 跳x) < 0.01,
			"JUMP 途中按右键不许产生横向位移（原版 tick:1375-1395 只改朝向）；vx=%s dx=%.2f"
			% [str(_速度().x), _位置().x - 跳x])
	_断言(int(_玩.get("facing")) == 1, "JUMP 途中按右键仍要改朝向（原版 :1385-1395）")

	# ── ①b 走着起跳：jumpRightTarget:1623 ⇒ 朝向×走速；空中改按左键也不许翻速度 ──
	_站上(长段, 中点 - 120.0)
	Input.action_press("ui_right")
	_步(1)
	_按跳()
	_断言(absf(_速度().x - 走) < 0.01, "走着起跳横向速度 = +走速（jumpRightTarget:1623），实得 %s" % str(_速度()))
	Input.action_release("ui_right")
	Input.action_press("ui_left")
	var 跳x2 := _位置().x
	_步(8)
	Input.action_release("ui_left")
	_断言(absf(_速度().x - 走) < 0.01 and _位置().x > 跳x2,
			"JUMP 中途松右键改按左键：横向速度必须仍是 +走速（没有空中控制），实得 vx=%s dx=%.2f"
			% [str(_速度().x), _位置().x - 跳x2])
	_断言(int(_玩.get("facing")) == -1, "但朝向要跟着左键改（原版只改 direction）")

	# ── ①c 下+跳跃穿台：jumpDownTarget:1592 ⇒ x:0, y:0，途中按键不横移 ──────
	var 洞 := _找穿台点()
	if 洞.is_empty():
		_断言(false, "%s 找不到可穿的下一层，穿台断言无法进行" % 语义图)
	else:
		# 先直接钉 `_穿台下落()` 本身：带着横向速度进去也必须清零
		_站上(洞.段, float(洞.x))
		_玩.set("velocity", Vector2(走, 0.0))
		_玩.call("_穿台下落")
		_断言(absf(_速度().x) < 0.01,
				"穿台下落本身必须清零横向速度（jumpDownTarget:1596 x:0，与地图族无关），实得 %s" % str(_速度()))
		# 再跑真按键路径：先按着右键走起来，再下+跳
		_站上(洞.段, float(洞.x))
		Input.action_press("ui_right")
		_步(1)
		Input.action_press("ui_down")
		Input.action_press("jump")
		_步(1)
		Input.action_release("jump")
		_断言(not bool(_玩.get("on_ground")), "下+跳跃应触发穿台（离地）")
		_断言(absf(_速度().x) < 0.01, "穿台那一下横向速度必须清零（jumpDownTarget:1596 x:0），实得 %s" % str(_速度()))
		var 落x := _位置().x
		_步(8)
		_断言(absf(_速度().x) < 0.01 and absf(_位置().x - 落x) < 0.01,
				"穿台下落途中按右键不许横移；vx=%s dx=%.2f" % [str(_速度().x), _位置().x - 落x])
		Input.action_release("ui_right")
		Input.action_release("ui_down")

	# ── ② 落地当帧清 x（tick:1396-1408），并清 跳起中 ────────────────────────
	_站上(长段, 中点 - 120.0)
	Input.action_press("ui_right")
	_步(1)
	_按跳()
	var 落帧 := _步到落地(180)
	Input.action_release("ui_right")
	_断言(bool(_玩.get("on_ground")), "起跳后应落回平台（%d 帧内）" % 落帧)
	_断言(absf(_速度().x) < 0.01, "JUMP 落地当帧横向速度清 0（tick:1396-1408），实得 %s" % str(_速度()))
	_断言(not bool(_玩.get("跳起中")), "落地后 跳起中 该清")

	# ── ③ 自动寻路的空中转向是**有意例外**（`_走点击路线()` 的 landing_delta）───
	_站上(长段, 中点)
	_玩.set("click_move_active", true)
	_玩.set("auto_actions", [{
		"type": "jump", "x": 中点, "landing_x": 中点 + 120.0,
		"direction": 1, "target_component": 0, "down": false,
	}])
	_玩.set("auto_action_index", 0)
	_玩.set("auto_jump_direction", 1)
	_玩.set("on_ground", false)
	_玩.set("跳起中", true)
	_玩.set("current_fh_id", "")
	_玩.set("position", Vector2(中点 - 60.0, _段面y(长段, 中点) - 40.0))
	_玩.set("velocity", Vector2(0.0, -100.0))
	_步(1)
	_断言(_速度().x > 0.01, "自动寻路起跳后应能靠 dir 对准落点（本工程路线执行器的例外），实得 %s" % str(_速度()))
	_玩.set("click_move_active", false)
	_玩.set("auto_actions", [])
	_玩.set("auto_action_index", 0)

	# ── ⑤ checkAbyss：低于最低地面时当帧夹回，随后站住 ─────────────────────
	var 夹x := (float(长段.x1) + float(长段.x2)) * 0.5
	var 最低 := _最低(夹x)
	_断言(最低 != INF, "长平台中点这一列应有最低地面")
	_玩.set("position", Vector2(夹x, 最低 + 500.0))
	_玩.set("current_fh_id", "")
	_玩.set("on_ground", false)
	_玩.set("跳起中", true)
	_玩.set("climbing", false)
	_玩.set("velocity", Vector2(0.0, 300.0))
	_玩._physics_process(帧)
	_断言(absf(_位置().y - 最低) < 1.0,
			"掉到最低地面以下要当帧夹回（checkAbyss:722-736），实得 y=%s 最低=%s" % [str(_位置().y), str(最低)])
	for _i in 3:
		_玩._physics_process(帧)
	_断言(bool(_玩.get("on_ground")) and String(_玩.get("current_fh_id")) != "",
			"夹回后应站在最低地面上，实得 on_ground=%s fh=%s y=%s"
			% [str(_玩.get("on_ground")), String(_玩.get("current_fh_id")), str(_位置().y)])

	# ── ⑥ 竖直端面单向：从平台沿下方起跳横向离台，不许被端面假挡 ─────────────
	## 木叶村：71 号高台在 y=637（x 2140..2317），52 号台在它下面 y=669，
	## 71 的右端面是 72 号竖段（y1=637 < y2=653）。原版 `checkFoothold():297-371` 拿
	## `GVector.findIntersection():108-136` 求交，那道 `dotProduct(位移, 法线) < 0` 用的法线
	## 是 `(y2-y1, 0)` ⇒ `y1 < y2` 只挡**向左**，向右跳出去原版根本不认交点。
	## 从 2280 起跳按住右键：脚在 y 637..653 那条带里跨过 x=2317。旧代码两边都挡，
	## 上升那三帧横向被钉在 2316（`vy` 上升、vx 不清，所以之后又弹出去）—— 手感上就是
	## 用户 2026-10-31 报的「移动起跳会被阻碍 / 从平台下方起跳，碰到平台会挡着」。
	## 174 张图全扫：旧语义 942 个空中卡点里有 309 个是这种反向假挡，改后 0 个。
	if not await _载图(沿台图):
		_finish()
		return
	var 表沿: Dictionary = _地表.get("id_map") as Dictionary
	var 台52: Dictionary = 表沿.get("52", {})
	var 台71: Dictionary = 表沿.get("71", {})
	var 墙72: Dictionary = 表沿.get("72", {})
	_断言(float(台71.get("y1", 0)) == 637.0 and float(台52.get("y1", 0)) == 669.0
			and float(墙72.get("x1", 0)) == 2317.0
			and float(墙72.get("y1", 0)) < float(墙72.get("y2", 0)),
			"%s 真值应有 71 高台 y=637、52 台 y=669、72 端面 x=2317 且 y1<y2" % 沿台图)
	if 台52.is_empty():
		_断言(false, "%s 找不到 52 号台，起跳腿无法进行" % 沿台图)
	else:
		_站上(台52, 2280.0)
		Input.action_press("ui_right")
		_步(1)
		_按跳()
		var 沿卡 := 0
		var 沿前 := _位置().x
		for _i in 40:
			_玩._physics_process(帧)
			if not bool(_玩.get("on_ground")) and absf(_速度().x) > 1.0 \
					and absf(_位置().x - 沿前) < 0.4:
				沿卡 += 1
			沿前 = _位置().x
		Input.action_release("ui_right")
		_断言(沿卡 == 0 and _位置().x > 2380.0,
				"从 71 高台底下起跳右移，不许在 72 号端面被假挡（旧代码上升三帧钉在 2316）；实得 卡帧=%d x=%.1f"
				% [沿卡, _位置().x])

	# ── ④ 真实地图翻车点：探针量到旧行为会掉出地图底的采样点，逐点落得住 ────
	if not await _载图(翻车图):
		_finish()
		return
	# 点位来自 `.scratch/_探针_落出点明细.gd` / `_探针_旧版越界.gd`（只读探针）。
	# 旧语义在 403000000 段4 带方向穿台会飘进井壁、掉到 y≈2023（该列最低地面只有 1175）；
	# 新语义穿台 x=0 直落，落回井底平台。跳跃那两条是「原地起跳、空中再按住右键」——
	# 正是用户说的"跳跃移动"：旧代码每帧写 `dir×走速` 会横飘，新代码空中没有控制。
	var 翻车点 := [
		{"段": "4", "x": 1169.5, "穿台": true, "说": "命运之抉择 段4 带方向穿台"},
		{"段": "13", "x": 3760.3, "穿台": false, "说": "命运之抉择 段13 右边缘起跳后空中按右"},
		{"段": "50", "x": 3796.4, "穿台": false, "说": "命运之抉择 段50 右边缘起跳后空中按右"},
	]
	for 点 in 翻车点:
		var 段: Dictionary = (_地表.get("id_map") as Dictionary).get(String(点.段), {})
		if 段.is_empty():
			_断言(false, "%s 脚点 %s 不在表里" % [点.说, 点.段])
			continue
		_站上(段, float(点.x))
		if bool(点.穿台):
			Input.action_press("ui_right")
			Input.action_press("ui_down")
			Input.action_press("jump")
			_步(1)
			Input.action_release("jump")
			Input.action_release("ui_down")
		else:
			_按跳()
			Input.action_press("ui_right")
		var 越线 := false
		var 帧数 := 0
		while 帧数 < 300 and not bool(_玩.get("on_ground")):
			_玩._physics_process(帧)
			帧数 += 1
			var 逐帧最低 := _最低(_位置().x)
			if 逐帧最低 != INF and _位置().y > 逐帧最低 + 1.0:
				越线 = true
		Input.action_release("ui_right")
		_断言(bool(_玩.get("on_ground")) and String(_玩.get("current_fh_id")) != "",
				"%s：应在 300 帧内落到脚点上，实得 on_ground=%s fh=%s pos=%s"
				% [点.说, str(_玩.get("on_ground")), String(_玩.get("current_fh_id")), str(_位置())])
		_断言(not 越线, "%s：下落/跳跃途中 y 不许超过该列最低地面（checkAbyss:722-736）" % 点.说)
		if bool(_玩.get("on_ground")):
			_断言(_位置().y <= _最低(_位置().x) + 1.0,
					"%s：最终落点 y 应在最低地面之上，落点 %s 最低 %s"
					% [点.说, str(_位置()), str(_最低(_位置().x))])

	# ── ⑦ 斜坡落点：整帧位移扫掠求交（2026-11-02 报「跳到当前平台下面，一般有斜坡」）──
	# 原版真值：`AbstractPhysicObject.checkFoothold():373-389` 拿**这一帧的位移向量**与脚点
	# `GVector.findIntersection():108-136` 求交。老代码只按落点这一列取面 + `gy >= 前y-1`，
	# 斜坡一帧抬升 >1px 就把已经穿过的坡面判掉 ⇒ 人从坡里穿下去、落到下面的平台。
	if not await _载图("100010000"):
		_finish()
		return
	var 坡: Dictionary = (_地表.get("id_map") as Dictionary).get("14", {})
	var 坡下平: Dictionary = (_地表.get("id_map") as Dictionary).get("15", {})
	var 底平: Dictionary = (_地表.get("id_map") as Dictionary).get("49", {})
	_断言(not 坡.is_empty() and int(坡.x1) == 673 and int(坡.y1) == 327
			and int(坡.x2) == 763 and int(坡.y2) == 387,
			"100010000 段14 应是 (673,327)→(763,387) 的斜段（地图 JSON 真值），实得 %s" % str(坡))
	_断言(not 坡下平.is_empty() and int(坡下平.y1) == 387 and int(坡下平.y2) == 387,
			"100010000 段15 应是 x=763 起的平地（地图 JSON 真值），实得 %s" % str(坡下平))
	_断言(not 底平.is_empty() and int(底平.y1) == 767,
			"100010000 段49 应是 y=767 的下层平台（地图 JSON 真值），实得 %s" % str(底平))
	# 直接钉扫掠：探针实测的穿越帧 (681.7,332.4)→(678.8,340.2)，按段14 直线解出交点 y≈332.72。
	var 扫: Dictionary = _地表.call("扫掠落点", Vector2(681.7, 332.4), Vector2(678.8, 340.2))
	_断言(String(扫.get("id", "")) == "14",
			"穿越帧应扫到段14（斜坡），实得 %s" % str(扫))
	_断言(absf(float(扫.get("y", INF)) - 332.72) < 0.05
			and absf(float(扫.get("x", INF)) - 681.58) < 0.05,
			"穿越帧交点应约 (681.58,332.72)（段14 与位移线求交），实得 %s" % str(扫))
	# 反向：同一段位移倒过来（向上）不该接住 —— `dot(位移,法线) < 0` 的法线闸。
	var 上扫: Dictionary = _地表.call("扫掠落点", Vector2(681.7, 340.2), Vector2(681.7, 332.4))
	_断言(上扫.is_empty(), "向上位移不许被斜坡接住（findIntersection 法线闸），实得 %s" % str(上扫))
	# 端到端：站在段15 左端 x=781 起跳按住左键 —— 探针实测旧语义在这个相位会穿过段14、
	# 落到下层段49（y=767）；x≤780 的相位碰巧被 1px 容差接住，所以起点钉 781。
	# 走速钉回原版"属性 100"那个点（125×1.4=175，`跳跃常数.走路速度`）：本机存档属性更高时
	# 人飞得远、整段斜坡从头顶过去，落不到坡上 —— 那是轨迹不同，不是这条腿要抓的穿台。
	_玩.set("move_speed", 175.0)
	_站上(坡下平, 781.0)
	Input.action_press("ui_left")
	_按跳()
	var 坡帧 := _步到落地(150)
	Input.action_release("ui_left")
	var 坡落 := String(_玩.get("current_fh_id"))
	_断言(bool(_玩.get("on_ground")) and 坡落 == "14",
			"段15 左端向左跳，应落在段14 斜坡上（%d 帧），实得 on_ground=%s fh=%s pos=%s"
			% [坡帧, str(_玩.get("on_ground")), 坡落, str(_位置())])
	_断言(坡落 != "49" and _位置().y < 400.0,
			"不许穿过斜坡掉到下层段49（y=767），实得 fh=%s pos=%s" % [坡落, str(_位置())])
	if 坡落 == "14":
		_断言(absf(_位置().y - _段面y(坡, _位置().x)) < 2.0,
				"落点应贴段14 坡面，实得 pos=%s 坡面 y=%.2f"
				% [str(_位置()), _段面y(坡, _位置().x)])

	# ── ⑧ 站着走出小平台尽头必须离地下落（2026-11-02 报）────────────────────
	# 上一版把「扫掠落点」放在 `if not followed_ground:` 里**站着也跑**：起脚点正好压在
	# 脚下那条面上 ⇒ findIntersection 交点 t=0、落点=起点，人每帧被拽回边缘、永远走不出去，
	# 只能跳。原版 `checkFoothold():373-389` 那段扫掠只在 `currFoothold == null` 分支里。
	# 数据真值：段32 平地 [1163..1280] y=826，右端 33 是竖直落面 (x=1280, y 826→862)；
	# 段26 平地 [243..361] y=621，左端 25 是竖直落面 (x=243, y 657→621)。两处都不是墙
	# （朝右 33 的 y2>y1、朝左 25 的 y1>y2 ⇒ `_挡在脚点端头的墙前` 不挡）。
	var 表台: Dictionary = _地表.get("id_map") as Dictionary
	var 台32: Dictionary = 表台.get("32", {})
	var 竖33: Dictionary = 表台.get("33", {})
	var 台26: Dictionary = 表台.get("26", {})
	var 竖25: Dictionary = 表台.get("25", {})
	_断言(int(台32.get("x1", 0)) == 1163 and int(台32.get("x2", 0)) == 1280
			and int(台32.get("y1", 0)) == 826
			and int(竖33.get("x1", 0)) == 1280 and int(竖33.get("y2", 0)) == 862,
			"100010000 应有段32 平地 [1163..1280] y=826、右端竖直落面 33 y 826→862，实得 %s / %s"
			% [str(台32), str(竖33)])
	_断言(int(台26.get("x1", 0)) == 243 and int(台26.get("x2", 0)) == 361
			and int(台26.get("y1", 0)) == 621
			and int(竖25.get("x1", 0)) == 243 and int(竖25.get("y2", 0)) == 621,
			"100010000 应有段26 平地 [243..361] y=621、左端竖直落面 25 y 657→621，实得 %s / %s"
			% [str(台26), str(竖25)])
	_玩.set("move_speed", 175.0)
	# ⑧a 先在平台中间走：不许误离地（这条防「一改就全图踩空」的反向翻车）
	_站上(台32, 1200.0)
	Input.action_press("ui_right")
	_步(10)
	Input.action_release("ui_right")
	_断言(bool(_玩.get("on_ground")) and absf(_位置().y - 826.0) < 0.01
			and String(_玩.get("current_fh_id")) == "32",
			"平台中间正常行走不许离地/掉高度，实得 on_ground=%s fh=%s y=%.2f"
			% [str(_玩.get("on_ground")), String(_玩.get("current_fh_id")), _位置().y])
	# ⑧b 右端：走出去必须离地、跨过 x=1280、y 下降
	_站上(台32, 1277.0)
	Input.action_press("ui_right")
	var 右离地 := false
	var 右最远 := _位置().x
	var 右最低y := _位置().y
	for _i in 60:
		_玩._physics_process(帧)
		右最远 = maxf(右最远, _位置().x)
		右最低y = maxf(右最低y, _位置().y)
		if not bool(_玩.get("on_ground")):
			右离地 = true
	Input.action_release("ui_right")
	_断言(右离地, "段32 右端走出去必须离地（旧逻辑被 t=0 扫掠拽住，on_ground 恒 true）")
	_断言(右最远 > 1290.0, "必须真的跨过右端 x=1280，实得最远 x=%.1f" % 右最远)
	_断言(右最低y > 826.0 + 20.0, "必须落下（旧逻辑 y 恒为 826），实得最低 y=%.1f" % 右最低y)
	# ⑧c 左端对称
	_站上(台26, 246.0)
	Input.action_press("ui_left")
	var 左离地 := false
	var 左最远 := _位置().x
	var 左最低y := _位置().y
	for _i in 60:
		_玩._physics_process(帧)
		左最远 = minf(左最远, _位置().x)
		左最低y = maxf(左最低y, _位置().y)
		if not bool(_玩.get("on_ground")):
			左离地 = true
	Input.action_release("ui_left")
	_断言(左离地, "段26 左端走出去必须离地（旧逻辑被 t=0 扫掠拽住，on_ground 恒 true）")
	_断言(左最远 < 233.0, "必须真的跨过左端 x=243，实得最远 x=%.1f" % 左最远)
	_断言(左最低y > 621.0 + 20.0, "必须落下（旧逻辑 y 恒为 621），实得最低 y=%.1f" % 左最低y)

	_finish()

## ── 载图 / 驱动小工具 ──────────────────────────────────────────────────────
func _载图(图号: String) -> bool:
	if _场景 != null:
		_场景.queue_free()
		_场景 = null
		_玩 = null
		_地表 = null
		await process_frame
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_断言(false, "没有 GameSession 自动加载，本门无法进图")
		return false
	会话.set("current_map_id", 图号)
	var 场景包 := load(地图资源.playable_scene_path(图号)) as PackedScene
	if 场景包 == null:
		_断言(false, "%s 的可玩场景不在盘上" % 图号)
		return false
	_场景 = 场景包.instantiate()
	root.add_child(_场景)
	for _i in 10:
		await process_frame
	_玩 = _场景.get_node_or_null("Player")
	_地表 = _场景.get_node_or_null("Footholds")
	if _玩 == null or _地表 == null:
		_断言(false, "%s 场景缺 Player / Footholds" % 图号)
		return false
	_玩.set_physics_process(false)
	return true

func _按跳() -> void:
	_玩.set("jump_was_pressed", false)
	Input.action_press("jump")
	_步(1)
	Input.action_release("jump")

func _步(帧数: int) -> void:
	for _i in 帧数:
		_玩._physics_process(帧)

func _步到落地(上限: int) -> int:
	var n := 0
	while n < 上限 and not bool(_玩.get("on_ground")):
		_玩._physics_process(帧)
		n += 1
	return n

func _站上(段: Dictionary, x: float) -> void:
	_玩.set("position", Vector2(x, _段面y(段, x)))
	_玩.set("current_fh_id", String(段.id))
	_玩.set("on_ground", true)
	_玩.set("climbing", false)
	_玩.set("跳起中", false)
	_玩.set("jump_was_pressed", false)
	_玩.set("velocity", Vector2.ZERO)
	_玩.set("facing", 1)

func _段面y(段: Dictionary, x: float) -> float:
	return float(_地表.call("ground_y_on", x, 段))

func _最低(x: float) -> float:
	return float(_地表.call("最低地面y", x))

func _位置() -> Vector2:
	return _玩.get("position") as Vector2

func _速度() -> Vector2:
	return _玩.get("velocity") as Vector2

## 数据来自地图 JSON，不是被测代码：找一条够长的水平脚点当试验台。
func _长平台() -> Dictionary:
	var 最优: Dictionary = {}
	var 最长 := 0.0
	for 段 in (_地表.get("segments") as Array):
		var 长 := absf(float(段.x2) - float(段.x1))
		if absf(float(段.y2) - float(段.y1)) < 0.5 and 长 > 最长:
			最长 = 长
			最优 = 段
	return 最优 if 最长 > 400.0 else {}

## 找一条「脚下还有别的平台」的平地 x —— 下+跳在那里才会穿台。
func _找穿台点() -> Dictionary:
	for 段 in (_地表.get("segments") as Array):
		if absf(float(段.y2) - float(段.y1)) >= 0.5:
			continue
		if absf(float(段.x2) - float(段.x1)) < 100.0:
			continue
		for 比例 in [0.5, 0.4, 0.6, 0.3, 0.7]:
			var x := lerpf(float(段.x1), float(段.x2), 比例)
			var 地面 := _段面y(段, x)
			var 下: Dictionary = _地表.call("find_platform_below", x, 地面, String(段.id))
			if float(下.get("y", INF)) != INF:
				return {"段": 段, "x": x}
	return {}

func _finish() -> void:
	_已收尾 = true
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("jump")
	if _失败.is_empty():
		print("跳跃穿台落点回归测试：通过（%d 条断言）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("跳跃穿台落点回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
