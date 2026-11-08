extends SceneTree

## 心法这条链的**在线**回归用例（连真的本地服务端夹具跑，`开发工具/跑在线用例.ps1 -用例 心法在线`）。
##
## 离线那道门（`测试/心法页回归测试.gd`）能证明"画面对、分支对、发的字节名对"，但它拿的是
## **假后端** —— 证明不了服务端收不收、收了以后状态变不变。本门补的就是这半截（10-12 铁律：
## 每一项"做完" = 画面像原版 **且** 真连本地服务端跑通有反应）。
##
## 四段，逐段都是"点它 ⇒ 服务端有反应"：
##  ① 登录后 `authoritative_skills` 里有那三条心法编号 ⇒ 列表的数据源真来自服务端回帧
##     （夹具用 `--skills "9029,1000,1001,1004"` 预置；1000/1001/1004 在 GameData 里 `xinfa==1`）。
##  ② 开窗 ⇒ 发 `86:7` ⇒ 服务端 `QUERY_XINFA` ⇒ 回 `1288:3:<id>`
##     （`fake_flash_server.py:34799-34800` + `_send_default_xinfa():34904`）。
##     ★ 回帧那颗必须是**服务端自己挑的那颗**（`_default_xinfa_id():34885` = 已学里
##     编号最小的那枚心法）⇒ 拿它当参照，客户端自造的默认值当场露馅。
##  ③ 页上点第二格 ⇒ 主格换名 ⇒ 点「确定」发 `86:6:<id>` ⇒ 服务端写 `defaultXinfaId` 并 `save()`
##     （`:35021-35028`）。**服务端这一支不回帧**（原版也不回）⇒ 证据只能这样取：
##     再发一次 `7` 查询，回帧里的 id 必须是刚切过去那颗 ⇒ 才叫真落盘。
##  ④ 打了这颗心法之后，打坐的那一拍 tick 会给它加熟练度（`:38442-38459`）⇒ 客户端收到
##     一条 39 技能更新（`skill_received`）⇒ 这就是原版"心法 +1 飘字"的数据源（#176）。
##     ⚠ 服务端两拍之间是 30 秒（`MEDITATION_REWARD_INTERVAL_SECONDS = 30.0`，`:11116`）⇒ 这段
##     要等约 45 秒；等不到就是红，并打印它在窗口期里实际收到了哪几条技能帧。
##
## ⚠ 三条口径：
##   · 夹具的服务端在**独立端口** 18702/18703，但客户端**不会自己读环境变量**
##     （`后端连接.gd:521` 只认 `game_settings.backend_port`，缺省 `DEFAULT_PORT=18684`）⇒
##     本门必须把那一键临时写成夹具端口、跑完还原。10-14 首跑漏了这一步：连的是用户自己那台
##     18684（当时开着），于是"服务端挑了 1004"其实读的是**用户的存档**，而夹具一个字节没收到；
##     今天那台没开 ⇒ 直接"连接超时"。这种错**只会污染用户的角色**，不会让门变绿，所以
##     门里加了一条 `print("连夹具端口 %d")` 作为可见证据。
##   · 本门会**登录** ⇒ 客户端 `user://玩家数据.json` 会被写 ⇒ 跑前按字节快照、跑完原样还原并断言
##     （#166 那条坑：在线残留会让第二天的离线门假红）；
##   · 页面用 `测试/假心法宿主.gd` 里那套**接口名**挂真后端，宿主只有三件（`_content`/`_backend`/`close`）
##     —— 这三件在真 `功能窗口` 上存在已由离线门 §接口 逐条钉过，这里不重复。
##
## 用法：Godot --headless --path . --script res://测试/心法在线回归测试.gd（端口/账号由夹具注入）

const 心法控制器 := preload("res://脚本/界面/窗口/心法窗.gd")
const 心法场景 := preload("res://场景/界面/窗口/心法/心法窗.tscn")

var _失败: Array[String] = []
var _心法回帧: Array = []			# 每条 action==3 的 3 号回帧都留一份
var _打坐帧: Array = []			# 每条 action==1 的回帧（`1288:1:<state>:<角色>:<搭档>`，state 0=停 1=单人 2=双修）
var _技能帧: Array = []			# (技能id, 层数, 熟练度)
var _飘字信号: Array = []			# 后端.心法熟练度增加(名, 层差) —— 头顶那行字的数据源
var _获得提示: Array[String] = []		# 后端.获得提示(一行 BBCode) —— 右下角那一列
var _属性飘字: Array = []			# 后端.属性飘字(前缀, 数值, 是增, 颜色) —— 头顶那一族
var 宿主: Node
var 原端口 := -1			# `game_settings.backend_port` 跑前的值（只还原自己动过的那一键）
var 存档路 := "user://玩家数据.json"
var 存档前 := PackedByteArray()
var 本来有存档 := false


