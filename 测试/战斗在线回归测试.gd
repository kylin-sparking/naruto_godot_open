extends SceneTree

## 「战斗在线」门（2026-10-03，两条在线专属 bug 的门）——走真实服务端夹具：
##   ① **怪出手帧到得了 text 客户端**（`241:1:...`）：
##      夹具的 `_broadcast_server_monster_attack` 原来只把 cmd=1 发给 binary 参与者，
##      我们（text 模式）永远收不到 → 在线怪打人**没有出手动画**（探针实测：被击 26 次、
##      出手帧 0 次）。钉 `monster_attacked` 有帧、object 对得上、direction 是 ±1。
##   ② **杀掉的怪要从 `_entities` 摘掉并释放**：服务端只发 KILL(239)、**从不发 163**，
##      原来 kill 分支只清 `_entities_by_object`、演员也从不 free → 尸体节点带 sprite
##      永久留在 `_entities`（探针实测：连杀后实体数纹丝不动）。
##   ③ 顺带把 §3.87 的 184→伤害数字**在场景层**钉一遍（协议层门测解析，这里测真挂到演员身上）。
## 由 `开发工具/跑在线用例.ps1 -用例 战斗在线` 调（它起隔离夹具；**不能并行**）。

const 地图实体脚本 := preload("res://脚本/地图/地图实体.gd")
const 伤害数字脚本 := preload("res://脚本/角色/伤害数字.gd")
## 木叶村东侧那扇门（portal 3 `east00`）通往的野外图。现查 `数据/地图/木叶森林/地图.json`：
## `life` 里 40 条 type=m（终结谷浅滩只有 2 条，火之国边境 37 条）⇒ 这条门后面要打野怪，
## 落到这张图才够靶子。
const 野外图 := 102010000
const 村图 := 100000000
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

var _失败: Array[String] = []
var _受检 := 0
var _原端口 := -1		# `game_settings.backend_port` 跑前的值（只还原自己动过的那一键）


