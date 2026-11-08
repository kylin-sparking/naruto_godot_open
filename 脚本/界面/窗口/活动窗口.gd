extends RefCounted

const 原版界面 := "res://素材/界面/原版窗口/"
const 物品格贴图 := 原版界面 + "通用控件/物品格.png"
const 活动场景 := preload("res://场景/界面/窗口/活动/活动窗口.tscn")
const 信息场景 := preload("res://场景/界面/窗口/信息/信息窗口.tscn")
const 福利场景 := preload("res://场景/界面/窗口/福利/福利窗口.tscn")
const 亲热天堂场景 := preload("res://场景/界面/窗口/亲热天堂/亲热天堂窗口.tscn")
## 「线上有礼」的三档门槛取自 GameData 的 `Gift.monthly`（导出见 开发工具/导出礼包配置.py）。
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
## 藏宝候选格的资质框/流光 —— 原版 `SuccessWindowCell.__showIcon:184-212` 按 `value.aptitude`
## 叠 `EquipAptitude*F` 并用 `EquipAnimationF`（紫装流光）。全项目唯一搭这两层的入口。
const 装备品质 := preload("res://脚本/单例/装备品质.gd")
## 原版这些 `RichTextLabel` 的文案是 Flash 的 `htmlText`（`<font color='#00ff00'>`），
## Godot 的 `RichTextLabel` 吃的是 BBCode —— **不翻译就整串标签原样显示成文字**
## （同 `功能窗口.译文为BBCode` 那条 2026-09-22 的实机教训）。
const 富文本 := preload("res://脚本/界面/富文本.gd")
## 物品格悬停详情框：与背包/仓库/人物同一份接线（`MToolTipItem` 那套的客户端实现）。
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")

var 窗口

var _session:
	get: return 窗口._session
var _activity:
	get: return 窗口._activity
var _status:
	get: return 窗口._status
var _prize_tab:
	get: return 窗口._prize_tab
	set(value): 窗口._prize_tab = value
var _activity_overview_tab:
	get: return 窗口._activity_overview_tab
var _info_tab:
	get: return 窗口._info_tab

func _init(宿主) -> void:
	窗口 = 宿主

func _instantiate_page(scene: PackedScene) -> Control:
	return 窗口._instantiate_page(scene)

func _configure_original_panel(panel: Panel, outer := false) -> void:
	窗口._configure_original_panel(panel, outer)

func _configure_label(label: Label, font_size: int, color: Color) -> void:
	窗口._configure_label(label, font_size, color)

func _apply_tab_skin(tab: Button) -> void:
	窗口._apply_tab_skin(tab)

func _sub_panel_style() -> StyleBoxTexture:
	return 窗口._sub_panel_style()

func _configure_standard_button(button: Button) -> void:
	窗口._configure_standard_button(button)

func _set_prize_tab(index: int) -> void:
	窗口._set_prize_tab(index)

func _set_check(value: bool, key: String) -> void:
	窗口._set_check(value, key)

func _refresh_current() -> void:
	窗口._refresh_current()

func _today() -> int:
	return 窗口._today()

func _check_in() -> void:
	窗口._check_in()

## 亲热天堂的公开入口（`功能窗口._explore_treasure` 也转到这里）。
func 藏宝按钮() -> void:
	_寻宝按钮()

func _render_check_in() -> void:
	_render_prize_window()

func _render_benefit() -> void:
	_render_prize_window()

func _render_activity() -> void:
	var page := _instantiate_page(活动场景)
	_configure_original_panel(page.get_node("外框") as Panel, true)
	var tab_names := ["日常活动", "每周活动", "活动副本", "活动新闻"]
	for index in tab_names.size():
		var tab := page.get_node("分页/%s" % tab_names[index]) as Button
		窗口.选页签(tab, index == _activity_overview_tab)
		_apply_tab_skin(tab)
		tab.pressed.connect(窗口._set_activity_overview_tab.bind(index))
		var tab_page := page.get_node("页面/%s" % tab_names[index]) as Control
		tab_page.visible = index == _activity_overview_tab
		_configure_original_panel(tab_page.get_node("内容面板") as Panel)
	_configure_page_labels(page)
	var state: Dictionary = 窗口._backend.authoritative_activity if 窗口._backend != null and bool(窗口._backend.in_game) else {}
	(page.get_node("页面/日常活动/状态") as Label).text = "今日活跃度：%d" % int(state.get("points", 0))

func _render_info() -> void:
	var page := _instantiate_page(信息场景)
	_configure_original_panel(page.get_node("外框") as Panel, true)
	var tab_names := ["系统公告", "聊天信息", "个人成就"]
	for index in tab_names.size():
		var tab := page.get_node("分页/%s" % tab_names[index]) as Button
		窗口.选页签(tab, index == _info_tab)
		_apply_tab_skin(tab)
		tab.pressed.connect(窗口._set_info_tab.bind(index))
		var tab_page := page.get_node("页面/%s" % tab_names[index]) as Control
		tab_page.visible = index == _info_tab
		_configure_original_panel(tab_page.get_node("内容面板") as Panel)
	_configure_page_labels(page)
	if 窗口._backend != null and bool(窗口._backend.in_game):
		var achievements: Array[Dictionary] = 窗口._backend.authoritative_achievements
		var completed := 0
		for achievement in achievements:
			if bool(achievement.get("gained", false)):
				completed += 1
		(page.get_node("页面/个人成就/内容") as Label).text = "已完成成就：%d / %d" % [completed, achievements.size()]

func _configure_page_labels(page: Control) -> void:
	for node in page.find_children("*", "Label", true, false):
		var label := node as Label
		_configure_label(label, 12, Color("#ffd27c") if label.name == "标题" else Color.WHITE)

