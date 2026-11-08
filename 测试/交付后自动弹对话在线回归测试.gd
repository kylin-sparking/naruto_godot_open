extends SceneTree

## 「交完任务，如果这个 NPC 还有下一环，对话窗要自己再弹一次」——#182（用户 2026-10-10 实测打回）。
##
## 为什么单独立一条在线用例：**这一段只可能坏在服务端**。
## 原版客户端点完「交付」只发一个包就结束了（`UI.as:2262-2265` 的 `onQuestItemHandWindowHand`
## ⇒ `requestNPCMoreTalkEx(COMMIT, value)`），**没有任何一处会再要一次对话**；
## 而本工程客户端收到 328 帧是无条件把窗弹开的（`小地图面板.gd:133 → _on_backend_npc_dialog
## → show_npc_dialog`）。所以「弹不弹」这件事 100% 取决于服务端交付之后有没有重推那一帧。
##
## 走的就是玩家那条路：54 开对话 → 57:3 点任务行 → 57:1 逐句翻台词 → 服务端在最后一句落交付。
## 判据故意分成两半：
##   ① 交付**有没有**生效（任务离开已接）—— 这是老链，红了就说明后面那条无从谈起；
##   ② 交付生效之后**必须再出现一帧对话**，且那一帧的任务行里带着下一环（1003 → 1006，
##      两环都挂在同一枚 NPC 模板 1 上：`数据/任务.json` 的 `npc.1` == 下一环的 `npc.0`）。
## ② 是本条存在的理由：修之前服务端压根不重推 ⇒ ② 必红。
##
## ⚠ 判别「交付后重推的那一帧」与「作者台词那一帧」靠 `player_text`：
##   台词帧是 `_send_authored_quest_dialog` 发的，`player_text` 恒非 `-`（客户端要点下格翻下一句）；
##   重推帧走的是 `_send_current_npc_dialog`，`player_text` 就是 `-`（没有可选回应）。

var _backend: Node
var _会话: Node
var _表 := {}
var _已接: Array = []
var _可接: Array = []
var _帧: Array = []
## 每收到一帧 328 就存一份**当时的** last_npc_dialog（信号在赋值之后发，取得到）。
var _对话记录: Array = []
var _列表次数 := 0
var _发现: Array[String] = []
## 本条只动 `backend_port` 一个键，收尾必须还原回去（否则用户客户端明天连到临时口）。
var _原端口 := -1
var _判数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _等(pred: Callable, 毫秒 := 6000) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if bool(pred.call()):
			return true
		await create_timer(0.05).timeout
	return false


func _条(id: String) -> Dictionary:
	for 条 in _已接:
		if String((条 as Dictionary).get("id", "")) == id:
			return 条 as Dictionary
	return {}


func _NPC(模板: int) -> Dictionary:
	for 号 in _backend.map_npcs:
		var 状: Dictionary = _backend.map_npcs[号]
		if int(状.get("npc_id", -1)) == 模板:
			return 状
	return {}


## 一帧里的任务行 = selection 段里那些 `文字&任务id&状态` 的任务 id 串
## （键名照 `_解析NPC任务行` 的实际形状：`{"文字","任务id","状态"}`，别写成英文键拿到 -1）。
func _行号(帧: Dictionary) -> Array[String]:
	var 出: Array[String] = []
	for 行 in (帧.get("selection", []) as Array):
		出.append(str(int((行 as Dictionary).get("任务id", -1))))
	return 出


func _记帧(npc_id: int, _message: String) -> void:
	var 快: Dictionary = _backend.get("last_npc_dialog") as Dictionary
	_对话记录.append({"npc_id": npc_id, "player_text": String(快.get("player_text", "-")),
			"行": _行号(快), "菜单": (快.get("menu", []) as Array).size()})
	_帧.append(npc_id)


## 玩家点一行的完整跳数：54 → 57:3 → 逐句 57:1 直到不再回帧。返回翻了几句。
func _走任务行(模板: int, 任务号: int) -> int:
	if _NPC(模板).is_empty():
		return -1
	_backend.request_npc_dialog(int(模板))
	await create_timer(0.4).timeout
	_backend.request_npc_selection(int(任务号))
	await create_timer(0.4).timeout
	var 翻 := 0
	while 翻 < 12:
		var 起点 := _帧.size()
		_backend.request_npc_next()
		await create_timer(0.4).timeout
		if _帧.size() == 起点:
			break
		翻 += 1
	return 翻


