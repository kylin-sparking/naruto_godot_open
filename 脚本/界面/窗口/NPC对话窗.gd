extends Node
## 纲手那类 NPC 对话窗（原版 `com/mxw/uifl/controls/QuestDialog.as`）。
##
## 挂在 `小地图面板` 下当**覆盖层**（原版是 `PopUpMananger.centerWindow` 居中摆舞台 `:401`，
## 本工程 HUD 那层就是舞台），不再用之前那枚「单格 + 一枚服务钮」的假气泡。
##
## 场景 15 个节点全由 `开发工具/生成NPC对话场景.py` 烘（两格 NinePatch + 名字 + 台词 + 三行菜单），
## 这里只管三件事：**填数据**、**按行数增减行**、**点行走既有 `request_npc_menu_action`**。
##
## ⚠ 菜单是**服务端下发**的（`NPCTalkProcessor.as:34-55` 把整段 buffer 读成对象 ⇒
## `_data.menu`），本工程的服务端在 `fake_flash_server.py:51696-51717` 用
## `NPC_SERVICE_MENUS[npc.template_id]` 拼 `label&action` 再以 `@` 相连，末尾补「离开&-1」。
## 所以客户端**不许自己写菜单表**，只解析 328 帧里那一段。

signal 已关闭
signal 行被点(动作值)		# 小地图面板 用它把「挑战副本 / 挑战精英副本」映射到本地页面

const 场景 := preload("res://场景/界面/窗口/NPC对话/NPC对话窗.tscn")
const 首行y := 20
const 行距 := 20
## 行的命中矩形要比字的上沿再高 7（原版文字画在 y=−7，见 `_排行` 那条注释）。
## 与 `开发工具/生成NPC对话场景.py` 的 `行顶上移` **必须同一个数**（那边烘场景、这边排运行期的行）。
const 行顶上移 := 7
const 上格高 := 81
const 下格距 := 5
const 下格最少 := 74
const 台词宽 := 456		# `:384-385` 上格宽 − 50
const 台词x := 25.0		# `:386` `_npcTextArea.x = 25`；回应块 `:409` 取同一个 x
const 回应行高 := 17		# 与 `_排上格` 同口径（同一个 StructuredText 类）
const 回应块底 := 40.0	# `:411` `_loc2_ = height + 40`
const 每行字 := 38		# 456 / 12px 汉字
## ── selection（任务行）那一族**不是菜单行**：`:249-345` 把整个 selection 段拼成
## **一块居中富文本链接**（每行一条 `<a href="event:值">`），画在下格右侧、垂直居中。
## 用户 2026-10-05 拿实机图打回就是打在这一条上（原来我把它当普通菜单行画了）。
const 选择宽 := 366.0		# `:336` `new StructuredText(串, _playerSaidSkin.width − 140)` = 506−140
const 选择行距 := 7.0		# `:332` `<textformat leading='5'>` ⇒ Godot 行距 = leading + 2
const 选择块底 := 40.0		# `:339` `_loc8_ = _loc13_.height + 40`（下格高至少要有这么多）
## 前缀与状态后缀（`en_US$message_properties.as` 逐字）
const 前缀 := {"trunk": "[主线]", "branch": "[支线]", "daily": "[日环]", "weekly": "[周环]",
		"monthly": "[月环]", "loop": "[挂机]", "mixin": "[护送]", "banghui": "[家族]"}
## 行号：主线 :937 / 支线 :1068 / 日环 :1705 / 周环 :255 / 月环 :1006 / 挂机 :2160 / 护送 :1676 / 家族 :531
const 带计数 := ["daily", "weekly", "loop", "mixin", "banghui"]	# `:266-313` 只有这五支拼 (loopId/loopCount)
const 后缀 := {0: "（可接）", 1: "（进行中）", 2: "（可交）", 4: "（对话）"}	# :1658 / :2676 / :602 / :2856
const 状态色 := {1: "#1e90ff"}					# `:322` 进行中是蓝，其余四支都是 #00ff00

