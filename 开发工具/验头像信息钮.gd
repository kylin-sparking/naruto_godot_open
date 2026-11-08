extends SceneTree
## 头像信息（目标信息条 `DetailsWindow`）那六颗钮 + 菜单每一行的**命中与分发**量具。
##
## 为什么要有它：用户报「加为好友 / 邀请组队 / 私聊 / 菜单（含子钮）都不对」，
## 而"不对"有三种完全不同的病：① 根本点不到（被别的件压住 = #226）；
## ② 点到了但没发帧；③ 发了帧但服务端没回。静态读代码分不开这三种，只能真点。
##
## 口径：
## · 按**真鼠标**（`push_input`），不是 `emit_signal("pressed")` —— 后者绕不过命中区，
##   正好把①这一类坏演成绿（工程里那条"行为门要吃真事件"）。
## · 每颗钮先只发 motion，把 `gui_get_hovered_control()` 打出来 ⇒ 谁压着一眼就看见。
## · 没连服务端时 `request_*` 返回 false ⇒ 面板会回「…需要在线」；
##   这句话出现 = **点到了、也走到发帧那一步了**，与"点不到"是两种病，必须分开报。
## · ⚠ `_process` 里**不许 await**（一 await 就返回 null、下一步被反复重入）⇒ 整条步序
##   单独一条协程 `_跑()`，`_process` 只踢一脚。
## · ⚠ 层号照抄地图场景（现查 `场景/生成/地图_100000000_烘焙.tscn`）⇒ 别自己另排一遍，
##   排了就测不出"被谁压住"。
##
## 用法（**不能加 --headless**：无头下视口尺寸不落到锚点布局上，整块条会算到屏幕外，
## 测出来的"点不到"是量具的假红。10-17 实测：无头时条全局矩形 P=(-83,0)，有头 P=(365,4)）：
##   "godot" --path . --script res://开发工具/验头像信息钮.gd

const 头像面板场景 := "res://场景/界面/头像面板.tscn"
const 窗口管理场景 := "res://场景/界面/窗口管理.tscn"
const 聊天场景 := "res://场景/界面/聊天面板.tscn"
const 技能场景 := "res://场景/界面/技能面板.tscn"
const 小地图场景 := "res://场景/界面/小地图面板.tscn"
const 系统消息场景 := "res://场景/界面/组件/系统消息.tscn"

## 与地图场景同一套层号（现查烘焙场景），别自己另排一遍。
const 层表 := {
	头像面板场景: 300, 小地图场景: 20, 聊天场景: 100,
	技能场景: 100, 窗口管理场景: 110, 系统消息场景: 110,
}

const 钮表 := ["钮_查看资料", "钮_交易", "钮_加好友", "钮_组队", "钮_私聊", "钮_菜单"]
## 每颗钮**期望**听到的收口话（没连服务端时应走到"需要在线"那一支；私聊/菜单本来就不发包）。
const 期望话 := {
	"钮_查看资料": "需要在线", "钮_交易": "需要在线", "钮_加好友": "需要在线",
	"钮_组队": "需要在线", "钮_私聊": "", "钮_菜单": "",
}

var _面板: Node = null
var _条: Control = null
var _会话: Node = null
var _管理: Node = null
var _收: Array = []
var _红 := 0
var _帧 := 0
var _踢了 := false


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	for 路 in 层表:
		var 景 := load(路) as PackedScene
		if 景 == null:
			print("红 场景取不到：", 路, " ⇒ 层栈不完整，这张量具的命中结果不可信")
			quit(2)
			return
		var 节 := 景.instantiate()
		节.set("layer", int(层表[路]))
		root.add_child(节)
		if 路 == 头像面板场景:
			_面板 = 节
		if 路 == 窗口管理场景:
			_管理 = 节
	## ⚠ 取单例一律 `root.get_node("名字")`（**相对**）—— SceneTree 脚本里 `root` 就是 Window，
	## 写成 `get_node("/root/GameSession")` 会报
	## `Can't use get_node() with absolute paths from outside the active scene tree`、
	## 拿到 null ⇒ 后面那句提示一条都收不到，看起来像"钮没反应"（10-17 自己踩的）。
	_会话 = root.get_node_or_null("GameSession")
	var 后 = root.get_node_or_null("BackendConnection")
	后.set("in_game", false)
	_会话.notification_requested.connect(func(话: String) -> void: _收.append(话))


func _process(_d: float) -> bool:
	_帧 += 1
	if _踢了 or _帧 < 14:
		return false
	_踢了 = true
	_跑()
	return false


