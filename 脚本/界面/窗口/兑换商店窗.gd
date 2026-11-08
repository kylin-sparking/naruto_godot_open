extends RefCounted

## 伊鲁卡「兑换商店」= 原版 `exchangeShop/ExchangeShopWindow`（720×540）。
##
## 外壳（内容底 / 列表面板 / 说明行 / 滚动区）在 `场景/界面/窗口/兑换商店/兑换商店窗.tscn`
## （`开发工具/原版服务窗.py 生成 兑换商店` 从 SPEC 产出 ⇒ **别手改 .tscn**）。
## 本文件只做原版运行期那件事：把 `setData(list)` 那批 `ExchangeItem` 摆成格子。
##
## 格子 = `ExchageShopWindowCell`（**类名原版就少个 n**，130×200，`extends Sprite` 无 Embed
## ⇒ 纯代码拼的，库里查不到这张符号）。`addChild` 顺序照 `:195-248` 逐条复现：
##   0 自身 `drawBorder()`：`lineStyle(1,0x474747)` + `beginFill(0x201E22,0.35)` +
##     `drawRoundRect(0,0,130,200,6,6)`（:144-151）⇒ Godot 侧走 `组件/原版图形.gd` 的 `_draw()`
##     （原版是矢量绘制，既不是皮肤图也不是主题样式 ⇒ 手绘 StyleBoxFlat 被 `UI资源回归测试` 禁；
##      该件目前**直角**，原版 6px 圆角未收口，见 `原版图形.gd` 顶部）；
##   1 目标标题 (0,4) 130×16 白居中「兑换物品」（:199-202，msg:2404）；
##   2 主格 `ItemWindowCell` x=(130−40)/2=45 y=22（:203-206 + doLayout :136-137）；
##   3 材料标题 (0,66) 130×16「兑换所需材料」（:207-210，msg:1890；**够料时整行变绿** :187）；
##   4-6 剩余时间/剩余总量/可兑换次数 三行 —— AS3 里 `visible=false` 从未显形，
##     内容只进右上角那枚 ⓘ 的 tooltip（:211-225 + :274-291）⇒ 这里根本不建件，只算文案；
##   7 「兑换」钮 MButtonF `isScale9Grid=true` 80×22 x=(130−80)/2 y=170（:226-235）；
##   8 `_line` LineHPicF 2×2 `visible=false`（:236-242）⇒ 不建；
##   9 材料格容器 x=(130−容器宽)/2 y=84，格 40×40、**每行 3 枚、横距 1 纵距 1**（:243-246 + :400-401）；
##  10 ⓘ 圆点：`lineStyle(1,白,0.85)` + `beginFill(0x336699)` + `drawCircle(7,7,7)`，
##     摆在 `x = 130−18 = 112, y = 4`（:250-274）⇒ Godot 同样走 `原版图形.gd`（`形状 = 型.圆点`，14×14）。
##
## 行数据 = 服务端 `1820 EXCHANGE_ACTION` cmd 0（`ExchangeProcessor.as:53-82` → `Client.as:8939`）
## ⇒ **2026-10-04 用户点头：只接这一条「取列表」**（`后端连接.gd::_decode_exchange_binary` →
##   `authoritative_exchange` → 本文件 `_在线行()`）。**点「兑换」那一跳（cmd 2 + sn）仍未接。**
## `渲染()` 也收调用方给的行数组（门/量具喂 `数据/界面/兑换商店_夹具.json` 用）；
## 两个来源都没有 ⇒ 就是原版那个"没收到回帧"的空态（**不假造数据、也不显示假数字**）。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 文字提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 原版图形 := preload("res://脚本/界面/组件/原版图形.gd")

const 夹具路径 := "res://数据/界面/兑换商店_夹具.json"
const 格皮 := "res://素材/界面/原版窗口/通用控件/物品格.png"
## ⚠ 三条路径**逐条写字面量**，不许写成「目录 + 基名 + 后缀」拼出来：
##   `开发工具/打包木叶村NPC页.py` 的素材扫描与 `页面包闭包.py` 都只认字面量，
##   拼串会让这三张皮在闭包里**查无**（= 交包时静默漏皮）。
const 钮皮 := ["res://素材/界面/原版窗口/兑换商店/兑换钮.png",
		"res://素材/界面/原版窗口/兑换商店/兑换钮_悬停.png",
		"res://素材/界面/原版窗口/兑换商店/兑换钮_按下.png"]		# 80×22 预烘（+30 / −40）