## 本门要**登录** ⇒ 客户端会往 `user://玩家数据.json` 写在线会话 ⇒ 不还原就是 #166 那条坑
## （第二天的离线门读到这份残留，报成"离线默认值漏进在线会话"那种假红）。
## 口径：跑前按字节拍快照，跑完原样写回去并再读一次比对。
func 拍快照() -> void:
	var 读 := FileAccess.open(存档路, FileAccess.READ)
	if 读 == null:
		本来有存档 = false
		return
	本来有存档 = true
	存档前 = 读.get_buffer(读.get_length())


func 还原存档() -> void:
	# 只还原自己动过的那一键（`backend_port`），别整份覆盖 `game_settings`
	if 原端口 >= 0:
		var 会话 := root.get_node_or_null("GameSession")
		if 会话 != null:
			(会话.get("game_settings") as Dictionary)["backend_port"] = 原端口
	if not 本来有存档:
		print("  （跑前根本没有 %s ⇒ 没东西可还原；本门确实新建了一份在线存档，这条只能报数不能假装还原）" % 存档路)
		return
	var 写 := FileAccess.open(存档路, FileAccess.WRITE)
	if 写 == null:
		_断(false, "还原时打不开 %s 写" % 存档路)
		return
	写.store_buffer(存档前)
	写.close()
	var 读 := FileAccess.open(存档路, FileAccess.READ)
	_断(读 != null and 读.get_buffer(读.get_length()) == 存档前,
			"跑完把 %s **按字节还原**了（跑前 %d 字节）" % [存档路, 存档前.size()])


## 在线用例专用的最小宿主：控制器只碰这三件（`_content` / `_backend` / `close`）。
class 活宿主 extends Node:
	var _content := Control.new()
	var _刚开窗 := true		# 宿主 `open_page()` 才为真；回帧引起的重渲染是 false（`功能窗口.gd`）
	var _backend: Node = null
	var 关窗次数 := 0

	func _ready() -> void:
		_content.name = "页面容器"
		_content.size = Vector2(960.0, 560.0)
		add_child(_content)

	func close() -> void:
		关窗次数 += 1


func _initialize() -> void:
	call_deferred("_run")


func _等秒(秒: float, 条件: Callable) -> bool:
	var 止 := Time.get_ticks_msec() + int(秒 * 1000.0)
	while Time.get_ticks_msec() < 止:
		if 条件.call():
			return true
		await create_timer(0.05).timeout
	return 条件.call()


