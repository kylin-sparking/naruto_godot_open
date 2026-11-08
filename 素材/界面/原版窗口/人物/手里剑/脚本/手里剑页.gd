extends Control
## 手里剑页 —— 还原 Flash ShouLiJianPanel 的美术布局与纯 UI 交互。
##
## 职责边界（群主定的）：只管 UI 与按钮交互，不接协议。
## 对外只发五个信号，由 人物窗口.gd 转成既有调用：
##   启用切换(新值:bool) / 提速请求(全部:bool) / 突破请求() / 购买请求(物品id)
##   / 失败继续切换(已勾)
## 「提升速度 / 突破瓶颈」按钮按原版规则打开两个屏幕级弹窗（同 八门 突破瓶颈按钮 的做法：
## 搬到 屏幕弹窗层 + 整屏暗幕 + 居中于人物窗口）。

signal 启用切换(新值: bool)
signal 提速请求(全部: bool)
signal 突破请求()
signal 购买请求(物品id: String)
## 突破弹窗里「失败后自动继续」那一勾（原版 `_failCheckBox` 的 CLICK）。
signal 失败继续切换(已勾: bool)

const 数据 := preload("res://素材/界面/原版窗口/人物/手里剑/脚本/手里剑数据.gd")
## 等级条是原版 `ShouLiJianWindow` 的那根 MBar ⇒ 0.5s 补间（真值 `真值/窗口/进度条补间.md` §⑤）。
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")

# —— 服务端状态（只读展示）——
var _阶段 := 1
var _等级 := 1        # 全局等级 1..28（原版语义）
var _熟练度 := 0
## 突破瓶颈失败累积的幸运值（服务端 `1817:1:<值>`，`JingMaiSource.shouLiJianXingYunValue`）。
var _幸运值 := 0
var _已启用 := false
var _触发几率 := 0     # 服务端 ratio，0 时回退到表内基础值
var _攻击力 := 0
var _预览阶 := 0       # 0 = 还没刷过，首次跟随 _阶段

@onready var _当前使用: Label = get_node("当前信息/当前使用/值")
@onready var _当前进度: Label = get_node("当前信息/当前进度/值")
@onready var _当前等级: Label = get_node("当前信息/当前等级/值")
@onready var _当前触发: Label = get_node("当前信息/当前触发几率/值")
@onready var _启用复选框: TextureButton = get_node("当前信息/启用复选框")
@onready var _手里剑图标: TextureRect = get_node("详情面板/手里剑图标")
@onready var _上一页: TextureButton = get_node("详情面板/上一页")
@onready var _下一页: TextureButton = get_node("详情面板/下一页")
@onready var _页码: Label = get_node("详情面板/页码")
@onready var _名称值: Label = get_node("详情面板/名称/值")
@onready var _品阶值: Label = get_node("详情面板/品阶/值")
@onready var _进度值: Label = get_node("详情面板/修炼进度/值")
@onready var _等级条: ProgressBar = get_node("详情面板/修炼等级")
@onready var _等级条文字: Label = get_node("详情面板/修炼等级/值")
@onready var _提升按钮: Button = get_node("详情面板/提升速度")
@onready var _突破按钮: Button = get_node("详情面板/突破瓶颈")
@onready var _获得方式值: Label = get_node("详情面板/获得方式值")
@onready var _攻击能力值: Label = get_node("详情面板/攻击能力值")
@onready var _攻击距离值: Label = get_node("详情面板/攻击距离值")
@onready var _目标数量值: Label = get_node("详情面板/攻击目标数量值")
@onready var _触发几率值: Label = get_node("详情面板/触发几率值")
@onready var _特殊说明: RichTextLabel = get_node("详情面板/特殊能力说明")
@onready var _技能图标: Array[TextureRect] = [
	get_node("详情面板/技能图标1") as TextureRect,
	get_node("详情面板/技能图标2") as TextureRect,
	get_node("详情面板/技能图标3") as TextureRect]
@onready var _提速弹窗: Control = get_node("修炼提速弹窗")
@onready var _突破弹窗: Control = get_node("手里剑突破瓶颈弹窗")