## 开心有礼（原版 `PrizeWindow2`）。六个子页的美术**全部烘在** `福利窗口.tscn` 里
## （生成器 `开发工具/生成福利窗口场景.py`，坐标逐条取自原版 AS3），所以这里不再
## 运行时贴面板皮肤 / 贴页签皮肤 / 用代码摆标签 —— 那些会把烘好的主题和坐标顶掉，
## 编辑器里看到的样子就不是运行时的样子。
##
## 页签 ↔ 子页（**不能按类名猜**，对应关系取各自 Pane 的构造）：
##   0 每日签到 PrizeCheckInPanel · 1 线上有礼 PrizeOnlinePane2 · 2 首杀礼包 PrizeFirstCZWindow
##   3 活动奖励 PrizeCompensatoryPane · 4 限时大奖 PrizeActivityPanel · 5 新服有礼 PrizeXinFuWindow
##
## 这里只剩两件事：① 切页签 ② 把只有运行期才知道的数填进烘好的节点。
func _render_prize_window() -> void:
	var page := _instantiate_page(福利场景)
	var 页签容器 := page.get_node("分页") as Control
	var 内容 := page.get_node("滚动区/内容") as VBoxContainer
	for index in 页签容器.get_child_count():
		var tab := 页签容器.get_child(index) as Button
		窗口.选页签(tab, index == _prize_tab)
		tab.pressed.connect(_set_prize_tab.bind(index))
		# 子页**按序号**取（顺序与页签一致），名字是用户会改的东西
		(内容.get_child(index) as Control).visible = index == _prize_tab
	# 子页序号 ↔ 原版 Pane 的对应见本函数头注释；下面按同一序号填运行期的数。
	match _prize_tab:
		0:
			_填签到(内容.get_child(0) as Control)
		1:
			_填线上有礼(内容.get_child(1) as Control)
		2:
			_填首杀礼包(内容.get_child(2) as Control)
		3:
			_填活动奖励(内容.get_child(3) as Control)
		4:
			_填限时大奖(内容.get_child(4) as Control)
		5:
			_填新服有礼(内容.get_child(5) as Control)


## 按路径挖字典（任一层不是字典就返回 null）—— `actions.each["0"].items` 这类深路径
## 一次写出来，省掉一长串 `x is Dictionary` 的嵌套强转。
func _挖(根: Variant, 路径: Array) -> Variant:
	var 当前: Variant = 根
	for 键 in 路径:
		if not (当前 is Dictionary):
			return null
		当前 = (当前 as Dictionary).get(键)
	return 当前


## `Variant` → int，非数字给兜底（`_挖` 挖空时是 null，别让 `int(null)` 参与路径）。
func _整(值: Variant, 兜底: int = 0) -> int:
	return int(值) if 值 is int or 值 is float or 值 is String else 兜底


## 充值活动的配置块（`1814` cmd 2）。离线/未进游戏时是空字典。
func _充值配置() -> Dictionary:
	var 配: Variant = _充值活动().get("config", {})
	return 配 if 配 is Dictionary else {}


## 子页所属的**场景根**：`物品提示框`/`装备提示框` 挂在那里，不在 `滚动区` 里 ——
## `ScrollContainer` 会裁剪子树，提示框必须能跑出可视区。沿父链向上找到带提示框的那层。
func _提示根(页: Node) -> Control:
	var 节: Node = 页
	while 节 != null:
		if 节.has_node("物品提示框"):
			return 节 as Control
		节 = 节.get_parent()
	return null


## 给物品格接原版悬停详情框。
##
## 真值：原版这四个子页悬停都弹 `MToolTipItem` —— 签到 `PrizeItemCell.showToolTip:153-156`，
## 首杀/限时/新服 `SimpleItemCell.as:220`。「线上有礼」那三档图标是 SWF 美术
## （`PrizeOnlinePane2` 的档位没有 ItemData），原版不弹，所以那边不接。
##
## 格子是场景里那层 40x40 底板（`*格`，`mouse_filter = 2`）；图标 `*图` 与数量 Label 压在
## 它上面且都是 IGNORE，抬底板这一层就够。STOP 的 Control 默认
## `mouse_force_pass_scroll_events = true`，滚轮照样交给外层 `ScrollContainer`。
func _接格子提示(页: Node, 格: Control, 物品id: int, 数量: int) -> void:
	if 格 == null or 物品id <= 0:
		return
	var 根 := _提示根(页)
	if 根 == null:
		return
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	格子提示框.接线(窗口, 根, 格, {"id": str(物品id), "quantity": 数量})


## 原版 `PrizeCheckInPanel.updateStatus(canCheck, accumulateDays)` + `PrizeCheckInCell.setStatus`：
## 目标行 = 今日未签则 累计+1、否则 累计；行<目标 已领取，行==目标且可签 「签到领奖」，
## 行>目标 置灰「未签到」。**未签到时按钮是 visible 的，只是 enabled=false**（:155-158）。
func _填签到(页: Control) -> void:
	var 累计 := int(_activity.state.get("check_in_streak", 0))
	var 今日已签 := int(_activity.state.get("last_check_in_day", -1)) == _today()
	var 目标 := 累计 if 今日已签 else 累计 + 1
	for 天 in range(1, 8):
		var 行 := 页.get_node("第%d天" % 天) as Control
		var 钮 := 行.get_node("领取") as Button
		var 章 := 行.get_node("已领取") as TextureRect
		钮.pressed.connect(_check_in)
		if 天 < 目标 or (天 == 目标 and 今日已签):
			钮.visible = false
			章.visible = true
		elif 天 == 目标:
			钮.text = "签到领奖"          # PRIZE_QIANDAOlINGJIANG
			钮.disabled = false
			钮.visible = true
			章.visible = false
		else:
			钮.text = "未签到"            # PRIZE_QIANDAO
			钮.disabled = true
			钮.visible = true
			章.visible = false
	# 悬停详情框（用户 2026-11-01 报修：图标放上去没有详情框）。
	# 数据源与原版同一条：`Gift.everyday.dayN`（本地 `数据/礼包.json`），按配置顺序对格子序号。
	for 天 in range(1, 8):
		var 签到行 := 页.get_node("第%d天" % 天) as Control
		var 奖励 := 游戏数据.每日签到奖励(天)
		for 序 in 奖励.size():
			_接格子提示(页, 签到行.get_node_or_null("物品%d格" % (序 + 1)) as Control,
				int((奖励[序] as Dictionary).get("itemId", 0)),
				int((奖励[序] as Dictionary).get("count", 1)))


## 福利/礼包（`1344`）的权威状态。离线或未进游戏时返回空字典。
func _礼包状态() -> Dictionary:
	return 窗口._backend.authoritative_gifts if 窗口._backend != null and bool(窗口._backend.in_game) else {}


## 充值活动（`1814`）的权威状态：config / limit / xinfu / first_kill 四块。
func _充值活动() -> Dictionary:
	return 窗口._backend.authoritative_czhuodong if 窗口._backend != null and bool(窗口._backend.in_game) else {}