var _根: Control
var _上格: NinePatchRect
var _下格: NinePatchRect
var _名: Label
var _台: RichTextLabel
var _单: Control
var _行们: Array[Control] = []
var _值: Array = []		# int = 服务端动作值（菜单行）或任务 id（selection 行）；Callable = 本工程本地入口
var _本地们: Array = []		# 与 _值 同下标：selection 行**发完协议之后**还要开的本地页（Callable / null）
var _菜单数 := 0			# 前 _菜单数 个是菜单行，其后都是 selection 行（发 57:3 而不是 57:2）
var _选择高 := 0.0
var _回应: Node		## 原版 `data.text` 那一行绿色玩家回应（下格内），只在剧情模式下可见
var _选择行: Array[String] = []		# 带 BBCode 的那几行（画进 RichTextLabel）
var _选择净: Array[String] = []		# **净文案**（判据与量具比的是这个）


func _ready() -> void:
	根()


func 根() -> Control:
	if _根 != null:
		return _根
	_根 = 场景.instantiate() as Control
	add_child(_根)
	_上格 = _根.get_node("上格") as NinePatchRect
	_下格 = _根.get_node("下格") as NinePatchRect
	_名 = _上格.get_node("名字") as Label
	_台 = _上格.get_node("台词") as RichTextLabel
	_单 = _下格.get_node("菜单/行1") as Control
	# 原版 `_playerSaidSkin`（`QuestDialog.as:151` + `:414-415`）整块是**热区**：点它 = "我说完了"
	# ⇒ 发 NEXT 翻下一句。菜单行/选择块各自 STOP，点它们不会顺带翻句（见 `_排行`）。
	_下格.mouse_filter = Control.MOUSE_FILTER_STOP
	_下格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_下格.gui_input.connect(_点下格)
	_根.visible = false
	return _根


## `showDialog(npcId, words, data)` 的等价入口。`菜单` = `[[文字, 动作值], ...]`。
##
## **`回应` 就是原版 `data.text`** —— `drawView():393-399` 在这里分叉：
##   有 `text` ⇒ `createPlayerTextArea()`（下格只有那一行绿色玩家回应，**一个菜单行都不建**）；
##   没有 ⇒ `createSelection()`（菜单行 / 任务链接块）。
## ⇒ "点任务出剧情、交易按钮不见"不是 hide，是**这条分支根本不建菜单**。
## 点下格 = `clickPlayerSaidHandler():137-145` ⇒ 发 `57:NEXT:1` 翻下一句（`说完了()`）。
func 显示(npc编号: int, npc名: String, 台词: String, 菜单: Array, 选择: Array = [], 回应 := "") -> void:
	var 件 := 根()
	件.visible = true
	_名.text = npc名
	_台.text = "[color=#ffffff]" + 台词 + "[/color]"
	_排上格(台词)
	if 回应 != "":
		_菜单数 = 0
		_排行([])
		_排选择([], 0)
		_排回应(回应)
	else:
		_藏回应()
		_菜单数 = 菜单.size()
		var 菜单高 := _排行(菜单)
		var 块 := _排选择(选择, 菜单.size())
		_拍下格(菜单高, 块)
	_居中()
	件.move_to_front()


## `createPlayerTextArea():404-416`：绿字、宽 = 上格宽 − 50、x 与台词同（25）、
## 下格高 = max(74, 文本高 + 40)、文本在**下格内垂直居中**。
func _排回应(文本: String) -> void:
	var 件 := _回应件()
	件.text = "[color=#00ff00]" + 文本 + "[/color]"
	件.visible = true
	(件 as Control).size = Vector2(台词宽, 回应行高 * 回应行数(文本))
	var 高 := maxf(float(下格最少), (件 as Control).size.y + 回应块底)
	_下格.size = Vector2(float(506), 高)
	_下格.position = Vector2(0, _上格.size.y + 下格距)
	根().size = Vector2(float(506), _上格.size.y + 下格距 + 高)
	(件 as Control).position = Vector2(台词x, 高 * 0.5 - (件 as Control).size.y * 0.5)


