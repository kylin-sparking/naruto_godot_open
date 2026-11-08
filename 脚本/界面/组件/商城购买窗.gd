extends Control

## 原版商城**购买弹窗** —— `com/mxw/uifl/biguan/BuyEqpWindow.as`（518 行）。
## 版式与出处见 `场景/界面/组件/商城购买窗.tscn` 的头注释。
##
## 它替换掉之前"点购买就直接买 1 个"的过渡做法（§3.48 记的账）。
## 成交链路照原版：`CashItemCell` 购买 → `BUY_FROM_LIST` → `CashShopWindow2.__buyItem`
## （`:444-451`）→ 本窗；本窗「购买」→ `onBuyClick`（`:~420`）→ 派发购买事件 → 服务端 1081。
##
## 取值规则（逐条对 AS3，别自己"顺手修正"）：
##   `setData`（`:196-232`）
##     · `price = 现价`；`sayItem.htmlText = desc`（**只有 desc，没有 detaildesc** —— 绿字）
##     · `isLiJin == 1` → 券勾选与券图标可见、**默认选中券**、元宝勾选取消
##     · 否则 → **元宝勾选置灰**（`ybCheckBox.enabled = false`），`setBuyInfo(CN.COIN, false)`
##     · `_consumableCound = 现价 × 数量`
##   `setBuyInfo(货币名, isLiJin)`（`:231-250`）
##     · `balanceTf.text = BUYEQPWINDOW_BALANCE_TF_TEXT` 里把 `%1` 换成货币名（「你帐号中还有元宝：」）
##   `onChange`（`:~330`）：数量变了就重算总价、并检查余额
##   `onClickAddBtn` / `onClickMinusBtn`：+1 / -1（下限 1）
##   `onBuyClick`：够钱才发；不够在 `lackBalanceTf` 里提示
##
## ⚠️ 本窗**不管协议**：只发 `确认购买(sn, 数量, 用点券)`，由 `功能窗口._成交商城` 转成
##    `request_cash_shop_buy(sn, 数量, shop_type)`。**那枚钱包选择器必须一路带到报文**
##    （2026-10-17 巡检 #17：原来 `_成交商城` 把它丢了、恒发 0 ⇒ 勾了点券仍按元宝扣，
##    本窗两枚勾选形同装饰）。与 `买卖数量窗` 同一个形状。

## 购买：(sn, 数量, 是否走绑定元宝/点券)
signal 确认购买(sn: int, 数量: int, 用点券: bool)
## 关掉了（确定买完 / 点关闭 / 点取消都算）。宿主据此清掉窗口上的"正在购买哪件商品"。
signal 关闭了

const 橙色 := Color("#ff8b00")
## `MWindow.as:229` 拖动区高度。
const 拖动区高 := 29.0

var _行: Dictionary = {}
var _现价 := 0
var _元宝余额 := 0
var _点券余额 := 0
var _用点券 := false
var _拖动中 := false
var _拖动偏移 := Vector2.ZERO

@onready var _商品名: Label = $商品名
@onready var _商品单价: Label = $商品单价
@onready var _说明: RichTextLabel = $说明
@onready var _数量: LineEdit = $数量
@onready var _总价: Label = $总价
@onready var _余额标签: Label = $余额标签
@onready var _账号余额: Label = $账号余额
@onready var _余额不足: Label = $余额不足
@onready var _元宝勾选: CheckBox = $元宝勾选
@onready var _券勾选: CheckBox = $券勾选
@onready var _购买: Button = $购买