## 真鼠标点一件，返回 `{"悬停": 命中的件名, "话": [点完收到的提示]}`。
func _点(件: Control) -> Dictionary:
	var 心: Vector2 = 件.get_global_rect().get_center()
	var 移 := InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	root.push_input(移)
	await process_frame
	var 悬停: Node = (root as Viewport).gui_get_hovered_control()
	var 悬说 := "（空）"
	if 悬停 != null:
		var 爬: Node = 悬停
		var 层 := "?"
		while 爬 != null:
			if 爬 is CanvasLayer:
				层 = str((爬 as CanvasLayer).layer)
			爬 = 爬.get_parent()
		悬说 = "%s 层=%s 矩形=%s" % [String(悬停.name), 层,
				str((悬停 as Control).get_global_rect()) if 悬停 is Control else "-"]
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 心
	按.global_position = 心
	root.push_input(按)
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 心
	放.global_position = 心
	root.push_input(放)
	await process_frame
	await process_frame
	return {"悬停": String(悬停.name) if 悬停 != null else "（空）", "话": _收.duplicate(),
			"细": 悬说}


func _报(判: bool, 题: String, 细: String) -> void:
	if not 判:
		_红 += 1
	print("%s %s %s" % ["√" if 判 else "红", 题, 细])


func _跑() -> void:
	print("视口=", (root as Viewport).get_visible_rect().size, " 窗=", root.size)
	_条 = (_面板.get_node("头像区域") as Control).get_node("选中人物信息") as Control
	print("头像区域 矩形=", (_条.get_parent() as Control).get_global_rect())
	# 走真入口：选中一个玩家档（只有 type==1 出那排钮，`hideBtn():287-298`）
	_面板.call("_on_map_character_selected", {
		"type": 1, "char_id": 2, "name": "社交同伴", "level": 33,
		"level_text": "Lv.33", "hp": 100, "max_hp": 200, "mp": 50, "max_mp": 100})
	await process_frame
	await process_frame
	print("条全局矩形：", _条.get_global_rect(), " 可见=", _条.visible, " z=", _条.z_index)
	## 把**我方等级钉成 100**：上面喂的目标是 33 级 ⇒ 按 `DetailsWindow._menu():309-320`
	## （`LIMIT_LEVEL=60`）这一档必须出「收徒」那一行。不钉的话我方等级取自存档、
	## 行表可能是 5 行也可能是 6 行，菜单子钮的覆盖就随环境飘（10-17 普查到的第十四类假绿：
	## 夹具不覆盖分支 ⇒ 判据"0 比 0"恒真）。
	var 我方级 := 100
	var 目标级 := 33
	(_会话.get("player_stats") as Dictionary)["level"] = 我方级
	var 该有行: Array = ["族邀", "赠花", "羁绊", "看摊", "双修"]
	if 我方级 < 60 and 目标级 >= 60:
		该有行.append("拜师")
	elif 我方级 >= 60 and 目标级 < 60:
		该有行.append("收徒")
	## 每行点完**必须有一句话说**：五行**全都接上了协议**（#88 撤掉「赠花 = 本机没窗」那句假话），
	## 所以离线时七行统一说"需要在线"。点了不响 = 用户报的那句"没反应"，不许演绿。
	var 行话 := {
		"族邀": "需要在线", "赠花": "需要在线",
		"羁绊": "需要在线",
		"看摊": "需要在线", "双修": "需要在线", "拜师": "需要在线", "收徒": "需要在线",
	}
	for 名 in 钮表:
		var 钮 := _条.get_node(名) as TextureButton
		_收.clear()
		var 结: Dictionary = await _点(钮)
		var 话: Array = 结["话"] as Array
		var 到: bool = String(结["悬停"]) == 名
		var 期望 := String(期望话[名])
		var 判: bool = 到
		var 说 := "中心=%s 悬停到=%s" % [str(钮.get_global_rect().get_center()), String(结["悬停"])]
		if not 期望.is_empty():
			判 = 到 and not 话.is_empty() and String(话[0]).contains(期望)
			说 += " 收到=「%s」期望含「%s」" % [
				" / ".join(PackedStringArray(话)) if not 话.is_empty() else "（没提示）", 期望]
		_报(判, 名, 说)
	## 菜单那颗弹开之后，**每一行**都要真点一次（用户点名"包括菜单按钮的所有子按钮"）。
	## ⚠ 两个坑（都是这一轮自己踩出来的）：
	## ① **不许点"底"** —— 底是 `mouse_filter=IGNORE` 的 TextureRect，那一点会穿到它下面的
	##    真实那一行 ⇒ 选中一项 ⇒ `收起()` ⇒ 后面每一行都"点不到"，全是量具造的假红。
	## ② 点中一行**菜单就收了**（原版也是），所以**每行点之前都要确认还开着**，
	##    关了就重新点一下 `钮_菜单` 弹回来。
	var 菜 := _条.get_node("目标菜单") as Control
	var 菜钮 := _条.get_node("钮_菜单") as TextureButton
	print("目标菜单 可见=", 菜.visible, " 矩形=", 菜.get_global_rect(), " 子件数=", 菜.get_child_count())
	var 实得行: Array = []
	for i in 12:
		var 行 := 菜.get_node_or_null("项_%d" % i) as Button
		if 行 == null:
			continue
		if not 行.visible or 行.size.x <= 0.0:
			print("   跳过（本次没这一项）：项_%d" % i)
			continue
		var 文案 := 行.text
		实得行.append(文案)
		if not 菜.visible:
			await _点(菜钮)
			## 重新弹开之后**必须隔帧**再看行的全局矩形：`展开()` 里排完版才算得出正确位置，
			## 同帧取到的是上一轮的旧矩形 ⇒ 点空、`gui_get_hovered_control()` 回 null（10-17 现查）。
			await process_frame
			await process_frame
		print("   [点前] 项_%d「%s」菜单可见=%s 行可见=%s  disabled=%s 行全局=%s 焦点=%s" % [
				i, 文案, str(菜.visible), str(行.visible), str(行.disabled), str(行.get_global_rect()),
				String(str(root.gui_get_focus_owner()))])
		_收.clear()
		var 结2: Dictionary = await _点(行)
		var 到2: bool = String(结2["悬停"]) == String(行.name)
		var 话2: Array = 结2["话"] as Array
		var 话串 := " / ".join(PackedStringArray(话2)) if not 话2.is_empty() else "（没提示）"
		## 点完必须**自己收起来**（`物品菜单._ready` 那条 `选择了.emit + 收起()`）。
		var 收了: bool = not 菜.visible
		var 该话 := String(行话.get(文案, ""))
		var 说了: bool = not 该话.is_empty() and 话串.contains(该话)
		_报(到2 and 收了 and 说了, "菜单行 项_%d「%s」" % [i, 文案], "行矩形=%s 悬停到=%s 点完菜单收起=%s 收到=「%s」期望含「%s」" % [
			str(行.get_global_rect()), String(结2["细"]), str(收了), 话串, 该话])
	_报(实得行 == 该有行, "菜单行表 = 原版三档算式",
			"我 %d 级 / 他 %d 级 ⇒ 应有 %s，实得 %s" % [我方级, 目标级, str(该有行), str(实得行)])
	## ── 师徒申请窗（#225）：帧到 ⇒ **真鼠标**点那一扇的「确定」───────────────
	## 离线门只能证到"分发对不对"，这一腿证的是**那颗钮在屏幕上点得到**
	## （原版 `AgreestToturWindow` 宽随文字算、钮位是递推算出来的 ⇒ 算错一格就点不着）。
	var 后2 = root.get_node_or_null("BackendConnection")
	var 申 := _管理.get_node("师徒申请层/师徒申请窗") as Control
	后2.set("in_game", true)
	后2.call("_handle_bridge_text", "77:4:1001:张三")
	await process_frame
	_报(申.visible, "师徒申请窗 开窗", "喂进 `77:4:1001:张三` ⇒ visible=%s 矩形=%s" % [
			str(申.visible), str(申.get_global_rect())])
	## `setLocationCenter():52-72`：每次算完宽都回正中（宽随名字变，不重算就会一直贴左上角）。
	## ⚠ 这里是 `extends SceneTree` 的脚本，**没有 `get_tree()`**（写成那样整份 parse 失败、
	## 整个量具跑不起来）；舞台尺寸直接问 `root`（Window 自己就是 Viewport）。
	var 台: Vector2 = (root as Viewport).get_visible_rect().size
	_报(absf(申.position.x + 申.size.x / 2.0 - 台.x / 2.0) <= 1.0
			and absf(申.position.y + 申.size.y / 2.0 - 台.y / 2.0) <= 1.0,
			"师徒申请窗 回正中", "位置=%s 尺寸=%s 舞台=%s" % [str(申.position), str(申.size), str(台)])
	var 结3: Dictionary = await _点(申.get_node("确定钮") as Control)
	var 到3: bool = String(结3["悬停"]) == "确定钮"
	var 话3: Array = 结3["话"] as Array
	## 没连服务端 ⇒ 那一发发不出去，`_点确定` 会报「处理师徒申请需要在线」——
	## 这句话就是"点得到 + 走到了发帧那一步"的证据（真发出去了什么，归在线门与离线门那两腿）。
	_报(到3 and not 申.visible and not 话3.is_empty(),
			"师徒申请窗 点「确定」", "悬停到=%s 点完关窗=%s 收到=「%s」" % [
			String(结3["悬停"]), str(not 申.visible),
			" / ".join(PackedStringArray(话3)) if not 话3.is_empty() else "（没提示）"])
	后2.set("in_game", false)
	print("头像信息钮量具：红 %d 条" % _红)
	quit(1 if _红 > 0 else 0)
