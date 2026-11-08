extends SceneTree

## 八门「开通穴道」的**在线**端到端：点开通 ⇒ 服务端起倒计时 ⇒ 到点结算 ⇒ 穴位数 +1。
##
## 为什么单开一条：离线门只能钉到"包发得出去"（`§3.162` 那条链），
## 而玩家真正看到的反馈是**服务端那两帧**：
##   · `1290:1:<角色号>:<秒>:<true|false>`（延迟引爆/倒计时，原版 `actionMaiDelayExplode`）
##   · `1290:2:<list_id>:<mai_id>:<该门已开穴位数>`（结果帧，成功失败都发）
## 2026-10-16 用户报"点完只剩一句等待服务端"就是**客户端没认第 1 帧**（§3.180）。
##
## ③ 是**失败腿**（§3.207）：夹具服务端原来把 `succeeded` 写死 `True`、还在概率上偷偷 `+20`
##   ⇒ 掷骰那一支和 `八门穴位开通失败。` 那句全是死代码。现在它按真表掷骰，这条腿才钉得住：
##   夹具用 `--mai-opened 1:17` 把门 1 预置成"只差一枚 10% 的翳风"，连点 8 次 ⇒
##   一次都不失败的先验 `0.1^8 = 1e-8`，所以这条腿**必然**能抓到失败那一发。
##
## 跑法：由 `开发工具/跑在线用例.ps1 -用例 八门开通` 调（夹具给独立端口 18708/18709）。

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 门序 := 0			# 开门
const 第一枚 := 0		# 客户端点序的第 0 枚（服务端要求按顺序开通，所以只能是它）
const 等帧秒 := 12.0	# 服务端的引爆延迟 + 余量
const 门1 := 1
const 门1预置 := 17		# 夹具 `--mai-opened 1:17`；下一枚＝翳风 prob 10（`数据/经脉.json` 门1 pts[17]）
const 门1总枚 := 21
const 失败腿次 := 8
const 提示隔秒 := 1.7	# `_send_character_notice` 对**同一句话**有 1.5 秒去重（`:40429-40431`）
const 失败文案 := "八门穴位开通失败。"

var _后端
var _帧: Array = []		# 收到的每条 1290（种/状态）
var _提示: Array = []		# 落到提示口子的文本（512 拒绝句 + 右下角获得提示）
var _聊: Array = []		# chat_received 的每一条，用来查那条的 positions 真是 512
var _倒计时数 := 0			# `八门倒计时` 发过几次 = **真**倒计时帧到了几次
var _失败: Array[String] = []
var _收好了 := false
var _原端口 := -1
var 存档路 := "user://玩家数据.json"
var 存档前 := PackedByteArray()
var 本来有存档 := false


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


## 兜底：`_跑` 里任何一条 script error 都会让它**直接中断**（不 return、不 quit）⇒ Godot 进程挂着不走，
## 夹具就一直等 ⇒ 整条在线流水线挂死（§3.204 记过这一族）。本门加了 ③ 失败腿之后最长能跑到两三分钟，
## 更该有个出口。5 分钟没落到汇总就按红退出，至少日志能拿到。
func _看门狗() -> void:
	await create_timer(300.0).timeout
	if _收好了:
		return
	printerr("八门开通在线回归测试：看门狗超时（300s）—— 中途崩了没走到汇总")
	quit(1)


func 拍快照() -> void:
	var 读 := FileAccess.open(存档路, FileAccess.READ)
	if 读 == null:
		本来有存档 = false
		return
	本来有存档 = true
	存档前 = 读.get_buffer(读.get_length())


func 还原端口() -> void:
	if _原端口 >= 0:
		var 会话 := root.get_node_or_null("GameSession")
		if 会话 != null:
			(会话.get("game_settings") as Dictionary)["backend_port"] = _原端口


