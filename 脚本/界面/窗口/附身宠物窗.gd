extends RefCounted
## 附身宠物选宠窗（原版 `SuiShenPet`，193×190 小背景）。逐件真值 = `真值/窗口/随身摊位窗.md` §⑩。
##
## 一扇窗两个用途，靠**调用方在开窗前写进宿主变量** `_附身用途` 区分（原版是实例字段 `myType`）：
##   · `"摆摊"`（`TradeWindowEvent.BAITAN_TYPE`）：摊位窗第 1 页点「宠物列表」开它，
##     点「上架」⇒ `StallWindow.selectedPetHandler:236-250` 的六道闸 ⇒ `1296:5`;
##   · `"交易"`（`JIAOYI_TYPE`，默认）：交易窗「宠物列表」开它，点「上架」⇒ `119:18`
##     （`UI.as:1761-1767`：`myType == JIAOYI_TYPE` 才发）。
##
## ⚠ 页是**代码现搭**（同 `二级密码窗`：整页就是一张几何表），没有 `.tscn`。
## ⚠ 列表行复用 `宠物条目.tscn`（153×22），与 `PetItemRenderer` 的 152×20 底图同源。
## ⚠ 不 preload `摊位窗` 之外的控制器 —— `摊位窗` 也不 preload 本脚本（由 `功能窗口` 的
##   `_render_page` 调度），避免脚本互相 preload 成环。

const 条目场景 := preload("res://场景/界面/组件/宠物条目.tscn")
const 宠物数值 := preload("res://脚本/角色/宠物数值.gd")
const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")

const 皮_内容面板 := "res://素材/界面/原版窗口/通用控件/内容面板.png"
const 状态附 := "res://素材/界面/原版窗口/宠物/状态_附.png"
const 状态战斗 := "res://素材/界面/原版窗口/宠物/状态_战斗.png"
const 钮字色 := Color(0.988235, 0.956863, 0.611765, 1)	# MButton3._textColors[up] = #fcf49c

## 页根 = 外框 193 × (190 − 29)（`整框: true` 那一支，容器原点 (0,29)）。
const 页根 := [193.0, 161.0]

## AS3 坐标 − 29。列表底 `SuiShenPet.as:60-64`（6,30,183,126）；列表 `:89-94`（8,34,175,115）；
## 三钮 y = 30+126+6 = 162 ⇒ 133，宽 37（`UIConfig.btn_width_two`），x 依次 6 / 78 / 150。
const 矩形 := {
	"列表底": [6.0, 1.0, 183.0, 126.0],
	"列表": [8.0, 5.0, 175.0, 115.0],
	"查看钮": [6.0, 133.0, 37.0, 22.0],
	"上架钮": [78.0, 133.0, 37.0, 22.0],
	"取消钮": [150.0, 133.0, 37.0, 22.0],
}

## 文案 = 语言表字面量：`SUISHENPET_TITLE` / `MAIL_EXAMINE` /
## `STALL_UPSHELF_WINDOW_UP_SHELF` / `COMMON_CANCEL`。标题由 `窗口尺寸.json` 烘，不在这里重复。
const 文查看 := "查看"
const 文上架 := "上架"
const 文取消 := "取消"


static func _新页(宿主: Node) -> Control:
	var 页 := Control.new()
	页.name = "附身宠物内容"
	页.mouse_filter = Control.MOUSE_FILTER_IGNORE
	页.size = Vector2(float(页根[0]), float(页根[1]))
	宿主._content.add_child(页)
	return 页


static func _底(页: Control, 名: String, 尺: Array) -> NinePatchRect:
	var 面 := NinePatchRect.new()
	面.name = 名
	面.texture = load(皮_内容面板) as Texture2D
	面.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面.position = Vector2(float(尺[0]), float(尺[1]))
	面.size = Vector2(float(尺[2]), float(尺[3]))
	面.patch_margin_left = 11
	面.patch_margin_right = 10
	面.patch_margin_top = 10
	面.patch_margin_bottom = 11
	页.add_child(面)
	return 面


