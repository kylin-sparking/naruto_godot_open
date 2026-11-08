extends SceneTree

## 行为门（#181）：把地图真的搭起来，看三件事在运行期成不成立 ——
##   ① 单体技（`target=1`）**只打选中的那一只**，旁边的怪一点血都不掉；
##   ② 面积技（`target=2`）命中盒框到的**两只都掉**；
##   ③ 选中的忍术 + 点怪 ⇒ 之后每拍自动放它（用户原话「释放一次后再用鼠标点击敌人
##      就会默认使用当前选中的忍术」）；
##   ④ 反向：单体技在**没选中怪**时不放，而且**不扣蓝、不转冷却**（不许白放一次）。
##
## 为什么不能只靠源码钉：上一轮「走到跟前自动开对话」就是门全绿、实机不弹
## （`has_method` 恒假那种假绿）⇒ 这一族改动一律要真把 `玩家` + `LifeRoot` 摆出来跑帧。
## 真值与判据出处见 `脚本/角色/技能目标选择.gd` 文件头（`AbstractAttackSkill.as:598-637`、
## `:388-404`、`SkillDataTool.as:177-181`、`TargetHandler.as:128-147`、`SkillExecute.as:205`）。
##
## 跑法：--headless 就够（不看像素，只看血量与状态）。

const 出 := "res://测试/截图/追踪栏/技能单体与面积行为.txt"
const 单体号 := 1001001
const 面积号 := 1001003
const 投掷号 := 1001002		# `数据/技能动画元数据.json` 里唯一带 `ball` 相位的职业技（ballAfter=250）


## #193/#218 用的**假后端**：只要 `in_game` 与两个会记账的发包口。
## 在线那一档的伤害由服务端算 ⇒ 本工程把"什么时候发哪一张帧"当成观测量：
##   · **结算（42）= 弹没到身上就不许发**（用户 10-11 报的"先掉血后飞到"）；
##   · **广播（1328）= 按下这一拍就该发**（用户 10-14 报的"别人看我放技能特效延迟很高"——
##     上一轮把两张帧捆在一起压到命中帧，旁观者就得等整段飞行时间才看到出手动画）。
class 假后端 extends Node:
	var in_game := true
	var 发过: Array = []			## 42 结算
	var 广播过: Array = []			## 1328 广播
	var 位移过: Array = []			## 位移采样（`玩家._sync_backend_movement`）
	## ⚠ 桩**必须把这个方法也接上**：`_sync_backend_movement` 在 `_physics_process` 里跑，
	##   缺它就不是"少记一条"，而是 `Invalid call. Nonexistent function 'send_movement (via call)'`
	##   当场打断那次同步（§3.245：全量日志 grep 到过一次，签名照 `后端连接.gd:982` 抄，
	##   ⚠ **参数个数也要抄**：`玩家.gd:1624` 实发四参（`朝向` 是合支那轮加进 `36` 帧的），
	##   桩少一节默认值 ⇒ `Expected 3 argument(s)` 一样是**静默丢整条腿**（§3.253 抓到过一次）。
	func send_movement(位置: Vector2, 动作: int = 3, 速度: Vector2 = Vector2.ZERO,
			朝向: int = 0) -> bool:
		位移过.append({"位": 位置, "动": 动作, "速": 速度, "朝": 朝向})
		return true
	func announce_skill_cast(编号: int, 等级: int, 目标ids: Array, 位: Vector2,
			朝: int, 姿态: int = 11) -> bool:
		广播过.append({"id": 编号, "ids": 目标ids.duplicate()})
		return true
	func request_skill_damage(编号: int, 等级: int, 目标ids: Array, 朝: int, 姿态: int = 11) -> bool:
		发过.append({"id": 编号, "ids": 目标ids.duplicate()})
		return true

var 日志: Array[String] = []
var 判 := 0
var 红 := 0
var 存前 := PackedByteArray()


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1
	_写()


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


func _帧(n: int) -> void:
	for i in n:
		await process_frame


## 等 n 帧，**每一帧都把玩家与两只怪钉回原位**。
## 怪有巡逻 AI、伤害又要等飞行物落地 ⇒ 只钉一次的话，等完帧再量血量必然假红
## （实测同一份代码 5 次红 1 次：甲掉乙不掉、乙掉甲不掉都出现过）。
func _钉着等(n: int, 玩: Node2D, 甲: Node2D, 乙: Node2D) -> void:
	for i in n:
		await process_frame
		_摆位(玩, 甲, 乙)


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return PackedByteArray([1])
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _尾() -> void:
	_判(_字节("user://玩家数据.json") == 存前, "门不许动存档（本门全程不调任何落盘接口）")
	日志.append("汇：判 %d 条 / 红 %d 条" % [判, 红])
	_写()
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)


## 玩家居中、甲在右 60、乙在左 60。怪有巡逻 AI ⇒ **每次施法前、以及自动追打的每一帧都要重钉**，
## 否则红项报的是"怪走开了"（同一份代码两次跑一绿一红，实测过）。
func _摆位(玩: Node2D, 甲: Node2D, 乙: Node2D) -> void:
	玩.global_position = Vector2(600.0, 300.0)
	甲.global_position = Vector2(660.0, 300.0)
	乙.global_position = Vector2(540.0, 300.0)


