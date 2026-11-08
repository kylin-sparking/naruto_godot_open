extends RefCounted
## 首领页（原版 `com/mxw/uifl/controls/wangBoss/WangBossWindow.as` 573×324 + `WangBossCell.as`）。
##
## 从 `活动窗口.gd` **切出来单独成件**（2026-10-03）：那个控制器 `preload` 了活动/信息/福利/
## 亲热天堂/宝石工艺/首领六张场景 ⇒ 交包时要么把五张不相干的页一起拖走、要么在融合方那边
## 直接 `preload` 编译失败。切出来之后本包只带这一份控制器 + 一张场景。
##
## 几何全在 .tscn 里（场景由 `开发工具/生成首领场景.py` 从量具表 `截首领页.gd` 生成 ⇒ 别手改场景），
## 本文件只做三件事：**按页切片喂三张卡、翻页钮的三档皮与可点态、两个 tooltip + 跳图接线**。
## 逐件出处 `game-client/真值/窗口/首领.md` §0~§7。
##
## ⚠ **协议一条都没发**：原版窗口是"服务端回 `requestWangList` 才创建"的，本工程没有这条协议
## （`后端连接.gd` 只有帮会 BOSS 的 `request_guild_boss_state`）⇒ 卡上的 `alive/nextTime` 是
## **未证字段**，场景烘 `alive=true`（「未死亡」这一合法原态），有数据时这里会覆盖。见真值 §6.1。
## 跳图只走**既有**钩子 `GameSession.request_map_change`（与 `传送门.gd:130` 同一条），
## 停挂机只走 `request_hang(false)` 且**只在真在挂机时**才发 —— 不发明新协议。

const 原版界面 := "res://素材/界面/原版窗口/"
const 首领星级贴图 := 原版界面 + "首领/星级.png"		# StarLevelIconF(693) 14×13
const 首领半星贴图 := 原版界面 + "首领/半星.png"			# StarHollowF(782) 14×13
const 首领场景 := preload("res://场景/界面/窗口/首领/首领窗口.tscn")

## ── 首领（原版 `WangBossWindow` 573×324 + `WangBossCell`）————————————————
## 场景是 **1:1 烘焙**（`开发工具/生成首领场景.py` 从 `开发工具/截首领页.gd` 的真值表生成），
## 所以这里**不再改任何字号/颜色/贴图/坐标** —— 旧薄壳那版运行期现改样式，正是
## "编辑器里看到的和实机不是同一套"的根值（真值 `首领.md` 开头那段作废声明）。
## 控制器只做**数据驱动**的四件事：按页切片喂三张卡、翻页钮态与页码、两个 tooltip、
## 点「地图数值 / 挑战钮」跳图。逐条出处见 `game-client/真值/窗口/首领.md` §2/§4/§5。
const 首领文案路径 := "res://数据/界面/首领_文案.json"
const 首领每页 := 3					# `Window:61` `new PageComponent(条数, 3)`
const 首领星位 := 7					# 每卡烘满 7 枚（原版最多 6 实 + 1 空），用不到的 visible=false
const 文字提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")

static var _首领文案: Dictionary = {}
static var _首领页 := 1					# **1 起**（`PageComponent.currentPage` 是 1-based，页码写 "1/4"）
static var _首领根: Control = null			# 当前页根：翻页只重喂三张卡，不重建窗口（原版就是复用 cell）
static var _分页皮 := {}					# 钮名 → [常态, 悬停, 按下]（禁用档走场景烘的 texture_disabled）