## 原版 `PrizeOnlinePane2.setData(state)` —— 线上有礼（**按在线时长**三档，与活跃度无关）。
##
## 真值出处：`PrizeOnlinePane2.as:217-250`
##   `_prizeBtn.enabled = gainable`
##   时长文本 = `int(分钟/60) + "小时" + (分钟%60 ? 分钟%60 + "分钟" : "")`
##   三档图标：拿 `本周分钟/60` 依次比 `Gift.monthly` 的三档 `hours`，
##             **没到的那几档灰化**（`Style.getDisableFilter()` = 亮度灰化，不是变暗）
##   三档进度 = `本周小时 / 该档 hours`，>1 取 1
## 数据侧：`1344:4:<上周分钟>:<上周奖励>:<本周分钟>:<gainable>`（服务端 `_send_monthly_online_reward`）。
func _填线上有礼(页: Control) -> void:
	var 线: Dictionary = _礼包状态().get("monthly", {})
	var 上周分钟 := int(线.get("last_week_minutes", 0))
	var 本周分钟 := int(线.get("week_minutes", 0))
	var 上周奖励 := int(线.get("last_week_reward", 0))
	var 可领 := bool(线.get("gainable", false))
	(页.get_node("上周时长") as LineEdit).text = _时长文本(上周分钟)
	(页.get_node("本周时长") as LineEdit).text = _时长文本(本周分钟)
	# 原版文案是「[上周获得N点券奖励]」+ 可领时再接一段蓝色的「[未获奖]」——
	# 字面看着别扭，但 `PrizeOnlinePane2.as:221-223` 就是这么拼的（`gainable` 为真才补后半段）。
	(页.get_node("上周获奖") as RichTextLabel).text = 富文本.译文为BBCode(
		"<font size='12' color='#00ff00'>[上周获得%d点券奖励]</font><font size='12' color='#1e90ff'>%s</font>" % [
			上周奖励, "[未获奖]" if 可领 else "",
		])
	var 钮 := 页.get_node("领取上周") as Button
	钮.disabled = not 可领
	钮.pressed.connect(func():
		if 窗口._backend != null:
			窗口._backend.request_gift_claim("monthly"))
	var 档位 := 游戏数据.线上有礼档位()
	var 本周小时 := float(本周分钟) / 60.0
	for index in 3:
		var 门槛 := float(档位[index].get("hours", 0)) if index < 档位.size() else 0.0
		var 图标 := 页.get_node("档%d图标" % index) as TextureRect
		图标.material = null if 本周小时 >= 门槛 else 窗口.禁用灰度材质()
		_设进度(页, index, 0.0 if 门槛 <= 0.0 else minf(1.0, 本周小时 / 门槛))


## 时长文案。原版 `PrizeOnlinePane2.as:225-226`：整小时就只写小时，有零头才补分钟。
func _时长文本(分钟: int) -> String:
	var 时 := 分钟 / 60
	var 余 := 分钟 % 60
	return "%d小时%s" % [时, "" if 余 == 0 else "%d分钟" % 余]


## 进度条的"按比例露出"。**不是压扁贴图** —— 原版 `PrizeOnlineProgress.percent` 改的是
## 蒙版的宽度（`maskMc.width`），所以这里用 `region_rect` 裁源图、同时把节点矩形收窄到
## 与裁出来的那一段等宽，效果与"从左往右露出来"一致。
## 满宽从同排的 `档N进度底` 取 —— 两者在烘场景时是同一个矩形。
func _设进度(页: Control, index: int, 比例: float) -> void:
	var 进度 := 页.get_node("档%d进度" % index) as TextureRect
	var 底 := 页.get_node("档%d进度底" % index) as TextureRect
	if 进度 == null or 进度.texture == null or 底 == null:
		return
	var 裁 := clampf(比例, 0.0, 1.0)
	进度.visible = 裁 > 0.0
	# ⚠️ `TextureRect` 在 Godot 4.7 **没有 `region_enabled` / `region_rect`**
	#    —— 本机 4.7.1 实测：这两个属性**只在 `Sprite2D` / `Sprite3D` 上**
	#    （`TextureButton`、`NinePatchRect` 也没有，见 `开发工具/Godot_API陷阱探针.gd`）——
	#    上一版照 Sprite 的印象写，
	#    运行期会报 "Invalid assignment of property or key 'region_enabled'"，
	#    **把 `_填线上有礼` 从这一句起整个打断**（三档进度没画、后续代码也不执行）。
	#    这里改用 `AtlasTexture` 裁源图 + 收窄节点矩形，等价于原版 `maskMc.width` 的"露出一段"。
	# 原始贴图与"满宽"各存一份 meta：节点矩形每次都会被收窄，不留底会越算越小。
	# ⚠️ **meta 的键必须是 ASCII 标识符** —— `set_meta("原图", …)` 会被 Godot 拒掉并刷
	#    "Invalid metadata identifier"，`get_meta` 于是每次都拿到默认值（本项目第三次踩这条）。
	# ⚠️ 用 `get_meta(名, 默认值)` 取 —— `var x: float = 进度.get_meta(名)` 在键不存在时
	#    会把 `null` 赋给 float 并报 "Trying to assign value of type 'Nil'"。
	var 原图: Texture2D = 进度.get_meta("src_tex", 进度.texture)
	var 满宽: float = 进度.get_meta("full_w", 底.size.x)
	进度.set_meta("src_tex", 原图)
	进度.set_meta("full_w", 满宽)
	var 图 := 进度.texture as AtlasTexture
	if 图 == null or 图.atlas != 原图:
		图 = AtlasTexture.new()
		图.atlas = 原图
		进度.texture = 图
	图.region = Rect2(0.0, 0.0, 原图.get_width() * 裁, 原图.get_height())
	进度.size.x = 满宽 * 裁


