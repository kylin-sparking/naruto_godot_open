extends RefCounted

## 打坐时技能栏上方那颗「心法」球点开的窗 = 原版 `com/mxw/uifl/controls/XinfaWindow`
## （275×295，标题「修炼心法」）。静态件全由 `开发工具/原版服务窗.py 生成 心法` 从 SPEC 烘进
## `场景/界面/窗口/心法/心法窗.tscn`，**别手改 .tscn**；这里只做运行期那三件：
## 列表按**已学**心法建、箭头切列表显隐、确定/取消的分支。
## 逐件出处与文案见 `真值/窗口/心法.md`（§①几何、§②文案、§③列表口径、§④协议面）。

const 格宽 := 40.0		# 元件 130 `SkillCellF` 的 `background`(#125) 原生 40×40
const 区高 := 90.0		# `:32` `private var _height:int = 90`（滚动区可视高）
const 图标内缩 := 3.0		# `SkillCell.setSkillIcon():302-303` `icon.x = icon.y = 3`（图标原尺寸 34×34）
const 层数位 := Vector2(2.0, 25.0)	# 元件 130 时间轴 `floorText`(#126) @(2,25)
const 区宽 := 57.0		# `:194` `skillScrollPane.width = 57`

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
## 共用滚动条件（滑块下限 13 那条原版算法）。**目前只在这一页挂**，理由见 `配滚动区`。
const 滚动条件类 := preload("res://脚本/界面/组件/原版滚动条.gd")

static var _表: Dictionary = {}

## ★ 「选了哪一格」与「列表开没开」必须活在**重渲染之间**。原版这扇窗是一个活实例，回帧只调
##   `setSeleclSkillData()`（填主格 + 重建格子），**不重建窗口**；而本工程的宿主把
##   `heal_state_received` 接成了"整页重渲染"（`功能窗口._refresh_current`）⇒ 状态若只存在
##   `渲染()` 的局部变量里，**晚到的回帧会把玩家刚点的那一格冲成空**，他接着点「确定」就变成
##   "没选中 ⇒ 一颗字节都不发" —— 用户 2026-10-14 报的「有时候切换了没反应」正是这条竞态。
##   开窗（`宿主._刚开窗` 为真）时归零，等价于原版新建一个窗实例。
static var _选中: Dictionary = {"项": {}}
static var _展开 := false


## GameData `Skill` 段里 `xinfa==1` 那 21 条（由 `生产链/导出心法表.py` 落的表）。
## ⚠ 名称不在 Skill 自己的 `info.desc.name`（21 条里 15 条是空串），导出时已经用
##    `String` 段的 `Skill` 子段（键 = 七位补零的技能号）替好了。
static func 心法表() -> Dictionary:
	if not _表.is_empty():
		return _表
	var 读 := FileAccess.open("res://数据/界面/心法表.json", FileAccess.READ)
	if 读 == null:
		push_warning("心法窗：读不到 数据/界面/心法表.json ⇒ 列表会是空的")
		return _表
	var 解: Variant = JSON.parse_string(读.get_as_text())
	if 解 is Dictionary:
		_表 = (解 as Dictionary).get("条目", {}) as Dictionary
	return _表


## 本角色已学的心法 = 原版 `DataCenter.getFirstTypePassivizeSkills()`（`DataCenter.as:2058-2072`）：
## 遍历 **skillInfoList（已学）** 再按 `SkillDataTool.isSkillXinfa()`（= GameData `xinfa==1`）筛。
## ⇒ 列出的**不是**那 21 条，而是"这一号学过的哪几条"。每项 = {id, 名称, 层数, 图标}。
static func 已学心法(后端: Node) -> Array:
	var 出: Array = []
	if 后端 == null:
		return 出
	var 已学: Dictionary = 后端.get("authoritative_skills") as Dictionary
	var 表 := 心法表()
	for 键 in 表.keys():
		var 号 := int(String(键))
		if not 已学.has(号):
			continue
		var 项: Dictionary = 表[键] as Dictionary
		var 信: Dictionary = 已学[号] as Dictionary
		出.append({"id": 号, "名称": String(项.get("名称", "")),
				"层数": int(信.get("level", 0)), "图标": String(项.get("图标", ""))})
	出.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return 出


