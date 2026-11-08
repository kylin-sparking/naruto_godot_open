extends SceneTree

## 心法页（原版 `com/mxw/uifl/controls/XinfaWindow` 275×295）的**行为门**。
##
## 逐件几何不在这里 —— `测试/原版服务窗回归测试.gd` 已经把 17 扇逐个比
## `数据/界面/<页>_期望.json`、还会重跑生成器比场景（手改 .tscn 立刻红）。这里量的是
## 那一族门结构性看不见的东西 —— **运行期才存在的那棵树**（列表格是控制器按数据建的，
## `.tscn` 里一个字节都没有）与**这条链上到底发了几条字节、什么顺序**。
##
## 分三节，每节各抓一种复发：
##
## §真页（真的 `窗口管理` + 真的鼠标事件 ⇒ 防"窗做出来了但没人点得开"）
##  1. 点球那条链：`技能面板.gd` 的 xinfa 分支 ⇒ `request_feature(心法)` ⇒ `窗口管理.打开或收起`
##     ⇒ `功能窗口` match 表 ⇒ 页根 = `原版心法窗内容`、标题「修炼心法」、外框 275×295。
##  2. ★ 常态**列表不在窗上**（`:73-80` 从没 addChild）⇒ 真点那枚箭头才浮出，再点收回。
##  3. 真点列表里第二格 ⇒ 主格图标/名/层数跟着换、列表收回（`:245-249`）。
##  4. 心法**不连背包**（原版走 `reverseDisplay`，不是 `centerTwoWindow`）⇒ 不许出现在
##     `窗口管理` 的 `伴随背包` / `居中弹` 里。
##
## §数据面（假宿主 + 假后端记账 ⇒ 防"发了什么包没人知道"与"列表列错东西"）
##  5. 列的是**已学 ∩ xinfa==1**，不是全部 21 条，也不是全部已学（`DataCenter.as:2058-2072`）
##     ⇒ 喂三条心法 + 一枚非心法 ⇒ 只有三格、非心法那枚不出现。
##  6. 格摆位 `y = 40*i + 2`（`:223`）、图标 (3,3) **原尺寸**（`SkillCell.setSkillIcon:302-303`）、
##     层数角标在元件 130 时间轴那格 (2,25) 且 `floor > 0` 才显。
##  7. ★ 只有一枚（或零枚）时滚动区高压成 `90 >> 1 = 45`（`:313`）；两枚以上才是 90。
##  8. 零枚 ⇒ 那枚箭头 `enabled=false`（`:312`）⇒ 点它**什么都不该发生**。
##  9. ★ 开窗只发**一条** `86:7`：回帧后宿主会重渲染这一页，若渲染里无条件再发 ⇒
##     7→3→渲染→7 每帧一条包。这条判据就是抓那个环的。
## 10. 主格**只由回帧填**（`:85-96 setSeleclSkillData` 的 `id != 0` 闸门）⇒ 没回帧时
##     名/层数/图标三样全空，**不许**拿列表第一枚凑（原版没有这行）。
## 11. 回帧那颗不在已学列表里 ⇒ 主格保持空（原版 `getSkillObject(id)` 拿不到就不填，
##     而且 `cleanSelectSkillCell()` 在 `if` 里 ⇒ 也不会清空已有的）。
## 12. 「确定」= 先发 `6:<id>` 再关窗（`onClickOkBtn` 的序）；**没选中时一颗字节都不发**、
##     仍然关窗；「取消」**永远不发**（派发的是 XINFA_XIULIAN_CANCEL，全工程只注册了
##     OK 与 DAKAI 两个监听 —— `UI.as:1086-1087`）。
## 13. 本工程这条链上**没有任何 toast**（原版也没有）⇒ 通知必须一条都不出。
##
## §接口（防"假宿主失配 = 假通过"）
## 14. 假宿主用到的四个成员（`_content` / `_backend` / `close` / `_通知`）与假后端用到的
##     四个（`authoritative_skills` / `authoritative_heal` / `request_xinfa_show` /
##     `request_xinfa_change`）在**真的** `功能窗口.gd` / `后端连接.gd` 上逐条存在，
##     且真的那两个 `request_` 发的就是 `86:7` / `86:6:<id>`。
##
## ⚠ 三条硬口径（工程里踩过）：`push_input` 前先钉 `root.size`；悬停分两跳、改状态与断言
##   之间隔 3 帧；**不落存档** —— 跑前记 `user://玩家数据.json` 的字节、跑完断言没变，
##   中途塞进 `authoritative_skills` 的夹具逐条删回去并断言字典回到原样。
##
## 运行：Godot --headless --path . --script res://测试/心法页回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 心法场景 := preload("res://场景/界面/窗口/心法/心法窗.tscn")
const 心法控制器 := preload("res://脚本/界面/窗口/心法窗.gd")
const 假宿主脚本 := preload("res://测试/假心法宿主.gd")