func _run() -> void:
	拍快照()
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_败("缺少 BackendConnection / GameSession 单例")
		return
	## ⚠ **必须**把夹具端口写回 `game_settings.backend_port`：客户端只认这一键，不会读环境变量
	##   （`后端连接.gd:521` ⇒ 默认 `DEFAULT_PORT = 18684`）。18684 是**用户自己那台客户端在连的号**
	##   ⇒ 不写就等于拿用例去点用户的角色（切他的心法！）。
	##   10-14 首跑就是这样：连的是 18684 上当时开着的那台，所以"服务端挑了 1004"其实是从用户存档里
	##   读的 `defaultXinfaId`，而夹具那份 18702 一个字节都没收到。写法照
	##   `交付后自动弹对话在线回归测试.gd:113-124`。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18702
	var 设置: Dictionary = 会话.get("game_settings")
	原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	print("连夹具端口 %d（账号 %s）" % [口, String(设置.get("backend_account", ""))])
	宿主 = 活宿主.new()
	宿主._backend = 后端
	root.add_child(宿主)
	await create_timer(0.2).timeout

	后端.heal_state_received.connect(func(状: Dictionary):
		if int(状.get("action", 0)) == 3:
			_心法回帧.append(状.duplicate(true))
		elif int(状.get("action", 0)) == 1:
			_打坐帧.append(状.duplicate(true))
	)
	后端.skill_received.connect(func(号: int, 级: int, 熟练: int):
		_技能帧.append([号, 级, 熟练])
	)
	## 打坐那一拍到了之后，数据层要**当场**把它认成"心法涨层"并分两路发出去
	## （`DataCenter.as:1578-1588` 那一个 if）。挂在这里 = 从真帧到信号全程不掺假。
	后端.心法熟练度增加.connect(func(名: String, 层: int): _飘字信号.append([名, 层]))
	后端.获得提示.connect(func(文: String): _获得提示.append(文))
	后端.属性飘字.connect(func(前: String, 数: int, 增: bool, 色: Color): _属性飘字.append([前, 数, 增, 色]))
	后端.sync_character()
	if not await _等秒(20.0, func() -> bool: return bool(后端.in_game)):
		_败("没进真实游戏会话：%s - %s" % [后端.status, 后端.detail])
		return

	# ── ① 列表的数据源真来自服务端 ──────────────────────────────────────────
	if not await _等秒(10.0, func() -> bool:
		return (后端.authoritative_skills as Dictionary).size() > 0):
		_败("登录后服务端一条技能帧都没发 ⇒ 心法列表没有数据源（authoritative_skills 空）")
		return
	var 已学 := 心法控制器.已学心法(后端)
	_断(已学.size() >= 3,
			"已学 ∩ xinfa==1 至少有 3 条（夹具 --skills 预置了 1000/1001/1004），实测 %d 条：%s"
			% [已学.size(), str(_ids(已学))])
	_断(not 已学.has(9029) and not _有(已学, 9029),
			"9029 那条预置忍术**不是**心法 ⇒ 不该出现在这张列表（`:2058-2072` 的 xinfa==1 筛）")

	# ── ② 开窗发 7 ⇒ 回帧 3:<id>，且那颗是服务端自己挑的 ────────────────────
	宿主._刚开窗 = true
	var 页 := 心法控制器.渲染(宿主, 心法场景)
	_断(页 != null and 页.get_node("心法列表/心法列表_内容").get_child_count() == 已学.size(),
			"页面按真数据建了 %d 格" % (页.get_node("心法列表/心法列表_内容").get_child_count() if 页 != null else -1))
	_断(String((页.get_node("心法名") as Label).text) == "",
			("★ 回帧**还没到**的这一次渲染，主格是空的（实测「%s」）—— 客户端不许自己猜一颗心法填上去；"
			+ "原版 `UI.as:649-652` 开窗只发查询，格子等 `1288:3:<id>` 才填")
			% String((页.get_node("心法名") as Label).text))
	if not await _等秒(8.0, func() -> bool: return _心法回帧.size() > 0):
		_败("发了 86:7 但没收到 1288:3:<id> 回帧（服务端 QUERY_XINFA 那支没跑通）")
		return
	var 首 := _心法回帧[0] as Dictionary
	var 服务端那颗 := int(首.get("xinfa_id", -1))
	# ⚠ 参照值要**自己算**、且要按服务端自己的算式算：`_default_xinfa_id():34885` 先看存档里
	#   已存的 `defaultXinfaId`，没有才回落到「已学里编号最小的那枚心法」。夹具这一轮带了
	#   `--reset-xinfa-default`（抹掉那一行）⇒ 这里可以钉死 = min(已学编号)。
	#   （`mini()` 是"两个整数取小"，不是数组取小 —— 这里要自己遍历。）
	var 应挑 := 0
	for 号 in _ids(已学):
		if 应挑 == 0 or int(号) < 应挑:
			应挑 = int(号)
	_断(服务端那颗 == 应挑,
			"回帧给的就是服务端自己挑的那颗 = 已学最小编号 %d（`:35105-35122`），实测 %d" % [应挑, 服务端那颗])
	_断(_有(已学, 服务端那颗),
			"★ 服务端挑的那颗确实在**已学**列表里 ⇒ 主格填得上（客户端不必也不该自造兜底）")
	# 回帧之后宿主会重渲染（本工程把 heal_state_received 接成了 `_refresh_current`）⇒ 手动走同一条：
	# `刚开` 必须为**假**，否则这一轮又发一条 7 ⇒ 7→3→渲染→7 成环（离线门钉的是流水，这里钉真回帧数）
	宿主._刚开窗 = false
	var 页二 := 心法控制器.渲染(宿主, 心法场景)
	await create_timer(1.5).timeout
	_断(_心法回帧.size() == 1,
			"回帧引起的重渲染**没有**再发一条 7（实测共收到 %d 条 3 号回帧）" % _心法回帧.size())
	var 名标 := 页二.get_node("心法名") as Label
	var 层标 := 页二.get_node("心法层数") as Label
	_断(String(名标.text) == String(_名(已学, 服务端那颗)),
			"回帧把主格填上了：名标「%s」（应为「%s」）" % [String(名标.text), String(_名(已学, 服务端那颗))])
	_断(String(层标.text).begins_with("当前层数:"),
			"层标「%s」= CN.CURRENT_CENGSHU + floor（`:92`，冒号半角）" % String(层标.text))

	# ── ③ 点第二格 ⇒ 确定 ⇒ 6:<id> ⇒ 服务端真落盘（用再查询取证）────────────
	# ⚠ `目标` 必须在 if/else **外面**声明：GDScript 4 是块作用域，写在 else 里的话
	#   下面第 ④ 段根本看不见它（`--check-only` 当场报 "not declared in the current scope"）。
	var 目标 := 0		# ③ 里赋成真值，④ 段要用同一个目标
	if 已学.size() < 2:
		_败("已学心法不足 2 条 ⇒ 没法验「切到另一颗」（夹具 --skills 要至少两条心法）")
		return
	目标 = int((已学[1] as Dictionary)["id"])
	var 内容 := 页二.get_node("心法列表/心法列表_内容") as Control
	var 格 := 内容.get_child(1) as Control
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	格.gui_input.emit(按)
	_断(String(页二.get_node("心法名").text) == String(_名(已学, 目标)),
			"点第二格 ⇒ 主格换成「%s」" % String(_名(已学, 目标)))
	(页二.get_node("确定钮") as Button).pressed.emit()
	await create_timer(1.0).timeout			# 给这条 6 走完一次往返的时间
	_断(宿主.关窗次数 == 1, "确定之后窗关了（`:114`），实测关 %d 次" % 宿主.关窗次数)
	_心法回帧.clear()
	if not bool(后端.request_xinfa_show()):
		_败("再查询那条 7 没发出去")
		return
	if not await _等秒(8.0, func() -> bool: return _心法回帧.size() > 0):
		_败("切完心法再查询没有回帧")
		return
	var 现在 := int((_心法回帧[0] as Dictionary).get("xinfa_id", -1))
	_断(现在 == 目标,
			("★ 点确定真的改掉了服务端状态：再查询回帧 = %d（刚切的 %d / 切之前的 %d）"
					+ " ⇒ `CHANGE_XINFA` 那支 `store.state.character_config[defaultXinfaId]` 落盘了")
					% [现在, 目标, 服务端那颗])
	# 非法编号必须被服务端**驳回并回落到合法值**（`:35021-35031` 的 else 支）
	_心法回帧.clear()
	后端.request_xinfa_change(9999999)
	await create_timer(1.0).timeout
	后端.request_xinfa_show()
	if await _等秒(8.0, func() -> bool: return _心法回帧.size() > 0):
		var 回落 := int((_心法回帧[0] as Dictionary).get("xinfa_id", -1))
		_断(回落 == 目标,
				"没学过的编号 9999999 被服务端拒绝、回落到 %d（不是 0、也不是脏值）—— 客户端不许自造这层校验"
				% 回落)
	else:
		_败("发过非法 6:<id> 之后再查询没有回帧")

	# ── ④ 打坐那一拍给这颗心法加熟练度（服务端 30 秒一拍）──────────────────────
	# ⚠ 先钉"打坐**确实开起来了**"再等那一拍：`handle_heal_over_time():35002-35010` 在
	#   `_is_dead()` 或 `_is_in_combat()`（脱战 5 秒，`OUT_OF_COMBAT_SECONDS:11103`）时回的是
	#   `1288:1:0`（STOPPED）而不是 `:1:` ⇒ 只等 39 帧的话，"被拒"和"没等到"看起来一模一样
	#   （10-14 首跑就是这么糊过去的：45 秒零帧，日志里看不出服务端到底开没开）。
	var 打坐前 := int(((后端.authoritative_skills as Dictionary).get(目标, {}) as Dictionary).get("master_level", -1))
	_断(bool(后端.request_heal_start()), "发了打坐 START（86:1）")
	_打坐帧.clear()
	if not await _等秒(8.0, func() -> bool: return _打坐帧.size() > 0):
		后端.request_heal_stop()
		_败("发了 86:1 但服务端没回任何一条 1288:1:<state> ⇒ 打坐这条根本没接线（不是'等不到那一拍'）")
		return
	var 开的状态 := int((_打坐帧[_打坐帧.size() - 1] as Dictionary).get("state", -1))
	_断(开的状态 == 1,
			("服务端真的进了单人打坐（`1288:1:1` = HealState.SINGLE，`:35007-35010`），实测 state=%d"
			+ "（0 = 被拒：死了或还在战斗中，`:35003-35005`）") % 开的状态)
	_飘字信号.clear()
	_获得提示.clear()
	_属性飘字.clear()
	var 到 := await _等秒(45.0, func() -> bool:
		for 一 in _技能帧:
			if int(一[0]) == 目标 and int(一[2]) > 打坐前:
				return true
		return false)
	后端.request_heal_stop()
	_断(到, ("打坐约 30 秒那一拍给心法 %d 加了熟练度并回了一条 39 技能帧（`:38442-38459`）—— "
			+ "窗口期实际收到的技能帧 %s；这条也是 #176「心法熟练度提示」的数据源") % [目标, str(_技能帧)])
	if 到:
		# ── 那条 39 帧到了之后，头顶/右下角这两路**必须跟着出**（用户 10-14 报的"打坐时头顶的字"）──
		# 参照值自己从数据表现算，不向被测代码要（否则查表写错也照样绿）。
		var 层差 := 0
		for 一 in _技能帧:
			if int(一[0]) == 目标:
				层差 = maxi(层差, int(一[2]) - 打坐前)
		var 表: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/心法表.json"))
		var 真名 := String((((表 as Dictionary).get("条目", {}) as Dictionary)
				.get(str(目标).pad_zeros(7), {}) as Dictionary).get("名称", ""))
		_断(真名 != "" and 真名 == String(load("res://脚本/单例/后端连接.gd").心法名(目标)),
				"心法名查表与数据表一致（%s vs %s）—— 名字错了头顶那行就是自造的"
						% [真名, String(load("res://脚本/单例/后端连接.gd").心法名(目标))])
		_断(_飘字信号.size() == 1 and String(_飘字信号[0][0]) == 真名 and int(_飘字信号[0][1]) == 层差,
				"★ 真帧一到就发出「心法熟练度增加(%s, +%d)」⇒ 角色头顶那行蓝字有了数据源；实得 %s"
						% [真名, 层差, str(_飘字信号)])
		_断(_获得提示.has("[color=#00cc33]%s心法熟练度 [color=#f0dd06]+%d[/color][/color]" % [真名, 层差]),
				"右下角同一拍多一行「%s心法熟练度 +%d」（`PROM_XINFA_GET` 原样）；实得 %s"
						% [真名, 层差, str(_获得提示)])
		## 那一拍服务端**同时**发一条属性帧带新精华（`_send_stats({StatType.ZQ})`，`:38455`）
		## ⇒ 头顶那一族（#175 的属性档）也必须被真帧驱动一次，不能只有心法熟练度那一档活着。
		var 精华: Array = []
		for 条 in _属性飘字:
			if String(条[0]) == "精华":
				精华 = 条
		_断(not 精华.is_empty() and bool(精华[2]) and int(精华[1]) > 0
				and 精华[3] == Color(0.0, 0.6, 1.0),
				"★ 同一拍那条属性帧 ⇒ 头顶飘「精华 + N」（ZQ 档蓝 #0099FF）；实得 %s" % str(_属性飘字))

	if _失败.is_empty():
		还原存档()
		后端.disconnect_backend()
		print("心法在线回归：通过（查询回帧 / 切换落盘 / 非法值回落 / 打坐加熟练度 四段都真跑通）")
		quit(0)
		return
	for 一 in _失败:
		push_error(一)
	还原存档()
	print("心法在线回归：失败 %d 段 —— %s" % [_失败.size(), " / ".join(_失败)])
	后端.disconnect_backend()
	quit(1)


func _有(列: Array, 号: int) -> bool:
	for 项 in 列:
		if int((项 as Dictionary)["id"]) == 号:
			return true
	return false


func _ids(列: Array) -> Array:
	var 出: Array = []
	for 项 in 列:
		出.append(int((项 as Dictionary)["id"]))
	return 出


func _名(列: Array, 号: int) -> String:
	for 项 in 列:
		if int((项 as Dictionary)["id"]) == 号:
			return String((项 as Dictionary)["名称"])
	return ""


func _断(过: bool, 文: String) -> void:
	if not 过:
		_失败.append(文)
	print("  %s %s" % ["√" if 过 else "!!", 文])


func _败(文: String) -> void:
	push_error(文)
	print("!! %s" % 文)
	还原存档()		# 中途死掉也要把客户端存档还原（不还原就留残留，见文件头 #166 那条）
	quit(1)
