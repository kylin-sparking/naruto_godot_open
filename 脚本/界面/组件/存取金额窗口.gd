extends Control

## 原版**存钱/取钱**金额窗（`SaveAndTakeMoneyWindow`）。版式见 §3.10.9。
##
## ⚠️ 它 `extends MWindow`、**不是 UIWindow** —— 没有 `super(宽,高)` 那一步，
## 尺寸是给 `background`（`MWindowSmall_background`，符号 767，243×171）手动设
## `width = 187` / `height = 174`（`:80-82`）。项目里对应 `小窗口边框.png`(243×171) ✓
## 关闭按钮/标题的最终位置由 `MWindow.drawWindowLayout()` 决定（`:210-217`）：
## 标题 `y = 5` 居中、关闭 `x = 宽−25−6 = 156`、`y = 6`。
##
##   `:84`  黄底 `MYellow_background` @ (6,30) 175×137
##   `:95`  持有底 `MTextInput_background` @ (23,57) 139×21
##   `:101` 数量底 `MTextInput_background` @ (31,110) 68×21
##   `:219` 金币图标 @ (28,59) 17×17
##   `:108` 上标签 @ (8,32) 171×18；`:111` 下标签 @ (8,82) 171×18（`setTextFieldXYWH` 的 −2
##          与 `MLabel` 内部的 +2 相抵，所以**可视文字 y 就是 34 / 84**）
##   `:114` 持有金额 @ (46,57) 100×18（`formatNumber` 千分位）
##   `:116` 数量输入 @ (35,111) 64×18 —— 原生 TextField，不是 MTextInput2
##   `:126` 加号 @ (100,111) 18×18；`:130` 减号 @ (13,111) 18×18
##   `:134` MAX @ (126,110)，`isScale9Grid=true` ⇒ 宽 = 文字宽+6；文字 "MAX" 是硬编码
##   `:140` 确定 @ (52,138) 37×22；`:147` 取消 @ (102,138) 37×22
##
## 取值（`:225-232`、`:68-76`、`:170-178`、`:190-193`、`:195-215`）：
##   下限 0、上限 `可操作金额`；输入超上限会被强制写回；
##   「确定」只在 `>0` 时发事件。
## 协议（以服务端为准）：`STORAGE(59)` action **4 = 存钱** / **5 = 取钱**，字段 `double money`
## （`StorageProcessor.as:164-169` / `:143-148`；服务端 `_handle_storage_text` 同一套字段）。
## 客户端已有该封装：`游戏会话.deposit_storage_gold` / `withdraw_storage_gold`。

signal 确认存取(是存入: bool, 金额: int)

## 语言表 key（`en_US$message_properties.as`）
const 你的背包中拥有的金币 := "你的背包中拥有的金币："   ## PACK_MONEY(597)
const 你的仓库中拥有的金币 := "你的仓库中拥有的金币："   ## STORAGE_MONEY(127)
const 你希望存多少到仓库中 := "你希望存多少到仓库中："   ## SAVE_STORAGE_MONEY(424)
const 你希望取多少到背包中 := "你希望取多少到背包中："   ## TAKE_STORAGE_MONEY(132)
const 存钱 := "存钱"
const 取钱 := "取钱"

const 色_橙 := Color("ff9100")

## 交易档要换的那两张币图（`MIconGoldCoinF` 17×17 / `MIconGoldYuanBaoF` 19×13）。
## ⚠ 写完整字面量、不拼串 —— 交包时的皮肤扫描只认整串路径。
const 金币皮 := "res://素材/界面/原版窗口/通用控件/金币.png"
const 元宝皮 := "res://素材/界面/原版窗口/通用控件/元宝币.png"
const 数字格式 := preload("res://脚本/界面/数字格式.gd")

var _是存入 := true
var _上限 := 0

@onready var _数量: LineEdit = $数量


func _ready() -> void:
	($减 as Button).pressed.connect(_加减.bind(-1))
	($加 as Button).pressed.connect(_加减.bind(1))
	($MAX as Button).pressed.connect(_填满)
	($确定 as Button).pressed.connect(_确定)
	($取消 as Button).pressed.connect(隐藏)
	($关闭 as Button).pressed.connect(隐藏)
	_数量.text_changed.connect(_限制输入)