## ── 翻页效果（2026-10-03）────────────────────────────────────────────────
## 原版 `PageComponent.setPage` 是**瞬间换页**（重喂 cell）。这里在 Godot 侧补一层翻页动画，
## 两种模式由 `翻页方式` 选：
##   · `"整页"` —— 三张卡**连同各自的框**作为一整块平移推入（框跟着走，滑动中能看到框沿扫过）；
##   · `"揭示"` —— 框与内容都钉死，只用一条边界把新内容从左/右擦出来（内容零位移）。
## 两模式共用同一套层：**揭层** = `clip_contents` 容器（裁掉卡片区以外），**揭页** = 新页内容层。
const 翻页方式 := "整页"				# "整页" | "揭示"
const 滑动时长 := 0.24					# 秒；TRANS_CUBIC + EASE_OUT（起步快、收尾稳）
const 卡片区 := Rect2(11, 15, 551, 250)			# 卡片_0 左上 (11,15) → 卡片_2 右下 (562,265)
## 翻页起手时，静止层**旧内容**的淡出时长。必须明显短于 `滑动时长`：
## 整块平移时，没被新页盖住的那一侧会一直露着旧文字，等新页扫到位才被整体替换
## ⇒ 观感上"顿"一下。先让它化掉，右侧就只剩空框，新页扫过来时是连续的。
const 淡出时长 := 0.12
## 参与淡出的「内容件」（**不含**三块背景板 `卡片底`/`头像底`/`信息底` —— 框不淡、一直留着）。
## 只改 `modulate.a`、不碰 `visible`：`visible` 被星级/挑战钮/空态的显隐语义占着，动不得。
const 淡出件 := ["头像底/头像", "名称", "类型", "等级数值", "地图数值", "时间数值",
		"星级", "挑战钮", "等级标签", "地图标签", "时间标签", "爆率标签"]
## 层全部**运行时动态建**、不碰 .tscn（场景是 `开发工具/生成首领场景.py` 的产物，手改会被冲掉）。

## 内容层里**要藏掉**的节点 = "框"、恒定表头、以及**挑战钮**（它们留在静止层不动）。
## `序号` 原版恒空、`爆率标签` 原文恒定 ⇒ 一并归入静止层，少一层重叠采样的发虚。
## `挑战钮` 归静止层的理由：它是**每个框固定的入口**，不是 boss 信息；若跟着内容走，
##   揭示中会与静止层那枚叠成两个图标、命中区还在跑 ⇒ 反而更容易点错。
const 静止件 := ["卡片底", "头像底", "信息底", "序号", "等级标签", "地图标签",
		"时间标签", "爆率标签", "挑战钮"]

static var _滑动中 := false				# 动画未完不吃新点击（原版瞬间换页没这个问题）
static var _揭层: Control = null			# 揭示容器（clip_contents）：宽度推进＝揭开多少
static var _揭页: Control = null			# 内容层：固定在最终位置，靠 position 补偿保持零位移

static func 首领原文() -> Dictionary:
	if _首领文案.is_empty():
		var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string(首领文案路径))
		if typeof(包) == TYPE_DICTIONARY:
			for 键 in (包.get("文案", {}) as Dictionary):
				_首领文案[键] = String((包["文案"] as Dictionary)[键]["值"])
	return _首领文案


static func 首领表() -> Dictionary:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/原版杂项.json"))
	return (包["BossWang"]["boss"] as Dictionary) if typeof(包) == TYPE_DICTIONARY else {}


static func 首领总页() -> int:
	return int(ceil(float(首领表().size()) / float(首领每页)))


## 第 卡 格（0..2）当前该显示的那条；越界 ⇒ 空字典 = 原版 `removeData()` 后的空态。
## ⚠ GameData 的 id 在 Godot JSON 里一律是 float ⇒ 查表前必须 `int()` 再 `str()`
##   （否则得到 "2100001.0"、表里根本没这个键，实测整列文本会假报空）。
static func 首领行(卡: int) -> Dictionary:
	var 序 := (_首领页 - 1) * 首领每页 + 卡
	var 行: Dictionary = 首领表().get(str(序), {}) as Dictionary
	# 在线（2026-10-03 接 `WANG_LIST 1351`）：`alive/nextTime` 以服务端为准——夹具逐条算
	# 在场怪/跨图世界状态/onlyOneChannel 线路 + 排期（`fake_flash_server.handle_wang_list`）。
	# 静态表的键就是 BossWang 的 `index` 原键（0 起），回帧行同键 ⇒ 按 index 配对；
	# 离线 `wang_list` 恒空 ⇒ 整段短路、一切照旧（`测试/首领页回归测试.gd` 的静态断言不受影响）。
	if 行.is_empty() or _宿主 == null:
		return 行
	for 在线行 in _宿主._session.wang_list:
		if typeof(在线行) != TYPE_DICTIONARY or int(在线行.get("index", -1)) != 序:
			continue
		var 合并: Dictionary = 行.duplicate(true)
		合并["alive"] = bool(在线行.get("alive", true))
		合并["nextTime"] = int(在线行.get("nextTime", 0))
		return 合并
	return 行


static func 首领怪(行: Dictionary) -> Dictionary:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/怪物.json"))
	return (包 as Dictionary).get(str(int(行.get("mobid", 0))), {}) if typeof(包) == TYPE_DICTIONARY else {}