func 还原存档() -> void:
	if 本来有存档:
		var 写 := FileAccess.open(存档路, FileAccess.WRITE)
		if 写 != null:
			写.store_buffer(存档前)
			写.close()
		var 读 := FileAccess.open(存档路, FileAccess.READ)
		var 现 := 读.get_buffer(读.get_length()) if 读 != null else PackedByteArray()
		_记(现.size() == 存档前.size(), "跑完把 %s **按字节还原**了（跑前 %d 字节）" % [存档路, 存档前.size()])
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
		_记(not FileAccess.file_exists(存档路), "跑前没有存档 ⇒ 跑完也不该留下")


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
	_后端 = root.get_node_or_null("BackendConnection")
	if _后端 == null:
		_fail("缺少后端连接单例")
		return
	_后端.cultivation_received.connect(func(种: String, 状: Dictionary) -> void:
		if 种 == "八门":
			_帧.append(状.duplicate(true)))
	# ⚠️ 判"这一发有没有起倒计时"**只能数 `八门倒计时` 那根信号**，不能查状态字典里有没有
	#    `countdown_seconds` —— 那个键被 merge 进了权威字典、**此后的每一帧都还带着它**
	#    （`后端连接._handle_cultivation_text` 是 `state.duplicate(true)` 发出来的）。
	if _后端.has_signal("八门倒计时"):
		_后端.八门倒计时.connect(func(_秒: int) -> void: _倒计时数 += 1)
	_后端.chat_received.connect(func(件: Dictionary) -> void: _聊.append(件))
	if _后端.has_signal("获得提示"):
		_后端.获得提示.connect(func(文: String) -> void: _提示.append(文))
	# 服务端那句 512 拒绝是经 `_通知` → 会话的 `notification_requested` 落到提示口子的
	# （原来这里接的 `系统消息` **这根信号在 `后端连接.gd` 里根本没有**，`has_signal` 恒 false
	#   ⇒ 那个收集器是个从没收到过任何东西的摆设，本门的拒绝判据等于没接）。
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null and 会话.has_signal("notification_requested"):
		会话.notification_requested.connect(func(文: String) -> void: _提示.append(文))
	# ⚠️ **必须自己把端口指到夹具**：客户端只认 `game_settings.backend_port`（缺省 18684 ⇒
	#    会连到用户自己那台）—— 本门第一次跑就因此连错了机器（那一轮的数据其实不是夹具的）。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18708
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	print("连夹具端口 %d" % 口)

	_后端.sync_character()
	if not await _等秒(12.0, func() -> bool: return bool(_后端.in_game)):
		_fail("进不了游戏：%s - %s" % [_后端.status, _后端.detail])
		return

	# 先要一条统计帧，看服务端认为开门开了几枚
	_帧.clear()
	_后端.request_bamen(1)
	if not await _等秒(5.0, func() -> bool: return not _帧.is_empty()):
		_fail("服务端没回八门统计帧（1290:3）")
		return
	var 统计: Dictionary = _帧[-1]
	var 开前 := int((统计.get("exploded", {}) as Dictionary).get(门序, 0))
	print("  开门已开 %d 枚（服务端统计帧）" % 开前)

	# 点开通：门 0 / 客户端点序第 0 枚 / 不带灵符
	_帧.clear()
	_提示.clear()
	if not _后端.request_bamen(2, 门序, 第一枚, 0):
		_fail("开通请求没发出去")
		return

	# ① 立刻该来一条**倒计时帧**（§3.180 的判据：客户端原来把它当祝福值吞了）
	if not await _等秒(5.0, func() -> bool: return not _帧.is_empty()):
		_fail("服务端对开通没回任何帧（提示：%s）" % str(_提示))
		return
	# ⚠️ 判据是"**其中有一条**是倒计时帧"，不是"第一条" —— 上一发统计请求的回包可能先落地
	#    （本门第一版就写成了"第一条"，于是被自己的统计回包判红，白跑一轮）。
	var 倒计帧: Dictionary = {}
	for f in _帧:
		if (f as Dictionary).has("countdown_seconds"):
			倒计帧 = f
			break
	_记(not 倒计帧.is_empty(),
		"开通后应当收到**倒计时帧**（`1290:1`，含 countdown_seconds），实收 %s（提示：%s）"
			% [str(_帧.map(func(f): return f.keys())), str(_提示)])
	if not 倒计帧.is_empty():
		_记(int(倒计帧.get("countdown_seconds", 0)) > 0,
			"倒计时秒数应当 > 0，实为 %s" % 倒计帧.get("countdown_seconds"))

	# ② 倒计时到点后再**问一次统计**（＝客户端重开窗那一下；服务端会在处理这条请求时先结算到点的开通）
	#    ⚠️ 这一问**必不可少**：服务端的到点结算原来只在"进游戏/切图"触发，
	#    原地开完穴道没人引爆 ⇒ 永远等不到结果（本门第一次跑就是这么红的）。
	await create_timer(minf(等帧秒, 11.0)).timeout
	_后端.request_bamen(1)
	var 到点 := await _等秒(等帧秒, func() -> bool:
		return int((_帧[-1].get("exploded", {}) as Dictionary).get(门序, 0)) > 开前)
	var 开后 := int((_帧[-1].get("exploded", {}) as Dictionary).get(门序, 0))
	_记(到点, "倒计时结束、服务端结算后，开门已开数应当从 %d 涨上去（实为 %d；帧序 %s；提示 %s）"
		% [开前, 开后, str(_帧.map(func(f): return f.keys())), str(_提示)])

	await _跑失败腿()

	还原端口()
	还原存档()
	_收尾()


## 查服务端认为某门已开几枚（从最新一帧往回找带这枚键的 `exploded`）。没找到给 -1。
func _门已开(门: int) -> int:
	for i in range(_帧.size() - 1, -1, -1):
		var 爆: Dictionary = (_帧[i] as Dictionary).get("exploded", {})
		if 爆.has(门):
			return int(爆[门])
	return -1


func _有失败句() -> bool:
	return _提示.find(失败文案) >= 0