func _ready() -> void:
	(get_node("详情面板/上一页") as TextureButton).pressed.connect(_翻预览阶.bind(-1))
	(get_node("详情面板/下一页") as TextureButton).pressed.connect(_翻预览阶.bind(1))
	_提升按钮.pressed.connect(_打开提速弹窗)
	_突破按钮.pressed.connect(_打开突破弹窗)
	_启用复选框.toggled.connect(func(已勾: bool): 启用切换.emit(已勾))
	_提速弹窗.connect("提速请求", func(全部: bool): 提速请求.emit(全部))
	_突破弹窗.connect("突破请求", func(): 突破请求.emit())
	_突破弹窗.connect("购买请求", func(物品id: String): 购买请求.emit(物品id))
	_突破弹窗.connect("失败继续切换", func(已勾: bool): 失败继续切换.emit(已勾))
	# F6 单跑本页时没人调 应用状态，这里先按默认状态刷一次，
	# 否则箭头脚本 _ready 的默认可用会把「第一页的上一页」置灰漏掉。
	_预览阶 = _阶段
	_刷新当前信息()
	_刷新预览()


## 人物窗口 每次渲染手里剑页时调用；只刷展示，不发请求。
func 应用状态(状态: Dictionary, 攻击力: int = 0) -> void:
	var 旧阶段 := _阶段
	_阶段 = clampi(int(状态.get("stage", 1)), 1, 7)
	# ⚠️ 协议里那一位是**本阶等级 1..4**，不是全局等级：原版 `Client.onAnQi_updateStatus`
	#    收到后算 `shouLiJianRealLevel = 4*(stage-1) + level`（`JingMaiSource.as:415`），
	#    往 `updateView` 传的正是这个**累计值**（`JingMaiSource.as:420`）。
	#    原来这里直接把回帧值当全局等级用 ⇒ 第 2 阶（十字手里剑）练满回帧 `4`，
	#    页面写「4/8级」——满了却显示还剩一半（用户 2026-10-18 实机报修）。
	_等级 = 数据.每阶最大等级 * (_阶段 - 1) + clampi(int(状态.get("level", 1)), 1, 数据.每阶最大等级)
	_熟练度 = int(状态.get("master", 0))
	_幸运值 = maxi(0, int(状态.get("blessing", 0)))
	_已启用 = bool(状态.get("open", false))
	_触发几率 = int(状态.get("ratio", 0))
	_攻击力 = 攻击力
	_启用复选框.set_pressed_no_signal(_已启用)
	# 原版：阶段变了就跳回当前阶，否则保留用户正停着的预览页
	if _预览阶 == 0 or 旧阶段 != _阶段:
		_预览阶 = _阶段
	_刷新当前信息()
	_刷新预览()
	# 回帧时**就地**刷开着的突破弹窗上的幸运值 —— 原版 `JingMaiSource.as:429-437 onAnQi_updateZhuFu`
	# 收 `1817:1` 后直接 `windowMap[THROUGH_SHOU_LI_JIAN_WINDOW].updateXingYunValue(值)`，
	# 弹窗既不关也不重建。我们原来只在 `_打开突破弹窗` 里取一次幸运值 ⇒
	# 突破失败服务端明明加了 1-3 点（`_advance_stage_cultivation` 失败支），玩家永远看到 0/N
	# （用户 2026-10-20 报修 2.1）。
	if is_instance_valid(_突破弹窗) and (_突破弹窗 as Control).visible:
		_突破弹窗.call("更新显示", _阶段, _等级, _幸运值)


func _翻预览阶(增量: int) -> void:
	_预览阶 = clampi(_预览阶 + 增量, 1, 7)
	_刷新预览()


## 当前预览阶里第 `位` 枚技能图标对应哪个技能 id（这一阶没铺出来的格子返回 0）。
## 悬停提示得**跟着预览阶现算**：原版每枚 `SkillCell` 自己带着载荷
## （`ShouLiJianPanel.as:531-537`），我们这页三枚图标是"这一阶有几枚技能就铺几枚"、
## 图换了 id 也换了 —— 烘死就会拿 4 阶第 2 枚（9103）去报 5 阶的名。
func 预览技能id(位: int) -> int:
	var 技能: Array = (数据.取阶(_预览阶) as Dictionary).get("技能", [])
	if 位 < 0 or 位 >= 技能.size():
		return 0
	return int(技能[位])


