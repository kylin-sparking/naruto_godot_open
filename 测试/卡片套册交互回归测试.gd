extends SceneTree

## 「卡片套册收集」交互回归门（2026-10-04，用户实机打回「你做的全是死的」之后补的）。
##
## 盯的是**只有真鼠标能证明**的四件事，静态几何门一条都看不见：
##   ① 左列树**整行可点**：点叶换选中 + 填右列；点枝（整行或那枚 ⊕/⊖ 钮）开合这一枝，
##      并按原版 `treeItemClickHandler` 的 BranchNode 分支**清空右列 + 两钮置灰**；
##   ② `掉落怪物` 那一列是**可点链接**：悬停变 #FF0000 + 手型、移开回 #00FF00，
##      点一下有响应（原版是 `MovePlayerToMap` 寻路，本工程未接协议 ⇒ 落状态行）；
##   ③ 三列文本的**混色**与两枚钮的**可用/禁用**（`setBtnEnabled` 的三档）；
##   ④ **编辑器 == 运行期**：`.tscn` 里烘的开屏那一态（套卡名/五行/条内 `0/52`/五枚卡格图标）
##      必须与运行期 `渲染()` 画出来的**逐字相同** —— 数据一变而场景没重烘，这里就红。
##
## ⚠ 三条硬口径（都是这个工程踩过的）：
##   · `push_input` 前先钉 `root.size`（无头默认视口拿不到 GUI 命中，点了静默不生效）；
##   · 绝不用 `mouse_entered.emit()` 演绿 —— 全部走 `InputEventMouseMotion` + 隔 3 帧；
##   · 本门**不发真协议**（提交/领取那两支在线才发，这里用**假后端**收一次就够；寻路仍只落状态行）
##     ⇒ 不碰存档、不动角色。
##
## 运行：Godot --headless --path . --script res://测试/卡片套册交互回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 场景路 := "res://场景/界面/窗口/卡片套册/卡片套册窗.tscn"
var 场景文 := ""
const 页名 := "卡片套册"
const 页根 := "原版卡片套册内容"

const 绿 := Color(0, 1, 0)
const 红 := Color(1, 0, 0)

var 场景: Node
var 管: Node
var 窗: Node
var 页: Control
var 宿主: Node
var 红数 := 0
var 日志: Array[String] = []


## 假后端：只收不连，用来**看提交/领取到底发没发**（§3.120）。
class 假后端:
	extends Node
	var in_game := true
	var authoritative_card := {}
	var 提交: Array = []
	var 领取: Array = []

	func request_card_commit(级: int, 点: int) -> bool:
		提交.append([级, 点])
		return true

	func request_card_claim(级: int, 点: int) -> bool:
		领取.append([级, 点])
		return true

	func request_card_node(_级: int, _点: int) -> bool:
		return true

	func request_card_level(_级: int) -> bool:
		return true


func _记(过: bool, 文本: String) -> void:
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文本])


func _initialize() -> void:
	call_deferred("_run")



func _run() -> void:
	root.size = Vector2i(960, 560)
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	for _帧 in range(6):
		await process_frame
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	管.call("打开", 页名)
	窗 = 管.call("取或建窗口", 页名) as Node
	if 窗 == null:
		收尾("取或建窗口(%s) 给了 null" % 页名)
		return
	页 = _找(窗, 页根) as Control
	宿主 = 窗
	if 页 == null:
		收尾("找不到页根 %s ⇒ 页没建出来（递归找，不写死整条路径）" % 页根)
		return
	_记(String(页.get_path()).contains("页面容器/" + 页根),
			"页根挂在 遮罩/主窗口/页面容器 下（`功能窗口.gd:658`），实测 %s" % String(页.get_path()))
	for _帧 in range(3):
		await process_frame
	_量开屏()
	_备货()			# ⚠️ 必须在 `_点叶` **之前**：`可提交` 是"选中叶"那一刻按背包算的（见 §3.120）
	_记(宿主._背包数量(12100010) > 0, "备货：叶_40_2 那一套的卡要真进背包（实测 %d）" % 宿主._背包数量(12100010))
	await _点叶()
	await _点枝()
	await _点怪链()
	await _点提交()
	收尾("")


func _找(n: Node, 名: String) -> Node:
	if n == null:
		return null
	if String(n.name) == 名:
		return n
	for c in n.get_children():
		var 果 := _找(c, 名)
		if 果 != null:
			return 果
	return null


func 列() -> Control:
	return 页.get_node("树/树_内容") as Control


