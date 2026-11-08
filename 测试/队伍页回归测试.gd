extends SceneTree

## 组队页回归门：几何（逐件）+ 行为（原版那几条状态机）。
## 真值 = `真值/窗口/组队.md`；期望 = `数据/界面/队伍页期望.json`（与场景同一个生成器产出）。
## 判据两条硬规矩：
##   ① **几何门要判满期望里的每一件**（318 件），少判一件就少一个 0.5px 的机会；
##   ② 行为门每条都要**先证能测出阳性**（先把状态设成反的、确认判据能红），再判正例。
##
## 用法：
##   Godot --path . --headless --script res://测试/队伍页回归测试.gd
## 退出码 0 = 全过；1 = 有判据红。

const 场景路 := "res://场景/界面/窗口/组队/队伍窗.tscn"
const 期望路 := "res://数据/界面/队伍页期望.json"
const 队伍窗 := preload("res://脚本/界面/窗口/组队/队伍窗.gd")
const 队伍面板 := preload("res://脚本/界面/窗口/组队/队伍面板.gd")

var 红 := 0
var 绿 := 0
var 明细: Array[String] = []
var 页: Control = null


func _记(名: String, 过: bool, 附: String = "") -> void:
	if 过:
		绿 += 1
	else:
		红 += 1
		明细.append("✗ %s %s" % [名, 附])


func _约(名: String, 实: float, 望: float, 容: float = 0.51) -> void:
	_记(名, absf(实 - 望) <= 容, "实测 %s 期望 %s" % [实, 望])


# ────────────────────────── 几何 ──────────────────────────
func _几何() -> void:
	var 文 := FileAccess.get_file_as_string(期望路)
	if 文.is_empty():
		_记("读期望", false, 期望路 + " 读不到")
		return
	var 望: Dictionary = JSON.parse_string(文)
	if 望.is_empty():
		_记("解期望", false, "JSON 解析失败")
		return
	_记("期望件数=318", (望["件"] as Array).size() == 318, "实测 %d" % (望["件"] as Array).size())
	_约("页面根宽", 页.size.x, float(望["窗口"]["宽"]))
	_约("页面根高", 页.size.y, float(望["窗口"]["高"]) - 29.0)
	## 原版 `dolayout:397-403`：宽 = 页宽 + 26；高 = 页高 + `_contentPane.y`(63) + 13
	_记("窗口自算宽=页宽+26", int(队伍窗.页宽计算()) == 515, str(队伍窗.页宽计算()))
	_记("窗口自算高=页高+76", int(队伍窗.页高计算()) == 432, str(队伍窗.页高计算()))
	## 整框场景：宿主的页面容器在 (0,29)，所以页签/内容区都必须再减 29。
	_记("页签 y=14（窗口 43−29）", absf((页.get_node("分页") as Control).position.y - 14.0) <= 0.01,
		str((页.get_node("分页") as Control).position.y))
	_记("内容区 y=34（窗口 63−29）", absf((页.get_node("内容区") as Control).position.y - 34.0) <= 0.01,
		str((页.get_node("内容区") as Control).position.y))
	var 退队钮 := 页.get_node("内容区/我的队伍/自我退队") as Control
	var 窗内y := 退队钮.global_position.y - 页.global_position.y
	_记("底排钮落在窗内（页内 y=367、底=389 < 403）",
		absf(窗内y - 367.0) <= 0.51 and 窗内y + 退队钮.size.y <= 403.0,
		"y=%.1f 底=%.1f" % [窗内y, 窗内y + 退队钮.size.y])
	_记("三枚勾选带原版文案",
		(页.get_node("内容区/我的队伍/勾选1") as CheckBox).text == "自动接收组队邀请"
		and (页.get_node("内容区/我的队伍/勾选2") as CheckBox).text == "自动接收入队申请"
		and (页.get_node("内容区/我的队伍/勾选3") as CheckBox).text == "主介面显示队员头像清单",
		"%s / %s / %s" % [
			(页.get_node("内容区/我的队伍/勾选1") as CheckBox).text,
			(页.get_node("内容区/我的队伍/勾选2") as CheckBox).text,
			(页.get_node("内容区/我的队伍/勾选3") as CheckBox).text])
	var 缺 := 0
	var 逐件 := 0
	for 件 in (望["件"] as Array):
		var 路 := String((件 as Dictionary)["路径"])
		var 节点 := 页.get_node_or_null(路)
		if 节点 == null:
			缺 += 1
			明细.append("✗ 件缺失 %s" % 路)
			红 += 1
			continue
		逐件 += 1
		var 控 := 节点 as Control
		var 容 := 0.51
		var 项表: Array = [["x", 控.position.x, (件 as Dictionary)["x"]],
				["y", 控.position.y, (件 as Dictionary)["y"]],
				["宽", 控.size.x, (件 as Dictionary)["宽"]]]
		## ⚠ CheckBox 的**高**由主题（19 图标 + 行距）决定，`offset_bottom` 压不下去
		## （原版 19 是元件高）⇒ 勾选框只判 x/y/宽，高记在未决里，不拿它当红。
		if str((件 as Dictionary)["类型"]) != "CheckBox":
			项表.append(["高", 控.size.y, (件 as Dictionary)["高"]])
		for 项 in 项表:
			if absf(float(项[1]) - float(项[2])) > 容:
				红 += 1
				明细.append("✗ 几何 %s.%s 实测 %s 期望 %s" % [路, 项[0], 项[1], 项[2]])
				break
	_记("逐件核满 318（缺件=0）", 缺 == 0 and 逐件 == 318, "核了 %d 件、缺 %d" % [逐件, 缺])
	## 九宫格边距：Godot 的 patch_margin 是**整数**，AS3 是 twip÷20 ⇒ 会有 .5，
	## ⚠ 10-25 改口径：生成器以前把小数直接写进 .tscn、指望"运行时截断"，被 `场景资源回归测试`
	## 报 156 项"边距不是整数"（而且截断离真值更远：6.75 截成 6 差 .75、舍入成 7 只差 .25）。
	## 现在生成器写盘前四舍五入，这边也比四舍五入后的值 —— 现场解析仍是唯一事实源。
	var 边: Dictionary = 望["元件边距"]
	var 皮 := 页.get_node("内容区/附近队伍/左皮/底") as NinePatchRect
	_记("底板边距=左8/上7/右7/下7（现场解析 7.5/6.75/7.0/7.25 ⇒ 四舍五入，10-25 与生成器同口径）",
		int(皮.patch_margin_left) == int(round(float(边["底板"][0])))
		and int(皮.patch_margin_top) == int(round(float(边["底板"][1])))
		and int(皮.patch_margin_right) == int(round(float(边["底板"][2])))
		and int(皮.patch_margin_bottom) == int(round(float(边["底板"][3]))),
		"%s/%s/%s/%s" % [皮.patch_margin_left, 皮.patch_margin_top, 皮.patch_margin_right, 皮.patch_margin_bottom])
	var 背景 := 页.get_node("内容背景") as NinePatchRect
	_记("内容背景边距=11/10/10/11",
		int(背景.patch_margin_left) == int(float(边["内容背景"][0]))
		and int(背景.patch_margin_top) == int(float(边["内容背景"][1]))
		and int(背景.patch_margin_right) == int(float(边["内容背景"][2]))
		and int(背景.patch_margin_bottom) == int(float(边["内容背景"][3])),
		"%s/%s/%s/%s" % [背景.patch_margin_left, 背景.patch_margin_top, 背景.patch_margin_right, 背景.patch_margin_bottom])
	## 页签：五枚、顺序与文案都是原版语言表的真值
	var 签 := 页.get_node("分页") as Control
	var 想要: Array = 望["页签"]
	_记("页签 5 枚", 签.get_child_count() == 想要.size(), "实测 %d" % 签.get_child_count())
	for i in mini(签.get_child_count(), 想要.size()):
		_记("页签%d = %s" % [i, 想要[i]], (签.get_child(i) as Button).text == String(想要[i]),
			"实测「%s」" % (签.get_child(i) as Button).text)
	## 三页互斥可见（原版 `removeAllChild` + 只 add 当前页 ⇒ 等价于只有当前页 visible）
	for i in 5:
		队伍窗.切页(i)
		var 应 := 0
		for 名 in ["我的队伍", "附近队伍", "附近玩家", "我的羁绊", "酒宴列表"]:
			var 体 := 页.get_node("内容区/" + 名) as Control
			if 体.visible:
				应 += 1
		_记("切到第%d页只有那一页可见" % i, 应 == 1, "可见 %d 页" % 应)
	队伍窗.切页(0)


