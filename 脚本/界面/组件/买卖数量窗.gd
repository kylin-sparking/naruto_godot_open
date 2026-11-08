extends Control

## 原版**买卖数量窗**（`com/mxw/uifl/controls/BuyAndSaleItemWindow.as`，324 行）。
## 版式与出处见 `场景/界面/组件/买卖数量窗.tscn` 的头注释。
##
## 它是 NPC 商店唯一的成交通路：
##   · 点商品格 → `ShopWindow2.onItemClick`（`:415-424`）→ `showBuyAndSaleWindow(cell, true)`（买）
##   · 出售模式下点背包物品 → `UIConfig.saleValidateFun` = `showBuyAndSaleWindow`（`:648`）（卖）
##
## 取值规则（都照抄，别自己"顺手修正"）：
##   `setData`（`:115-165`）
##     · 单价 = 买？`data.price` : `floor(data.price / 3)`；且 `price > 0` 时下限 1
##     · 数量初值 = `data.count`（**买**的时候也是它 —— 原版没给"默认买 1 个"）
##     · 标题：买 `BUY_WINDOW_TITLE`「购买窗口」／卖 `SALE_WINDOW_TITLE`「出售窗口」
##     · 买且 `件数 × 单价 > 元宝余额` 时**确定按钮置灰**（`:141-148`）
##     · 卖的时候 `okBtn.enabled = true`
##   `onChange`（`:66-86`）
##     · 买：`数量 × 单价 > 元宝` 时**把数量压回** `floor(元宝 / 单价)`
##     · 卖：数量 > `data.count` 时压回件数
##   `onClickAddBtn`（`:109-118`）：买要满足 `(n+1) × 单价 <= 元宝` 才 +1；卖要 `n < 件数`
##   `onClickMinusBtn`（`:167-175`）：`n > 1` 才 -1（**没有"减到 0"**）
##   `setTotalPrice`（`:296-305`）：买 `n × price`、卖 `floor(price × n / 3)`；`price > 0` 时下限 1
##   `onOk`（`:88-107`）：**只校验 `数量 > 0`**，然后发 `ShopWindowEvent.BUY_ITEM` /
##     `SELL_ITEM`（带 `slot`），最后关窗。
##
## ⚠️ 本窗**不管协议**：只发信号，由宿主（`功能窗口.gd`）转成 `request_npc_shop_*`。
##    这样它跟 `拆分窗口`/`销毁窗口` 是同一个形状（组件只报意图）。

## 买：`数量 × 单价`；卖：`floor(单价 × 数量 / 3)`。宿主据此发协议。
signal 确定买卖(是买: bool, 物品id: String, 数量: int, 槽位: int)

const 橙色 := Color("#ff8b00")

var _是买 := true
var _物品id := ""
var _槽位 := 0
var _件数 := 1        ## 卖的时候是可卖上限；买的时候只用于初值
var _单价 := 1
var _余额 := 0        ## 元宝余额，买的时候的上限来源（`API.dataCenter.cocoNuts`）

@onready var _标题: Label = $标题
@onready var _物品名: Label = $物品名
@onready var _单价值: Label = $单价值
@onready var _总价值: Label = $总价值
@onready var _数量: LineEdit = $数量
@onready var _确定: Button = $确定


func _ready() -> void:
	_数量.text_changed.connect(_限制输入)
	_数量.text_submitted.connect(func(_t: String): _确定买卖())
	($加 as Button).pressed.connect(_加减.bind(1))
	($减 as Button).pressed.connect(_加减.bind(-1))
	_确定.pressed.connect(_确定买卖)
	($取消 as Button).pressed.connect(隐藏)
	($关闭 as Button).pressed.connect(隐藏)


