extends Control

## 家族主窗内容页（原版 `com\mxw\uifl\controls\familly\FamillyWindow`，617×390 窗、
## 内容区 601×322 @ (8,38) ⇒ 本页以内容区左上为 (0,0)，底栏 8 钮落在 y=325）。
## 真值：`game-client/真值/窗口/家族.md` §1。只做美术与按钮交互，数据/协议一律走既有钩子：
## 动作分发交回宿主 `功能窗口._show_guild_action()`，创建/离开交回 `社交窗口._create_guild/_leave_guild`。

const 钮皮目录 := "res://素材/界面/原版窗口/家族/钮底%d%s.png"	# 档宽 + 态后缀（预烘九宫格）
const 动作表 := ["家族列表", "家族升级", "家族技能", "家族尾兽", "家族旗帜", "家族贡献", "家族商店", "成员信息"]
## `FamillyWindow.as:130-145` 家徽格底色按等级 1/2/3/4/≥5
const 家徽等级色 := {1: Color(1, 1, 1), 2: Color(0, 1, 0), 3: Color(0x1E / 255.0, 0x90 / 255.0, 1),
	4: Color(0xBA / 255.0, 0x55 / 255.0, 0xD9 / 255.0), 5: Color(0xFF / 255.0, 0xA5 / 255.0, 0)}
## 职务名/色统一走 `家族职务`（全工程只此一份）。
## ⚠️ 这里原来抄的 `{5:族长, 4:副族长, 3:长老, 2:精英, 1:成员}` **整个是反的** ——
##    服务端给族长的是 rank 1，于是族长被显示成"成员"（用户 2026-10-09 报的）。真值见该文件。
const 家族职务 := preload("res://脚本/界面/窗口/家族/家族职务.gd")
const 行高 := 23.0			# `FamillyWindow.as:208` rowHeight=23
const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

var _宿主: Node
var _会话: Node
var _行容器: Control
var _列表窗口: Control
var _滚动条: Control
var _滑块: TextureButton
var _滚动偏移 := 0.0
var _可视高 := 116.0
var _已填 := false

func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	_会话 = get_node_or_null("/root/GameSession")
	for 名 in 动作表 + ["修改钮"]:
		var 钮 := get_node_or_null(名) as TextureButton
		if 钮 == null:
			continue
		_绑三态(钮, 钮.get_node_or_null("Label") as Label, 37 if 名 == "修改钮" else 61)
	_列表窗口 = get_node_or_null("成员区/列表窗口") as Control
	_行容器 = get_node_or_null("成员区/列表窗口/内容列") as Control
	_滚动条 = get_node_or_null("成员区/滚动条") as Control
	_滑块 = get_node_or_null("成员区/滚动条/滑块") as TextureButton
	var 上 := get_node_or_null("成员区/滚动条/滚动上") as TextureButton
	var 下 := get_node_or_null("成员区/滚动条/滚动下") as TextureButton
	for 钮 in [上, 下, _滑块]:
		if 钮 != null:
			钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if 上 != null:
		上.pressed.connect(_滚像素.bind(-行高))
	if 下 != null:
		下.pressed.connect(_滚像素.bind(行高))
	刷新(宿主._session.guild if 宿主 != null and 宿主._session != null else {})

