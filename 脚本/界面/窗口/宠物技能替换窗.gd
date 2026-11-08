extends Control

## 原版「宠物技能重置」主窗 —— `com/mxw/uifl/controls/pet/PetSkillResetWindow.as`（444×423）。
##
## 入口链（巡检 #22 之前**整条缺失**）：背包双击/使用「神奇技能符」15018001
## → `ItemWindow2.as:1056` 的 `type == "jineng"` 支 ⇒ `new PetSkillResetWindow()` + `setItem`
## → 窗里「确定重置」才发 `requestUseItem(position, itemId, {oldskill,newskill,petUid})`
## （`PetSkillResetWindow.as:89-93`），服务端 `_use_pet_skill_symbol` 结算并回 17 号技能列表。
##
## 版式真值（坐标全是**窗局部**，`initWindow:164-235` + `drawSkin:138-162`）：
##   `_contentBg` = (8,38) 428×355（`UIWindow` 的 CONTENT_GAP=8、高 = 423−68）
##   列表底板 MPane 177×136 @ (13,60)；列表线 (16,82) 171×2
##   宠物列表 (15,84) 169×105、行高 22
##   装备面板 `PetEquipmentPanel.SMALL` 236×115 @ (192,60)
##   宠物行 (192,175) 宽 236 居中；分隔线一 y=198、分隔线二 y=283（x=11、宽 422）
##   label1 (16,38)、label2 (16,200)、label3 (16,285) 全是 UI_ORANGE；label4 (16,395) 绿
##   八技能格 x=16、y=230、步距 = 格宽 40 + 7；新技能格 (16,315)
##   查阅 y = 315+40 = 355；确定重置 x = 444−宽−8、y = 423−22−5
##
## ⚠️ 三个 `addNotice` 的原文与判据顺序逐字照 `resetSkill:69-94`：
##   没选宠物 → `..._PROMPT_1`；没选旧技能 → `..._PROMPT_2`；没选新技能 → `..._PROMPT_3`。
##   窗**不自己关** —— 原版那次发包之后也没有 `onCloseBtnClick`；成功与否由服务端回帧/提示决定，
##   技能列表靠 `pets_changed` 就地刷新（同 `宠物窗口` 的刷新口径）。
##
## 「查阅」开的是 `宠物技能选择窗`（同 444×423），摆位照 `UIMain2.centerTwoWindow:3159-3185`：
##   选择窗居中、重置窗放它右边 1px（两窗并排）。选完**选择窗不关**
##   （`PetSkillSelectWindow.selectedSkillHandler:64-72` 只回填 `setResetSkill`），
##   要退出由玩家点它自己的关闭钮；原版关重置窗不连带关选择窗，这里连带收起（见 `隐藏`）。

signal 确认替换(宠物uid: int, 旧技能: int, 新技能: int)
signal 关闭了

