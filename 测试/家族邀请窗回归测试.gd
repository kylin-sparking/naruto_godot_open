extends SceneTree
## 家族邀请窗（原版 `MPromptWindow.popupHasPlayerInfoWindow`）离线门。
## 逐件参照值手抄自 `真值/窗口/家族邀请窗.md`（AS3 与服务端行号都在那张表里），
## **不从被测场景反查** —— 场景和门一起写错就永远绿。
##
## 覆盖：① `1552:16` 那一帧**逐字段**解出来（两个 id 不许混）② 段数不够 ⇒ 一帧都不发
## ③ 收到帧只塞托盘、**不开窗**（原版 `FamillyManager:339-343` 就是塞 `CueGird`）
## ④ 去重键 = `charId`（`CueManage.checkExist:113-150` 家族那一支）+ 入场补间真在跑
## ⑤ **真鼠标**点那一格 ⇒ 窗开、页建、填的是被点那格的人 ⑥ 逐件矩形 + 层序（addChild 原序）
## ⑦ 三行文字/正文/等级职业两行 + 四个颜色 + 行距 ⑧ 头像按 face 取到图
## ⑨ 三颗钮的文字/手型/宽档 ⑩ 三态换皮与松手回常态（MButtonF = MButton3 一族）
## ⑪ 点「拒绝」/「同意加入」⇒ 关窗**并把缓存清掉** ⑫ 换第二任族长 ⇒ 页跟着换人
## ⑬ 三条上行的空号闸 ⑭ 尺寸表 / 居中弹 / 场景在盘上
##
## ⚠ 三条量法口径（10-17 本轮现学到，每条都是先跑红才发现的）：
## 1. 托盘那格入场是 **2 秒补间**（`邀请托盘.入场秒` ← `CueManage` 的 `TweenLite.to(_,2,…)`），
##    没落地时它停在 x=10 ⇒ **两格都在 x=10 会互相压着**，必须先等落位、且一次只点一格。
## 2. 按下去之后**必须把同一屏幕位的松开补上**：那一格在派发时自删，
##    拿节点去算松开位会 `previously freed` 报错、松手整个被跳过 ⇒ 视口停在"左键还按着"，
##    后面所有悬停/点击全被吞（第一版就是这么"钮没反应"的）。⇒ 按下与松开都用**坐标**。
## 3. 鼠标**大距离瞬移**不触发 `mouse_entered`（同帧视口只按最后一条 motion 拾取）
##    ⇒ `_挪到` 走"中点 → 目标"两跳。
##
## 跑法：`"godot" --path . --headless --script res://测试/家族邀请窗回归测试.gd`

const 场景路径 := "res://场景/界面/窗口/家族/家族邀请窗.tscn"
const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 职业表 := preload("res://脚本/单例/职业.gd")
## 九宫格边距的**唯一事实源**是这张表（与主题生成器同源），门在这儿现取现比：
## `.tscn` 里把 `patch_margin_*` 写成 `texture_margin_*` 是**静默丢掉**的（NinePatchRect 没这个属性），
## 结果整张皮被拉平、几何门照样全过 —— 10-17 就在这页上踩过，所以钉一条独立参照。
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

