extends SceneTree

## 家族入族审批 + 成员管理接线回归门（2026-11-08，B）。
##
## 第一扇 `家族成员管理回归测试.gd` 钉的是**数据解码 + 成员页版式/排序/分页**；
## 本门钉的是**从帧到发包这一整条线**，也就是玩家真正点得动的那几颗：
##
## ① 入族申请 `1552:8` ⇒ 托盘 TYPE_FAMILY_APPLY(6) 一格（图标/提示/按 charId 去重），
##    点格开**同一扇**「邀请入族」页壳的审核档（标题「申请入族」、主钮「批准入族」），
##    批准 ⇒ `1552:14:<申请人角色号>`、拒绝 ⇒ `1552:13:<申请人角色号>`。
##    ⚠ 这一档带的是**申请人角色号**，不是家族号（邀请档才带家族 id）。
## ② 家族页「成员信息」⇒ 开成员窗 + 拉一次 `1552:105:<族号>`（详细 17 字段）。
## ③ 成员行菜单：查看资料 `94:0:<号>`、加为好友 `127:1:<号>`、任命五档 `1552:17:<号>:<rank>`、
##    禅让确认后 `1552:18:<号>`、开除确认后 `1552:4:<号>`。
## ④ 权限/空号闸：族长不能对自己做管理操作；查看离线只提示；弹劾要求非族长 + 在线 + 弹劾令。
## ⑤ 自动同意复选框 ⇒ `1552:20:<0|1>`；解散/退出确认后 `1552:5` / `1552:6`。
##
## 口径：摘掉真 `/root/BackendConnection`、换 `测试/测试后端连接.gd`（继承真后端、只记不发），
## 所以每条上行的 opcode + 报文字节都能逐字比；跑完换回。有看门狗与"跑完了"哨兵。
##
## 运行：`Godot --headless --path . --script res://测试/家族入族审批与成员动作回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 功能窗口场景 := "res://场景/界面/功能窗口.tscn"
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 码家族 := 1552
const 码资料 := 94
const 码好友 := 127
const 申请图标 := "res://素材/界面/原版窗口/通用控件/托盘_家族邀请.png"
const 弹劾令 := 15019001

var _通过 := 0
var _失败: Array[String] = []
var _通知们: Array[String] = []
var _后
var _管: Node
var _窗: Node
var _跑完了 := false
var _帧数 := 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_跑")


## 看门狗：脚本报错会让 `_跑` 停在某个 await 上、quit 永远不来（门挂死 = 假绿）
func _process(_d: float) -> bool:
	_帧数 += 1
	if _帧数 > 900 and not _跑完了:
		_失败.append("门 900 帧内没跑完（中途报错停在 await 上？）")
		_收尾()
	return _帧数 > 900


func _判(对: bool, 明: String) -> void:
	if 对:
		_通过 += 1
	else:
		_失败.append(明)


func _帧() -> Array[String]:
	var 出: Array[String] = []
	for 条 in _后.sent_requests:
		出.append("%d:%s" % [int((条 as Dictionary).get("opcode", 0)),
			String((条 as Dictionary).get("content", ""))])
	return 出


func _清() -> void:
	_后.sent_requests.clear()
	_通知们.clear()


func _有提示(关键词: String) -> bool:
	for 字 in _通知们:
		if String(字).contains(关键词):
			return true
	return false


func _收(原文: String) -> void:
	_后.call("_handle_bridge_text", 原文)


## 用例之间把确认弹都取消掉，免得上一段挡住下一段的"只在未开时开"。
func _收弹(宿主: Node) -> void:
	宿主.call("_show_guild_action", "家族确认弹:取消")
	await process_frame
	await process_frame


