extends SceneTree

## 福利页去充值回归门（2026-10-28 用户报修「开心有礼：首充礼包→首日礼包、累计充值元宝→累计击杀BOSS数」；
## 2026-10-31 再改口径：首日礼包 → **首杀礼包**（击杀一只 BOSS 可领）、活动期固定为当月）。
##
## 病根不是某个 bug，而是**三处会各自漂移**的口径：
##   ① 门槛数字**烘在场景文案里**（`福利窗口.tscn` 的「活动期间累计充值100元宝」那一排）；
##   ② 服务端那两张表在 `fake_flash_server.py`（`LIMITED_ACTIVITY_BOSS_TOTAL` / `_EACH`）；
##   ③ 客户端填数与点击口径在 `活动窗口.gd`（读哪个字段、往哪个节点写）。
## 三者只要有一处改了另两处没跟上，玩家看到的就是"页面上写 100 元宝、服务端按 8 只算"这种
## 谁都对不上的面板。所以本门**同时**钉三层：场景结构、字面数字、以及**把 `活动窗口` 的
## 三个填数函数真跑一遍**（喂假 `1814` 载荷，看节点被写成什么、点下去发了什么协议）。
##
## 第四层是这轮改文案时顺手挖出来的：原版那些 `RichTextLabel` 的文案是 **Flash 的 `htmlText`**
## （`<font color='#00ff00'>`），而 Godot 吃 BBCode。`福利窗口.tscn` 里烘的那行是 BBCode，
## 客户端代码写的却是 HTML —— 于是**数据一到，整串尖括号标签原样显示成文字**，
## 这轮要展示的「累计击杀BOSS数」玩家根本看不到。所以第二层里每条填完数的富文本都过
## `_钉是BBCode`：不许残留尖括号，且必须是场景那种 `[color=…]` 写法。
##
## ⚠️ 三层里最容易被漏的是"点击那条腿"：离线时 `_充值活动()` 是空 dict，`_填限时大奖`
##    在函数头就 `return` 了 —— 于是 `页.get_node("击杀数")` 这一句**根本不会被执行**，
##    场景改了节点名而客户端没改，离线门也不会红（`功能入口回归测试` 就是这种情况）。
##    本门用假后端把 `authoritative_czhuodong` 喂满，专治这一条。
##
## 原版真值（只读参照，运行期不 import 2.2.3）：
##   `PrizeFirstCZWindow.as:234-250`（`active`/`chargeTotal` 两态）＋ `:254-267`（`lingQuHandler`）
##   `PrizeActivityPanel.as:103-156`（`chargeTotal`/`statusTotal`/`detailTotal`）＋ `:196-205`（点击带 `configure.info.id`）
##   `PrizeXinFuWindow.as:232-250`（`curr>=count && count>0` ⇒ 已领取）＋ `:254-262`（`count==0` ⇒ 只提示、**不发协议**）
## 本轮偏离原版的登记在 `真值/窗口/开心有礼.md` ④ ＋ 编年史 §3.304。
##
## 运行：`Godot --headless --path . --script res://测试/福利页去充值回归测试.gd`

const 福利场景路径 := "res://场景/界面/窗口/福利/福利窗口.tscn"
const 活动窗口脚本 := "res://脚本/界面/窗口/活动窗口.gd"
## 悬停腿要从 `数据/物品.json` 现读物品名（提示框 标题 就是它填的）。
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 与服务端两张表逐条对齐（表本身由 `开发工具/服务端福利页体检.py` 拿源码核这两串字面量）。
const 累计门槛 := [1, 2, 3, 5, 8, 12, 20, 30, 50]
const 额度门槛 := [2, 4, 8, 16]

## 不许在这三页里出现的充值字样（有意偏离原版：用户 2026-10-28 要求去掉充值功能与信息）。
const 禁词 := ["首充", "充值", "捐", "元宝", "点券"]

var 红数 := 0
## 悬停腿实际跑了几条（期望 8）。GDScript 运行期错误只会掐断**当前这一段**、
## 后面的 `_记` 全不执行 —— 不给个计数，整段被跳过时门照样打「通过」（本工程踩过）。
var 悬停腿数 := 0