const 格宽 := 130.0
const 格高 := 200.0
const 列数 := 5
const 横距 := 5.0					# `ExchangeShopWindow.as:23 hgap`
const 纵距 := 6.0					# `:25 vgap`
const 格边 := 40.0
const 材料列 := 3					# `ExchageShopWindowCell.as:23 rowCount`
const 材料距 := 1.0					# `:31/:59 hgap=vgap=1`

const 白 := Color(1, 1, 1)
const 绿 := Color(0, 1, 0)					# UI_GREEN
const 红 := Color(1, 0, 0)					# UI_RED
const 橙 := Color(1, 0x91 / 255.0, 0)				# UI_ORANGE

## 语言表逐字（`en_US$message_properties.as`，行号见各条）
const 目标标题 := "兑换物品"					# :2404 EXCHANGE_SHOP_WINDOW_EXCHANGE_ITME
const 材料标题 := "兑换所需材料"					# :1890 EXCHANGE_SHOP_WINDOW_NEED_MATERIA
const 剩余时间头 := "剩余时间"					# :2119
const 剩余总量头 := "剩余总量"					# :3063
const 可兑次数头 := "可兑换次数"					# :2398
const 无限制 := "[color=#00ff00]无限制[/color]"		# :2745 WUXIANZHI（html 原样是 `<font color="#00ff00">`）
const 无限制灰 := "[color=#CCCCCC]无限制[/color]"		# :2533 WUXIANZHI_1
const 已兑完 := "[color=#999999]已全部兑换完毕[/color]"	# :1511 DUIHUAN_WANBI
const 已过期 := "已过期"						# :2706 HAVEEXPIRED
const 兑换字 := "兑换"						# :21 BTN_TEXT
const 已兑字 := "已兑"						# :401 BTN_TEXT_2
const 次 := "次"							# :2493 CELL_CI
const 天 := "天"							# :1513 CELL_DAY
const 小时 := "小时"							# :467 BIGUAN_WINDOW_HOUR
const 分钟 := "分钟"							# :3247 BIGUAN_WINDOW_MINUTE
const 秒 := "秒"							# :1539 COPY_FINISH_WINDOW_SECOND
const 料不足 := "您没有足够的材料来进行兑换，请收集材料后再进行操作"	# :1237 NOTICE_1
const 已兑完知 := "该物品已经兑换完毕，请等待下次活动"		# :1236 NOTICE_2
## ⚠️ 这条常量原来写的是"本工程未接（待点头）" —— **假缺口**（§3.121）：
## 后端 `request_exchange(sn)` 早就有（`1820` 子命令 **2** + sn，服务端 `handle_exchange_action`
## 动作 2 就是结算那一支），系统窗口的「兑换」页一直在用它。这里只留"离线那口话"。
const 离线结算 := "兑换要在服务端结算（离线不模拟）"
const 空态 := "兑换行由服务端 1820 下发（cmd 0 列表）⇒ 未连接后端 / 回帧还没到 ⇒ 列表是空的"


## `宿主` = `功能窗口`（要 `_content` / `_show_hint`（**别直写 `_status.text`**，那是个
##   `visible=false` 的标签，只有 `_show_hint` 会把它显形）/ `_背包数量()` / `_session` / `_舞台尺寸()`）。
static func 渲染(宿主: Node, 场景: PackedScene, 行: Array = []) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 滚动 := 页.get_node("兑换列表") as ScrollContainer
	var 内容 := 滚动.get_node("兑换列表_内容") as Control
	_排滚动(滚动, 内容)
	if 行.is_empty():
		行 = _在线行(宿主)
	if 行.is_empty():
		宿主._show_hint(空态)
		return 页
	宿主._show_hint("兑换商店：%d 行（数据源：服务端回帧 / 门喂的 2.2.3 捕获夹具）" % 行.size())
	建行(内容, 滚动, 行, 宿主)
	return 页