const 格宽 := 40.0
const 区高 := 90.0
## 夹具：三条心法（id 就是 GameData `Skill` 段的七位补零键去掉前导零）+ 一枚**非心法**
const 心一 := 1000		# 体能强化
const 心二 := 1001		# 查克拉强化
const 心三 := 1004		# 替身术
const 非心 := 1001001		# 在 Skill 段里 `xinfa != 1` ⇒ 绝不该出现在这张列表

var 场景: Node
var 管: Node
var 假: Node
var 页: Control
var 真后端: Node
var 真技能快照 := {}
var 红数 := 0
var 日志: Array[String] = []
var 走完: Array[String] = []
var 存档前 := ""
var 鼠位 := Vector2.ZERO


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


func _悬停(位置: Vector2) -> void:
	var 中 := (鼠位 + 位置) * 0.5
	var 移 := InputEventMouseMotion.new()
	移.position = 中
	移.global_position = 中
	root.push_input(移)
	鼠位 = 中
	await _等(2)
	移 = InputEventMouseMotion.new()
	移.position = 位置
	移.global_position = 位置
	root.push_input(移)
	鼠位 = 位置
	await _等(3)


func _点(位置: Vector2) -> void:
	await _悬停(位置)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位置
	按.global_position = 位置
	root.push_input(按)
	await _等(2)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 位置
	放.global_position = 位置
	root.push_input(放)
	await _等(3)


func _点钮(钮: Control) -> void:
	await _点(钮.get_global_rect().get_center())


func _存档字节() -> String:
	var 读 := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if 读 == null else 读.get_as_text()


## 页里那些**运行期才有**的件（`.tscn` 查无 ⇒ 只能从跑起来的树上取）
func _区() -> ScrollContainer:
	return 页.get_node("心法列表") as ScrollContainer


func _内容() -> Control:
	return 页.get_node("心法列表/心法列表_内容") as Control


func _箭头() -> Control:
	return 页.get_node("选择心法钮") as Control


func _格们() -> Array:
	var 出: Array = []
	for 子 in _内容().get_children():
		if String(子.name).begins_with("格"):
			出.append(子)
	return 出


func _主格图标() -> TextureRect:
	return 页.get_node("主格/主格图标") as TextureRect


## 重开一页（假宿主那条路）：清掉上一页、换夹具、记流水归零。
## ⚠ `_刚开窗 = true` —— 这条路径模拟的是"玩家点球开窗"（`功能窗口.open_page`）。
func _重开(已学: Dictionary, 回帧: Dictionary) -> Control:
	for 子 in 假._content.get_children():
		假._content.remove_child(子)
		子.queue_free()
	假._backend.authoritative_skills = 已学
	假._backend.authoritative_heal = 回帧
	# ⚠ 这两个是 `Array[String]`（带类型的数组），**不能**赋一个无类型的 `[]` 进去 ——
	#   运行期报 `Invalid assignment of property or key '流水' with value of type 'Array'`
	#   然后静默继续 ⇒ 上面那些 `流水 == ["7"]` 判据全在比旧账（工程里"门绿但没跑"的原型）。
	假.流水.clear()
	假.通知.clear()
	假.关窗次数 = 0
	假._刚开窗 = true
	页 = 心法控制器.渲染(假, 心法场景)
	return 页