func _藏回应() -> void:
	if _回应 != null:
		(_回应 as Control).visible = false


func _回应件() -> Node:
	if _回应 != null:
		return _回应
	## 节点**烘在场景里**（`下格/回应`，默认 `visible = false`）⇒ 编辑器里看得见、和运行期同一形状。
	## 找不到才现建：那说明有人手改了 `.tscn` 而没重跑 `开发工具/生成NPC对话场景.py`。
	var 找 := _下格.get_node_or_null("回应")
	if 找 != null:
		_回应 = 找
		return 找
	push_warning("NPC对话窗：场景里没有 下格/回应 —— 请重跑 开发工具/生成NPC对话场景.py，别靠运行期建")
	var 块 := RichTextLabel.new()
	块.name = "回应"
	块.bbcode_enabled = true
	块.scroll_active = false
	块.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	块.mouse_filter = Control.MOUSE_FILTER_IGNORE	# 热区是**整个下格**（原版 skin 上挂 CLICK）
	_下格.add_child(块)
	_回应 = 块
	return 块


## 行数按**字符数**算，与 `_排上格` 同一口径（`get_content_height()` 是布局高，
## autowrap 会把 min 宽压小 ⇒ 行数暴涨、整格掉下去）。
static func 回应行数(文本: String) -> int:
	var 行 := 0
	for 段 in 文本.split("\n"):
		行 += maxi(1, int(ceil(float(段.length()) / float(每行字))))
	return maxi(1, 行)


## 原版 `PopUpMananger.centerWindow(this)`（`QuestDialog.as:401`）= 在舞台上水平垂直都居中。
## 本工程这层是 HUD 里的一个普通 Control ⇒ 自己按视口算，别留在 (0,0)（左上角就是现在的症状）。
func _居中() -> void:
	if _根 == null:
		return
	var 视: Viewport = get_viewport()		# 本类 extends Node ⇒ 只有 get_viewport()，没有 get_viewport_rect()
	var 视口: Vector2 = 视.get_visible_rect().size if 视 != null else Vector2.ZERO
	_根.position = Vector2((视口.x - _根.size.x) / 2.0, (视口.y - _根.size.y) / 2.0)


func 关闭() -> void:
	if _根 != null:
		_根.visible = false
	已关闭.emit()


