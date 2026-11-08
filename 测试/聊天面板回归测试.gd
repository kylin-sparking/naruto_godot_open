extends SceneTree

## 聊天面板「发消息」这条链的离线回归门（用户 2026-10-23 报修 13：聊天框发消息功能未实装）。
##
## 报的现象：在聊天框打字、按回车，屏幕上什么都没发生。
##
## 三类成因（真值 `真值/窗口/聊天正文与通告位.md`）：
##   A. **真缺陷**：`_on_backend_chat` 把 `is_self` 硬写成 `true`。原版那个第五参是
##      `param1.charName == DataCenter.getInstance().stats.name`（`UI.as:363/366/373`）
##      ⇒ 别人私聊我，我屏上却是「你对XXX说」。`9cb038e`(10-17) 修过，`074dd89`(10-22 的 `-X ours`
##      合并) 把它整个埋了回来（§3.255）—— 而唯一能照到它的 `测试/头像信息在线回归测试.gd`
##      **从没登记进 `开发工具/跑在线用例.ps1`** ⇒ 那次 revert 一条判据都没红。
##      本门补的就是那道**不依赖第二个号**的闸（名字用桩给，不读用户存档）。
##   B. **真缺陷**：原版舞台键监听里那一格没人做 —— 焦点不在输入框时按 ENTER
##      `API.resetFocus(this.inputTextField)` 把光标抢进聊天框（`ChatPane.as:835-847`）。
##      本工程没它 ⇒ 玩家打完怪按回车想说话，什么都没发生。同格还有 ESC 放出焦点、
##      **空正文**时 ENTER·左·右 放出焦点（`ChatPane.as:813-831`），也缺。
##   C. **不是缺陷**：默认页签是「综合」而综合页只收 `MISC(4)`（`ChatPane.as:1685-1700` 一条只进
##      一个数组、`:873-905` 页签只切 `chatScrollPane.source`），默认频道却是世界（`:282`）。
##      ⇒ 在默认态发一句世界，聊天列表里**确实看不到自己那一句**，原版一模一样。
##      再加一层：普通频道那句原版还会在人物头顶冒话泡（`UI.as:367-369 _loc3_.speakWords`），
##      本工程没移植话泡 ⇒ 双重静默，玩家只觉得"没实装"。话泡是旧账，本门只钉"别把原版路由改成自造的合并"。
##
## 门钉十组：① 默认态 + 两张位值表；② 六位路由（每页只见自己那位）；③ is_self 六档（含名字来源优先级
## 与"取不到名字不判成自己"）；④ 键盘五格**全走真派发**（`root.push_input`）；⑤ 舞台 ENTER 抢焦点 +
## 折叠态先展开 + 旁框聚焦不抢；⑥ 世界 5s 与全频 1s 两道 CD 的顺序与拦截点；⑦ 喇叭无道具即拦、
## 有道具走 type 8 且只上浮条；⑧ 私聊 `/名 正文` 解析、三种坏格式、发完留前缀；⑨ 上行帧形状
## （桩捕获 + `后端连接.gd` 与夹具双侧字面钉）；⑩ 字面钉与旧账。
##
## 运行：Godot --headless --path . --script res://测试/聊天面板回归测试.gd

const 面板场景 := "res://场景/界面/聊天面板.tscn"
const 面板脚本 := "res://脚本/界面/聊天面板.gd"
const 后端脚本 := "res://脚本/单例/后端连接.gd"
const 服务端路 := "res://服务端/runtime/tools/fake_flash_server.py"

## 名字全部用钉死的假名：**不读用户存档**（会话那份被下面的桩顶掉）。
const 我的名 := "钉死的我"
const 别人的名 := "钉死的澪"

## 只实现聊天面板真正会碰的三样：`in_game`、`authoritative_stats`、`request_chat`。
## ⚠ 桩必须 `extends Node`（面板里 `_backend: Node`），方法名与参数序要和 `后端连接.request_chat`
##   逐字一致 —— 不一致不是"测到桩"，是测到运行时找不到方法。
class 桩后端 extends Node:
	var in_game := false
	var authoritative_stats := {}
	var 发过: Array = []

	func request_chat(正文: String, 类型: int = 0, 目标号: int = 0, 目标名: String = "") -> bool:
		发过.append([正文, 类型, 目标号, 目标名])
		return true

