extends Control

## 原版**一键出售弹窗** —— `com/mxw/uifl/controls/QuickSaleWindow.as`（173 行）。
## 版式与出处见 `场景/界面/组件/一键出售窗.tscn` 的头注释。
##
## ⚠️ 这**不是一条发出去的协议**，是一个让玩家选条件的模态窗：
##   `ShopWindow2.as:569-572 onQuickSaleBtn` → `UIMain2.as:2401-2407 showQuickSaleWindow()`
##   → `PopUpMananger.centerWindow(new QuickSaleWindow(), true)`。
##   我们以前把「一键出售」折成"点一下直接发 1..30 格"（§3.42 记的账），
##   结果第 3 个 int 被服务端读成**品质上限 = 0** ⇒ 每次必回 SHOP_ERROR（巡检 #18）。
##
## 取值规则（逐条对 AS3，别自己"顺手修正"）：
##   `OKBtnClickHandler`（`:57-73`）
##     · 三枚下拉取的是**值数组**下标，不是选项序号：
##       `_levelArr=[20,40,60,80,100,120]`、`_starArr=[3,4,5,6]`、`_colorArr=[1,2,3]`
##     · 目标位图恒带 `SELL_TARGET_EQUIP=1`，勾选才 `|=2`（残卷）/`|=4`（玉链）
##     · 发完就 `onCloseBtnClick(null)` ⇒ **确定即关窗**
##   三枚下拉**没有** setData、没有初值：`MComboBox` 默认 `selectedIndex = 0`
##   ⇒ 开窗即「20级及以下 / 3星及以下 / 白品及以下」，两枚勾选默认不勾。
##
## ⚠️ 本窗**不管协议**：只发 `确认出售(等级, 星级, 品质, 目标)`，
##    由 `功能窗口._成交一键出售` 转成 `request_npc_shop_one_key_sell(...4 个 int)`。

## 成交：(等级上限, 星级上限, 品质上限, 目标位图)
signal 确认出售(等级: int, 星级: int, 品质: int, 目标: int)
## 关掉了（确定 / 关闭 / 取消都算，同 `商城购买窗` 的口径）。
signal 关闭了

## `QuickSaleWindow.as:30/44/32` 那三枚值数组 —— 文案在场景里、值在这里，两份**必须同序**。
## 文案逐字出自 `en_US$message_properties.as`：LEVELARR :1268 / STARARR :2727 / COLORARR :200。
const 等级档 := [20, 40, 60, 80, 100, 120]
const 星级档 := [3, 4, 5, 6]
const 品质档 := [1, 2, 3]
const 等级文案 := ["20级及以下", "40级及以下", "60级及以下", "80级及以下", "100级及以下", "120级及以下"]
const 星级文案 := ["3星及以下", "4星及以下", "5星及以下", "6星及以下"]
const 品质文案 := ["白品及以下", "绿品及以下", "蓝品及以下"]
## `:18-22` 三枚位图常量。
const 目标装备 := 1
const 目标残卷 := 2
const 目标玉链 := 4

@onready var _等级: OptionButton = $等级下拉
@onready var _星级: OptionButton = $星级下拉
@onready var _品质: OptionButton = $品质下拉
@onready var _残卷: CheckBox = $残卷勾选
@onready var _玉链: CheckBox = $玉链勾选


func _ready() -> void:
	for 文 in 等级文案:
		_等级.add_item(文, _等级.item_count)
	for 文 in 星级文案:
		_星级.add_item(文, _星级.item_count)
	for 文 in 品质文案:
		_品质.add_item(文, _品质.item_count)
	($确定 as Button).pressed.connect(_点确定)
	($取消 as Button).pressed.connect(隐藏)
	($关闭 as Button).pressed.connect(隐藏)


## 原版每次 `new QuickSaleWindow()` ⇒ 上一轮的勾选不该留着。
func 打开() -> void:
	_等级.selected = 0
	_星级.selected = 0
	_品质.selected = 0
	_残卷.button_pressed = false
	_玉链.button_pressed = false
	visible = true
	_居中()


## `PopUpMananger.centerWindow`：舞台居中。与 `商城购买窗` 同一个 `set_deferred` 理由
## （挂上 `_overlay` 的那一刻布局还没跑，当场写 `global_position` 会用到祖先的旧变换）。
func _居中() -> void:
	var 舞台 := get_viewport().get_visible_rect().size
	set_deferred("global_position", Vector2(
		round((舞台.x - size.x) * 0.5), round((舞台.y - size.y) * 0.5)
	))


func 隐藏() -> void:
	if not visible:
		return
	visible = false
	关闭了.emit()


func _点确定() -> void:
	var 目标 := 目标装备
	if _残卷.button_pressed:
		目标 |= 目标残卷
	if _玉链.button_pressed:
		目标 |= 目标玉链
	# `:59-61` 用 `selectedIndex` 去**值数组**里取值，所以这里也必须按下标取。
	确认出售.emit(等级档[_等级.selected], 星级档[_星级.selected], 品质档[_品质.selected], 目标)
	隐藏()
