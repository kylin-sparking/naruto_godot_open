extends RefCounted
## 「输入型」确认弹 = `MDialog.showInputDialog:244-292` 的移植（好友页的 删除/拉黑/移除/泯恩仇 走它）。
## 从 `功能窗口` 抽出来独立成件：几何门和运行期截图器都要能把它开进**自己的**遮罩里量/拍，
## 留在窗口方法里就非得连带一整扇功能窗口当宿主。
##
## 版式全部来自 AS3 字面：
##   正文 `createTextArea("left")` ⇒ 左对齐、x=14、y=14、宽 = CONTENT_WIDTH(283)−16 = 267（:507-527）
##   输入框 `createInputText` ⇒ x=(302−283)/2=9.5、宽 267、MTextInput2 高 21（:543-550）
##   `line1.y = 文本底+2`、`input.y = 文本底+8`（:263-265）
##   `contentHeight = 输入底+5`、`panelHeight = contentHeight + BOTTOM_HEIGHT(50)`（:275-276）
##   `okBtn.y = cancelBtn.y = panelHeight − 22 − 5 − 8`（:279）
## 好友页调用时把输入框设成 `TextFieldType.DYNAMIC`（只读，只是把名字显示出来让确认）⇒ 只读=true。

const WINDOW_SKIN := preload("res://脚本/界面/窗口/界面皮肤.gd")
## `FamillyPopUpWindow` 那一族的几何与建件（`弹单钮`/`弹双钮` 走它，**不**走本文件的 MDialog 那三档）。
const 家族弹窗脚本 := preload("res://脚本/界面/窗口/家族弹窗.gd")

const 窗宽 := 302.0
const 内容宽 := 283.0
const 间隙 := 8.0
const 钮高 := 22.0
const 底高 := 50.0
const 确定X := 77.0
const 取消X := 186.0
## 挂进 `功能窗口.遮罩` 的那一层要带这一枚标记 —— `功能窗口.有浮层()` 就认它，
## `窗口管理.重排层级()` 据此把"身上有弹窗的那一扇"钉在所有窗口之上
## （原版 `UIMain2.bringMWindowToTop:3693-3712` 给置顶留了上限，窗口永远升不到弹窗之上）。
## ⚠ 键名必须 ASCII：Godot 4 的 metadata 键要求合法标识符，中文键**静默存不进去**。
const 浮层标记 := "overlay_popup"


## 建好并挂进 `遮罩`，返回遮罩层（门要拿它量各件坐标）。
## `最多字数` = 原版 `pane.input.textField.maxChars`（宠物改名传 12），0 = 不限。
static func 弹出(遮罩: Control, 正文: String, 默认值: String, 只读: bool, 回调: Callable, 最多字数: int = 0) -> Control:
	var 遮罩层 := Control.new()
	遮罩层.name = "输入确认框"
	遮罩层.set_meta("mdialog", "input")	
	遮罩层.set_meta(浮层标记, true)