class 桩会话 extends Node:
	var player_stats := {}

const 判满条数 := 110	# 对账用：`_收尾` 里"存档字节没变"那条判完时的累计条数（校准于首跑绿）

var 判 := 0
var 红: Array[String] = []
var 存档前 := ""
var 面板 = null
var 后端桩: 桩后端 = null
var 会话桩: 桩会话 = null

func _记(条件: bool, 说明: String, 补: String = "") -> void:
	判 += 1
	if not 条件:
		红.append(说明 + ("　⇒ " + 补 if 补 != "" else ""))

func _等帧(n: int = 2) -> void:
	for _i in range(n):
		await process_frame

func _等秒(秒: float) -> void:
	await create_timer(秒).timeout
	await process_frame

func _存档字节() -> String:
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if f == null else f.get_as_text()

## 真派发一个按键。⚠ 不用"直接调处理器"糊弄：那条会绕过 LineEdit 自己的 `_gui_input`，
## 量出来的先后顺序和玩家手里的顺序不是一回事（本门 ④⑤ 两组就靠这个顺序判事）。
func _按键(码: int) -> void:
	var k := InputEventKey.new()
	k.keycode = 码
	k.pressed = true
	root.push_input(k)
	await _等秒(0.06)

## 把两道 CD 都让开：只留给"这一腿想测的东西"。
func _放CD() -> void:
	面板._last_world_send_msec = Time.get_ticks_msec() - 6000
	面板._last_send_msec = Time.get_ticks_msec() - 5000

func _清() -> void:
	面板._chat_messages.clear()
	面板._render_chat_messages()

func _最后一条() -> Dictionary:
	var 列: Array = 面板._chat_messages
	return {} if 列.is_empty() else (列[列.size() - 1] as Dictionary)

func _最后bbcode() -> String:
	return String(_最后一条().get("bbcode", ""))

func _收(类型: int, 位: int, 正文: String, 名: String, 目标名: String = "") -> void:
	面板.call("_on_backend_chat", {
		"type": 类型, "positions": 位, "message": 正文, "name": 名, "target_name": 目标名})

func _页文() -> String:
	return String(面板._chat_log.get_parsed_text())

func _常量(名: String) -> Variant:
	return (面板.get_script() as GDScript).get_script_constant_map().get(名, null)

func _initialize() -> void:
	call_deferred("_跑")

func _跑() -> void:
	root.size = Vector2i(960, 560)
	存档前 = _存档字节()
	面板 = (load(面板场景) as PackedScene).instantiate()
	root.add_child(面板)
	await _等秒(0.3)
	if 面板 == null or not 面板.has_method("_send_chat"):
		_收尾("聊天面板场景没长出来（" + 面板场景 + "）")
		return
	if 面板._chat_log == null or 面板._chat_input == null:
		_收尾("消息区/输入框没取到 ⇒ 下面全是空测")
		return
	# 会话/后端换成桩：既不动用户存档里的名字，也能捕获"发出去的那一帧"。
	会话桩 = 桩会话.new()
	会话桩.player_stats = {"name": 我的名, "laba_count": 0}
	面板.set("_session", 会话桩)
	后端桩 = 桩后端.new()
	后端桩.authoritative_stats = {"name": 我的名}
	面板.set("_backend", 后端桩)
	await _量默认态()
	await _量路由()
	await _量是自己说的()
	await _量键盘()
	await _量舞台回车()
	await _量冷却()
	await _量喇叭()
	await _量私聊()
	await _量上行帧()
	_量字面()
	_收尾()

