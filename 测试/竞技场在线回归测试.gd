extends SceneTree
## 竞技场（2306 PK_ACTION）的**端到端在线用例**：真连夹具起的那台服务端，一环都不替身。
##
## 判的是「点它有请求 ⇒ 服务端认 ⇒ 回帧 ⇒ 客户端吃进控制器」这一段：
##   客户端 `request_arena_*` / `request_basic_attack` → 服务端 `handle_pk_action:28912`
##   → `_start_arena_challenge:29373`（真闸：`Pk.common.reqLevel=45`、`arena_used_count`、
##   `arena_opponent is not None`）→ 回 `128` 换图 + `238:arena-player` + `2306:5/4` →
##   `_handle_arena_text:3768` → `竞技场窗._回帧`（static 状态 = 那扇窗的数据源）。
##
## ★ 与另外两条门的分工（别在这条上假称判过画面）：
##   · 窗开出来逐件画成什么样、点两下落到哪 ⇒ `开发工具/验竞技场开窗.gd` / `验竞技场对战.gd`
##     （有头量具，真 `push_input` + 视口像素）；
##   · 十二档包形 / 战报合并 / 动作词对照 / 尺寸表 ⇒ `测试/竞技场页回归测试.gd`（离线门 85 条）；
##   · 本条只管**协议真的往返**与**服务端那道闸真的拦**。
##
## 结算那一串**判得到**：夹具那台服务端的对手 max_hp 是从模板角色算的（血很薄），
## 我们连发普攻十几秒内就能让服务端自己判死 ⇒ 2306:7/6/1/3 + 239 + 5 秒后传送回原图
## 这一整串都在本条里真跑过。**判不到的一条也如实写**：`_finish_arena_battle` 结尾推给
## **在线对手**的那一发 2306:10 —— 夹具里的传承同伴从不登录，本机看不到对面那一侧。
##
## 跑法（夹具自己起服务端、自己隔离 user://，`--reset` ⇒ 满次数零冷却）：
##   python 开发工具/本地服务端夹具.py --root .fixture-arena --reset --port 18754 \
##     --gm-http 18755 --run "res://测试/竞技场在线回归测试.gd" --godot <Godot console.exe>
## 或经批量编排：PowerShell -File 开发工具\跑在线用例.ps1 -用例 竞技场

const 竞技场窗脚本 := preload("res://脚本/界面/窗口/竞技场窗.gd")

const 竞技场图 := "503000000"			# 服务端 `common.mapid`；`MapDefinition(503000000, 竞技场)`
const 对手号基 := 1_500_000_000			# `ARENA_MONSTER_OBJECT_ID_BASE :11130`
const 战斗秒 := 900					# `ARENA_BATTLE_SECONDS :11126`
const 免费次 := 15					# `Pk.common.freePkCount`
const 等级闸 := 45					# `Pk.common.reqLevel`（★ 不是 AS3 `PVP_ENTER_LEVEL=30`，见真值 §⑮）
const 走近距离 := 210				# `_tick_arena` 里"距离超过这个才走一步"
const 我方落点 := 450				# `:29447` 写死的 x（y 由地图地面决定，见 `_地面y`）
const 对手落点 := 1450				# `:29434` 写死的 x（同上）
const 竞技场地图路 := "res://数据/地图/竞技场/地图.json"

var _后
var _会话
var _判数 := 0
var _红 := 0
var _帧: Array = []				# [{动作, 值}]，按到达顺序
var _对手动: Dictionary = {}			# 对手最近一次 241 里的 x
var _对手血: Array = []				# 252 一条条百分比
var _我被打: Array = []			# 194 DAMAGE_PLAYER（对面还手，客户端吃进 player_damaged）
var 对手号 := 0
var 对手object := 0
var _原端口 := -1


