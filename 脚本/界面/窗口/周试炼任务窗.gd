extends RefCounted

## 宇智波富岳（模板 27）菜单第二行「周试炼任务」= 原版 `component/DailyQuestWindow`（355×367）。
##
## ⚠ **类名叫 Daily、走的却是 weekly 那一支**：`QuestDataManager.as:278-288` 按任务的
## `type` 分流，`weekly` ⇒ `DAILY_QUEST_WINDOW`（就是这一扇）。别按类名把它当成日环、
## 也别和隔壁 `RefreshDailyQuestWindow`（日环那扇）混用 —— 两个类**没有一件共用**。
##
## 外壳 11 件在 `场景/界面/窗口/环任务/周试炼任务窗.tscn`（`开发工具/原版服务窗.py 生成 周试炼任务`
## 从 SPEC 烘出 ⇒ **别手改 .tscn**；逐件 AS3 行号在 SPEC 每条的 `出处` 里，验收口径在
## `game-client/真值/窗口/木叶村NPC.md` §6f）。本文件只做 `onDataCompelete:215-286` 那批运行期件。
##
## ⚠ 数据面同隔壁：`order / totalOrder / finishCount / difiiculty / require / richDegree /
##   simpleEncourge / encouragEx / encourageItems / encourageItemsEx` 都来自服务端 **444 任务信息帧**
##   （`_send_original_started_quest_list` 等）；离线或还没接取时空 `数` ⇒ 四块文本留空、
##   两组格子一枚都不建。
##
## ⚠ 交互面：
##   降难度 `:157-166`：**难度 > 1** 才动，否则通知条 `REQUIRE_QUSET_MINIMUM`
##   提回报 `:193-201`：**丰厚度 < 10** 才动，否则通知条 `REQUIRE_QUSET_MAX`
##   ⇒ 两支「才动」走的是 `QuestDataManager.changeQuest`（`:169-177`）= **打开 EnlargeWindow**
##     并塞 `QuestLoop` 材料 + `{isTiSheng, quest}`（`_开调整`）；确认后由宿主发 **104:8 / 104:9**。
##   开始任务 `:83-96`：status 1 寻路 / 2 找交付 NPC，**两支都关窗**；目标来自 444，
##     交宿主 `_环任务开始`，不走协议。

const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")
const 调整场景 := preload("res://场景/界面/组件/扩容窗口.tscn")
## 号<=0 时原版拿 Etc 那朵花（玫瑰花）的 itemid 当图标（值取自 数据/原版杂项.json）。
const 花号 := 16000143
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")

const 格皮 := "res://素材/界面/原版窗口/通用控件/物品格.png"		# SimpleItemCell 的 MGrid_background

const 白 := Color(1, 1, 1)

## 语言表逐字（`en_US$message_properties.as`；`<br/>`→`\n`、`<font color='#x'>`→`[color=#x]`，
## 全角空格「　」与半角空格按原文一个都不动 —— 它们是版式的一部分）
const 周文 := "[color=#ffffff][color=#ff9100]木叶警所环式任务完成情况一览：[/color]\n本周接取次数   %1 [color=#1e90ff]（每周最多可接取木叶警所任务 %2 次）[/color]\n本周完成次数   %3 [color=#1e90ff]（次数=25,50,75时，额外奖励大量经验）[/color]\n　　　　　　     [color=#1e90ff]（次数=100时，额外奖励巨额经验与精华）[/color][/color]"	# :1460 WEEKLY_QUEST
const 日文 := "今日接取次数  %1 （每日最多可接任务20次）\n今日完成次数  %2 （完成20次有额外经验奖励）"	# :2206 DAILY_QUEST（本窗只有 questType=daily 时才用得到）
const 追踪一 := "[color=#00ff00]本次任务目标：　　　　　　　　难度： %1 [/color][color=#ffffff]（最小为1）[/color]\n"	# :3213 DIFFICULTY_QUSET
const 追踪二 := "[color=#ffffff] %1 [/color]"																		# :2437 REQUIRE_QUSET
const 奖励一 := "[color=#00ff00]本次任务奖励：　　　　　　   丰厚度：%1[/color][color=#ffffff]（最大为10）[/color]\n"	# :447 RICHDEGREE_QUSET
const 特殊奖励 := "[color=#00ff00]本次任务完成额外奖励：[/color]\n[color=#ffffff] %1 [/color]"						# :3303 ENCOURAGEX_QUSET
const 难度最小 := "该任务的难度已达到最小值！"																		# :2666 REQUIRE_QUSET_MINIMUM
const 回报最大 := "该任务的回报已达到最大值！"																		# :1827 REQUIRE_QUSET_MAX
const 空态 := "周试炼的运行期数字（第几环 / 完成次数 / 难度 / 丰厚度 / 奖励物品）只在服务端 444 任务信息帧里 ⇒ 离线或还没接取时只画静态件"

