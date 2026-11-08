extends RefCounted

## 原版「活跃度」窗（`ActivityTaskWindow`）的刷新与交互。
##
## 版式（谁在什么位置、多大、什么色）**全部烘在**
## `场景/界面/窗口/活跃度/活跃度窗口.tscn` 里 —— 那份由
## `开发工具/生成活跃度窗口场景.py` 从 `数据/活跃度奖励.json` + 反编译 AS3 生成，
## 坐标逐条带行号。本文件**不摆一个控件**，只做 AS3 里"数据回来之后才发生的事"：
##
## | 本文件做的事 | 原版出处 |
## |---|---|
## | 15 条次数 `(已做/所需)` | `ActivityTaskPaneCell.setCount:132-139` |
## | 次数满了 ⇒ 隐「打开/前往」+ 小鸟、显「完成」章 | 同 `setCount` + `setMcVisible:351-359` |
## | 8 档奖励的「已领」章 + 置灰 | `ActivityTaskWindow.updateGotLevel:78-92` + `RewardPane.setEnabled:37-52` |
## | 条文本 `分数/150` + 凹槽按分数填充 | `ActivityTaskWindow.setDataBottom:268-283` |
## | 「领取奖励」可点性 + 可点时闪动 | 同 `setDataBottom` + `onShandong:97-110` + `__onEnterFrame:211-223` |
## | 每档经验按**玩家等级**重算 | `RewardPane.setData:122-126` = `int(exp × 等级³ ÷ 100)` |
## | 「打开/前往」悬停变红 | `ActivityTaskPaneCell:56-64`（MOUSE_OVER→UI_RED，OUT→UI_BLUE） |
##
## 数据从 `_backend.authoritative_activity` 读（`2326` 帧，见 `后端连接._handle_activity_text`）：
## `task_counts` 15 项 / `claimed_level` 已领到的**档位下标**（-1 = 一档没领）/ `points` 总活跃分。
## 状态变化时 `功能窗口` 已把 `activity_state_received` 接到 `_render_page()`，所以这里
## 只在渲染时读一次，不自建刷新循环。
##
## ⚠️ 三条协议/玩法边界（按工程规矩，本移植只画不接）：
## 「打开」跳 Boss/PVP/意志/家族窗、「前往」与小鸟的 NPC 寻路，原版靠
## `ActivityTaskPaneCell.setData:257-282` 从 **icon 类名**反推 `itemName`/`targetId`
## （boss/pvp/yizhi/jiazu、targetId 18/23），再调 `requestWangList` / `PvpManager` /
## `MovePlayerToNpc`。真值已经抄在上面这份注释里，**接线归 群主**。

const 活跃度场景 := preload("res://场景/界面/窗口/活跃度/活跃度窗口.tscn")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## `ActivityTaskWindow.TOTAL_HUOYUEDU`
const 总活跃度 := 150
## `RewardPane.setEnabled` 里那六个被压到 0.6 的东西（不含底图和「已领」章）
const 置灰项 := ["标题", "分隔线", "经验", "点券"]
const 置灰物品前缀 := ["物品1", "物品2"]
const 置灰透明度 := 0.6
## `UIConfig.UI_BLUE` / `UI_RED` —— 链接的常态与悬停态
const 色_链接 := Color("#1e90ff")
const 色_悬停 := Color("#ff0000")
## 凹槽可视段的原生宽度：`MBarExpF` 的 maskMc 在 `width=450` 之后是 450-28=422
const 填充满宽 := 422.0
## `__onEnterFrame` 的 GlowFilter 色 16773120 = #fff000；blur 4→20→4 每帧 ±1
## ⇒ 一个来回 32 帧 ≈ 0.53s。原版是**外发光**，本工程跑 gl_compatibility，
## `modulate > 1` 会被夹住、发不出亮，所以这里用"金色 ↔ 本色"的脉冲代替，
## 触发条件与节奏照抄，只有手段不同（记在未决清单）。
const 色_闪动 := Color("#fff000")
const 闪动半周期 := 0.265

