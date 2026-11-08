extends SceneTree

## 离线门：右下角那列「获得提示」（原版 `NoticePnl` + 喂它的两处差值引擎）。
##
## 玩家眼里的效果：杀一只怪、接一单任务、用掉一盒拉面，屏幕**右下角**就该冒出一列
## 右对齐的描边小字（`经验 +160`、`金币 +400`、`获得了3个拉面（小）`……），
## 停 10 秒后整列一起淡掉；新的一条进来会把计时重新拉起，最多留 8 行。
##
## 五条腿，各挡一类「看着像做完了」：
##  * **文案腿**：模板逐条对语言包 `en_US$message_properties.as`（本文件**自己抄一份**标签与色，
##    与 `获得提示文案.gd` 两本对照），并把「该不出的一条都不许出」当硬判据 ——
##    HP/MP/攻/防/暴/闪 在原版**只飘字不进这列**，等级放特效，经验变少不提示。
##  * **差值腿**：喂**真文本帧**（`38:25&100@27&5000…`）走 `_handle_stats_text`，
##    而不是只调内部函数 ⇒ 解析、字段号表、5 秒初始化期一起验到。
##    原版 `DataCenter.as:2281-2288` 那个「进游戏 5 秒内不提示」是**这条链最容易做反的地方**：
##    压过头 = 玩家杀怪没反馈；压不住 = 一上线刷一屏假增减。
##  * **背包腿**：ADD / UPDATE / CLEAR / DROP 四支各一条（`ItemManager.as:52/95/439/443/574`），
##    外加 `fromDrop == 2`（进游戏那份整包）与装备槽（slot < 0）两条反向对照，
##    以及 UPDATE 那支 `can_trade` 到底读第几段（读到第 6 段就永远显示"未绑定"）。
##  * **版面腿**：8 行上限、行序（新的贴锚点、往上长）、250 宽右对齐、描边、鼠标穿透、
##    10 秒停留 + 每 50ms 减 0.1 + 到 0.1 整块清空 + 来新条重新计时。
##  * **接线腿**：HUD 必须真把这层挂上并把信号接到 `加一条`；后端必须在四个 producer 位置各留一处。
##
## 跑法：`Godot --path . --headless --script res://测试/获得提示回归测试.gd`
## 全程只建控件 + 直调解析器 ⇒ 不碰 `user://`（末了按字节比对存档，动了就红）。

