extends Control

## 原版**物品拆分**窗（`SplitWindow`）。版式见 开发记录（本地） §3.10.8。
##
##   `SplitWindow.as:19/:42`  `extends UIWindow`、`super(180, 204)`
##   `:72`   标题 `SPLIT_WINDOW_TITLE` = 「物品拆分」
##          （背包调进来时 `ItemWindow2.as:1166-1171` 会 `setTitle(CN.ITEM_CHAIFEN)` 覆盖，
##           两个 key 的中文都是「物品拆分」，所以最终一致）
##   `:74`   黄底 `MYellow_background` @ (6,39) 168×137
##   `:80`   输入框底 `MGrid_background` @ (44,109) 86×20
##   `:91`   说明 `SPLIT_INPUT_QUANTITY` @ (12,44) 宽 160，橙色 `#ff9100`，可换行
##   `:101`  数量输入 @ (47,111) 86，白、`restrict="0123456789"`、`maxChars=4`、居中
##   `:125`  加号 `MPlusBtnF` @ (135,110) 18×18；`:129` 减号 `MMinusBtnF` @ (17,110) 18×18
##   `:111`  确定 @ (25,179) 37×22；`:118` 取消 @ (118,179) 37×22
##
## 取值规则（`:170`、`:62`、`:142`、`:157`）：
##   初值 = **件数 − 1**；加号上限 `件数−1`、减号下限 `1`；
##   **「确定」只校验 `>0`**（对 `件数−1` 没有硬拦截，`maxChars=4` 也允许打到 9999）。

signal 确认拆分(位置: int, 数量: int)

const 减号下限 := 1

var _件数 := 1        ## 原版 `itemData.count`，上限的来源
var _位置 := 0        ## 原版 `itemData.position`，随确认一起发出去

@onready var _数量: LineEdit = $数量


func _ready() -> void:
	($减 as Button).pressed.connect(_加减.bind(-1))
	($加 as Button).pressed.connect(_加减.bind(1))
	($确定 as Button).pressed.connect(_确定)
	($取消 as Button).pressed.connect(隐藏)
	($关闭 as Button).pressed.connect(隐藏)
	_数量.text_changed.connect(_限制输入)


## `setData`（`:170`）：初值 = 件数 − 1
func 打开(件数: int, 位置: int) -> void:
	_件数 = maxi(1, 件数)
	_位置 = 位置
	_数量.text = str(maxi(1, _件数 - 1))
	visible = true
	_数量.grab_focus()


func 隐藏() -> void:
	visible = false


## 加号：`if(_loc2_ < itemData.count - 1) _loc2_++`；减号：`if(_loc2_ > 1) _loc2_--`（`:62`/`:142`）
func _加减(方向: int) -> void:
	var 当前 := _数量.text.to_int()
	var 上限 := maxi(1, _件数 - 1)
	当前 = clampi(当前 + 方向, 减号下限, 上限)
	_数量.text = str(当前)


## 输入框 `restrict="0123456789"` 的等价物（Godot 的 LineEdit 没有 restrict，手动滤）
func _限制输入(新文本: String) -> void:
	var 过滤 := ""
	for 字 in 新文本:
		if 字 >= "0" and 字 <= "9":
			过滤 += 字
	if 过滤 != 新文本:
		_数量.text = 过滤
		_数量.caret_column = 过滤.length()


## `onClickOk`（`:157`）**只校验 `>0`**，然后派发 `ItemEvent.ITEM_SPLIT`
## → `UI.as:711-714` → `requestItemSplit(position, splitCount)`（`ITEM_SPLIT = 1332`）。
func _确定() -> void:
	var 数量 := _数量.text.to_int()
	if 数量 <= 0:
		return
	确认拆分.emit(_位置, 数量)
	隐藏()