## 只记参数、不发包的假后端。`_充值活动()` 要的是 `in_game` + `authoritative_czhuodong` 两样。
class 假后端 extends RefCounted:
	var in_game := true
	var authoritative_czhuodong: Dictionary = {}
	var authoritative_gifts: Dictionary = {}
	var 发的: Array = []

	func request_czhuodong_gain(活动id: String, 类型: String, 档号: int) -> bool:
		发的.append(["gain", 活动id, 类型, 档号])
		return true

	func request_czhuodong_gain_first_kill() -> bool:
		发的.append(["first_kill"])
		return true

	func request_czhuodong_gain_xinfu(类型: String, 奖励id: int) -> bool:
		发的.append(["xinfu", 类型, 奖励id])
		return true


class 假宿主 extends RefCounted:
	var _backend
	var 提示: Array = []
	## `格子提示框.接线` 的闭包要这两样（`_session.player_stats` / `_舞台尺寸()`）——
	## 只在悬停时读，所以下面那几条悬停腿没有它们就会直接报错。
	var _session := {"player_stats": {"level": 90, "job": 1}, "equipped_items": {}}
	var _activity := {"state": {}}

	func _show_hint(文: String) -> void:
		提示.append(文)

	func _舞台尺寸() -> Vector2:
		return Vector2(960.0, 560.0)

	func _today() -> int:
		return 1

	## `活动窗口` 会往图标上挂这枚材质；门里不判渲染，给个 `null` 让它"不灰"就行。
	func 禁用灰度材质() -> Material:
		return null


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 资源 := load(福利场景路径) as PackedScene
	if 资源 == null:
		_记(false, "福利窗口.tscn 读不到（下面全部判据会空转）")
		_finish()
		return
	var 场 := 资源.instantiate()
	root.add_child(场)

	_扫场景(场)
	var 页代码 = _建填数机(场)
	if 页代码 != null:
		_跑首杀礼包(页代码, 场)
		_跑限时大奖(页代码, 场)
		_跑新服有礼(页代码, 场)
		_跑线上有礼(页代码, 场)
		_跑悬停详情框(页代码, 场)
	_扫源码()
	场.free()
	_finish()


## ── 第一层：场景结构（节点名 / 文案 / 坐标）──────────────────────────────────
func _扫场景(场: Control) -> void:
	var 页签 := 场.get_node_or_null("分页") as Control
	if 页签 == null or 页签.get_child_count() != 6:
		_记(false, "分页不是 6 个页签（实际 %d）" % (页签.get_child_count() if 页签 != null else -1))
		return
	var 第二页 := 页签.get_child(2) as Button
	_记(第二页 != null and 第二页.name == &"首杀礼包" and 第二页.text == "首杀礼包",
			"第 3 个页签没改成「首杀礼包」（节点名或文字仍是旧口径）")
	for 页号 in [2, 4, 5]:
		var 页 := 场.get_node_or_null("滚动区/内容/%s" % (页签.get_child(页号) as Button).name) as Control
		if 页 == null:
			_记(false, "内容页 %d（%s）找不到" % [页号, (页签.get_child(页号) as Button).name])
			continue
		for 禁 in 禁词:
			_记(not _页里有(页, 禁),
					"「%s」页里还留着 %s（这三页按用户口径不许再有充值/元宝/点券信息）" % [页.name, 禁])
	# 首杀礼包页：页头那行删干净了，框要跟着上移 24。
	var 首杀 := 场.get_node_or_null("滚动区/内容/首杀礼包") as Control
	if 首杀 != null:
		var 框 := 首杀.get_node_or_null("奖励框") as Panel
		_记(框 != null and int(框.offset_top) == 21,
				"首杀礼包页「奖励框」没跟着页头一起上移（offset_top=%s，期望 21）"
				% (框.offset_top if 框 != null else "无节点"))
		_记(框 != null and 框.get_node_or_null("领取") is Button, "首杀礼包页的「领取」钮没了")
		# 条件文案得说清楚是击杀 —— 离线时状态块是空的，玩家能看到的只有这一行。
		var 说明 := 框.get_node_or_null("奖励说明") as RichTextLabel if 框 != null else null
		_记(说明 != null and 说明.text.contains("BOSS"),
				"首杀礼包页的奖励说明没写清领取条件（实际：%s）"
				% (说明.text if 说明 != null else "无节点"))
	_记(场.get_node_or_null("滚动区/内容/限时大奖/击杀数") is LineEdit,
			"限时大奖页没有改名的「击杀数」输入框（客户端按这个名字取节点，缺了就崩）")
	_记(场.get_node_or_null("滚动区/内容/限时大奖/单位") != null,
			"限时大奖页那枚单位标签没从「元宝」改成「单位」")
	# 限时大奖九档 / 四档的字面门槛 —— 玩家看到的就是这串数字。
	for 序 in 累计门槛.size():
		var 案 := 场.get_node_or_null("滚动区/内容/限时大奖/累计%d/文案" % (序 + 1)) as RichTextLabel
		_记(案 != null and 案.text.contains("累计击杀[color=#ff0000]%d[/color]只BOSS" % 累计门槛[序]),
				"累计%d 的文案门槛不是 %d 只（实际：%s）" % [序 + 1, 累计门槛[序], 案.text if 案 != null else "无节点"])
	for 序 in 额度门槛.size():
		var 案 := 场.get_node_or_null("滚动区/内容/限时大奖/额度%d/文案" % (序 + 1)) as RichTextLabel
		_记(案 != null and 案.text.contains("每击杀满[color=#ff0000]%d[/color]只BOSS" % 额度门槛[序]),
				"额度%d 的文案门槛不是 %d 只（实际：%s）" % [序 + 1, 额度门槛[序], 案.text if 案 != null else "无节点"])
	# 新服有礼：点券三兄弟删干净，换成一枚真物品格。
	var 每档 := 场.get_node_or_null("滚动区/内容/新服有礼/大奖框/每档1") as Control
	if 每档 == null:
		_记(false, "新服有礼「每档1」整行不见了")
	else:
		for 名 in ["可领", "点券数", "点券"]:
			_记(每档.get_node_or_null(名) == null, "新服有礼「每档1」还留着点券节点 %s" % 名)
		var 图 := 每档.get_node_or_null("物品0图") as TextureRect
		_记(图 != null and 图.texture != null, "新服有礼「每档1」没有物品图（送的是物品，格子得画出来）")
		var 排行 := 场.get_node_or_null("滚动区/内容/新服有礼/大奖框/排行2") as Control
		_记(排行 != null and int(排行.offset_top) == 96,
				"排行2 没给每档1 腾出物品格的位置（offset_top=%s，期望 96）"
				% (排行.offset_top if 排行 != null else "无节点"))


