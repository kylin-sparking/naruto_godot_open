extends SceneTree
## 在线腿：挂机**循环**要真连本地服务端跑通（#281 的最后一条腿）。
##
## 页面那三条上行（1283 配置 / 7779 那族飘条 / 1808 起停）已经由
## `测试/副本挂机真实回归测试.gd` 在真服务端上量过；那条量的是**配置存得回去**。
## 这条量的是另一件事：**点了"开始挂机"之后，人真的会自己找怪、真的把怪打死、
## 真的把掉下来的东西捡回背包** —— 而且这三件都是**服务端算的**，不是本地演的。
## 之所以非要这一条：10-18 之前循环只在离线门里跑（`拍()` 由门直接调），
## 出招上行/伤害结算/掉落归属这些只有真服务端才会拒绝我们的地方，一条都没验过。
##
## 用法（端口由夹具给，用例自己从环境变量读，别写死）：
##   python 开发工具/本地服务端夹具.py --root .fixture --port 18712 --gm-http 18713 \
##          --run res://测试/挂机循环在线回归测试.gd --godot <Godot>
##   PowerShell -File 开发工具/跑在线用例.ps1 -用例 挂机循环

## `playable_scene_path()` 在 **`脚本/地图/地图资源.gd:46`**（静态），不在 GameSession 上。
## 写成 `会话.call("playable_scene_path", …)` 会 `Nonexistent function` ⇒ 整条协程静默终止、
## 连结论行都打不出来（10-18 第三次踩这一族）。口径照 `测试/首领在线回归测试.gd:19/92`。
const 地图资源 := preload("res://脚本/地图/地图资源.gd")
## ⚠ 会话写盘是**两份**（`游戏会话.gd:2999` 玩家设置.json + `:3026` 玩家数据.json），
## 而这两份与另一份同名工程**共用同一个 user://**。10-19 实测：本腿只快照了一份，
## 结果 `backend_port=18712` 与临时注册的账号留在了用户自己客户端读的那份里过夜。
const 存档路 := "user://玩家数据.json"
const 设置路 := "user://玩家设置.json"

var _失败: Array[String] = []
var _判数 := 0
var _死怪: Array = []			# 服务端报"这只尸体清掉了"（removed 帧）的怪号
var _击杀: Array = []			# 服务端报"这只被打死了"（monster_killed）的怪号 ← 判据认这一条
var _我方伤害数 := 0			# 服务端算出来的、由**本机**打出的伤害帧数
var _掉新: Array = []			# 服务端掉出来的掉落号
var _掉型 := {}				# 号 → 是不是金币（`is_meso`）：要格子的与不要格子的必须分开数
var _拾回: Array = []			# **我**捡走的那几号（服务端广播的 273 移除帧）
var _未判 := 0					# 这场**没能执行到**的判据条数，必须打在末行里（不许混进"通过"）
var _存档前 := {}				# 路 → 原字节
var _原端口 := -1
var _跑过 := false				# `_结束()` 只许收口一次（多条 return 路上都调它）


func _initialize() -> void:
	call_deferred("_run")


func _判(条件: bool, 说明: String) -> void:
	_判数 += 1
	if not 条件:
		_失败.append(说明)


func _等到(条件: Callable, 毫秒: int) -> bool:
	var 起点 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 起点 < 毫秒:
		if bool(条件.call()):
			return true
		await process_frame
	return bool(条件.call())


## 循环自己发过的那几发 1808（`挂机托管.上行记录`：`{档, 在线, 发出}`）。
## ⚠ **不能**拿 `后端.sent_requests` 当证据口 —— 那是**离线替身**才有的流水，
## 真后端没有这一键（`测试/任务在线回归测试.gd:46` 早就写明过），
## 上一版 `as Array` 每拍报一次 `Invalid cast` 把整条腿刷屏。
func _发过(托管, 档: int) -> bool:
	if 托管 == null:
		return false
	for 条 in (托管.get("上行记录") as Array):
		var 项 := 条 as Dictionary
		if 项 == null:
			continue
		if int(项.get("档", -1)) == 档 and bool(项.get("在线", false)) and bool(项.get("发出", false)):
			return true
	return false


## 原版 `:1074-1081` 把「挂机中」挂到 `API.stage` ⇒ 屏幕层（本工程 = HUD 那枚 CanvasLayer）。
## 找它一律走模块自己的引用：同层里出现第二枚同名时 `add_child` 会把后挂的改名，
## 按节点名找就只剩"永远找到第一枚"（10-19 行为门变异实测漏抓的那条，同一族）。
func _取特效(托管) -> Node:
	return 托管.get("_特效") as Node if 托管 != null else null