func _ready() -> void:
	_数量.text_changed.connect(_数量变了)
	($加 as Button).pressed.connect(_加减.bind(1))
	($减 as Button).pressed.connect(_加减.bind(-1))
	_元宝勾选.pressed.connect(func(): _选货币(false))
	_券勾选.pressed.connect(func(): _选货币(true))
	_购买.pressed.connect(_点购买)
	($关闭 as Button).pressed.connect(隐藏)
	gui_input.connect(_on_drag_input)
	# 原版 `newBtn()`（`:158-159`）把「购买」「充值」两颗**按文字宽**并排居中：
	#   buyBtn.x = (background.width - buyBtn.tf.width - payBtn.tf.width - 30) >> 1
	# 本工程按用户要求**删掉了充值那颗**（2026-10-18，有意偏离原版：没有充值渠道）
	# ⇒ 只剩「购买」，改按**按钮自身宽**居中（按文字宽会把 37 宽的钮偏右几像素，眼睛看得出）。
	_排购买()


func 打开(商品: Dictionary, 元宝余额: int, 点券余额: int) -> void:
	_行 = 商品
	_现价 = maxi(1, int(商品.get("now_price", 商品.get("price", 1))))
	刷新余额(元宝余额, 点券余额)

	_商品名.text = String(商品.get("name", ""))
	_商品单价.text = str(_现价)
	var 图标路径 := String(商品.get("icon", ""))
	($物品格/图标 as TextureRect).texture = (
		load(图标路径) as Texture2D if ResourceLoader.exists(图标路径) else null
	)
	# `setData`：说明只有 `desc`（绿字），**不带 detaildesc** —— 与商城商品行的说明框不同，
	# 别把两处的规则混起来。
	_说明.text = String(商品.get("description", ""))

	# `:218-228` —— 礼金品：券可选且默认选中；否则元宝勾选置灰
	var 是礼金 := bool(商品.get("is_li_jin", false))
	_券勾选.visible = 是礼金
	($券图标 as TextureRect).visible = 是礼金
	_元宝勾选.disabled = not 是礼金
	_选货币(是礼金, true)

	_数量.text = "1"
	_刷新总价()
	visible = true
	_居中()


## **只更余额**：数量、购买方式勾选、说明、位置一概不碰。宿主的页面每次回帧都重建一遍，
## 重建后该走这条 —— 再 `打开()` 一次就把玩家刚打的数量与刚勾的货币冲回默认值
## （2026-10-18 实机报修「购买窗里购买方式/购买数量点不动」）。
func 刷新余额(元宝余额: int, 点券余额: int) -> void:
	_元宝余额 = maxi(0, 元宝余额)
	_点券余额 = maxi(0, 点券余额)
	_刷新总价()


## 这扇窗是不是**正在买这件商品**（按 `sn` 认）。宿主用它决定"重开"还是"只更余额"。
func 正在买(sn: int) -> bool:
	return visible and int(_行.get("sn", -1)) == sn


## `PopUpMananger.centerWindow`（`positionWindwo`）—— **舞台居中**，与买卖数量窗同一套。
##
## ⚠️ **必须 `set_deferred`**：弹窗现在是在 `_render_shop()` 里**边建页边开**的
## （见 §3.49.4：打开态存在窗口上，整页重建时要重新开出来），
## 而那一刻页面/主窗口的布局还没跑 —— 当场写 `global_position` 会用到**祖先的旧变换**，
## 弹窗就摆歪。用户 2026-09-27 实机报的"购买弹窗位置不在中间"就是这个。
func _居中() -> void:
	var 舞台 := get_viewport().get_visible_rect().size
	set_deferred("global_position", Vector2(
		round((舞台.x - size.x) * 0.5), round((舞台.y - size.y) * 0.5)
	))


