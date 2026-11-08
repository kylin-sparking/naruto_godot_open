extends RefCounted
## 家族创建窗数据填充（原版 `com/mxw/uifl/controls/familly/FamillyCreateWindow.as`）。
##
## 为什么要有它：创建窗原来是"只有 UI、没有任何逻辑"的一扇 —— 三个真实缺口：
##   ① **创建条件那块是死的**：原版要显示 `getFamillyCreateCfg().item[0]`（= `flag["1"].cost`
##      的 16000022×1）并画出"有没有"的状态，我们这边连填都没填；
##   ② **「检测重名」那颗钮点了没反应**：原版 `nameValidateHandler` →
##      `requestBanghuiCheckBanghuiName`（服务端 `action 21` → 回包 `19:<0|1>`），
##      这条链路客户端**一个字节都没接**；
##   ③ **图形选择翻页没接**：原版按 `ImgType.BangHui.flagStyle` 里"首位 1 且长度 < 5"的键
##      分页，每页把 `_qiItem.setIcon(PicTool.getJiaHuiPic(样式))` 换成对应家徽。
##      我们这边翻页不动、家徽图恒为初始图，创建时也只能发样式 0。
##
## 口径出处：
##   · 创建消耗 `flag["1"].cost`（见 `游戏数据.family_create_cost()`）
##   · 可翻页样式 1000~1019（见 `游戏数据.family_create_styles()`）
##   · 家徽图 `PicTool.getJiaHuiPic(flagStyle)` = `家徽图.取(样式)`
##
## ⚠️ **不要在这里 preload `家族子窗壳.gd`** —— 壳要 preload 本脚本（填充分发那一串），
##    反向再 preload 就是循环依赖、两个脚本一起解析失败。
##    所以对外接口一律**收内容页 `页`**，由 `功能窗口` 去壳里取（它本来就 preload 了壳）。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")
const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")

## 页面上当前选中样式的存放键（ASCII：中文键会被 `set_meta` 静默丢掉）。
## `功能窗口._发创建家族` 就是读它来决定发哪个 flagStyle。
const 样式键 := "guild_create_flag_style"
const 页键 := "guild_create_style_page"
const 接线键 := "guild_create_wired"
const 重名键 := "guild_create_name_ok"

const 足色 := Color("#00ff00")     # `UIConfig.UI_GREEN`，原版创建条件那行用的就是它
const 缺色 := Color("#ff5a5a")


static func 填(页: Control, 宿主: Node) -> void:
	if 页 == null or 宿主 == null or String(页.name) != "家族创建窗":
		return
	_填占位(页, 宿主)
	_填创建条件(页, 宿主)
	_填家徽(页, 宿主)
	_补购买钮(页, 宿主)
	_接线(页, 宿主)


## ── 「购买」钮 ──────────────────────────────────────────────────────────────
##
## ⚠️ 这颗钮**原版 AS3 里没有**：`FamillyCreateWindow.createChildren()` 建完 `_zhuShuCell`
##    就直接 `_createBtn` 了，中间没有购买钮。它是**单机版客户端后加的**（用户给的实机
##    截图里就在族书格下面）。所以它**不在** `开发工具/生成家族子窗.py` 的 SPEC 里 ——
##    为加一颗钮去重跑生成器会把全部家族子窗重刷一遍，风险不值当。
##    这里在开窗时按截图补建，位置与样式都对齐同一套皮（钮底37 三态 + `家族子窗._设态`）。
const 购买钮名 := "钮购买"
const 购买钮皮 := "res://素材/界面/原版窗口/家族/钮底37"
const 购买钮尺寸 := Vector2(44, 22)

static func _补购买钮(页: Control, 宿主: Node) -> void:
	if 页.get_node_or_null(购买钮名) != null:
		return
	var 格 := 页.get_node_or_null("格族书") as Control
	if 格 == null:
		return
	var 钮 := TextureButton.new()
	钮.name = 购买钮名
	钮.focus_mode = Control.FOCUS_NONE
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_SCALE
	钮.texture_normal = load(购买钮皮 + ".png") as Texture2D
	钮.set_meta("skin", 购买钮皮)
	钮.size = 购买钮尺寸
	# 水平居中于族书格、贴其下沿 —— 截图里就是这样（族书格与标题同宽居中）。
	钮.position = Vector2(格.position.x + (格.size.x - 购买钮尺寸.x) * 0.5,
			格.position.y + 格.size.y + 8.0)
	钮.tooltip_text = "购买族之书"
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var 字 := Label.new()
	字.text = "购买"
	字.set_anchors_preset(Control.PRESET_FULL_RECT)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	钮.add_child(字)
	页.add_child(钮)
	# 三态复用页面自己的 `_设态`（`家族子窗.gd`）：亮度档、悬停/按下/禁用的规则与别的钮一致。
	if 页.has_method("_设态"):
		钮.mouse_entered.connect(func() -> void: 页.call("_设态", 钮, 1))
		钮.mouse_exited.connect(func() -> void: 页.call("_设态", 钮, 0))
		钮.button_down.connect(func() -> void: 页.call("_设态", 钮, 2))
		钮.button_up.connect(func() -> void: 页.call("_设态", 钮, 0))
		页.call("_设态", 钮, 0)
	钮.pressed.connect(func() -> void:
		# 走宿主那条统一分发（`家族创建窗:购买`），与其余子窗钮同一个入口。
		if 宿主 != null and 宿主.has_method("_show_guild_action"):
			宿主.call("_show_guild_action", "家族创建窗:购买"))