## 会话里的兑换表 = `后端连接.authoritative_exchange`（1820 cmd 0 的**原始二进制**回帧解出来的）。
## 这里把它翻成**原版 `ExchangeItem` 的字段名** —— `建格/刷格/_行文案` 全按 AS3 名读，
## 门喂的夹具也是这套名 ⇒ 「会话 / 夹具」两个来源同一形状，页面里只有一条读取路径。
static func _在线行(宿主: Node) -> Array:
	var 后端: Node = 宿主.get("_backend") as Node
	if 后端 == null or not bool(后端.get("in_game")):
		return []
	var 出: Array = []
	for 条v in (后端.get("authoritative_exchange") as Array):
		var 条: Dictionary = 条v
		var 料: Array = []
		for 项v in (条.get("need_items", []) as Array):
			var 项: Dictionary = 项v
			料.append({"itemid": int(项.get("item_id", 0)), "count": int(项.get("quantity", 0))})
		出.append({
			"sn": int(条.get("sn", 0)),
			"isTimeLimited": bool(条.get("time_limited", false)),
			"restTime": int(条.get("rest_time", 0)),
			"totalCountLimit": int(条.get("total_limit", 0)),
			"singleCountLimit": int(条.get("character_limit", 0)),
			"exchangeCount": int(条.get("exchange_count", 0)),
			"singleExchanged": int(条.get("single_exchanged", 0)),
			"targetItemid": int(条.get("item_id", 0)),
			"targetQuantity": int(条.get("quantity", 1)),
			"needItems": 料,
		})
	return 出


static func 读夹具() -> Array:
	if not FileAccess.file_exists(夹具路径):
		return []
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(夹具路径))
	if typeof(解) != TYPE_DICTIONARY:
		return []
	return (解 as Dictionary).get("行", [])


static func _排滚动(滚动: ScrollContainer, 内容: Control) -> void:
	# 内容宽 = 区宽 − 实测条宽（`ScrollContainer` 的最小宽含条宽 ⇒ 写区宽会把条整条挤出框外）
	var 条宽: float = maxf(0.0, 滚动.get_v_scroll_bar().get_combined_minimum_size().x)
	内容.custom_minimum_size.x = maxf(1.0, 滚动.size.x - 条宽)


static func 建行(内容: Control, 滚动: ScrollContainer, 行: Array, 宿主: Node) -> void:
	var 宽: float = 内容.custom_minimum_size.x
	for i in 行.size():
		var 数: Dictionary = 行[i]
		var 格 := 建格(数, 宿主, 宽)
		内容.add_child(格)
		格.position = Vector2(2.0 + (i % 列数) * (格宽 + 横距), 4.0 + int(i / 列数) * (格高 + 纵距))
	var 高: float = maxf(滚动.size.y, 4.0 + (1 + int((行.size() - 1) / 列数)) * (格高 + 纵距) - 纵距 + 4.0)
	内容.custom_minimum_size.y = 高
	内容.size.y = 高