static func _钮(页: Control, 名: String, 尺: Array, 文本: String) -> Button:
	var 钮 := Button.new()
	钮.name = 名
	钮.text = 文本
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.add_theme_font_size_override("font_size", 12)
	钮.add_theme_color_override("font_color", 钮字色)
	钮.custom_minimum_size = Vector2(float(尺[2]), float(尺[3]))
	钮.position = Vector2(float(尺[0]), float(尺[1]))
	钮.size = Vector2(float(尺[2]), float(尺[3]))
	页.add_child(钮)
	return 钮


## `setData():148-178`：一份**新的**宠物清单进来 ⇒ 选中回到第 0 行；一只都没有 ⇒
## 「查看 / 上架」两颗全灰。调用方（开窗前）负责把 `_附身选中` 清 0，这里也兜一次。
static func 渲染(宿主: Node) -> Control:
	var 页 := _新页(宿主)
	_底(页, "列表底", 矩形["列表底"])
	var 用途 := str(宿主.get("_附身用途"))
	var 清单: Array = 我的宠物(宿主)
	# 原版 `list.selectedIndex = 0`：清单一空就是 -1，非空则恒回第 0 行（setData 每次点都重灌）。
	if 清单.is_empty():
		宿主.set("_附身选中", -1)
	elif int(宿主.get("_附身选中")) < 0 or int(宿主.get("_附身选中")) >= 清单.size():
		宿主.set("_附身选中", 0)
	_填列表(宿主, 页, 清单)
	var 查看 := _钮(页, "查看钮", 矩形["查看钮"], 文查看)
	var 上架 := _钮(页, "上架钮", 矩形["上架钮"], 文上架)
	var 取消 := _钮(页, "取消钮", 矩形["取消钮"], 文取消)
	查看.disabled = 清单.is_empty()
	上架.disabled = 清单.is_empty() or (用途 == "交易" and _交易已锁(宿主))
	宿主.set("_附身上架钮", 上架)
	查看.pressed.connect(_点查看.bind(宿主))
	上架.pressed.connect(_点上架.bind(宿主))
	取消.pressed.connect(func() -> void: 宿主.call("close"))
	return 页


## 我的宠物清单（原版 `PetDataManage.getList()`）。没挂会话 ⇒ 空清单（两颗钮灰着）。
static func 我的宠物(宿主: Node) -> Array:
	var 会 = 宿主.get("_session")
	if 会 == null:
		return []
	var 清 = 会.get("pets")
	return 清 if 清 is Array else []


static func _交易已锁(宿主: Node) -> bool:
	var 后 = 宿主.get("_backend")
	if 后 == null:
		return false
	return bool((后.get("authoritative_trade") as Dictionary).get("my_locked", false))


static func _填列表(宿主: Node, 页: Control, 清单: Array) -> void:
	var 滚 := ScrollContainer.new()
	滚.name = "列表"
	滚.position = Vector2(float(矩形["列表"][0]), float(矩形["列表"][1]))
	滚.size = Vector2(float(矩形["列表"][2]), float(矩形["列表"][3]))
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	页.add_child(滚)
	var 列 := VBoxContainer.new()
	列.name = "宠物列"
	列.custom_minimum_size = Vector2(153.0, 0.0)
	列.add_theme_constant_override("separation", 0)
	滚.add_child(列)
	var 选中 := int(宿主.get("_附身选中"))
	var 行们: Array = []
	for i in 清单.size():
		var 宠: Dictionary = 清单[i] as Dictionary
		var 条目 := 条目场景.instantiate() as Button
		条目.name = "宠物条目_%d" % i
		(条目.get_node("名字") as Label).text = 宠物数值.显示名(宠)
		(条目.get_node("名字") as Label).add_theme_color_override("font_color",
			宠物数值.品质色_of(int(宠.get("aptitude", 1)), 宠物数值.是尾兽(int(宠.get("item_id", 0)))))
		(条目.get_node("等级") as Label).text = str(int(宠.get("level", 0)))
		var 状态 := 条目.get_node("状态") as TextureRect
		if bool(宠.get("attached", false)):
			状态.visible = true
			状态.texture = load(状态附)
		elif bool(宠.get("deployed", false)):
			状态.visible = true
			状态.texture = load(状态战斗)
		else:
			状态.visible = false
		var 条 := 条目.get_node("选中条") as Control
		条.visible = i == 选中
		条目.pressed.connect(_点行.bind(宿主, i))
		条目.mouse_entered.connect(func() -> void: 条.visible = true)
		## ⚠ 不能捕获建行那一刻的「是否选中」：那之后玩家可能换了选中行 ⇒ 回到旧行时
		## 会把它的条又亮起来。每次现读宿主那个数。
		条目.mouse_exited.connect(func() -> void: 条.visible = int(宿主.get("_附身选中")) == i)
		列.add_child(条目)
		行们.append(条目)
	宿主.set("_附身行们", 行们)


