extends RefCounted

## 左侧队伍面板 = 原版 `com/mxw/uifl/controls/troop/TroopHPPane`（`UIConfig.TROOP_HP_PANE_F`）。
## 它是挂在 **HUD 层**的浮窗，不是队伍页里的一块 ⇒ 形态与 `竞技场结算弹.gd` 一致（代码建件、
## 位置尺寸全按 AS3 字面量）。逐句转写，每条都注了行号。
## ⚠ 不用内部类：Godot 的内部类看不到外层 `const`（条宽/色白/职业表…会全查不到），
##   所以格子的每一件都由这些 `static func` 直接摆，状态存在节点自己的 meta 上（键必须是 ASCII）。
##
## 几何真值（`真值/窗口/组队.md` §⑨-D）：屏幕 (0,108)（`:324-327`）；宽 = titleBar 宽 = **164**
## （`:367`/`:456-459`）；标题条 164×22（MainLib cid 803）；标题字「组队」色 **#B5BDD0** 居中粗体
## （`:57-61`，11910608 换算别手抖）；折叠钮 18×18 摆 (144,2)，初值 selected=true（`:370-373`/`:65`），
## 660 内 upSkin=599 加号 / selectedUpSkin=603 减号 ⇒ 展开画减号；一格 45
## （`:27`）；列表容器 y=22（`:71`）；格天然 **164×45**：头像盒 (0,0) 46×45、血条 (42,17) 110×12、
## 蓝条 (42,29) 110×12、等级盒 (0,27) 46×18 居中 12px #FF9100（824 内 cid 823）、
## 名字墨迹 (47,4) 白色（MainLib cid 824 + `:40-48`）；
## 队长星 x = 42+110+1、y = 17 + ((12+12−17)>>1)（`:141-149`）。
## ★ `filterMyself:174-187` ⇒ **面板里没有自己**。
## ★ 灰化条件与成员格不同：`!isInSameMap || !isOnline`（`:113`/`:120`）。
## ★ 只在「成员 > 1 且没勾隐藏」时出现（`UI.as:2116-2133`）；数据空 ⇒ 自己从父上摘掉（`:144-151`）。
## ★ 血蓝**只由 203 驱动**：`上成员()` 里原版只调 updateLevel/updateMap/updateStatus 三个，
##   不重发血蓝 ⇒ 这边同样不重发。

const 职业表 := preload("res://脚本/单例/职业.gd")
const 灰度着色 := preload("res://脚本/界面/组件/禁用灰度.gdshader")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const 菜单场景 := preload("res://场景/界面/组件/物品菜单.tscn")
const 通用 := "res://素材/界面/原版窗口/通用控件/"
const 皮目录 := "res://素材/界面/原版窗口/组队/"

const 格高 := 45
const 格宽 := 164
const 面板宽 := 164
const 标题高 := 22
const 屏x := 0.0
const 屏y := 108.0
const 条x := 42.0
const 条宽 := 110.0
const 条高 := 12.0
const 血y := 17.0
const 蓝y := 29.0
const 名x := 47.0
const 名y := 2.0
const 级x := 0.0
const 级y := 28.0
const 级宽 := 46.0
const 头像宽 := 46.0
const 头像高 := 45.0
const 标题色 := Color(0.709804, 0.741176, 0.815686)	# 11910608 = #B5BDD0（:58，别按 #B5B5F0 猜）
const 白 := Color(1, 1, 1)
const 橙 := Color(1.0, 0.568627, 0.0)		# UI_ORANGE 16748800 = #FF9100（等级字）
const 灰化 := Color(0.42, 0.42, 0.42)

## 格菜单（`TroopHPPane.as:75-78`）：`MPopupMenu(六项, 50)` 定宽 50 + `Timer(250,1)` 单次。
## 文案取值同 CN：密语/查看/交友/交易/看摊/赠花；50 是**底宽**，控件整宽 = 54（+4）。
const 菜单宽 := 50.0
const 选择延迟 := 0.25
const 菜单项名 := ["密语", "查看", "交友", "交易", "看摊", "赠花"]

static var 面板: Control = null
static var 宿主: Node = null
static var 我号 := -1
static var 展开 := true
static var _灰度材质: ShaderMaterial = null
static var _菜单: Control = null
static var _计时: Timer = null
static var _选中行: Dictionary = {}
static var _弹点 := Vector2.ZERO


