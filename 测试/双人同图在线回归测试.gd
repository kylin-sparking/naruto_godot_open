extends SceneTree

## 「双人同图」在线用例（2026-10-14，用户实机报：**登两个号、同图谁都看不到对面**）。
##
## 这条是双修（#205）与组队/切磋/私聊那一整类的**前置**：看不见对面就什么都测不了。
## 判据分四层，缺哪一层就红在哪一层，不用来回猜：
##   ① 服务端有没有把对面发过来 —— 两端各自的 `map_players` 里必须有对方；
##   ② 客户端解出来对不对 —— 名字/编号/坐标/头像位不能是 0 或空；
##   ③ 世界场景真把他建出来了 —— `_remote_players` 里有他、在场景树里、落点就是帧里的坐标、
##      自己是显示的（"看不见"最阴的一种是数据全对、节点没建）；
##   ④ **对面走一步要跟着动** —— 对端发 36，主号的 `map_players` 与场景里的演员都要挪过去。
##      本轮就是这一层红的：187 少认一段 command ⇒ 位置永远停在进图那一刻，两个号从同一个
##      出生点起步就重叠、一走开就互相看不见（用户 2026-10-14 实机的报法正是"谁都看不到对面"）。
## ⚠ 场景**先立**、第二个号**后进图**（走信号路径），顺序反了就只能证明"补建函数能跑"。
##
## 跑法：`Godot --headless --path . --script res://测试/双人同图在线回归测试.gd`
## 由 `开发工具/跑在线用例.ps1 -用例 双人同图` 调（夹具给独立端口 18704/18705、
## 第二个账号 `naruto/123456` 与临时角色编号 `NW_SOCIAL_PEER_ID`）。
##
## ⚠ 三条口径（都是踩过的）：
##   · 客户端**只认** `game_settings.backend_port`，不读环境变量 ⇒ 本门自己写、跑完还原；
##   · 本门会**两个会话都登录** ⇒ `user://玩家数据.json` 会被写 ⇒ 按字节快照 + 还原 + 断言；
##   · 主会话就是 autoload 那一个（`character_id == 1`），对端是新 `new()` 出来的第二连接。

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
## 跳跃抛物线判据的参照常数。**只取常数、不调用收端那条函数** ⇒ 不是自证。
const 重力参照 := preload("res://脚本/角色/跳跃常数.gd").重力
## 发包条件（原版"变脏即发"那两条闸门）抽成了纯函数 ⇒ 这里能直接喂真值表判，
## 不必去数真包（数真包要跑完整条客户端→服务端→广播链，那种夹具反而更不可信）。
const 同步口径 := preload("res://脚本/角色/跳跃常数.gd")
const 地图场景路 := "res://场景/地图/地图场景.tscn"
const PEER_ACCOUNT := "naruto"
const PEER_PASSWORD := "123456"

var _主		# autoload BackendConnection
var _对		# 第二条连接
var _对编号 := 0
var _对双修帧: Array = []	## 对端收到的打坐状态帧（`action` 2 = 邀请）—— 判"这一次新发了"用
var _失败: Array[String] = []
var _原端口 := -1
var 存档路 := "user://玩家数据.json"
var 存档前 := PackedByteArray()
var 本来有存档 := false

## ── 探针（2026-10-14 加）───────────────────────────────────────────────────
## 用户实机两句反馈把这门顶出了两个新洞：
##   · "延迟还是很大" ⇒ 以前只量**平滑度**（静止帧/反向帧），量不出"我比他晚了几十毫秒"
##     这一件事 ⇒ 现在把延迟**量成毫秒**：包里的位置他什么时候发的、我什么时候收到的、
##     我这边的身体什么时候才走到那个点上。
##   · "还是看不到别人释放技能特效" ⇒ 以前 ⑦ 是**手工喂一条 1328 文本**，只证明
##     "我会解这条帧"，证明不了"对端真发招 ⇒ 服务端真转发 ⇒ 我真收得到"。
##     现在让对端**真的调 `announce_skill_cast`（= 出手那一拍的广播）**（真 TCP 出包、服务端真广播）。
var _探针在等 := {}			## x -> 发送毫秒
var _单向毫秒: Array = []		## 每包一条「出包 → 本端解出来」的单向耗时
var _出招探针: Array = []		## 收到的 1328 原文（按到达顺序）
var _出招毫秒: Array = []		## 与 出招探针 同序：到达那一刻的毫秒（量"出手→我看见"）
var _发招时刻 := 0				## 对端出包那一刻
var _移动探针在 := false
var 包计数 := 0				## 对端 187 一共落了几包（平滑度要认出"刚落包的那一帧"）
var 在线鼠位 := Vector2(-80.0, -80.0)


func _initialize() -> void:
	call_deferred("_跑")


func 拍快照() -> void:
	var 读 := FileAccess.open(存档路, FileAccess.READ)
	if 读 == null:
		本来有存档 = false
		return
	本来有存档 = true
	存档前 = 读.get_buffer(读.get_length())


func 还原存档() -> void:
	if 本来有存档:
		var 写 := FileAccess.open(存档路, FileAccess.WRITE)
		if 写 != null:
			写.store_buffer(存档前)
			写.close()
		var 读 := FileAccess.open(存档路, FileAccess.READ)
		var 现 := 读.get_buffer(读.get_length()) if 读 != null else PackedByteArray()
		_记(现.size() == 存档前.size(), "跑完把 %s **按字节还原**了（跑前 %d 字节）"
				% [存档路, 存档前.size()])
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
		_记(not FileAccess.file_exists(存档路), "跑前没有存档 ⇒ 跑完也不该留下（本门两个号都登录过）")


func _动作到了(演员: Node2D, 名: String) -> bool:
	if 演员 == null or not is_instance_valid(演员) or 演员.get_child_count() == 0:
		return false
	return String((演员.get_child(0) as Node).get("action")) == 名


## 187 到达的那一刻（`后端连接._process` 里 poll 到、解完就发信号）⇒ 记下与出包时刻之差。
func _收移动探针(状: Dictionary) -> void:
	if not _移动探针在 or int(状.get("character_id", 0)) != _对编号:
		return
	包计数 += 1		## 平滑度那把尺子要认出"这一帧刚落了他的一包"（见下面 走在包数）
	var 键 := int(状.get("x", 0))
	if _探针在等.has(键):
		_单向毫秒.append(float(Time.get_ticks_msec() - int(_探针在等[键])))
		_探针在等.erase(键)


func _收出招探针(状: Dictionary) -> void:
	if int(状.get("character_id", 0)) != _对编号:
		return
	_出招探针.append(状)
	_出招毫秒.append(Time.get_ticks_msec())


## 尺子的读数辅助：**空数组不许崩**（崩了会把"包一个都没到"这种最坏情况伪装成量具坏了）。
func _中位(已排好的: Array) -> float:
	if 已排好的.is_empty():
		return -1.0
	return float(已排好的[int(已排好的.size() / 2)])


func _最大(已排好的: Array) -> float:
	if 已排好的.is_empty():
		return -1.0
	return float(已排好的[已排好的.size() - 1])


## 取"现在是哪几个"（按实例身份，不按个数）。
func 件名单(根: Node, 关键字: String) -> Array:
	var 名单: Array = []
	for 子 in 根.get_children():
		var 脚 = 子.get_script()
		if 脚 != null and String((脚 as Resource).resource_path).contains(关键字):
			名单.append(子.get_instance_id())
	return 名单


## ⚠ 判"这一拍挂出了新的特效"要用**身份差**，不能用"数量变多"：上一招的特效正好在这一拍
## 自己播完消失 ⇒ 一加一减数量打平，判据假红（2026-10-14 ⑨′ 就是这么红的）。
func 新挂出(根: Node, 关键字: String, 之前: Array) -> int:
	var 新 := 0
	for 身份 in 件名单(根, 关键字):
		if not 之前.has(身份):
			新 += 1
	return 新


func _帧里到了(后, 编号: int, 目标x: int) -> bool:
	return int((后.map_players as Dictionary).get(编号, {}).get("x", -1)) == 目标x


## 演员有没有走到某一格（攀爬那段要判 y，x 那条判据不够用）。
func _到了某处(演员: Node2D, 目标: Vector2) -> bool:
	return 演员 != null and is_instance_valid(演员) 			and 演员.position.distance_to(目标) < 6.0


func _过了某点(演员: Node2D, 目标x: float) -> bool:
	## 「至少已经到了」而不是「落在 ±2 的带里」：收端按速度自己积分，最后一包之后还会
	## 往前挪一小截再收回来 —— 窄带子会在他"已经过头"那一瞬间判成没到（假红）。
	return 演员 != null and is_instance_valid(演员) and 演员.position.x >= 目标x - 2.0


func _记(过: bool, 文: String) -> void:
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