static func 首领地图名(行: Dictionary) -> String:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/地图名.json"))
	return String((包 as Dictionary).get(str(int(行.get("mapid", 0))), "")) if typeof(包) == TYPE_DICTIONARY else ""


## 星级枚数（`Cell.createStarContainer:293-316`）。原版 `dropStars` 是**字符串** `"2.5"` ⇒
## `split(".")` ⇒ 点号前 = 实心枚数、**只要还有小数段**再补 1 枚空心星（不是"半星"）。
## 本工程导成了数字、且 Godot 的 JSON 把数字一律解成 float ⇒ 按等价数值口径：
## `实心 = floor(值)`、`小数 > 0 ⇒ 补一枚空心`。11 条真实数据两种口径逐条相同（真值 §2.2）。
static func 首领星段(行: Dictionary) -> Array:
	var 值: float = float(行.get("dropStars", 0.0))
	var 实: int = int(floor(值))
	return [实, (1 if 值 - float(实) > 0.0 else 0)]


## `Cell:115-132`：`alive == false` ⇒ 时间 = 剩余倒计时串（**不是时刻**），
## `floor(秒/3600)` 补零 `:` `floor(秒%3600/60)` 补零。
static func 首领倒计时(秒: int) -> String:
	var 时: int = int(floor(float(秒) / 3600.0))
	var 分: int = int(floor(fmod(float(秒), 3600.0) / 60.0))
	return "%02d:%02d" % [时, 分]


static var _宿主		# 渲染入口存一次：下面十几个静态函数都要拿 `_session`/`_status`
                				# （与 `意志窗口.gd` 同形；不这么写就得给每个函数加一个宿主参数）


## 唯一入口（`功能窗口._render_page` 的 `"首领"` 分支调它）。
static func 渲染(宿主) -> void:
	_宿主 = 宿主
	# 开窗链路照原版「没数据才请求」（`UI.as:1675-1685`：窗口不存在才 `Client.requestWangList()`）。
	# 回帧 `wang_list_changed` 会驱动宿主重渲染本页（`功能窗口` 监听），所以这里只发一次请求。
	# 离线 `request_wang_list()` 返回 false ⇒ 卡片保持静态表原态（`alive=true`，合法）。
	if _宿主._session.wang_list.is_empty():
		_宿主._session.request_wang_list()
	_首领根 = _宿主._instantiate_page(首领场景)
	# 每次开窗都是新根 ⇒ 翻页态必须归零（旧揭层随旧根一起销毁）
	_滑动中 = false
	_揭层 = null
	_揭页 = null
	_首领页 = clampi(_首领页, 1, maxi(1, 首领总页()))
	for 钮名 in ["首页", "上一页", "下一页", "末页"]:
		var 钮 := _首领根.get_node("分页/" + 钮名) as BaseButton
		钮.pressed.connect(_首领跳页.bind(钮名))
	# ⚠ 卡上的两个入口**只在这里连一次**：`_首领刷新()` 每次翻页都会跑，
	#   在填卡里 connect 会越叠越多（原版是一个 cell 一个监听器，建的时候挂死）。
	#   所以 handler 只收**卡位**，点击当时再按当前页解析出那一行。
	for 卡 in 首领每页:
		(_首领根.get_node("卡片_%d/挑战钮" % 卡) as BaseButton).pressed.connect(
				_首领前往卡.bind(卡))
		(_首领根.get_node("卡片_%d/地图数值" % 卡) as Label).gui_input.connect(
				_首领图上输入.bind(卡))
	_首领接分页三态()
	_首领建揭层()
	_首领刷新()


## 揭层 = 揭示容器（`clip_contents`）+ 内容层。加在 `_首领根` **子列表末尾** ⇒ 绘制在最上层
## （盖住三张正式卡片），但裁切框只露出卡片区 ⇒ 内容层不会压到分页栏/黄底外沿。
## 初始宽度 0 ⇒ 什么也不揭，静止层（旧内容 + 框）原样可见。
static func _首领建揭层() -> void:
	_揭层 = Control.new()
	_揭层.name = "揭层"
	_揭层.position = 卡片区.position
	_揭层.size = Vector2(0.0, 卡片区.size.y)	# 宽度就是"揭开进度"，高度铺满卡片区
	_揭层.clip_contents = true
	_揭层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_首领根.add_child(_揭层)
	_揭页 = Control.new()
	_揭页.name = "揭页"
	_揭页.size = 卡片区.size
	_揭页.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_揭层.add_child(_揭页)