static func 建格(数: Dictionary, 宿主: Node, 区宽: float) -> Control:
	var 格 := Control.new()
	格.name = "兑换格%s" % str(int(数.get("sn", 0)))
	格.size = Vector2(格宽, 格高)
	格.custom_minimum_size = 格.size
	# 0 边框（原版是 `drawRoundRect` 矢量画的 ⇒ 走 `原版图形.gd::_draw()`，不是样式也不是图）
	var 框 := Control.new()
	框.set_script(原版图形)
	框.name = "边框"
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	框.size = Vector2(格宽, 格高)
	格.add_child(框)
	# 1 目标标题
	格.add_child(_行字("目标标题", 目标标题, 白, 4.0, 格宽))
	# 2 主格
	var 主 := _格子("主格", int(数.get("targetItemid", 0)), int(数.get("targetQuantity", 1)), 宿主)
	主.position = Vector2((格宽 - 格边) / 2.0, 22.0)		# doLayout :136-137
	格.add_child(主)
	# 3 材料标题（够料变绿）
	var 料: Array = 数.get("needItems", [])
	var 够 := true
	for x in 料:
		if int(宿主._背包数量(int((x as Dictionary).get("itemid", 0)))) < int((x as Dictionary).get("count", 0)):
			够 = false
	var 材题 := _行字("材料标题", 材料标题, 绿 if 够 else 白, 66.0, 格宽)
	格.add_child(材题)
	# 9 材料格容器
	var 容 := Control.new()
	容.name = "材料格"
	容.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 列数实: int = mini(材料列, 料.size())
	var 容宽: float = maxf(1.0, 列数实 * (格边 + 材料距) - 材料距)
	for j in 料.size():
		var 项: Dictionary = 料[j]
		var 子 := _格子("材料%d" % (j + 1), int(项.get("itemid", 0)), int(项.get("count", 0)), 宿主)
		# :400-401 `x = width*(i%rowCount) + i%rowCount*hgap`、`y = height*floor(i/rowCount) + …*vgap`
		子.position = Vector2((格边 + 材料距) * (j % 材料列), (格边 + 材料距) * int(j / 材料列))
		# `setFilters(拥有 >= 需求)` ⇒ 不够的那枚灰化（`Style.getDisableFilter` = 同一条灰度矩阵）
		子.set_meta("need", int(项.get("count", 0)))
		if int(宿主._背包数量(int(项.get("itemid", 0)))) < int(项.get("count", 0)):
			_灰化(子)
		容.add_child(子)
	容.size = Vector2(容宽, (1 + int(maxi(0, 料.size() - 1) / 材料列)) * (格边 + 材料距))
	容.position = Vector2((格宽 - 容.size.x) / 2.0, 84.0)		# doLayout :139-140
	格.add_child(容)
	# 7 「兑换」钮
	var 钮 := TextureButton.new()
	钮.name = "兑换钮"
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_SCALE
	钮.texture_normal = load(钮皮[0])
	钮.texture_hover = null					# 三档一律换皮（口径同 MButton3 那族）
	钮.texture_pressed = null
	钮.position = Vector2((格宽 - 80.0) / 2.0, 170.0)		# :226-235
	钮.size = Vector2(80.0, 22.0)
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	格.add_child(钮)
	var 题 := Label.new()
	题.name = "钮字"
	题.size = Vector2(80.0, 22.0)
	题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	题.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	题.add_theme_font_size_override("font_size", 12)
	题.mouse_filter = Control.MOUSE_FILTER_IGNORE
	钮.add_child(题)
	# 10 ⓘ 圆点 + tooltip（原版 `drawCircle` ⇒ 同样走 `原版图形.gd`）
	var 圈 := Control.new()
	圈.set_script(原版图形)
	圈.set("形状", 1)		# 型.圆点 —— 静态类型是 Control，只能走 set()
	圈.name = "信息点"
	圈.position = Vector2(格宽 - 18.0, 4.0)
	圈.size = Vector2(14.0, 14.0)
	圈.mouse_filter = Control.MOUSE_FILTER_STOP
	格.add_child(圈)
	var i字 := Label.new()
	i字.name = "i"
	i字.text = "i"
	i字.position = Vector2(4.0, -2.0)
	i字.size = Vector2(8.0, 16.0)
	i字.add_theme_color_override("font_color", 白)
	i字.add_theme_font_size_override("font_size", 12)
	i字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	圈.add_child(i字)
	var 态 := {"数": 数, "钮": 钮, "钮字": 题, "宿主": 宿主, "够": 够}
	钮.mouse_entered.connect(_钮态.bind(态, 1))
	钮.mouse_exited.connect(_钮态.bind(态, 0))
	钮.button_down.connect(_钮态.bind(态, 2))
	钮.button_up.connect(_钮态.bind(态, 0))
	钮.pressed.connect(点兑换.bind(态))
	圈.mouse_entered.connect(_圈提示.bind(格, 态))
	圈.mouse_exited.connect(_圈离开.bind(格))
	刷格(态)
	_计秒(态)
	return 格


