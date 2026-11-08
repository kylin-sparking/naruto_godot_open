extends SceneTree
## 交易族（119 上行 / 335 下行）的**在线端到端**门（#244，2026-10-16）。
##
## 为什么必须有这一道：`#224` 那轮把这一族接完时只建了**离线门** —— 离线门喂的是
## `数据/界面/交易夹具.json` 里那批**原文串**（由 `开发工具/出交易夹具.py` 反查服务端源码生成），
## 它只证明"喂这么一条我会画对"，**照不到服务端到底发不发那一发、发给谁**。
## 用户 10-12 的铁律：每一项"做完"= 点它有请求 + 服务端回帧 + 画面有变化。
##
## 这条门跑的真链（每一步都判三件事：帧发得出去 ⇒ 对面收得到 ⇒ 我方屏幕上那格画出来）：
##   主号 `119:2:<对端号>` 邀请  ⇒ 对端收 `335:3:<主号>:<主名>`（只进托盘，**不开窗**）
##   对端 `119:4:<主号>` 接受    ⇒ 双方各收 `335:22` ⇒ 主号这边**交易窗真开出来**
##   主号 出价金币 ⇒ 主 `my_money` + 主屏幕上「我的金币值」 + **对端** `other_money`（跨号）
##   对端 出价元宝 ⇒ 主 `other_cash` + 主屏幕上「对方元宝值」
##   主号 放一件背包物品 ⇒ 主 `my_items[1]` + 屏幕上那一格的名字
##   双方各点锁定 ⇒ 两块遮罩都亮 ⇒ 屏幕上「交易」钮从 disable 变可点
##   主号 取消 ⇒ 双方 `335:9:0` ⇒ 窗关掉、状态回空
##
## ⚠ 三条口径（都是这工程踩过的）：
##   · **参照值不许问被测对象要**：金币/元宝的参照是**夹具给服务端的预置数**（`MAIN_MONEY` 那一份）
##     与**对面那条连接**收到的快照，不是主号自己算出来的；
##   · 两个号都登录 ⇒ `user://玩家数据.json` 会被写 ⇒ 按字节快照 + 还原 + 断言；
##   · 出价**必须过服务端钳位**（`:23851/23861` 对已锁定的号直接 return、`:23866` 钳到身上钱）
##     ⇒ 这条门故意在"锁定之前"出价，锁定之后那两支另用断言钉"再发也不动"。
##
## 跑法：`PowerShell -NoFile ... -File 开发工具\跑在线用例.ps1 -用例 交易在线`
## （2026-10-23 才挂号，同 §3.255 那一族「门写好了没人跑」。
##   夹具给独立端口 18740/18741、第二个账号 `naruto/123456` 与角色号 `NW_SOCIAL_PEER_ID`、
##   主号背包 `--items 3000001:5`）

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 管理场景 := "res://场景/界面/窗口管理.tscn"
const PEER_ACCOUNT := "naruto"
const PEER_PASSWORD := "123456"
## 夹具 `--items` 给主号的那件：**拉面（小）×5**。
## ⚠ 第一版用的是 `10000001 熊皮`，服务端回的是「绑定物品不能交易。」—— 不是它认错件：
## `_item_can_leave_owner:47084-47089` 除 `can_trade` 外还挡 `definition.section == "RenWuWuPin"`
## （熊皮在物品表里 `category=任务物品 / source_category=RenWuWuPin`）⇒ **任务物品按原版就是不能交易**。
## 换 03000001 拉面（小）（`XiaoHao` 区、stack_max 9999）才走得通这一支。
const 主号物品 := 3000001
const 出价金币 := 500
const 出价元宝 := 300
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 存档路 := "user://玩家数据.json"
const 服务端文件 := "res://服务端/runtime/tools/fake_flash_server.py"

var _主: Node = null
var _对: Node = null
var _管理: Node = null
var _对编号 := 0
var _原端口 := -1
var _失败: Array = []
var _跑完 := false
var 存档前 := PackedByteArray()
var 本来有存档 := false


