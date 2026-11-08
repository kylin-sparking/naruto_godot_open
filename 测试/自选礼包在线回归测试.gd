extends SceneTree

## 自选礼包**在线**回归门（2026-10-18，巡检 #21 的在线那一半）。
##
## 病根（离线门照不到的那半）：`ChoiceLibaoWindow` 那一族的结算要客户端把**选了哪一条**
## 用 `{job, index}` 发回去，`index` 是**服务端那份扁平清单的下标**
## （`fake_flash_server.py:49562-49611 _authored_gift_reward_rows`）。这条下标契约只能钉在真服务端上：
##   · 客户端多算/少算一行 ⇒ 玩家点第 3 格领到第 4 条 —— 离线门里两边都是我们自己的代码，
##     它对撞的是"我们的两份实现"，照不到 `2.2.3` 那份；
##   · 报文的第 3 段（原版本是 AMF3 对象）必须**整段以 `{` 开头**才能被
##     `_use_item_request_fields:49791-49814` 还原成一个字段 —— 少一个字节就落回
##     `split(":")`，`fields[2]` 变成 `{"job"`，`json.loads` 抛错 ⇒ 选择被静默丢掉。
##
## 盯五件：
##   ① **不带选择** ⇒ 服务端回原话「请先在自选礼包中选择一件奖励。」
##      （`_use_authored_gift_item:49677-49682`）且**一件不扣**（那句 `return 0`）；
##   ② 客户端候选条数 == 服务端清单条数（`礼包候选` 与 `:49562` 同序同滤）；
##   ③ **逐条走完 5 个下标**：发 `{job:候选.job, index:候选.index}` ⇒ 进包的**正好是
##      候选那一行的 item_id、数量正好是那一行的 count**，其余四条一件不进 —— 这一条
##      就是把"点第 3 格领第 4 条"钉死的地方；
##   ④ 每次成功**只扣一枚**礼包（`consume_count=1`，原版 `__onOkBtnClick` 也不带 useAll）；
##   ⑤ 越界 index / 错 job ⇒ 服务端拒、一件不扣（`:49673-49678` 那四个判据里的两条）。
##
## ⚠ 三条口径：
##   · 种子：`跑在线用例.ps1` 的 `$夹具额外` 用 `--items "11020014:5"` **整张换掉**默认背包
##     （`本地服务端夹具.py:556 grant_items` 按 stack_max 分批，5 件一摞）。缺料 ⇒ 门自己红并说
##     "是夹具没发"，不许含糊成"连不上服务端"；
##   · 端口：客户端只认 `game_settings.backend_port`，缺省 18684 会连到**用户自己那台**、
##     动真存档 ⇒ 这里必须自己指到夹具端口（和 `$夹具额外` 的 `--port` 同一条数字，§3.180）；
##   · 镜像是服务端**推**下来的（`后端连接.gd:4543 → 游戏会话.apply_backend_inventory`），
##     所以每一步都靠 `_等(条件)` 等帧，不 sleep 猜时间；判定一律读 `authoritative_inventory`
##     （服务端那一份），不读客户端本地乐观值。
##   · ⑤ 放在 ③ **之前**跑：那时背包里还有 5 枚礼包，拒没拒才数得出来；③ 吃光之后再试就是空判。
##
## 反向对照（2026-10-18，两条都真跑过、跑完逐条 `cp` 还原并核对字节数 296094/37831）：
##   R4 把 `游戏数据.礼包候选` 的**组内行序**倒过来（`行.duplicate()` + `reverse()`）⇒ 红在 ③ 第一条
##      「选中 index 0（6000063×1）服务端却没发这一条」—— 这正是"点第 1 格领最后一条"；
##      ⚠️ 第一版变异写成 `行.reversed()`，Godot 4 没这个方法 ⇒ **整个 autoload 编译失败**、
##      门连 `_run` 都没进（看门狗 240s 才收掉）—— 红是红了，红的不是契约，所以换了写法重跑；
##   R2 把 `后端连接.request_use_item` 的选择段退回写死 `"-"` ⇒ ① **照样绿**（那句原话本来就归这条）、
##      ② 也绿（条数没错），红在 ③ 第一条 —— 说明这门的牙在"下标真的对得上"那一步，不在"会不会拒"。
##   （离线路那一半的反向对照在 `测试/自选礼包窗回归测试.gd`：去掉脏行跳过 ⇒ 红 3 项。）
##
## 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 自选礼包`

