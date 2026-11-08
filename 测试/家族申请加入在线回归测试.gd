extends SceneTree

## 家族列表窗「申请加入」的**端到端**在线用例。
##
## 走的是真链路，一环都不替身：
##   服务端 `1552:3` 的 12 字段行 → `后端连接._handle_guild_text` action 3
##   → `家族列表窗.从后端刷新` 建行 → `_选中(0)` → 按「申请加入」
##   → `家族列表窗._发动作` → `功能窗口._show_guild_action` → `_发申请加入`
##   → `后端连接.request_guild_apply`（`1552:2:<家族id>`）→ 服务端 `request_family_join`
##   → 1552:15 家族摘要 → `authoritative_guild.joined`。
##
## 夹具给的前提（`本地服务端夹具.seed_peer_family`）：**同伴**名下有族、**主角色没入族** ——
## 这正是这条链唯一走得通的初始态（原版 `FamillyManager.joinFamilly` 第一句就是
## `myFamillyInfo.id != 0` ⇒ 只提示、不申请）。
##
## ⚠️ 家族 id 的两种写法都会静默错（§3.64.3 病根五）：行里的是**整数形态**，
##    这里钉的是服务端 `families()` 里的那个 id，不是补零后的字符串。

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")

var _后端
var _会话
var _宿主: Node
var _页: Control
var _通知: Array[String] = []
## 无头用例里**不要 pull**：拉帧会喂给非真窗的输入，`pressed` 信号要 precache 的
## 子资源（字体的位图）没加载，触发时崩在 `Font.draw`。见下面 `on_pressed` 的注释。
var _按钮信号: Signal


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _后端 == null or _会话 == null:
		_fail("缺少 BackendConnection/GameSession 单例")
		return
	var 家族id := int(OS.get_environment("NW_PEER_FAMILY_ID"))
	var 家族名 := OS.get_environment("NW_PEER_FAMILY_NAME")
	if 家族id <= 0 or 家族名.is_empty():
		_fail("夹具没给同伴家族（NW_PEER_FAMILY_ID=%d NW_PEER_FAMILY_NAME=%s）"
			% [家族id, 家族名])
		return

	_会话.notification_requested.connect(func(文本: String) -> void: _通知.append(文本))
	_后端.sync_character()
	if not await _等待(func(): return bool(_后端.in_game), 15000):
		_fail("主角色无法进入真实后端：%s - %s" % [_后端.status, _后端.detail])
		return
	if bool((_会话.guild as Dictionary).get("joined", false)):
		_fail("前提不成立：主角色一开始就已经在家族里了")
		return

	# ── ① 服务端列表行 → 权威列表 ────────────────────────────────────
	if not _后端.request_guild_list():
		_fail("家族列表请求未发送")
		return
	if not await _等待(func(): return _找行(家族id) != null, 5000):
		_fail("服务端家族列表里没有同伴那个族（id=%d）" % 家族id)
		return
	var 行: Dictionary = _找行(家族id)
	# 这 12 个字段是服务端 `handle_banghui` action 101 逐个写出来的，
	# 断言它们 == 断言"客户端没读错位"。等级总和/本周击杀 BOSS 两列以前压根没解析。
	# 等级总和 = 该族成员等级和（同伴 1 级 ⇒ 1）；人数上限 50 是服务端写死的字面量。
	if String(行.get("name", "")) != 家族名:
		_fail("列表行的家族名不对：%s" % 行.get("name", ""))
		return
	if int(行.get("capacity", 0)) != 50 or int(行.get("level_sum", -1)) != 1 \
			or int(行.get("flag_level", 0)) != 1 or String(行.get("flag_name", "")) != "同伴旗帜":
		_fail("列表行读错了位（期 capacity=50/level_sum=1/flag_level=1/flag_name=同伴旗帜）：%s" % [行])
		return

	# ── ② 真窗：经窗壳开出来，装配把 `social_changed` 挂上 ──────────
	_宿主 = (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(_宿主)
	await create_timer(0.1).timeout
	壳.切换(_宿主, "家族列表窗", "家族列表", true)
	_页 = 壳.取内容(_宿主, "家族列表窗")
	if _页 == null:
		_fail("窗壳没开出家族列表窗（壳里记的表里没有「家族列表窗」）")
		return
	# ⚠️ **精确钉住这个脚本**：`取内容` 万一取到窗壳那张 Panel（有壳时它会被移到 0 号位），
	#    `_家族表` 会从 Control 上报错、而不是静默当成"列表空"。
	if not (_页.get_script() as Script).resource_path.ends_with("家族列表窗.gd"):
		_fail("取到的不是家族列表窗内容页，而是 %s（%s）" % [_页.name, _页.get_class()])
		return
	# `装配` 里调的 `从后端刷新` 是同步的：开出来的当帧就该有行。
	if (_页.get("_家族表") as Array).is_empty():
		_fail("家族列表窗开着但没有行（权威列表 %d 条）"
			% (_后端.authoritative_guild_list as Array).size())
		return
	if not _选中并检查(家族id):
		return

	# ── ④ 服务端真的把我们加进去了 ────────────────────────────────
	# 先打一发**无副作用的探针**：给一个不存在的家族 id 发同样的 action 2。
	# 服务端 `request_family_join` 查不到那个族就什么都不做（family is None ⇒ "invalid"），
	# 返回值却能证明"这条桥是通的" —— 否则按钮那一步失败时，
	# `_send_bridge_request` 的静默 `return false` 会让人以为是宿主/动作串没接上。
	if not _后端.request_guild_apply(999999):
		_fail("探针：request_guild_apply 返回 false（桥路不通，in_game=%s）" % bool(_后端.in_game))
		return
	_按申请加入()
	if not await _等待(func(): return bool(_后端.authoritative_guild.get("joined", false)), 6000):
		_fail("发了 1552:2 之后服务端没有把主角色加进家族（authoritative_guild=%s，通知=%s）"
			% [_后端.authoritative_guild, _通知])
		return
	if String(_后端.authoritative_guild.get("name", "")) != 家族名 \
			or int(_后端.authoritative_guild.get("id", 0)) != 家族id:
		_fail("加入的家族不对：%s" % [_后端.authoritative_guild])
		return

	# ── ⑤ 入族之后：「申请加入」自己变灰（`FL:123-133` 的 `init()`）─────
	# 这是"刷新路径也吃到了结果"的证据：灰态不是开窗时算死的，是随家族态重画的。
	if not await _等待(func(): return _钮灰(), 3000):
		_fail("入族后「申请加入」没有变灰（FL:123-133 要求 myFamillyInfo.id != 0 时禁用）")
		return
	_页.call("从后端刷新")			# 让宿主把灰态重算一遍
	if not _钮灰():
		_fail("重刷之后「申请加入」又亮了")
		return
	# ⚠️ 重刷会**清掉选中**（`刷新` 把 `_选中序` 置 -1，原版 `list.dataProvider = ...`
	#    同样清 `selectedItem`）—— 所以下面的直调要先把那行重新选上，否则宿主的
	#    第一条拦截（没选中 ⇒ 静默）就先命中了，测不到"已有家族"那条。
	if not _选中并检查(家族id):
		return
	# 再把"已有家族还硬点"那条路走一遍：宿主自己的拦截也要给出提示（FM:769-777）。
	# ⚠️ 这里**直调宿主**是故意的 —— 钮已经灰了，玩家根本点不到它；
	#    要测的是"万一动作串进来了，宿主会不会只提示、不发第二发协议"。
	var 通知数 := _通知.size()
	_宿主.call("_发申请加入")
	if _通知.size() == 通知数:
		_fail("已有家族时走申请加入应当提示「很抱歉，你已经有家族了！」，实际一条通知都没有")
		return

	print("家族申请加入在线回归测试：通过（12 字段行 → 行选中 → 申请加入 → 服务端真加入 → 入族后置灰）")
	_后端.disconnect_backend()
	quit(0)


func _钮灰() -> bool:
	var 钮 := _页.get_node_or_null("申请加入") as TextureButton
	return 钮 != null and 钮.disabled


## 选中 id 那一行，并核对「选中家族()」取到的就是它。
func _选中并检查(家族id: int) -> bool:
	var 序号 := -1
	var 表 := _页.get("_家族表") as Array
	for i in 表.size():
		if int((表[i] as Dictionary).get("id", 0)) == 家族id:
			序号 = i
			break
	if 序号 < 0:
		_fail("列表窗里找不到 id=%d 那一行" % 家族id)
		return false
	_页.call("_选中", 序号)
	var 选 := _页.call("选中家族") as Dictionary
	if int(选.get("id", 0)) != 家族id:
		_fail("选中的行不是 id=%d 那个族（选中=%s）" % [家族id, 选])
		return false
	return true


## 扣一次「申请加入」——就是玩家的那一下（`pressed` 信号）。
func _按申请加入() -> void:
	var 钮 := _页.get_node("申请加入") as TextureButton
	if 钮.disabled:
		_fail("没入族时「申请加入」不该是灰的（FL:123-133 只在有族时禁）")
		return
	if 钮.pressed.get_connections().is_empty():
		_fail("「申请加入」钮没有接线（装配没跑到？）")
		return
	钮.pressed.emit()


func _找行(家族id: int) -> Variant:
	for 项 in (_后端.authoritative_guild_list as Array):
		if int((项 as Dictionary).get("id", 0)) == 家族id:
			return 项
	return null


func _等待(条件: Callable, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while not 条件.call() and Time.get_ticks_msec() < 截止:
		await create_timer(0.05).timeout
	return true if 条件.call() else false


func _fail(说明: String) -> void:
	push_error("家族申请加入在线回归测试：失败 - %s" % 说明)
	if _后端 != null:
		_后端.disconnect_backend()
	quit(1)