## `setData(可操作金额, 是否存入)`。存钱时上限是**身上金币**、取钱时是**仓库金币**
## （`StorageWindow2.as:476` / `:480`）。
##
## `交易档 = true` 走的是**另一扇原版窗**：`SaveCoinOrBeanWindow extends SaveAndTakeMoneyWindow`
## ——版式与这只逐件相同（同一只 `background1`/两张输入底/加减/MAX/确定取消），
## 只换标题、两行文案、那张币图（`SaveCoinOrBeanWindow.as` 的 `setData` + `setPng`）：
##   金币档 = 标题「交易金币」+ 币图 `金币.png` @ (28,**59**)；
##   元宝档 = 标题「交易元宝」+ 币图 `元宝币.png` @ (28,**61**)。
## ⚠ 这时第一个参数**不再是"存/取"**，而是"**金币档 / 元宝档**"，
##   `确认存取` 那一路信号跟着换语义（真 = 金币 → `119:15`、假 = 元宝 → `119:13`）。
## 上限那一格原版走 `BaseUtil.formatNumber`（带千分位）—— `setData:255` 写在**基类**里，
## 仓库档与交易档共用同一行 ⇒ 两条档都要千分位（10-16 见 `真值/窗口/交易与邀请托盘.md §⑬·4`）。
func 打开(是存入: bool, 上限: int, 交易档 := false) -> void:
	_是存入 = 是存入
	_上限 = maxi(0, 上限)
	var 图 := $金币图标 as TextureRect
	if 交易档:
		($标题 as Label).text = "交易金币" if 是存入 else "交易元宝"
		($上标签 as Label).text = "你的背包中拥有的金币：" if 是存入 else "你的背包中拥有的元宝："
		($下标签 as Label).text = "你希望交易多少金币?" if 是存入 else "你希望交易多少元宝?"
		# 这两行在原版都是橙色：金币档的 `tf1` 由代码包 `<font color="#ff9100">`，
		# 元宝档的两行连下标签都自带那个包裹（`PackString` 里就写着颜色）。
		for 名 in ["上标签", "下标签"]:
			(get_node(名) as Label).add_theme_color_override("font_color", 色_橙)
		_摆币图(图, 是存入)
		($持有金额 as Label).text = 数字格式.千分位(_上限)
	else:
		($标题 as Label).text = 存钱 if 是存入 else 取钱
		# 文案与配色按 AS3 原样：存钱那组上标签不带橙色包裹、下标签带；取钱那组两个都带。
		var 上 := $上标签 as Label
		上.text = 你的背包中拥有的金币 if 是存入 else 你的仓库中拥有的金币
		($下标签 as Label).text = 你希望存多少到仓库中 if 是存入 else 你希望取多少到背包中
		_摆币图(图, true)
		## `setData:255` 是**基类**那一条，仓库档与交易档共用 ⇒ 千分位两边都要有。
		($持有金额 as Label).text = 数字格式.千分位(_上限)
	_数量.text = "0"
	# 原版弹窗由 `PopUpMananger` 摆位、**在舞台里居中**（不是挂在父控件原点）。
	# 这里按 960x560 的舞台算，再钳进父级矩形。
	var 舞台 := get_viewport().get_visible_rect().size
	var 父 := get_parent() as Control
	var 中心 := 舞台 * 0.5
	if 父 != null:
		中心 = 父.size * 0.5
	position = Vector2(floorf(中心.x - size.x * 0.5), floorf(中心.y - size.y * 0.5))
	visible = true
	_数量.grab_focus()


func 隐藏() -> void:
	visible = false


## 币图按**各自天然尺寸**摆：金币 17×17 @ (28,59)、元宝 19×13 @ (28,61)
## （`SaveCoinOrBeanWindow.setPng:38-59` 只给 x/y —— Flash 的 Sprite 不缩放）。
## ⚠ 这只控件在场景里是 `expand_mode = EXPAND_IGNORE_SIZE` ⇒ 框尺寸完全由这里给：
##   沿用金币那 17×17 的框去装 19×13 的元宝 = 整张被拉高压扁（用户 10-16 报的"元宝图标不对劲"）。
static func _摆币图(图: TextureRect, 是金币: bool) -> void:
	图.texture = load(金币皮) as Texture2D if 是金币 else load(元宝皮) as Texture2D
	图.position = Vector2(28, 59) if 是金币 else Vector2(28, 61)
	图.size = Vector2(17, 17) if 是金币 else Vector2(19, 13)


func _加减(方向: int) -> void:
	var 当前 := _数量.text.to_int()
	_数量.text = str(clampi(当前 + 方向, 0, _上限))


func _填满() -> void:
	_数量.text = str(_上限)


## 输入超上限强制写回（原版 `on_change`），并把非数字滤掉（`restrict="0123456789"`）。
func _限制输入(新文本: String) -> void:
	var 过滤 := ""
	for 字 in 新文本:
		if 字 >= "0" and 字 <= "9":
			过滤 += 字
	var 值 := 过滤.to_int()
	if 值 > _上限:
		值 = _上限
		var 文本 := str(值)
		if 文本 != 过滤:
			过滤 = 文本
	if 过滤 != 新文本:
		_数量.text = 过滤
		_数量.caret_column = 过滤.length()


func _确定() -> void:
	var 金额 := _数量.text.to_int()
	if 金额 <= 0:
		return
	确认存取.emit(_是存入, 金额)
	隐藏()