const 文案 := preload("res://脚本/界面/获得提示文案.gd")
const 层脚本 := preload("res://脚本/界面/获得提示层.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 后端路 := "res://脚本/单例/后端连接.gd"
const HUD路 := "res://脚本/界面/小地图面板.gd"

## ── 本文件自己抄的一份语言包（`en_US$message_properties.as` 行号见 获得提示文案.gd 的表）──
const G_绿 := "#00cc33"
const G_黄 := "#f0dd06"
## 字段号 → 标签（标签后面那个空格**是原文有的**，别当手误删掉）
const G_标签 := {
	13: "生命值上限 ", 14: "查克拉上限 ", 20: "攻击速度 ", 21: "移动速度 ", 22: "精华 ",
	25: "经验 ", 27: "金币 ", 28: "绑定金币 ", 30: "点券 ", 33: "罪恶值 ",
}
## 只飘字、不进这一列（HP/MP/ATK/DEF/BSK/AVD）
const G_只飘字 := [6, 7, 16, 17, 18, 19]
## 协议里存在、但原版这列根本不出（LEVEL/JOB/AP/SP/FAME/兽栏容量…）
const G_不列表 := [1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 15, 23, 24, 26, 29, 31, 32, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43]
const G_恒正 := [25]
const G_初窗 := 5000			# DataCenter.as:2285 写死的 5000ms
const G_停留 := 10.0			# NoticePnl.as:25 TIME_SHOW
const G_淡出步 := 0.1			# :117
const G_淡出帧 := 0.05			# :116 delay=50
const G_最大行 := 8			# :19 MAX_LINES
const G_面板宽 := 250.0			# :35/:47
const G_行距 := 5.0			# :77
const G_上距 := 125.0			# :36 y = STAGE_HEIGHT - 125
const G_屏 := Vector2(960, 560)
const G_单行高 := 15.0			# 本工程 12px 单行口径（行高 + 行距 = 20 一层）
const 物品甲 := "03000001"		# 拉面（小）
const 物品乙 := "04000001"		# 牛奶（小）

var 总 := 0
var 红 := 0
var 日志: Array[String] = []
var 收: Array[String] = []


func _记(过: bool, 说: String) -> void:
	总 += 1
	if not 过:
		红 += 1
		日志.append("  !! " + 说)
	else:
		日志.append("  √ " + 说)


func _同(实, 期, 说: String) -> void:
	var 过 := false
	if (实 is float or 实 is int) and (期 is float or 期 is int):
		过 = absf(float(实) - float(期)) < 0.0001
	else:
		过 = str(实) == str(期)
	_记(过, "%s：实得 %s，期望 %s" % [说, str(实), str(期)])


## 按原版形状拼一行期望值：`[color=绿]标签 [color=黄]值[/color][/color]`
func G_行(标签: String, 值: String) -> String:
	return "[color=%s]%s[color=%s]%s[/color][/color]" % [G_绿, 标签, G_黄, 值]


## 取收到的第 i 条文案。取不到时返回一个**必然不相等**的标记串：
## 这样"少了一条"是让那一条自己变红，而不是把整段判据一起跳过 —— 断言总数必须恒定，
## 否则变异实测里「总数没变才算门没被绕过」那条判据就废了（本轮实测到的口径）。
func _取(i: int) -> String:
	return 收[i] if i >= 0 and i < 收.size() else "<没收到第%d条（共 %d 条）>" % [i + 1, 收.size()]


func _文(子们: Array, i: int) -> String:
	if i < 0 or i >= 子们.size():
		return "<没有第%d行>" % (i + 1)
	return (子们[i] as RichTextLabel).text


func _顶(子们: Array, i: int) -> float:
	if i < 0 or i >= 子们.size():
		return 9999.0
	return (子们[i] as Control).position.y


func _底(子们: Array, i: int) -> float:
	if i < 0 or i >= 子们.size():
		return 9999.0
	var 子 := 子们[i] as Control
	return 子.position.y + 子.size.y


func _存档文本() -> String:
	if not FileAccess.file_exists("user://玩家数据.json"):
		return "<无文件>"
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "<打不开>" if f == null else f.get_as_text()


func _读码(p: String) -> String:
	var f := FileAccess.open(p, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	## ⚠ 无头必须钉视口尺寸：这层的摆位按视口算，不钉量到的是默认 64 宽（同 小地图标记门:89-91）
	root.size = Vector2i(int(G_屏.x), int(G_屏.y))
	var 存档前 := _存档文本()
	var 后端 = root.get_node_or_null("/root/BackendConnection")
	_记(后端 != null, "拿得到 /root/BackendConnection（差值引擎在它身上，拿不到后面全红是对的）")
	_记(层脚本 != null and 文案 != null, "获得提示层 / 获得提示文案 能 load（parse 炸在这里就会红，不会静默零覆盖）")
	_文案腿()
	if 后端 != null:
		_差值腿(后端)
		_背包腿(后端)
		_断线腿(后端)
	await _版面腿()
	if 后端 != null:
		await _接线实证腿(后端)
	_接线腿()
	var 存档后 := _存档文本()
	_记(存档前 == 存档后, "离线门不许写存档：user://玩家数据.json")
	_尾()


## ── 文案腿：模板 + 「该不出的一条都不许出」──────────────────────────────
func _文案腿() -> void:
	for 号 in G_标签:
		var 标 := String(G_标签[号])
		_同(文案.属性(int(号), 7), G_行(标, "+7"), "字段 %d 正差" % int(号))
		if G_恒正.has(int(号)):
			## 经验：`DataCenter.as:2434` 的 `if(_loc4_ > 0)` —— 变少**不提示**（不是提示 -N）
			_同(文案.属性(int(号), -7), "", "字段 %d 负差（原版判掉）" % int(号))
			_同(文案.属性(int(号), 0), "", "字段 %d 差 0" % int(号))
		else:
			_同(文案.属性(int(号), -7), G_行(标, "-7"), "字段 %d 负差自带减号" % int(号))
			_同(文案.属性(int(号), 0), "", "字段 %d 差 0" % int(号))
	for 号 in G_只飘字:
		_同(文案.属性(int(号), 100), "", "字段 %d（HP/MP/攻/防/暴/闪）只飘字，不进这列" % int(号))
		_记(not 文案.会提示(int(号)), "字段 %d 连基准都不该存" % int(号))
	for 号 in G_不列表:
		_同(文案.属性(int(号), 100), "", "字段 %d 原版这列根本不出" % int(号))
	_记(文案.会提示(25) and 文案.会提示(27) and 文案.会提示(28) and 文案.会提示(33),
		"经验/金币/绑定金币/罪恶值 四个都在提示表里（28、33 服务端确实发，见 fake_flash_server.py:17705-17707）")
	_同(文案.元宝(8), G_行("元宝 ", "+8"), "元宝 +8")
	_同(文案.元宝(-8), G_行("元宝 ", "-8"), "元宝 -8")
	_同(文案.元宝(0), "", "元宝差 0 不提示")
	_同(文案.道具获得(3, "拉面（小）"),
		"[color=%s]获得了[color=%s]3[/color]个[color=%s]拉面（小）[/color][/color]" % [G_绿, G_黄, G_黄],
		"获得了 3 个（原文这里**没有空格**）")
	_同(文案.道具失去(4, "牛奶（小）"),
		"[color=%s]失去了[color=%s]4[/color]个[color=%s]牛奶（小）[/color][/color]" % [G_绿, G_黄, G_黄],
		"失去了 4 个")
	_同(文案.带符号(5), "+5", "带符号 正")
	_同(文案.带符号(-5), "-5", "带符号 负")
	_同(文案.带符号(5, true), "+5", "带符号 恒正档")
	_同(文案.填(G_行("金币 ", "%1"), "+3"), G_行("金币 ", "+3"), "占位符 %1 替换（CN.replaceString:5392-5404）")
	## 表里每一档的色，必须是语言包那两档，不许自造
	for 号 in G_标签:
		var 文 := 文案.属性(int(号), 1)
		_记(文.begins_with("[color=" + G_绿 + "]") and G_黄 in 文,
			"字段 %d 的两档色还是 #00cc33 / #f0dd06" % int(号))


## ── 差值腿：喂真文本帧走 _handle_stats_text ──────────────────────────────
func _复位(后端) -> void:
	## 每一段测完把三件状态清干净，免得上一段的基准值串到下一段（那是假绿的老路）
	(后端.get("_提示旧值") as Dictionary).clear()
	后端.set("_首帧属性毫秒", 0)
	后端.set("_初更新", true)
	收.clear()


func _喂属性(后端, 串: String) -> void:
	后端.call("_handle_stats_text", PackedStringArray(["38", 串]))


func _差值腿(后端) -> void:
	if not 后端.has_signal("获得提示"):
		_记(false, "后端连接 没声明 `获得提示` 信号 ⇒ 这一列根本没数据源")
		return
	后端.connect("获得提示", func(t: String) -> void: 收.append(t))
	_复位(后端)
	_记(bool(后端.get("_初更新")), "复位后 _初更新 = true（原版 isInitUpdate 默认 true，DataCenter.as:144）")

	_喂属性(后端, "25&100@27&5000@22&30@13&500@20&5@6&120")
	_记(收.size() == 0, "进游戏第一帧一条都不提示（初始化期）；实得 %d 条：%s" % [收.size(), str(收)])
	var 旧: Dictionary = 后端.get("_提示旧值")
	_记(旧.has("25") and 旧.has("27") and 旧.has("13") and 旧.has("20"),
		"初始化期**照样要把基准值打好**（少打一条，5 秒后第一帧就没得比）；实得键 %s" % str(旧.keys()))
	## HP 这一档**不进右下角那一列**（`:2447-2469` 那个 case 里没有 `addNotice`），
	## 但**基准必须存** —— 头顶那一档减的就是它（`:2453` `_loc13_ = param1.value - this.stats.hp`，
	## 而 `:2465` 那句赋值在 `isInitUpdate` 判断之外）。
	## ⚠ 这一条原来写的是"连基准都不存（存了就是自造）"—— 那是**只有右下角一列时**的口径；
	##   10-14 把头顶那一族的生产者接上之后，两处共用同一份基准，判据随之改成
	##   "存基准、但不出这一列的行"（不出行由下面 `只飘字字段` 那组反向对照钉着）。
	_记(旧.has("6"), "HP 要存基准（头顶那一档 `:2453` 减的就是它）；实得键 %s" % str(旧.keys()))
	_记(not 旧.has("5"), "职业(5) 两处都不出 ⇒ 连基准都不该存（存了就是自造）；实得键 %s" % str(旧.keys()))

	## 边界：原版是 `getTimer() - firstInitTime > 5000`（`DataCenter.as:2285`），而且**翻牌在
	## 算差值之前**（`updatePlayerStats:2278-2292` 先维护标记、再逐条 updateOneStatu）⇒
	## 过 5 秒的那一帧既翻牌、又把这一帧的差值报出来。两头都要有基准值垫着，
	## 否则"没提示"到底是压住了还是没得比，分不清（这就是假绿的老路）。
	_复位(后端)
	后端.set("_首帧属性毫秒", Time.get_ticks_msec() - 4800)
	后端.set("_初更新", true)
	(后端.get("_提示旧值") as Dictionary)["27"] = 1000
	_喂属性(后端, "27&1100")
	_记(bool(后端.get("_初更新")), "距起点不到 5 秒 ⇒ 初始化期还没翻牌")
	_记(收.size() == 0, "没翻牌时**有基准、有差值**也照样压住（金币 +100 不该冒出来）；实得 %d 条" % 收.size())

	_复位(后端)
	后端.set("_首帧属性毫秒", Time.get_ticks_msec() - 5200)
	后端.set("_初更新", true)
	(后端.get("_提示旧值") as Dictionary)["27"] = 1000
	_喂属性(后端, "27&1100")
	_记(not bool(后端.get("_初更新")), "过了 5 秒 ⇒ 就在这一帧翻牌（不是等下一帧）")
	_同(收.size(), 1, "翻牌那一帧同时把差值报出来")
	_同(_取(0), G_行("金币 ", "+100"), "金币 +100")

	_复位(后端)
	后端.set("_首帧属性毫秒", Time.get_ticks_msec() - (G_初窗 + 1))
	后端.set("_初更新", true)
	## 基准值先垫好（上一帧的那套数）—— 不垫的话"没提示"到底是压住了还是没得比，分不出来
	var 垫: Dictionary = 后端.get("_提示旧值")
	垫["25"] = 100.0
	垫["27"] = 5000.0
	垫["22"] = 30.0
	垫["13"] = 500.0
	垫["20"] = 5.0
	垫["6"] = 120.0
	_喂属性(后端, "25&260@27&5400@22&28@13&480@20&4@6&140")
	_同(收.size(), 5, "过了 5 秒的那一帧：经验/金币/精华/生命上限/攻速 各一条（HP 那条不该在里面）")
	_同(_取(0), G_行("经验 ", "+160"), "经验差 = 新 − 旧")
	_同(_取(1), G_行("金币 ", "+400"), "金币 +400")
	_同(_取(2), G_行("精华 ", "-2"), "精华 -2")
	_同(_取(3), G_行("生命值上限 ", "-20"), "生命上限 -20")
	_同(_取(4), G_行("攻击速度 ", "-1"), "攻速 -1")

	_喂属性(后端, "25&260@27&5400")
	_记(收.size() == 5, "同值再喂一帧 ⇒ 差 0，一条都不加；实得 %d 条" % 收.size())

	收.clear()
	_喂属性(后端, "25&200@27&5300")
	_同(收.size(), 1, "经验变少**不提示**、金币变少提示 ⇒ 只 1 条")
	_同(_取(0), G_行("金币 ", "-100"), "金币 -100")

	## 28 绑定金币 / 33 罪恶值：名字表没建模，但这列要出（差值引擎按字段号判，跟会话建模解耦）
	_复位(后端)
	后端.set("_首帧属性毫秒", Time.get_ticks_msec() - (G_初窗 + 1))
	后端.set("_初更新", false)
	_喂属性(后端, "28&1200@33&5")
	_喂属性(后端, "28&1000@33&0")
	_同(收.size(), 2, "绑定金币与罪恶值各一条（第一帧只打基准，第二帧才报差）")
	_同(_取(0), G_行("绑定金币 ", "-200"), "绑定金币 -200")
	_同(_取(1), G_行("罪恶值 ", "-5"), "罪恶值 -5")

	## 元宝：`Client.onCashMoneyInfo:9062-9070`
	_复位(后端)
	后端.set("_初更新", false)
	后端.call("_报元宝提示", 12)
	_记(收.size() == 0, "元宝第一帧只打基准不提示；实得 %d 条" % 收.size())
	后端.call("_报元宝提示", 20)
	_同(收.size(), 1, "元宝 12 → 20 出一条")
	_同(_取(0), G_行("元宝 ", "+8"), "元宝 +8")
	_复位(后端)
	后端.call("_报元宝提示", 30)
	_记(收.size() == 0, "还在初始化期（没来过属性帧）⇒ 元宝也不提示；实得 %d 条" % 收.size())


## ── 背包腿：ADD / UPDATE / CLEAR / DROP 四支 ────────────────────────────
func _喂背包(后端, 段: Array) -> void:
	后端.call("_handle_inventory_change", PackedStringArray(Array(段)))


func _体(号: String, 格: int, 数: int, 可交: int) -> String:
	## `_parse_item_entry` 的段序：type&id&slot&quantity&price&0&canTrade&owner&0&uniqueId
	return "2&%s&%d&%d&0&0&%d&测试&0&1234" % [号, 格, 数, 可交]


func _背包腿(后端) -> void:
	_复位(后端)
	(后端.get("authoritative_inventory") as Array).clear()

	_喂背包(后端, ["1073", "0", _体(物品甲, 5, 3, 1), "0", "1", "5"])
	_同(收.size(), 1, "ADD（fromDrop=0，背包格 5）出一条")
	_同(_取(0), 文案.道具获得(3, "拉面（小）"), "获得了 3 个拉面（小）")

	收.clear()
	_喂背包(后端, ["1073", "0", _体(物品乙, 6, 2, 1), "2", "1", "6"])
	_记(收.size() == 0, "ADD 且 fromDrop=2（进游戏那份整包）不提示；实得 %d 条：%s" % [收.size(), str(收)])

	收.clear()
	_喂背包(后端, ["1073", "0", "1&01010011&-1&1&0&0&1&测试&0&9", "0", "0", "-1"])
	_记(收.size() == 0, "ADD 到装备槽（slotId<0）不提示（原版 `:571` 的 slotId > 0）；实得 %d 条" % 收.size())

	## UPDATE：数量 3 → 5，同时把 can_trade 打到第 7 段（第 6 段是 common）
	收.clear()
	_喂背包(后端, ["1073", "1", "0", 物品甲, "5", "5", "1", "0"])
	_同(收.size(), 1, "UPDATE +2 出一条")
	_同(_取(0), 文案.道具获得(2, "拉面（小）"), "获得了 2 个（差 = 新 − 旧，不是新数量）")
	var 格五: Dictionary = 后端.call("_item_at_slot", 5)
	_同(int(格五.get("quantity", -1)), 5, "UPDATE 之后格 5 的数量")
	_记(格五.has("can_trade"), "UPDATE 之后 can_trade 有值（不许静默丢）")
	_同(str(格五.get("can_trade", null)), "false", "can_trade 取**第 7 段**（第 6 段是 common，读错位就永远显示未绑定）")
	_同(str(格五.get("common", null)), "true", "common 取第 6 段")

	收.clear()
	_喂背包(后端, ["1073", "1", "0", 物品甲, "5", "1", "1", "1"])
	_同(收.size(), 1, "UPDATE -4 出一条")
	_同(_取(0), 文案.道具失去(4, "拉面（小）"), "失去了 4 个")

	收.clear()
	_喂背包(后端, ["1073", "1", "0", 物品甲, "5", "1", "1", "1"])
	_记(收.size() == 0, "UPDATE 差 0 不提示；实得 %d 条" % 收.size())

	收.clear()
	_喂背包(后端, ["1073", "1", "2", 物品甲, "5", "9", "1", "1"])
	_记(收.size() == 0, "UPDATE 且 fromDrop=2 不提示；实得 %d 条" % 收.size())

	## 同一格换了别的物品：名字取**新** id，差值仍按旧堆数量算（`ItemManager.as:419-431` 就这样）
	收.clear()
	_喂背包(后端, ["1073", "1", "0", 物品乙, "5", "2", "1", "1"])
	_同(收.size(), 1, "格 5 换成别的物品也出一条")
	_同(_取(0), 文案.道具失去(7, "牛奶（小）"), "名字用新 id（牛奶），数量差照旧堆（新 2 − 旧 9 = −7）")

	## CLEAR（flag 5）与 DROP（flag 7）：整堆失去，**没有** fromDrop 判断
	收.clear()
	_喂背包(后端, ["1073", "5", "false", "1", "5"])
	_同(收.size(), 1, "CLEAR 出一条整堆失去")
	_同(_取(0), 文案.道具失去(2, "牛奶（小）"), "失去了 2 个（整堆数量）")
	收.clear()
	_喂背包(后端, ["1073", "7", "6"])
	_同(收.size(), 1, "DROP 出一条整堆失去")
	_同(_取(0), 文案.道具失去(2, "牛奶（小）"), "失去了 2 个")
	收.clear()
	_喂背包(后端, ["1073", "5", "false", "1", "40"])
	_记(收.size() == 0, "空格子上 CLEAR 不提示（原版 `if(_loc2_)`）；实得 %d 条" % 收.size())

	## MOVE / MERGE 那几支（flag 2/3/4）**不产生**提示 —— 少钉这条，把移动算成"失去了"就会红
	(后端.get("authoritative_inventory") as Array).clear()
	_喂背包(后端, ["1073", "0", _体(物品甲, 7, 4, 1), "0", "1", "7"])
	收.clear()
	_喂背包(后端, ["1073", "3", "7", "8", "4"])
	_记(收.size() == 0, "MOVE_AND_MERGE 不提示；实得 %d 条：%s" % [收.size(), str(收)])
	(后端.get("authoritative_inventory") as Array).clear()


## ── 断线腿：一局的状态必须跟着复位 ──────────────────────────────────────
func _断线腿(后端) -> void:
	_复位(后端)
	后端.set("_首帧属性毫秒", Time.get_ticks_msec() - (G_初窗 + 1))
	后端.set("_初更新", false)
	_喂属性(后端, "27&5000")
	_喂属性(后端, "27&4000")
	_记(收.size() == 1, "断线前先造一个已经翻牌的态（金币 -1000 已报出）；实得 %d 条" % 收.size())
	后端.call("disconnect_backend")
	var 旧: Dictionary = 后端.get("_提示旧值")
	_记(旧.is_empty(), "断线把差值基准一起清了（不清 ⇒ 重连后第一帧报「金币 -3000」这种假账）；实剩 %d 键" % 旧.size())
	_记(bool(后端.get("_初更新")), "断线把初始化期复位成 true")
	_同(int(后端.get("_首帧属性毫秒")), 0, "断线把起点复位成 0（0 = 这局还没来过属性帧）")
	收.clear()
	_喂属性(后端, "27&9000")
	_记(收.size() == 0, "重连后第一帧不提示；实得 %d 条" % 收.size())


## ── 版面腿：画的那一块 ──────────────────────────────────────────────────
## ⚠ 这一腿必须** await 到下一帧**再量行高：`fit_content` 的 RichTextLabel 高度是
##   布局跑完才算得出，当帧量到的是 0 —— 拿 0 去比"高 15"等于没判。
func _版面腿() -> void:
	var 层: Control = 层脚本.new()
	root.add_child(层)
	await _等两帧()
	_同(str(层.position), str(Vector2(G_屏.x - G_面板宽, G_屏.y - G_上距)),
		"_ready 里自己按视口摆到 (W−250, H−125)（NoticePnl.as:35-36）")
	_同(层.mouse_filter, Control.MOUSE_FILTER_IGNORE, "整块鼠标穿透（:30-31 mouseEnabled=false）")

	层.call("加一条", G_行("经验 ", "+100"))
	await _等两帧()		# 行高要等布局跑完，当帧量到 0 ⇒ 后面三条全是白判
	_同(层.call("行数"), 1, "一条进来 ⇒ 1 行")
	var 一: RichTextLabel = 层.get_child(层.get_child_count() - 1) as RichTextLabel
	_记(一 != null, "行是 RichTextLabel（拿不到 ⇒ 后面全红是对的）")
	if 一 == null:
		return
	_同(一.size.x, G_面板宽, "行宽 250（tf.width = 250，:47）")
	_同(一.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "右对齐（autoSize = RIGHT，:48）")
	_同(一.mouse_filter, Control.MOUSE_FILTER_IGNORE, "行也不挡鼠标")
	_记(一.bbcode_enabled and not 一.scroll_active, "BBCode 开着 + 不许出滚动条")
	_同(一.get_theme_constant("outline_size"), 皮肤表.文字规则_描边数值, "描边宽度走皮肤表（对应原版 GlowFilter）")
	_同(str(一.get_theme_color("font_outline_color")), str(皮肤表.文字规则_描边色), "描边色走皮肤表")
	_同(一.size.y, G_单行高, "单行高 15（12px + 本工程行距口径 leading+2）")
	_同(一.position.y + 一.size.y, 0.0, "最新那行的**底边贴在锚点**（doLayout:74 y = 累计 − 文本高）")

	## 冲到 10 条：只留 8 行，摘的必须是最旧那两条（`shift()`，`:103-106`）
	层.call("清空")
	for i in 10:
		层.call("加一条", G_行("金币 ", "第%d行" % (i + 1)))
	await _等两帧()		# 摘行 + 重排都要等布局，当帧量到的是上一帧的位置
	_同(层.call("行数"), G_最大行, "第 9 条进来 ⇒ 摘掉最旧那行，恒不超过 MAX_LINES")
	_同((层.get("历史") as Array).size(), 11,
		"历史数组一条都留（原版 selectInfoWindowCharInfoData 全存，`清空` 只清屏不清历史）：本腿共 1 + 10 条")
	var 子们: Array[Control] = []
	for 子 in 层.get_children():
		if 子 is RichTextLabel:
			子们.append(子 as Control)
	_同(子们.size(), G_最大行, "树里也只剩 8 个行节点（摘掉的必须真从树上下来）")
	## ⚠ 这一组的断言条数**不随行数变**（拿 `_文/_顶/_底` 兜住下标）：写成 `if 行数对: 判 5 条
	##   else: 判 1 条` 的话，任何让行数变掉的变异都会顺带把总数改掉，
	##   而"总数不变 ⇒ 门没被绕过、是真被判红"那条判据就废了（本轮变异实测逮到的口径）。
	_记(_文(子们, 0).contains("第3行"), "最旧那两条被摘 ⇒ 树上第一行是「第3行」；实为 %s" % _文(子们, 0))
	_记(not _文(子们, 子们.size() - 1).contains("第1行"),
		"留在屏上的是最新 8 条而不是最旧 8 条；末行实为 %s" % _文(子们, 子们.size() - 1))
	_同(_底(子们, 子们.size() - 1), 0.0, "最新那行的底边仍贴锚点（doLayout:74 y = 累计 − 文本高）")
	_同(_底(子们, 子们.size() - 2) + G_行距, _顶(子们, 子们.size() - 1),
		"相邻两行的净间距 = 5（上一条底 → 下一条顶，:77 累计 = y − 5）")
	_记(_顶(子们, 0) < _顶(子们, 1), "越旧的排越上（整列向上长）")

	## 折行：原版 multiline + wordWrap，长文案会占两层
	层.call("清空")
	var 长 := G_行("获得了", "01234567890123456789012345678901234567890123456789012345678901234567890123456789")
	层.call("加一条", 长)
	await _等两帧()
	var 折: RichTextLabel = 层.get_child(层.get_child_count() - 1) as RichTextLabel
	_记(折 != null and 折.size.y > G_单行高 + 0.5, "超过 250 宽要折行（原版 wordWrap=true）；实高 %s"
		% str(折.size if 折 != null else Vector2.ZERO))

	## 计时：停 10 秒（那一拍 alpha 仍是 1）⇒ 之后每 50ms 减 0.1 ⇒ 到 0.1 整块清空
	层.call("清空")
	层.call("加一条", G_行("经验 ", "+1"))
	await _等两帧()
	for i in 20:
		层.call("_process", 0.5)
	_同(层.modulate.a, 1.0, "刚满 10 秒那一拍 alpha 还是 1（原版 count==TIME_SHOW 算出来就是 1.0）")
	_同(层.call("行数"), 1, "停留期一行都不掉")
	var 步 := 0
	var 序: Array[String] = []
	while 层.call("行数") > 0 and 步 < 40:
		层.call("_process", G_淡出帧)
		步 += 1
		if 层.call("行数") > 0:
			序.append("%.1f" % 层.modulate.a)
	## 判据写成"整串相等"而不是"每步各记一条"：这样总条数不随运行时长短变（跨轮比数才对得上）
	_同(序, ["0.9", "0.8", "0.7", "0.6", "0.5", "0.4", "0.3", "0.2"],
		"淡出一档一档减：每 50ms −0.1，alpha 序列就这 8 档（原版 :116-117）")
	_同(步, 9, "从 1.0 走到「≤0.1 就整块清」正好 9 拍 × 50ms（`:123` 那一判）")
	_同(层.call("行数"), 0, "到 alpha ≤ 0.1 时**整块清空**（:123-137，不是逐行各自消失）")
	_同(层.modulate.a, 1.0, "清空后 alpha 复位（下次来一条是干净的一块）")

	## 来一条新的 ⇒ 计时重新拉起
	层.call("加一条", G_行("金币 ", "+1"))
	for i in 20:
		层.call("_process", 0.5)
	层.call("加一条", G_行("金币 ", "+2"))
	_同(层.modulate.a, 1.0, "每来一条把整块寿命重置（:89-91 timer.reset + alpha=1）")
	_同(层.call("行数"), 2, "淡出前那两条还在（原版是一列一起活、一起淡）")
	层.call("清空")
	_同(层.call("行数"), 0, "清空() 之后没行")
	层.queue_free()


## 等两帧：fit_content 的行高要等布局跑完才准
func _等两帧() -> void:
	await process_frame
	await process_frame


## ── 接线实证腿：把 HUD 真 instantiate 出来，从后端发一条，看那一列有没有多一行 ──
## 源码钉只能证明"字面上接了"；这一条证明**运行期真接上了**（变异把 `has_signal` 改掉、
## 或把 add_child 漏掉，源码钉不一定抓得到，这一条一定抓）。
func _接线实证腿(后端) -> void:
	var 包 = load("res://场景/界面/小地图面板.tscn")
	_记(包 != null, "HUD 场景能 load（拿不到 ⇒ 下面四条只能记红）")
	if 包 == null:
		_记(false, "HUD 上没建出获得提示层")
		_记(false, "后端发一条后 HUD 那列没多一行")
		_记(false, "HUD 上那一层不挡鼠标")
		_记(false, "HUD 释放时那一层跟着走（不留孤儿子树）")
		return
	var HUD = (包 as PackedScene).instantiate()
	root.add_child(HUD)
	await _等两帧()
	var 层 = HUD.get_node_or_null("获得提示层")
	_记(层 != null, "HUD 一进场就把「获得提示层」挂在自己底下（原版这块挂在 API.ui.content 上）")
	_记(层 == null or (层 as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"HUD 上那一层不挡鼠标（原版 mouseEnabled=false）")
	var 前 := 0 if 层 == null else int(层.call("行数"))
	后端.emit_signal("获得提示", G_行("经验 ", "+7"))
	await _等两帧()
	_记(层 != null and int(层.call("行数")) == 前 + 1,
		"后端发一条 ⇒ 屏幕上那一列真多一行（不是只写在源码里）；实得 %d 行（起 %d）"
		% [0 if 层 == null else int(层.call("行数")), 前])
	HUD.queue_free()
	await _等两帧()
	_记(not is_instance_valid(HUD), "HUD 释放后这一支整棵走掉（换图不留在树上 ⇒ 不重复挂一层）")


## ── 接线腿：两处 producer + HUD 挂载，钉源码形状 ─────────────────────────
func _接线腿() -> void:
	var 后码 := _读码(后端路)
	var HUD码 := _读码(HUD路)
	_记(后码.length() > 0 and HUD码.length() > 0, "两份源码读得到（读不到 ⇒ 这一腿整条白判）")
	有(后码, "signal 获得提示(文本: String)", "后端声明了 `获得提示` 信号")
	有(后码, "const 获得提示文案 := preload(\"res://脚本/界面/获得提示文案.gd\")", "后端 preload 文案层")
	有(后码, "_记属性帧()", "属性帧每来一帧先维护初始化期")
	有(后码, "_报属性提示(field_id, float(pair[1]))", "属性提示按**字段号**判，在名字表过滤之前")
	有(后码, "获得提示文案.道具获得", "道具获得 producer 在")
	有(后码, "获得提示文案.道具失去", "道具失去 producer 在")
	有(后码, "获得提示文案.元宝", "元宝 producer 在")
	无(后码, "获得提示.emit(获得提示文案.属性(", "属性那条不许直接把文案 emit 出去（经验变少会挂出一行空行）")
	## UPDATE 那支的段号：can_trade 第 7、common 第 6、from_drop 第 2
	有(后码, "updated[\"can_trade\"] = fields.size() < 8 or int(fields[7]) == 1", "UPDATE 的 can_trade 读第 7 段")
	无(后码, "updated[\"can_trade\"] = fields.size() < 7", "UPDATE 的 can_trade 不许读回第 6 段（那是 common）")
	有(后码, "int(fields[2]) != 2 and 差 != 0", "UPDATE 判 fromDrop=2 与差 0")
	有(后码, "落位 > 0 and int(fields[3]) != 2", "ADD 判 slotId>0 与 fromDrop=2")
	有(后码, "_提示旧值.clear()", "断线复位基准值")
	有(后码, "_初更新 = true", "断线复位初始化期")
	## HUD：必须真把这层挂上并接信号
	有(HUD码, "获得提示层.new()", "HUD 建了获得提示层")
	有(HUD码, 'if _backend.has_signal("获得提示"):', "HUD 先判信号存在再接（跨版本不静默断链）")
	有(HUD码, 'connect("获得提示", _于获得提示)', "HUD 用通用写法接上信号")
	无(HUD码, "_backend.获得提示.connect", "不许写 `_backend.获得提示.connect`（Node 型拿不到信号名 ⇒ parse 炸）")
	有(HUD码, "加一条", "HUD 那头的落点是 加一条")


## 判"含不含"之前**先把注释行剥掉**：本工程的注释正写着这些反例（比如"不许读回第 6 段"），
## 不剥就会假绿 —— 判据反过来红给看才算数（同 提示条本体回归测试._有码 那条教训）。
func 净码(文: String) -> String:
	var 保: Array[String] = []
	for 行 in 文.split("\n"):
		if 行.strip_edges().begins_with("##"):
			continue
		保.append(行)
	return "\n".join(保)


func 有(文: String, 串: String, 说: String) -> void:
	_记(净码(文).contains(串), 说)


func 无(文: String, 串: String, 说: String) -> void:
	_记(not 净码(文).contains(串), 说 + "（这条是反向判据）")


func _尾() -> void:
	日志.append("")
	日志.append("汇：共 %d 条，红 %d 条" % [总, 红])
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)