## `setExchageBtnEnabled`（:153-174）三支 + `setRemainGross` 的 `_boolean`（:483-491）。
static func 刷格(态: Dictionary) -> void:
	var 数: Dictionary = 态["数"]
	var 单限: int = int(数.get("singleCountLimit", 0))
	var 单已: int = int(数.get("singleExchanged", 0))
	var 总限: int = int(数.get("totalCountLimit", 0))
	var 总已: int = int(数.get("exchangeCount", 0))
	var 完: bool = 总限 > 0 and 总限 <= 总已
	var 字 := 兑换字
	var 可用 := true
	if (单限 != 0 and 单限 <= 单已) or 完:
		字 = 已兑字
		可用 = false
	elif not bool(态["够"]):
		可用 = false
	(态["钮字"] as Label).text = 字
	var 钮 := 态["钮"] as TextureButton
	钮.disabled = not 可用
	钮.modulate = Color(1, 1, 1) if 可用 else Color(0.55, 0.55, 0.55)
	态["完"] = 完
	态["文案"] = [_行文案(数, 完)]


static func _行文案(数: Dictionary, 完: bool) -> String:
	var 总限: int = int(数.get("totalCountLimit", 0))
	var 单限: int = int(数.get("singleCountLimit", 0))
	var 出 := ""
	if not bool(数.get("isTimeLimited", false)):
		出 = "%s：%s" % [剩余时间头, 无限制]
	elif int(数.get("restTime", 0)) <= 0:
		出 = "%s：%s" % [剩余时间头, 已过期]
	else:
		出 = "%s：%s" % [剩余时间头, _秒数(int(数.get("restTime", 0)))]
	if 总限 == 0:
		出 += "\n%s：%s" % [剩余总量头, 无限制]
	elif 完:
		出 += "\n%s：%s" % [剩余总量头, 已兑完]
	else:
		出 += "\n%s：[color=#00ff00]%d%s[/color]" % [剩余总量头, maxi(0, 总限 - int(数.get("exchangeCount", 0))), 次]
	if 单限 == 0:
		出 += "\n%s：%s" % [可兑次数头, 无限制]
	else:
		出 += "\n%s：[color=#00ff00]【%d】%s[/color]" % [
				可兑次数头, maxi(0, 单限 - int(数.get("singleExchanged", 0))), 次]
	return 出


## `_onTick`（:309-338）的档位：**天 / 小时 / 分钟 / 秒**，且 **< 1 小时整串变红**（:329/:333）。
static func _秒数(秒数: int) -> String:
	var 分: int = 秒数 / 60
	var 时: int = 分 / 60
	var 天: int = 时 / 24
	if 天 > 0:
		return "[color=#00ff00]%d%s[/color]" % [天, 天]
	if 时 > 0:
		return "[color=#00ff00]%d%s[/color]" % [时, 小时]
	if 分 > 0:
		return "[color=#ff0000]%d%s[/color]" % [分, 分钟]
	return "[color=#ff0000]%d%s[/color]" % [秒数, 秒]


## 原版 `new Timer(1000, leftTime)` + `_onTick` 每秒 `--leftTime` ⇒ 这里只搬"会自己走"这件事，
## 到 0 就按 `haveexpired()`（:340-345）把钮禁掉。
static func _计秒(态: Dictionary) -> void:
	var 数: Dictionary = 态["数"]
	if not bool(数.get("isTimeLimited", false)) or int(数.get("restTime", 0)) <= 0:
		return
	var 时 := Timer.new()
	时.name = "秒表"
	时.wait_time = 1.0
	时.one_shot = false
	(态["钮"] as Control).get_parent().add_child(时)
	时.timeout.connect(func():
		var 剩: int = int(数.get("restTime", 0)) - 1
		数["restTime"] = 剩
		if 剩 <= 0:
			时.stop()
			数["isTimeLimited"] = true
			态["过期"] = true
		刷格(态))
	时.start()


static func _钮态(态: Dictionary, 档: int) -> void:
	var 钮 := 态["钮"] as TextureButton
	钮.texture_normal = load(钮皮[档])