const 界面皮肤 := preload("res://脚本/界面/窗口/界面皮肤.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 宠物数值 := preload("res://脚本/角色/宠物数值.gd")
const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 装备提示场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")
const 选择窗脚本 := preload("res://脚本/界面/窗口/宠物技能选择窗.gd")
## 选中环的「只留橙框」处理与 `自选礼包窗` 同一份（原版两处都是 `SkillCellSelectedGridF`
## 那套带灰底的选中态，用户 2026-11-07 要求只保留橙框）。
const 自选礼包窗脚本 := preload("res://脚本/界面/窗口/自选礼包窗.gd")

const 关闭钮皮 := "res://素材/界面/原版窗口/通用控件/关闭按钮.png"
const 分隔线皮 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"
const 格底图 := preload("res://素材/界面/原版窗口/通用控件/物品格.png")
const 装备面板皮 := preload("res://素材/界面/原版窗口/宠物/宠物装备面板.png")
const 附身皮 := "res://素材/界面/原版窗口/宠物/状态_附.png"
const 出战皮 := "res://素材/界面/原版窗口/宠物/状态_战斗.png"

const 窗宽 := 444.0
const 窗高 := 423.0
const 内容位 := Vector2(8.0, 38.0)
const 内容宽 := 428.0
const 内容高 := 355.0
const 列表面板位 := Vector2(13.0, 60.0)
const 列表面板尺寸 := Vector2(177.0, 136.0)
const 列表线位 := Vector2(16.0, 82.0)
const 列表线宽 := 171.0
const 宠物列表位 := Vector2(15.0, 84.0)
const 宠物列表尺寸 := Vector2(169.0, 105.0)
const 宠物行高 := 22.0
const 装备面板位 := Vector2(192.0, 60.0)
const 装备面板尺寸 := Vector2(236.0, 115.0)
const 宠物行位 := Vector2(192.0, 175.0)
const 宠物行宽 := 236.0
const 分隔一y := 198.0
const 分隔二y := 283.0
const 分隔x := 11.0
const 分隔宽 := 422.0
const 技能格起点 := Vector2(16.0, 230.0)
const 技能格尺寸 := 40.0
const 技能格步 := 47.0		# `_loc1_ += _loc3_.width + 7`
const 技能格数 := 8
const 新技能格位 := Vector2(16.0, 315.0)
const 查阅位 := Vector2(16.0, 355.0)
const 确定y := 396.0		# `_height − height − UIConfig.BORDER_GAP` = 423−22−5
const 底部右边距 := 8.0		# `UIConfig.CONTENT_GAP`
const 绿字位 := Vector2(16.0, 395.0)	# `_height − 28`
const 绿字宽 := 360.0
const 关闭钮宽 := 25.0
const 关闭钮高 := 24.0

## 装备面板五格（`PetEquipmentPanel.updateDisplayList:125-144`，SMALL 分支）：
##   equip1 (8,10)=PetA 兽铠 / equip3 (188,10)=PetC 兽符 / equip2 (8,55)=PetD 兽盔
##   equip4 (188,55)=PetB 兽爪 / equip5 (53,55)=PetE 变身
const 装备槽表 := [
	{"位": Vector2(8.0, 10.0), "名": "兽铠", "部位": 1},
	{"位": Vector2(188.0, 10.0), "名": "兽符", "部位": 3},
	{"位": Vector2(8.0, 55.0), "名": "兽盔", "部位": 4},
	{"位": Vector2(188.0, 55.0), "名": "兽爪", "部位": 2},
	{"位": Vector2(53.0, 55.0), "名": "变身", "部位": 5},
]
## 装备面板里宠物立绘的注册点（`PetEquipmentPanel.as:115-116`：x=(236−60)/2+30、y=equip2.y+40−5）。
const 模型位 := Vector2(118.0, 90.0)

const 橙 := Color("#ff9100")	# `UIConfig.UI_ORANGE = 16748800`
const 白 := Color.WHITE
const 绿 := Color("#00ff00")	# `UIConfig.UI_GREEN = 65280`
const 蓝 := Color("#1e90ff")	# `UIConfig.UI_BLUE = 2003199`

const 窗口标题 := "宠物技能重置"		# `CN.PETSKILLRESETWINDOW_TITLE`
const 选宠提示 := "1.请选择您需要重置技能的宠物"			# `..._SELECET_PET_STR`
const 选技能提示 := "2.所选宠物技能如下，请选择您要重置的宠物技能"	# `..._RESET_SKILL_STR_1`
const 新技能提示 := "3.您希望把该技能重置为"			# `..._RESET_SKILL_STR_2`
const 九阶提示 := "神奇技能符仅限【9阶】以上宠物使用"		# `..._RESET_SKILL_STR_3`
const 查阅字 := "查阅"			# `..._CHA_YUE`
const 确定字 := "确定重置"		# `..._SURE_RESET`
const 仅九阶提示 := "请选择您需要重置技能的宠物"		# `..._PROMPT_1`
const 选旧技能提示 := "请选择您要重置的技能"		# `..._PROMPT_2`
const 选新技能提示 := "请选择您要重置该技能的技能"	# `..._PROMPT_3`
const 携带数前缀 := "携带数量"		# `CN.PETWINDOW_XIE_DAI_SHU_LIANG`
const 名称字 := "名称"			# `CN.PETWINDOW_NAME`
const 等级字 := "等级"			# `CN.PETWINDOW_LEVEL`

static var _空样式: StyleBoxEmpty = null

var _宿主: Node = null
var _宠物们: Array = []
var _选中号 := 0			# 宠物的 `unique_id`；0 = 没选
var _旧技能 := 0
var _新技能 := 0
var _行们: Array[Button] = []
var _行条们: Array[TextureRect] = []
var _装备格们: Array[Button] = []
var _模型层: Control = null
var _宠物文本: RichTextLabel = null
var _携带数: Label = null
var _技能格们: Array[Button] = []
var _选中环: TextureRect = null
var _新格: Button = null
var _选择窗: Control = null
var _列表容器: VBoxContainer = null


static func _空() -> StyleBoxEmpty:
	if _空样式 == null:
		_空样式 = StyleBoxEmpty.new()
	return _空样式


static func _技能图标(技号: int) -> Texture2D:
	var 路径 := 游戏数据.skill_icon_path({"icon_class": "Skill_PetSkill_%d_icon" % 技号})
	if 路径.is_empty() or not ResourceLoader.exists(路径):
		return null
	return load(路径) as Texture2D


## `SkillCell.setCellPetValue:177-190` 的提示框：技能名 + 层数 + 说明。
static func _技能提示(技号: int, 等级: int) -> String:
	var 记 := 游戏数据.pet_skill(技号)
	return "%s Lv.%d\n%s" % [
		String(记.get("name", "宠物技能 %d" % 技号)), 等级, String(记.get("desc", ""))]


## `宿主` = `功能窗口`（格子提示框要它的 `_session` / `_舞台尺寸()`）。
func 打开(宿主: Node) -> void:
	_宿主 = 宿主
	_宠物们 = _取宠物清单()
	_重建()
	visible = true
	_居中()
	_接会话信号(true)


func _会话() -> Node:
	if _宿主 == null:
		return null
	return _宿主.get("_session") as Node


func _取宠物清单() -> Array:
	var 会话 := _会话()
	if 会话 == null:
		return []
	return (会话.get("pets") as Array).duplicate(true)


func _接会话信号(连: bool) -> void:
	var 会话 := _会话()
	if 会话 == null or not 会话.has_signal("pets_changed"):
		return
	var 回调 := Callable(self, "_收到宠物帧")
	if 连:
		if not 会话.is_connected("pets_changed", 回调):
			会话.connect("pets_changed", 回调)
	elif 会话.is_connected("pets_changed", 回调):
		会话.disconnect("pets_changed", 回调)


## 服务端换完技能会回 17（技能列表）+ UPDATE（整只宠）；两者都走 `pets_changed`。
## 原版对应的是 `updateCurrentPet:119-125` → `selectedPetHandler(null)`：整只重取、选中清空。
func _收到宠物帧(_宠物们v: Variant = null) -> void:
	if not visible:
		return
	_宠物们 = _取宠物清单()
	_刷新全部()


func _重建() -> void:
	for 子 in get_children():
		子.free()
	_行们.clear()
	_行条们.clear()
	_装备格们.clear()
	_技能格们.clear()
	_选中环 = null
	_新格 = null
	_选择窗 = null
	_模型层 = null
	_旧技能 = 0
	_新技能 = 0
	size = Vector2(窗宽, 窗高)

	var 框 := Panel.new()
	框.name = "框"
	框.position = Vector2.ZERO
	框.size = size
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	框.theme_type_variation = 皮肤表.变体_窗口边框
	add_child(框)

	var 标 := Label.new()
	标.name = "标题"
	标.text = 窗口标题
	标.position = Vector2(0.0, 5.0)
	标.size = Vector2(窗宽, 18.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.theme_type_variation = 皮肤表.变体_窗口标题
	add_child(标)

	var 关 := Button.new()
	关.name = "关闭"
	关.position = Vector2(窗宽 - 关闭钮宽 - 6.0, 6.0)
	关.size = Vector2(关闭钮宽, 关闭钮高)
	关.focus_mode = Control.FOCUS_NONE
	关.flat = true
	关.icon = load(关闭钮皮) as Texture2D if ResourceLoader.exists(关闭钮皮) else null
	关.pressed.connect(隐藏)
	add_child(关)

	var 黄底 := Panel.new()
	黄底.name = "黄底"
	黄底.position = 内容位
	黄底.size = Vector2(内容宽, 内容高)
	黄底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黄底.theme_type_variation = 皮肤表.变体_内容面板
	add_child(黄底)

	_标签(选宠提示, 橙, Vector2(16.0, 38.0), 417.0).name = "选宠提示"

	var 底板 := Panel.new()
	底板.name = "列表面板"
	底板.position = 列表面板位
	底板.size = 列表面板尺寸
	底板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(底板)

	_携带数 = Label.new()
	_携带数.name = "携带数量"
	_携带数.position = 列表面板位
	_携带数.size = Vector2(列表面板尺寸.x, 18.0)
	_携带数.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_携带数.mouse_filter = Control.MOUSE_FILTER_IGNORE
	界面皮肤.configure_label(_携带数, 12, 白)
	add_child(_携带数)

	_线("列表线", 列表线位, 列表线宽)

	var 滚 := ScrollContainer.new()
	滚.name = "宠物列表"
	滚.position = 宠物列表位
	滚.size = 宠物列表尺寸
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	滚.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	滚.clip_contents = true
	add_child(滚)
	var 行容器 := VBoxContainer.new()
	行容器.name = "行容器"
	行容器.custom_minimum_size = Vector2(宠物列表尺寸.x, 0.0)
	行容器.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	行容器.add_theme_constant_override("separation", 0)
	滚.add_child(行容器)
	_列表容器 = 行容器

	# —— 宠物装备面板（`PetEquipmentPanel.SMALL`，九宫格底 + 五格 + 立绘）——
	var 装备层 := Control.new()
	装备层.name = "装备面板"
	装备层.position = 装备面板位
	装备层.size = 装备面板尺寸
	装备层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(装备层)
	var 底 := NinePatchRect.new()
	底.name = "底"
	底.texture = 装备面板皮
	底.patch_margin_left = 12
	底.patch_margin_top = 12
	底.patch_margin_right = 12
	底.patch_margin_bottom = 12
	底.position = Vector2.ZERO
	底.size = 装备面板尺寸
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	装备层.add_child(底)
	for 槽 in 装备槽表:
		var 格 := 物品格场景.instantiate() as Button
		var 部位 := int((槽 as Dictionary)["部位"])
		格.name = "装备格_%d" % 部位
		格.position = (槽 as Dictionary)["位"]
		格.focus_mode = Control.FOCUS_NONE
		格.set("可拖拽", false)
		装备层.add_child(格)
		_装备格们.append(格)
		var 槽名 := Label.new()
		槽名.name = "槽名"
		槽名.text = String((槽 as Dictionary)["名"])
		槽名.position = Vector2(0.0, 8.0)
		槽名.size = Vector2(技能格尺寸, 20.0)
		槽名.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		槽名.mouse_filter = Control.MOUSE_FILTER_IGNORE
		界面皮肤.configure_label(槽名, 12, 橙)
		格.add_child(槽名)
	_模型层 = Control.new()
	_模型层.name = "模型"
	_模型层.position = Vector2.ZERO
	_模型层.size = 装备面板尺寸
	_模型层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	装备层.add_child(_模型层)

	_宠物文本 = RichTextLabel.new()
	_宠物文本.name = "宠物文本"
	_宠物文本.bbcode_enabled = true
	_宠物文本.scroll_active = false
	_宠物文本.fit_content = false
	_宠物文本.position = 宠物行位
	_宠物文本.size = Vector2(宠物行宽, 18.0)
	_宠物文本.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_宠物文本.add_theme_font_size_override("normal_font_size", 12)
	_宠物文本.add_theme_constant_override("line_separation", 2)
	add_child(_宠物文本)

	_线("分隔线一", Vector2(分隔x, 分隔一y), 分隔宽)
	_标签(选技能提示, 橙, Vector2(16.0, 分隔一y + 2.0), 417.0).name = "选技能提示"

	# —— 八技能格 + 选中环（`SkillCellF` 40×40，步距 47）——
	for 号 in 技能格数:
		var 格 := _建技能格("技能格_%d" % 号, 技能格起点 + Vector2(技能格步 * 号, 0.0))
		格.pressed.connect(_点旧技能.bind(格))
		_技能格们.append(格)
	_选中环 = TextureRect.new()
	_选中环.name = "选中环"
	_选中环.texture = 自选礼包窗脚本._取纯选中环()
	_选中环.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_选中环.size = Vector2(46.0, 46.0)		# `SkillCellSelectedGridF` 46×46
	_选中环.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_选中环.visible = false
	add_child(_选中环)

	_线("分隔线二", Vector2(分隔x, 分隔二y), 分隔宽)
	_标签(新技能提示, 橙, Vector2(16.0, 分隔二y + 2.0), 417.0).name = "新技能提示"
	_新格 = _建技能格("新技能格", 新技能格位)
	_新格.disabled = true			# 原版 `setResetSkill` 由选择窗回填，本身不可点

	var 查阅 := Button.new()
	查阅.name = "查阅"
	查阅.text = 查阅字
	var 查阅宽 := _量钮宽(查阅字)
	查阅.position = 查阅位
	查阅.custom_minimum_size = Vector2(查阅宽, 22.0)
	查阅.size = Vector2(查阅宽, 22.0)
	界面皮肤.configure_standard_button(查阅, Vector2(查阅宽, 22.0))
	查阅.pressed.connect(_点查阅)
	add_child(查阅)

	var 确定 := Button.new()
	确定.name = "确定重置"
	确定.text = 确定字
	var 确定宽 := _量钮宽(确定字)
	确定.position = Vector2(窗宽 - 确定宽 - 底部右边距, 确定y)
	确定.custom_minimum_size = Vector2(确定宽, 22.0)
	确定.size = Vector2(确定宽, 22.0)
	界面皮肤.configure_standard_button(确定, Vector2(确定宽, 22.0))
	确定.pressed.connect(_点确定)
	add_child(确定)

	_标签(九阶提示, 绿, 绿字位, 绿字宽).name = "九阶提示"

	# 提示框最后建 ⇒ 盖得住五格与按钮（同 `礼包详情窗._建提示框`）。
	_建提示框()
	_刷新全部()


func _标签(文字: String, 颜色: Color, 位置: Vector2, 宽: float) -> Label:
	var 节点 := Label.new()
	节点.text = 文字
	节点.position = 位置
	节点.size = Vector2(宽, 18.0)
	节点.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	节点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	界面皮肤.configure_label(节点, 12, 颜色)
	add_child(节点)
	return 节点


func _线(名: String, 位置: Vector2, 宽: float) -> void:
	var 线 := TextureRect.new()
	线.name = 名
	线.texture = load(分隔线皮) as Texture2D if ResourceLoader.exists(分隔线皮) else null
	线.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	线.position = 位置
	线.size = Vector2(宽, 2.0)
	add_child(线)


## `SkillCellF`：格底 + 图标 + 左下角层数（`SkillCell.as:122-126`：floorText 在格内 (2,25)
## 宽 50、白字 12、黑描边）。
func _建技能格(名: String, 位置: Vector2) -> Button:
	var 格 := Button.new()
	格.name = 名
	格.position = 位置
	格.size = Vector2(技能格尺寸, 技能格尺寸)
	格.custom_minimum_size = Vector2(技能格尺寸, 技能格尺寸)
	格.focus_mode = Control.FOCUS_NONE
	格.flat = true
	for 状态 in ["normal", "hover", "pressed", "disabled", "focus"]:
		格.add_theme_stylebox_override(状态, _空())
	var 底 := TextureRect.new()
	底.name = "底"
	底.texture = 格底图
	底.position = Vector2.ZERO
	底.size = Vector2(技能格尺寸, 技能格尺寸)
	底.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(底)
	var 图标 := TextureRect.new()
	图标.name = "图标"
	图标.position = Vector2(3.0, 3.0)		# `MCell` 34×34 居中于 40×40
	图标.size = Vector2(34.0, 34.0)
	图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(图标)
	var 等级 := Label.new()
	等级.name = "等级"
	等级.position = Vector2(2.0, 25.0)
	等级.size = Vector2(50.0, 16.0)
	等级.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	等级.mouse_filter = Control.MOUSE_FILTER_IGNORE
	界面皮肤.configure_label(等级, 12, 白)
	格.add_child(等级)
	格.set_meta("skill_id", 0)
	add_child(格)
	return 格


func _建提示框() -> void:
	for 项 in [["物品提示框", 物品提示场景], ["装备提示框", 装备提示场景]]:
		var 名 := String(项[0])
		if get_node_or_null(名) != null:
			continue
		var 框 := (项[1] as PackedScene).instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(框)


## —— 列表 / 选中 ——

func _找宠(号: int) -> Dictionary:
	for 宠 in _宠物们:
		if int((宠 as Dictionary).get("unique_id", 0)) == 号:
			return 宠 as Dictionary
	return {}


func _校正选中() -> void:
	if _选中号 != 0 and not _找宠(_选中号).is_empty():
		return
	_选中号 = int((_宠物们[0] as Dictionary).get("unique_id", 0)) if not _宠物们.is_empty() else 0


func _刷新全部() -> void:
	_校正选中()
	_刷新宠物列表()
	_刷新选中宠()


func _刷新宠物列表() -> void:
	if _列表容器 == null:
		return
	for 子 in _列表容器.get_children():
		子.free()
	_行们.clear()
	_行条们.clear()
	var 会话 := _会话()
	var 上限 := int(会话.get("pet_capacity")) if 会话 != null else _宠物们.size()
	_携带数.text = "%s%d/%d" % [携带数前缀, _宠物们.size(), 上限]
	for 宠v in _宠物们:
		var 宠: Dictionary = 宠v as Dictionary
		var 号 := int(宠.get("unique_id", 0))
		var 行 := Button.new()
		行.name = "宠_%d" % 号
		行.custom_minimum_size = Vector2(宠物列表尺寸.x, 宠物行高)
		行.size = Vector2(宠物列表尺寸.x, 宠物行高)
		行.focus_mode = Control.FOCUS_NONE
		for 状态 in ["normal", "hover", "pressed", "disabled", "focus"]:
			行.add_theme_stylebox_override(状态, _空())
		_列表容器.add_child(行)
		_行们.append(行)

		var 条 := TextureRect.new()
		条.name = "选中条"
		条.texture = load(皮肤表.选中条) as Texture2D
		条.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		条.position = Vector2(2.0, 2.0)
		条.size = Vector2(152.0, 20.0)		# `MSelected_background1` 152×20 @ (2,2)
		条.mouse_filter = Control.MOUSE_FILTER_IGNORE
		条.visible = 号 == _选中号
		行.add_child(条)
		_行条们.append(条)

		# 状态角标：`PetItemRenderer.getIocn:56-71`，附身/出战 19×19 @ (8,2)。
		var 状态图 := ""
		if bool(宠.get("attached", false)):
			状态图 = 附身皮
		elif bool(宠.get("deployed", false)):
			状态图 = 出战皮
		if not 状态图.is_empty() and ResourceLoader.exists(状态图):
			var 角标 := TextureRect.new()
			角标.name = "状态"
			角标.texture = load(状态图) as Texture2D
			角标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			角标.position = Vector2(8.0, 2.0)
			角标.size = Vector2(19.0, 19.0)
			角标.mouse_filter = Control.MOUSE_FILTER_IGNORE
			行.add_child(角标)

		var 名 := Label.new()
		名.name = "名字"
		名.text = 宠物数值.显示名(宠)
		名.position = Vector2(25.0, 2.0)		# `_nameLabel.setPosition(25,2)`、105×20
		名.size = Vector2(105.0, 20.0)
		名.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		名.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var 色 := 宠物数值.品质色_of(int(宠.get("aptitude", 1)),
				宠物数值.是尾兽(int(宠.get("item_id", 0))))
		界面皮肤.configure_label(名, 12, 色)
		行.add_child(名)

		var 级 := Label.new()
		级.name = "等级"
		级.text = "" if int(宠.get("level", 0)) == 0 else str(int(宠.get("level", 0)))
		级.position = Vector2(130.0, 2.0)	# `x = 名字.x + 105`、25×20 居中
		级.size = Vector2(25.0, 20.0)
		级.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		级.mouse_filter = Control.MOUSE_FILTER_IGNORE
		界面皮肤.configure_label(级, 12, 白)
		行.add_child(级)

		行.pressed.connect(_点宠物.bind(号))
		行.mouse_entered.connect(func() -> void: 条.visible = true)
		行.mouse_exited.connect(func() -> void: 条.visible = 号 == _选中号)


func _点宠物(号: int) -> void:
	if 号 == _选中号:
		return
	_选中号 = 号
	for 序 in _行们.size():
		_行条们[序].visible = int(_行们[序].name.trim_prefix("宠_")) == 号
	_刷新选中宠()


func _刷新选中宠() -> void:
	_旧技能 = 0
	_新技能 = 0
	_选中环.visible = false
	(_新格.get_node("图标") as TextureRect).texture = null
	_新格.tooltip_text = ""
	for 格 in _技能格们:
		(格.get_node("图标") as TextureRect).texture = null
		格.tooltip_text = ""
		格.disabled = true
		格.set_meta("skill_id", 0)
		(格.get_node("等级") as Label).text = ""
	for i in _装备格们.size():
		var 格 := _装备格们[i]
		格.icon = null
		var 数量 := 格.get_node_or_null("数量") as Label
		if 数量 != null:
			数量.text = ""
		(格.get_node("槽名") as Label).visible = true
	for 子 in _模型层.get_children():
		_模型层.remove_child(子)
		子.queue_free()
	var 宠 := _找宠(_选中号)
	if 宠.is_empty():
		_宠物文本.text = ""
		return

	# —— 五装备格：图标 / 空槽名 / 资质框 / 悬停提示框 ——
	var 装备列表: Array = 宠.get("equipment", [])
	for i in 装备槽表.size():
		var 格 := _装备格们[i]
		var 部位 := int((装备槽表[i] as Dictionary)["部位"])
		var 已装: Dictionary = {}
		for 装 in 装备列表:
			if int((装 as Dictionary).get("equipment_slot",
					(装 as Dictionary).get("slot_index", 0))) == 部位:
				已装 = 装 as Dictionary
		var 槽名 := 格.get_node("槽名") as Label
		槽名.visible = 已装.is_empty()
		格.disabled = 已装.is_empty()
		if 已装.is_empty():
			格.call("清空品质覆盖层")
			格子提示框.接线(_宿主, self, 格, {})
			continue
		var 号 := String(已装.get("id", 已装.get("item_id", "0")))
		格.icon = 游戏数据.item_icon(int(号)) as Texture2D
		格.disabled = false
		var 品质: Dictionary = {"id": 号}
		if 已装.has("aptitude"):
			品质["aptitude"] = int(已装.get("aptitude", 0))
		格.call("设置品质", 品质, false)
		格子提示框.接线(_宿主, self, 格, 已装)

	# —— 名称/等级行（`selectedPetHandler:269` 的 htmlText，浅蓝标题 + 白值）——
	_宠物文本.text = "[color=#1e90ff]%s [/color][color=#ffffff]%s[/color][color=#1e90ff]　　%s [/color][color=#ffffff]%s[/color]" % [
		名称字, 宠物数值.显示名(宠), 等级字, str(int(宠.get("level", 0)))]

	# —— 宠物立绘（`PetEquipmentPanel.setPetData` → `this.icon = param1.petSkin`）——
	var 形象号 := int(宠.get("face", 0))
	if 形象号 <= 0:
		形象号 = int(宠.get("item_id", 0))
	var 精灵 := preload("res://脚本/角色/原始动画精灵.gd").new()
	if 精灵.configure("pet", str(形象号).pad_zeros(8), "stand"):
		_模型层.add_child(精灵)
		精灵.position = 模型位
	else:
		精灵.free()

	# —— 八技能格（`selectedPetHandler:275-295`）——
	var 技能: Array = 宠.get("skills", [])
	for i in mini(技能.size(), 技能格数):
		var 技: Dictionary = 技能[i] as Dictionary
		var 技号 := int(技.get("id", 0))
		var 等级 := int(技.get("level", 0))
		var 格 := _技能格们[i]
		(格.get_node("图标") as TextureRect).texture = _技能图标(技号)
		格.disabled = false
		格.set_meta("skill_id", 技号)
		格.tooltip_text = _技能提示(技号, 等级)
		(格.get_node("等级") as Label).text = str(等级) if 等级 > 0 else "0"


func _点旧技能(格: Button) -> void:
	var 技号 := int(格.get_meta("skill_id", 0))
	if 技号 <= 0:
		return
	_旧技能 = 技号
	_选中环.position = 格.position - Vector2(3.0, 3.0)	# `SkillCellSelectedGridF` 外扩 3
	_选中环.visible = true


func _点查阅() -> void:
	if _选择窗 != null and is_instance_valid(_选择窗):
		return
	_选择窗 = 选择窗脚本.new() as Control
	_选择窗.name = "宠物技能选择窗"
	add_child(_选择窗)
	_选择窗.connect("选中技能", Callable(self, "_设新技能"))
	_选择窗.connect("关闭了", Callable(self, "_选择窗关了"))
	_选择窗.call("打开")
	# `UIMain2.centerTwoWindow:3159-3185`：选择窗（param1）居中、重置窗放它右边 1px。
	var 舞台 := get_viewport().get_visible_rect().size.x
	var 两窗宽 := 窗宽 * 2.0 + 1.0
	var 选x := float((舞台 - 两窗宽) * 0.5) if 舞台 > 两窗宽 else 0.0
	var 重y := global_position.y
	global_position = Vector2(选x + 窗宽 + 1.0, 重y)
	_选择窗.global_position = Vector2(选x, 重y)


func _选择窗关了() -> void:
	if _选择窗 != null and is_instance_valid(_选择窗):
		_选择窗.queue_free()
	_选择窗 = null


## `setResetSkill:96-103`：把选中的技能号填进「新技能」格（层数/是否学过的标记不显示）。
func _设新技能(技号: int) -> void:
	_新技能 = 技号
	(_新格.get_node("图标") as TextureRect).texture = _技能图标(技号)
	_新格.tooltip_text = _技能提示(技号, 0)


func _点确定() -> void:
	# `resetSkill:69-94` 三条 addNotice 的顺序与原文逐字照抄。
	if _选中号 <= 0:
		_通知(仅九阶提示)
		return
	if _旧技能 <= 0:
		_通知(选旧技能提示)
		return
	if _新技能 <= 0:
		_通知(选新技能提示)
		return
	确认替换.emit(_选中号, _旧技能, _新技能)


func _通知(文本: String) -> void:
	if _宿主 != null and _宿主.has_method("_通知"):
		_宿主.call("_通知", 文本)


func 隐藏() -> void:
	if not visible:
		return
	_接会话信号(false)
	_选择窗关了()
	visible = false
	关闭了.emit()


## `PopUpMananger.centerWindow`：舞台居中（延迟一帧，理由同 `自选礼包窗._居中`）。
func _居中() -> void:
	var 视口 := get_viewport()
	if 视口 == null:
		return
	var 舞台 := 视口.get_visible_rect().size
	set_deferred("global_position", Vector2(
		round((舞台.x - size.x) * 0.5), round((舞台.y - size.y) * 0.5)
	))


## `MButton3.measure():378-390`：`isScale9Grid = true` 且没显式设宽 ⇒ 文字宽 + 6
## （查阅/确定重置两枚都是这一支，见 `initWindow:220-233`）。
func _量钮宽(文: String) -> float:
	var 字 := get_theme_font("font", "Button") as Font
	if 字 == null:
		return 30.0
	return ceilf(字.get_string_size(文, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			get_theme_font_size("font_size", "Button")).x) + 6.0
