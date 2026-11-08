## 迷路森林（406010000 / 森林出口 406010001）「禁寻路」控制器回归门。
##
## 用户 2026-10-28 报：「迷路森林，各种功能触发键失效（转向，跳跃）」。
## 原版这两口**换掉了整个移动控制器**：`PlayerController.tick():295-309` 判
## `nowInNotFindPathMap` 就只跑 `tickInJingSuMaps():67-190` ——
##   · 左右键**不转向**（原版根本不读左右键），人一直朝当前朝向走，撞墙才掉头（`:67-85`）；
##   · `JUMP` 键照常起跳，且是 `jumpRightTarget()/jumpLeftTarget()`（`KeyController.as:488/1623`）
##     ⇒ 竖向 `-jumpSpeed` + 水平 `朝向 × walkSpeed`；
##   · 踩地图箭头/火箭走 `onTouchItem()`（`PlayerController.as:250-290`），速度表
##     `JingSuFuBen`（`JinChuFuBenRolesSpeedManager.loadSpeedConfig():76-127`）；
##   · 点地走 / 自动寻路 ⇒ `NOT_PATH_FIND`（`KeyController.pathFind():934-941`）；
##   · 金锄副本（406010000）里忍术一律 `WARNING_NOT_SKILL_MAP`（`Job0.isSkillForbiden():422-427`）；
##   · 打坐/双修上行被 `Client.as:4340` / `HealHandler.requestHealStart():349-353` 咽掉。
##
## 门的层次（少任一条都会假绿）：
##   ① 图族判定；② `JingSuFuBen` 系数逐档钉字面量（AS3 侧是 `aspect × speed`）；
##   ③ 真场景里的行走/掉头/跳跃/空中惯性；④ 触碰道具的矩形与 1000ms 去重；
##   ⑤ 走向/忍术/打坐三条"被吞掉"的入口；⑥ 后端两条打坐上行不发。
extends SceneTree

const 禁寻路地图 := preload("res://脚本/地图/禁寻路地图.gd")
const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")

var _失败: Array[String] = []
var _条数 := 0
var _提示: Array[String] = []
var _已收尾 := false
var _秒 := 0.0

func _initialize() -> void:
	call_deferred("_run")

## 门里崩了不会报红、只会挂死 ⇒ 看门狗兜底。
func _process(delta: float) -> bool:
	_秒 += delta
	if not _已收尾 and _秒 > 90.0:
		printerr("迷路森林禁寻路回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false

func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)

func _截段(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)

