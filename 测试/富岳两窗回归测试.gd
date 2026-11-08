extends SceneTree

## 富岳两窗回归门（2026-10-05）：每日环任务（`RefreshDailyQuestWindow` 355×407）
## + 周试炼任务（`DailyQuestWindow` 355×367）—— 宇智波富岳（模板 27）那两行 selection 补行的落地页。
##
## 盯的是**只有跑起来才看得见**的四类事：
##   ① 两扇落地页真开得出、标题/尺寸对（`数据/界面/窗口尺寸.json` 两条 `整框:true`）；
##   ② **没数据时一个数字都不许假造**：次数文本 / 星级 / 鼓励文本 / 格子 / 倒计时全为空或零枚，
##      而状态行要说清"为什么空"并且**真的显形**（`_status` 在场景里 `visible=false`，
##      只断 `.text` 是假绿 —— 那条口径是 2026-10-04 用户抓的）；
##   ③ 喂一条 444 形状的数 ⇒ 运行期件按原版公式长出来：星级枚数与 x、赠送格「末位生效 +
##      `count<=0` 灰化」、奖励/特殊奖励的**盒高把格子容器顶下去**（`:236/:239`）、
##      10 枚格子的折行（`x>331 ⇒ x=24、y+=45`，Ex 组起点是 **6** 不是 10）、倒计时 `mm:ss` 会自己走；
##   ④ 交互面的**分支**：`richDegree>=5` 静默、两枚「今日不再提示」弹框（取消 ⇒ `handler(null)`
##      ⇒ 不改单例字段）、`difiiculty>1` / `richDegree<10` 与那两句通知条、开始任务**两支都关窗**。
##
## ⚠ 四条硬口径：
##   · `push_input` 前钉 `root.size`（无头默认视口拿不到 GUI 命中）；
##   · 改状态与断言之间隔 3 帧；
##   · 本门**不走真网络**（104 请求都进 `测试后端连接` 桩）；只有那两枚勾选会走 `_set_check` 落盘 ⇒ 跑前快照 `game_settings`、
##     跑完还原 + 再存 + **断言还原**（口径见「离线门不许写存档」）；
##   · 窗下沿的钮**过去**可能点不到（`窗口管理.重排层级` 给窗的局部层是 1..N，而 GUI 拾取比的
##     就是这个数 ⇒ 命中被层号 100 的聊天/技能面板吃掉，画序却正常）。
##     **2026-10-06 已修**（改成 `HUD基 110 + i + 1`，门：`窗口行为契约体检` C1b）。
##     这里仍**先试真点**，点不动就如实记「命中通路没量到」，
##     再断「信号确实接了一个处理器」+ 用处理器验分支文案 —— 命中与分支分开说，
##     不是拿 `emit()` 演绿（口径同 `伊鲁卡三窗回归测试._量互换` 末尾那两条）。
##
## 运行：`Godot --headless --path . --script res://测试/富岳两窗回归测试.gd`

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 夹具路 := "res://数据/界面/环任务_夹具.json"
const 日环窗 := preload("res://脚本/界面/窗口/日环任务窗.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")	# 借它直接喂一枚三行文案的勾选弹（①b 段）
const 周窗 := preload("res://脚本/界面/窗口/周试炼任务窗.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 后端脚本 := preload("res://脚本/单例/后端连接.gd")
const 页日 := "日环任务"
const 页周 := "周试炼任务"
const 星级皮 := "res://素材/界面/原版窗口/首领/星级.png"
const 格皮 := "res://素材/界面/原版窗口/通用控件/物品格.png"
const 码环动作 := 104


## 两扇窗「开始任务」只调 HUD 的两条入口；把真 HUD 暂时移出 group，
## 换这只记录桩 ⇒ 能分开钉 status=1（提示条寻路）与 status=2（交付 NPC）。
class 记录HUD:
	extends Node
	var 调用: Array = []
	func 前往NPC(号: int, _显示 := true) -> void:
		调用.append(["前往NPC", 号])
	func _于提示条确定(类: int, 号: int) -> void:
		调用.append(["提示条", 类, 号])

## 语言表逐字（断言用，出处 `en_US$message_properties.as`）
const 次数句 := "今日接取次数  3 （每日最多可接任务20次）\n今日完成次数  1 （完成20次有额外经验奖励）"	# :2206
const 倒计时首 := "距离下次免费刷新任务时间：02:05"														# :1733
const 倒计时后 := "距离下次免费刷新任务时间：02:04"
const 难度最小 := "该任务的难度已达到最小值！"															# :2666
const 回报最大 := "该任务的回报已达到最大值！"															# :1827

var 场景: Node
var 管: Node
var 红数 := 0
var 日志: Array[String] = []
var 夹具日: Dictionary = {}
var 夹具周: Dictionary = {}
var 通知记录: Array[String] = []
var 接通知: Callable
var 假后端: Node
var 记录HUD实例: Node
## 两枚勾选会走 `_set_check` 落盘；`game_settings` 内存还原后重写的字节与原档不必一致
## ⇒ 开场按字节快照、收尾按字节还原。
const 门存档快照 := preload("res://测试/门存档快照.gd")
var _文件前 := {}


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


func _窗(页名: String) -> Node:
	return 管._窗口们.get(页名) as Node


func _页根(页名: String) -> Control:
	var 窗 := _窗(页名)
	if 窗 == null:
		return null
	var 出: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			出 = 子 as Control
	return 出			# 取最后一个：直接调 `_render_*()` 追加的那一页在最后


func _文(件: Node) -> String:
	if 件 is RichTextLabel:
		return (件 as RichTextLabel).text
	if 件 is Label:
		return (件 as Label).text
	return "<不是文本件>"


func _钮(页: Control, 名: String) -> Button:
	return 页.get_node(名) as Button


## 通知条最后一条（空态原因 / 未接那一跳都从这里读）。
func _尾通知() -> String:
	return 通知记录[通知记录.size() - 1] if not 通知记录.is_empty() else ""


func _清通知() -> void:
	通知记录.clear()


func _清请求() -> void:
	if 假后端 != null:
		假后端.sent_requests.clear()


## 桩后端记的是 `{"opcode":104,"content":"动作:任务号"}` —— 判环任务就只看这一条。
func _末请求() -> Dictionary:
	if 假后端 == null or 假后端.sent_requests.is_empty():
		return {}
	return 假后端.sent_requests[假后端.sent_requests.size() - 1] as Dictionary


func _请求条数() -> int:
	return 假后端.sent_requests.size() if 假后端 != null else 0


## 服务端回帧的替身：清掉在途请求，让下一颗钮能再发（真实环境由 444 驱动）。
func _应答(窗: Node, 编号: int) -> void:
	窗.call("_收到环任务进度", {"id": 编号})
	await _等(2)


## 门**自己**按 AS3 `htmlText` 的口径翻一遍（不复用 `确认弹.文案转BBCode`，两边不一致就报红）：
## `<font color='#rrggbb'>` ⇒ `[color=#rrggbb]`、`</font>` ⇒ `[/color]`、`<br/>` ⇒ 换行。
func _翻文案(文: String) -> String:
	var 前 := "<font color='"
	var 出 := 文.replace("</font>", "[/color]").replace("<br/>", "\n").replace("<br>", "\n")
	while true:
		var a := 出.find(前)
		if a < 0:
			break
		var b := 出.find(">", a)
		if b < 0:
			break
		var 色 := 出.substr(a + 前.length(), b - a - 前.length()).replace("'", "").replace('"', "")
		出 = 出.substr(0, a) + "[color=" + 色 + "]" + 出.substr(b + 1)
	return 出


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


func _等_ms(毫秒: int) -> void:
	# 秒表那一段要**真等一秒**：「new 了 Timer 但从不 start」是静默死掉那一类，静态断言抓不到。
	var 时 := create_timer(float(毫秒) / 1000.0)
	await 时.timeout


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_跑")


func _读夹具() -> void:
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(夹具路))
	if typeof(解) != TYPE_DICTIONARY:
		return
	夹具日 = ((解 as Dictionary).get("日环", {}) as Dictionary).duplicate(true)
	夹具周 = ((解 as Dictionary).get("周", {}) as Dictionary).duplicate(true)