static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 后端: Node = 宿主.get("_backend") as Node
	var 区 := 页.get_node("心法列表") as ScrollContainer
	var 内容 := 页.get_node("心法列表/心法列表_内容") as Control
	var 箭头 := 页.get_node("选择心法钮") as Control
	var 主格 := 页.get_node("主格") as Control
	var 名标 := 页.get_node("心法名") as Label
	var 层标 := 页.get_node("心法层数") as Label
	var 主图 := _铺图标(主格, "主格图标")
	var 刚开 := bool(宿主.get("_刚开窗"))		# 开窗 vs 回帧引起的重建（见上面 `_选中` 那段）
	if 刚开:
		_选中 = {"项": {}}
		_展开 = false

	# ── 列表（`:212-232 initCellCount` + `:297-316 setData`）────────────────
	var 列表 := 已学心法(后端)
	配滚动区(区, 内容, 列表.size())
	区.visible = _展开		# ★ 原版常态 false：`skillScrollPane` 从没被 addChild 进显示列表
	for 序 in 列表.size():
		var 项: Dictionary = 列表[序] as Dictionary
		var 格 := Control.new()
		格.name = "格%d" % 序
		格.position = Vector2(0.0, 格宽 * float(序) + 2.0)		# `:223` `y = height * i + 2`
		格.size = Vector2(格宽, 格宽)
		格.mouse_filter = Control.MOUSE_FILTER_STOP
		# 手型：`SkillCell.setCellValue():273` 的 `buttonMode = true`。
		# ⚠ Control **没有** `cursor` 这个属性 —— 写 `格.cursor = ...` 运行期报
		#   `Invalid assignment of property or key 'cursor'`（本次真撞到），要的是
		#   `mouse_default_cursor_shape`。
		格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		内容.add_child(格)
		_铺格(格, String(项["图标"]), int(项["层数"]))
		格.gui_input.connect(_点格.bind(区, 主图, 名标, 层标, 项))
	# `:312` `selectSkillBtn.enabled = len > 0` —— MButton3 族 enabled=false 就吃掉指针
	箭头.mouse_filter = Control.MOUSE_FILTER_STOP if 列表.size() > 0 else Control.MOUSE_FILTER_IGNORE
	箭头.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if 列表.size() > 0 else Control.CURSOR_ARROW
	箭头.gui_input.connect(_点箭头.bind(列表.size(), 区))

	# ── 开窗查询（`UI.as:649-652` 只发 `7`；回帧 `1288:3:<id>` 才由 `Client.as:8033` 填主格）──
	# 只在**开窗**那一轮发：回帧引起的重渲染再发就成了 7→3→渲染→7 的死循环。
	# 也不能退化成"收到过 3 就不再发"—— 那样第二次开窗不查询，切完心法再打开还是旧值。
	if 刚开 and 后端 != null and 后端.has_method("request_xinfa_show"):
		后端.call("request_xinfa_show")
	# 主格：玩家已经点过一格 ⇒ 保住他那格（晚到的回帧不许冲掉）；否则用服务端回帧那颗
	if int((_选中["项"] as Dictionary).get("id", 0)) != 0:
		_填主格(主图, 名标, 层标, _选中["项"] as Dictionary)
	else:
		_按服务端填(后端, 列表, 主图, 名标, 层标)

	# ── 两颗钮共用一个分支（`:97-115 onClickOkBtn`）─────────────────────────
	(页.get_node("确定钮") as Button).pressed.connect(_点确定取消.bind(宿主, 后端, true, 区))
	(页.get_node("取消钮") as Button).pressed.connect(_点确定取消.bind(宿主, 后端, false, 区))
	return 页