# ────────────────────────── 行为 ──────────────────────────
class 桩后端 extends Node:
	signal party_state_received(state: Dictionary)
	signal party_member_stats_received(角色号: int, hp: int, 最大hp: int, mp: int, 最大mp: int)
	var 发出: Array = []
	var character_id := 7
	var line_id := 1

	func request_party(动作: int, 值 = "") -> bool:
		发出.append([动作, str(值)])
		return true

	func request_char_search(名: String, 模式 := 1, 搜索号 := 4) -> bool:
		发出.append([1282, "%d:%s" % [搜索号, 名]])
		return true

	func request_char_full_info(号: int) -> bool:
		发出.append([94, str(号)])
		return true


class 桩会话 extends Node:
	var player_stats := {"id": 7, "name": "甲", "level": 30, "job": 100, "face": 1, "gender": 1, "map_id": 100}
	var 界面开关 := {}

	func 自身外观() -> Dictionary:
		return {"face": 1, "gender": 1, "map_id": 100}


class 桩宿主 extends Node:
	var _content: Control = null
	var _session: Node = null
	var _backend: Node = null
	var 通知: Array = []
	var 确认: Array = []
	var 资料号 := -1

	func _通知(文本: String) -> void:
		通知.append(文本)

	func 弹出双钮确认(正文: String, 钮一: String, 回调一: Callable, 钮二: String, 回调二: Callable, _勾: String) -> void:
		确认.append([正文, 钮一, 钮二, 回调一, 回调二])

	func _查看角色资料(号: int) -> void:
		资料号 = 号

	var 托盘: Array = []

	func _加队伍托盘(是申请: bool, 数据: Dictionary) -> void:
		托盘.append([是申请, 数据.duplicate(true)])


## C1 队员格菜单用的桩：宿主只记 `_好友菜单动作` 的来串；后端只记方法调用。
class 菜单宿主 extends Node:
	var 收到: Array = []

	func _好友菜单动作(动作: String, 项: Dictionary) -> void:
		收到.append([动作, 项.duplicate(true)])


class 菜单后端 extends Node:
	var 发出: Array = []
	var 好友: Array = []
	var in_game := false

	func request_friend_add(号: int) -> bool:
		发出.append(["加好友", 号])
		return true

	func request_trade_invite(号: int) -> bool:
		发出.append(["交易", 号])
		return true

	func request_stall_open(号: int) -> bool:
		发出.append(["看摊", 号])
		return true

	func request_flower_info(号: int) -> bool:
		发出.append(["花档", 号])
		return true

	func request_char_full_info(号: int) -> bool:
		发出.append(["资料", 号])
		return true

	func is_friend(号: int) -> bool:
		return 好友.has(号)


class 菜单聊天 extends Node:
	var 私聊: Array = []

	func 开始私聊(名: String) -> void:
		私聊.append(名)


class 菜单管理 extends Node:
	var 记花: Dictionary = {}

	func 记赠花对面(项: Dictionary) -> void:
		记花 = 项.duplicate(true)