func _页里有(根: Node, 串: String) -> bool:
	for 节 in 根.find_children("*", "", true, false):
		if String(节.name).contains(串):
			return true
		var t: Variant = 节.get("text")
		if typeof(t) == TYPE_STRING and String(t).contains(串):
			return true
	return false


## ── 第二层：把三个填数函数真跑一遍 ──────────────────────────────────────────
func _建填数机(场: Control) -> Object:
	var 宿主 := 假宿主.new()
	宿主._backend = 假后端.new()
	var 页代码 = load(活动窗口脚本).new(宿主)
	if 页代码 == null:
		_记(false, "活动窗口.gd 实例化失败")
	return 页代码


func _后端(页代码: Object) -> Object:
	return 页代码.窗口._backend


## 富文本落到节点上的**必须**是 BBCode：尖括号一个都不许剩（`<font …>` 会原样显示成文字），
## 且这轮改的关键词要在。第二层每条填数腿填完都过这里。
func _钉是BBCode(文: String, 节点名: String, 关键词: String) -> void:
	_记(not 文.contains("<") and not 文.contains(">"),
			"%s 里还有尖括号标签没翻译（玩家会看到 `%s`）" % [节点名, 文])
	_记(文.contains("[color="), "%s 没走 `译文为BBCode`（没有 [color=…] 标记：%s）" % [节点名, 文])
	_记(文.contains(关键词), "%s 少了「%s」（实际：%s）" % [节点名, 关键词, 文])


