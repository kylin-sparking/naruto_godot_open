extends Control
## 交易窗里的一格 = 原版 `TradeWindowCell`（`controls/cell/TradeWindowCell.as`）。
## 版式逐件出处见 `真值/窗口/交易与邀请托盘.md` §②，**几何全烘进 `交易格.tscn`**
## （编辑器里看得见 = 运行时看得见，运行期只换文字与图标）。
##
## 结构照 AS3 的 addChild 顺序（`:33-50`）：格底(Button 40×40，图标在它里面居中)
## → 数量 → 名字。数量与名字在原版是**格的兄弟件**、不是格底的子件；
## 本工程把数量挂进格底是为了复用 `可拖拽格.设置品质()` 那套覆盖层（它按宿主=格子算偏移），
## 视觉上两处 y 一致（0,22 与格底原点重合），不引入偏差。

## 有东西落到这一格（`交易槽`, 载荷）。载荷就是 `可拖拽格._drop_data` 那个字典。
signal 落到(交易槽: int, 载荷: Dictionary)

## 点这一格（原版没有单击行为，本工程用它做「上架模式点背包物品」的目标反馈 ⇒ 不接线时不响）
signal 被点击(交易槽: int)

@onready var 格: Button = $格
@onready var 数量: Label = $格/数量
@onready var 名字: Label = $名字

var 交易槽 := 1
var 物品: Dictionary = {}


func _ready() -> void:
	格.拖放.connect(_收拖放)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_收鼠标)


## 只有**我这侧**的格能当落点（原版给 10 个格都挂了 `MSPRITE_UP`，
## 但 `onItemUp` 只认 `dragSource == ITEM_WINDOW` 且永远落在 `myCellArr` 的那一侧 ——
## `TradeWindow2.as:399-402` 取的是 `myCellArr.indexOf(target)`）。
## 归属/槽位由 `交易窗.gd` 的 `_接格子()` 统一填，不在这里自己认领。
func _收拖放(来源格: Button, 目标格: Button, 物品id: String) -> void:
	落到.emit(交易槽, {"来源格": 来源格, "目标格": 目标格, "物品id": 物品id})


func _收鼠标(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton:
		var 键 := 事件 as InputEventMouseButton
		if 键.button_index == MOUSE_BUTTON_LEFT and 键.pressed:
			被点击.emit(交易槽)


## `setCellValue`（`:85-139`）：有物品就画，空字典就是空格。
## ⚠ 空格的清法是 `removeData()`（`:141-171`）：格底**留着**、图标与两行文字清掉、覆盖层摘掉。
func 填(件: Dictionary) -> void:
	物品 = 件
	if 件.is_empty():
		格.icon = null
		格.disabled = true
		数量.text = ""
		名字.text = ""
		格.call("清空品质覆盖层")
		return
	格.disabled = false
	var 图标路径 := String(件.get("icon", ""))
	格.icon = (load(图标路径) as Texture2D) if ResourceLoader.exists(图标路径) else null
	# `:133-136` 只有 `count > 1` 才写字（1 件不带角标）
	var 件数 := int(件.get("quantity", 1))
	数量.text = str(件数) if 件数 > 1 else ""
	名字.text = String(件.get("name", ""))
	# 资质框 + 紫橙流光：原版 `:95-108` 也是按物品实例叠的（aptitude 有才叠）
	格.call("设置品质", 件, true)


## 空格子的运行时判据（门用它钉"清空真的清到了")。
func 是空的() -> bool:
	return 物品.is_empty() and 名字.text == "" and 格.icon == null