## `:313` `skillScrollPane.height = len > 1 ? _height : _height >> 1` ⇒ 只有一枚（或没有）时压成 45。
## 内容宽一律走 `原版皮肤表.配原版滚动区()`（区宽 − 实测条宽），口径同 副本列表/兑换商店。
## 再叠上共用件「原版滚动条」——**目前只有这一页挂**（铺到共用路径上会把商城的滑块甩飞，
## 原因与再铺开的条件写在 `原版滚动条.挂到` / `原版皮肤表.配原版滚动区` 上面那段）。
static func 配滚动区(区: ScrollContainer, 内容: Control, 枚数: int) -> void:
	var 可视 := 区高 if 枚数 > 1 else float(int(区高) >> 1)
	区.size = Vector2(区宽, 可视)
	皮肤表.配原版滚动区(区, 内容, 区宽, 可视, 格宽 * float(maxi(1, 枚数)) + 2.0)
	滚动条件类.挂到(区, 内容, 区宽, 可视)


## 一格 = 底板 + 图标（原尺寸，不缩放）+ 层数角标。
## ⚠ 主格**不走这里的角标**：`:190` `selectSkillIocn.floorText.text = ""` 起步就清空、
##   `setSeleclSkillData` 也只 `setCellValue`+`setSkillIcon`，没再写 floorText ⇒ 主格永远没有层数字。
static func _铺格(格: Control, 图标路: String, 层数: int) -> void:
	var 底 := _铺一层(格, "格底")
	底.texture = load("res://素材/界面/技能面板/技能格底板.png")
	_铺图标(格, "格图标", 图标路)
	_格层数(格, 层数)


## `SkillCell.setSkillIcon():302-303` = `icon = PicTool.getSkillPic(id)`、`icon.x = icon.y = 3`
## —— 图标**原尺寸**摆（技能图标原生 34×34），不许拉伸。
static func _铺图标(父: Control, 名: String, 图标路 := "") -> TextureRect:
	var 图 := TextureRect.new()
	图.name = 名
	图.position = Vector2(图标内缩, 图标内缩)
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP
	if 图标路.begins_with("res://") and ResourceLoader.exists(图标路):
		图.texture = load(图标路) as Texture2D
	父.add_child(图)
	return 图


## `SkillCell.setCellValue():277-283` 的 `floorText.text = floor`（`+加成` 那半段依赖
## `getAddedSkillLevel()`，本工程与技能栏一样还没接 ⇒ 挂在真值 md 的未决表）。
static func _格层数(格: Control, 层数: int) -> void:
	if 层数 <= 0:
		return		# 原版 `param1.floor > 0` 才显（`技能面板.gd:256` 同一口径）
	var 标 := Label.new()
	标.name = "格层数"
	标.position = 层数位
	标.size = Vector2(34.0, 14.0)
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", Color.WHITE)
	标.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	# 描边一律读规则值：`SkillCell.as:126` `floorText.filters = BaseUtil.getGlowFilter()` ——
	# 是 UI 那一族的标准辉光（blur 2），**不是** `KeyboardCell` 标号用的 MGlaveLabel（blur 3），
	# 所以这里不许抄技能栏那个 3（抄了就等于给这族角标自造一档描边）。
	标.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.text = str(层数)
	格.add_child(标)


## `:85-96 setSeleclSkillData(param1)`：`param1 && param1.id != 0` 才填主格，
## 之后**无条件** `setData()`（= 重建列表）。回帧带来的 id 不在已学列表里 ⇒ 什么都不填。
static func _按服务端填(后端: Node, 列表: Array, 主图: TextureRect, 名标: Label, 层标: Label) -> void:
	if 后端 == null:
		return
	var 当前 := int((后端.get("authoritative_heal") as Dictionary).get("xinfa_id", 0))
	if 当前 == 0:
		return
	for 项 in 列表:
		if int((项 as Dictionary)["id"]) == 当前:
			_填主格(主图, 名标, 层标, 项 as Dictionary)
			return


