extends SceneTree
## 组队族的**在线端到端**门：两个真号连本机夹具服务端，走完整条链。
##
## 为什么必须有这一道：`队伍页回归测试.gd` 是**离线**门（喂帧、判画法），照不到
## "服务端到底发不发那一发、发给谁"。用户铁律：每一项"做完"= 点它有请求 + 服务端回帧 + 画面有变化。
##
## 跑的真链（每步判三件：帧发得出去 ⇒ 对面收得到 ⇒ 我方屏幕上画出来）：
##   主号 `120:1` 建队                ⇒ 主 `authoritative_party.id > 0`
##   主号 `120:4:<对名>` 邀请         ⇒ **对面**收 `59:4`（只进托盘，不弹窗）
##   对面 `120:3:<队号>` 接受         ⇒ 两边 members=2、leader=主号
##   打开「组队」页                   ⇒ 第 1 格 = 主名（队长浮首）、第 2 格 = 对名
##   左侧血蓝面板                     ⇒ 出现、且**不含自己**（格数 1）
##   主号 `120:6:<对号>` 移交队长     ⇒ 主 `队长号`=对号；页里两格**内容互换**（队长永远第 1 格）
##   对面 `120:5:<主号>` 请离         ⇒ 主被踢 ⇒ 成员清空、面板撤掉
##   对面 `120:2` 退队                ⇒ 队散
##
## ⚠ 三条口径：
##   · 两个号都登录 ⇒ `user://玩家数据.json` 会被写 ⇒ **按字节快照 + 还原 + 断言**；
##   · 客户端只认 `game_settings.backend_port`（缺省 18684 = 用户自己那台）⇒ 必须改这一键并还原；
##   · 监听要接在**收帧的那一端**（邀请只发给被邀请者），接错端会整条连带红。
##
## 跑法：`PowerShell -File 开发工具\跑在线用例.ps1 -用例 组队`
## （夹具给独立端口 18718/18719，并自带第二个账号 `naruto/123456` 与 `NW_SOCIAL_PEER_ID`）

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 队伍窗 := preload("res://脚本/界面/窗口/组队/队伍窗.gd")
const 队伍面板 := preload("res://脚本/界面/窗口/组队/队伍面板.gd")
const 管理场景 := "res://场景/界面/窗口管理.tscn"
const PEER_ACCOUNT := "naruto"
const PEER_PASSWORD := "123456"
const 存档路 := "user://玩家数据.json"

var _主: Node = null
var _对: Node = null
var _会话: Node = null
var _管理: Node = null
var _对管理: Node = null
var _对编号 := 0
var _原端口 := -1
var _失败: Array = []
var _对收: Array = []
var _主收: Array = []
var _主提示: Array = []
var 存档前 := PackedByteArray()
var 本来有存档 := false


func _initialize() -> void:
	call_deferred("_跑")


func _记(过: bool, 文: String) -> void:
	print(("  ok  " if 过 else "  ✗  ") + 文)
	if not 过:
		_失败.append(文)


func _等秒(秒: float, 条件: Callable) -> bool:
	var 起 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 起 < int(秒 * 1000.0):
		if 条件.call():
			return true
		await create_timer(0.1).timeout
	return 条件.call()


func 拍快照() -> void:
	本来有存档 = FileAccess.file_exists(存档路)
	if 本来有存档:
		存档前 = FileAccess.get_file_as_bytes(存档路)


func 还原存档() -> void:
	if 本来有存档:
		var f := FileAccess.open(存档路, FileAccess.WRITE)
		if f != null:
			f.store_buffer(存档前)
			f.close()
	elif FileAccess.file_exists(存档路):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
	var 后 := FileAccess.get_file_as_bytes(存档路) if FileAccess.file_exists(存档路) else PackedByteArray()
	print("  ok  存档还原（%d 字节，前后一致=%s）" % [后.size(), str(本来有存档 and 后 == 存档前 or (not 本来有存档 and 后.is_empty()))])


func 还原端口() -> void:
	var 设置: Dictionary = _会话.get("game_settings")
	设置["backend_port"] = _原端口


func _页() -> Control:
	## ⚠ 宿主的回帧路径会**重建整页**（同一族坑 #312）⇒ 手里那个 `页` 可能已被 free。
	## 一律现取 `队伍窗.页`，别缓存。
	return 队伍窗.页