## 原版 `PrizeFirstCZWindow.updateStatus`（`:234-250`）+ `lingQuHandler`（`:254-267`）：
##   原版读 `firstCZData.chargeTotal` 填「您累计充值 __ 元宝」、充值额 > 0 才可领；
##   2026-10-28 按用户口径去掉充值，2026-10-31 用户再定口径：这一页是**首杀礼包**，
##   条件 = 击杀任意 BOSS 一只（`bossKills >= 1`），与限时大奖同一把尺子。
## 数据侧：`1814` cmd 4 的 `{active, bossKills}`（桶名 `first_kill`）。
## ⚠️ 这一页读的是**充值活动**，不是礼包 —— 旧代码读 `authoritative_gifts.first_claimed`（那是首次登录礼包），
##    与本页是两回事，所以在线时永远显示"未领取"。
func _填首杀礼包(页: Control) -> void:
	var 首: Dictionary = _充值活动().get("first_kill", {})
	var 已领 := int(首.get("active", 0)) != 0
	var 达标 := int(首.get("bossKills", 0)) >= 1
	# 悬停详情框（用户 2026-11-01 报修）：左格是礼包本体（`config.fc.info.libaoId`），
	# 右格是礼包里发的物品（`config.fc.actions.each["0"].items`）—— 原版两格都是
	# `SimpleItemCell`，悬停就弹 `MToolTipItem`。
	var 配 := _充值配置()
	_接格子提示(页, 页.get_node_or_null("奖励框/礼包格格") as Control,
		_整(_挖(配, ["fc", "info", "libaoId"])), 1)
	var 包物: Variant = _挖(配, ["fc", "actions", "each", "0", "items"])
	if 包物 is Array and not (包物 as Array).is_empty() and (包物 as Array)[0] is Dictionary:
		var 首件 := (包物 as Array)[0] as Dictionary
		_接格子提示(页, 页.get_node_or_null("奖励框/奖励格区/奖励1格") as Control,
			_整(首件.get("id")), _整(首件.get("count"), 1))
	var 钮 := 页.get_node("奖励框/领取") as Button
	for 连 in 钮.pressed.get_connections():
		钮.pressed.disconnect(连["callable"])
	钮.text = "已领取" if 已领 else "领取奖励"
	# 没拿到状态、或还没杀过 BOSS 就把钮置灰 —— 不摆"看着能点、点了没反应"的空壳
	# （见 `_禁用无人认领的领取钮`）。
	钮.disabled = 已领 or not 达标
	if 钮.disabled:
		return
	钮.pressed.connect(func():
		if 窗口._backend != null:
			窗口._backend.request_czhuodong_gain_first_kill())


## 原版 `PrizeActivityPanel.onCzHuodong_updateStatus`（`:103-156`）+ `clickPrizeBtnHandler`（`:196-205`）：
##   `active == 0` 整页不画；
##   标题 = 「您活动期间（起-止）累计击杀BOSS数：」（原版是「累计充值」，本轮按用户口径改口径，
##         数字来自 cmd 1 的 `bossKills`，填进场景里改名后的 `击杀数` 输入框）；
##   累计档（9 个）：`enabled = statusTotal[i] > 0`；若 `detailTotal[i].count>0 且 curr>=count` → 「已领取」置灰；
##   额度档（4 个）：同上，但可点性是 `statusEach[i] != 0`。
## 数据侧：`1814` cmd 1 的 status（服务端 `_send_czhuodong_activity_status`）。
func _填限时大奖(页: Control) -> void:
	var 活: Dictionary = _充值活动().get("limit", {})
	if 活.is_empty() or int(活.get("active", 0)) == 0:
		_禁用无人认领的领取钮(页, ["累计", "额度"])
		return
	(页.get_node("击杀数") as LineEdit).text = str(int(活.get("bossKills", 0)))
	# 外面套 `[right]` 是因为**场景里烘的那行就是右对齐**（`[right]…[/right]`）—— 翻译完不加，
	# 数据一到标题就从右跳左，看着像闪了一下。
	(页.get_node("活动标题") as RichTextLabel).text = "[right]%s[/right]" % 富文本.译文为BBCode(
		"<font color='#00ff00'>您活动期间<font color='#ffffff'>（%s-%s）</font>累计击杀BOSS数：</font>" % [
			_活动日期(活.get("beginTime")), _活动日期(活.get("endTime")),
		])
	_填档位组(页, "累计", 活.get("statusTotal", []), 活.get("detailTotal", []), "total")
	_填档位组(页, "额度", 活.get("statusEach", []), 活.get("detailEach", []), "each")


## 限时大奖的一排档位。`状态表[i]` 决定可点性，`明细表[i]`（`{curr,count}`）决定是否已领。
func _填档位组(页: Control, 前缀: String, 状态表: Variant, 明细表: Variant, 类型: String) -> void:
	var 状态: Array = 状态表 if 状态表 is Array else []
	var 明细: Array = 明细表 if 明细表 is Array else []
	# 悬停详情框的奖品：`config.limit.actions.<total|each>[i].items`（原版这两排格子
	# 都是 `SimpleItemCell`，悬停弹 `MToolTipItem`）。
	var 档配置: Variant = _挖(_充值配置(), ["limit", "actions", 类型])
	for index in 状态.size():
		var 行 := 页.get_node_or_null("%s%d" % [前缀, index + 1]) as Control
		if 行 == null:
			continue
		if 档配置 is Array and index < (档配置 as Array).size():
			var 格件: Variant = _挖((档配置 as Array)[index], ["items"])
			if 格件 is Array:
				for 序 in (格件 as Array).size():
					if (格件 as Array)[序] is Dictionary:
						var 件 := (格件 as Array)[序] as Dictionary
						_接格子提示(页, 行.get_node_or_null("奖励%d格" % (序 + 1)) as Control,
							_整(件.get("id")), _整(件.get("count"), 1))
		var 钮 := 行.get_node_or_null("领取") as Button
		if 钮 == null:
			continue
		var 明: Dictionary = 明细[index] if index < 明细.size() and 明细[index] is Dictionary else {}
		var 已领 := int(明.get("count", 0)) > 0 and int(明.get("curr", 0)) >= int(明.get("count", 0))
		# ⚠️ 每次都先断开再连 —— 这一页会被反复重建，重复 connect 会让一次点击发多发一次协议。
		for 连 in 钮.pressed.get_connections():
			钮.pressed.disconnect(连["callable"])
		if 已领:
			钮.text = "已领取"
			钮.disabled = true
		else:
			钮.text = "领取奖励"
			钮.disabled = int(状态[index] if index < 状态.size() else 0) == 0
			var 档号 := index
			钮.pressed.connect(func(): _领限时大奖(类型, 档号, int(状态[档号])))


