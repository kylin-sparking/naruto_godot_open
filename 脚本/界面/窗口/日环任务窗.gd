extends RefCounted

## 宇智波富岳（模板 27）菜单第一行「每日环任务」= 原版 `component/RefreshDailyQuestWindow`
## （355×407，标题两扇共用 `DAILY_QUSET_WINDOW_TITLE`「木叶警所环式任务」`:669`）。
##
## 外壳 16 件在 `场景/界面/窗口/环任务/日环任务窗.tscn`（`开发工具/原版服务窗.py 生成 日环任务`
## 从 SPEC 烘出 ⇒ **别手改 .tscn**；逐件 AS3 行号在 SPEC 每条的 `出处` 里，验收口径在
## `game-client/真值/窗口/木叶村NPC.md` §6f）。本文件只做原版 `onDataCompelete` 那批**运行期件**：
## 次数文本、星级、鼓励文本、赠送格、倒计时秒表，加两枚 `MCheckBoxF` 与三颗钮的行为。
##
## ⚠ 数据面：`order / finishCount / richDegree / require / simpleEncourge / encourageItems /
##   remainSeconds` 全在 `BasicQuestInfoData`（public var）上，来自服务端 **444 任务信息帧**
##   （`_send_original_started_quest_list` 等）。离线 / 还没接取时宿主给空 `数` ⇒
##   `渲染()` **只画静态件、一个数字都不假造**，原因写进状态行
##   （`宿主._show_hint`，不是直写 `_status.text` —— 那件默认 `visible=false`）。
##
## ⚠ 交互面：
##   **客户端那半（已照搬）**：满 5 星静默、两枚「今日不再提示」勾选弹（`MDialog.showCheckBoxDialog`）、
##     点券够不够、倒计时每秒走、点开始任务必关窗 —— 行号见各函数。
##   **服务端那半（已接）**：刷新任务 / 免费刷新 / 自动刷新 = **104:9**，立即完成 = **104:10**，
##     统一走 `宿主._环任务操作`（`功能窗口.gd`：发帧 → 等 444 回包 → 原地刷新，10 秒不回就
##     通知并停自动）。「开始任务」是本地寻路 / 找交付 NPC（`_环任务开始`），不走协议。

const 任务文字 := preload("res://素材/界面/任务界面/脚本/任务窗口.gd")
const 复选项场景 := preload("res://场景/界面/组件/原版复选项.tscn")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")

## ⚠ 两条路径**逐条写字面量**：`开发工具/打包木叶村NPC页.py` 的素材扫描与 `页面包闭包.py`
##   都只认字面量，拼串 ⇒ 皮在闭包里查无（= 交包时静默漏皮）。
const 星级皮 := "res://素材/界面/原版窗口/首领/星级.png"
const 格皮 := "res://素材/界面/原版窗口/通用控件/物品格.png"

const 黄 := Color(1, 0xF0 / 255.0, 0)		# UI_YELLOW `UIConfig.as:932`（两枚勾选的字色 `:222`）
const 白 := Color(1, 1, 1)

## 语言表逐字（`en_US$message_properties.as`，**行号写在每条后面**；`\r`→`\n`、`<font>`→BBCode
## 按原样口径转 —— `确认弹.文案转BBCode` 认的是 HTML 那一版，所以两条弹框传的是 `<font>` 原句）
const 次数模板 := "今日接取次数  %1 （每日最多可接任务20次）\n今日完成次数  %2 （完成20次有额外经验奖励）"	# :2206 DAILY_QUEST
const 鼓励模板 := "[color=#ffffff]任务目标：\n%1任务奖励：\n%2[/color]"									# :89 + 外层 <font #ffffff>（`:271-274`）
const 倒计时头 := "距离下次免费刷新任务时间：%1"															# :1733 RIHUAN_COUNT_DOWN_TEXT
const 勾选一 := "自动刷新到5星"																			# :1743
const 勾选二 := "当点券不够时自动停止"																		# :1741
const 刷新弹 := "刷新日环任务奖励需要花费<font color='#FFF000'>%1元宝或点券</font><br><font color='#FF0000'>优先使用点券</font>"	# :411
## 号<=0 时原版拿 Etc 里那朵花（玫瑰花）的 itemid 当图标
## （RefreshDailyQuestWindow.as:446-452）；值取自 数据/原版杂项.json 的 Etc.items.flower.itemid。
const 花号 := 16000143
const 完成弹 := "直接完成日环任务需要花费<font color='#FFF000'>%1元宝或点券</font><br><font color='#FF0000'>优先使用点券</font>"	# :133 RIHUAN_FINISH_QUEST_TIP
const 不再提示 := "今日不再提示"																			# :1984
const 点券不够 := "很抱歉，你的点券不够"																	# :1969 RIHUAN_DIANQUAN_BUGOU