const 礼包 := 11020014			# 轮回技能可选礼包：libao_select，组 "0" 有 5 行、100..400 全空
const 候选行数 := 5				# `数据/礼包奖励.json["11020014"].rewards_by_job["0"]` 实测 5 行
const 夹具端口 := 18720			# 必须与 跑在线用例.ps1 `$夹具额外` 的 --port 同时改
const 提示位 := 512				# `MessagePosition.CHAR_NOTICE`（`UI.as:375-377`）
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

var _红数 := 0
var _原端口 := -1
var _秒 := 0.0
var _文本: PackedStringArray = []
var _backend: Node
var _会话: Node


## 看门狗：这条门的每一步都有 `_等(...)` 兜着，但 `_run` 里**任何一句崩了**（比如
## 变异跑把 `礼包候选` 打挂）就再也走不到 `quit()`，夹具会一直等 Godot 退出 ——
## "崩而不红"比红更难查，所以超时也当失败（240s：夹具启动 ≈50s + 五轮往返各 ≤6s）。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 240.0:
		_红("看门狗超时（240s）—— 中途崩了没走到收尾")
	return false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_backend = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _backend == null or _会话 == null:
		_红("缺单例：BackendConnection=%s GameSession=%s" % [_backend, _会话])
		return
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 夹具端口
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	print("连夹具端口 %d" % 口)
	_backend.chat_received.connect(_收提示)
	_backend.sync_character()
	if not await _等(_进图好了, 15000):
		_红("无法进入真实后端：%s - %s" % [_backend.status, _backend.detail])
		return

	# —— 前置：种子（5 枚礼包一摞）到位没 ——
	if not await _等(_种子好了, 10000):
		_报种子()
		return
	var 格位 := _格(_镜像())
	_查(格位 > 0, "镜像里查不到礼包的 slot_index（格位 %d）" % 格位)

	# —— ② 候选条数 == 服务端清单条数（同一序同一滤才谈得上 index）——
	var 职业 := int(_backend.authoritative_stats.get("job", 0))
	var 候选: Array = 游戏数据.礼包候选(礼包, 职业)
	_查(候选.size() == 候选行数,
			("客户端候选 %d 条 ≠ 服务端应有的 %d 条（职业 %d）—— 序或过滤条件与服务端" +
				"`_authored_gift_reward_rows:49562` 分叉了") % [候选.size(), 候选行数, 职业])
	if 候选.size() != 候选行数:
		_收尾()
		return

	# —— ① 不带选择 ⇒ 原话拒绝、一件不扣 ——
	var 袋前 := _件(_镜像())
	_文本.clear()
	if not bool(_会话.call("use_inventory_slot", 格位)):
		_红("不带选择那发连包都没发出去（在线使用链没接通）")
	if not await _等(_回原话, 5000):
		_红("不带选择时服务端没回原话「请先在自选礼包中选择一件奖励。」（实测提示 %s）"
				% (str(_文本) if not _文本.is_empty() else "一条也没有"))
	_查(_件(_镜像()) == 袋前,
			"没选东西却被扣掉了一枚礼包（服务端那句是 `return 0`，扣件说明选择被判成了合法）")
	_查(_进的件数(候选) == 0, "没选东西却已经有候选进包了")

	# —— ⑤ 越界 index / 错 job ⇒ 拒、不扣（趁 ③ 还没把礼包吃光跑）——
	await _跑拒绝腿(格位, 候选)

	# —— ③④ 逐条下标：点第 n 格 ⇒ 收到的正是第 n 条、其余候选一件不进、只扣一枚礼包 ——
	for 项 in 候选:
		var 序 := int((项 as Dictionary).get("index", -1))
		var 职: int = int((项 as Dictionary).get("job", 0))
		var 号 := _候选号(项)
		var 应发 := int((项 as Dictionary).get("count", 0))
		var 货前 := _镜像件数(号)
		var 包前 := _件(_镜像())
		var 别前 := {}					# 其余候选这一发之前的件数 ——「只发选中那一条」的基线
		for 别 in 候选:
			var 别号 := _候选号(别)
			if 别号 != 号:
				别前[别号] = _镜像件数(别号)
		if not bool(_会话.call("use_inventory_slot", 格位, false, {"job": 职, "index": 序})):
			_红("index %d 那一发没发出去" % 序)
			break
		var 目标 := 货前 + 应发
		if not await _等(func() -> bool: return _镜像件数(号) >= 目标, 6000):
			_红(("选中 index %d（%d×%d）服务端却没发这一条 —— 客户端算出来的下标和服务端清单" +
					"不同序，玩家点第 %d 格领的是别的奖励") % [序, 号, 应发, 序 + 1])
			break
		var 现包 := _件(_镜像())
		if 现包 != 包前 - 1:
			_红("index %d 成功之后礼包从 %d 枚变成 %d 枚（原版一次只吃一枚）" % [序, 包前, 现包])
			break
		var 串门 := 0
		for 别号 in 别前:
			串门 += _镜像件数(int(别号)) - int(别前[别号])
		_查(串门 == 0,
				"index %d 那次除了选中的一条还进来了 %d 件别的候选 —— 自选族只发选中的那一条" % [序, 串门])

	_查(_件(_镜像()) == 0, "5 枚吃完镜像还剩 %d 枚（每轮各扣一枚才对）" % _件(_镜像()))
	_收尾()