## `List.ITEM_CLICK`：只换选中行，不发任何帧。
static func _点行(宿主: Node, 序: int) -> void:
	宿主.set("_附身选中", 序)
	var 行们: Array = 宿主.get("_附身行们")
	for i in 行们.size():
		var 件 = 行们[i]
		if is_instance_valid(件):
			((件 as Control).get_node("选中条") as Control).visible = i == 序


static func _当前(宿主: Node) -> Dictionary:
	var 清 := 我的宠物(宿主)
	var 序 := int(宿主.get("_附身选中"))
	if 序 < 0 or 序 >= 清.size():
		return {}
	return 清[序] as Dictionary


## `onClickselectBtn():121-129`：`showPetInfoWindow(getPetData(uid))`。
## 本工程 PetInfoWindow 未移植 ⇒ 开已有的「宠物」页并把它选中到这一只（真值 §⑩ 已登记）。
static func _点查看(宿主: Node) -> void:
	var 宠 := _当前(宿主)
	if 宠.is_empty():
		return
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("取或建窗口"):
		return
	var 窗 = 管理.call("取或建窗口", "宠物")
	窗.set("_selected_pet_id", str(宠.get("id", "")))
	管理.call("打开", "宠物")


## `onClickShangjiaBtn():102-117` 分两支：交易档发 `119:18`，摆摊档交给 `摊位窗.选宠上架`
## （原版是 `SHANGJIA_PET` 事件 ⇒ `StallWindow.selectedPetHandler` 那六道闸）。
## ⚠ **不关本窗**：原版两支都不 hide（摆摊档关上架弹层后还能再选一只；交易档等成交/取消才关）。
static func _点上架(宿主: Node) -> void:
	var 宠 := _当前(宿主)
	if 宠.is_empty():
		return
	if str(宿主.get("_附身用途")) == "交易":
		var 后 = 宿主.get("_backend")
		if 后 == null:
			宿主.call("_show_hint", "交易需要连接服务端")
			return
		后.call("request_trade_set_pet", int(宠.get("unique_id", 0)))
		return
	var 管理: Node = 宿主.get_parent()
	if 管理 == null:
		return
	var 摊: Node = 管理.call("取窗口", "随身摊位") if 管理.has_method("取窗口") else null
	if 摊 == null or not bool(摊.call("已打开")):
		宿主.call("_show_hint", "摊位已关闭，请重新打开随身摊位")
		return
	摊位窗.选宠上架(摊, 宠)


## 交易锁定后 `setShangjiaBtnEnbled(false)`（`TradeWindow2.as:449`）；`setOtherData` 时再放开（`:357`）。
static func 设上架可用(宿主: Node, 可: bool) -> void:
	var 钮 := 宿主.get("_附身上架钮") as Button
	if 钮 != null and is_instance_valid(钮):
		钮.disabled = not 可