## 拖动**有意偏离原版**（用户 2026-11-01 要求购买窗能自由拖动）：原版
## `BuyEqpWindow.as:279` 构造里 `startDragY = -1`（MWindow 的拖动区被关掉），
## 这扇窗拖不动、位置由 `PopUpMananger.centerWindow` 钉在舞台中央。
## 只认顶部 29px（`MWindow.as:229`）内的左键；按钮/输入框自己有 STOP，事件轮不到这里。
func _on_drag_input(event: InputEvent) -> void:
	# ⚠️ 参数类型只能是 `InputEvent`（`gui_input` 就是这么发的），而 `global_position`
	# 在子类 `InputEventMouse` 上 —— 直接 `event.global_position` 会让类型推断失败、整份脚本
	# 解析不过（2026-11-01 实测：商城购买窗整个 load 失败）。
	if event is InputEventMouseButton:
		var 钮 := event as InputEventMouseButton
		if 钮.button_index != MOUSE_BUTTON_LEFT:
			return
		if 钮.pressed and 钮.position.y <= 拖动区高:
			_拖动中 = true
			_拖动偏移 = 钮.global_position - global_position
		else:
			_拖动中 = false
	elif event is InputEventMouseMotion and _拖动中:
		var 动 := event as InputEventMouseMotion
		var 舞台 := get_viewport().get_visible_rect().size
		var 目标 := (动.global_position - _拖动偏移).round()
		global_position = Vector2(
			clampf(目标.x, 0.0, maxf(0.0, 舞台.x - size.x)),
			clampf(目标.y, 0.0, maxf(0.0, 舞台.y - size.y))
		)


func 隐藏() -> void:
	if not visible:
		return
	visible = false
	关闭了.emit()


## `setBuyInfo`（`:231-250`）—— 余额那行文案是 `BUYEQPWINDOW_BALANCE_TF_TEXT`（「你帐号中还有%1：」），
## `%1` 换成货币名（元宝 / 点券）。
func _选货币(用点券: bool, 初始化 := false) -> void:
	# ⚠️ 这个守卫只管**用户点击**：元宝勾选被置灰（非礼金商品）时，玩家点它不该切货币。
	# 但 `打开()` 那次初始化调用**必须放行** —— 否则非礼金商品的余额行永远是空的
	# （实测症状：「你帐号中还有元宝：」不显示。AS3 `setData` 的 else 分支是会
	#  `setBuyInfo(CN.COIN, false)` 的，`BuyEqpWindow.as:226`）。
	if not 初始化 and _元宝勾选.disabled and 用点券 == false:
		return
	_用点券 = 用点券
	_元宝勾选.button_pressed = not 用点券
	_券勾选.button_pressed = 用点券
	_余额标签.text = "你帐号中还有%s：" % ("点券" if 用点券 else "元宝")
	_刷新总价()
	if 初始化:
		return


## 数量或货币变了 → 重算总价 + 余额够不够。
func _刷新总价() -> void:
	var 数量 := maxi(0, _数量.text.to_int())
	var 总价 := 数量 * _现价
	_总价.text = str(总价)
	_账号余额.text = str(_点券余额 if _用点券 else _元宝余额)
	var 余额 := _点券余额 if _用点券 else _元宝余额
	_购买.disabled = 数量 <= 0 or 总价 > 余额
	_余额不足.text = "余额不足" if 数量 > 0 and 总价 > 余额 else ""


func _加减(方向: int) -> void:
	var 数量 := maxi(0, _数量.text.to_int()) + 方向
	_数量.text = str(maxi(1, 数量))
	_刷新总价()


## `buyCound` 的 `restrict = "0123456789"`
func _数量变了(新文本: String) -> void:
	var 过滤 := ""
	for 字 in 新文本:
		if 字 >= "0" and 字 <= "9":
			过滤 += 字
	if 过滤 != 新文本:
		_数量.text = 过滤
		_数量.caret_column = 过滤.length()
		return
	_刷新总价()


func _点购买() -> void:
	var 数量 := _数量.text.to_int()
	if 数量 <= 0:
		return
	确认购买.emit(int(_行.get("sn", 0)), 数量, _用点券)
	隐藏()


## 只剩「购买」一颗 ⇒ 在窗内居中。原版是两颗并排、按 `tf.width`（文字宽）算的（`newBtn():158-159`），
## 单颗若还按文字宽会把 37 宽的钮推偏几像素，所以这里按**按钮自身宽**居中。
func _排购买() -> void:
	_购买.position.x = (size.x - _购买.size.x) * 0.5