static func 加字(父: Control, 基: String, 文: String, 位置: Vector2, 尺寸: Vector2,
		色: Color, 对齐: int, 粗: bool) -> Label:
	## 原版这三处字都是「本色字 + 黑 GlowFilter」，标题还多一个 bold（:57-61 / :49 / MGlowLabel）。
	## 黑晕不用自己加：工程主题 `Label/constants/outline_size = 2` + 黑 outline 就是那圈光晕的口径。
	## ⚠ 本色层**不许**再叠自己的 outline 覆盖、字号必须 12：宋体内嵌点阵只到 12px，
	##   14px 会退轮廓渲染 ⇒ 发虚（用户 2026-10-25 打回"等级清晰度不对"的真凶）。
	## 粗体 = 再叠一份右移 1px 的同色 Label（Flash 对宋体的合成粗体就是这个形状）。
	var 前 := Label.new()
	前.name = 基
	前.position = 位置
	前.size = 尺寸
	前.text = 文
	前.horizontal_alignment = 对齐
	前.add_theme_color_override("font_color", 色)
	前.add_theme_font_size_override("font_size", 12)
	前.mouse_filter = Control.MOUSE_FILTER_IGNORE
	父.add_child(前)
	if 粗:
		## Flash 对宋体的合成粗体 = 同一字形右移 1px 再画一遍（竖笔 1px→2px、横笔不变），
		## 与实机字形逐行对过：叠 +2 会出现 3px 的糊块，原版没有。
		var 叠 := Label.new()
		叠.name = 基 + "粗1"
		叠.position = 位置 + Vector2(1, 0)
		叠.size = 尺寸
		叠.text = 文
		叠.horizontal_alignment = 对齐
		叠.add_theme_color_override("font_color", 色)
		叠.add_theme_font_size_override("font_size", 12)
		叠.mouse_filter = Control.MOUSE_FILTER_IGNORE
		父.add_child(叠)
	return 前


static func 设文(父: Node, 基: String, 文: String) -> void:
	## 粗体是叠出来的第二份 Label ⇒ 换文字时两层必须一起改，否则留下旧字影。
	for 尾 in ["", "粗1"]:
		var 件 := 父.get_node_or_null(基 + 尾)
		if 件 is Label:
			(件 as Label).text = 文


static func 灰度材质() -> ShaderMaterial:
	## 原版 `Style.getDisableFilter()` = ColorMatrix 灰度（不是调暗）。
	if _灰度材质 == null:
		_灰度材质 = ShaderMaterial.new()
		_灰度材质.shader = 灰度着色
	return _灰度材质


static func 建(主: Node, 层: Node, 自己号: int) -> void:
	## `自己号` 由调用方给（`队伍窗.自己号` 是从 `player_stats.id` 取的、已经在用）；
	## **不许**在这边再猜一次键名 —— 猜错就是 `filterMyself` 静默失效（面板里出现自己）。
	宿主 = 主
	我号 = 自己号
	拆()
	展开 = true
	面板 = Control.new()
	面板.name = "原版队伍面板"
	面板.position = Vector2(屏x, 屏y)
	面板.custom_minimum_size = Vector2(面板宽, 标题高)
	面板.size = Vector2(面板宽, 标题高)
	层.add_child(面板)
	## 标题条 = 原版元件 `TroopHPPaneTitleSkinF`（MainLib 符号 803，天然 164×22）。
	## 以前用 `StyleBoxFlat` 铺一块纯深色 ⇒ 实机图 3/4 与图 1/2 的金属条完全不同。
	var 条 := TextureRect.new()
	条.name = "标题条"
	条.position = Vector2.ZERO
	条.size = Vector2(面板宽, 标题高)
	var 条路 := 皮目录 + "面板标题条.png"
	if ResourceLoader.exists(条路):
		条.texture = load(条路)
	条.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	条.stretch_mode = TextureRect.STRETCH_SCALE
	条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面板.add_child(条)
	## 标题字 = MGlowLabel（:374-377）+ TextFormat（:57-62）：#B5BDD0 居中 **bold** + 黑 GlowFilter(blur3,strength6)。
	## 实机量得原版两字墨迹 28 宽、非粗只有 23 ⇒ 粗体那层必须叠。
	加字(面板, "标题", "组队", Vector2(0, 3), Vector2(面板宽, 16), 标题色, HORIZONTAL_ALIGNMENT_CENTER, true)
	## 折叠钮 = 原版 `BranchButton`（MainLib 符号 660：upSkin=599 加号 / selectedUpSkin=603 减号）。
	## 初值 selected=true（:65）⇒ 展开态画**减号**；以前把 660 整枚导出 ⇒ 加号减号叠成"÷"，
	## 且两态不换皮（用户 2026-10-25 打回"收放按钮不对"）。原版是 MButton3 ⇒ 悬停 +30 / 按下 −40 预烘。
	var 折 := TextureButton.new()
	折.name = "折叠钮"
	折.position = Vector2(144, 2)
	折.size = Vector2(18, 18)
	折.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	折皮(折)
	折.mouse_entered.connect(_折悬停.bind(折))
	折.mouse_exited.connect(_折回up.bind(折))
	折.button_down.connect(_折按下.bind(折))
	折.button_up.connect(_折回up.bind(折))
	折.pressed.connect(_点折叠)
	面板.add_child(折)
	var 列 := Control.new()
	列.name = "列表"
	列.position = Vector2(0, 标题高)
	列.size = Vector2(面板宽, 0)
	列.visible = 展开
	面板.add_child(列)
	## 格菜单照原版挂在**面板**上（`:137 addChild(this._popupMenu)`）⇒ 弹点是面板局部坐标。
	## 菜单实例常驻、只切 visible；原版那种"点菜单外任意处就销毁"这一版没有全局接收者，
	## 收起时机 = 选中一项 / 折叠面板 / 拆面板（与背包页那枚菜单同一口径）。
	_菜单 = 菜单场景.instantiate() as Control
	_菜单.name = "队伍菜单"
	_菜单.visible = false
	面板.add_child(_菜单)
	_菜单.connect("选择了", _选菜单)
	## `:77 new Timer(250,1)`：单次、每次点击 reset+start；到点（`onTimerHand:135-141`）才挂菜单。
	_计时 = Timer.new()
	_计时.name = "选择计时"
	_计时.wait_time = 选择延迟
	_计时.one_shot = true
	面板.add_child(_计时)
	_计时.timeout.connect(_弹菜单)
	_选中行 = {}