func _跑() -> void:
	拍快照()
	_主 = root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if _主 == null or 会话 == null:
		printerr("双人同图：缺 BackendConnection / GameSession 单例")
		quit(1)
		return
	## 独立端口（18704）—— 默认 18684 是**用户自己那台客户端在连的号**，绝不能拿用例去点它。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18704
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_对编号 = int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	print("连夹具端口 %d；对端角色编号 %d（账号 %s）" % [口, _对编号, PEER_ACCOUNT])
	if _对编号 <= 0:
		printerr("双人同图：夹具没给 NW_SOCIAL_PEER_ID ⇒ 没有第二个号，本门无从判起")
		还原端口()
		quit(1)
		return

	_主.sync_character()
	if not await _等秒(20.0, func() -> bool: return bool(_主.in_game)):
		printerr("双人同图：主号进不了游戏 %s - %s" % [_主.status, _主.detail])
		收拾并退出()
		return

	## ⚠ 顺序必须和玩家实机一致：**先把地图场景立起来**，第二个号再进图。
	## 反过来（两个号都进去了才建场景）只走 `_ready()` 里的 `_hydrate_server_entities()`，
	## 那条路证明得了"补建函数本身能跑"，证明不了真机上"对面走进你屏幕"这一路（信号路径）。
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	for 帧 in 14:
		await process_frame
	var 管: Node = 场景.get_node_or_null("窗口管理")
	if 管 != null:
		管.call("全部关闭")
	var 实体: Node = 场景.find_child("LifeRoot", true, false)
	_记(实体 != null, "地图场景起来了（LifeRoot 取到了）")
	if 实体 == null:
		收拾并退出()
		return
	## 探针挂在**主号那条连接**上（就是真机里"看别人"的那台客户端走的是同一个信号）。
	_主.connect("player_moved", Callable(self, "_收移动探针"))
	_主.connect("player_cast", Callable(self, "_收出招探针"))

	# 第二个号：另起一条连接（同一个 Godot 进程里两条真 TCP 会话，服务端按账号各建一个 session）
	_对 = BACKEND_SCRIPT.new()
	_对.name = "双人同图对端"
	root.add_child(_对)
	## ★ 对端收到的**每一条**打坐状态帧都记下来（`action` 2 = 双修邀请）。
	## ⚠ 光看 `authoritative_heal.pending_inviter_id` 会**假绿**：那一格是粘的 ——
	## 早些时候收到过一次邀请就一直留着，后面邀请根本没发出去也照样等于我的号
	## （10-17 本轮 ⑪ 的"同意被拒"就是这么被盖住的）。判"这一次真的发了"只能看**新帧**。
	_对.connect("heal_state_received", func(状: Dictionary) -> void: _对双修帧.append(状.duplicate(true)))
	_对.connect_backend(PEER_ACCOUNT, PEER_PASSWORD, false)
	if not await _等秒(10.0, func() -> bool: return bool(_对.authenticated)):
		printerr("双人同图：第二个号登录不上（夹具里有没有 %s 这个账号？）" % PEER_ACCOUNT)
		收拾并退出()
		return
	var 找 := 0
	for 角 in _对.characters:
		if int(角.get("id", 0)) == _对编号:
			找 = _对编号
	if 找 == 0:
		_对.characters.append({"id": _对编号, "name": String(OS.get_environment("NW_SOCIAL_PEER_NAME"))})
	if not bool(_对.select_character(_对编号)):
		printerr("双人同图：第二个号选不上临时角色 %d" % _对编号)
		收拾并退出()
		return
	if not await _等秒(20.0, func() -> bool: return bool(_对.in_game) and int(_对.character_id) == _对编号):
		printerr("双人同图：第二个号进不了游戏（%s - %s）" % [_对.status, _对.detail])
		收拾并退出()
		return

	print("主号：角色 %d 图 %d；对端：角色 %d 图 %d"
			% [int(_主.character_id), int(_主.authoritative_map_id),
				int(_对.character_id), int(_对.authoritative_map_id)])
	_记(int(_主.authoritative_map_id) == int(_对.authoritative_map_id),
			"两个号在**同一张图**（%d vs %d）—— 不同图就谈不上看见"
					% [int(_主.authoritative_map_id), int(_对.authoritative_map_id)])

	# ── ① 服务端有没有把对面发过来 ──────────────────────────────────────────
	var 主看见 := await _等秒(8.0, func() -> bool: return (_主.map_players as Dictionary).has(_对编号))
	var 对看见 := await _等秒(8.0, func() -> bool: return (_对.map_players as Dictionary).has(int(_主.character_id)))
	_记(主看见, "★ 主号收到对端的 162（`map_players` 里有 %d）；实得 %s"
			% [_对编号, str((_主.map_players as Dictionary).keys())])
	_记(对看见, "★ 对端收到主号的 162；实得 %s" % str((_对.map_players as Dictionary).keys()))
	if not (主看见 and 对看见):
		收拾并退出()
		return

	# ── ② 解出来的字段对不对（名字/坐标/头像位为 0 就是字段序错了）──────────
	var 态: Dictionary = (_主.map_players as Dictionary).get(_对编号, {}) as Dictionary
	_记(String(态.get("name", "")).length() > 0, "对端名字解出来了：%s" % str(态.get("name", "")))
	_记(int(态.get("x", 0)) != 0 or int(态.get("y", 0)) != 0,
			"对端坐标不是 (0,0)（实得 %s,%s）—— 为 0 说明 162 的字段序对不上"
					% [str(态.get("x", 0)), str(态.get("y", 0))])
	_记(int(态.get("face", 0)) > 0, "对端头像位 %d 有效（脸是 0 就画不出人）" % int(态.get("face", 0)))

	# ── ③ 世界场景真把它建出来了（对端是在场景已立起来之后进图的 ⇒ 走信号路径）──
	## 取演员一律走 `_remote_players`，**不按节点名找**：名字要能落上，得等 ③′ 那步单独判
	## （按名字找一旦因为改名时机落空，整条门会假红 —— 本轮就被它骗过一次）。
	var 名册 = 实体.get("_remote_players")
	var 演员: Node2D = null
	if 名册 is Dictionary:
		var 存 = (名册 as Dictionary).get(_对编号)
		if 存 != null and is_instance_valid(存):
			演员 = 存 as Node2D
	_记(演员 != null, "对端进图那一拍，地图实体把他记进了 `_remote_players`（实得 %s）"
			% (str((名册 as Dictionary).keys()) if 名册 is Dictionary else "取不到"))
	if 演员 == null:
		收拾并退出()
		return
	_记(演员.is_inside_tree(), "那个演员节点真的挂在场景树里（不在树里 = 屏幕上什么都没有）")
	_记(String(演员.name) == "远程玩家_%d" % _对编号,
			"演员节点的名字是「远程玩家_%d」（实得「%s」）—— 名字落不上就没法按名找他" % [_对编号, str(演员.name)])
	var 落点: Vector2 = 演员.position
	_记(absf(落点.x - float(态.get("x", 0))) < 1.0 and absf(落点.y - float(态.get("y", 0))) < 1.0,
			"他的落点就是服务端发的坐标（节点 %s vs 帧里 %s,%s）"
					% [str(落点), str(态.get("x", 0)), str(态.get("y", 0))])
	_记(演员.visible, "演员是显示的（`show_other_characters` 那枚设置要是关了，这里就是关着的）")
	## ⚠ 层带：远程玩家以前**什么都不设** ⇒ 恒为 z=0，而本地玩家/怪物/瓦片都在
	## `层号*512 + 256 + 层内序` 那一档 ⇒ 别人被地面与装饰物整个埋掉（能点着、看不见）。
	## 现在走 `_远程角色层次()` = 同一条层带的**基准值**（不加偏移），
	## 而本地那一头是 `基准 + 1` ⇒ **重叠时严格自己压住别人**（用户 2026-10-17 令：
	## "两个角色叠在一起应该是显示自己为最上层"）。10-17 之前这条正好是反的（远程 +1），
	## 所以判据不能只写"差 ≤ 1"—— 差 1 两个方向都成立 = 反了也不红。
	var 本方: Node2D = 场景.get_tree().get_first_node_in_group("player") as Node2D
	_记(本方 != null and 演员.z_index > 0,
			"远程玩家在角色层带里（他 z=%s）—— 为 0 就是被地面/装饰物埋掉" % str(演员.z_index))
	_记(本方 != null and 本方.z_index > 演员.z_index and 本方.z_index - 演员.z_index <= 1,
			"★ 同一条层带里**本地严格压住远程**（本地 z=%s vs 他 z=%s）—— " % [
					str(本方.z_index) if 本方 != null else "取不到", str(演员.z_index)]
				+ "他比我大就是用户 10-17 报的「叠在一起看不见自己」；差得远就是两人不同带"	)

	# ── ④ 对面**走一步**要跟着动（这一条才是"谁都看不到对面"的真凶）────────────
	## 187 的字段序以前偏了一格（`187:<command>:<charId>:…` 少认 command）⇒ charId 读成 0、
	## x 读成角色编号，`map_players` 查不到键 0 就整帧扔掉 —— **对面永远停在进图那一刻的坐标**：
	## 两个号都从同一个出生点起步 ⇒ 重叠在一起看不出有人，一走开就互相看不见。
	var 原坐标 := Vector2(int(态.get("x", 0)), int(态.get("y", 0)))
	var 新坐标 := Vector2(原坐标.x + 90.0, 原坐标.y)
	_记(bool(_对.send_movement(新坐标, 3, Vector2(400, 0))),
			"对端发出移动请求 36（第 3 段=动作号 3「走」、第 4 段=速度x +400；入口 = 玩家.gd 同一条）")
	var 跟上了 := await _等秒(4.0, _帧里到了.bind(_主, _对编号, int(新坐标.x)))
	var 态后: Dictionary = (_主.map_players as Dictionary).get(_对编号, {}) as Dictionary
	_记(跟上了, "★ 主号收到对端的 187 并把坐标解进了 `map_players`（实得 %s,%s；帧里应是 %s,%s）"
			% [str(态后.get("x", -1)), str(态后.get("y", -1)), str(int(新坐标.x)), str(int(新坐标.y))])
	## ⚠ 判"挪过去了"用**至少到了**，不用"落在 ±2 的带里"：收端按速度自己积分
	## （原版那条 `applyVelocity`），最后一包之后他还会往前挪一小截再收回 ——
	## 拿窄带子去等，正好会在他"已经过头"那一瞬间判成没到（2026-10-14 就这么假红过一次）。
	var 走到 := await _等秒(3.0, _过了某点.bind(演员, 新坐标.x))
	_记(走到, "★ 场景里那个演员真的跟着挪过去了（节点 %s → 至少该到 %s）—— 不挪就是「对面站着不动」"
			% [str(演员.position), str(新坐标)])

	# ── ⑤ 走路要**播走路帧**（用户 2026-10-14 报的第二条：看别人是直板板地平移）────
	## 动作号从 187 的第 11 段来（`PLAYER_MOVEMENT_ACTION_WALK=3`，服务端 `:113`），
	## 折成美术动作名的表在 `原始动画精灵.动作名()`。
	## ⚠ **必须持续发**（真机就是每 0.1 秒一拍）：只发一条再慢慢查，0.45 秒收不到下一包
	##   那具身体会照规矩回站立（"半秒没动静 = 他真停了"），那时查到的就不是"他在走"这件事
	##   —— 2026-10-14 把收端换成"本地积分 + 慢对齐"之后这一步先红过一次，踩的就是这个时机。
	var 精灵 = 演员.get_child(0)
	var 走路动作名 := ""
	var 帧甲 := -1
	var 走路x := float(新坐标.x)
	for 拍 in 10:
		走路x += 32.0
		_对.send_movement(Vector2(走路x, float(新坐标.y)), 3, Vector2(400, 0))
		var 拍起 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - 拍起 < 80:
			await process_frame
		if 拍 == 5:
			走路动作名 = String(精灵.get("action")) if 精灵 != null else "没有精灵"
			帧甲 = int(精灵.get("frame_index")) if 精灵 != null else -1
	var 帧乙: int = int(精灵.get("frame_index")) if 精灵 != null else -1
	_记(走路动作名 == "walk", "连发动作号 3 ⇒ 他那具身体切到 walk（实得「%s」）" % 走路动作名)
	_记(帧乙 != 帧甲 and 帧甲 >= 0, "走路循环的帧号在往前走（第 5 拍到第 10 拍：%d → %d；walk 一套 6 帧 ×120 毫秒）"
			% [帧甲, 帧乙])

	# ── ⑥ 停下来要回站立（停的那一拍必须发得出去，否则对面原地踏步）──────────────
	_对.send_movement(Vector2(走路x, float(新坐标.y)), 1, Vector2.ZERO)
	var 回到站立 := await _等秒(3.0, _动作到了.bind(演员, "stand"))
	_记(回到站立, "对端发动作号 1「站」⇒ 他回到 stand（实得「%s」）"
			% str((演员.get_child(0) as Node).get("action")))

	# ── ⑥′ 爬到绳子上：**层带走绳子那一层、停下来要还挂在绳子上**（用户 2026-10-14 实机报）──
	## 两件事各有各的判据，别混成一条：
	##   · **层带**：本地玩家爬着时进的是 `RenderProfile.角色z(绳子 page, 200) + 1` —— 原版
	##     `AbstractPhysicObject.tikcLayer` 给攀爬角色的是 `getALayer(currLadderRope.page)`
	##     （比地形层高 ⇒ 不被梯子美术盖住），`玩家.gd` 攀爬那一支早接上了；远程这一头
	##     以前只按落脚点 y 算层 ⇒ "爬到一半图层整个不对"。
	##     ⚠ 远程这一头**不带那个 +1**（10-17 起 `+1` 归本地 = "自己压住别人"那条），
	##     所以下面"该是几层"算的是基准值。别顺手也 +1：两边同值时这条判据就分不出方向了。
	##   · **停姿**：本端停在绳子上之后**不再发位移包**，收端那条"半秒没下一包=真停了"
	##     如果一律回站立，就变成"站在半空中"（原版没有超时算停这一说）。
	var 攀爬根 = 场景.get_node_or_null("LadderRoot")
	var 绳表 = 攀爬根.get("ladders") if 攀爬根 != null else null
	if not (绳表 is Array) or (绳表 as Array).is_empty():
		print("  （这张图没有攀爬物，⑥′ 跳过 —— 有绳子的图要单独跑一次）")
	else:
		var 绳: Dictionary = (绳表 as Array)[0]
		var 绳位 := Vector2(float(绳.get("x", 0)), (float(绳.get("y1", 0)) + float(绳.get("y2", 0))) / 2.0)
		var 该是几层: int = RenderProfile.角色z(int(绳.get("page", 0)), 200)
		_记(bool(_对.send_movement(绳位, 5, Vector2(0, -40))),
				"对端发出『上绳』：动作号 5（爬绳）、坐标落在绳子中段 %s" % str(绳位))
		var 上绳了 := await _等秒(3.0, _到了某处.bind(演员, 绳位))
		_记(上绳了, "★ 主号那具身体真的挪到绳子上（节点 %s vs %s）" % [str(演员.position), str(绳位)])
		var 爬绳动作 := String((演员.get_child(0) as Node).get("action"))
		_记(爬绳动作 == "rope", "动作号 5 ⇒ 播 rope（挂在绳上的那套，实得「%s」）" % 爬绳动作)
		_记(演员.z_index == 该是几层,
				"★ 爬着的时候他进的是**绳子那一层**（z=%d，该是 %d）—— 不是按落脚点算的地形层"
						% [演员.z_index, 该是几层])
		## 停手不再发包：等过"半秒没下一包"那条判定窗口（0.45 秒 + 收拢），看他挂不挂得住
		var 等停 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - 等停 < 1200:
			await process_frame
		_记(String((演员.get_child(0) as Node).get("action")) == "rope",
				"⭐ 停在绳子上不再发包 ⇒ **还挂在绳上**（实得「%s」）。"
				% String((演员.get_child(0) as Node).get("action"))
				+ "上一版这里一律回站立 = 用户看到的『停止攀爬后角色站在攀爬物那里』")
		_记(演员.z_index == 该是几层, "停手之后层带不掉回地形层（z=%d，该是 %d）"
				% [演员.z_index, 该是几层])
		## 收尾：让他回地面，后面的 ⑦⑧⑨ 还要用"站着"这个前提
		_对.send_movement(新坐标, 1, Vector2.ZERO)
		await _等秒(3.0, _动作到了.bind(演员, "stand"))

	# ── ⑦ 他**出招**要播出手动作（用户 2026-10-14 报：特效能看到、人直板板站着）──────
	## 走的是真帧入口 `_handle_bridge_text`（= TCP 读到的那一行原文，`后端连接.gd:1637` 同一句），
	## 形状照服务端 `_send_player_attack_info()`：`1328:<charId>:…:<stance>:<dir>:<speed>:<skillId>:…`
	## stance=11 就是 `Action.as:6` 那张表里的 "attack"。
	_主.call("_handle_bridge_text", "1328:%d:0:0:0:0:11:1:0:1001001:1:%d:%d:-:0:-:-"
			% [_对编号, int(新坐标.x), int(新坐标.y)])
	for 弃 in 4:
		await process_frame
	var 特效前 := 件名单(实体, "技能动画精灵")
	var 飞行前 := 件名单(实体, "技能飞行物")
	_记(String(精灵.get("action")) == "attack",
			"收到 1328(stance=11) ⇒ 他切到 attack（实得「%s」）" % str(精灵.get("action")))
	# ⑦b **起手特效也要挂出来**（用户 2026-10-14："技能特效只能看到怪物的受击特效"）
	var 怪号 := 0
	for 键 in (_主.map_monsters as Dictionary).keys():
		怪号 = int(键)
		break
	_主.call("_handle_bridge_text", "1328:%d:0:0:0:0:11:1:0:1001002:1:%d:%d:-:%d:-:-"
			% [_对编号, int(新坐标.x), int(新坐标.y), 怪号])
	for 弃 in 6:
		await process_frame
	_记(新挂出(实体, "技能动画精灵", 特效前) >= 1,
			"1001002 的起手特效挂进了地图实体（发招前场上 %d 个、现在新挂 %d 个）"
					% [特效前.size(), 新挂出(实体, "技能动画精灵", 特效前)])
	_记(新挂出(实体, "技能飞行物", 飞行前) >= 1 and 怪号 > 0,
			"有 ball 相位的技能还抛了飞行物去追那只怪（怪编号 %d，发招前 %d 个、现在新挂 %d 个）"
					% [怪号, 飞行前.size(), 新挂出(实体, "技能飞行物", 飞行前)])
	_记(bool((实体.get("_远程出招中") as Dictionary).get(_对编号, false)),
			"出手期间记在 `_远程出招中` 里 —— 移动帧不许把这一招打断")
	var 收回 := await _等秒(3.0, _动作到了.bind(演员, "stand"))
	_记(收回, "一招播完自己回站立（实得「%s」；attack 一套 4 帧 ×150 毫秒）"
			% str((演员.get_child(0) as Node).get("action")))
	# ⑧ stance 槽没给（服务端自己发起的广播那 9 处都是 `stance=0`）⇒ 按技能号查同一张动作表
	_主.call("_handle_bridge_text", "1328:%d:0:0:0:0:0:-1:0:9029:1:%d:%d:-:0:-:-"
			% [_对编号, int(新坐标.x), int(新坐标.y)])
	for 弃 in 4:
		await process_frame
	var 查得 := String(精灵.get("action"))
	_记(查得 != "stand" and not 查得.is_empty(),
			"stance=0 时按技能号 9029 查 `数据/技能动作.json` 也要切到出手动作（实得「%s」）" % 查得)
	_记(int((演员.get_child(0) as Node).get("frame_index") if 演员.get_child_count() > 0 else -1) >= 0,
			"出手动画的帧号可读")

	# ── ⑨ **真发招**端到端（用户 2026-10-14 第二条："还是看不到别人释放技能特效"）─────
	## 上面 ⑦⑧ 是**手工喂一条 1328 文本**给解码器 ⇒ 只证明"这条帧我会解"，证明不了
	## "对端真发招 ⇒ 服务端真转发 ⇒ 我真收得到"。这一节让**对端真的调 `announce_skill_cast`（= 出手那一拍的广播）**：
	## 真 TCP 出 1328 ⇒ 服务端 `handle_player_attack_announce` 里那句
	## `_send_visible(self._strip_timestamp(read_str), include_self=False)`（`:41091`）真转发
	## ⇒ 主号这条连接真收到。断在哪一段（发不出去 / 转不过来 / 收得到但没画出来）一眼可见。
	var 特效乙 := 件名单(实体, "技能动画精灵")
	var 飞行乙 := 件名单(实体, "技能飞行物")
	_出招探针.clear()
	_出招毫秒.clear()
	var 怪号乙 := 0
	for 键乙 in (_对.map_monsters as Dictionary).keys():
		怪号乙 = int(键乙)
		break
	_记(怪号乙 > 0, "对端自己也看得见怪（这一招拿 %d 当靶子）" % 怪号乙)
	## 1001002 = 工程特效表里**确定有 start 与 ball 两相位**的一号 ⇒ 一次把
	## "起手那团"和"飞出去那颗球"两件事都判掉。服务端查不到这个号不影响转发
	## （转发那支只看 `not selected_ids`，玩家目标串是 `-`）。
	_发招时刻 = Time.get_ticks_msec()
	_记(bool(_对.announce_skill_cast(1001002, 1, [怪号乙], 新坐标, 1, 11)),
			"★ 对端真的发出一条 1328（技能 1001002、靶子=怪 %d、出手号 stance=11）" % 怪号乙)
	var 收到真招 := await _等秒(4.0, func() -> bool: return not _出招探针.is_empty())
	_记(收到真招, ("★ 服务端把对端这一招**转发给了主号**（实收 %d 条 1328）—— "
			+ "收不到就是服务端那段 `_send_visible` 没走到（重播保护 / 距离校验 / 根本没转发）")
					% _出招探针.size())
	## ⭐ **出手 → 我看见 隔了几毫秒**（用户 2026-10-14："从别人窗口看技能特效延迟也很高"）。
	## 特效节点是在收到这条帧的那同一个回调里挂出来的 ⇒ 这个差就是旁观者眼里"他放了半天我才看见"的数。
	## 上一轮的毛病不在网络也不在这条链上，而在**发包时机**：广播被和结算捆在一起压到飞行物落地
	## 才发（≈470 毫秒），所以这里必须先由 `技能单体与面积行为门` 钉住"按下那一拍就发"，
	## 本条再钉"发出去到挂出来 ≤ 40 毫秒"。
	if 收到真招:
		var 出手延迟 := float(int(_出招毫秒[0]) - _发招时刻)
		print("  施法延迟尺子：出手→我看见 %.0f 毫秒（出包 %d / 到达 %d）" % [出手延迟, _发招时刻, int(_出招毫秒[0])])
		_记(出手延迟 <= 40.0, "★ 别人出手到我看见 ≤ 40 毫秒（实得 %.0f）—— 这一段以前要等弹落地 ≈470 毫秒"
				% 出手延迟)
	if not _出招探针.is_empty():
		var 招帧: Dictionary = _出招探针[0] as Dictionary
		_记(int(招帧.get("skill_id", 0)) == 1001002,
				"转过来的这条里技能号还是 1001002（实得 %s）" % str(招帧.get("skill_id")))
		_记(String(招帧.get("monsters", "-")) == str(怪号乙),
				"转过来的这条里靶子还是那只怪（实得「%s」）—— 目标串丢了飞行物就没处指"
						% str(招帧.get("monsters")))
	for 弃 in 6:
		await process_frame
	_记(新挂出(实体, "技能动画精灵", 特效乙) >= 1,
			"这一路也真把起手特效挂了出来（发招前场上 %d 个、现在新挂 %d 个）"
					% [特效乙.size(), 新挂出(实体, "技能动画精灵", 特效乙)])
	_记(新挂出(实体, "技能飞行物", 飞行乙) >= 1,
			"有 ball 相位 ⇒ 还抛了飞行物去追靶子（发招前场上 %d 个、现在新挂 %d 个）"
					% [飞行乙.size(), 新挂出(实体, "技能飞行物", 飞行乙)])
	## ⑨′ **没有目标的那一招也要看得见**（用户"还是看不到别人释放技能特效"的另一半）：
	## 以前 `request_skill_attack`（现已拆成 `announce_skill_cast` + `request_skill_damage`）一遇到空目标就 `return false`，整条广播都不发出去 ⇒
	## 对面既没动作也没特效。原版 `AbstractAttackSkill.hitTest()` 是一出手就发（`:629`，
	## 连 `getSkillTarget()==2` 那一档都发），只有结算那条才需要目标。
	_出招探针.clear()
	## ⚠ "发招前"那份名单必须在**发招之前**取：这一路是同步的（发出去 → 服务端转回来 →
	## 地图实体当场挂特效），晚一步取就已经把新挂的那个算进"前"里了（⑨′ 第一版就这么 self-fulfilled）。
	var 特效丙 := 件名单(实体, "技能动画精灵")
	_记(bool(_对.announce_skill_cast(1001003, 1, [], 新坐标, 1, 11)),
			"★ 对端**空目标**也真的发出了 1328（自检 / 空放那一类，1001003）")
	var 收到空招 := await _等秒(4.0, func() -> bool: return not _出招探针.is_empty())
	_记(收到空招, "★ 空目标那一招服务端也转发到了主号（实收 %d 条）—— 收不到就是'没目标不发'那条老路"
			% _出招探针.size())
	if not _出招探针.is_empty():
		var 空招帧: Dictionary = _出招探针[0] as Dictionary
		_记(int(空招帧.get("skill_id", 0)) == 1001003 and String(空招帧.get("monsters", "")) == "-",
				"转过来的这条目标槽是 `-`、技能号还是 1001003（实得「%s」/ %s）"
						% [str(空招帧.get("monsters")), str(空招帧.get("skill_id"))])
	for 弃 in 6:
		await process_frame
	_记(新挂出(实体, "技能动画精灵", 特效丙) >= 1,
			"空目标这一招的起手特效也挂出来了（发招前场上 %d 个、现在新挂 %d 个）"
					% [特效丙.size(), 新挂出(实体, "技能动画精灵", 特效丙)])
	# ── ⑨⁗ **按两个真号各自的职业各测一招**（用户 10-15："木叶忍者释放的技能油女澪看不到"）──
	## 上面三招全是 1001xxx —— 那是**夹具号**的号段，木叶忍者（job=300）和油女澪（job=400）
	## 谁都没学过。只钉一招 = 换号就假绿（这条坑本轮已经在别的出证脚本上栽过一次），
	## 所以拿两个号**真学的两招**各跑一遍。ball 那一列是 10-15 从
	## `数据/技能动画元数据.json` **现查写死**的（3001001 无 ball、4001002 有 ball；
	## ⚠ 别拿 `SkillAnimationScript.有相位()` 当参照 —— 被测的那条链读的就是它，自证）。
	## ⚠ **必须带一号"以 0 开头的"**：`数据/技能动画元数据.json` 的键是 7 位**带前导零**的串，
	## `0002000` 这一整段就是世界/家族/奥义那一类忍术。收端以前取号写的是 `str(int(...))`
	## ⇒ 前导零被吃掉 ⇒ 查表落空 ⇒ 施法光与飞行物整条静默，而受击特效走另一条链（已补零）
	## ⇒ 用户 10-15 报的"世界忍术潜影蛇手之类看不到施法特效和飞行特效、只能看到受击特效"。
	## 3001001/4001002 恰好都是 7 位无前导零 ⇒ 只测它们 = 假绿（这条就是补那个洞）。
	for 试 in [[3001001, false], [4001002, true], [2000, true]]:
		var 招号: int = int(试[0])
		var 该抛: bool = bool(试[1])
		_出招探针.clear()
		var 特效丁 := 件名单(实体, "技能动画精灵")
		var 飞行丁 := 件名单(实体, "技能飞行物")
		_记(bool(_对.announce_skill_cast(招号, 1, [怪号乙], 新坐标, 1, 11)),
				"★ 对端真的发出 1328（%d）" % 招号)
		var 收到丁 := await _等秒(4.0, func() -> bool: return not _出招探针.is_empty())
		_记(收到丁, "★ 服务端把 %d 这一招转发到了主号（实收 %d 条）—— 收不到就是转发那段没走到"
				% [招号, _出招探针.size()])
		for 弃 in 6:
			await process_frame
		## ⚠ 文案**不许跨行 `+` 再接 `%`**：GDScript 里 `%` 比 `+` 结合更紧，
		## `"长句" + "后半" % [参数]` 会把参数喂给只有半截的那条串 ⇒ 报 formatting error，
		## 而打出来的是一串没代入的 `%d` 却仍然记成 √（伪装成 ok）。
		var 新特效数 := 新挂出(实体, "技能动画精灵", 特效丁)
		var 新飞行数 := 新挂出(实体, "技能飞行物", 飞行丁)
		_记(新特效数 >= 1,
				"%d 的起手特效在旁观端挂出来了（发招前 %d 个、现在新挂 %d 个）—— 挂不出来就是「油女澪看不到木叶忍者放技能」的那一半" % [招号, 特效丁.size(), 新特效数])
		if 该抛:
			_记(新飞行数 >= 1,
					"%d 表里有 ball 相位 ⇒ 旁观端也抛了飞行物（发招前 %d、新挂 %d）" % [招号, 飞行丁.size(), 新飞行数])
		else:
			_记(新飞行数 == 0,
					"%d 表里没有 ball 相位 ⇒ 不该凭空抛飞行物（实挂 %d）" % [招号, 新飞行数])
	var 学过的: Array = []
	for 技 in (_对.authoritative_skills as Dictionary).keys():
		if int(技) > 0:
			学过的.append(int(技))
	print("  对端已学技能号：%s" % (str(学过的) if not 学过的.is_empty() else "（一个都没有）"))

	# ── ⑩ 连续走的**平滑度 + 延迟**（用户 2026-10-14："原版的延迟我肉眼分辨不出来"）──
	## 尺子：对端按真机节奏**每 100 毫秒真实时间**发一个采样点（8 段 ×40 像素），本端
	## **逐引擎帧**记演员的 x 与时刻 ⇒ 数三件事：静止帧（这帧没挪 = 走一下停一下）、
	## 反向帧（往回退 = 两条补间在抢同一个 position）、最大单帧跳（跳得大 = 一格一格）。
	## ⚠ 采样窗口必须按**真实毫秒**切，不能按帧数：无头跑的引擎帧不固定 60fps，
	## 按帧数会把"100 毫秒一包"压成几十毫秒，量出来的全是假数（本轮第一版就栽在这）。
	##
	## 延迟这一笔**必须量成毫秒**（用户 2026-10-14："延迟还是很大"）：只量平滑度照不到
	## "我比他晚了 N 毫秒"这件事。两笔账分开量，才知道该修哪一层：
	##   · **单向传输** = 出包那一刻 → 主号把这条 187 解出来那一刻（真 TCP + 真服务端广播）；
	##   · **晚看到**   = 出包那一刻 → 主号屏幕上那具身体真的走到这个点上那一刻
	##     （= 单向传输 + 本地外推/收敛的欠账，才是玩家眼里的那个"延迟"）。
	## ⚠ 起点要**现读**，不能拿 ④ 那一份 `态后`：⑤ 已经把他往前走了 320 像素，用旧起点
	## 会让这一段变成"往回走"，反向帧与终点误差全成了假数。
	var 当前: Dictionary = (_主.map_players as Dictionary).get(_对编号, {}) as Dictionary
	var 起点x := float(当前.get("x", 0))
	var 起点y := float(当前.get("y", 0))
	var 采样: Array = []
	var 在走采样: Array = []		## 只含"还在一段一段发点"期间的帧：静止帧要在这段里数
	var 走在时刻: Array = []		## 与 在走采样 同序：这一帧是第几毫秒（单帧位移要按这一帧的帧长折算）
	var 走在包数: Array = []		## 与 在走采样 同序：采这一帧时对端已经落了几包
	var 走在段: Array = []		## 与 在走采样 同序：这一帧属于第几个发点窗口（第 0 段是"把他对到这一段起点"，不判）
	var 时刻: Array = []			## 与 采样 同序：这一帧是第几毫秒（延迟尺子要用）
	var 报点 := {}					## x -> 发送毫秒
	var 末点 := 起点x
	_移动探针在 = true
	_单向毫秒.clear()
	for 段 in 8:
		末点 = 起点x + 40.0 * (段 + 1)
		var 发于 := Time.get_ticks_msec()
		_探针在等[int(末点)] = 发于
		报点[int(末点)] = 发于
		## 速度要和采样步长**自洽**：40 像素 / 100 毫秒 = 400 像素每秒。
		## （第一版给的是 240，外推按 240 猜、真值却按 400 跑 ⇒ 量出来的"终点误差"是夹具自己的错）
		_对.send_movement(Vector2(末点, 起点y), 3, Vector2(400, 0))
		var 窗起 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - 窗起 < 100:
			await process_frame
			采样.append(演员.position.x)
			在走采样.append(演员.position.x)
			走在时刻.append(Time.get_ticks_msec())
			走在包数.append(包计数)
			走在段.append(段)
			时刻.append(Time.get_ticks_msec())
	_移动探针在 = false
	## 收敛窗口要给够：收端最后一段最多按速度再猜 0.2 秒，之后还要把他收回真值点
	## （0.5 秒收不到下一包 = 判定他真停了）⇒ 只等 0.4 秒会把"还在收"当成"停在错的地方"
	## （本轮第一版就是这么误判成 27 像素终点误差的）。
	var 收敛起 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 收敛起 < 900:
		await process_frame
		采样.append(演员.position.x)
	var 静止 := 0
	var 反向 := 0
	var 最大跳 := 0.0
	var 超限帧 := 0
	var 首段帧 := 0				## 第 0 段（把他对到本段起点）让开的帧数
	var 最差比 := 0.0
	var 最差处 := ""
	var 上个符号 := 0
	## ⚠ 头 3 帧不判：第 1 包到达时收端要把节点从"上一段的站位"挪到这一段的起点
	## （>200 像素走的是"直接落位"那一支），那是**对位**、不是走路的抖。
	for i in range(3, 在走采样.size()):
		var 步: float = float(在走采样[i]) - float(在走采样[i - 1])
		## ⚠ **第 0 段（第一个 100 毫秒窗口）整段不判**：上一节刚把他发到别的位置（⑩′ 那一腿
		## 是"把他挪到 60 像素外"、后面还把他摆回对坐位），这一段头几帧是**把他对到本段起点**，
		## 不是走路。10-18 实测：第 3 帧 6 毫秒里挪 7.6 像素（该挪 2.4）—— 帧长越短，
		## `400×dt+4` 越贴不住一次对位。静止/反向照旧判，"一格一格"那种病在 1~7 段照样现形。
		if int(走在段[i]) == 0:
			首段帧 += 1
			continue
		if absf(步) < 0.05:
			静止 += 1
		else:
			var 号: int = 1 if 步 > 0 else -1
			if 上个符号 != 0 and 号 != 上个符号:
				反向 += 1
			上个符号 = 号
			## ⚠ 判"跳得大不"**不能钉一个固定像素数**：收端按对端速度自己积分
			## （原版那条 `x += velocity*dt`），一帧本来就该挪 `400 × 这一帧的帧长`。
			## 以前钉死 20 像素（= 400×50ms），无头负载一抖出现 63 毫秒的长帧就误报 25.18
			## （10-17 本轮实测）；而"一格一格"的病状是**一帧挤进 40 像素**，
			## 跟帧长无关 ⇒ 按这一帧自己的帧长折算：`400 × dt + 4`（4 像素留给取整/轮询零头）。
			var 帧长 := clampf(float(走在时刻[i] - 走在时刻[i - 1]) / 1000.0, 0.001, 0.5)
			var 该帧上限 := 400.0 * 帧长 + 4.0
			var 比 := absf(步) / 该帧上限
			if 比 > 最差比:
				最差比 = 比
				最差处 = "第 %d 帧：挪 %.2f / 帧长 %.1f 毫秒 / 上限 %.2f" % [
						i, 步, 帧长 * 1000.0, 该帧上限]
			if 比 > 1.0:
				超限帧 += 1
			最大跳 = maxf(最大跳, absf(步))
	var 终点误差: float = absf(float(采样[采样.size() - 1]) - 末点)
	var 真判帧 := maxi(0, 在走采样.size() - 首段帧 - 3)
	print(("  平滑度尺子：采样 %d 帧 / 静止 %d / 反向 %d / 对端共落 %d 包 / 让开对位段 %d（真判 %d 帧）"
			+ " / 最大单帧跳 %.2f 像素（按该帧帧长折算，最差比 %.2f @ %s，超限 %d 帧）"
			+ " / 终点误差 %.2f（末点 %s）") % [
				采样.size(), 静止, 反向, 包计数, 首段帧, 真判帧, 最大跳,
				最差比, 最差处, 超限帧, 终点误差, str(末点)])
	## ⚠ 让开对位段之后**还得真判到东西**：整段都被让开的话，这条就变成 0 帧也打「红 0」
	## （假绿的新形状：判据还在、覆盖没了）。60 帧 = 至少三个发点窗口真在走（每窗约 15 帧）；
	## 覆盖率随包频与帧长变（实测 8 包 / 120 帧），掉到 60 以下说明夹具或网络变了 ⇒ 要让人看见。
	_记(真判帧 >= 60,
			"量具自检：让开 %d 帧对位段之后还剩 %d 帧真在判（不足 60 帧 = 这条等于没判）" % [首段帧, 真判帧])
	var 传输 := _单向毫秒.duplicate()
	传输.sort()
	var 晚看到: Array = []
	for 键丙 in 报点.keys():
		for i in 采样.size():
			if float(采样[i]) >= float(键丙) - 1.0:
				晚看到.append(float(时刻[i]) - float(报点[键丙]))
				break
	var 晚甲 := 晚看到.duplicate()
	晚甲.sort()
	print("  延迟尺子：单向传输 中位 %s / 最大 %s 毫秒（%d 包）；晚看到 中位 %s / 最大 %s 毫秒（%d 个点）"
			% [str(_中位(传输)), str(_最大(传输)), 传输.size(),
				str(_中位(晚甲)), str(_最大(晚甲)), 晚看到.size()])
	_记(传输.size() == 8, "8 个采样点主号都收到了（实收 %d）—— 少一包就是这条链在丢包"
			% 传输.size())
	_记(晚看到.size() == 8, "8 个点都算出了『晚看到』的毫秒数（实得 %d）" % 晚看到.size())
	_记(not 传输.is_empty() and float(传输[int(传输.size() / 2)]) <= 60.0,
			"单向传输延迟中位 ≤ 60 毫秒（实得 %s）—— 真 TCP + 真服务端广播这一段的账"
					% str(_中位(传输)))
	var 晚文 := ("★ 看到对面比他自己晚 ≤ 30 毫秒（实得中位 %s / 最大 %s 毫秒）—— 这就是玩家眼里"
			+ "那个『延迟』；改成原版那套『收端按速度自己积分』之前实测中位 62 毫秒"
			+ "（`velocity_x` 那一格根本没解进 state ⇒ 外推整段是死的）")
	_记(not 晚甲.is_empty() and float(晚甲[int(晚甲.size() / 2)]) <= 30.0,
			晚文 % [str(_中位(晚甲)), str(_最大(晚甲))])
	_记(静止 <= 6, "连续走 8 段里静止帧 ≤ 6（实得 %d / %d 帧）—— 静止帧多就是「走一下停一下」"
			% [静止, 在走采样.size()])
	_记(反向 == 0, "没有往回退的帧（实得 %d）—— 有就是两条补间在抢同一个 position" % 反向)
	_记(超限帧 == 0, "单帧位移没有超过「这一步本来就该走的量」（上限 = 400 像素/秒 × 该帧帧长 + 4；"
			+ "最差比 %.2f，超限 %d 帧，最大一帧 %.2f 像素）—— 真\"一格一格\"是 40 像素挤进一帧" % [
				最差比, 超限帧, 最大跳])
	_记(终点误差 <= 6.0, "走完整段落在服务端发的终点上（误差 %.2f）" % 终点误差)

	# ── b 跳跃段：**旁观端那具身体要和真身跑同一条抛物线**（用户 10-15"一抖一抖"）──
	## 发端在跳跃中途**故意不纠偏** —— 原版 `Sampler.as:87-90` 把"只有 VELOCITY 变脏"那一格
	## 明确排除掉（不发包），前提就是收端那具身体自己带重力。上一版这里对动作 2 按**常速**
	## 推（`速度.y × 秒`）⇒ 与真身每帧 `velocity.y += 2000 × delta` 算的**不是同一条曲线**：
	## 到 200 毫秒时解析式已经拐下来，常速式还在往上多冲 40 像素，下一包再把他硬拽回地面
	## —— 肉眼正是"跳一下、抖一下"。参照值按解析式自己算，不问被测对象要。
	var 跳包位 := 演员.position
	_对.send_movement(Vector2(跳包位.x + 80.0, 跳包位.y), 2, Vector2(400.0, -666.0))
	var 抛物最大差 := 0.0
	var 跳帧数 := 0
	var 最长帧 := 0.0
	var 起跳到达 := -1.0		## 那一包**真正让画面动起来**的时刻（秒）—— 参照式从发出时刻起算，差的正是这一段
	var 跳窗起 := Time.get_ticks_msec()
	var 上刻 := 跳窗起
	while Time.get_ticks_msec() - 跳窗起 < 200:
		await process_frame
		var 此刻 := Time.get_ticks_msec()
		最长帧 = maxf(最长帧, float(此刻 - 上刻) / 1000.0)
		上刻 = 此刻
		跳帧数 += 1
		if 起跳到达 < 0.0 and absf(演员.position.y - 跳包位.y) > 0.5:
			起跳到达 = float(此刻 - 跳窗起) / 1000.0
		var 秒 := float(此刻 - 跳窗起) / 1000.0
		var 期望y := 跳包位.y - 666.0 * 秒 + 0.5 * 重力参照 * 秒 * 秒
		抛物最大差 = maxf(抛物最大差, absf(演员.position.y - 期望y))
	## ⚠ 阈值**不能钉 6**（10-17 本轮实测 9.88 / 6.51 被负载顶红），也不能只按帧长折算：
	## 偏移有两个来源 —— ① **这一包到达晚了**：参照式从"发出"起算，收端只能从"收到"起算，
	## 差 `|vy| × 到达延迟`（666 像素/秒 × 8 毫秒 ≈ 5 像素）；② 收端逐帧显式欧拉 vs 解析式，
	## 差 `½·g·t·dt`（t=0.2 秒、最长帧 30 毫秒 ⇒ 6 像素）。两项都**按这一轮实测**算出来。
	## "常速积分"那个错是 40 像素量级，照样越线（判据的阳性对照没有丢）。
	var 到达秒 := 起跳到达 if 起跳到达 >= 0.0 else 0.05
	var 抛物阈值 := 666.0 * 到达秒 + 0.5 * 重力参照 * 0.2 * 最长帧 + 3.0
	print("  跳跃抛物线尺子：采样 %d 帧 / 与解析式最大偏差 %.2f 像素（到达 %.1f 毫秒、最长帧 %.1f 毫秒 ⇒ 阈值 %.2f；常速积分在 200 毫秒处该差 %.0f）"
			% [跳帧数, 抛物最大差, 到达秒 * 1000.0, 最长帧 * 1000.0, 抛物阈值, 0.5 * 重力参照 * 0.04])
	_记(跳帧数 >= 6, "跳跃这一段至少采到 6 帧（实得 %d）—— 采太少这条判据是空的" % 跳帧数)
	_记(起跳到达 >= 0.0, "跳跃那一条包**真的让画面动了起来**（不能是收端早就在动 ⇒ 起点判据自证）")
	_记(抛物最大差 <= 抛物阈值,
			"旁观端与真身跑同一条抛物线（最大偏差 %.2f / 阈值 %.2f 像素）—— 常速积分会差 40 像素，就是那一下抖"
					% [抛物最大差, 抛物阈值])
	# ── c 停手尺子：**本端停了，对面那具身体不该再多冲一下**（用户 10-15 的 GIF：
	## "我操控木叶忍者的窗口已经停止运动了，但是油女澪的窗口还动了一下"）──────
	## 喂三段"正在爬"（vy=−125，每段隔 100 毫秒 = 真机节流周期），再喂一段"松手"（vy=0），
	## 然后等 1 秒让它收拢，量**最终落点比最后一条包给的点多走多少像素**。
	## 参照点是包里的 y（不是收端自己的积分结果）⇒ 不问被测对象要。
	var 爬x := 演员.position.x
	var 爬y := 演员.position.y
	## 三段都按真机节流周期 100 毫秒一发、每发**位移与速度自洽**（125 像素/秒 × 0.1 秒 = 12.5 像素），
	## 第三发之后只等两帧就发松手包 —— 这就是本轮按原版 `Sampler.tick` 补的"速度一变当场发"
	## 在真机上的形状（原版 `forceSamplerSend()` 由 `KeyController.as:552/575/769` 在停步那一拍调）。
	## ⚠ 位移必须与间隔自洽。上一版红过一次"第三段等满 100 毫秒却只让真身走 2.5 像素"；
	## 这一版又发现**松手包也得自洽**：真身从上一包到松手那一刻之间确实还在爬，
	## 所以松手包带的 y 必须 = 上一包 y + 速度 × 实际间隔 —— 否则等于"夹具一边让收端
	## 按 125 像素/秒外推、一边说人没动"，量出来的偏离是**尺子自己的错**
	## （上一轮报给用户那个"多冲 14 像素"就是这么来的：14 ≈ 125 × 那 112 毫秒）。
	var 上一包时刻 := Time.get_ticks_msec()
	for 段 in 3:
		爬y -= 12.5
		_对.send_movement(Vector2(爬x, 爬y), 4, Vector2(0.0, -125.0))
		上一包时刻 = Time.get_ticks_msec()
		var 段起 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - 段起 < 100:
			await process_frame
	for 帧 in 2:
		await process_frame
	## 松手那一拍（本轮按原版 `Sampler.tick` 补的"速度一变当场发"就是为了让它立刻出去）
	爬y -= 125.0 * float(Time.get_ticks_msec() - 上一包时刻) / 1000.0
	_对.send_movement(Vector2(爬x, 爬y), 4, Vector2(0.0, 0.0))
	var 停点y := 爬y
	## ⚠ 要量的是**中途冲出去多远再回来**（"还动了一下"看到的是那个凸起），不是最终落点差：
	## 最终差 0.29 像素也可能中间冲了 12 像素再倒回来 ⇒ 必须逐引擎帧取最大偏离。
	var 最大偏离 := 0.0
	## ⭐ 同一个窗口里**顺手采帧号**（e 冻帧尺子）：位置由积分管、腿由 frame_index 管，
	## 两件事发生在同一段时间里，分开跑两次夹具只会让第二条量到"已经停稳之后"的空窗。
	var 蹬了几下 := 0
	var 蹬帧明细: Array[String] = []
	var 上帧号 := -1
	var 帧号采样 := 0
	var 收拢起 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 收拢起 < 1000:
		await process_frame
		最大偏离 = maxf(最大偏离, absf(演员.position.y - 停点y))
		## ⚠ 前 150 毫秒不算：单向传输实测 7~11 毫秒 + 收端下一拍才吃到松手包，
		## 从松手那一帧就要求零变化会把"包还在路上"算成缺陷（那是假红，不是判据）。
		if Time.get_ticks_msec() - 收拢起 >= 150:
			var 号 := int(演员.get_child(0).get("frame_index"))
			if 上帧号 >= 0 and 号 != 上帧号:
				蹬了几下 += 1
				## 变化发生在什么时候、当时那具身体的三个状态各是什么 —— 找解冻者用。
				蹬帧明细.append("%.0f毫秒 帧%d→%d paused=%s 外推在=%s" % [
					float(Time.get_ticks_msec() - 收拢起), 上帧号, 号,
					str(演员.get_child(0).get("paused")),
					str(演员.get_parent().get("_远程外推") is Dictionary
							and (演员.get_parent().get("_远程外推") as Dictionary).has(
								int(演员.get_meta("remote_id", -1))))])
			上帧号 = 号
			帧号采样 += 1
	var 多冲 := absf(演员.position.y - 停点y)
	print("  停手尺子：松手那一包之后 中途最大偏离 %.2f 像素 / 最终差 %.2f 像素（该停在 y=%.1f，实得 %.1f）"
			% [最大偏离, 多冲, 停点y, 演员.position.y])
	## 阈值的来源（不是凑的数）：收端在松手包到达之前**只能按上一包的速度猜**，
	## 猜错的上界就是"一个采样周期的位移" = 125 像素/秒 × 0.1 秒 = **12.5 像素**；
	## 想压到 0 只有一个办法 —— 收端等到包才动，那正是"走一下停一下"（走路那档实测过：
	## 封顶压到 0.1 秒就冻人）。所以这条判的是"别超出一个采样周期"，不是"零误差"。
	## ⚠ 不许随手放宽：修之前实测 **26.6 像素 ≈ 走路那一档的封顶 0.2 秒 × 125** ⇒ 一看就知道
	## 是"爬梯套了走路的窗口"；分档之后 8.77 像素（= 松手包实际晚到约 70 毫秒 × 125）。
	_记(最大偏离 <= 12.5,
			"本端停手后旁观端中途偏离 ≤ 一个采样周期的位移 12.5 像素（实得 %.2f；修前 26.6）"
					% 最大偏离)
	_记(str(演员.get_child(0).get("action")) in ["ladder", "rope"],
			"停在绳上时姿势还挂着爬梯（实得 %s）—— 不许扭成站立"
					% str(演员.get_child(0).get("action")))

	# ── e 冻帧尺子的判据（采样在上面 c 那个 1 秒窗口里已经做完）──────────────
	## 走路停下没这问题：那时动作会从 walk 翻成 stand（`玩家.gd:1078-1086`），
	## 而爬梯停下是**挂在原姿势上**（动作还是 4/5）⇒ 只能靠 `hold_first_frame` 冻帧，
	## 那条一漏，就是用户看到的"我停了、他腿还在蹬几下"。
	print("  冻帧尺子：松手包之后第 150 毫秒起连采 %d 帧，frame_index 变了 %d 次（停在第 %d 帧，动作 %s）"
			% [帧号采样, 蹬了几下, 上帧号, str(演员.get_child(0).get("action"))])
	for 明 in 蹬帧明细:
		print("      · " + 明)
	_记(帧号采样 >= 8, "冻帧这条至少采到 8 帧（实得 %d）—— 采太少这条判据是空的" % 帧号采样)
	_记(蹬了几下 == 0,
			"本端停止攀爬后，旁观端的腿一帧都不许再蹬（实得变了 %d 次）" % 蹬了几下)

	# ── f 发包条件真值表（#232）：**"变脏即发"这条目前没有别的门钉得住** ────────
	## 上面那些尺子喂的是 187（收端），一条都不经过发端这两道闸门 ⇒ 谁把它们改回
	## "每 0.1 秒一发"或"只按位移发"，画面只是迟钝一点，**没有任何一条像素门会红**。
	## 所以这里把条件本身当被测对象，逐格喂真值。参照值全来自原版行号，见 `玩家.gd` 注。
	var 表 := [
		## [动作翻, 速度翻, 位置没变, 距上次秒, 该不该发, 这一格在防什么退化]
		[false, false, false, 0.05, false, "匀速直行一个包都不发（原版 `Sampler.tick` 只认脏标记）—— 改成每帧发就是这条退化"],
		[true, false, true, 0.02, true, "停在原地时动作翻回站立必须发 —— 只按位移发就永远传不出\"停\"，对面看着我原地踏步"],
		[false, true, false, 0.02, true, "原地换向/变速当场发，不等那 0.1 秒（10-15 用户\"还有一丢丢延迟\"那一笔）"],
		[false, false, false, 0.12, true, "一直在走、节流到点也要发 —— 否则对面只收到起步那一包"],
		[false, false, true, 0.50, false, "站着不动不许刷包 —— 加了这条闸门才不会每帧发"],
	]
	for 格 in 表:
		var 实发 := 同步口径.该发位移包(格[0], 格[1], 格[2], 格[3], 0.1)
		_记(实发 == 格[4],
				"发包条件：动作翻=%s 速度翻=%s 位置没变=%s 距上次=%.2f 秒 ⇒ 该发=%s（实得 %s）—— %s"
						% [str(格[0]), str(格[1]), str(格[2]), 格[3], str(格[4]), str(实发), 格[5]])

	# ── d 落地吸附尺子：**旁观端那具身体不许穿到台面以下再被拽回来**（用户 10-15
	## "从别人视角看跳跃，落下像踩在棉花上，还会弹一下"）────────────────
	## 本地那具身体每帧吸附到落脚点（`玩家.gd:1120-1129`），上一版旁观端**只有抛物线
	## 积分、没有吸附** ⇒ 下降末速可到 670 像素/秒、外推封顶 0.2 秒，期望位能穿到台面
	## 下方 160 像素；等"已落地"那一包（y=台面、vy=0）到了再一把拽回来 = 一次回弹。
	var 脚点: Node = 演员.get_parent().get_parent().get_node_or_null("Footholds")
	_记(脚点 != null and 脚点.has_method("find_foothold"),
			"夹具拿得到落脚点表（Footholds）—— 拿不到这条判据就是空的")
	if 脚点 != null:
		var 台x := 演员.position.x
		## 先按"当前位置上方 40 像素"找台面，再把采样点摆到**台面正上方 40 像素**：
		## 这样"不吸附会冲到多远"是确定的（600×0.2 + 0.5×2000×0.04 = 160 像素），
		## 而台面只在 40 像素之下 ⇒ 少了吸附必然越线，不用靠运气。
		var 初查: Dictionary = 脚点.call("find_foothold", 台x, 演员.position.y - 40.0, "")
		var 台面 := float(初查.get("y", INF))
		_记(台面 != INF and 台面 > 演员.position.y - 40.0,
				"这条 x 上真找得到一块台面（实得 %s）—— 查无台面 ⇒ 判据恒真，是假绿" % str(初查.get("y", "无")))
		if 台面 != INF:
			var 采样y := 台面 - 40.0
			_对.send_movement(Vector2(台x, 采样y), 2, Vector2(0.0, 600.0))	## 正往下冲
			var 穿 := 0.0
			var 采起 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - 采起 < 260:
				await process_frame
				穿 = maxf(穿, 演员.position.y - 台面)
			_对.send_movement(Vector2(台x, 台面), 2, Vector2(0.0, 0.0))	## "我已落地"那一包
			var 定起 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - 定起 < 400:
				await process_frame
			print("  落地吸附尺子：下降段穿过台面最多 %.2f 像素（不吸附该穿约 120）/ 落地包之后离台面 %.2f 像素"
					% [穿, 演员.position.y - 台面])
			## 阈值 1 像素：吸附是**硬贴**到台面（`position.y = 地面`），没有"大概对齐"，
			## 所以这里不许有余量；有余量就说明吸附没生效、只剩 30/秒那条收敛在慢慢拽。
			_记(穿 <= 1.0,
					"旁观端下降时不许穿到台面以下（实得穿 %.2f 像素）—— 穿过去再拽回来就是『落到棉花上、还弹一下』"
							% 穿)
			_记(absf(演员.position.y - 台面) <= 1.0,
					"落地那一包到了就稳稳停在台面上（实得差 %.2f 像素）" % absf(演员.position.y - 台面))

	# ── g 移动速度属性 → 走路/攀爬速度（#239，10-15 逐行查实的那条链）──────────
	## 原版：`DataCenter.as:2771-2784` 收 field 21 ⇒ `player.walkSpeedFactor =
	## SkillHandler.getWalkSpeedFactor()`（`:425-441`）= `FightValue.walkSpeedFactor × 减速`
	## = `1.4 × 属性 / 100`（`NumValue.as:25-28`）；
	## `AbstractPhysicObject.as:922` 走路 = `125 × 系数`、**`:600` 攀爬 = `125 × 同一个系数`**。
	## 我们原来把 175 烤进常量 ⇒ 走路恰好等于"属性 100"那个点（看不出错），
	## **攀爬写死 125 ⇒ 比原版慢 28.6%**，且任何加移速的装备/心法/宠物都不生效。
	var 本地玩家 = 场景.get_tree().get_nodes_in_group("player")[0]
	## ⚠ `extends SceneTree` 的脚本里 **autoload 标识符不存在**（直接写 `GameSession` 会在
	## 编译期就 `Identifier not found` ⇒ 整条门一条断言都不跑），必须按节点名去 root 取。
	var 会话件: Node = root.get_node_or_null("GameSession")
	var 属性 := float(会话件.get("player_stats").get("move_speed", 0))
	_记(属性 > 0.0, "服务端真给了移动速度属性（实得 %s）—— 拿不到下面几条全是空的" % str(
			会话件.get("player_stats").get("move_speed", "无")))
	## ① 纯公式真值表（参照值按原版算式自己算，不问被测对象要）
	_记(absf(同步口径.走路速度(100.0) - 175.0) < 0.01,
			"属性 100 ⇒ 走路 175（实得 %.2f）" % 同步口径.走路速度(100.0))
	_记(absf(同步口径.攀爬速度(100.0) - 175.0) < 0.01,
			"属性 100 ⇒ 攀爬 175（实得 %.2f；旧代码写死 125，比原版慢 28.6%%）" % 同步口径.攀爬速度(100.0))
	_记(absf(同步口径.走路速度(200.0) - 350.0) < 0.01,
			"属性翻倍 ⇒ 走路也翻倍（实得 %.2f）—— 加成必须是**线性**吃进去的" % 同步口径.走路速度(200.0))
	_记(absf(同步口径.攀爬速度(150.0) - 同步口径.走路速度(150.0)) < 0.01,
			"同一档属性下攀爬与走路**同速**（原版两者共用 walkSpeedFactor）")
	_记(absf(同步口径.起跳速度() - 666.0) < 0.01,
			"起跳 = 555 × 1.2 = 666（实得 %.2f）—— `jumpSpeedFactor` 原版全树无赋值点，恒取初值"
					% 同步口径.起跳速度())
	## ② 真接线：主角身上的实际值 == 按**服务端实发属性**算出来的值
	if 属性 > 0.0:
		_记(absf(float(本地玩家.get("move_speed")) - 同步口径.走路速度(属性)) < 0.01,
				"本地主角走路速度 == 125×1.4×服务端属性/100（实得 %.2f，该是 %.2f，属性 %d）"
						% [float(本地玩家.get("move_speed")), 同步口径.走路速度(属性), int(属性)])
		_记(absf(float(本地玩家.get("climb_speed")) - 同步口径.攀爬速度(属性)) < 0.01,
				"本地主角攀爬速度 == 走路同一系数（实得 %.2f，该是 %.2f）—— 不再是写死的 125"
						% [float(本地玩家.get("climb_speed")), 同步口径.攀爬速度(属性)])
	## ③ 属性变了要**当场**重算：这条只查"有没有接上 stats_received"，
	##    不自己 emit（emit 等于自演自证）—— 真推送由换装/心法那两条在线用例覆盖。
	var 后端 = root.get_node_or_null("BackendConnection")
	_记(后端 != null and 后端.get_signal_connection_list("stats_received").size() > 0,
			"主角接上了 stats_received（换装/心法改属性时会当场重算走路与攀爬速度）—— 实得连接数 %d"
					% (0 if 后端 == null else 后端.get_signal_connection_list("stats_received").size()))
	## ④ 行为：把属性临时改成 150 再算一次，必须跟着变；**改完原样还原**（不许污染会话）
	var 原属性 = 会话件.get("player_stats").get("move_speed", 100)
	会话件.get("player_stats")["move_speed"] = 150
	本地玩家.call("应用移动速度属性")
	var 提速后 := float(本地玩家.get("move_speed"))
	var 提速后爬 := float(本地玩家.get("climb_speed"))
	会话件.get("player_stats")["move_speed"] = 原属性
	本地玩家.call("应用移动速度属性")
	_记(absf(提速后 - 262.5) < 0.01 and absf(提速后爬 - 262.5) < 0.01,
			"属性 150 ⇒ 走路与攀爬都变 262.5（实得 %.2f / %.2f）—— 加移速的装备从此真的让人变快"
					% [提速后, 提速后爬])
	_记(absf(float(本地玩家.get("move_speed")) - 同步口径.走路速度(float(原属性))) < 0.01,
			"验完把会话还原了（还原后走路 %.2f，该是 %.2f）—— 离线门不许留脏状态"
					% [float(本地玩家.get("move_speed")), 同步口径.走路速度(float(原属性))])

	# ── ⑦ 双修那一拍：我这具浮起来，对面那具必须**跟着同一个 y** ────────────────
	## 参照值 = `CharacterHandler.as:722-760`，原话只有一句 `_loc3_.y = param1.y`（`:754`）：
	## 浮着的那一具把 y **抄给对面那一具** ⇒ 一屏里两个人永远贴在一条水平线上。
	## 而"两具各自的伙伴是谁"靠的是 `1288:1` 那**两条对调帧**（第二条走 `HealHandler.as:315-331`
	## 的 else 支 ⇒ 本工程落在 `后端连接.远程双修伙伴`）。少这一半，`tickHealDouble` 那句
	## `_loc3_.healPartnerId != 0` 永远假 ⇒ 屏幕上只有我一个人浮，另一具站着不动。
	## ⚠ 这条只能在线证：离线门里没有远程节点，而"跟着浮"的全部证据就是那个节点的 y。
	## 代价是这一段固定多花 ~11 秒（原版要坐满 `HEAL_TIME_SIN = 10000` 毫秒才起浮）。
	var 我号 := int(_主.character_id)
	## ★ 先把他**叫到我旁边**再邀 —— 原版发邀那一步有闸：`canRequestDoubleHeal:240`
	## 要 `|Δx| < 40 && |Δy| < 20`，不够近就先 `pathFind` 走过去（`requestToDoubleHeal:388-392`）。
	## 这一步不是走过场：`startHealDouble` 摆的是"**两人中点** ∓ 25"，
	## 两人隔着三百像素时那个中点落在两人中间的空地上，摆完还是各坐各的（10-17 第一次跑就量到 102.5）。
	var 我位 := (本地玩家 as Node2D).position
	_对.send_movement(我位 + Vector2(30.0, 0.0), 3, Vector2.ZERO)
	_记(await _等秒(5.0, func() -> bool:
			return is_instance_valid(演员) and absf(float((演员 as Node2D).position.x) - 我位.x) < 60.0),
			"先把对端挪到我旁边（我 %.1f，他 %.1f）—— 原版发邀前就要求 |Δx| < 40" % [
					我位.x, (演员 as Node2D).position.x if is_instance_valid(演员) else -9999.0])
	_主.request_double_heal_invite(_对编号)
	_记(await _等秒(8.0, func() -> bool:
			return int((_对.get("authoritative_heal") as Dictionary).get("pending_inviter_id", 0)) == 我号),
			"双修邀请路由到对面了（配对的先决）")
	## ⚠ 摆位用的中点必须在**同意之前**取：一收到 state=2，`_process` 里那一拍就把我这具
	## 摆到"中点 ∓ 25"了，之后再来量"摆前"就是拿结果当输入（自证）。
	var 摆前我x := float((本地玩家 as Node2D).position.x)
	var 摆前他x := float((演员 as Node2D).position.x) if is_instance_valid(演员) else 0.0
	var 摆位中点 := (摆前我x + 摆前他x) * 0.5
	var 我在左 := 我号 < _对编号
	_对.request_double_heal_accept(我号)
	_记(await _等秒(8.0, func() -> bool:
			return int((_主.get("authoritative_heal") as Dictionary).get("state", 0)) == 2),
			"对面同意 ⇒ 我这具进双修态（实得 %s）" % str(_主.get("authoritative_heal")))
	_记(await _等秒(6.0, func() -> bool:
			return int((_主.get("远程双修伙伴") as Dictionary).get(_对编号, 0)) == 我号),
			"★ 我这台客户端也知道了「对面那具的伙伴是我」（`远程双修伙伴[%s]`，实得 %s）—— 少了这一条就只有一个人浮" % [
				str(_对编号), str(_主.get("远程双修伙伴"))])
	if is_instance_valid(演员) and 本地玩家 != null:
		(本地玩家 as Object).call("set_practising", true)
		## 先等几帧让"对坐摆位"落定（摆位是 `_process` 里的一次性写 position，
		#  会把 y 也挪到目标 x 所在那一段的地面上）——不隔这几帧，`浮前` 里混的是摆位量，
		## 下面那条"确实动了"的阳性对照就成了自证。
		var 让摆位 := 0
		while 让摆位 < 8:
			await process_frame
			让摆位 += 1
		var 浮前 := float((本地玩家 as Node2D).position.y)
		## 先证明"真的在浮"，再判"两具相等"——不然静止的两具 y 天然相等 = 0 比 0 空判（第十五种）。
		var 起浮了 := await _等秒(14.0, func() -> bool:
				return absf(float((本地玩家 as Node2D).position.y) - 浮前) >= 1.0)
		_记(起浮了, "坐满 10 秒后我这具**确实动了**（起浮前 y=%.2f，现在 %.2f）" % [
				浮前, float((本地玩家 as Node2D).position.y)])
		var 同步对: Array = []
		var 位串: Array = []
		var 最大偏差 := 0.0
		## ★ 镜头那两条**并进同一个采样环**里量，不另开一段：10-17 第一版另开了 24 帧，
		## 那一段正好落在浮动**归零之后** ⇒ 「角色没动 / 锚点没动 / 相机没动」三条一起为 0，
		## 看着全绿其实什么都没判（记忆里第十五种「0 比 0 恒真」）。
		var 相机: Node2D = 场景.find_child("WorldCamera", true, false) as Node2D
		var 锚串: Array = []
		var 相串: Array = []
		var 第几次 := 0
		while 第几次 < 12:
			var 小帧 := 0
			while 小帧 < 8:
				await process_frame
				小帧 += 1
			var 本y := float((本地玩家 as Node2D).position.y)
			var 他y := float((演员 as Node2D).position.y)
			锚串.append(float(((本地玩家 as Object).call("相机锚点") as Vector2).y))
			相串.append(float(相机.global_position.y) if 相机 != null else 本y)
			## ⚠ 采样点取在 `process_frame` 那一刻 ⇒ 读到的是「上一帧 `_process` 抄过去的值」，
			## 而本地这一具在本帧物理里又浮了 1 像素 ⇒ **一帧的落后量**会有 ±1 的零头
			## （10-17 实测十二次里绝大多数逐字节相等、偶尔差 1）。所以这一条判「跟得上」
			## （不跟就是 ±8 的差），「抄的是同一个数」由下面那一发**直接调 `_双修对坐()`
			## 之后逐字节相等**来钉。
			最大偏差 = maxf(最大偏差, absf(本y - 他y))
			同步对.append([本y, 他y])
			位串.append(本y)
			第几次 += 1
		_记(最大偏差 <= 1.0, "★ 十二次采样里对面那具与本具的最大偏差 %.2f 像素（原版 `_loc3_.y = param1.y`；不跟就是 ±8 的差）｜%s" % [
				最大偏差, str(同步对)])
		实体.call("_双修对坐")
		_记(float((演员 as Node2D).position.y) == float((本地玩家 as Node2D).position.y),
				"直接调那一拍同步之后两具 y **逐字节相等**（本地 %.2f / 对面 %.2f）—— 证明抄的是同一个数，不是「差不多」" % [
					float((本地玩家 as Node2D).position.y), float((演员 as Node2D).position.y)])
		# ── ⑦″ 浮动的时候**镜头不许跟着上下动**（用户 2026-10-17 第三条，让我去查原版）────
		## 查到的结论：原版 `Camera.tick()` 走 `gotoFocusObject`（`Camera.as:97-155`），焦点确实是
		## player 本体（`World.as:287` 的 `setFocusObject(this.player)`），读的 y **含**那 ±8 ——
		## 但它外面套了一张 256×256 的死区 `_innerRect`：焦点没走出死区 ⇒ `_rect` 一格都不动
		## ⇒ 屏幕上镜头静止。硬跟那一条 `gotoFocusObjectCenter` 只在出生与改窗口尺寸时各调一次。
		## 我们是每物理帧硬跟，所以由 `玩家.相机锚点()` 显式把偏移摘掉。三条缺一不可：
		## 角色在动（阳性对照）、锚点不动（机制）、相机不动（结果）。
		if 相机 == null:
			_记(false, "场景里找不到 WorldCamera ⇒ 镜头这一条无从测起")
		else:
			var 位跨 := _跨度(位串)
			var 锚跨 := _跨度(锚串)
			var 相跨 := _跨度(相串)
			_记(位跨 >= 1.0, "★ 阳性对照：这十二拍里角色节点自己确实在上下动（y 跨度 %.2f 像素）" % 位跨
					+ "—— 不动的话下面两条就是 0 比 0 空判")
			_记(锚跨 <= 0.01, "★ `相机锚点()` 一动不动（跨度 %.2f，同期位跨 %.2f）" % [锚跨, 位跨]
					+ "—— 浮动的量被摘掉了，相机看到的是真落脚点")
			_记(相跨 <= 0.01, "★★ 镜头真的没跟着上下动（相机 y 跨度 %.2f）—— 用户 10-17 那一条" % 相跨)
		# ── ⑦‴ 姿势与对坐摆位（用户 10-17 两张原版截图：两人**侧身对坐**、中间一张小桌）────
		var 我精灵 = (本地玩家 as Object).get("player_sprite")
		_记(我精灵 != null and String((我精灵 as Node).get("action")) == "sit1",
				"★ 双修时我这具播的是 **sit1**（侧身对坐；`HealHandler.as:415` 的 SIT1）——实得「%s」。"
				% (String((我精灵 as Node).get("action")) if 我精灵 != null else "取不到精灵")
				+ "坐下一律 sit0 = 正面打坐，那就是用户看到的「姿势不对」")
		## ★ 对端那具的位置**不再由我们这侧写**：原版 `startHealDouble` 只写 `_loc2_`（自己），
		## 对面怎么站由**他自己的客户端**摆完随位移帧带过来。10-17 上一版为了凑 50 像素
		## 在本地每帧钉对面 x ⇒ 用户实机看到"另一个角色带着另一个角色走了"。
		## ⇒ 这里照对端客户端的做法，由**对端自己发**他摆位后的坐标（动作号 8 不会被服务端
		## 那道"移动即断坐"误伤：SIT0/SIT1 是原版明写的豁免），顺带把他的朝向一起发过来。
		## ⚠ 起点（摆前我/他、中点、谁在左）在同意**之前**就取好了 —— 见上面那组变量。
		var 他该在左 := _对编号 < 我号
		var 他摆位目标 := 摆位中点 + (-25.0 if 他该在左 else 25.0)
		_记(bool(_对.send_movement(Vector2(他摆位目标, (演员 as Node2D).position.y), 8, Vector2.ZERO,
						1 if 他该在左 else -1)),
				"对端自己发摆位后的坐标 + 动作号 8「sit1」+ 自己的朝向（原版每侧只摆自己）")
		var 他挪到位 := await _等秒(4.0, func() -> bool:
				return is_instance_valid(演员) and absf(float((演员 as Node2D).position.x) - 他摆位目标) <= 1.0)
		_记(他挪到位, "★ 他那具按**自己的包**站到了中点%s 25（目标 %.1f，实得 %.1f）—— 我这侧不写他的 x"
				% ["−" if 他该在左 else "+", 他摆位目标,
					float((演员 as Node2D).position.x) if is_instance_valid(演员) else -9999.0])
		var 我x := float((本地玩家 as Node2D).position.x)
		var 他x := float((演员 as Node2D).position.x)
		_记(absf(我x - (摆位中点 + (-25.0 if 我在左 else 25.0))) <= 1.5,
				"★ 我这具摆到中点%s 25（摆前 我 %.1f / 他 %.1f ⇒ 中点 %.1f，实得 %.1f）—— "
						% ["−" if 我在左 else "+", 摆前我x, 摆前他x, 摆位中点, 我x]
				+ "原版 `HealHandler.as:423/434`｜诊断：%s" % str(实体.get("双修摆位诊断")))
		_记(absf(absf(我x - 他x) - 50.0) <= 1.0,
				"★ 两人摆成 50 像素间距（我 %.1f / 他 %.1f ⇒ 差 %.1f）—— 两边各摆各的、谁也没拖谁"
						% [我x, 他x, absf(我x - 他x)])
		## ★ **对面那一具的 x 归他自己的包**：把他再发到 80 像素外，看我这侧跟不跟。
		## 上一版每帧钉 x 的写法在这里会把节点拽回中点 ±25 ⇒ 这条专门抓那个回归。
		var 他临时x := 他x + 80.0
		_对.send_movement(Vector2(他临时x, (演员 as Node2D).position.y), 8, Vector2.ZERO, 1 if 他该在左 else -1)
		var 他跟过去了 := await _等秒(4.0, func() -> bool:
				return is_instance_valid(演员) and absf(float((演员 as Node2D).position.x) - 他临时x) <= 1.0)
		_记(他跟过去了, "★★ 对面那具的 x 真的是**他自己的包**说了算（发到 %.1f，实得 %.1f）—— "
				% [他临时x, float((演员 as Node2D).position.x) if is_instance_valid(演员) else -9999.0]
				+ "我这侧每帧钉 x 的话，他会一直被拽回中点 ±25（用户 10-17 的「带着另一个角色走了」）")
		## 摆回对坐位，后面朝向/姿势那几条还要用这个位置
		_对.send_movement(Vector2(他摆位目标, (演员 as Node2D).position.y), 8, Vector2.ZERO,
				1 if 他该在左 else -1)
		await _等秒(3.0, func() -> bool:
				return is_instance_valid(演员) and absf(float((演员 as Node2D).position.x) - 他摆位目标) <= 1.0)
		var 他坐好了 := await _等秒(3.0, func() -> bool:
				return is_instance_valid(演员) \
						and String(((演员 as Node2D).get_child(0) as Node).get("action")) == "sit1")
		_记(他坐好了, "★ 远程那一具真的换成了 sit1（实得「%s」）"
				% String(((演员 as Node2D).get_child(0) as Node).get("action")))
		_记((我x < 他x) == 我在左,
				"★ 谁在左由**角色号比大小**定（我号 %d vs 他号 %d ⇒ 该我在左=%s，实得我在左=%s）"
						% [我号, _对编号, str(我在左), str(我x < 他x)])
		_记(int((本地玩家 as Object).get("facing")) == (1 if 我在左 else -1),
				"★ 我这具转身朝向对方（facing=%s，该 %s）" % [
					str((本地玩家 as Object).get("facing")), str(1 if 我在左 else -1)])
		## 角色那一套美术天然**朝右**（`原始动画精灵:120` `左向美术 = kind != "character"`）
		## ⇒ `scale.x > 0` 就是朝右。远程该朝右 ⇔ 他在左边 ⇔ 他号 < 我号。
		## ⚠ 取属性只能走 `.scale.x`：`Node.get("scale.x")` **不解析点号路径**、回 null，
		## 而 `float(null)` 是硬错（`Nonexistent 'float' constructor`）⇒ 10-17 第一次跑就崩在这里。
		var 他皮 := ((演员 as Node2D).get_child(0) as Node2D)
		_记((他皮.scale.x > 0.0) == (_对编号 < 我号),
				"★ 远程那一具也转身朝向对方（他朝右=%s，该 %s；实得 scale.x=%s）" % [
					str(他皮.scale.x > 0.0), str(_对编号 < 我号), str(他皮.scale.x)])
		## ★ **贴图真的换成 sit1 那一张**，不是只把状态机里的动作名改了：
		## `原始动画精灵._apply_frame()` 在 `_get_texture()` 取不到图时**直接 return**、
		## 保留上一张 ⇒ `action == "sit1"` 照样成立（记忆里"逐帧特效只查属性 = 假绿"那一族）。
		var 我图 := String(((本地玩家 as Object).get("player_sprite") as Node)
				.get("sprite").get("texture").resource_path) if \
				(本地玩家 as Object).get("player_sprite") != null else ""
		_记(我图.contains("_sit1"),
				"★★ 我这具**屏幕上那张图**就是 sit1 的贴图（实得「%s」）—— 只查动作名的话，" % 我图
				+ "取不到图时 `_apply_frame` 会留着上一张、动作名照样对")
		## ★ 对面那具**过了 0.45 秒还挂着 sit1**：`_推进远程玩家` 那条"半秒没下一包=真停了"
		## 以前把动作一律改回 1（站立）⇒ 用户 10-17 实机看到的「一个站着一个坐着」就是这里。
		## 坐下的那一端**不再发位移包**（原版"变脏即发"），所以这一等必然走到那条出口。
		var 等挂住 := 0
		while 等挂住 < 90:
			await process_frame
			等挂住 += 1
		_记(String(((演员 as Node2D).get_child(0) as Node).get("action")) == "sit1",
				"★★ 1.5 秒之后远程那一具**还挂在 sit1**（实得「%s」）—— 被改回 stand 就是"
				% String(((演员 as Node2D).get_child(0) as Node).get("action"))
				+ "`_推进远程玩家` 那一列「停下来仍保持原姿势」漏了动作号 8")
		# ── ⑧ 一方走了 ⇒ 双修当场中断，**没走的那一方回到单人打坐**（用户 10-17 第二条）──
		## 真值两条：① 客户端 `HealHandler.tick():171-175` —— `nowInHeal && serverHealState != 0
		## && movementAction ∉ {SIT0, SIT1}` ⇒ **自己发 `requestHealStop`**；
		## ② 服务端把对面那一位改成 **SINGLE(1)** 而不是 STOPPED(0) —— 因为收端 `healStateChange`
		## 收到 1 走 `startHealSingle()` ⇒ `Character.as:2735` 设 **SIT0**（正面打坐），
		## 收到 0 才 `endHeal()` 站起来。用户看到的"没动的角色恢复到单人打坐姿势"就是这一条。
		Input.action_press("ui_right")
		var 我走了 := await _等秒(3.0, func() -> bool:
				return not bool((本地玩家 as Object).get("is_practising")))
		Input.action_release("ui_right")
		_记(我走了, "★ 我按着方向键走一步 ⇒ 本地**自己**退出打坐（原版 tick 那一支）｜诊断：%s"
				% str((本地玩家 as Object).get("打坐打断诊断")))
		## 停坐是**一问一答**：上行 `86:2` → 服务端 `_stop_healing` → 下行 `1288:1:0/1`。
		## 10-17 第一版在这里**没等**就查 ⇒ 读到的还是上一拍的 state=2，看着像服务端没动。
		_记(await _等秒(5.0, func() -> bool:
				return int((_主.get("authoritative_heal") as Dictionary).get("state", -1)) == 0),
				"服务端把我这具改成停坐（实得 %s）" % str(_主.get("authoritative_heal")))
		var 他回单人 := await _等秒(6.0, func() -> bool:
				var 状: Dictionary = _对.get("authoritative_heal") as Dictionary
				return int(状.get("state", 0)) == 1 and int(状.get("partner_id", 0)) == 0)
		_记(他回单人, "★★ 没动的那一方**回到单人打坐**（对面那台 state=1、partner=0，实得 %s）"
				% str(_对.get("authoritative_heal")))
		## ⚠ 这一条**不能**判"我这侧看见他那具换回 sit0"：对端这台是一具**裸后端**，没有 `玩家` 节点，
		## 他的动作号只在他自己那台客户端算好之后随位移帧发过来 ⇒ 他回到单修**不会**变成一个新的
		## 上行帧，我这侧看到的还是最后收到的那个动作号。那是量具的边界，不是产品的洞。
		## 我这侧真能观察到的、也是原版那条 else 支的落点，是 `远程双修伙伴` 被清算掉。
		_记(await _等秒(5.0, func() -> bool:
				return not (_主.get("远程双修伙伴") as Dictionary).has(_对编号)),
				"★ 我这台客户端把「他那具的伙伴是我」清算掉了（`远程双修伙伴` 实得 %s）"
				% str(_主.get("远程双修伙伴")))
		# ── ⑨ 位移帧带上"我自己那一侧的朝向"（10-17 双修"他该朝我、却背对我"的根因）────
		## 以前收端只能"按速度符号推"朝向 ⇒ **站着不动、速度 0 的人永远停在上一次移动的那一侧**。
		## 原版 `Character` 的采样帧里本来就有 `direction` 这一格，收端直接照它转身
		## （`CommandController.as:46-47` 那一段）。
		## 这一发故意做成老算法**推不出来**的样子：位置不动、速度给 0、只有朝向翻成 -1。
		var 他站处 := (演员 as Node2D).position
		_对.send_movement(他站处, 1, Vector2.ZERO, -1)
		var 他转身了 := await _等秒(4.0, func() -> bool:
				return is_instance_valid(演员) \
						and ((演员 as Node2D).get_child(0) as Node2D).scale.x < 0.0)
		_记(他转身了, "★★ 速度为 0、只有朝向翻面 ⇒ 他那具真的转身了（实得 scale.x=%s）—— "
				% str(((演员 as Node2D).get_child(0) as Node2D).scale.x)
				+ "只按速度符号推的那条老算法在这一发下永远推不出来，人就一直背对着")
		# ── ⑩ 离得不够近时**不是拒绝，是先自动走过去再发**（原版 requestToDoubleHeal）────
		## `HealHandler.as:374-395`：`canRequestDoubleNow`（`|Δx|<40 && |Δy|<20` + 自己在站/走
		## + 在地上 + 有落脚点）不成立 ⇒ `nowGotoDoubleHealId = id; API.player.pathFind(x, y)`，
		## 之后每拍由 `tickGotoDoubleHeal:88-116` 复查，够近那一拍才 `requestDoubleHealInvite`。
		## 这条闸不是防作弊，它是**摆位的前提**：隔着一百多像素时"中点 ∓ 25"落在空地上，
		## 两个人各被夹到自己落脚点的端点 ⇒ 看着还是各坐各的。
		_主.request_heal_stop()
		_对.request_heal_stop()
		_记(await _等秒(6.0, func() -> bool:
				return int((_主.get("authoritative_heal") as Dictionary).get("state", -1)) == 0),
				"先把两边停坐清干净，才测得出「点一下到底发了什么」（实得 %s）"
				% str(_主.get("authoritative_heal")))
		var 我站x := float((本地玩家 as Node2D).position.x)
		_对.send_movement(Vector2(我站x + 160.0, float((本地玩家 as Node2D).position.y)), 1, Vector2.ZERO, -1)
		var 他走远了 := await _等秒(6.0, func() -> bool:
				return is_instance_valid(演员) and absf(float((演员 as Node2D).position.x) - 我站x) > 60.0)
		_记(他走远了, "先把对面那具挪到 60 像素之外，让他**够不到**原版那道 40 像素闸（实距 %s）" % (
				str(absf(float((演员 as Node2D).position.x) - 我站x)) if is_instance_valid(演员) else "无演员"))
		_对双修帧.clear()
		var 话 := String(实体.call("请求双修", _对编号))
		_记(话.is_empty(), "够不到闸 ⇒ **不报错、也不说「距离过远」**，而是接下自动赶路（实得「%s」）" % 话)
		_记(bool((本地玩家 as Object).get("click_move_active")),
				"★ 本地真的开始朝他走（`走向` 被叫起来了；实得 click_move_active=%s）"
				% str((本地玩家 as Object).get("click_move_active")))
		_记(await _等秒(14.0, func() -> bool:
				for 帧 in _对双修帧:
					if int(帧.get("action", 0)) == 2 and int(帧.get("pending_inviter_id", 0)) == 我号:
						return true
				return false),
				"★★ 走到 40 像素内那一拍，邀请**真的自己发出去了**（对面收到一条**新的** 1288:2 邀请帧；"
				+ "这一轮共收 %d 条打坐帧，距 %.1f，提示「%s」）" % [
					_对双修帧.size(),
					absf(float((演员 as Node2D).position.x) - float((本地玩家 as Node2D).position.x))
							if is_instance_valid(演员) else -1.0,
					String(实体.get("双修提示"))])
	else:
		_记(false, "拿不到远程演员或本地玩家 ⇒ 上面那步无从测起（远程玩家节点：%s 本地：%s）" % [
				str(演员), str(本地玩家)])
	## ⑫ 打坐那颗「双修」球：真发 1282 ⇒ 服务端真回帧 ⇒ 屏幕上开出成对的两扇
	## 这一条才是「每一项都要真连本地服务端跑通」在这一页的落点。前面 ⑦~⑪ 判的是**地图那一侧**
	## 那条闸，这一段判的是**面板**整条链：球 → `窗口管理.打开或收起("双修")` → 真上行 →
	## 服务端真回 `1282` → 两扇出现（列表里就是服务端看见的那个号）→ 真点一行 →
	## 真点「开始双修」→ 对面收到一条**新的** 1288 邀请帧。
	## ⚠ `root.size` 必须**跑起来之后再设**：在 `_initialize` 那一层设会被启动流程顶回无头
	## 默认的 64×64（10-18 探针实测），那收视口拾取整体失效、「真点」这类判据一条都判不到。
	## ⚠ 拿不到 窗口管理/地图实体 要**明说**，不许静默跳过 ⇒ 否则这一段变成 0 条判据还打「红 0」。
	if 管 == null or 实体 == null:
		_记(false, "⑫ 拿不到 窗口管理 或 地图实体 ⇒ 成对窗这条在线腿整段没跑")
	else:
		root.size = Vector2i(960, 560)
		for 帧 in 3:
			await process_frame
		_记(root.size == Vector2i(960, 560),
				"⑫ 视口落到 %s（停在 64×64 ⇒ 下面每一条「真点」都点不到东西）" % str(root.size))
		var 成对 = load("res://脚本/界面/窗口/双修/双修成对窗.gd")
		成对.关掉(管)
		var 他档: Dictionary = (_主.map_players as Dictionary).get(_对编号, {}) as Dictionary
		_对双修帧.clear()
		管.call("打开或收起", "双修")
		var 开出了 := await _等秒(12.0, func() -> bool: return bool(成对.已开(管)))
		_记(开出了, "★★ 那颗球只发一发 1282 ⇒ 屏幕上什么都没有；**服务端真回了** searchType 4 那一帧，"
				+ "两扇才开出来（原版 `Client.onCharSearchResult:5003-5010` 就是这个次序）")
		if not 开出了:
			_记(false, "⑫ 两扇没开出来 ⇒ 后面三步（列表里有他 / 点行 / 开始双修）整段没测到")
		else:
			var 成对态: Dictionary = 成对.取状态(管)
			var 选人窗: Control = 成对态["选人"] as Control
			var 简介窗: Control = 成对态["简介"] as Control
			_记(简介窗 != null and absf(简介窗.position.x + 280.0 - 选人窗.position.x) <= 1.0
					and absf(简介窗.position.y - 选人窗.position.y) <= 1.0,
					"两扇成对摆着：简介在左、中间 1 像素缝、同一个 y（实得 简 %s 选 %s）"
							% [str(简介窗.position), str(选人窗.position)])
			var 行容 := 选人窗.get_node("行容器") as Control
			var 他的名字 := String(他档.get("name", ""))
			var 行名们: Array = []
			for 子 in 行容.get_children():
				行名们.append(String(((子 as Control).get_node("名") as Label).text))
			var 他的序: int = 行名们.find(他的名字)
			_记(行容.get_child_count() > 0 and 他的序 >= 0,
					"★ 列表里就是**服务端看见的那个号**「%s」（mode 2 走 `visible_peers`），实得 %d 行 %s"
					% [他的名字, 行容.get_child_count(), str(行名们)])
			if 他的序 >= 0:
				var 他那行 := 行容.get_child(他的序) as Control
				var 那级 := String((他那行.get_node("等级") as Label).text)
				_记(int(那级) == int(他档.get("level", -1)),
						"行里的等级 == 162 名册里的等级（行 %s / 名册 %s）" % [那级, str(他档.get("level", -1))])
				_记(not String((他那行.get_node("职业") as Label).text).is_empty(),
						"第 3 列是职业名而不是空（实得「%s」）" % String((他那行.get_node("职业") as Label).text))
				在线点(他那行)
				await process_frame
				_记((选人窗.get_node("选中条") as Control).visible,
						"屏幕上真点那一行 ⇒ 那根共享选中条显示出来（`pressed.emit()` 演不出这一步）")
				_对双修帧.clear()
				## ⚠ GDScript 的 `%` 结合得比 `+` **紧**：`A + B % [三值]` 只把 B 当格式串，
				## B 里只有两个占位符 ⇒ 整条消息原样打出来（本轮日志里那串 `%d` 就是这么来的）。
				## ⇒ 拼接后要**用括号把整条括起来**再 `%`。
				在线点(选人窗.get_node("取消钮"))
				await process_frame
				## ⚠ `双修提示` 要**点完之后**再读：它是 `请求双修` 那一拍写进去的，
				## 点之前读到的是上一轮留下的旧话 ⇒ 拿旧值对新状态，"面板收不收"那条就判错了对象。
				var 提示话 := String(实体.get("双修提示"))
				_记(await _等秒(20.0, func() -> bool:
						for 帧 in _对双修帧:
							if int(帧.get("action", 0)) == 2 and int(帧.get("pending_inviter_id", 0)) == 我号:
								return true
						return false),
						("★★ 「开始双修」真点下去 ⇒ 对面收到一条**新的** 1288 邀请帧（本轮共收 %d 条打坐帧、"
						+ "距 %.1f、提示「%s」）") % [
							_对双修帧.size(),
							absf(float((演员 as Node2D).position.x) - float((本地玩家 as Node2D).position.x))
									if (is_instance_valid(演员) and 本地玩家 != null) else -1.0,
							提示话])
				_记(提示话.is_empty() == (not bool(成对.已开(管))),
						("面板收不收跟着地图那句话走：回空话 ⇒ 收掉、这一单交到底；回一句拒绝 ⇒ 留着让人改选"
						+ "（实得 提示「%s」已开=%s）") % [提示话, str(bool(成对.已开(管)))])
			成对.关掉(管)
	# ── ⑪ 一方**下线/离场** ⇒ 对面必须被放回单人打坐（用户 10-17："点了离开双修还挂着"）──
	## 真值：人一断开，服务端那条会话就没了；原版客户端每具角色随连接走，
	## 不存在"伙伴那具还挂着"这种状态。我们这条会话是服务端复用的 ⇒
	## **服务端必须主动把留下的那位改成 SINGLE**（`leave_world` / `before_map_change` 两处），
	## 否则他永远在双修态：奖励字段不清、`partner_id` 指着空气、再点双修还被"你正在双修"挡住。
	if is_instance_valid(演员) and 本地玩家 != null:
		## ⚠ 先**站稳 + 坐下**再同意：真实客户端收到 state=2 时 `healStateChange` 当场
		## `setMovementAction(SIT1)`，动作号从这一帧起就是 8 —— 服务端新加的"移动即断坐"
		## 兜底判的就是动作号。这条裸玩家没有 `技能面板` 那个消费者，所以要自己坐；
		## 不坐（或还悬空导致 `set_practising` 直接 return）的话，摆位那一拍会发动作号 1
		## ⇒ 被服务端当场判"动了"、双修还没开始就散（本轮实测）。
		_记(await _等秒(5.0, func() -> bool:
				return (bool((本地玩家 as Object).get("on_ground"))
						and not bool((本地玩家 as Object).get("climbing")))),
				"⑪ 先等本地站稳（on_ground=%s climbing=%s）—— `set_practising` 悬空时会直接 return"
						% [str((本地玩家 as Object).get("on_ground")), str((本地玩家 as Object).get("climbing"))])
		(本地玩家 as Object).call("set_practising", true)
		await process_frame
		_记(bool((本地玩家 as Object).get("is_practising")),
				"⑪ 本地坐下了（is_practising=%s）—— 不坐下的话动作号还是 1，双修一起就被服务端判移动"
						% str((本地玩家 as Object).get("is_practising")))
		_对.request_double_heal_accept(我号)
		_记(await _等秒(8.0, func() -> bool:
				return int((_主.get("authoritative_heal") as Dictionary).get("state", 0)) == 2),
				"⑪ 先重新进一次双修（对面有 ⑩ 那发邀请挂着，直接同意；实得 我 %s / 他 %s）"
				% [str(_主.get("authoritative_heal")), str(_对.get("authoritative_heal"))])
		_对.disconnect_backend()
		_记(await _等秒(10.0, func() -> bool:
				var 状: Dictionary = _主.get("authoritative_heal") as Dictionary
				return int(状.get("state", 0)) == 1 and int(状.get("partner_id", 0)) == 0),
				"★★ 对面一下线，我这具**回到单人打坐**（state=1、partner=0，实得 %s）"
				% str(_主.get("authoritative_heal")))
		_记(await _等秒(5.0, func() -> bool:
				return not (_主.get("远程双修伙伴") as Dictionary).has(_对编号)),
				"★ 我这台客户端也把「他那具的伙伴是我」清掉了（`远程双修伙伴` 实得 %s）"
				% str(_主.get("远程双修伙伴")))
	else:
		_记(false, "⑪ 拿不到远程演员或本地玩家 ⇒ 下线清算那步无从测起")
	_主.request_heal_stop()

	_记(场景.get_tree().get_nodes_in_group("player").size() > 0,
			"本方角色在场景里（组 player）—— 连自己都没有就是场景没起来")
	场景.queue_free()
	for 帧 in 3:
		await process_frame
	收拾并退出()


