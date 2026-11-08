extends SceneTree
## 头像下那颗战斗模式钮的**在线端到端**门（#350，2026-10-25）。
##
## 为什么单开一条：离线腿里没有 TCP ⇒ `send_game_request` 第一行就回 false，
## "点了没反应"与"发了但服务端不理"两种坏法在离线门上长得一模一样 ——
## `测试/姓名战斗挂机回归测试.gd` 那 161 条钉的是画面与状态机，照不到这一段。
## 这条判四层：真鼠标点得到 → `1792:0:<档>` 到得了服务端 → 服务端回 `1792:2` 把我这侧权威档改掉
## → **同屏对面也收到这一发**（服务端切完是 `_send_visible`，`fake_flash_server.py:41833`，
## 不是只回自己；只判自己变绿 = 别人的客户端永远不知道你切了全体）。
##
## 只走 **4（全体）→ 1（普通）** 两档：服务端 `handle_open_pvp_action:41808-41826` 对
## 2（无队）/3（无族）**直接回原值**并只发一句提示 ⇒ 那两档在这儿测的是"闸"、测不到切换。
##
## 跑法：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具\跑在线用例.ps1 -用例 战斗模式 -Godot godot`
## （夹具另给一对端口 18756/18757：18684 是用户自己那台客户端在连的号，绝不顶）

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 头像面板场景 := "res://场景/界面/头像面板.tscn"
const 存档路 := "user://玩家数据.json"
const 服务端文件 := "res://服务端/runtime/tools/fake_flash_server.py"
const PEER_ACCOUNT := "naruto"
const PEER_PASSWORD := "123456"
## 那颗点开的四行菜单（原版 `PKModePane2`）。
const 模式菜单脚本 := preload("res://脚本/界面/组件/PK模式菜单.gd")
## 模式号 → 皮肤基名（`CharactorInfoPane.as:446-461`，四枚 upSkin 元件 759/743/747/755）。
const 模式基名 := {1: "模式_普通", 2: "模式_组队", 3: "模式_家族", 4: "模式_全体"}
## 本腿该判满的条数（不含末尾那条计数自查，它只读 `模数`、自己不加）：
## 一处加判据就要同步改这里，否则"半路死了"照绿。
## ⚠ 别把自查写成 `_模记(模数 == 本腿条数, …)`：实参**先于**函数体求值，那一瞬 `模数`
## 还是加之前的数 ⇒ 恒差一条、每次都红（2026-10-25 第一次跑就是这么红的，不是门不敏感）。
const 本腿条数 := 18

var _主: Node = null
var _对: Node = null
var _会话: Node = null
var _面板: Node = null
var _对编号 := 0
var _原端口 := -1
var _失败: Array = []
## 对面那侧收到的 `1792:2`，每条形如 [号, 模式]。
var _对模式: Array = []
## 我这侧说过的话（`GameSession.notification_requested` + 后端聊天帧）。
var _收: Array = []
var 模数 := 0
var 存档前 := PackedByteArray()
var 本来有存档 := false
## 协程中途报错 ⇒ `quit()` 永远调不到 ⇒ 进程挂死、日志看着像"还在跑"（10-17 实测吊了六分钟）。
## 所以超时没跑完按红收口，别把红伪装成"没跑完"。
var 跑完了 := false


func _initialize() -> void:
	var 起 := Time.get_ticks_msec()
	call_deferred("_跑")
	while not 跑完了 and Time.get_ticks_msec() - 起 < 180_000:
		await process_frame
	if not 跑完了:
		printerr("战斗模式在线：门自己没跑完（协程中途报错，看上面最后一条 SCRIPT ERROR）")
		还原端口()
		quit(1)


func _记(过: bool, 文: String) -> void:
	if 过:
		print("  √ " + 文)
	else:
		_失败.append(文)
		printerr("  !! " + 文)


## 本腿的判据：走这条才计数 ⇒ 末尾 `模数 == 本腿条数` 抓"整腿半路死了"。
func _模记(过: bool, 文: String) -> void:
	模数 += 1
	_记(过, 文)


