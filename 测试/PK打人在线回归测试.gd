extends SceneTree
## 「打其他玩家」这条链的**在线端到端**门（#352/#354/#355/#356，2026-10-25 夜）。
##
## 判的是四件事，缺一件都不算接通（用户 10-12 硬令：只画壳 = 没做）：
## ① 客户端**选得到人**（`地图实体.可打的玩家` 在全体+非安全图里真的含对面那具）；
## ② **发得出去**（`request_pvp_basic_attack` 那两发 40/1328 真出网）；
## ③ **服务端真结算**（回 1329 伤害帧 + 1330 血条帧 ⇒ 那具身上的 HpBar 掉下来）；
## ④ **该拦的时候两边都拦得住**，而且**说的是原版那一句**：
##    木叶村（`peaceMaps` 第一张）⇒ 客户端不选它、硬发也只收到服务端「本地图禁止PK」且不掉血；
##    和平模式 ⇒ 客户端不选它、话是「您当前的PK模式为和平模式…」。
##
## ⚠ 两条负例都要"两边都问"：判定与文案是两个函数（见 真值/系统/PK判定.md §3）。
##   只有服务端拒、客户端照发 = 用户看到一串打不出去的攻击；只有客户端拦、服务端不拦 =
##   别人打他照样掉血。这两种坏法在离线门上长得一模一样，只有两个号真连着才分得开。
##
## ⚠ 两个号**必须真的在同一张图**：10-25 第一跑就是栽在这里 —— 出生图不固定（村 100000000
##   或 终结谷浅滩 101010000），主号换到村判安全图、对面却留在浅滩 ⇒ 我这侧根本看不见那具，
##   `可打的玩家` 是空的、判定也走到"看不见"分支，**负例全绿却什么都没判**（0 比 0）。
##   现在每条负例前面都钉一条"这一刻看得见那具"，并且 `_带到` 会把两个号都搬到同一张图。
##   服务端没有"队友跟图"机制（现查 `fake_flash_server.py`：只有 `_handle_change_map:14863`
##   这一条入口），所以对面那个号必须自己再发一次 33。
##
## 图为什么这么挑：`数据/PVP配置.json` 的 peaceMaps = [100000000, 101010000, 101020000,
## 101030000, 101040000] ⇒ **木叶村本身就是安全图**（原版规则，不是缺陷）。正例那一半必须换到
## **102010000 木叶森林**（不在 peaceMaps、`reqLevel=10`、从村东门 3 一跳直达）。换图走
## `request_map_change` ⇒ 内部 `_find_portal_to_map` ⇒ 发 `33:2:-1:<门号>`，与玩家自己走到门口
## 点门是**同一条服务端路径**（`handle_enter_portal`），不是给客户端塞假状态。
##
## 等级：夹具主号被 `seed_level` 抬到 100，对端默认 1 级 ⇒ 会被服务端的等级闸(45)与等级差闸(15)
## 双重拒，症状和"链没接通"一模一样 ⇒ **这条用例必须带 `--peer-level 100`**（已写进 跑在线用例.ps1）。
##
## 跑法：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具\跑在线用例.ps1 -用例 PK打人 -Godot godot`
## （夹具另起一对端口 18758/18759：18684 是用户自己那台客户端在连的号，绝不顶）

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 地图实体脚本 := preload("res://脚本/地图/地图实体.gd")
const 判定 := preload("res://脚本/角色/PVP判定.gd")
const 存档路 := "user://玩家数据.json"
const 服务端文件 := "res://服务端/runtime/tools/fake_flash_server.py"
const PEER_ACCOUNT := "naruto"
const PEER_PASSWORD := "123456"
const 村图 := 100000000
const 野外图 := 102010000
## 服务端结算的距离闸：`PLAYER_ATTACK_DISTANCE=550 + SYNC_TOLERANCE=160`（`fake_flash_server:11196-11197`）
## ⇒ 两号必须挨着，否则打出去也结算不了（那种红会被误读成"链断了"）。
const 出手距离上限 := 700

## 本腿该判满的条数（**不含**末尾那条计数自查 —— 实参先于函数体求值，包自己会恒差一条）。
## ⚠ 加/删一条判据就要同步改这里，否则"半路死了"照样打「红 0 条」。
## `_带到` 每调用一次**固定 2 条**（请求发出去了 / 真到了），不管走直达还是中转 ⇒ 条数与出生图无关。
const 本腿条数 := 44

