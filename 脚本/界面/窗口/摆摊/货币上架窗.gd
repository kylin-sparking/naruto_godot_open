extends RefCounted
## 货币上架窗（原版 `com.mxw.uifl.controls.stall.UpShelfMoneyWindow`）。
## 逐件真值 = `真值/窗口/随身摊位窗.md` §⑩（入口 `StallWindow.as:648-671`）。
##
## 整页就是一张几何表 ⇒ **代码现搭、不烘场景**（口径同 `摊位列表窗.gd:12-15`、`二级密码窗.gd`）。
## 页根 = 外框 251×168 − 标题栏 29 = **251×139**（`整框: true`，容器原点 (0,29)）。
## `super(251,168,false)`（`:60`）⇒ 第三参 false 与「随身摊位」的 true 相反，但两扇都自己画内容底
## （`background2 = new MYellow_background()`，`:118`）⇒ 尺寸表里 `内容底: false`。
##
## 上行只有一条：`requestStallAddMoneyToStall(_moneyType == 0, 数量, 价格)`（`:94`）
## ⇒ `1296:8:<是否金币>:<金币数>:<元宝数>`（`StallProcessor.as:210-228`）。
## `_moneyType == 0` = 卖**金币**、标价用**元宝**；`== 1` = 卖元宝、标价用金币（`:92-93` 那个换位）。
##
## ⚠ 两枚输入的判式顺序照原文（`:69-91`）：空数量 → 空价格 → 数量 > 余额（金币/元宝各一条）。
##   原文**不判数量 > 0**（"0" 能一路发出去）⇒ 这里也不加客户端闸，服务端那一侧自己拒
##   （`_handle_stall_action` action 8 要求两个数都 > 0）。别把这条"顺手补上"，那不是原版语义。

const 皮_内容面板 := "res://素材/界面/原版窗口/通用控件/内容面板.png"	# MYellow_background，九宫 [11,10,10,11]
const 皮_物品格 := "res://素材/界面/原版窗口/通用控件/物品格.png"		# MGrid_background，九宫 [9,6,9,6]
const 金币皮 := "res://素材/界面/原版窗口/通用控件/金币.png"			# MIconGoldCoinF 17×17
const 元宝皮 := "res://素材/界面/原版窗口/通用控件/元宝币.png"			# MIconGoldYuanBaoF 19×13
const 钮字色 := Color(0.988235, 0.956863, 0.611765, 1)	# MButton3._textColors[up] = #fcf49c
const 橙 := Color("ff9100")								# UIConfig.UI_ORANGE = 16748800
const 白 := Color.WHITE

## 文案（`en_US$message_properties.as` 行号随每行注释）。
const 提示 := "请输入要出售的数量"			# STALLUPSHELFWINDOW_INPUT_SALE_COUNT :1935
const 价格标签 := "出售价格："				# STALLUPSHELFWINDOW_SALE_PRIZE :201
const 币名 := ["游戏金币", "商城元宝"]		# ITMEWINDOW_MONEY :1709 / ITMEWINDOW_YUANBAO :134
const 上架 := "上架"						# STALL_UPSHELF_WINDOW_UP_SHELF :2677
const 数量空 := "您没有输入要出售货币的数量，请您输入后继续进行上架出售操作。"	# NOTICE_1 :3097
const 价格空 := "您没有输入出售价格，请您输入后继续进行上架出售操作。"		# NOTICE_2 :3095
const 金不足 := "您背包中的游戏金币不足，无法上架出售"	# NOTICE_3 :3093
const 宝不足 := "您拥有的商城元宝不足，无法上架出售"	# NOTICE_4 :3092

const 价上限 := 1000000000				# MAX_MONEY（`:28`）