## 回帧到达后宿主干的事：`heal_state_received` → `_refresh_current()` → 整页重建
## （`_flush_refresh()` 会先把 `_刚开窗` 置假）。**不清流水** —— 流水要跨这次重建连着看。
func _刷新() -> Control:
	假._content.remove_child(页)
	页.queue_free()
	假._刚开窗 = false
	页 = 心法控制器.渲染(假, 心法场景)
	return 页


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	存档前 = _存档字节()
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	真后端 = root.get_node_or_null("/root/BackendConnection")
	if 管 == null:
		_收尾("地图场景下没有 窗口管理")
		return
	假 = 假宿主脚本.new()
	假.name = "假心法宿主"
	root.add_child(假)
	await _等(2)
	管.call("全部关闭")
	await _量真页()
	await _量数据面()
	await _量接口()
	_收尾()


## ── §真页：真的窗口管理 + 真的鼠标事件 ──────────────────────────────────────
func _量真页() -> void:
	日志.append("=== §真页 275×295「修炼心法」===")
	if 真后端 == null:
		_记(false, "有 /root/BackendConnection（列表数据源 = authoritative_skills）")
		return
	# 夹具只塞内存字典、不 `_apply_skill`（那条会带会话落盘），跑完逐条删回去
	真技能快照 = 真后端.authoritative_skills.duplicate(true)
	真后端.authoritative_skills[心一] = {"level": 7, "master_level": 0}
	真后端.authoritative_skills[心二] = {"level": 3, "master_level": 0}
	真后端.authoritative_skills[心三] = {"level": 0, "master_level": 0}
	真后端.authoritative_skills[非心] = {"level": 9, "master_level": 0}

	var 面板文 := FileAccess.get_file_as_string("res://脚本/界面/技能面板.gd")
	_记(面板文.contains("_session.request_feature(\"心法\")"),
			"心法球那条链的头一环在：`技能面板.gd` 的 xinfa 分支 ⇒ `request_feature(心法)`")
	管.call("打开", "心法")
	await _等(6)
	var 窗: Node = 管._窗口们.get("心法") as Node
	_记(窗 != null, "落地页「心法」真开出来了（`窗口管理.打开` ⇒ `功能窗口._render_xinfa`）")
	if 窗 == null:
		_清真夹具()
		return
	var 根: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			根 = 子 as Control
	_记(根 != null and String(根.name) == "原版心法窗内容", "页根 = %s" % (根.name if 根 != null else "无"))
	页 = 根
	if 页 == null:
		_清真夹具()
		return
	_记(String(窗._title.text) == "修炼心法",
			"标题「修炼心法」（`:123` CN.XINFA_WINDOW_TITLE，实测「%s」）" % String(窗._title.text))
	_记(absf(窗._window.size.x - 275.0) < 0.6 and absf(窗._window.size.y - 295.0) < 0.6,
			"外框 275×295（`:253-255` background 那两行），实测 %.0f×%.0f"
			% [窗._window.size.x, 窗._window.size.y])
	_记(not (管.伴随背包.has("心法")) and not (管.居中弹.has("心法")),
			"心法**不连背包、也不居中**（原版走 `Client.as:8034 reverseDisplay`，不是 `centerTwoWindow`）"
					+ "⇒ 不许进 伴随背包/居中弹")

	# ② 常态列表不在窗上
	_记(_区() != null and not _区().visible,
			"刚开窗 列表区 visible=false（`:191-200` 建了 `skillScrollPane` 但从没 addChild ⇒ "
			+ "运行期靠那枚箭头挂上/摘下）")
	_记(_箭头() != null and _箭头().mouse_filter == Control.MOUSE_FILTER_STOP,
			"有已学心法 ⇒ 箭头可点（`:312` `selectSkillBtn.enabled = len > 0`）")
	await _点钮(_箭头())
	_记(_区().visible, "真点箭头 ⇒ 列表浮出（`:76-80` addChild 那一支）")
	var 格们 := _格们()
	_记(格们.size() == 3,
			"列表 3 格 = 已学 ∩ xinfa==1（夹具喂了 4 条、其中 %d 不是心法）—— 实测 %d 格"
			% [非心, 格们.size()])
	_记(_区().size.y == 区高, "三枚 ⇒ 区高 90（`:313` len>1 那一支），实测 %.0f" % _区().size.y)
	if 格们.size() == 3:
		await _点钮(格们[1] as Control)
		var 名标 := 页.get_node("心法名") as Label
		var 层标 := 页.get_node("心法层数") as Label
		_记(String(名标.text) == "查克拉强化",
				"真点第二格 ⇒ 名标「%s」（= 心法表里 %d 那条的名称，`:89` skillName.text = param1.name）"
				% [String(名标.text), 心二])
		_记(String(层标.text) == "当前层数:3",
				"层标「%s」= CN.CURRENT_CENGSHU（语言表逐字，冒号是**半角**）+ floor（夹具 level=3）"
				% String(层标.text))
		_记(not _区().visible, "点完一格列表收回（`:245-249` setSeleclSkillData 之后再 onClickSkillBtn）")
		var 主图 := _主格图标()
		var 主图路 := String(主图.texture.resource_path).get_file() if 主图.texture != null else "空"
		_记(主图.texture != null,
				"主格图标真挂上了（`:87-88` setCellValue + setSkillIcon）：%s" % 主图路)
	await _点钮(_箭头())
	_记(_区().visible, "收回后再点箭头又浮出（开关式，`:73-76` 判 parent）")
	await _点钮(页.get_node("确定钮") as Button)
	await _等(4)
	# ⚠ 本工程的 `close()` 只把遮罩藏起来（`功能窗口.gd:568-573`，页面树留着复用），
	#   所以这条判的是**遮罩**，不是"节点被销毁"。
	_记(not bool(窗._overlay.visible), "真点「确定」把窗关了（`:114` onCloseBtnClick ⇒ 遮罩隐藏）")
	_清真夹具()
	走完.append("真页")


