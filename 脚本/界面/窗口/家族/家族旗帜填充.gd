extends RefCounted
## 家族旗帜窗的数据填充（原版 `FamillyFlagWindow.drawProgress` / `setData`，`FF.as:97-175,452-511`）。
##
## 分工与 `家族列表填充.gd` 同：UI 是另一位开发者生成的，**数据与协议归我们**。
## 在 `家族子窗壳.切换` 里被调一次（与列表填充并列）。
##
## 数据来源两处，都是主项目已有的权威解析：
##   * 族旗列表 ← `BackendConnection.authoritative_flag_list`（服务端 `1815:0`，
##     行 = `MapFlagInfo.decode` 的 12 字段，见 `后端连接._handle_flag_text`）；
##   * 本族名/家徽等级 ← `会话.guild`（`1552:15` 的摘要 + `1552:4` 的家徽标识）。
##
## ⚠️ 「势力对比」**不是按家族发的**，是**按地图**发的：
##   原版把全服族旗按地图收成一张表，再**按家族分组数数**（`FF:103-134`），
##   取前两名 + 「其它」。所以这里的分组只能在这张表上做，不能指望服务端给统计。
##
## 当前实现：列表行由权威 `1815:0` 回包生成；按钮动作由宿主转发 `1815:1/2`。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")
const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")

## `FF:496-511 getJiaHuiLevelColor`：1 白 / 2 绿 / 3 蓝 / 4 紫 / ≥5 橙
const 家徽等级色 := {1: Color(1, 1, 1), 2: Color(0, 1, 0), 3: Color(0x1E / 255.0, 0x90 / 255.0, 1),
	4: Color(0xBA / 255.0, 0x55 / 255.0, 0xD9 / 255.0), 5: Color(0xFF / 255.0, 0xA5 / 255.0, 0)}
## `FF:136-138` 的三色：第一 #00ff00、第二 #ff9119、其它 #ffde19
const 首名色 := "#00ff00"
const 次名色 := "#ff9119"
const 其它色 := "#ffde19"
## `FF:150-162` 三段渐变：[暗, 亮, 暗]，两端是主色的暗版
const 首段色 := [Color("#185e20"), Color("#00ff00"), Color("#185e20")]
const 次段色 := [Color("#6e3f07"), Color("#ff9119"), Color("#6e3f07")]
const 其它段色 := [Color("#766800"), Color("#ffde19"), Color("#766800")]
const 段渐变位置 := [0.0, 90.0 / 255.0, 1.0]		# `createGradientBox(..., [0,90,255])`
const 进度全长 := 364.0					# `FF:150,155,159` 的 364 字面量
const 进度高 := 12.0					# `FF:149` _loc12_ = 12


static func 填(页: Control, 宿主: Node) -> void:
	if 页 == null or 宿主 == null or String(页.name) != "家族旗帜窗":
		return
	# 底部三颗钮的命中区要先撑到装得下字（见 `_摆底部钮` 上面那段）——
	# ⚠️ 必须**在 null 判断之后**调，它是无条件解引用 `页` 的。
	_摆底部钮(页)
	# 列表是异步到的（服务端 `1815:0`），挂一次重填 —— 与列表填充同一套做法。
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
	if 后端 != null and 后端.has_signal("flag_list_received") and not 页.has_meta("flag_refresh_hooked"):
		页.set_meta("flag_refresh_hooked", true)
		家族页回调.挂(页, 后端.flag_list_received, func(_表: Array) -> void: 填(页, 宿主))
	_填左列(页, 宿主)
	_填对比(页, 宿主, 后端)
	_填列表(页, 宿主, 后端)


## 左列：家族名 / 家徽等级 / 家徽预览底色（`FF:468-482` 的 setData 尾部）
static func _填左列(页: Control, 宿主: Node) -> void:
	var 会话 = 宿主.get("_session")
	var 家族: Dictionary = (会话.guild if 会话 != null else {}) as Dictionary
	var 在族 := bool(家族.get("joined", false))
	var 名框 := 页.get_node_or_null("输入家族名") as LineEdit
	if 名框 != null:
		名框.text = String(家族.get("name", "")) if 在族 else ""
	var 级框 := 页.get_node_or_null("输入家族级") as LineEdit
	if 级框 != null:
		级框.text = str(int(家族.get("level", 0))) if 在族 else "0"
	# 家徽预览底色：`FF:478-482` 按家徽等级铺一块满格色（`_flagBgShape` 画在预览盒里）
	var 盒 := 页.get_node_or_null("盒旗帜预览") as NinePatchRect
	if 盒 == null:
		return
	var 底色 := 盒.get_node_or_null("等级底色") as ColorRect
	if 底色 == null:
		底色 = ColorRect.new()
		底色.name = "等级底色"
		底色.mouse_filter = Control.MOUSE_FILTER_IGNORE
		盒.add_child(底色)
		盒.move_child(底色, 0)
	底色.position = Vector2.ZERO
	底色.size = 盒.size
	var 等级 := maxi(1, int(家族.get("level", 1))) if 在族 else 1
	底色.color = 家徽等级色[5] if 等级 >= 5 else 家徽等级色.get(等级, 家徽等级色[1])
	# 家徽图：`FF:484-487` —— 原尺寸 34×34 **居中**摆在预览盒里（不缩放）。
	var 徽 := 盒.get_node_or_null("家徽图") as TextureRect
	if 徽 == null:
		徽 = TextureRect.new()
		徽.name = "家徽图"
		徽.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		徽.stretch_mode = TextureRect.STRETCH_SCALE
		徽.mouse_filter = Control.MOUSE_FILTER_IGNORE
		盒.add_child(徽)
	徽.texture = 家徽图.取(int(家族.get("flag_style", -1))) if 在族 else null
	徽.visible = 徽.texture != null
	徽.size = Vector2.ONE * 家徽图.边长
	徽.position = (盒.size - 徽.size) * 0.5