## ── 输入框占位提示 ─────────────────────────────────────────────────────────
##
## 原版**没有 placeholder 这种东西**：`FamillyCreateWindow.initView()`（`FC:96-117`）把这三句
## 直接写成控件的**文本**，聚焦时清空（`inputFocusInHander`）、失焦且为空时还原
## （`inputFocusOutHander`）。所以"提示文字"其实就是控件文本 —— 取表单时必须把它当空值，
## 否则会把"家族名称2-6个字"当成真家族名发出去。
##
## 真值取自 `en_US$message_properties.as`：`NAME_PROMPT` / `GONGGAO_PROMPT` / `JIAHUI_NAME_PROMPT`。
const 家族名提示 := "家族名称2-6个字"
const 公告提示 := "再次输入公告（200个字）"
const 家徽名提示 := "家徽名称2-6字"
const 提示键 := "guild_create_prompt_wired"

static func _填占位(页: Control, 宿主: Node) -> void:
	var 家族名 := 页.get_node_or_null("输入家族名") as LineEdit
	var 公告 := 页.get_node_or_null("输入文本公告") as TextEdit
	var 家徽名 := 页.get_node_or_null("输入家徽名") as LineEdit
	if 家族名 != null and 家族名.text.strip_edges().is_empty():
		家族名.text = 家族名提示
	if 公告 != null and 公告.text.strip_edges().is_empty():
		公告.text = 公告提示
	if 家徽名 != null and 家徽名.text.strip_edges().is_empty():
		家徽名.text = 家徽名提示
	if 页.has_meta(提示键):
		return
	页.set_meta(提示键, true)
	_接提示(家族名, 家族名提示)
	_接提示(公告, 公告提示)
	_接提示(家徽名, 家徽名提示)


static func _接提示(控件: Control, 提示: String) -> void:
	if 控件 == null:
		return
	if 控件 is LineEdit:
		var 行 := 控件 as LineEdit
		行.focus_entered.connect(func() -> void:
			if 行.text == 提示:
				行.text = "")
		行.focus_exited.connect(func() -> void:
			if 行.text.strip_edges().is_empty():
				行.text = 提示)
	elif 控件 is TextEdit:
		var 块 := 控件 as TextEdit
		块.focus_entered.connect(func() -> void:
			if 块.text == 提示:
				块.text = "")
		块.focus_exited.connect(func() -> void:
			if 块.text.strip_edges().is_empty():
				块.text = 提示)


## 取控件文本，**占位提示算空**。
static func _去提示(控件: Control, 提示: String) -> String:
	if 控件 == null:
		return ""
	var 文 := ""
	if 控件 is LineEdit:
		文 = (控件 as LineEdit).text
	elif 控件 is TextEdit:
		文 = (控件 as TextEdit).text
	文 = 文.strip_edges()
	return "" if 文 == 提示 else 文


## 三个表单字段（**已去掉占位提示**）。协议层一律用它 ——
## 直接读控件文本会把提示语当成真值发出去。
static func 取表单(页: Control) -> Dictionary:
	return {
		"name": _去提示(页.get_node_or_null("输入家族名"), 家族名提示),
		"emblem": _去提示(页.get_node_or_null("输入家徽名"), 家徽名提示),
		"notice": _去提示(页.get_node_or_null("输入文本公告"), 公告提示),
	}