## 首杀礼包（2026-10-31 用户口径：原「首日礼包」，条件 = 击杀一只 BOSS）。
## 三态：达标未领 ⇒ 可点并发 cmd 4；已领 ⇒ 置灰；未达标（bossKills=0）⇒ 置灰。
## 「跨天已过期」那一态随日期键一起退休了 —— 条件不再是建号当天。
func _跑首杀礼包(页代码: Object, 场: Control) -> void:
	var 页 := 场.get_node("滚动区/内容/首杀礼包") as Control
	var 钮 := 页.get_node("奖励框/领取") as Button
	var 后端 := _后端(页代码)
	# 态一：杀过一只 ⇒ 「领取奖励」可点，点下去发 cmd 4。
	后端.authoritative_czhuodong = {"first_kill": {"active": 0, "bossKills": 1}}
	后端.发的.clear()
	页代码._填首杀礼包(页)
	_记(钮.text == "领取奖励" and not 钮.disabled, "首杀礼包：已杀 BOSS 却画成 %s（disabled=%s）" % [钮.text, 钮.disabled])
	钮.pressed.emit()
	_记(后端.发的 == [["first_kill"]], "首杀礼包：点「领取」没发 cmd 4（实际 %s）" % str(后端.发的))
	# 态二：已领 ⇒ 置灰、点了不发。
	后端.authoritative_czhuodong = {"first_kill": {"active": 1, "bossKills": 9}}
	后端.发的.clear()
	页代码._填首杀礼包(页)
	_记(钮.text == "已领取" and 钮.disabled, "首杀礼包：已领却仍是 %s（disabled=%s）" % [钮.text, 钮.disabled])
	钮.pressed.emit()
	_记(后端.发的.is_empty(), "首杀礼包：已领还能重复发协议（%s）" % str(后端.发的))
	# 态三：一只 BOSS 都没杀 ⇒ 「领取奖励」但置灰（别摆成看着能点、点了没反应）。
	后端.authoritative_czhuodong = {"first_kill": {"active": 0, "bossKills": 0}}
	后端.发的.clear()
	页代码._填首杀礼包(页)
	_记(钮.text == "领取奖励" and 钮.disabled,
			"首杀礼包：没杀过 BOSS 却画成 %s（disabled=%s）" % [钮.text, 钮.disabled])
	钮.pressed.emit()
	_记(后端.发的.is_empty(), "首杀礼包：未达标还发得出协议（%s）" % str(后端.发的))
	# 数据没到 ⇒ 置灰。
	后端.authoritative_czhuodong = {}
	页代码._填首杀礼包(页)
	_记(钮.disabled, "首杀礼包：没拿到状态时按钮还是可点的")


func _跑限时大奖(页代码: Object, 场: Control) -> void:
	var 页 := 场.get_node("滚动区/内容/限时大奖") as Control
	var 后端 := _后端(页代码)
	var 状态: Array = []
	for 门槛 in 累计门槛:
		状态.append(1 if 门槛 <= 8 else 0)          # 击杀数喂 8 ⇒ 前 5 档达标
	var 明细: Array = []
	for 序 in 累计门槛.size():
		明细.append({"curr": 1 if 序 == 0 else 0, "count": 1})   # 第 1 档已经领过
	后端.authoritative_czhuodong = {
		# ⚠️ `id` 必须是 **float**：线上走 AMF3/JSON，数字一律解成 float（实测 config.limit.info.id = 1.0）。
		#    客户端若直接 `str()` 就会送出 "1.0"，服务端只认 "1"/"limit" ⇒ 点了没反应。
		"config": {"limit": {"info": {"id": 5.0}}, "fc": {"info": {}}},
		"limit": {
			"active": 1, "bossKills": 8, "beginTime": "2026-07-01 00:00:00", "endTime": "2026-08-01 00:00:00",
			"statusTotal": 状态, "statusEach": [1, 1, 0, 0],
			"detailTotal": 明细, "detailEach": [{"curr": 0, "count": 1}, {"curr": 0, "count": 1},
				{"curr": 0, "count": 0}, {"curr": 0, "count": 0}],
		},
	}
	后端.发的.clear()
	页代码._填限时大奖(页)
	_记((页.get_node("击杀数") as LineEdit).text == "8",
			"限时大奖：bossKills 没落进「击杀数」框（实际 %s）" % (页.get_node("击杀数") as LineEdit).text)
	var 标题 := (页.get_node("活动标题") as RichTextLabel).text
	_记(not 标题.contains("充值"), "限时大奖：标题还是充值口径（%s）" % 标题)
	_钉是BBCode(标题, "限时大奖「活动标题」", "累计击杀BOSS数")
	# 场景里烘的那行是右对齐；代码翻译完没套 `[right]` 的话，数据一到标题就从右跳左。
	_记(标题.begins_with("[right]") and 标题.ends_with("[/right]"),
			"限时大奖：标题丢了场景那行的右对齐（%s）" % 标题)
	var 一档 := (页.get_node("累计1/领取") as Button)
	_记(一档.text == "已领取" and 一档.disabled, "限时大奖：已领的第 1 档没置灰（%s）" % 一档.text)
	var 五档 := (页.get_node("累计5/领取") as Button)
	_记(五档.text == "领取奖励" and not 五档.disabled, "限时大奖：达标未领的第 5 档不可点（%s）" % 五档.text)
	# 这条同时钉「活动 id 读 config.limit.info.id」—— 上一版误读 config.fc，靠兜底值撞对。
	五档.pressed.emit()
	_记(后端.发的 == [["gain", "5", "total", 4]],
			("限时大奖：点第 5 档发的报文不对（%s）。id 必须是 config.limit 的 5（float 5.0 要归成 \"5\"，"
			+ "带小数点服务端不认），不是 fc 的兜底 1") % str(后端.发的))
	# 非数字 id（服务端同样接受 "limit"）必须原样送，不能被 int() 抹成 0。
	(后端.authoritative_czhuodong["config"]["limit"]["info"] as Dictionary)["id"] = "limit"
	后端.发的.clear()
	(页.get_node("累计2/领取") as Button).pressed.emit()
	_记(后端.发的 == [["gain", "limit", "total", 1]],
			"限时大奖：字符串 id 被改写了（%s）——服务端认 \"limit\"，抹成别的就领不到" % str(后端.发的))
	# 未达标的那档点下去只给说法、不发协议，且提示语不再是"充值额"。
	var 后端2 := 假后端.new()
	后端2.authoritative_czhuodong = 后端.authoritative_czhuodong
	页代码.窗口._backend = 后端2
	(页.get_node("累计9/领取") as Button).pressed.emit()
	_记(后端2.发的.is_empty(), "限时大奖：没达标也发了协议（%s）" % str(后端2.发的))
	_记((页代码.窗口.提示.size() == 1 and String(页代码.窗口.提示[0]).contains("击杀数")),
			"限时大奖：未达标的提示语还在说充值（%s）" % str(页代码.窗口.提示))
	页代码.窗口._backend = 后端