## ── ① 默认态与两张位值表（手抄 AS3 字面量）────────────────────────────────
func _量默认态() -> void:
	_记(面板._selected_tab == 0, "默认页签 = 综合（`ChatPane.as:307 setDefaultTabBtn(this.tabBtn0)`）",
			str(面板._selected_tab))
	_记(面板._selected_channel == 4,
			"默认频道 = 世界（`ChatPane.as:282 selectedChannelType = ChatType.PUBLIC_CHAT`；本工程的 CHAT_CHANNELS 里没有综合，世界落在下标 4）",
			str(面板._selected_channel))
	_记(面板._chat_input.text == "", "开局输入框是空的")
	_记(面板._chat_input.max_length == 100, "输入框上限 = `ChatUtil.as:24 INPUT_MAX_CHARS` = 100",
			str(面板._chat_input.max_length))
	var 页: Array = _常量("TAB_POSITIONS")
	_记(页 == [4, 8, 16, 32, 64, 128],
			"六页各收一位 = `ChatType.as:58-66 getDictionary` 的 MISC/GENERAL/WHISPER/PARTY/GUILD/WORLD", str(页))
	var 频: Dictionary = _常量("CHANNEL_POSITIONS")
	_记(int(频.get("普通", -1)) == 8 and int(频.get("私聊", -1)) == 16 and int(频.get("队伍", -1)) == 32
			and int(频.get("家族", -1)) == 64 and int(频.get("世界", -1)) == 128 and int(频.get("喇叭", -1)) == 256,
			"频道→位那张表逐位对得上 `ChatType.getDictionary`", str(频))
	var 签: Array = _常量("CHAT_TABS")
	_记(签 == ["综合", "普通", "私聊", "队伍", "家族", "世界"],
			"页签顺序 = `ChatType.TAB_CHANNELS`（综合在前、没有喇叭页）", str(签))
	_记(_页文() == "", "综合页开局没东西", _页文())

## ── ② 六位路由：每条只进自己那一页 ────────────────────────────────────────
func _量路由() -> void:
	var 位表 := [4, 8, 16, 32, 64, 128]
	_清()
	for i in range(6):
		_收(1 if i == 0 else 3, 位表[i], "句%d" % i, 别人的名)
	await _等帧()
	for i in range(6):
		面板._select_chat_tab(i)
		await _等帧()
		var 文 := _页文()
		_记(文.contains("句%d" % i), "第 %d 页（位 %d）看得见自己那一条" % [i, 位表[i]], 文)
		var 别见 := ""
		for j in range(6):
			if j != i and 文.contains("句%d" % j):
				别见 += "句%d " % j
		_记(别见 == "", "第 %d 页看不见别的位的那几条（一条只进一个数组，`ChatPane.as:1685-1700`）" % i, 别见)
		_记(文.split("\n", false).size() == 1, "第 %d 页正好一条（不是合并显示）" % i, 文)
	面板._select_chat_tab(0)
	await _等帧()
	_记(_页文().contains("句0") and not _页文().contains("句5"),
			"回综合页还是只见 MISC —— 玩家发在世界的句子**原版就不进综合页**（C 类，不是缺陷）", _页文())