## 等上一发的出手动作播完（`出手中` 落回假）。
## 加了"出手中不能再放"这条原版限制之后，量具必须自己等 —— 不然下一次施法会被挡，
## 红项报的是"动作还没播完"，不是逻辑错。最多等 240 帧（4 秒）后放弃。
func _等出手完(玩: Node, 甲: Node2D, 乙: Node2D) -> void:
	var i := 0
	while bool(玩.get("出手中")) and i < 240:
		await process_frame
		_摆位(玩, 甲, 乙)
		i += 1


## 玩家站中间、两只怪都挪到**左边远处**：`range=1` 的命中盒是贴朝向的单侧盒（原版
## `SkillDataTool.getSkillHitRect():60-131` 那张定表），面朝右时盒在 [x, x+100] ⇒ 这样两只都出盒。
func _摆到盒外(玩: Node2D, 甲: Node2D, 乙: Node2D) -> void:
	玩.global_position = Vector2(600.0, 300.0)
	玩.set("facing", 1)
	甲.global_position = Vector2(300.0, 300.0)
	乙.global_position = Vector2(260.0, 300.0)


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _看门狗() -> void:
	var 截止 := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < 截止:
		if not 日志.is_empty() and str(日志[日志.size() - 1]).begins_with("汇"):
			return
		await create_timer(0.2).timeout
	_判(false, "看门狗：150 秒没跑到汇总（看最后一条停在哪一步）")
	_尾()