# 同名叠两层时 Godot 会把后一个改名 @Control@N，门只能按标记认
	遮罩层.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩层.mouse_filter = Control.MOUSE_FILTER_STOP
	遮罩层.z_index = 100
	var 暗层 := ColorRect.new()
	暗层.name = "暗层"
	暗层.set_anchors_preset(Control.PRESET_FULL_RECT)
	暗层.color = Color(0, 0, 0, 0.5)
	遮罩层.add_child(暗层)
	var 主体 := Control.new()
	主体.name = "主体"
	主体.size = Vector2(窗宽, 140.0)
	遮罩层.add_child(主体)
	var 外框 := Panel.new()
	外框.name = "外框"
	外框.set_anchors_preset(Control.PRESET_FULL_RECT)
	外框.theme_type_variation = WINDOW_SKIN.皮肤表.变体_小窗口边框
	主体.add_child(外框)
	var 正文件 := RichTextLabel.new()		# 正文带 <br/>（泯恩仇那句两行）⇒ 必须能渲染标记
	正文件.name = "正文"
	正文件.bbcode_enabled = true
	正文件.scroll_active = false
	正文件.position = Vector2(14.0, 14.0)	# MDialog:522-523 bg2(6,6) + CONTENT_GAP
	正文件.size = Vector2(内容宽 - 间隙 * 2.0, 19.0)	# :515 宽 = CONTENT_WIDTH − 16；一行 = 15+4
	正文件.add_theme_font_size_override("normal_font_size", 12)
	正文件.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	正文件.text = 文案转BBCode(正文)
	主体.add_child(正文件)
	var 线Y := 正文件.position.y + 正文件.size.y + 2.0		# :264 line1.y = 文本底 + 2
	var 分隔 := TextureRect.new()
	分隔.name = "分隔线"
	分隔.texture = load("res://素材/界面/原版窗口/通用控件/横向分隔线.png") as Texture2D
	分隔.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	分隔.mouse_filter = Control.MOUSE_FILTER_IGNORE
	分隔.position = Vector2(3.0, 线Y)
	分隔.size = Vector2(287.0, 2.0)
	主体.add_child(分隔)
	var 输入 := LineEdit.new()
	输入.name = "输入框"
	输入.position = Vector2(floorf((窗宽 - 内容宽) / 2.0), 正文件.position.y + 正文件.size.y + 间隙)	# :265 + :548
	输入.size = Vector2(内容宽 - 间隙 * 2.0, 21.0)		# :549 宽 = 267、MTextInput2 高 21
	输入.text = 默认值
	输入.editable = not 只读
	输入.focus_mode = Control.FOCUS_NONE if 只读 else Control.FOCUS_ALL
	输入.add_theme_font_size_override("font_size", 12)
	if 最多字数 > 0:
		输入.max_length = 最多字数		# `PetWindow.as:658` 改名的 `maxChars = 12`
	主体.add_child(输入)
	var 高 := 输入.position.y + 输入.size.y + 5.0 + 底高		# :275-276
	主体.size = Vector2(窗宽, 高)
	主体.position = Vector2(floorf((遮罩.size.x - 窗宽) * 0.5), floorf((遮罩.size.y - 高) * 0.5))
	var 收 := func() -> void:
		遮罩层.queue_free()
	for 项 in [["确定", 确定X, true], ["取消", 取消X, false]]:
		var 钮 := Button.new()
		钮.name = String(项[0])
		钮.text = String(项[0])
		钮.custom_minimum_size = Vector2(70.0, 钮高)
		钮.position = Vector2(float(项[1]), 高 - 钮高 - 13.0)		# :279 panelHeight − h − 5 − 8
		主体.add_child(钮)
		if bool(项[2]):
			钮.pressed.connect(func() -> void:
				收.call()
				回调.call(输入.text))		# :282-292 handler(input.text, data)
		else:
			钮.pressed.connect(func() -> void:
				收.call()
				回调.call(null))			# 取消 → handler(null)（调用方以 null 判"没确认"）
	暗层.gui_input.connect(func(事件: InputEvent) -> void:
		if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
			收.call()
			回调.call(null))
	遮罩.add_child(遮罩层)
	return 遮罩层


