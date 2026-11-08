extends SceneTree
## 赠花窗（原版 `MarryZengHuaWindow`，页名「赠花」）离线门（#88 / 原报修 #263）。
## 参照值**逐条抄自 AS3**（`com/mxw/uifl/controls/marry/MarryZengHua{Window,Cell,LogCell}.as`
## + `com/mxw/data/flower/Flower*.as` + `en_US$message_properties.as` + `UIConfig.as`），
## **不从被测场景反查** —— 场景和门一起写错就永远绿。真值表在 `真值/窗口/赠花窗.md`。
##
## 覆盖：① `58:2` 十段逐字段 ② 缺段（整帧 <10 / 记录条目 <8 / 档位条目 <6 / 记录写 `-`）
## ③ 记录**号+名都撞**才算重复（只撞名或只撞号都要留）④ 记录按 sendTime 升序、档位按 youhaodu 升序
## ⑤ `cid == 我` **不开窗**（那一支原版开的是没移植的 `MyFlowerWindow`）、`cid != 我` 由回帧开窗
## ⑥ 逐件矩形（页 16 件 + 记录子件 5 + 花格子件 7）+ 层序（= addChild 原序）+ 九宫格边距现取参照
## ⑦ 文案：档案三行 / 统计那句（含 AS3 那六个空格）/ 说明 / 五条记录 / 玫瑰句 vs 妖姬句 /
##    角标分岔 / 单位分岔 / 购买钮只妖姬那档露 / 加为好友·回赠恒藏 / 换第二任对面整页跟着换人
## ⑧ `_时间` 四档边界 ⑨ 立绘活的、挂 `立绘框`、摆位 (73,173) = `146>>1` 与 `208−35`
## ⑩ 四颗钮三态与手型、档宽 37（`btn_width_two`）⑪ 托盘 `61:44` 两判 + **不去重** + 真点 ⇒ **单钮**弹
## ⑫ 妖姬那句的**两条**判据（花号 == 妖姬 **或** 朵 == 99）⑬ 尺寸表 + 素材在盘上
## ⑭ 键名交叉核对（参照值 = AS3 `Flower*` 的字段名，两边都得对得上）
## ⑮ 段数闸写在源码哪一档（行为上判不出，原因见 ⑮ 注释）⑯ 未判（离线判了就是假绿）
##
## ⚠ 三条量法口径（求婚窗那一族的同族坑，别再踩）：
## 1. 无头 `root.size` **一次设不成** ⇒ 每帧重设直到 `get_visible_rect()` 真等于 960×560，这条本身当判据。
## 2. 托盘那格入场是 **2 秒补间** ⇒ 按墙钟等 + 判 `position.x > 300`，一次只点一格。
## 3. 按下/松开只传**屏幕坐标**：那一格派发时自删，拿节点算松开位会 `previously freed`、松手整个被跳过
##    ⇒ 视口停在"左键还按着"，之后所有悬停/点击都被吞。
##
## 跑法：`godot --path . --headless --script res://测试/赠花窗回归测试.gd`