const 要价 := 10			# `RefreshDailyQuestWindow.as:56` `_refreshQuestYuanBao`
const 完成要价 := 5			# `QuestDataManager.as:51` `_finishQuestYuanBao`

const 空态 := "日环的运行期数字（第几环 / 完成次数 / 星级 / 剩余秒 / 奖励物品）只在服务端 444 任务信息帧里 ⇒ 离线或还没接取时只画静态件"

## 原版 `QuestDataManager.showRefreshQuestWindow / showFinishQuestWindow`（`:73/:75`，默认 true）
## 是**单例字段**（会话级、不落盘）⇒ 这里同样用 static，别塞进 `game_settings`。
static var _再提示刷新 := true
static var _再提示完成 := true


## 原版这两枚是 `QuestDataManager` **单例上的字段**：同一次会话里勾了「今日不再提示」就一直不弹，
## 换会话回 true。我们把它做成 static ⇒ 门/量具跑前要能复位，否则上一条断言会把下一条的弹框吃掉。
static func 新会话() -> void:
	_再提示刷新 = true
	_再提示完成 = true


static func 构造数据(条: Dictionary, 定: Dictionary, 职业: int) -> Dictionary:
	var 动态: Dictionary = 条.get("dynamic_data", {})
	var 奖: Dictionary = 动态.get("act", {})
	var 额外: Dictionary = 动态.get("actEx", {})
	var 检: Dictionary = 动态.get("check", {})
	var 信: Dictionary = 定.get("info", {})
	return {
		"questId": int(条.get("id", 0)), "questType": str(信.get("type", "")),
		"order": int(条.get("loop_id", 0)), "totalOrder": int(信.get("loopCount", 0)),
		"finishCount": int(条.get("finish_count", 0)),
		"richDegree": int((奖.get("info", {}) as Dictionary).get("level", 1)),
		"difiiculty": int((检.get("info", {}) as Dictionary).get("level", 1)),
		"status": int(条.get("flash_status", 1)),
		"endNpcId": int((定.get("npc", {}) as Dictionary).get("1", 0)),
		"require": 任务文字._指标符({"check": 定.get("check", {}), "进度": 任务文字._进度表(条)}),
		"simpleEncourge": 任务文字._奖励({"act": {"1": 奖}}),
		"encouragEx": 任务文字._奖励({"act": {"1": 额外}}),
		"encourageItems": _奖励物品(奖, 职业), "encourageItemsEx": _奖励物品(额外, 职业),
		"remainSeconds": maxi(0, ceili((int(条.get("cooldown_deadline", 0)) - Time.get_ticks_msec()) / 1000.0)),
		"cooldown_deadline": int(条.get("cooldown_deadline", 0)),
	}


static func _奖励物品(奖励: Dictionary, 职业: int) -> Array:
	var 出: Array = []
	for 组 in ["item", "equip"]:
		for 物 in 任务文字._列(奖励.get(组, {})):
			if int(物.get("job", 0)) in [0, 职业]:
				出.append({"id": int(物.get("id", 0)), "count": int(物.get("count", 0))})
	return 出


## `宿主` = `功能窗口`（要 `_content` / `_overlay` / `_show_hint` / `_通知` / `_session` / `close`）。
## `数` = 一条 `BasicQuestInfoData` 形状（字段名照 AS3，门喂）；空 ⇒ 只画静态件。
static func 渲染(宿主: Node, 场景: PackedScene, 数: Dictionary = {}) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 绑 := {"宿主": 宿主, "页": 页, "数": 数, "点过": false, "勾一": null, "勾二": null, "自动表": null}
	页.set_meta("ring_quest_binding", 绑)
	_建勾选(页, 宿主, 绑)
	_接钮(页, 绑)
	if 数.is_empty():
		宿主._通知(空态)
		return 页
	填数据(页, 数, 绑)
	return 页