## ── ③ is_self 六档（本轮修复的核心；名字来源优先级也钉）───────────────────
func _量是自己说的() -> void:
	_清()
	_收(3, 8, "普通我发", 我的名)
	var 我句 := _最后bbcode()
	_记(我句.contains("[color=#ffffff]你说[/color]"),
			"帧里的名字 == 我自己的名字 ⇒「你说」（原版第五参 `charName == stats.name`）", 我句)
	_清()
	_收(3, 8, "普通他发", 别人的名)
	var 他句 := _最后bbcode()
	_记(他句.contains(别人的名) and 他句.contains("[color=#ffffff]说[/color]")
			and not 他句.contains("你说") and not 他句.contains("你对"),
			"名字不同 ⇒「XX说」，**不许**冒出「你说」", 他句)
	_清()
	_收(4, 16, "我说给澪", 我的名, 别人的名)
	var 我私 := _最后bbcode()
	_记(我私.contains("你对") and 我私.contains(别人的名) and 我私.contains("我说给澪"),
			"自己发的私聊 ⇒「你对XX说」", 我私)
	_清()
	_收(4, 16, "澪说给我", 别人的名, 我的名)
	var 他私 := _最后bbcode()
	_记(他私.contains(别人的名) and 他私.contains("对你说") and not 他私.contains("你对%s" % 别人的名),
			"**别人**发来的私聊 ⇒「XX对你说」，不是「你对XX说」（10-17 的 bug2、10-22 被合并撤掉的那条）",
			他私)
	## 名字来源优先级：先读**这条连接**的 `authoritative_stats.name`，全局会话那份只兜底
	## （双号在线时 `player_stats` 会被对面那条连接的属性帧盖掉 ⇒ 只读全局必然错）。
	后端桩.authoritative_stats = {"name": 别人的名}
	_清()
	_收(3, 8, "换权威名", 别人的名)
	_记(_最后bbcode().contains("你说"),
			"权威属性里的名字改了 ⇒ 判据跟着改（读的是这条连接那份）", _最后bbcode())
	后端桩.authoritative_stats = {}
	_清()
	_收(3, 8, "兜底会话名", 我的名)
	_记(_最后bbcode().contains("你说"),
			"权威那份取不到名字时兜底到 `player_stats.name`", _最后bbcode())
	会话桩.player_stats = {"name": "", "laba_count": 0}
	_清()
	_收(3, 8, "两个都取不到", 我的名)
	_记(not _最后bbcode().contains("你说"),
			"两处名字都取不到 ⇒ **不判成自己**（宁可显示成别人，也不能把别人的话说成「你说」）", _最后bbcode())
	会话桩.player_stats = {"name": 我的名, "laba_count": 0}

## ── ④ 键盘五格：全部真派发 ────────────────────────────────────────────────
func _量键盘() -> void:
	后端桩.in_game = false
	_清()
	await 放输入("回车一发")
	await _按键(KEY_ENTER)
	_记(面板._chat_messages.size() == 1, "聚焦 + 有正文 ⇒ 回车把这条发出去了（`__sendMsg:1030-1053`）",
			str(面板._chat_messages.size()))
	_记(面板._chat_input.text == "", "发完输入框清空（`__sendMsg:975`）", 面板._chat_input.text)
	_记(面板._chat_input.has_focus(), "发完焦点仍在输入框，能连着打下一句")
	_清()
	面板._chat_input.text = ""
	await _按键(KEY_ENTER)
	_记(面板._chat_messages.is_empty(), "空正文回车**不发**（原版那格只 resetFocus）", _页文())
	_记(not 面板._chat_input.has_focus(), "空正文回车 ⇒ 放出焦点（`ChatPane.as:823-830`）")
	await 放输入("")
	await _按键(KEY_LEFT)
	_记(not 面板._chat_input.has_focus(), "空正文时 ← 也放出焦点（同格）")
	await 放输入("")
	await _按键(KEY_KP_ENTER)
	_记(not 面板._chat_input.has_focus(), "小键盘回车走同一格（`KEY_KP_ENTER`）")
	await 放输入("ESC 一发")
	await _按键(KEY_ESCAPE)
	_记(not 面板._chat_input.has_focus(), "ESC ⇒ 放出焦点（`ChatPane.as:815-818`）")
	_记(面板._chat_messages.is_empty(), "ESC 不发送、不落消息", _页文())
	## 一次没发过言的玩家按 ESC 也要退得出来 ⇒ ESC 判必须在"没历史就 return"之前。
	面板._input_history.clear()
	await 放输入("没历史也要退")
	await _按键(KEY_ESCAPE)
	_记(not 面板._chat_input.has_focus(), "输入历史为空时 ESC 仍能放出焦点（顺序钉）")
	_清()
	面板._input_history.clear()
	for 句 in ["第一句", "第二句", "第三句"]:
		面板._input_history.append(句)
	面板._history_index = 面板._input_history.size()
	await 放输入("")
	await _按键(KEY_UP)
	_记(面板._chat_input.text == "第三句", "↑ 翻到最后一条历史（`showLog:1066-1078`）", 面板._chat_input.text)
	await _按键(KEY_UP)
	_记(面板._chat_input.text == "第二句", "再 ↑ 往前一条", 面板._chat_input.text)
	await _按键(KEY_DOWN)
	_记(面板._chat_input.text == "第三句", "↓ 往后一条", 面板._chat_input.text)
	await _按键(KEY_UP)
	await _按键(KEY_UP)
	await _按键(KEY_UP)
	_记(面板._input_history.has(面板._chat_input.text),
			"↑ 到底再翻是**环绕**（原版 curLogIndex<0 ⇒ 取末尾），不会翻成空框", 面板._chat_input.text)
	_记(面板._chat_input.caret_column == 面板._chat_input.text.length(),
			"翻出来的历史把光标停在末尾（`setSelection(len,len)`）", str(面板._chat_input.caret_column))