func _run() -> void:
	# ── ① 图族判定（数据源：原版杂项 FuBen 里 type == 9）──────────────────
	_断言(禁寻路地图.是禁寻路图("406010000"), "迷路森林 406010000 应判为禁寻路图")
	_断言(禁寻路地图.是禁寻路图("406010001"), "森林出口 406010001 应判为禁寻路图")
	_断言(not 禁寻路地图.是禁寻路图("101010000"), "木叶村 101010000 不该被当成禁寻路图")
	_断言(not 禁寻路地图.是禁寻路图("403000000"), "命运之抉择 403000000 不该被当成禁寻路图")
	_断言(禁寻路地图.是金锄副本("406010000"), "金锄副本只认 406010000（Map.nowJinChuFuBen）")
	_断言(not 禁寻路地图.是金锄副本("406010001"), "森林出口 406010001 不在金锄副本里 ⇒ 忍术不拦")

	var 会话 := root.get_node_or_null("GameSession")
	var 后端 := root.get_node_or_null("BackendConnection")
	if 会话 == null:
		_断言(false, "没有 GameSession 自动加载，本门无法进图")
		_finish()
		return
	会话.set("current_map_id", "406010000")

	var 场景包 := load(MAP_RESOURCES.playable_scene_path("406010000")) as PackedScene
	if 场景包 == null:
		_断言(false, "406010000 的可玩场景不在盘上")
		_finish()
		return
	var 场景 := 场景包.instantiate()
	root.add_child(场景)
	for _帧 in 12:
		await process_frame

	var 玩 := 场景.get_node_or_null("Player")
	if 玩 == null:
		_断言(false, "406010000 场景里没有 Player")
		_finish()
		return
	var 图 := 场景.get_node_or_null("Footholds")
	## `_server_drops` / `_推进去捡` / `_触碰表` 都在 LifeRoot（挂 `地图实体.gd`）上，
	## 不在场景根（根是 `地图根节点.gd`）。
	var 实体 := 场景.get_node_or_null("LifeRoot")
	if 实体 == null:
		_断言(false, "406010000 场景里没有 LifeRoot（掉落/触碰那条没验到）")
		_finish()
		return
	if 图 == null:
		_断言(false, "406010000 场景里没有 Footholds")
		_finish()
		return
	if 后端 != null and 后端.has_signal("获得提示"):
		后端.connect("获得提示", func(文: String) -> void: _提示.append(文))

	_断言(bool(玩.get("禁寻路")), "Player._ready 该按 current_map_id 置 禁寻路 = true")

	# 手动物理步进：关掉引擎驱动的 _physics_process，自己按 60fps 调，
	# 这样断言只量"这一帧控制器做了什么"，不被真实帧率/其它系统打断。
	玩.set_physics_process(false)
	var 帧 := 1.0 / 60.0

	# ── ② JingSuFuBen 系数（AS3 字面量：aspect × speed；x 乘走速、y 乘跳速）──
	var 走 := float(玩.get("move_speed"))
	var 跳 := float(玩.get("jump_speed"))
	_断言(走 > 0.0, "走路速度应 > 0（属性缺失时按 100 算，不许把人冻住），实得 %s" % str(走))
	_断言(absf(跳 - 666.0) < 0.01, "起跳速度恒为 666（550×1.2；原版 jumpSpeedFactor 全树没赋值点），实得 %s" % str(跳))
	_断言(禁寻路地图.速度("upHuoJianSpeed", 走, 跳).is_equal_approx(Vector2(0.0, -3.5 * 跳)),
			"upHuoJianSpeed 应为 (0, −3.5×跳速)（表: x 1×0 / y −1×3.5），实得 %s"
			% str(禁寻路地图.速度("upHuoJianSpeed", 走, 跳)))
	_断言(禁寻路地图.速度("downHuoJianSpeed", 走, 跳).is_equal_approx(Vector2(0.0, 跳)),
			"downHuoJianSpeed 应为 (0, +跳速)，实得 %s" % str(禁寻路地图.速度("downHuoJianSpeed", 走, 跳)))
	_断言(禁寻路地图.速度("upJianTouSpeed", 走, 跳).is_equal_approx(Vector2(走, -跳)),
			"upJianTouSpeed 应为 (+走速, −跳速)，实得 %s" % str(禁寻路地图.速度("upJianTouSpeed", 走, 跳)))
	_断言(禁寻路地图.速度("leftUpHuoJianSpeed", 走, 跳).is_equal_approx(Vector2(-2.2 * 走, -2.2 * 跳)),
			"leftUpHuoJianSpeed 应为 (−2.2×走速, −2.2×跳速)，实得 %s"
			% str(禁寻路地图.速度("leftUpHuoJianSpeed", 走, 跳)))
	_断言(禁寻路地图.速度("rightDownHuoJianSpeed", 走, 跳).is_equal_approx(Vector2(走, 跳)),
			"rightDownHuoJianSpeed 应为 (+走速, +跳速)，实得 %s"
			% str(禁寻路地图.速度("rightDownHuoJianSpeed", 走, 跳)))

	# ── ③ 自动走 / 撞墙掉头 / 左右键无效 / 跳跃 ───────────────────────────
	var 段 := _长平台(图)
	if 段.is_empty():
		_断言(false, "406010000 里找不到长度 >500 的水平脚点，走跑相关断言无法进行")
		_finish()
		return

	_站上(玩, 段)
	玩.set("facing", 1)
	玩.set("右被挡", false)
	玩.set("左被挡", false)
	var 前x := (玩.get("position") as Vector2).x
	for _i in 6:
		玩._physics_process(帧)
	_断言((玩.get("position") as Vector2).x > 前x + 1.0,
			"禁寻路图里不按键也该自己朝当前朝向走（x %.1f → %.1f）" % [前x, (玩.get("position") as Vector2).x])
	_断言(int(玩.get("facing")) == 1, "朝向应保持 1（撞墙前不掉头）")
	_断言(absf((玩.get("velocity") as Vector2).x - 走) < 0.01, "地面速度应是 +走速，实得 %s" % str(玩.get("velocity")))

	# 用户报的"转向键失效"：原版本来就不给转向 ⇒ 按左键也不许左转
	Input.action_press("ui_left")
	_站上(玩, 段)
	玩.set("facing", 1)
	for _i in 3:
		玩._physics_process(帧)
	Input.action_release("ui_left")
	_断言(int(玩.get("facing")) == 1 and (玩.get("velocity") as Vector2).x > 0.0,
			"禁寻路图里左键不该让人掉头/反向（原版 tickInJingSuMaps 不读左右键）；实得 facing=%s v=%s"
			% [str(玩.get("facing")), str(玩.get("velocity"))])

	# 撞右墙 ⇒ 掉头向左（tickInJingSuMaps:67-71）
	_站上(玩, 段)
	玩.set("facing", 1)
	玩.set("右被挡", true)
	玩.set("左被挡", false)
	玩._physics_process(帧)
	_断言(int(玩.get("facing")) == -1, "右被挡 + 朝右 ⇒ 这一帧该掉头朝左，实得 %s" % str(玩.get("facing")))
	_断言((玩.get("velocity") as Vector2).x < 0.0, "掉头后水平速度该为负，实得 %s" % str(玩.get("velocity")))
	_断言(not bool(玩.get("右被挡")), "撞墙旗标读完即清（checkInit:246 每帧清零）")

	# 撞左墙 ⇒ 掉头向右
	_站上(玩, 段)
	玩.set("facing", -1)
	玩.set("右被挡", false)
	玩.set("左被挡", true)
	玩._physics_process(帧)
	_断言(int(玩.get("facing")) == 1 and (玩.get("velocity") as Vector2).x > 0.0,
			"左被挡 + 朝左 ⇒ 该掉头朝右；实得 facing=%s v=%s" % [str(玩.get("facing")), str(玩.get("velocity"))])

	# 撞墙旗标只在"正朝那一侧"时才掉头（原版 `&& direction == RIGHT`）
	_站上(玩, 段)
	玩.set("facing", -1)
	玩.set("右被挡", true)
	玩._physics_process(帧)
	_断言(int(玩.get("facing")) == -1, "朝左时右被挡不该把人翻回右边")

	# 跳跃：走着起跳 = jumpRightTarget ⇒ y = −跳速、x = 朝向×走速
	_站上(玩, 段)
	玩.set("facing", 1)
	玩.set("jump_was_pressed", false)
	Input.action_press("jump")
	玩._physics_process(帧)
	Input.action_release("jump")
	_断言(absf((玩.get("velocity") as Vector2).y + 跳) < 0.01,
			"跳跃键该给竖向 −跳速，实得 %s" % str(玩.get("velocity")))
	## ⚠ 这里**不断言** `velocity.x == 朝向×走速`：地面上那一行本来就写成 `dir×走速`，
	##   起跳块再赋一次是照抄 `jumpRightTarget` 的冗余 ⇒ 那条断言删掉起跳块那两行也不会红（假腿）。
	_断言(not bool(玩.get("on_ground")), "起跳后这一帧应离地")

	# 空中横向速度是"那一下给的" ⇒ 不许被 dir×走速 抹平（火箭射出去才飞得起来）
	_站上(玩, 段)
	玩.set("跳起中", false)   # 只留 `禁寻路` 这一条分支能兜住，别让 跳起中 把这条钉变松
	玩.set("on_ground", false)
	玩.set("current_fh_id", "")
	玩.set("climbing", false)
	玩.set("position", Vector2(2000.0, 1700.0))
	玩.set("velocity", Vector2(-2.2 * 走, -2.2 * 跳))
	var 空x := 2000.0
	玩._physics_process(帧)
	_断言((玩.get("position") as Vector2).x < 空x - 5.0,
			"空中应保持 −2.2×走速 的横向位移（x 2000 → %s）" % str((玩.get("position") as Vector2).x))
	_断言(absf((玩.get("velocity") as Vector2).x + 2.2 * 走) < 0.01,
			"空中横向速度不许被 dir×走速 覆盖，实得 %s" % str(玩.get("velocity")))

	# 穿台下落：原版 jumpDownTarget():1592 是纯直落（x:0, y:0）—— 与地图族无关
	_站上(玩, 段)
	玩.set("velocity", Vector2(走, 0.0))
	玩.call("_穿台下落")
	_断言(absf((玩.get("velocity") as Vector2).x) < 0.01, "禁寻路图穿台下落该把水平速度清零，实得 %s" % str(玩.get("velocity")))
	玩.set("禁寻路", false)
	玩.set("velocity", Vector2(走, 0.0))
	玩.call("_穿台下落")
	_断言(absf((玩.get("velocity") as Vector2).x) < 0.01,
			"非禁寻路图穿台下落同样该清零（2026-10-30 按原版 `jumpDownTarget` 修正旧口径："
			+ "以前这里钉的是「只清禁寻路」，那正是带方向穿台横飘掉出地图的来源），实得 %s"
			% str(玩.get("velocity")))
	玩.set("跳起中", false)
	玩.set("禁寻路", true)

	# ── ④ onTouchItem：八枚箭头的速度/朝向，以及就地掉头 ─────────────────────
	_站上(玩, 段)
	玩.set("facing", 1)
	玩.set("velocity", Vector2.ZERO)
	玩.call("onTouchItem", 15037004)
	_断言(玩.get("velocity").is_equal_approx(Vector2(0.0, -3.5 * 跳)),
			"15037004（fastJumpUpTarget2）应竖直弹射 (0,−3.5×跳速)，实得 %s" % str(玩.get("velocity")))
	_断言(not bool(玩.get("on_ground")) and String(玩.get("current_fh_id")) == "",
			"弹射时该离地并清脚点（原版 currFoothold = null）")

	_站上(玩, 段)
	玩.set("facing", 1)
	玩.call("onTouchItem", 15037006)
	_断言(int(玩.get("facing")) == -1, "15037006 先把朝向改成左（jumpLeftTarget2 带 direction）")
	_断言(玩.get("velocity").is_equal_approx(Vector2(-2.2 * 走, -2.2 * 跳)),
			"15037006 应 (−2.2×走速, −2.2×跳速)，实得 %s" % str(玩.get("velocity")))

	_站上(玩, 段)
	玩.set("facing", -1)
	玩.call("onTouchItem", 15037007)
	_断言(int(玩.get("facing")) == 1, "15037007 先把朝向改成右")
	_断言(玩.get("velocity").is_equal_approx(Vector2(2.2 * 走, -2.2 * 跳)),
			"15037007 应 (+2.2×走速, −2.2×跳速)，实得 %s" % str(玩.get("velocity")))

	_站上(玩, 段)
	玩.set("facing", -1)
	玩.call("onTouchItem", 15037008)
	_断言(int(玩.get("facing")) == -1, "15037008 朝向向左")
	_断言(玩.get("velocity").is_equal_approx(Vector2(-走, 0.0)),
			"15037008（leftDownHuoJian: x −1×1 / y +1×0）应 (−走速, 0)，实得 %s" % str(玩.get("velocity")))

	_站上(玩, 段)
	玩.set("facing", -1)
	玩.call("onTouchItem", 15037009)
	_断言(int(玩.get("facing")) == 1, "15037009 朝向向右")
	_断言(玩.get("velocity").is_equal_approx(Vector2(走, 跳)),
			"15037009（rightDownHuoJian）应 (+走速, +跳速)，实得 %s" % str(玩.get("velocity")))

	_站上(玩, 段)
	玩.set("facing", 1)
	玩.set("velocity", Vector2.ZERO)
	玩.call("onTouchItem", 15037002)
	_断言(玩.get("velocity").is_equal_approx(Vector2(走, 跳)),
			"15037002（downJianTouSpeed）应 (+走速, +跳速)，实得 %s" % str(玩.get("velocity")))

	_站上(玩, 段)
	玩.set("facing", 1)
	玩.set("velocity", Vector2.ZERO)
	玩.call("onTouchItem", 15037001)
	_断言(int(玩.get("facing")) == -1 and absf((玩.get("velocity") as Vector2).x + 走) < 0.01,
			"15037001（toZheFan）应就地掉头并给 −走速；实得 facing=%s v=%s"
			% [str(玩.get("facing")), str(玩.get("velocity"))])
	_断言(bool(玩.get("on_ground")), "15037001 是「走」不是「跳」，人不该离地")

	_站上(玩, 段)
	玩.set("facing", 1)
	玩.set("velocity", Vector2.ZERO)
	玩.call("onTouchItem", 12345)
	_断言(玩.get("velocity") == Vector2.ZERO and int(玩.get("facing")) == 1,
			"不认识的物品号不该改速度/朝向")

	# ── ⑤ 触碰矩形 + 1000ms 去重（DropItemHandler.pickItemInARect）──────────
	var 掉 := Node2D.new()
	掉.set_meta("drop_touch_up", true)
	掉.set_meta("drop_item", "15037004")
	掉.set_meta("drop_owner", 0)
	实体.add_child(掉)
	_站上(玩, 段)
	掉.global_position = 玩.global_position + Vector2(10.0, 0.0)
	var 掉落表: Dictionary = 实体.get("_server_drops")
	var 触碰表: Dictionary = 实体.get("_触碰表")
	var 锁定表: Dictionary = 实体.get("_锁定表")
	掉落表[900001] = 掉
	玩.set("velocity", Vector2.ZERO)
	实体.call("_推进去捡", 16.0)
	_断言(玩.get("velocity").is_equal_approx(Vector2(0.0, -3.5 * 跳)),
			"踩到 15037004 应弹射（矩形 A=(x−20,y−42,42,42) 与 B=(x−17,y−17,34,34) 相交），实得 %s"
			% str(玩.get("velocity")))
	_断言(float(触碰表.get(900001, 0.0)) > 0.0,
			"触发过的那一枚该进 1000ms 去重表")
	_断言(not 锁定表.has(900001),
			"15037xxx 触发道具**不该**占 5 秒拾取锁（原版 pickDropItem 的 itemid/1000 != 15037 本意）")
	_断言(not bool(掉.get_meta("drop_picking", false)),
			"触发道具不该起拾取动画（它不是可捡物，是踩上去的机关）")

	玩.set("velocity", Vector2.ZERO)
	实体.call("_推进去捡", 16.0)
	_断言(玩.get("velocity") == Vector2.ZERO, "同一枚 1000ms 内不该重复触发")

	实体.call("_推进去捡", 1000.0)
	实体.call("_推进去捡", 16.0)
	_断言(玩.get("velocity").is_equal_approx(Vector2(0.0, -3.5 * 跳)),
			"过了 1000ms 再踩同一枚应再次触发（去重表到期）")

	# 矩形边界：横向差 30 像素（A 右边 x+22 / B 左边 x+13）就不该相交
	触碰表.clear()
	_站上(玩, 段)
	掉.global_position = 玩.global_position + Vector2(40.0, 0.0)
	玩.set("velocity", Vector2.ZERO)
	实体.call("_推进去捡", 16.0)
	_断言(玩.get("velocity") == Vector2.ZERO, "横向差 40 像素（矩形不相交）不该触发")
	掉落表.erase(900001)
	掉.queue_free()

	# ── ⑥ 三个"被吞掉"的入口 ───────────────────────────────────────────────
	_提示.clear()
	var 走通 := bool(玩.call("走向", Vector2(2000.0, 1765.0)))
	_断言(not 走通, "禁寻路图里 走向() 应直接失败（原版 pathFind 给 NOT_PATH_FIND）")
	_断言(not bool(玩.get("click_move_active")), "禁寻路图里 走向() 不该排起点击路线")
	_断言(_提示.has("在当前地图无法开启自动寻路"),
			"点地走应给 NOT_PATH_FIND 提示；实得 %s" % str(_提示))

	_提示.clear()
	_站上(玩, 段)
	玩.set("出手中", false)
	玩.call("use_skill_slot", 1)
	_断言(_提示.has("在当前地图不能使用该忍术"),
			"金锄副本里忍术应回 WARNING_NOT_SKILL_MAP；实得 %s" % str(_提示))
	## ⚠ 这一格原有的"出手中 仍为 false"拿掉：1 号槽是单体技，没有选中怪时
	##    `use_skill_slot` 在 `档 == 1 and 选中 == null` 处就返回、本来就不置 `出手中`，
	##    即使拆掉金锄守卫这条断言也不会红（反向对照实测）——留着就是自洽空转。

	_断言(not bool(玩.call("toggle_practise")), "禁寻路图里 toggle_practise() 应返回 false")
	_断言(not bool(玩.get("is_practising")), "禁寻路图里不许本地起坐姿（否则画面坐着、服务端没反应）")
	玩.call("set_practising", true)
	_断言(not bool(玩.get("is_practising")), "禁寻路图里 set_practising(true) 也不许起坐姿")

	# ── ⑦ 后端：打坐/双修上行在禁寻路图里不发 ──────────────────────────────
	if 后端 == null:
		_断言(false, "没有 BackendConnection 自动加载，打坐上行那两腿没验到")
	else:
		后端.set("authoritative_map_id", 406010000)
		_断言(bool(后端.call("_禁寻路图")), "后端按 authoritative_map_id=406010000 应判为禁寻路图")
		_断言(not bool(后端.call("request_heal_start")), "禁寻路图里 request_heal_start() 应返回 false")
		_断言(not bool(后端.call("request_double_heal_invite", 12345)), "禁寻路图里双修邀请应返回 false")
		后端.set("authoritative_map_id", 101010000)
		_断言(not bool(后端.call("_禁寻路图")), "木叶村不该被后端判成禁寻路图")
		## ⚠ 离线时 `send_game_request()` 因为没连上服务端也返回 false ⇒
		##    "发不发"这件事在这里量不出来，只能钉住守卫行本身（与 `自动寻路提示回归测试` 同法）。
		var 源 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
		_断言(_截段(源, "func request_heal_start", "\nfunc ").contains("if _禁寻路图():"),
				"request_heal_start 少了 _禁寻路图() 守卫（离线断言量不到，只能看源码）")
		_断言(_截段(源, "func request_double_heal_invite", "\nfunc ").contains("if _禁寻路图():"),
				"request_double_heal_invite 少了 _禁寻路图() 守卫")

	_finish()

## 找一条够长的水平脚点当试验台（数据来自地图 JSON，不是被测代码）。
func _长平台(图: Node) -> Dictionary:
	for 段 in (图.get("segments") as Array):
		if absf(float(段.y2) - float(段.y1)) < 0.5 and absf(float(段.x2) - float(段.x1)) > 500.0:
			return 段
	return {}

func _站上(玩: Node, 段: Dictionary) -> void:
	玩.set("position", Vector2((float(段.x1) + float(段.x2)) * 0.5, float(段.y1)))
	玩.set("current_fh_id", String(段.id))
	玩.set("on_ground", true)
	玩.set("climbing", false)
	玩.set("velocity", Vector2.ZERO)

func _finish() -> void:
	_已收尾 = true
	if _失败.is_empty():
		print("迷路森林禁寻路回归测试：通过（%d 条断言）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("迷路森林禁寻路回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