## 端口这一键是**共享的会话设置** ⇒ 用完必须还原，否则下一条用例（甚至用户自己的客户端）
## 会连到 18698 这台已经关掉的夹具上。跑前 -1 = 没动过，就不写回。
func _还原端口() -> void:
	if _原端口 < 0:
		return
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		(会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
	_原端口 = -1


## ⭐ 假玩家：只为了把 `地图实体` 那一头的接线**用真服务端帧**量出来。
## 在线用例里根本没有真的 玩家 节点（世界场景才会建），而震屏的调用链是
## `184 解码 → monster_damaged → 地图实体._on_server_monster_damaged → _player._震屏()`，
## 少了这个挂钩就只能证明"包解出来了"，证不了"震屏真被喊起来"（2026-10-11 用户报的正是这一环）。
class 震屏记录器 extends Node2D:
	## ⚠ 这两个字段是**真玩家身上有的**（`玩家.gd` 的 `facing` / `on_ground`）：
	## `_播放玩家伤害数字` 在放的那一刻要读它们（决定朝向、决定「我闪」还是「跳闪」），
	## 桩上没有 ⇒ `int(null)` 运行期直接报 "Nonexistent 'int' constructor"，
	## 节点已经 add_child 了但 `播放()` 没跑 ⇒ 门数得出条数、读出来全是空串。
	var facing := 1
	var on_ground := true
	var 次数 := 0
	func _震屏() -> void:
		次数 += 1


func _initialize() -> void:
	call_deferred("_run")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _停(话: String) -> void:
	_还原端口()
	printerr("战斗在线回归测试：中断 - " + 话)
	quit(1)

func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if backend == null or 会话 == null:
		_停("缺单例")
		return
	## ⚠ 必须自己把夹具端口写回 `game_settings.backend_port`：客户端只认这一键、**不读环境变量**
	##   （`后端连接.gd:521` 默认 `DEFAULT_PORT = 18684`）。`跑在线用例.ps1` 给本条起的是
	##   **18698/18699** 那一对 ⇒ 不写就等于去连 18684 上用户自己那台号（今天那台没开，
	##   症状是"连接超时"，开着的时候就是拿用例点用户的角色）。同 §心法.md ⑧ 那条坑。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18698
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	print("连夹具端口 %d（账号 %s）" % [口, String(设置.get("backend_account", ""))])
	backend.sync_character()
	if not await _等(func(): return bool(backend.in_game), 15000):
		_停("进不了后端：%s - %s" % [backend.status, backend.detail])
		return
	## 出生图不固定（夹具新建的号有时落在木叶村 100000000 —— 那张图 `life` 只有 26 个 n、
	## **一只怪都没有**；有时落在终结谷浅滩 101010000）。这条门后面全程要打野怪，
	## 所以没怪就**按真门的编号请求换图**（`request_map_change` 内部就是 `_find_portal_to_map`
	## ⇒ 发的是 `33:2:-1:<门号>`，与服务端 `handle_enter_portal` 那条完全同一条路，
	## 不是给客户端塞一个假状态）。
	## 出生图不固定：夹具新建的号可能落在**木叶村**（`数据/地图/木叶村/地图.json` 的 `life`
	## 只有 26 条 type=n，**一只怪都没有**）、也可能落在**终结谷浅滩**（只有 2 条 m、
	## mobTime=1800 ⇒ 杀了要等半小时才回）。这条门后面全程要打野怪，所以怪少于 8 只就
	## **按真门的编号请求换图**：`request_map_change` 内部就是 `_find_portal_to_map`
	## ⇒ 发出去的是 `33:2:-1:<门号>`，跟玩家自己走到门口点门是同一条服务端路径
	## （`handle_enter_portal`），不是给客户端塞一个假状态。目的地 = **木叶森林**
	## （40 条 m，够当靶子）；从浅滩去森林没有直达门，先回村再往东 —— 两跳都是真门。
	if (backend.map_monsters as Dictionary).size() < 8:
		var 出发图 := int(backend.get("authoritative_map_id"))
		var 跳表: Array[int] = []
		if 出发图 == 野外图:
			pass		# 已经在木叶森林，只是怪还没生出来，往下等
		elif 出发图 == 村图:
			跳表.append(野外图)
		else:
			跳表.append(村图)
			跳表.append(野外图)
		for 目标 in 跳表:
			var 请求过: bool = backend.request_map_change(目标, 0, 0)
			_查(请求过, "从图 %d 该能在本图 portal 表里反查到通往 %d 的门并发 33 请求（真人走门那条路）"
					% [出发图, 目标])
			if not await _等(func(): return int(backend.get("authoritative_map_id")) == 目标, 15000):
				_停("请求去 %d 之后 15 秒 `authoritative_map_id` 还是 %d（换图帧没回来）"
						% [目标, int(backend.get("authoritative_map_id"))])
				return
		if not await _等(func(): return (backend.map_monsters as Dictionary).size() >= 8, 20000):
			_停("到了 %d 之后 20 秒服务端只发了 %d 只怪（该有 40 个 m 位）"
					% [野外图, (backend.map_monsters as Dictionary).size()])
			return
	var life: Node = (地图实体脚本.new()) as Node
	root.add_child(life)
	for _帧 in 4:
		await process_frame
	if not bool(life.get("_server_authoritative")):
		_停("地图实体没进服务端权威模式")
		return
	var 目标号 := 0
	for 号 in backend.map_monsters:
		var 状: Dictionary = backend.map_monsters[号]
		if int(状.get("hp", 1)) > 0:
			目标号 = int(号)
			break
	if 目标号 == 0:
		_停("没有活怪可打")
		return
	## ⚠ 这一刻的怪表要**当场拍成快照**：下面的击杀段会把它们一只只从 `map_monsters` 里摘掉，
	## 之后 194 那几段还要拿"本图真怪的模板号/出手招"当料，读实时表就读空了
	## （2026-10-11 实测：浅滩只有 2 只，杀完 `扫过的号` 是空的 ⇒ `扫过的号[0]` 直接越界）。
	var 开局怪号: Array[int] = []
	for 号 in backend.map_monsters:
		开局怪号.append(int(号))
	var 开局怪状态: Dictionary = (backend.map_monsters as Dictionary).duplicate(true)
	# —— 信号捕获 ——
	var 出手帧: Array[Dictionary] = []
	var 伤害帧: Array[Dictionary] = []
	var 杀掉号 := [0]
	backend.monster_attacked.connect(func(状: Dictionary): 出手帧.append(状))
	backend.monster_damaged.connect(func(号: int, 量: int, 暴: bool, _受击: bool, 自己: bool, 活着: bool):
		伤害帧.append({"object_id": 号, "damage": 量, "critical": 暴, "自己打出": 自己, "打完活着": 活着}))
	backend.monster_killed.connect(func(号: int, _a: int): 杀掉号[0] = 号)
	var 目标演员: Object = (life.get("_entities_by_object") as Dictionary).get(目标号)
	if 目标演员 == null:
		_停("地图实体里没有目标怪的演员（object_id=%d）" % 目标号)
		return
	var 假玩家: 震屏记录器 = 震屏记录器.new()		#  typed 保住 `.次数` 的静态访问
	root.add_child(假玩家)
	life.set("_player", 假玩家)		# 在线腿的震屏出口就挂在这里（真包 ⇒ 真调用）

	# —— 打杀掉这只怪（钉 bug①尸体回收 + bug③184→伤害数字）——
	# 说明：bug②（241 cmd=1 出手帧）在**这条在线门里不做"是否到达"的断言** ——
	# 冷夹具的普通怪是被动的、不主动上手，而满级角色一两刀就秒了它、它来不及反击，
	# "怪主动出手"在线不可稳定复现。它的**客户端解析**由 `后端协议回归测试` 离线确定地钉，
	# 它的**服务端补发**（text 参与者也要收到 241:1）由活体探针验过（站桩被追 20s：194 到 26、241:1 到 26）。
	# 这里若恰好收到出手帧（怪临死反扑），就顺手校验它的字段形状。
	var 数字挂上 := false
	var 打死 := false
	for _刀 in range(60):
		var 状: Dictionary = backend.map_monsters.get(目标号, {})
		if 状.is_empty():
			打死 = true
			break
		backend.send_movement(Vector2(float(状.get("x", 0)) - 12.0, float(状.get("y", 0))), 1)
		await create_timer(0.08).timeout
		backend.request_basic_attack(目标号,
				Vector2(float(状.get("x", 0)), float(状.get("y", 0))),
				1 if _刀 % 2 == 0 else -1)
		await create_timer(0.3).timeout
		if not 数字挂上 and not 伤害帧.is_empty():
			数字挂上 = _有伤害数字节点(目标演员)
		if 杀掉号[0] == 目标号:
			打死 = true
			break
	for 首 in 出手帧:
		if int(首.get("direction", 0)) not in [1, -1]:
			_查(false, "收到的出手帧 direction 不是 ±1（实际 %s）" % str(首.get("direction")))
			break
	_查(bool(伤害帧.is_empty()) == false, "在线出手没有等到 184 伤害结算帧")
	_查(数字挂上, "184 的伤害数字没挂到演员节点下（§3.87 的 184→_spawn_damage_number 链断在场景层）")
	## ── 用**真服务端帧**钉在线那三位（这几条会抓到今天那种解码 bug）──
	## 现查（10-11）：夹具这张图 39 只小怪、角色一刀 300 血 ⇒ 每只怪只来**一条** 184 且 alive 恒 false，
	## 所以"打到半血那一包"在线**观测不到**（那两位归协议门 P1~P3 用服务端字面量钉）。这里改扫多只怪，
	## 用真包钉住"是不是自己打出的"与"暴击→震屏"这一对。暴击是服务端骰子（夹具把敏捷点到 1000 ⇒
	## 原版上限夹到 50%/刀），扫 10 只一条都不爆的概率约 0.1% ⇒ 断言写成"震屏次数 == 暴击条数"
	## 这种**两侧都算**的形状，不写成"必须爆"（那等于把门交给骰子）。
	var 扫过的号: Array[int] = []
	for 号 in backend.map_monsters:
		扫过的号.append(int(号))
	for 只 in range(mini(9, 扫过的号.size())):
		var 他号 := 扫过的号[只]
		var 他状: Dictionary = backend.map_monsters.get(他号, {})
		if 他状.is_empty():
			continue
		backend.send_movement(Vector2(float(他状.get("x", 0)) - 12.0, float(他状.get("y", 0))), 1)
		await create_timer(0.06).timeout
		backend.request_basic_attack(他号, Vector2(float(他状.get("x", 0)), float(他状.get("y", 0))), 1)
		await create_timer(0.22).timeout
	var 我打的事件: Array[Dictionary] = []
	for 件 in 伤害帧:
		我打的事件.append(件)
	var 全部自己 := not 我打的事件.is_empty()
	var 暴击条 := 0
	for 件 in 我打的事件:
		if not bool(件.get("自己打出", false)):
			全部自己 = false
		if bool(件.get("critical", false)):
			暴击条 += 1
	print("[诊断] 扫了 %d 只怪：184 事件 %d 条，其中暴击 %d 条，震屏被喊 %d 次" % [扫过的号.size(), 我打的事件.size(), 暴击条, 假玩家.次数])
	_查(我打的事件.size() >= 6,
		"扫多只怪之后该攒够 184 事件（每条都是一个真包）；实得 %d 条 ⇒ 出手/回帧这条链在线没跑起来" % 我打的事件.size())
	_查(全部自己,
		"真 184 帧解出来的『由自己打出』该恒真（isPlayer[1]=1 且 characterId[2]=本人，两位都在包里）")
	_查(我打的事件.size() > 0 and not bool((我打的事件[我打的事件.size() - 1] as Dictionary).get("打完活着", true)),
		"最后一条 184（打死那一包）的 alive 该是 false；实得 %s" % str((我打的事件[我打的事件.size() - 1] as Dictionary).get("打完活着", null)))
	_查(假玩家.次数 == 暴击条,
		"在线每一发『自己打出的暴击』恰好喊一次震屏（多了=不暴击也抖，少了=接线又断了）；实得 震屏 %d / 暴击 %d" % [假玩家.次数, 暴击条])
	if not 打死:
		_停("60 刀没打掉目标，无法验证尸体回收")
		return
	# 死亡动画（die1）播完才 free：给足 3 秒
	await create_timer(3.2).timeout
	var 还挂着 := false
	for e in (life.get("_entities") as Array):
		# ⚠️ 不能用 `Array.has(目标演员)` —— 目标演员若已 free，把 freed 对象传进
		#    TypedArray.has 会直接报 "previously freed"（2026-10-03 跑红踩过）。逐个判有效性。
		if e == 目标演员 and is_instance_valid(e):
			还挂着 = true
	_查(not 还挂着, "杀掉的怪还挂在 `_entities` 里（在线尸体泄漏复发：kill 分支要 erase）")
	_查(not is_instance_valid(目标演员),
			"杀掉的怪节点没被释放（`_服务端死亡` 播完 die1 要 queue_free —— 服务端从不发 163 兜底）")
	# ── 194「怪物技能流水字 + 暴击位 + 闪开位」的在线那一半（#197）──────────
	## 服务端发法（`fake_flash_server.py:36966`，逐字节照它造）：
	##   `194:<character_id>:<skill>:<true/false>:<damage>:<action>:<oid>:<int(critical)>:0`
	## 冷夹具的普通怪不主动上手（上面 bug② 那段说明过），所以这里**照服务端那一条的格式**
	## 喂进真解析入口 `_handle_bridge_text` —— 量的是"服务端那样发，我们这头到底飘什么"，
	## 不是自己给自己递一个字典（那等于自证）。招号也不是编的：现查 `数据/怪物.json`，
	## 1574 只怪里 **632 只**的出手招在 `数据/技能对手技.json` 那 14 条里
	## （例：`1000005 荆棘刺蛇` lv12 用 2001「五行封印」⇒ 该飘「五行解印」）。
	var 我号 := int(backend.get("character_id"))
	_查(我号 > 0, "在线这一半要拿**自己**的 character_id 造 194，会话里该有号；实得 %d" % 我号)
	var 旁号 := 开局怪号[0]

	# A：招 2001、状态没生效 ⇒ 伤害那条之后**追加**一条蓝色克制提示
	_清飘字(假玩家)
	backend._handle_bridge_text("194:%d:2001:false:123:30:%d:0:0" % [我号, 旁号])
	_排空飘字(假玩家)
	_查(_数飘字(假玩家) == 2,
			"真 194 帧（skillTrigger=false）该飘两条：伤害红字 + 蓝色流水字；实得 %d 条" % _数飘字(假玩家))
	_查(_最新飘字文本(假玩家) == "五行解印",
			"最后一条该是克制提示「五行解印」（2001 的对手技）；实得「%s」" % _最新飘字文本(假玩家))
	_查(_最新飘字颜色(假玩家) == Color(50.0 / 255.0, 153.0 / 255.0, 1.0),
			"克制提示走 `CocoStatType.SKILL` = #3299FF 蓝，不是挨打的红；实得 %s" % str(_最新飘字颜色(假玩家)))

	# B：同一招、状态真生效了 ⇒ 原版那个 `if(!skillTrigger)` 整支不进
	_清飘字(假玩家)
	backend._handle_bridge_text("194:%d:2001:true:123:30:%d:0:0" % [我号, 旁号])
	_排空飘字(假玩家)
	_查(_数飘字(假玩家) == 1 and _最新飘字文本(假玩家) == "  - 123",
			"skillTrigger=true 只该有伤害那一条；实得「%s」共 %d 条" % [_最新飘字文本(假玩家), _数飘字(假玩家)])

	# C：拿**本图真怪自己数据里的招**造一发（服务端发的就是这个号）⇒ 飘不飘由那张 14 条表说了算
	## 一只怪的 `skill` 段常常是好几条（`attack1` 是普通招 8000、`skill1` 才是带克制的那条），
	## 所以要把这只怪**所有**招都翻一遍，优先挑一条表里有对手技的 —— 挑不到才退回第一招。
	var 本图怪 := 0
	var 本图招 := 8000
	var 对手名: String = ""
	var 怪表: Dictionary = GAME_DATA.取表("怪物")
	for 号2 in 开局怪号:
		var 状2: Dictionary = 开局怪状态.get(号2, {})
		var 模板 := int(状2.get("monster_id", 0))
		var 定义: Dictionary = 怪表.get(str(模板), {})
		var 招集: Dictionary = 定义.get("skill", {})
		for key in 招集:
			var 一条 = 招集[key]
			if not (一条 is Dictionary):
				continue
			var 招号 := int((一条 as Dictionary).get("skill", 0))
			if 招号 <= 0:
				continue
			if 本图怪 == 0:
				本图怪 = 模板
				本图招 = 招号
			var 名: String = GAME_DATA.skill_flow_text(招号)
			if 名 != "":
				本图怪 = 模板
				本图招 = 招号
				对手名 = 名
				break
		if 对手名 != "":
			break
	print("[诊断] 本图取到怪 %d、出手招 %d ⇒ 对手技名「%s」" % [本图怪, 本图招, 对手名])
	_清飘字(假玩家)
	backend._handle_bridge_text("194:%d:%d:false:123:30:%d:0:0" % [我号, 本图招, 旁号])
	_排空飘字(假玩家)
	_查(_数飘字(假玩家) == (2 if 对手名 != "" else 1)
			and (_数飘字(假玩家) == 1 or _最新飘字文本(假玩家) == 对手名),
			"拿本图怪真招 %d 造一发：表里有对手技就该两条（末条「%s」），没有就该一条；实得 %d 条「%s」"
			% [本图招, 对手名, _数飘字(假玩家), _最新飘字文本(假玩家)])

	# D：暴击位（服务端第 7 段发的就是 `int(critical)`）⇒ 打在自己身上写「致命」
	_清飘字(假玩家)
	backend._handle_bridge_text("194:%d:8000:false:123:30:%d:1:0" % [我号, 旁号])
	_排空飘字(假玩家)
	_查(_最新飘字文本(假玩家) == "致命  - 123",
			"194 的 hit_flag=1 ⇒ 「致命  - 123」（8000 没有对手技，只这一条）；实得「%s」"
			% _最新飘字文本(假玩家))

	# E：damage=0 不是空包 —— 原版那一支照样飘「我闪」（服务端反弹/闪开那段确实会发 0）
	_清飘字(假玩家)
	backend._handle_bridge_text("194:%d:2001:false:0:30:%d:0:0" % [我号, 旁号])
	_排空飘字(假玩家)
	_查(_数飘字(假玩家) == 1 and _最新飘字文本(假玩家) == "我闪",
			"damage=0 那一发只飘「我闪」，不该把克制提示挤出来；实得「%s」共 %d 条"
			% [_最新飘字文本(假玩家), _数飘字(假玩家)])

	if not _失败.is_empty():
		for 条 in _失败:
			printerr("战斗在线回归测试：" + 条)
		_还原端口()
		quit(1)
		return
	print("战斗在线回归测试：通过（%d 条断言：出手帧形状/伤害数字/尸体回收）" % _受检)
	backend.disconnect_backend()
	_还原端口()
	quit(0)

## 演员眼下有没有挂着一条 `伤害数字`（按脚本身份认；血条里也有 Label，loose 匹配会假绿）。
func _有伤害数字节点(演员: Object) -> bool:
	if 演员 == null or not is_instance_valid(演员):
		return false
	for i in 演员.get_child_count():
		var 子: Node = 演员.get_child(i)
		if 子 != null and 子.get_script() == 伤害数字脚本:
			return true
	return false
## ── 玩家身上那串飘字的读法（在线 194 那一半用；判"追加一条"必须能数、判文案必须读末条）──
## 队列是原版节奏（每个角色每 400 毫秒放一条），投完不排空就读 ⇒ 读到空串。
func _飘字节点(谁: Node) -> Array:
	var 出: Array = []
	if 谁 == null or not is_instance_valid(谁):
		return 出
	for 子 in 谁.get_children():
		if 子.get_script() != null and String((子.get_script() as Script).resource_path).contains("伤害数字"):
			出.append(子)
	return 出

func _数飘字(谁: Node) -> int:
	return _飘字节点(谁).size()

func _清飘字(谁: Node) -> void:
	for 子 in _飘字节点(谁):
		谁.remove_child(子)
		(子 as Node).queue_free()

func _最新飘字(谁: Node) -> Node:
	var 条 := _飘字节点(谁)
	return (条[条.size() - 1] as Node) if not 条.is_empty() else null

func _最新飘字文本(谁: Node) -> String:
	var 件 := _最新飘字(谁)
	if 件 == null:
		return ""
	var 签 = 件.get("_标签")
	return (签 as Label).text if 签 is Label else ""

func _最新飘字颜色(谁: Node) -> Color:
	var 件 := _最新飘字(谁)
	if 件 == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var 签 = 件.get("_标签")
	return (签 as Label).get_theme_color("font_color") if 签 is Label else Color(0.0, 0.0, 0.0, 0.0)

func _排空飘字(谁: Node) -> void:
	if 谁 == null or not is_instance_valid(谁):
		return
	var 队 := 谁.get_node_or_null("飘字队列")
	if 队 != null:
		队.call("全放")