## 原版 `clickPrizeBtnHandler`：累计档可领次数为 0 时只给提示，不发协议。
func _领限时大奖(类型: String, 档号: int, 可领次数: int) -> void:
	if 窗口._backend == null:
		return
	if 类型 == "total" and 可领次数 <= 0:
		窗口._show_hint("总计可领取1次，目前的击杀数可领取0次，已领取完毕")
		return
	# ⚠️ 活动 id 读的是**本页**的配置块 `config.limit.info.id`（原版 `PrizeActivityPanel.as:204`
	#    传 `this._configure.info.id`，而 `_configure` 是按 `param1.path`＝"limit" 取的）。
	#    上一版误取了 `config.fc` —— fc 里没有 `id` 字段，靠兜底的 "1" 恰好撞上，属于运气。
	var 配置: Dictionary = (_充值活动().get("config", {}) as Dictionary).get("limit", {})
	# ⚠️ AMF3/JSON 通道把数字一律解成 float —— 直接 `str(1.0)` 得到 `"1.0"`，而服务端只认
	#    `"1"` / `"limit"` ⇒ 点了「领取奖励」服务端当成非法请求、静默重发状态，**奖励永远不到手**
	#    （用户 2026-10-31 报的就是这个）。数字先转 int 再转串；非数字（如 "limit"）原样送。
	var 原id: Variant = (配置.get("info", {}) as Dictionary).get("id", 1)
	var 活动id := str(int(原id)) if typeof(原id) == TYPE_FLOAT or typeof(原id) == TYPE_INT else str(原id)
	窗口._backend.request_czhuodong_gain(活动id, 类型, 档号)


## 原版 `formatActivityDate`（`:158-170`）：ISO 串取前 10 位，`-` 换成 `.`。
func _活动日期(值: Variant) -> String:
	var 文本 := String(值)
	if 文本.length() < 10:
		return 文本
	return 文本.substr(0, 10).replace("-", ".")


## 原版 `PrizeXinFuWindow.updateStatus`（`:232-250`）+ `clickHandler`（`:254-262`）：
##   每档：`curr >= count 且 count > 0` → 「已领取」置灰；否则「领取奖励」；
##   点击：`count == 0`（未达条件）只提示 `PRIZEXINFU_NOENOUGH_CONDITION`，否则
##         `requestCzHuodong_gainXf(type, gainId)`。
## 数据侧：`1814` cmd 3 的 `detailEach`（每档）/ `detailRank`（排行档）。
## ⚠️ 原版 `EACH` 那一档还会在行内画「可领取 __ 点券 点」三个控件（`PrizeXinFuWindow.as:272-289`）——
##    本轮按用户口径去掉点券，场景里那三个节点已删，这里也就不再填数（服务端同时不再下发 `cashbindRemaining`）。
func _填新服有礼(页: Control) -> void:
	var 新: Dictionary = _充值活动().get("xinfu", {})
	if 新.is_empty():
		# ⚠️ 前缀是**父节点名**（`每档1` / `排行2`），不是整条路径 —— 写成 `大奖框/每档`
		#    会一个都匹配不上（这条是被 `功能入口回归测试` 那新加的空壳断言抓出来的）。
		_禁用无人认领的领取钮(页, ["每档", "排行"])
		return
	var 明细: Dictionary = 新.get("detailEach", {}) if 新.get("detailEach") is Dictionary else {}
	var 排行: Dictionary = 新.get("detailRank", {}) if 新.get("detailRank") is Dictionary else {}
	_填新服一行(页, "每档1", 明细.get("6000057", {}), "EACH", 6000057)
	_填新服一行(页, "排行2", 排行.get("6000058", {}), "RANK", 6000058)


## 新服有礼的一行。`状态` 是服务端那条 `{curr, count}`。
func _填新服一行(页: Control, 行名: String, 状态: Variant, 类型: String, 奖励id: int) -> void:
	var 行 := 页.get_node_or_null("大奖框/%s" % 行名) as Control
	if 行 == null:
		return
	# 悬停详情框：那一格画的就是这一档发的物品
	# （`config._xinfu.actions.<each|rank>.<奖励id>.items`，原版是 `SimpleItemCell`）。
	var 组 := "each" if 类型 == "EACH" else "rank"
	var 档物: Variant = _挖(_充值配置(), ["_xinfu", "actions", 组, str(奖励id), "items"])
	if 档物 is Array and not (档物 as Array).is_empty() and (档物 as Array)[0] is Dictionary:
		var 件 := (档物 as Array)[0] as Dictionary
		_接格子提示(页, 行.get_node_or_null("物品0格") as Control,
			_整(件.get("id")), _整(件.get("count"), 1))
	var 钮 := 行.get_node_or_null("领取") as Button
	if 钮 == null:
		return
	var 条: Dictionary = 状态 if 状态 is Dictionary else {}
	var 所需 := int(条.get("count", 0))
	var 已做 := int(条.get("curr", 0))
	var 已领 := 所需 > 0 and 已做 >= 所需
	for 连 in 钮.pressed.get_connections():
		钮.pressed.disconnect(连["callable"])
	钮.text = "已领取" if 已领 else "领取奖励"
	钮.disabled = 已领
	钮.pressed.connect(func(): _领新服有礼(类型, 奖励id, 所需))


## 原版 `PrizeXinFuWindow.clickHandler`：条件没达成就只提示，不发协议。
func _领新服有礼(类型: String, 奖励id: int, 所需: int) -> void:
	if 窗口._backend == null:
		return
	if 所需 <= 0:
		窗口._show_hint("很抱歉，您尚未达到领取条件")
		return
	窗口._backend.request_czhuodong_gain_xinfu(类型, 奖励id)


## 把「数据还没到」时**烘死的可点态**统一摁成置灰。
##
## 为什么需要它：这几个按钮在场景里烘的是 `disabled = false`（见 `福利窗口.tscn`），
## 而各页的填充函数在拿不到数据时会**直接 return** —— 于是按钮既没置灰、也没接处理器，
## 用户看到的是"这个我能点"，点下去**什么都不发生**（连提示都没有）。
## 2026-09-27 用户报"这些面板还是不能领取奖励，即便已经符合条件"，这一批空壳就是可疑来源之一。
## 宁可置灰 —— 灰着点不动至少是**诚实的反馈**，而静默无反应会被当成 bug。
##
## ⚠️ 只置灰、不接处理器：数据到了自然会重画（`功能窗口._on_reward_state_received`
##    → `_refresh_current`），那时再按真实状态决定可点性与文案。
func _禁用无人认领的领取钮(页: Control, 前缀表: Array) -> void:
	for 节点 in 页.find_children("*", "Button", true, false):
		var 钮 := 节点 as Button
		if 钮 == null:
			continue
		for 前缀 in 前缀表:
			if String(钮.get_parent().name).begins_with(String(前缀)):
				钮.disabled = true
				break