# ==================== 行上的「打开 / 前往 / 小鸟」 ====================
#
# 这一行的三个动作**不是按名字猜的**：原版 `ActivityTaskPaneCell` 从**图标类名**反推
# 该行要干什么（`setData:257-282` 的两个 switch），下面两张表就是照抄那两个 switch。

## 图标类名 → 「打开」要开的东西（`setData:259-272`）。
## 值即原版内部名 `itemName`，与 `onOpen:80-127` 的 switch 分支一一对应。
const 图标到条目 := {
	"UISwf_ActivityTask_BossBattle": "boss",
	"UISwf_ActivityTask_ArenaBattle": "pvp",
	"UISwf_ActivityTask_SpritePower": "yizhi",
	"UISwf_ActivityTask_OurHonor": "jiazu",
}
## 图标类名 → 「前往/小鸟」要找的 NPC 模板 id（`setData:273-282`）。
## 原版分两组给 18 / 23，不是"每个任务一个 NPC"。
const 图标到NPC := {
	"UISwf_ActivityTask_LianZhanCopy": 18,
	"UISwf_ActivityTask_Destiny": 18,
	"UISwf_ActivityTask_RenBattle": 18,
	"UISwf_ActivityTask_GoodGuys": 18,
	"UISwf_ActivityTask_SevenIsGood": 18,
	"UISwf_ActivityTask_CheckLuck": 18,
	"UISwf_ActivityTask_Run": 18,
	"UISwf_ActivityTask_EscortTask": 23,
}
## 原版 `PvpManager.PVP_ENTER_LEVEL`（`PvpManager.as:30`）与 `YiZhiManager.LIMIT_LEVEL`（`:28`）。
const 竞技场门槛 := 30
const 意志门槛 := 20
## 红色千纸鹤。「小鸟」跨图传送要持有它（原版 `ActivityTaskPaneCell.as:160`
## `isBagExistItem(16000010) > 0`）。它本身在 GameData `Gift.everyday.day2` 的奖励里。
const 千纸鹤 := "16000010"


static func 渲染(窗口) -> void:
	var 页面 := 窗口._instantiate_page(活跃度场景) as Control
	var 状态: Dictionary = 窗口._backend.authoritative_activity if 窗口._backend != null else {}
	var 档位: Array[Dictionary] = 游戏数据.活跃度档位()
	var 任务: Array[Dictionary] = 游戏数据.活跃度任务()
	var 等级 := 1
	if 窗口._session != null:
		等级 = maxi(1, int(窗口._session.player_stats.get("level", 1)))
	_刷新任务(页面, 任务, 状态.get("task_counts", []))
	_刷新奖励(页面, 档位, 状态, 等级)
	_刷新底部(窗口, 页面, 档位, 状态)
	_绑悬停(页面)
	_绑行动作(窗口, 页面, 任务)


## `ActivityTaskWindow.setLeftCount:154-162` —— 15 条一律 setCount，缺项按 0。
static func _刷新任务(页面: Control, 任务: Array, 次数: Variant) -> void:
	var 列表 := 页面.get_node_or_null("内容底/任务面板/任务滚动区/任务列表") as Container
	if 列表 == null:
		push_error("活跃度页缺 内容底/任务面板/任务滚动区/任务列表")
		return
	for 序 in 任务.size():
		var 行 := 列表.get_child(序) as Control
		if 行 == null:
			continue
		var 所需 := int(任务[序].get("count", 0))
		var 已做 := int(次数[序]) if 次数 is Array and 序 < (次数 as Array).size() else 0
		# setCount:134 —— 括号和斜杠都是文本的一部分，不是排版
		var 次数文本 := 行.get_node_or_null("次数") as Label
		if 次数文本 != null:
			次数文本.text = "(%d/%d)" % [已做, 所需]
		var 已满 := 已做 >= 所需
		# setMcVisible(false) 时：链接与小鸟一起隐、完成章显（:351-359 就是同一开关取反）。
		# 注意 openTxt 是**无条件存在**的（open==0 时只是空文本），原版也照样置 visible，
		# 所以这里不特判空文本 —— 空文本没有像素，置与不置看不出差别。
		for 名 in ["链接", "小鸟"]:
			var 件 := 行.get_node_or_null(名) as CanvasItem
			if 件 != null:
				件.visible = not 已满
		var 完成 := 行.get_node_or_null("完成") as CanvasItem
		if 完成 != null:
			完成.visible = 已满
		elif 已满:
			push_error("活跃度页第 %d 行没有「完成」章节点" % (序 + 1))


