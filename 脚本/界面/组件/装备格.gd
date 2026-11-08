extends "res://脚本/界面/组件/可拖拽格.gd"
## 装备格（人物面板那 20 格用的组件）。
##
## 管两件事：
##   ① 按**物品状态**切换格子上的覆盖层（资质/破碎/耐久/强化/镶嵌，共六层）；
##   ② 当**背包物品的落点** —— 从背包拖装备过来落在这一格就穿上。
##      条件照原版 `EquipPane.onItemUp`（`com/mxw/uifl/controls/char/EquipPane.as:968-996`）：
##      物品的 `getItemEquipPosition(id)` 必须**正好等于**这一格的 `part`，不等就静默丢下。
## 版式（位置/尺寸）全在 `.tscn` 里，这里不碰。
## 每个覆盖层的显示条件都照原版 `EquipmentWindowCell.showIcon`
## （`com/mxw/uifl/controls/cell/EquipmentWindowCell.as:121-174`）逐条对应。
##
## ⚠️ 反向（装备格拖回背包）**故意不做**：原版起拖端是死代码，见 `可拖拽格.gd` 里
## `可拖拽` 那段。原版卸装备走双击 / 物品菜单「卸下」（**左键**弹出），客户端已有单击 `_unequip`。

const 装备部位表 := preload("res://脚本/单例/装备部位.gd")


## 这一格只接**该落在它这儿**的那件装备。
## 出处 `EquipPane.onItemUp`（`:984`）：
##   `if(EquipmentPosition.getItemEquipPosition(this.dragModel.dragData.id) == param1.target.part)`
## 不等时原版**什么都不做、也没有提示**（`:990` 直接 removeDragDataProxy），
## 所以这里返回 false 就够 —— Godot 不会画落点高亮、也不会调 `_drop_data`。
##
## 另有一条原版短路（`:979-983`）：拖来的物品与目标格**是同一件**（category 与 id 都相同）
## → 直接返回。这里等价于"物品 id 与这一格现有的相同就不接"。
## 只认**背包**来的拖拽：原版 `EquipPane.onItemUp`（`:972`）那道判断是
##   `if(this.dragModel.dragData != null && this.dragModel.dragSource == DragManager.ITEM_WINDOW)`
## —— 从随身仓库（`STORAGE_WINDOW`）之类的地方拖过来**什么都不做**（`:994` 只把代理撤掉）。
## 这里把"不接"落在 `_can_drop_data` 上，等于 Godot 不画落点高亮，
## 用户看到的就是"这儿放不下"；原版没有这层光标语义，效果一样是静默无反应。
func _can_drop_data(位置: Vector2, 数据: Variant) -> bool:
	if not super._can_drop_data(位置, 数据):
		return false
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	var 物品id := String(字典.get("物品id", ""))
	if 物品id.is_empty():
		return false
	if 物品id == self.物品id:
		return false
	return 装备部位表.位置(物品id) == 槽位号


## 空格子：把六层覆盖层全关掉。资质框与流光那两层归父类管（`可拖拽格.gd`），
## 其余五层是装备格特有的。
func 清空覆盖层() -> void:
	for 名 in ["破碎角标", "耐久红框", "强化底", "强化数字", "蓝钻", "镶嵌金钻"]:
		var 节点 := get_node_or_null(名) as CanvasItem
		if 节点 != null:
			节点.visible = false
	清空品质覆盖层()


func 设置破碎(破碎: bool) -> void:
	var 节点 := get_node_or_null("破碎角标") as TextureRect
	if 节点 != null:
		节点.visible = 破碎


## 耐久归零的红框。原版 `EquipmentWindowCell.as:171`：`_maskMc.visible = (endure == 0)`。
func 设置耐久归零(归零: bool) -> void:
	var 节点 := get_node_or_null("耐久红框") as TextureRect
	if 节点 != null:
		节点.visible = 归零


## 强化角标。照 `EquipStrengthIcon.setStrengthInfo(level, false)`（`:45-63`）——
## 格子那条路传的 param2 是 `false`，所以蓝钻门槛是 **>= 10**（不是 17）：
##   等级 <= 0  → 什么都不显示
##   1..9       → 底 + 数字
##   >= 10      → 底 + 蓝钻（不再显示数字）
func 设置强化(等级: int) -> void:
	var 底 := get_node_or_null("强化底") as TextureRect
	var 数字 := get_node_or_null("强化数字") as Label
	var 蓝钻 := get_node_or_null("蓝钻") as TextureRect
	var 显示 := 等级 > 0
	if 底 != null:
		底.visible = 显示
	if 蓝钻 != null:
		蓝钻.visible = 显示 and 等级 >= 10
	if 数字 != null:
		数字.visible = 显示 and 等级 < 10
		if 数字.visible:
			数字.text = str(等级)


## 镶嵌金钻。照 `EquipStrengthIcon.isShowGoldIcon`（`:25-43`）：
## **至少 5 个孔，且每个宝石等级都 >= 6**。
func 设置镶嵌(镶嵌表: Array) -> void:
	var 节点 := get_node_or_null("镶嵌金钻") as TextureRect
	if 节点 != null:
		节点.visible = 该显示金钻(镶嵌表)


static func 该显示金钻(镶嵌表: Array) -> bool:
	if 镶嵌表.size() < 5:
		return false
	for 条 in 镶嵌表:
		if not (条 is Dictionary) or int((条 as Dictionary).get("stone_level", 0)) < 6:
			return false
	return true
