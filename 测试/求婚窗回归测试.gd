extends SceneTree
## 求婚窗（原版 `ProposalWindow`，页名「羁绊申请」）离线门。
## 逐件参照值手抄自 `真值/窗口/求婚窗.md`（AS3 与服务端行号都在那张表里），
## **不从被测场景反查** —— 场景和门一起写错就永远绿。
##
## 覆盖：① `61:14` 逐字段（族名那位要落到 `banghui`，`CharInfoPane.setData:77` 读的就是它）
## ② 缺段一帧都不发 ③ `61:17` 逐字段 + 末段对戒号，收到**只塞格、不开窗**
## ④ 求婚那一格**不去重**（原版 `CueManage` 没这一族的键）⑤ **真鼠标**点那一格 ⇒ 开的是「被求档」
## ⑥ 逐件矩形 + 层序（addChild 原序）+ 九宫格边距现取参照 ⑦⑧ 两档的文字/颜色/标题/取件钮可见性
## ⑨ 头像按 face、对戒图按 item ⑩ 五颗钮三态（一颗真走 + 两颗真悬停、两颗查接法）
## ⑪ 被求档点「拒绝」⇒ 关窗 ⑫⑬⑭ 三条闸量在**发起档**：没对戒 / 挑到对戒 / 已结婚（含"夹具真灌进去 1 件"
##    那条对照，否则三条判据就是"0 比 0 恒真"的假绿）⑮ 换第二任求方 ⇒ 整页跟着换人
## ⑯ `61:18` 那一句 ⑰ `61:19/20/13` 写权威配偶 + 缺段 ⑱ 发起档直接开窗 ⑲ 尺寸表 / 素材在盘上
## ⑳ 五支的**段数闸写在源码哪一档**（这条行为上测不出，原因见 ⑳ 里那段注释）
##
## ⚠ 三条量法口径（这一族先跑红才学到的，别再踩）：
## 1. 无头 `root.size` **一次设不成** ⇒ 每帧重设直到 `get_visible_rect()` 真等于 960×560，这条本身当判据。
## 2. 托盘那格入场是 **2 秒补间** ⇒ 按墙钟等 + 判 `position.x > 300`，一次只点一格。
## 3. 按下/松开只传**屏幕坐标**：那一格派发时自删，拿节点算松开位会 `previously freed`、松手整个被跳过
##    ⇒ 视口停在"左键还按着"，之后所有悬停/点击都被吞。
##
## 跑法：`"godot" --path . --headless --script res://测试/求婚窗回归测试.gd`