## 跑完（含挂掉那条路）都要把 `backend_port` 还回原值 —— 夹具的 user:// 虽然是临时的，
## 但这台机两个工程同名**共用 user://**，留着一个 18754 会把明天的门顶歪。
func _还原端口() -> void:
	if _会话 == null or _原端口 < 0:
		return
	var 设置: Dictionary = _会话.get("game_settings")
	设置["backend_port"] = _原端口
	_会话.set("game_settings", 设置)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_后 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _后 == null or _会话 == null:
		_败("缺 BackendConnection/GameSession 单例（夹具没起对？）")
		return
	## 客户端连哪个口**只认** `game_settings.backend_port`（`后端连接.gd:870`），环境变量它不读。
	## ⇒ 夹具起的是临时口时这一键必须本门自己写、跑完还原（旧坑：拿默认 18684 去连 = 连到
	##   用户自己那台服务端、跑的是他的账号）。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	if 口 > 0:
		设置["backend_port"] = 口
	prints("竞技场在线腿：连夹具端口", str(口 if 口 > 0 else _原端口))
	_后.connect("竞技场帧", func(动作: int, 值: Dictionary) -> void: _帧.append({"动作": 动作, "值": 值}))
	_后.connect("monster_moved", func(状: Dictionary) -> void:
		if int(状.get("object_id", -1)) == 对手object:
			_对手动["起步"] = int(状.get("start_x", 0)))		# 241 的载荷是 start_x/vx/vy，**没有 x**
	_后.connect("monster_hp_changed", func(号: int, 百分比: int) -> void:
		if 号 == 对手object:
			_对手血.append(百分比))
	_后.connect("player_damaged", func(状: Dictionary) -> void: _我被打.append(状))
	## ★ 自己的血量**不看 1330**：`_handle_player_hp_text:3682` 按原版 `Client.as:5977-5985`
	##   把"角色号 == 自己"那一条**直接丢**（自己的血条走 34 状态帧）⇒ 拿 1330 当"对面还手"
	##   的证据，测到的永远是 0 条（10-24 第一跑就是这么红的，不是服务端没打）。
	##   所以这里认的是 194 DAMAGE_PLAYER ⇒ `player_damaged`。
	# 控制器是"运行期由 窗口管理._ready 挂上"的（`PvpManager` 那份常驻单例的等价物）；
	# 这里挂的是**同一个 `_回帧`**，所以下面判的键就是那扇窗显示时读的同一份。
	竞技场窗脚本.挂全局(_后)

	_后.sync_character()
	if not await _等(func(): return bool(_后.in_game), 15000):
		_败("主角色进不了真实后端：%s - %s" % [_后.status, _后.detail])
		return
	var 我的等级 := int((_后.authoritative_stats as Dictionary).get("level", 0))
	_判("前置：服务端真给了等级、且过得了 reqLevel=%d 那道闸（实测 %d）" % [等级闸, 我的等级], 我的等级 >= 等级闸)
	对手号 = int(OS.get_environment("NW_LEGACY_PEER_ID"))
	if 对手号 <= 0 or 对手号 == int(_后.character_id):
		_败("夹具没给可用候选（NW_LEGACY_PEER_ID=%d 我自己=%d）；服务端候选池只收**别的账号里 level≥45 的角色**" % [对手号, int(_后.character_id)])
		return

	# ── ① 面板：上行 0 ⇒ 下行 0 ──────────────────────────────────────────
	_判("request_arena_panel 发得出去", _后.request_arena_panel())
	if not await _等(func(): return _有(0), 8000):
		_败("服务端没回 2306:0（面板）")
		return
	var 面 := _取帧(0)
	_判("2306:0 计数五段真来自服务端：上限=%d（实测 %d）、已用 0、冷却 0（夹具每轮 --reset）" % [免费次, int(面.get("上限", -1))],
			int(面.get("上限", -1)) == 免费次 and int(面.get("已用", -1)) == 0 and int(面.get("冷却", -1)) == 0)
	_判("2306:0 的排名读到位（服务端默认 1000 ⇒ 必须 >0；实测 %d）" % int(面.get("排名", 0)),
			int(面.get("排名", 0)) > 0)
	var 候: Array = 面.get("候选", []) as Array
	var 条 := _候选(候)
	_判("候选池里真出现夹具那个高级同伴（服务端只从别的账号 level≥45 的角色里取，没有 NPC 池）", not 条.is_empty())
	if 条.is_empty():
		_败("候选=%s" % [候])
		return
	_判("那一行的等级/攻速/移速/名字都解出来了（12 段一个没错位；playerLevel 才是角色等级、pkLevel 是竞技场名次）",
			int(条.get("playerLevel", 0)) >= 等级闸 and int(条.get("wlkspeed", 0)) > 0
			and int(条.get("atkspeed", 0)) > 0 and String(条.get("name", "")) != ""
			and int(条.get("pkLevel", 0)) > 0)
	_判("控制器那份候选与服务端同一份、且含同一个号（`竞技场窗.候选` 就是那扇窗的数据源）",
			(竞技场窗脚本.候选 as Array).size() == 候.size() and not _候选(竞技场窗脚本.候选 as Array).is_empty())

	# ── ② 英雄榜：上行 4 ⇒ 下行 9 ────────────────────────────────────────
	_判("request_arena_heroes 发得出去", _后.request_arena_heroes())
	if not await _等(func(): return _有(9), 8000):
		_败("服务端没回 2306:9（英雄榜）")
		return
	_判("英雄榜回帧真喂进控制器（服务端 %d 行 == 控制器 %d 行，且 >0）" % [
			(_取帧(9).get("英雄", []) as Array).size(), (竞技场窗脚本.英雄榜 as Array).size()],
			(竞技场窗脚本.英雄榜 as Array).size() == (_取帧(9).get("英雄", []) as Array).size()
			and (竞技场窗脚本.英雄榜 as Array).size() > 0)

	# ── ③ 「无需挑战直接查看结果」：上行 1 + battle_type=1 ⇒ `:29383-29401` 只翻旧战报
	#    ★ 判"该多的没多"（10/5 两条计数 + 不换图 + 不加次数），不判"总帧数没变"——
	#      ①②那两发的 11/9 是异步到的，夹在中间会把"什么都没回"这条伪造成红。
	var 十前 := _计(10)
	var 五前 := _计(5)
	_判("request_arena_challenge(类型 1) 发得出去", _后.request_arena_challenge(对手号, 1))
	await create_timer(1.5).timeout
	_判("新号没有旧战报 ⇒ 类型 1 不回 2306:10、不回 2306:5、不换图、不加次数（`:29383-29401` 只从 arena_reports 里找）",
			_计(10) == 十前 and _计(5) == 五前 and String(_会话.current_map_id) != 竞技场图
			and int((竞技场窗脚本.计数 as Dictionary).get("已用", 0)) == 0)

	# ── ④ 真挑战：battle_type=0 ⇒ 换图 + 对手帧 + 2306:5 + 2306:4
	_判("request_arena_challenge(类型 0) 发得出去", _后.request_arena_challenge(对手号, 0))
	if not await _等(func(): return String(_会话.current_map_id) == 竞技场图, 10000):
		_败("服务端没把主角色传送进竞技场图（current_map_id=%s）⇒ 128 没吃到或那道闸没过" % String(_会话.current_map_id))
		return
	_判("真换进了竞技场图（客户端吃了服务端的 128 换图帧）", String(_会话.current_map_id) == 竞技场图)
	对手object = 对手号基 + 对手号 % 500_000_000		# `:29448-29452`
	if not await _等(func(): return (_后.map_monsters as Dictionary).has(对手object), 8000):
		_败("服务端发了 238:arena-player，但客户端没登记到 object_id=%d（现有怪=%s）" % [对手object, (_后.map_monsters as Dictionary).keys()])
		return
	var 状: Dictionary = (_后.map_monsters as Dictionary).get(对手object, {}) as Dictionary
	var 对: Dictionary = 状.get("对手", {}) as Dictionary
	_判("对手帧 26 段解对了：名字/等级与**面板那一行**一致（两条独立帧互证）且头像 >0",
			int(对.get("level", -1)) == int(条.get("playerLevel", -1))
			and String(对.get("name", "")) == String(条.get("name", "")) and int(对.get("face", 0)) > 0)
	## ★ 落点的参照值**自己从地图数据算**，不问服务端要（10-24 用户实机报的第一条就是
	##   服务端把两个人写死在 y=862 —— 竞技场那张图主地面在 540、VR 底只有 767 ⇒ 人卡到地图底下）。
	## 先给量具自己来两条阳性对照：`_地面y` 整个坏掉时只以"参照算不出"的形式红，看不出是量具坏。
	_判("_地面y 量具自检：x=100 ⇒ 418（实测 %d）" % _地面y(100), _地面y(100) == 418)
	_判("_地面y 量具自检：两个落点 x=450/1450 ⇒ 540/540（实测 %d/%d，都是平段 ⇒ 取 max(y1,y2) 不引入误差）" % [
			_地面y(我方落点), _地面y(对手落点)],
			_地面y(我方落点) == 540 and _地面y(对手落点) == 540)
	var 地面 := _地面y(对手落点)
	_判("对手落在**竞技场地图的真地面**上（x=%d 服务端给的 y=%d、地图数据算出来的地面 y=%d）" % [
			对手落点, int(状.get("y", -1)), 地面],
			int(状.get("x", -1)) == 对手落点 and 地面 > 0 and int(状.get("y", -1)) == 地面)
	if not await _等(func(): return _有(5), 8000):
		_败("服务端没回 2306:5（战斗剩余）")
		return
	_判("2306:5 的秒数 = 服务端常量 ARENA_BATTLE_SECONDS=%d（实测 %d）" % [战斗秒, int(_取帧(5).get("秒", -1))],
			int(_取帧(5).get("秒", -1)) == 战斗秒 and 竞技场窗脚本.战斗剩余 == 战斗秒)
	if not await _等(func(): return int((竞技场窗脚本.计数 as Dictionary).get("已用", 0)) == 1, 8000):
		_败("开打之后 2306:4 没把「已用」推到 1（计数=%s）" % [竞技场窗脚本.计数])
		return
	_判("挑战真扣了一次次数（服务端 `arena_used_count += 1` 落了档、2306:4 回帧吃到控制器）",
			int((竞技场窗脚本.计数 as Dictionary).get("已用", 0)) == 1)

	# ── ⑤ 闸：还在对战中不许再开一场（`:29412 arena_opponent is not None`）
	var 图前 := String(_会话.current_map_id)
	var 次前 := int((竞技场窗脚本.计数 as Dictionary).get("已用", 0))
	var 零前 := _计(0)
	_后.request_arena_challenge(对手号, 0)
	await create_timer(1.5).timeout
	_判("对战中再点挑战 ⇒ 服务端只回面板（2306:0 多一条），不加次数、不再开一场（`:29412` 那道闸）",
			String(_会话.current_map_id) == 图前
			and int((竞技场窗脚本.计数 as Dictionary).get("已用", 0)) == 次前
			and _计(0) > 零前 and _计(5) == 1 and _计(4) == 1)

	# ── ⑥ 对手自己走过来（服务端 `_tick_arena` 每 0.25 秒发一条 241）+ 对面真还手（194 + 1330）
	var 走到 := await _等(func(): return abs(int(_对手动.get("起步", 999999)) - 我方落点) <= 走近距离, 30000)
	_判("对手真在往我们这边走（241 被吃进 monster_moved；起步 x=%s，我落在 %d）" % [str(_对手动.get("起步", "一条没到")), 我方落点],
			走到 and int(_对手动.get("起步", 999999)) < 对手落点)
	var 还手 := await _等(func(): return not _我被打.is_empty(), 25000)
	var 最后伤害 := 0
	if not _我被打.is_empty():
		最后伤害 = int((_我被打.back() as Dictionary).get("damage", 0))
	_判("对面真还手（服务端 `_tick_arena` 的反击帧 194 被客户端吃进 player_damaged：%d 下，最后一下伤害=%d）" % [
			_我被打.size(), 最后伤害], 还手 and 最后伤害 > 0)

	# ── ⑦ 打到手数直到服务端判死（40 普攻 ⇒ 服务端自算伤害 ⇒ 243 + 252 + 239 ⇒ `_finish_arena_battle`）
	var 出手 := 0
	while 出手 < 60 and not _有(7):
		_后.request_basic_attack(对手object, Vector2(float(_对手动.get("起步", 对手落点)), float(_地面y(对手落点))), 1)
		出手 += 1
		await create_timer(0.25).timeout
	_判("普攻打得上：服务端回 243/252、对手血量百分比真掉了（%d 条 252，最低 %s%%，出手 %d 发）" % [
			_对手血.size(), str(_最低(_对手血)), 出手], not _对手血.is_empty() and _最低(_对手血) < 100)
	if not await _等(func(): return _有(7), 10000):
		_败("打了 %d 发、服务端没判死对手 ⇒ 结算那一串拿不到（252 最低 %s%%，对面还在不在=%s）" % [
				出手, str(_最低(_对手血)), str((_后.map_monsters as Dictionary).has(对手object))])
		return
	_判("对手被服务端判死并从怪那本账里摘掉（239 KILL_MONSTER ⇒ monster_removed）",
			not (_后.map_monsters as Dictionary).has(对手object))
	var 结 := _取帧(7)
	_判("结算 2306:7：这场是**胜**且阅历 > 0（服务端 prizeWin={jingbi:50,yueli:50}）",
			bool(结.get("胜", false)) and int(结.get("阅历", 0)) > 0)
	_判("结算 2306:6：返场倒计时 %d 秒（ARENA_RETURN_DELAY_SECONDS）" % int(_取帧(6).get("秒", -1)),
			int(_取帧(6).get("秒", -1)) == 5)
	_判("结算 2306:1：新排名回到控制器（排名=%d）" % 竞技场窗脚本.排名, _计(1) >= 1 and 竞技场窗脚本.排名 > 0)
	_判("结算 2306:3：战报进控制器（战报 %d 条）" % (竞技场窗脚本.战报 as Array).size(),
			_计(3) >= 1 and (竞技场窗脚本.战报 as Array).size() > 0)
	_判("结算之后进了 600 秒冷却（2306:4 里 冷却=%d；ARENA_COOLDOWN_SECONDS）" % int((竞技场窗脚本.计数 as Dictionary).get("冷却", -1)),
			int((竞技场窗脚本.计数 as Dictionary).get("冷却", 0)) > 0)
	var 回城 := await _等(func(): return String(_会话.current_map_id) != 竞技场图, 14000)
	_判("打完 5 秒后服务端把我们传送回原图（实测现在在 %s）" % String(_会话.current_map_id), 回城)

	# ── ⑧ 清冷却（上行 2）：⑦ 打完之后冷却 > 0 ⇒ 服务端按 `ceil(冷却秒/60)*1` 扣点券、冷却归零。
	#    ★ 判"冷却真变 0"就够证付了钱：`:29345` 那一支在**余额不够时直接 return、一个字都不回** ⇒
	#      "有 2306:4 回来 + 冷却=0" 这条链本身就已经包含"扣款成功"。
	var 冷前 := int((竞技场窗脚本.计数 as Dictionary).get("冷却", 0))
	var 四前 := _计(4)
	_判("request_arena_clear_cooldown 发得出去", _后.request_arena_clear_cooldown())
	if not await _等(func(): return _计(4) > 四前, 8000):
		_败("清 CD 发出去了但服务端没回 2306:4（四前=%d 现=%d，冷却=%d；点券不够时服务端就是什么都不回）" % [四前, _计(4), 冷前])
		return
	_判("清 CD 真生效：冷却 %d → %d、已用次数还是 1（服务端扣的点券 = ceil(%d/60)）" % [
			冷前, int((竞技场窗脚本.计数 as Dictionary).get("冷却", -1)), 冷前],
			冷前 > 0 and int((竞技场窗脚本.计数 as Dictionary).get("冷却", -1)) == 0
			and int((竞技场窗脚本.计数 as Dictionary).get("已用", 0)) == 1)

	# ── ⑨ 排名奖（上行 5）：rank 不在奖表 ⇒ 回 2306:11:<rank>:<2|0>
	#    ★ 判"多一条 11/8"而不是"有 11"：⑤ 那一发被拒时服务端也回面板（含 11），
	#      拿"有没有 11"当证据会把那一条算成这条的功劳（同一族假绿见过多次）。
	var 十一前 := _计(11)
	var 八前 := _计(8)
	_判("request_arena_rank_prize 发得出去", _后.request_arena_rank_prize())
	if not await _等(func(): return _计(11) > 十一前 or _计(8) > 八前, 8000):
		_败("领奖这一条发出去了，服务端 2306:11 / 2306:8 都没多一条（11 %d→%d，8 %d→%d）" % [
			十一前, _计(11), 八前, _计(8)])
		return
	_判("排名奖这一问真有新回帧（11 %d→%d、8 %d→%d；控制器记下 奖等级=%d 奖状态=%d）" % [
			十一前, _计(11), 八前, _计(8), 竞技场窗脚本.奖等级, 竞技场窗脚本.奖状态],
			_计(11) > 十一前 or _计(8) > 八前)

	print("竞技场在线腿：判 %d 条，红 %d 条。收到的 2306 档位（次数）：%s" % [_判数, _红, _档位表()])
	print("★ 仍未收口（如实）：对面那一侧收到的 2306:10 推帧（`_finish_arena_battle` 只推给**在线的**对手），")
	print("  夹具里的传承同伴从不登录 ⇒ 本条判不到；要补这一腿得让两个号同时在线（见台账「双人同图」那种夹具）。")
	_后.disconnect_backend()
	_还原端口()
	quit(0 if _红 == 0 else 1)