func _跑一跑(毫秒: int) -> void:
	## ⚠ 无头**不锁帧**，`await process_frame` 几百毫秒就能烧掉上万帧 ⇒ 空等一定要按墙上时间算
	## （同一族坑本轮已经踩过一次：按 600 帧等玩家 = 实际只等了半秒）。
	var 起点 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 起点 < 毫秒:
		await process_frame


func _run() -> void:
	_存档前 = _快照()
	var 后端 = root.get_node_or_null("BackendConnection")
	var 会话 = root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_失败.append("缺 BackendConnection / GameSession 单例")
		_结束()
		return
	## 客户端连哪个口**只认** `game_settings.backend_port`（`后端连接.gd:705`），环境变量它不读
	## ⇒ 夹具起的是临时口时这一键必须本门自己写、跑完还原（旧坑：拿默认 18684 去连，
	## 顶掉/连到用户自己那台服务端，用例跑到的是他的账号）。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	if 口 > 0:
		设置["backend_port"] = 口
	prints("在线腿：连夹具端口", str(口 if 口 > 0 else _原端口))
	## 证据口要先接上再进图，不然第一波怪死/掉落就漏了。
	## ⚠ "打死"必须认**服务端那条击杀帧** `monster_killed`（`后端连接.gd:3461`），
	## 不是 `monster_removed`（尸体清理，会晚好几秒、这一场甚至不再重发）——
	## 上一版只接了 removed，结果服务端 5 枚掉落都发出来了、击杀计数还是 0（10-19 实测）。
	后端.connect("monster_killed", func(号, 动): _击杀.append(int(号)))
	后端.connect("monster_damaged", func(号, 伤害, 暴, 动画, 自己, 还活):
		if bool(自己):
			_我方伤害数 += 1)
	后端.connect("monster_removed", func(号): _死怪.append(int(号)))
	后端.connect("map_drop_spawned", func(状):
		var 号 := int((状 as Dictionary).get("object_id", 0))
		_掉新.append(号)
		## 记下这一枚**要不要格子**（金币不要）。用户 10-19 报的第二条症状正是
		## "要格子的物品一枚都不进、只有金币进" ⇒ 不分这一档就永远照不出来。
		_掉型[号] = bool((状 as Dictionary).get("is_meso", false)))
	后端.connect("map_drop_removed", func(号, 画, 角, 宠):
		if int(角) == int(后端.get("character_id")): _拾回.append(int(号)))
	后端.call("sync_character")
	if not await _等到(func(): return bool(后端.get("in_game")), 20000):
		_失败.append("没能进游戏：%s - %s" % [后端.get("status"), 后端.get("detail")])
		_结束()
		return
	## ⚠ `--script` 起的 Godot **不会自动加载主场景** ⇒ 光登录成功，场景里根本没有人
	## （第一次跑就红在"40 秒没建出玩家"，等多久都没用）。照本工程既有在线腿的做法
	## （`测试/首领在线回归测试.gd:90-100`）：自己把**运行时真正加载的那份烘焙场景**装起来。
	var 地图路 := 地图资源.playable_scene_path(str(会话.get("current_map_id")))
	var 打包 = load(地图路) as PackedScene
	_判(打包 != null, "加载不到烘焙地图场景：%s" % 地图路)
	if 打包 == null:
		_结束()
		return
	var 图: Node = 打包.instantiate()
	root.add_child(图)
	current_scene = 图
	## 按**墙上时间**等（无头不锁帧，按帧数等几百毫秒就烧完了）
	var 玩家 = null
	if await _等到(func(): return not get_nodes_in_group("player").is_empty(), 40000):
		玩家 = get_nodes_in_group("player")[0]
	_判(玩家 != null, "装好场景后 40 秒还没建出玩家")
	if 玩家 == null:
		_结束()
		return
	var 托管 = (玩家 as Node).get_node_or_null("挂机托管")
	_判(托管 != null, "玩家下面没有 挂机托管（在线这一路没挂上实现体）")
	if 托管 == null:
		_结束()
		return
	## 开局前提：图里得有服务端发下来的活怪（不然"打死了"永远是 0 比 0）
	var 实体 = (玩家 as Node).get_parent().get_node_or_null("LifeRoot")
	_判(实体 != null, "没有 LifeRoot")
	if 实体 == null:
		_结束()
		return
	if not await _等到(func(): return (实体.call("挂机的全部怪") as Array).size() > 0, 15000):
		_失败.append("服务端 15 秒内一只怪都没发过来 ⇒ 这条腿没东西可打")
		_结束()
		return
	_prints_怪(实体, 玩家, "开局")
	_判(not bool((会话.get("hang_state") as Dictionary).get("active", true)),
			"用例开始前不该已经在挂机")

	# ── ① 点开始 ⇒ 1808:0 真的发出去了，而且循环真的在跑 ──────────────
	会话.call("request_hang", true)
	_判(bool(托管.get("在跑")), "会话广播之后循环的 `在跑` 没立起来")
	_判(await _等到(func(): return _发过(托管, 0), 8000), "点开始 8 秒内没把 1808:0 发到服务端")
	_判(await _等到(func(): return (会话.get("hang_state") as Dictionary).get("active", false) \
			and int(托管.get("_帧")) > 0, 8000), "8 秒里循环一帧都没走（预热 800ms 之后该动了）")
	## ★ 这一条是本轮事故的正主：10-18 之前挑中怪之后循环**只出手一次**就再也不动
	## （`_追击` 一面旗举到底 ⇒ 空闲大块再也没进过）。原版的"还在打这只"是
	## `toAttackAnemy`，每帧由 `SkillExecute.moveToAttack()` 重算，本工程对成玩家手里的追打命令。
	_判(await _等到(func(): return (玩家 as Node).get("自动接近目标") != null, 15000),
			"15 秒里没把任何一只怪交给追打 ⇒ 挂机根本没在打（实得 目标=%s 追击=%s）" % [
				str(托管.get("目标")), str(托管.get("_追击"))])
	## 开挂那一刻屏幕中央那枚"挂机中"（原版 `GuajiHandler:1074-1081` `API.stage.addChild`，
	## x = 舞台宽/2、y = 110）在线上也得真挂出来 —— ④ 那句"停完不许还看得见"才不是空判。
	var 挂中 = _取特效(托管) as Node
	_判(挂中 != null and (挂中 as CanvasItem).visible,
			"开挂后屏幕层要有那枚『挂机中』（它是 HUD 那一层的子节点，不是玩家子节点）；实得 %s" % str(挂中))

	# ── ② 真的打死一只**服务端认的**怪 ────────────────────────────────
	# 判据不能用"本地看到血条空了"：那可以是本地演的。只认服务端那条击杀帧。
	# ⚠ 也不能只等 `monster_removed`：那是**尸体清理**，比击杀帧晚好几秒、这一场还可能不再发
	# （10-19 实测：服务端 5 枚掉落都发出来了、本地也真捡走一枚，removed 却是 0）。
	# 窗口给到 150 秒：这张烘焙图出生点附近只有两三只怪，打完要等刷新。
	var 到 := await _等到(func(): return _击杀.size() > 0, 150000)
	if not 到:
		_prints_怪(实体, 玩家, "150 秒后")
		prints("循环内部：在跑=%s 帧=%s 状态=%s 目标=%s 活动区=%s 我=%s 寻路中=%s 追击=%s" % [
			str(托管.get("在跑")), str(托管.get("_帧")), str(托管.get("状态文字")),
			str((托管.get("目标") as Object).name if (托管.get("目标") is Node) else 托管.get("目标")),
			str(托管.get("_活动区")), str((玩家 as Node2D).position),
			str(实体.call("玩家是否在寻路") if 实体.has_method("玩家是否在寻路") else "?"),
			str(托管.get("_追击"))])
	_判(到 and _击杀.size() > 0,
			"挂机 150 秒里服务端一只怪都没让死（击杀帧 %d、尸体清理帧 %d、我方伤害帧 %d）⇒ 挑怪/走位/出招这一串在真服务端上没跑通" % [
				_击杀.size(), _死怪.size(), _我方伤害数])
	prints("在线腿：服务端击杀帧 =", str(_击杀), "｜我方伤害帧 =", str(_我方伤害数),
			"｜尸体清理 =", str(_死怪), "｜掉新 =", str(_掉新), "｜我捡走 =", str(_拾回))
	## 比"打死"更早的一格证据：服务端**算出了由本机打出的伤害**。
	## 这图上怪稀（出生点附近两三只，打完要等刷新），所以万一 150 秒没等到击杀帧，
	## 这一条还能说清"出手有没有真送到服务端"——两者红法不一样，别并成一条。
	_判(_我方伤害数 > 0, "服务端一帧『我方造成伤害』都没算出来 ⇒ 挂机打出的招根本没进服务端结算")

	# ── ③ 打死的怪要掉东西，而且挂机把它捡回背包、**地上那一枚要没掉** ──────────
	# 掉落是概率，所以这一段**不许直接判 >0**；但"一场都没掉"= 这一腿零覆盖，
	# 必须自己把 `未判` 说出口并打进末行 —— 以前那句 `_掉新.is_empty() or …` 就是
	# 拿 `or` 把"没判过"混进"通过"（§第十四/十五种：0 比 0 恒真），连着两轮 掉新=[] 都没人吭声。
	if _掉新.is_empty():
		await _跑一跑(30000)
	if _掉新.is_empty():
		_未判 += 1
		prints("未判 1：服务端这一场一枚掉落都没出 ⇒ 『掉出来 → 挂机说要捡 → 地上那枚消失』整条腿没被执行到")
	else:
		_判(_拾回.size() > 0,
				"掉出来的东西一个都没捡走（掉 %d 枚、捡 %d 枚）⇒ 拾取那条支线在线上是死的" % [_掉新.size(), _拾回.size()])
		## 用户 10-19 报的正主：『挂机自动拾取之后，物品竟然还在地面上』。
		## 判的是**挂机自己点名要捡的那些枚**最后有没有从 `LifeRoot._server_drops` 里消失 ——
		## 光数 273 帧到没到照不出"到了但没落到地上那一枚"（客户端那条链由
		## `开发工具/量拾取移除.gd` 13 条单独钉）。留 3 秒宽限：拾取动画本身要 600 毫秒。
		await _跑一跑(3000)
		var 地上: Dictionary = (实体.get("_server_drops") as Dictionary) if 实体 != null else {}
		var 没走: Array = []
		for 号 in (托管.get("拾取发过") as Array):
			if 地上.has(int(号)):
				没走.append(int(号))
		_判(没走.is_empty(),
				"挂机发过拾取请求的掉落里，这些枚**还躺在地上**：%s（发过 %s 枚、273 回了 %s 枚）" % [
					str(没走), str((托管.get("拾取发过") as Array).size()), str(_拾回.size())])
		prints("在线腿：掉=%s｜挂机发过拾取=%s｜273 我捡走=%s｜还躺在地上=%s" % [
			str(_掉新), str(托管.get("拾取发过")), str(_拾回), str(没走)])
		## 没被点名的那几枚要说清"为什么不捡"，不然下一次又要靠猜（0=不该要 1=捡得动 2=要先走过去）
		var 还在: Array = []
		for 掉 in (实体.call("挂机的掉落", Rect2(-1000000.0, -1000000.0, 2000000.0, 2000000.0)) as Array):
			还在.append({"号": int((掉 as Dictionary).get("object_id", 0)),
					"物品": String((掉 as Dictionary).get("item_id", "")),
					"类": int(托管.call("该不该捡", 掉))})
		prints("在线腿：挂机眼中场上还剩 %s（类：1=捡得动 2=要走过去 0=按勾选不该要）；会去捡=%s" % [
			str(还在), str(bool(托管.call("会去捡")))])
		## 用户 10-19 报的第二条正主：**要格子的物品一枚都不进背包，只有金币进**。
		## 上一版只判"一枚都没捡走"⇒ 金币进了就把这一条顶绿了，非金币全丢也不红。
		## 掉落是概率 ⇒ "这一场压根没掉过非金币"要自己说成 `未判`，不许混进通过（§十四/十五种）。
		var 非金币: Array = []
		for 号 in _掉新:
			if not bool(_掉型.get(int(号), false)):
				非金币.append(int(号))
		if 非金币.is_empty():
			_未判 += 1
			prints("未判 1：这一场只掉了金币（共 %d 枚，要格子的物品 0 枚）⇒ 『非金币掉落被捡回背包』这一条没被执行到" % _掉新.size())
		else:
			var 没进: Array = []
			for 号 in 非金币:
				if not _拾回.has(号):
					没进.append(号)
			_判(没进.size() < 非金币.size(),
					"掉了 %d 枚**要格子的物品**、挂机一枚都没捡回（这一场金币进了 %d 枚）"
							% [非金币.size(), _掉新.size() - 非金币.size()]
					+ " ⇒ 用户报的『地面这么多东西都不拾取，只拾取了金币』；没捡回的号 %s，场上还剩 %s" % [str(没进), str(还在)])
			prints("在线腿：非金币掉 %s｜没进背包 %s｜有空槽=%s｜服务端格数=%s｜我的角色号=%s" % [
				str(非金币), str(没进), str(bool(托管.call("_有空槽"))),
				str(托管.get("_会话").call("背包总格数")), str(后端.get("character_id"))])

	# ── ④ 停 ⇒ 1808:1 发出去、循环停、特效摘掉 ────────────────────────
	会话.call("request_hang", false)
	_判(not bool(托管.get("在跑")), "点了停止，循环的 `在跑` 还立着")
	_判(_发过(托管, 1), "停挂机没把 1808:1 发到服务端（原版 `:1053` `requestHang_stopHang()`）")
	var 特效 = _取特效(托管) as Node
	## ⚠ 先断言"这一路真挂过特效节点"，再断"停完不许还看得见" ——
	## 只写后半句的话，节点没建成也照样绿（0 比 0，10-17 那条口径的第三次踩）。
	_判(特效 != null, "停完之后特效节点应该还在（只是不许可见）；实得 null ⇒ 开挂那一路根本没建过它")
	_判(特效 == null or not (特效 as CanvasItem).visible,
			"停完『挂机中』特效还挂着（原版 `:1083-:1086` 是 removeChild，我们等价地收 visible）")

	_结束()