func 放输入(文本: String) -> void:
	_放CD()
	面板._selected_channel = 0
	面板._chat_input.text = 文本
	面板._chat_input.grab_focus()
	await _等帧()

## ── ⑤ 舞台 ENTER 抢焦点（本轮补的那格）+ 折叠态 + 旁框 ────────────────────
func _量舞台回车() -> void:
	面板._chat_input.release_focus()
	await _等帧()
	_记(面板.get_viewport().gui_get_focus_owner() != 面板._chat_input,
			"量具自检：起手确实没焦点（否则下面那条是空测）")
	await _按键(KEY_ENTER)
	_记(面板._chat_input.has_focus(), "没聚焦时按 ENTER ⇒ 光标抢进聊天框（`ChatPane.as:835-847`）")
	_记(面板._chat_messages.is_empty(), "抢焦点这一发**不**发送任何东西")
	面板._chat_input.release_focus()
	面板._set_chat_hidden(true)
	await _等秒(0.7)
	_记(面板._chat_hidden, "量具自检：已折叠（否则下面那条展开判据是空的）")
	await _按键(KEY_ENTER)
	_记(面板._chat_input.has_focus(), "折叠着按 ENTER 也要进得了输入框")
	_记(not 面板._chat_hidden, "折叠态先展开再抢焦点（本工程输入行会滑出屏幕，不展开等于把光标藏起来）")
	await _等秒(0.7)
	var 旁 := LineEdit.new()
	面板.add_child(旁)
	旁.size = Vector2(120, 20)
	旁.grab_focus()
	await _等帧()
	var 焦点件 = 面板.get_viewport().gui_get_focus_owner()
	# ⚠ `is_ancestor_of()` 对**自己**返回 false ⇒ 旁框本体拿到了焦点时也得算通过。
	_记(焦点件 == 旁 or (焦点件 != null and 旁.is_ancestor_of(焦点件)),
			"量具自检：焦点在旁框里（含它的内部文本件）", str(焦点件))
	await _按键(KEY_ENTER)
	_记(not 面板._chat_input.has_focus(),
			"焦点在别的输入框里 ⇒ ENTER 不被聊天框抢走（原版那格判商城搜索框；Godot 这边由 GUI 先消费保证）")
	旁.free()

