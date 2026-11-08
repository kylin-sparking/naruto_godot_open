extends SceneTree

## 好友页菜单动作分发回归门（2026-11-08，A1）。
##
## 病根：`好友窗口._发菜单项` 把菜单项转成 `"页:项"` 动作串交给宿主时**把这一行的数据丢了**；
## 宿主那侧 `_show_guild_action` 只有名字、没有编号 ⇒ 查看/密语/组队/看摊/删除/拉黑/移除/赠花/交友
## 全是死键（点了只落一句"等待家族服务器数据"）。原版 `FriendWindow2.onMenuHand:338-440`
## 收的是 `param1.object as BuddyMemeber`，协议全靠那四项（编号/名字/在线/头像）。
##
## 本门钉的是**宿主侧出口**（页面侧"行数据有没有交回"由 `好友页回归测试.gd` 的 `验行数据` 盯）：
##   · 每条菜单项发**哪一号 opcode、报文长什么样**（数值来自 `后端连接` 的真入口，不读自造文案）；
##   · 查看离线仍要发资料请求（AS3 先 addNotice 再 clickCharacter），提示也要落；
##   · 密语**不发包**（`ChatEvent.CHECK_ONLINE`），只把聊天框切私聊；
##   · 删除按页签分 3/7/9 三档（AS3 三个不同 action，别全发 3）；
##   · 赠花先存"对面四项"再发 94:6（回帧开窗要用）；
##   · 交友先判"已是好友"（只提示不发包）；
##   · 老口径动作串（没有行数据）⇒ 明说缺数据，**不许发 `127:x:0` 空包**；
##   · 离线时一键都不发，提示"需要在线"。
##
## 口径同 `商城开窗发包回归测试.gd`：摘掉真 `/root/BackendConnection`、换 `测试/测试后端连接.gd`
## （继承真后端、只记不发），跑完换回；开场钉 `root.size`；有"跑完了"哨兵，中途报错一律红。
##
## 运行：`Godot --headless --path . --script res://测试/好友动作分发回归测试.gd`

const 功能窗口场景 := "res://场景/界面/功能窗口.tscn"
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 码资料 := 94
const 码好友 := 127
const 码组队 := 120
const 码摊 := 1296

var _通过 := 0
var _失败: Array[String] = []
var _通知们: Array[String] = []
var _假
var _跑完了 := false
var _帧数 := 0


## `功能窗口._取窗口管理()` 要找的 `记赠花对面`（真身在 `窗口管理`，门里只记账）。
class 假管理 extends Node:
	var 花: Array[Dictionary] = []

	func 记赠花对面(项: Dictionary) -> void:
		花.append(项.duplicate(true))


## `_开始好友私聊` 遍历的 `chat_panel` 组（真身是 `聊天面板.开始私聊`，这里只记账）。
class 假聊天 extends Node:
	var 私聊: Array[String] = []

	func 开始私聊(名: String) -> void:
		私聊.append(名)


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_跑")


## 看门狗：脚本报错会让 `_跑` 停在某个 await 上、quit 永远不来（门挂死 = 假绿）
func _process(_d: float) -> bool:
	_帧数 += 1
	if _帧数 > 600 and not _跑完了:
		_失败.append("门 600 帧内没跑完（中途报错停在 await 上？）")
		_收尾()
	return _帧数 > 600


func _判(对: bool, 明: String) -> void:
	if 对:
		_通过 += 1
	else:
		_失败.append(明)


func _帧(假) -> Array[String]:
	var 出: Array[String] = []
	for 条 in 假.sent_requests:
		出.append("%d:%s" % [int((条 as Dictionary).get("opcode", 0)),
				String((条 as Dictionary).get("content", ""))])
	return 出


## 清账 → 发一条菜单动作 → 回读这一发落在后端的东西。
func _发(窗: Node, 动作: String, 项: Dictionary) -> Array[String]:
	_假.sent_requests.clear()
	_通知们.clear()
	窗.call("_好友菜单动作", 动作, 项)
	return _帧(_假)


func _有提示(关键词: String) -> bool:
	for 字 in _通知们:
		if String(字).contains(关键词):
			return true
	return false