func _prints_怪(实体, 玩: Node, 标签: String) -> void:
	var 我: Vector2 = (玩 as Node2D).global_position
	var 行: Array = []
	for 怪 in (实体.call("挂机的全部怪") as Array):
		if not is_instance_valid(怪):
			continue
		var 位: Vector2 = (怪 as Node2D).global_position
		行.append("%s@%.0f,%.0f(距离%.0f 层%s)" % [
			str((怪 as Node).get("display_name")), 位.x, 位.y, 我.distance_to(位),
			str(实体.call("怪的层号", 怪))])
	prints("【%s】服务端怪 %d 只：%s" % [标签, 行.size(), " | ".join(行)])


func _结束() -> void:
	if _跑过:
		return
	_跑过 = true
	## 收口三件事：① 会话**内存里**那套 game_settings 换回快照那份 ② 两份 user:// 文件按字节还原
	## ③ 结论与退出码。
	## ⚠ 顺序要紧：只还原文件不够 —— `quit()` 之前任何一处 `_save_local_state()` 都会把
	## 内存里的临时值再写回去（10-19 实测：`backend_port=18712` 与临时注册的账号就是这么
	## 留在了用户自己客户端读的那份存档里过夜，连本腿**根本没快照**的 `玩家设置.json` 也一起脏了）。
	var 会 = root.get_node_or_null("GameSession")
	if 会 != null:
		var 原字节: PackedByteArray = _存档前.get(存档路, PackedByteArray())
		if not 原字节.is_empty():
			var 解 = JSON.parse_string(原字节.get_string_from_utf8())
			if 解 is Dictionary and (解 as Dictionary).has("game_settings"):
				var 旧: Dictionary = (解 as Dictionary)["game_settings"]
				var 设置: Dictionary = 会.get("game_settings")
				设置.clear()
				for 键名 in 旧:
					设置[键名] = 旧[键名]
	_还原存档(_存档前)
	if _失败.is_empty():
		## 未判必须打进末行：读日志的人只看末行，`通过` 后面不跟这一句就会把"零覆盖"当成"过了"。
		prints("挂机循环在线回归测试：通过（%d 条判据，未判 %d 条%s）" % [_判数, _未判,
				"" if _未判 == 0 else " ⇒ 拾取那一条腿这场没被执行到，不算验过"])
		quit(0)
		return
	for 条 in _失败:
		prints("红：" + 条)
	prints("挂机循环在线回归测试：%d 条判据，红 %d 条，未判 %d 条" % [_判数, _失败.size(), _未判])
	quit(1)


func _快照() -> Dictionary:
	## 一份文件一段原字节；不存在 ⇒ 空字节，还原时**删掉**本腿新建的那份。
	var 出 := {}
	for 路 in [存档路, 设置路]:
		出[路] = FileAccess.get_file_as_bytes(路) if FileAccess.file_exists(路) else PackedByteArray()
	return 出


func _还原存档(快照: Dictionary) -> void:
	for 路 in 快照:
		var 字节: PackedByteArray = 快照[路]
		if 字节.is_empty():
			if FileAccess.file_exists(路):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(路))
			continue
		var f := FileAccess.open(路, FileAccess.WRITE)
		if f != null:
			f.store_buffer(字节)
			f.close()