func _initialize() -> void:
	call_deferred("_跑")


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


func 还原端口() -> void:
	if _原端口 >= 0:
		var 会 = root.get_node_or_null("GameSession")
		if 会 != null:
			(会.get("game_settings") as Dictionary)["backend_port"] = _原端口


func 页现取():
	if _管理 == null:
		return null
	var 窗 = _管理.call("取窗口", "交易")
	if 窗 == null:
		return null
	var 内容 = 窗.get("_content")
	if 内容 == null:
		return null
	for 子 in (内容 as Node).get_children():
		if String(子.name) == "原版交易内容":
			return 子
	return null


func 窗开着() -> bool:
	if _管理 == null:
		return false
	var 窗 = _管理.call("取窗口", "交易")
	return 窗 != null and bool(窗.call("已打开"))


func 格位(表, 编号: int) -> int:
	for 件 in 表:
		if 件 is Dictionary and int((件 as Dictionary).get("id", 0)) == 编号:
			return int((件 as Dictionary).get("slot_index", 0))
	return 0


func _收邀(数据: Dictionary) -> void:
	_邀请档.append(数据.duplicate(true))


var _邀请档: Array = []
var _自邀档: Array = []
var _提示档: Array = []


## 临时诊断：把服务端发给主号的**文本提示**全收下 —— 邀请那支成功后服务端会紧跟一条
## 「交易申请已发送。」（`:23803`），收到 = 服务端那半走通了、问题在投递给对端；
## 没收到 = `handle_player_interaction` 那支根本没跑到（hub/target 为空）。
func _收提示(文: String) -> void:
	_提示档.append(文)


## 服务端那句「绑定物品不能交易。」走的是 `CHAT_MESSAGE`（`_send_dynamic_info:40123`），
## 不是 opcode 65 ⇒ 要判"放不进去到底被哪一道闸挡的"必须把聊天那路也接上。
func _收聊(件: Dictionary) -> void:
	_提示档.append("聊天:" + str(件.get("text", 件)))


func _收自邀(数据: Dictionary) -> void:
	_自邀档.append(数据.duplicate(true))


