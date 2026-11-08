extends Control
## 手里剑突破瓶颈弹窗 —— 还原 Flash ThroughShouLiJianWindow（434×341）的 UI。
## 只管开关窗、按静态表填充两阶手里剑/消耗/成功率/幸运值展示，
## 「开始突破瓶颈」只发一个信号，由 人物窗口.gd 转成既有的 request_shuriken(1)。
##
## 「购买升阶物品」原版 `gouMaiHandler`（`ThroughShouLiJianWindow.as:372-381`）**不买东西**，
## 它只 dispatch 一条 `CashShopWindowEvent.REQUEST_CASH_ITEM_INFO`（`id = 那件升阶物品的 id`），
## 由 `UI.as:197-205` 转成 `requestCashItemInfo(id, 0)` —— 回包 1079 才把商城购买窗弹出来。
## 这条在我们这儿就是**统一出口** `功能窗口.请求商城商品`（扩容窗/材料格/改名那几处同源），
## 所以这里同样只发信号、不自建购买逻辑。
##
## 「失败后自动继续」= 原版 `_failCheckBox`（`ThroughShouLiJianWindow.as:348-356`，
## 文案 `PETLAYERTAB_CHENCK_BOX_NAME_2`「失败后自动继续」）⇒ 这里只发 `失败继续切换(已勾)`，
## **勾选状态记在宿主 `功能窗口._手里剑失败继续` 上**（页面每次重绘都换新弹窗件，记在控件上会丢）。
## 取消勾选那一下 = 原版 `continueToPoHandler:428-434` 的 `clearTimeout`。
## ⚠️ **有意偏离**：原版点标题栏关闭（`onCloseBtnClick:94-98`）**只摘库存监听、不 clearTimeout**
## ⇒ 挂着勾关窗，客户端仍每 900ms 自发一发、把钱和材料悄悄耗光。这边改成
## **弹窗不在屏幕上亮着就不再跳**（`人物窗口.手里剑弹窗还亮着`）：玩家自己关、切子页、
## 整页重建把这扇窗收掉，三种都算"看不见了"，一律不再烧钱 —— 记在 §3.264。

signal 突破请求()
signal 购买请求(物品id: String)
signal 失败继续切换(已勾: bool)

const 数据 := preload("res://素材/界面/原版窗口/人物/手里剑/脚本/手里剑数据.gd")
## 成功率/幸运两根 = 原版 `ThroughShouLiJianWindow` 的 `_xinYunBar`（MBar 族）⇒ 0.5s 补间。
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")

## 当前这一阶突破要买的那件（`下.is_empty()` 时为空 ⇒ 购买键禁用）。
var _物品id := ""


func _ready() -> void:
	visible = false
	(_取("关闭按钮") as BaseButton).pressed.connect(_收起)
	(_取("开始突破瓶颈") as BaseButton).pressed.connect(func(): 突破请求.emit())
	(_取("购买升阶物品") as BaseButton).pressed.connect(func() -> void:
		if not _物品id.is_empty():
			购买请求.emit(_物品id))
	# 原版这枚是 `MCheckBox` 的 `MouseEvent.CLICK` ⇒ 对应 Godot 的 `toggled`（点击翻态才发，
	# `set_pressed_no_signal` 回灌不发 —— 正是我们要的：回灌是**同步状态**，不该被当成"玩家改了勾选"）。
	(_取("失败后自动继续") as BaseButton).toggled.connect(
		func(已勾: bool) -> void: 失败继续切换.emit(已勾))


## 宿主每次重绘页面时把 `_手里剑失败继续` 回灌进来（弹窗件是新的，勾选态存在宿主上）。
func 设置失败继续(已勾: bool) -> void:
	(_取("失败后自动继续") as TextureButton).set_pressed_no_signal(已勾)