func 面板() -> Control:
	return 页.get_node("面板") as Control


func 文(件: Node) -> String:
	if 件 is RichTextLabel:
		return (件 as RichTextLabel).text
	if 件 is Label:
		return (件 as Label).text
	return "<不是文本件>"


## ── 真鼠标 ──────────────────────────────────────────────────────────────────

func 移到(位置: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位置
	移.global_position = 位置
	root.push_input(移)


func 点(位置: Vector2) -> void:
	移到(位置)
	for _帧 in range(2):
		await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位置
	按.global_position = 位置
	root.push_input(按)
	for _帧 in range(2):
		await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.button_mask = 0
	放.position = 位置
	放.global_position = 位置
	root.push_input(放)
	for _帧 in range(4):
		await process_frame


## ⚠ `点()` 是协程 ⇒ 必须 `await`，不然只跑到第一个 `await` 就返回，
##   断言会在事件还没发完的那一刻读状态（= 假红或假绿）。
func 点件(件: Control) -> void:
	if 件 == null:
		return
	await 点(件.get_global_rect().get_center())


## ── ① 开屏态 + ④ 编辑器一致 ──────────────────────────────────────────────────

func _量开屏() -> void:
	日志.append("=== 开屏（原版 setTreeData 末尾：展开第一枝 + 选第一枚叶）===")
	var 内 := 列()
	var 枝数 := 0
	var 叶数 := 0
	var 可见叶 := 0
	for 子 in 内.get_children():
		var 名 := String(子.name)
		if 名.begins_with("枝_"):
			枝数 += 1
		elif 名.begins_with("叶_"):
			叶数 += 1
			if 子.visible:
				可见叶 += 1
	_记(枝数 == 9 and 叶数 == 45, "树 = 9 枝 × 5 叶（数据/卡片.json 全量），实测 %d 枝 %d 叶" % [枝数, 叶数])
	_记(可见叶 == 5, "只有第一枝展开 ⇒ 可见叶 5，实测 %d" % 可见叶)

	# —— **三方**核对：运行期画的 == `.tscn` 里烘的 == 本门钉的真值常量。
	#   只比"运行期 vs 常量"是不够的：那样改了场景（编辑器露馅）门照样绿
	#   （2026-10-04 变异实测：手改 `行1_卡名` 的烘值 → 退出码还是 0）。
	var 面板件 := 面板()
	var 表 := {
		"面板_套卡名": "火影套卡",
		"面板_加成说明": "奖励：你将可获得10个潜能点的永久加成(系统随机分配)",
		"行1/行1_卡名": "[color=#00ff00]千手柱间卡[/color]",
		"行1/行1_数量": "[color=#ff0000]0[/color][color=#ffffff]/20[/color]",
		"行1/行1_掉落怪": "[url=mob1000017-105010000][u]通灵实验体[/u][/url]",
		"行5/行5_卡名": "[color=#00ff00]千手纲手卡[/color]",
		"行5/行5_数量": "[color=#ff0000]0[/color][color=#ffffff]/2[/color]",
		"行5/行5_掉落怪": "[url=mob1000019-105020000][u]吞灵土蛊[/u][/url]",
	}
	for 路 in 表:
		var 件 := 面板件.get_node_or_null(路)
		var 名: String = 路.split("/")[-1]
		_记(件 != null and 文(件) == String(表[路]),
				"运行期 %s = %s" % [名, 表[路]])
		_记(场景烘文本(名) == String(表[路]),
				"场景里烘的 %s 与运行期同一份（编辑器视图 = 游戏里那一屏），实测 %s"
				% [名, 场景烘文本(名)])
	var 条 := 面板件.get_node("面板_收集进度") as Control
	_记(文(条.get_node("值")) == "0/52",
			"条里那一行是 MBar 自己的 tf（`MBar.as:163`）= \"0/52\"，实测 %s" % 文(条.get_node("值")))
	var 图标表 := preload("res://脚本/单例/游戏数据.gd")
	for i in 5:
		var 格 := 面板件.get_node("卡格%d" % (i + 1)) as Control
		var 图 := 格.get_node_or_null(String(格.name) + "_图标") as TextureRect
		var 号: int = [12100000, 12100001, 12100002, 12100003, 12100004][i]
		_记(图 != null and 图.visible and 图.texture != null
				and 图.texture.resource_path == 图标表.item_icon_path(号),
				"卡格%d 图标 == 数据表 %d 的图标（烘进场景的那张与运行期同一张）" % [i + 1, 号])
	_记(文(面板件.get_node("面板_背包数量")) == "背包中的数量：",
			"「背包中的数量：」原版就是个标题（`packageItemCount` 从不更新）")

	var 提 := 页.get_node("提交钮") as Button
	var 领 := 页.get_node("领取钮") as Button
	_记(not 提.disabled, "选中叶 ⇒ 提交卡片可用（`setBtnEnabled` :268 btn1 恒 true）")
	_记(领.disabled, "未收集完成 ⇒ 领取奖励禁用（:260-267 finish=false）")
	var 禁皮 := 领.get_theme_stylebox("disabled", "") as StyleBoxTexture
	_记(禁皮 != null and String(禁皮.texture.resource_path).ends_with("领取钮_禁用.png"),
			"禁用档是**烘出来的灰皮**（getGrayFilter 预烘），不是 modulate：=%s"
			% (禁皮.texture.resource_path.get_file() if 禁皮 != null else "无"))
	_记(领.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "钮是手型光标")
	_记(页.get_node_or_null("文字提示_提交钮") != null, "提交卡片挂了原版那颗 tooltip（窗口 :101）")


## ── ② 点叶 ──────────────────────────────────────────────────────────────────

## 往背包里**只写内存**塞上「叶_40_2（40/2 木叶精英套卡）」真要的那几张卡 ——
## 不塞的话窗口的 `可提交` 恒 false，走的是「未满足收集条件」那一支，
## 下面"真发"的断言**一条都跑不到**（第一版就这么假绿过：反向对照只红了一条才发现）。
## ⚠️ 塞的必须是**这一套的 items**，随手塞 12100000 没用（窗口判的是这一套）。
func _备货() -> void:
	var 会话: Node = (宿主 as Node).get("_session")
	if 会话 == null:
		return
	var 表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/卡片.json")) as Dictionary
	var 套: Dictionary = ((表.get("40", {}) as Dictionary).get("2", {}) as Dictionary)
	for 卡 in (套.get("items", {}) as Dictionary).values():
		# ⚠️ JSON 里的数是 **float** ⇒ `str(12100010.0)` = "12100010.0"，
		#    而 `_背包数量` 拿 `int("12100010.0")` 是 **0**（不是合法整数字面量）⇒ 塞了等于没塞。
		#    必须先 `int()` 再 `str()`（工程里"JSON 数字是 float"那一族的老坑）。
		(会话.get("inventory") as Array).append({"id": str(int((卡 as Dictionary).get("id", 0))), "quantity": 1})


func _点叶() -> void:
	日志.append("=== 真鼠标点第三枚叶（40_2）===")
	var 内 := 列()
	var 新 := 内.get_node_or_null("叶_40_2") as Control
	var 旧 := 内.get_node_or_null("叶_40_0") as Control
	if 新 == null or 旧 == null:
		_记(false, "找不到 叶_40_2 / 叶_40_0")
		return
	await 点件(新)
	_记(新.get_node_or_null("选中底") != null, "点中 ⇒ 这一行铺上 MSelected_background1")
	_记(旧.get_node_or_null("选中底") == null, "旧选中行的底**被清掉**（不是叠两层）")
	_记(文(面板().get_node("面板_套卡名")) == "木叶精英套卡",
			"右列跟着换成第三套「木叶精英套卡」，实测 %s" % 文(面板().get_node("面板_套卡名")))
	_记(文(页.get_node("树/树_内容/叶_40_2/标签")) == "[color=#1e90ff]木叶精英套卡[/color][color=#ff0000](未完成)",
			"叶行是**两色**：名 #1e90ff + 状态 #ff0000（语言表 GUWAN_SHOUJI_WEIWAN_CHENG 逐字）")


## ── ③ 点枝（展开钮 + 整行两条路）─────────────────────────────────────────────

func _点枝() -> void:
	日志.append("=== 真鼠标点第二枝的 ⊕/⊖ 钮（50级收集）===")
	var 枝 := 列().get_node_or_null("枝_50") as Control
	if 枝 == null:
		_记(false, "找不到 枝_50")
		return
	var 钮 := 枝.get_node("展开钮") as TextureButton
	var 叶们: Array = []
	for 子 in 列().get_children():
		if String(子.name).begins_with("叶_50_"):
			叶们.append(子)
	var 展开前 := 0
	for 子 in 叶们:
		展开前 += 1 if (子 as Control).visible else 0
	await 点件(钮)
	var 展开后 := 0
	for 子 in 叶们:
		展开后 += 1 if (子 as Control).visible else 0
	_记(展开前 == 0 and 展开后 == 5, "点钮 ⇒ 这一枝 5 枚叶从藏到显（%d → %d）" % [展开前, 展开后])
	_记(String(钮.texture_normal.resource_path).ends_with("展开钮_选中.png"),
			"展开后钮换 **selectedUpSkin 真皮**（chid 603 ⊖），实测 %s"
			% String(钮.texture_normal.resource_path).get_file())
	_记(文(面板().get_node("面板_套卡名")) == "",
			"点枝清空右列（原版 `infoPanel.destory()`）⇒ 套卡名应为空，实测 %s" % 文(面板().get_node("面板_套卡名")))
	_记(文(页.get_node("面板/面板_收集进度/值")) == "0/0", "destory 后条是 0/0，实测 %s" % 文(页.get_node("面板/面板_收集进度/值")))
	_记((页.get_node("提交钮") as Button).disabled and (页.get_node("领取钮") as Button).disabled,
			"点枝 ⇒ 两钮都置灰（窗口 :148）")
	# 再点一次收回
	await 点件(钮)
	var 收 := 0
	for 子 in 叶们:
		收 += 1 if (子 as Control).visible else 0
	_记(收 == 0 and String(钮.texture_normal.resource_path).ends_with("展开钮.png"),
			"再点收回（%d 枚叶隐藏）且钮回 upSkin ⊕" % 收)


## ── ④ 掉落怪链接 ────────────────────────────────────────────────────────────

func _点怪链() -> void:
	日志.append("=== 真鼠标悬停 + 点「掉落怪物」链接 ===")
	# 先点回一枚叶，右列才有链接可点
	var 叶 := 列().get_node_or_null("叶_40_0") as Control
	await 点件(叶)
	var 掉 := 页.get_node("面板/行1/行1_掉落怪") as RichTextLabel
	_记(掉.mouse_filter == Control.MOUSE_FILTER_STOP, "链接件吃鼠标（STOP）")
	# ⚠ **分两跳**：同一帧只推一条 `MouseMotion` 时，视口只按最后一条做拾取，
	#   大距离瞬移不触发 `mouse_entered`（口径同 skill `flash-mbutton3-state-skins` 坑①）
	#   ⇒ 链接件自己那条 `gui_input` 也可能收不到。先跳到左边 30px 再进字里。
	var 心 := 掉.get_global_rect().get_center()
	移到(心 + Vector2(-30.0, 0.0))
	for _帧 in range(2):
		await process_frame
	移到(心)
	for _帧 in range(3):
		await process_frame
	var 悬色: Color = 掉.get_theme_color("default_color")
	_记(悬色 == 红, "悬停 → #FF0000（`StructuredText.as:719-722` a:hover），实测 %s" % 悬色.to_html(false))
	_记(掉.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "悬停 → 手型光标")
	移到(Vector2(4.0, 4.0))
	for _帧 in range(3):
		await process_frame
	var 常态: Color = 掉.get_theme_color("default_color")
	_记(常态 == 绿, "移开 → 回 #00FF00（COLOR_MONSTER），实测 %s" % 常态.to_html(false))
	(宿主 as Node)._status.text = ""
	await 点(掉.get_global_rect().get_center())
	# 2026-10-11 改：这一跳**接上了**（原版 `UI.as:769-775` 的 `case 2`：停挂机 +
	# `lockAutoMobId/lockAutoMapId` + `MovePlayerToMob` ⇒ 本工程 `会话.request_hang(false)`
	# + `玩家.开始自动接近(实体)`）。本门**只搭了窗、没有世界** ⇒ 那条路走到"找不到世界"为止；
	# **真走路那条**由带地图的门钉（同 `追踪找NPC回归测试` 那条口径）。
	_记(String((宿主 as Node)._status.text).contains("点掉落怪"),
			"⑧点链接有回应（接上之后：没世界就说找不到世界；**真走路**那条要带地图的门才量得到），实测 %s"
			% String((宿主 as Node)._status.text))


## ── ⑤ 提交卡片：原版那三支分支 ───────────────────────────────────────────────

func _点提交() -> void:
	日志.append("=== 真鼠标点「提交卡片」===")
	var 提 := 页.get_node("提交钮") as Button
	# 备货之后"有货"这件事的**判据是窗口自己的 `可提交`**（选中叶时按这一套的 items 算的），
	# 别再自己按 id 列表猜一遍（第一版就是那么猜的，结果和窗口不一致、断言跑错分支）。
	var 有货 := not 提.disabled
	# ⚠️ **先把"有货"那一支逼出来**：离线样例背包里没有套卡（`1210000x`），
	#    不塞一件的话 `期望` 恒是「未满足收集条件」⇒ **下面那两条"真发"的断言根本跑不到**
	#    （我自己第一版就是这样：反向对照只红了一条，才发现提交那条是死的）。只写内存、不落盘。
	var 期望 := "未满足收集条件" if not 有货 else "服务端结算"
	# ⚠️ **先确保选中的还是 叶_40_2**：上面 `_点枝` 把右列清空之后，`_点怪链` 那一下鼠标
	#    可能落在树的一行上 ⇒ 选中被改成 `叶_40_0`（可提交=false）。老版本门没发现这件事，
	#    因为它的两条断言**都没跑到**（见下面 `_备货` 的注）。
	await 点件(列().get_node("叶_40_2") as Control)
	(宿主 as Node)._status.text = ""
	await 点件(提)
	var 实测 := String((宿主 as Node)._status.text)
	if 期望 == "未满足收集条件":
		_记(实测 == 期望, "背包里没有该套卡 ⇒ 原版只 addNotice 不发帧（窗口 :313-317），实测 %s" % 实测)
	else:
		_记(实测.find("服务端结算") >= 0, "背包里有卡 ⇒ 离线那口话是「要在服务端结算」，实测 %s" % 实测)
	_记(实测 != "", "点提交**一定**有一行回显（不是静默）")
	# ④ 在线（假后端）：提交/领取都要**真发**（§3.120 —— 以前这两枚写死"本工程未接（待点头）"）
	var 假 := 假后端.new()
	(宿主 as Node).set("_backend", 假)
	(宿主 as Node)._status.text = ""
	await 点件(提)
	if 期望 == "未满足收集条件":
		_记(假.提交.is_empty(), "没货时**一个帧都不发**（连了服务端也一样）")
	else:
		_记(假.提交.size() == 1 and 假.提交[0] == [40, 2],
			"在线点「提交卡片」该发 request_card_commit(40, 2)（当前选中 叶_40_2），实测 %s" % str(假.提交))
	# 领取钮：原版 `setBtnEnabled():258-269` **只在 `finish && !gained` 时可用** ⇒
	# 先喂一帧"这一套已收集完成、尚未领取"，再重新选中让钮态重算。
	假.authoritative_card = {"level": 40, "node_id": 2, "committed": true, "claimed": false, "items": []}
	await 点件(列().get_node("叶_40_2") as Control)
	_记(not (页.get_node("领取钮") as Button).disabled,
		"服务端说这一套已完成、未领取 ⇒ 领取钮解禁（原版 `finish && !gained`）")
	(宿主 as Node)._status.text = ""
	await 点件(页.get_node("领取钮") as Button)
	_记(假.领取.size() == 1 and 假.领取[0] == [40, 2],
		"在线点「领取奖励」该发 request_card_claim(40, 2)，实测 %s" % str(假.领取))
	假.authoritative_card = {"level": 40, "node_id": 2, "committed": true, "claimed": true, "items": []}
	await 点件(列().get_node("叶_40_2") as Control)
	_记((页.get_node("领取钮") as Button).disabled,
		"服务端说已领取 ⇒ 领取钮该禁用（`setBtnEnabled` 的 `gained`）")
	(宿主 as Node).set("_backend", null)


## 从磁盘上的 `.tscn` **文本**里取该件烘的 `text`（不 load 场景 ⇒ 无头、不碰存档，
## 口径同 `测试/原版服务窗回归测试.gd`）。查无该件时回一个显眼的假串，让断言点名而不是静默绿。
func 场景烘文本(名: String) -> String:
	if 场景文 == "":
		场景文 = FileAccess.get_file_as_string(场景路)
	var 头 := '[node name="%s"' % 名
	var i := 场景文.find(头)
	if i < 0:
		return "<场景里查无该件>"
	var 尾 := 场景文.find("\n[node", i)
	var 块 := 场景文.substr(i, (尾 if 尾 > 0 else 场景文.length()) - i)
	var j := 块.find('text = "')
	if j < 0:
		return "<该件没有 text 行>"
	var 起 := j + 8
	return 块.substr(起, 块.find('"', 起) - 起)


func 收尾(致命: String) -> void:
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	for 一 in 日志:
		print(一)
	print("卡片套册交互回归：%s（红 %d 项）" % ["通过" if 红数 == 0 else "不通过", 红数])
	quit(1 if 红数 > 0 else 0)