func _跑新服有礼(页代码: Object, 场: Control) -> void:
	var 页 := 场.get_node("滚动区/内容/新服有礼") as Control
	var 后端 := _后端(页代码)
	# count 必须是 1：原版点击规则是 `count==0 ⇒ 只提示不发协议`，喂 0 这两条免费档就永远领不到。
	后端.authoritative_czhuodong = {"xinfu": {
		"active": 1,
		"detailEach": {"6000057": {"curr": 0, "count": 1}},
		"detailRank": {"6000058": {"curr": 1, "count": 1}},
	}}
	后端.发的.clear()
	页代码._填新服有礼(页)
	var 每钮 := (页.get_node("大奖框/每档1/领取") as Button)
	_记(每钮.text == "领取奖励" and not 每钮.disabled, "新服有礼：免费档没变成可领（%s）" % 每钮.text)
	每钮.pressed.emit()
	_记(后端.发的 == [["xinfu", "EACH", 6000057]], "新服有礼：点免费档没发协议（%s）" % str(后端.发的))
	var 排钮 := 页.get_node("大奖框/排行2/领取") as Button
	_记(排钮.text == "已领取" and 排钮.disabled, "新服有礼：领过的排行档没置灰（%s）" % 排钮.text)


## 「线上有礼」不在本轮改的三页里，但它的 `上周获奖` 和限时大奖标题是**同一个 HTML 没翻译**的病
## （`PrizeOnlinePane2.as:221-223` 的 `htmlText` 直接抄进代码）。这轮顺手接上转换器，
## 就一并钉住：别哪天又退回成尖括号原样显示。
func _跑线上有礼(页代码: Object, 场: Control) -> void:
	var 页 := 场.get_node("滚动区/内容/线上有礼") as Control
	var 后端 := _后端(页代码)
	后端.authoritative_gifts = {"monthly": {
		"last_week_minutes": 120, "last_week_reward": 5, "week_minutes": 480, "gainable": true,
	}}
	页代码._填线上有礼(页)
	_钉是BBCode((页.get_node("上周获奖") as RichTextLabel).text, "线上有礼「上周获奖」", "上周获得5点券奖励")
	_记((页.get_node("上周时长") as LineEdit).text == "2小时"
			and (页.get_node("本周时长") as LineEdit).text == "8小时",
			"线上有礼：时长框没按分钟填成小时（%s / %s）" % [
				(页.get_node("上周时长") as LineEdit).text, (页.get_node("本周时长") as LineEdit).text])
	# `gainable` 为真时原版还会补一段蓝色的「[未获奖]」—— 抄的就是那两条标签，钉一下没漏。
	_记((页.get_node("领取上周") as Button).disabled == false, "线上有礼：可领时「领取上周」却是灰的")