var _主: Node = null
var _对: Node = null
var _会话: Node = null
var _人生: Node = null
var _对编号 := 0
var _原端口 := -1
var _失败: Array = []
var 数 := 0
var 跑完了 := false
## 1329 一条条存；1330 每条形如 [号, 上限, 当前]（血条是"覆盖"语义，留全序列只为一眼看出没掉）。
var _伤帧: Array = []
var _血帧: Array = []
## 我这侧"说过的话"（`GameSession.notification_requested` + 后端聊天帧）。
var _收: Array = []
var 存档前 := PackedByteArray()
var 本来有存档 := false


func _initialize() -> void:
	var 起 := Time.get_ticks_msec()
	call_deferred("_跑")
	while not 跑完了 and Time.get_ticks_msec() - 起 < 300_000:
		await process_frame
	if not 跑完了:
		printerr("PK打人在线：门自己没跑完（协程中途报错，看上面最后一条 SCRIPT ERROR）")
		还原端口()
		quit(1)


func _记(过: bool, 文: String) -> void:
	数 += 1
	if 过:
		print("  √ " + 文)
	else:
		_失败.append(文)
		printerr("  !! " + 文)


func _等秒(秒: float, 条件: Callable) -> bool:
	var 止 := Time.get_ticks_msec() + int(秒 * 1000.0)
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.1).timeout
	return bool(条件.call())


func _图(会: Node) -> int:
	return int(会.get("authoritative_map_id"))


## 把某个号带到目标图，**固定记 2 条**。直达门找不到 / 18 秒没落地 ⇒ 走中转（先回村，村东门直达森林）。
func _带到(会: Node, 目标图: int, 说明: String, 落点 := Vector2.ZERO) -> bool:
	var 出发图 := _图(会)
	var 发出过 := 出发图 == 目标图 or bool(会.request_map_change(目标图, int(落点.x), int(落点.y)))
	var 到了 := 出发图 == 目标图
	if not 到了 and 发出过:
		到了 = await _等秒(18.0, func() -> bool: return _图(会) == 目标图)
	if not 到了:
		会.request_map_change(村图, 0, 0)
		var 回村 := await _等秒(18.0, func() -> bool: return _图(会) == 村图)
		发出过 = 发出过 or 回村
		if 回村 and 目标图 != 村图:
			发出过 = true
			会.request_map_change(目标图, int(落点.x), int(落点.y))
			到了 = await _等秒(18.0, func() -> bool: return _图(会) == 目标图)
	_记(发出过, "%s：换图请求发得出去（从 %d 出发去 %d）" % [说明, 出发图, 目标图])
	_记(到了, "%s：真落到了 %d（实得 %d）" % [说明, 目标图, _图(会)])
	return 到了 and 发出过


## 对面那具演员（走地图实体自己的 `_按角色号找演员`，不是我另拼一份表）。
func _演员() -> Node:
	if _人生 == null:
		return null
	return _人生.call("_按角色号找演员", _对编号) as Node


## `可打的玩家` 里有没有**那一具**（内容判据：比的是同一个节点 —— 名单里有"东西"不等于有他）。
func _名单含对面() -> bool:
	var 他: Node = _演员()
	if 他 == null:
		return false
	for 候 in (_人生.call("可打的玩家") as Array):
		if 候 == 他:
			return true
	return false


func _对号等级() -> int:
	var 他: Node = _演员()
	if 他 == null:
		return -1
	return int(他.get_meta("pk_level", -1))


func _我号等级() -> int:
	var 属 = null if _会话 == null else _会话.get("player_stats")
	if not (属 is Dictionary):
		return -1
	return int((属 as Dictionary).get("level", -1))


