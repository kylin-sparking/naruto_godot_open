extends Control

## 原版 NPC 商店的**装备修理窗** —— `com/mxw/uifl/controls/MendEtcWindow.as`（295×250）。
## 版式与出处见 `场景/界面/组件/修理窗.tscn` 的头注释。
##
## ⚠️ 这**不是**"修手上那一件"：`onClickXiuliBtn`（`:44-63`）→ `ShopWindowEvent.ETC_XIULI`
##   → `UI.as:1687 onShopEtcXiuli` → `Client.requestRepairEquip(repairType)`
##   → `ItemChangeProcessor.as:249-255` = `ITEM_CHANGE` 子命令 **7** + **一个** `writeInt`。
##   那一个 int 是**修理方式**（0 普通 / 1 特殊），服务端拿它一次修**身上全部**装备
##   （巡检 #19：我们以前发的是 `NPC_SHOP` 子命令 2 = 商品补货，而且只挑第一件受损的）。
##
## 两栏费用的算法逐字照 `setData()`（`:65-84`）：对 `equippedItems` 每件累加
## `(maxEndure - endure) × getEtcXiuliPrice(stage)[0|1]`，
## 而 `StringTool.getEtcXiuliPrice`（`StringTool.as:510-518`）返回
## `[naijiu.repair.stageN.normalPrice, specialPrice]` ⇒ 价由**调用方**算好传进来
## （`功能窗口._repair_prices`），本窗**不碰会话、不碰协议**。
##
## `onClickXiuliBtn` 的闸门：点的那一档**合计为 0** ⇒ `noticePnl.addNotice(CN.BUXUYAO_XIULI)`
## 并 `return` —— **不发帧、也不关窗**（窗口只在真的发出去之后才 `onCloseBtnClick`）。

## 成交：0 普通修理 / 1 特殊修理（就是 `writeInt` 的那一个 int）。
signal 确认修理(类型: int)
## 这一档不需要修理（`CN.BUXUYAO_XIULI`，由调用方去顶全局提示条）。
signal 提示不需要修理
## 关掉了（关闭钮 / 成交后自动关，同 `一键出售窗` 的口径）。
signal 关闭了

const 类型普通 := 0
const 类型特殊 := 1

@onready var _普通数值: Label = $普通数值
@onready var _特殊数值: Label = $特殊数值
var _普通合计 := 0
var _特殊合计 := 0


func _ready() -> void:
	($普通按钮 as Button).pressed.connect(_点修理.bind(类型普通))
	($特殊按钮 as Button).pressed.connect(_点修理.bind(类型特殊))
	($关闭 as Button).pressed.connect(隐藏)


## `UIMain2.showMendEtcWindow()` 走 `reverseDisplay` ⇒ 每次显示都跑一遍 `initWindow()`
## → `setData()`，所以**费用是开窗那一刻重算的**，两栏合计由调用方按同一张表算好传进来。
func 打开(普通合计: int, 特殊合计: int) -> void:
	_普通合计 = maxi(0, 普通合计)
	_特殊合计 = maxi(0, 特殊合计)
	_普通数值.text = str(_普通合计)
	_特殊数值.text = str(_特殊合计)
	visible = true
	_居中()


## `PopUpMananger.centerWindow`：舞台居中（同 `一键出售窗` 的 `set_deferred` 理由）。
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


func _点修理(类型: int) -> void:
	if (_特殊合计 if 类型 == 类型特殊 else _普通合计) == 0:
		提示不需要修理.emit()
		return
	确认修理.emit(类型)
	隐藏()