## §③ 页局部 = AS3 − 29（`整框: true`）。三颗钮的宽 = 文字宽 + 6（`MButton3.as:383`，
## 「查看资料」「同意加入」各 4 字 ⇒ 54，「拒绝」2 字 ⇒ 30），x 按 `:260-262` 那三行算式。
const 逐件 := {
	"内容底": [8.0, 9.0, 248.0, 97.0],		# MYellow_background (8,38) 264−16 × 165−68
	"头像格": [16.0, 17.0, 40.0, 40.0],		# MGrid_background (_contentBg.x+8, _contentBg.y+8)
	"族长名": [62.0, 17.0, 140.0, 18.0],		# MGlowLabel UI_BLUE (格.x+46, 格.y)
	"等级职业": [202.0, 17.0, 48.0, 38.0],	# TextArea2 宽 48、leading 4 ⇒ 盒高 15×2+4+4
	"族名": [62.0, 35.0, 140.0, 18.0],		# MGlowLabel UI_WHITE (名字.x, 名字.y+18)
	"分隔线": [11.0, 61.0, 242.0, 2.0],		# LineHPicF (_contentBg.x+3, 格.y+44) 宽 248−6
	"正文": [16.0, 67.0, 232.0, 34.0],		# TextArea2 UI_ORANGE 宽 248−16，两行 ⇒ 15×2+4
	"查看资料钮": [53.0, 109.0, 54.0, 22.0],	# :260 (264−54−54−30−20)/2
	"同意钮": [117.0, 109.0, 54.0, 22.0],		# :261 53+54+10
	"拒绝钮": [181.0, 109.0, 30.0, 22.0],		# :262 117+54+10
}
## `createChildren:236-249` 先建 ok/cancel，`createHasPlayerInfoWindow:180-232` 才加其余
## ⇒ 页里的层序就是这个数组的顺序（不是场景文件的书写顺序，也不是按名字排）。
const 层序 := ["内容底", "同意钮", "拒绝钮", "查看资料钮", "头像格",
		"族长名", "等级职业", "族名", "分隔线", "正文"]
const 钮文字 := {"查看资料钮": "查看资料", "同意钮": "同意加入", "拒绝钮": "拒绝"}
## 每颗钮该落在哪一档宽（`MButtonF.isScale9Grid` ⇒ 文字 + 6，工程按档预烘皮）
const 钮档 := {"查看资料钮": 54, "同意钮": 54, "拒绝钮": 30}
## 四个颜色的真值。⚠ 一律走 `Color(字符串)`：`Color(0x1E90FF)` 在 Godot 4 里不是"按十六进制取色"
## 那个构造器，写进去会拿到一个离谱的浮点数（本轮就是这么误报红的）。
## UIConfig：UI_BLUE 2003199=#1e90ff、UI_WHITE 16777215=#ffffff、UI_ORANGE 16748800=#ffa000；
## `TextArea2.as:22` 默认参就是 16777215 ⇒ 右列不分色。
const 色表 := {
	"族长名": Color("#1e90ff"), "族名": Color("#ffffff"),
	"等级职业": Color("#ffffff"), "正文": Color("#ffa000"),
	"钮常态": Color("#fcf49c"), "钮悬停": Color("#ffffc3"),
}
## face 用真存在的头像号（`素材/原版直解/Char/Char_10000204…_info_portrait.png`）——
## 编一个没有的号会让这条判据变成"量具自己取不到图"，不是产品错（本轮踩过）。
const 甲帧 := "1552:16:测试族长甲:30:2:10000204:木叶之火:2001:77"
const 乙帧 := "1552:16:测试族长乙:44:1:10000205:暗部:2002:88"

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 收帧: Array = []
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


## 把视口钉成 960×560。⚠ **一次设不成**：无头下 `root.size = (960,560)` 第一帧会被夹回
## `min_size` 的 64×64 并且就留在那儿（实测），于是"居中弹"按 64×64 居中 ⇒ 页里那三颗钮
## 落在屏幕之外 ⇒ `push_input` 全部落空、悬停/点击静默无反应，看着像"钮坏了"。
## ⇒ 每帧重设直到 `get_visible_rect()` 真的等于 960×560，并且**这条本身要当判据**：
## 钉不住就是量具坏了，宁可报红也不许往下跑出一屏假绿。
func _钉视口() -> void:
	for i in 60:
		if root.get_visible_rect().size != Vector2(960.0, 560.0):
			root.size = Vector2i(960, 560)
		await process_frame
	_判(root.get_visible_rect().size == Vector2(960.0, 560.0),
			"视口钉到 960×560（实得 %s，root.size=%s）—— 钉不住则下面所有真点判据都不算数"
			% [str(root.get_visible_rect().size), str(root.size)])