## 右上盒「势力对比」：三色文本 + 计数 + 上限 + 本族已安插数 + 三段渐变进度条。
static func _填对比(页: Control, 宿主: Node, 后端: Node) -> void:
	var 表: Array = (后端.get("authoritative_flag_list") if 后端 != null else []) as Array
	var 总数 := 表.size()
	# 按家族分组数数（`FF:108-131`）—— 同一 bang_id 的族旗算一家
	var 计数 := {}
	for 行 in 表:
		var id := int((行 as Dictionary).get("bang_id", 0))
		计数[id] = int(计数.get(id, 0)) + 1
	var 组: Array = []
	for id in 计数:
		组.append({"id": id, "n": int(计数[id]),
			"名": String(_首行家族名(表, int(id)))})
	组.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	var 首: Dictionary = 组[0] if 组.size() > 0 else {}
	var 次: Dictionary = 组[1] if 组.size() > 1 else {}
	var 首数 := int(首.get("n", 0))
	var 次数 := int(次.get("n", 0))
	# ⚠️ AS3 这里不设下限（`_loc8_ = 总数 - 首 - 次`）。总数是**地图数**、分组是**按族旗数**，
	#    同一张图有两个族的旗时就会算出负数 —— 负宽度的矩形画不出来。这里钳到 0。
	var 其它数 := maxi(0, 总数 - 首数 - 次数)
	_设势力文本(页.get_node_or_null("标题势力") as Control,
		"[color=%s]%s[/color][color=%s]%s[/color][color=%s]%s[/color]" % [
			首名色, _段文本("1:", 首, 首数, 首数 > 0),
			次名色, _段文本("2:", 次, 次数, 次数 > 0),
			其它色, _段文本("其它", {}, 其它数, 其它数 > 0),
		])
	_设标签(页, "标题计数", "%d面" % 总数)
	_设标签(页, "标签旗数上限", "最大可安插%d面旗帜" % 总数)
	_设输入(页, "输入旗数", "%d面" % int(_本族数(宿主, 表)))
	_画进度(页.get_node_or_null("区进度条") as Control, 总数, 首数, 次数, 其它数)


## ── 列表滚动 ──────────────────────────────────────────────────────────────
#
# ⚠️ **行不能直接挂在 `列表` 上**：`列表` 是场景里的**裁剪窗**（431×165，`clip_contents=true`）。
#    直接挂行、再把容器撑到内容高，裁剪区会跟着一起变大 ⇒ 行溢出到窗外、把底部三颗钮压住
#    （用户 2026-10-07 那张现状截图就是这个样子）。行改挂在运行时建的「内容列」里，
#    滚动 = 移动内容列（`家族列表窗` 用的是同一套办法）。
const 行高像素 := 23.0
const 滚动条宽 := 15.0
const 滚动箭头高 := 14.0
const 滑块最短 := 20.0
const 滚动皮目录 := "res://素材/界面/原版窗口/通用控件/"