func _跑() -> void:
	var 会话 = root.get_node_or_null("GameSession")
	var 真后端 := root.get_node_or_null("BackendConnection")
	if 会话 == null or 真后端 == null:
		_失败.append("拿不到 GameSession / BackendConnection 单例")
		_收尾()
		return
	root.remove_child(真后端)
	_假 = 测试后端.new()
	_假.name = "BackendConnection"
	_假.in_game = true
	root.add_child(_假)
	await process_frame
	会话.notification_requested.connect(func(字: String) -> void: _通知们.append(字))

	var 管 := 假管理.new()
	管.name = "假窗口管理"
	root.add_child(管)
	var 聊 := 假聊天.new()
	聊.name = "假聊天"
	聊.add_to_group("chat_panel")
	root.add_child(聊)
	# 场景根是 CanvasLayer（窗口壳），不是 Control —— 别给 `instantiate()` 加 Control 类型
	var 窗 = (load(功能窗口场景) as PackedScene).instantiate()
	管.add_child(窗)
	await process_frame
	await process_frame

	var 瑞 := {"character_id": 101, "name": "瑞树", "level": 60, "online": true, "face": 3}

	# ① 查看（在线）⇒ 要的是完整资料 94:0:<号>（不是 94:4 顶栏血蓝）
	var 帧 := _发(窗, "好友:查看", 瑞)
	_判(帧 == ["%d:0:101" % 码资料],
		"① 查看 ⇒ 94:0:<编号>，实得 %s" % [str(帧)])
	_判(_通知们.is_empty(), "① 在线查看不该弹提示，实得 %s" % [str(_通知们)])

	# ② 查看（离线）⇒ 先一句"该玩家不在线！"，**仍然**发资料请求（FW2:351-355）
	var 离 := 瑞.duplicate()
	离["online"] = false
	帧 = _发(窗, "好友:查看", 离)
	_判(帧 == ["%d:0:101" % 码资料],
		"② 离线查看仍要发 94:0:<编号>（AS3 提示后照旧 clickCharacter），实得 %s" % [str(帧)])
	_判(_通知们.has("该玩家不在线！"), "② 离线查看要先落一句「该玩家不在线！」，实得 %s" % [str(_通知们)])

	# ③ 密语 ⇒ 不发包（CHECK_ONLINE 只切频道），交给聊天面板
	聊.私聊.clear()
	帧 = _发(窗, "好友:密语", 瑞)
	_判(帧.is_empty(), "③ 密语不该发任何包（原版只切私聊频道），实得 %s" % [str(帧)])
	_判(聊.私聊 == ["瑞树"], "③ 密语要把玩家名交给聊天面板，实得 %s" % [str(聊.私聊)])

	# ④ 组队邀请 ⇒ 120:4:<名字>（取名字，不是编号）
	帧 = _发(窗, "好友:组队", 瑞)
	_判(帧 == ["%d:4:瑞树" % 码组队], "④ 组队 ⇒ 120:4:<名字>，实得 %s" % [str(帧)])

	# ⑤ 看摊 ⇒ 1296:2:<摊主号>
	帧 = _发(窗, "好友:看摊", 瑞)
	_判(帧 == ["%d:2:101" % 码摊], "⑤ 看摊 ⇒ 1296:2:<编号>，实得 %s" % [str(帧)])

	# ⑥ 删除三页三档（AS3 三个 action：3/7/9）
	帧 = _发(窗, "好友:删除", 瑞)
	_判(帧 == ["%d:3:101" % 码好友], "⑥ 好友页删除 ⇒ 127:3:<编号>，实得 %s" % [str(帧)])
	帧 = _发(窗, "最近:删除", 瑞)
	_判(帧 == ["%d:7:101" % 码好友], "⑥ 最近页删除 ⇒ 127:7:<编号>（不是 3），实得 %s" % [str(帧)])
	帧 = _发(窗, "仇人:删除", 瑞)
	_判(帧 == ["%d:9:101" % 码好友], "⑥ 仇人页删除 ⇒ 127:9:<编号>（不是 3），实得 %s" % [str(帧)])

	# ⑦ 拉黑 4 / 移出黑名单 6
	帧 = _发(窗, "好友:拉黑", 瑞)
	_判(帧 == ["%d:4:101" % 码好友], "⑦ 拉黑 ⇒ 127:4:<编号>，实得 %s" % [str(帧)])
	帧 = _发(窗, "黑名单:移除", 瑞)
	_判(帧 == ["%d:6:101" % 码好友], "⑦ 移出黑名单 ⇒ 127:6:<编号>，实得 %s" % [str(帧)])

	# ⑧ 赠花 ⇒ 先存对面四项、再发 94:6（回帧 58:2 才开赠花窗）
	管.花.clear()
	帧 = _发(窗, "好友:赠花", 瑞)
	_判(帧 == ["%d:6:101" % 码资料], "⑧ 赠花 ⇒ 94:6:<编号>，实得 %s" % [str(帧)])
	if 管.花.size() == 1:
		var 花: Dictionary = 管.花[0]
		_判(int(花.get("charId", 0)) == 101 and String(花.get("name", "")) == "瑞树"
				and int(花.get("face", 0)) == 3 and int(花.get("level", 0)) == 60,
			"⑧ 赠花前要把对面四项（编号/名字/头像/等级）存给窗口管理，实得 %s" % [花])
	else:
		_判(false, "⑧ 赠花没把对面四项交给窗口管理（记了 %d 次）" % 管.花.size())

	# ⑨ 交友：不在好友列表 ⇒ 127:1；已经是好友 ⇒ 只提示、不发包
	# `authoritative_friends` 是 Array[Dictionary]，无类型 `[]` 赋不进去 ⇒ 用 clear/append
	_假.authoritative_friends.clear()
	帧 = _发(窗, "好友:交友", 瑞)
	_判(帧 == ["%d:1:101" % 码好友], "⑨ 交友 ⇒ 127:1:<编号>，实得 %s" % [str(帧)])
	_假.authoritative_friends.append({"character_id": 101, "name": "瑞树"})
	帧 = _发(窗, "好友:交友", 瑞)
	_判(帧.is_empty(), "⑨ 已经是好友时不该再发 127:1，实得 %s" % [str(帧)])
	_判(_通知们.has("该玩家已经是你的好友"), "⑨ 已是好友要落一句提示，实得 %s" % [str(_通知们)])
	_假.authoritative_friends.clear()

	# ⑩ 老口径（没有行数据）⇒ 明说缺数据，不许发 127:3:0 这种空包
	帧 = _发(窗, "好友:删除", {})
	_判(帧.is_empty(), "⑩ 缺行数据的删除不许发包（会变成 127:3:0），实得 %s" % [str(帧)])
	_判(_通知们.has("删除：找不到这名玩家的数据"),
		"⑩ 缺行数据要明说，实得 %s" % [str(_通知们)])

	# ⑪ 离线：一键都不发，落"需要在线"
	_假.in_game = false
	帧 = _发(窗, "好友:删除", 瑞)
	_判(帧.is_empty(), "⑪ 离线时不该发包，实得 %s" % [str(帧)])
	_判(_通知们.has("删除好友需要在线"), "⑪ 离线要提示「删除好友需要在线」，实得 %s" % [str(_通知们)])
	_假.in_game = true

	# ⑫ 添加好友钮（A2）：不发包，开「好友选人窗」并按加好友档配置多功能钮
	帧 = _发(窗, "好友:添加好友钮", {})
	var 遮 := 窗.get("_overlay") as Control
	var 根 := 遮.get_node_or_null("家族子窗_好友选人窗") if 遮 != null else null
	_判(帧.is_empty(), "⑫ 添加好友钮不该发包，实得 %s" % [str(帧)])
	_判(根 != null, "⑫ 添加好友钮要开「好友选人窗」，实得 overlay 子节点 %s"
		% [str(遮.get_children().map(func(节): return 节.name)) if 遮 != null else "无遮罩"])
	if 根 != null:
		var 内容 := 子窗壳.取内容(窗, "好友选人窗")
		if 内容 != null:
			var 多功能 := 内容.get_node_or_null("多功能钮/Label") as Label
			var 题 := 内容.get_node_or_null("标题") as Label
			_判(多功能 != null and 多功能.text == "添加好友",
				"⑫ 选人窗的多功能钮要切成 FRIEND_ADD「添加好友」，实得 %s"
				% [多功能.text if 多功能 != null else "缺节点"])
			_判(题 != null and 题.text == "查询玩家",
				"⑫ 选人窗标题 = SELCET_PLAYER_WINDOW_TITLE「查询玩家」，实得 %s"
				% [题.text if 题 != null else "缺节点"])
		else:
			_判(false, "⑫ 选人窗开出来了但取不到内容节点")
	_判(not _有提示("等待家族服务器数据") and not _有提示("好友页这一项还没接"),
		"⑫ 已接项不许落「未接/等待家族服务器数据」，实得 %s" % [str(_通知们)])

	# ⑬ 对话（在线）⇒ 开私聊窗并把它设到这一行；离线 ⇒ 只提示、不开窗
	帧 = _发(窗, "好友:对话", 瑞)
	var 私根 := 遮.get_node_or_null("家族子窗_好友私聊窗") if 遮 != null else null
	_判(帧.is_empty(), "⑬ 对话不发包（首句由聊天框发），实得 %s" % [str(帧)])
	_判(私根 != null, "⑬ 在线对话要开「好友私聊窗」")
	if 私根 != null:
		var 私内 := 子窗壳.取内容(窗, "好友私聊窗")
		if 私内 != null:
			var 私题 := 私内.get_node_or_null("标题") as Label
			_判(私题 != null and 私题.text.contains("瑞树"),
				"⑬ 私聊窗标题要带上对面名字（FRIENDCHAT_WINDOW_TITLE），实得 %s"
				% [私题.text if 私题 != null else "缺节点"])
		else:
			_判(false, "⑬ 私聊窗开出来了但取不到内容节点")
	_发(窗, "好友:对话", 离)
	_判(_通知们.has("该玩家不在线！"), "⑬ 离线对话要落「该玩家不在线！」，实得 %s" % [str(_通知们)])

	管.queue_free()
	聊.queue_free()
	await process_frame
	_跑完了 = true
	_假.free()
	root.add_child(真后端)
	_收尾()


func _收尾() -> void:
	if not _跑完了:
		_失败.append("门没跑到底（中途报错退出）⇒ 上面每条判式都还没量到")
	for 条 in _失败:
		print("失败 - ", 条)
	print("好友动作分发回归测试：通过 %d，红 %d" % [_通过, _失败.size()])
	quit(0 if _失败.is_empty() else 1)