static func 折皮(折: TextureButton) -> void:
	## 展开（selected=true）⇒ 603 减号族；收起 ⇒ 599 加号族。
	## 三档一律换 `texture_normal`，**不填 hover/pressed 槽**：Godot 松手后只要指针还在钮上就回
	## hover，而原版 `mouseUpHandler`（MButton3.as:103-108）回的是 UP —— 不移出就不再亮。
	_折态(折, 0)


static func _折态(折: TextureButton, 态: int) -> void:
	var 基 := "面板折叠钮_展开" if 展开 else "面板折叠钮"
	var 尾: String = [".png", "_悬停.png", "_按下.png"][态]
	var 路 := 皮目录 + 基 + 尾
	折.texture_normal = load(路) if ResourceLoader.exists(路) else null
	折.texture_hover = null
	折.texture_pressed = null


static func _折悬停(折: TextureButton) -> void:
	_折态(折, 1)


static func _折按下(折: TextureButton) -> void:
	_折态(折, 2)


static func _折回up(折: TextureButton) -> void:
	_折态(折, 0)


static func 拆() -> void:
	if 面板 != null and is_instance_valid(面板):
		面板.queue_free()
	面板 = null
	_菜单 = null
	_计时 = null
	_选中行 = {}


static func _点折叠() -> void:
	## `__expend:442-454`：selected 取反 ⇒ 列表 visible 跟着走 ⇒ 高 = 标题 或 标题+列表。
	## 换态同时换皮：展开=603 减号、收起=599 加号（`selectedUpSkin` 非空，两态**不同图**）。
	展开 = not 展开
	if 面板 == null or not is_instance_valid(面板):
		return
	折皮(面板.get_node("折叠钮") as TextureButton)
	(面板.get_node("列表") as Control).visible = 展开
	if not 展开:
		收起菜单()
	设高()


static func 收起菜单() -> void:
	if _计时 != null and is_instance_valid(_计时):
		_计时.stop()
	_选中行 = {}
	if _菜单 != null and is_instance_valid(_菜单):
		_菜单.call("收起")