## 一页的全部重算：三张卡 + 页码 + 四枚钮态。原版 `setData` 也是先 `removeData()`
## 全部清空、再 `requestData(indexBegin, indexEnd)` 只喂切片命中的卡。
static func _首领刷新() -> void:
	if _首领根 == null:
		return
	for 卡 in 首领每页:
		_首领填卡(卡)
	(_首领根.get_node("分页/页码") as Label).text = "%d/%d" % [_首领页, 首领总页()]
	_首领钮可点("首页", _首领页 > 1)
	_首领钮可点("上一页", _首领页 > 1)
	_首领钮可点("下一页", _首领页 < 首领总页())
	_首领钮可点("末页", _首领页 < 首领总页())


## `PageComponent.setBtnEnabled:102-120` 只改 enabled；禁用档画的是 `getGrayFilter()`
## （`MButton3` 的滤镜，不是库里另一张真皮）⇒ Godot 侧用**烘好的灰皮**当 `texture_disabled`。
## 换可点性时一定把 `texture_normal` 落回常态：上一枚可能正停在悬停/按下档
## （原版同理 —— `mouseUpHandler:103-108` 松手回 STATE_UP）。
static func _首领钮可点(钮名: String, 可点: bool) -> void:
	var 钮 := _首领根.get_node("分页/" + 钮名) as TextureButton
	钮.disabled = not 可点
	_首领落皮(钮名, 0)


## 四枚箭头的三档皮：`PageComponent.createArrowBtn:70-75` 造的是 **`MButton3`**
## （字段声明 `:23-41` 全是 `MButton3`）⇒ 一张皮 + 运行时滤镜：
## 悬停 `clamp(皮+30)`、按下 `clamp(皮−40)`（`StyleUtil.as:7-12,43-47`）⇒ 一律**换 `texture_normal`**。
## ⚠ 两条「不许用」（skill `flash-mbutton3-state-skins`）：
##   · 不用 `texture_hover`/`texture_pressed` —— Godot 松手后只要鼠标还悬着会回到 hover，
##     而原版松手回 STATE_UP（不移出鼠标就不再亮）；
##   · 不用 material —— 会被子节点继承，且不是工程既有那条路（意志页的禁用钮用的是烘好的灰皮）。
static func _首领接分页三态() -> void:
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		var 钮 := _首领根.get_node("分页/" + 名) as TextureButton
		var 皮: Array = [钮.texture_normal]
		for 档 in ["悬停", "按下"]:
			var 路 := "res://素材/界面/专用控件/分页%s_%s.png" % [名, 档]
			# 三档缺任何一档 ⇒ 整条链静默死掉（钮永远不亮、而门可能仍是绿的）⇒ 明确报出来
			if not ResourceLoader.exists(路):
				push_warning("首领分页钮缺派生皮：%s（先跑 开发工具/生成首领钮态图.py）" % 路)
			皮.append(load(路) as Texture2D)
		_分页皮[名] = 皮
		# 手型 = `MButton3.init:135` `buttonMode = useHandCursor = true`（已烘在场景里）
		钮.mouse_entered.connect(_首领落皮.bind(名, 1))
		钮.mouse_exited.connect(_首领落皮.bind(名, 0))
		钮.button_down.connect(_首领落皮.bind(名, 2))
		钮.button_up.connect(_首领落皮.bind(名, 0))


static func _首领落皮(名: String, 态: int) -> void:
	var 皮: Array = _分页皮.get(名, []) as Array
	if 皮.size() < 3 or 皮[态] == null:
		return
	var 钮 := _首领根.get_node("分页/" + 名) as TextureButton
	# 禁用态不吃悬停/按下（原版禁用根本不进 over/down 档，画的是灰档）
	钮.texture_normal = 皮[0] if 钮.disabled else 皮[态]


static func _首领跳页(钮名: String) -> void:
	var 总 := 首领总页()
	var 新页 := _首领页
	match 钮名:
		"首页":
			新页 = 1
		"上一页":
			新页 = maxi(1, _首领页 - 1)
		"下一页":
			新页 = mini(总, _首领页 + 1)
		"末页":
			新页 = 总
	新页 = clampi(新页, 1, maxi(1, 总))
	if 新页 == _首领页:
		return						# 已到头 ⇒ 无位移（原版 `setPage` 也直接 return）
	if _滑动中:
		return						# 动画未完不吃新点击，避免内容层叠层
	_首领翻页(新页)