## 「消息型」确认弹 = `MDialog.showMessageDialog:170-242`（宠物放生、快捷键窗那两枚二次确认都走它）。
## 与输入型差三处，全是 AS3 字面：
##   正文 `createTextArea()` **默认 center**（输入型传的是 `"left"`，`:259` vs `:197`）；
##   文本高 `setMessage:411` 是 `textHeight + 8`（MLabel 那条是 +4，别混）；
##   `contentHeight = 文本.y + 文本.高`（没有输入框那 `+BORDER_GAP`），
##   且构造 `:328` 把 `line1/line2` 都关掉了 ⇒ **消息型没有分隔线**。
static func 弹消息(遮罩: Control, 正文: String, 回调: Callable) -> Control:
	var 遮罩层 := Control.new()
	遮罩层.name = "消息确认框"
	遮罩层.set_meta("mdialog", "message")
	遮罩层.set_meta(浮层标记, true)
	遮罩层.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩层.mouse_filter = Control.MOUSE_FILTER_STOP
	遮罩层.z_index = 100
	var 暗层 := ColorRect.new()
	暗层.name = "暗层"
	暗层.set_anchors_preset(Control.PRESET_FULL_RECT)
	暗层.color = Color(0, 0, 0, 0.5)
	遮罩层.add_child(暗层)
	var 主体 := Control.new()
	主体.name = "主体"
	主体.size = Vector2(窗宽, 140.0)
	遮罩层.add_child(主体)
	var 外框 := Panel.new()
	外框.name = "外框"
	外框.set_anchors_preset(Control.PRESET_FULL_RECT)
	外框.theme_type_variation = WINDOW_SKIN.皮肤表.变体_小窗口边框
	主体.add_child(外框)
	var 正文件 := RichTextLabel.new()
	正文件.name = "正文"
	正文件.bbcode_enabled = true
	正文件.scroll_active = false
	正文件.position = Vector2(14.0, 14.0)	# bg2(6,6) + CONTENT_GAP
	正文件.add_theme_font_size_override("normal_font_size", 12)
	正文件.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	正文件.text = 文案转BBCode(正文)
	# `setMessage:411` 的 `textHeight` 是 Flash **实测折行后**的高度；原来这里写死一行
	# （15+8=23）—— 快捷键窗那两句单行确认看不出问题，但结印「自动提升」的二次确认有**五行**，
	# 23 高的正文配上 `高 = 14+文本高+50` 的窗 ⇒ 两枚按钮直接压在文字上、下面四行也没地方站。
	# 行数按真实字体在**同一个折行宽**上量墨迹高，高度仍按 Flash 行盒 15 算
	# （Godot 这套 SimSun 单行量出 13，直接拿 13n 会把窗越算越矮 —— 同 `模态确认弹._量行数`）。
	var 文本高 := 15.0 * _量行数(正文件, 内容宽 - 间隙 * 2.0) + 8.0
	正文件.size = Vector2(内容宽 - 间隙 * 2.0, 文本高)
	主体.add_child(正文件)
	var 高 := 正文件.position.y + 文本高 + 底高		# :200-201
	主体.size = Vector2(窗宽, 高)
	主体.position = Vector2(floorf((遮罩.size.x - 窗宽) * 0.5), floorf((遮罩.size.y - 高) * 0.5))
	var 收 := func() -> void:
		遮罩层.queue_free()
	# `handlerCancelParam.push(CANCEL)`（:203）⇒ 取消回调拿到的是 **CANCEL(=2)**，不是 null；
	# 确定回调拿 OK(=1)。调用方按 MDialog.OK 判，所以这里传整数而不是布尔。
	for 项 in [["确定", 确定X, 1], ["取消", 取消X, 2]]:
		var 钮 := Button.new()
		钮.name = String(项[0])
		钮.text = String(项[0])
		钮.custom_minimum_size = Vector2(70.0, 钮高)
		钮.position = Vector2(float(项[1]), 高 - 钮高 - 13.0)		# :207/:219 panelHeight − h − 5 − 8
		主体.add_child(钮)
		var 传参: int = int(项[2])
		钮.pressed.connect(func() -> void:
			收.call()
			回调.call(传参))
	# 点暗层 = 关掉而不回调（showMessageDialog 没有遮罩点击处理）
	暗层.gui_input.connect(func(事件: InputEvent) -> void:
		if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
			收.call())
	遮罩.add_child(遮罩层)
	return 遮罩层


## AS3 的 `<font color>` / `<br>` 折成 BBCode（与量具 `译文为BBCode` 同一套换算）。
static func 文案转BBCode(文: String) -> String:
	return 家族弹窗脚本.文案转BBCode(文)


## 正文实际占几行（`弹消息` 用来定窗高）。
## ⚠️ 拿不到字体时**退回按换行数**估 —— 别让一次量不到把整个确认弹退回一行（那是修前的行为）。
## 实现与家族弹窗族共用一份（`家族弹窗.量行数`）。
static func _量行数(标: RichTextLabel, 折行宽: float) -> int:
	return 家族弹窗脚本.量行数(标, 折行宽)