## `页坐标 = AS3 外框坐标 − (0,29)`；算式逐条见真值 §⑩。
## `[x, y, 宽, 高]`。
const 矩形 := {
	"底": [6.0, 10.0, 239.0, 124.0],		# `:273-274`：x=6、y=39、宽=background.width−12=239；高由 `:297` 反推 124
	"提示": [6.0, 15.0, 239.0, 20.0],		# `:275-276` x=底.x、y=底.y+5
	"格": [16.0, 37.0, 40.0, 40.0],			# `:277-278` x=底.x+10、y=提示.y+20+2
	"数量输入": [73.0, 47.0, 95.0, 20.0],	# `:279-282` x=格.x+40+17、y=格.y+10
	"金币单选": [173.0, 41.0, 19.0, 19.0],	# `:283-284` x=量.x+95+5、y=格.y+4
	"元宝单选": [173.0, 64.0, 19.0, 19.0],	# `:285-286` y=金币单选框.y+19+4
	"价格标签": [11.0, 82.0, 60.0, 20.0],	# `:287-288` x=底.x+5、y=格.y+40+5
	"价格输入": [73.0, 82.0, 95.0, 20.0],	# `:289-292` x=标签.x+60+2
	"币种": [170.0, 82.0, 60.0, 20.0],		# `:293-294` x=价格输入.x+95+2
	"上架": [107.0, 107.0, 37.0, 22.0],		# `:295-296` y=价格行.y+20+5；x=6+(239−37)/2
}


static func 页在(宿主: Node) -> Control:
	var 页 = 宿主._货币上架页
	if 页 == null or not is_instance_valid(页) or (页 as Control).get_parent() != 宿主._content:
		return null
	return 页 as Control


static func 渲染(宿主: Node) -> Control:
	var 页 := Control.new()
	页.name = "货币上架内容"
	页.mouse_filter = Control.MOUSE_FILTER_IGNORE
	页.size = Vector2(251.0, 139.0)
	宿主._content.add_child(页)
	宿主._货币上架页 = 页
	## `setData():259-269`：每次开窗都回到「卖金币」、两格清空、币种写「商城元宝」。
	宿主._货币类型 = 0

	_底(页, "底", 矩形["底"], 皮_内容面板, [11, 10, 10, 11])
	_文字(页, "提示", 矩形["提示"], 提示, HORIZONTAL_ALIGNMENT_CENTER, 橙)
	var 格 := _底(页, "格", 矩形["格"], 皮_物品格, [9, 6, 9, 6])
	var 图 := TextureRect.new()
	图.name = "图标"
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_SCALE
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(图)

	var 数 := _输入(页, "数量输入", 矩形["数量输入"], 白)
	数.max_length = 10				# 原文没设 maxChars，长度靠 `MAX_MONEY` 现钳
	数.text_changed.connect(_数变.bind(宿主))
	var 价 := _输入(页, "价格输入", 矩形["价格输入"], 橙)
	价.max_length = 10
	价.text_changed.connect(_价变.bind(宿主))

	_单选(页, "金币单选", 矩形["金币单选"], 币名[0], 宿主, 0)
	_单选(页, "元宝单选", 矩形["元宝单选"], 币名[1], 宿主, 1)
	_文字(页, "价格标签", 矩形["价格标签"], 价格标签, HORIZONTAL_ALIGNMENT_LEFT, 橙)
	_文字(页, "币种", 矩形["币种"], 币名[1], HORIZONTAL_ALIGNMENT_CENTER, 橙)

	var 钮 := _钮(页, "上架", 矩形["上架"], 上架)
	钮.pressed.connect(_点上架.bind(宿主))
	_设货币类型(宿主, 0)
	return 页


## 一枚「单选」= 19×19 的 `复选框选中/未选` + 右侧 21px 处的标签（`MRadioButtonF`）。
## 标签色白（原版 `MRadioButtonF` 文字不带橙）；宽度给到页右沿，`clip_text` 防串行。
static func _单选(页: Control, 名: String, 尺: Array, 文本: String, 宿主: Node, 类型: int) -> void:
	var 框 := TextureRect.new()
	框.name = 名
	框.texture = load("res://素材/界面/原版窗口/通用控件/复选框未选.png") as Texture2D
	框.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	框.stretch_mode = TextureRect.STRETCH_SCALE
	框.mouse_filter = Control.MOUSE_FILTER_STOP
	框.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	框.position = Vector2(float(尺[0]), float(尺[1]))
	框.size = Vector2(float(尺[2]), float(尺[3]))
	框.gui_input.connect(func(事: InputEvent) -> void:
		var 点 := 事 as InputEventMouseButton
		if 点 != null and 点.pressed and 点.button_index == MOUSE_BUTTON_LEFT:
			_点单选(宿主, 类型))
	页.add_child(框)
	var 字 := Label.new()
	字.name = "文字"
	字.text = 文本
	字.position = Vector2(float(尺[0]) + 21.0, float(尺[1]))
	字.size = Vector2(58.0, float(尺[3]))
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_color_override("font_color", 白)
	字.add_theme_font_size_override("font_size", 12)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.clip_text = true
	页.add_child(字)