static func 上成员(名单: Array) -> void:
	## `setData:226-283` 的两条路：面板原本没格 ⇒ 全建；原本有 ⇒ 删多的、建缺的、其余增量。
	## ★ 这里**不动血蓝**（见文件头最后一条 ★）。
	if 面板 == null or not is_instance_valid(面板):
		return
	var 新: Array = 滤掉自己(名单)
	var 列: Control = 面板.get_node("列表") as Control
	var 旧: Array = 现有号()
	var 新号: Array = []
	for 行 in 新:
		新号.append(int((行 as Dictionary).get("id", 0)))
	for 号 in 旧:
		if 新号.find(号) == -1:
			删格(号)
	if 旧.is_empty():
		for i in 新.size():
			建格(新[i], i)
	else:
		for i in 新.size():
			var 行: Dictionary = 新[i]
			var 号 := int(行.get("id", 0))
			if 旧.find(号) == -1:
				建格(行, 旧.size() + 面板内格数())
			var 格 := 找格(号)
			if 格 != null:
				格.set_meta("row", 行)
				改等级(号, int(行.get("level", 0)))
				改图(号, int(行.get("map_id", 0)))
				改状态(号, bool(行.get("在同图", false)))
				## 全量状态帧里队长可能已经换人（例如队长退队/重新组队）⇒ 旧星必须摘掉。
				## 以前这里只改等级/地图/灰度，队长星只在 `changeTroopCaptain` 那条增量帧里换。
				if bool(行.get("队长", false)):
					加星(格 as Button)
				else:
					摘星(格 as Button)
	设高()


static func 面板内格数() -> int:
	var 列: Control = 面板.get_node("列表") as Control
	return 列.get_child_count()


static func 现有号() -> Array:
	var 出: Array = []
	if 面板 == null or not is_instance_valid(面板):
		return 出
	var 列: Control = 面板.get_node("列表") as Control
	for c in 列.get_children():
		出.append(int(c.get_meta("cid")))
	return 出


static func 滤掉自己(名单: Array) -> Array:
	## `filterMyself:174-187`
	var 出: Array = []
	for 行 in 名单:
		if int((行 as Dictionary).get("id", -1)) != 我号:
			出.append(行)
	return 出


static func 找格(号: int) -> Node:
	if 面板 == null or not is_instance_valid(面板):
		return null
	var 列: Control = 面板.get_node("列表") as Control
	for c in 列.get_children():
		if int(c.get_meta("cid")) == 号:
			return c
	return null


static func 建格(行: Dictionary, 序: int) -> Button:
	var 格 := Button.new()
	格.name = "队伍格%s" % str(int(行.get("id", 0)))
	格.flat = true
	格.custom_minimum_size = Vector2(格宽, 格高)
	格.size = Vector2(格宽, 格高)
	格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND	# :47 buttonMode
	格.set_meta("cid", int(行.get("id", 0)))
	格.set_meta("row", 行)
	格.pressed.connect(_点格.bind(int(行.get("id", 0))))
	## 名字底板 = 原版 `TroopHPPaneCellF` 的 d1 cid **805**（天然 137×17，左侧凹口正好扣住头像圆环）。
	## 模板匹配在 824 里的位置 = (27,0)；格子的可见宽度其实是 **164**（不是 152）。
	## 805 原图在格内 (27,0) 宽 137；但头像圆环 (0..46) 会露出底板左侧（透明角），
	## 原版看到的是**从头像右缘 46 起**的 118px 那一段 ⇒ 用裁好的可见段，避免头像上压一条灰带。
	var 板 := TextureRect.new()
	板.name = "名字底板"
	板.position = Vector2(46, 0)
	板.size = Vector2(118, 17)
	var 板路 := 皮目录 + "面板名字底板_可见.png"
	if ResourceLoader.exists(板路):
		板.texture = load(板路)
	板.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	板.stretch_mode = TextureRect.STRETCH_KEEP
	板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(板)
	## 头像框 = 原版 `portraitBg`（cid **808**，天然 46×45 铜环）。
	## 以前用主题 `Panel` ⇒ 实机是一个棕色圆角方块（用户 2026-10-25 图2 打回）。
	var 盒 := Control.new()
	盒.name = "头像盒"
	盒.position = Vector2.ZERO
	盒.size = Vector2(头像宽, 头像高)
	盒.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(盒)
	var 框 := TextureRect.new()
	框.name = "头像框"
	框.position = Vector2.ZERO
	框.size = Vector2(头像宽, 头像高)
	var 框路 := 皮目录 + "面板头像框.png"
	if ResourceLoader.exists(框路):
		框.texture = load(框路)
	框.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	框.stretch_mode = TextureRect.STRETCH_KEEP
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	盒.add_child(框)
	var 图 := TextureRect.new()
	图.name = "头像"
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_SCALE
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	盒.add_child(图)
	加槽(格, "血槽", "血条底", 条x, 血y)
	加填充(格, "血罩", "面板血条", 条x, 血y)
	加槽(格, "蓝槽", "经验条槽", 条x, 蓝y)
	加填充(格, "蓝罩", "面板蓝条", 条x, 蓝y)
	## 原版 `nameText` = MGlowLabel：setPosition(45,−2) 后 y+=1（:40-48）；Flash TextField 另有 2px
	## 内边距 ⇒ **墨迹**落在 (47, 格内4)（用户 2026-10-25 打回"名字坐标不对"后按实机校准）。
	## 白字 + 黑 GlowFilter(blur3,strength6) ⇒ 光晕由 加字 的晕层给。
	加字(格, "名字", "", Vector2(名x, 名y), Vector2(110, 16), 白, HORIZONTAL_ALIGNMENT_LEFT, false)
	## 原版 levelText = 824 内 cid 823 的 DefineEditText：placement (2,29) + bounds(−2..44, −2..16)
	## ⇒ 盒 (0,27)~(46,45)、align=center、12px SimSun、#FF9100、黑 GlowFilter(blur2,strength10)。
	## 控件 y 取 28 = 盒顶 27 + 1（Godot 居中行高与 Flash 差 1px，按实机墨迹 53..60 校准）。
	## ⚠ 字号必须 12：宋体内嵌点阵只到 12px，14px 退轮廓渲染 ⇒ 发虚（用户打回"清晰度不对"）。
	加字(格, "等级", "", Vector2(级x, 级y), Vector2(级宽, 18), 橙, HORIZONTAL_ALIGNMENT_CENTER, false)
	(面板.get_node("列表") as Control).add_child(格)
	格.position = Vector2(0, 序 * 格高)
	重画(格)
	## 建格的这一次**不碰血蓝**：原版建格走 `data = param1` 的 setter（`:86-115`）里确实有
	## `hpBar.setData(...)` ⇒ 首次出现是有血蓝的。这边同样在 重画() 里按行里的 hp/maxHp 画一次，
	## 但**后续上成员() 不再动它**（只有 203 动）。
	return 格