func _跑() -> void:
	root.size = Vector2i(960, 560)
	_读夹具()
	if 夹具日.is_empty() or 夹具周.is_empty():
		_记(false, "夹具读不到（%s）⇒ 喂数那两大段**没量到**（不是通过）" % 夹具路)
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	日环窗.新会话()
	# 反馈通道 2026-10-05 起是**通知条**（原版 `API.ui.addNotice`）⇒ 门全程接着它。
	var 会话0 = root.get_node_or_null("/root/GameSession")
	if 会话0 != null:
		接通知 = func(文本: String) -> void: 通知记录.append(文本)
		会话0.notification_requested.connect(接通知)
	假后端 = 测试后端.new()
	假后端.name = "环任务假后端"
	假后端.in_game = true
	root.add_child(假后端)
	await _量环数据链(会话0)
	await _量日环空态()
	await _量日环喂数(页日)
	await _量日环勾选()
	await _量日环钮()
	await _量环接续()
	await _量周空态()
	await _量周喂数()
	await _量周钮()
	await _量服务端环动作()
	收尾("")


func 收尾(致命: String) -> void:
	# 文件级还原（内存里 `game_settings` 已经还原过，但重写出来的字节与原档不必一致）。
	门存档快照.全还原(_文件前)
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	for 一 in 日志:
		print(一)
	print("富岳两窗回归：%s（红 %d 项）" % ["通过" if 红数 == 0 else "不通过", 红数])
	quit(1 if 红数 > 0 else 0)


## ── ⑧ 环任务数据链：444 动态段 → 会话合并 → 窗/追踪同一条定义 ───────────────
##
## 空窗的根因不是「服务端没有环任务」，而是文本 444 把 loopId/dynamicData/finishCount
## 丢了：后端解不出、会话不落库、两扇窗永远只拿到空 `{}`。这一段直接从 base64 段开始，
## 逐层钉到窗的 `BasicQuestInfoData` 形状，证明四层用的是同一份动态定义。
func _量环数据链(会话: Node) -> void:
	日志.append("=== 环任务数据链：base64 动态段 → 会话合并 → 窗数据 ===")
	var 动 := {
		"check": {
			"info": {"level": 3},
			"mobs": {"0": {"id": 1, "count": 20, "map": 100010000}},
		},
		"act": {
			"info": {"level": 4}, "exp": 5200, "money": 1500,
			"item": {"0": {"id": 16000143, "count": 1, "job": 0}},
		},
		"actEx": {"zq": 2},
		"npc": 27,
		"daily_cooldown": {"remain_seconds": 125},
	}
	var 编 := Marshalls.utf8_to_base64(JSON.stringify(动))
	var 解器 = 测试后端.new()
	var 环: Dictionary = 解器._解任务环字段(8002, 编, 7)
	_记(int(环.get("loop_id", 0)) == 8002 and int(环.get("finish_count", 0)) == 7,
			"动态段解出 loop_id=8002 / finish_count=7，实测 %s" % str(环))
	var 动回: Dictionary = (环.get("dynamic_data", {}) as Dictionary).get("act", {})
	_记(int(动回.get("exp", 0)) == 5200 and int(动回.get("money", 0)) == 1500
			and int((动回.get("info", {}) as Dictionary).get("level", 0)) == 4
			and int(((动回.get("item", {}) as Dictionary).get("0", {}) as Dictionary).get("id", 0)) == 16000143,
			"dynamic_data 原样落地（act 段 exp/money/level/item 逐个对上），实测 %s" % str(动回))
	_记(int(环.get("turn_in_npc", "")) == 27, "交付 NPC 从 dynamic.npc 落地，实测 %s" % str(环.get("turn_in_npc", "")))
	var 剩 := int(环.get("cooldown_deadline", 0)) - Time.get_ticks_msec()
	_记(剩 > 124_000 and 剩 <= 125_000,
			"daily_cooldown.remain_seconds=125 ⇒ 本地截止时间约 +125s，实测 %dms" % 剩)
	var 空: Dictionary = 解器._解任务环字段(8001, "-", 0)
	_记(not 空.has("dynamic_data"), "编码是「-」⇒ 不假造 dynamic_data（空环只带 loop/finish）")
	解器.free()

	if 会话 == null:
		_记(false, "拿不到 GameSession ⇒ 合并/构造两段没量到")
		return
	var 静态 := {
		"info": {"type": "daily", "name": "环任务", "loopCount": 20},
		"check": {
			"0": {"lvmin": 20}, "info": {"level": 1},
			"mobs": {"0": {"id": 2, "count": 99}},
		},
		"act": {"info": {"level": 1}, "exp": 100, "money": 100},
		"npc": {"1": 0},
	}
	var 条 := {
		"id": "8001", "loop_id": 3, "finish_count": 7, "flash_status": 1,
		"dynamic_data": 动, "cooldown_deadline": Time.get_ticks_msec() + 125_000,
	}
	var 合: Dictionary = 会话.合并任务定义(条, 静态)
	var 检: Dictionary = (合.get("check", {}) as Dictionary).get("1", {})
	var 奖: Dictionary = (合.get("act", {}) as Dictionary).get("1", {})
	_记(int((检.get("info", {}) as Dictionary).get("level", 0)) == 3
			and int(((检.get("mobs", {}) as Dictionary).get("0", {}) as Dictionary).get("id", 0)) == 1,
			"会话合并：check[\"1\"] 被动态段整段覆盖（等级 3、怪 1），实测 %s" % str(检))
	_记(int(奖.get("exp", 0)) == 5200 and int((合.get("actEx", {}) as Dictionary).get("zq", 0)) == 2,
			"act[\"1\"] / actEx 同样来自动态段")
	_记(int((合.get("npc", {}) as Dictionary).get("1", 0)) == 27, "静态 npc[\"1\"]=0 ⇒ 取动态 npc=27")
	_记(int(((静态.get("check", {}) as Dictionary).get("info", {}) as Dictionary).get("level", 0)) == 1
			and int((静态.get("npc", {}) as Dictionary).get("1", -1)) == 0,
			"合并是先 duplicate 再覆盖 ⇒ **不就地改坏定义表**")
	var 无动: Dictionary = 会话.合并任务定义({"id": "8001"}, 静态)
	_记(无动 == 静态, "没有 dynamic_data ⇒ 原样返回静态定义")
	var 非环 := 静态.duplicate(true)
	非环["info"]["type"] = "branch"
	_记(会话.合并任务定义(条, 非环) == 非环,
			"非 daily/weekly/banghui/mixin 不吃动态段（普通任务的定义不许被环数据串改）")

	var 数: Dictionary = 日环窗.构造数据(条, 合, 0)
	_记(int(数.get("questId", 0)) == 8001 and String(数.get("questType", "")) == "daily"
			and int(数.get("order", 0)) == 3 and int(数.get("totalOrder", 0)) == 20
			and int(数.get("finishCount", 0)) == 7,
			"窗数据：8001/daily/第 3 环/共 20 环/完成 7，实测 %s" % str(数))
	_记(int(数.get("richDegree", 0)) == 4 and int(数.get("difiiculty", 0)) == 3
			and int(数.get("status", 0)) == 1 and int(数.get("endNpcId", 0)) == 27,
			"星级/难度/状态/交付 NPC 全来自动态段（4/3/1/27）")
	_记(String(数.get("require", "")).find("(0/20)") >= 0
			and String(数.get("require", "")).find("event:mob") >= 0,
			"目标文本用动态 check 拼（含 0/20 与怪物链接），实测「%s」" % 数.get("require", ""))
	_记(String(数.get("simpleEncourge", "")).find("5200") >= 0,
			"奖励文本用动态 act 拼（经验 5200），实测「%s」" % 数.get("simpleEncourge", ""))
	var 物: Array = 数.get("encourageItems", [])
	_记(物.size() == 1 and int((物[0] as Dictionary).get("id", 0)) == 16000143
			and int((物[0] as Dictionary).get("count", 0)) == 1,
			"赠送格物品来自动态 act.item，实测 %s" % str(物))
	_记(int(数.get("remainSeconds", 0)) > 124 and int(数.get("remainSeconds", 0)) <= 125,
			"倒计时由 cooldown_deadline 现算（不走静态 remainSeconds）")

	var HUD := get_first_node_in_group("game_hud")
	if HUD == null or not HUD.has_method("_追踪定义条"):
		_记(false, "地图里没有 game_hud ⇒ 追踪定义合并那一条没量到")
		return
	var 旧 = HUD._追踪定义.get("8001", null)
	HUD._追踪定义["8001"] = 静态
	var 合追: Dictionary = HUD._追踪定义条(条)
	_记(int(((合追.get("check", {}) as Dictionary).get("1", {}) as Dictionary).get("info", {}).get("level", 0)) == 3,
			"追踪栏走**同一个** 合并任务定义（check[\"1\"] 等级 3）")
	if 旧 == null:
		HUD._追踪定义.erase("8001")
	else:
		HUD._追踪定义["8001"] = 旧