## 活动奖励（原版 `PrizeCompensatoryPane`）。它画的是 `activities` 里的活动列表，
## 而烘好的场景里**一个活动格子都没有**（只有一句「暂无奖励」），所以这里只能：
##   有 `activities` → 把「暂无奖励」藏起来（列表暂时画不出来，见交接文档待办）；
##   没有          → 显示「暂无奖励」。
## ⚠️ 不要在这里用代码摆格子 —— 本页的美术是烘死的，运行期摆控件会与编辑器里看到的不是一回事。
func _填活动奖励(页: Control) -> void:
	var 提示 := 页.get_node_or_null("暂无奖励") as Label
	if 提示 == null:
		return
	var 限: Dictionary = _充值活动().get("limit", {})
	var 有活动: Variant = 限.get("activities") if 限 is Dictionary else null
	提示.visible = not (有活动 is Dictionary and not (有活动 as Dictionary).is_empty())

## 亲热天堂（小地图「藏宝图」，NPC 21 卡卡西）——原版 `TreasureBoxWindow` 的四态机器：
##   0 待显示（按钮「显示宝贝」）/ 1 已开出（「开始」）/ 2 待停止（「停止」）/ -1 领取（「领取」）
## 协议走 `FudaiProcessor` 的 17 查询 / 18 开箱 / 19 开始 / 20 领取（服务端 `handle_fudai` 已实现）。
## 过去这里只有画皮：`_explore_treasure` 与 `功能窗口._explore_treasure` 互相指成死链，点按钮只报无效调用。
const 藏宝说明 := {
	2: "送给卡卡西一本《亲热天堂1》，有几率兑换到：\n3至5星紫色装备、修炼灵符（小）/修炼灵符（中）、秘笈残卷或4阶通灵兽",
	3: "送给卡卡西一本《亲热天堂2》，有几率兑换到：\n3至7星紫色装备、修炼灵符（小）/修炼灵符（中）、秘笈残卷或5阶通灵兽",
	4: "送给卡卡西一本《亲热天堂3》，有几率兑换到：\n3至10星紫色装备、修炼灵符（小）/修炼灵符（中）、秘笈残卷或6阶通灵兽",
}
## 三档宝书的物品号 = `数据/宝盒.json` 的 `baoxiang[类型].itemid`（原版 `StringTool.getBaoXiangItemIdFromType`）。
const 藏宝书 := {2: "15008002", 3: "15008003", 4: "15008004"}
const 藏宝流程 := "兑换流程：准备好亲热天堂->选择相应的兑换类别->\n点击“显示宝贝”按钮->开始兑换->点击“停止”选中"

var _藏宝页: Control
var _藏宝格: Array[Control] = []
var _宝藏状态 := 0
var _宝藏类型 := -1
var _宝藏背包格 := -1
var _宝藏候选: Array = []
var _宝藏奖品: Dictionary = {}
var _宝藏落点 := -1
var _藏宝亮格 := -1
var _宝藏刻度 := 0
var _藏宝定时: Timer
var _藏宝自动开始待发 := false
## 「显示宝贝」发出去、还没等到回帧。原版 `TreasureBoxWindow.onClickStartBtn:369-372` 点下去先
## `setBaowuBtnEanbled(false)`；本工程不灰按钮（回帧可能永远不来），改成**回帧不是「已开出」就说话**
## —— 否则服务端一拒，屏幕一动不动，用户只能报「点了没反应」。
var _藏宝待开 := false

func _render_treasure() -> void:
	_停藏宝动画()
	_藏宝待开 = false
	var page := _instantiate_page(亲热天堂场景)
	_藏宝页 = page
	_藏宝格.clear()
	_藏宝亮格 = -1
	_configure_original_panel(page.get_node("内容底") as Panel, true)
	_configure_original_panel(page.get_node("宝物区") as Panel)
	_configure_original_panel(page.get_node("角色框") as Panel)
	# 12 = 原版真值：`TreasureBoxWindow.as:270/277` 这两枚都是裸 `new TextField()`，
	# 没有另建 TextFormat ⇒ 吃 Flash 默认 TextFormat.size = 12（同 §「MLabel 默认 12」那条口径）。
	_configure_label(page.get_node("兑换说明") as Label, 12, Color("#ff9100"))
	_configure_label(page.get_node("兑换流程") as Label, 12, Color("#00ff00"))
	_configure_label(page.get_node("亲热天堂标签") as Label, 12, Color("#ff9100"))
	_configure_label(page.get_node("礼品标签") as Label, 12, Color("#ff9100"))
	(page.get_node("兑换流程") as Label).text = 藏宝流程
	var reward_grid := page.get_node("宝物格") as GridContainer
	for slot in reward_grid.get_children():
		var 框 := slot as TextureRect
		框.texture = load(物品格贴图) as Texture2D
		_补藏宝格子(框)
		_藏宝格.append(框)
	_补藏宝图标格(page.get_node("亲热天堂格") as TextureRect)
	_补藏宝图标格(page.get_node("礼品格") as TextureRect)
	var explore := page.get_node("显示宝贝") as Button
	_configure_standard_button(explore)
	explore.pressed.connect(_寻宝按钮)
	for 号 in [2, 3, 4]:
		var 书钮 := page.get_node("亲热天堂%d" % (号 - 1)) as TextureButton
		if 书钮 != null:
			书钮.pressed.connect(_选藏宝书.bind(号))
	var auto_claim := page.get_node("兑换后自动领取") as CheckBox
	auto_claim.button_pressed = bool(_session.game_settings.get("treasure_auto_claim", false))
	auto_claim.toggled.connect(_set_check.bind("treasure_auto_claim"))
	var auto_start := page.get_node("自动开始下一轮") as CheckBox
	auto_start.button_pressed = bool(_session.game_settings.get("treasure_auto_start", false))
	auto_start.toggled.connect(_set_check.bind("treasure_auto_start"))
	_接藏宝后端()
	_恢复藏宝书()
	_刷新藏宝界面()
	# 进场先要一次 17（服务端会回 16 个候选预览；`FudaiProcessor` 的 XUNBAO）。
	var 后端 := _会话后端()
	if 后端 != null and _宝藏状态 == 0:
		后端.call("request_treasure_show")

func _会话后端() -> Node:
	return 窗口.get("_backend") as Node

func _接藏宝后端() -> void:
	var 后端 := _会话后端()
	if 后端 == null or not 后端.has_signal("treasure_state_received"):
		return
	if not 后端.treasure_state_received.is_connected(_收到藏宝状态):
		后端.treasure_state_received.connect(_收到藏宝状态)