func _清真夹具() -> void:
	for 号 in [心一, 心二, 心三, 非心]:
		真后端.authoritative_skills.erase(号)
	_记(str(真后端.authoritative_skills) == str(真技能快照),
			"真后端的 authoritative_skills 夹具**逐条删回去**了（跑前 %d 条 / 跑后 %d 条）"
			% [真技能快照.size(), 真后端.authoritative_skills.size()])


## ── §数据面：假宿主 + 假后端记账 ────────────────────────────────────────────
func _量数据面() -> void:
	日志.append("=== §数据面（假后端记字节）===")

	# ⑨ 零枚：箭头吃掉指针 + 点它什么都不发生
	var 页零 := _重开({}, {})
	var 区零 := 页零.get_node("心法列表") as ScrollContainer
	var 箭零 := 页零.get_node("选择心法钮") as Control
	_记(箭零.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"零枚 ⇒ 箭头 MOUSE_FILTER_IGNORE（`:312` enabled=false；MButton3 的 disabled 就是不吃指针）")
	var 空点 := InputEventMouseButton.new()
	空点.button_index = MOUSE_BUTTON_LEFT
	空点.pressed = true
	箭零.gui_input.emit(空点)
	_记(not 区零.visible, "零枚时点箭头 列表**不**浮出（`:69` `if(data.length > 0)` 那圈闸门）")
	_记(区零.size.y == 45.0, "零枚 ⇒ 区高 45（`:313` `_height >> 1`），实测 %.0f" % 区零.size.y)

	# ⑩ 没回帧 ⇒ 主格三样全空 + 一条 7
	_记(str(页零.get_node("心法名").text) == "" and str(页零.get_node("心法层数").text) == "",
			"没回帧 ⇒ 名/层数两枚 Label 是**空串**（`:141-144` 那两枚 getLabel 的初值就是空文本；"
			+ "拿列表第一枚凑 = 自造）")
	_记((页零.get_node("主格/主格图标") as TextureRect).texture == null, "没回帧 ⇒ 主格图标也是空的")
	_记(假.流水 == ["7"], "开窗发的就是那**一条** 7（实测流水 %s）" % str(假.流水))

	# ⑤⑥⑪ 三枚心法 + 一枚非心法、回帧那颗不在已学里
	var 已学 := {
		心一: {"level": 7, "master_level": 0},
		心二: {"level": 3, "master_level": 0},
		心三: {"level": 0, "master_level": 0},
		非心: {"level": 9, "master_level": 0}}
	var 页一 := _重开(已学, {"action": 3, "xinfa_id": 9999999})
	var 格们 := 页一.get_node("心法列表/心法列表_内容").get_children()
	_记(格们.size() == 4 - 1, "四键里只有三枚是心法 ⇒ 三格（实测 %d）" % 格们.size())
	var 第零 := 格们[0] as Control
	_记(第零.position.y == 2.0, "第一格 y = 40*0 + 2（`:223`），实测 %.1f" % 第零.position.y)
	_记((格们[2] as Control).position.y == 格宽 * 2.0 + 2.0,
			"第三格 y = 40*2 + 2 = 82（实测 %.1f）" % (格们[2] as Control).position.y)
	_记(第零.size == Vector2(格宽, 格宽), "格 40×40（元件 130 的 background #125 原生尺寸）")
	var 图标零 := 第零.get_node("格图标") as TextureRect
	_记(图标零.position == Vector2(3.0, 3.0) and 图标零.stretch_mode == TextureRect.STRETCH_KEEP,
			"格图标 @(3,3) 且 STRETCH_KEEP（原尺寸、不缩）—— `setSkillIcon:302-303`）")
	_记(图标零.texture != null and 图标零.texture.get_size() == Vector2(34.0, 34.0),
			"图标 34×34 原生（实测 %s）" % str(图标零.texture.get_size() if 图标零.texture != null else Vector2.ZERO))
	var 角标 := 第零.get_node_or_null("格层数") as Label
	_记(角标 != null and 角标.position == Vector2(2.0, 25.0) and String(角标.text) == "7",
			"层数角标 @(2,25) 文本 = floor（元件 130 时间轴 floorText 那一格；`:277`+`:283`），实测 %s"
			% (str(角标.text) if 角标 != null else "无此件"))
	_记((格们[2] as Control).get_node_or_null("格层数") == null,
			"第三枚 floor=0 ⇒ **不显**角标（`:279` 那类 `floor > 0` 闸门，口径同 技能面板.gd:256）")
	_记(str(页一.get_node("心法名").text) == "",
			"回帧那颗 9999999 不在已学里 ⇒ 主格保持空（`:85-86` 拿不到对象/`id==0` 就不填）")
	# 阳性对照：同一条箭头在**有货**时必须把列表翻开（只有阴性那条 = 回调报错也能"通过"）
	var 区一 := 页一.get_node("心法列表") as ScrollContainer
	var 箭一 := 页一.get_node("选择心法钮") as Control
	var 开点 := InputEventMouseButton.new()
	开点.button_index = MOUSE_BUTTON_LEFT
	开点.pressed = true
	箭一.gui_input.emit(开点)
	_记(区一.visible, "三枚时点箭头 ⇒ 列表浮出（和上面那条零枚阴性配成一对，单有阴性抓不到回调报错）")

	# ⑨ 回帧那颗**在**已学里 ⇒ 主格填上；而且"回帧 ⇒ 宿主重渲染"这一圈**不再发第二条 7**
	var 页二 := _重开(已学, {})		# 先按"没收到回帧"开一页 ⇒ 发那条 7
	_记(假.流水 == ["7"], "开窗发的就是那一条 7（实测流水 %s）" % str(假.流水))
	假._backend.authoritative_heal = {"action": 3, "xinfa_id": 心一}	# 回帧到了
	var 页二后 := _刷新()		# 宿主 `_refresh_current()` 走的正是这条路（_刚开窗 已置假）
	_记(假.流水 == ["7"],
			"★ 收到 3 号回帧 ⇒ 重渲染**不再**发 7（防 7→3→渲染→7 成环），实测流水 %s" % str(假.流水))
	_记(str(页二后.get_node("心法名").text) == "体能强化",
			"回帧填主格 ⇒ 名标「%s」（`:85-96` setSeleclSkillData）" % str(页二后.get_node("心法名").text))
	_记(str(页二后.get_node("心法层数").text) == "当前层数:7",
			"层标「%s」" % str(页二后.get_node("心法层数").text))
	# ★ 关窗再开必须**再查一次**（原版每次 DAKAI 都发 7）。旧写法"收到过 3 就不再发"会让
	#   第二次开窗显示上一次的旧心法 ⇒ 用户看到的"切换了没反应"。
	假._刚开窗 = true
	var 页二再 := 心法控制器.渲染(假, 心法场景)
	_记(假.流水 == ["7", "7"],
			"★ 再开窗又发一条 7（不然切完心法重开还是旧值），实测流水 %s" % str(假.流水))

	# ★★ 用户 2026-10-14 实机报的「慢一开」：切成 2 → 重开还显示 1 → 再关再开才变 2。
	#   根因：开窗那一轮先把**上一轮回帧留在身上的旧值**填进主格，而 `_填主格` 顺手把这一填
	#   登记成了"玩家自己选的" ⇒ 本轮晚到的新回帧被"别冲掉玩家刚点的"那道闸门挡在门外，
	#   于是每次开窗都显示上一次的那颗，只有下一次开窗才追上。
	#   ⇒ 主格的**来源**要分开：服务端回帧顶上来时不许占用"玩家点过"那一格。
	假._backend.authoritative_heal = {"action": 3, "xinfa_id": 心一}	# 上一轮留下的旧值
	var 页慢 := _重开(已学, {"action": 3, "xinfa_id": 心一})
	_记(str(页慢.get_node("心法名").text) == "体能强化",
			"（回帧还在路上，旧值先顶着 = 用户第一次打开看到的那颗）")
	假._backend.authoritative_heal = {"action": 3, "xinfa_id": 心三}	# 本轮查询的回帧到了
	var 页慢后 := _刷新()
	_记(str(页慢后.get_node("心法名").text) == "替身术",
			"★ 本轮回帧一到，主格**当场换成新的**（不许等到下一次开窗才追上）—— 实测「%s」"
			% str(页慢后.get_node("心法名").text))

	# ★ 竞态回归：玩家点了一格，**晚到的回帧重渲染不许把这一格冲掉**
	#   （用户 2026-10-14 报「有时候切换了没反应」= 回帧比手快时，选中被重建清空 ⇒
	#    点「确定」变成"没选中 ⇒ 一颗字节都不发"）。
	var 页竞 := _重开(已学, {})
	var 内竞 := 页竞.get_node("心法列表/心法列表_内容") as Control
	var 事竞 := InputEventMouseButton.new()
	事竞.button_index = MOUSE_BUTTON_LEFT
	事竞.pressed = true
	(内竞.get_child(2) as Control).gui_input.emit(事竞)
	_记(str(页竞.get_node("心法名").text) == "替身术", "（先点第三格「替身术」，再让回帧晚到）")
	假._backend.authoritative_heal = {"action": 3, "xinfa_id": 心一}
	var 页竞后 := _刷新()
	_记(str(页竞后.get_node("心法名").text) == "替身术",
			"★ 晚到的回帧**没有**冲掉玩家刚点的那格（服务端那颗是「体能强化」）—— 实测「%s」"
			% str(页竞后.get_node("心法名").text))
	(页竞后.get_node("确定钮") as Button).pressed.emit()
	_记(假.流水 == ["7", "6:1004", "close"],
			"所以他点「确定」真的发出去了切换包（实测流水 %s）" % str(假.流水))

	# ★ 同一族的另一半：玩家**翻开**列表后晚到的回帧，不许又把它合回去
	#   （合回去 = 点了箭头"没反应"）。展开态和选中态都得跨重渲染活着。
	var 页展 := _重开(已学, {})
	var 箭展 := 页展.get_node("选择心法钮") as Control
	箭展.gui_input.emit(事竞)
	_记((页展.get_node("心法列表") as ScrollContainer).visible,
			"（先翻开列表，再让回帧晚到）")
	假._backend.authoritative_heal = {"action": 3, "xinfa_id": 心一}
	var 页展后 := _刷新()
	var 区展后 := 页展后.get_node("心法列表") as ScrollContainer
	_记(区展后.visible,
			"★ 回帧引起的重渲染**不**把玩家翻开的列表合回去，实测 visible=%s" % str(区展后.visible))
	(页展后.get_node("选择心法钮") as Control).gui_input.emit(事竞)
	_记(not 区展后.visible,
			"再点一次箭头 ⇒ 收起（`_展开` 取反），实测 visible=%s" % str(区展后.visible))
	_记(假.流水 == ["7"],
			"展开/收起这一路一颗包都不发（原版 selectSkillBtn 只动 visible），实测流水 %s" % str(假.流水))

	# ⑦ 只有一枚 ⇒ 45
	var 页三 := _重开({心二: {"level": 2, "master_level": 0}}, {"action": 3, "xinfa_id": 心二})
	_记(页三.get_node("心法列表").size.y == 45.0,
			"一枚 ⇒ 区高 45（`:313`），实测 %.0f" % 页三.get_node("心法列表").size.y)

	# ⑫ 三态：无选中 / 有选中 × 确定 / 取消
	var 页四 := _重开(已学, {})
	(页四.get_node("取消钮") as Button).pressed.emit()
	_记(假.流水 == ["7", "close"],
			"没选中点「取消」⇒ 只有开窗那条 7、没有切换包，并且关窗（`:97-115`）实测 %s" % str(假.流水))
	var 页五 := _重开(已学, {})
	# 这一条不是凑数：它保证下面 `get_child(1)` 点到的真是第二格（拿不到格 ⇒ 点空 = 假绿）
	_记(页五.get_node("心法列表/心法列表_内容").get_child_count() == 3, "重开这一页有 3 格，下面点第 2 格")
	var 第2 := 页五.get_node("心法列表/心法列表_内容").get_child(1) as Control
	var 事2 := InputEventMouseButton.new()
	事2.button_index = MOUSE_BUTTON_LEFT
	事2.pressed = true
	第2.gui_input.emit(事2)
	_记(str(页五.get_node("心法名").text) == "查克拉强化", "点第二格 ⇒ 主格换成「%s」" % str(页五.get_node("心法名").text))
	(页五.get_node("确定钮") as Button).pressed.emit()
	_记(假.流水 == ["7", "6:1001", "close"],
			"★ 有选中点「确定」⇒ 先发 6:1001 **再**关窗（`onClickOkBtn` 派发⇒关窗 的序），实测 %s" % str(假.流水))
	var 页六 := _重开(已学, {"action": 3, "xinfa_id": 心三})
	_记(str(页六.get_node("心法名").text) == "替身术", "（回帧把主格填上了 = 下面这条「取消」是在**有选中**的状态下点的）")
	(页六.get_node("取消钮") as Button).pressed.emit()
	_记(假.流水 == ["7", "close"],
			"有选中点「取消」⇒ 除了**开窗那一条 7**（`UI.as:649-652`，与取消无关）之外一条切换包都不发"
			+ "（派发的是 XINFA_XIULIAN_CANCEL，全工程只注册了 OK 与 DAKAI 两个监听，`UI.as:1086-1087`），实测 %s" % str(假.流水))
	_记(假.通知.is_empty(), "这条链上原版一颗 toast 都没有 ⇒ 本工程也不许有（实测 %d 条）" % 假.通知.size())
	走完.append("数据面")