## ── 悬停详情框（2026-11-01 用户报修「开心有礼和首杀礼包，里面的道具礼包鼠标放上去
##    都没有显示详情框」）────────────────────────────────────────────────────
## 真值：原版这四个子页的格子都是 `PrizeItemCell`（`showToolTip:153-156`）/
## `SimpleItemCell`（`as:220`），悬停弹 `MToolTipItem`；「线上有礼」三档图标是 SWF 美术、
## 没有 ItemData，原版不弹 —— 那边不接，这里也不判。
##
## 判据三层：① 格子被抬成 STOP（场景里烘的是 IGNORE，不抬的话悬停事件根本到不了格子）；
## ② 悬停真把 `物品提示框` 点亮且标题是**这一格发的那件物品**（id 从配置现给，名字从
## `数据/物品.json` 现读）；③ 移开真收回去。`11010041` 的名字顺带钉死（本轮改名）。
func _跑悬停详情框(页代码: Object, 场: Control) -> void:
	var 后端 := _后端(页代码)
	后端.authoritative_czhuodong = {
		"config": {
			"fc": {"info": {"libaoId": 11_010_041.0},
				"actions": {"each": {"0": {"items": [{"id": 11_010_041.0, "count": 10.0}]}}}},
			"limit": {"info": {"id": 1.0}, "actions": {
				"total": [{"cash": 1.0, "items": [{"id": 11_010_057.0, "count": 1.0}]}],
				"each": [{"cash": 2.0, "items": [{"id": 15_009_004.0, "count": 4.0}]}],
			}},
			"_xinfu": {"actions": {
				"each": {"6000057": {"items": [{"id": 15_012_001.0, "count": 1.0}]}},
				"rank": {"6000058": {"items": [{"id": 15_009_005.0, "count": 1.0}]}},
			}},
		},
		"first_kill": {"active": 0, "bossKills": 1},
		"limit": {"active": 1, "bossKills": 1,
			"beginTime": "2026-11-01 00:00:00", "endTime": "2026-12-01 00:00:00",
			"statusTotal": [1, 0, 0, 0, 0, 0, 0, 0, 0], "statusEach": [1, 0, 0, 0],
			"detailTotal": [], "detailEach": []},
		"xinfu": {"active": 1,
			"detailEach": {"6000057": {"curr": 0, "count": 1}},
			"detailRank": {"6000058": {"curr": 0, "count": 1}}},
	}
	页代码._填签到(场.get_node("滚动区/内容/每日签到"))
	页代码._填首杀礼包(场.get_node("滚动区/内容/首杀礼包"))
	页代码._填限时大奖(场.get_node("滚动区/内容/限时大奖"))
	页代码._填新服有礼(场.get_node("滚动区/内容/新服有礼"))

	# 签到第 1 天两格：发给的是 `数据/礼包.json` 的 day1 前两件。
	_验悬停(场, "滚动区/内容/每日签到/第1天/物品1格", 11_000_160)
	_验悬停(场, "滚动区/内容/每日签到/第1天/物品2格", 15_002_001)
	# 首杀礼包：左格是礼包本体，右格是礼包里的东西（配置发的是同一件 ×10）。
	_验悬停(场, "滚动区/内容/首杀礼包/奖励框/礼包格格", 11_010_041)
	_验悬停(场, "滚动区/内容/首杀礼包/奖励框/奖励格区/奖励1格", 11_010_041)
	# 限时大奖：累计档与额度档各取第一格的奖品。
	_验悬停(场, "滚动区/内容/限时大奖/累计1/奖励1格", 11_010_057)
	_验悬停(场, "滚动区/内容/限时大奖/额度1/奖励1格", 15_009_004)
	# 新服有礼：两行各一格。
	_验悬停(场, "滚动区/内容/新服有礼/大奖框/每档1/物品0格", 15_012_001)
	_验悬停(场, "滚动区/内容/新服有礼/大奖框/排行2/物品0格", 15_009_005)

	# 本轮改名：`11010041` 的显示名必须已经是「首杀礼包」（数据表 `数据/物品.json`，
	# 由 `开发工具/改首杀礼包道具名.py` 改；另一件「回归首充礼包」不许被连带）。
	var 包 := 游戏数据.item("11010041")
	_记(String(包.get("name", "")) == "首杀礼包",
			"11010041 的显示名还是「%s」（本轮用户要求改成「首杀礼包」）" % 包.get("name", ""))
	var 回归 := 游戏数据.item("11010067")
	_记(String(回归.get("name", "")).contains("回归首充礼包"),
			"11010067「回归首充礼包」被误改成了「%s」" % 回归.get("name", ""))