const 格边 := 40.0
const 格距 := 5.0			# `DailyQuestWindow.as:250/:272` `_loc5_ += 宽 + 5`
const 换行起 := 24.0			# `:252/:274` 折行后 x 回 24（**不是回到 10/6**）
const 一版宽 := 331.0			# `_textSkin.width` = 331 ⇒ 折行判据拿它比（`:251/:273`）

## `TextArea2` 的 `adjustContent` 盒高（`TextArea2.as:122-126`）= 文本高 + 4 + 2·paddingV，
## 而文本高按原版度量 = `15n + (n−1)·leading`（leading 4 `:80`）。这两块文本下面**压着物品格容器**
## （`:236/:239` 容器 y = 文本 y + 文本高）⇒ 行数一变格子就跟着走，必须算而不是问引擎。
## ⚠ 只数显式 `\n`，**折行没算进去**（`simpleEncourge` 是服务端给的 html，长起来会低估）⇒ 未收口。
static func _盒高(行数: int, 上下边距: int) -> float:
	if 行数 <= 0:
		return 0.0 + 4.0 + 2.0 * 上下边距
	return 15.0 * 行数 + (行数 - 1) * 4.0 + 4.0 + 2.0 * 上下边距


## `宿主` = `功能窗口`；`数` = 一条 `BasicQuestInfoData` 形状（字段名照 AS3，门喂）。
static func 渲染(宿主: Node, 场景: PackedScene, 数: Dictionary = {}) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	页.set_meta("ring_quest_data", 数)
	_接钮(页, 宿主, 数)
	if 数.is_empty():
		宿主._通知(空态)
		return 页
	填数据(页, 数, 宿主)
	return 页


## = `onDataCompelete`（`:215-286`）：`destroy()`（清追踪文本与两组格子）→ 四块文本 → 两组格子。
static func 填数据(页: Control, 数: Dictionary, 宿主: Node) -> void:
	_清(页)
	(页.get_node("说明") as RichTextLabel).text = 说明文(数)
	var 追 := RichTextLabel.new()
	追.name = "追踪文本"
	追.bbcode_enabled = true
	追.scroll_active = false
	追.fit_content = true			# StructuredText：高由量文决定，AS3 没写死 ⇒ 不自定义高
	追.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	追.add_theme_font_size_override("normal_font_size", 12)
	追.add_theme_constant_override("line_separation", 2)
	追.position = Vector2(0.0, 0.0)
	追.size = Vector2(321.0, 0.0)	# `:228` `_textSkin.width − BORDER_GAP*2` = 331−10
	追.text = 富文本.译文为BBCode(替(追踪一, [str(int(数.get("difiiculty", 0)))]) + 替(追踪二, [str(数.get("require", ""))]))
	(页.get_node("追踪槽") as Control).add_child(追)
	# 奖励文本（paddingV = 4 `:119`）：文本 + 盒高，然后把**格子容器**按原版公式抬到文本底下
	var 奖 := 页.get_node("奖励文本") as RichTextLabel
	奖.text = 替(奖励一, [str(int(数.get("richDegree", 0)))]) + 富文本.译文为BBCode(str(数.get("simpleEncourge", "")))
	var 奖行: int = _行数(奖.text)
	奖.size.y = _盒高(奖行, 4)
	var 槽一 := 页.get_node("奖励格槽") as Control
	槽一.position.y = 奖.position.y + 奖.size.y		# `:236`
	_排格(槽一, 数.get("encourageItems", []), 10.0, 宿主, 页)	# `:240-262` 起 x = **10**
	# 特殊奖励文本（paddingV = 2 `:132`）：同一条公式
	var 特 := 页.get_node("特殊奖励文本") as RichTextLabel
	特.text = 替(特殊奖励, [str(数.get("encouragEx", ""))])
	特.size.y = _盒高(_行数(特.text), 2)
	var 槽二 := 页.get_node("特殊格槽") as Control
	槽二.position.y = 特.position.y + 特.size.y		# `:239`
	_排格(槽二, 数.get("encourageItemsEx", []), 6.0, 宿主, 页)	# `:263` 起 x = **6**