static func _填列表(页: Control, 宿主: Node, 后端: Node) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	var 列 := 容器.get_node_or_null("内容列") as Control
	if 列 == null:
		列 = Control.new()
		列.name = "内容列"
		# 内容列不吃事件：滚轮由裁剪窗（列表）自己收。
		列.mouse_filter = Control.MOUSE_FILTER_IGNORE
		容器.add_child(列)
		_接滚轮(容器, 页)
		_建滚动条(页, 容器)
	for 子 in 列.get_children():
		列.remove_child(子)		# queue_free 是延迟的，当帧还在树里 ⇒ 新行会排到它后面
		子.queue_free()
	var 表: Array = _铺行(后端)
	var y := 0.0
	for 行数据 in 表:
		var 行 := _建列表行(行数据 as Dictionary, 页, 宿主)
		行.position = Vector2(0.0, y)
		列.add_child(行)
		y += 行高像素
	列.size = Vector2(maxf(容器.size.x, 1.0), maxf(容器.size.y, y))
	# ⚠️ 裁剪窗自己的尺寸**不能动**（它一变大裁剪就失效，见上面文件头的说明）。
	_滚动到(页, 容器, 列, 0.0)
	# 选中态：**同 map_id 就留着，表里没有了就退回第一行**。
	# ⚠️ 原来是"有 meta 就不动"，于是列表换了一份数据之后选中态还指着旧行
	#    （旧行可能已经不在表里），两颗钮的可用态跟着一起错 —— 取证器
	#    `开发工具/截家族旗帜窗全景.gd` 第二屏（把 13 面换成 1 个空点）就是这么露出来的。
	# ⚠️ `_更新按钮` 必须**每次**都调：选中换了、表换了，钮的灰态都得跟着重算。
	var 旧 := 页.get_meta("flag_selected", {}) as Dictionary
	var 旧图 := int(旧.get("map_id", 0))
	var 新选 := {}
	if 旧图 > 0:
		for 行数据 in 表:
			if int((行数据 as Dictionary).get("map_id", 0)) == 旧图:
				新选 = 行数据 as Dictionary
				break
	if 新选.is_empty() and not 表.is_empty():
		新选 = 表[0] as Dictionary
	页.set_meta("flag_selected", 新选)
	_更新按钮(页, 宿主)


## 底部三颗钮的几何：**宽度跟着文字走**、两两间隔 30、整体居中。
##
## ⚠️⚠️ 场景里（生成器烘的）三颗钮**一律写死 57×22**，而 `Label` 是撑满按钮的：
##     「说明资讯」4 字（12px 宋体 ≈48px）勉强塞得下，但「安插本族旗帜」「修复族旗血量」
##     是 6 字（≈72px）⇒ **文字画到按钮矩形之外**。玩家点的是凸出去的那截字，
##     而点击判定只在 57×22 里 ⇒ 表现就是"看得见、点不动"
##     —— 用户 2026-10-09 报的"说明资讯/安插本族旗帜/修复族旗血量 这三个都无法点击"。
##     ⚠️ 这类几何 bug **离线门和探针一律抓不到**：它们都是 `pressed.emit()`，绕过命中测试。
##        要抓只能靠几何断言（`钮.size.x >= 文字宽`），见 `开发工具/探旗帜安插按钮.gd`。
##
## 原版这三颗钮是 `BaseUtil.getButton(text, ...)`（宽度跟着文字走），摆法见 `FFW:370-375`：
##   `y = 高 - 钮高 - BORDER_GAP`（`UIConfig.BORDER_GAP = 5`，`UIConfig.as:890`），两两间隔 30。
##   宽度取"文字宽 + 6"：真值 `MButton3.measure()`（`MButton3.as:378-390`）——
##   九宫格皮时 `_width = tf.width + 6`，`tf` 是 `autoSize = LEFT` 的文本框（宽 = 纯文字宽）。
##   ⚠️ 原版把 `_modifyFlagBloodBtn.visible = false`（`FFW:369`）且**没找到再打开的地方**，
##      也就是原版常态只有两颗钮、居中只算这两颗；我们这版三颗都露出来，
##      所以这里按"所有可见钮一起居中"排 —— 是有意的偏差，别当成抄漏了。
static func _摆底部钮(页: Control) -> void:
	var 钮们: Array[Control] = []
	for 名 in ["钮说明资讯", "钮安插本族旗帜", "钮修复族旗血量"]:
		var 钮 := 页.get_node_or_null(名) as Control
		if 钮 != null and 钮.visible:
			钮们.append(钮)
	if 钮们.is_empty():
		return
	for 钮 in 钮们:
		_撑钮到文字(钮)
	var 间隔 := 30.0
	var 总宽 := 间隔 * (钮们.size() - 1)
	for 钮 in 钮们:
		总宽 += 钮.size.x
	# 页尺寸：`填` 可能跑在壳还没定尺寸之前，退回 `custom_minimum_size`（604×332）。
	var 页宽 := 页.size.x if 页.size.x > 1.0 else 页.custom_minimum_size.x
	var x := (页宽 - 总宽) / 2.0
	for 钮 in 钮们:
		钮.position.x = x
		x += 钮.size.x + 间隔
	# 兜底：把三颗钮挪到**页面最末**（= 最上层）。这样任何运行时加进来的兄弟节点
	# （比如 `_建滚动条` 补的那根滚动条、或将来别的覆盖层）都不可能压在它们上面吃点击。
	# 只影响绘制/命中顺序，不影响位置。
	for 钮 in 钮们:
		页.move_child(钮, -1)