func _判(名: String, 过: bool) -> void:
	_判数 += 1
	if not 过:
		_red()
	print("  %-4s  %s" % ["通过" if 过 else "红", 名])


func _red() -> void:
	_红 += 1


func _候选(候: Array) -> Dictionary:
	for 项 in 候:
		if int((项 as Dictionary).get("charId", 0)) == 对手号:
			return 项 as Dictionary
	return {}


func _有(动作: int) -> bool:
	return _计(动作) > 0


## 把收到的档位打成 `0×3 1×1 …` 这种一行证据（交包/复核时要看的就是这个）。
func _档位表() -> String:
	var 计数: Dictionary = {}
	for 项 in _帧:
		var 名 := str(int(项["动作"]))
		计数[名] = int(计数.get(名, 0)) + 1
	var 键: Array = 计数.keys()
	键.sort()
	var 出: Array[String] = []
	for 名 in 键:
		出.append("%s×%d" % [名, 计数[名]])
	return " ".join(出)


func _计(动作: int) -> int:
	var n := 0
	for 项 in _帧:
		if int(项["动作"]) == 动作:
			n += 1
	return n


func _取帧(动作: int) -> Dictionary:
	for i in range(_帧.size() - 1, -1, -1):
		if int(_帧[i]["动作"]) == 动作:
			return _帧[i]["值"] as Dictionary
	return {}


