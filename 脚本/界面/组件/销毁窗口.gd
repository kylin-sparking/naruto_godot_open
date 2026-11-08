extends Control

## 原版**物品销毁**窗（`DestroyWindow`）。版式见 开发记录（本地） §3.10.8。
##
##   `DestroyWindow.as:19/:42`  `extends UIWindow`、`super(180, 204)`
##   `:101`  标题 `DESTROY_WINDOW_TITLE` = 「物品销毁」
##   `:102`  黄底 `MYellow_background` @ (6,39) 168×137
##   `:108`  提示 `MGlowLabel` @ (6,42) 宽 168，文案 `DESTROY_OK` = 「你确定销毁物品吗？」（橙色）
##   `:115`  物品名 `MGlowLabel` @ (0,71) 宽 180、居中
##   `:123`  物品格 `ItemWindowCell` @ **(70,92)** 40×40（x = `(180−40)>>1`）
##   `:127`  确定 @ (25,179)；`:134` 取消 @ (118,179)
##
## ⚠️ 按钮宽与拆分窗**不一样**：`:142/:144` 把 `isScale9Grid` 改回 `true` ⇒
## `MButton3.measure()` 令宽 = **文字宽 + 6**（`MButton3.as:378-398`），源码没有像素定值。
## 拆分窗是固定 37。这里按"文字宽 + 6"算。
##
## ⚠️ `BaseUtil.getLabel` 返回的标签内部 `textField.y = 2`（`MLabel.as:207`），
## 所以 `y=42` 的文字实际渲染在 ≈44、`y=71` 的在 ≈73 —— 与本组件里标签的 y 一致。
##
## 销毁协议 —— 三条路，按上下文分（`DestroyWindow.as:46-71`）：
##   跨服战袋 → `WAR_BAG_ACTION(1824)`：`byte 4, int position`
##   **普通背包** → `ITEM_MOVE(68)`：`byte category=0, short src, short 0, short dropCount(=件数)`
##   **仓库** → `STORAGE(59)`：`byte 6, int src`
## ⚠️ 销毁**不走** `ITEM_CHANGE(1040)` —— 那个 opCode 是装备类操作（镶嵌/强化/洗炼）。
## 客户端两条现成：`游戏会话.discard_item(物品id, 数量)` / `后端.request_storage_remove_item(槽位)`。

signal 确认销毁(归属: String, 槽位: int, 物品id: String, 件数: int)

## `DESTROY_OK`（`en_US$message_properties.as:3207`）
const 提示文案 := "你确定销毁物品吗？"
## `MButton3.as:378-398` measure()：`_width = tf.width + 6`
const 按钮文字留白 := 6.0
const 按钮高 := 22.0

var _归属 := "背包"
var _槽位 := 0
var _物品id := ""
var _件数 := 1


func _ready() -> void:
	($确定 as Button).pressed.connect(_确定)
	($取消 as Button).pressed.connect(隐藏)
	($关闭 as Button).pressed.connect(隐藏)
	($提示 as Label).text = 提示文案


## `setData`：显示物品名与图标；销毁数量就是**整叠件数**（`:57-62` 的 `dropCount = count`）。
func 打开(物品id: String, 物品名: String, 图标: Texture2D, 件数: int, 归属: String, 槽位: int) -> void:
	_物品id = 物品id
	_件数 = maxi(1, 件数)
	_归属 = 归属
	_槽位 = 槽位
	($物品名 as Label).text = 物品名
	($物品格/图标 as TextureRect).texture = 图标
	_自适应按钮宽()
	var 舞台 := get_viewport().get_visible_rect().size
	var 父 := get_parent() as Control
	if 父 != null:
		position = Vector2(floorf((父.size.x - size.x) * 0.5), floorf((父.size.y - size.y) * 0.5))
	else:
		position = Vector2(floorf((舞台.x - size.x) * 0.5), floorf((舞台.y - size.y) * 0.5))
	visible = true


func 隐藏() -> void:
	visible = false


## 原版把 `isScale9Grid` 设回 true 后由 `measure()` 把宽算成"文字宽 + 6"。
## 取消按钮的 x 是 `cellBackground.x + cellBackground.width - 宽 - 19`（`:138`），
## 所以宽度一变，它也跟着往左移。
func _自适应按钮宽() -> void:
	var 确定 := $确定 as Button
	var 取消 := $取消 as Button
	var 字体 := 确定.get_theme_font("font")
	var 字号 := 确定.get_theme_font_size("font_size")
	for 按钮 in [确定, 取消]:
		var 文字宽 := 字体.get_string_size(按钮.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
		var 宽 := ceilf(文字宽 + 按钮文字留白)
		按钮.size = Vector2(宽, 按钮高)
	取消.position.x = 6.0 + 168.0 - 取消.size.x - 19.0


func _确定() -> void:
	确认销毁.emit(_归属, _槽位, _物品id, _件数)
	隐藏()