## 「勾选型」确认弹 = `MDialog.showCheckBoxDialog:77-127`（意志页「召唤导师」走它）。
## 与消息型差四处，全是 AS3 字面：
##   正文同样是 `createTextArea()` 默认 **center**、`setMessage:411` 高 = `textHeight + 8`；
##   多一枚 `createCheckBox`：`checkBox.y = 文本.y + 文本.高 + CONTENT_GAP(8)`、
##     `checkBox.x = (DIALOG_WIDTH − 宽)/2`（`:93-99`），`selected` 用第 2 参；
##   `panelHeight = 勾选.y + 勾选.高 + BOTTOM_HEIGHT(50)`（**:101**，不是 contentHeight+50）；
##   `line2`（`DialogLine` 287@(3,·)）**显形**，`y = 勾选底 + BUTTON_GAP(4)`（`:123-124`）。
## 回调契约（`:107-121`）：确定 → `handler(checkBox.selected)`（**true/false**），
## 取消 → `handler(null)` ⇒ 调用方必须能区分"没选"和"选了不勾"，所以回传 Variant。
## 勾选高 = **19**：`MCheckBox.as:81-82` 的 `_height = upSkin.height`，皮是 19×19。
##   这里原先写 27，是被 Godot `CheckBox` 当时的"自然高"骗了 —— 那个 27 不是引擎死数，
##   是主题里 `CheckBox/hover_pressed` 漏声明、回拿到的兜底盒上下各 4 撑出来的（10-25 已在
##   `原版皮肤表.gd` 补上空盒收回 19）。地板一收，`panelHeight = 勾选.y + 19 + 50` 就回到
##   原版的算法上 ⇒ 弹窗比原来矮 8 像素、分隔线上移 8。判据在 `测试/勾选框几何回归测试.gd`。
static func 弹勾选(遮罩: Control, 正文: String, 勾选文案: String, 初值: bool,
		回调: Callable, 节点名 := "勾选确认框") -> Control:
	const 勾选高 := 19.0			# `MCheckBox.as:81-82` = upSkin 原生高
	var 遮罩层 := Control.new()
	遮罩层.name = 节点名
	遮罩层.set_meta("mdialog", "checkbox")
	遮罩层.set_meta(浮层标记, true)
	遮罩层.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩层.mouse_filter = Control.MOUSE_FILTER_STOP
	遮罩层.z_index = 100
	var 暗层 := ColorRect.new()
	暗层.name = "暗层"
	暗层.set_anchors_preset(Control.PRESET_FULL_RECT)
	暗层.color = Color(0, 0, 0, 0.5)
	遮罩层.add_child(暗层)
	var 主体 := Control.new()
	主体.name = "主体"
	主体.size = Vector2(窗宽, 140.0)
	遮罩层.add_child(主体)
	var 外框 := Panel.new()
	外框.name = "外框"
	外框.set_anchors_preset(Control.PRESET_FULL_RECT)
	外框.theme_type_variation = WINDOW_SKIN.皮肤表.变体_小窗口边框
	主体.add_child(外框)
	var 正文件 := RichTextLabel.new()
	正文件.name = "正文"
	正文件.bbcode_enabled = true
	正文件.scroll_active = false
	正文件.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER	# `createTextArea()` 默认 center
	正文件.position = Vector2(14.0, 14.0)	# bg2(6,6) + CONTENT_GAP(8)
	正文件.add_theme_font_size_override("normal_font_size", 12)
	正文件.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	正文件.text = 文案转BBCode(正文)
	主体.add_child(正文件)
	## `setMessage:411` 高 = `textHeight + 8`，而 `textHeight` = 15·**行数** ⇒ 行数必须现量。
	## 以前这一行写死 `15 + 8`（只算一行）⇒ 两行以上的文案被面板底边裁掉，而勾选行/钮位/窗高
	## 全都跟着往上顶一格（10-24 竞技场那枚三行文案就是这么露出半截的）。
	var 文本高 := 15.0 * float(_量行数(正文件, 内容宽 - 间隙 * 2.0)) + 8.0
	正文件.size = Vector2(内容宽 - 间隙 * 2.0, 文本高)
	var 勾 := CheckBox.new()
	勾.name = "勾选"
	勾.text = 勾选文案
	勾.button_pressed = 初值			# `:94` `checkBox.selected = isSelected`
	勾.focus_mode = Control.FOCUS_NONE
	勾.size = Vector2(内容宽, 勾选高)
	勾.position = Vector2(floorf((窗宽 - 勾.size.x) / 2.0),
			正文件.position.y + 文本高 + 间隙)	# :93 文本底 + CONTENT_GAP
	主体.add_child(勾)
	var 高 := 勾.position.y + 勾选高 + 底高		# :101（勾选底 + BOTTOM_HEIGHT）
	主体.size = Vector2(窗宽, 高)
	主体.position = Vector2(floorf((遮罩.size.x - 窗宽) * 0.5), floorf((遮罩.size.y - 高) * 0.5))
	var 线 := TextureRect.new()		# `line2` = DialogLine 287@(3,·)，原生高 2
	线.name = "分隔线"
	线.texture = load("res://素材/界面/原版窗口/通用控件/横向分隔线.png") as Texture2D
	线.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	线.position = Vector2(3.0, 勾.position.y + 勾选高 + 4.0)	# :124 勾选底 + BUTTON_GAP(4)
	线.size = Vector2(287.0, 2.0)
	主体.add_child(线)
	var 收 := func() -> void:
		遮罩层.queue_free()
	for 项 in [["确定", 确定X, true], ["取消", 取消X, false]]:
		var 钮 := Button.new()
		钮.name = String(项[0])
		钮.text = String(项[0])
		钮.custom_minimum_size = Vector2(70.0, 钮高)
		钮.position = Vector2(float(项[1]), 高 - 钮高 - 13.0)	# :104 panelHeight − h − 5 − 8
		主体.add_child(钮)
		if bool(项[2]):
			钮.pressed.connect(func() -> void:
				收.call()
				回调.call(勾.button_pressed))		# handler(checkBox.selected)
		else:
			钮.pressed.connect(func() -> void:
				收.call()
				回调.call(null))				# handlerCancelParam.push(null)（:106）
	暗层.gui_input.connect(func(事件: InputEvent) -> void:
		if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
			收.call()
			回调.call(null))
	遮罩.add_child(遮罩层)
	return 遮罩层