## ── §接口：假宿主/假后端 的成员必须在真身上存在（否则 = 假通过）──────────────
## 口径：这里核的是**接口面**（名字与发的字节），不是行为 —— 行为由 §真页 用真的
## `窗口管理` + 真的鼠标事件跑过（那条链一旦成员名对不上，`_render_xinfa` 当场就炸）。
## 不 `new()` 真脚本：`后端连接` 的实例会带着 TCP 单例的构造走一遍，门不该碰它。
func _量接口() -> void:
	日志.append("=== §接口（假 ↔ 真 逐条对）===")
	var 宿主文 := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd")
	for 名 in ["var _content: Control", "var _backend: Node"]:
		_记(宿主文.contains(名), "真 功能窗口 声明了 `%s`（假宿主给的那两样不是自造）" % 名)
	for 名 in ["func close(", "func _通知(", "func _render_xinfa("]:
		_记(宿主文.contains(名), "真 功能窗口 有方法 `%s`" % 名.replace("func ", "").replace("(", ""))
	_记(宿主文.contains("心法窗.渲染(self, 心法场景)"),
			"`_render_xinfa()` 真把宿主与场景喂给了控制器（不是拿别的页凑的）")

	var 后端文 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	for 名 in ["var authoritative_skills", "var authoritative_heal"]:
		_记(后端文.contains(名), "真 后端连接 有成员 `%s`（假后端那两个不是自造）" % 名)
	for 名 in ["func request_xinfa_show(", "func request_xinfa_change("]:
		_记(后端文.contains(名), "真 后端连接 有方法 `%s`" % 名.replace("func ", "").replace("(", ""))
	_记(后端文.contains("send_game_request(OP_HEAL, \"7\")"),
			"`request_xinfa_show()` 发的就是 `86:7`（OP_HEAL=86 + 子命令 7 = 原版 HealProcessor 的 QUERY_XINFA）")
	_记(后端文.contains("send_game_request(OP_HEAL, \"6:%d\" % xinfa_id)"),
			"`request_xinfa_change(id)` 发的就是 `86:6:<id>`（CHANGE_XINFA）")
	_记(假._backend.宿主 == 假,
			"假后端接上了假宿主（没接上 ⇒ 记账静默丢掉，上面那些流水判据会全成空数组）")
	走完.append("接口")