static func 加槽(父: Control, 名: String, 图名: String, x: float, y: float) -> void:
	var 条 := TextureRect.new()
	条.name = 名
	条.position = Vector2(x, y)
	条.size = Vector2(条宽, 条高)
	var 路 := 通用 + 图名 + ".png"
	if ResourceLoader.exists(路):
		条.texture = load(路)
	条.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	条.stretch_mode = TextureRect.STRETCH_SCALE
	条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	父.add_child(条)


static func 加填充(父: Control, 名: String, 皮名: String, x: float, y: float) -> Control:
	## 原版 MBar = barBg(槽) + bar(整条填充) + maskMc(矩形遮罩) ⇒ 血蓝是按比例**裁**出来的，
	## 不是把整条拉伸。这里用 `clip_contents` 子容器复刻：里面永远是 110×12 的原图，只裁宽。
	var 罩 := Control.new()
	罩.name = 名
	罩.position = Vector2(x, y)
	罩.size = Vector2(条宽, 条高)
	罩.clip_contents = true
	罩.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 图 := TextureRect.new()
	图.name = "填充"
	图.position = Vector2.ZERO
	图.size = Vector2(条宽, 条高)
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 路 := 皮目录 + 皮名 + ".png"
	if ResourceLoader.exists(路):
		图.texture = load(路)
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP
	罩.add_child(图)
	父.add_child(罩)
	return 罩


static func 重画(格: Button) -> void:
	## 对应原版 `set data(param1)`（`:86-115`）：头像 → 名字 → 等级 → 图 → 队长星 → 灰化 → tooltip。
	## 血蓝只在**行里带得到 hp 时**画一次（原版第一次 setData 就是这个条件）。
	var 行: Dictionary = 格.get_meta("row")
	var 盒: Control = 格.get_node("头像盒") as Control
	var 图: TextureRect = 盒.get_node("头像") as TextureRect
	var 脸 := int(行.get("face", 0))
	图.visible = 脸 > 0
	if 脸 > 0:
		图.texture = OriginalSprite.portrait("character", 角色造型.造型号(脸, int(行.get("gender", 1))))
		图.size = Vector2(头像宽 - 5, 头像高 - 5)			# :91 (盒宽−5)×(盒高−5)
		图.position = Vector2(int(头像宽 - 图.size.x) >> 1, int(头像高 - 图.size.y) >> 1)
	设文(格, "名字", String(行.get("name", "")))
	设文(格, "等级", str(int(行.get("level", 0))))	# :102 纯数字
	改血蓝(int(行.get("id", 0)), int(行.get("hp", 0)), int(行.get("maxHp", 1)),
		int(行.get("mp", 0)), int(行.get("maxMp", 1)))
	if bool(行.get("队长", false)):
		加星(格)
	改状态(int(行.get("id", 0)), bool(行.get("在同图", false)))
	写提示(格)