## 我这侧活着没有（原版 `API.player.isDie`）。⚠ `player_stats` 里**没有** "hp" 这一键
## ⇒ 拿 `hp` 当存在判、缺失默认 1，会把"根本没这个字段"误读成"血量 1 ⇒ 快死了/活着"。
## 10-25 在线第一跑就是把 0 比 0 的假绿当真绿跑了过去（打印出来是 `‹没这键›` 才发现）。
func _我还活着() -> bool:
	var 属 = null if _会话 == null else _会话.get("player_stats")
	if not (属 is Dictionary):
		return false
	## ⚠ 必须写成 `: Variant`：`var 值 = 字典.get("hp", "‹没没键›")` 在 4.7 里会被**推断成 int**
	## （因为表里这一键实际是 int），于是下一行 `值 == "‹没这键›"` 当场报
	## `Invalid operands 'int' and 'String' in operator '=='` ⇒ 函数中途死、调用方拿到 null ⇒
	## 判据红，而画面上一切正常（10-25 在线第四跑就是这么红了一条"我这侧还活着"）。
	var 值: Variant = (属 as Dictionary).get("hp", null)
	if 值 == null:
		## ⚠ 打印里要带**实际键名**：`{}` 到底是不是空、有没有 hp 这一键，看这一行就知道。
		## 10-25 栽过一次：`.get("hp", 1) <= 0` 把"这侧状态字典压根没有 hp"读成"没死"，
		## 于是"我方已死 ⇒ 说死亡那句"整条在在线门里永远不成立（0 比 0 假绿）。
		push_warning("我这侧的 player_stats 里没有 hp 键 ⇒ 无法判活着")
		return false
	return int(值) > 0


func _我这侧状态() -> Dictionary:
	var 属 = null if _会话 == null else _会话.get("player_stats")
	return 属 if 属 is Dictionary else {}


## 拼一份给 `判定` 的输入：**用地图实体自己那两个生产函数**（`_PVP我方`/`_PVP目标`），
## 不许手写"我认为它会吐出来的字典"（那样测的是我自己）。图号现取权威值。
## ⚠ 看不见那具时返回的是 `可打=true + 话=‹看不见那具›` ⇒ 负例当场红，
##   不会退化成"打不了"恒真那种 0 比 0（10-25 第一跑就是这个形状骗过去的）。
func _判(模式: int) -> Dictionary:
	var 他: Node = _演员()
	if 他 == null:
		return {"可打": true, "话": "‹看不见那具›"}
	var 我: Dictionary = _人生.call("_PVP我方", _对编号) as Dictionary
	我["图号"] = _图(_主)
	var 标: Dictionary = _人生.call("_PVP目标", 他) as Dictionary
	return 判定.判定(模式, 我, 标)


func _收过那句(句: String) -> bool:
	for 项 in _收:
		if String(项).contains(句):
			return true
	return false


func _间距() -> float:
	var 他: Node = _演员()
	if 他 == null:
		return 99999.0
	return (他.position as Vector2).distance_to((_主.get("authoritative_position") as Vector2))


func 拍快照() -> void:
	本来有存档 = FileAccess.file_exists(存档路)
	if 本来有存档:
		存档前 = FileAccess.get_file_as_bytes(存档路)


func 还原存档() -> void:
	if 本来有存档:
		var 止 := FileAccess.get_file_as_bytes(存档路) if FileAccess.file_exists(存档路) else PackedByteArray()
		if 止 != 存档前:
			var 会 = root.get_node_or_null("GameSession")
			if 会 != null:
				(会.get("game_settings") as Dictionary)["backend_port"] = _原端口
			var tmp := 存档路 + ".还原中"
			var f := FileAccess.open(tmp, FileAccess.WRITE)
			f.store_buffer(存档前)
			f.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
			DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(存档路))
		print("  √ 跑完把 user://玩家数据.json 按字节还原了（跑前 %d 字节）" % 存档前.size())
	elif FileAccess.file_exists(存档路):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
		print("  √ 跑前本来没有存档，跑完把写出来的那份删了")


func 还原端口() -> void:
	if _原端口 >= 0:
		var 会 = root.get_node_or_null("GameSession")
		if 会 != null:
			(会.get("game_settings") as Dictionary)["backend_port"] = _原端口


## `原因 != ""` ⇒ 这不是正常跑完，是**中途卡住提前收口**：后面那些判据一条都没跑，
## 必须记成红（否则"半条门"照样打「红 0 条」）。
func 收拾并退出(原因 := "") -> void:
	if 原因 != "":
		_失败.append("门提前收口（后面那些判据一条都没跑）：" + 原因)
		printerr("  !! 门提前收口（后面那些判据一条都没跑）：" + 原因)
	跑完了 = true
	还原端口()
	还原存档()
	print("PK打人在线门：本腿判 %d 条（应满 %d）/ 红 %d 条" % [数, 本腿条数, _失败.size()])
	quit(1 if _失败.size() > 0 else 0)