## `setData(param1, param2)`（`:115`）。`余额` 传元宝数（买时判定用）。
func 打开(物品: Dictionary, 是买: bool, 余额: int, 格位 := 0) -> void:
	_是买 = 是买
	_物品id = String(物品.get("id", ""))
	# ⚠️ **优先用调用方给的格位**（背包点格子进来的那条有）：字典里的 `slot_index` 在离线种子件上
	#    可能压根没写，而按 id 反查首摞在同 id 两摞时会操作错那一款（巡检 #16）。
	_槽位 = 格位 if 格位 > 0 else int(物品.get("slot_index", 物品.get("position", 0)))
	_件数 = maxi(1, int(物品.get("quantity", 物品.get("count", 1))))
	# `:151-158` —— 单价：买 = price，卖 = floor(price / 3)；price > 0 时下限 1
	var 原价 := int(物品.get("price", 0))
	_单价 = 原价 if 是买 else int(floor(原价 / 3.0))
	if 原价 > 0:
		_单价 = maxi(1, _单价)
	_余额 = maxi(0, 余额)

	_标题.text = "购买窗口" if 是买 else "出售窗口"
	_物品名.text = String(物品.get("name", ""))
	_单价值.text = str(_单价)
	_数量.text = str(_件数)
	_确定.disabled = 是买 and _件数 * _单价 > _余额
	_回算总价()

	visible = true
	# `PopUpMananger.centerWindow`（`positionWindwo`，`:122-144`）—— **舞台居中**：
	# x = round((960 - 宽) >> 1)、y = round((560 - 高) >> 1)。用 global_position 直接摆，
	# 这样不依赖宿主窗口在页里的偏移量。
	global_position = Vector2(
		round((_舞台().x - size.x) * 0.5), round((_舞台().y - size.y) * 0.5)
	)
	_数量.grab_focus()


## 真实舞台尺寸。⚠️ **不是**固定的 960x560 —— 原版 `Config.STAGE_WIDTH/HEIGHT`
## 由 `Game.as:76-93` 按真实窗口尺寸重算。写死会让弹窗跑到左上角。
func _舞台() -> Vector2:
	return get_viewport().get_visible_rect().size


func 隐藏() -> void:
	visible = false


## `onClickAddBtn`（`:109-118`）／`onClickMinusBtn`（`:167-175`）
func _加减(方向: int) -> void:
	var 当前 := _数量.text.to_int()
	if 方向 > 0:
		if _是买:
			if (当前 + 1) * _单价 <= _余额:
				当前 += 1
		elif 当前 < _件数:
			当前 += 1
	else:
		if 当前 > 1:
			当前 -= 1
	_数量.text = str(当前)
	_回算总价()


## `onChange`（`:66-86`）—— 超额时**把输入框本身改掉**，不是只提示
func _限制输入(新文本: String) -> void:
	var 过滤 := ""
	for 字 in 新文本:
		if 字 >= "0" and 字 <= "9":
			过滤 += 字
	# `TextField.maxChars = 8`（`:252`）
	if 过滤.length() > 8:
		过滤 = 过滤.substr(0, 8)
	if 过滤 != 新文本:
		_数量.text = 过滤
		_数量.caret_column = 过滤.length()
		return
	var 数量 := 过滤.to_int()
	if 数量 <= 0:
		_回算总价()
		return
	if _是买:
		if _单价 > 0 and 数量 * _单价 > _余额:
			var 压回 := int(floor(_余额 / float(_单价)))
			_数量.text = str(压回)
			_数量.caret_column = _数量.text.length()
	else:
		if 数量 > _件数:
			_数量.text = str(_件数)
			_数量.caret_column = _数量.text.length()
	_回算总价()


## `setTotalPrice`（`:296-305`）
func _回算总价() -> void:
	var 数量 := _数量.text.to_int()
	var 总价 := 数量 * _单价 if _是买 else int(floor(_单价 * 数量 / 3.0))
	if _单价 > 0:
		总价 = maxi(1, 总价)
	_总价值.text = str(总价)


## `onOk`（`:88-107`）—— 只校验 > 0
func _确定买卖() -> void:
	var 数量 := _数量.text.to_int()
	if 数量 > 0:
		确定买卖.emit(_是买, _物品id, 数量, _槽位)
	隐藏()