const 场景路径 := "res://场景/界面/窗口/家族/赠花窗.tscn"
const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 页根名 := "原版赠花内容"
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 赠花脚本 := preload("res://脚本/界面/窗口/家族/赠花窗.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## ── 页内 16 件 ────────────────────────────────────────────────────────────
## 全部由 AS3 算式推出（`整框: true` ⇒ 页局部 y = AS3 y − 29；`_contentBg` = (8,30) 534×375，
## 高那句来自 `drawWindowLayout:228` `_contentBg.height = _height − 40 = 415 − 40`）：
## · 右栏底 `:96-100` 宽 `534−160=374`、高 `375−8−2=365`、x `534−374+2(TEXT_GAP)=162`、y `30+5(BORDER_GAP)=35`
## · 立绘框 `:102-103` x `8+5=13`、y `35`，尺寸 = `CHAR_WIDTH/HEIGHT` 146×208
## · 档案底 `:111-115` 147×70、x 13、y `30+213=243`；档案文字 `:116-119` 147×(70−10)=60、x 15、y `243+5=248`
## · 说明底 `:121-125` 147×85、y `243+70+2=315`；说明文字 `:126-129` 147×(85+10)=95、x 15、y `315+5=320`
## · 收花统计 `:131-135` 364×20、x `162+5=167`、y `35+5=40`
## · 记录_i `:138-145` x `162+16=178`、y `35+32+i*30`（`MarryZengHuaLogCell` 底高 30）
## · 花格 `:147-161` 二×二但 `:151` 把右下角 break 掉 ⇒ 三格；x `162+8+列*180`、y `35+200+行*80`
const 逐件 := {
	"内容底": [8.0, 1.0, 534.0, 375.0],
	"右栏底": [162.0, 6.0, 374.0, 365.0],
	"立绘框": [13.0, 6.0, 146.0, 208.0],
	"档案底": [13.0, 214.0, 147.0, 70.0],
	"档案文字": [15.0, 219.0, 147.0, 60.0],
	"说明底": [13.0, 286.0, 147.0, 85.0],
	"说明文字": [15.0, 291.0, 147.0, 95.0],
	"收花统计": [167.0, 11.0, 364.0, 20.0],
	"记录_0": [178.0, 38.0, 300.0, 30.0],
	"记录_1": [178.0, 68.0, 300.0, 30.0],
	"记录_2": [178.0, 98.0, 300.0, 30.0],
	"记录_3": [178.0, 128.0, 300.0, 30.0],
	"记录_4": [178.0, 158.0, 300.0, 30.0],
	"花格_0": [170.0, 206.0, 180.0, 80.0],
	"花格_1": [350.0, 206.0, 180.0, 80.0],
	"花格_2": [170.0, 286.0, 180.0, 80.0],
}
## 层序 = `createChildren()` 的 addChild 原序（`_contentBg` 是 UIWindow 基类先建的 ⇒ 排第一）。
const 层序 := ["内容底", "右栏底", "立绘框", "档案底", "档案文字", "说明底", "说明文字", "收花统计",
		"记录_0", "记录_1", "记录_2", "记录_3", "记录_4", "花格_0", "花格_1", "花格_2"]
## 记录子件（`MarryZengHuaLogCell.as:38-72`）：底 300×30；内容 (5,5)；加为好友 x=202、回赠 x=262
## （两个 y 都取 `_info.y` = 5）；时间 (300+5−2, 5) = (303,5)，宽 = `btn_width_four` 61。
const 记录子件 := {
	"底": [0.0, 0.0, 300.0, 30.0], "内容": [5.0, 5.0, 190.0, 20.0],
	"加为好友": [202.0, 5.0, 60.0, 20.0], "回赠": [262.0, 5.0, 40.0, 20.0],
	"时间": [303.0, 5.0, 61.0, 20.0],
}
const 记录层序 := ["底", "内容", "加为好友", "回赠", "时间"]
## 花格子件（`MarryZengHuaCell.as:42-81`）：底 180×80；物品格 (8,8) 40×40（`CONTENT_GAP`，原生尺寸）；
## 图标 = 物品格 +2 ⇒ (10,10) 36×36；赠送钮 x `8+2=10`、y `8+40+2=50`、宽 `btn_width_two` 37；
## 描述 x `8+40=48`、y `8−4=4`、130×75；角标 x 10、y `8+22=30`、宽 40、右对齐；
## 购买钮 x `0+180−37−20=123`、y 50。
## 层序 = ctor 里 `底→物品格→赠送钮→描述→角标→购买钮`，再由 `updateView:96` 把图标 `addChildAt(..,2)`
## ⇒ 图标正好压在物品格之上、赠送钮之下。
const 花格子件 := {
	"底": [0.0, 0.0, 180.0, 80.0], "物品格": [8.0, 8.0, 40.0, 40.0],
	"图标": [10.0, 10.0, 36.0, 36.0], "赠送钮": [10.0, 50.0, 37.0, 22.0],
	"描述": [48.0, 4.0, 130.0, 75.0], "角标": [10.0, 30.0, 40.0, 20.0],
	"购买钮": [123.0, 50.0, 37.0, 22.0],
}
const 花格层序 := ["底", "物品格", "图标", "赠送钮", "描述", "角标", "购买钮"]

const 色表 := {
	"收花统计": Color("#fff000"),	# UI_YELLOW 16773120
	"时间": Color("#fff000"),
	"加为好友": Color("#00ff00"),	# UI_GREEN 65280
	"回赠": Color("#00ff00"),
	"角标": Color("#ffffff"),		# `Cell:68` 直接写 16777215
	"钮常态": Color("#fcf49c"), "钮悬停": Color("#ffffc3"), "钮按下": Color("#acadb2"),
}

## ── 帧形状（段序 = 服务端 `_flower_character_info_fields`，与原版 `FlowerCharInfo.decode:44-91` 对上）──
## `58:2:<号>:<脸>:<友好度>:<总朵>:<本周>:<今日次数>:<记录串>:<档位串>`；
## 记录条目 = `名&号&朵&**经过秒**&脸&职&级&花号`，档位条目 = `朵&经验&花费&友好度&type&花号`，
## 条目之间 `@`，空记录服务端写 `-`。
## 三档花的**数值**抄自服务端 `FLOWER_GIFT_OPTIONS:515-519`（1 朵玫瑰 友好 1 花费 1000、
## 20 朵 友好 20 花费 20、99 朵蓝妖姬 友好 500 花费 1）；经验那位按等级算，门里给的是**同形状假值**，
## 只判"浮点解出来、整值按整数印"。花号 16000143/16000149 = 服务端 `ROSE_ITEM_ID`/`BLUE_ROSE_ITEM_ID`，
## 与 `数据/原版杂项.json` 的 `flower.itemid`/`flower.rosebuleid` 同一个值。
const 记录串 := "求花丙&2003&99&90000&10000206&3&50&16000149" \
		+ "@求花甲&2001&20&30&10000204&2&30&16000143" \
		+ "@求花乙&2002&1&3600&10000205&1&44&16000143"
const 档位串 := "99&0&1&500&0&16000149@1&5040&1000&1&0&16000143@20&151200&20&20&0&16000143"
const 主帧 := "58:2:2002:10000205:137:60:21:2:" + 记录串 + ":" + 档位串
## 只有 `cid` 换成我 ⇒ 那一支原版开的是 `MyFlowerWindow`（本工程没移植，**不许顶替**）。
const 我帧 := "58:2:2001:10000204:137:60:21:2:" + 记录串 + ":" + 档位串
## 换第二任对面（号 2003）⇒ 整页都得跟着换人。
const 丙帧 := "58:2:2003:10000206:88:5:5:1:" + 记录串 + ":" + 档位串
## 五条里第一条与第二条**号+名都撞** ⇒ 第二条丢；第三条只撞名、第四条只撞号 ⇒ 都得留。
const 重复帧 := "58:2:2002:10000205:137:60:21:2:" \
		+ "求花甲&2001&20&30&10000204&2&30&16000143" \
		+ "@求花甲&2001&99&45&10000204&2&30&16000143" \
		+ "@求花甲&2099&5&75&10000204&2&30&16000143" \
		+ "@求花丁&2001&6&80&10000204&2&30&16000143:" + 档位串
## 记录条目只七段（缺花号）⇒ 那一条整条跳过；档位条目只五段（缺花号）⇒ 同理。
const 坏记录帧 := "58:2:2002:10000205:137:60:21:2:坏条目&2001&20&30&10000204&2&30@" + 记录串 \
		+ ":1&5040&1000&1&0@20&151200&20&20&0&16000143"
## 服务端空记录写的是 `-`（`logs or "-"`）⇒ 十条齐全、零条记录，**不是**丢帧。
const 空记录帧 := "58:2:2002:10000205:137:60:21:2:-:" + 档位串
## `61:44:<发号>:<收号>:<发名>:<朵>:<花号>` = 服务端 `_send_flower_gift` 末尾那份 payload，
## **两边各发一份** ⇒ 收端必须两判都过才塞格。
const 我收 := "61:44:2002:2001:对友乙:20:16000143"
const 我发 := "61:44:2001:2002:我名:20:16000143"
const 路人 := "61:44:2003:2004:路人丁:20:16000143"
const 我收妖姬 := "61:44:2002:2001:对友乙:99:16000149"
const 我号 := 2001
const 对号 := 2002

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 收档: Array = []
var 收花: Array = []
var 提示: Array = []
var _鼠 := Vector2(480.0, 300.0)


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)


func _等几帧(n: int) -> void:
	for i in n:
		await process_frame


func _钉视口() -> void:
	for i in 60:
		if root.get_visible_rect().size != Vector2(960.0, 560.0):
			root.size = Vector2i(960, 560)
			await process_frame
		else:
			break
	await _等几帧(2)
	_判(root.get_visible_rect().size == Vector2(960.0, 560.0),
			"视口钉到 960×560（实得 %s，root.size=%s）—— 钉不住则下面所有真点判据都不算数"
			% [str(root.get_visible_rect().size), str(root.size)])


func _收(后: Node, 原文: String) -> void:
	后.call("_handle_bridge_text", 原文)


func _矩形(件: Control) -> Array:
	return [件.position.x, 件.position.y, 件.size.x, 件.size.y]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