## 原版 `FamillyPopUpWindow.popUpWindow(正文, p, 回调1, 钮一文字, 回调2, 钮二文字, false, 勾选文字)`
## —— **两颗钮的文字都是调用方给的**（竞技场那一枚是「挑战」/「查看结果」，`PvpPlayerPanel.as:76`）。
## ⚠ 这一档与 `弹单钮` 同族（`家族弹窗.gd`），**不是** `MDialog`；`modal` 传的是 false ⇒ 没有暗层。
## 回调契约保持旧的两支：**第一颗 ⇒ 回调.call(1)**、**第二颗 ⇒ 回调.call(null)**，
## 勾选值由调用方自己回读 `主体/勾选`（`功能窗口.弹出双钮确认` 就是这么接的，别改这一层语义）。
static func 弹双钮(遮罩: Control, 正文: String, 钮一: String, 钮二: String,
		勾选文案: String, 回调: Callable) -> Control:
	return 家族弹窗脚本.弹出(遮罩, "双钮确认框", 正文, 勾选文案, false, 钮一, 钮二,
			func() -> void: 回调.call(1),
			func() -> void: 回调.call(null), false)

## 只留一颗「确定」的家族弹窗 = `FamillyPopUpWindow.popUpWindow(正文, null, null, "", null, "", false)`
## （第 8 参勾选文字给空 ⇒ `updateView:85-89` 那个 `if(param7)` 不成立 ⇒ 复选框**保持不显**；
## 第 7 参 `modal=false` ⇒ 连暗层都没有）再补一刀 `hideCancelButton:164-168`
## （藏掉取消、把确定**重新居中**）。竞技场的「本期排名奖励获得」走的就是这一档
## （`PvpManager.onPk_showPaiHangPrize:98-103`）。
## ⚠ 这一档**不是** `MDialog`，几何在 `家族弹窗.gd`（10-24 之前被接在 `弹勾选` 上、
##   正文盒还写死一行 ⇒ 三行文案被面板底边裁掉）。
static func 弹单钮(遮罩: Control, 正文: String) -> Control:
	return 家族弹窗脚本.弹出(遮罩, "单钮确认框", 正文, "", false,
			"确定", "", Callable(), Callable(), false)