func _刷新当前信息() -> void:
	var 阶 := 数据.取阶(_阶段)
	_当前使用.text = String(阶.get("名", "基础手里剑"))
	_当前进度.text = "%d/%d" % [_熟练度, 数据.熟练度上限]
	_当前等级.text = "%d/%d级" % [_等级, 数据.每阶最大等级 * _阶段]
	var 本阶 := 数据.本阶等级(_阶段, _等级)
	var 几率 := _触发几率
	if 几率 <= 0:
		几率 = int((阶.get("倍率", [10]) as Array)[本阶 - 1])
	_当前触发.text = "%d%%" % 几率


func _刷新预览() -> void:
	var 阶 := 数据.取阶(_预览阶)
	if 阶.is_empty():
		return
	_页码.text = "%d/7" % _预览阶
	# 与写轮眼页同一套箭头交互脚本：到头时去饱和变灰并挡掉 pressed
	_上一页.call("设置是否可用", _预览阶 > 1)
	_下一页.call("设置是否可用", _预览阶 < 7)
	_名称值.text = String(阶["名"])
	_品阶值.text = "%d阶" % _预览阶
	_获得方式值.text = "人物到达%d级获得" % 数据.获得等级

	var 本阶: int
	var 全局上限 := 数据.每阶最大等级 * _预览阶
	if _预览阶 == _阶段:
		本阶 = 数据.本阶等级(_阶段, _等级)
		_进度值.text = "%d/%d" % [_熟练度, 数据.熟练度上限]
		进度条补间.灌值(_等级条, float(_等级), float(全局上限), [_等级, 全局上限])
		if 本阶 >= 数据.每阶最大等级 and _熟练度 >= 数据.熟练度上限:
			_等级条文字.text = "已达瓶颈"
		else:
			_等级条文字.text = "%d/%d" % [_等级, 全局上限]
		_提升按钮.text = "提升速度"
		_突破按钮.text = "突破瓶颈"
		_提升按钮.disabled = false
		_突破按钮.disabled = false
	elif _预览阶 < _阶段:
		本阶 = 数据.每阶最大等级
		_进度值.text = "%d/%d" % [数据.熟练度上限, 数据.熟练度上限]
		进度条补间.灌值(_等级条, float(全局上限), float(全局上限), [全局上限, 全局上限])
		_等级条文字.text = "已达瓶颈"
		_提升按钮.text = "已修炼"
		_突破按钮.text = "已修炼"
		_提升按钮.disabled = true
		_突破按钮.disabled = true
	else:
		本阶 = 1
		_进度值.text = "0/%d" % 数据.熟练度上限
		_等级条.max_value = 1.0
		# ⚠ **有意偏离**：原版 `?/?` 的早退发生在写文案之后、补间之前（`MBar.as:158-161`）⇒
		#   预览未修炼的阶时条**停在上一次的位置**。本工程明确画**空条**（跳到 0 比留着上一阶的数
		#   好懂），补间照走 —— 记在 §3.243。
		进度条补间.补间(_等级条, "value", 0.0, [_预览阶, -1])
		_等级条文字.text = "?/?"
		_提升按钮.text = "未修炼"
		_突破按钮.text = "未修炼"
		_提升按钮.disabled = true
		_突破按钮.disabled = true

	var 倍率 := int((阶["倍率"] as Array)[本阶 - 1])
	_攻击能力值.text = "%d(%d%%的人物攻击力)" % [int(_攻击力 * 倍率 / 100.0), 倍率]
	_攻击距离值.text = "%d格" % (int(阶["距离"]) / 10)
	_目标数量值.text = str(int(阶["目标"]))
	_触发几率值.text = "%d%%" % 倍率

	_手里剑图标.texture = load(数据.图标路径(_预览阶, 本阶)) as Texture2D
	var 技能: Array = 阶["技能"]
	var 有技能: bool = not 技能.is_empty()
	_特殊说明.visible = not 有技能
	for i in _技能图标.size():
		var 图 := _技能图标[i]
		图.visible = i < 技能.size()
		if 图.visible:
			图.texture = load(数据.技能图标路径(int(技能[i]))) as Texture2D