func _run() -> void:
	_backend = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _backend == null or _会话 == null:
		print("交付后对话：缺单例，无法跑")
		quit(1)
		return
	_backend.quest_list_received.connect(func(a: Array, b: Array):
		_已接 = a
		_可接 = b
		_列表次数 += 1)
	_backend.npc_dialog_received.connect(_记帧)
	_表 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/任务.json"))
	## ⚠ 本条走的是**独立端口**（18696，`跑在线用例.ps1` 的 $夹具额外），不是客户端默认那台 18684
	##   —— 默认端口是用户自己那台客户端在连的号，绝不能拿用例去顶它。
	##   夹具只把端口号放进环境变量，客户端不会自己读 ⇒ 不在这儿写回 `game_settings`，
	##   用例就会连到 18684 上（实测：连接超时、`received=0`）。写法照 创角进图在线回归测试.gd:139-159。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18696
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	print("连夹具端口 %d（账号 %s）" % [口, String(设置.get("backend_account", ""))])
	_backend.sync_character()
	if not await _等(func(): return bool(_backend.in_game), 15000):
		print("交付后对话：没进游戏 %s - %s" % [_backend.status, _backend.detail])
		quit(1)
		return
	var 起点 := _列表次数
	await _等(func(): return _列表次数 >= 起点 + 2, 8000)
	print("进游戏：已接 %d / 可接 %d" % [_已接.size(), _可接.size()])

	# ============ 夹具前提：1003 在已接里、它的交付 NPC（模板 1）在本图 ============
	var 定: Dictionary = _表.get("1003", {})
	var 交付模板 := int(((定.get("npc", {}) as Dictionary)).get("1", 0))
	var 下一环 := "1006"
	var 下环发NPC := int((((_表.get(下一环, {}) as Dictionary).get("npc", {})) as Dictionary).get("0", 0))
	_判(交付模板 > 0 and 交付模板 == 下环发NPC,
			"夹具前提变了：1003 的交付 NPC=%d、1006 的发任务 NPC=%d，本条靠「两环同一枚 NPC」才成立" % [交付模板, 下环发NPC])
	if _NPC(交付模板).is_empty():
		_判(false, "本图找不到交付 NPC 模板 %d（本图 NPC=%s）⇒ 这一轮没法测" % [交付模板, _本图NPC()])
	if _条("1003").is_empty():
		_判(false, "1003 没在已接列表里（服务端自动接取没生效），后面两条判据都无从谈起")

	# ============ ① 交付 ============
	var 帧数前 := _帧.size()
	var 翻 := await _走任务行(交付模板, 1003)
	await create_timer(0.6).timeout
	print("① 1003：翻了 %d 句，已接里还剩 %s" % [翻, JSON.stringify(_条("1003"))])
	_判(翻 > 0, "点了 1003 这行一句台词都没回（57:3 没被接住）⇒ 交付根本没开始")
	var 交掉了 := _条("1003").is_empty()
	_判(交掉了, "翻完对话 1003 还在已接里（交付没生效）")

	# ============ ② 交付生效之后服务端必须重推一帧对话（本条存在理由）============
	var 本次: Array = _对话记录.slice(帧数前)
	print("② 这一趟收到的对话帧：")
	for i in 本次.size():
		var 帧: Dictionary = 本次[i]
		print("   [%d] npc=%s 菜单 %d 条 player_text=「%s」 行=%s" % [i, 帧["npc_id"],
				int(帧["菜单"]), String(帧["player_text"]), JSON.stringify(帧["行"])])
	var 重推: Dictionary = {}
	for 帧 in 本次:
		if int(帧["npc_id"]) != 交付模板:
			continue
		if String(帧["player_text"]) != "-":
			continue
		## ⚠ 这里必须读**存进快照的那个键**（`_记帧` 把行号存成 `"行"`）——
		##   第一版这里写成 `_行号(帧)`，那是给**原始 last_npc_dialog** 用的函数、要读 `"selection"` 键，
		##   拿它读快照恒得空数组 ⇒ 屏幕上明明印出了 `[3] 行=["1006"]`、判据还说没推（量具坏，不是游戏坏）。
		if (帧["行"] as Array).has(下一环):
			重推 = 帧
	_判(交掉了 and 重推.is_empty() == false,
			"交完 1003 之后服务端**没有**再推一帧带 1006 的对话（player_text=- 那一类一条都没有）"
			+ " ⇒ 客户端对话窗不会弹，玩家要自己再点一次 NPC —— 用户 2026-10-10 报的就是这个")
	## 「和手动点 NPC 同形」这一条为什么要判：重推帧与首帧都是服务端 `_send_current_npc_dialog`
	## 造的（菜单段非空 = 有「离开」那一类服务行），客户端 `show_npc_dialog` 拿到同一种帧
	## 就走同一条渲染分支 ⇒ 窗里长什么样不需要我再证明一遍，要证明的是「帧到了、且是同一种帧」。
	var 首帧: Dictionary = 本次[0] if 本次.size() > 0 else {}
	_判(重推.is_empty() or (not 首帧.is_empty() and int(重推["菜单"]) == int(首帧["菜单"]) and int(重推["菜单"]) > 0),
			"重推帧的菜单段与首帧不同形（首帧 %d 条 / 重推 %d 条）⇒ 客户端会画成另一种窗" % [
				int(首帧.get("菜单", -1)), int(重推.get("菜单", -1))])
	# 反向：重推那一帧只许带**这枚 NPC 自己的**任务行，别把别的 NPC 的任务塞进来
	if not 重推.is_empty():
		for 号 in (重推["行"] as Array):
			var 下下 := int(号)
			if 下下 <= 0:
				continue
			var 属 := _任务属不属于这枚NPC(下下, 交付模板)
			_判(属, "重推帧里混进了 %s —— 它跟 NPC 模板 %d 无关（发或交都不在这枚）" % [str(号), 交付模板])
	# 台词帧不该被误当成重推：作者台词那一帧的 player_text 一定不是 `-`
	var 台词帧 := 0
	for 帧 in 本次:
		if String(帧["player_text"]) != "-":
			台词帧 += 1
	_判(台词帧 >= 1, "这一趟一条作者台词帧都没有（翻了 %d 句？）⇒ 没法把「重推帧」和「台词帧」分开判" % 翻)

	print("")
	if _发现.is_empty():
		print("交付后自动弹对话在线回归测试：通过（判 %d 条 / 红 0，交付生效 + 服务端重推带 %s 的对话帧）" % [_判数, 下一环])
		_还原设置()
		_backend.disconnect_backend()
		quit(0)
		return
	for 项 in _发现:
		push_error("交付后对话：%s" % 项)
	print("交付后自动弹对话在线回归测试：判 %d 条 / 红 %d 处 —— %s" % [_判数, _发现.size(), " | ".join(_发现)])
	_还原设置()
	_backend.disconnect_backend()
	quit(1)


## 这条任务的「发」或「交」有一头挂在这枚 NPC 上吗（重推帧的任务行就该只含本枚 NPC 的）。
func _任务属不属于这枚NPC(编号: int, 模板: int) -> bool:
	var 定: Dictionary = _表.get(str(编号), {})
	if 定.is_empty():
		return false
	var n: Dictionary = 定.get("npc", {}) as Dictionary
	return int(n.get("0", -1)) == 模板 or int(n.get("1", -1)) == 模板


## 只还原自己动过的那一个键，别顺手整份覆盖 `game_settings`。
func _还原设置() -> void:
	if _原端口 < 0:
		return
	var 设置: Dictionary = _会话.get("game_settings")
	设置["backend_port"] = _原端口


func _判(条件: bool, 消息: String) -> void:
	_判数 += 1
	if not 条件:
		_发现.append(消息)


func _本图NPC() -> String:
	var 出: Array[String] = []
	for 号 in _backend.map_npcs:
		出.append(str((_backend.map_npcs[号] as Dictionary).get("npc_id")))
	return ", ".join(出)