func _最低(列: Array) -> int:
	var 小 := 999
	for 项 in 列:
		小 = mini(小, int(项))
	return 小


func _等(条件: Callable, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while not 条件.call() and Time.get_ticks_msec() < 截止:
		await create_timer(0.05).timeout
	return bool(条件.call())


func _败(说明: String) -> void:
	push_error("竞技场在线回归测试：失败 - %s" % 说明)
	print("竞技场在线腿：**跑挂了** —— %s（判到这一步之前 判 %d 条 / 红 %d 条）" % [说明, _判数, _红])
	if _后 != null:
		_后.disconnect_backend()
	_还原端口()
	quit(1)


## 落点的**参照值自己算**：从地图数据里取盖住 x 的那些 foothold 段中 y 最大的一块（= 最低的可站地面）。
## 不许拿服务端发回来的那个 y 当期望值（那就是"问被测对象要答案"，10-24 它给的正是错的 862）。
## 段形如 `{"x1":389,"x2":1589,"y1":540,"y2":540}`（平地两值相等、斜坡不等）。
## 竞技场地图的落脚点是**三层**嵌套（层 → 组 → 段，实测 `foothold["0"]["0"]["3"]`）。
## 以前按两层走 ⇒ 把"段号那一本账"当成了一段 ⇒ `x1` 查不到 ⇒ 参照值恒 −1 ⇒ 这条判据恒红
## （10-24，量具坏、地图数据本身是对的）。改成形状无关：凡是同时带 `x1`/`y1` 的字典就是一段。
func _地面y(x: int) -> int:
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(竞技场地图路).trim_prefix("﻿"))
	if not (解 is Dictionary):
		push_error("读不到竞技场地图数据 ⇒ 落点那条没法判")
		return -1
	var 收: Array = []
	_收地段(解, 收)
	var 出 := -1
	for 项 in 收:
		var d: Dictionary = 项 as Dictionary
		var 左 := mini(int(d.get("x1", 0)), int(d.get("x2", 0)))
		var 右 := maxi(int(d.get("x1", 0)), int(d.get("x2", 0)))
		if x < 左 or x > 右:
			continue
		## 同一条 x 上取**最低**那一段（y 越大越低）⇒ 与 `MapDefinition.ground_position` 同口径。
		出 = maxi(出, maxi(int(d.get("y1", 0)), int(d.get("y2", 0))))
	return 出


func _收地段(节: Variant, 出: Array) -> void:
	if 节 is Dictionary:
		var d: Dictionary = 节 as Dictionary
		if d.has("x1") and d.has("x2") and d.has("y1") and d.has("y2"):
			出.append(d)
			return
		for 值 in d.values():
			_收地段(值, 出)
	elif 节 is Array:
		for 值 in (节 as Array):
			_收地段(值, 出)