## `:390-391` 上格高 = max(台词底 + 20, 77)；台词高 = 行数 × 17。
## ⚠ 行数按**字符数**算，不用 `get_content_height()`：那是 Godot 布局高，autowrap 会把
## min 宽压小 ⇒ 行数暴涨、整格往下掉（副本传送页同一颗雷，见 `真值对照表.md`）。
func _排上格(文本: String) -> void:
	var 行 := 0
	for 段 in 文本.split("
"):
		行 += maxi(1, int(ceil(float(段.length()) / float(每行字))))
	var 高 := maxf(float(上格高), float(39 + 行 * 17 + 20))
	_上格.size = Vector2(float(506), 高)
	_下格.position = Vector2(0, 高 + 下格距)


## `createSelection():215-255` 的 menu 分支：按数据增减 `SelectionLalel`（这里是「行」）。
func _排行(菜单: Array) -> float:
	_值.clear()
	_本地们.clear()
	_行们.clear()
	var 容 := _下格.get_node("菜单") as Control
	## **先把所有行藏掉**再按数据逐个点亮：模板「行1」烘在场景里是可见的，
	## 而下面的循环只 `visible = true` 不复位 ⇒ 空菜单（剧情模式）会留一行带旧文案的鬼影。
	## 以前从没暴露，是因为菜单在这之前总会兜底凑出「离开」那一行。
	for 子 in 容.get_children():
		(子 as Control).visible = false
	# 模板就是烘在场景里的「行1」：它**不删**，多余的旧行从第 2 行起清掉。
	# （原先把子节点全 remove + queue_free 再 duplicate 已释放的模板 ⇒ 运行期只剩一行，
	#   门直接报「缺节点 行2/行3」。）
	for 子 in 容.get_children().slice(1):
		容.remove_child(子)
		子.queue_free()
	for i in 菜单.size():
		var 项: Array = 菜单[i] as Array
		var 行: Control = 容.get_child(0) as Control if i == 0 else _单.duplicate() as Control
		if i > 0:
			容.add_child(行)
			# duplicate 不改名 ⇒ Godot 会把重名的自动改成「行1@2」，门按 行2/行3 取就落空。
			行.name = "行%d" % (i + 1)
		# 行是「菜单」的子节点 ⇒ 这里必须是**菜单局部**坐标（菜单已经带上了 首行y 那 20px）
		## 上移 7 = 把「文字画在 y=−7」并进行的命中矩形（原版命中区是子节点实际范围）。
		## 不上移的话：行矩形 0..20、字在 −7..13 ⇒ 字的上半截点不到，还会被上一行的矩形盖住（点错行）。
		行.position = Vector2(0, float(i * 行距 - 行顶上移))
		行.visible = true
		# STOP：点行只发 MENU，别把下格那块"我说完了"热区一起触发（父层会收到同一次点击）
		行.mouse_filter = Control.MOUSE_FILTER_STOP
		行.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		(行.get_node("文字") as Label).text = str(项[0])
		_值.append(项[1])
		_行们.append(行)
		_接行点击(行, i)
	return float(首行y + 菜单.size() * 行距)	# 原版 `_loc15_` = 最后一行的 y+高（SelectionLalel 高 20）


## 重复开窗时行是**复用**的（现在空菜单只藏不删）⇒ 直接 connect 会撞
## `Signal 'gui_input' is already connected`，更糟的是**一次点击发两遍包**。
## `bind(i)` 每次生成新 Callable，`is_connected` 认不出来，只能按方法名清干净再接。
func _接行点击(行: Control, 序: int) -> void:
	for 连 in 行.gui_input.get_connections():
		var 功: Callable = 连.get("callable")
		if 功.is_valid() and String(功.get_method()) == "_点行":
			行.gui_input.disconnect(功)
	行.gui_input.connect(_点行.bind(序))


## `:249-345` 的 selection 分支：**整段拼成一块**居中富文本，不是"一行一个按钮"。
## 每行 = `<a href="event:值"><font color=…>[前缀]文字(次数/上限)（状态）</font></a>`，
## 行与行之间 `<br/>`、`<textformat leading='5'>`。点击走 `selectionLinKHandler`（`:355`）。
## 离线没有 328 帧 ⇒ `选择` 由 `小地图面板` 按同一套编码给（状态 0=可接、次数按服务端
## 那条 `min(已接+1, 上限)` 取已接=0 ⇒ 富岳就是 `(1/20)`，与用户实机截图一致）。
func _排选择(选择: Array, 菜单数: int) -> float:
	var 块 := _下格.get_node_or_null("选择块") as RichTextLabel
	if 选择.is_empty():
		if 块 != null:
			块.visible = false
		# ⚠ 必须一起清干净：`行文字表()` 是**跨枚 NPC 复用同一个对话窗实例**读的，
		#   上一枚（富岳）的两行没清 ⇒ 后面每一枚都带着它，量具一次报 8 枚不符（本轮实测踩到）。
		_选择净.clear()
		_选择行.clear()
		_选择高 = 0.0
		return 0.0
	if 块 == null:
		块 = RichTextLabel.new()
		块.name = "选择块"
		块.bbcode_enabled = true
		块.scroll_active = false
		块.mouse_filter = Control.MOUSE_FILTER_STOP
		# 链接就得是手型（Flash 的 `<a>` 自带手型 + 下划线 ⇒ 这边两样都得自己给）
		块.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		块.add_theme_font_size_override("normal_font_size", 12)
		_下格.add_child(块)
		块.meta_clicked.connect(_点选择)
	块.visible = true
	var 行们: Array[String] = []
	_选择净.clear()
	for i in 选择.size():
		var 条: Dictionary = 选择[i] as Dictionary
		_值.append(条.get("值", -1))
		# 本工程已移植的那几扇（日环/护送/兑换/卡片…）：**发完 57:3 再开页**，两样都做
		_本地们.append(条.get("本地", null))
		var 净 := 选择文案(条)
		_选择净.append(净)
		# 原版：整行套 `<a href="event:值">`（Flash 的 `<a>` 自带下划线）+ 一个 `<font color=…>`。
		# ⚠ Godot 这边实测 `[meta=…]` **不会被吃掉**（截图上直接印出 `[meta=1]…[/meta]`），
		#   认的是 `[url=…]` —— 点它一样回 `meta_clicked`（meta 就是那个序号）⇒ 用 url 包、
		#   颜色和 `[u]` 放在里面，别让主题的链接色盖掉原版那三档色。
		行们.append("[url=%d][color=%s][u]%s[/u][/color][/url]" % [
				菜单数 + i, 状态色.get(int(条.get("任务状态", 0)), "#00ff00"), 净])
	块.text = "
".join(行们)
	块.add_theme_constant_override("line_separation", int(选择行距))
	块.size = Vector2(选择宽, 0.0)
	块.custom_minimum_size = 块.size
	var 高: float = maxf(1.0, 块.get_content_height())
	块.size = Vector2(选择宽, 高)
	_选择高 = 高
	_选择行 = 行们
	return 高 + 选择块底	# `:339` `_loc8_ = _loc13_.height + 40`


## 一行 selection 的显示文案（`:256-306` 的字符串拼装，逐字）。
static func 选择文案(条: Dictionary) -> String:
	var 类 := String(条.get("类型", ""))
	var 文 := String(条.get("文字", ""))
	if 前缀.has(类):
		文 = 前缀[类] + 文
	if 类 in 带计数:
		文 = "%s(%s/%s)" % [文, str(int(条.get("次数", 0))), str(int(条.get("上限", 0)))]
	# ⚠ 读 `任务状态`（0=可接 1=进行中 2=可交 4=对话）。表里那列 `状态` 是**移植状态说明**，
	#   拿它 `int()` 会报「Cannot represent 已建(… ) as a 64-bit signed integer」并整条不显。
	var 态 := int(条.get("任务状态", 0))
	if 后缀.has(态):
		文 += 后缀[态]
	return 文


func _点选择(序: Variant) -> void:
	按下行(int(String(str(序)).to_int()))


## `:357-362` 下格高 = max(末行底 − 下格.y + 20, 74)。
func _拍下格(菜单底: float = 0.0, 块底: float = 0.0) -> void:
	# `:341-346`：下格高 = max(菜单末行底 + 20, 选择块高 + 40, 74)
	var 高 := maxf(float(下格最少), maxf(菜单底 + 20.0, 块底))
	_下格.size = Vector2(float(506), 高)
	根().size = Vector2(float(506), _上格.size.y + 下格距 + 高)
	_摆选择()


## `:337` `x = (skin.width − textfield.textWidth − 4) / 2`、`:352` `y = skin.y + (skin.height − height)/2`
## ⇒ **按量出来的文字宽水平居中**（不是按 366 那块盒居中），且在**下格内**垂直居中。
func _摆选择() -> void:
	var 块 := _下格.get_node_or_null("选择块") as RichTextLabel
	if 块 == null or _选择行.is_empty():
		return
	var 字 := 块.get_theme_font("normal_font") as Font
	var 号 := 块.get_theme_font_size("normal_font_size")
	var 最宽 := 0.0
	for 净 in _选择净:
		最宽 = maxf(最宽, 字.get_string_size(净, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 号).x)
	块.position = Vector2(floorf((_下格.size.x - 最宽 - 4.0) / 2.0),
			floorf((_下格.size.y - _选择高) / 2.0))


## `clickMenuHandler():129-135` ⇒ `requestNPCMoreTalkEx(NPCTalkCmdType.MENU, value)`，
## 发完就 `closeDialog()`。本工程对应 `request_npc_menu_action(value)`（57 子命令 2）。
## 行为门要用**真事件**点行，但也要能在无头门里直接走同一条代码路径
## （不是 `emit()` 演一遍）⇒ 动作体单独拆出来， 只做事件过滤。
func 行文字表() -> Array[String]:
	var 出: Array[String] = []
	for 行 in _行们:
		出.append((行.get_node("文字") as Label).text)
	for 净 in _选择净:
		出.append(净)
	return 出


## selection 那几行的净文案（门钉的就是它）。
func 选择文字表() -> Array[String]:
	return _选择净.duplicate()


func 按下行(序号: int) -> void:
	if 序号 >= _值.size():
		return
	var 值 = _值[序号]
	var 是任务行 := 序号 >= _菜单数
	var 会 := get_node_or_null("/root/BackendConnection")
	if 值 is Callable:
		# 离线（表算出来的行）或本工程自造入口：只走本地，一个协议包都不发
		(值 as Callable).call()
	elif 是任务行:
		# 原版 `selectionLinKHandler():106-118`：href 的值就是**任务 id** ⇒ `57:3:<任务id>`。
		# 服务端据此走 `_handle_original_quest_npc(selected_quest_id=…)` —— 接取/对话目标/
		# 交付全从这一跳开始。之前这里跟菜单行一样发 `57:2`，服务端把任务 id 当菜单动作值
		# 解析（`NpcMenuAction(raw_action)` 直接 ValueError 丢掉）⇒ **点任务行永远没反应**。
		if 会 != null and 会.has_method("request_npc_selection"):
			会.call("request_npc_selection", int(值))
	elif 会 != null and 会.has_method("request_npc_menu_action"):
		# 原版：菜单动作的回包才是开窗的地方（`Client.as:1212 onCopy_visitHistory → showCopyWindow`、
		# `:1149 onHeroEnterInfo → showEliteCopyWindow`）。本工程那两扇窗挂在 `功能窗口` 的页上，
		# 所以把「值 → 本地页」这一跳交给监听 `行被点` 的小地图面板去做，不在这里写死页面名。
		会.call("request_npc_menu_action", int(值))
		行被点.emit(int(值))
	if 是任务行 and 序号 < _本地们.size() and (_本地们[序号] is Callable):
		(_本地们[序号] as Callable).call()
	关闭()


func _点行(事件: InputEvent, 序号: int) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
		按下行(序号)


## 点下格（"我说完了"）⇒ 发 NEXT 翻下一句；翻到最后一句时服务端才落
## 接取 / 对话目标 / 交付（`_finish_original_quest_dialog`）。原版发完就关窗，
## 下一句由服务端那条 54/328 回包重新把窗打开 —— 本工程 `npc_dialog_received` 同一条路。
func 说完了() -> void:
	var 会 := get_node_or_null("/root/BackendConnection")
	if 会 != null and 会.has_method("request_npc_next"):
		会.call("request_npc_next")
	关闭()


## 点舞台空白 / ESC ⇒ 原版 `__clickStageHandler`：发 CLOSE 并清掉服务端那半截对话，
## **不结算任务**（半途走开就是这个语义）。
func 离开() -> void:
	var 会 := get_node_or_null("/root/BackendConnection")
	if 会 != null and 会.has_method("request_npc_leave"):
		会.call("request_npc_leave")
	关闭()


func _点下格(事件: InputEvent) -> void:
	var 键 := 事件 as InputEventMouseButton
	if 键 != null and 键.pressed and 键.button_index == MOUSE_BUTTON_LEFT:
		说完了()