## `:245-249 onClickSkill` = `setSeleclSkillData(该格)` + `onClickSkillBtn(null)`（收起列表）。
static func _点格(事: InputEvent, 区: ScrollContainer, 主图: TextureRect, 名标: Label,
		层标: Label, 项: Dictionary) -> void:
	if not (事 is InputEventMouseButton) or not (事 as InputEventMouseButton).pressed:
		return
	if int((事 as InputEventMouseButton).button_index) != MOUSE_BUTTON_LEFT:
		return
	_选中["项"] = 项		# ★ 只有**玩家点的那一格**才登记（扛住晚到的回帧，见 `_填主格` 上面那段）
	_填主格(主图, 名标, 层标, 项)
	_展开 = false
	区.visible = false


## `:69-83 onClickSkillBtn`：`if(data.length > 0)` 才开关 —— 有父就摘、没父就挂。
## ⚠ 参数序必须是**事件在前**：`Callable.bind()` 是把绑的参数**接在调用参数后面**，
##   写成 `_点箭头(枚数, 事, 区)` 会让 枚数 收到 InputEvent、事 收到 int ⇒ 运行期报
##   Invalid type、箭头点了没反应（2026-10-13 行为门第一条红就是这个）。
static func _点箭头(事: InputEvent, 枚数: int, 区: ScrollContainer) -> void:
	if 枚数 <= 0:
		return
	if not (事 is InputEventMouseButton) or not (事 as InputEventMouseButton).pressed:
		return
	if int((事 as InputEventMouseButton).button_index) != MOUSE_BUTTON_LEFT:
		return
	_展开 = not _展开
	区.visible = _展开


## `:92` `skillLevel.text = CN.CURRENT_CENGSHU + param1.floor` = 「当前层数:」+ 层数。
## ⚠ 这里**不登记选中**：主格被填上有两个来源 —— 玩家点格子、服务端回帧顶上来。
##   只有前者才算"玩家的主意"（要扛住晚到的回帧），后者只是**当前这一刻的真相**，
##   下一轮回帧必须能把它换掉。混在一起登记 = 每次开窗都显示上一次那颗、下一开才追上
##  （用户 2026-10-14 实机报的「慢一开」）。
static func _填主格(主图: TextureRect, 名标: Label, 层标: Label, 项: Dictionary) -> void:
	var 图标路 := String(项["图标"])
	# 主格的图标同样摆 (3,3) 原尺寸 —— 它是 `_铺图标()` 建的 TextureRect，只换 texture 不动位置
	主图.texture = (load(图标路) as Texture2D) if 图标路.begins_with("res://") else null
	名标.text = String(项["名称"])
	层标.text = "当前层数:%d" % int(项["层数"])


## `:97-115 onClickOkBtn`（两颗钮挂在同一个函数上，靠 `param1.target` 分流）：
## · 主格有值 且 target == okBtn ⇒ 派发 XINFA_XIULIAN_OK ⇒ `UI.as:1836-1839 xiulianXinfa()`
##   ⇒ `Client.requestXinfaChange(skillId)` ⇒ `86:6:<id>`。
## · target == cancelBtn 那一支派发的是 XINFA_XIULIAN_CANCEL —— 全工程 grep 只注册了
##   OK 与 DAKAI 两个监听（`UI.as:1086-1087`）⇒ **取消一个字节都不发**。
## · 主格没值 ⇒ 两支都不发，但仍然往下走：收起列表 + 关窗（`:111-114` 在那个小写之外）。
static func _点确定取消(宿主: Node, 后端: Node, 是确定: bool, 区: ScrollContainer) -> void:
	var 号 := int((_选中["项"] as Dictionary).get("id", 0))
	if 号 != 0 and 是确定 and 后端 != null and 后端.has_method("request_xinfa_change"):
		后端.call("request_xinfa_change", 号)
	if 区.visible:
		区.visible = false		# `:111-113` `if(skillScrollPane.parent) removeChild(...)`
	_展开 = false
	宿主.call("close")		# `:114` `onCloseBtnClick(null)`


static func _铺一层(父: Control, 名: String) -> TextureRect:
	var 图 := TextureRect.new()
	图.name = 名
	图.position = Vector2.ZERO
	图.size = 父.size
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_SCALE
	父.add_child(图)
	return 图