## ── ⑥ 两道 CD 的顺序与拦截点 ──────────────────────────────────────────────
func _量冷却() -> void:
	后端桩.in_game = true
	_清()
	后端桩.发过.clear()
	面板._selected_channel = 4	# 世界
	面板._last_world_send_msec = 0
	面板._last_send_msec = Time.get_ticks_msec() - 5000
	面板._chat_input.text = "世界第一句"
	面板._send_chat()
	_记(后端桩.发过.size() == 1, "世界频道第一句发得出去（全局 CD 已过、世界没记过时间戳）", str(后端桩.发过))
	var 记的世界 := int(面板._last_world_send_msec)
	_记(记的世界 > 0, "发出去才记下世界时间戳（`__sendMsg:1004-1007`）", str(记的世界))
	_清()
	面板._last_send_msec = Time.get_ticks_msec() - 5000
	面板._chat_input.text = "世界第二句"
	面板._send_chat()
	_记(后端桩.发过.size() == 1, "5 秒内第二句世界被拦（`WORLD_CHANNEL_TIME_CD`，`ChatPane.as:63` = 5000）",
			str(后端桩.发过))
	_记(int(面板._last_world_send_msec) == 记的世界, "被拦时**不**推时间戳（原版拒绝支在赋值之前 return）",
			str(面板._last_world_send_msec))
	_记(_最后bbcode().contains("世界频道发言冷却时间尚未结束"),
			"拒绝落成一条『世界』页的提示（`setTip(CN.PUBLIC_CHAT_CD, WORLD, …)`）", _最后bbcode())
	## 全频 1s：把世界那道让开，只留这一道。
	_清()
	后端桩.发过.clear()
	面板._last_world_send_msec = Time.get_ticks_msec() - 6000
	面板._last_send_msec = Time.get_ticks_msec()
	面板._selected_channel = 0	# 普通：不碰世界那道
	面板._chat_input.text = "连打一句"
	面板._send_chat()
	_记(后端桩.发过.is_empty(), "1 秒内换频道发也被拦（`checkTime():1760-1770` 的 >1000）", str(后端桩.发过))
	_记(_最后bbcode().contains("请过 1 秒后再发言"),
			"那条拒绝的文案 = `CN.CHAT_TIP_SEND_TOO_FAST`", _最后bbcode())

## ── ⑦ 喇叭：无道具即拦，有道具走 type 8、只上浮条 ─────────────────────────
func _量喇叭() -> void:
	_清()
	后端桩.发过.clear()
	会话桩.player_stats = {"name": 我的名, "laba_count": 0}
	面板._selected_channel = 5
	_放CD()
	面板._chat_input.text = "没喇叭的一句"
	面板._send_chat()
	_记(后端桩.发过.is_empty(), "背包没喇叭 ⇒ 不发包（`__sendMsg:983-987` 的 LABA_COUNT）", str(后端桩.发过))
	_记(面板._chat_messages.size() == 1 and _最后bbcode().contains("你背包中的喇叭不足！"),
			"只落一条文案 = `CN.LABA_COUNT` 的拒绝提示", _最后bbcode())
	_清()
	后端桩.发过.clear()
	会话桩.player_stats = {"name": 我的名, "laba_count": 3}
	面板._chat_input.text = "有喇叭的一句"
	面板._send_chat()
	_记(后端桩.发过.size() == 1 and int(后端桩.发过[0][1]) == 8,
			"有喇叭 ⇒ 发 type=8（`ChatMessageType.LABA`）", str(后端桩.发过))
	_记(面板._chat_messages.is_empty(), "喇叭不进消息列表（`ChatPane.setMsg:1659-1664` 转给 speakerPane）",
			_页文())
	_清()
	_收(8, 256, "服务端喇叭", 别人的名)
	_记(面板._chat_messages.is_empty(), "服务端来的喇叭帧同样不进 `_chat_messages`")
	_记(面板._喇叭列表 != null and 面板._喇叭列表.get_child_count() == 1,
			"它走独立浮条（浮条长出一行）",
			str(面板._喇叭列表.get_child_count() if 面板._喇叭列表 != null else -1))