static func _底(页: Control, 名: String, 尺: Array, 皮: String, 边: Array) -> NinePatchRect:
	var 面 := NinePatchRect.new()
	面.name = 名
	面.texture = load(皮) as Texture2D
	面.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面.position = Vector2(float(尺[0]), float(尺[1]))
	面.size = Vector2(float(尺[2]), float(尺[3]))
	## ⚠ `patch_margin_*` 是 **int**：收到 float 整条建件都中止（工程栽过）。
	面.patch_margin_left = int(边[0])
	面.patch_margin_right = int(边[1])
	面.patch_margin_top = int(边[2])
	面.patch_margin_bottom = int(边[3])
	页.add_child(面)
	return 面


static func _文字(页: Control, 名: String, 尺: Array, 文本: String, 对齐: int, 色: Color) -> Label:
	var 字 := Label.new()
	字.name = 名
	字.text = 文本
	字.position = Vector2(float(尺[0]), float(尺[1]))
	字.size = Vector2(float(尺[2]), float(尺[3]))
	字.horizontal_alignment = 对齐
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", 色)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	页.add_child(字)
	return 字


## 输入：工程主题已把 `输入框.png` 挂在 LineEdit 上 ⇒ 不再另画底（同 `二级密码窗._输入`）。
## 原文两格都是**居中**（`_loc1_.align = CENTER`，`:134-135`）。
static func _输入(页: Control, 名: String, 尺: Array, 色: Color) -> LineEdit:
	var 框 := LineEdit.new()
	框.name = 名
	框.position = Vector2(float(尺[0]), float(尺[1]))
	框.size = Vector2(float(尺[2]), float(尺[3]))
	框.alignment = HORIZONTAL_ALIGNMENT_CENTER
	框.add_theme_font_size_override("font_size", 12)
	框.add_theme_color_override("font_color", 色)
	页.add_child(框)
	return 框


static func _钮(页: Control, 名: String, 尺: Array, 文本: String) -> Button:
	var 钮 := Button.new()
	钮.name = 名
	钮.text = 文本
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.add_theme_font_size_override("font_size", 12)
	钮.add_theme_color_override("font_color", 钮字色)
	## `custom_minimum_size` 必须给到 37：默认钉的是 MButtonF 原生 57 宽。
	钮.custom_minimum_size = Vector2(float(尺[2]), float(尺[3]))
	钮.position = Vector2(float(尺[0]), float(尺[1]))
	钮.size = Vector2(float(尺[2]), float(尺[3]))
	页.add_child(钮)
	return 钮


## `onClickRadioBtn():240-257`：点已选中的那枚什么都不做；换档才改币种标签、图标，并**清空两格**。
static func _点单选(宿主: Node, 类型: int) -> void:
	if int(宿主._货币类型) == 类型:
		return
	_设货币类型(宿主, 类型)
	var 页 := 页在(宿主)
	if 页 == null:
		return
	(页.get_node("数量输入") as LineEdit).text = ""
	(页.get_node("价格输入") as LineEdit).text = ""