## ── 创建条件（原版 `_qiTiaoJianSkin` 那一栏）───────────────────────────────
## 显示第一项消耗物品的图标与"需要 N 个"，并按背包**实有**数量上色。
static func _填创建条件(页: Control, 宿主: Node) -> void:
	var 消耗 := 游戏数据.family_create_cost()
	var 行: Array = 消耗.get("item", [])
	if 行.is_empty():
		return
	var 项 := 行[0] as Dictionary
	var 物品号 := int(项.get("id", 0))
	var 需要 := int(项.get("count", 1))
	var 名 := 游戏数据.family_material_name(物品号, "族之书")
	var 拥有 := 背包数量(宿主, 物品号)
	var 标签 := 页.get_node_or_null("标签创建条件") as Label
	if 标签 != null:
		# 原版那行的字是 `需要族の书1个`（"の" 是**物品表里的原名**，不是错别字）。
		标签.text = "需要%s%d个" % [名, 需要]
		标签.add_theme_color_override("font_color", 足色 if 拥有 >= 需要 else 缺色)
		var 提示 := "背包中：%d / %d" % [拥有, 需要]
		if 拥有 < 需要:
			# 不够时**就地给购买入口**：点旁边的族书图标即可买（见 `_点族书`）。
			# 原来这里只有一句"不足"，玩家得自己跑去商城找，而在商城里这本又是买不到的
			# （见 `fake_flash_server.handle_cash_shopping` 的分类口径修复）。
			提示 += "\n点右侧族书图标即可购买"
		标签.tooltip_text = 提示
	var 格 := 页.get_node_or_null("格族书") as TextureRect
	if 格 != null:
		var 图 := 游戏数据.item_icon(物品号)
		if 图 != null:
			格.texture = 图
		格.tooltip_text = "%s ×%d（背包 %d）\n点击购买" % [名, 需要, 拥有]
		# 场景里这个格子是 `mouse_filter = 2`(IGNORE)，不接鼠标事件；要能点就得改成 STOP。
		格.mouse_filter = Control.MOUSE_FILTER_STOP
		格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var 回 := _点族书.bind(页, 宿主)
		if not 格.gui_input.is_connected(回):
			格.gui_input.connect(回)


## 点族书图标 = 买一本（原版没有这个入口，是本项目的便利补充：族书不足时不用满地图找商城）。
## 走的是**点券商城**那条既有协议（客户端 `request_cash_shop_buy`），金额/入包全由服务端结算。
## ⚠️ **参数顺序必须是「信号参数在前、bind 的附加参数在后」** —— 上面那行是
## `_点族书.bind(页, 宿主)`：`gui_input` 先发 `事件`，bind 的两个排在它后面。
## 2026-10-12 之前这里写成 `(页, 宿主, 事件)` ⇒ 第 1 个参数拿到的是 Control，
## 一进函数就报 `Cannot convert argument 1 from Object to Object.` ⇒ **点族书图标毫无反应**
## （用户实机日志刷的就是这条）。本工程 2026-10-08 记过同一类坑，这处当时漏了。
static func _点族书(事件: InputEvent, 页: Control, 宿主: Node) -> void:
	if not (事件 is InputEventMouseButton):
		return
	var 按 := 事件 as InputEventMouseButton
	if not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if 宿主.has_method("_发购买族书"):
		宿主.call("_发购买族书")


## ── 图形选择（家徽图案翻页）───────────────────────────────────────────────
static func _填家徽(页: Control, 宿主: Node) -> void:
	var 样式表 := 游戏数据.family_create_styles()
	if 样式表.is_empty():
		return
	var 总 := 样式表.size()
	var 页号 := clampi(int(页.get_meta(页键, 0)), 0, 总 - 1)
	页.set_meta(页键, 页号)
	var 样式 := 样式表[页号]
	页.set_meta(样式键, 样式)
	var 图 := 页.get_node_or_null("格家徽图") as TextureRect
	if 图 != null:
		var 纹 := 家徽图.取(样式)
		if 纹 != null:
			图.texture = 纹
		图.tooltip_text = "家徽样式 %d" % 样式
		# ⚠️⚠️ **按原尺寸居中、不缩放**：预览格在场景里是 40×40，而家徽图是 34×34 ——
		#    `TextureRect` 默认 `stretch_mode = SCALE`，会把 34 **拉到 40**（非整数缩放 ⇒
		#    发糊、颜色也被冲淡，用户 2026-10-11 报"太模糊了、颜色不对"）。
		#    原版 `SimpleItemCell.setIcon`（`:97-107`）是**按原尺寸居中**的，家族页那边
		#    （`家族窗口._画家徽格`）也是这么画的 —— 这里跟它们对齐。
		#    节点原始矩形先存进 meta（重复填充时不会越缩越小）；键必须是 ASCII。
		if not 图.has_meta("cell_rect"):
			图.set_meta("cell_rect", Rect2(图.position, 图.size))
		var 原矩形: Rect2 = 图.get_meta("cell_rect")
		图.size = Vector2.ONE * 家徽图.边长
		图.position = 原矩形.position + (原矩形.size - 图.size) * 0.5
	var 页码 := 页.get_node_or_null("分页短旗选择/页码") as Label
	if 页码 != null:
		页码.text = "%d/%d" % [页号 + 1, 总]
	# ⚠️ 翻页钮**不在这里接线**：它们由页面自己的 `家族子窗._绑` 接成
	#    `_发动作("家族创建窗:上一页"/"下一页")` → 宿主 `_show_guild_action`，
	#    与其余子窗钮走同一条路（见 `功能窗口` 的那两个分支）。
	#    这里原来用 `Callable(静态函数).bind(...)` 自己接 —— 那种绑定在静态上下文里不可靠，
	#    一旦抛错会把后面的 `_补购买钮` 一起吃掉（表现是"购买钮没建出来"）。