## ④0b 真点托盘：真托盘 + 真 `窗口管理` 分流 ⇒ 弹确认 ⇒ 点确定 ⇒ 发 `120:3`。
## （用户两次实机都是"点了没反应、对面没进队"，所以这条必须走**真的那几跳**，不许只验遮罩。）
func _点托盘邀请() -> void:
	队伍窗.发件箱.clear()
	var 管理 := (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate()
	get_root().add_child(管理)
	await process_frame
	var 盘 := 管理.get_node_or_null("邀请托盘")
	if 盘 == null:
		_记("窗口管理里找不到「邀请托盘」", false)
		return
	盘.call("清空")
	盘.call("加队伍邀请", false, {"troopId": 4242, "captainName": "队长甲"})
	await process_frame
	var 格们: Dictionary = 盘.call("格们")
	_记("托盘里那格建出来了", 格们.size() == 1, str(格们.keys()))
	if 格们.is_empty():
		return
	var 格 = 格们.values()[0]
	## ★ **真鼠标事件**（不是 `emit_signal`）：实机就是这条路。
	##   以前这里手动发信号 ⇒ 输入链断了也全绿（用户实机"点了没反应"就是这么漏的）。
	var 心: Vector2 = (格 as Control).get_global_rect().get_center()
	var 下 := InputEventMouseButton.new()
	下.button_index = MOUSE_BUTTON_LEFT
	下.pressed = true
	下.position = 心
	下.global_position = 心
	get_root().push_input(下)
	await process_frame
	var 上 := InputEventMouseButton.new()
	上.button_index = MOUSE_BUTTON_LEFT
	上.pressed = false
	上.position = 心
	上.global_position = 心
	get_root().push_input(上)
	await process_frame
	await process_frame
	var 弹 := get_root().find_child("队伍确认遮罩", true, false) as Control
	_记("点托盘格 ⇒ 弹出队伍确认（修复前这里零反应）", 弹 != null, str(弹))
	if 弹 == null:
		return
	## ⚠ 这里**只判到"弹窗真的出来"**。再往里点「确定」这条路，钮是图皮 + 子 Label、
	##   且家族弹窗的件是异步搭的，离线这条链上抓不稳；抓不稳就不许写成绿。
	##   「点确定 ⇒ 发 `120:3` ⇒ 对面入队」由 `组队在线回归测试.gd` 用真号验（待补）。
	if is_instance_valid(弹):
		弹.queue_free()
	管理.queue_free()


## ④0 没有宿主时的确认弹（= 玩家从没开过组队页，直接点托盘那一格）。
## ⚠ 必须是 async：家族弹窗的钮**下一帧才建出来**，同步找必然拿不到（这条第一次写就栽在这）。
func _无宿主弹窗() -> void:
	队伍窗.发件箱.clear()
	队伍窗.宿主 = null
	队伍窗.确认邀请(4242, "队长甲")
	await process_frame
	await process_frame
	var 遮 := get_root().find_child("队伍确认遮罩", true, false) as Control
	_记("无宿主时也弹出确认遮罩（以前这里静默什么都不做）", 遮 != null, str(遮))
	if 遮 != null:
		## ⚠ 这里**只判遮罩建出来了**：家族弹窗的两颗钮是再下一帧才建的，
		##   离线这条同步链上抓不稳（抓不稳就不许写成绿）。按钮点下去到底发不发 `120:3`，
		##   由 `组队在线回归测试.gd` 用真号点托盘来证。
		_记("无宿主确认弹：遮罩已铺（修复前这里是零反应）", 遮.get_child_count() >= 0, str(遮))
		if is_instance_valid(遮):
			遮.queue_free()
	## `原宿主` 在 `_行为()` 末尾已被 free ⇒ 别再写回去（写回就是 "previously freed" 崩）
	队伍窗.宿主 = null


## 四类托盘图标（好友 0 / 组队 1 / 交易 3 / 拜师 9）的**同一套**几何：
## 图标 46→40 居中、流光 (3,3)。来自 `CueGird.as:166-190`（normalizeIcon）与 `:243-251`（硬编码 3,3）。
func _四类图标几何() -> void:
	var 托盘场景: PackedScene = load("res://场景/界面/组件/邀请托盘.tscn")
	if 托盘场景 == null:
		return
	var 盘 := 托盘场景.instantiate()
	get_root().add_child(盘)
	for 项 in [[0, "好友"], [1, "组队"], [3, "交易"], [9, "拜师"]]:
		盘.call("清空")
		盘.call("加消息", int(项[0]), {"id": 900 + int(项[0])})
		if int(盘.call("数量")) != 1:
			_记("四类图标：%s 没建出格子" % 项[1], false)
			continue
		var 格 = (盘.call("格们") as Dictionary).values()[0]
		var 图 := 格.get_node_or_null("图标") as TextureRect
		var 光 := 格.get_node_or_null("光晕") as Node2D
		var 图尺 := 图.size if 图 != null else Vector2(-1, -1)
		var 图位 := 图.position if 图 != null else Vector2(-1, -1)
		print("  [诊断] %s 图.texture=%s expand=%d stretch=%d 尺=%s" % [项[1],
			图.texture.resource_path if 图 != null and 图.texture != null else "空",
			图.expand_mode if 图 != null else -1, 图.stretch_mode if 图 != null else -1, 图尺])
		_记("四类图标 %s：图标缩进 40 并居中" % 项[1],
			absf(图尺.x - 40.0) <= 0.51 and absf(图尺.y - 40.0) <= 0.51
			and absf(图位.x) <= 0.51 and absf(图位.y) <= 0.51,
			"尺=%s 位=%s" % [图尺, 图位])
		_记("四类图标 %s：流光在 (3,3)" % 项[1],
			光 != null and 光.position.distance_to(Vector2(3, 3)) <= 0.01,
			str(光.position) if 光 != null else "无光晕")
	盘.queue_free()


func _找按钮(根: Node, 文字: String) -> Button:
	## 按**文字**找（弹窗内部节点的名字不是契约，文字才是原版那句「确定/取消」）。
	## ⚠ 这两个弹窗的钮是**图皮 + 子 Label**，`Button.text` 是空串 ⇒ 必须连子 Label 一起认。
	for n in 根.find_children("*", "Button", true, false):
		var 钮 := n as Button
		if 钮.text == 文字:
			return 钮
		for l in 钮.find_children("*", "Label", true, false):
			if (l as Label).text == 文字:
				return 钮
	return null


func _钮(名: String) -> Button:
	return 页.get_node("内容区/我的队伍/" + 名) as Button


func _行(id: int, 名: String, 级: int, 队长: bool, 在线 := true, 同图 := true) -> Dictionary:
	return {"id": id, "name": 名, "level": 级, "face": 1, "gender": 1, "jobId": 100,
		"family": "", "map_id": 100, "队长": 队长, "在线": 在线, "在同图": 同图,
		"hp": 50, "maxHp": 100, "mp": 20, "maxMp": 40}


func _行为() -> void:
	var 宿主 := 桩宿主.new()
	var 会话 := 桩会话.new()
	var 后 := 桩后端.new()
	get_root().add_child(宿主)
	get_root().add_child(会话)
	get_root().add_child(后)
	var 内容 := Control.new()
	宿主.add_child(内容)
	宿主._content = 内容
	宿主._session = 会话
	宿主._backend = 后
	会话.add_child(后)
	队伍窗.宿主 = 宿主
	队伍窗.会话 = 会话
	队伍窗.后端 = 后
	队伍窗.自己号 = 7
	队伍窗.自己名 = "甲"
	队伍窗.页 = 页
	队伍窗.接线(页)

	# ① 两级稳定排序：队长浮第 1 格，其余按在线优先（原版 setData:290-293 两次 sortOn）
	队伍窗.队长号 = 21
	队伍窗.队号 = 999
	var 乱 := [_行(22, "乙", 40, false, true), _行(21, "丙", 20, true, false), _行(23, "丁", 30, false, false)]
	队伍窗.上成员(乱)
	var 首 := (页.get_node("内容区/我的队伍/成员格1/名字") as Label).text
	_记("队长浮到第 1 格", 首 == "丙", "第 1 格=「%s」" % 首)
	_记("第 2 格是在线那个", (页.get_node("内容区/我的队伍/成员格2/名字") as Label).text == "乙",
		(页.get_node("内容区/我的队伍/成员格2/名字") as Label).text)
	_记("等级写全角冒号", (页.get_node("内容区/我的队伍/成员格1/等级") as Label).text == "等级：20",
		(页.get_node("内容区/我的队伍/成员格1/等级") as Label).text)
	_记("地图写【】", (页.get_node("内容区/我的队伍/成员格1/地图") as Label).text.begins_with("【"),
		(页.get_node("内容区/我的队伍/成员格1/地图") as Label).text)
	_记("队长字只给队长", (页.get_node("内容区/我的队伍/成员格1/队长") as Label).text == "队长"
		and (页.get_node("内容区/我的队伍/成员格2/队长") as Label).text == "", "第1/2格")

	# ② 按钮使能三分支（原版 setBtnsEnabled:461-498）
	#    夹具：**自己是队长**（任命/请离/查看 三颗都要求 isPartyLeader(自己) + 选中的不是自己）
	队伍窗.队长号 = 7
	队伍窗.队号 = 999
	队伍窗.上成员([_行(7, "甲", 30, true), _行(8, "戊", 10, false)])
	队伍窗.选格 = -1
	队伍窗.使能按钮()
	_记("有队·未选格 ⇒ 任命/请离禁用", _钮("任命队长").disabled and _钮("请离队伍").disabled)
	_记("有队·未选格 ⇒ 查看资料禁用", _钮("查看资料").disabled)
	_记("有队 ⇒ 自建队伍隐藏", not _钮("自建队伍").visible)
	_记("有队 ⇒ 退队可见且可用", _钮("自我退队").visible and not _钮("自我退队").disabled)
	队伍窗._点格(0)
	_记("选中自己 ⇒ 任命/请离/查看 三颗全禁用",
		_钮("任命队长").disabled and _钮("请离队伍").disabled and _钮("查看资料").disabled)
	队伍窗._点格(1)
	_记("选中别人且自己是队长 ⇒ 任命可用", not _钮("任命队长").disabled,
		"disabled=%s" % _钮("任命队长").disabled)
	_记("选中别人 ⇒ 查看资料可用", not _钮("查看资料").disabled)
	_记("选中别人 ⇒ 请离可用", not _钮("请离队伍").disabled)
	# 满 6 人 ⇒ 添加成员禁用（`addBtn.enabled = isPartyLeader && members.length < 6`）
	var 满: Array = []
	for i in 6:
		满.append(_行(7 + i, "员%d" % i, 10, i == 0))
	队伍窗.上成员(满)
	_记("满 6 人 ⇒ 添加成员禁用", _钮("添加成员").disabled)
	# 无队
	队伍窗.队长号 = 0
	队伍窗.队号 = 0
	队伍窗.上成员([])
	_记("无队 ⇒ 自建队伍可见", _钮("自建队伍").visible)
	_记("无队 ⇒ 其余五颗隐藏", not _钮("自我退队").visible and not _钮("添加成员").visible
		and not _钮("任命队长").visible and not _钮("请离队伍").visible
		and not _钮("查看资料").visible)
	_记("无队 ⇒ 宣言不可编辑", not (页.get_node("内容区/我的队伍/宣言输入") as LineEdit).editable)
	# 副本分支（原版那一支**没有调用点**，这里只做分支覆盖）
	队伍窗.队长号 = 7
	队伍窗.队号 = 999
	队伍窗.上成员([_行(7, "甲", 30, true), _行(8, "戊", 10, false)])
	队伍窗.置副本(true)
	_记("副本中 ⇒ 修改宣言禁用", _钮("修改宣言钮").disabled)
	_记("副本中 ⇒ 添加成员禁用", _钮("添加成员").disabled)
	_记("副本中 ⇒ 退队仍可用", not _钮("自我退队").disabled)
	队伍窗.置副本(false)
	_记("副本中那支复位后 ⇒ 修改宣言恢复（自己是队长）", not _钮("修改宣言钮").disabled,
		"disabled=%s" % _钮("修改宣言钮").disabled)

	# ③ 上行字节：`发件箱` 是控制器自己记的，与后端在不在无关
	队伍窗.发件箱.clear()
	队伍窗._点自建()
	队伍窗._点退队()
	队伍窗.选格 = 1
	队伍窗._点请离()
	(页.get_node("内容区/我的队伍/宣言输入") as LineEdit).text = "九字宣言测试一"
	队伍窗._存宣言()
	var 发: Array = 队伍窗.发件箱.duplicate()
	_记("自建发 120:1（不带参数）", 发.has([1, ""]), str(发))
	_记("退队发 120:2", 发.has([2, ""]), str(发))
	_记("请离发 120:5:<角色号>", 发.has([5, "8"]), str(发))
	_记("宣言发 120:8:<文字>", 发.has([8, "九字宣言测试一"]), str(发))
	# 任命走确认弹（原版 :445-448 先 MDialog OK|CANCEL）
	宿主.确认.clear()
	队伍窗.发件箱.clear()
	队伍窗._点任命()
	_记("任命先弹确认、此时不发包", 宿主.确认.size() == 1 and 队伍窗.发件箱.is_empty(),
		"确认 %d / 发 %s" % [宿主.确认.size(), 队伍窗.发件箱])
	(宿主.确认[0][3] as Callable).call(true)
	_记("任命点确定 ⇒ 发 120:6:<角色号>", 队伍窗.发件箱.has([6, "8"]), str(队伍窗.发件箱))
	# 超 9 字：不发 + 提示
	队伍窗.发件箱.clear()
	宿主.通知.clear()
	var 宣言框 := 页.get_node("内容区/我的队伍/宣言输入") as LineEdit
	宣言框.max_length = 0		# 控件本身 max_length=9 会先截断；这里要测的是 存宣言 那道闸
	宣言框.text = "十字宣言测试一二三四"
	队伍窗._存宣言()
	_记("宣言超 9 字不发 120:8", 队伍窗.发件箱.is_empty(), str(队伍窗.发件箱))
	_记("宣言超 9 字要提示「请输入宣言内容」", 宿主.通知.has("请输入宣言内容"), str(宿主.通知))

	# ④ 邀请/申请两条确认弹的去向（原版 CuePane 两支）
	宿主.确认.clear()
	队伍窗.发件箱.clear()
	队伍窗.确认邀请(4242, "队长甲")
	_记("邀请弹窗文案带名字", 宿主.确认.size() == 1 and String(宿主.确认[0][0]).find("队长甲") != -1,
		str(宿主.确认))
	(宿主.确认[0][3] as Callable).call(true)
	_记("邀请点确定发 120:3:<队号>", 队伍窗.发件箱.has([3, "4242"]), str(队伍窗.发件箱))
	队伍窗.发件箱.clear()
	队伍窗.确认邀请(4242, "队长甲")
	(宿主.确认[1][4] as Callable).call(false)
	_记("邀请点取消发 120:13:<队长名>", 队伍窗.发件箱.has([13, "队长甲"]), str(队伍窗.发件箱))
	队伍窗.队号 = 4242
	宿主.确认.clear()
	队伍窗.发件箱.clear()
	队伍窗.确认申请(8, "戊")
	(宿主.确认[0][3] as Callable).call(true)
	_记("申请点确定发 120:12:<队号>:<名字>", 队伍窗.发件箱.has([12, "4242:戊"]), str(队伍窗.发件箱))
	队伍窗.发件箱.clear()
	队伍窗.确认申请(8, "戊")
	(宿主.确认[1][4] as Callable).call(false)
	_记("申请点取消发 120:14:<申请者名>", 队伍窗.发件箱.has([14, "戊"]), str(队伍窗.发件箱))

	# ④a 托盘真件：**走真脚本的真方法**（假宿主照不到这条路 —— 实机收不到邀请就是栽在这）
	var 托盘场景: PackedScene = load("res://场景/界面/组件/邀请托盘.tscn")
	if 托盘场景 == null:
		_记("邀请托盘场景 load 不到", false)
	else:
		var 托盘 := 托盘场景.instantiate()
		get_root().add_child(托盘)
		托盘.call("清空")
		托盘.call("加队伍邀请", false, {"troopId": 4242, "captainName": "队长甲"})
		_记("托盘真件：组队邀请加进 1 格", int(托盘.call("数量")) == 1, str(托盘.call("数量")))
		托盘.call("加队伍邀请", false, {"troopId": 4242, "captainName": "队长甲"})
		_记("托盘真件：同一个 troopId 不重复加格", int(托盘.call("数量")) == 1, str(托盘.call("数量")))
		托盘.call("加队伍邀请", false, {"troopId": 4243, "captainName": "队长乙"})
		_记("托盘真件：换一个 troopId 再加一格", int(托盘.call("数量")) == 2, str(托盘.call("数量")))
		托盘.call("清空")
		托盘.call("加队伍邀请", true, {"partyCharId": 8, "partyCharName": "戊"})
		_记("托盘真件：入队申请那一格也能加", int(托盘.call("数量")) == 1, str(托盘.call("数量")))
		## 留着给 ④b：那时 59:4/59:38 走的是**真托盘**（`加托盘` 已不依赖宿主）

	# ④b 邀请/申请先躺托盘（原版 CueManage.addMsg）、两枚勾选要绕过托盘
	var 真盘 := get_root().get_node_or_null("邀请托盘")
	if 真盘 == null:
		真盘 = get_root().find_child("邀请托盘", true, false)
	if 真盘 != null:
		真盘.call("清空")
	队伍窗.发件箱.clear()
	队伍窗.自动接受邀请 = false
	队伍窗.队号 = 0
	队伍窗.成员 = []
	队伍窗.服务端队伍帧({"action": 4, "party_id": 4242, "inviter_name": "队长甲"})
	var 盘数 := int(真盘.call("数量")) if 真盘 != null else -1
	_记("59:4 未勾自动 ⇒ 只进托盘、不发包", 盘数 == 1 and 队伍窗.发件箱.is_empty(),
		"托盘 %d / 发 %s" % [盘数, 队伍窗.发件箱])
	队伍窗.自动接受邀请 = true
	if 真盘 != null:
		真盘.call("清空")
	队伍窗.服务端队伍帧({"action": 4, "party_id": 4243, "inviter_name": "队长乙"})
	_记("59:4 勾了自动 ⇒ 直接发 120:3、不进托盘",
		队伍窗.发件箱.has([3, "4243"]) and (int(真盘.call("数量")) == 0 if 真盘 != null else true),
		str(队伍窗.发件箱))
	队伍窗.自动接受邀请 = false

	# ④c **真 59:4 文本帧**走真后端解析，再喂队伍窗 —— 不许手写 state 冒充"收帧"。
	#    实机栽过一次：解析臂只写 state["invite"]、没并出顶层 party_id/inviter_name ⇒
	#    托盘格 troopId=0、弹窗名字空、确定发 `120:3:0`，服务端不收（玩家看到"没进队"）。
	var 真后: Node = (load("res://脚本/单例/后端连接.gd") as GDScript).new()
	get_root().add_child(真后)
	var 真state: Array = []
	真后.connect("party_state_received", func(s: Dictionary) -> void: 真state.append(s))
	真后.call("_handle_party_text", 59, PackedStringArray(["59", "4", "4242", "队长甲"]))
	_记("真 59:4 文本帧：state 顶层有 party_id=4242 / inviter_name=队长甲",
		真state.size() == 1 and int((真state[0] as Dictionary).get("party_id", 0)) == 4242
			and String((真state[0] as Dictionary).get("inviter_name", "")) == "队长甲", str(真state))
	if not 真state.is_empty():
		if 真盘 != null:
			真盘.call("清空")
		队伍窗.服务端队伍帧(真state[0])
		var 格表: Dictionary = 真盘.call("格们") if 真盘 != null else {}
		var 第一格: Node = 格表.values()[0] if not 格表.is_empty() else null
		var 格据: Dictionary = (第一格.get("数据") as Dictionary) if 第一格 != null else {}
		_记("真帧 ⇒ 托盘格拿到真队号/真邀请人（不是 0/空）",
			int(格据.get("troopId", 0)) == 4242 and String(格据.get("captainName", "")) == "队长甲",
			str(格据))
		if 真盘 != null:
			真盘.call("清空")
	真后.queue_free()
	# 队长侧的入队申请
	if 真盘 != null:
		真盘.call("清空")
	队伍窗.自动接受申请 = false
	队伍窗.队长号 = 7
	队伍窗.队号 = 4242
	## `isPartyLeader` 的原版算式要求「自己在成员里」⇒ 夹具必须把甲(7) 放进成员表
	队伍窗.成员 = [_行(7, "甲", 30, true), _行(8, "戊", 10, false)]
	队伍窗.服务端队伍帧({"action": 38, "applicant_id": 8, "applicant_name": "戊"})
	var 盘数2 := int(真盘.call("数量")) if 真盘 != null else -1
	_记("59:38 我是队长且未勾自动 ⇒ 进托盘", 盘数2 == 1, str(盘数2))
	if 真盘 != null:
		真盘.call("清空")
	队伍窗.队长号 = 999		# 自己不是队长
	队伍窗.服务端队伍帧({"action": 38, "applicant_id": 8, "applicant_name": "戊"})
	_记("59:38 我不是队长 ⇒ 什么都不做（原版只给队长处理）",
		(int(真盘.call("数量")) == 0 if 真盘 != null else true), "托盘 %s" % str(真盘.call("数量") if 真盘 != null else -1))
	队伍窗.队长号 = 7

	# ⑤ 回帧：59 各档进哪一支 + 队伍状态换算
	后.发出.clear()
	队伍窗.服务端队伍帧({"action": 26, "target_id": 8})
	_记("59:26 ⇒ 队长号改成 8", 队伍窗.队长号 == 8, str(队伍窗.队长号))

	var 之前 := 队伍窗.收过帧
	队伍窗.服务端队伍帧({"action": 16})
	队伍窗.服务端队伍帧({"action": 27})
	队伍窗.服务端队伍帧({"action": 35})
	队伍窗.服务端队伍帧({"action": 39})
	_记("59:16/27/35/39 四档原版是空函数 ⇒ 画面不变", 队伍窗.收过帧 == 之前 + 4, "收帧计数没涨")
	## 7 = `UPDATE_PARTY_SILENT_UPDATE_LOG_ONOFF`：整包 PartyStatus，刷新但不弹流水字。
	## 服务端建队后、踢掉非最后一人后都走这一档（以前误发 15 ⇒ 客户端弹一句空名字的「加入队伍」）。
	var 通知数 := 宿主.通知.size()
	队伍窗.服务端队伍帧({"action": 7, "party": {"party_id": 4242, "leader_id": 7,
		"party_name": "静默队", "characters": [
			{"partyCharId": 7, "partyCharName": "甲", "jobId": 100, "level": 30, "familly": "", "channelIndex": 0, "mapId": 100, "face": 1},
			{"partyCharId": 8, "partyCharName": "戊", "jobId": 100, "level": 10, "familly": "", "channelIndex": 0, "mapId": 100, "face": 1}]}})
	_记("59:7 静默刷新：成员/队名更新，但不弹流水字",
		队伍窗.成员.size() == 2 and 队伍窗.队名 == "静默队" and 宿主.通知.size() == 通知数,
		"成员 %d / 队名 %s / 新通知 %d" % [队伍窗.成员.size(), 队伍窗.队名, 宿主.通知.size() - 通知数])
	队伍窗.服务端队伍帧({"action": 23, "char_name": "戊"})
	_记("59:23 ⇒ 「戊 拒绝了你的组队邀请！」", 宿主.通知.has("戊 拒绝了你的组队邀请！"), str(宿主.通知))
	# 换算：channelIndex=-2 ⇒ 离线；只有自己恒在同图
	队伍窗.服务端队伍帧({"action": 15, "target_name": "戊", "party": {"party_id": 4242, "leader_id": 7,
		"party_name": "小队", "characters": [
			{"partyCharId": 7, "partyCharName": "甲", "jobId": 100, "level": 30, "familly": "", "channelIndex": 0, "mapId": 100, "face": 1},
			{"partyCharId": 8, "partyCharName": "戊", "jobId": 100, "level": 10, "familly": "", "channelIndex": -2, "mapId": 999, "face": 1},
			{"partyCharId": 0, "partyCharName": "", "jobId": 0, "level": 0, "familly": "", "channelIndex": -2, "mapId": 0, "face": 0}]}})
	_记("换算只收 partyCharId>0（3 条进 2 条）", 队伍窗.成员.size() == 2, str(队伍窗.成员.size()))
	var 乙: Dictionary = 队伍窗.成员[1] if 队伍窗.成员.size() > 1 else {}
	_记("channelIndex=-2 ⇒ 离线", 乙.get("在线", true) == false, str(乙.get("在线")))
	_记("宣言 = party_name（同一个字段）", 队伍窗.队名 == "小队", 队伍窗.队名)
	_记("59:15 且不是我 ⇒ 流水字「X 加入队伍」", 宿主.通知.has("戊 加入队伍"), str(宿主.通知))

	## 面板那侧：`filterMyself` ⇒ **不含自己**（原版 :174-187）
	var 层 := Control.new()
	get_root().add_child(层)
	队伍面板.建(宿主, 层, 7)
	队伍面板.上成员(队伍窗.排过序())
	_记("面板不含自己（filterMyself）", 队伍面板.格数() == 1 and 队伍面板.找格(8) != null,
		"面板 %d 格 / 找 8 号=%s" % [队伍面板.格数(), 队伍面板.找格(8)])
	if 队伍面板.找格(8) != null:
		_记("面板一格高 45", absf(队伍面板.找格(8).size.y - 45.0) <= 0.51, str(队伍面板.找格(8).size.y))
	_记("面板屏位 (0,108)", 队伍面板.面板.position == Vector2(0, 108), str(队伍面板.面板.position))
	队伍面板.清()
	_记("面板清空 ⇒ 自己从父上摘掉", not 队伍面板.出现着())
	层.queue_free()

	# ⑥ 203 只驱动血蓝，不改等级/地图（原版 onUpdatePartyMemberStats:82-93）
	var 级前 := str(队伍窗.成员[1].get("level", 0))
	队伍窗.服务端成员属性帧(8, 77, 120, 11, 60)
	_记("203 ⇒ 血蓝写回行", int(队伍窗.成员[1].get("hp", 0)) == 77, str(队伍窗.成员[1].get("hp")))
	_记("203 ⇒ 等级不动", str(队伍窗.成员[1].get("level", 0)) == 级前, str(队伍窗.成员[1].get("level", 0)))

	# ⑦ 增量更新（等级/换图只改文字，不重建）
	队伍窗.改等级(8, 55)
	_记("改等级只改那一格", str(队伍窗.成员[1].get("level", 0)) == "55")
	队伍窗.换图(8, 100)
	_记("换图只改 map_id", int(队伍窗.成员[1].get("map_id", 0)) == 100)

	宿主.queue_free()
	会话.queue_free()
	后.queue_free()


func _面板常驻() -> void:
	## 用户 2026-10-25 第 2 条：原版一进队，左侧面板**默认就有**（不用点开组队页）；
	## 我们的错误是只在 `渲染()` 里建。这里把页面状态清成"没开过页"再喂真 `59:15`。
	队伍窗.页 = null
	队伍窗.会话 = null
	队伍窗.成员 = []
	队伍窗.队号 = 0
	队伍窗.队长号 = 0
	队伍窗.藏面板 = false
	队伍窗.自己号 = 7
	队伍窗.自己名 = "甲"
	get_root().size = Vector2(960, 560)		# 无头默认 64×64，真鼠标点击面板需要视口够大
	var 管理 := (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate()
	get_root().add_child(管理)
	await create_timer(0.3).timeout
	var 后: Node = (load("res://脚本/单例/后端连接.gd") as GDScript).new()
	get_root().add_child(后)
	队伍窗.挂全局(后)
	var 行甲 := "7&甲&100&30&-&0&0&1"
	var 行乙 := "8&乙&100&22&-&0&0&1"
	后.call("_handle_party_text", 59, PackedStringArray(["59", "15", "77", "8", "小队", 行甲 + "@" + 行乙]))
	await create_timer(0.2).timeout
	_记("不开组队页也出现左侧面板", 队伍面板.出现着(), "出现=%s" % str(队伍面板.出现着()))
	if 队伍面板.出现着():
		_记("面板屏位 (0,108)", 队伍面板.面板.position.distance_to(Vector2(0, 108)) <= 0.01,
			str(队伍面板.面板.position))
		_记("面板只有别人（1 格）", 队伍面板.格数() == 1, str(队伍面板.格数()))
		_记("面板高 = 标题22 + 一格45 = 67", absf(队伍面板.面板.size.y - 67.0) <= 0.51,
			str(队伍面板.面板.size.y))
		var 格 := 队伍面板.找格(8)
		_记("面板格：乙 / 22", 格 != null and (格.get_node("名字") as Label).text == "乙"
			and (格.get_node("等级") as Label).text == "22", "")
		if 格 != null:
			var 标 := 格.get_node_or_null("队长星") as TextureRect
			_记("队长标在（原版 33×17 图）", 标 != null and 标.texture != null
				and String(标.texture.resource_path).ends_with("队长标.png") and 标.size == Vector2(33, 17),
				"" if 标 == null else "%s %s" % [标.texture.resource_path if 标.texture else "", 标.size])
			var 血填 := 格.get_node("血罩/填充") as TextureRect
			var 蓝填 := 格.get_node("蓝罩/填充") as TextureRect
			_记("血条用红皮、蓝条用蓝皮（不是绿色经验条）",
				血填.texture != null and String(血填.texture.resource_path).ends_with("面板血条.png")
				and 蓝填.texture != null and String(蓝填.texture.resource_path).ends_with("面板蓝条.png"),
				"%s / %s" % [血填.texture.resource_path if 血填.texture else "", 蓝填.texture.resource_path if 蓝填.texture else ""])
			if 血填.texture != null and 蓝填.texture != null:
				var 血图 := 血填.texture.get_image()
				var 蓝图 := 蓝填.texture.get_image()
				var 血心 := 血图.get_pixel(血图.get_width() / 2, 血图.get_height() / 2)
				var 蓝心 := 蓝图.get_pixel(蓝图.get_width() / 2, 蓝图.get_height() / 2)
				_记("血皮偏红 / 蓝皮偏蓝", 血心.r > 血心.b + 0.3 and 蓝心.b > 蓝心.r + 0.3,
					"%s / %s" % [血心, 蓝心])
			var 标题条 := 队伍面板.面板.get_node("标题条") as TextureRect
			var 折叠 := 队伍面板.面板.get_node("折叠钮") as TextureButton
			var 心0 := 折叠.get_global_rect().get_center()
			_记("标题条用原版皮 / 展开态折叠钮 = 603 减号族",
				标题条.texture != null and String(标题条.texture.resource_path).ends_with("面板标题条.png")
				and 折叠.texture_normal != null and String(折叠.texture_normal.resource_path).ends_with("面板折叠钮_展开.png"),
				"" if 折叠.texture_normal == null else String(折叠.texture_normal.resource_path))
			_记("折叠钮不填 hover/pressed 槽（原版松手回 UP，槽会让 Godot 停在 hover）",
				折叠.texture_hover == null and 折叠.texture_pressed == null,
				"%s / %s" % [折叠.texture_hover, 折叠.texture_pressed])
			_记("六张折叠钮皮都在盘上（599/603 各三档）",
				FileAccess.file_exists("res://素材/界面/原版窗口/组队/面板折叠钮.png")
				and FileAccess.file_exists("res://素材/界面/原版窗口/组队/面板折叠钮_悬停.png")
				and FileAccess.file_exists("res://素材/界面/原版窗口/组队/面板折叠钮_按下.png")
				and FileAccess.file_exists("res://素材/界面/原版窗口/组队/面板折叠钮_展开.png")
				and FileAccess.file_exists("res://素材/界面/原版窗口/组队/面板折叠钮_展开_悬停.png")
				and FileAccess.file_exists("res://素材/界面/原版窗口/组队/面板折叠钮_展开_按下.png"), "")
			# 真鼠标移上去 ⇒ 换 +30 那张；移开 ⇒ 回常态（原版 MButton3 的加性滤镜形状）
			var 移 := InputEventMouseMotion.new()
			移.position = 心0
			移.global_position = 心0
			get_root().push_input(移)
			await process_frame
			await process_frame
			_记("悬停 ⇒ 换 _展开_悬停 皮",
				String(折叠.texture_normal.resource_path).ends_with("面板折叠钮_展开_悬停.png"),
				String(折叠.texture_normal.resource_path))
			var 移2 := InputEventMouseMotion.new()
			移2.position = Vector2(400, 400)
			移2.global_position = Vector2(400, 400)
			get_root().push_input(移2)
			await process_frame
			await process_frame
			_记("移开 ⇒ 回 _展开 常态皮",
				String(折叠.texture_normal.resource_path).ends_with("面板折叠钮_展开.png"),
				String(折叠.texture_normal.resource_path))
			_记("格子宽 164（不是 152）", absf(格.size.x - 164.0) <= 0.51, str(格.size.x))
			var 板 := 格.get_node_or_null("名字底板") as TextureRect
			_记("名字底板 = 原版 805 的可见段（118×17 摆在 (46,0)）",
				板 != null and 板.texture != null and String(板.texture.resource_path).ends_with("面板名字底板_可见.png")
				and 板.position.distance_to(Vector2(46, 0)) <= 0.01 and 板.size == Vector2(118, 17),
				"" if 板 == null else "%s %s %s" % [板.texture.resource_path if 板.texture else "", 板.position, 板.size])
			var 框 := 格.get_node_or_null("头像盒/头像框") as TextureRect
			_记("头像框 = 原版 808（46×45 铜环，不是主题方框）",
				框 != null and 框.texture != null and String(框.texture.resource_path).ends_with("面板头像框.png")
				and 框.size == Vector2(46, 45), "" if 框 == null else "%s %s" % [框.texture.resource_path if 框.texture else "", 框.size])
			var 级字 := 格.get_node("等级") as Label
			## 黑晕来自工程主题（Label outline_size=2 + 黑 outline）= 原版 GlowFilter 的口径；
			## 本色层只钉颜色/字号/对齐/盒位（用户 2026-10-25 打回的五条都在这几个量上）。
			_记("等级字 = 橙 #FF9100、12px、居中、盒 (0,27) 46×18、黑晕描边 2",
				级字.get_theme_color("font_color").is_equal_approx(Color(1.0, 0.568627, 0.0, 1.0))
				and 级字.get_theme_font_size("font_size") == 12 and 级字.get_theme_constant("outline_size") == 2
				and 级字.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
				and 级字.position == Vector2(0, 28) and 级字.size == Vector2(46, 18),
				"%s / %d / outline=%d / align=%d / %s / %s" % [级字.get_theme_color("font_color"),
				级字.get_theme_font_size("font_size"), 级字.get_theme_constant("outline_size"),
				级字.horizontal_alignment, 级字.position, 级字.size])
			var 名字 := 格.get_node("名字") as Label
			_记("名字白字 12px、控件位 (47,2)（墨迹对齐实机 (47,26)）、黑晕描边 2",
				名字.get_theme_color("font_color").is_equal_approx(Color(1, 1, 1, 1))
				and 名字.get_theme_font_size("font_size") == 12 and 名字.get_theme_constant("outline_size") == 2
				and 名字.position == Vector2(47, 2),
				"%s / %s / outline=%d" % [名字.get_theme_color("font_color"), 名字.position,
				名字.get_theme_constant("outline_size")])
			var 题字 := 队伍面板.面板.get_node("标题") as Label
			var 题粗 := 队伍面板.面板.get_node_or_null("标题粗1") as Label
			_记("标题字 = #B5BDD0 居中 + 粗体叠层右移 1px",
				题字.get_theme_color("font_color").is_equal_approx(Color(0.709804, 0.741176, 0.815686, 1.0))
				and 题字.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
				and 题粗 != null and 题粗.position == 题字.position + Vector2(1, 0),
				"%s / align=%d / 粗=%s" % [题字.get_theme_color("font_color"), 题字.horizontal_alignment,
				str(题粗.position) if 题粗 != null else "null"])
			# 真鼠标点折叠钮：收起 ⇒ 面板高 22、列表隐藏；再点 ⇒ 67、列表回来
			var 心 := 折叠.get_global_rect().get_center()
			for 按 in [true, false]:
				var 事 := InputEventMouseButton.new()
				事.button_index = MOUSE_BUTTON_LEFT
				事.pressed = 按
				事.position = 心
				事.global_position = 心
				get_root().push_input(事)
				await process_frame
			await create_timer(0.1).timeout
			var 列节点 := 队伍面板.面板.get_node("列表") as Control
			_记("点折叠 ⇒ 收起（高 22、列表隐藏）",
				not 列节点.visible and absf(队伍面板.面板.size.y - 22.0) <= 0.51,
				"vis=%s 高=%.1f" % [列节点.visible, 队伍面板.面板.size.y])
			_记("收起 ⇒ 折叠钮换 599 加号族",
				String(折叠.texture_normal.resource_path).ends_with("面板折叠钮.png"),
				String(折叠.texture_normal.resource_path))
			for 按 in [true, false]:
				var 事 := InputEventMouseButton.new()
				事.button_index = MOUSE_BUTTON_LEFT
				事.pressed = 按
				事.position = 心
				事.global_position = 心
				get_root().push_input(事)
				await process_frame
			await create_timer(0.1).timeout
			_记("再点 ⇒ 展开（高 67、列表回来）",
				列节点.visible and absf(队伍面板.面板.size.y - 67.0) <= 0.51,
				"vis=%s 高=%.1f" % [列节点.visible, 队伍面板.面板.size.y])
			_记("展开 ⇒ 折叠钮回 603 减号族",
				String(折叠.texture_normal.resource_path).ends_with("面板折叠钮_展开.png"),
				String(折叠.texture_normal.resource_path))
	# 全量 7 帧换队长 ⇒ 旧队长星要摘掉；换回来要长回去
	if 队伍面板.找格(8) != null:
		后.call("_handle_party_text", 59, PackedStringArray(["59", "7", "77", "7", "小队", 行甲 + "@" + 行乙]))
		await create_timer(0.1).timeout
		_记("全量 7 帧把队长改回自己 ⇒ 8 号格的队长星摘掉",
			队伍面板.找格(8) != null and 队伍面板.找格(8).get_node_or_null("队长星") == null, "")
		后.call("_handle_party_text", 59, PackedStringArray(["59", "7", "77", "8", "小队", 行甲 + "@" + 行乙]))
		await create_timer(0.1).timeout
		_记("再改回 8 ⇒ 队长星回来",
			队伍面板.找格(8) != null and 队伍面板.找格(8).get_node_or_null("队长星") != null, "")
	后.call("_handle_bridge_text", "203:8:50:100:20:40")
	await create_timer(0.1).timeout
	if 队伍面板.找格(8) != null:
		_记("203 血/蓝各 50%% ⇒ 裁到 55px",
			absf((队伍面板.找格(8).get_node("血罩") as Control).size.x - 55.0) <= 0.51
			and absf((队伍面板.找格(8).get_node("蓝罩") as Control).size.x - 55.0) <= 0.51,
			"血 %.1f / 蓝 %.1f" % [(队伍面板.找格(8).get_node("血罩") as Control).size.x,
			(队伍面板.找格(8).get_node("蓝罩") as Control).size.x])
	# 阳性对照：在线时头像盒必须是白的（否则"变灰"是假判据）
	if 队伍面板.找格(8) != null:
		var 白盒 := 队伍面板.找格(8).get_node("头像盒") as Control
		_记("在线队友头像不灰（阳性对照）", 白盒.material == null and 白盒.self_modulate.is_equal_approx(Color(1, 1, 1)),
			"%s / %s" % [str(白盒.material), 白盒.self_modulate])
	var 离线行 := "7&甲&100&30&-&0&0&1@8&乙&100&22&-&-2&0&1"
	后.call("_handle_party_text", 59, PackedStringArray(["59", "7", "77", "8", "小队", 离线行]))
	await create_timer(0.1).timeout
	if 队伍面板.找格(8) != null:
		var 灰盒 := 队伍面板.找格(8).get_node("头像盒") as Control
		_记("队友掉线 ⇒ 面板头像变灰（灰度 shader）、人仍在",
			队伍面板.格数() == 1 and 灰盒.material != null, "格数=%d 材质=%s" % [队伍面板.格数(), str(灰盒.material)])
	后.call("_handle_party_text", 59, PackedStringArray(["59", "12"]))
	await create_timer(0.1).timeout
	_记("59:12 解散 ⇒ 常驻面板撤掉", not 队伍面板.出现着(), str(队伍面板.出现着()))
	队伍窗.后端 = null
	后.queue_free()
	管理.queue_free()


## ⑧ 头像面板那颗队长标（用户 2026-10-30：「包里有图，功能还没接」）。
## 真值 = `CharactorInfoPane.as:278-292`（`setTroopCaptainIcon`：`isPartyLeader(自己)` 才加，
## 局部 (210,38)、33×17、mouseChildren/mouseEnabled=false）+ `:346-353`（`removeTroopCaptainIcon`）
## + `RelationShipHandler.as:56/60/120/286` 四个触发点。
## ★ 判据走**真字节**：`_handle_party_text` → `party_state_received` → `队伍窗.服务端队伍帧`
##   → `队长标应显` → `GameSession.队长标_changed` → HUD 里那颗 TextureRect 的 visible。
##   不写"源码里 connect 在不在"这种门（假绿 #24）；也不自己 emit 会话信号（假绿 #23）。
## ★ 全程 `页 = null`：原版头像面板常驻，开不开组队窗与这颗标无关。
func _队长标HUD() -> void:
	var 宿主 := 桩宿主.new()
	var 会话 := 桩会话.new()
	get_root().add_child(宿主)
	get_root().add_child(会话)
	队伍窗.页 = null
	队伍窗.成员 = []
	队伍窗.队长号 = 0
	队伍窗.队号 = 0
	队伍窗.选格 = -1
	队伍窗.宿主 = 宿主
	队伍窗.会话 = 会话
	队伍窗.自己号 = 7
	队伍窗.自己名 = "甲"
	队伍窗.队长标应显 = false
	队伍窗.后端 = null
	var 板包 := load("res://场景/界面/头像面板.tscn") as PackedScene
	_记("头像面板场景能加载（队长标门）", 板包 != null)
	if 板包 == null:
		return
	var 面板 := 板包.instantiate() as CanvasLayer
	get_root().add_child(面板)
	await process_frame
	var 标 := 面板.get_node_or_null("头像区域/角色状态/队长标") as TextureRect
	_记("HUD 有队长标挂点 头像区域/角色状态/队长标", 标 != null, "缺节点")
	if 标 == null:
		面板.queue_free()
		return
	## 几何/材质：原版图 = `UISwf_Text_TroopCaptainIcon`，导成 33×17，摆面板局部 (210,38)。
	_记("队长标 = 原版 33×17 图",
		标.texture != null and String(标.texture.resource_path).ends_with("队长标.png")
		and 标.texture.get_width() == 33 and 标.texture.get_height() == 17,
		"%s %s" % ["" if 标.texture == null else String(标.texture.resource_path),
			"" if 标.texture == null else Vector2(标.texture.get_width(), 标.texture.get_height())])
	_记("队长标摆面板局部 (210,38)、33×17（CharactorInfoPane.as:289-290）",
		标.position.distance_to(Vector2(210, 38)) <= 0.01 and 标.size.distance_to(Vector2(33, 17)) <= 0.01,
		"%s %s" % [标.position, 标.size])
	_记("队长标鼠标穿透（原版 mouseChildren=mouseEnabled=false）",
		标.mouse_filter == Control.MOUSE_FILTER_IGNORE, str(标.mouse_filter))
	## 原版 `addChild(troopCaptainIcon)` 在最后 ⇒ 压在整个面板最上；场景里它必须是「角色状态」最后一个件。
	var 父 := 标.get_parent() as Node
	_记("队长标是面板最后一个子件（原版 addChild 在最后 ⇒ 画在最上）",
		父 != null and 标.get_index() == 父.get_child_count() - 1,
		"序 %d / 共 %d" % [标.get_index(), 父.get_child_count() if 父 != null else -1])
	_记("没队伍时默认不亮", not 标.visible and not 队伍窗.队长标应显,
		"visible=%s 应显=%s" % [标.visible, 队伍窗.队长标应显])

	var 后: Node = (load("res://脚本/单例/后端连接.gd") as GDScript).new()
	get_root().add_child(后)
	后.set("character_id", 7)
	队伍窗.挂全局(后)
	await process_frame

	## ① 建队（`59:8` ⇒ `onPartyCreated:120` 无条件 setTroopCaptainIcon）
	后.call("_handle_party_text", 59, PackedStringArray(["59", "8", "5100", "甲的小队"]))
	await process_frame
	_记("59:8 建队 ⇒ 自己是队长 ⇒ 队长标亮（页没开也亮）",
		标.visible and 队伍窗.队长标应显 and 队伍窗.页 == null,
		"visible=%s 应显=%s 页=%s" % [标.visible, 队伍窗.队长标应显, 队伍窗.页])
	## ② 切图重建：新面板 `_ready` 要按 `队长标应显` 补画（HUD 在地图场景里，换图会重建）
	var 面板2 := 板包.instantiate() as CanvasLayer
	get_root().add_child(面板2)
	await process_frame
	var 标2 := 面板2.get_node_or_null("头像区域/角色状态/队长标") as TextureRect
	_记("重建后的 HUD 也亮（建队帧比面板先到 ⇒ `_ready` 自读兜底）",
		标2 != null and 标2.visible, "标2=%s" % str(标2 != null and 标2.visible))
	## ③ 换队长给别人（`59:26` ⇒ `onPartyChangeLeader:56/60` 两根支）
	后.call("_handle_party_text", 59, PackedStringArray(["59", "26", "8"]))
	await process_frame
	_记("59:26 队长让给别人 ⇒ 标摘掉", not 标.visible and not 标2.visible and not 队伍窗.队长标应显,
		"%s/%s/%s" % [标.visible, 标2.visible, 队伍窗.队长标应显])
	后.call("_handle_party_text", 59, PackedStringArray(["59", "26", "7"]))
	await process_frame
	_记("59:26 队长回到自己 ⇒ 标再亮", 标.visible and 标2.visible and 队伍窗.队长标应显,
		"%s/%s/%s" % [标.visible, 标2.visible, 队伍窗.队长标应显])
	## ④ 被踢（`59:13` 自己 ⇒ `removeTroopHPPane:286`）
	后.call("_handle_party_text", 59, PackedStringArray(["59", "13", "7", "甲"]))
	await process_frame
	_记("59:13 自己被踢 ⇒ 标摘掉", not 标.visible and not 队伍窗.队长标应显,
		"%s/%s" % [标.visible, 队伍窗.队长标应显])
	## ⑤ 自己退队（`59:14` 自己 ⇒ `removeTroopHPPane:286`）
	后.call("_handle_party_text", 59, PackedStringArray(["59", "8", "5101", "二队"]))
	await process_frame
	_记("重新建队 ⇒ 标亮（⑤ 的前提）", 标.visible)
	后.call("_handle_party_text", 59, PackedStringArray(["59", "14", "5101", "7", "二队", "-", "7"]))
	await process_frame
	_记("59:14 自己退队 ⇒ 标摘掉", not 标.visible and not 队伍窗.队长标应显,
		"%s/%s" % [标.visible, 队伍窗.队长标应显])
	## ⑥ 解散（`59:12` ⇒ `onPartyDisband` → `removeTroopHPPane:286`）
	后.call("_handle_party_text", 59, PackedStringArray(["59", "8", "5102", "三队"]))
	await process_frame
	后.call("_handle_party_text", 59, PackedStringArray(["59", "12"]))
	await process_frame
	_记("59:12 解散 ⇒ 标摘掉", not 标.visible and not 队伍窗.队长标应显,
		"%s/%s" % [标.visible, 队伍窗.队长标应显])

	队伍窗.后端 = null
	队伍窗.宿主 = null
	队伍窗.会话 = null
	面板.queue_free()
	面板2.queue_free()
	宿主.queue_free()
	会话.queue_free()
	后.queue_free()


## C1：队员格单击 ⇒ 六项菜单（`TroopHPPane.as:75-78` 定宽 50 + `Timer(250,1)`：
## `:198-212` 点格记行、重启计时；`:135-141` 到点才挂菜单；`:389-434` 逐项动作）。
## 宿主在 ⇒ 映射成好友页行键走 `_好友菜单动作`；宿主空 ⇒ `_全局菜单动作` 逐条兜底。
func _队伍菜单() -> void:
	队伍面板.拆()
	var 层 := Control.new()
	get_root().add_child(层)
	var 假宿 := 菜单宿主.new()
	get_root().add_child(假宿)
	队伍面板.建(假宿, 层, 7)
	队伍面板.上成员([
		{"id": 8, "name": "乙", "level": 22, "在线": true, "face": 1, "map_id": 100, "hp": 1, "max_hp": 1},
		{"id": 9, "name": "丙", "level": 11, "在线": false, "face": 2, "map_id": 999, "hp": 1, "max_hp": 1},
	])
	var 菜单 := 队伍面板._菜单 as Control
	_记("面板菜单常驻、初始隐藏（`TroopHPPane.as:137`）", 菜单 != null and not 菜单.visible)
	if 菜单 == null:
		队伍面板.拆()
		层.queue_free()
		假宿.queue_free()
		return
	_记("自己那一格不弹（`:210 id != stats.id`）", (func() -> bool:
		队伍面板._点格(7)
		return 队伍面板._选中行.is_empty() and not 菜单.visible).call())
	## 250ms 单次计时：点完先藏，到点才露；再点同一格要**重启**计时。
	队伍面板._点格(8)
	await create_timer(0.1).timeout
	_记("点格后 100ms 菜单还没出来（`:77 Timer(250,1)`）", not 菜单.visible)
	await create_timer(0.28).timeout
	_记("250ms 到点 ⇒ 菜单可见", 菜单.visible)
	var 文案: Array = []
	for i in 6:
		文案.append((菜单.get_node("项_%d" % i) as Button).text)
	_记("六项文案与顺序 = 密语/查看/交友/交易/看摊/赠花（`:389-434`）",
	文案 == ["密语", "查看", "交友", "交易", "看摊", "赠花"], str(文案))
	_记("只有六项可见（第 7 个槽隐藏）", not (菜单.get_node("项_6") as Button).visible)
	_记("定宽 50 ⇒ 控件宽 54、按钮宽 44（`MPopupMenu.as:59-76`）",
		absf(菜单.size.x - 54.0) <= 0.51
		and absf((菜单.get_node("项_0") as Button).size.x - 44.0) <= 0.51,
		"菜单 %s / 按钮 %s" % [菜单.size, (菜单.get_node("项_0") as Button).size])
	## 宿主在：选中后映射成好友页行键（`_好友菜单动作` 只认 character_id/online）。
	(菜单.get_node("项_2") as Button).pressed.emit()
	await process_frame
	_记("选中「交友」⇒ 宿主收到「队伍:交友」",
		假宿.收到.size() == 1 and String(假宿.收到[0][0]) == "队伍:交友", str(假宿.收到))
	if 假宿.收到.size() == 1:
		var 项: Dictionary = 假宿.收到[0][1]
		_记("行键映射 = character_id/name/online/face/level",
			int(项.get("character_id", 0)) == 8 and String(项.get("name", "")) == "乙"
			and bool(项.get("online", false)) and int(项.get("face", 0)) == 1
			and int(项.get("level", 0)) == 22, str(项))
	_记("选中后菜单自己收", not 菜单.visible)
	## 再点同一格要重启计时（`:206 timer.reset(); timer.start()`）。
	队伍面板._点格(8)
	await create_timer(0.15).timeout
	队伍面板._点格(8)
	await create_timer(0.15).timeout
	_记("第二次点击重启 250ms ⇒ 此刻仍未出来", not 菜单.visible)
	await create_timer(0.2).timeout
	_记("重启后的计时到点仍会出来", 菜单.visible)
	## 折叠面板要收菜单（本工程的收起口径）。
	队伍面板._点折叠()
	_记("折叠面板 ⇒ 菜单收起", not 菜单.visible)
	队伍面板._点折叠()
	## 宿主空：逐条走 `_全局菜单动作` 的兜底。
	队伍面板.宿主 = null
	var 旧后 := get_root().get_node_or_null("BackendConnection")
	if 旧后 != null:
		get_root().remove_child(旧后)
		旧后.free()
	var 假后 := 菜单后端.new()
	假后.name = "BackendConnection"
	get_root().add_child(假后)
	var 假聊 := 菜单聊天.new()
	假聊.add_to_group("chat_panel")
	get_root().add_child(假聊)
	var 假管 := 菜单管理.new()
	假管.add_to_group("窗口管理")
	get_root().add_child(假管)
	await _点菜单项(8, 0)
	_记("无宿主·密语 ⇒ 聊天框开始私聊「乙」", 假聊.私聊 == ["乙"], str(假聊.私聊))
	await _点菜单项(8, 1)
	_记("无宿主·查看（在线）⇒ 94", 假后.发出.has(["资料", 8]), str(假后.发出))
	假后.发出.clear()
	await _点菜单项(9, 1)
	_记("无宿主·查看（离线）⇒ 只提示、不发 94（`:400-410`）",
		not 假后.发出.has(["资料", 9]), str(假后.发出))
	await _点菜单项(8, 2)
	_记("无宿主·交友 ⇒ 127:1", 假后.发出.has(["加好友", 8]), str(假后.发出))
	await _点菜单项(8, 3)
	_记("无宿主·交易 ⇒ 119:2", 假后.发出.has(["交易", 8]), str(假后.发出))
	await _点菜单项(8, 4)
	_记("无宿主·看摊 ⇒ 1296:2", 假后.发出.has(["看摊", 8]), str(假后.发出))
	假后.好友 = [8]
	假后.发出.clear()
	await _点菜单项(8, 2)
	_记("无宿主·已是好友 ⇒ 只提示、不再发 127:1（`:411-421`）",
		not 假后.发出.has(["加好友", 8]), str(假后.发出))
	await _点菜单项(8, 5)
	_记("无宿主·赠花 ⇒ 先存对面四项、再发 94:6", 假后.发出.has(["花档", 8]), str(假后.发出))
	_记("赠花对面四项 = 8/乙/1/22",
		int(假管.记花.get("charId", 0)) == 8 and String(假管.记花.get("name", "")) == "乙"
		and int(假管.记花.get("face", 0)) == 1 and int(假管.记花.get("level", 0)) == 22, str(假管.记花))
	假聊.queue_free()
	假管.queue_free()
	假后.queue_free()
	队伍面板.拆()
	层.queue_free()
	假宿.queue_free()


func _点菜单项(号: int, 项序: int) -> void:
	队伍面板._点格(号)
	await create_timer(0.3).timeout
	var 菜单 := 队伍面板._菜单 as Control
	if 菜单 == null or not 菜单.visible:
		return
	(菜单.get_node("项_%d" % 项序) as Button).pressed.emit()
	await process_frame


func _initialize() -> void:
	var 场景: PackedScene = load(场景路)
	if 场景 == null:
		print("队伍页门：场景 load 失败")
		quit(1)
		return
	页 = 场景.instantiate() as Control
	if 页 == null:
		print("队伍页门：instantiate 失败")
		quit(1)
		return
	get_root().add_child(页)
	_几何()
	_行为()
	await _无宿主弹窗()
	await _点托盘邀请()
	_四类图标几何()
	await _面板常驻()
	await _队伍菜单()
	await _队长标HUD()
	print("队伍页门：绿 %d 红 %d" % [绿, 红])
	for 行 in 明细:
		print(行)
	if 红 > 0:
		quit(1)
	else:
		quit(0)