func _跑() -> void:
	拍快照()
	_主 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _主 == null or _会话 == null:
		printerr("PK打人在线：缺 BackendConnection / GameSession 单例（自动加载没跑起来）")
		quit(1)
		return
	## 服务端那三支还在不在（撤了 ⇒ 这一整条石沉大海，而客户端侧全是绿的）。
	var 源 := FileAccess.get_file_as_string(服务端文件)
	_记(源.contains("def handle_player_attack_announce"),
			"服务端 1328 那一支还在（撤了 ⇒ 打人永远石沉大海）")
	_记(源.contains("PendingPvpHit"), "服务端结算前那张认领表还在（PendingPvpHit）")
	_记(源.contains("def _ordinary_pvp_denial_reason"),
			"服务端普通图那几道闸还在（`_ordinary_pvp_denial_reason`）")

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18758
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_对编号 = int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	print("连夹具端口 %d；对面那个号 = %d（账号 %s）" % [口, _对编号, PEER_ACCOUNT])
	if _对编号 <= 0:
		printerr("PK打人在线：夹具没给 NW_SOCIAL_PEER_ID ⇒ 没有第二个号，这条腿无从判起")
		还原端口()
		quit(1)
		return

	_主.sync_character()
	_记(await _等秒(20.0, func() -> bool: return bool(_主.in_game)),
			"主号进得了游戏（%s - %s）" % [str(_主.status), str(_主.detail)])
	if not bool(_主.in_game):
		收拾并退出("卡在「主号进不了游戏」⇒ 本腿后面一条没跑")
		return

	_对 = BACKEND_SCRIPT.new()
	_对.name = "PK打人在线对面那个号"
	root.add_child(_对)
	## 1329/1330 两侧都接：它们是 `_send_visible`（打人者与旁观者都收得到）。
	## 只在对端身上判会漏掉"打人这一侧屏幕上一片安静"这种坏法。
	_对.connect("player_damage_by_player_received", func(信: Dictionary) -> void: _伤帧.append(信))
	_对.connect("player_hp_received",
			func(号: int, 最大: int, hp: int) -> void: _血帧.append([号, 最大, hp]))
	_主.connect("player_damage_by_player_received", func(信: Dictionary) -> void: _伤帧.append(信))
	_主.connect("player_hp_received",
			func(号: int, 最大: int, hp: int) -> void: _血帧.append([号, 最大, hp]))
	_会话.connect("notification_requested", func(话: String) -> void: _收.append(话))
	_主.connect("chat_received",
			func(件: Dictionary) -> void: _收.append("聊天:" + str(件.get("message", 件))))
	_对.connect_backend(PEER_ACCOUNT, PEER_PASSWORD, false)
	_记(await _等秒(12.0, func() -> bool: return bool(_对.authenticated)),
			"第二个号登录得上（夹具里有 %s 这个账号吗）" % PEER_ACCOUNT)
	if not bool(_对.authenticated):
		收拾并退出("卡在「第二个号登录不上」")
		return
	if not bool(_对.select_character(_对编号)):
		收拾并退出("卡在「第二个号选不上角色 %d」" % _对编号)
		return
	_记(await _等秒(20.0, func() -> bool:
			return bool(_对.in_game) and int(_对.character_id) == _对编号),
			"第二个号也进了游戏（%s - %s）" % [str(_对.status), str(_对.detail)])
	if not bool(_对.in_game):
		收拾并退出("卡在「第二个号进不了游戏」")
		return

	_人生 = (地图实体脚本.new()) as Node
	root.add_child(_人生)
	for 帧 in 8:
		await process_frame
	_记(bool(_人生.get("_server_authoritative")), "地图实体进了服务端权威模式")
	_记(_我号等级() >= 45 and _我这侧状态().has("hp"),
			"我这侧等级 ≥45 且状态帧里有 hp 这一键（实得 等级=%d hp=%s）"
			% [_我号等级(), str(_我这侧状态().get("hp", "‹没这键›"))])

	# ── 先把两个号弄到**同一张图**（村里），否则下面全是空判
	var 主到村 := await _带到(_主, 村图, "主号")
	var 对到村 := await _带到(_对, 村图, "对面号")
	if not (主到村 and 对到村):
		收拾并退出("卡在「两个号没同到木叶村」⇒ 安全图那半条没跑")
		return
	_记(await _等秒(12.0, func() -> bool: return _演员() != null),
			"在村里我这侧看得见对面那具（看不见下面的负例就全是空判）")
	_记(await _等秒(8.0, func() -> bool: return _对号等级() >= 45),
			"对面那具身上的等级 ≥45（实得 %d；夹具要带 --peer-level 100）" % _对号等级())

	# ── 负例①：木叶村是安全图
	_记(_主.request_pk_mode(判定.全体), "在村里把模式切成全体（1792 上行发得出去）")
	_记(await _等秒(10.0, func() -> bool:
			return int(_主.authoritative_pk_mode) == 判定.全体),
			"服务端回帧、我这侧权威模式真变 4（实得 %d）" % int(_主.authoritative_pk_mode))
	_记(判定.是安全图(村图), "配置里 100000000 确实算安全图（否则这条负例是空判）")
	_记(not _名单含对面(), "全体 + 在木叶村 ⇒ 名单里就是没有他（客户端这道闸在）")
	_记(not bool(_判(判定.全体).get("可打", true)),
			"同样这组输入，判定说「打不了」（实得 %s）" % str(_判(判定.全体)))
	_记(String(_判(判定.全体).get("话", "")) == String(判定.话["安全图"]),
			"说的是那一句「本地图禁止PK」（实得「%s」）" % str(_判(判定.全体).get("话", "")))
	## 绕过客户端闸硬发一发 1328 ⇒ 服务端那一侧也必须拒，并且回的就是那一句。
	_收.clear(); _伤帧.clear()
	_记(_主.announce_pvp_skill_cast(1000, 1, [_对编号],
			_主.get("authoritative_position") as Vector2, 1),
			"硬发那一发 1328 出得去网（不然下面的拒绝无从验起）")
	_记(await _等秒(10.0, func() -> bool: return _收过那句(String(判定.话["安全图"]))),
			"服务端也拒了，回的就是「本地图禁止PK」（实得 %s）" % str(_收))
	_记(_伤帧.is_empty(),
			"在村里这条链一条伤害帧都没回来（真掉血 = 没拦住；实得 %d 条）" % _伤帧.size())

	# ── 负例②：和平模式。**必须在村里判**（10-25 第二跑的教训）：森林里有 40 只怪，
	#    我这侧站着不动会被打死，而 `getNoAttackWarning` 的「我方已死」那句排在 switch **之前**
	#    （`PVPHandler.as:402` vs `:412`）⇒ 死了之后说的就不是和平那句了，红会指向错误的方向。
	#    村里零怪（`数据/地图/木叶村/地图.json` 的 life 全是 n），这一档才干净。
	_记(_主.request_pk_mode(判定.和平), "在村里切回和平（1792 上行发得出去）")
	_记(await _等秒(10.0, func() -> bool:
			return int(_主.authoritative_pk_mode) == 判定.和平),
			"权威模式回 1（实得 %d）" % int(_主.authoritative_pk_mode))
	## ⚠ 这两件事**分开判、分开打印**（合在一条 `and` 里，红了我不知道是哪一侧塌的 ——
	## 10-25 第三跑就是这条合起来判据红了、而 hp 明明打印出 3225）。
	_记(_演员() != null,
			"这一刻仍然看得见那具（对面号=%d ｜ 我这侧角色号=%d）" % [_对编号, int(_主.character_id)])
	_记(_我还活着(),
			"我这侧还活着（实得 hp=%s / max_hp=%s ｜ 生产端算出来的死亡=%s）" % [
				str(_我这侧状态().get("hp", "‹没这键›")),
				str(_我这侧状态().get("max_hp", "‹没这键›")),
				str(bool(_人生.call("_PVP我方", _对编号).get("死亡", false)))])
	_记(not _名单含对面(), "和平模式 ⇒ 名单里又没有他了（同一个人、同一张图，只有模式变了）")
	_记(not bool(_判(判定.和平).get("可打", true)),
			"和平模式下判定说「打不了」（实得 %s）" % str(_判(判定.和平)))
	## ⚠ 期望是**和平那句**而不是「本地图禁止PK」：原版 switch（`:412`）在图闸（`:432`）之前
	##    ⇒ 这条在线判的就是那道顺序（离线表里同一条是 C 组变异逮的）。
	_记(String(_判(判定.和平).get("话", "")) == String(判定.话["和平模式"]),
			"说的是那一句「PK模式为和平模式…」（switch 先于图闸；实得「%s」）" % str(_判(判定.和平).get("话", "")))
	## 正例那一半要 4 档 ⇒ 现场切回去（也顺带证明 1↔4 来回切都真的落帧）。
	_记(_主.request_pk_mode(判定.全体), "再去森林之前把模式切回全体（1792 上行发得出去）")
	_记(await _等秒(10.0, func() -> bool:
			return int(_主.authoritative_pk_mode) == 判定.全体),
			"权威模式回 4（实得 %d）" % int(_主.authoritative_pk_mode))

	# ── 正例：两个号都换到木叶森林（非安全图），挨着站，真打真掉血
	## 对面那发要**落点现取**（主号落地之后的坐标，不是换图之前那份 —— 拿旧的会把靶子丢在半路）。
	var 主到林 := await _带到(_主, 野外图, "主号")
	if not 主到林:
		收拾并退出("卡在「主号没到森林」⇒ 正例那半条没跑")
		return
	var 落点: Vector2 = _主.get("authoritative_position") as Vector2
	var 对到林 := await _带到(_对, 野外图, "对面号（跟着主号此刻的坐标落）", 落点)
	if not 对到林:
		收拾并退出("卡在「对面号没到森林」⇒ 结算那半条没跑")
		return
	_记(await _等秒(12.0, func() -> bool: return _演员() != null),
			"到森林里仍然看得见对面那具（同图同线才看得见）")
	_记(await _等秒(15.0, func() -> bool: return _间距() <= 出手距离上限),
			"两具演员挨得够近（服务端距离闸 550+160；实得 %.1f）" % _间距())
	_记(await _等秒(10.0, func() -> bool: return _名单含对面()),
			"森林 + 全体 ⇒ 名单里真有他那具（内容判据：比的是同一个节点）")
	_记(bool(_判(判定.全体).get("可打", false)),
			"同样这组输入，判定给「可打」（实得 %s）" % str(_判(判定.全体)))

	_伤帧.clear(); _血帧.clear()
	_记(_主.request_pvp_basic_attack(_对编号, 落点, 1),
			"打他 ⇒ 40 + 1328 两发都出得去网")
	_记(await _等秒(15.0, func() -> bool:
			for 信 in _伤帧:
				if int((信 as Dictionary).get("victim_id", 0)) == _对编号 \
						and int((信 as Dictionary).get("damage", 0)) > 0:
					return true
			return false),
			"服务端真结算了：回了一条 1329，被打的是他、伤害 > 0（共 %d 条：%s）" % [_伤帧.size(), str(_伤帧)])
	_记(await _等秒(10.0, func() -> bool:
			for 帧 in _血帧:
				if int((帧 as Array)[0]) == _对编号 and int((帧 as Array)[2]) < int((帧 as Array)[1]):
					return true
			return false),
			"还回了 1330：他那条血条 hp < 上限（实得 %s）" % str(_血帧))
	_记(await _等秒(10.0, func() -> bool:
			var 他: Node = _演员()
			if 他 == null:
				return false
			var 条: Node = 他.get_node_or_null("HpBar")
			return 条 != null and bool(条.visible) and float(条.get("_比例")) < 0.999),
			"画面落点：那具头顶的血条显形且没满（1330 真被解出来挂上去了）")
	## 计数自查**不走 `_记`**（走的话 `数` 会把自己也算进去 ⇒ 末行打成"判 45 条（应满 44）"，
	## 读日志的人以为漏了一条）。这里只红不计数。
	if 数 != 本腿条数:
		_失败.append("本腿只判了 %d 条（应满 %d）⇒ 半路死了，后面的判据一条没跑" % [数, 本腿条数])
		printerr("  !! 本腿只判了 %d 条（应满 %d）⇒ 半路死了，后面的判据一条没跑" % [数, 本腿条数])
	else:
		print("  √ 本腿判满 %d 条" % 数)
	收拾并退出()