## 翻页：到两头就停（原版 `PageComponent` 不环绕）。
static func 翻页(页: Control, 宿主: Node, 步: int) -> void:
	var 样式表 := 游戏数据.family_create_styles()
	if 页 == null or 样式表.is_empty():
		return
	页.set_meta(页键, clampi(int(页.get_meta(页键, 0)) + 步, 0, 样式表.size() - 1))
	_填家徽(页, 宿主)


## ── 接线：检测重名 ────────────────────────────────────────────────────────
static func _接线(页: Control, 宿主: Node) -> void:
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		return
	if 后端.has_signal("guild_name_checked") and not 页.has_meta(接线键):
		页.set_meta(接线键, true)
		家族页回调.挂(页, 后端.guild_name_checked, func(可用: bool) -> void: _重名回应(页, 宿主, 可用))
	# 每次开窗重来：上一扇窗的"名字可用"不能带到这一扇。
	页.set_meta(重名键, false)


static func _重名回应(页: Control, 宿主: Node, 可用: bool) -> void:
	页.set_meta(重名键, 可用)
	if 宿主.has_method("_通知"):
		宿主.call("_通知", "家族名可以使用" if 可用 else "该家族名已被使用，请换一个")


## ── 对外（都收内容页，见文件头"不要循环 preload"那段）───────────────────

## 当前选中的家徽样式。
static func 选中样式(页: Control) -> int:
	return int(页.get_meta(样式键, 0)) if 页 != null else 0


## 上次「检测重名」的结果是不是"可用"。
static func 名字可用(页: Control) -> bool:
	return 页 != null and bool(页.get_meta(重名键, false))


## 改名之后必须重新检测：这里把结果复位。
static func 清重名态(页: Control) -> void:
	if 页 != null:
		页.set_meta(重名键, false)


## 背包里某件物品的权威数量；拿不到后端就返回 0（宁可不放行，也不虚报够用）。
static func 背包数量(宿主: Node, 物品号: int) -> int:
	if 宿主 == null:
		return 0
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
	if 后端 == null or not 后端.has_method("inventory_quantity"):
		return 0
	return int(后端.call("inventory_quantity", 物品号))


## 创建前的全部校验。返回 "" 表示可以发协议，否则返回给玩家看的提示。
## 逐条对应原版 `FamillyCreateWindow.validateInput()` + `creatJiaZhuHandler()`：
##   家族名非空且 ≥2 字、家徽名非空且 ≥2 字（原版两条都判，文案不同）、
##   以及**背包里要有创建材料** —— 后者原版在 `FamillyManager.createFamilly()` 里判
##   （`item[0].count > isBagExistItem(id)` ⇒ 提示 `FAMILLY_MANAGER_SORRY_BUGOU`）。
static func 校验(页: Control, 宿主: Node) -> String:
	if 页 == null:
		return "创建窗没开着"
	# 表单三值一律走 `取表单`：占位提示算空（见 `_去提示` 的说明）。
	var 表单 := 取表单(页)
	var 名 := String(表单.get("name", ""))
	var 徽名 := String(表单.get("emblem", ""))
	if 名.is_empty():
		return "请输入家族名称"
	if 名.length() < 2:
		return "家族名至少 2 个字"
	if 徽名.is_empty():
		return "请输入家徽名称"
	if 徽名.length() < 2:
		return "家徽名至少 2 个字"
	var 消耗 := 游戏数据.family_create_cost()
	var 行: Array = 消耗.get("item", [])
	if not 行.is_empty():
		var 项 := 行[0] as Dictionary
		var 物品号 := int(项.get("id", 0))
		var 需要 := int(项.get("count", 1))
		if 背包数量(宿主, 物品号) < 需要:
			return "很抱歉，您的%s不足，无法创建家族" % 游戏数据.family_material_name(物品号, "族之书")
	return ""