## 服务端 `_send_family_invitation:22296-22313` 的原文形状写在上面的两个 const 里。
## ⚠ 段序**不是手写的猜测**：逐条抄 `fake_flash_server.py:22310-22313` 那个 f-string
## （name / level / job / face / family name / leader_id / family_id），
## 在线门 §⑦ 再用真服务端把同一串打到本端对一次 ⇒ 这里错了那边就红。
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


## 鼠标挪到位：先跳**中点**再跳目标（两帧两跳）。一帧瞬移不触发 `mouse_entered`。
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


## 按下/松开**只认屏幕位**：被点的格会在派发那一刻自删，
## 再拿那个节点算松开位就报 `previously freed` ⇒ 松手被整个跳过 ⇒ 视口停在"左键还按着"，
## 之后每一次悬停和点击都被吞（第一版的"三态没反应"根本原因是这个，不是产品）。
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


## 真鼠标点一件（挪过去 → 按下 → 松开）。不许 `emit_signal("pressed")` 演。
func _真点(件: Control) -> void:
	if not is_instance_valid(件):
		return
	var 屏: Vector2 = 件.get_global_rect().get_center()
	await _挪到(屏)
	await _按下(屏)
	await _松开(屏)


## 等托盘那格的 2 秒入场补间走完（不落位 ⇒ 几格全叠在 x=10，点谁都不一定）。
## ⚠ 按**墙钟**等而不是等固定帧数：无头没 vsync，一秒能跑几千帧，而补间按真实时间走。
func _等落位() -> void:
	var 起 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 起 < 2600:
		await process_frame


## ⚠ `功能窗口` 的根是 **CanvasLayer** ⇒ 别 `as Control`；判"开没开"问它自己的 `_overlay.visible`。
func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


func _找页(窗: Node) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String((子 as Node).name) == "原版家族邀请内容":
			return 子 as Control
	return null


func _早退(管理: Node) -> void:
	跑完了 = true
	print("家族邀请窗离线门：通过 %d，红 %d" % [通过, 失败])