## `setMoneyTypeLableText():198-208` + `setItemIcon():98-114` 两条一起做。
## 卖金币 ⇒ 币种列写「商城元宝」、格子里画金币；卖元宝 ⇒ 反过来。
static func _设货币类型(宿主: Node, 类型: int) -> void:
	宿主._货币类型 = 类型
	var 页 := 页在(宿主)
	if 页 == null:
		return
	(页.get_node("币种") as Label).text = 币名[1] if 类型 == 0 else 币名[0]
	(页.get_node("金币单选") as TextureRect).texture = \
			load("res://素材/界面/原版窗口/通用控件/复选框选中.png") as Texture2D \
			if 类型 == 0 else load("res://素材/界面/原版窗口/通用控件/复选框未选.png") as Texture2D
	(页.get_node("元宝单选") as TextureRect).texture = \
			load("res://素材/界面/原版窗口/通用控件/复选框选中.png") as Texture2D \
			if 类型 == 1 else load("res://素材/界面/原版窗口/通用控件/复选框未选.png") as Texture2D
	var 图 := 页.get_node("格/图标") as TextureRect
	图.texture = load(金币皮) as Texture2D if 类型 == 0 else load(元宝皮) as Texture2D
	## 原版 `:111-112` 按 34×34 符号居中；本工程那两枚币图是 17×17 / 19×13 ⇒ 按自己的尺寸居中。
	var 寸 := 图.texture.get_size()
	图.position = Vector2(roundf((40.0 - 寸.x) / 2.0), roundf((40.0 - 寸.y) / 2.0))
	图.size = 寸


## `onChangeSaleCount():182-196`：先按 `MAX_MONEY` 钳，再按当前币种的余额钳。
## 原文 `Number("")` = 0 ⇒ 空串原样留着（不会被打成 "0"）；只有**超出**时才回写。
static func _数变(宿主: Node, 词: String) -> void:
	var 页 := 页在(宿主)
	if 页 == null:
		return
	var 框 := 页.get_node("数量输入") as LineEdit
	var 净 := _只留数字(框, 词)
	var 值 := 净.to_int()
	if 值 > 价上限:
		值 = 价上限
	var 余 := _余额(宿主, int(宿主._货币类型))
	if 值 > 余:
		值 = 余
	if 值 != 净.to_int():
		框.text = str(值)
		框.caret_column = 框.text.length()


## `onChangeSalePrize():210-217`：只按 `MAX_MONEY` 钳（余额那一侧不钳 —— 价格本来就不受余额限制）。
static func _价变(宿主: Node, 词: String) -> void:
	var 页 := 页在(宿主)
	if 页 == null:
		return
	var 框 := 页.get_node("价格输入") as LineEdit
	var 净 := _只留数字(框, 词)
	var 值 := mini(净.to_int(), 价上限)
	if 值 != 净.to_int():
		框.text = str(值)
		框.caret_column = 框.text.length()


## `restrict = "0123456789"` 的移植（同 `拆分窗口.gd:61-68` 那一族）。
static func _只留数字(框: LineEdit, 词: String) -> String:
	var 留 := ""
	for 字 in 词:
		if 字 >= "0" and 字 <= "9":
			留 += 字
	if 留 != 词:
		框.text = 留
		框.caret_column = 留.length()
	return 留


## 余额：`_moneyType == 0` 比 `cocoNuts`（金币）、否则比 `cashMoney`（元宝）。
## 取不到（没连服务端）按 0 算 ⇒ 数量一律被钳成 0，点「上架」会先弹「数量为空」——
## 与原版未登录时 `API.dataCenter` 那两个数恒 0 的表现一致。
static func _余额(宿主: Node, 类型: int) -> int:
	var 后 = 宿主._backend
	if 后 == null:
		return 0
	var 账: Dictionary = 后.get("authoritative_stats") as Dictionary
	return int(账.get("money" if 类型 == 0 else "cash", 0))


## `onClickUpshelfBtn():67-96`：四条判式按序，过了才发 `1296:8:` 并**自己关窗**（`:95`）。
static func _点上架(宿主: Node) -> void:
	var 页 := 页在(宿主)
	if 页 == null:
		return
	var 数文 := (页.get_node("数量输入") as LineEdit).text
	var 价文 := (页.get_node("价格输入") as LineEdit).text
	if 数文.is_empty():
		宿主._通知(数量空)
		return
	if 价文.is_empty():
		宿主._通知(价格空)
		return
	var 类型 := int(宿主._货币类型)
	if 数文.to_int() > _余额(宿主, 类型):
		宿主._通知(金不足 if 类型 == 0 else 宝不足)
		return
	var 后 = 宿主._backend
	if 后 == null or not bool(后.call("request_stall_add_money", 类型 == 0,
			数文.to_int(), 价文.to_int())):
		宿主._show_hint("货币上架需要连接服务端")
		return
	宿主.close()