static func 改等级(号: int, 值: int) -> void:
	## `TroopHPPaneCell.updateLevel:162-167`：只改那一格数字 + 重算 tooltip。
	var 格 := 找格(号)
	if 格 == null:
		return
	var 行: Dictionary = 格.get_meta("row")
	行["level"] = 值
	格.set_meta("row", 行)
	设文(格, "等级", str(值))
	写提示(格)


static func 改图(号: int, 值: int) -> void:
	## `updateMap:80-84`：data.mapId 改掉 ⇒ **只重算 tooltip**（这一格上没有地图文字）。
	var 格 := 找格(号)
	if 格 == null:
		return
	var 行: Dictionary = 格.get_meta("row")
	行["map_id"] = 值
	格.set_meta("row", 行)
	写提示(格)


static func 改状态(号: int, 在同图: bool) -> void:
	## `updateStatus:117-121`：**只看 在同图 或 在线 之一为假就灰**。
	var 格 := 找格(号)
	if 格 == null:
		return
	var 行: Dictionary = 格.get_meta("row")
	行["在同图"] = 在同图
	格.set_meta("row", 行)
	var 灰: bool = (not 在同图) or (not bool(行.get("在线", true)))
	var 盒 := 格.get_node("头像盒") as Control
	盒.self_modulate = Color(1, 1, 1)
	盒.material = 灰度材质() if 灰 else null


static func 改一格血蓝(号: int, 当前hp: int, 最大hp: int, 当前mp: int, 最大mp: int) -> void:
	## `updateSingleData:126-133`：查字典 ⇒ 只调那一格的 `updateHp`。
	改血蓝(号, 当前hp, 最大hp, 当前mp, 最大mp)


static func 改血蓝(号: int, 当前hp: int, 最大hp: int, 当前mp: int, 最大mp: int) -> void:
	## `TroopHPPaneCell.updateHp:151-160`：四个值写回 data，两根条 setData，最后**重算 tooltip**。
	var 格 := 找格(号)
	if 格 == null:
		return
	var 行: Dictionary = 格.get_meta("row")
	行["hp"] = 当前hp
	行["maxHp"] = 最大hp
	行["mp"] = 当前mp
	行["maxMp"] = 最大mp
	格.set_meta("row", 行)
	var 血比 := clampf(float(当前hp) / maxf(1.0, float(最大hp)), 0.0, 1.0)
	var 蓝比 := clampf(float(当前mp) / maxf(1.0, float(最大mp)), 0.0, 1.0)
	(格.get_node("血罩") as Control).size.x = 条宽 * 血比
	(格.get_node("蓝罩") as Control).size.x = 条宽 * 蓝比
	写提示(格)


static func 加星(格: Button) -> void:
	## `addStarIcon:141-149`：先标 data.isCaptain；星已经在了就不重复加。
	var 行: Dictionary = 格.get_meta("row")
	行["队长"] = true
	格.set_meta("row", 行)
	if 格.has_node("队长星"):
		return
	var 星 := TextureRect.new()
	星.name = "队长星"
	星.mouse_filter = Control.MOUSE_FILTER_IGNORE		# :145 mouseChildren/mouseEnabled=false
	## 原版 `BaseUtil.getImageText("TroopCaptainIcon")` = UISwf 的 33×17 图文；
	## x/y 照 :146-147：x=hpBar.x+hpBar.bg.width+1、y=hpBar.y+((12+12−17)>>1)。
	var 路 := 皮目录 + "队长标.png"
	if ResourceLoader.exists(路):
		星.texture = load(路)
		星.size = Vector2(33, 17)
	else:
		星.size = Vector2(16, 16)
	星.position = Vector2(条x + 条宽 + 1, 血y + (int(条高 + 条高 - 17) >> 1))
	格.add_child(星)


static func 摘星(格: Button) -> void:
	## `removeStarIcon:70-78`
	var 行: Dictionary = 格.get_meta("row")
	行["队长"] = false
	格.set_meta("row", 行)
	if 格.has_node("队长星"):
		格.get_node("队长星").queue_free()