## 翻一页，走 `翻页方式` 选定的那一种：
##   · `"整页"` —— 揭层整片铺满（只起"裁掉框外部分"的作用），新页整块从框外平移到框内；
##   · `"揭示"` —— 新页落在最终位置不动，揭层宽度 0→551 推进（边界擦过）。
## 方向口径：**新页 > 当前页（下一页/右箭头）⇒ 自左往右**；反之自右往左。
static func _首领翻页(新页: int) -> void:
	if _揭层 == null or _揭页 == null:
		_首领页 = 新页					# 层没建起来（异常兜底）：退回瞬间换页，不做动画
		_首领刷新()
		return
	_滑动中 = true
	var 向 := 1.0 if 新页 > _首领页 else -1.0
	var 整页 := 翻页方式 == "整页"
	# 页码先跳：点下去立即有反馈；末尾 `_首领落定` 会再刷一遍（值相同）
	_首领页 = 新页
	(_首领根.get_node("分页/页码") as Label).text = "%d/%d" % [_首领页, 首领总页()]
	# 揭示模式下内容层**不带框** ⇒ 空态格没东西可盖，得先把静止层那一格清掉；
	# 顺带把挑战钮显隐同步到目标页（钮归静止层、不随内容走，别留一枚点不出 boss 的钮）。
	# 整页模式相反：副本连框一起、整块盖住静止层，空态与钮都会被"正确的那一份"盖掉 ⇒ 无需预处理。
	if not 整页:
		for 卡 in 首领每页:
			var 无数据 := 首领行(卡).is_empty()
			if 无数据:
				_首领填卡(卡)
			var 钮 := _首领根.get_node_or_null("卡片_%d/挑战钮" % 卡) as CanvasItem
			if 钮 != null:
				钮.visible = not 无数据
	# 内容层：三张卡的副本
	for 旧 in _揭页.get_children():
		旧.free()
	for 卡 in 首领每页:
		var 源 := _首领根.get_node_or_null("卡片_%d" % 卡) as Control
		if 源 == null:
			continue
		# ⚠ `duplicate` 默认**连信号**（flags=15）⇒ 必须去掉 DUPLICATE_SIGNALS(=1)，
		#   否则副本里的挑战钮/可点标签会各自多挂一条监听、清层时打到已 free 的节点。
		var 影 := 源.duplicate(2 | 4 | 8) as Control
		影.position = 源.position - 卡片区.position	# 源是根坐标，影在揭页内 ⇒ 减去框原点
		_揭页.add_child(影)
		_禁鼠标(影)					# 内容层只负责"画面"，鼠标一律穿透到静止层的正式卡片
		# ⚠ 顺序要紧：**先填卡再剥框**。`_首领填卡` 找的是 `卡片_N/头像底/头像` 这条原路径，
		#   剥框时头像会被抬走 ⇒ 反过来做就取不到头像节点了。
		_首领填卡(卡, 影, false)			# 用**目标页**数据喂内容层（含空态）
		if not 整页:
			_首领剥到只剩内容(影)
	var 补 := _揭页.create_tween()
	补.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 旧内容快速化掉（与平移同时起跑）⇒ 没被新页盖住的那一侧右侧只剩空框，不再有文字残留。
	var 淡 := _首领根.create_tween()
	淡.tween_method(_首领旧内容透明, 1.0, 0.0, 淡出时长)
	if 整页:
		_揭层.position = 卡片区.position
		_揭层.size = 卡片区.size			# 整片铺满：只用来裁掉框外的部分
		_揭页.position = Vector2(-卡片区.size.x * 向, 0.0)
		补.tween_property(_揭页, "position:x", 0.0, 滑动时长)
	elif 向 > 0.0:
		# 揭示·右箭头：左边界钉住、宽度 0→551 ⇒ 边界自左往右扫
		_揭层.position = 卡片区.position
		_揭层.size.x = 0.0
		_揭页.position = Vector2.ZERO
		补.tween_property(_揭层, "size:x", 卡片区.size.x, 滑动时长)
	else:
		# 揭示·左箭头：右边界钉住 ⇒ 位置与宽度同步收，内容层反向补偿位置以守住零位移
		#   （内容层全局 x 始终 = 卡片区左沿 11，全程不动）
		_揭层.position = Vector2(卡片区.position.x + 卡片区.size.x, 卡片区.position.y)
		_揭层.size.x = 0.0
		_揭页.position = Vector2(-卡片区.size.x, 0.0)
		补.set_parallel(true)
		补.tween_property(_揭层, "position:x", 卡片区.position.x, 滑动时长)
		补.tween_property(_揭层, "size:x", 卡片区.size.x, 滑动时长)
		补.tween_property(_揭页, "position:x", 0.0, 滑动时长)
	补.finished.connect(_首领落定)