## 取内容页。两种宿主两套挂法：
##   ① 普通功能窗口（「家族邀请」＝页壳）：页挂在 `_content` 下、节点名 = 场景根名；
##   ② 家族子窗壳：`家族子窗_<窗名>` 这一层挂在 `_overlay` 下。
func _内容(宿主: Node, 根名: String) -> Control:
	var 内容 := 宿主.get("_content") as Control
	if 内容 != null:
		for 子 in 内容.get_children():
			if String((子 as Node).name) == 根名:
				return 子 as Control
	var 遮罩 := 宿主.get("_overlay") as Control
	if 遮罩 == null:
		return null
	var 根 := 遮罩.get_node_or_null(根名) as Control
	if 根 == null:
		return null
	for 子 in 根.get_children():
		if String((子 as Node).name) == "窗壳":
			continue
		return 子 as Control
	return null


## 页里的钮是 `TextureButton`，确认弹里的钮是普通 `Button` ⇒ 一律按 `BaseButton` 收。
func _点(钮: Node) -> void:
	if 钮 != null:
		(钮 as BaseButton).pressed.emit()


## 成员行按角色号在**当前页**里找序号（排序/筛选之后下标会变，别写死）。
func _行序(页: Control, 号: int) -> int:
	var 行们: Array = 页.get_meta("mg_page_rows", []) as Array
	for i in 行们.size():
		if int((行们[i] as Dictionary).get("character_id", 0)) == 号:
			return i
	return -1