func _量日环空态() -> void:
	日志.append("=== 日环（355×407）：没喂 444 那条数的时候 ===")
	管.call("全部关闭")
	管.call("打开", 页日)
	var 窗 := _窗(页日)
	_记(窗 != null, "落地页「%s」开出来了" % 页日)
	if 窗 == null:
		return
	await _等(3)
	var 页 := _页根(页日)
	_记(页 != null and String(页.name) == "原版日环任务内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	_记(String(窗._title.text) == "木叶警所环式任务", "标题两扇共用那句（:669），实测 %s" % 窗._title.text)
	_记(absf(窗._window.size.x - 355.0) < 0.6 and absf(窗._window.size.y - 407.0) < 0.6,
			"外框 355×407（`super(355,407,true)` :75），实测 %.0f×%.0f" % [窗._window.size.x, 窗._window.size.y])
	# ⚠ 2026-10-05 用户实机图打回的第一条：`super(...,true)` ⇒ `UIWindow.as:34-40` 会 `new MYellow_background()`
	#   摆在 (8,38)、尺寸 (宽−16, 高−68)。工程里这张皮 = 通用控件/内容面板.png（tag 10，263×252）。
	#   少这一条 ⇒ 整窗露出地图背景（"面板做得太差劲"的根因），而件几何门全绿 —— 所以必须钉运行期显形 + 皮名。
	var 底 = 窗._content_bg
	_记(底 != null and 底.visible, "内容底**显形**（第三参 true ⇒ UIWindow 自画 MYellow_background）")
	var 底皮 := ""
	if 底 != null:
		var 板 := 底.get_theme_stylebox("panel") as StyleBoxTexture
		if 板 != null and 板.texture != null:
			底皮 = String(板.texture.resource_path)
	_记(底皮.get_file() == "内容面板.png",
			"内容底皮 = 内容面板.png（MYellow_background tag10），实测「%s」" % 底皮)
	_记(底 != null and absf(底.position.x - 8.0) < 0.6 and absf(底.position.y - 38.0) < 0.6
			and absf(底.size.x - 339.0) < 0.6 and absf(底.size.y - 339.0) < 0.6,
			"内容底 (8,38) 339×339（`UIWindow.as:37-38 + 64-65`），实测 %s %s" % [str(底.position), str(底.size)])
	_记(_文(页.get_node("说明标题")) == "日环任务说明"
			and absf((页.get_node("说明标题") as Label).get_theme_color("font_color").g - 0x91 / 255.0) < 0.004,
			"说明标题「日环任务说明」#ff9100（RIHUAN_LABEL :2809 + UI_ORANGE :928）")
	_记(_文(页.get_node("说明")).count("\n") == 4,
			"说明是**静态那 5 行**（RIHUAN_DESC_1 :1184，`\r`→`\n`），实测 %d 行"
			% (_文(页.get_node("说明")).count("\n") + 1))
	# 空态硬门：五块运行期件一枚都不许有
	_记(_文(页.get_node("次数文本")) == "", "没数据 ⇒ 次数文本留空（不是写 0/0），实测「%s」" % _文(页.get_node("次数文本")))
	_记(_文(页.get_node("倒计时")) == "", "没数据 ⇒ 倒计时留空（AS3 初始 `getLabel(\"\")`），实测「%s」" % _文(页.get_node("倒计时")))
	_记((页.get_node("星级槽") as Control).get_child_count() == 0, "没数据 ⇒ 星级 0 枚")
	_记((页.get_node("鼓励槽") as Control).get_child_count() == 0, "没数据 ⇒ 鼓励文本不建")
	_记((页.get_node("赠送格槽") as Control).get_child_count() == 0, "没数据 ⇒ 赠送格不建")
	_记(页.get_node_or_null("秒表") == null, "没数据 ⇒ 秒表不挂")
	# ⚠ 2026-10-05 用户实机图打回的那一条：原因**不许写在窗口标题栏上**
	#   （`后端状态` 那件 150×23 就贴在标题行，长句会把「木叶警所环式任务」压掉）
	#   ⇒ 走通知条，并且反过来钉住"标题栏那行没被我们点亮"。
	# 标题栏那件本身会被 `_on_backend_status` 写成「后端：未连接」并置 `visible=false` ——
	# 那是宿主既有的短状态行，不是我们写的长句。判据只看：**不显形**且**短**（压不掉标题）。
	_记(not 窗._status.visible and 窗._status.text.length() < 24,
			"标题栏那行**没有**被写长句（打回项），实测「%s」visible=%s" % [窗._status.text, str(窗._status.visible)])
	_记(_尾通知().find("444") >= 0, "空态原因走**通知条**（原版 addNotice），实测「%s」" % _尾通知())
	# 静态件：两枚勾选与三颗钮在空态也要在（原版 createChildren 建的，不靠回帧）
	var 一 := (页.get_node("勾选槽") as Control).get_child(0) as Control
	var 二 := (页.get_node("勾选槽2") as Control).get_child(0) as Control
	_记((页.get_node("勾选槽") as Control).get_child_count() == 1 and 一 != null
			and _文(一.get_node("文本")) == "自动刷新到5星",
			"第一枚 MCheckBoxF 建在槽里（:209-215 + :1743）")
	_记(二 != null and _文(二.get_node("文本")) == "当点券不够时自动停止", "第二枚建在第二个槽里（:216-223 + :1741）")
	if 一 != null:
		_记(absf((一.get_node("文本") as Label).get_theme_color("font_color").g - 0xF0 / 255.0) < 0.004,
				"两枚字色都是 UI_YELLOW #fff000（:222）")
		_记((一.get_node("标记") as CanvasItem) != null and (一.get_node("点击区域") as Button) != null,
				"复选项组件的 标记 / 点击区域 都在（不靠主题画勾）")
	for 名 in ["立即完成钮", "刷新任务钮", "开始任务钮"]:
		var 钮 := _钮(页, 名)
		_记(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 是手型" % 名)
		_记(钮.pressed.get_connections().size() == 1, "%s 接了一个处理器" % 名)
	_记(_钮(页, "刷新任务钮").text == "刷新任务" and _钮(页, "开始任务钮").text == "开始任务"
			and _钮(页, "立即完成钮").text == "立即完成", "三颗钮的字 :1703 / :2436 / :3202 逐字")


## ── ② 日环：喂一条 444 形状的数 ─────────────────────────────────────────────

func _量日环喂数(_页名: String) -> void:
	日志.append("=== 日环：喂夹具（order=3 / finishCount=1 / richDegree=4 / remainSeconds=125）===")
	var 窗 := _窗(页日)
	if 窗 == null or 夹具日.is_empty():
		_记(false, "窗或夹具不在 ⇒ 这一段**没量到**")
		return
	窗.call("_render_daily_ring", 夹具日)
	await _等(3)
	var 页 := _页根(页日)
	_记(_文(页.get_node("次数文本")) == 次数句,
			"次数文本逐字（DAILY_QUEST 只有两个占位：order 进第一个、finishCount 进第二个），实测「%s」"
			% _文(页.get_node("次数文本")).replace("\n", "\\n"))
	var 星 := 页.get_node("星级槽") as Control
	_记(星.get_child_count() == 4, "星级 = richDegree = 4 枚（:276-283），实测 %d" % 星.get_child_count())
	var 位对 := 星.get_child_count() == 4
	for i in 星.get_child_count():
		var 子 := 星.get_child(i) as TextureRect
		if 子 == null or absf(子.position.x - float(i * 14)) > 0.6 or 子.size != Vector2(14.0, 13.0) \
				or String(子.texture.resource_path) != 星级皮:
			位对 = false
	_记(位对, "每枚 14×13、x = i*14、贴图就是那张 星级.png（StarLevelIconF cid693）")
	var 鼓 := 页.get_node_or_null("鼓励槽/鼓励文本") as RichTextLabel
	_记(鼓 != null and absf(鼓.size.x - 250.0) < 0.6, "鼓励文本宽 250（StructuredText 构造第 2 参 :275）")
	# ⚠ StructuredText 与 TextArea2 **不是同一套行距**：原版实机量到 4 行中心 236/249.5/263.5/277.5
	#   ⇒ 行距 13.8（TextArea2 那 5 行量到 18.0）。Godot 自然行高 12.5 ⇒ separation 取 2。
	#   写成 6 会让这块高 20px、最后一行被 (22,277) 那枚赠送格压住（2026-10-05 打回第二条）。
	_记(鼓 != null and 鼓.get_theme_constant("line_separation") == 2,
			"鼓励文本行距 = 2（StructuredText 实机 14，不是 TextArea2 的 18），实测 %d"
			% (鼓.get_theme_constant("line_separation") if 鼓 != null else -1))
	_记(鼓 != null and 鼓.size.y > 52.0 and 鼓.size.y < 66.0,
			"四行块高 %.0f（4 行 × 14 ⇒ 58 上下），太高就是行距又回到 6" % (鼓.size.y if 鼓 != null else -1.0))
	_记(鼓 != null and 鼓.text == ("[color=#ffffff]任务目标：\n%s任务奖励：\n%s[/color]"
			% [_翻文案(str(夹具日["require"])), _翻文案(str(夹具日["simpleEncourge"]))]),
			"鼓励文本 = :89 那句填 require/simpleEncourge（htmlText 要翻成 BBCode），实测「%s」"
			% (鼓.text.replace("\n", "\\n") if 鼓 != null else "无"))
	var 槽 := 页.get_node("赠送格槽") as Control
	_记(槽.get_child_count() == 1, "赠送格只有**一枚**（原版是单个 `_itemCell` 字段，循环里互相盖 :437-455）")
	if 槽.get_child_count() == 1:
		var 格 := 槽.get_child(0) as Control
		var 末: Dictionary = (夹具日["encourageItems"] as Array)[0] as Dictionary
		_记(格.get_node("数量").text == str(int(末["count"])), "数量 = label，实测 %s" % 格.get_node("数量").text)
		var 全: Rect2 = 格.get_global_rect()
		var 页全: Rect2 = 页.get_global_rect()
		_记(absf(全.position.x - (页全.position.x + 22.0)) <= 0.8
				and absf(全.position.y - (页全.position.y + 248.0)) <= 0.8,
				"赠送格在页面 (22,248)（= countDownLabel.x、319−40−TEXT_GAP=277 再抬 29），实测 (%.0f,%.0f)"
				% [全.position.x - 页全.position.x, 全.position.y - 页全.position.y])
		var 号 := int(末["id"])
		# 原版 `updateItemCell:446-452`：服务端**没给物品号**时摆 `Etc.json` 的
		# `items.flower.itemid` = 16000143（玫瑰花），`count<=0` ⇒ `Style.getDisableFilter()` 灰化
		# （:466-470）。用户实机图里那颗灰掉、写着 0 的格子就是这朵花 ⇒ 空格子=假数据。
		var 图 := 格.get_node_or_null("图标") as TextureRect
		var 路 := (图.texture.resource_path if 图 != null and 图.texture != null else "")
		_记(号 > 0 or 日环窗.花号 == 16000143, "夹具 id=0 走的是**玫瑰花**那一支（Etc.json items.flower.itemid）")
		_记(路.contains("16000143"), "物品号 %d ⇒ 真图标（16000143），实测「%s」" % [号, 路])
		_记(格.material is ShaderMaterial, "count=0 ⇒ 整格套上灰化 shader（getDisableFilter）")
	_记(_文(页.get_node("倒计时")) == 倒计时首, "倒计时 mm:ss 补零（:246-252），实测「%s」" % _文(页.get_node("倒计时")))
	_记(页.get_node_or_null("秒表") != null, "remainSeconds>0 ⇒ 挂上秒表（:288-291 TimerManager.add）")


## ── ③ 两枚勾选（会落盘 ⇒ 快照 / 还原 / 再存 / 断言还原）─────────────────────

func _量日环勾选() -> void:
	日志.append("=== 日环：两枚 MCheckBoxF 的初值 / 翻转 / 落盘与还原（真点一次）===")
	var 窗 := _窗(页日)
	if 窗 == null:
		_记(false, "窗没开 ⇒ 这一段**没量到**")
		return
	var 会话: Node = 窗._session
	var 键表 := ["riHuan_auto", "riHuan_stop"]
	var 快照 := {}
	for 键 in 键表:
		快照[键] = 会话.game_settings.get(键, null)
	var 件 := (_页根(页日).get_node("勾选槽") as Control).get_child(0) as Control
	var 初 := bool((件.get_node("标记") as CanvasItem).visible)
	_记(初 == bool(会话.game_settings.get("riHuan_auto", false)),
			"初值是从 `game_settings.riHuan_auto` 读的（原版 `UIConfig.userCfg.riHuan.auto` :214）")
	await _点(件.get_node("点击区域").get_global_rect().get_center(), 窗)
	# ⚠ 这一下点下去**必然连带整页重建**：`_set_check` → `update_setting` → `settings_changed`
	#   → `_refresh_current`（`功能窗口.gd:329`，十几个信号都挂同一条）⇒ 刚才那个 `件` 已被 free。
	#   所以这里**重新取页**再量 —— 而"重建后的那一枚显示的就是刚落盘的值"正是编辑器=运行期同一条口径。
	var 页2 := _页根(页日)
	var 件2 := (页2.get_node("勾选槽") as Control).get_child(0) as Control
	_记(件2 == 件, "环任务页改成**就地刷新**（`_刷新环任务页` 先接管）⇒ 旧件仍有效、不整页重建")
	var 后 := bool((件2.get_node("标记") as CanvasItem).visible)
	_记(后 == (not 初), "点一下翻转、重建后仍显示新状态（原版 `autoResfreshHandler:200` 只写 userCfg），实测 %s→%s"
			% [str(初), str(后)])
	_记(bool(会话.game_settings.get("riHuan_auto", false)) == 后, "翻转同时写进设置（这条**会落盘** ⇒ 下面立即还原）")
	for 键 in 键表:
		if 快照[键] == null:
			会话.game_settings.erase(键)
		else:
			会话.game_settings[键] = 快照[键]
	if 会话.has_method("_save_local_state"):
		会话.call("_save_local_state")
	var 原 := true
	for 键 in 键表:
		if 快照[键] == null:
			原 = 原 and not 会话.game_settings.has(键)
		else:
			原 = 原 and 会话.game_settings[键] == 快照[键]
	_记(原, "跑完把 `game_settings` 还原回跑前（离线门不许留存档）")


## ── ④ 日环三颗钮的分支 ──────────────────────────────────────────────────────
##
## 2026-11 起这三颗钮**真发 104**（立即完成 10 / 刷新 9 / 开始走寻路），宿主改成
## `_刷新环任务页` 就地刷新 ⇒ 一次点击不再抹掉夹具态，这一段可以一路真点。
## 请求走 `测试后端连接` 的桩（只记 opcode+content），不碰真实连接。

func _量日环钮() -> void:
	日志.append("=== 日环：立即完成 104:10 / 刷新 104:9 / 开始任务 ===")
	var 窗 := _窗(页日)
	if 窗 == null:
		_记(false, "窗没开 ⇒ 这一段**没量到**")
		return
	窗._backend = 假后端		# 桩只记包，真实连接保持原样
	_清请求()
	var 页 := _页根(页日)
	if 页 == null:
		_记(false, "页根不在 ⇒ 这一段**没量到**")
		return
	var 绑 := {"宿主": 窗, "页": 页, "数": 夹具日, "点过": false}
	# ① 立即完成 ⇒ 出**带勾选**的确认框（初值不勾、正文那句填 5）
	窗._show_hint("")
	日环窗._点立即(绑)
	var 弹 := _找弹(窗)
	_记(弹 != null, "点立即完成 ⇒ 出「今日不再提示」那种勾选弹框（`MDialog.showCheckBoxDialog`）")
	if 弹 != null:
		var 正 := 弹.get_node("主体/正文") as RichTextLabel
		_记(正 != null and 正.text.find("直接完成日环任务需要花费") >= 0 and 正.text.find("5元宝或点券") >= 0,
				"正文是 :133 那句、占位填的是 5（`_finishQuestYuanBao`），实测「"
				+ (正.text.replace("
", "\n") if 正 != null else "无") + "」")
		var 勾 := 弹.get_node("主体/勾选") as CheckBox
		_记(勾 != null and 勾.text == "今日不再提示" and not 勾.button_pressed,
				"勾选文案 :1984、初值**不勾**（`showCheckBoxDialog(…, false, …)`）")
		# ①b **多行文案**那一条：正文盒高以前写死"一行"（`15 + 8`）⇒ 两行以上被面板底边裁掉，
		#   勾选行/钮位/整框高全跟着错（10-24 竞技场排名奖那枚三行露半截，根因就在这）。
		#   自己喂三行，期望值手算，不向被测代码要：
		#   `setMessage:411` 高 = textHeight + 8 = 15·3 + 8 = **53**；
		#   `:93` 勾选.y = 14 + 53 + CONTENT_GAP(8) = **75**；
		#   `:101` panelHeight = 75 + 勾选高(19) + BOTTOM_HEIGHT(50) = **144**。
		#   ⚠️ 勾选高 = **19**（`MCheckBox.as:81-82` `_height = upSkin.height`，皮 19×19）；
		#      这里原写 27，是 Godot 主题漏声明回拿兜底盒撑出来的，10-25 已在
		#      `原版皮肤表.gd` 收回（判据在 `测试/勾选框几何回归测试.gd`），期望值同步收 8。
		var 三行弹 := 确认弹.弹勾选(窗._overlay, "第一行\n第二行\n第三行", "今日不再提示", false,
				func(_v: Variant) -> void: pass, "三行勾选弹")
		await _等(3)
		var 三主 := 三行弹.get_node_or_null("主体") as Control
		var 三正 := 三行弹.get_node_or_null("主体/正文") as RichTextLabel
		var 三勾 := 三行弹.get_node_or_null("主体/勾选") as CheckBox
		_记(三正 != null and absf(三正.size.y - 53.0) < 0.6,
				"三行 ⇒ 正文盒高 = 15·3+8 = 53（实得 %s）" % (str(三正.size.y) if 三正 != null else "无正文"))
		_记(三正 != null and 三正.get_content_height() <= int(三正.size.y) + 1,
				"三行**装得下**（内容高 %d ≤ 盒高 %d）—— 这条就是用户实机看到的「露半截」" % [
				三正.get_content_height() if 三正 != null else -1, 三正.size.y if 三正 != null else -1])
		_记(三勾 != null and absf(三勾.position.y - 75.0) < 0.6,
				"勾选行跟着往下走 = 14+53+8 = 75（实得 %s）" % (str(三勾.position.y) if 三勾 != null else "无勾选"))
		_记(三主 != null and absf(三主.size.y - 144.0) < 0.6,
				"整框高 = 75+19+50 = 144（实得 %s）" % (str(三主.size.y) if 三主 != null else "无主体"))
		三行弹.queue_free()
		await _等(3)
		# 取消 ⇒ `handler(null)` ⇒ 单例字段不动、不回显
		var 尾前 := _尾通知()	# 取消那支应当一个字都不多
		await _点(弹.get_node("主体/取消").get_global_rect().get_center(), 窗)
		_记(_找弹(窗) == null, "点取消 ⇒ 弹框关掉（真点，命中在弹框上）")
		_记(_尾通知() == 尾前, "取消那支 `if(param1==null) return` ⇒ 通知条一个字都不多（:419-424）")
	# ② 确定（不勾）⇒ 真发 104:10；在途期间两枚钮禁用
	_清请求()
	日环窗._点立即(绑)
	var 弹2 := _找弹(窗)
	_记(弹2 != null, "第二次点仍然弹（没勾「不再提示」⇒ `showFinishQuestWindow` 还是 true）")
	(弹2.get_node("主体/确定") as Button).pressed.emit()
	await _等(2)
	var 末 := _末请求()
	_记(int(末.get("opcode", 0)) == 码环动作 and String(末.get("content", "")) == "10:8001",
			"确定 ⇒ 立即完成真发包 OP_QUEST_ACTION(104) 「10:8001」，实测 %s" % str(末))
	_记(_请求条数() == 1, "一次确定只发一发，实测 %d" % _请求条数())
	var 页在途 := _页根(页日)
	_记(_钮(页在途, "立即完成钮").disabled and _钮(页在途, "刷新任务钮").disabled,
			"在途 ⇒ 两枚钮都禁用（点不到第二下，服务端不会被同一动作连打）")
	await _应答(窗, 8001)
	_记(not _钮(页在途, "立即完成钮").disabled, "收到 444 进度 ⇒ 钮恢复可点")
	# ③ 勾上「今日不再提示」再确定 ⇒ 之后**不再弹**
	_清请求()
	日环窗._点立即(绑)
	var 弹3 := _找弹(窗)
	_记(弹3 != null, "第三次点仍然弹（「今日不再提示」还没勾）")
	if 弹3 != null:
		(弹3.get_node("主体/勾选") as CheckBox).button_pressed = true
		(弹3.get_node("主体/确定") as Button).pressed.emit()
		await _等(2)
	_记(String(_末请求().get("content", "")) == "10:8001", "勾选后确定同样发 104「10:8001」")
	await _应答(窗, 8001)
	_清请求()
	日环窗._点立即(绑)
	_记(_找弹(窗) == null, "勾了「今日不再提示」⇒ 之后**不再弹框**（`showFinishQuestWindow = !param1` :425）")
	_记(String(_末请求().get("content", "")) == "10:8001",
			"不弹框也直接发 104「10:8001」（原版 `sureFinishOneDailyQuest(true)`）")
	await _应答(窗, 8001)
	# ④ 刷新任务：满 5 星**静默**
	页 = await _重喂日环()
	_清通知()
	_清请求()
	var 满: Dictionary = 夹具日.duplicate(true)
	满["richDegree"] = 5
	日环窗._点刷新({"宿主": 窗, "页": 页, "数": 满, "点过": false})
	await _等(2)
	_记(_请求条数() == 0 and 通知记录.is_empty() and _找弹(窗) == null,
			"richDegree>=5 ⇒ 点刷新**什么都不发生**（连弹框也不出，`refreshHandler:80-83` 直接 return）")
	# ⑤ 刷新任务：有倒计时 ⇒ 弹框那一支；没倒计时 ⇒ 免费那一支
	_清通知()
	_清请求()
	日环窗._点刷新({"宿主": 窗, "页": 页, "数": 夹具日, "点过": false})
	var 弹4 := _找弹(窗)
	_记(弹4 != null and 弹4.get_node("主体/正文").text.find("刷新日环任务奖励需要花费") >= 0
			and 弹4.get_node("主体/正文").text.find("10元宝或点券") >= 0,
			"remainSeconds>0 ⇒ :411 那句、占位填的是 10（`_refreshQuestYuanBao`）")
	if 弹4 != null:
		(弹4.get_node("主体/确定") as Button).pressed.emit()
		await _等(2)
	_记(String(_末请求().get("content", "")) == "9:8001", "倒计时未走完 ⇒ 确定真发 104「9:8001」")
	await _应答(窗, 8001)
	_清请求()
	日环窗._点刷新({"宿主": 窗, "页": 页, "数": {"richDegree": 1, "remainSeconds": 0}, "点过": false})
	await _等(2)
	_记(_找弹(窗) == null and String(_末请求().get("content", "")) == "9:8001",
			"remainSeconds=0 ⇒ **不弹框**直接发 104「9:8001」（免费那一支，`refreshHandler:79-99`）")
	await _应答(窗, 8001)
	# ⑥ 秒表：真的挂了、真的是 1 秒周期；每一 tick 干什么用**引擎自己那个 timeout** 打一下看
	页 = await _重喂日环()
	var 表 := 页.get_node_or_null("秒表") as Timer
	_记(表 != null and not 表.is_stopped() and absf(表.wait_time - 1.0) < 0.001 and not 表.one_shot,
			"秒表挂着、1.0 秒周期、重复（`TimerManager.as:37` `new Timer(1000)`）")
	_记(_文(页.get_node("倒计时")) == 倒计时首, "挂上时先按当前值出一次字，实测「%s」" % _文(页.get_node("倒计时")))
	表.timeout.emit()
	await _等(2)
	_记(_文(页.get_node("倒计时")) == 倒计时后, "timeout 打一下 ⇒ 自己减一格（`updateCountTime:246-256`），实测「%s」" % _文(页.get_node("倒计时")))
	# ⑦ 开始任务：两支（进行中 ⇒ 提示条寻路；已完成 ⇒ 交付 NPC），两支都**必关窗**
	页 = await _重喂日环()
	var 真HUD := get_first_node_in_group("game_hud")
	var 记录 := 记录HUD.new()
	记录.name = "环任务记录HUD"
	root.add_child(记录)
	if 真HUD != null:
		真HUD.remove_from_group("game_hud")
	记录.add_to_group("game_hud")
	日环窗._点开始({"宿主": 窗, "页": 页, "数": 夹具日, "点过": false})
	_记(记录.调用.size() == 1 and String(记录.调用[0][0]) == "提示条" and int(记录.调用[0][2]) == 8001,
			"status=1 ⇒ 进行中走提示条寻路（`_于提示条确定(0, 8001)`），实测 %s" % str(记录.调用))
	_记(not bool(窗.call("已打开")), "点开始任务**必然关窗**（`startHandler` 末尾 `onCloseBtnClick(null)`）")
	var 已完: Dictionary = 夹具日.duplicate(true)
	已完["status"] = 2
	日环窗._点开始({"宿主": 窗, "页": 页, "数": 已完, "点过": false})
	_记(记录.调用.size() == 2 and String(记录.调用[1][0]) == "前往NPC" and int(记录.调用[1][1]) == 27,
			"status=2 ⇒ 已完成后找交付 NPC 27（`前往NPC(endNpcId)`），实测 %s" % str(记录.调用))
	记录.remove_from_group("game_hud")
	记录.queue_free()
	if 真HUD != null:
		真HUD.add_to_group("game_hud")
	await _等(2)


## 重新喂夹具 ⇒ 返回**当前**那一页。宿主的任何一次重建都会把夹具态抹掉（这两扇没有会话级
## 数据源 ⇒ 重建就回到空态；对照：兑换商店重建后自己从 `authoritative_exchange` 把行读回来），
## 所以凡是要读运行期件的段都先重喂一次。
func _重喂日环() -> Control:
	var 窗 := _窗(页日)
	窗.call("_render_daily_ring", 夹具日)
	await _等(2)
	return _页根(页日)


## 找那一枚「带勾选的确认弹」（`MDialog.showCheckBoxDialog` 的 Godot 侧 = `确认弹.弹勾选`）：
## 它给自己打了 `mdialog = "checkbox"` 这个**ASCII** meta（中文 meta 键会被静默丢掉）。
func _找弹(窗: Node) -> Control:
	var 遮 := 窗.get_node_or_null("遮罩") as Control
	if 遮 == null:
		return null
	var 栈: Array = [遮]
	while not 栈.is_empty():
		var n: Node = 栈.pop_back()
		if n.has_meta("mdialog") and String(n.get_meta("mdialog")) == "checkbox" \
				and is_instance_valid(n) and not n.is_queued_for_deletion():
			return n as Control
		for c in n.get_children():
			栈.append(c)
	return null


## 真点一下：移动 → 按下 → 松手，每步隔 2~3 帧（口径同 `伊鲁卡三窗回归测试._点`）。
func _点(位: Vector2, 窗: Node) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	root.push_input(移)
	await _等(2)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位
	按.global_position = 位
	root.push_input(按)
	await _等(2)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 位
	放.global_position = 位
	root.push_input(放)
	await _等(3)


## ── ⑤ 环任务接续：杀怪名去 HTML + 交完自动接下一环（窗不关、数字跟新）────────
##
## 用户 2026-11-07 报的三条里，两条落在这里：
##   · 杀怪目标名带着 `<a href='event:mob…'>` 一串字（`任务窗口._指标符` 原样给的是 AS3 htmlText）；
##   · 交完当前环后，富岳再给的那条 `42:1:8001` 把**开着**的窗切掉（`窗口管理.打开或收起` 对已开窗是关闭），
##     且没有在途请求时 `444:2` 被丢掉 ⇒ 窗停在交完的那条。
func _量环接续() -> void:
	日志.append("=== 日环：杀怪名去 HTML / 无在途请求也跟新 / 自动接上不关窗 ===")
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	var HUD := get_first_node_in_group("game_hud")
	if 会话 == null or HUD == null:
		_记(false, "缺 GameSession 或 game_hud ⇒ 这一段**没量到**")
		return
	var 动甲 := {
		"check": {"info": {"level": 2},
			"mobs": {"0": {"id": 1000011, "count": 12, "map": 103020000}}},
		"act": {"info": {"level": 1}, "exp": 300, "money": 10},
		"npc": 39,
	}
	var 条甲 := {"id": "8001", "loop_id": 2, "finish_count": 0, "flash_status": 1,
		"dynamic_data": 动甲, "cooldown_deadline": Time.get_ticks_msec() + 125_000}
	var 定甲: Dictionary = 会话.合并任务定义(条甲, 游戏数据.取表("任务").get("8001", {}))
	var 数甲: Dictionary = 日环窗.构造数据(条甲, 定甲, 0)
	_记(String(数甲.get("require", "")).find("<a href='event:mob") >= 0,
			"前提：`_指标符` 的杀怪行**本来带** `<a href='event:mob…'>`（正是用户看到的那串字）")
	管.call("全部关闭")
	管.call("打开", 页日)
	await _等(3)
	var 窗 := _窗(页日)
	if 窗 == null:
		_记(false, "日环窗没开 ⇒ 这一段**没量到**")
		return
	窗.call("_render_daily_ring", 数甲)
	await _等(3)
	var 页 := _页根(页日)
	var 鼓 := 页.get_node_or_null("鼓励槽/鼓励文本") as RichTextLabel
	_记(鼓 != null and 鼓.text.find("<") < 0 and 鼓.text.find("event:") < 0,
			"页上杀怪名**没有**残留 `<…>` / `event:`（htmlText 已翻成 BBCode），实测「%s」"
			% (鼓.text.replace("\n", "\\n") if 鼓 != null else "无"))
	_记(鼓 != null and 鼓.text.find("流浪叛忍") >= 0 and 鼓.text.find("(0/12)") >= 0,
			"只剥标签、不丢字：怪名「流浪叛忍」与 0/12 都在，实测「%s」"
			% (鼓.text.replace("\n", "\\n") if 鼓 != null else "无"))
	# 服务端交完一环直接接下一环并推 `444:2`（`_complete_original_quest:58194` 那一支）；
	# 客户端此刻**没有在途 104 请求**，旧代码把这条帧整个丢掉 ⇒ 窗停在交完的那条。
	var 备份: Array = 会话.accepted_quests.duplicate(true)
	var 动乙 := {
		"check": {"info": {"level": 3},
			"mobs": {"0": {"id": 1000011, "count": 20, "map": 103020000}}},
		"act": {"info": {"level": 2}, "exp": 600, "money": 20},
		"npc": 61,
	}
	会话.accepted_quests.clear()
	会话.accepted_quests.assign([{
		"id": "8001", "loop_id": 5, "finish_count": 9, "flash_status": 1,
		"dynamic_data": 动乙, "cooldown_deadline": Time.get_ticks_msec() + 125_000,
	}])
	窗.call("_收到环任务进度", {"id": 8001})
	await _等(3)
	页 = _页根(页日)
	var 次数 := _文(页.get_node("次数文本"))
	_记(次数.find("今日接取次数  5") >= 0 and 次数.find("今日完成次数  9") >= 0,
			"没有在途请求，`444:2` 也要把页跟到下一环（第 5 环 / 完成 9），实测「%s」"
			% 次数.replace("\n", "\\n"))
	# 下一环的 `42:1` 走 `_开环任务窗`：原版 `QuestDataManager.startQuest:290-296` 是 `setDOShow(…, true)`。
	# `request_feature` 那条链到 `窗口管理.打开或收起`，对已开窗是**关闭** ⇒ 窗会自己消失。
	HUD.call("_开环任务窗", 8001)
	await _等(3)
	_记(bool(窗.call("已打开")), "自动接下一环后环任务窗**仍然开着**（不是被切换关掉）")
	页 = _页根(页日)
	次数 = _文(页.get_node_or_null("次数文本"))
	_记(次数.find("今日接取次数  5") >= 0,
			"重开一页也接的是新那环（不是空态/旧数），实测「%s」" % 次数.replace("\n", "\\n"))
	会话.accepted_quests.clear()
	会话.accepted_quests.assign(备份)
	管.call("全部关闭")
	await _等(2)


## ── ⑥ 周试炼：空态 + 类名陷阱 ───────────────────────────────────────────────

func _量周空态() -> void:
	日志.append("=== 周试炼（355×367）：空态 ===")
	管.call("全部关闭")
	管.call("打开", 页周)
	var 窗 := _窗(页周)
	_记(窗 != null, "落地页「%s」开出来了" % 页周)
	if 窗 == null:
		return
	await _等(3)
	var 页 := _页根(页周)
	_记(页 != null and String(页.name) == "原版周试炼任务内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	_记(String(窗._title.text) == "木叶警所环式任务", "两扇**同标题**（:669），别以为是两句话")
	_记(absf(窗._window.size.y - 367.0) < 0.6, "外框高 367（`super(355,367,true)` :49），实测 %.0f" % 窗._window.size.y)
	var 底2 = 窗._content_bg
	var 底皮2 := ""
	if 底2 != null:
		var 板2 := 底2.get_theme_stylebox("panel") as StyleBoxTexture
		if 板2 != null and 板2.texture != null:
			底皮2 = String(板2.texture.resource_path)
	_记(底2 != null and 底2.visible and 底皮2.get_file() == "内容面板.png",
			"周试炼同口径：内容底显形 + 皮 MYellow_background，实测「%s」" % 底皮2)
	_记(底2 != null and absf(底2.size.x - 339.0) < 0.6 and absf(底2.size.y - 299.0) < 0.6,
			"内容底 339×299（`super(355,367,true)` ⇒ 高 367−68），实测 %s" % str(底2.size))
	for 名 in ["说明", "奖励文本", "特殊奖励文本"]:
		_记(_文(页.get_node(名)) == "", "没数据 ⇒ %s 留空（全在 onDataCompelete 里填）" % 名)
	for 名 in ["追踪槽", "奖励格槽", "特殊格槽"]:
		_记((页.get_node(名) as Control).get_child_count() == 0, "没数据 ⇒ %s 零枚" % 名)
	_记(not 窗._status.visible and 窗._status.text.length() < 24 and _尾通知().find("444") >= 0,
			"周试炼同口径：原因走通知条、标题栏那行不亮，实测「%s」visible=%s 通知「%s」"
			% [窗._status.text, str(窗._status.visible), _尾通知()])
	_记(_钮(页, "降难度钮").text == "降低任务难度" and _钮(页, "提回报钮").text == "提升奖励回报",
			"两枚钮的字 :1769 / :932 逐字（⚠ 82 宽整帧拉伸，与日环那三枚 54 宽**不同度量**）")
	var 皮 := (_钮(页, "降难度钮").get_theme_stylebox("normal") as StyleBoxTexture)
	_记(皮 != null and String(皮.texture.resource_path) == "res://素材/界面/原版窗口/环任务/降难度钮.png",
			"降难度钮的常态皮是本页烘的那张（不是通用钮），实测 %s" % (皮.texture.resource_path if 皮 != null else "无"))


## ── ⑥ 周试炼：喂夹具 ⇒ 盒高公式 + 10 枚格子折行 ─────────────────────────────

func _量周喂数() -> void:
	日志.append("=== 周试炼：喂夹具（order=12 / totalOrder=100 / finishCount=7 / 10 枚奖励格）===")
	var 窗 := _窗(页周)
	if 窗 == null or 夹具周.is_empty():
		_记(false, "窗或夹具不在 ⇒ 这一段**没量到**")
		return
	窗.call("_render_weekly_ring", 夹具周)
	await _等(3)
	var 页 := _页根(页周)
	var 说 := _文(页.get_node("说明"))
	_记(说.find("本周接取次数   12 ") >= 0 and 说.find("木叶警所任务 100 次") >= 0
			and 说.find("本周完成次数   7 ") >= 0,
			"WEEKLY_QUEST 三个变参各就各位（:1460 + `getQuestString:177-183`），实测「%s」" % 说.replace("\n", "\\n"))
	_记(说.begins_with("[color=#ffffff][color=#ff9100]"), "外层白 + 内层橙**嵌套**照原版（别拉平成一色）")
	var 追 := 页.get_node_or_null("追踪槽/追踪文本") as RichTextLabel
	_记(追 != null and 追.text.find("难度： 3 ") >= 0 and 追.text.find(_翻文案(str(夹具周["require"]))) >= 0,
			"追踪文本 = DIFFICULTY+REQUIRE 两句拼（:227-232，require 是 htmlText ⇒ 翻成 BBCode），实测「%s」"
			% (追.text.replace("\n", "\\n") if 追 != null else "无"))
	_记(追 != null and absf(追.size.x - 321.0) < 0.6, "追踪文本宽 321 = 331−BORDER_GAP*2（:228）")
	# 盒高公式 ⇒ 格子容器被顶下去（`:236` 容器 y = 文本 y + 文本高）
	var 奖 := 页.get_node("奖励文本") as RichTextLabel
	_记(absf(奖.size.y - 46.0) < 0.6,
			"奖励文本 2 行 ⇒ 盒高 = 15·2+(2−1)·4+4+2·4 = 46（TextArea2.as:122-126），实测 %.1f" % 奖.size.y)
	var 槽一 := 页.get_node("奖励格槽") as Control
	_记(absf(槽一.position.y - 185.0) < 0.6, "奖励格槽 y = 139+46 = 185（**不是烘的 151**），实测 %.1f" % 槽一.position.y)
	_记(槽一.get_child_count() == 10, "10 枚奖励格（喂夹具就是要量折行那一支），实测 %d" % 槽一.get_child_count())
	var 期望x: Array = [10.0, 55.0, 100.0, 145.0, 190.0, 235.0, 280.0, 325.0, 24.0, 69.0]
	var 期望y: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 45.0, 45.0]
	var 排对 := 槽一.get_child_count() == 10
	for i in mini(槽一.get_child_count(), 10):
		var 格 := 槽一.get_child(i) as Control
		if 格 == null or absf(格.position.x - float(期望x[i])) > 0.6 or absf(格.position.y - float(期望y[i])) > 0.6:
			排对 = false
	_记(排对, "折行判据「先加后判」：x>331 ⇒ x 回 **24**、y += 45（:250-254），第 9 枚应在 (24,45)")
	var 特 := 页.get_node("特殊奖励文本") as RichTextLabel
	_记(absf(特.size.y - 42.0) < 0.6, "特殊奖励 2 行、paddingV=2 ⇒ 30+4+4+4 = 42，实测 %.1f" % 特.size.y)
	var 槽二 := 页.get_node("特殊格槽") as Control
	_记(absf(槽二.position.y - 266.0) < 0.6, "特殊格槽 y = 224+42 = 266（:239），实测 %.1f" % 槽二.position.y)
	_记(槽二.get_child_count() == 1, "Ex 组 1 枚（:265-285）")
	if 槽二.get_child_count() == 1:
		var 格2 := 槽二.get_child(0) as Control
		_记(absf(格2.position.x - 6.0) < 0.6, "Ex 那组起点 x = **6**（:263，与上一组的 10 只差这一个数），实测 %.0f" % 格2.position.x)
		_记(String((格2 as TextureRect).texture.resource_path) == 格皮
				and 格2.get_node("数量").horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
				"格子是那张 物品格.png、数量右对齐（SimpleItemCell.as:136-144）")
	var 有图 := 0
	for i in 槽一.get_child_count():
		if 槽一.get_child(i).get_node_or_null("图标") != null:
			有图 += 1
	_记(有图 == 10, "10 枚格子**全都有图标** ⇒ 夹具里的号在读者物品表里都解得出（实测 %d/10）" % 有图)


## ── ⑦ 周试炼：降难度 104:8 / 提回报 104:9 / 开始任务 ────────────────────────

func _量周钮() -> void:
	日志.append("=== 周试炼：降难度 / 提回报 / 开始任务 ===")
	var 窗 := _窗(页周)
	if 窗 == null:
		_记(false, "窗没开 ⇒ 这一段**没量到**")
		return
	窗._backend = 假后端
	var 页 := _页根(页周)
	if 页 == null:
		_记(false, "页根不在 ⇒ 这一段**没量到**")
		return
	_清通知()
	_清请求()
	# 够格 ⇒ 打开真 EnlargeWindow（原来那一支写的是"未接"）
	周窗._点降(窗, 夹具周.duplicate(true))
	await _等(2)
	var 调整 := 页.get_node_or_null("任务调整") as Control
	_记(调整 != null and 调整.visible,
			"difiiculty=3>1 ⇒ 开真 EnlargeWindow（`QuestDataManager.as:169-177`）")
	if 调整 != null:
		_记(String((调整.get_node("标题") as Label).text) == "改变任务", "标题「改变任务」")
		_记((调整.get_node("需要数") as Label).text.find("1个乾坤密卷") >= 0,
				"需要数 = 「改变任务需要在背包中有1个乾坤密卷」，实测「%s」"
				% (调整.get_node("需要数") as Label).text)
		_记(not (调整.get_node("获得途径") as Label).visible, "改变任务隐藏「获得途径」（:200-204）")
		_记(absf((调整.get_node("说明") as Label).size.y - 105.0) < 0.6,
				"说明盒高 105（`:125`），实测 %.0f" % (调整.get_node("说明") as Label).size.y)
		var 拥有: int = int(窗._背包数量(16000005))
		_记((调整.get_node("确定") as Button).disabled == (拥有 < 1),
				"拥有 %d 个乾坤密卷 ⇒ 「确定」%s（:92-98 不足不给点）"
				% [拥有, "禁用" if (调整.get_node("确定") as Button).disabled else "可点"])
		调整.emit_signal("确认扩充", "任务")
		await _等(2)
	_记(String(_末请求().get("content", "")) == "8:8002", "确认 ⇒ 降难度真发 104「8:8002」")
	await _应答(窗, 8002)
	var 低: Dictionary = 夹具周.duplicate(true)
	低["difiiculty"] = 1
	_清通知()
	_清请求()
	周窗._点降(窗, 低)
	_记(通知记录.size() == 1 and 通知记录[0] == 难度最小,
			"difiiculty<=1 ⇒ **通知条**那句（:2666），实测 %s" % str(通知记录))
	_记(_请求条数() == 0, "已最小 ⇒ 一个包都不发，实测 %d" % _请求条数())
	# 提回报 ⇒ 同一扇 EnlargeWindow，确认后发 9
	_清请求()
	周窗._点提(窗, 夹具周.duplicate(true))
	await _等(2)
	var 调整2 := 页.get_node_or_null("任务调整") as Control
	_记(调整2 != null and 调整2.visible, "richDegree=6<10 ⇒ 同样开真 EnlargeWindow")
	if 调整2 != null:
		调整2.emit_signal("确认扩充", "任务")
		await _等(2)
	_记(String(_末请求().get("content", "")) == "9:8002", "提升 ⇒ 真发 104「9:8002」")
	await _应答(窗, 8002)
	var 高: Dictionary = 夹具周.duplicate(true)
	高["richDegree"] = 10
	var 旧调整 := 页.get_node_or_null("任务调整")
	_清通知()
	_清请求()
	周窗._点提(窗, 高)
	_记(通知记录.size() == 1 and 通知记录[0] == 回报最大,
			"richDegree>=10 ⇒ **通知条**那句（:1827），实测 %s" % str(通知记录))
	_记(_请求条数() == 0 and 页.get_node_or_null("任务调整") == 旧调整,
			"已满 10 星 ⇒ 一个包都不发、也不再开「改变任务」框，实测 %d 包" % _请求条数())
	# 三颗钮都得是手型 + 各接一个处理器
	for 名 in ["降难度钮", "提回报钮", "开始任务钮"]:
		var 钮 := _钮(页, 名)
		_记(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 是手型" % 名)
		_记(钮.pressed.get_connections().size() == 1, "%s 接了一个处理器" % 名)
	# 开始任务：夹具 status=2 ⇒ 交付 NPC 那一支 + 关窗
	var 真HUD := get_first_node_in_group("game_hud")
	var 记录 := 记录HUD.new()
	记录.name = "环任务记录HUD"
	root.add_child(记录)
	if 真HUD != null:
		真HUD.remove_from_group("game_hud")
	记录.add_to_group("game_hud")
	周窗._点开始(窗, 夹具周.duplicate(true))
	_记(记录.调用.size() == 1 and String(记录.调用[0][0]) == "前往NPC" and int(记录.调用[0][1]) == 27,
			"status=2 ⇒ `前往NPC(27)`（原版 `qusetClickText(3, endNpcId)`），实测 %s" % str(记录.调用))
	_记(not bool(窗.call("已打开")), "同样**点下去就关窗**（:96）")
	记录.remove_from_group("game_hud")
	记录.queue_free()
	if 真HUD != null:
		真HUD.add_to_group("game_hud")
	await _等(2)


## ── ⑧ 服务端环动作锤：104 的 8/9/10 真扣真封顶 ──────────────────────────────
##
## 客户端这几颗钮发的包在 ⑥/⑦ 已逐条钉住；服务端那半边（降难度扣乾坤密卷、
## 周 10 星 / 日 5 星封顶、日刷新 10 点券 + 600s、完成 5 点券转 READY 并结算）
## 只有跑 Python 才看得见 —— 门里 `OS.execute` 调 `测试/环任务动作服务端锤.py`，
## 进程内 `FakeFlashSession.__new__` 驱动真 `_handle_ring_quest_action`，退出码即断言。
## 解释器按仓库约定用 `运行时/python/python.exe`，找不到再退 PATH；都没有 ⇒ 红着说原因。
func _量服务端环动作() -> void:
	日志.append("=== 服务端环动作：104 的 8/9/10 ===")
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/环任务动作服务端锤.py"
	if not FileAccess.file_exists(锤):
		_记(false, "找不到锤脚本 " + 锤)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 输出: Array = []
	var 码 := -1
	for 解释器 in 候选:
		码 = OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
		if 码 >= 0:
			break
	var 末 := ""
	if not 输出.is_empty():
		末 = String(输出[输出.size() - 1]).strip_edges()
	_记(码 == 0, "服务端环动作锤退出码应为 0，实测 %d；末行「%s」" % [码, 末])
	# Windows 上 OS.execute 按 ANSI 码页解进程输出 ⇒ 中文是乱码，别拿文案判绿；
	# 退 0 且**有输出**才算锤真跑完（没解释器时码会是 −1）。
	_记(not 输出.is_empty(), "锤该有输出（Windows 上中文按 ANSI 解码、不比对文案）")
	if 码 != 0:
		for 行 in 输出:
			var 条 := String(行).strip_edges()
			if 条.begins_with("!!!"):
				日志.append(条)