## ① 之后、③ 之前跑的拒绝腿（那时候背包里还有 5 枚礼包，拒没拒才数得出来）。
func _跑拒绝腿(格位: int, 候选: Array) -> void:
	var 试法: Array = [
		[{"job": 0, "index": 候选行数 + 3}, "越界 index（%d 条清单给到 %d）" % [候选行数, 候选行数 + 3]],
		[{"job": 700, "index": 0}, "错 job（组 0 的行发 job 700）"],
	]
	for 试 in 试法:
		var 名 := String(试[1])
		var 包前 := _件(_镜像())
		if not bool(_会话.call("use_inventory_slot", 格位, false, 试[0] as Dictionary)):
			_红("%s 那一发没发出去" % 名)
			continue
		if await _等(_发过候选, 1200):
			_红("%s 服务端却发出来候选奖励了（`:49673-49678` 那四个判据漏了一条）" % 名)
		_查(_件(_镜像()) == 包前, "%s 服务端却照扣了礼包（那句应是 `return 0`）" % 名)


func _收提示(m: Dictionary) -> void:
	if int(m.get("positions", 0)) == 提示位:
		_文本.append(String(m.get("message", "")))


func _进图好了() -> bool:
	return bool(_backend.in_game) and not _镜像().is_empty()


func _种子好了() -> bool:
	return _件(_镜像()) >= 候选行数


func _回原话() -> bool:
	return "|".join(_文本).contains("请先在自选礼包中选择一件奖励")


func _发过候选() -> bool:
	var 职业 := int(_backend.authoritative_stats.get("job", 0))
	for 项 in 游戏数据.礼包候选(礼包, 职业):
		if _镜像件数(_候选号(项)) > 0:
			return true
	return false


func _进的件数(候选: Array) -> int:
	## 候选那几件在镜像里一共有几件 —— ①⑤ 用："还一件没发"的时候必须是 0。
	var 总 := 0
	for 项 in 候选:
		总 += _镜像件数(_候选号(项))
	return 总


static func _候选号(项: Variant) -> int:
	return int(String((项 as Dictionary).get("item_id", "0")))


func _镜像() -> Array:
	return _backend.authoritative_inventory as Array


func _镜像件数(item_id: int) -> int:
	return _件数(_镜像(), item_id)


func _件(items: Array) -> int:
	return _件数(items, 礼包)


func _件数(items: Array, item_id: int) -> int:
	var 总 := 0
	for 件v in items:
		if 件v is Dictionary and int((件v as Dictionary).get("id", 0)) == item_id:
			总 += int((件v as Dictionary).get("quantity", 0))
	return 总


func _格(items: Array) -> int:
	var 格 := 0
	for 件v in items:
		if 件v is Dictionary and int((件v as Dictionary).get("id", 0)) == 礼包:
			格 = int((件v as Dictionary).get("slot_index", 0))
	return 格


func _报种子() -> void:
	_红(("夹具没发够礼包：镜像里 %d 只有 %d 枚（要 %d 枚，`--items %d:%d` 那一条；" +
			"现有镜像 %d 格）") % [礼包, _件(_镜像()), 候选行数, 礼包, 候选行数, _镜像().size()])


func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while not bool(条件.call()) and Time.get_ticks_msec() < 止:
		await create_timer(0.05).timeout
	return bool(条件.call())


func _查(过: bool, 文: String) -> void:
	if not 过:
		_红数 += 1
		print("!! " + 文)


func _红(文: String) -> void:
	_查(false, 文)
	_收尾()


func _收尾() -> void:
	if _原端口 >= 0 and _会话 != null:
		(_会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
		_原端口 = -1
	if _backend != null:
		_backend.call("disconnect_backend")
	if _红数 == 0:
		print("自选礼包在线回归测试：通过（不带选择 ⇒ 原话拒绝且不扣件 / 候选条数与服务端清单同序同滤 / "
				+ "5 个下标逐个点中各自那条 / 每轮只扣一枚礼包 / 越界与错 job 都被拒）")
		quit(0)
	else:
		print("自选礼包在线回归测试：失败 %d 项" % _红数)
		quit(1)