## ── ⑧ 私聊解析：`/名 正文`、坏格式、发完留前缀 ────────────────────────────
func _量私聊() -> void:
	_清()
	后端桩.发过.clear()
	面板._selected_channel = 1	# 私聊
	_放CD()
	面板._chat_input.text = "/%s 晚上打本" % 别人的名
	面板._send_chat()
	_记(后端桩.发过.size() == 1, "私聊发得出去", str(后端桩.发过))
	if 后端桩.发过.size() == 1:
		var 帧: Array = 后端桩.发过[0]
		_记(String(帧[0]) == "晚上打本", "上行**只带正文**，`/名 ` 前缀不进正文", String(帧[0]))
		_记(int(帧[1]) == 4, "私聊 type=4（`ChatMessageType.WHISPER`）", str(帧))
		_记(String(帧[3]) == 别人的名, "对象名走 target_name（原版事件只带 `playName`）", str(帧))
		_记(int(帧[2]) == 0,
				"目标角色号恒 0 ⇒ 服务端按名字找人（`__sendMsg:1029-1036` 只塞了 playName）", str(帧))
	_记(面板._chat_input.text == "/%s " % 别人的名, "发完保留「/对象名 」（`__sendMsg:978`）",
			面板._chat_input.text)
	for 坏 in ["没有斜杠的一句", "/只名字", "/名字 ", "/ 光杆"]:
		_清()
		后端桩.发过.clear()
		_放CD()
		面板._chat_input.text = 坏
		面板._send_chat()
		_记(后端桩.发过.is_empty(), "私聊坏格式「%s」不发包" % 坏, str(后端桩.发过))
		_记(_最后bbcode().contains("私聊格式：/玩家名 消息"),
				"坏格式给出格式提示（本工程把提示落成一条聊天行）", _最后bbcode())
	面板._selected_channel = 4

## ── ⑨ 上行帧形状：桩捕获的参数 + 后端与夹具两侧字面 ───────────────────────
func _量上行帧() -> void:
	_清()
	后端桩.发过.clear()
	面板._selected_channel = 4	# 世界
	_放CD()
	面板._chat_input.text = "帧形一句"
	面板._send_chat()
	_记(后端桩.发过.size() == 1 and String(后端桩.发过[0][0]) == "帧形一句"
			and int(后端桩.发过[0][1]) == 7,
			"世界频道 ⇒ (正文, type=7)（`ChatMessageType.WORLD`）", str(后端桩.发过))
	_记(面板._chat_messages.is_empty(),
			"在线发出去时**不**本地回显（等服务端那一帧，免得同句两遍）", _页文())
	var 后端文 := FileAccess.get_file_as_string(后端脚本)
	_记(后端文.contains("const OP_CHAT := 1536"),
			"`OP_CHAT = 1536`（`SendOpCodes.CHAT_MESSAGE = ReceiveOpCodes.CHAT_MESSAGE`）")
	_记(后端文.contains("\"1536:0:0:%d:0:%d:%s:-:%s\""),
			"`request_chat` 的帧形 = `1536:charType:positions:type:targetCharType:targetId:正文:tag:对象名`")
	_记(后端文.contains(".replace(\":\", \" \").replace(\"@\", \" \").replace(\"&\", \" \")"),
			"正文里 `:` `@` `&` 先换掉（夹具按 `:` 分段，正文只允许占一段）")
	var 夹 := FileAccess.get_file_as_string(服务端路)
	_记(夹.contains("if len(fields) < 8:") and 夹.contains("message = \":\".join(fields[5:-2]).strip()"),
			"夹具仍按「8 段下限 + 正文取 5..-2」解这一帧 ⇒ 我们动段序它会静默丢消息")
	_记(夹.contains("4: 16,") and 夹.contains("7: 128,") and 夹.contains("8: 257,"),
			"夹具的 type→positions 映射没变（私聊 16 / 世界 128 / 喇叭 257）")
	_记(夹.contains("target = self.hub.session_for_name(target_name)"),
			"目标号为 0 时夹具按名字找人 ⇒ 上面「target_id 恒 0」那条才有落点")