## = 原版 `onDataCompelete`（`:262-306`）：先 `destroy()` 清上一轮的件，再按回帧逐件填。
static func 填数据(页: Control, 数: Dictionary, 绑: Dictionary) -> void:
	绑["数"] = 数
	for 槽名 in ["鼓励槽", "赠送格槽", "星级槽"]:
		for 子 in 页.get_node(槽名).get_children():
			子.get_parent().remove_child(子)
			子.queue_free()
	(页.get_node("次数文本") as RichTextLabel).text = 替(次数模板,
			[str(int(数.get("order", 0))), str(int(数.get("finishCount", 0)))])
	# ⚠ 原版 `getQuestString:290-297` 那两个 `order < 10 ? "" + order : order` 是**无害废话**
	#   （两枝一模一样），别当成「个位数要补零」—— AS3 这里没补零，我们也不补。
	画星(页, int(数.get("richDegree", 0)))
	var 鼓 := RichTextLabel.new()
	鼓.name = "鼓励文本"
	鼓.bbcode_enabled = true
	鼓.scroll_active = false
	鼓.fit_content = true			# StructuredText 的高是量出来的（AS3 没写死 ⇒ 槽烘 0 高）
	鼓.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	鼓.add_theme_font_size_override("normal_font_size", 12)
	鼓.add_theme_constant_override("line_separation", 2)
	鼓.position = Vector2(0.0, 0.0)
	鼓.size = Vector2(250.0, 0.0)	# `:275-277` `new StructuredText(_loc2_, 250)`
	# 目标/奖励两段由 `任务文字._指标符` / `_奖励` 拼出来，里面带 `<font>/<a href='event:…'>` 原版标记；
	# `确认弹.文案转BBCode` 只认 font/br，链接会原样露给玩家（用户 2026-11-07 报
	# 「杀怪的目标名称有一堆字符，例如 <a href=' event」）⇒ 统一走 `富文本.译文为BBCode`。
	鼓.text = 富文本.译文为BBCode(替(鼓励模板, [str(数.get("require", "")), str(数.get("simpleEncourge", ""))]))
	(页.get_node("鼓励槽") as Control).add_child(鼓)
	_填赠送格(页, 数, 绑)
	起秒表(页, int(数.get("remainSeconds", 0)))


## `onDataCompelete:276-283`：`richDegree` 枚 `StarLevelIconF`，`x = i * 宽`（14×13），y 不动。
static func 画星(页: Control, 枚: int) -> void:
	var 槽 := 页.get_node("星级槽") as Control
	for 子 in 槽.get_children():
		子.queue_free()
	for i in maxi(0, 枚):
		var 星 := TextureRect.new()
		星.name = "星%d" % (i + 1)
		星.texture = load(星级皮)
		星.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		星.mouse_filter = Control.MOUSE_FILTER_IGNORE
		星.position = Vector2(float(i * 14), 0.0)
		星.size = Vector2(14.0, 13.0)
		槽.add_child(星)