static func 点兑换(态: Dictionary) -> void:
	var 宿主 := 态["宿主"] as Node
	var 数: Dictionary = 态["数"]
	if bool(态.get("过期", false)) or bool(态.get("完", false)):
		宿主._show_hint(已兑完知)
	elif not bool(态["够"]):
		宿主._show_hint(料不足)
	else:
		# 三道前置都过了 ⇒ 真发（原版 `onExchange`：`API.client.requestExchange(sn)`）
		var 后端 = 宿主._backend
		if 后端 == null or not bool(后端.in_game):
			宿主._show_hint(离线结算)
		elif not 后端.request_exchange(int(数.get("sn", 0))):
			宿主._show_hint("请求发送失败，请检查原版服务器连接")
		# 发成功**不提示**（同 `功能窗口._成交修理`/`请求商城商品`）：
		# 兑换的结果由回帧把背包和余额刷出来，玩家看的是那个，不是回执一句话。


static func _行字(名: String, 文: String, 色: Color, y: float, 宽: float) -> Label:
	var 字 := Label.new()
	字.name = 名
	字.text = 文
	字.position = Vector2(0.0, y)
	字.size = Vector2(宽, 16.0)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.add_theme_color_override("font_color", 色)
	字.add_theme_font_size_override("font_size", 12)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return 字


## `ItemWindowCell`（`cell/ItemWindowCell.as:50-60`）：格底 `MGrid_background` 40×40 先 addChild，
## 数量 tf 在格内 (1,24) 37×16；图标是 `__showIcon` 之后 `addChild` 进格的子件 ⇒ 居中取整。
static func _格子(名: String, 号: int, 数: int, 宿主: Node) -> Control:
	var 格 := TextureRect.new()
	格.name = 名
	格.texture = load(格皮)
	格.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	格.stretch_mode = TextureRect.STRETCH_SCALE
	格.size = Vector2(格边, 格边)
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	标.text = str(数) if 数 > 0 else ""
	标.position = Vector2(1.0, 24.0)
	标.size = Vector2(37.0, 16.0)
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", 白)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(标)
	var 节点名 := "物品提示_" + 名
	格.mouse_entered.connect(func():
		var 页: Control = 格
		while 页 != null and not String(页.name).begins_with("原版"):
			页 = 页.get_parent() as Control
		if 页 == null:
			return
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
		var 页: Control = 格
		while 页 != null and not String(页.name).begins_with("原版"):
			页 = 页.get_parent() as Control
		if 页 != null:
			var 框 := 页.get_node_or_null(节点名) as CanvasItem
			if 框 != null:
				框.visible = false)
	return 格


static func _灰化(格: Control) -> void:
	# `Style.getDisableFilter()` 的矩阵系数与 `禁用灰度.gdshader` 同一条；
	# ⚠ 材质**不会被子节点继承**（本工程实测）⇒ 格底与图标/数量都要挂。
	var 材 := load("res://脚本/界面/组件/禁用灰度.gdshader")
	var 灰 := Color(0.42, 0.42, 0.42, 1.0)
	for 子 in [格] +格.get_children():
		var 项 := 子 as CanvasItem
		if 项 != null:
			var m := ShaderMaterial.new()
			m.shader = 材
			项.material = m
		if 子 is Label:
			(子 as Label).add_theme_color_override("font_color", 灰)


static func _圈提示(格: Control, 态: Dictionary) -> void:
	var 页: Control = 格
	while 页 != null and not String(页.name).begins_with("原版"):
		页 = 页.get_parent() as Control
	if 页 == null:
		return
	var 名 := "文字提示_信息点"
	var 框 := 页.get_node_or_null(名) as Control
	if 框 == null:
		框 = 文字提示场景.instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页.add_child(框)
	框.设置(确认弹.文案转BBCode(String((态["文案"] as Array)[0])).replace("\n", "[br]"),
			页.get_viewport_rect().size)
	框.visible = true
	框.贴到鼠标(页.get_local_mouse_position(), 页.get_viewport_rect().size)


static func _圈离开(格: Control) -> void:
	var 页: Control = 格
	while 页 != null and not String(页.name).begins_with("原版"):
		页 = 页.get_parent() as Control
	if 页 == null:
		return
	var 框 := 页.get_node_or_null("文字提示_信息点") as CanvasItem
	if 框 != null:
		框.visible = false