const 场景路径 := "res://场景/界面/窗口/家族/求婚窗.tscn"
const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 页根名 := "原版求婚内容"
const 职业表 := preload("res://脚本/单例/职业.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 求婚脚本 := preload("res://脚本/界面/窗口/家族/求婚窗.gd")

## §③ 页局部 = AS3 − 29（`整框: true`）。三颗主钮 y = 447−29 = 418（`ProposalWindow.as:199`），
## x = 54.25 / 163.5 / 284.75 是 `:197/:196/:198` 那三行算式的结果，**不是量出来的**。
## 底部五格步距 32/7/18/7（`ProposaBottomWindow.as:112-129`，四段各不相同 ⇒ 不能按等距画）。
const 逐件 := {
	"内容底": [6.0, 11.0, 376.0, 402.0],
	"子底": [11.0, 82.0, 366.0, 320.0],
	"头像格": [30.0, 26.0, 54.0, 54.0],
	"名字": [94.0, 16.0, 100.0, 20.0],
	"等级": [194.0, 16.0, 100.0, 20.0],
	"职业": [94.0, 39.0, 100.0, 20.0],
	"家族": [194.0, 39.0, 100.0, 20.0],
	"心意提示": [94.0, 62.0, 300.0, 20.0],
	"说明白字": [15.0, 84.0, 380.0, 20.0],
	"对戒格": [21.0, 136.0, 40.0, 40.0],
	"能力1": [93.0, 136.0, 40.0, 40.0],
	"能力2": [140.0, 136.0, 40.0, 40.0],
	"效果1": [198.0, 136.0, 40.0, 40.0],
	"效果2": [245.0, 136.0, 40.0, 40.0],
	"放入钮": [292.0, 131.0, 70.0, 22.0],
	"购买钮": [292.0, 158.0, 70.0, 22.0],
	"羁绊戒指标": [11.0, 106.0, 60.0, 18.0],
	"戒指能力标": [106.5, 106.0, 60.0, 18.0],
	"佩戴效果标": [211.5, 106.0, 60.0, 18.0],
	"结后句": [15.0, 179.0, 347.0, 20.0],
	"说明框": [19.0, 199.0, 376.0, 197.0],
	"查看资料钮": [54.25, 418.0, 61.0, 22.0],
	"主钮": [163.5, 418.0, 61.0, 22.0],
	"次钮": [284.75, 418.0, 37.0, 22.0],
}
## 层序 = `ProposalWindow()` 的调用序（`newBackground → newCharInfo → newBottom → newBtn`，`:35-43`）
## 加上各件内部 `addChild` 序；不是场景文件的书写顺序，也不是按名字排。
const 层序 := ["内容底", "子底", "头像格", "名字", "等级", "职业", "家族", "心意提示", "说明白字",
		"对戒格", "能力1", "能力2", "效果1", "效果2", "放入钮", "购买钮",
		"羁绊戒指标", "戒指能力标", "佩戴效果标", "结后句", "说明框",
		"查看资料钮", "主钮", "次钮"]
## 九宫格件用的是哪张共享皮（边距现取 `皮肤表.九宫格`，门里不写第二份数）——
## 那张映射写在 ⑥ 里面（`皮肤表.内容面板` 这类常量在 const 字典里当键值取不到实例，实测报
## `Cannot call non-static function "get()"`）。
## 五颗钮的**档宽**：`ProposalWindow.as:120/125/129` 用 `btn_width_four=61`/`btn_width_two=37`，
## `ProposaBottomWindow.as:134/140` 用 `btn_width_five=70`（`UIConfig.as:964/968/970`）。
const 钮档 := {"查看资料钮": 61, "主钮": 61, "次钮": 37, "放入钮": 70, "购买钮": 70}

const 色表 := {
	"名字": Color("#1e90ff"), "等级": Color("#1e90ff"),
	"职业": Color("#1e90ff"), "家族": Color("#1e90ff"),
	"心意提示": Color("#ff0000"), "说明白字": Color("#ffffff"),
	"结后句": Color("#ff0000"), "三标": Color("#fff000"),
	"钮常态": Color("#fcf49c"), "钮悬停": Color("#ffffc3"),
	"钮按下": Color("#acadb2"), "钮灰": Color("#939393"),
}

## 原文形状逐条抄服务端（**不是手写猜的**）：
## · `14` = `fake_flash_server.py:23236-23241` `14:<名>:<级>:<职>:<族名>:<脸>:<号>`
## · `17` = `:23270-23275` 同形再末段 `<对戒号>`
## · `18` = `:23365-23367` `18:<拒绝方名>`　· `19/20` = `:23346-23355` `<号>:<对戒号>:<名>:<脸>:<职>`
## · `13` = `:22285-22291` `<号>:<名>:<职>:<对戒号>`
## face 用盘上真有的两个号（编一个没有的 ⇒ 量具自己取不到图，不是产品错）。
const 甲十四 := "61:14:求方甲:30:2:木叶之火:10000204:2001"
const 甲十七 := "61:17:求方甲:30:2:木叶之火:10000204:2001:19010001"
const 乙十七 := "61:17:求方乙:44:1:暗部:10000205:2002:19030001"
const 丙十八 := "61:18:拒绝者丙"
const 丁十九 := "61:19:2001:19010001:求方甲:10000204:2"
const 戊二十 := "61:20:2002:19030001:求方乙:10000205:1"
const 己十三 := "61:13:2001:求方甲:2:19010001"

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 收十四: Array = []
var 收十七: Array = []
var 收十八: Array = []
var 收结: Array = []
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


## ⚠ `authoritative_inventory` 是 **`Array[Dictionary]`（类型化数组）**：
## 拿无类型字面量 `[{...}]` 去 `set` 会**静默丢掉**（实测：无类型 ⇒ 后端里 0 条，typed ⇒ 1 条），
## 于是 `_挑对戒` 永远挑不到 ⇒ 那三条"没对戒/有对戒"的判据全变成"0 比 0 恒真"的假绿。
## ⇒ 所有灌背包一律走这个助手（10-17 记忆里的"类型化数组 set 静默丢"这一条又踩了一次）。
func _灌背包(后: Node, 件: Array) -> void:
	var 定: Array[Dictionary] = []
	for x in 件:
		定.append(x as Dictionary)
	后.set("authoritative_inventory", 定)


## 把一个 `match` 的函数体切成「臂 → 那一支的文本」。分隔线认的是**恰好两个制表符开头、以冒号结尾**
## 那一行（`match` 体里的普通语句都是三个制表符），所以不会把 `if …:` 误当成臂。
func _臂表(体: String) -> Dictionary:
	var 表 := {}
	var 当 := ""
	var 串 := ""
	for 行 in 体.split("\n"):
		if 行.begins_with("\t\t") and not 行.begins_with("\t\t\t") and 行.ends_with(":"):
			if 当 != "":
				表[当] = 串
			当 = 行.trim_prefix("\t\t").trim_suffix(":")
			串 = ""
		elif 当 != "":
			串 += 行 + "\n"
	if 当 != "":
		表[当] = 串
	return 表


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


func _早退() -> void:
	跑完了 = true
	print("求婚窗离线门：通过 %d，红 %d" % [通过, 失败])


func _跑() -> void:
	print("求婚窗离线门开始")
	await _钉视口()
	var 后: Node = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("authoritative_spouse", {"charId": 0, "name": "", "face": 0, "job": 0, "hunjieId": 0})
	var 空包: Array[Dictionary] = []
	后.set("authoritative_inventory", 空包)
	后.connect("bond_preview_received", func(人: Dictionary) -> void: 收十四.append(人))
	后.connect("bond_invite_received", func(邀: Dictionary) -> void: 收十七.append(邀))
	后.connect("bond_refused_received", func(拒: Dictionary) -> void: 收十八.append(拒))
	后.connect("bond_established_received", func(婚: Dictionary) -> void: 收结.append(婚))
	## 主钮那三条路的"说了什么"是真信号 ⇒ 接 **GameSession** 那一条，不是问被测对象要答案。
	var 会话 := root.get_node_or_null("GameSession")
	_判(会话 != null and 会话.has_signal("notification_requested"),
			"GameSession 上有 notification_requested（三态那条路靠它说话）")
	if 会话 != null:
		会话.connect("notification_requested", func(话: String) -> void: 提示.append(话))
	await _等几帧(2)
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	await _等几帧(4)
	var 盘 = 管理.get_node_or_null("邀请托盘")
	_判(盘 != null, "窗口管理底下有「邀请托盘」这一层（实得 %s）" % str(盘))
	if 盘 == null:
		_早退()
		return
	盘.call("清空")
	await _等几帧(2)

	# ── ① `61:14` 逐字段 ──────────────────────────────────────────────────
	_收(后, 甲十四)
	await _等几帧(2)
	_判(收十四.size() == 1, "喂一帧 `61:14:…` ⇒ 一条 bond_preview_received（实得 %d 条）" % 收十四.size())
	if 收十四.is_empty():
		_早退()
		return
	var 望十四 := {"name": "求方甲", "level": 30, "job": 2, "banghui": "木叶之火",
			"face": 10000204, "charId": 2001}
	var 人: Dictionary = 收十四[0] as Dictionary
	for 键 in 望十四:
		_判(人.has(键) and str(人[键]) == str(望十四[键]),
				"`14` 解出来的 `%s` == `%s`（实得 `%s`；全字典=%s）" % [键, 望十四[键], 人.get(键, "‹无›"), str(人)])
	_判(not 人.has("famillyName"), "`14` 不另起 `famillyName` 这个键（pane 读的是 `banghui`）")
	_判(not 人.has("item"), "`14` **不带**对戒号（带末段那一支是 `17`，两支别并）")

	# ── ② 缺段 ⇒ 一帧都不发 ──────────────────────────────────────────────
	var 前 := 收十四.size()
	_收(后, "61:14:求方甲:30:2:木叶之火:10000204")
	_收(后, "61:14:求方甲")
	await _等几帧(2)
	_判(收十四.size() == 前, "缺段的 `61:14` 被丢掉（前 %d → 后 %d）" % [前, 收十四.size()])
	## `61:14` 那一支**本来就会把窗开出来**（原版 `onFriend_taStart` 直接 setData+show），
	## 所以量"收到 `61:17` 不开窗"之前必须先全部关掉 —— 不然量到的是上一支留下的那扇，假红。
	管理.call("全部关闭")
	await _等几帧(3)
	_判(not _开着(管理._窗口们.get("羁绊申请") as Node), "全部关闭确实把 ① 那扇收掉了（后面量的才是 17 那一支）")

	# ── ③ `61:17` 逐字段 + 只塞格不开窗 ───────────────────────────────────
	_收(后, 甲十七)
	await _等几帧(2)
	_判(收十七.size() == 1, "喂一帧 `61:17:…` ⇒ 一条 bond_invite_received（实得 %d 条）" % 收十七.size())
	if 收十七.is_empty():
		_早退()
		return
	var 邀: Dictionary = 收十七[0] as Dictionary
	for 键 in 望十四:
		_判(str(邀.get(键, "‹无›")) == str(望十四[键]),
				"`17` 解出来的 `%s` == `%s`（实得 `%s`）" % [键, 望十四[键], 邀.get(键, "‹无›")])
	_判(int(邀.get("item", 0)) == 19010001,
			"`17` 末段 = 对戒号 19010001（被求那侧第一格画的就是它），实得 %d" % int(邀.get("item", 0)))
	_判(int(盘.call("数量")) == 1, "那一帧让头顶真多出一格（实得 %d 格）" % int(盘.call("数量")))
	var 窗: Node = 管理._窗口们.get("羁绊申请") as Node
	_判(窗 == null or not _开着(窗), "收到 `61:17` **不开窗**（原版 `Client.as:7883` 只 addMsg 进 CueGird）")
	var 甲格: Control = 盘.最后一格()
	var 图: TextureRect = 甲格.get_node_or_null("图标") as TextureRect
	_判(图 != null and 图.texture != null and String(图.texture.resource_path).contains("托盘_求婚"),
			"那一格的图标 = 原版求婚那枚（实得 %s）" % (
				图.texture.resource_path if 图 != null and 图.texture != null else "（无）"))

	# ── ④ 求婚那一格**不去重**（同一个人再求一次 ⇒ 两格）───────────────────
	_收(后, 甲十七)
	await _等几帧(2)
	_判(int(盘.call("数量")) == 2,
			"同一个求方再发一次 ⇒ **还是再塞一格**（实得 %d）。并成一格就是自造了原版没有的去重键"
			% int(盘.call("数量")))
	_收(后, 乙十七)
	await _等几帧(2)
	_判(int(盘.call("数量")) == 3, "换第二任求方 ⇒ 三格（实得 %d）" % int(盘.call("数量")))
	盘.call("清空")
	await _等几帧(2)

	# ── ⑤ 真点那一格 ⇒ 开「被求档」 ──────────────────────────────────────
	_收(后, 甲十七)
	await _等落位()
	var 格: Control = 盘.最后一格()
	_判(格 != null and int(格.get("类型")) == 8,
			"那一格带的是类型 8（`邀请托盘.类型求婚申请`），实得 %s" % str(格.get("类型") if 格 != null else "没格"))
	_判(格 != null and 格.position.x > 300.0,
			"那一格飞到头顶槽位了（x=%.0f）—— 没落位就点会点到叠在上面的别的格"
			% (格.position.x if 格 != null else -1.0))
	await _真点(格)
	窗 = 管理._窗口们.get("羁绊申请") as Node
	_判(窗 != null and _开着(窗), "真点托盘那一格 ⇒ 窗开出来了（分发在 `窗口管理._on_托盘已点`）")
	var 页 := _找页(窗)
	_判(页 != null, "页本体「%s」建出来了（264 那一族同形：整窗 388×475，页 388×446）" % 页根名)
	if 页 == null:
		_早退()
		return

	# ── ⑥ 逐件矩形 + 层序 + 九宫格边距 ────────────────────────────────────
	_判(absf(页.size.x - 388.0) < 0.51 and absf(页.size.y - 446.0) < 0.51,
			"页 = 388×446，实得 %.0f×%.0f" % [页.size.x, 页.size.y])
	for 名 in 逐件:
		var 子 := 页.get_node_or_null(名) as Control
		_判(子 != null, "逐件：%s 在" % 名)
		if 子 == null:
			continue
		_判(_近(_矩形(子), 逐件[名]), "%s 矩形 = (%s)，实得 (%s)" % [名, 逐件[名], _矩形(子)])
	var 实际序: Array = []
	for 子 in 页.get_children():
		实际序.append(String((子 as Node).name))
	_判(实际序 == 层序, "层序 = addChild 原序，实得 %s" % str(实际序))
	var 皮路 := {"内容底": 皮肤表.内容面板, "子底": 皮肤表.子面板, "头像格": 皮肤表.物品格,
			"对戒格": 皮肤表.物品格, "能力1": 皮肤表.物品格, "能力2": 皮肤表.物品格,
			"效果1": 皮肤表.物品格, "效果2": 皮肤表.物品格}
	for 名 in 皮路:
		var 块 := 页.get_node_or_null(名) as NinePatchRect
		_判(块 != null, "%s 是 NinePatchRect（九宫格件）" % 名)
		if 块 == null:
			continue
		var 组: Array = 皮肤表.九宫格[皮路[名]]
		var 期 := [int(组[0]), int(组[1]), int(组[2]), int(组[3])]
		var 实 := [块.patch_margin_left, 块.patch_margin_right, 块.patch_margin_top, 块.patch_margin_bottom]
		_判(实 == 期, 名 + " 九宫格边距(左右上下) = " + str(期) + "（现取自 皮肤表.九宫格." + str(皮路[名])
				+ "；写成 texture_margin_* 会被静默丢掉 ⇒ 整张皮拉平），实得 " + str(实))

	# ── ⑦⑧ 被求档的文字 / 颜色 / 取件钮隐藏 / 标题 ────────────────────────
	_判((页.get_node("名字") as Label).text == "名字：求方甲", "第一行（实得「%s」）" % (页.get_node("名字") as Label).text)
	_判((页.get_node("等级") as Label).text == "等级：30", "第二行（实得「%s」）" % (页.get_node("等级") as Label).text)
	_判((页.get_node("职业") as Label).text == "职业：" + 职业表.取(2), "第三行（实得「%s」）" % (页.get_node("职业") as Label).text)
	_判((页.get_node("家族") as Label).text == "家族：木叶之火", "第四行（实得「%s」）" % (页.get_node("家族") as Label).text)
	for 名 in ["名字", "等级", "职业", "家族"]:
		_判(_色近((页.get_node(名) as Label).get_theme_color("font_color"), 色表[名]),
				"%s = UI_BLUE #1e90ff（`CharInfoPane.as:39-46` 四行同色）" % 名)
	_判(_色近((页.get_node("心意提示") as Label).get_theme_color("font_color"), 色表["心意提示"]),
			"pane 那行提示取 `<font color='#ff0000'>` 里的红（BaseUtil.getLabel 第二参 16711680 只是底色）")
	_判((页.get_node("心意提示") as Label).text == "TA向您出示了心意，您愿意与TA建立羁绊吗？",
			"被求档 pane 提示 = CHARINFO_PANE_TISHI_TEXT_1（实得「%s」）" % (页.get_node("心意提示") as Label).text)
	_判((页.get_node("说明白字") as Label).text == "TA为您呈上的羁绊对戒是：",
			"被求档窗级提示 = PROPOSA_WINDOW_TA_WEINI_FENGXIAN_JIEZHI（实得「%s」）" % (页.get_node("说明白字") as Label).text)
	_判(_色近((页.get_node("说明白字") as Label).get_theme_color("font_color"), 色表["说明白字"]),
			"窗级那句 = 白（`ProposalWindow.newBottom:177`）")
	for 名 in ["羁绊戒指标", "戒指能力标", "佩戴效果标"]:
		_判(_色近((页.get_node(名) as Label).get_theme_color("font_color"), 色表["三标"]), "%s = #fff000" % 名)
	_判((页.get_node("羁绊戒指标") as Label).text == "羁绊戒指", "第一个黄标签（实得「%s」）" % (页.get_node("羁绊戒指标") as Label).text)
	_判((页.get_node("结后句") as Label).text == "建立羁绊后的你们可以：", "结后句（实得「%s」）" % (页.get_node("结后句") as Label).text)
	_判((页.get_node("主钮/文字") as Label).text == "同意请求",
			"被求档主钮 = PROPOSA_WINDOW_TONGYI_QIUHUN（实得「%s」）" % (页.get_node("主钮/文字") as Label).text)
	_判((页.get_node("次钮/文字") as Label).text == "拒绝",
			"被求档次钮 = REMITCOPY_DECLINE（实得「%s」）" % (页.get_node("次钮/文字") as Label).text)
	_判((页.get_node("查看资料钮/文字") as Label).text == "查看信息", "第一颗 = POPUP_QUERY「查看信息」")
	_判(not (页.get_node("放入钮") as Control).visible and not (页.get_node("购买钮") as Control).visible,
			"被求档 ⇒ 那两颗取件/购买钮**不显示**（`ProposaBottomWindow.isProposa:201-204`）")
	_判(String(窗.get_node("遮罩/主窗口/标题").text) == "羁绊确认",
			"被求档标题 = PROPOSA_WINDOW_TITLE_OK（实得「%s」）" % String(窗.get_node("遮罩/主窗口/标题").text))

	# ── ⑨ 头像与对戒图 ────────────────────────────────────────────────────
	var 头像 := 页.get_node("头像格/头像") as TextureRect
	_判(头像.texture != null, "头像按 face=10000204 真取到了图")
	_判(头像.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
			"头像格里的 TextureRect 不顶格子（必须 IGNORE_SIZE，实得 %d）" % 头像.expand_mode)
	_判(头像.position == Vector2(2.0, 2.0) and 头像.size == Vector2(49.0, 49.0),
			"PortraitHead = 54−5 = 49 见方、摆在格内 `>>1` = (2,2)（`CharInfoPane.as:60-66`），实得 %s %s"
			% [str(头像.position), str(头像.size)])
	var 戒图 := 页.get_node("对戒格/对戒图") as TextureRect
	_判(戒图.texture != null, "对戒图按 item=19010001 取到了图标（取不到说明物品表/图标链断了）")

	# ── ⑩ 三态：一颗真走 + 四颗查接法（点下去会触发业务，不挨个真点）────────
	var 查 := 页.get_node("查看资料钮") as TextureButton
	var 基名 := String(查.get_meta("skin"))
	var 查位: Vector2 = 查.get_global_rect().get_center()
	await _挪到(查位)
	_判(String(查.texture_normal.resource_path) == 基名 + "_悬停.png",
			"悬停 ⇒ texture_normal 换成 _悬停（实得 %s）" % String(查.texture_normal.resource_path))
	_判(_色近((查.get_node("文字") as Label).get_theme_color("font_color"), 色表["钮悬停"]), "悬停字色 #ffffc3")
	await _按下(查位)
	_判(String(查.texture_normal.resource_path) == 基名 + "_按下.png",
			"按住 ⇒ 换成 _按下（实得 %s）" % String(查.texture_normal.resource_path))
	_判(_色近((查.get_node("文字") as Label).get_theme_color("font_color"), 色表["钮按下"]), "按下字色 #acadb2")
	await _松开(查位)
	_判(String(查.texture_normal.resource_path) == 基名 + ".png",
			"松手（鼠标还停在钮上）⇒ 回常态那张，不是停在悬停档（实得 %s）" % String(查.texture_normal.resource_path))
	## 另外三颗：**悬停那一腿真走**（悬停不触发业务，安全）；按下/松手那一腿以上面那颗为准。
	## ⚠ 不用 `Callable.get_bound_parameters()` 查"接的是哪一档"—— Godot 4.7 的 Callable **没有这个方法**
	## （实测 parse 直接炸），也别退回"我只记得我接过了"那种自证。
	for 名 in ["主钮", "次钮"]:
		var 钮 := 页.get_node(名) as TextureButton
		var 基 := String(钮.get_meta("skin"))
		await _挪到(钮.get_global_rect().get_center())
		_判(String(钮.texture_normal.resource_path) == 基 + "_悬停.png",
				"%s 悬停 ⇒ 换成 _悬停 那张（实得 %s）" % [名, String(钮.texture_normal.resource_path).get_file()])
		_判(_色近((钮.get_node("文字") as Label).get_theme_color("font_color"), 色表["钮悬停"]),
				"%s 悬停字色 = #ffffc3" % 名)
	## 放入/购买这两颗在**被求档是隐藏的**（`isProposa:201-204`）⇒ 这里只查接法与皮基名，
	## 真悬停由 ⑭ 之后重新灌成发起档再走一遍（隐藏件不吃 GUI 命中，硬点必然假红）。
	for 名 in ["放入钮", "购买钮"]:
		var 钮 := 页.get_node(名) as TextureButton
		for 条 in ["mouse_entered", "mouse_exited", "button_down", "button_up"]:
			var 接: Array = (钮.get(条) as Signal).get_connections()
			var 中 := false
			for 元 in 接:
				if String((元.callable as Callable).get_method()) == "_设态":
					中 = true
			_判(中, "%s 的 `%s` 接到了 `_设态`（实得 %d 条连接）" % [名, 条, 接.size()])
	## 移开鼠标：让两颗钮回常态，别把悬停档带进下面那一段真点。
	await _挪到(Vector2(480.0, 520.0))
	for 名 in 钮档:
		var 钮 := 页.get_node(名) as TextureButton
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s = 手型光标（`MButton3.init():135`）" % 名)
		_判(absf(钮.size.x - float(钮档[名])) < 0.51,
				"%s 宽 = %d（`UIConfig.as:964/968/970` 写死的档宽，不是文字量出来的），实得 %.0f"
				% [名, 钮档[名], 钮.size.x])
		_判(String(钮.get_meta("skin")).ends_with("钮底%d" % int(钮档[名])),
				"%s 的皮基名 = 钮底%d，实得 %s" % [名, 钮档[名], String(钮.get_meta("skin")).get_file()])
		_判(钮.texture_hover == null and 钮.texture_pressed == null,
				"%s **不设** texture_hover/_pressed（松手要回 up）" % 名)
	_判(页.get_node("查看资料钮/文字") != null and String((页.get_node("查看资料钮/文字") as Label).text) != "",
			"状态机没把钮里的字清空")

	# ── ⑪ 被求档的「拒绝」：窗关掉（那一发 `127:22` 离线量不到 ⇒ 记在下面那条未判里）──
	await _真点(页.get_node("次钮") as TextureButton)
	_判(not _开着(窗), "被求档点「拒绝」⇒ 窗关掉（`ProposalWindow.onClickCancelBtn:108-115`）")

	# ── ⑫⑬⑭ 三条闸只能量在**发起档**上：被求档那两颗取件/购买钮是隐藏的（隐藏件不吃 GUI 命中，
	##   在那里点必然假红），而"没放对戒"这道 return 本来就是发起档的分支（`:80-84`）。
	var 窗发: Node = null
	var 页发: Control = null
	管理.call("全部关闭")
	await _等几帧(2)
	_收(后, 甲十四)
	await _等几帧(6)
	窗发 = 管理._窗口们.get("羁绊申请") as Node
	页发 = _找页(窗发)
	_判(页发 != null, "关掉被求那一扇、再喂 `61:14` ⇒ 发起档这一页建出来了（三条闸量在它身上）")
	if 页发 == null:
		_早退()
		return
	_判(求婚脚本._挑对戒(后) == 0, "背包空的 ⇒ 挑不出对戒（实得 %d）" % 求婚脚本._挑对戒(后))
	提示.clear()
	await _真点(页发.get_node("主钮") as TextureButton)
	_判(提示.size() == 1 and String(提示[0]).contains("请先放入羁绊对戒"),
			"没放对戒 ⇒ 说「请先放入羁绊对戒」且**不发帧**（`ProposalWindow.as:80-84`），实得 %s" % str(提示))
	_判(_找页(窗发) != null and _开着(窗发), "被拦下之后窗还开着（原版那一支是 return，不关窗）")
	## ⚠ 每一次都灌一份**新的类型化数组**：`authoritative_inventory` 是 `Array[Dictionary]`，
	## 无类型字面量 `set` 进去是**静默丢掉**的（实测 0 条）⇒ 那样这三条判据就成了"0 比 0 恒真"的假绿。
	_灌背包(后, [{"id": "19010001", "slot_index": -50, "quantity": 1}])
	_判(求婚脚本._挑对戒(后) == 0, "对戒**穿在身上**（slot_index=-50）不算 ⇒ 与服务端 `:22930-22938` 同一条闸")
	_灌背包(后, [{"id": "19099001", "slot_index": 3, "quantity": 1}])
	_判(求婚脚本._挑对戒(后) == 0, "号不在 `190[1-8]0001` 那八个里（19099001）⇒ 不算对戒")
	## ⚠ 上面那条**单独存在是判不出"号段闸被拆掉"的**（19099001 % 10000 = 9001，
	## 连 `% 10000 == 1` 这一半都不过 ⇒ 把整条算式简化成 `% 10000 == 1` 它照样挑不到，10-17 实测假绿）。
	## ⇒ 还得各喂一件**只坏在半截算式上**的：一位坏 `%10000`、一位坏 `190[1-8]` 那一段。
	_灌背包(后, [{"id": "19010002", "slot_index": 3, "quantity": 1}])
	_判(求婚脚本._挑对戒(后) == 0, "末四位是 0002（19010002）⇒ 不算对戒（钉 `% 10000 == 1` 那半截）")
	_灌背包(后, [{"id": "19090001", "slot_index": 3, "quantity": 1}])
	_判(求婚脚本._挑对戒(后) == 0, "阶是 9（19090001，末四位对）⇒ 不算对戒（钉 `阶 <= 8` 那半截）")
	_灌背包(后, [{"id": "18010001", "slot_index": 3, "quantity": 1}])
	_判(求婚脚本._挑对戒(后) == 0,
			"末四位对、阶也对，但号在 19010001 之下（18010001）⇒ 靠**那一段号域**挡下")
	_灌背包(后, [{"id": "19040001", "slot_index": 3, "quantity": 0}])
	_判(求婚脚本._挑对戒(后) == 0, "数量 0 ⇒ 不算有对戒")
	_灌背包(后, [{"id": "19040001", "slot_index": 3, "quantity": 2}])
	_判(求婚脚本._挑对戒(后) == 19040001, "背包里那件 19040001 ⇒ 挑得到（实得 %d）" % 求婚脚本._挑对戒(后))
	_判(int((后.get("authoritative_inventory") as Array).size()) == 1,
			"上面那一条**不是**因为背包空才挑不到：夹具真灌进去 1 件（实得 %d 件）"
			% (后.get("authoritative_inventory") as Array).size())
	提示.clear()
	await _真点(页发.get_node("放入钮") as TextureButton)
	_判(提示.size() == 1 and String(提示[0]).contains("已放入"),
			"点「放入羁绊戒」⇒ 挑一件并说「已放入…（阶 4）」，实得 %s" % str(提示))
	_判((页发.get_node("对戒格/对戒图") as TextureRect).texture != null, "放入以后第一格里有图了")
	var 缓存: Dictionary = 窗发.get("_求婚") if 窗发.get("_求婚") is Dictionary else {}
	_判(int(((缓存.get("人") if 缓存.get("人") is Dictionary else {}) as Dictionary).get("item", 0)) == 19040001,
			"挑到的号写回宿主缓存（重渲染不会把格子洗白），实得 %s" % str(窗发.get("_求婚")))
	后.set("authoritative_spouse", {"charId": 9999, "name": "别人", "face": 0, "job": 0, "hunjieId": 0})
	提示.clear()
	await _真点(页发.get_node("主钮") as TextureButton)
	_判(提示.size() == 1 and String(提示[0]).contains("你已经建立了羁绊啦"),
			"已经结过 ⇒ 说 BUYAO_ZHAOSANBUSILE 那一句、**不再发第二求**（`:85-89`），实得 %s" % str(提示))
	后.set("authoritative_spouse", {"charId": 0, "name": "", "face": 0, "job": 0, "hunjieId": 0})
	提示.clear()
	await _真点(页发.get_node("主钮") as TextureButton)
	_判(提示.size() == 1 and String(提示[0]).contains("羁绊请求已发送"),
			"过了两道闸 ⇒ 走发送那一条并说 QIUHUN_QINGJIU_YIFANGCONG（实得 %s）" % str(提示))
	_判(not _开着(窗发) or _找页(窗发) == null, "发完那一句以后窗自己关掉（`:94` 末尾 `onClickCancelBtn(null)`）")
	_判((窗发.get("_求婚") if 窗发 != null else {}) is Dictionary
			and (窗发.get("_求婚") as Dictionary).is_empty(),
			"关窗把宿主缓存清了（不清 ⇒ 下一任求方带着上一任的对戒号），实得 %s" % str(窗发.get("_求婚")))

	# ── ⑮ 换第二任求方 ⇒ 整页跟着换人、不吃上一任的缓存与对戒 ──────────────
	窗发.set("_求婚", {"是被求": false, "人": {"name": "求方乙", "level": 44, "job": 1,
			"banghui": "暗部", "face": 10000205, "charId": 2002, "item": 19030001}})
	管理.call("打开", "羁绊申请")
	await _等几帧(6)
	var 页二 := _找页(窗发)
	_判(页二 != null and (页二.get_node("名字") as Label).text == "名字：求方乙",
			"重新灌一份 ⇒ 页重建且第一行是**新那位**（实得「%s」）"
			% ((页二.get_node("名字") as Label).text if 页二 != null else "‹没建页›"))
	_判(页二 != null and (页二.get_node("放入钮") as Control).visible,
			"这一份是**发起档** ⇒ 那两颗取件钮又回来了（档位真按数据切，不是烘死在场景里）")
	var 戒路 := ""
	if 页二 != null and (页二.get_node("对戒格/对戒图") as TextureRect).texture != null:
		戒路 = String((页二.get_node("对戒格/对戒图") as TextureRect).texture.resource_path)
	_判(戒路.contains("19030001"),
			"新那位的对戒号 19030001 画进第一格（不吃上一任那枚 19040001），实得「%s」" % 戒路.get_file())
	_判(页二 != null and String(窗发.get_node("遮罩/主窗口/标题").text) == "发起羁绊",
			"发起档标题 = PROPOSA_WINDOW_TITLE（实得「%s」）" % String(窗发.get_node("遮罩/主窗口/标题").text))
	管理.call("全部关闭")
	await _等几帧(3)

	# ── ⑯ `61:18` ⇒ 那一句（名字替进 %1 的位置）────────────────────────────
	收十八.clear(); 提示.clear()
	_收(后, 丙十八)
	await _等几帧(2)
	_判(收十八.size() == 1 and String((收十八[0] as Dictionary).get("name", "")) == "拒绝者丙",
			"`61:18` ⇒ bond_refused_received{name}（实得 %s）" % str(收十八))
	_判(提示.size() == 1 and String(提示[0]) == "真遗憾，拒绝者丙拒绝了您的羁绊请求，再努努力吧！",
			"消费者把名字替进 DUIFANG_JUJUE_JIEHUN_QINGQIU 的 %%1 位（实得 %s）" % str(提示))

	# ── ⑰ `61:19/20` 与 `61:13` ⇒ 同一份权威配偶 ───────────────────────────
	收结.clear()
	_收(后, 丁十九)
	await _等几帧(2)
	_判(收结.size() == 1, "`61:19` ⇒ bond_established_received（实得 %d 条）" % 收结.size())
	var 婚: Dictionary = 后.get("authoritative_spouse") as Dictionary
	_判(int(婚.get("charId", 0)) == 2001 and String(婚.get("name", "")) == "求方甲"
			and int(婚.get("hunjieId", 0)) == 19010001 and int(婚.get("job", 0)) == 2,
			"`19` 写成权威配偶（charId/name/hunjieId/job 四位对齐原版那个对象），实得 %s" % str(婚))
	_收(后, 戊二十)
	await _等几帧(2)
	var 婚2: Dictionary = 后.get("authoritative_spouse") as Dictionary
	_判(int(婚2.get("charId", 0)) == 2002 and String(婚2.get("name", "")) == "求方乙",
			"`20` 同形、写的是**同意方**那一份，实得 %s" % str(婚2))
	_收(后, 己十三)
	await _等几帧(2)
	var 婚3: Dictionary = 后.get("authoritative_spouse") as Dictionary
	_判(int(婚3.get("charId", 0)) == 2001 and int(婚3.get("hunjieId", 0)) == 19010001,
			"登录补发 `61:13` 也写同一份（`:22285-22291`），实得 %s" % str(婚3))
	for 短 in ["61:14:甲:30:2:族:10000204", "61:17:甲:30:2:族:10000204:2001",
			"61:18", "61:19:2001:19010001:甲:10000204", "61:13:2001:甲:2", "61:21:", "61:22:"]:
		var 前14 := 收十四.size(); var 前17 := 收十七.size()
		var 前18 := 收十八.size(); var 前结 := 收结.size()
		_收(后, 短)
		await _等几帧(1)
		_判(收十四.size() == 前14 and 收十七.size() == 前17 and 收十八.size() == 前18 and 收结.size() == 前结,
				"缺段的 `%s` 一条都不发" % 短)
	后.set("authoritative_spouse", {"charId": 0, "name": "", "face": 0, "job": 0, "hunjieId": 0})

	# ── ⑱ 发起档（`61:14` **直接开窗**，与族邀那一支相反）─────────────────
	管理.call("全部关闭")
	await _等几帧(2)
	收十四.clear()
	_收(后, 甲十四)
	await _等几帧(6)
	var 窗三: Node = 管理._窗口们.get("羁绊申请") as Node
	var 页三 := _找页(窗三)
	_判(窗三 != null and _开着(窗三) and 页三 != null,
			"喂 `61:14` ⇒ **不点任何格**，我这侧那扇直接开出来（`onFriend_taStart:9500`）")
	if 页三 != null:
		_判((页三.get_node("心意提示") as Label).text == "请问您是希望向TA发出羁绊请求吗？",
				"发起档 pane 提示 = CHARINFO_PANE_TISHI_TEXT_2（实得「%s」）" % (页三.get_node("心意提示") as Label).text)
		_判((页三.get_node("说明白字") as Label).text == "您需要先拥有羁绊对戒以示心意",
				"发起档窗级提示 = PROPOSA_WINDOW_NI_XUEYAO_CHENGYI（实得「%s」）" % (页三.get_node("说明白字") as Label).text)
		_判((页三.get_node("主钮/文字") as Label).text == "建立羁绊", "发起档主钮 = PROPOSA_WINDOW_QIUHUN")
		_判((页三.get_node("次钮/文字") as Label).text == "关闭", "发起档次钮 = DIALOG_BTN_STOP_DIALOG")
		_判((页三.get_node("放入钮") as Control).visible and (页三.get_node("购买钮") as Control).visible,
				"发起档 ⇒ 那两颗**看得见**")
		_判((页三.get_node("对戒格/对戒图") as TextureRect).texture == null,
				"刚开的发起档第一格是空的（没放东西就是空的，不自造占位图）")
		提示.clear()
		await _真点(页三.get_node("次钮") as TextureButton)
		_判(提示.is_empty(), "发起档点「关闭」⇒ **不发任何东西**（`:108-115` 那一档只 onCloseBtnClick），实得 %s" % str(提示))
	_判(not bool(后.call("request_bond_start", 0)), "邀 0 号 ⇒ false（`号 > 0` 那道闸还在）")
	_判(not bool(后.call("request_bond_invite", 2001, 0)), "对戒号 0 ⇒ false（那一发带的是**两个 int**）")
	_判(not bool(后.call("request_bond_accept", 0, 19010001)), "同意一个 0 号 ⇒ false")
	_判(not bool(后.call("request_bond_refuse", 0)), "拒绝一个 0 号 ⇒ false")
	print("未判（离线里判了就是假绿）：四条上行的**包体字节**（127:15/20/21/22 各段顺序与宽度）"
			+ "与「空号闸在活连接上真的不发帧」——无头没有 TCP，`send_game_request` 第一行就 return false，"
			+ "闸挡的和没连接挡的在这里分辨不出 ⇒ 归在线门 §⑧（那两发真出得去、服务端真按段序解出来了）。")

	# ── ⑲ 尺寸表 / 素材 / 场景在盘上 ────────────────────────────────────
	管理.call("全部关闭")
	await _等几帧(2)
	var 表 := JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/窗口尺寸.json")) as Dictionary
	var 规: Dictionary = 表.get("羁绊申请", {}) as Dictionary
	_判(int(规.get("宽", 0)) == 388 and int(规.get("高", 0)) == 475 and bool(规.get("整框", false)),
			"尺寸表「羁绊申请」= 388×475 整框:true（实得 %s）" % str(规))
	_判(String(规.get("标题", "")) == "发起羁绊", "表里那条标题 = 默认档「发起羁绊」（另一档由渲染改写）")
	_判(规.get("内容底") == false, "这页自己画 MYellow ⇒ 外壳那张不能再叠第二遍")
	for 皮 in ["res://素材/界面/原版窗口/通用控件/内容面板.png", "res://素材/界面/原版窗口/通用控件/子面板.png",
			"res://素材/界面/原版窗口/通用控件/物品格.png", "res://素材/界面/原版窗口/好友/钮底61.png",
			"res://素材/界面/原版窗口/好友/钮底37.png", "res://素材/界面/原版窗口/好友/钮底70.png",
			"res://素材/界面/原版窗口/好友/钮底70_悬停.png", "res://素材/界面/原版窗口/好友/钮底70_按下.png",
			"res://素材/界面/原版窗口/通用控件/托盘_求婚.png"]:
		_判(ResourceLoader.exists(皮), "%s 在（这页要用的皮）" % 皮.get_file())
	_判(FileAccess.file_exists(场景路径) and FileAccess.file_exists("res://脚本/界面/窗口/家族/求婚窗.gd"),
			"场景与控制器都在盘上（preload 断了会整个功能窗口 parse 失败）")

	# ── ⑳ 五支的段数闸写在源码哪一档（**判的是文本，不是行为**，原因写在下面）────────
	## 把 `if fields.size() < 8:` 拆掉以后，缺段那一帧**不会多发**：它会走到 `fields[7]`
	## 下标越界、当场报错中断，信号照样是 0 条 ⇒ ②/⑰ 那种"喂完前后一样多"的行为判据
	## **两边都成立**（10-17 变异 P1 实测：闸拆了、门仍 220 全绿）。这一族只能钉源码文本，
	## 并且把"我钉的是文本"写在判据里，别让它冒充行为证据。
	var 源 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	var 起 := 源.find("func _handle_friend_text")
	var 止 := 源.find("\nfunc ", 起 + 1)
	var 体 := 源.substr(起, 止 - 起) if 起 >= 0 and 止 > 起 else ""
	_判(体 != "", "切到了 `_handle_friend_text` 的函数体（切不到 ⇒ 下面十条都是假绿，先红这条）")
	var 臂 := _臂表(体)
	for 条 in [["13", 6], ["14", 8], ["17", 9], ["18", 3], ["19, 20", 7]]:
		var 名: String = String(条[0])
		var 少 := int(条[1])
		var 内: String = String(臂.get(名, ""))
		_判(内 != "", "臂表里找得到 `%s` 这一支（阳性对照：整支没切到就是这条红）" % 名)
		_判(内.contains("if fields.size() < %d:" % 少),
				"`%s` 那一支的段数闸写的是 `< %d`（源码核对；这一支前 90 字=%s）" % [名, 少, 内.substr(0, 90)])

	# ── ㉑ 背包那三个键名**必须与服务端 58 帧解出来的那一份同名**（源码核对）──────────
	## 10-17 这条是**在线门 §⑧ 逮到的**，不是离线门：`_挑对戒` 原先读 `item_id` / `position` / `count`
	## —— 那三个键是我自己编的，而喂给它的夹具字典**照抄了同一套自造键** ⇒ 两边一起错、互相印证，
	## 239 条全绿而真机上「放入羁绊戒」永远回"请先放入羁绊对戒"。⇒ 键名这种"两边约定"的东西
	## 必须拿**对面那一份的源码**当参照值（这里就是 `_parse_item_entry`），不能拿被测代码自己的键。
	var 服源 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	var 解起 := 服源.find("func _parse_item_entry")
	var 解止 := 服源.find("\nfunc ", 解起 + 1)
	var 解体 := 服源.substr(解起, 解止 - 解起) if 解起 >= 0 and 解止 > 解起 else ""
	_判(解体 != "", "切到了 `_parse_item_entry` 的函数体（切不到 ⇒ 下面三条参照值全是假的）")
	for 键 in ["\"id\": item_id", "\"slot_index\": slot_index", "\"quantity\": int(values[3])"]:
		_判(解体.contains(键), "服务端那条帧解出来带的键 = %s（参照值取自**解析器自己**）" % 键)
	var 控源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/家族/求婚窗.gd")
	var 挑起 := 控源.find("static func _挑对戒")
	var 挑止 := 控源.find("static func _是对戒")
	var 控体 := 控源.substr(挑起, 挑止 - 挑起) if 挑起 >= 0 and 挑止 > 挑起 else ""
	_判(控体 != "", "切到了 `_挑对戒` 那一段（切不到 ⇒ 下面三条又是假的）")
	for 读 in ["get(\"id\", 0)", "get(\"slot_index\", 0)", "get(\"quantity\", 0)"]:
		_判(控体.contains(读), "`_挑对戒` 读的键里有 %s（与上面那三条同名 ⇒ 两边是同一份约定）" % 读)
	跑完了 = true
	print("求婚窗离线门：通过 %d，红 %d" % [通过, 失败])