static func _绑悬停(页面: Control) -> void:
	var 列表 := 页面.get_node_or_null("内容底/任务面板/任务滚动区/任务列表") as Container
	if 列表 == null:
		return
	for 行 in 列表.get_children():
		var 链接 := (行 as Control).get_node_or_null("链接") as Label
		# 原版给 openTxt 无条件挂了 MOUSE_OVER/OUT（哪怕 open==0 时它是空文本）。
		# 空文本没有可视像素 ⇒ 收不到鼠标，与原版一致，不必特判。
		if 链接 == null or 链接.text.is_empty():
			continue
		链接.mouse_entered.connect(链接.add_theme_color_override.bind("font_color", 色_悬停))
		链接.mouse_exited.connect(链接.add_theme_color_override.bind("font_color", 色_链接))


## 给每一行的「打开/前往」链接与「小鸟」接上动作。
##
## 原版这一行有两个可点件，**做的事不一样**（`ActivityTaskPaneCell.as`）：
##   链接：open=1 → `onOpen` 开对应窗口（`:80-127`）；open=2 → `onGoTo` 走**本图**那个 NPC（`:239-245`）
##   小鸟：open=2 才有 → `onClickBirdMC` **跨图**传送（`:141-...`，要先持有红色千纸鹤）
static func _绑行动作(窗口, 页面: Control, 任务: Array) -> void:
	var 列表 := 页面.get_node_or_null("内容底/任务面板/任务滚动区/任务列表") as Container
	if 列表 == null:
		return
	for 序 in mini(任务.size(), 列表.get_child_count()):
		var 行 := 列表.get_child(序) as Control
		if 行 == null:
			continue
		var 图标 := String((任务[序] as Dictionary).get("icon", ""))
		var 开放 := int((任务[序] as Dictionary).get("open", 0))
		var 条目 := String(图标到条目.get(图标, ""))
		var 目标 := int(图标到NPC.get(图标, 0))
		var 链接 := 行.get_node_or_null("链接") as Label
		if 链接 != null:
			# 场景里 链接 的 `mouse_filter` 已经是 STOP（悬停能收到），这里只连点击。
			for 连 in 链接.gui_input.get_connections():
				链接.gui_input.disconnect(连["callable"])
			链接.gui_input.connect(func(事件: InputEvent):
				if not (事件 is InputEventMouseButton and 事件.pressed
						and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
					return
				if 开放 == 1 and not 条目.is_empty():
					_打开条目(窗口, 条目)
				elif 开放 == 2 and 目标 > 0:
					_前往条目(窗口, 目标))
		var 小鸟 := 行.get_node_or_null("小鸟") as TextureRect
		if 小鸟 == null or 目标 <= 0:
			continue
		# ⚠️ 场景里 小鸟 的 `mouse_filter` 是 **IGNORE**（默认值），原版 `birdMC.buttonMode = true`
		#    是要能点的 —— 不改这个属性它永远收不到鼠标。本页只有这一处运行期动鼠标过滤。
		小鸟.mouse_filter = Control.MOUSE_FILTER_STOP
		小鸟.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for 连 in 小鸟.gui_input.get_connections():
			小鸟.gui_input.disconnect(连["callable"])
		小鸟.gui_input.connect(func(事件: InputEvent):
			if 事件 is InputEventMouseButton and 事件.pressed \
					and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_飞往条目(窗口, 目标))


## 原版 `ActivityTaskPaneCell.onOpen:80-127`。各分支都带等级门槛，不够就只提示。
static func _打开条目(窗口, 条目: String) -> void:
	var 等级 := 1
	if 窗口._session != null:
		等级 = maxi(1, int(窗口._session.player_stats.get("level", 1)))
	match 条目:
		"boss":
			窗口._session.request_feature("首领")
		"yizhi":
			if 等级 >= 意志门槛:
				窗口._session.request_feature("遗址")
			else:
				_提示(窗口, "很抱歉，你的等级不够")
		"jiazu":
			# 原版按"有没有家族"分流到家族列表 / 家族贡献窗；本移植的「家族」页两者都在。
			窗口._session.request_feature("家族")
		"pvp":
			# 原版 `ActivityTaskPaneCell.as:96-98`：等级 >= `PVP_ENTER_LEVEL`(30) 且 `isOpen` ⇒ `showPvpWindow()`
			# （= `reverseDisplay`，已开则关 ⇒ 走 `窗口管理.打开或收起` 那一条）。`isOpen` 原版出厂就是 true（`:38`）。
			if 等级 >= 竞技场门槛:
				窗口._session.request_feature("竞技场")
			else:
				_提示(窗口, "很抱歉，你的等级不够")


## 原版 `onGoTo:239-245` → `CharacterHandler.MovePlayerToNpc(targetId)`：走**本图**那个 NPC。
## 目标不在地图上时原版是静默无动作；这里给一句提示，否则玩家只会觉得"点了没反应"。
static func _前往条目(窗口, npc_id: int) -> void:
	var 玩家 := _取玩家(窗口)
	if 玩家 == null or 窗口._session == null:
		return
	var 编号 := "%08d" % npc_id
	for npc in 窗口._session.get_map_npcs():
		if String(npc.get("id", "")) != 编号:
			continue
		if 玩家.has_method("走向"):
			## 第 4 参 = 原版 `pathFind` 的 `showtip`：这一支等价于 `MovePlayerToNpc`
			## （`CharacterHandler.as:710` 传 true）⇒ 要挂「自动寻路中」。
			玩家.走向(Vector2(float(npc.get("x", 0)), float(npc.get("y", 0))), true, true)
		return
	_提示(窗口, "该 NPC 不在这张地图上，请点右边的红色千纸鹤传送过去")


## 原版 `onClickBirdMC:141-...` → `ActivityTaskManager.startTransfer` →
## `requestMoveToNpcMap(npcId, mapId)`（`MOVETO_NPCMAP = 4027`）。
## 两道守卫照原版：副本/战场里不能传送；跨图要先持有红色千纸鹤。
static func _飞往条目(窗口, npc_id: int) -> void:
	if 窗口._backend == null or 窗口._session == null:
		return
	if int(窗口._session.copy_state.get("active_copy_id", -1)) >= 0:
		_提示(窗口, "对不起，在副本中无法直接传送")
		return
	var 目标图 := _NPC所在地图(npc_id)
	if 目标图 <= 0:
		_提示(窗口, "找不到该 NPC 的位置")
		return
	if str(目标图) == str(窗口._session.current_map_id):
		_前往条目(窗口, npc_id)          # 已经在本图，走过去就行，不必消耗道具
		return
	if not _持有千纸鹤(窗口):
		_提示(窗口, "需要一只红色千纸鹤才能传送过去")
		return
	窗口._backend.request_move_to_npc_map(npc_id, 目标图, 0, true, true)


## `NpcLocation`（GameData `Etc` 段，已随 `数据/原版杂项.json` 导出）：
## 键是**8 位补零的 NPC id**、子键 `"0"` 是该 NPC 所在地图。原版 `StringTool.getNpcLocation`。
static func _NPC所在地图(npc_id: int) -> int:
	var 表: Variant = 游戏数据.取表("原版杂项").get("NpcLocation", {})
	if 表 is not Dictionary:
		return 0
	var 条: Variant = (表 as Dictionary).get("%08d" % npc_id, null)
	return int((条 as Dictionary).get("0", 0)) if 条 is Dictionary else 0


static func _持有千纸鹤(窗口) -> bool:
	if 窗口._session == null:
		return false
	for 件 in 窗口._session.inventory:
		if 件 is Dictionary and String((件 as Dictionary).get("id", "")) == 千纸鹤:
			return int((件 as Dictionary).get("count", 0)) > 0
	return false


static func _取玩家(窗口) -> Node2D:
	var 树: SceneTree = 窗口.get_tree()
	return 树.get_first_node_in_group("player") as Node2D if 树 != null else null


static func _提示(窗口, 文本: String) -> void:
	if 窗口._status != null:
		窗口._show_hint(文本)


## `updateGotLevel:78-92` —— `for (i = -1; i < claimed; i++) rewardArr[i+1].setEnabled(false)`
## ⇒ 下标 0..claimed_level 的档位盖「已领」章。claimed_level=-1（一档没领）时一个都不盖。
static func _刷新奖励(页面: Control, 档位: Array, 状态: Dictionary, 等级: int) -> void:
	var 已领 := int(状态.get("claimed_level", -1))
	for 序 in 档位.size():
		var 格 := 页面.get_node_or_null("内容底/奖励%d" % (序 + 1)) as Control
		if 格 == null:
			push_error("活跃度页缺 内容底/奖励%d" % (序 + 1))
			continue
		# setData:124-126，烘的是等级 1 ⇒ 这里无论如何都要重写
		var 经验 := 格.get_node_or_null("经验") as Label
		if 经验 != null:
			经验.text = "经验：%d" % int(int(档位[序].get("exp", 0)) * pow(等级, 3) / 100)
		var 盖了 := 序 <= 已领
		var 章 := 格.get_node_or_null("已领") as CanvasItem
		if 章 != null:
			章.visible = 盖了
			# setEnabled 的 `filters = ColorMatrix(保留 R、G/B 归零)` 等价于乘 (1,0,0)
			章.self_modulate = Color(1, 0, 0, 1) if 盖了 else Color.WHITE
		var 透明 := 置灰透明度 if 盖了 else 1.0
		for 名 in 置灰项:
			var 件 := 格.get_node_or_null(名) as CanvasItem
			if 件 != null:
				件.modulate.a = 透明
		for 前 in 置灰物品前缀:
			for 后缀 in ["格", "图", "数量"]:
				var 件 := 格.get_node_or_null(前 + 后缀) as CanvasItem
				if 件 != null:
					件.modulate.a = 透明


## `setDataBottom:268-283` —— 条文本、凹槽宽度、领取钮的可点性与闪动。
static func _刷新底部(窗口, 页面: Control, 档位: Array, 状态: Dictionary) -> void:
	var 分数 := int(状态.get("points", 0))
	var 条 := 页面.get_node_or_null("内容底/活跃度条") as Control
	if 条 != null:
		var 文本 := 条.get_node_or_null("条文本") as Label
		if 文本 != null:
			文本.text = "%d/%d" % [分数, 总活跃度]
		var 裁剪 := 条.get_node_or_null("条裁剪") as Control
		if 裁剪 != null:
			# 原版 tween 的是 `maskMc.width`（整条 450 宽画好、从左往右露出来），
			# 所以这里改的是裁剪框宽度，不是填充图的宽度 —— 后者会把贴图压扁。
			裁剪.size.x = 填充满宽 * minf(1.0, float(分数) / 总活跃度)
	var 钮 := 页面.get_node_or_null("内容底/领取奖励") as Button
	if 钮 == null:
		push_error("活跃度页缺 内容底/领取奖励")
		return
	# :272-282 —— `param1 < 7 && levelArr[param1+1] <= param2`。已领=-1 时下档=0，
	# 即"第一档够分就亮"，与原版一致（不是"领完一档才亮下一档"）。
	# 小地图那颗活跃度光晕用的是同一条判据（`游戏数据.活跃度可领`），别各写一份。
	var 可领 := 游戏数据.活跃度可领(状态, 档位)
	钮.disabled = not 可领
	钮.pressed.connect(func():
		if 窗口._backend != null:
			窗口._backend.request_activity_claim())
	if 可领:
		# onShandong(true) 挂 ENTER_FRAME、false 时 filters=null。这里用循环 Tween 顶掉
		# 逐帧改滤镜，页面销毁时 Tween 随节点一起没。
		var 闪 := 钮.create_tween()
		闪.set_loops()
		闪.tween_property(钮, "self_modulate", 色_闪动, 闪动半周期).from(Color.WHITE)
		闪.tween_property(钮, "self_modulate", Color.WHITE, 闪动半周期)