func 刷新(家族: Dictionary) -> void:
	_已填 = true
	var 在族 := bool(家族.get("joined", false))
	var 徽 := get_node_or_null("家徽区") as Control
	if 徽 != null:
		var 名 := 徽.get_node("家徽名值") as Label
		名.text = String(家族.get("flag_name", 家族.get("name", ""))) if 在族 else "未加入家族"
		名.add_theme_color_override("font_color", Color("#6ee07d") if 在族 else Color("#a9957f"))
		var 级 := 徽.get_node("家族等级值") as Label
		级.text = "%d 级" % int(家族.get("level", 0))
		_画家徽格(徽.get_node("家徽格") as Control, int(家族.get("emblem_level", 家族.get("level", 1))),
			int(家族.get("flag_style", -1)))
		for 文 in [["家徽名标题", Color.WHITE], ["家族等级标题", Color.WHITE], ["加成属性", Color.WHITE]]:
			(徽.get_node(文[0]) as Label).add_theme_color_override("font_color", 文[1])
	var 告 := get_node_or_null("公告区/公告") as TextEdit
	if 告 != null:
		告.text = String(家族.get("notice", "")) if 在族 else " "
		告.editable = 在族
	if not 告.text_changed.is_connected(_限公告长):
		告.text_changed.connect(_限公告长)
	var 修 := get_node_or_null("公告区/修改钮") as TextureButton
	if 修 != null:
		(修.get_node("修改钮文字") as Label).text = "修改" if 在族 else "创建家族"
		修.disabled = false
		# ⚠️ 这个钮原先**只绑了三态皮、没接 pressed** ⇒ 点它一声不响。未入族时它的
		#    文案就是「创建家族」，玩家因此根本进不去创建流程（2026-10-05 用户报的
		#    "不知道能否创建家族"）。在族 = 提交公告（`1552:7`）；不在族 = 开创建窗。
		if not 修.pressed.is_connected(_按修改钮):
			修.pressed.connect(_按修改钮)
		_设三态(修, 0)
	var 信 := get_node_or_null("信息区/信息") as RichTextLabel
	if 信 != null:
		信.text = "家族名称：%s\n现任族长：%s\n家徽等级：%d 级\n家族人数：%d\n个人贡献：%d" % [
			String(家族.get("name", "-")) if 在族 else "-",
			String(家族.get("leader", "-")) if 在族 else "-",
			int(家族.get("level", 0)), int(家族.get("members", 0)), int(家族.get("contribution", 0))]
	_填成员(家族.get("member_list", []) as Array if 家族.get("member_list", []) is Array else [], 在族)
	for i in 动作表.size():
		var 钮 := get_node_or_null(动作表[i]) as TextureButton
		if 钮 == null:
			continue
		# 底栏八钮的可用态，逐条对原版 `FamillyWindow`：
		#   · 列表（FW:238）恒可点；
		#   · **技能**（FW:245）生来 `enabled = false`，且全篇**再没有一处放权** ——
		#     单机版的家族技能摆在人物面板技能窗第 4 页（`showSkillHandler` →
		#     `showSKILLWINDWOTab4()`），这颗钮在原版里就是死的。我们以前按"尾兽那样
		#     入族放权"把它点亮了，可点下去什么都不做（壳的开窗表里没有「家族技能」）
		#     —— 亮着办不成事比灰着更糟，改回原版口径。
		#   · 尾兽/旗帜/贡献/商店/成员 = `updateFamilly` 那句 `= param1`（FW:412，
		#     在族才放权）；本页只在入族后渲染，所以现实中恒真，口径照抄。
		#   · **商店另加一道家族等级 < 2 禁用**（FW:413-416：`famillyLevel < 2`
		#     ⇒ `_famillyShopBtn.enabled = false`）—— 这正是"升级后会变"的一处：
		#     1 级灰着、升到 2 级才亮（服务端不拦等级，这是原版的纯客户端门）。
		#   · **升级 = 只有族长**：`updateFamilly`（FW:417-419）里
		#     `isManager && _isMyFamilly` 时 `_shengjiBtn.enabled = true`，否则关。
		#     `isManager` 真值 `FM.as:455-462`：`stats.id == myFamillyInfo.leaderId`（**角色 id**）。
		#     服务端 `_handle_multiplayer_family` 的 action 10 同样只认族长
		#     （非族长的请求被**静默丢弃**，一句回包都没有）⇒ 不灰就是"亮着却办不成事"
		#     （同 `家族旗帜填充._更新按钮` 那条理由）。
		match 动作表[i]:
			"家族技能":
				钮.disabled = true
			"家族商店":
				钮.disabled = not 在族 or int(家族.get("level", 0)) < 2
			"家族尾兽", "家族旗帜", "家族贡献", "成员信息":
				钮.disabled = not 在族
			"家族升级":
				钮.disabled = not 在族 or not _是族长(家族)
			_:
				钮.disabled = false
		if not 钮.pressed.is_connected(_发动作):
			钮.pressed.connect(_发动作.bind(动作表[i]))
		_设三态(钮, 0)

## `FW:202` textField.maxChars = 200 —— Godot 4.7 的 TextEdit 没有 max_length 属性，
## 只能在 text_changed 里裁（多输的字符立刻被削回去，观感同原版）。
const 公告上限 := 200

func _限公告长() -> void:
	var 告 := get_node_or_null("公告区/公告") as TextEdit
	if 告 == null or 告.text.length() <= 公告上限:
		return
	var 裁 := 告.text.substr(0, 公告上限)
	告.text = 裁


func _发动作(名: String) -> void:
	if _宿主 != null and _宿主.has_method("_show_guild_action"):
		_宿主.call("_show_guild_action", 名)