## 把静止层三张卡的**内容**整体调到给定不透明度（三块背景板不在 `淡出件` 里 ⇒ 框不受影响）。
## 用 `modulate.a` 而不是 `visible`：后者的语义被星级/挑战钮/空态的显隐占着，动不得。
static func _首领旧内容透明(值: float) -> void:
	if not is_instance_valid(_首领根):
		return
	for 卡 in 首领每页:
		var 卡件 := _首领根.get_node_or_null("卡片_%d" % 卡) as Control
		if 卡件 == null:
			continue
		for 件名 in 淡出件:
			var 件 := 卡件.get_node_or_null(件名) as CanvasItem
			if 件 != null:
				件.modulate.a = 值


## 内容层剥到只剩「内容」：把三块背景板、恒定表头与挑战钮（见 `静止件`）藏掉 ——
## 它们由静止层的正式卡片一直画着，所以揭示时看到的才是**框不动、只有头像与 boss 信息露面**。
## ⚠ `头像` 是 `头像底` 的**子节点** ⇒ 藏了 `头像底` 会连带把头一起藏掉，必须把它抬到
##   卡片根上。`reparent` 默认 `keep_global_transform = true` ⇒ 自动落到 (4,4)，
##   与静止层头像的盒内位置逐像素一致（不会因抬层而偏 4px）。
static func _首领剥到只剩内容(影: Control) -> void:
	for 件名 in 静止件:
		var 件 := 影.get_node_or_null(件名) as CanvasItem
		if 件 != null:
			件.visible = false
	var 头像 := 影.get_node_or_null("头像底/头像") as Control
	if 头像 != null:
		头像.reparent(影)


## 落定。⚠ 顺序要紧：**先把静止层恢复好**（旧内容透明度拉回 1 + 写入目标页数据），
## 此刻揭层还整片盖着、这些改动都看不见；**再**收揭层、清内容层 ⇒ 露出来时已是正确画面。
## 反过来做的话，会先露出"半透明 + 还是旧数据"的静止层，闪一下。
static func _首领落定() -> void:
	_滑动中 = false
	if not is_instance_valid(_首领根):
		return
	_首领旧内容透明(1.0)
	_首领刷新()
	if is_instance_valid(_揭层):
		_揭层.position = 卡片区.position
		_揭层.size.x = 0.0
	if is_instance_valid(_揭页):
		_揭页.position = Vector2.ZERO
		for 影 in _揭页.get_children():
			影.free()