func _跑() -> void:
	print("家族邀请窗离线门开始")
	await _钉视口()
	await process_frame
	var 后: Node = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("authoritative_guild", {})
	收帧.clear()
	后.connect("family_invite_received", func(邀: Dictionary) -> void: 收帧.append(邀))
	await process_frame
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame
	var 盘 = 管理.get_node_or_null("邀请托盘")
	_判(盘 != null, "窗口管理底下有「邀请托盘」这一层（实得 %s）" % str(盘))
	if 盘 == null:
		_早退(管理)
		return
	盘.call("清空")
	await process_frame

	# ── ① 逐字段解码（两个 id 混用 = 同意那一发永远换不回）────────────────
	_收(后, 甲帧)
	for i in 2:
		await process_frame
	_判(收帧.size() == 1, "喂一帧 `1552:16:…` ⇒ 发一条 family_invite_received（实得 %d 条）" % 收帧.size())
	if 收帧.is_empty():
		_早退(管理)
		return
	var 邀: Dictionary = 收帧[0] as Dictionary
	var 期望 = {
		"name": "测试族长甲", "playerName": "测试族长甲", "level": 30, "job": 2,
		"face": 10000204, "famillyName": "木叶之火", "charId": 2001, "id": 77,
	}
	for 键 in 期望:
		_判(邀.has(键) and str(邀[键]) == str(期望[键]),
				"解出来的 `%s` == `%s`（实得 `%s`；全字典=%s）" % [键, 期望[键], 邀.get(键, "‹没有这个键›"), str(邀)])
	_判(int(邀.get("charId", 0)) != int(邀.get("id", 0)),
			"两位 id 本来就该不同：charId=族长角色号 2001、id=家族号 77（相等说明把同一格填了两遍）")

	# ── ② 段数不够 ⇒ 一帧都不发（半个窗比不弹更糟：会弹一扇名字空白、点同意发族号 0 的窗）──
	var 前 := 收帧.size()
	_收(后, "1552:16:测试族长甲:30:2:10000204:木叶之火:2001")
	_收(后, "1552:16:测试族长甲")
	for i in 2:
		await process_frame
	_判(收帧.size() == 前, "缺段的那两帧被丢掉（前 %d → 后 %d）" % [前, 收帧.size()])

	# ── ③ 收到帧只塞格，不开窗 ────────────────────────────────────────────
	_判(int(盘.call("数量")) == 1, "一帧 ⇒ 托盘一格（实得 %d）" % int(盘.call("数量")))
	var 甲格: Control = 盘.最后一格()
	var 图: TextureRect = 甲格.get_node_or_null("图标") as TextureRect
	_判(图 != null and 图.texture != null and String(图.texture.resource_path).contains("托盘_家族邀请"),
			"那一格的图标 = 原版家族邀请那枚（实得 %s）" % (
				图.texture.resource_path if 图 != null and 图.texture != null else "（无）"))
	var 窗: Node = 管理._窗口们.get("家族邀请") as Node
	_判(窗 == null or not _开着(窗), "收到帧**不开窗**（原版只 addMsg，点格才 popup）")

	# ── ④ 去重键 = charId：同一个族长再邀一次只一格；换族长才两格 ──────────
	_收(后, 甲帧)
	_判(int(盘.call("数量")) == 1, "同一个族长再发一次 ⇒ 还是一格（实得 %d）" % int(盘.call("数量")))
	_收(后, 乙帧)
	_判(int(盘.call("数量")) == 2, "换一个族长 ⇒ 两格（实得 %d）" % int(盘.call("数量")))
	await _等落位()
	## 落位判据（钉住"入场补间真的在跑"，也钉住"门为什么必须等"）：
	## 原版 `CueManage` 的 `TweenLite.to(_, 2, {x: nextX})` ⇒ 从 x=10 飞到 380 / 340。
	var 乙格: Control = 盘.最后一格()
	_判(乙格 != null and 乙格.position.x > 300.0 and 甲格.position.x > 300.0
			and absf(甲格.position.x - 乙格.position.x) > 30.0,
			"两格都飞到各自槽位、不再互相压着（甲 x=%.0f 乙 x=%.0f；还叠在 x=10 就说明补间没跑完）"
			% [甲格.position.x, 乙格.position.x if 乙格 != null else -1.0])

	# ── ⑤ 真点**甲那一格** ⇒ 窗开、页建、填的是甲的数据 ────────────────────
	await _真点(甲格)
	窗 = 管理._窗口们.get("家族邀请") as Node
	_判(窗 != null and _开着(窗), "真点托盘那一格 ⇒ 窗自己开出来了（分发在 `窗口管理._on_托盘已点`）")
	if 窗 == null or not _开着(窗):
		_早退(管理)
		return
	var 页 := _找页(窗)
	_判(页 != null, "页本体「原版家族邀请内容」建出来了")
	if 页 == null:
		_早退(管理)
		return
	_判((页.get_node("族长名") as Label).text == "测试族长甲",
			"点的是甲那格 ⇒ 页里第一行就是「测试族长甲」（实得「%s」）"
			% (页.get_node("族长名") as Label).text)
	_判(int(盘.call("数量")) == 1, "点过的那格自己没了（`CueGird.onClickHand:345-351` 派发完就 destroy）")

	# ── ⑥ 逐件矩形 + 层序 ────────────────────────────────────────────────
	_判(absf(页.size.x - 264.0) < 0.51 and absf(页.size.y - 136.0) < 0.51,
			"页 = 264×136（整窗 264×165 − 标题栏 29），实得 %.0f×%.0f" % [页.size.x, 页.size.y])
	for 名 in 逐件:
		var 子 := 页.get_node_or_null(名) as Control
		_判(子 != null, "逐件：%s 在" % 名)
		if 子 == null:
			continue
		_判(_近(_矩形(子), 逐件[名]), "%s 矩形 = (%s)，实得 (%s)" % [名, 逐件[名], _矩形(子)])
	var 实际序: Array = []
	for 子 in 页.get_children():
		实际序.append(String((子 as Node).name))
	_判(实际序 == 层序, "层序 = addChild 原序 %s，实得 %s" % [str(层序), str(实际序)])

	## 九宫格件用的是哪张共享皮（边距按这张查，门里不写第二份数）。
	var 用哪张 := {"内容底": 皮肤表.内容面板, "头像格": 皮肤表.物品格}
	for 名 in 用哪张:
		var 块 := 页.get_node_or_null(名) as NinePatchRect
		_判(块 != null, "%s 是 NinePatchRect（九宫格件）" % 名)
		if 块 == null:
			continue
		var 组: Array = 皮肤表.九宫格[用哪张[名]]
		var 期 := [int(组[0]), int(组[1]), int(组[2]), int(组[3])]
		var 实 := [块.patch_margin_left, 块.patch_margin_right, 块.patch_margin_top, 块.patch_margin_bottom]
		_判(实 == 期, 名 + " 九宫格边距(左右上下) = " + str(期) + "（现取自 皮肤表.九宫格." + str(用哪张[名])
				+ "；写成 texture_margin_* 会被静默丢掉 ⇒ 整张皮拉平），实得 " + str(实))

	# ── ⑦ 三行文字 + 四个颜色 + 行距 ───────────────────────────────────────
	_判((页.get_node("族名") as Label).text == "木叶之火",
			"族名 = 帧里的家族名（实得「%s」）" % (页.get_node("族名") as Label).text)
	_判(_色近((页.get_node("族长名") as Label).get_theme_color("font_color"), 色表["族长名"]),
			"族长名 = UI_BLUE #1e90ff（MGlowLabel `:202`），实得 %s"
			% str((页.get_node("族长名") as Label).get_theme_color("font_color")))
	_判(_色近((页.get_node("族名") as Label).get_theme_color("font_color"), 色表["族名"]),
			"族名 = UI_WHITE（`:217`）")
	## `:215` 那一列 = `level + COMMON_JI + "\r" + getJobName(job)` ⇒ 两行、没有冒号没有空格
	var 列文 := String((页.get_node("等级职业") as RichTextLabel).text)
	_判(列文 == "30级\n" + 职业表.取(2),
			"右列两行 = 「30级」换行 + 职号 2 的名字，实得「%s」" % 列文.replace("\n", "⏎"))
	_判(_色近((页.get_node("等级职业") as RichTextLabel).get_theme_color("default_color"), 色表["等级职业"]),
			"右列 = TextArea2 默认白（`TextArea2.as:22` 默认参 16777215）")
	_判(int((页.get_node("等级职业") as RichTextLabel).get_theme_constant("line_separation")) == 6,
			"右列行距 = leading 4 + 2 = 6（工程口径），实得 %d"
			% int((页.get_node("等级职业") as RichTextLabel).get_theme_constant("line_separation")))
	_判(String((页.get_node("正文") as RichTextLabel).text) == "该玩家邀请你加入他的家族，请问你是否审核通过",
			"正文 = `FAMILLY_MANAGER_YAOQING_NI_JIARU` 一字不改（实得「%s」）"
			% String((页.get_node("正文") as RichTextLabel).text))
	_判(_色近((页.get_node("正文") as RichTextLabel).get_theme_color("default_color"), 色表["正文"]),
			"正文 = UI_ORANGE #ffa000（`new TextArea2(UIConfig.UI_ORANGE)` `:226`）")
	_判(not String((页.get_node("正文") as RichTextLabel).text).contains("<font"),
			"正文里没有漏转换的 `<font>` 标签")

	# ── ⑧ 头像按 face 取到图 ─────────────────────────────────────────────
	var 头 := 页.get_node("头像格/头像") as TextureRect
	_判(头 != null and 头.texture != null, "头像按 face=10000204 取到了图（PortraitHead TYPE_CHAR）")
	_判(头.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
			"头像格里的 TextureRect 不顶格子（expand_mode 必须是 IGNORE_SIZE，实得 %d）" % 头.expand_mode)

	# ── ⑨ 三颗钮：文字 / 手型 / 档宽 / 皮基名 ──────────────────────────────
	for 名 in 钮文字:
		var 钮 := 页.get_node(名) as TextureButton
		var 字 := 钮.get_node_or_null("文字") as Label
		_判(字 != null and 字.text == String(钮文字[名]),
				"%s 的文字 = 「%s」，实得「%s」" % [名, 钮文字[名], 字.text if 字 != null else "（没有文字节点）"])
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 是手型光标" % 名)
		_判(absf(钮.size.x - float(钮档[名])) < 0.51,
				"%s 宽 = 文字宽 + 6 = %d，实得 %.0f" % [名, 钮档[名], 钮.size.x])
		_判(钮.has_meta("skin"), "%s 带了皮肤基名（三态靠它换皮）" % 名)
		_判(_色近(字.get_theme_color("font_color"), 色表["钮常态"]),
				"%s 常态字色 = #fcf49c（`MButton3.as:69-74` up 那一档），实得 %s" % [名, str(字.get_theme_color("font_color"))])

	# ── ⑩ 三态：悬停 +30 / 按下 −40 / 松手回常态（断的是**真生效的图文件名**）──
	var 同 := 页.get_node("同意钮") as TextureButton
	var 基名 := String(同.get_meta("skin"))
	var 同位: Vector2 = 同.get_global_rect().get_center()
	await _挪到(同位)
	_判(String(同.texture_normal.resource_path) == 基名 + "_悬停.png",
			"悬停 ⇒ texture_normal 换成 _悬停 那张（实得 %s）" % String(同.texture_normal.resource_path))
	_判(_色近((同.get_node("文字") as Label).get_theme_color("font_color"), 色表["钮悬停"]),
			"悬停 ⇒ 字色换 #ffffc3（`MButton3.as:69-74` over 那一档）")
	await _按下(同位)
	_判(String(同.texture_normal.resource_path) == 基名 + "_按下.png",
			"按住 ⇒ 换成 _按下 那张（实得 %s）" % String(同.texture_normal.resource_path))
	await _松开(同位)
	## ⚠ 松手**还压在钮上**也必须回常态 —— 这就是工程里不许用 `texture_hover` 的理由：
	## Godot 松手后停在 hover 档，而原版 `mouseUpHandler:103-108` 回的是 STATE_UP。
	_判(String(同.texture_normal.resource_path) == 基名 + ".png",
			"松手（鼠标还停在钮上）⇒ 回常态那张，不是停在悬停档（实得 %s）" % String(同.texture_normal.resource_path))
	_判(同.texture_hover == null, "这颗钮**没有** texture_hover（有就必然和原版松手回哪一态打架）")
	_判(同.texture_pressed == null, "这颗钮**没有** texture_pressed（同上）")

	# ── ⑪ 点「拒绝」⇒ 关窗 + 缓存清掉，而且**不拿旧数据重开** ───────────────
	await _真点(页.get_node("拒绝钮") as TextureButton)
	_判(not _开着(窗), "点「拒绝」把窗关掉（`cancelHandler:396-410` 发完那一发就 onCloseBtnClick）")
	_判((窗.get("_家族邀请") as Dictionary).is_empty(),
			"关掉把宿主上的缓存清干净（实得 %s）" % str(窗.get("_家族邀请")))

	# ── ⑫ 第二任族长那一格 ⇒ 整页跟着换人，不吃上一任的缓存 ────────────────
	盘.call("清空")
	await process_frame
	_收(后, 乙帧)
	await _等落位()
	var 第二格: Control = 盘.最后一格()
	_判(第二格 != null and int((第二格.get("数据") as Dictionary).get("charId", 0)) == 2002,
			"重新塞进来的那格是族长乙（实得 %s）" % str(第二格.get("数据") if 第二格 != null else "没格"))
	if 第二格 != null:
		await _真点(第二格)
		var 页2 := _找页(窗)
		_判(_开着(窗) and 页2 != null and (页2.get_node("族长名") as Label).text == "测试族长乙",
				"点乙那一格 ⇒ 重开一页且第一行换成「测试族长乙」（实得「%s」）"
				% ((页2.get_node("族长名") as Label).text if 页2 != null else "没建页"))
		if 页2 != null:
			_判((页2.get_node("族名") as Label).text == "暗部"
					and String((页2.get_node("等级职业") as RichTextLabel).text).begins_with("44级"),
					"乙那页整页跟着换人：族名「暗部」、右列首行「44级」（实得「%s」/「%s」）" % [
						(页2.get_node("族名") as Label).text,
						String((页2.get_node("等级职业") as RichTextLabel).text).replace("\n", "⏎")])
			await _真点(页2.get_node("同意钮") as TextureButton)
			_判(not _开着(窗), "点「同意加入」也关窗（`okHandler:146-163` 的 `_viewType != 1` 恒真）")
			_判((窗.get("_家族邀请") as Dictionary).is_empty(),
					"同意这一发同样把缓存清掉（实得 %s）" % str(窗.get("_家族邀请")))

	# ── ⑬ 空号闸归在线门判，这里不许假称判得住 ───────────────────────────
	## 变异实测（`开发工具/_变异核族邀门.py` M4/M5/M6）抓到的一条**门的缺陷，不是产品的**：
	## 无头没有 TCP，`send_game_request` 第一行就 `return false` ⇒ 把 `号 > 0` 那道闸整个删掉，
	## 这里四条断言照样全过 —— "返回 false"这件事在无头里**分辨不出是闸挡的还是没连接挡的**。
	## ⇒ 判据搬去 `测试/头像信息在线回归测试.gd` §⑦（那边 socket 是活的，发得出去就是闸没挡住）。
	_判(后.has_method("request_family_invite") and 后.has_method("request_family_invite_accept")
			and 后.has_method("request_family_invite_reject") and 后.has_method("request_family_invite_by_name"),
			"三条上行 + 按名字那一发都在后端上（方法名就是在线门要点的那几个）")
	print("未判（改到离线门里就是假绿，故搬走）：邀 0 号 / 同意 0 号家族 / 拒绝 0 号家族 / 按名字查不到 ⇒ 不发帧，"
			+ "以及三条上行的**包体字节**与「按名字解析到号 ⇒ 真发出去」——无头没有 TCP，量不到；归在线门 §⑦。")

	# ── ⑭ 登记面 ─────────────────────────────────────────────────────────
	var 表 := JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/窗口尺寸.json")) as Dictionary
	var 规格: Dictionary = 表.get("家族邀请", {}) as Dictionary
	_判(int(规格.get("宽", 0)) == 264 and int(规格.get("高", 0)) == 165
			and bool(规格.get("整框", false)) and String(规格.get("标题", "")) == "邀请入族",
			"尺寸表：264×165、整框 true、标题「邀请入族」（实得 %s）" % str(规格))
	_判(管理.居中弹.has("家族邀请"), "这扇窗登记进了「居中弹」（`centerWindow(_, false)` 每次回正中）")
	_判(ResourceLoader.exists(场景路径), "场景在盘上：%s" % 场景路径)
	_判(ResourceLoader.exists("res://素材/界面/原版窗口/通用控件/横向分隔线.png")
			and ResourceLoader.exists("res://素材/界面/原版窗口/好友/钮底30.png")
			and ResourceLoader.exists("res://素材/界面/原版窗口/好友/钮底30_悬停.png"),
			"分隔线与 30 档三态皮都在盘上（少一张 ⇒ 那颗钮静默停在常态）")
	跑完了 = true
	print("家族邀请窗离线门：通过 %d，红 %d" % [通过, 失败])