func _补藏宝格子(框: TextureRect) -> void:
	var 图标 := 框.get_node_or_null("图标") as TextureRect
	if 图标 == null:
		图标 = TextureRect.new()
		图标.name = "图标"
		图标.position = Vector2(3, 3)
		图标.size = Vector2(34, 34)
		图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
		框.add_child(图标)
	var 数量 := 框.get_node_or_null("数量") as Label
	if 数量 == null:
		数量 = Label.new()
		数量.name = "数量"
		数量.position = Vector2(2, 22)
		数量.size = Vector2(37, 18)
		数量.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		数量.add_theme_font_size_override("font_size", 12)
		数量.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		数量.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		数量.add_theme_constant_override("outline_size", 2)
		数量.mouse_filter = Control.MOUSE_FILTER_IGNORE
		框.add_child(数量)
	var 选中 := 框.get_node_or_null("选中") as Control
	if 选中 == null:
		# 原版是 `Mc_YellowIcon` 位图；本工程没有这张素材，又不能在脚本里现造
		# `StyleBoxFlat`（`测试/UI资源回归测试.gd:105` 钉死：样式数据只能来自
		# `素材/界面/原版主题.tres`）⇒ 用四条 2px `ColorRect` 拼一个空心黄框。
		选中 = Control.new()
		选中.name = "选中"
		选中.position = Vector2(-3, -3)
		选中.size = Vector2(46, 46)
		选中.mouse_filter = Control.MOUSE_FILTER_IGNORE
		选中.visible = false
		var 黄 := Color("#ffd24a")
		for 名 in ["上边", "下边", "左边", "右边"]:
			var 线 := ColorRect.new()
			线.name = 名
			线.color = 黄
			线.mouse_filter = Control.MOUSE_FILTER_IGNORE
			match 名:
				"上边":
					线.position = Vector2.ZERO
					线.size = Vector2(46, 2)
				"下边":
					线.position = Vector2(0, 44)
					线.size = Vector2(46, 2)
				"左边":
					线.position = Vector2.ZERO
					线.size = Vector2(2, 46)
				"右边":
					线.position = Vector2(44, 0)
					线.size = Vector2(2, 46)
			选中.add_child(线)
		框.add_child(选中)

func _补藏宝图标格(框: TextureRect) -> void:
	if 框 == null:
		return
	框.texture = load(物品格贴图) as Texture2D
	var 图标 := 框.get_node_or_null("图标") as TextureRect
	if 图标 == null:
		图标 = TextureRect.new()
		图标.name = "图标"
		图标.position = Vector2(3, 3)
		图标.size = Vector2(34, 34)
		图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
		框.add_child(图标)
	var 数量 := 框.get_node_or_null("数量") as Label
	if 数量 == null:
		数量 = Label.new()
		数量.name = "数量"
		数量.position = Vector2(2, 22)
		数量.size = Vector2(37, 18)
		数量.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		数量.add_theme_font_size_override("font_size", 12)
		数量.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		数量.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		数量.add_theme_constant_override("outline_size", 2)
		数量.mouse_filter = Control.MOUSE_FILTER_IGNORE
		框.add_child(数量)

func _填藏宝格(框: Control, 条目: Dictionary) -> void:
	var 图标 := 框.get_node_or_null("图标") as TextureRect
	var 数量 := 框.get_node_or_null("数量") as Label
	if 图标 == null or 数量 == null:
		return
	if 条目.is_empty():
		图标.texture = null
		数量.text = ""
		装备品质.挂覆盖层(框, {})
		return
	图标.texture = 游戏数据.item_icon(String(条目.get("id", "")))
	var 数量值 := int(条目.get("quantity", 1))
	数量.text = str(数量值) if 数量值 > 1 else ""
	# 候选可能带 `aptitude`（亲热天堂3 紫装）；非装备条目没有这个键 ⇒ 什么都不叠。
	装备品质.挂覆盖层(框, 条目)

func _找书格位(类型: int) -> int:
	if not 藏宝书.has(类型):
		return -1
	var 书号 := String(藏宝书[类型]).pad_zeros(8)
	for i in range(_session.inventory.size()):
		var 条目: Dictionary = _session.inventory[i] as Dictionary
		if 条目.is_empty():
			continue
		if String(条目.get("id", "")).pad_zeros(8) == 书号 and int(条目.get("quantity", 0)) > 0:
			return i + 1
	return -1

## 进页时把「当前类型」恢复成背包里第一本宝书（原版 `setSongguoData`：2→3→4 找第一本）。
func _恢复藏宝书() -> void:
	if _宝藏类型 > 0 and _找书格位(_宝藏类型) > 0:
		_宝藏背包格 = _找书格位(_宝藏类型)
		return
	for 号 in [2, 3, 4]:
		if _找书格位(号) > 0:
			_宝藏类型 = 号
			_宝藏背包格 = _找书格位(号)
			return
	_宝藏类型 = -1
	_宝藏背包格 = -1

func _选藏宝书(类型: int) -> void:
	if _宝藏状态 != 0:
		return
	_宝藏类型 = 类型
	_宝藏背包格 = _找书格位(类型)
	_宝藏候选 = []
	_宝藏奖品 = {}
	_刷新藏宝界面()

func _藏宝自动领取() -> bool:
	var 勾 := _藏宝页.get_node_or_null("兑换后自动领取") as CheckBox
	return 勾 != null and 勾.button_pressed

func _藏宝自动开始() -> bool:
	var 勾 := _藏宝页.get_node_or_null("自动开始下一轮") as CheckBox
	return 勾 != null and 勾.button_pressed

func _刷新藏宝界面() -> void:
	if _藏宝页 == null:
		return
	var 说明 := _藏宝页.get_node_or_null("兑换说明") as Label
	if 说明 != null:
		说明.text = String(藏宝说明.get(_宝藏类型, String(藏宝说明[2])))
	var 书格 := _藏宝页.get_node_or_null("亲热天堂格") as TextureRect
	if 书格 != null:
		if _宝藏类型 > 0 and 藏宝书.has(_宝藏类型):
			var 格位 := _找书格位(_宝藏类型)
			var 数量值 := 0
			if 格位 > 0:
				数量值 = int((_session.inventory[格位 - 1] as Dictionary).get("quantity", 1))
			_填藏宝格(书格, {"id": String(藏宝书[_宝藏类型]), "quantity": 数量值})
		else:
			_填藏宝格(书格, {})
	var 礼格 := _藏宝页.get_node_or_null("礼品格") as TextureRect
	if 礼格 != null:
		_填藏宝格(礼格, _宝藏奖品)
	var 钮 := _藏宝页.get_node_or_null("显示宝贝") as Button
	if 钮 != null:
		var 文本 := "显示宝贝"
		match _宝藏状态:
			1: 文本 = "开始"
			2: 文本 = "停止"
			-1: 文本 = "领取"
		钮.text = 文本
		钮.disabled = _宝藏状态 == 0 and (_宝藏类型 < 0 or _宝藏背包格 < 1)
		for 号 in [2, 3, 4]:
			var 书钮 := _藏宝页.get_node_or_null("亲热天堂%d" % (号 - 1)) as TextureButton
			if 书钮 != null:
				书钮.disabled = _宝藏状态 != 0
	_摆藏宝候选()