static func 换队长(新队长号: int) -> void:
	## `changeTroopCaptain:330-343`：**先全员摘星**，再给新队长那一格加。
	if 面板 == null or not is_instance_valid(面板):
		return
	var 列: Control = 面板.get_node("列表") as Control
	for c in 列.get_children():
		摘星(c as Button)
	var 格 := 找格(新队长号)
	if 格 != null:
		加星(格 as Button)


static func 删格(号: int) -> void:
	## `removeCell:285-298` + `drawLayoutPane:300-310`：删掉它 ⇒ **y 比它大的每一格各抬 45**。
	var 格 := 找格(号)
	if 格 == null:
		return
	var 列: Control = 面板.get_node("列表") as Control
	var 旧位: float = 格.position.y
	列.remove_child(格)
	格.queue_free()
	for c in 列.get_children():
		if c.position.y > 旧位:
			c.position.y -= 格高
	设高()


static func 设高() -> void:
	## `setPackStatus:144-151`：高 = 标题 + 列表；**数据空 ⇒ 从父上摘掉**（自己什么都不做都不行，
	## 原版就是这么撤的）。
	if 面板 == null or not is_instance_valid(面板):
		return
	var 列: Control = 面板.get_node("列表") as Control
	## ⚠ 以前用 `列.size.y`，可它从建出来起一直是 0（建格只摆 y，不改容器高）⇒
	##   面板永远只有标题 22 高，收起/展开都像"没变大"（用户 2026-10-25 打回折叠钮）。
	列.size = Vector2(面板宽, 列.get_child_count() * 格高)
	面板.size = Vector2(面板宽, 标题高 + (列.size.y if 列.visible else 0))
	if 列.get_child_count() == 0 and 面板.get_parent() != null:
		面板.get_parent().remove_child(面板)


static func 清() -> void:
	## `removeData:345-357`：字典清、列表摘光、然后按 `setPackStatus` 撤窗。
	收起菜单()
	if 面板 != null and is_instance_valid(面板):
		var 列: Control = 面板.get_node("列表") as Control
		for c in 列.get_children():
			列.remove_child(c)
			c.queue_free()
		设高()


static func 出现着() -> bool:
	return 面板 != null and is_instance_valid(面板) and 面板.get_parent() != null


static func 格数() -> int:
	if 面板 == null or not is_instance_valid(面板):
		return 0
	return (面板.get_node("列表") as Control).get_child_count()


static func _点格(号: int) -> void:
	## `__selectListItem:198-212`：记下**点中的那一行**、菜单摆到面板局部鼠标点、**重启** 250ms 单次计时；
	## 到点才由 `onTimerHand:135-141` 把菜单露出来。自己那一格不弹（`id != stats.id`）。
	## ⚠ 面板现在**不开组队页也会出现** ⇒ 宿主可能是 null；派发那一侧有全局兜底，不许静默吞点击。
	if 面板 == null or not is_instance_valid(面板):
		return
	if 号 <= 0 or 号 == 我号:
		return
	var 格 := 找格(号)
	if 格 == null:
		return
	_选中行 = (格.get_meta("row") as Dictionary).duplicate()
	_弹点 = 面板.get_local_mouse_position()
	if _计时 == null or not is_instance_valid(_计时) or _菜单 == null or not is_instance_valid(_菜单):
		_查看资料(号)		# 面板没建好计时/菜单：至少别把点击吞掉
		return
	_计时.stop()
	_计时.start()


static func _弹菜单() -> void:
	if 面板 == null or not is_instance_valid(面板):
		return
	if _菜单 == null or not is_instance_valid(_菜单) or _选中行.is_empty():
		return
	if int(_选中行.get("id", -1)) == 我号:
		return
	## 定宽 50（`:76`）；舞台尺寸只用来把菜单钳回屏幕（原版不钳，但贴出屏就点不到）。
	_菜单.call("弹出", 菜单项名, _弹点, 面板.get_viewport_rect().size, 菜单宽)


static func _选菜单(项名: String) -> void:
	var 行 := _选中行
	_选中行 = {}
	if 行.is_empty():
		return
	var 号 := int(行.get("id", 0))
	var 名 := String(行.get("name", ""))
	## 队伍行键名（id/在线）换成好友页那套（character_id/online）——`_好友菜单动作` 只认后者。
	var 项 := {
		"character_id": 号, "name": 名, "online": bool(行.get("在线", false)),
		"face": int(行.get("face", 0)), "level": int(行.get("level", 0)),
	}
	if 宿主 != null and is_instance_valid(宿主) and 宿主.has_method("_好友菜单动作"):
		宿主.call("_好友菜单动作", "队伍:%s" % 项名, 项)
		return
	_全局菜单动作(项名, 项)