## 一格：抬成 STOP → 悬停点亮且标题对 → 移开收回。
func _验悬停(场: Control, 路径: String, 物品id: int) -> void:
	悬停腿数 += 1
	var 格 := 场.get_node_or_null(路径) as Control
	if 格 == null:
		_记(false, "悬停：%s 找不到（格子路径改名了？）" % 路径)
		return
	_记(格.mouse_filter == Control.MOUSE_FILTER_STOP,
			"悬停：%s 的 mouse_filter 还是 %d（必须抬成 STOP，否则悬停到不了格子）"
			% [路径, 格.mouse_filter])
	var 框 := 场.get_node_or_null("物品提示框") as Control
	if 框 == null:
		_记(false, "悬停：场景根没有「物品提示框」（ScrollContainer 里会被裁掉，得挂根下）")
		return
	格.mouse_entered.emit()
	var 期望 := String(游戏数据.item(str(物品id)).get("name", ""))
	var 实 := String((框.get_node("标题") as Label).text)
	_记(框.visible and 实 == 期望,
			"悬停：%s 没弹出「%s」的详情框（visible=%s 标题=「%s」）" % [路径, 期望, 框.visible, 实])
	格.mouse_exited.emit()
	_记(not 框.visible, "悬停：%s 移开鼠标后详情框还亮着" % 路径)


## ── 第三层：源码 tripwire（客户端还在读服务端已经不发的那个字段吗）────────────
## 只扫**代码行**：这轮改的口径在注释里还得留着讲原版行为（`## 原版读 firstCZData.chargeTotal…`），
## 连注释一起禁就成了假红 —— 上一版就是这么红的。
func _代码部分(文: String) -> String:
	var 出 := ""
	for 一 in 文.split("\n"):
		if 一.strip_edges().begins_with("#"):
			continue
		出 += 一 + "\n"
	return 出


func _扫源码() -> void:
	var 全文 := FileAccess.get_file_as_string(活动窗口脚本)
	if 全文.is_empty():
		_记(false, "活动窗口.gd 读不到（这层会空转）")
		return
	var 文 := _代码部分(全文)
	for 旧 in ["chargeTotal", "cashbindRemaining", "first_charge", "充值金额", "request_czhuodong_gain_fc"]:
		_记(not 文.contains(旧), "活动窗口.gd 的代码还在引用 %s（服务端已不发/场景已删）" % 旧)
	for 新 in ["bossKills", "first_kill", "_填首杀礼包", "request_czhuodong_gain_first_kill",
			"富文本.译文为BBCode"]:
		_记(文.contains(新), "活动窗口.gd 里没有 %s（这轮改的口径没落到代码上）" % 新)


func _finish() -> void:
	_记(悬停腿数 == 8,
			"悬停腿只跑了 %d/8 条 —— 中途有运行期错误把这一段掐了，别让剩下的判据假绿" % 悬停腿数)
	if 红数 == 0:
		print("福利页去充值回归测试：通过（场景无充值/点券残留 · 九档四档字面门槛与表一致 · "
				+ "首杀三态 · 击杀数落框与活动id取 limit（float 归一）· 新服免费档可领 · 富文本走 BBCode）"
				+ " · 四页格子悬停弹详情框（首杀礼包/限时大奖/新服有礼/每日签到，线上有礼无 ItemData 不接）")
		quit(0)
	else:
		print("福利页去充值回归测试：失败 %d 项" % 红数)
		quit(1)