func _收对端(state: Dictionary) -> void:
	_对收.append(state.get("action", -1))


func _收主端(state: Dictionary) -> void:
	_主收.append(state.get("action", -1))


func _收主提示(文: String) -> void:
	_主提示.append(文)


func _跑() -> void:
	拍快照()
	_主 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _主 == null or _会话 == null:
		_记(false, "缺 BackendConnection / GameSession 单例")
		quit(1)
		return
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18718
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_对编号 = int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	print("连夹具端口 %d；对面那个号 = %d（账号 %s）" % [口, _对编号, PEER_ACCOUNT])
	if _对编号 <= 0:
		_记(false, "夹具没给 NW_SOCIAL_PEER_ID ⇒ 没有第二个号")
		quit(1)
		return

	_主.sync_character()
	if not await _等秒(20.0, func() -> bool: return bool(_主.in_game)):
		_记(false, "主号进不了游戏（%s - %s）" % [_主.status, _主.detail])
		收拾并退出()
		return
	var 我号 := int(_主.character_id)
	var 我名 := String((_会话.get("player_stats") as Dictionary).get("name", ""))
	_记(我名 != "", "主号名字取到「%s」" % 我名)

	_管理 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(_管理)
	await create_timer(0.4).timeout

	_对 = BACKEND_SCRIPT.new()
	_对.name = "组队在线对面那个号"
	root.add_child(_对)
	_对.connect("party_state_received", Callable(self, "_收对端"))
	_主.connect("party_state_received", Callable(self, "_收主端"))
	if _主.has_signal("server_message_received"):
		_主.connect("server_message_received", Callable(self, "_收主提示"))
	_对.connect_backend(PEER_ACCOUNT, PEER_PASSWORD, false)
	## ⚠ `connect_backend` 没有返回值（交易在线门也是不判返回值的）⇒ **不许**拿返回值当失败判据；
	##   真正的判据是下面 `authenticated` 那个等待。
	if not await _等秒(10.0, func() -> bool: return bool(_对.authenticated)):
		_记(false, "第二个号登录不上（夹具里有没有 %s？）" % PEER_ACCOUNT)
		收拾并退出()
		return
	if not bool(_对.select_character(_对编号)):
		_记(false, "第二个号选不上角色 %d" % _对编号)
		收拾并退出()
		return
	if not await _等秒(20.0, func() -> bool: return bool(_对.in_game) and int(_对.character_id) == _对编号):
		_记(false, "第二个号进不了游戏（%s - %s）" % [_对.status, _对.detail])
		收拾并退出()
		return
	var 对名 := ""
	if _对.has_method("自身名"):
		对名 = String(_对.call("自身名"))
	if 对名 == "":
		var 档: Dictionary = (_对.get("authoritative_stats") as Dictionary)
		对名 = String(档.get("name", ""))
	if 对名 == "":
		_记(false, "拿不到对面的名字")
		收拾并退出()
		return
	_记(true, "第二个号进图：%s（%d）" % [对名, _对编号])
	## ★ 对面也必须有 `窗口管理`：托盘格是它下面的节点，没有它就只能证明"后端收到帧"，
	##   证明不了"玩家看得见"。用户实机报的正是"对面什么都没看到"。
	_对管理 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(_对管理)
	## `窗口管理._ready` 里挂的是**全局那份**后端；对端是另一个实例 ⇒ 这里手动挂它的
	if _对管理.has_method("_ready"):
		pass
	队伍窗.挂全局(_对)
	await create_timer(0.4).timeout

	# ① 建队：`120:1` 不带参数（`PacketCreator.getCreatePartyRequestPacket:342-347`）
	_记(bool(_主.call("request_party", 1)), "主号发出 `120:1` 建队")
	if not await _等秒(6.0, func() -> bool: return int((_主.get("authoritative_party") as Dictionary).get("id", 0)) > 0):
		_记(false, "服务端没回建队那一帧（authoritative_party.id 还是 0）")
		收拾并退出()
		return
	var 队号 := int((_主.get("authoritative_party") as Dictionary).get("id", 0))
	_记(true, "服务端建队成功，队号 %d" % 队号)

	# ② 邀请：`120:4:<对名>` ⇒ **对面**收 `59:4`
	_对收.clear()
	_记(true, "主号准备发 `120:4:<%s>`（短重试直到服务端认到）" % 对名)
	## ⚠ 对面「客户端已进图」不等于「服务端 hub 已把它登记进 `sessions_by_character`」：
	##   实测同一条用例会时好时坏（主号偶尔收到 18 没找到该玩家）⇒ 这里按玩家真实操作
	##   **短重试 6 次（0.5s 一次）**，并把"第几次才成功"记进判据 —— 成功太晚说明服务端登记慢。
	var 第几次 := 0
	for i in 6:
		第几次 = i + 1
		_主.call("request_party", 4, 对名)
		if await _等秒(1.2, func() -> bool: return _对收.has(4)):
			break
	var 到了: bool = _对收.has(4)
	if 到了 and 第几次 > 1:
		print("  （提示）邀请第 %d 次才被服务端认到（前几次回了 18）" % 第几次)
	if not 到了:
		## 诊断腿：服务端 `session_for_name:10013-10023` 是按**角色名** casefold 精确匹配的。
		## 主号收到 18（NOT_FIND_CHAR）⇒ 客户端手里的这个名字不是服务端注册的那个。
		## 再拿**账号名**试一次，用来区分「名字不对」与「服务端根本没注册这个会话」。
		print("  （诊断）按角色名「%s」没找到，改用账号名「%s」再试一次" % [对名, PEER_ACCOUNT])
		_主收.clear()
		_主.call("request_party", 4, PEER_ACCOUNT)
		到了 = await _等秒(6.0, func() -> bool: return _对收.has(4))
		if 到了:
			_记(false, "邀请只能用**账号名**「%s」找到人（角色名「%s」查无）——服务端按角色名匹配这条不通"
				% [PEER_ACCOUNT, 对名])
	if not 到了:
		_记(false, "对面没收到 `59:4` 邀请帧（对面收到 %s / 主号收到 %s / 主号提示 %s）"
			% [str(_对收), str(_主收), str(_主提示)])
		收拾并退出()
		return
	_记(true, "对面收到 `59:4` 邀请")
	var 对盘 := root.find_child("邀请托盘", true, false)
	var 盘格数 := int(对盘.call("数量")) if 对盘 != null else -1
	_记(盘格数 == 1, "对面**托盘里出现 1 格组队邀请**（实测 %d）" % 盘格数)
	## ⚠ 数量对不等于点得对：托盘格的数据必须来自真 `59:4` 解析。
	##   只判"有 1 格"时，后端把 party_id/inviter_name 忘在 state["invite"] 里也能全绿，
	##   而实机是弹窗空名字 + 确定发 `120:3:0`（队伍进不去）。
	var 盘格们: Dictionary = 对盘.call("格们") if 对盘 != null else {}
	var 邀请件: Node = 盘格们.values()[0] if not 盘格们.is_empty() else null
	var 邀据: Dictionary = (邀请件.get("数据") as Dictionary) if 邀请件 != null else {}
	_记(int(邀据.get("troopId", 0)) == 队号 and String(邀据.get("captainName", "")) == 我名,
		"对面托盘格拿到真队号/真邀请人（不是 0/空）：%s" % str(邀据))

	# ③ 接受：`120:3:<队号>` ⇒ 两边 members=2、leader=主号
	_记(bool(_对.call("request_party", 3, 队号)), "对面发出 `120:3:<%d>`" % 队号)
	var 两队 := func() -> bool:
		var a: Array = (_主.get("authoritative_party") as Dictionary).get("members", [])
		var b: Array = (_对.get("authoritative_party") as Dictionary).get("members", [])
		return a.size() == 2 and b.size() == 2
	if not await _等秒(8.0, 两队):
		_记(false, "两边成员数没到 2（主 %d / 对 %d）" % [
			(_主.get("authoritative_party") as Dictionary).get("members", []).size(),
			(_对.get("authoritative_party") as Dictionary).get("members", []).size()])
		收拾并退出()
		return
	_记(true, "两边都收到 2 人队伍")
	_记(int((_主.get("authoritative_party") as Dictionary).get("leader_id", 0)) == 我号,
		"主号是队长（leader_id=%d）" % int((_主.get("authoritative_party") as Dictionary).get("leader_id", 0)))

	# ④ 开页：队长浮到第 1 格（原版 setData 两次 sortOn）
	_管理.call("打开", "组队")
	await create_timer(1.2).timeout
	if 队伍窗.页 == null or not is_instance_valid(队伍窗.页):
		_记(false, "「组队」页没被建出来（队伍窗.页 为空）")
		收拾并退出()
		return
	_记(队伍窗.成员.size() == 2, "页里 2 个成员（%d）" % 队伍窗.成员.size())
	_记(String((_页().get_node("内容区/我的队伍/成员格1/名字") as Label).text) == 我名,
		"第 1 格是队长自己：%s" % (_页().get_node("内容区/我的队伍/成员格1/名字") as Label).text)
	_记(String((_页().get_node("内容区/我的队伍/成员格2/名字") as Label).text) == 对名,
		"第 2 格是对面：%s" % (_页().get_node("内容区/我的队伍/成员格2/名字") as Label).text)
	_记(String((_页().get_node("内容区/我的队伍/成员格1/队长") as Label).text) == "队长",
		"「队长」两字在队长那一格")
	# ⑤ 左侧血蓝面板：出现，且**不含自己**
	_记(队伍面板.出现着(), "左侧血蓝面板出现了")
	_记(队伍面板.格数() == 1, "面板只有 1 格（filterMyself 不含自己，实测 %d）" % 队伍面板.格数())
	_记(队伍面板.找格(_对编号) != null, "面板里那一格是对面（%d）" % _对编号)

	# ⑥ 移交队长：`120:6:<对号>` ⇒ 队长号改、两格内容互换（队长仍第 1 格）
	_对收.clear()
	_记(bool(_主.call("request_party", 6, _对编号)), "主号发出 `120:6:<%d>` 移交" % _对编号)
	if not await _等秒(6.0, func() -> bool: return 队伍窗.队长号 == _对编号):
		_记(false, "移交没生效（队长号还是 %d）" % 队伍窗.队长号)
	else:
		_记(true, "移交生效：队长号 = %d" % 队伍窗.队长号)
		await create_timer(0.5).timeout
		_记(String((_页().get_node("内容区/我的队伍/成员格1/名字") as Label).text) == 对名,
			"第 1 格换成了新队长：%s" % (_页().get_node("内容区/我的队伍/成员格1/名字") as Label).text)
		_记(String((_页().get_node("内容区/我的队伍/成员格2/名字") as Label).text) == 我名,
			"第 2 格换成了原队长：%s" % (_页().get_node("内容区/我的队伍/成员格2/名字") as Label).text)

	# ⑦ 主号（此刻不是队长）退队：`120:2` ⇒ 2 人队剩 1 人 ⇒ 服务端整队解散。
	#    离队者收 14（targetId == 自己 ⇒ 清空），队长收 12（`onPartyDisband` ⇒ 清空）。
	_主收.clear()
	_对收.clear()
	_记(bool(_主.call("request_party", 2)), "主号发出 `120:2` 退队")
	if not await _等秒(8.0, func() -> bool: return 队伍窗.成员.is_empty()):
		_记(false, "主号退队后页里还有 %d 个成员（主号收到 %s / 对面收到 %s）"
			% [队伍窗.成员.size(), str(_主收), str(_对收)])
	else:
		_记(true, "主号退队后自己那侧清空")
		_记(not 队伍面板.出现着(), "左侧面板跟着撤掉")
	_记(int((_对.get("authoritative_party") as Dictionary).get("id", 0)) == 0,
		"对面（队长）那侧也跟着清空：2 人队剩 1 人 ⇒ 解散（对面收到 %s）" % str(_对收))

	# ⑧ 重新建队 + 邀请 + 接受，再测「队长踢人」：2 人队被踢 ⇒ 两边都清
	_主.call("request_party", 1)
	if not await _等秒(6.0, func() -> bool:
			return int((_主.get("authoritative_party") as Dictionary).get("id", 0)) > 0):
		_记(false, "重新建队没成功（主号 authoritative_party=%s）" % str(_主.get("authoritative_party")))
		收拾并退出()
		return
	var 新队号 := int((_主.get("authoritative_party") as Dictionary).get("id", 0))
	_记(true, "重新建队成功，队号 %d" % 新队号)
	_对收.clear()
	for i in 6:
		_主.call("request_party", 4, 对名)
		if await _等秒(1.2, func() -> bool: return _对收.has(4)):
			break
	if not _对收.has(4):
		_记(false, "重新邀请对面没收到 `59:4`（对面收到 %s）" % str(_对收))
		收拾并退出()
		return
	_对.call("request_party", 3, 新队号)
	if not await _等秒(8.0, func() -> bool:
			var 包: Dictionary = _对.get("authoritative_party") as Dictionary
			return int(包.get("id", 0)) == 新队号 and int(包.get("leader_id", 0)) == 我号):
		_记(false, "重新组队没成（对面 authoritative_party=%s）" % str(_对.get("authoritative_party")))
		收拾并退出()
		return
	_主收.clear()
	_对收.clear()
	_记(bool(_主.call("request_party", 5, _对编号)), "主号（队长）发出 `120:5:<%d>` 请离" % _对编号)
	if not await _等秒(8.0, func() -> bool:
			return int((_对.get("authoritative_party") as Dictionary).get("id", 0)) == 0):
		_记(false, "对面被踢后队伍没清（对面收到 %s / 主号收到 %s）" % [str(_对收), str(_主收)])
	else:
		_记(true, "对面被踢后队伍清空")
	if not await _等秒(8.0, func() -> bool: return 队伍窗.成员.is_empty()):
		_记(false, "踢人后队长那侧还挂着 %d 个成员（主号收到 %s）"
			% [队伍窗.成员.size(), str(_主收)])
	else:
		_记(true, "队长那侧也跟着清空：2 人队剩 1 人 ⇒ 解散")

	# ⑨ 队友掉线但没退队：服务端保留名单、把那一行发成 channelIndex=-2 ⇒ 左边头像灰
	_主.call("request_party", 1)
	if not await _等秒(6.0, func() -> bool:
			return int((_主.get("authoritative_party") as Dictionary).get("id", 0)) > 0):
		_记(false, "掉线用例前重新建队没成功")
		收拾并退出()
		return
	var 灰队号 := int((_主.get("authoritative_party") as Dictionary).get("id", 0))
	_对收.clear()
	for i in 6:
		_主.call("request_party", 4, 对名)
		if await _等秒(1.2, func() -> bool: return _对收.has(4)):
			break
	if not _对收.has(4):
		_记(false, "掉线用例邀请没收到 `59:4`（对面收到 %s）" % str(_对收))
		收拾并退出()
		return
	_对.call("request_party", 3, 灰队号)
	if not await _等秒(8.0, func() -> bool:
			var 包: Dictionary = _对.get("authoritative_party") as Dictionary
			return int(包.get("id", 0)) == 灰队号 and int(包.get("leader_id", 0)) == 我号):
		_记(false, "掉线用例重新组队没成")
		收拾并退出()
		return
	_主收.clear()
	_记(true, "掉线用例：两人已在队（队号 %d）" % 灰队号)
	## 真断线：关掉第二个号的连接（不发行 120:2），服务端应当保留名单并广播离线状态。
	_对.call("disconnect_backend")
	_对.queue_free()
	var 掉线标记 := await _等秒(10.0, func() -> bool:
		for 行 in 队伍窗.成员:
			if int((行 as Dictionary).get("id", 0)) == _对编号:
				return not bool((行 as Dictionary).get("在线", true))
		return false)
	_记(掉线标记, "队友掉线后仍留在名单里、标记为离线（主号收到 %s）" % str(_主收))
	var 灰格 := 队伍面板.找格(_对编号)
	var 灰盒 := (灰格.get_node("头像盒") as Control) if 灰格 != null else null
	_记(灰盒 != null and 灰盒.material != null,
		"左侧面板那一格头像变灰（格=%s / 材质=%s）" % ["有" if 灰格 != null else "无",
		str(灰盒.material) if 灰盒 != null else "无"])
	_主.call("request_party", 2)
	await _等秒(6.0, func() -> bool: return 队伍窗.成员.is_empty())

	收拾并退出()


func 收拾并退出() -> void:
	await create_timer(0.2).timeout
	if _管理 != null and is_instance_valid(_管理):
		_管理.queue_free()
	if _对 != null and is_instance_valid(_对):
		_对.queue_free()
	还原端口()
	还原存档()
	print("组队在线门：%s（红 %d 条）" % ["全过" if _失败.is_empty() else "有红", _失败.size()])
	for t in _失败:
		print("  ✗ " + t)
	quit(0 if _失败.is_empty() else 1)