## 一串读数的"跨度" = 最大值 − 最小值。用来判"这一串里到底动没动"。
## 真点击：走视口拾取（两跳移鼠标 + 按下 + 松开），**不用 `pressed.emit()`** ——
## 后者绕过命中测试：摆错位、被别的件压住、disabled 还能点，这三种坏它都测不出来。
## ⚠ 调用前必须把 `root.size` 设对：无头默认 64×64 时拾取整体失效（10-18 探针实测）。
func 在线点(件: Control) -> void:
	var 心: Vector2 = 件.get_global_rect().position + 件.size * 0.5
	for 位在 in [在线鼠位 + (心 - 在线鼠位) * 0.5, 心]:
		var 动 := InputEventMouseMotion.new()
		动.position = 位在
		动.global_position = 位在
		root.push_input(动, true)
	for 按下 in [true, false]:
		var 事 := InputEventMouseButton.new()
		事.button_index = MOUSE_BUTTON_LEFT
		事.pressed = 按下
		事.position = 心
		事.global_position = 心
		root.push_input(事, true)
	在线鼠位 = 心


func _跨度(表: Array) -> float:
	if 表.is_empty():
		return 0.0
	var 小 := float(表[0])
	var 大 := float(表[0])
	for 值 in 表:
		小 = minf(小, float(值))
		大 = maxf(大, float(值))
	return 大 - 小


func 还原端口() -> void:
	if _原端口 < 0:
		return
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		(会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
	_原端口 = -1


func 收拾并退出() -> void:
	if _对 != null and is_instance_valid(_对):
		_对.disconnect_backend()
		_对.free()
	if _主 != null:
		(_主 as Object).disconnect_backend()
	还原端口()
	还原存档()
	if _失败.is_empty():
		print("双人同图在线回归：通过（两个号互相看得见：帧到 → 解出 → 场景建出节点 → 走一步跟着动 四层都真）")
		quit(0)
		return
	print("双人同图在线回归：失败 %d 条 —— %s" % [_失败.size(), " / ".join(_失败)])
	quit(1)