## 把一颗钮撑到能装下它的字 —— **命中区必须覆盖看得见的字**，否则就是"点不动"。
static func _撑钮到文字(钮: Control) -> void:
	var 字 := 钮.get_node_or_null("Label") as Label
	if 字 == null:
		return
	var 字体 := 字.get_theme_font("font")
	var 字号 := 字.get_theme_font_size("font_size")
	var 文字宽 := 字体.get_string_size(String(字.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
	# `maxf` 而不是直接赋值：场景里量准过的那几颗（说明资讯 57）保持原样，只把装不下的撑开。
	钮.size.x = maxf(钮.size.x, 文字宽 + 6.0)


## 行表 = **按 `flagmap`（13 张领域战地图）铺**，服务端族旗表按 `map_id` 配上去；
## 配不上的图**补一条空点**（只有 map_id/x/y，没有族旗）。
##
## ⚠️⚠️ 这是"到底能不能安插族旗"的命门：原来我们**直接拿服务端族旗表当行表** ⇒
##    列表里只有"已经有旗的图"，空位根本不在列表里 —— 玩家永远选不到空点、
##    于是**永远安插不了**（而且安插钮还会因为选中行是别人的旗而恒灰）。
##    真值：原版 `FamillyFlagWindow.getFlags`（`FFW:513-545`）就是先遍历
##    `FamillyManager.getFamillyWarMaps()`（= `数据/家族.json` 的 `flagmap`，`FM.as:529-532`，
##    按 `flagmap` 的**行号顺序**），每张图去服务端行里按 `map_id` 找同行；
##    找不到就 `new MapFlagInfo()` 只赋 `map_id/x/y` 再 push 进去。
##    ⇒ 列表**恒为 13 行**，顺序就是 `flagmap` 的顺序（第 1 行是 flagmap 键 "0" 那张图）。
static func _铺行(后端: Node) -> Array:
	var 服务端: Array = (后端.get("authoritative_flag_list") if 后端 != null else []) as Array
	var 出: Array = []
	for 图 in 游戏数据.family_flag_maps():
		var 目标 := int((图 as Dictionary).get("mapid", 0))
		var 找到: Dictionary = {}
		for 行 in 服务端:
			if int((行 as Dictionary).get("map_id", 0)) == 目标:
				找到 = 行 as Dictionary
				break
		if 找到.is_empty():
			出.append({
				"map_id": 目标,
				"x": int((图 as Dictionary).get("x", 0)),
				"y": int((图 as Dictionary).get("y", 0)),
				"channel": -1, "bang_id": 0, "bang_name": "",
				"flag_hp": 0, "flag_maxhp": 0, "flag_level": 0,
				"flag_style": -1, "flag_color": 0, "flag_name": "",
			})
		else:
			出.append(找到)
	return 出


## 点行高亮：**只亮一行**（原来只给自己 `modulate`，上一条不会复位 ⇒ 点几行就亮几行）。
static func _高亮(页: Control, 选中行: Control) -> void:
	var 列 := 页.get_node_or_null("列表/内容列")
	if 列 == null:
		return
	for 子 in 列.get_children():
		if 子 is Control:
			(子 as Control).modulate = Color("#d7b27e") if 子 == 选中行 else Color.WHITE


## 两颗钮"为什么是灰的"的一句话说明（原版那三个判据逐条列出来）。
##
## 为什么要有它：按钮态是**四条与运算**，灰着的时候光看界面完全看不出是哪一条不过
## （2026-10-08 排"安插不了"时就是靠它一眼定到"自己的角色 id 取错了地方"）。
## 测试失败信息里也带上它。
static func 按钮态说明(页: Control, 宿主: Node) -> String:
	var 选中 := 页.get_meta("flag_selected", {}) as Dictionary
	var 会话 = 宿主.get("_session")
	var 后端 = 宿主.get("_backend")
	var 家族: Dictionary = (会话.guild if 会话 != null else {}) as Dictionary
	var 统计: Variant = 会话.get("player_stats") if 会话 != null else {}
	var 自己id := int(后端.get("character_id")) if 后端 != null else 0
	var 族长id := int(家族.get("leader_id", 0))
	var 图 := int(选中.get("map_id", 0))
	return ("入族=%s 族长id=%d 自己id=%d 管理=%s 图=%d(%s) 在领域战表=%s 该图旗主=%d 本族id=%d"
		% [bool(家族.get("joined", false)), 族长id, 自己id,
			族长id > 0 and 自己id > 0 and 自己id == 族长id,
			图, 游戏数据.map_name(图), 游戏数据.family_flag_map_ids().has(图),
			int(选中.get("bang_id", 0)), int(家族.get("id", 0))])


## 滚轮 / 拖拽滚列表。挂在**裁剪窗**上（内容列是 IGNORE，收不到事件）。
static func _接滚轮(容器: Control, 页: Control) -> void:
	容器.mouse_filter = Control.MOUSE_FILTER_STOP
	容器.gui_input.connect(func(事件: InputEvent) -> void:
		var 按 := 事件 as InputEventMouseButton
		if 按 == null or not 按.pressed:
			return
		if 按.button_index == MOUSE_BUTTON_WHEEL_UP:
			_滚像素(页, -行高像素)
		elif 按.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_滚像素(页, 行高像素)
		else:
			return
		页.get_viewport().set_input_as_handled())


## 右侧滚动条。几何自己算（不照抄 `家族列表窗` 场景里那套 14/241/14 —— 那套的轨道
## 比控件还高，是照原版一个更高的列表定的；我们这里按裁剪窗实际高度收边）。
static func _建滚动条(页: Control, 容器: Control) -> void:
	var 高 := maxf(容器.size.y, 滚动箭头高 * 2.0 + 滑块最短)
	var 条 := Control.new()
	条.name = "滚动条"
	条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	条.position = Vector2(容器.position.x + 容器.size.x - 滚动条宽, 容器.position.y)
	条.size = Vector2(滚动条宽, 高)
	页.add_child(条)
	var 上 := TextureButton.new()
	上.name = "滚动上"
	上.texture_normal = load(滚动皮目录 + "滚动向上.png") as Texture2D
	上.ignore_texture_size = true
	上.focus_mode = Control.FOCUS_NONE
	上.size = Vector2(滚动条宽, 滚动箭头高)
	上.position = Vector2.ZERO
	条.add_child(上)
	var 槽皮 := TextureRect.new()
	槽皮.name = "滚动槽"
	槽皮.texture = load(滚动皮目录 + "滚动槽.png") as Texture2D
	槽皮.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	槽皮.stretch_mode = TextureRect.STRETCH_SCALE
	槽皮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	槽皮.position = Vector2.ZERO
	槽皮.size = Vector2(滚动条宽, 高)
	条.add_child(槽皮)
	条.move_child(槽皮, 0)
	var 滑 := TextureButton.new()
	滑.name = "滑块"
	滑.texture_normal = load(滚动皮目录 + "滚动滑块.png") as Texture2D
	滑.ignore_texture_size = true
	滑.focus_mode = Control.FOCUS_NONE
	滑.size = Vector2(滚动条宽, 滑块最短)
	滑.position = Vector2(0.0, 滚动箭头高)
	条.add_child(滑)
	var 下 := TextureButton.new()
	下.name = "滚动下"
	下.texture_normal = load(滚动皮目录 + "滚动向下.png") as Texture2D
	下.ignore_texture_size = true
	下.focus_mode = Control.FOCUS_NONE
	下.size = Vector2(滚动条宽, 滚动箭头高)
	下.position = Vector2(0.0, 高 - 滚动箭头高)
	条.add_child(下)
	上.pressed.connect(func() -> void: _滚像素(页, -行高像素))
	下.pressed.connect(func() -> void: _滚像素(页, 行高像素))


static func _列表两件(页: Control) -> Array:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return []
	var 列 := 容器.get_node_or_null("内容列") as Control
	return [] if 列 == null else [容器, 列]


static func _上限(容器: Control, 列: Control) -> float:
	return maxf(0.0, 列.size.y - 容器.size.y)


static func _当前偏移(容器: Control, 列: Control) -> float:
	return clampf(-列.position.y, 0.0, _上限(容器, 列))


static func _滚像素(页: Control, 像素: float) -> void:
	var 两 := _列表两件(页)
	if 两.is_empty():
		return
	var 容器 := 两[0] as Control
	var 列 := 两[1] as Control
	_滚动到(页, 容器, 列, _当前偏移(容器, 列) + 像素)


static func _滚动到(页: Control, 容器: Control, 列: Control, 目标: float) -> void:
	var 上 := _上限(容器, 列)
	列.position.y = -clampf(目标, 0.0, 上)
	var 条 := 页.get_node_or_null("滚动条") as Control
	if 条 == null:
		return
	# 内容装得下就整条收起来（原版 `ScrollBar` 也是没得滚就隐藏）。
	条.visible = 上 > 0.0
	if not 条.visible:
		return
	var 轨道 := maxf(0.0, 条.size.y - 滚动箭头高 * 2.0)
	var 高 := maxf(滑块最短, 轨道 * 容器.size.y / maxf(容器.size.y, 列.size.y))
	var 滑 := 条.get_node_or_null("滑块") as Control
	if 滑 != null:
		滑.size = Vector2(滚动条宽, 高)
		滑.position = Vector2(0.0, 滚动箭头高 + (轨道 - 高) * (0.0 if 上 <= 0.0 else _当前偏移(容器, 列) / 上))

static func _建列表行(数据: Dictionary, 页: Control, 宿主: Node) -> Control:
	var 行 := Control.new()
	行.custom_minimum_size = Vector2(431.0, 23.0)
	行.size = Vector2(431.0, 23.0)
	行.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# meta 键必须 ASCII；把 map_id 带上：选中态要靠它认行，测试也要按行点
	# （行里那 5 个 Label 是运行时建的、没名字，光看控件认不出来是哪一行）。
	行.set_meta("map_id", int(数据.get("map_id", 0)))
	行.gui_input.connect(func(事件: InputEvent) -> void:
		if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
				and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			页.set_meta("flag_selected", 数据)
			_更新按钮(页, 宿主)
			_高亮(页, 行)
			行.get_viewport().set_input_as_handled()
	)
	var 值 := [游戏数据.map_name(int(数据.get("map_id", 0))),
		"%d,%d" % [int(数据.get("x", 0)) / 100, int(数据.get("y", 0)) / 100],
		String(数据.get("flag_name", "")), str(int(数据.get("flag_level", 0))),
		String(数据.get("bang_name", ""))]
	var 宽 := [80.0, 50.0, 80.0, 40.0, 80.0]
	var x := 0.0
	for i in 5:
		var 字 := Label.new()
		字.position = Vector2(x, 2.0)
		字.size = Vector2(宽[i], 19.0)
		字.text = String(值[i]) if i < 2 or int(数据.get("bang_id", 0)) != 0 else ""
		字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		字.clip_text = true
		字.add_theme_color_override("font_color", Color("#00ff00") if i == 0 else Color.WHITE)
		字.mouse_filter = Control.MOUSE_FILTER_IGNORE
		行.add_child(字)
		x += 宽[i]
	var 血底 := ColorRect.new()
	血底.position = Vector2(334.0, 6.0)
	血底.size = Vector2(74.0, 11.0)
	血底.color = Color("#26352b")
	血底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.add_child(血底)
	var 最大 := int(数据.get("flag_maxhp", 0))
	var 当前 := clampi(int(数据.get("flag_hp", 0)), 0, maxi(最大, 1))
	var 血填 := ColorRect.new()
	血填.position = Vector2(334.0, 6.0)
	血填.size = Vector2(74.0 * (float(当前) / float(maxi(最大, 1))), 11.0)
	血填.color = Color("#36b85a") if 当前 > 0 else Color.TRANSPARENT
	血填.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.add_child(血填)
	var 血 := Label.new()
	血.position = Vector2(330.0, 1.0)
	血.size = Vector2(92.0, 20.0)
	血.text = "%d/%d" % [当前, 最大] if int(数据.get("bang_id", 0)) != 0 else ""
	血.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	血.add_theme_color_override("font_color", Color("#ffffff"))
	血.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.add_child(血)
	return 行

## 两颗钮的可用态。逐条对齐原版 `FFW.updateButtonState`（`FamillyFlagWindow.as:394-412`）：
##
##   `_loc2_ = FamillyManager.isManager`
##     真值 `FM.as:455-462`：`API.dataCenter.stats.id == myFamillyInfo.leaderId` ——
##     比的是**角色 id**，不是名字、也不是 rank。⇒ 这里也用 `player_stats.id` 对 `guild.leader_id`。
##     ⚠️ **不能拿 `rank >= 5` 当"是管理"**：那会把普通成员也放行，服务端随后回
##        「只有族长可以操作族旗。」（`fake_flash_server.handle_map_flag_action`），
##        按钮亮着却办不成事，比灰着更让人迷惑。
##   `_loc3_ = getMapFlagFamillyId(选中的图)`（= 那一行族旗的 `bang_id`）
##   安插钮 enabled = `_loc2_ && isInWarMaps(图) && _loc3_ == 0`
##   修复钮 enabled = `_loc2_ && isInWarMaps(图) && _loc3_ == myFamillyInfo.id`
##
## ⚠️ 原版**没有**"血量满了就灰掉修复钮"这一条 —— 原来我们多加了这个条件，
##    在满血（族旗平时就是 10000/10000）时修复钮永远是灰的，和单机版对不上。
##    （服务端自己会回「族旗生命值已经满了。」）
## ⚠️ `isInWarMaps` 那道判定原版也有（`:404`）：只有 `数据/家族.json` 的 `flagmap`
##    里那 13 张领域战地图能安插。清单本来就只发这 13 张，所以现实中恒真，
##    但口径照抄，免得将来服务端多发一张图就悄悄放行。
static func _更新按钮(页: Control, 宿主: Node) -> void:
	var 选中 := 页.get_meta("flag_selected", {}) as Dictionary
	var 会话 = 宿主.get("_session")
	var 家族: Dictionary = (会话.guild if 会话 != null else {}) as Dictionary
	var 在族 := bool(家族.get("joined", false))
	var 统计: Variant = 会话.get("player_stats") if 会话 != null else {}
	var 当前名 := String(统计.get("name", "")) if 统计 is Dictionary else ""
	# ⚠️ "我的角色 id"要从 **`BackendConnection.character_id`** 取：`player_stats` 里**没有 `id`**
	#    （`服务端同步.应用人物` 只把 `player_stats` 里已存在的键填进去，id/name 属于"非属性键"）。
	#    取错地方的话这个 id 恒为 0 ⇒"是管理"恒为假 ⇒ 安插钮永远是灰的。
	var 自己id := 0
	var 后端 = 宿主.get("_backend")
	if 后端 != null:
		# ⚠️ `Object.get()` **只收一个参数**（那是 Dictionary 的 `get(k, 默认值)`），
		#    写成 `get("character_id", 0)` 会直接解析报错。
		自己id = int(后端.get("character_id"))
	if 自己id <= 0 and 统计 is Dictionary:
		自己id = int(统计.get("id", 0))
	var 族长id := int(家族.get("leader_id", 0))
	# 首选"角色 id 相等"（原版 `FM.as:455-462` 的口径）；**拿不到族长 id**（老回包/离线）
	# 才退回比名字 —— 兜底只在 `族长id <= 0` 时生效。
	var 是管理 := 族长id > 0 and 自己id > 0 and 自己id == 族长id
	if not 是管理 and 族长id <= 0 and not 当前名.is_empty():
		是管理 = String(家族.get("leader", "")) == 当前名
	var 图 := int(选中.get("map_id", 0))
	var 是领域战图: bool = 图 > 0 and 游戏数据.family_flag_map_ids().has(图)
	var 旗主 := int(选中.get("bang_id", 0))
	var 插 := 页.get_node_or_null("钮安插本族旗帜") as TextureButton
	var 修 := 页.get_node_or_null("钮修复族旗血量") as TextureButton
	if 插 != null:
		插.disabled = not 在族 or not 是管理 or not 是领域战图 or 旗主 != 0
	if 修 != null:
		修.disabled = not 在族 or not 是管理 or not 是领域战图 or 旗主 != int(家族.get("id", 0))
	# 悬停就把"为什么灰着"说出来。
	# 为什么要有：这四条是与运算，灰着的时候光看界面完全看不出是哪一条不过 ——
	# 用户 2026-10-09 报的"安插还是无法点击"，光凭截图分不出是灰着还是点了没反应。
	# 原版这颗钮本来也挂 tooltip（`FFW.updateTooltip`，内容是每日次数），这里换成"原因"。
	_设提示(插, not 在族, not 是管理, not 是领域战图, 旗主 != 0,
		"点这里把本族族旗安插到选中的地图", "你还没有加入家族", "只有族长可以操作族旗",
		"这张地图不能安插族旗", "这张地图已经有族旗了")
	_设提示(修, not 在族, not 是管理, not 是领域战图, 旗主 != int(家族.get("id", 0)),
		"把这张图上的**本族**族旗血量修满", "你还没有加入家族", "只有族长可以操作族旗",
		"这张地图不能安插族旗", "这张地图上没有本族的族旗")


## 给一颗钮设"可用时的说明 / 不可用时的原因"。四个 `不…` 依次对应四条判据。
static func _设提示(钮: TextureButton, 不在族: bool, 非管理: bool, 非领域战图: bool, 另有原因: bool,
		可用文案: String, 因不在族: String, 因非管理: String, 因非领域战图: String, 因另有: String) -> void:
	if 钮 == null:
		return
	if 不在族:
		钮.tooltip_text = 因不在族
	elif 非管理:
		钮.tooltip_text = 因非管理
	elif 非领域战图:
		钮.tooltip_text = 因非领域战图
	elif 另有原因:
		钮.tooltip_text = 因另有
	else:
		钮.tooltip_text = 可用文案

## `FF:136-138`：`"1:" + 家族名 + "(" + n + "面)"`；没人时留一个空格。
static func _段文本(前缀: String, 组: Dictionary, 数: int, 有: bool) -> String:
	if not 有:
		return " "
	return "%s%s(%d面)" % [前缀, String(组.get("名", "")), 数]


static func _首行家族名(表: Array, id: int) -> String:
	for 行 in 表:
		if int((行 as Dictionary).get("bang_id", 0)) == id:
			return String((行 as Dictionary).get("bang_name", ""))
	return ""


## 本族（`会话.guild.id`）在这张表里占几面（`FF:164-174` 找 `bang_id == myFamillyInfo.id`）。
static func _本族数(宿主: Node, 表: Array) -> int:
	var 会话 = 宿主.get("_session")
	var 家族: Dictionary = (会话.guild if 会话 != null else {}) as Dictionary
	var 自己 := int(家族.get("id", 0))
	if 自己 <= 0:
		return 0
	var n := 0
	for 行 in 表:
		if int((行 as Dictionary).get("bang_id", 0)) == 自己:
			n += 1
	return n


## 势力那行是三色的（原版用 `_shiLiLabel.htmlText`，`FF:139`），而场景里那个节点是 `Label`
## —— Label 不认 BBCode。**不动场景**（几何门量的就是这个节点），在它里面挂一个铺满的
## RichTextLabel，把原 Label 的文字清空当"占位框"用。
static func _设势力文本(节: Control, bb: String) -> void:
	if 节 == null:
		return
	if 节 is Label:
		(节 as Label).text = ""
	var 富 := 节.get_node_or_null("势力富文本") as RichTextLabel
	if 富 == null:
		富 = RichTextLabel.new()
		富.name = "势力富文本"
		富.bbcode_enabled = true
		富.scroll_active = false
		富.fit_content = false
		富.mouse_filter = Control.MOUSE_FILTER_IGNORE
		富.add_theme_font_size_override("normal_font_size", 12)
		富.add_theme_color_override("default_color", Color("#ffde19"))
		节.add_child(富)
		# 锚点要在进树之后设，否则按父节点当时的尺寸算（窗口刚建出来时父节点还是 0×0）。
		富.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 原版 `_shiLiLabel.align = "center"`（`FF:301`）—— Godot 的 RichTextLabel 没有
	# `horizontal_alignment` 属性，居中要写在 BBCode 里。
	富.text = "[center]" + bb + "[/center]"


static func _设标签(页: Control, 名: String, 文本: String) -> void:
	var 节 := 页.get_node_or_null(名) as Label
	if 节 != null:
		节.text = 文本


static func _设输入(页: Control, 名: String, 文本: String) -> void:
	var 节 := 页.get_node_or_null(名) as LineEdit
	if 节 != null:
		节.text = 文本


## 三段渐变条（`FF:142-163`）：每段宽 = 364 × 该组占比、高 12，横排；每段自带 [暗,亮,暗] 三段渐变。
static func _画进度(区: Control, 总: int, 首: int, 次: int, 其它: int) -> void:
	if 区 == null:
		return
	for 子 in 区.get_children():
		区.remove_child(子)
		子.queue_free()
	if 总 <= 0:
		return
	var 左 := 0.0
	for 段 in [[首, 首段色], [次, 次段色], [其它, 其它段色]]:
		var 数 := int(段[0])
		if 数 <= 0:
			continue
		var 宽 := 进度全长 * (float(数) / float(总))
		var 条 := TextureRect.new()
		条.size = Vector2(宽, 进度高)
		条.position = Vector2(左, 0.0)
		条.texture = _渐变(段[1])
		条.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		条.stretch_mode = TextureRect.STRETCH_SCALE
		条.mouse_filter = Control.MOUSE_FILTER_IGNORE
		区.add_child(条)
		左 += 宽


## 横向三段渐变贴图（AS3 的 `createGradientBox(w, h, PI/2, x, y)` 就是横向）。
static func _渐变(色: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(段渐变位置)
	g.colors = PackedColorArray([色[0], 色[1], 色[2]])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 64			# 会被 TextureRect 横向拉伸，取个小宽度即可
	return t


# ── 下轮搬「族旗安插列表」要的东西（本轮已核过，别再从头查）─────────────────────
#
# 行 = `FamillyFlagItemRenderer`（`super(416,23)`，`FamillyFlagItemRenderer.as:29`），
# 六列链式（宽，无 +2 间隙 —— 这里和列表窗不同）：
#   地图名称 80 绿 0x00FF00 @0 · 座标 50 白 @80 · 家徽名称 80 白 @130 ·
#   等级 40 白 @210 · 所属家族 80 白 @250 · 族旗生命 = `MBarExpF` @288（宽 80）
# 取数（`:33-56`）：
#   地图名称 = `StringTool.getMapString(map_id)` → 我方 `游戏数据.map_name(八位补零)`
#   座标     = `int(x/100) + "," + int(y/100)` ← **整除 100**，不是原值
#   家徽名称 = flag_name · 等级 = flag_level · 所属家族 = bangName
#   族旗生命 = `setData(flag_hp, flag_maxhp)`；`bang_id == 0` 时整行留空、血条 `visible=false`
# 血条几何（`MBar` 符号 167）：血条底 `血条底.png` 122×11、槽在局部 (48,3) 宽 74（=80−6），
#   填充 `血条填充.png` 按比例从左裁；文字 `hp/maxhp` 自适应 9 号（同宠物窗口那套 `_设条`）。