func _摆藏宝候选() -> void:
	for i in range(_藏宝格.size()):
		var 框 := _藏宝格[i]
		var 选中 := 框.get_node_or_null("选中") as Control
		if 选中 != null:
			选中.visible = _宝藏状态 == 2 and i == _藏宝亮格
		if i < _宝藏候选.size():
			_填藏宝格(框, _宝藏候选[i])
		else:
			_填藏宝格(框, {})

func _寻宝按钮() -> void:
	if _藏宝页 == null:
		return
	var 后端 := _会话后端()
	if 后端 == null:
		_通知("亲热天堂需要联网后使用")
		return
	match _宝藏状态:
		0:
			if _宝藏类型 < 0 or _宝藏背包格 < 1:
				_通知("背包里没有可用的亲热天堂")
				return
			_藏宝待开 = true
			后端.call("request_treasure_open", _宝藏类型, _宝藏背包格)
		1:
			后端.call("request_treasure_start")
		2:
			_停藏宝动画()
			_藏宝定住()
		_:
			_藏宝领取()

func _藏宝领取() -> void:
	var 后端 := _会话后端()
	if 后端 != null:
		后端.call("request_treasure_gain")

func _通知(文本: String) -> void:
	if _session.has_signal("notification_requested"):
		_session.notification_requested.emit(文本)

func _收到藏宝状态(状态: Dictionary) -> void:
	# 只在「刚点过显示宝贝」这一帧上判落空，别把进页时那次 17 查询也算进去。
	var 待开 := _藏宝待开
	_藏宝待开 = false
	if _藏宝页 == null:
		return
	var 动作 := int(状态.get("action", 0))
	if 动作 == 18:
		_宝藏状态 = 2
		_宝藏落点 = int(状态.get("index", -1))
		_宝藏刻度 = 0
		_刷新藏宝界面()
		_开始藏宝动画()
		return
	var 新状态 := int(状态.get("state", 0))
	_宝藏状态 = 新状态
	var 新候选: Variant = 状态.get("candidates", [])
	if 新候选 is Array and not (新候选 as Array).is_empty():
		_宝藏候选 = 新候选
	var 新类型 := int(状态.get("type", -1))
	if 新类型 >= 2 and 新类型 <= 4:
		_宝藏类型 = 新类型
	_宝藏奖品 = 状态.get("gained", {}) if 状态.get("gained", {}) is Dictionary else {}
	if 新状态 == 1 or 新状态 == 2:
		# 开箱成功后书已被服务端扣掉，别再重算格位。
		pass
	elif 新状态 == 0:
		_宝藏奖品 = {}
		_宝藏落点 = -1
		_藏宝亮格 = -1
		_宝藏背包格 = _找书格位(_宝藏类型)
	_停藏宝动画()
	_刷新藏宝界面()
	if 待开 and 新状态 != 1 and 新状态 != 2:
		_通知("没能开箱：那本亲热天堂已经不在原来的格位了，重开一次藏宝图再试")
	if 新状态 == 1 and _藏宝自动开始待发:
		_藏宝自动开始待发 = false
		var 后端 := _会话后端()
		if 后端 != null:
			后端.call("request_treasure_start")
	elif 新状态 == 0 and _藏宝自动开始() and _宝藏背包格 > 0:
		_藏宝自动开始待发 = true
		var 后端2 := _会话后端()
		if 后端2 != null:
			后端2.call("request_treasure_open", _宝藏类型, _宝藏背包格)

func _开始藏宝动画() -> void:
	if _藏宝页 == null:
		return
	if _藏宝定时 == null:
		_藏宝定时 = Timer.new()
		_藏宝定时.name = "藏宝定时"
		_藏宝定时.wait_time = 0.03
		_藏宝定时.one_shot = false
		_藏宝页.add_child(_藏宝定时)
		_藏宝定时.timeout.connect(_藏宝滴答)
	_藏宝定时.start()

func _停藏宝动画() -> void:
	if _藏宝定时 != null and is_instance_valid(_藏宝定时):
		_藏宝定时.stop()

func _藏宝滴答() -> void:
	if _宝藏状态 != 2 or _藏宝格.is_empty():
		return
	_宝藏刻度 += 1
	var 旧 := _藏宝亮格
	_藏宝亮格 = randi() % _藏宝格.size()
	if 旧 >= 0 and 旧 < _藏宝格.size():
		var 旧选中 := _藏宝格[旧].get_node_or_null("选中") as Control
		if 旧选中 != null:
			旧选中.visible = false
	var 新选中 := _藏宝格[_藏宝亮格].get_node_or_null("选中") as Control
	if 新选中 != null:
		新选中.visible = true
	if _藏宝自动开始() and _宝藏刻度 > 10:
		_停藏宝动画()
		_藏宝定住()

## 「停止」定格：候选第 index 个就是奖品（原版 `setAwardData`）。
func _藏宝定住() -> void:
	_宝藏状态 = -1
	if _宝藏落点 >= 0 and _宝藏落点 < _宝藏候选.size():
		_宝藏奖品 = _宝藏候选[_宝藏落点]
	_刷新藏宝界面()
	if _藏宝自动领取():
		var 树: SceneTree = 窗口.get_tree()
		if 树 != null:
			await 树.create_timer(0.5).timeout
			if is_instance_valid(_藏宝页) and _宝藏状态 == -1:
				_藏宝领取()

## 「宝石工艺」窗（`StoneWindow`）**整扇搬进 `功能窗口._render_mining`** 了（2026-10-03 实装轮）：
## 合成页要走真协议（`requestMergeStone`）、要按格位现读放置态、要接 1042 回包摆三格，
## 状态全在宿主上，放在这里反而多一层转发。这里只留一句话指路，别再往回搬。

## 「首领」窗（`WangBossWindow` 573×324）**整扇搬到独立的 `脚本/界面/窗口/首领窗口.gd`**（2026-10-03
## 合并另一位开发者的首领页包）：11 条 BossWang 真表 + 三卡翻页 + 三档钮态 + 两个 tooltip。
## 旧实现在这里的三张卡是**编的数据**（水木/再不斩/白 硬名字硬等级）。指路，别再往回搬。