## 我是不是族长 —— 口径与 `家族旗帜填充._更新按钮` 完全一致：
##   首选**角色 id 相等**（原版 `FM.as:455-462`：`API.dataCenter.stats.id ==
##   myFamillyInfo.leaderId`）；拿不到族长 id（老回包/离线）才退回**比名字**兜底。
## ⚠️ "我的角色 id"只能从 `BackendConnection.character_id` 取 —— `player_stats` 里
##    **没有 `id`**（`服务端同步.应用人物` 只填已存在的键）。取错地方 ⇒ 恒 0 ⇒
##    "是族长"恒假 ⇒ 升级钮永远灰着（2026-10-08 排安插不了时就是这么栽的）。
## ⚠️ 后端**先问宿主要**（真宿主 `功能窗口._backend`），别一上来就
##    `get_node_or_null("/root/...")` —— 门在 `_initialize` 阶段就调 `刷新`，
##    那一刻页面还没进树，绝对路径会刷一条 ERROR（本工程拿日志噪声当过真问题查）。
func _是族长(家族: Dictionary) -> bool:
	var 后端: Node = null
	if _宿主 != null:
		var 宿: Variant = _宿主.get("_backend")
		if 宿 is Node:
			后端 = 宿 as Node
	# ⚠️ 绝对路径要**在树里**才走：门在 `_initialize` 阶段就调 `刷新`，那一刻页面还没进树，
	#    `get_node_or_null("/root/...")` 会刷一条 ERROR（本工程拿日志噪声当过真问题查）。
	#    （`装配` 取 `/root/GameSession` 那条老噪声同源，见 `_ready` 前的既有限位。）
	if 后端 == null and is_inside_tree():
		后端 = get_node_or_null("/root/BackendConnection")
	var 族长id := int(家族.get("leader_id", 0))
	var 自己id := int(后端.get("character_id")) if 后端 != null else 0
	if 族长id > 0:
		return 自己id > 0 and 自己id == 族长id
	# 兜底：族长 id 拿不到时比名字（`会话.guild.leader` 对 `player_stats.name`）。
	var 统计: Variant = _会话.get("player_stats") if _会话 != null else {}
	var 当前名 := String((统计 as Dictionary).get("name", "")) if 统计 is Dictionary else ""
	return not 当前名.is_empty() and String(家族.get("leader", "")) == 当前名


## 公告区那个钮：在族 = 把公告框里的文本提交给服务端（`1552:7`，服务端只认族长）；
## 不在族 = 它是「创建家族」，交给宿主的开窗表去开创建窗（表里 `"修改钮"` 那一项）。
func _按修改钮() -> void:
	var 家族: Dictionary = (_会话.guild if _会话 != null else {}) as Dictionary
	var 在族 := bool(家族.get("joined", false))
	if not 在族:
		_发动作("修改钮")
		return
	var 告 := get_node_or_null("公告区/公告") as TextEdit
	if 告 == null:
		return
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null or not bool(后端.in_game):
		return
	后端.call("request_guild_notice", 告.text)

func _画家徽格(格: Control, 等级: int, 样式号 := -1) -> void:
	if 格 == null:
		return
	var 底 := 格.get_node_or_null("底色") as ColorRect
	if 底 != null:
		底.color = 家徽等级色[5] if 等级 >= 5 else 家徽等级色.get(maxi(1, 等级), Color(1, 1, 1))
	# `FW:107`：`_jiaHuiCell.setIcon(PicTool.getJiaHuiPic(flag.style))` ——
	# `SimpleItemCell.setIcon`（`:97-107`）是**按原尺寸居中**（不缩放），格子 40×40 ⇒ (3,3)。
	var 徽 := 格.get_node_or_null("家徽图") as TextureRect
	if 徽 == null:
		徽 = TextureRect.new()
		徽.name = "家徽图"
		徽.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		徽.stretch_mode = TextureRect.STRETCH_SCALE
		徽.mouse_filter = Control.MOUSE_FILTER_IGNORE
		格.add_child(徽)
	徽.texture = 家徽图.取(样式号)
	徽.visible = 徽.texture != null
	徽.size = Vector2.ONE * 家徽图.边长
	徽.position = (格.size - 徽.size) * 0.5
	# `FW:109`：`MToolTipText.createToolTip(stage, _jiaHuiCell, getJiaHuiJiaChengString(flag.level))`
	# —— 文案是**逐项列出该等级加成的属性**（真值 `FamillyManager.getJiaHuiJiaChengString`）。
	格.tooltip_text = 游戏数据.家徽加成文案(等级)