## ③ **失败腿**：服务端掷骰输了应当「当场回一句、不开穴、不起倒计时」，且**不进账**。
##   门 1 被夹具预置成 17 枚 ⇒ 下一枚翳风 10%；连点 8 次，一次不失败的先验 1e-8。
##   ⚠️ 每次之间要隔 `提示隔秒`：`_send_character_notice:40429-40431` 对**同一句话**去重 1.5 秒，
##      贴着装的话第二次的拒绝句会被服务端自己吞掉 —— 那是服务端的行为，不是客户端丢了。
func _跑失败腿() -> void:
	_帧.clear()
	_后端.request_bamen(1)
	if not await _等秒(5.0, func() -> bool: return _门已开(门1) >= 0):
		_fail("失败腿：服务端统计帧里没有门 1 的已开数（1290:3 的 exploded 少了这个键）")
		return
	var 预置 := _门已开(门1)
	_记(预置 == 门1预置,
		"失败腿前提：夹具 `--mai-opened 1:%d` 应当让门 1 已开 %d 枚，实为 %d（预置没落地这条腿就没料，判红）"
			% [门1预置, 门1预置, 预置])
	if 预置 != 门1预置:
		return
	var 起 := 预置
	var 成 := 0
	var 败 := 0
	for 第 in range(失败腿次):
		var 当前 := _门已开(门1)
		if 当前 >= 门1总枚:
			print("  · 门 1 已开满 %d 枚，失败腿剩下几次没有 10%% 的料可点，收手" % 门1总枚)
			break
		_帧.clear()
		_聊.clear()
		_提示.clear()
		var 倒计前 := _倒计时数
		if not _后端.request_bamen(2, 门1, 当前, 0):
			_fail("失败腿第 %d 次：开通请求没发出去" % (第 + 1))
			return
		# 成与败**在服务端是同一条返回路径上分岔的**：掷骰赢 ⇒ 起 `1290:1` 倒计时（10 秒后才结算），
		# 输 ⇒ 当场 `512 那句 + 1290:2 结果帧`、没有倒计时。所以先等这两者之一出现。
		if not await _等秒(6.0, func() -> bool: return _倒计时数 > 倒计前 or _有失败句()):
			_fail("失败腿第 %d 次：既没起倒计时也没见失败句（帧 %s / 提示 %s / chat %s）"
				% [第 + 1, str(_帧.map(func(f): return f.keys())), str(_提示), str(_聊)])
			return
		if _倒计时数 > 倒计前:
			# 掷骰赢：等过那 10 秒引爆，再问一次统计把结果帧要回来。
			# ⚠️ 必须等它结算完才能装下一发，否则下一发会被「八门穴道正在倒计时」拒 ——
			#    那句也会回一发 `1290:2`，长得跟失败一模一样，会被这条腿记成"失败"、把账算错。
			await create_timer(等帧秒).timeout
			_帧.clear()
			_后端.request_bamen(1)
			if not await _等秒(6.0, func() -> bool: return _门已开(门1) == 当前 + 1):
				_fail("失败腿第 %d 次起了倒计时（判定成功），但结算后门 1 已开数没从 %d 变 %d（实为 %d）"
					% [第 + 1, 当前, 当前 + 1, _门已开(门1)])
				return
			成 += 1
			continue
		败 += 1
		_记(_倒计时数 == 倒计前,
			"失败那一发不该起倒计时帧（第 %d 次：提示 %s）" % [第 + 1, str(_提示)])
		_记(_门已开(门1) == 当前,
			"失败那一发的结果帧里门 1 已开数**不该动**：期望 %d，实为 %d（帧 %s）"
				% [当前, _门已开(门1), str(_帧.map(func(f): return f.keys()))])
		var 那件: Dictionary = {}
		for 件 in _聊:
			if String((件 as Dictionary).get("message", "")) == 失败文案:
				那件 = 件
		_记(int(那件.get("positions", -1)) == 512,
			"服务端那句「%s」必须走 CHAT 的 CHAR_NOTICE(512)，实得帧 %s（本次 chat 全量 %s）"
				% [失败文案, str(那件), str(_聊)])
		await create_timer(提示隔秒).timeout
	_记(败 > 0,
		"%d 次 10%% 的开通里应当**至少一次当场失败**（成 %d、败 %d；一次不失败的先验 0.1^%d = 1e-8）"
			% [失败腿次, 成, 败, 失败腿次])
	_记(_门已开(门1) == 起 + 成,
		"门 1 已开数的增量应当**等于成功次数**（起 %d、成 %d、败 %d、终 %d）"
			% [起, 成, 败, _门已开(门1)])


func _fail(文: String) -> void:
	_失败.append(文)
	printerr("  !! " + 文)
	还原端口()
	还原存档()
	_收尾()


func _收尾() -> void:
	_收好了 = true
	if _失败.is_empty():
		print("八门开通在线回归测试：通过（统计帧 / 倒计时帧 / 到点结算已开数 +1 / 失败腿：无倒计时、不动账、512 那句、增量==成功数）")
		quit(0)
		return
	for 项 in _失败:
		printerr("八门开通在线回归测试：" + 项)
	print("八门开通在线回归测试：失败 %d 条" % _失败.size())
	quit(1)