## `updateItemCell:437-455`（`Config.openZengHua = true`，`Config.as:88`）：原版只有一个
## `_itemCell` **字段** ⇒ 循环里每一枚都在往同一格上盖，最后留下 `encourageItems` 的**末位**、
## 位置按第一次调用的 `i=0` 算（`countDownLabel.x + 0*40`）。这不是我们的简化，是原版的形状。
static func _填赠送格(页: Control, 数: Dictionary, 绑: Dictionary) -> void:
	var 物品: Array = 数.get("encourageItems", [])
	if 物品.is_empty():
		return
	var 末: Dictionary = 物品[物品.size() - 1] as Dictionary
	var 号 := int(末.get("id", 0))
	var 量 := int(末.get("count", 0))
	var 槽 := 页.get_node("赠送格槽") as Control
	for 子 in 槽.get_children():
		子.queue_free()
	var 格 := TextureRect.new()
	格.name = "赠送格"
	格.texture = load(格皮)
	格.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	格.stretch_mode = TextureRect.STRETCH_SCALE
	格.size = Vector2(40.0, 40.0)
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 图标：`ItemFactory.createSingleItem(id)` 之后居中取整（`SimpleItemCell.as:164-165`）。
	# ⚠ `号 <= 0` 时原版拿的是 `ImgUtil.getImg(ImgType.Etc,"flower")` 那朵花的 itemid
	#   （`:446-452`）⇒ 本工程没有这条 Etc 映射，**留空、不假造图标**（已进未收口）。
	if 号 <= 0:
		号 = 花号	# 原版 `：446-452` 拿 Etc 那朵花当图标（值取自 数据/原版杂项.json）
	var 路 := 游戏数据.item_icon_path(号)
	if 路 != "" and ResourceLoader.exists(路):
		var 图 := TextureRect.new()
		图.name = "图标"
		图.texture = load(路)
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var 寸: Vector2 = 图.texture.get_size()
		图.position = Vector2(roundf((40.0 - 寸.x) / 2.0), roundf((40.0 - 寸.y) / 2.0))
		图.size = 寸
		格.add_child(图)
	var 标 := Label.new()
	标.name = "数量"
	标.text = str(量)
	标.position = Vector2(0.0, 20.0)		# `SimpleItemCell.as:136-144`：(0,20) 40×20 **右对齐**
	标.size = Vector2(40.0, 20.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", 白)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(标)
	if 量 <= 0:
		_灰化(格)	# `:466-470` `param2 <= 0 ⇒ Style.getDisableFilter()`
	_接提示(格, 绑, 号)
	槽.add_child(格)


static func _接提示(格: Control, 绑: Dictionary, 号: int) -> void:
	if 号 <= 0:
		return
	var 宿主 := 绑["宿主"] as Node
	格.mouse_entered.connect(func():
		var 页 := 绑["页"] as Control
		var 框 := 页.get_node_or_null("物品提示_赠送") as Control
		if 框 == null:
			框 = 物品提示场景.instantiate() as Control
			框.name = "物品提示_赠送"
			框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			页.add_child(框)
		var 等级 := 0
		if 宿主._session != null:
			等级 = int(宿主._session.player_stats.get("level", 0))
		框.设置(str(号), int(宿主._背包数量(号)), 等级, 游戏数据.item(号))
		框.visible = true
		框.贴到鼠标(页.get_local_mouse_position(), 宿主._舞台尺寸()))
	格.mouse_exited.connect(func():
		var 框 := (绑["页"] as Control).get_node_or_null("物品提示_赠送") as CanvasItem
		if 框 != null:
			框.visible = false)


static func _灰化(格: Control) -> void:
	var 材 := load("res://脚本/界面/组件/禁用灰度.gdshader")
	var 灰 := Color(0.42, 0.42, 0.42, 1.0)
	for 子 in [格] + 格.get_children():
		var 项 := 子 as CanvasItem
		if 项 != null:
			var m := ShaderMaterial.new()
			m.shader = 材
			项.material = m
		if 子 is Label:
			(子 as Label).add_theme_color_override("font_color", 灰)


## `:240-257` `updateCountTime` + `:288-292`：`remainSeconds > 0` 才挂 tick（`TimerManager.as:37`
## 的 `new Timer(1000)` = 每秒），**先按当前值出字、再减一**；减到 0 的下一次 tick 摘掉 tick 停更。
static func 起秒表(页: Control, 初始: int) -> void:
	var 旧 := 页.get_node_or_null("秒表") as Timer
	if 旧 != null:
		旧.stop()
		页.remove_child(旧)
		旧.queue_free()
	var 态 := {"剩": 初始, "字": 页.get_node("倒计时") as Label, "表": null}
	_走秒(态)
	if 初始 > 0:
		var 时 := Timer.new()
		时.name = "秒表"
		时.wait_time = 1.0
		页.add_child(时)
		时.timeout.connect(_走秒.bind(态))
		态["表"] = 时
		时.start()


static func _走秒(态: Dictionary) -> void:
	var 剩 := int(态["剩"])
	var 表 := 态["表"] as Timer
	if 剩 <= 0:
		if 表 != null:
			表.stop()
	(态["字"] as Label).text = 替(倒计时头, ["%02d:%02d" % [int(剩 / 60), 剩 % 60]])
	if 剩 > 0:
		态["剩"] = 剩 - 1


## `createChildren:209-223`：两枚 `MCheckBoxF` 的字色都是 `UI_YELLOW`；选中态落
## `UIConfig.userCfg.riHuan.auto / stop`（**会落盘**的那份）⇒ 这边读/写 `game_settings`。
static func _建勾选(页: Control, 宿主: Node, 绑: Dictionary) -> void:
	var 表 := [["勾选槽", 勾选一, "riHuan_auto", "勾一"],
			["勾选槽2", 勾选二, "riHuan_stop", "勾二"]]
	for 项 in 表:
		var 槽 := 页.get_node(String(项[0])) as Control
		var 件 := 复选项场景.instantiate() as Control
		件.name = "复选_" + String(项[2])
		件.custom_minimum_size = 槽.size
		件.size = 槽.size
		var 字 := 件.get_node("文本") as Label
		字.text = String(项[1])
		字.add_theme_color_override("font_color", 黄)
		var 钮 := 件.get_node("点击区域") as Button
		钮.size = 槽.size
		钮.focus_mode = Control.FOCUS_NONE
		_设勾(件, bool(_读设置(宿主, String(项[2]))))
		# 用 `pressed` + 自己翻 `标记.visible`（口径同 `设置窗口._点复选:129-135`）⇒ 不碰
		# `toggled` 那条「实参排在 bind 之前」的坑，也不给钮开 `toggle_mode`。
		钮.pressed.connect(_点勾.bind(宿主, 件, String(项[2])))
		绑[String(项[3])] = 件
		槽.add_child(件)


static func _设勾(件: Control, 选中: bool) -> void:
	(件.get_node("标记") as CanvasItem).visible = 选中


static func _勾(件: Control) -> bool:
	return bool((件.get_node("标记") as CanvasItem).visible)


static func _点勾(宿主: Node, 件: Control, 键: String) -> void:
	var 新 := not _勾(件)
	_设勾(件, 新)
	if 宿主.has_method("_set_check"):
		宿主._set_check(新, 键)		# 原版 `autoResfreshHandler:200` / `stopResfreshHandler:99`


static func _读设置(宿主: Node, 键: String) -> bool:
	var 会话: Node = 宿主.get("_session") as Node
	if 会话 == null:
		return false
	return bool((会话.get("game_settings") as Dictionary).get(键, false))


static func _接钮(页: Control, 绑: Dictionary) -> void:
	(页.get_node("立即完成钮") as Button).pressed.connect(_点立即.bind(绑))
	(页.get_node("刷新任务钮") as Button).pressed.connect(_点刷新.bind(绑))
	(页.get_node("开始任务钮") as Button).pressed.connect(_点开始.bind(绑))


## `finishedHandler:355-358` → `QuestDataManager.finishOneDailyQuest:772-785`：
## 先看 `showFinishQuestWindow`，要提示就弹**带勾选**的确认框（初值不勾、取消 ⇒ `handler(null)`）。
static func _点立即(绑: Dictionary) -> void:
	var 宿主 := 绑["宿主"] as Node
	if (绑["数"] as Dictionary).is_empty():
		宿主._通知(空态)
		return
	if not _再提示完成:
		_定完成(true, 宿主)
		return
	确认弹.弹勾选(宿主._overlay, 替(完成弹, [str(完成要价)]), 不再提示, false, _定完成.bind(宿主))


## ⚠ 形参顺序：`Callable.bind()` 把绑定的参数排在**调用参数之后** ⇒ `回调.call(选)` 打的是
##   `_定完成(选, 宿主)`。写成 (宿主, 选) 会在运行期报「Cannot convert argument 1 from bool to Object」。
static func _定完成(选: Variant, 宿主: Node) -> void:
	if 选 == null:
		return						# `sureFinishOneDailyQuest:419-424`：取消那一支直接 return
	_再提示完成 = not bool(选)		# `:425` `showFinishQuestWindow = !param1`
	宿主._环任务操作(10, 8001)


## `refreshHandler:79-99`，四条分支的顺序一个都不许改：**满 5 星静默** → 停自动 →
## `refreshLeftTime > 0` 才可能弹框 → 否则走「免费」那一支。
static func _点刷新(绑: Dictionary) -> void:
	var 宿主 := 绑["宿主"] as Node
	var 数: Dictionary = 绑["数"]
	if 数.is_empty():
		宿主._通知(空态)
		return
	if int(数.get("richDegree", 0)) >= 5:
		return
	停自动(绑)
	绑["点过"] = true
	var 剩余 := int(数.get("remainSeconds", 0))
	if 数.has("cooldown_deadline"):
		剩余 = maxi(0, int(数["cooldown_deadline"]) - Time.get_ticks_msec())
	if 剩余 > 0:
		if _再提示刷新:
			确认弹.弹勾选(宿主._overlay, 替(刷新弹, [str(要价)]), 不再提示, false, _定刷新.bind(绑))
		else:
			_定刷新(true, 绑)
	else:
		请刷新(绑)


## 同 `_定完成`：`选` 必须在第一位（`弹勾选` 的回调是 `回调.call(勾选值)`）。
static func _定刷新(选: Variant, 绑: Dictionary) -> void:
	if 选 == null:
		return
	_再提示刷新 = not bool(选)
	请刷新(绑)


static func 请刷新(绑: Dictionary) -> void:
	if not (绑["宿主"] as Node)._环任务操作(9, 8001):
		停自动(绑)


static func 停自动(绑: Dictionary) -> void:
	绑["点过"] = false
	var 表: Timer = 绑.get("自动表") as Timer
	if is_instance_valid(表):
		表.stop()
		表.queue_free()
	绑["自动表"] = null


## `autoRefreshQuest:100-119`（只在 `_btnClicked` 时由 `set quest` 触发）：
## 满 5 星停；勾了「点券不够时停止」且点券 < 10 ⇒ 通知条 + 停；点券或元宝够 ⇒ 排 1s 后刷新。
static func _自动刷新(绑: Dictionary) -> void:
	var 宿主 := 绑["宿主"] as Node
	var 数: Dictionary = 绑["数"]
	var 自 := _勾(绑["勾一"] as Control)
	if int(数.get("richDegree", 0)) >= 5:
		停自动(绑)
		自 = false
	if not 自:
		return
	var 停 := _勾(绑["勾二"] as Control)
	var 点券 := _钱(宿主, "cash_bind")		# `DataCenter.as:3151` `bandMoney = cash_bind`
	var 元宝 := _钱(宿主, "cash")
	if 停 and 点券 < 要价:
		宿主._通知(点券不够)
		停自动(绑)
		return
	if 点券 < 要价 and 元宝 < 要价:
		停自动(绑)
		return
	if is_instance_valid(绑.get("自动表")):
		return
	var 表 := Timer.new()
	表.one_shot = true
	表.wait_time = 1.0
	(绑["页"] as Control).add_child(表)
	绑["自动表"] = 表
	表.timeout.connect(func():
		绑["自动表"] = null
		表.queue_free()
		if (绑["页"] as Control).is_visible_in_tree() and bool(绑["点过"]) and _读设置(宿主, "riHuan_auto"):
			请刷新(绑))
	表.start()


static func _钱(宿主: Node, 键: String) -> int:
	var 会话: Node = 宿主.get("_session") as Node
	if 会话 == null:
		return 0
	return int((会话.get("player_stats") as Dictionary).get(键, 0))


## `startHandler:104-117`：按 status 分两支（1=进行中 ⇒ 寻路；2=已完成 ⇒ 点交付 NPC），
## **两支都紧接着 `onCloseBtnClick(null)` 关窗** ⇒ 这边同样先回显、后关窗。
static func _点开始(绑: Dictionary) -> void:
	var 宿主 := 绑["宿主"] as Node
	var 数: Dictionary = 绑["数"]
	if 数.is_empty():
		宿主._通知(空态)
		return
	停自动(绑)
	宿主._环任务开始(数)


static func _关(宿主: Node) -> void:
	if 宿主.has_method("close"):
		宿主.close()


## `CN.replaceString`（`CN.as:5392-5403`）：`%1`→第 1 个变参、`%2`→第 2 个……按序换。
static func 替(模板: String, 参数: Array) -> String:
	var 文 := 模板
	for i in 参数.size():
		文 = 文.replace("%" + str(i + 1), str(参数[i]))
	return 文