func _打开提速弹窗() -> void:
	_提速弹窗.call("更新显示", _阶段, _等级, _熟练度)
	_弹出到屏幕层(_提速弹窗)


func _打开突破弹窗() -> void:
	# 原版每次开窗都现取幸运值（`ThroughShouLiJianWindow.updateView:182`）。
	_突破弹窗.call("更新显示", _阶段, _等级, _幸运值)
	_弹出到屏幕层(_突破弹窗)


## 宿主每次重绘本页时把「失败后自动继续」的勾选态回灌给弹窗（真值存在 `功能窗口` 上，
## 因为页面重绘会换掉整棵弹窗件 —— 记在控件上等于一帧就丢）。
func 设置失败继续(已勾: bool) -> void:
	if is_instance_valid(_突破弹窗):
		_突破弹窗.call("设置失败继续", 已勾)


# —— 屏幕级弹窗搬运（与 突破瓶颈按钮.gd 同一套路，暗幕单独一张、互不干扰）——

## 页面被换掉时（`功能窗口._render_page` 每次重绘都把整棵 `_content` `queue_free` 重建），
## 把**已经搬进屏幕层的自己那两张弹窗**一起收掉。它们连的是本页的信号，页面一没就成僵尸窗：
## 服务端随便来一帧，玩家眼前这张还亮着，点「开始突破瓶颈」却从此毫无反应
## （2026-10-18 实机报修"很呆滞"里就有这一半）；层里留着同名旧件还会把下一次搬进来的新窗
## 顶成 `@Control@431` 这种自动名。没搬出去的（还是本页孩子）跟着页面一起 free，不用管。
func _exit_tree() -> void:
	for 件 in [_提速弹窗, _突破弹窗]:
		var 弹 := 件 as Control
		if 弹 != null and is_instance_valid(弹) and 弹.get_parent() != self:
			弹.get_parent().remove_child(弹)
			弹.queue_free()
	var 树 := get_tree()
	if 树 == null:
		return
	var 层 := (树.root as Node).get_node_or_null("屏幕弹窗层") as CanvasLayer
	if 层 == null:
		return
	var 暗幕 := 层.get_node_or_null("手里剑弹窗暗幕") as CanvasItem
	if 暗幕 != null:
		暗幕.visible = false

func _弹出到屏幕层(弹窗: Control) -> void:
	var 层 := _屏幕弹窗层()
	弹窗.visible = true
	if 弹窗.get_parent() != 层:
		弹窗.reparent(层)
	var 暗幕 := _暗幕(层)
	暗幕.visible = true
	var 窗: Control = null
	var 走: Node = self
	while 走 != null:
		if 走.get_parent() is CanvasLayer:
			窗 = 走 as Control
			break
		走 = 走.get_parent()
	if 窗 != null:
		弹窗.global_position = (窗.global_position + ((窗.size - 弹窗.size) / 2.0)).floor()
	else:
		弹窗.global_position = ((get_viewport_rect().size - 弹窗.size) / 2.0).floor()


# 弹窗关闭时自己把同层的「手里剑弹窗暗幕」一起收掉，见两个弹窗脚本。

func _屏幕弹窗层() -> CanvasLayer:
	var 根 := get_tree().root
	var 层 := 根.get_node_or_null("屏幕弹窗层") as CanvasLayer
	if 层 == null:
		层 = CanvasLayer.new()
		层.name = "屏幕弹窗层"
		层.layer = 120
		根.add_child(层)
	return 层


func _暗幕(层: CanvasLayer) -> ColorRect:
	var 暗幕 := 层.get_node_or_null("手里剑弹窗暗幕") as ColorRect
	if 暗幕 == null:
		暗幕 = ColorRect.new()
		暗幕.name = "手里剑弹窗暗幕"
		暗幕.color = Color(0, 0, 0, 0.45)
		暗幕.mouse_filter = Control.MOUSE_FILTER_STOP
		暗幕.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		层.add_child(暗幕)
		层.move_child(暗幕, 0)
	return 暗幕