func _填成员(成员: Array, 在族: bool) -> void:
	if _行容器 == null:
		return
	for 子 in _行容器.get_children():
		子.queue_free()
	if not 在族 or 成员.is_empty():
		var 提示 := Label.new()
		提示.name = "空提示"
		提示.size = Vector2(349.0, 行高)
		提示.text = "暂无成员"
		提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		提示.add_theme_color_override("font_color", Color("#a9957f"))
		_行容器.add_child(提示)
	else:
		for i in 成员.size():
			var 记: Dictionary = 成员[i]
			var 行 := Control.new()
			行.name = "行%d" % (i + 1)
			行.size = Vector2(349.0, 行高)
			行.position = Vector2(0.0, i * 行高)
			行.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_行容器.add_child(行)
			var 本行职务 := int(记.get("rank", 1))
			var 值 := [String(记.get("name", "-")), "Lv.%d" % int(记.get("level", 0)),
				家族职务.职务名(本行职务), str(int(记.get("contribution", 0))),
				str(int(记.get("weekly_contribution", 0)))]
			var 列宽 := [110.0, 58.0, 64.0, 68.0, 68.0]		# `FW:218-231` 表头五列宽
			var x := 0.0
			for c in 5:
				var 字 := Label.new()
				字.name = ["角色名", "等级", "职位", "贡献", "财富"][c]
				字.position = Vector2(x, 2.0)
				字.size = Vector2(列宽[c], 19.0)
				字.text = 值[c]
				字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				# 第 2 列是「职位」⇒ 按 rank 上色（原版 `FamillyItemRenderer:30` 用的是 htmlText）。
				字.add_theme_color_override("font_color",
					家族职务.职务色(本行职务) if c == 2 else Color("#8fe0a8"))
				行.add_child(字)
				x += 列宽[c]
	_同步滚动()

func _滚动上限() -> float:
	return 0.0 if _行容器 == null else maxf(0.0, _行容器.size.y - _可视高)

func _滚像素(px: float) -> void:
	_滚动偏移 = clampf(_滚动偏移 + px, 0.0, _滚动上限())
	_同步滚动()

func _同步滚动() -> void:
	if _行容器 == null or _滚动条 == null:
		return
	var 上限 := _滚动上限()
	_滚动条.visible = 上限 > 0.0
	_行容器.position.y = -_滚动偏移
	if _滑块 != null:
		var 轨道 := 88.0						# 滚动槽 14..102（`ScrollBar.as:278,283` 箭头各 14）
		var 高 := maxf(20.0, 轨道 * _可视高 / maxf(_可视高, _可视高 + 上限))
		_滑块.size = Vector2(15.0, 高)
		var 比 := 0.0 if 上限 <= 0.0 else _滚动偏移 / 上限
		_滑块.position = Vector2(0.0, 14.0 + (轨道 - 高) * 比)
		var 底 := _滚动条.get_node_or_null("滑块底") as NinePatchRect
		if 底 != null:
			底.position = _滑块.position
			底.size = _滑块.size

func _绑三态(钮: TextureButton, 文字: Label = null, 档: int = 61) -> void:
	# ⚠️ 键**必须 ASCII**（原来是 `"档"`）：中文键被 `set_meta` 拒掉后 `has_meta("档")` 恒 false，
	#    `_设三态` 就永远退回默认档 61 —— **「修改钮」的 37 档皮一直没生效**，还不报错（§3.64.4）。
	钮.set_meta("tier", 档)
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.set_meta("txt", 文字)
	钮.mouse_entered.connect(_设三态.bind(钮, 1))
	钮.mouse_exited.connect(_设三态.bind(钮, 0))
	钮.button_down.connect(_设三态.bind(钮, 2))
	钮.button_up.connect(_设三态.bind(钮, 0))		# `MButton3.as:103-108` 松手回 STATE_UP
	_设三态(钮, 0)

## 三档皮 = 同一张 `钮底.png` 过 `getLightFilter(±30/-40)` / `getGrayFilter()`（《度量表》§3.1）
func _设三态(钮: TextureButton, 态: int) -> void:
	var 后缀 := ""
	if 钮.disabled:
		后缀 = "_灰"
	elif 态 == 1:
		后缀 = "_悬停"
	elif 态 == 2:
		后缀 = "_按下"
	var 档 := int(钮.get_meta("tier")) if 钮.has_meta("tier") else 61
	钮.texture_normal = load(钮皮目录 % [档, 后缀]) as Texture2D
	var 文字 := 钮.get_meta("txt") as Label if 钮.has_meta("txt") else null
	if 文字 != null:
		文字.add_theme_color_override("font_color", Color.WHITE if not 钮.disabled else Color("#939393"))

func _gui_input(事件: InputEvent) -> void:
	if not (事件 is InputEventMouseButton) or not (事件 as InputEventMouseButton).pressed:
		return
	var 键 := 事件 as InputEventMouseButton
	if 键.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	if _列表窗口 != null and Rect2(_列表窗口.get_global_transform_with_canvas().origin, _列表窗口.size) \
			.has_point(get_global_mouse_position()):
		_滚像素(-12.0 if 键.button_index == MOUSE_BUTTON_WHEEL_UP else 12.0)	# 同聊天栏：delta3 × lineScrollSize4
		get_viewport().set_input_as_handled()