## `getQuestString:169-188` 的 switch：`daily` 与 `weekly` 各一句，其它类型**回空串**。
## ⚠ 原版 daily 那支把 `(order, totalOrder, finishCount)` 三个变参塞进只有 `%1/%2` 的
##   `DAILY_QUEST`（`:176`）⇒ 第三个数被丢掉、句子里不会出现完成次数。这是**原版的 bug，照抄**，
##   别"顺手修好"。weekly 那支三个都用得上。
static func 说明文(数: Dictionary) -> String:
	match String(数.get("questType", "")):
		"daily":
			return 替(日文, [str(int(数.get("order", 0))), str(int(数.get("totalOrder", 0)))])
		"weekly":
			return 替(周文, [str(int(数.get("order", 0))), str(int(数.get("totalOrder", 0))),
					str(int(数.get("finishCount", 0)))])
		_:
			return ""


static func _行数(文: String) -> int:
	if 文.is_empty():
		return 0
	# 行 = `\n` 数 + 1；原版这几句都以 `<br/>` 收尾**且后面还接了内容**，所以只有真的
	# 以 `\n` 结尾才不留下一个空尾行。
	var 行 := 文.count("\n") + 1
	if 文.ends_with("\n"):
		行 -= 1
	return 行


static func _清(页: Control) -> void:
	# `destroy:288-300`：摘追踪文本、清空两组格子。
	var 追 := 页.get_node_or_null("追踪槽/追踪文本")
	if 追 != null:
		追.get_parent().remove_child(追)
		追.queue_free()
	for 名 in ["奖励格槽", "特殊格槽"]:
		var 槽 := 页.get_node(名) as Control
		for 子 in 槽.get_children():
			槽.remove_child(子)
			子.queue_free()


## `:240-262`（Ex 组 `:265-285` 只差起点 x）：
## `x = 起 + i*(40+5)`，**先加后判**：`x > 331` ⇒ `x = 24`、`y += 40+5`。
static func _排格(槽: Control, 物品: Array, 起x: float, 宿主: Node, 页: Control) -> void:
	var x := 起x
	var y := 0.0
	for i in 物品.size():
		var 项: Dictionary = 物品[i] as Dictionary
		var 格 := _格(int(项.get("id", 0)), int(项.get("count", 0)), i)
		格.position = Vector2(x, y)
		槽.add_child(格)
		# ⚠ 悬停回调**必须在 add_child 之后**接：`_格` 里取 `格.get_parent()` 会是 null
		#   （同一类坑：`gui_input.connect(F.bind(...))` 的实参顺序，10-04 卡片套册栽过一次）
		_接提示(格, 宿主, int(项.get("id", 0)), i, 页)
		x += 格边 + 格距
		if x > 一版宽:
			x = 换行起
			y += 格边 + 格距