## ── ⑩ 字面钉与旧账 ────────────────────────────────────────────────────────
func _量字面() -> void:
	var 文 := FileAccess.get_file_as_string(面板脚本)
	var 入口 := _段(文, "func _on_backend_chat")
	_记(入口.contains("是我说的") and 入口.contains("authoritative_stats"),
			"`_on_backend_chat` 里 is_self 是**算**出来的（名字相等），且优先读这条连接的权威属性")
	_记(not 入口.contains("_format_chat_message(channel, 发言人, String(message.get(\"message\", \"\")), true"),
			"没再被硬写成 `true`（074dd89 那次 `-X ours` 合并就是把它埋回去的，§3.255）")
	_记(入口.contains("UI.as:363"), "判据的 AS3 出处写在代码里（`param1.charName == stats.name`）")
	var 键段 := _段(文, "func _on_chat_input_gui_input")
	_记(键段.contains("KEY_ESCAPE") and 键段.contains("release_focus()"), "ESC / 空正文那格在处理器里")
	_记(键段.find("KEY_ESCAPE") >= 0 and 键段.find("_input_history.is_empty()") > 键段.find("KEY_ESCAPE"),
			"顺序：ESC 判在「没历史就 return」**之前**（否则一次没发过言就退不出输入框）")
	_记(键段.contains("KEY_LEFT") and 键段.contains("KEY_RIGHT") and 键段.contains("KEY_KP_ENTER"),
			"空正文时 左/右/小键盘回车 同样放出焦点（`ChatPane.as:823-830`）")
	var 舞台 := _段(文, "func _unhandled_key_input")
	_记(舞台.contains("KEY_ENTER") and 舞台.contains("grab_focus()"),
			"舞台级 ENTER 抢焦点那格存在（`ChatPane.as:835-847`）")
	_记(舞台.contains("get_viewport().set_input_as_handled()") and not 舞台.contains("\taccept_event()"),
			"本脚本 `extends CanvasLayer` ⇒ 用视口那份，不是 Control 的 accept_event()")
	_记(舞台.contains("_set_chat_hidden(false)"), "折叠态先展开（本工程输入行会跟着滑出屏幕）")
	_记(文.contains("const WORLD_CHANNEL_TIME_CD := 5000"), "世界 CD = 5000（`ChatPane.as:63`）")
	_记(文.contains("const REPEAT_SEND_CD := 1000"), "全频 CD = 1000（`checkTime():1766`）")
	var 发段 := _段(文, "func _send_chat")
	_记(发段.find("CHAT_TIP_PUBLIC_CHAT_CD") >= 0
			and 发段.find("CHAT_TIP_PUBLIC_CHAT_CD") < 发段.find("_last_world_send_msec = world_now"),
			"世界那道：先判拒绝、再记时间戳（拒绝不推窗口）")
	_记(发段.find("_last_world_send_msec = world_now") < 发段.find("CHAT_TIP_SEND_TOO_FAST"),
			"两道 CD 的**先后**＝原版：先世界、后全频（`__sendMsg:995-1010`）")
	_记(文.contains("speakWords"), "旧账在明面上：普通频道头顶话泡（`UI.as:367-369`）没移植")
	_记(文.contains("§3.255"), "合并把 is_self 撤掉那笔账挂在编年史 §3.255")
	_记(文.contains("§3.239 F"), "PUB_NOTICE/通告条那几块缺面板的旧账仍挂 §3.239 F")
	_记(not 文.contains("POS_DYNAMIC"),
			"DYNAMIC_INFO(1024)/COPY_NOTICE(2048) 仍未按 `UI.as` 分派（别把这条读成已做完）")

func _段(文: String, 头: String) -> String:
	var 起 := 文.find(头)
	if 起 < 0:
		return ""
	var 下 := 文.find("\nfunc ", 起 + 头.length())
	return 文.substr(起, (下 - 起) if 下 > 0 else 文.length() - 起)

func _收尾(致命: String = "") -> void:
	var 现 := _存档字节()
	_记(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（门只喂帧、不落盘）")
	_记(判 == 判满条数, "判据条数 = 登记的 %d 条" % 判满条数, "实判 %d" % 判)
	if 面板 != null and is_instance_valid(面板):
		面板.free()
	if 后端桩 != null and is_instance_valid(后端桩):
		后端桩.free()
	if 会话桩 != null and is_instance_valid(会话桩):
		会话桩.free()
	if 致命 != "":
		红.append(致命)
	for 一 in 红:
		print("!! " + 一)
	print("聊天面板回归：%s（判 %d 项，红 %d 项）" % ["通过" if 红.is_empty() else "不通过", 判, 红.size()])
	quit(1 if not 红.is_empty() else 0)