## 内容层整棵子树禁鼠标（`Control.mouse_filter` 不继承 ⇒ 必须递归），
## 让翻页期间悬停/点击都落到静止层的正式卡片上。
static func _禁鼠标(节点: Node) -> void:
	if 节点 is Control:
		(节点 as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for 子 in 节点.get_children():
		_禁鼠标(子)


## 一格卡：`Cell.setData:84-136`（有数据）或 `Cell.removeData:247-268`（切片越界 ⇒ 空态）。
## ⚠ 空态清的是**十个文本**，连「等　　级：」这四枚固定标签一起清 —— 不是只清数值。
## `卡件` = **卡片节点本身**（缺省取正式卡 `_首领根/卡片_N`；翻页时传内容层里的副本）。
##   ⚠ 收的是"卡节点"而不是"卡的父节点"：内容层副本挂在 `揭页` 下、与静止层不同父，
##     "父节点 + 拼 `卡片_N/…`"表达不了 ⇒ 一律收卡片节点、内部直接 `卡.get_node(件名)`。
## `挂提示` = false 时不碰 `_首领根` 上的 tooltip 宿主（内容层只做画面，不接交互）。
static func _首领填卡(卡: int, 卡件: Control = null, 挂提示: bool = true) -> void:
	var 目标卡: Control = 卡件 if 卡件 != null else (_首领根.get_node("卡片_%d" % 卡) as Control)
	var 前 := "卡片_%d" % 卡
	var 行 := 首领行(卡)
	if 行.is_empty():
		for 件名 in ["序号", "名称", "类型", "等级数值", "地图数值", "时间数值",
				"等级标签", "地图标签", "时间标签", "爆率标签"]:
			(目标卡.get_node(件名) as Label).text = ""
		(目标卡.get_node("头像底/头像") as TextureRect).texture = null
		(目标卡.get_node("挑战钮") as BaseButton).visible = false
		for 序 in 首领星位:
			(目标卡.get_node("星级/星_%d" % 序) as CanvasItem).visible = false
		if 挂提示:
			_首领提示("头像%d" % 卡, 前 + "/头像底", "", false)
			_首领提示("前往%d" % 卡, 前 + "/地图数值", "", false)
			_首领提示("挑战%d" % 卡, 前 + "/挑战钮", "", false)
		return
	var 怪 := 首领怪(行)
	(目标卡.get_node("名称") as Label).text = String(怪.get("name", ""))		# :99 getMobString
	(目标卡.get_node("类型") as Label).text = String(行.get("levelDesc", ""))	# :100
	(目标卡.get_node("等级数值") as Label).text = (
			String(首领原文().get("WANG_BOSS_CELL_JI", "%1级")).replace(
					"%1", str(int(怪.get("level", 0)))) if int(怪.get("level", 0)) != 0 else "")	# :101 ⚠ 等级为 0 ⇒ 空串（`_loc3_ ? … : ""`）
	(目标卡.get_node("地图数值") as Label).text = 首领地图名(行)				# :102
	(目标卡.get_node("序号") as Label).text = ""								# :98 **恒空**
	(目标卡.get_node("爆率标签") as Label).text = String(
			首领原文().get("WANG_BOSS_INSTRUCTION", ""))
	# 头像：`PicTool.getWangBossPic:241-254` 按 index 取 `Effect_Wang_<index>`（运行期包）。
	# 没配图时原版返回**空 MovieClip** ⇒ 头像区只剩 `PetPic_background` ⇒ 这里 texture=null。
	var 图路 := 原版界面 + "首领/Effect_Wang_%d.png" % ((_首领页 - 1) * 首领每页 + 卡)
	var 头像 := 目标卡.get_node("头像底/头像") as TextureRect
	头像.texture = load(图路) as Texture2D if ResourceLoader.exists(图路) else null
	# 星：`createStarContainer:293-323`。场景烘满 7 枚 ⇒ 只翻 visible 与换实/空皮，**不新建节点**。
	var 段 := 首领星段(行)
	for 序 in 首领星位:
		var 星 := 目标卡.get_node("星级/星_%d" % 序) as TextureRect
		星.visible = 序 < int(段[0]) + int(段[1])
		星.texture = load(首领半星贴图 if int(段[1]) > 0 and 序 == int(段[0]) else 首领星级贴图) as Texture2D
	_首领活态(卡, 行, bool(行.get("alive", true)), 目标卡, 挂提示)
	# ⚠ 简介 tooltip 的宿主是 **potraitBg（头像底）**，不是头像本身：
	#   `Cell:133` `MToolTipText.createToolTip(stage, this.potraitBg, …)`。
	if 挂提示:
		_首领提示("头像%d" % 卡, 前 + "/头像底", 首领简介文(行), true)


## `Cell:103-132`：`alive` 决定「时间数值」文案，并决定「地图数值 / 挑战钮」上那两个
## 「前往挑战」tooltip 挂不挂（`alive == false` 时原版 `removeTip()`）。挑战钮**恒可见**
## （`:93` 在 setData 里置 true），只有空态才被 `removeData` 藏掉。
## 参数同 `_首领填卡`：`卡件` 是**卡片节点本身**。
static func _首领活态(卡: int, 行: Dictionary, 活: bool,
		卡件: Control = null, 挂提示: bool = true) -> void:
	var 目标卡: Control = 卡件 if 卡件 != null else (_首领根.get_node("卡片_%d" % 卡) as Control)
	var 前 := "卡片_%d" % 卡
	(目标卡.get_node("时间数值") as Label).text = (
			String(首领原文().get("WANG_BOSS_NOT_DIED", "未死亡")) if 活
			else 首领倒计时(int(行.get("nextTime", 0))))
	(目标卡.get_node("挑战钮") as BaseButton).visible = true
	if 挂提示:
		var 往 := String(首领原文().get("WANG_BOSS_KILL", "前往挑战"))
		_首领提示("前往%d" % 卡, 前 + "/地图数值", 往, 活)
		_首领提示("挑战%d" % 卡, 前 + "/挑战钮", 往, 活)


## 两个入口同一个动作（`Cell:73-77 __gotoMap`）：地图数值是 `Label` + `mouseEnabled`
## ⇒ 走 `gui_input`，只认左键按下；挑战钮是 `MWangBossKillBtnF` ⇒ 走 `pressed`。
static func _首领图上输入(事件: InputEvent, 卡: int) -> void:
	if 事件 is InputEventMouseButton and 事件.pressed and 事件.button_index == MOUSE_BUTTON_LEFT:
		_首领前往卡(卡)


static func _首领前往卡(卡: int) -> void:
	# ⚠ **滑动中一律不响应**：动画期间影分身在平移、而命中区（静止层三张卡）原地不动，
	#   此刻点下去，"看到的那一格"与"命中的那一格"对不上 ⇒ 会跳到别的 boss。
	#   落定后 `_滑动中` 归 false，两个入口自动恢复。等 0.24s 比跳错图划算。
	if _滑动中:
		return
	_首领前往(首领行(卡))


## 跳图只走**既有**钩子（`GameSession.request_map_change`，与 `传送门.gd:130` 同一条），
## 停挂机也只走既有的 `request_hang(false)`，且**只在真在挂机时**才发 ——
## 原版 `API.guajiHandler.isStart = false` 就是那个语义，不发明新协议。
static func _首领前往(行: Dictionary) -> void:
	if 行.is_empty():
		return
	var 图 := str(int(行.get("mapid", 0)))
	if 图 == "0":
		return
	if bool(_宿主._session.hang_state.get("active", false)):
		_宿主._session.request_hang(false)
	_宿主._session.request_map_change(图, "")
	_宿主._show_hint("前往 %s" % 首领地图名(行))


## `Cell:118-124` 的头像 tooltip = `WANG_BOSS_TIP` 填 `mobDesc` / `dropDesc`。
static func 首领简介文(行: Dictionary) -> String:
	var 模 := String(首领原文().get("WANG_BOSS_TIP", ""))
	if 模.is_empty():
		return ""
	return 模.replace("%1", String(行.get("mobDesc", ""))).replace("%2", String(行.get("dropDesc", "")))


## 提示节点**同名复用**（每次 new 会给同一宿主累加一条 `mouse_entered`，旧连接指着已
## `queue_free` 的节点 ⇒ 之后每次 hover 刷 `Invalid assignment of 'visible' on Nil`）。
## 文案为空 ⇒ 不挂（原版 `removeTip()` 的等价）。显隐按节点名现取现显，不捕获对象。
static func _首领提示(名: String, 宿主路: String, 文案: String, 要挂: bool) -> void:
	var 节点名 := "文字提示_" + 名
	var 框 := _首领根.get_node_or_null(节点名) as Control
	var 新建 := 框 == null
	if 新建:
		框 = 文字提示场景.instantiate() as Control
		框.name = 节点名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_首领根.add_child(框)
	框.设置(确认弹.文案转BBCode(文案), _首领根.get_viewport_rect().size)
	框.visible = false
	# ⚠ meta 的键**必须是 ASCII 标识符**（同文件 :258 已踩过一次）：
	#   `set_meta("挂", …)` 会被 Godot 拒掉并刷 `Invalid metadata identifier`，
	#   于是 `get_meta(…, false)` 永远拿默认值 ⇒ 提示框**永远不显示**、还不崩。
	框.set_meta("tip_on", 要挂 and not 文案.is_empty())
	var 宿主 := _首领根.get_node_or_null(宿主路) as Control
	if 宿主 == null:
		return
	if 新建:
		宿主.mouse_entered.connect(_首领显提示.bind(节点名, true))
		宿主.mouse_exited.connect(_首领显提示.bind(节点名, false))


## 显隐按节点名现取现显（不捕获对象引用 ⇒ 页面拆了也不会打到 Nil）。
static func _首领显提示(节点名: String, 显: bool) -> void:
	var 框 := _首领根.get_node_or_null(节点名) as CanvasItem
	if 框 != null:
		框.visible = 显 and bool(框.get_meta("tip_on", false))