func _色近(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 \
			and absf(a.b - b.b) < 0.004 and absf(a.a - b.a) < 0.004


## 正文一律按**解出来的Plain文本**比：BBCode 那层由 `富文本.译文为BBCode` 折，
## 拿 `.text` 比就得把 `<font>` 标签一起抄进来（那是拿实现当参照值）。
func _白(件: Node) -> String:
	var 文 := 件 as RichTextLabel
	return 文.get_parsed_text() if 文 != null else "‹不是 RichTextLabel›"


func _挪到(点: Vector2) -> void:
	var 中 := (_鼠 + 点) * 0.5
	for 目 in [中, 点]:
		var 移 := InputEventMouseMotion.new()
		移.position = 目
		移.global_position = 目
		移.relative = 目 - _鼠
		root.push_input(移)
		await process_frame
		await process_frame
	_鼠 = 点


func _按下(点: Vector2) -> void:
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 点
	按.global_position = 点
	root.push_input(按)
	await process_frame
	await process_frame


func _松开(点: Vector2) -> void:
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 点
	放.global_position = 点
	root.push_input(放)
	await process_frame
	await process_frame
	await process_frame


func _真点(件: Control) -> void:
	if not is_instance_valid(件):
		return
	var 屏: Vector2 = 件.get_global_rect().get_center()
	await _挪到(屏)
	await _按下(屏)
	await _松开(屏)


func _等落位() -> void:
	var 起 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 起 < 2600:
		await process_frame


func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


func _找页(窗: Node) -> Control:
	if 窗 == null:
		return null
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String((子 as Node).name) == 页根名:
			return 子 as Control
	return null


func _切函数(源: String, 头: String) -> String:
	var 起 := 源.find(头)
	var 止 := 源.find("\nfunc ", 起 + 1)
	if 起 < 0:
		return ""
	return 源.substr(起, 止 - 起) if 止 > 起 else 源.substr(起)


func _早退() -> void:
	跑完了 = true
	print("赠花窗离线门：通过 %d，红 %d" % [通过, 失败])


func _跑() -> void:
	print("赠花窗离线门开始")
	await _钉视口()
	var 后: Node = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("character_id", 我号)
	后.connect("花档收到", func(档: Dictionary) -> void: 收档.append(档))
	后.connect("收花帧收到", func(条: Dictionary) -> void: 收花.append(条))
	## 「赠送/购买」那两条路的"说了什么"是真信号 ⇒ 接 GameSession，不是问被测对象要答案。
	var 会话 := root.get_node_or_null("GameSession")
	_判(会话 != null and 会话.has_signal("notification_requested"),
			"GameSession 上有 notification_requested（号闸那条路靠它说话）")
	if 会话 != null:
		会话.connect("notification_requested", func(话: String) -> void: 提示.append(话))
	await _等几帧(2)

	# ── ① `58:2` 十段逐字段 ───────────────────────────────────────────────
	_收(后, 主帧)
	await _等几帧(2)
	_判(收档.size() == 1, "喂一帧 `58:2:…` ⇒ 一条 花档收到（实得 %d 条）" % 收档.size())
	if 收档.is_empty():
		_早退()
		return
	var 档: Dictionary = 收档[0] as Dictionary
	var 望顶 := {"cid": 2002, "face": 10000205, "youhaodu": 137, "totalFlowers": 60,
			"weeklyFlowers": 21, "count": 2}
	for 键 in 望顶:
		_判(档.has(键) and int(档[键]) == int(望顶[键]),
				"`58:2` 解出来的 `%s` == %s（实得 %s；全字典=%s）" % [键, 望顶[键], 档.get(键, "‹无›"), str(档)])
	## ⚠ 段 5/6/7 在 AS3 里是 `totalFlowers / weeklyFlowers / count`，**服务端返回表同序**；
	## 把"本周"与"总数"并排读最容易看错，这里各钉一位（60 vs 21）。
	_判(int(档.get("totalFlowers", 0)) == 60 and int(档.get("weeklyFlowers", 0)) == 21,
			"总数=60、本周=21 **没有互换**（`FlowerCharInfo.decode` 与统计那句的 %2/%3 就靠这两位）")
	var 记录: Array = 档.get("flowerDayLogInfo", []) as Array
	var 档列: Array = 档.get("flowerInfo", []) as Array
	_判(记录.size() == 3 and 档列.size() == 3, "三条记录 + 三档花（实得 %d / %d）" % [记录.size(), 档列.size()])
	if 记录.size() < 3 or 档列.size() < 3:
		_早退()
		return
	## 升序钉（④）：记录按**经过秒**升序 = 最新那条在前；档位按友好度升序 = 1 朵 → 20 朵 → 99 朵。
	var 望时: Array = [30, 3600, 90000]
	var 望友: Array = [1, 20, 500]
	var 实得时: Array = []
	var 实得友: Array = []
	for 条 in 记录:
		实得时.append(int((条 as Dictionary).get("sendTime", -1)))
	for 条 in 档列:
		实得友.append(int((条 as Dictionary).get("youhaodu", -1)))
	_判(实得时 == 望时, "记录按 sendTime **升序**（帧里故意倒着写）⇒ %s，实得 %s" % [str(望时), str(实得时)])
	_判(实得友 == 望友, "档位按 youhaodu **升序** ⇒ %s，实得 %s（花格按顺位摆，窗里不再排一次）"
			% [str(望友), str(实得友)])
	var 甲: Dictionary = 记录[0] as Dictionary
	var 望录 := {"senderName": "求花甲", "senderId": 2001, "count": 20, "sendTime": 30,
			"face": 10000204, "job": 2, "level": 30, "flowerid": 16000143}
	for 键 in 望录:
		_判(str(甲.get(键, "‹无›")) == str(望录[键]),
				"第一条记录的 `%s` == %s（实得 %s）" % [键, 望录[键], 甲.get(键, "‹无›")])
	var 第一档: Dictionary = 档列[0] as Dictionary
	var 望档 := {"count": 1, "exp": 5040.0, "cost": 1000, "youhaodu": 1, "type": 0, "flowerid": 16000143}
	for 键 in 望档:
		_判(str(第一档.get(键, "‹无›")) == str(望档[键]),
				"第一档的 `%s` == %s（实得 %s）" % [键, 望档[键], 第一档.get(键, "‹无›")])
	_判(第一档.get("exp") is float, "经验那位**必须 float**（帧里是 \"5040\"，`int()` 解会得 5040 "
			+ "但 1234.0 这种就归 0；原版 `FlowerInfo.exp:Number`）")

	# ── ② 缺段 / 坏条目 / `-` 空表 ────────────────────────────────────────
	var 前 := 收档.size()
	for 短 in ["58:2", "58:2:2002", "58:2:2002:10000205:137:60:21",
			"58:2:2002:10000205:137:60:21:2:" + 记录串, "58:2:2002:10000205:137:60:21::"]:
		_收(后, 短)
		await _等几帧(1)
	_判(收档.size() == 前, "九段以内的 `58:2` **一条都不发**（前 %d → 后 %d）" % [前, 收档.size()])
	_收(后, 坏记录帧)
	await _等几帧(2)
	_判(收档.size() == 前 + 1, "七段的记录条目 / 五段的档位条目**各自跳过**、整帧照发（实得 %d 条）" % (收档.size() - 前))
	var 坏: Dictionary = 收档[收档.size() - 1] as Dictionary
	var 坏录: Array = 坏.get("flowerDayLogInfo", []) as Array
	var 坏档: Array = 坏.get("flowerInfo", []) as Array
	_判(坏录.size() == 3, "那条七段记录被丢掉 ⇒ 只剩 3 条（实得 %d）" % 坏录.size())
	_判(坏档.size() == 1, "那条五段档位被丢掉 ⇒ 只剩 1 档（实得 %d）" % 坏档.size())
	_判(int((坏档[0] as Dictionary).get("flowerid", 0)) == 16000143,
			"活下来的那一档是**有花号**的那条（实得 %s）" % str(坏档))
	收档.clear()
	_收(后, 空记录帧)
	await _等几帧(2)
	_判(收档.size() == 1, "`-` 的空记录**照发**（服务端 `logs or \"-\"`，那是「没有一条」而不是坏帧）"
			+ " ⇒ 实得 %d 条" % 收档.size())
	var 空: Dictionary = 收档[0] as Dictionary if 收档.size() == 1 else {}
	_判((空.get("flowerDayLogInfo", []) as Array).is_empty(),
			"`-` 解出来是**空数组**而不是 [\"\"]（实得 %s）" % str(空.get("flowerDayLogInfo", [])))

	# ── ③ 重复条：号**和**名都撞才丢 ──────────────────────────────────────
	收档.clear()
	_收(后, 重复帧)
	await _等几帧(2)
	_判(收档.size() == 1, "重复那一帧照发（实得 %d 条）" % 收档.size())
	var 重档: Dictionary = 收档[0] as Dictionary if 收档.size() == 1 else {}
	var 重录: Array = 重档.get("flowerDayLogInfo", []) as Array
	_判(重录.size() == 3, "五条里丢掉**一条**（号+名都撞）⇒ 3 条（`FlowerCharInfo.checkExist:29-41`），实得 %d"
			% 重录.size())
	var 名串 := ""
	for 条 in 重录:
		名串 += "%s|%d;" % [String((条 as Dictionary).get("senderName", "")), int((条 as Dictionary).get("senderId", 0))]
	_判(名串.contains("求花甲|2001") and not 名串.contains("求花甲|2001;求花甲|2001"),
			"号+名都撞的那第二条**没进**（实得 %s）" % 名串)
	_判(名串.contains("求花甲|2099"), "只**撞名**（号不同）⇒ 要留（判据是「和」不是「或」），实得 %s" % 名串)
	_判(名串.contains("求花丁|2001"), "只**撞号**（名不同）⇒ 也要留，实得 %s" % 名串)
	## 重复的那条**丢的是后来者**（原版不覆盖已有那条），不是"合并成最后一条"。
	_判(int((重录[0] as Dictionary).get("count", 0)) == 20,
			"留下来的那条还是第一份（朵=20），没被第二份（朵=99）覆盖，实得 %s" % str(重录[0]))

	# ── 窗口管理上线：⑤ 之后都真走生产代码 ────────────────────────────────
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	await _等几帧(4)
	var 盘 = 管理.get_node_or_null("邀请托盘")
	_判(盘 != null, "窗口管理底下有「邀请托盘」这一层（实得 %s）" % str(盘))
	if 盘 == null:
		_早退()
		return
	盘.call("清空")
	收档.clear()
	await _等几帧(2)

	# ── ⑤ `cid == 我` 不开窗；`cid != 我` 回帧那一刻开窗 ──────────────────
	管理.call("记赠花对面", {"charId": 对号, "name": "对友乙", "face": 10000205, "level": 44})
	_收(后, 我帧)
	await _等几帧(4)
	var 窗: Node = 管理._窗口们.get("赠花") as Node
	_判(窗 == null or not _开着(窗),
			"回帧的 cid == 我自己 ⇒ **不开赠花窗**（那一支原版开的是没移植的 `MyFlowerWindow`："
			+ "顶过去就是一扇「我给自己送花」的假页）")
	_收(后, 主帧)
	await _等几帧(6)
	窗 = 管理._窗口们.get("赠花") as Node
	_判(窗 != null and _开着(窗), "对面那一帧 ⇒ **回帧到达才开窗**（`receiveRefreshFlowerWindow:338`）")
	var 页 := _找页(窗)
	_判(页 != null, "页本体「%s」建出来了（整窗 550×415、页 550×386 = 415−29）" % 页根名)
	if 页 == null:
		_早退()
		return

	# ── ⑥ 逐件矩形 + 层序 + 九宫格边距 ────────────────────────────────────
	_判(absf(页.size.x - 550.0) < 0.51 and absf(页.size.y - 386.0) < 0.51,
			"页 = 550×386，实得 %.0f×%.0f" % [页.size.x, 页.size.y])
	for 名 in 逐件:
		var 子 := 页.get_node_or_null(名) as Control
		_判(子 != null, "逐件：%s 在" % 名)
		if 子 == null:
			continue
		_判(_近(_矩形(子), 逐件[名]), "%s 矩形 = (%s)，实得 (%s)" % [名, 逐件[名], _矩形(子)])
	var 实际序: Array = []
	for 子 in 页.get_children():
		实际序.append(String((子 as Node).name))
	_判(实际序 == 层序, "层序 = createChildren 的 addChild 原序，实得 %s" % str(实际序))
	for i in 5:
		var 格 := 页.get_node("记录_%d" % i) as Control
		var 子序: Array = []
		for 子 in 格.get_children():
			子序.append(String((子 as Node).name))
		_判(子序 == 记录层序, "记录_%d 子件层序 = %s，实得 %s" % [i, str(记录层序), str(子序)])
		for 名 in 记录子件:
			var 件 := 格.get_node_or_null(名) as Control
			_判(件 != null and _近(_矩形(件), 记录子件[名]),
					"记录_%d/%s 矩形 = (%s)，实得 (%s)" % [i, 名, 记录子件[名], _矩形(件) if 件 != null else []])
	for i in 3:
		var 格 := 页.get_node("花格_%d" % i) as Control
		var 子序: Array = []
		for 子 in 格.get_children():
			子序.append(String((子 as Node).name))
		_判(子序 == 花格层序, "花格_%d 子件层序 = %s（图标是 `addChildAt(..,2)` 插进来的），实得 %s"
				% [i, str(花格层序), str(子序)])
		for 名 in 花格子件:
			var 件 := 格.get_node_or_null(名) as Control
			_判(件 != null and _近(_矩形(件), 花格子件[名]),
					"花格_%d/%s 矩形 = (%s)，实得 (%s)" % [i, 名, 花格子件[名], _矩形(件) if 件 != null else []])
	## 九宫格件用的是哪张共享皮 —— 边距**现取** `皮肤表.九宫格`（门里不写第二份数）。
	## ⚠ 那张映射写成局部字典：`皮肤表.内容面板` 这类常量放进 const 字典当键值取不到实例
	## （实测报 `Cannot call non-static function "get()"`）。
	var 皮路 := {页.get_node("内容底"): 皮肤表.内容面板, 页.get_node("右栏底"): 皮肤表.子面板,
			页.get_node("档案底"): 皮肤表.子面板, 页.get_node("说明底"): 皮肤表.子面板}
	for i in 5:
		皮路[页.get_node("记录_%d/底" % i)] = 皮肤表.子面板
	for i in 3:
		皮路[页.get_node("花格_%d/底" % i)] = 皮肤表.子面板
		皮路[页.get_node("花格_%d/物品格" % i)] = 皮肤表.物品格
	for 块 in 皮路:
		var 九: NinePatchRect = 块 as NinePatchRect
		var 组: Array = 皮肤表.九宫格[皮路[块]]
		var 期 := [int(组[0]), int(组[1]), int(组[2]), int(组[3])]
		var 实 := [九.patch_margin_left, 九.patch_margin_right, 九.patch_margin_top, 九.patch_margin_bottom]
		_判(实 == 期, ("%s 九宫格边距(左右上下) = %s（现取自 皮肤表.九宫格.%s；写成 texture_margin_* "
				+ "会被静默丢掉 ⇒ 整张皮拉平），实得 %s") % [String((九 as Node).name), str(期),
						String(皮路[块]).get_file(), str(实)])

	# ── ⑦ 文案（逐条比对 AS3 `message_properties`，空格/冒号都算数）────────
	_判(String(窗.get_node("遮罩/主窗口/标题").text) == "赠花",
			"标题 = ZENGHUA_WINDOW_TITLE「赠花」（实得「%s」）" % String(窗.get_node("遮罩/主窗口/标题").text))
	var 档案 := _白(页.get_node("档案文字"))
	_判(档案.contains("角色名：对友乙"), "档案第一行取的是**点菜单那一刻存的对面名**，实得「%s」" % 档案)
	_判(档案.contains("角色等级：44"), "档案第二行 = 对面等级（`MarryZengHuaWindow:184` 读 Manager 不是读帧）")
	_判(档案.contains("友好度：137"), "档案第三行 = **回帧里的** youhaodu（`:185`），实得「%s」" % 档案)
	## 统计那句：`%1` = 今日次数、`%2` = 本周、`%3` = 总数（`updateView:187` 就这个序）。
	## ⚠ 原版 "20" 与"本周"之间是**六个空格**，抄串时被折成一个 = 直接对不上原版。
	var 统 := String((页.get_node("收花统计") as Label).text)
	_判(统 == "今日收到次数：2/20      本周收到：21朵 总数：60朵",
			"统计那句逐字 = ZENGHUA_RECEIVE_INFO（含 20 与 本周 之间那六个空格），实得「%s」" % 统)
	_判(_色近((页.get_node("收花统计") as Label).get_theme_color("font_color"), 色表["收花统计"]),
			"统计那句 = UI_YELLOW #fff000（`MGlowLabel.color = UIConfig.UI_YELLOW`）")
	_判(int(页.get_node("收花统计").get_theme_font_size("font_size")) == 12, "统计那句字号 12（Flash 宋体口径）")
	var 说 := _白(页.get_node("说明文字"))
	_判(说.contains("1.每天只可进行一次赠花") and 说.contains("2.玫瑰花可由日环任务获得，蓝色妖姬可在商城购买获得"),
			"说明底那句 = ZENGHUA_SHUOMING_TXT 两条都在，实得「%s」" % 说)
	_判(说.contains("说明："), "「说明：」那半截蓝头也在（拆成两半就是漏了 htmlText 的开头）")
	var 望录文: Array = ["求花甲 赠送了[20朵玫瑰花]", "求花乙 赠送了[1朵玫瑰花]", "求花丙 赠送了[99朵蓝色妖姬]"]
	var 望录时: Array = ["刚刚", "1小时前", "1天前"]
	for i in 5:
		var 格 := 页.get_node("记录_%d" % i) as Control
		_判(_色近((格.get_node("时间") as Label).get_theme_color("font_color"), 色表["时间"]),
				"记录_%d 时间列 = UI_YELLOW" % i)
		_判(not (格.get_node("加为好友") as Control).visible and not (格.get_node("回赠") as Control).visible,
				"记录_%d 那两列**恒藏**（`MarryZengHuaWindow:196` 传的是 false，只有 MyFlowerWindow 传 true）" % i)
		_判(_色近((格.get_node("加为好友") as Label).get_theme_color("font_color"), 色表["加为好友"]),
				"记录_%d 加为好友 = UI_GREEN（藏着也得是绿的，`MyFlowerWindow` 那一档要用）" % i)
		if i < 3:
			var 文 := _白(格.get_node("内容"))
			_判(文 == String(望录文[i]),
					"记录_%d 正文逐字 == %s（%s），实得「%s」" % [i, 望录文[i],
							"妖姬那一档走 ZENGHUA_INFO_YAOJI_LOG（判据是**花号**）" if i == 2 else "名字后面多一个空格是原版就带的",
							文])
			_判(String((格.get_node("时间") as Label).text) == String(望录时[i]),
					"记录_%d 时间列 = %s（经过秒 30/3600/90000），实得「%s」" % [i, 望录时[i],
							String((格.get_node("时间") as Label).text)])
			var 正件 := 格.get_node_or_null("内容") as RichTextLabel
			_判(正件 != null, ("记录_%d 的正文是 RichTextLabel（`LogCell:57` 用的是 flash 版 TextField ⇒ "
					+ "这里得是富文本，`_白` 读的才是 `get_parsed_text()`）") % i)
		else:
			_判(_白(格.get_node("内容")) == "" and String((格.get_node("时间") as Label).text) == "",
					"多出来的记录格_%d 底板照画、正文**留空**（原版只灌前 min(记录数,5) 个）" % i)
	## 三档花的分岔（`Cell:102-122`）：朵 > 1 **且不是妖姬**才有角标、单位才是"元宝/点券"。
	var 望格 := [
		{"格": 0, "角": false, "标": "", "买": false, "含": ["赠送1朵玫瑰花", "友好度：1", "经验：5040", "花费：1000金币"]},
		{"格": 1, "角": true, "标": "20", "买": false, "含": ["赠送20朵玫瑰花", "友好度：20", "经验：151200", "花费：20元宝/点券"]},
		{"格": 2, "角": false, "标": "", "买": true, "含": ["赠送蓝色妖姬", "友好度：", "500", "(商城可购买)"]},
	]
	for 望 in 望格:
		var 号 := int(望["格"])
		var 格 := 页.get_node("花格_%d" % 号) as Control
		var 标 := 格.get_node("角标") as Label
		_判(标.visible == bool(望["角"]), "花格_%d 角标可见性 = %s（朵>1 且非妖姬才有），实得 %s"
				% [号, 望["角"], 标.visible])
		_判(String(标.text) == String(望["标"]), "花格_%d 角标文字 == 「%s」，实得「%s」" % [号, 望["标"], 标.text])
		_判(_色近(标.get_theme_color("font_color"), 色表["角标"]), "花格_%d 角标 = 白 16777215" % 号)
		_判((格.get_node("购买钮") as Control).visible == bool(望["买"]),
				"花格_%d 购买钮可见性 = %s（`Cell:116` 只有妖姬那档露），实得 %s"
				% [号, 望["买"], (格.get_node("购买钮") as Control).visible])
		var 文 := _白(格.get_node("描述"))
		for 片 in (望["含"] as Array):
			_判(文.contains(String(片)), "花格_%d 描述里有「%s」，实得「%s」" % [号, 片, 文])
		var 图: TextureRect = 格.get_node("图标") as TextureRect
		_判(图.texture != null, "花格_%d 图标按花号真取到了图（16000143/16000149 两张都在盘上）" % 号)
	_判(String((页.get_node("花格_0/赠送钮/文字") as Label).text) == "赠送",
			"钮上那句 = ZENGHUA_BUTTON_TXT「赠送」（不是「送花」）")
	_判(String((页.get_node("花格_2/购买钮/文字") as Label).text) == "购买", "购买那颗 = SHOP_BUY「购买」")

	# ── ⑦b 换第二任对面 ⇒ 整页跟着换人（页是每次重灌的，不是缓存）──────────
	管理.call("记赠花对面", {"charId": 2003, "name": "对友丙", "face": 10000206, "level": 50})
	_收(后, 丙帧)
	await _等几帧(4)
	var 页二 := _找页(窗)
	_判(页二 != null and _白(页二.get_node("档案文字")).contains("角色名：对友丙"),
			"换对面后重开 ⇒ 档案那一行跟着换成「对友丙」，实得「%s」"
			% (_白(页二.get_node("档案文字")) if 页二 != null else "‹页没了›"))
	_判(页二 != null and _白(页二.get_node("档案文字")).contains("友好度：88"),
			"友好度也跟着换成新那帧的 88（不是上一帧的 137 留在页上）")
	_判(页二 != null and 页二.get_node("立绘框").get_child_count() == 1,
			"重渲染后立绘框里**只有一枚**（先清空再挂；宠物 N4 那一族就是没清叠了两张）")
	## 换回来：后面的矩形/钮判据都按主帧那一份。
	管理.call("记赠花对面", {"charId": 对号, "name": "对友乙", "face": 10000205, "level": 44})
	_收(后, 主帧)
	await _等几帧(4)
	页 = _找页(窗)
	if 页 == null:
		_早退()
		return

	# ── ⑧ `_时间` 四档边界（`MarryZengHuaLogCell:115-139` 的整数除逐级）─────
	var 望时表 := {59: "刚刚", 0: "刚刚", 60: "1分钟前", 3599: "59分钟前", 3600: "1小时前",
			5999: "1小时前", 7200: "2小时前", 86399: "23小时前", 86400: "1天前", 172800: "2天前",
			90000: "1天前"}
	for 秒 in 望时表:
		var 得 := 赠花脚本._时间(int(秒))
		_判(得 == String(望时表[秒]), "`_时间(%d)` == 「%s」，实得「%s」" % [秒, 望时表[秒], 得])
	## 5999 → 1小时前（**向下取整**，不是四舍五入：99.98 分 = 1.66 时）。原版 `:115-139` 逐级整除，
	## 写成 `roundi` 就正好在 .5 那侧翻档 ⇒ 只有这种"差一点到下一档"的值能逮到。
	_判(赠花脚本._时间(5999) == 赠花脚本._时间(3600), "同一档内取整是**向下**（5999 与 3600 同句）")

	# ── ⑨ 立绘（活的、挂 charBg、摆位 = `146>>1` 与 `208−35`）──────────────
	var 容 := 页.get_node("立绘框") as Control
	_判(容.get_child_count() == 1, "立绘框里有一枚活的立绘（实得 %d）" % 容.get_child_count())
	if 容.get_child_count() >= 1:
		var 角 := 容.get_child(0) as Node2D
		_判(角.position == Vector2(73.0, 173.0),
				"立绘摆位 = (CHAR_WIDTH>>1, CHAR_HEIGHT−35) = (73,173)（`setImgChar:213-214`），实得 %s"
				% str(角.position))
		_判(角.has_method("play"), "那一枚是可播的活立绘（原版 `getCharAliveLookJustFace` + `addTick`），不是静态头像")

	# ── ⑩ 四颗钮：手型光标 / 档宽 37 / 皮基名 / 三态接法 / 一颗真走 ──────────
	var 钮名表 := ["花格_0/赠送钮", "花格_1/赠送钮", "花格_2/赠送钮", "花格_2/购买钮"]
	for 名 in 钮名表:
		var 钮 := 页.get_node(名) as TextureButton
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s = 手型光标（MButton3 useHandCursor）" % 名)
		_判(absf(钮.size.x - 37.0) < 0.51,
				"%s 宽 = 37（`btn_width_two`，`Cell:54/77` 写死的档宽，不是文字量出来的），实得 %.0f"
				% [名, 钮.size.x])
		_判(String(钮.get_meta("skin")).ends_with("钮底37"), "%s 的皮基名 = 钮底37，实得 %s"
				% [名, String(钮.get_meta("skin")).get_file()])
		_判(钮.texture_hover == null and 钮.texture_pressed == null,
				"%s **不设** texture_hover/_pressed（松手要回 up，同求婚窗那五颗的口径）" % 名)
		for 条 in ["mouse_entered", "mouse_exited", "button_down", "button_up"]:
			var 接: Array = (钮.get(条) as Signal).get_connections()
			var 中 := false
			for 元 in 接:
				if String((元.callable as Callable).get_method()) == "设态":
					中 = true
			_判(中, "%s 的 `%s` 接到了 `设态`（实得 %d 条连接）" % [名, 条, 接.size()])
	_判(not (页.get_node("花格_0/购买钮") as Control).visible,
			"花格_0 那颗购买钮是**藏**的（隐藏件不吃 GUI 命中 ⇒ 只能查接法，别去真点它）")
	var 送 := 页.get_node("花格_0/赠送钮") as TextureButton
	var 基名 := String(送.get_meta("skin"))
	var 送位: Vector2 = 送.get_global_rect().get_center()
	await _挪到(送位)
	_判(String(送.texture_normal.resource_path) == 基名 + "_悬停.png",
			"悬停 ⇒ texture_normal 换成 _悬停（实得 %s）" % String(送.texture_normal.resource_path))
	_判(_色近((送.get_node("文字") as Label).get_theme_color("font_color"), 色表["钮悬停"]), "悬停字色 #ffffc3")
	await _按下(送位)
	_判(String(送.texture_normal.resource_path) == 基名 + "_按下.png",
			"按住 ⇒ 换成 _按下（实得 %s）" % String(送.texture_normal.resource_path))
	_判(_色近((送.get_node("文字") as Label).get_theme_color("font_color"), 色表["钮按下"]), "按下字色 #acadb2")
	await _松开(送位)
	_判(String(送.texture_normal.resource_path) == 基名 + ".png",
			"松手（鼠标还停在钮上）⇒ 回常态那张，不是停在悬停档（实得 %s）" % String(送.texture_normal.resource_path))
	## 松手那一刻按下去真的走了一次 `pressed` ⇒ 离线里 `request_send_flower` 发不出去，
	## 能观测到的**只有**号闸那句话（in_game=false ⇒ 「还没连上线…」）。
	_判(提示.size() == 1 and String(提示[0]).contains("还没连上线"),
			"没进游戏就点赠送 ⇒ 说那一句、**不演一次成功**（`_点赠送` 的闸），实得 %s" % str(提示))
	await _挪到(Vector2(480.0, 520.0))

	# ── ⑪ 托盘 `61:44`：两判 + 不去重 + 真点 ⇒ 单钮弹 ─────────────────────
	## 先钉"单钮档要居中、两钮档保持 77/186"——直接打组件的口（不这么钉，"永远居中"这种变异
	## 只会走单钮那一条路，判据就成了空话）。
	var 弹 := 管理.get_node("模态确认弹层/模态确认弹") as Control
	弹.call("收起")
	await _等几帧(1)
	弹.call("弹出", "两颗都在", "确定", func() -> void: pass, "取消", func() -> void: pass)
	_判(absf((弹.get_node("主体/确定钮") as Control).position.x - 77.0) < 0.51,
			"两钮档：确定钮 x = 77（`MDialog:421` 那个**绝对值**，不是排成居中 HBox），实得 %.0f"
			% (弹.get_node("主体/确定钮") as Control).position.x)
	_判(absf((弹.get_node("主体/取消钮") as Control).position.x - 186.0) < 0.51,
			"两钮档：取消钮 x = 186（`:486`），实得 %.0f" % (弹.get_node("主体/取消钮") as Control).position.x)
	_判((弹.get_node("主体/取消钮") as Control).visible, "两钮档：取消钮看得见")
	弹.call("收起")
	await _等几帧(1)
	_判(not 弹.visible, "收起() 把弹收掉（点了确定就该是这个状态）")

	var 盘前 := int(盘.call("数量"))
	_收(后, 我发)
	await _等几帧(2)
	_判(int(盘.call("数量")) == 盘前, "我自己送出去那一发（senderId == 我）⇒ **不加格**，实得 %d"
			% int(盘.call("数量")))
	_收(后, 路人)
	await _等几帧(2)
	_判(int(盘.call("数量")) == 盘前, "别人发给别人（receiverId != 我）⇒ 也不加格，实得 %d" % int(盘.call("数量")))
	_收(后, 我收)
	await _等几帧(2)
	_判(int(盘.call("数量")) == 盘前 + 1, "对面送给我 ⇒ 多一格（`receiveFlower:204-218` 两判），实得 %d"
			% int(盘.call("数量")))
	_收(后, 我收)
	await _等几帧(2)
	_判(int(盘.call("数量")) == 盘前 + 2,
			"同一个人再送一次 ⇒ **还是再塞一格**（`CueManage.checkExist` 没列 TYPE_XIANHUA ⇒ 没有去重键），"
			+ "实得 %d" % int(盘.call("数量")))
	## ⚠ 点格之前先关窗：那扇赠花窗的**全屏遮罩**压在托盘那一格上面，`_真点` 会点到遮罩上
	## ⇒ 弹永远不出现（求婚窗那一族同一口径：量托盘之前先 `全部关闭`）。
	管理.call("全部关闭")
	await _等几帧(3)
	盘.call("清空")
	await _等几帧(2)
	_收(后, 我收)
	await _等落位()
	var 格: Control = 盘.最后一格()
	_判(格 != null and int(格.get("类型")) == 15,
			"那一格带的是类型 15（`邀请托盘.类型收到鲜花`），实得 %s" % str(格.get("类型") if 格 != null else "没格"))
	if 格 != null:
		var 图: TextureRect = 格.get_node_or_null("图标") as TextureRect
		_判(图 != null and 图.texture != null and String(图.texture.resource_path).contains("托盘_鲜花"),
				"那一格的图标 = 原版鲜花那枚（实得 %s）" % (
					图.texture.resource_path if 图 != null and 图.texture != null else "（无）"))
		_判(格.position.x > 300.0,
				"那一格飞到头顶槽位了（x=%.0f）—— 没落位就点会点到叠在上面的别的格" % 格.position.x)
	await _真点(格)
	_判(弹.visible, "真点那一格 ⇒ 弹出确认弹（`xianhuaHandler:256-280` 走 `showMessageDialog`）")
	var 正文 := _白(弹.get_node("主体/正文"))
	_判(正文.contains("对友乙") and 正文.contains("20") and 正文.contains("玫瑰花"),
			"弹里那句 = ZENGHUA_RECEIVE_TIP（名与朵都插进去了），实得「%s」" % 正文)
	_判(not (弹.get_node("主体/取消钮") as Control).visible,
			"那一档**只有确定**（`param3/param5` 留默认 ⇒ handler 为 null、buttons=1）")
	var 确 := 弹.get_node("主体/确定钮") as Control
	_判(absf(确.position.x - 136.0) < 0.51,
			"单钮档那颗**居中**：x = (302−30)/2 = 136（`MDialog:228-238`），实得 %.0f" % 确.position.x)
	var 主体高 := (弹.get_node("主体") as Control).size.y
	_判(absf((弹.get_node("主体/底") as Control).size.x - 302.0) < 0.51,
			"底板宽 = bg1.width 302（不是 `窗口边框` 那张，MDialog 不是 MWindow）")
	## 高度是**算出来的**（`panelHeight = 正文盒底 + BOTTOM_HEIGHT(50)`），随行数长；
	## 写死一个高度 = 两行文案时把字裁掉 ⇒ 这里钉**算式**而不是钉死值（行数由真实字体量，
	## 本机换字体就会变，硬钉 87 是假绿+假红的混合体）。
	_判(absf(确.position.y - (主体高 - 22.0 - 5.0 - 8.0)) < 0.51,
			"钮 y = 窗高 − 钮高22 − BORDER_GAP5 − 8（`:207` 那个 `- 8`），窗高 %.0f ⇒ 应 %.0f、实 %.0f"
			% [主体高, 主体高 - 35.0, 确.position.y])
	_判(主体高 >= 87.0, "单行文案的窗高下限 = 14 + (15+8) + 50 = 87（实得 %.0f）" % 主体高)
	提示.clear()
	await _真点(确)
	_判(not 弹.visible, "点确定 ⇒ 弹收掉（`xianhuaHandler` 那档 handler 是 null，只收弹）")
	_判(提示.is_empty(), "点确定**什么都不发**（原版那颗只 hide，没有上行），实得 %s" % str(提示))
	## 妖姬那一发：走的是另一句（判据两条，见 ⑫）。
	盘.call("清空")
	await _等几帧(2)
	_收(后, 我收妖姬)
	await _等落位()
	await _真点(盘.最后一格())
	_判(_白(弹.get_node("主体/正文")).contains("蓝色妖姬"),
			"收到 99 朵妖姬那一格 ⇒ 弹的是 YAOJI_TIP 那句，实得「%s」" % _白(弹.get_node("主体/正文")))
	弹.call("收起")
	await _等几帧(1)

	# ── ⑫ 妖姬那句的**两条**判据（`Manager.xianhuaHandler:271` 那个 `||`）───
	var 妖姬号 := 赠花脚本._妖姬号()
	_判(妖姬号 == 16000149,
			"妖姬号取自烘进去的表（`原版杂项.json → flower.rosebuleid`），不在代码里写死；实得 %d" % 妖姬号)
	var 三条 := [
		{"条": {"senderName": "甲", "count": 1, "flowerid": 16000149}, "望": "蓝色妖姬"},
		{"条": {"senderName": "甲", "count": 99, "flowerid": 16000143}, "望": "蓝色妖姬"},
		{"条": {"senderName": "甲", "count": 20, "flowerid": 16000143}, "望": "玫瑰花"},
	]
	for 项 in 三条:
		var 得 := 赠花脚本.收花文案(项["条"] as Dictionary)
		_判(得.contains(String(项["望"])),
				"收花文案(%s) 走「%s」那句，实得「%s」" % [str(项["条"]), 项["望"], 得])
	_判(not (赠花脚本.收花文案({"senderName": "甲", "count": 20, "flowerid": 16000143} as Dictionary))
			.contains("妖姬"), "普通玫瑰那句里**不出现**「妖姬」")

	# ── ⑬ 尺寸表 / 素材 / 场景在盘上 ──────────────────────────────────────
	管理.call("全部关闭")
	await _等几帧(2)
	var 表 := JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/窗口尺寸.json")) as Dictionary
	var 规: Dictionary = 表.get("赠花", {}) as Dictionary
	_判(int(规.get("宽", 0)) == 550 and int(规.get("高", 0)) == 415 and bool(规.get("整框", false)),
			"尺寸表「赠花」= 550×415 整框:true（唯一来源 `super(550,415,true)`），实得 %s" % str(规))
	_判(String(规.get("标题", "")) == "赠花", "表里那条标题 = ZENGHUA_WINDOW_TITLE")
	_判(规.get("内容底") == false, "这页自己画 MYellow ⇒ 外壳那张不能再叠第二遍")
	for 皮 in ["res://素材/界面/原版窗口/通用控件/内容面板.png", "res://素材/界面/原版窗口/通用控件/子面板.png",
			"res://素材/界面/原版窗口/通用控件/物品格.png", "res://素材/界面/原版窗口/好友/钮底37.png",
			"res://素材/界面/原版窗口/好友/钮底37_悬停.png", "res://素材/界面/原版窗口/好友/钮底37_按下.png",
			"res://素材/界面/原版窗口/通用控件/托盘_鲜花.png"]:
		_判(ResourceLoader.exists(皮), "%s 在（这页要用的皮）" % 皮.get_file())
	_判(FileAccess.file_exists(场景路径) and FileAccess.file_exists("res://脚本/界面/窗口/家族/赠花窗.gd"),
			"场景与控制器都在盘上（preload 断了会整个功能窗口 parse 失败）")
	for 件 in ["16000143", "16000149"]:
		var 径 := 游戏数据.item_icon_path(int(件))
		_判(径 != "", "花号 %s 的图标解得出路径（`物品图标索引.json` 有这一位），实得「%s」" % [件, 径])
		_判(游戏数据.item_icon(int(件)) != null, "花号 %s 那张图**真加载得出来**（不是只有路径字符串）" % 件)

	# ── ⑭ 键名交叉核对：两边都必须对上 AS3 `Flower*` 的字段名 ──────────────
	## 求婚窗那一族踩过：`_挑对戒` 读的键是编的、夹具也照同一套编的键灌 ⇒ 两边一起错、互相印证，
	## 239 条全绿而真机上永远"请先放入羁绊对戒"。⇒ 参照值用 **AS3 那三个类的字段名**
	## （`FlowerCharInfo.as:8-22` / `FlowerSenderInfo.as:6-20` / `FlowerInfo.as:6-16`），
	## 拿**解析器自己**与**窗自己的读法**各自去对，而不是让两边互相印。
	var 顶层键 := ["cid", "face", "youhaodu", "totalFlowers", "weeklyFlowers", "count",
			"flowerDayLogInfo", "flowerInfo"]
	var 记录键 := ["senderName", "senderId", "count", "sendTime", "face", "job", "level", "flowerid"]
	var 档位键 := ["count", "exp", "cost", "youhaodu", "type", "flowerid"]
	var 结算键 := ["senderId", "receiverId", "senderName", "count", "flowerid"]
	var 源 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	var 解体 := _切函数(源, "func _处理花档帧")
	_判(解体 != "", "切到了 `_处理花档帧` 的函数体（切不到 ⇒ 下面这一整段都是假绿，先红这条）")
	for 键 in 顶层键:
		_判(解体.contains("\"%s\":" % 键), "解析器写出的顶层键里有 `%s`（AS3 `FlowerCharInfo` 字段名）" % 键)
	for 键 in 记录键:
		_判(解体.contains("\"%s\":" % 键), "解析器写出的记录键里有 `%s`（AS3 `FlowerSenderInfo` 字段名）" % 键)
	for 键 in 档位键:
		_判(解体.contains("\"%s\":" % 键), "解析器写出的档位键里有 `%s`（AS3 `FlowerInfo` 字段名）" % 键)
	var 结体 := _切函数(源, "func _handle_friend_text")
	for 键 in 结算键:
		_判(结体.contains("\"%s\":" % 键), "`61:44` 解出来的键里有 `%s`" % 键)
	var 窗源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/家族/赠花窗.gd")
	for 键 in ["youhaodu", "count", "weeklyFlowers", "totalFlowers", "flowerDayLogInfo",
			"flowerInfo", "senderName", "sendTime", "flowerid", "exp", "cost"]:
		_判(窗源.contains("get(\"%s\"" % 键), "赠花窗读的键里有 `%s`（与上面解析器那一份同名 ⇒ 两边是同一份约定）" % 键)
	var 管源 := FileAccess.get_file_as_string("res://脚本/界面/窗口管理.gd")
	for 键 in ["cid", "senderId", "receiverId"]:
		_判(管源.contains("get(\"%s\"" % 键), "窗口管理读的键里有 `%s`（cid 判档、sender/receiver 判方向）" % 键)

	# ── ⑮ 段数闸写在源码哪一档（**判的是文本，不是行为**）────────────────
	## 把 `if fields.size() < 10:` 拆掉以后，缺段那一帧**不会多发**：它会走到 `fields[8]`
	## 下标越界、当场报错中断，信号照样是 0 条 ⇒ ② 那种"喂完前后一样多"的行为判据**两边都成立**
	## （求婚窗一族 10-17 变异 P1 实测：闸拆了、门仍全绿）。这一族只能钉源码文本，
	## 并且把"我钉的是文本"写在判据里，别让它冒充行为证据。
	_判(解体.contains("if fields.size() < 10:"),
			"`58:2` 的段数闸写的是 `< 10`（源码核对；整帧十条：号/脸/友好/总/周/次 + 记录 + 档位 + 前两固定段）")
	_判(解体.contains("if 段.size() < 8:"), "记录条目的闸写的是 `< 8`（名号朵时脸职级花号）")
	_判(解体.contains("if 段.size() < 6:"), "档位条目的闸写的是 `< 6`（朵经验花费友好type花号）")
	_判(解体.contains("if String(fields[8]) != \"-\""), "空记录认的是 `-` 而不是空串（服务端 `logs or \"-\"`）")
	_判(解体.contains("记录.sort_custom") and 解体.contains("档.sort_custom"),
			"两条升序排在**收端**做（原版 `FlowerCharInfo.as:77/:91`），窗里不许再排一次")
	var 上行体 := _切函数(源, "func request_flower_info")
	_判(上行体.contains("target_id > 0") and 上行体.contains("\"6:%d\" % target_id"),
			"`94:6` 那道闸与动作字节 6 都在（同 OP 上 0/4/6 三支只差一位，混了就点谁都不开窗）")
	var 送体 := _切函数(源, "func request_send_flower")
	_判(送体.contains("target_id > 0 and flower_count > 0") and 送体.contains("\"39:%d:%d\""),
			"`127:39:<号>:<朵>` 那两个 int 都在（`FriendProcessor.as:541-548` 写的是两个 writeInt）")
	## 三颗赠送钮各自绑的朵数：`bind` 进去的实参**读不出来**（Godot 4.7 的 Callable 没有
	## `get_bound_arguments`，实测 ClassDB 也查不到），而"朵"从帧到 `描述` 那一段已经由 ⑦
	## 行为性地钉死了（1/20/99 三句各不相同）⇒ 这里钉最后一步的源码：绑的是 `朵` 那个局部量。
	var 格体 := _切函数(窗源, "static func _刷花格")
	_判(格体 != "", "切到了 `_刷花格`（切不到 ⇒ 下面三条又是假的）")
	_判(格体.contains("var 朵 := int(条.get(\"count\", 0))"),
			"朵数取自当前那一条的 `count`（不是写死 1/20/99）")
	_判(格体.contains("_点赠送.bind(宿主, 号, 朵)"), "赠送钮绑的是 (宿主, 号, **朵**) 三个实参")
	_判(格体.contains("_点购买.bind(宿主, 花号)"), "购买钮绑的是 (宿主, 花号) —— 原版那句 `requestCashItemInfo(flowerid, 0)`")

	# ── ⑯ 未判（离线里判了就是假绿）──────────────────────────────────────
	print("未判（离线里判了就是假绿）：`94:6` 与 `127:39:<号>:<朵>` 的**包体字节**、"
			+ "「对面在线才回 `58:2`」「今天送过 ⇒ 服务端那句『每天只能赠花一次』」「朵数不在 1/20/99 ⇒ 拒」"
			+ "这三条服务端闸，以及 ⑭ 里那两道 `target_id > 0` 在**活连接上真的不发帧** —— "
			+ "无头没有 TCP，`send_game_request` 第一行就 return false，闸挡的和没连接挡的在这里分辨不出"
			+ " ⇒ 归在线门 `头像信息在线`（那一族 §④ 的「赠花」分支逐条真点真收）。"
			+ "另：`MyFlowerWindow`（我收到的花，带「加为好友/回赠」两列）与「购买」按物品号开商城分页"
			+ "本工程都没移植 ⇒ 前者 ⑤ 只钉了「不顶替」，后者钉的是「话说实」。")
	跑完了 = true
	print("赠花窗离线门：通过 %d，红 %d" % [通过, 失败])