## 那颗此刻**实际挂在 normal 槽上的图**的路径。皮没取到时直接 `.resource_path` 是当场报错、
## 整条协程死掉（后半判据一条不跑、末行照样能打「红 0 条」）⇒ 一律走这条。
func _模皮(钮: TextureButton) -> String:
	if 钮 == null or 钮.texture_normal == null:
		return "‹没皮›"
	return String(钮.texture_normal.resource_path)


## 对面那侧收到过 `[号, 模式]` 这一发没有。不靠 `Array.has([我号,4])` 的深比较
## （一旦不成立就是"看着收到了却判红"，读日志的人查不出来）。
func _对收了(号: int, 式: int) -> bool:
	for 项 in _对模式:
		if 项 is Array and (项 as Array).size() == 2 \
				and int((项 as Array)[0]) == 号 and int((项 as Array)[1]) == 式:
			return true
	return false


func _等秒(秒: float, 条件: Callable) -> bool:
	var 止 := Time.get_ticks_msec() + int(秒 * 1000.0)
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.1).timeout
	return bool(条件.call())


## 只把鼠标挪过去（不按）：给"点不到先量量压在谁身上"这种诊断用。
func _挪到(心: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	root.push_input(移)
	await process_frame
	await process_frame


## **真**鼠标点一下（按 + 放，走 `push_input`）。不许 `emit_signal("pressed")` 演。
func _点(件: Control) -> void:
	var 心: Vector2 = 件.get_global_rect().get_center()
	var 移 := InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	root.push_input(移)
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 心
	按.global_position = 心
	root.push_input(按)
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 心
	放.global_position = 心
	root.push_input(放)
	await process_frame
	await process_frame


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
	else:
		if FileAccess.file_exists(存档路):
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
	print("战斗模式在线门：本腿判 %d 条（应满 %d）/ 红 %d 条" % [模数, 本腿条数, _失败.size()])
	quit(1 if _失败.size() > 0 else 0)


func _跑() -> void:
	拍快照()
	_主 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _主 == null or _会话 == null:
		printerr("战斗模式在线：缺 BackendConnection / GameSession 单例（自动加载没跑起来）")
		quit(1)
		return
	## 服务端那一支还在不在（撤了 ⇒ 这一点永远石沉大海，而客户端侧全是绿的）。
	var 源 := FileAccess.get_file_as_string(服务端文件)
	_记(源.contains("def handle_open_pvp_action"),
			"服务端 1792 那一支还在（撤了 ⇒ 切模式永远石沉大海）")
	_记(源.contains('OPEN_PVP_ACTION)}:2:"'), "服务端确认那一发回的是 `1792:2:<号>:<档>`")

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18756
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_对编号 = int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	print("连夹具端口 %d；对面那个号 = %d（账号 %s）" % [口, _对编号, PEER_ACCOUNT])
	if _对编号 <= 0:
		printerr("战斗模式在线：夹具没给 NW_SOCIAL_PEER_ID ⇒ 没有第二个号，广播那一半无从判起")
		还原端口()
		quit(1)
		return

	_主.sync_character()
	if not await _等秒(20.0, func() -> bool: return bool(_主.in_game)):
		printerr("战斗模式在线：主号进不了游戏（%s - %s）" % [_主.status, _主.detail])
		收拾并退出("卡在「主号进不了游戏」⇒ 本腿一条没跑")
		return
	var 我号 := int(_主.character_id)

	## HUD 那颗长在头像面板里 ⇒ 按真游戏那一层号（地图场景里 `头像面板` 是 300）挂进来。
	var 节 := (load(头像面板场景) as PackedScene).instantiate()
	节.set("layer", 300)
	root.add_child(节)
	_面板 = 节
	## ⚠ 无头 `push_input` 之前必须钉 root.size：视口图/命中区按工程设置尺寸算，
	## 不钉会把钮判成"点不到"（10-16 记过这条引擎脾气）。
	root.size = Vector2i(960, 560)
	await create_timer(0.4).timeout

	## 第二个号：同图同线才收得到 `_send_visible` 那一发（`broadcast_visible` 按 line_id 筛）。
	_对 = BACKEND_SCRIPT.new()
	_对.name = "战斗模式在线对面那个号"
	root.add_child(_对)
	_对.connect("pk_mode_received", func(号: int, 式: int) -> void: _对模式.append([号, 式]))
	_会话.connect("notification_requested", func(话: String) -> void: _收.append(话))
	_主.connect("chat_received", func(件: Dictionary) -> void: _收.append("聊天:" + str(件.get("message", 件))))
	_对.connect_backend(PEER_ACCOUNT, PEER_PASSWORD, false)
	if not await _等秒(10.0, func() -> bool: return bool(_对.authenticated)):
		printerr("战斗模式在线：第二个号登录不上（夹具里有没有 %s 这个账号？）" % PEER_ACCOUNT)
		收拾并退出("卡在「第二个号登录不上」⇒ 广播那几条判据一条没跑")
		return
	if not bool(_对.select_character(_对编号)):
		printerr("战斗模式在线：第二个号选不上角色 %d" % _对编号)
		收拾并退出("卡在「第二个号选不上角色」⇒ 广播那几条判据一条没跑")
		return
	if not await _等秒(20.0, func() -> bool: return bool(_对.in_game) and int(_对.character_id) == _对编号):
		printerr("战斗模式在线：第二个号进不了游戏（%s - %s）" % [_对.status, _对.detail])
		收拾并退出("卡在「第二个号进不了游戏」⇒ 广播那几条判据一条没跑")
		return
	await create_timer(0.5).timeout

	# ── 本腿：真点那颗 ⇒ 四行菜单 ⇒ 真点某一行 ⇒ 服务端往返 + 对面收得到广播 ──
	_对模式.clear(); _收.clear()
	var 模钮 := (_面板.get_node_or_null("头像区域/角色状态/StatusToggle") as TextureButton)
	var 模起始 := int(_主.authoritative_pk_mode)
	_模记(模钮 != null and 模钮.visible, "头像下那颗找得到、也看得见（实得 %s）" % str(模钮))
	if 模钮 == null:
		收拾并退出("卡在「模钮 == null」⇒ 本腿后面的判据一条没跑")
		return
	_模记(模式基名.has(模起始) and _模皮(模钮).ends_with(str(模式基名.get(模起始, "")) + ".png"),
			"按下之前那颗画的就是当前那一档（权威模式 %d / 实得皮 %s）" % [模起始, _模皮(模钮)])
	await _挪到((模钮 as Control).get_global_rect().get_center())
	_模记(root.gui_get_hovered_control() == 模钮,
			"点之前那一点压在钮上（实得压在上面的=%s）" % str(root.gui_get_hovered_control()))
	await _点(模钮)
	_模记(模式菜单脚本.开着(),
			"真点那颗 ⇒ 四行菜单开在脸上（原版 showPvpModeViewHandler 是开关，不是循环换档）")
	if not 模式菜单脚本.开着():
		收拾并退出("卡在「点那颗没开出菜单」⇒ 切全体那几条判据一条没跑")
		return
	## 菜单本体按**节点名**取（不读 `PK模式菜单.菜单` 那个静态变量：经 preload 常量拿静态变量
	## 在 4.7 上是运行期 `get`，取不到就是 null ⇒ 会把"开出来了"伪装成"没开"）。
	var 模菜单 := (模钮.get_parent() as Node).get_node_or_null("PK模式菜单") as Control
	if 模菜单 == null:
		收拾并退出("卡在「模菜单 == null」⇒ 四行齐全那条没法判")
		return
	var 模齐全 := true
	for 档 in [1, 2, 3, 4]:
		if 模菜单.get_node_or_null("模式行%d" % 档) == null:
			模齐全 = false
	_模记(模齐全, "菜单里四行都在（模式行1/2/3/4，按 `PKModePane2.as:73-90` 的序）")
	## 选中条那两档：原版 `overHandler/outHandler` 是"悬停亮、移开**回到是否选中**"，不是一律隐藏。
	## 这一对专门钉 2026-10-25 在线第一跑逮到的那条：`项.set_meta("选中", …)` 的中文键在 Godot 4
	## 里报 `Invalid metadata identifier` **且静默存不进去** ⇒ 移开后 `get_meta("选中", false)` 恒 false
	## ⇒ 当前那一档的选中条再也亮不回来（画面缺陷 + 每次换档刷一串 ERROR）。
	var 行一 := 模菜单.get_node_or_null("模式行1") as Button
	var 行四 := 模菜单.get_node_or_null("模式行4") as Button
	if 行一 == null or 行四 == null:
		收拾并退出("卡在「模式行1/4 取不到」⇒ 选中条与切档那几条判据一条没跑")
		return
	await _挪到(行四.get_global_rect().get_center())
	_模记((行四.get_node("选中条") as CanvasItem).visible,
			"悬停「全体」那一行 ⇒ 它的选中条亮（原版 overHandler:146-149）")
	await _挪到(Vector2(700, 480))
	_模记((行一.get_node("选中条") as CanvasItem).visible
			and not (行四.get_node("选中条") as CanvasItem).visible,
			"移开 ⇒ 亮回当前那一档（模式行1）、悬停那行灭（outHandler:151-154 回的是「是否选中」）")
	## 第三条才是"选中态丢没丢"的那把刀：前两条里 行1 从头到尾没被压灭过（0 比 0 照不到）。
	## 只有**悬停当前那一行再移开**才走得到 `outHandler` 的"回落到是否选中"那一步 ——
	## 变异实测（`条.visible = 在` 一刀）就是靠这条红的，前两条照样绿。
	await _挪到((行一 as Control).get_global_rect().get_center())
	await _挪到(Vector2(700, 480))
	_模记((行一.get_node("选中条") as CanvasItem).visible,
			"悬停当前那一行再移开 ⇒ 它还亮着（原版 outHandler 回的是「是否选中」，不是一律隐藏）")
	await _点(行四)
	_模记(not 模式菜单脚本.开着(),
			"点「全体」那一行 ⇒ 菜单自己收掉（原版 onCheckPKMode 末尾 removeChild）")
	_模记(await _等秒(8.0, func() -> bool: return int(_主.authoritative_pk_mode) == 4),
			"服务端回 `1792:2:<我的号>:4` ⇒ 我这侧权威模式真变 4（实得 %d）" % int(_主.authoritative_pk_mode))
	_模记(await _等秒(4.0, func() -> bool: return _模皮(模钮).ends_with("模式_全体.png")),
			"屏幕上那颗换成全体那枚（实得 %s）" % _模皮(模钮))
	_模记(not 模钮.disabled, "收到回帧之后那颗不再灰着（请求中禁用、确认即恢复）")
	_模记(await _等秒(4.0, func() -> bool:
			for 话 in _收:
				if String(话).contains("全体"):
					return true
			return false),
			"这一趟有说话且点了「全体」（实得 %s）" % str(_收))
	_模记(await _等秒(8.0, func() -> bool: return _对收了(我号, 4)),
			"同屏对面也收到这一发广播（实得 %s）" % str(_对模式))
	await _点(模钮)
	_模记(模式菜单脚本.开着(), "再点那颗 ⇒ 菜单又开出来（同一颗的开关语义，不是点一次少一次）")
	if not 模式菜单脚本.开着():
		收拾并退出("卡在「再点那颗没开出菜单」⇒ 回普通那几条判据一条没跑")
		return
	_对模式.clear()
	var 模行一 := (模钮.get_parent() as Node).get_node_or_null("PK模式菜单/模式行1") as Control
	if 模行一 == null:
		收拾并退出("卡在「模行一 == null」⇒ 回普通那几条判据一条没跑")
		return
	await _点(模行一)
	_模记(await _等秒(8.0, func() -> bool: return int(_主.authoritative_pk_mode) == 1),
			"点「普通」⇒ 服务端回帧、权威模式回 1（实得 %d）" % int(_主.authoritative_pk_mode))
	_模记(await _等秒(4.0, func() -> bool: return _模皮(模钮).ends_with("模式_普通.png")),
			"那颗跟着换回普通那枚（实得 %s）" % _模皮(模钮))
	_模记(await _等秒(8.0, func() -> bool: return _对收了(我号, 1)),
			"回 1 那一发对面也收到（实得 %s）" % str(_对模式))
	_记(模数 == 本腿条数, "本腿判满 %d 条（实得 %d）—— 少一条就是半路死了" % [本腿条数, 模数])
	收拾并退出()