func 更新显示(阶段: int, 等级: int, 幸运值: int = 0) -> void:
	var 当前 := 数据.取阶(阶段)
	(_取("上信息/名称/值") as Label).text = String(当前.get("名", ""))
	(_取("上信息/品阶/值") as Label).text = "%d阶" % 阶段
	(_取("上信息/等级/值") as Label).text = "%d/%d级" % [等级, 数据.每阶最大等级 * 阶段]
	(_取("上图标") as TextureRect).texture = load(
		数据.图标路径(阶段, 数据.本阶等级(阶段, 等级))) as Texture2D

	var 下 := 数据.取阶(阶段 + 1)
	var 按钮 := _取("开始突破瓶颈") as Button
	var 购买钮 := _取("购买升阶物品") as Button
	_物品id = ""
	if 下.is_empty():
		(_取("下信息/下阶名称/值") as Label).text = " "
		(_取("下信息/下阶品阶/值") as Label).text = " "
		(_取("下信息/金币值") as Label).text = "0"
		(_取("下信息/精华值") as Label).text = "0"
		(_取("下信息/物品值") as Label).text = " "
		(_取("上信息/说明") as RichTextLabel).text = " "
		_设条("下信息/成功率条", "下信息/成功率条/成功率文字", 0, 1, "0/100")
		_设条("下信息/幸运条", "下信息/幸运条/幸运文字", 0, 1, "0/0")
		(_取("下图标") as TextureRect).texture = null
		按钮.disabled = true
		购买钮.disabled = true
		return
	var 上 := 下["up"] as Dictionary
	_物品id = str(int(上["物品id"]))
	购买钮.disabled = false
	(_取("下信息/下阶名称/值") as Label).text = String(下["名"])
	(_取("下信息/下阶品阶/值") as Label).text = "%d阶" % (阶段 + 1)
	(_取("下信息/金币值") as Label).text = str(int(上["金币"]))
	(_取("下信息/精华值") as Label).text = str(int(上["精华"]))
	(_取("下信息/物品值") as Label).text = "%s×%d" % [String(上["物品名"]), int(上["数量"])]
	(_取("上信息/说明") as RichTextLabel).text = "[color=#1e90ff]突破瓶颈失败会增加下次成功的幸运几率，幸运值保留12小时，每升阶1次，保留时间将重置为12小时[/color]\n[color=#ffffff]本次升阶成功幸运值为%d-%d，[/color][color=#ff0000]达到%d必成！[/color]" % [
		int(上["幸运小"]), int(上["幸运大"]), int(上["幸运大"])]
	_设条("下信息/成功率条", "下信息/成功率条/成功率文字", int(上["几率"]), 100, "%d/100" % int(上["几率"]))
	# 原版 `updateView` 末尾就是 `updateXingYunValue(JingMaiSource.shouLiJianXingYunValue)`：
	# `_xinYunBar.setData(幸运值, stageUp.zhufu_show)`（`ThroughShouLiJianWindow.as:182/394-400`）。
	# 这里原来把值写死 0 ⇒ 突破失败后服务端明明加了 1-3 点（`onAnQi_updateZhuFu`，
	# `AnQiProcessor.action_AnQiZhuFu`），玩家看到的永远是 0/N（2026-10-20 报修）。
	var 幸运上限 := maxi(1, int(上["幸运满"]))
	var 幸运 := clampi(幸运值, 0, 幸运上限)
	_设条("下信息/幸运条", "下信息/幸运条/幸运文字", 幸运, 幸运上限, "%d/%d" % [幸运, 幸运上限])
	(_取("下图标") as TextureRect).texture = load(数据.图标路径(阶段 + 1, 1)) as Texture2D
	按钮.disabled = false


func _设条(条名: String, 文字名: String, 值: float, 最大: float, 文字: String) -> void:
	var 条 := _取(条名) as ProgressBar
	进度条补间.灌值(条, 值, 最大, [值, 最大])
	(_取(文字名) as Label).text = 文字


func _收起() -> void:
	visible = false
	var 父 := get_parent()
	var 暗幕 := 父.get_node_or_null("手里剑弹窗暗幕") as CanvasItem
	if 暗幕 != null:
		暗幕.visible = false


func _取(路径: String) -> Node:
	return get_node(路径)