func _跑() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	var 真后 := root.get_node_or_null("BackendConnection")
	if 会话 == null or 真后 == null:
		_失败.append("拿不到 GameSession / BackendConnection 单例")
		_收尾()
		return
	root.remove_child(真后)
	_后 = 测试后端.new()
	_后.name = "BackendConnection"
	root.add_child(_后)
	await process_frame
	_后.set("in_game", true)
	_后.set("character_id", 101)
	_后.set("authoritative_guild", {})
	_后.set("authoritative_friends", [])
	# `authoritative_inventory` 是 `Array[Dictionary]`：`set()` 塞普通 Array 会被 typ 检查
	# 静默拒掉（数量恒 0 ⇒ 弹劾永远提示"没有弹劾令"），只能从原数组上 clear/append。
	var 背包: Array = _后.get("authoritative_inventory")
	背包.clear()
	背包.append({"id": 弹劾令, "quantity": 1})
	会话.notification_requested.connect(func(字: String) -> void: _通知们.append(字))

	var 我 := {"character_id": 101, "name": "阿头", "level": 60, "rank": 1, "channel_id": 1,
			"online": true, "skillValue": 10, "maiValue": 1, "chengjiuValue": 1,
			"shengwangValue": 1, "bossValue": 0, "contriValue": 100}
	var 乙 := {"character_id": 2002, "name": "beta", "level": 40, "rank": 9999, "channel_id": 3,
			"online": true, "skillValue": 1, "maiValue": 1, "chengjiuValue": 1,
			"shengwangValue": 1, "bossValue": 0, "contriValue": 1}
	var 丙 := {"character_id": 2003, "name": "gamma", "level": 30, "rank": 2, "channel_id": -1,
			"online": false, "skillValue": 1, "maiValue": 1, "chengjiuValue": 1,
			"shengwangValue": 1, "bossValue": 0, "contriValue": 1}
	var 族 := {"joined": true, "id": 7, "name": "暗部", "leader": "阿头", "leader_id": 101,
			"auto_accept": true, "member_list": [我, 乙, 丙]}
	会话.set("guild", 族)

	_管 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(_管)
	for i in 4:
		await process_frame
	var 盘 = _管.get_node_or_null("邀请托盘")
	if 盘 == null:
		_失败.append("窗口管理底下没有「邀请托盘」")
		_收尾()
		return
	盘.call("清空")
	await process_frame

	# ── ① 入族申请帧 ⇒ 托盘一格（类型/图标/提示/去重）─────────────────────
	_收("1552:8:候选人:2002:10000204:44")
	await process_frame
	await process_frame
	_判(int(盘.call("数量")) == 1, "① 1552:8 喂一帧 ⇒ 托盘一格（实得 %d）" % int(盘.call("数量")))
	var 格 = 盘.call("最后一格")
	_判(格 != null and int(格.get("类型")) == 6,
			"① 申请格类型 = 6 TYPE_FAMILY_APPLY（实得 %s）" % (str(格.get("类型")) if 格 else "<无>"))
	if 格 != null:
		_判(int((格.get("数据") as Dictionary).get("charId", 0)) == 2002,
				"① 申请格数据 charId = 申请人角色号（实得 %s）" % str(格.get("数据")))
		var 图 := 格.get_node_or_null("图标") as TextureRect
		_判(图 != null and 图.texture != null and String(图.texture.resource_path) == 申请图标,
				"① 申请格图标 = 托盘_家族邀请.png（与家族邀请同一张，CueGird.as:188-190）")
	盘.call("_于悬停", 6, true)
	await process_frame
	var 提示 := 盘.get_node_or_null("托盘提示框/文字") as RichTextLabel
	_判(提示 != null and String(提示.text) == "家族申请",
			"① 悬停提示 = 家族申请（实得 %s）" % (String(提示.text) if 提示 else "<无>"))
	盘.call("_于悬停", 6, false)
	_收("1552:8:候选人:2002:10000204:44")
	await process_frame
	_判(int(盘.call("数量")) == 1, "① 同一个申请人再发一次 ⇒ 仍一格（按 charId 去重）")
	_收("1552:8:候选人乙:2003:10000205:30")
	await process_frame
	_判(int(盘.call("数量")) == 2, "① 换一个申请人 ⇒ 两格（实得 %d）" % int(盘.call("数量")))

	# 点第一格（申请人 2002）⇒ 审核档页壳
	_清()
	盘.已点.emit(6, {"charId": 2002, "id": 2002, "name": "候选人", "playerName": "候选人",
			"level": 44, "face": 10000204, "famillyName": "无"})
	for i in 3:
		await process_frame
	var 窗们: Dictionary = _管.get("_窗口们")
	var 邀窗 := 窗们.get("家族邀请") as Node
	_判(邀窗 != null and bool(邀窗.call("已打开")), "① 点申请格 ⇒ 家族邀请页壳打开")
	if 邀窗 == null:
		_收尾()
		return
	var 标题 := 邀窗.get("_title") as Label
	_判(标题 != null and 标题.text == "申请入族",
			"① 审核档标题 = 申请入族（实得 %s）" % (标题.text if 标题 else "<无>"))
	var 页 := _内容(邀窗, "原版家族邀请内容")
	_判(页 != null, "① 审核档页本体建出来")
	if 页 != null:
		_判(String((页.get_node("正文") as RichTextLabel).text) == "该玩家申请加入你的家族，请问你是否审核通过",
				"① 审核档正文 = FAMILLY_MANAGER_SHIFO_TONGGUO")
		_判(String((页.get_node("同意钮/文字") as Label).text) == "批准入族",
				"① 审核档主钮文字 = 批准入族")
	_点(页.get_node_or_null("同意钮"))
	await process_frame
	await process_frame
	_判(_帧() == ["%d:14:2002" % 码家族],
			"① 批准 ⇒ 1552:14:<申请人角色号>（实得 %s）" % [str(_帧())])
	_判(not bool(邀窗.call("已打开")), "① 批准后窗自己收掉（okHandler 同款）")

	# 点第二格（申请人 2003）⇒ 拒绝
	盘.已点.emit(6, {"charId": 2003, "id": 2003, "name": "候选人乙", "playerName": "候选人乙",
			"level": 30, "face": 10000205, "famillyName": "无"})
	for i in 3:
		await process_frame
	_判(bool(邀窗.call("已打开")), "① 第二格再开审核档")
	var 页2 := _内容(邀窗, "原版家族邀请内容")
	_清()
	_点(页2.get_node_or_null("拒绝钮"))
	await process_frame
	await process_frame
	_判(_帧() == ["%d:13:2003" % 码家族],
			"① 拒绝 ⇒ 1552:13:<申请人角色号>（实得 %s）" % [str(_帧())])

	# ── ②③④ 成员管理：单开一扇功能窗口（与家族升级门同口径）──────────────
	_窗 = (load(功能窗口场景) as PackedScene).instantiate()
	root.add_child(_窗)
	await process_frame
	await process_frame

	# ② 家族页「成员信息」⇒ 开成员窗 + 一次 1552:105:7
	_清()
	_窗.call("_show_guild_action", "成员信息")
	for i in 3:
		await process_frame
	_判(_帧() == ["%d:105:7" % 码家族],
			"② 成员信息 ⇒ 1552:105:<族号>（详细 17 字段），实得 %s" % [str(_帧())])
	var 员页 := _内容(_窗, "家族子窗_家族成员窗")
	_判(员页 != null, "② 成员信息同时把成员窗开出来")
	if 员页 == null:
		_收尾()
		return
	_判(int(员页.get_meta("mg_asked", -1)) == -1,
			"② 手上已有成员行 ⇒ 填充器不再自拉第二发 105")

	# 查看资料：在线 ⇒ 94:0:<号>；离线 ⇒ 只提示
	_清()
	_窗.call("_家族成员菜单动作", "查看资料", {"character_id": 2002, "name": "beta", "channel_id": 3})
	await process_frame
	_判(_帧() == ["%d:0:2002" % 码资料], "③ 查看资料 ⇒ 94:0:<号>（实得 %s）" % [str(_帧())])
	_清()
	_窗.call("_家族成员菜单动作", "查看资料", {"character_id": 2002, "name": "beta", "channel_id": 0})
	await process_frame
	_判(_帧().is_empty() and _有提示("该玩家不在线！"),
			"③ 离线查看只提示、不发帧（实得 %s / %s）" % [str(_帧()), str(_通知们)])

	# 加为好友 ⇒ 127:1:<号>
	_清()
	_窗.call("_家族成员菜单动作", "加为好友", {"character_id": 2002, "name": "beta"})
	await process_frame
	_判(_帧() == ["%d:1:2002" % 码好友], "③ 加为好友 ⇒ 127:1:<号>（实得 %s）" % [str(_帧())])

	# 任命五档 ⇒ 1552:17:<号>:<rank>
	var 任阶 := {"任命副族长": 2, "任命长老": 3, "任命顾问": 4, "任命精英": 5, "任命族员": 9999}
	for 文 in 任阶:
		_清()
		_窗.call("_家族成员菜单动作", 文, {"character_id": 2002, "name": "beta"})
		await process_frame
		_判(_帧() == ["%d:17:2002:%d" % [码家族, int(任阶[文])]],
				"③ %s ⇒ 1552:17:2002:%d（实得 %s）" % [文, int(任阶[文]), str(_帧())])

	# 族长对自己那行 ⇒ 除查看资料外全拦
	_清()
	_窗.call("_家族成员菜单动作", "任命长老", 我)
	await process_frame
	_判(_帧().is_empty() and _有提示("不能对自己进行任命长老操作！"),
			"④ 族长对自己管理 ⇒ 只提示不发帧（实得 %s / %s）" % [str(_帧()), str(_通知们)])

	# 禅让：确认弹正文带名字，确定 ⇒ 1552:18:<号>
	_清()
	_窗.call("_家族成员菜单动作", "禅让族长", 乙)
	for i in 3:
		await process_frame
	var 弹 := _内容(_窗, "家族子窗_家族确认弹")
	_判(弹 != null, "③ 禅让 ⇒ 开家族确认弹")
	if 弹 != null:
		var 正 := 弹.get_node_or_null("文本正文") as RichTextLabel
		_判(正 != null and 正.text == "你确定要禅让给beta吗？",
				"③ 禅让正文带名字（实得 %s）" % (正.text if 正 else "<无>"))
		_判(String((弹.get_node("钮确定/Label") as Label).text) == "禅让",
				"③ 禅让确定钮文字 = 禅让")
		_点(弹.get_node_or_null("钮确定"))
		await process_frame
		await process_frame
	_判(_帧() == ["%d:18:2002" % 码家族], "③ 禅让确定 ⇒ 1552:18:<号>（实得 %s）" % [str(_帧())])

	# 开除：选中 beta 那一行再点开除 ⇒ 确认弹 ⇒ 1552:4:<号>
	var 序 := _行序(员页, 2002)
	_判(序 >= 0, "③ beta 在成员页当前页里（序 %d）" % 序)
	员页.set_meta("mg_selected", 序)
	_清()
	_窗.call("_show_guild_action", "家族成员窗:开除出族")
	for i in 3:
		await process_frame
	var 弹2 := _内容(_窗, "家族子窗_家族确认弹")
	_判(弹2 != null, "③ 开除 ⇒ 开确认弹")
	if 弹2 != null:
		var 正2 := 弹2.get_node_or_null("文本正文") as RichTextLabel
		_判(正2 != null and 正2.text == "你确认要开除玩家：beta",
				"③ 开除正文带名字（实得 %s）" % (正2.text if 正2 else "<无>"))
		_点(弹2.get_node_or_null("钮确定"))
		await process_frame
		await process_frame
	_判(_帧() == ["%d:4:2002" % 码家族], "③ 开除确定 ⇒ 1552:4:<号>（实得 %s）" % [str(_帧())])

	# 开除自己 / 开除族长 两道闸
	员页.set_meta("mg_selected", _行序(员页, 101))
	_清()
	_窗.call("_show_guild_action", "家族成员窗:开除出族")
	await process_frame
	_判(_帧().is_empty() and _有提示("不能开除自己！"), "④ 开除自己 ⇒ 只提示（%s）" % str(_通知们))
	await _收弹(_窗)

	# 自动同意复选框：当前 true ⇒ 发 0；翻成 false ⇒ 发 1
	_清()
	_窗.call("_show_guild_action", "家族成员窗:自动同意")
	await process_frame
	_判(_帧() == ["%d:20:0" % 码家族], "⑤ 自动同意 true 时点它 ⇒ 1552:20:0（实得 %s）" % [str(_帧())])
	会话.guild["auto_accept"] = false
	_清()
	_窗.call("_show_guild_action", "家族成员窗:自动同意")
	await process_frame
	_判(_帧() == ["%d:20:1" % 码家族], "⑤ 自动同意 false 时点它 ⇒ 1552:20:1（实得 %s）" % [str(_帧())])
	会话.guild["auto_accept"] = true

	# 解散 / 退出：确认弹 ⇒ 1552:5 / 1552:6
	_清()
	_窗.call("_show_guild_action", "家族成员窗:解散家族")
	for i in 3:
		await process_frame
	var 弹3 := _内容(_窗, "家族子窗_家族确认弹")
	_判(弹3 != null, "⑤ 解散家族 ⇒ 开确认弹")
	if 弹3 != null:
		var 正3 := 弹3.get_node_or_null("文本正文") as RichTextLabel
		_判(正3 != null and 正3.text == "你确认要解散家族吗？",
				"⑤ 解散正文 = 你确认要解散家族吗？（实得 %s）" % (正3.text if 正3 else "<无>"))
		_点(弹3.get_node_or_null("钮确定"))
		await process_frame
		await process_frame
	_判(_帧() == ["%d:5" % 码家族], "⑤ 解散确定 ⇒ 1552:5（实得 %s）" % [str(_帧())])

	_清()
	_窗.call("_show_guild_action", "家族成员窗:退出家族")
	for i in 3:
		await process_frame
	var 弹4 := _内容(_窗, "家族子窗_家族确认弹")
	if 弹4 != null:
		_点(弹4.get_node_or_null("钮确定"))
		await process_frame
		await process_frame
	_判(_帧() == ["%d:6" % 码家族], "⑤ 退出确定 ⇒ 1552:6（实得 %s）" % [str(_帧())])

	# ── ④ 弹劾：非族长 + 有弹劾令 ⇒ 消息确认框 ⇒ 1552:22 ────────────────
	var 族头 := {"character_id": 999, "name": "老大", "rank": 1}
	# 先在"我还是族长"的状态下验自己那一闸（下面马上把 leader_id 改成别人）
	_清()
	_窗.call("_家族成员菜单动作", "弹劾族长", 族头)
	await process_frame
	_判(_帧().is_empty() and _有提示("不能弹劾自己"), "④ 族长弹劾自己 ⇒ 只提示（%s）" % str(_通知们))

	_判(not _帧().has("%d:22" % 码家族), "④ 解散/退出之后还没误发过弹劾")
	会话.guild["leader_id"] = 999
	会话.guild["leader"] = "老大"
	会话.guild["member_list"] = [我, 乙,
			{"character_id": 999, "name": "老大", "level": 1, "rank": 1, "channel_id": 1, "online": true}]
	var 窗2 := (load(功能窗口场景) as PackedScene).instantiate()
	root.add_child(窗2)
	await process_frame
	await process_frame
	_清()
	窗2.call("_家族成员菜单动作", "弹劾族长", 族头)
	for i in 3:
		await process_frame
	var 遮 := 窗2.get("_overlay") as Control
	var 消 := 遮.get_node_or_null("消息确认框") as Control if 遮 != null else null
	_判(消 != null, "④ 有弹劾令 + 非族长 ⇒ 弹消息确认框（遮=%s 子=%s 通知=%s 弹劾令数=%d 族长=%s）"
			% [str(遮 != null), str(遮.get_children().map(func(子): return String(子.name)) if 遮 else []),
			str(_通知们), int(_后.call("inventory_quantity", 弹劾令)),
			str(会话.guild.get("leader_id", -1))])
	if 消 != null:
		var 正 := 消.get_node_or_null("主体/正文") as RichTextLabel
		_判(正 != null and 正.text.contains("【老大】") and 正.text.contains("5天"),
				"④ 弹劾正文带族长名与 5 天（实得 %s）" % (正.text if 正 else "<无>"))
		_清()
		var 主 := 消.get_node_or_null("主体") as Control
		var 钮 := 主.get_node_or_null("确定") as Control if 主 != null else null
		_判(钮 != null, "④ 弹劾确认框有「确定」钮（主体子=%s）"
				% str(主.get_children().map(func(子): return String(子.name)) if 主 else []))
		_点(钮)
		await process_frame
		await process_frame
		_判(_帧() == ["%d:22" % 码家族], "④ 确认弹劾 ⇒ 1552:22（实得 %s）" % [str(_帧())])

	# 没有弹劾令 ⇒ 只提示，不发帧、不弹框
	背包.clear()
	_清()
	窗2.call("_家族成员菜单动作", "弹劾族长", 族头)
	for i in 2:
		await process_frame
	var 遮2 := 窗2.get("_overlay") as Control
	_判(遮2.get_node_or_null("消息确认框") == null, "④ 没弹劾令 ⇒ 不弹确认框")
	_判(_帧().is_empty() and _有提示("弹劾令"), "④ 没弹劾令 ⇒ 只提示（%s / %s）"
			% [str(_帧()), str(_通知们)])

	_跑完了 = true
	_收尾()


func _收尾() -> void:
	if _跑完了 and not _失败.is_empty():
		pass
	for 条 in _失败:
		print("  !! " + 条)
	if _失败.is_empty():
		print("家族入族审批与成员动作回归测试：通过（%d 条断言）" % _通过)
		quit(0)
	else:
		print("家族入族审批与成员动作回归测试：FAIL %d 条（通过 %d）" % [_失败.size(), _通过])
		quit(1)