func _跑() -> void:
	## ── 夹具先把"舞台"钉成工程设计尺寸 ───────────────────────────────
	## 无头 `--script` 下根 Window 只有 **64×64**（实测 `get_visible_rect().size=(64.0,64.0)`），
	## 而原版这条闸 `DisplayUtil.outOfStage:170` 量的是 `Config.STAGE_WIDTH×STAGE_HEIGHT`
	## （`Config.as:176-178` 出厂 **960×560**）。镜头还按视口宽居中 ⇒ 玩家屏幕位只有 (32,250)，
	## 摆到玩家左边 60 像素的那只怪换算过去是 **x=-48** ⇒ 舞台外 ⇒ `能攻` 恒假 ⇒
	## `_冲选中目标` 开头那一闸直接走 `_放掉追击`，腿④ 的"自动追打"于是 0 发
	## （10-20 这两条红的根子，量具缺这颗钉，不是逻辑错）。
	## `测试/挂机行为回归测试.gd:77` 早就钉着同一颗（"无头视口默认 64×64，先钉成设计尺寸"）。
	## 参照值本门自己从工程配置算，不向被测对象要。
	var 设计 := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width")),
			float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	root.size = Vector2i(int(设计.x), int(设计.y))
	await _帧(1)
	## 存档基线要在**单例启动之后**取：跨天首次启动时 `游戏会话._reset_daily_quests_if_needed()`
	## 会按日重置并落一次盘（产品行为，不是本门写的）。基线取在启动前 ⇒ 每天第一次跑都假红。
	存前 = _字节("user://玩家数据.json")
	_判(Vector2(root.size) == 设计,
			"夹具：无头舞台要钉成工程设计的 %s（实得 %s）—— 不钉的话 `outOfStage` 量的是 64×64 的假视口"
			% [str(设计), str(root.size)])
	var 会 = root.get_node_or_null("GameSession")
	var 场: Node = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(60)
	var 玩: Node2D = get_first_node_in_group("player") as Node2D
	_判(玩 != null, "地图里玩家建出来了")
	var 根: Node = 场.get_node_or_null("LifeRoot")
	_判(根 != null, "拿得到 LifeRoot")
	if 玩 == null or 根 == null:
		_尾()
		return
	var 怪们: Array = []
	for 客 in 根.get_children():
		if str(客.get("kind")) == "m" and bool(客.get("alive")):
			怪们.append(客)
	_判(怪们.size() >= 2, "本图至少有两只活怪可以摆（实际 %d 只）" % 怪们.size())
	if 怪们.size() < 2:
		_尾()
		return
	var 甲: Node2D = 怪们[0]
	var 乙: Node2D = 怪们[1]
	# 把技能栏钉成"格0=单体、格1=面积"（编号与 target 档都取自 GameData 导出的 数据/技能.json）
	会.learned_skills.clear()
	# ⚠ 这四件键**一个都不能少**：`_rebuild_skill_slots()` 是直接 `skill.id / .name / .cooldown / .icon`
	#   取值的（不是 `.get`），少一个 `icon` 就整条函数中途报错、快捷栏静默保持原样
	#   —— 本门第一版就是这么红了 4 条，看着像"改坏了"，其实是量具喂错了。
	会.learned_skills.append({"id": str(单体号).pad_zeros(7), "name": "单体测试", "level": 1,
			"max_level": 9, "power": 10, "cooldown": 1.0, "icon": ""})
	会.learned_skills.append({"id": str(面积号).pad_zeros(7), "name": "面积测试", "level": 1,
			"max_level": 9, "power": 10, "cooldown": 1.0, "icon": ""})
	# 快捷栏**直接写**（`_rebuild_skill_slots()` 那套"先按旧栏回填、全空才按学的一览铺"的
	# 启发式不是本门要量的东西，拿它铺栏会让门的红项说不清是谁的锅）。
	会.skill_slots[0] = {"id": str(单体号).pad_zeros(7), "name": "单体测试",
			"cooldown": 1.0, "icon": ""}
	会.skill_slots[1] = {"id": str(面积号).pad_zeros(7), "name": "面积测试",
			"cooldown": 1.0, "icon": ""}
	# 格2 = **投掷技**（`1001002` 的动画元数据里有 `ball` 相位、`ballAfter=250`）—— 腿⑪ 要量它
	会.learned_skills.append({"id": str(投掷号).pad_zeros(7), "name": "投掷测试", "level": 1,
			"max_level": 9, "power": 10, "cooldown": 1.0, "icon": ""})
	会.skill_slots[2] = {"id": str(投掷号).pad_zeros(7), "name": "投掷测试",
			"cooldown": 1.0, "icon": ""}
	var 实0 := String(会.skill_slots[0].get("id", "(空)"))
	var 实1 := String(会.skill_slots[1].get("id", "(空)"))
	_判(实0 == str(单体号).pad_zeros(7) and 实1 == str(面积号).pad_zeros(7),
			"快捷栏钉好：格0=单体 %d、格1=面积 %d（实际 格0=%s 格1=%s，学的一览=%s）" % [
			单体号, 面积号, 实0, 实1, str(会.learned_skills.size())])
	会.player_stats["mp"] = 999999
	会.player_stats["zq"] = 999999
	会.set("backend_authoritative", false)
	# 摆位：玩家站中间，两只怪都在**面积技（range=3，左右对称 ±150）的命中盒**里
	玩.set("facing", 1)
	_摆位(玩, 甲, 乙)
	await _帧(4)

	# ──  单体：只打选中的那一只 ──────────────────────────────────────────────
	甲.set("hp", 9000); 乙.set("hp", 9000)
	_摆位(玩, 甲, 乙)
	# 选中走**真入口** `_select_character`（它同时设 `_selected_character` 与目标框，
	# 且要求怪身上有 `SelectionMarker`）。只调 `显示目标框` 是不够的 —— `get_selected_enemy()`
	# 读的是 `_selected_character`，那样单体那条会"看起来没打中"，其实是根本没选中。
	根.call("_select_character", 甲, {})
	_判(根.call("get_selected_enemy") == 甲, "点选甲之后 `get_selected_enemy()` 真的回甲（夹具没铺错）")
	会.call("设默认忍术", 单体号)
	var 次数甲 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	await _钉着等(20, 玩, 甲, 乙)
	# ⚠ 这里**不判甲掉没掉血**：伤害要等飞行物落地（`_放飞行物(..., 结算=true)`），
	# 拿它当观测点会假红（全量里就这么红过一次）。判"这一发确实放了 + 只报了甲"是确定的。
	_判(int(玩.get("施法次数")) == 次数甲 + 1,
			"单体这一发确实放出去了（施法次数 %d → %d）" % [次数甲, int(玩.get("施法次数"))])
	_判(玩.get("上次施法目标").size() == 1 and (玩.get("上次施法目标") as Array)[0] == 甲,
			"单体这一发**只报了一只**（实际 %d 只）—— 这条不等飞行物，判的是决策本身"
					% (玩.get("上次施法目标") as Array).size())
	_判(int(乙.get("hp")) == 9000,
			"旁边的乙一点血都没掉（%d）—— 用户点名的「单体攻击只能攻击当前选中的那一只怪物」" % int(乙.get("hp")))

	# ──  面积：框到的两只都掉 ────────────────────────────────────────────────
	甲.set("hp", 9000); 乙.set("hp", 9000)
	await _等出手完(玩, 甲, 乙)
	_摆位(玩, 甲, 乙)
	玩.call("use_skill_slot", 1)
	# ⚠ 面积这一发**不能只等 2 帧**：1001003 有"飞行物相位"（`技能动画.有相位(id,"ball")`），
	# 伤害是球飞到位才结算的（离线 `_放飞行物(..., 结算=true)`）—— 等 2 帧时"乙没掉血"
	# 是球还在路上（同一份代码 5 次里红 1 次，实测）。这里等 40 帧并每帧把怪钉回原位。
	for i in 150:
		await process_frame
		_摆位(玩, 甲, 乙)
	var 面报: Array = 玩.get("上次施法目标")
	# 面积这条判**报出去的目标集**：原版 `case 2` 干脆不带目标（服务端按范围算），
	# 本工程服务端只结算客户端报上来的那几只 ⇒ 「报几只」就是客户端的全部责任。
	_判(面报.size() == 2 and 面报.has(甲) and 面报.has(乙),
			"面积这一发把框到的**两只都报出去了**（实际 %d 只）" % 面报.size())

	# ── ③ 反向：**没选中怪、命中盒里也没怪** ⇒ 单体不放、也不白转冷却 ─────────────
	# ⚠ 这条原来只判"没选中怪 ⇒ 不放"。10-11 加了原版 `SkillExecute:420-436` 那条
	#   "按技能键自动锁盒里最近的一只"之后，光没选中是会放的（那是**对**的）⇒
	#   反向判据的前提要改成"盒里也没有怪"，否则量的是新行为、报的是假红。
	根.call("_clear_selected_character")
	_判(根.call("get_selected_enemy") == null, "清选中之后确实没有选中怪了（反向判据的前提）")
	会.skill_cooldowns[0] = 0.0
	甲.set("hp", 9000)
	var 蓝前 := int(会.player_stats.get("mp", 0))
	await _等出手完(玩, 甲, 乙)
	# ⚠ 顺序要紧：`_摆位()` 会把两只放回 60/60 两侧 ⇒ 甲又落回 range=1 的单侧盒里，
	#   那条"自动锁盒里最近一只"就会真的放出去（第一版就是这样假红的）。
	#   这一腿要的前提是"盒里没有怪"，所以**等完出手之后**再把两只挪出盒。
	_摆到盒外(玩, 甲, 乙)
	var 次数乙 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数乙,
			"没选中怪且盒里没怪 ⇒ 一发都没放（施法次数停在 %d）" % 次数乙)
	for i in 20:
		await process_frame
		_摆到盒外(玩, 甲, 乙)
	_判(int(甲.get("hp")) == 9000, "甲一点血没掉")
	_判(float(会.get_skill_cooldown(0)) <= 0.0, "而且**没转冷却**（早退在扣蓝之前，不白放一次）")
	_判(int(会.player_stats.get("mp", 0)) == 蓝前, "而且**没扣查克拉**")

	# ── ④ 点怪即放：选中怪 + 有默认忍术 ⇒ 每拍自动放，不用再去点技能格 ─────────
	甲.set("hp", 9000); 乙.set("hp", 9000)
	会.skill_cooldowns[0] = 0.0
	会.call("设默认忍术", 单体号)
	根.call("_select_character", 乙, {})
	玩.set("自动接近目标", 乙)
	## 腿④ 的前提钉子（2026-10-20 这两条红就是缺它才说不清是谁的锅）：`_冲选中目标` 开头那一道
	## 外层闸 `SkillExecute.moveToAttack():84` 的 `canAttack(curTarget)`（`SkillHandler:451` 里含
	## `DisplayUtil.outOfStage(怪,false)`）必须先为真，否则"自动放了 0 次"报的是闸、不是追发逻辑。
	var 托管: Node = 玩.get("_托管")
	_判(托管 != null, "夹具：玩家节点下要挂着 挂机托管（`能攻` 那道闸的实现体）")
	if 托管 != null:
		_判(托管.has_method("能攻"), "夹具：挂机托管 要实现 能攻（原版 `SkillHandler.canAttack:443`）")
		if 托管.has_method("能攻"):
			_判(bool(托管.call("能攻", 乙)),
					"前提：腿④ 选中的乙要算『能攻』（在舞台内 + 活着 + 没咬上别人 + 不是宠物怪 + 有身体盒）")
			## 阳性对照：同一条闸搬到舞台之外必须翻假 —— 没有这一条，上面那句等于恒真、没判到东西。
			乙.set("global_position", 乙.global_position + Vector2(20000.0, 0.0))
			_判(not bool(托管.call("能攻", 乙)),
					"阳性对照：搬到舞台外 20000 像素的乙『能攻』要翻假（原版 `outOfStage:152-185` 那道闸是活的）")
			_摆位(玩, 甲, 乙)
	var 次数丙 := int(玩.get("施法次数"))
	var 史前 := (玩.get("施法目标历史") as Array).size()	# 只查这一段新加的，前面两条腿的历史不算
	var 甲血前 := int(甲.get("hp"))
	for i in 150:
		await process_frame
		_摆位(玩, 甲, 乙)			# 怪会巡逻 ⇒ 每一帧钉回原位，否则"没打到"是它走开了不是逻辑错
		会.skill_cooldowns[0] = 0.0		# 手动清冷却，让"每拍都该放"这件事可观察
	var 追打次数 := int(玩.get("施法次数")) - 次数丙
	var 历史: Array = (玩.get("施法目标历史") as Array).slice(史前)
	var 全对乙 := true
	for 记 in 历史:
		if (记 as Array).size() != 1 or (记 as Array)[0] != 乙:
			全对乙 = false
	# 出手动作没播完不能再放（腿⑤ 刚钉的那条限制），所以 150 帧里是 2 发而不是 6 发 ——
	# 判 >= 2 就够证明"没再碰技能格它自己在放"，把上限卡死反而会把限制改动误判成回归。
	_判(追打次数 >= 2,
			"点怪之后没再碰技能格，选中的忍术**自己一直在放**（自动放了 %d 次）" % 追打次数)
	_判(全对乙 and not 历史.is_empty(),
			"自动追打的每一发都**只报选中的那只**（乙）—— 追打这段共 %d 发，没有一发顺报甲" % 历史.size())
	_判(int(甲.get("hp")) == 甲血前, "甲仍然一点没掉（%d）—— 反向证据：单体没有溅射" % int(甲.get("hp")))

	# ── ⑤ 施法限制（用户 2026-10-11 追加的三条）───────────────────────────────
	# 原版只有一处判据：`AbstractSkill.as:26` 的 `exeMovementActions = [STAND, WALK]`
	# + `:62-65 canExeMovementAction()` + `:106-124 fire()`（站着还要 currFoothold/grounded/landed）。
	# 例外照抄：普攻带 JUMP（`CommonAttack.as:27`）；`CLIMB` 不在**任何**一支的表里。
	# 这一腿全部**同步**判（不等帧）：重力会在下一帧把角色拉回地面。
	根.call("_select_character", 甲, {})
	await _等出手完(玩, 甲, 乙)
	会.skill_cooldowns[0] = 0.0
	玩.set("出手中", false)
	var 次数空 := int(玩.get("施法次数"))
	玩.set("on_ground", false)
	玩.call("use_skill_slot", 0)
	var 空中普攻 := bool(玩.call("perform_basic_attack", -1.0, 105.0, true))
	玩.set("on_ground", true)
	_判(int(玩.get("施法次数")) == 次数空, "跳在空中 ⇒ 技能放不出去（默认表只有 STAND/WALK）")
	_判(float(会.get_skill_cooldown(0)) <= 0.0, "空中这一发也没白转冷却")
	_判(空中普攻, "普攻在空中照样能打 —— 原版 `CommonAttack` 的表里带 JUMP（跳砍是原版行为，不是 bug）")

	会.skill_cooldowns[0] = 0.0
	玩.set("climbing", true)
	var 次数梯 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	var 梯上普攻 := bool(玩.call("perform_basic_attack", -1.0, 105.0, true))
	玩.set("climbing", false)
	_判(int(玩.get("施法次数")) == 次数梯, "爬梯子时技能放不出去")
	_判(not 梯上普攻, "爬梯子时**普攻也**放不出去（CLIMB 不在任何一支的 exeMovementActions 里）")

	会.skill_cooldowns[0] = 0.0
	var 落脚点 := String(玩.get("current_fh_id"))
	玩.set("current_fh_id", "")
	var 次数站 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	玩.set("current_fh_id", 落脚点)
	_判(int(玩.get("施法次数")) == 次数站 and 落脚点 != "",
			"站着但没落脚点 ⇒ 不放（原版 `fire():112-117` 的 currFoothold/grounded/landed；正控：原本有落脚点=%s）" % 落脚点)

	会.skill_cooldowns[0] = 0.0
	玩.set("出手中", true)
	var 次数出 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	玩.set("出手中", false)
	_判(int(玩.get("施法次数")) == 次数出,
			"上一发的出手动作还没播完 ⇒ 不能再放（`movementAction==ATTACK` 不在表里 = 用户说的「等放完才能动」那一半）")

	# 正向对照：限制全部解除后，同一格必须放得出去（否则上面四条"没放"是假绿）
	会.skill_cooldowns[0] = 0.0
	var 次数正 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数正 + 1,
			"阳性对照：限制解除后同一格确实放得出去（%d → %d）" % [次数正, int(玩.get("施法次数"))])

	# ── ⑥ 按技能键 ⇒ 自动锁"命中盒里最近的那只"（用户 2026-10-11 追加）──────────
	# 原版 `SkillExecute.as:420-436`：没有目标时先 `getSkillHitRect(技能,玩家,朝向)` 框怪表、
	# 取最近的一只设成 viewTarget+curTarget、停寻路，再放这一发。
	await _等出手完(玩, 甲, 乙)
	根.call("_clear_selected_character")
	会.skill_cooldowns[0] = 0.0
	玩.set("facing", 1)
	玩.global_position = Vector2(600.0, 300.0)
	甲.global_position = Vector2(640.0, 300.0)		# 近的（在 range=1 的单侧盒里）
	乙.global_position = Vector2(680.0, 300.0)		# 远的（也在盒里）
	_判(根.call("get_selected_enemy") == null, "这一腿开始前确实没有选中目标")
	var 次数锁 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数锁 + 1,
			"没选中怪、但盒里有怪 ⇒ 按下技能键照样放得出去（%d → %d）" % [次数锁, int(玩.get("施法次数"))])
	_判(根.call("get_selected_enemy") == 甲,
			"而且自动锁的是**最近的那只**（甲@%.0f，乙@%.0f）" % [甲.global_position.x, 乙.global_position.x])
	_判((玩.get("上次施法目标") as Array).size() == 1
			and (玩.get("上次施法目标") as Array)[0] == 甲, "这一发报出去的目标 = 自动锁到的甲")
	# 反向：把两只都挪到命中盒**之外**（range=1 是贴朝向的单侧盒，往左就出盒）
	await _等出手完(玩, 甲, 乙)
	根.call("_clear_selected_character")
	会.skill_cooldowns[0] = 0.0
	甲.global_position = Vector2(300.0, 300.0)
	乙.global_position = Vector2(260.0, 300.0)
	var 次数外 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数外 and 根.call("get_selected_enemy") == null,
			"盒里没有怪 ⇒ 不放、也不凭空锁一个目标（不是拿全图最近）")

	# ── ⑦ TAB 切目标（原版 `SkillHandler.switchTarget()`，键位 KeyDef 可改）────────
	_摆位(玩, 甲, 乙)
	根.call("_select_character", 甲, {})
	_判(根.call("get_selected_enemy") == 甲, "TAB 之前选中着甲")
	var 切一: Node = 玩.call("切换目标")
	_判(切一 != null and 根.call("get_selected_enemy") == 乙,
			"按一次 TAB 换到**第二近**的那只（乙）—— 原版靠 getNearestLifeObj 会 pop 掉最近者来轮换")
	var 切二: Node = 玩.call("切换目标")
	_判(切二 != null and 根.call("get_selected_enemy") == 甲, "再按一次换回甲（两只之间来回切）")

	# ──  放出去之前必须**面向目标**（用户 2026-10-11 实机报：背对怪也能放）──────────
	# 原版 `SkillExecute.as:122-127`：够得着 ⇒ 先
	#   `API.player.direction = GeomUtil.getRectangleDirection(player.outerBodyRect, target.outerBodyRect)`
	#   再 `fireSkill(...)`。⇒ 正确表现**不是**"背对就打不到"，而是**转身再打**。
	await _等出手完(玩, 甲, 乙)
	会.skill_cooldowns[0] = 0.0
	玩.global_position = Vector2(600.0, 300.0)
	甲.global_position = Vector2(660.0, 300.0)		# 怪在右边
	乙.global_position = Vector2(180.0, 300.0)		# 另一只挪到既远又不在盒里
	玩.set("facing", -1)						# 故意背对（朝左）
	根.call("_select_character", 甲, {})
	_判(int(玩.get("facing")) == -1, "起手时确实背对着甲（facing=-1）")
	var 次数背 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数背 + 1,
			"背对选中怪按下技能键 ⇒ 这一发照样放得出去（%d → %d）" % [次数背, int(玩.get("施法次数"))])
	_判(int(玩.get("facing")) == 1,
			"但**放之前已经转身朝怪**：facing 应 = 1，实得 %s（原版 :125 那一行）" % str(玩.get("facing")))
	_判((玩.get("上次施法目标") as Array).size() == 1 and (玩.get("上次施法目标") as Array)[0] == 甲,
			"转身之后报出去的还是选中的那一只甲，没有顺手改成别的目标")
	# 反向：盒里没有怪、也没选中 ⇒ 不放，**也不许凭空转身**（转身只跟着"真放这一发"走）
	await _等出手完(玩, 甲, 乙)
	根.call("_clear_selected_character")
	会.skill_cooldowns[0] = 0.0
	玩.set("facing", -1)
	甲.global_position = Vector2(660.0, 300.0)		# 在身后
	乙.global_position = Vector2(180.0, 300.0)		# 在朝向前方、但远到盒外（range=1 是贴身的单侧盒）
	var 次数空转 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数空转 and int(玩.get("facing")) == -1,
			"没目标 ⇒ 不放、facing 也保持原样（转身不是无条件动作）—— 实得 次数+%d facing=%s" % [
				int(玩.get("施法次数")) - 次数空转, str(玩.get("facing"))])
	# 反向 2：**面积技没有"选中的那一只"⇒ 放得出去，但不该被转身逻辑碰到**。
	# 原版 :125 那句转身只在"有目标要打"那条支上；面积技（`case 2`）压根不带目标。
	# （变异实测 N21 就是拿这条逼出来的：把转身写成无条件动作时，上面那条反向判据
	#   照样绿 —— 因为单体那一支在转身之前就 return 了，只有面积这一支会走到那行。）
	await _等出手完(玩, 甲, 乙)
	根.call("_clear_selected_character")
	会.skill_cooldowns[1] = 0.0
	_摆位(玩, 甲, 乙)
	玩.set("facing", -1)
	var 次数面 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 1)
	_判(int(玩.get("施法次数")) == 次数面 + 1 and int(玩.get("facing")) == -1,
			"面积技无选中 ⇒ 照放、但**不转身**（实得 次数+%d facing=%s）" % [
				int(玩.get("施法次数")) - 次数面, str(玩.get("facing"))])

	# ──  普攻（平A）也在出手前转身 —— 用户 2026-10-11 那条报的是"技能"，但原版同一行也管普攻 ──
	# `SkillExecute.moveToAttack():66-77` 取的是 `targetHandler.defaultSkill`，而**没选忍术时
	# `defaultSkill` 就是普攻**；`:122-127` 那句"够得着 ⇒ 先 `direction = getRectangleDirection(...)`
	# 再 fireSkill"服务的正是这一条。⇒ 点了一只身后的怪，平A 也要转身打，不能朝反方向空挥。
	await _等出手完(玩, 甲, 乙)
	玩.global_position = Vector2(600.0, 300.0)
	玩.set("facing", -1)					# 朝左 = 背对甲
	甲.global_position = Vector2(640.0, 300.0)	# 在右后方：普攻盒（朝左时 [550,600]）够不到
	乙.global_position = Vector2(200.0, 300.0)
	根.call("_select_character", 甲, {})
	var 打到背 := bool(玩.call("perform_basic_attack", -1.0, 105.0, true))
	_判(打到背 and int(玩.get("facing")) == 1,
			"背对选中怪按平A ⇒ 转身后打得到（打到=%s facing=%s）" % [str(打到背), str(玩.get("facing"))])
	# 反向：**没有选中怪**时不许凭空转身 —— 盒本来就只朝一侧，框到谁就打谁，转谁都不对。
	await _等出手完(玩, 甲, 乙)
	根.call("_clear_selected_character")
	玩.global_position = Vector2(600.0, 300.0)
	玩.set("facing", -1)
	甲.global_position = Vector2(640.0, 300.0)
	乙.global_position = Vector2(200.0, 300.0)
	var 打到空 := bool(玩.call("perform_basic_attack", -1.0, 105.0, true))
	_判(not 打到空 and int(玩.get("facing")) == -1,
			"没选中怪 ⇒ 这一挥打不到身后的甲、也不转身（打到=%s facing=%s）" % [str(打到空), str(玩.get("facing"))])

	# ──  够不着 ⇒ 不放这一发，先走过去（#194，用户：螺旋丸/雷切/烈焰斩/水之刃 这种近战技）──
	# 原版 `SkillExecute.as:376-435` 那一整支**没有 fireSkill**：只 `toAttackAnemy=true` +
	# `stopPathFind()` + `defaultSkill=param1`；放出去的是下一拍 `moveToAttack()`（够得着才放）。
	await _等出手完(玩, 甲, 乙)
	玩.call("cancel_auto_path")
	玩.set("自动接近目标", null)
	会.skill_cooldowns[0] = 0.0
	会.set("默认忍术", 0)
	玩.set("facing", 1)
	玩.global_position = Vector2(600.0, 300.0)
	甲.global_position = Vector2(1200.0, 300.0)		# range=1 的盒是 [600,700] ⇒ 这只在盒外
	乙.global_position = Vector2(1260.0, 300.0)
	根.call("_select_character", 甲, {})
	var 次数远 := int(玩.get("施法次数"))
	var 蓝远 := int(会.player_stats.get("mp", 0))
	var 冷却远 := float(会.skill_cooldowns[0])
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数远,
			"选中一只**射程外**的怪按技能 ⇒ 这一发不放（不站原地打空）")
	_判(int(会.player_stats.get("mp", 0)) == 蓝远 and float(会.skill_cooldowns[0]) == 冷却远,
			"而且不扣蓝、不转冷却（原版这一刻根本没走到 fireSkill）")
	_判(int(会.get("默认忍术")) == 单体号,
			"按下哪一枚，追打时就用哪一枚（原版 :435 `defaultSkill = param1`）—— 实得 %d" % int(会.get("默认忍术")))
	_判(玩.get("自动接近目标") == 甲, "并且把这只设成`自动接近目标` ⇒ 下一拍开始靠近")
	_判(int(玩.get("facing")) == 1, "靠近之前先转身朝着它")
	# 正向对照：走进射程 ⇒ 同一枚立刻放得出去（否则上面四条"没放"是假绿）
	玩.global_position = Vector2(600.0, 300.0)
	甲.global_position = Vector2(640.0, 300.0)
	乙.global_position = Vector2(1260.0, 300.0)
	会.skill_cooldowns[0] = 0.0
	var 次数近 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 0)
	_判(int(玩.get("施法次数")) == 次数近 + 1,
			"走进射程后按同一枚 ⇒ 放得出去（%d → %d）" % [次数近, int(玩.get("施法次数"))])

	# ──  在线投掷技：**弹到身上才发结算请求（42），广播（1328）当场就发**（#193 #218）──
	# 服务端一收到 42 就当场结算并回包 ⇒ 掉血与受击特效跟着回包立刻出现。
	# 原来这里是"按下就发"，所以玩家看到的是"先掉血、后飞到"。
	await _等出手完(玩, 甲, 乙)
	玩.call("cancel_auto_path")
	玩.set("自动接近目标", null)
	根.call("_clear_selected_character")
	会.skill_cooldowns[2] = 0.0
	玩.set("facing", 1)
	玩.global_position = Vector2(600.0, 300.0)
	甲.global_position = Vector2(760.0, 300.0)		# 1001002 是 range=2（盒 [600,1000]）⇒ 够得着，但要飞一段
	乙.global_position = Vector2(620.0, 300.0)
	根.call("_select_character", 甲, {})
	var 假 := 假后端.new()
	玩.set("_backend", 假)
	var 次数球 := int(玩.get("施法次数"))
	玩.call("use_skill_slot", 2)
	_判(int(玩.get("施法次数")) == 次数球 + 1, "投掷技这一发确实放出去了（动作与飞行物都起了）")
	_判(假.发过.is_empty(),
			"⭐ 但**当场没有发伤害请求** —— 弹还在半路（用户报的「先掉血后飞到」就是这一步）")
	## ⭐ 另一半（2026-10-14 用户"从别人窗口看技能特效延迟也很高"）：**出手广播必须当场发**。
	## 上一轮 #193 把广播与结算捆在一起压到命中帧 ⇒ 旁观者要等这段飞行（≈470 毫秒）
	## 才看到出手动作与起手特效。原版的分工是 `hitTest():629` 一出手就发广播。
	_判(假.广播过.size() == 1 and int(假.广播过[0]["id"]) == 投掷号,
			("⭐ 而**出手广播当场就发出去了**（实得 %d 条）—— 别人的动画与起手特效走这一条，"
			+ "不该跟着结算一起等弹落地") % 假.广播过.size())
	## 判"多久之后才发"用**真实毫秒**，不用帧数：无头跑不限帧，同一份代码这次 69 帧、
	## 上次 105 帧，拿帧数当判据必然假红。原版这条的时间是可以算出来的：
	## `ballAfter=250ms`（`数据/技能动画元数据.json` 的 ball.ballAfter）
	## + 飞行 `110px ÷ 500px/s = 220ms`（出手点 = 玩家x+50，`AbstractThrowSkillEffect.as:23-24`）
	## ≈ **470ms** ⇒ 下界 200ms（不许当场发）、上界 1000ms（不许回头去等施法特效播完）。
	var 起 := Time.get_ticks_msec()
	var 帧 := 0
	while 假.发过.is_empty() and 帧 < 600:
		await process_frame
		玩.global_position = Vector2(600.0, 300.0)
		甲.global_position = Vector2(760.0, 300.0)		# 怪有巡逻 AI ⇒ 每帧钉回去
		乙.global_position = Vector2(620.0, 300.0)
		帧 += 1
	var 耗时 := Time.get_ticks_msec() - 起
	_判(假.发过.size() == 1, "过了 %d 毫秒，弹落地 ⇒ 请求发出去了（共 %d 次）" % [耗时, 假.发过.size()])
	_判(耗时 >= 200 and 耗时 <= 1000,
			"这一发的落地时刻落在原版算出来的 ≈470ms 附近（200..1000ms 之间）—— 实得 %d 毫秒。" % 耗时
			+ "⚠ 这条只兜住「别当场发、也别跑飞」；`canBallAppear()` 的二选一它**钉不住**"
			+ "（变异 N28 把 `ballAfter≠0` 改回「也等施法特效播完」，耗时仍在界内 ⇒ 没响 ⇒"
			+ " 那一支目前只有代码注释与 §9 的算式作据，运行期未验）")
	_判(假.发过.size() == 1 and int(假.发过[0]["id"]) == 投掷号
			and int(假.发过[0]["ids"][0]) == int(甲.get("object_id")) and (假.发过[0]["ids"] as Array).size() == 1,
			"发出去的包 = 这一枚投掷技 + 只报选中的那一只甲（不是全图、不是框到的全部）")
	## ⭐ **位移包这条腿自己也要有判据**（§3.253）。上一轮桩只声明三参、`玩家.gd:1624` 实发四参
	## ⇒ `Expected 3 argument(s)` 把每一发都当场丢掉，而门**全绿** —— 因为 `位移过` 只记不判。
	## 下面两条同时钉两件事：① 桩与产品的**参数个数**对得上（对不上 ⇒ 一条也记不到）；
	## ② 包里的**朝向 = 翻过之后那一个**（原版 `Sampler.as:83-95` 的脏标记含 `DIRECTION`，
	##    少了这条"原地转身"永远传不出去，收端停在上次移动时的朝向 —— 10-17 双修那个
	##    "他该朝我，结果背对我"就是这一笔）。
	根.call("_clear_selected_character")
	玩.call("cancel_auto_path")
	玩.set("自动接近目标", null)
	var 位移前 := 假.位移过.size()
	玩.set("facing", -1)
	var 位移帧 := 0
	while 假.位移过.size() == 位移前 and 位移帧 < 60:
		await process_frame
		玩.global_position = Vector2(600.0, 300.0)		# 钉住位置 ⇒ 记到的这条只因"朝向翻"才发
		甲.global_position = Vector2(760.0, 300.0)
		乙.global_position = Vector2(620.0, 300.0)
		位移帧 += 1
	_判(假.位移过.size() > 位移前,
			"原地转身（facing 翻成 -1）⇒ 当场发位移包，不等节流周期（实得 +%d 条、%d 帧）" % [
				假.位移过.size() - 位移前, 位移帧])
	_判(假.位移过.size() > 位移前
			and int((假.位移过 as Array)[假.位移过.size() - 1]["朝"]) == -1,
			"而且包里的朝向 = -1（第 4 参一路带到 `send_movement`；"
			+ "实得 %s）" % str((假.位移过 as Array)[假.位移过.size() - 1]["朝"]
				if 假.位移过.size() > 位移前 else "没发"))
	# 反向：**没有 ball 相位**的单体技在线 ⇒ 当场就该发，不能因为等不到命中把这一发吞了
	await _等出手完(玩, 甲, 乙)
	根.call("_clear_selected_character")
	会.skill_cooldowns[0] = 0.0
	玩.global_position = Vector2(600.0, 300.0)
	甲.global_position = Vector2(640.0, 300.0)
	乙.global_position = Vector2(1260.0, 300.0)
	根.call("_select_character", 甲, {})
	var 发前 := 假.发过.size()
	玩.call("use_skill_slot", 0)
	_判(假.发过.size() == 发前 + 1,
			"没球美术的单体技在线 ⇒ 当场发请求（实得 +%d 次）" % (假.发过.size() - 发前))
	假.free()
	玩.set("_backend", null)
	_尾()