## `SimpleItemCell`（`:240` `new SimpleItemCell()` ⇒ `showCount=true`）：格底 40×40、
## 图标居中取整（`SimpleItemCell.as:164-165`）、数量在 (0,20) 40×20 **右对齐**（`:136-144`）、
## `itemData.canTrade = false`（`DailyQuestWindow.as:245`）⇒ 奖励格不可交易，只作预览。
static func _格(号: int, 量: int, 序: int) -> Control:
	var 格 := TextureRect.new()
	格.name = "奖励格%d" % (序 + 1)
	格.texture = load(格皮)
	格.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	格.stretch_mode = TextureRect.STRETCH_SCALE
	格.size = Vector2(格边, 格边)
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
		图.position = Vector2(roundf((格边 - 寸.x) / 2.0), roundf((格边 - 寸.y) / 2.0))
		图.size = 寸
		格.add_child(图)
	var 标 := Label.new()
	标.name = "数量"
	标.text = str(量)
	标.position = Vector2(0.0, 20.0)
	标.size = Vector2(40.0, 20.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", 白)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(标)
	return 格


static func _接提示(格: Control, 宿主: Node, 号: int, 序: int, 页: Control) -> void:
	if 号 <= 0:
		return
	var 节点名 := "物品提示_奖励%d" % (序 + 1)
	格.mouse_entered.connect(func():
		var 框 := 页.get_node_or_null(节点名) as Control
		if 框 == null:
			框 = 物品提示场景.instantiate() as Control
			框.name = 节点名
			框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			页.add_child(框)
		var 等级 := 0
		if 宿主._session != null:
			等级 = int(宿主._session.player_stats.get("level", 0))
		框.设置(str(号), int(宿主._背包数量(号)), 等级, 游戏数据.item(号))
		框.visible = true
		框.贴到鼠标(页.get_local_mouse_position(), 宿主._舞台尺寸()))
	格.mouse_exited.connect(func():
		var 框 := 页.get_node_or_null(节点名) as CanvasItem
		if 框 != null:
			框.visible = false)


static func _接钮(页: Control, 宿主: Node, 数: Dictionary) -> void:
	(页.get_node("降难度钮") as Button).pressed.connect(_点降.bind(宿主, 数))
	(页.get_node("提回报钮") as Button).pressed.connect(_点提.bind(宿主, 数))
	(页.get_node("开始任务钮") as Button).pressed.connect(_点开始.bind(宿主, 数))


static func _开调整(宿主: Node, 数: Dictionary, 提升: bool) -> void:
	var 页 := 宿主._content.get_child(宿主._content.get_child_count() - 1) as Control
	var 旧 := 页.get_node_or_null("任务调整")
	if 旧 != null:
		页.remove_child(旧)
		旧.queue_free()
	var 窗 := 调整场景.instantiate() as Control
	窗.name = "任务调整"
	窗.z_index = 100
	页.add_child(窗)
	var 号 := str(int((游戏数据.取表("原版杂项").get("QuestLoop", {}) as Dictionary).get("itemid", 0)))
	窗.确认扩充.connect(func(_归属: String): 宿主._环任务操作(9 if 提升 else 8, int(数.get("questId", 8002))))
	窗.请求购买.connect(宿主.请求商城商品)
	窗.打开任务(号, int(宿主._背包数量(int(号))))


static func _点降(宿主: Node, 数: Dictionary) -> void:
	if 数.is_empty():
		宿主._通知(空态)
		return
	if int(数.get("difiiculty", 0)) > 1:
		_开调整(宿主, 数, false)
		return
	宿主._通知(难度最小)	# `API.ui.addNotice` ⇒ 走通知条（状态行读不到）


static func _点提(宿主: Node, 数: Dictionary) -> void:
	if 数.is_empty():
		宿主._通知(空态)
		return
	if int(数.get("richDegree", 0)) < 10:
		_开调整(宿主, 数, true)
		return
	宿主._通知(回报最大)


## `startHandler:83-96`：两支都紧接着 `onCloseBtnClick(null)` ⇒ 回显完一定关窗。
static func _点开始(宿主: Node, 数: Dictionary) -> void:
	if 数.is_empty():
		宿主._通知(空态)
		return
	宿主._环任务开始(数)


## `CN.replaceString`（`CN.as:5392-5403`）：`%1`→第 1 个变参、`%2`→第 2 个……按序换。
static func 替(模板: String, 参数: Array) -> String:
	var 文 := 模板
	for i in 参数.size():
		文 = 文.replace("%" + str(i + 1), str(参数[i]))
	return 文