## 没开过组队页（宿主为空）时的兜底：逐条照 `__onMenuHandler:389-434`。
static func _全局菜单动作(项名: String, 项: Dictionary) -> void:
	var 号 := int(项.get("character_id", 0))
	var 名 := String(项.get("name", ""))
	var 后 := _后端()
	match 项名:
		"密语":
			## `ChatEvent.CHECK_ONLINE(playName)`：不发包，聊天框切私聊、预填 `/名字 `。
			for 节 in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("chat_panel"):
				if 节.has_method("开始私聊"):
					节.call("开始私聊", 名)
					return
			_通知("请在聊天框输入 /%s 消息" % 名)
		"查看":
			## `:400-410`：离线**只提示、不发 94**；在线才 `clickCharacter(id)`。
			if not bool(项.get("online", true)):
				_通知("该玩家不在线！")
				return
			_查看资料(号)
		"交友":
			## `:411-421`：已是好友只提示；否则 `127:1:<编号>`。
			if 后 != null and bool(后.call("is_friend", 号)):
				_通知("该玩家已经是你的好友")
			elif 后 != null:
				后.call("request_friend_add", 号)
		"交易":
			## `:422-426` `TradeWindowEvent.TRADE_INVITE` → `119:2:<编号>`。
			if 后 != null:
				后.call("request_trade_invite", 号)
		"看摊":
			## `:427-429` `UI.viewStall(id)` → `1296:2:<编号>`。
			if 后 != null:
				后.call("request_stall_open", 号)
		"赠花":
			## `:430-433` `openMarryZengHuaWindow(…)`：先存对面四项、再发 `94:6`，窗开在回帧那一刻。
			var 树 := Engine.get_main_loop() as SceneTree
			var 管 := 树.get_first_node_in_group("窗口管理") if 树 != null else null
			if 后 == null or 管 == null:
				_通知("赠花需要在线")
				return
			管.call("记赠花对面", {"charId": 号, "name": 名,
					"face": int(项.get("face", 0)), "level": int(项.get("level", 0))})
			后.call("request_flower_info", 号)


static func _查看资料(号: int) -> void:
	var 后 := _后端()
	if 后 != null and 后.has_method("request_char_full_info"):
		后.call("request_char_full_info", 号)


static func _后端() -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root.get_node_or_null("BackendConnection") if 树 != null else null


static func _通知(话: String) -> void:
	## 面板不是窗口，没有 `_通知` 可用 ⇒ 走会话那条全局提示信号（头像面板同款出口）。
	var 树 := Engine.get_main_loop() as SceneTree
	var 会 := 树.root.get_node_or_null("GameSession") if 树 != null else null
	if 会 != null and 会.has_signal("notification_requested"):
		会.emit_signal("notification_requested", 话)
	else:
		print_rich("[队伍面板] ", 话)


static func 写提示(格: Button) -> void:
	## `setToolTip:123-134` + `TROOP_HP_BAR_TIP`（九段占位，橙头绿身）。
	var 行: Dictionary = 格.get_meta("row")
	格.tooltip_text = "名称：%s\n等级：%d\n职业：%s\n家族：%s\n生命值：%d/%d\n查克拉：%d/%d\n所在地图：【%s】" % [
		String(行.get("name", "")), int(行.get("level", 0)),
		职业表.取(int(行.get("jobId", 行.get("job", 0)))), String(行.get("family", "")),
		int(行.get("hp", 0)), int(行.get("maxHp", 0)), int(行.get("mp", 0)), int(行.get("maxMp", 0)),
		地图名(int(行.get("map_id", 0)))]


static var 地图缓存: Dictionary = {}


static func 地图名(号: int) -> String:
	## `StringTool.getMapString(mapId)`
	if 地图缓存.is_empty():
		var 路 := "res://数据/地图索引.json"
		if FileAccess.file_exists(路):
			var 解 = JSON.parse_string(FileAccess.get_file_as_string(路))
			if 解 is Dictionary:
				地图缓存 = 解
	var 值 = 地图缓存.get(str(号), 地图缓存.get(号, null))
	return String(值) if 值 != null else str(号)