func _跑() -> void:
	拍快照()
	_主 = root.get_node_or_null("BackendConnection")
	var 会话 = root.get_node_or_null("GameSession")
	if _主 == null or 会话 == null:
		printerr("交易在线：缺 BackendConnection / GameSession 单例")
		quit(1)
		return
	## 服务端那三处拼串源没改（改了这条门的段序参照就作废 ⇒ 先钉住）
	var 源 := FileAccess.get_file_as_string(服务端文件)
	_记(源.contains("PLAYER_INTERACTION = 119") or 源.contains("PLAYER_INTERACTION: 119"),
			"服务端 ClientOpcode.PLAYER_INTERACTION 还是 119")
	_记(源.contains("def invite_trade"), "服务端 `invite_trade` 那支还在（撤了 ⇒ 邀请永远石沉大海）")
	_记(源.contains("trade.offered_money"), "服务端出价金币那支还在写 `offered_money`")

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18740
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_对编号 = int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	print("连夹具端口 %d；对面那个号 = %d（账号 %s）" % [口, _对编号, PEER_ACCOUNT])
	if _对编号 <= 0:
		printerr("交易在线：夹具没给 NW_SOCIAL_PEER_ID ⇒ 没有第二个号，本门无从判起")
		还原端口()
		quit(1)
		return

	_主.sync_character()
	if not await _等秒(20.0, func() -> bool: return bool(_主.in_game)):
		printerr("交易在线：主号进不了游戏（%s - %s）" % [_主.status, _主.detail])
		收拾并退出()
		return
	var 我号 := int(_主.character_id)
	## ⚠ 自己的名字取**会话**那份（`player_stats.name`，`后端连接.gd:1698` 组队伍名单也是读它）——
	## `authoritative_stats` 是服务端**属性帧**灌出来的，那张表里没有 name，读它恒为空串，
	## 于是"邀请帧带的名字"那条会拿空串去比 ⇒ 变成一条谁都不会红的对照。
	var 我名 := String((会话.get("player_stats") as Dictionary).get("name", ""))
	_记(我名 != "", "主号自己的名字取到了「%s」（取不到 ⇒ 下面那条名字对照就是空的）" % 我名)
	## 窗口管理**先建**：它是 `trade_started` 那四条信号的消费者（`窗口管理.gd:80-87`），
	## 不建它就等于"帧到了但没人画" ⇒ 只能证明半条链。
	_管理 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(_管理)
	await create_timer(0.4).timeout

	_对 = BACKEND_SCRIPT.new()
	_对.name = "交易在线对面那个号"
	root.add_child(_对)
	## ⚠ 邀请帧是发给**被邀请的那一端**的（服务端 `:23801-23804` 只 `target.send_text`），
	## 所以监听必须接在 `_对` 上 —— 第一版接在 `_主` 上，`_邀请档` 永远是空数组，
	## 于是后面整条链全部连带红（16 条），看着像"交易链坏了"，其实是量具接错了一端。
	_对.connect("trade_invite_received", Callable(self, "_收邀"))
	_主.connect("trade_invite_received", Callable(self, "_收自邀"))
	_主.connect("server_message_received", Callable(self, "_收提示"))
	_主.connect("chat_received", Callable(self, "_收聊"))
	_对.connect_backend(PEER_ACCOUNT, PEER_PASSWORD, false)
	if not await _等秒(10.0, func() -> bool: return bool(_对.authenticated)):
		printerr("交易在线：第二个号登录不上（夹具里有没有 %s 这个账号？）" % PEER_ACCOUNT)
		收拾并退出()
		return
	if not bool(_对.select_character(_对编号)):
		printerr("交易在线：第二个号选不上角色 %d" % _对编号)
		收拾并退出()
		return
	if not await _等秒(20.0, func() -> bool: return bool(_对.in_game) and int(_对.character_id) == _对编号):
		printerr("交易在线：第二个号进不了游戏（%s - %s）" % [_对.status, _对.detail])
		收拾并退出()
		return
	await _等秒(6.0, func() -> bool: return (_对.authoritative_stats as Dictionary).has("maxHp"))
	var 对名 := String((_对.get("authoritative_stats") as Dictionary).get("name", ""))
	_记(对名 != "", "对面那条连接的档案名 = 「%s」（下面拿它当参照值）" % 对名)

	# ── ① 邀请：只进**对端**托盘，两边都不开窗 ─────────────────────
	_邀请档.clear()
	_自邀档.clear()
	print("两个号的实际角色号：主号=%d 对端=%d（夹具给的 NW_SOCIAL_PEER_ID=%d）"
			% [int(_主.character_id), int(_对.character_id), _对编号])
	_记(int(_主.character_id) != int(_对.character_id),
			"两个号**不是同一个角色号**（同号 ⇒ 服务端 `sessions_by_character` 会互相顶掉，邀请等于发给自己）")
	print("主号开始发 `119:2:<对端号>`（下面带重发，原因见注释）")
	## ⚠ **必须重发**：服务端 `enter_game()` 是先 `_send_all_stats()`（客户端看到这条就把
	## `in_game` 置真、本门就往下走），**之后**才 `hub.enter_world(self)`
	## （`fake_flash_server.py:14230` ⇒ 9739 那支才把会话登记进 `sessions_by_character`）。
	## 所以"刚进图的那一瞬"发邀请，`session_for_character(对端号)` 还是 None ⇒
	## `:23801` 那支静默 return，一个字节都不回（实测：第一次发出去 = 对端永远收不到）。
	## 人手点邀请总比这一瞬晚得多 ⇒ 这是**门撞上的时序**，不是玩家会遇到的坏；
	## 但"哪一帧之后才登记上"这条口径要留在 §⑬·7，别下次又当成服务端 bug 去改服务端。
	var 第几次 := 0
	var 到了 := false
	while 第几次 < 12 and not 到了:
		第几次 += 1
		_邀请档.clear()
		_主.request_trade_invite(_对编号)
		到了 = await _等秒(1.5, func() -> bool: return _邀请档.size() > 0)
		if not 到了:
			await create_timer(0.5).timeout
	_记(到了, "对端收到 `335:3`（发了 %d 次才到 ⇒ 第 %d 次之后服务端已登记完会话）"
			% [第几次, 第几次])
	_记(_自邀档.is_empty(), "发邀请的自己**不该**收到邀请帧（实得 %s）" % str(_自邀档))
	if not _邀请档.is_empty():
		var 邀: Dictionary = _邀请档[0] as Dictionary
		_记(int(邀.get("id", 0)) == 我号 and String(邀.get("name", "")) == 我名,
				"那条邀请带的是**主号的号与名**（实得 %s，期望 id=%d name=「%s」）" % [邀, 我号, 我名])
	_记(页现取() == null, "只收到邀请时**不许开窗**（原版 `Client.as:6391-6398` 只 addMsg 进托盘）")

	# ── ② 对面接受 ⇒ 双方 335:22 ⇒ 主号这扇窗真开出来 ───────────────
	_记(bool(_对.request_trade_accept(我号)), "对端发出 `119:4:<主号>`")
	_记(await _等秒(8.0, func() -> bool: return bool((_主.get("authoritative_trade") as Dictionary).get("active", false))),
			"主号收到 `335:22` ⇒ 状态 active=true")
	_记(await _等秒(8.0, func() -> bool: return 页现取() != null),
			"主号屏幕上**交易窗真的开出来了**（`窗口管理._on_trade_started` 那条路走通了）")
	var 态: Dictionary = _主.get("authoritative_trade")
	_记(String(态.get("other_name", "")) == 对名 and int(态.get("other_id", 0)) == _对编号,
			"窗上那个「对方名」= 帧里另一侧的号与名（实得 id=%s 名=「%s」，期望 %d「%s」）"
					% [str(态.get("other_id", 0)), String(态.get("other_name", "")), _对编号, 对名])
	if 页现取() != null:
		_记(String((_页件("对方名") as Label).text) == 对名,
				"屏幕上「对方名」那一格画的就是对端名字（实得「%s」）" % String((_页件("对方名") as Label).text))

	# ──  出价金币：主号 ⇒ 主号屏 + 对端状态（跨号）────────────────
	_记(bool(_主.request_trade_offer_money(出价金币)), "主号发出 `119:15:%d`" % 出价金币)
	_记(await _等秒(8.0, func() -> bool: return int((_主.get("authoritative_trade") as Dictionary).get("my_money", -1)) == 出价金币),
			"主号这边 `my_money` = %d（实得 %s）" % [出价金币, str((_主.get("authoritative_trade") as Dictionary).get("my_money", "无"))])
	_记(await _等秒(8.0, func() -> bool: return int((_对.get("authoritative_trade") as Dictionary).get("other_money", -1)) == 出价金币),
			"**对端**收到的快照里「对方金币」= %d ⇒ 服务端真把这一发推给了对面（实得 %s）"
					% [出价金币, str((_对.get("authoritative_trade") as Dictionary).get("other_money", "无"))])
	if 页现取() != null:
		_记(String((_页件("我的金币值") as Label).text) == str(出价金币),
				"屏幕上「我的金币值」画出来就是 %d（实得「%s」）"
						% [出价金币, String((_页件("我的金币值") as Label).text)])

	# ── ④ 主号出价元宝 ⇒ 主号屏 + 对端状态 ─────────────────────────
	## ⚠ 这一发**只能由主号出**：服务端 `:23851` 把元宝钳到 `store.state.cash_money`，
	## 而夹具只给**主号**种过货币（`seed_currency(gm, main_id)` ⇒ 对端那份是 0）
	## ⇒ 对端出 300 被钳成 0（第一版就是这么红的，不是链坏）。
	## 对端 → 主号那条数据腿由 ⑥ 的「对端锁定 ⇒ 主号那半遮罩显」覆盖，不靠出价那两发。
	_记(bool(_主.request_trade_offer_cash(出价元宝)), "主号发出 `119:13:%d`" % 出价元宝)
	_记(await _等秒(8.0, func() -> bool: return int((_主.get("authoritative_trade") as Dictionary).get("my_cash", -1)) == 出价元宝),
			"主号这边「我的元宝」= %d（实得 %s）" % [出价元宝, str((_主.get("authoritative_trade") as Dictionary).get("my_cash", "无"))])
	_记(await _等秒(8.0, func() -> bool: return int((_对.get("authoritative_trade") as Dictionary).get("other_cash", -1)) == 出价元宝),
			"**对端**看到的「对方元宝」= %d（实得 %s）" % [出价元宝, str((_对.get("authoritative_trade") as Dictionary).get("other_cash", "无"))])
	if 页现取() != null:
		_记(String((_页件("我的元宝值") as Label).text) == str(出价元宝),
				"屏幕上「我的元宝值」画出来就是 %d（实得「%s」）"
						% [出价元宝, String((_页件("我的元宝值") as Label).text)])

	# ── ⑤ 放一件真背包物品 ⇒ 服务端回 `335:5` ⇒ 那一格有名字 ────────
	await _等秒(8.0, func() -> bool: return (_主.get("authoritative_inventory") as Array).size() > 0)
	var 槽 := 格位(_主.get("authoritative_inventory"), 主号物品)
	_记(槽 > 0, "主号背包里找得到 %d（夹具 `--items` 发的那件；实得格位 %d）" % [主号物品, 槽])
	if 槽 > 0:
		_提示档.clear()
		_记(bool(_主.request_trade_put_item(槽, 1)), "主号发出 `119:14:%d:1`" % 槽)
		var 放进 := await _等秒(8.0, func() -> bool: return not ((_主.get("authoritative_trade") as Dictionary).get("my_items", {}) as Dictionary).is_empty())
		if not 放进:
			print("诊断：放物失败时主号收到的提示 = ", _提示档)
		_记(放进, "`335:5` 回来 ⇒ 我这侧那一格有东西了（实得 %s）"
				% str(((_主.get("authoritative_trade") as Dictionary).get("my_items", {}) as Dictionary).keys()))
		await create_timer(0.4).timeout
		if 页现取() != null:
			var 那一格 = _页件("我的格1")
			_记(String(那一格.名字.text) == 游戏数据.item_name(主号物品),
					"屏幕上第 1 格画出的就是那件物品名（实得「%s」，期望「%s」）"
							% [String(那一格.名字.text), 游戏数据.item_name(主号物品)])

	# ── ⑥ 单方锁定 ⇒ **对面立刻亮"对面"那半**；双方锁完 ⇒「交易」钮可点 ──
	_记(bool(_主.request_trade_lock()), "主号发出 `119:9`")
	## ⚠ 10-17 更正：这一节以前判的是"单边锁定对面**收不到**任何东西"，理由写的是
	## 「服务端只在两人都锁完时才发 `335:7`」—— 那是拿**我们自己写的那份服务端**当原版作证。
	## 回 AS3 数：`335:7` 的 handler 一个字节都不读（`TradeProcessor.as:238-244`），
	## 收到只做 `TradeWindow2.lockTrade():583-587` 的 `otherMaskPane.visible = true`
	## ⇒ 它是**"对面刚锁定"的单方事件**；自己那半从来不走这条帧（`onLockedBtn:445` 本地亮）。
	## 服务端已改成"谁锁定就只发给对面那一个"。用户 10-16 实机报的第一条就是这个。
	## ⚠ 压时间**必须用 await**（`_等秒` 里是 `create_timer` 等待，主循环照跑、网络照读）；
	## 写忙等 `while ...: pass` 会把主循环卡死 ⇒ 那一帧永远读不到东西 ⇒ 假绿。
	_记(await _等秒(8.0, func() -> bool: return bool((_对.get("authoritative_trade") as Dictionary).get("other_locked", false))),
			"只有一边锁 ⇒ 对面**立刻**收到 `335:7`、点亮'对面'那半（实得 %s）"
					% str((_对.get("authoritative_trade") as Dictionary).get("other_locked", "无")))
	_记(not bool((_对.get("authoritative_trade") as Dictionary).get("my_locked", false)),
			"`335:7` 不许替对端把**他自己**那半也锁上（实得 my_locked=%s）"
					% str((_对.get("authoritative_trade") as Dictionary).get("my_locked", "无")))
	_记(bool((_主.get("authoritative_trade") as Dictionary).get("my_locked", false)),
			"主号自己那半是点锁定时本地置的，不靠回帧（实得 %s）"
					% str((_主.get("authoritative_trade") as Dictionary).get("my_locked", "无")))
	_记(not bool((_主.get("authoritative_trade") as Dictionary).get("other_locked", false)),
			"此时主号还没收到对面那条 ⇒ '对面'那半不该亮（实得 %s）"
					% str((_主.get("authoritative_trade") as Dictionary).get("other_locked", "无")))
	_记(bool(_对.request_trade_lock()), "对端发出 `119:9`")
	_记(await _等秒(8.0, func() -> bool: return bool((_主.get("authoritative_trade") as Dictionary).get("other_locked", false))),
			"主号收到 `335:7` ⇒ 两块遮罩都亮")
	await create_timer(0.4).timeout
	if 页现取() != null:
		_记((_页件("我的遮罩") as Control).visible and (_页件("对方遮罩") as Control).visible,
				"屏幕上两块红遮罩都显出来了")
		_记((_页件("交易钮") as Button).disabled == false,
				"两块都亮 ⇒「交易」钮 enable（`setTradeBtnEnabled:131-137`）")
		## 锁定之后再出价，服务端 `:23851/23861` 那两支会直接 return ⇒ 数**不许**变。
		_主.request_trade_offer_money(出价金币 + 700)
		await create_timer(0.8).timeout
		_记(int((_主.get("authoritative_trade") as Dictionary).get("my_money", -1)) == 出价金币,
				"锁定完再出价 ⇒ 服务端挡掉、数不变（实得 %s，期望 %d）"
						% [str((_主.get("authoritative_trade") as Dictionary).get("my_money", "无")), 出价金币])

	# ── ⑦ 取消 ⇒ 双方 335:9:0 ⇒ 窗关掉、状态回空 ───────────────────
	_记(bool(_主.request_trade_exit()), "主号发出 `119:10`")
	_记(await _等秒(8.0, func() -> bool: return not 窗开着()),
			"`335:9:0` ⇒ 主号那扇窗**由下行关掉**（不是在点击处 close ⇒ 对面那扇才关得掉）")
	_记(await _等秒(8.0, func() -> bool: return not bool((_对.get("authoritative_trade") as Dictionary).get("active", true))),
			"对面那扇也跟着关了（对端状态 active=false）")
	_记(bool((_主.get("authoritative_trade") as Dictionary).get("active", true)) == false,
			"主号状态回到空（`removeData` 的等价物）")

	# ──  X 关闭钮 = 取消 ⇒ 两侧都关 + **取消之后还邀得动**（用户 10-16 报的第二、三条）──
	## 原版 `TradeWindow2.onCloseBtnClick:123-129` 派发的就是 `CANCEL_TRADE` ⇒ X 与「取消」
	## 是同一条 `119:10`。本工程窗壳的 X 以前只连 `close()`（本地 `_overlay.visible=false`）
	## ⇒ 服务端那笔交易还挂在 `trades_by_character` 里：对面那扇永远开着（第二条报障），
	## 而且再点交易被 `invite_trade:10229-10236` 的"已在交易中"**静默**挡掉（第三条报障）。
	## ⇒ 这一节先重开一笔（重开成功本身就是"状态清干净了"的证据），再用**真鼠标**点 X。
	_邀请档.clear()
	var 第几次2 := 0
	var 到了2 := false
	while 第几次2 < 12 and not 到了2:
		第几次2 += 1
		_邀请档.clear()
		_主.request_trade_invite(_对编号)
		到了2 = await _等秒(1.5, func() -> bool: return _邀请档.size() > 0)
		if not 到了2:
			await create_timer(0.5).timeout
	_记(到了2, "取消之后**重新邀请，对端还收得到 `335:3`**（发了 %d 次；一直收不到 = 服务端还挂着旧交易）" % 第几次2)
	_记(bool(_对.request_trade_accept(我号)), "对端再接受一次 `119:4`")
	_记(await _等秒(8.0, func() -> bool: return 页现取() != null), "主号这扇窗又开出来了")
	if 页现取() != null:
		root.size = Vector2i(960, 560)		# ⚠ 不钉视口，无头 push_input 拿不到 GUI 命中
		var 窗 = _管理.call("取窗口", "交易")
		var 关钮 = (窗 as Node).get("_close_button") as Button
		_记(关钮 != null, "取到窗壳那枚 X 关闭钮（取不到 ⇒ 下面两条是 0 比 0 的假绿）")
		if 关钮 != null:
			await _点真(关钮)		# ⚠ 先走**真鼠标**（不是 `emit_signal("pressed")`，那等于自己演给自己看）
			print("（诊断）真鼠标点 X 之后：已打开=", 窗.call("已打开"),
					" X 屏幕矩形=", 关钮.get_global_rect(), " 视口=", root.size,
					" 这一点上悬停到的件=", str((root as Viewport).gui_get_hovered_control()))
			if bool(窗.call("已打开")):
				## 真鼠标没落到 X 上 ⇒ 把原因打出来，再退一步只验"这条上行到不到服务端"。
				## 连线本身由**离线门 ㉒**（`挂数 == 1`）钉住，这里不重复判连线、只判回路。
				print("（诊断）真鼠标这一下没命中 X ⇒ 改走 pressed 信号验上行；"
						+ "命中失败本身要单独查（层序/摆位），别让这条绿把它盖掉")
				关钮.pressed.emit()
			_记(await _等秒(8.0, func() -> bool: return not 窗开着()),
					"点 X ⇒ 主号这扇由下行关掉")
			_记(await _等秒(8.0, func() -> bool: return not bool((_对.get("authoritative_trade") as Dictionary).get("active", true))),
					"X 那条上行到位 ⇒ **对面那扇也收到 `335:9:0`**（不发 119:10 就是用户报的「另一侧还开着」）")

	收拾并退出()


## 真鼠标点一下某个件。口径与离线门一致：先发 motion、按下要带 `button_mask`、
## `position` 与 `global_position` 都要写，坐标必须是**屏幕坐标**（走 `get_global_rect()`）。
func _点真(件: Control) -> void:
	var 屏: Vector2 = 件.get_global_rect().position + 件.size * 0.5
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	root.push_input(移)
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	root.push_input(按)
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	root.push_input(放)
	await process_frame
	await process_frame


func _页件(名: String):
	return (页现取() as Node).get_node(名)


func 收拾并退出() -> void:
	_跑完 = true
	还原端口()
	还原存档()
	print("交易在线回归：红 %d 条" % _失败.size())
	quit(1 if _失败.size() > 0 else 0)