func _收尾(致命: String = "") -> void:
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	var 现 := _存档字节()
	_记(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（夹具只在内存里）")
	_记(走完.size() == 3,
			("真页 / 数据面 / 接口 三节都判到了最后一件（走完 %s）—— 少一节 = 门自己中途抛了异常，"
					+ "后面那些条等于没判，而 `红数` 看不出来") % str(走完))
	# ⚠ 光有上面那条还不够：运行期报 `Invalid assignment of property or key ...` 时，
	#   GDScript 只中止**当前那个调用**、外层函数照样跑完 ⇒ 走完 == 3 而 `红数` 仍是 0
	#   （2026-10-13 实测：假宿主的 `流水 = []` 赋错类型，一整节都在比旧账，末行照样"通过"）。
	#   ⇒ 再钉一条**判据条数**的下限：少一条就是有一整块没落到件上。
	_记(日志.size() >= 40,
			("一共判了 %d 条（下限 40）—— 条数掉了 = 有断言没执行到，而不是" + "它过了")
			% 日志.size())
	for 一 in 日志:
		print(一)
	print(("心法页回归：通过（红 %d 项）" % 红数) if 红数 == 0 else ("心法页回归：不通过（红 %d 项）" % 红数))
	quit(1 if 红数 > 0 else 0)
