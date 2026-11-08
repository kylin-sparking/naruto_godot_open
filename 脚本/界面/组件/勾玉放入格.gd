extends Control
## 「勾玉炼制」三页投料框的**落点件**（2026-10-13 接投料）。
##
## 原版三页各有一个 `ItemDropBox.itemCell`，`dropItemFun = dropItemHandler` → `validateItem`；
## 投料钮走的是**光标收集态**（`YuLianUpgragePanel:67` / `GouYuCompositePanel:67` /
## `GouYuResetPanel:65`：`CursorManager.showCursorUI("UpShelfCursor")` + `UIConfig.dropValidateFun`）。
## 本工程没有跟手光标件 ⇒ 照同族的**拖放**（先例 `宝石放入格` / `残卷放入格` /
## `徽章放入格` / `修复放入格`）。投料格是场景里的 `NinePatchRect`，
## 挂不了 `可拖拽格`（Button 基）⇒ 本件 **`extends Control`**，运行期 `set_script` 挂上去。
##
## 收不收（原版三个 `validateItem` 的**类型**那一闸）：
##   · 页0 `YuLianUpgragePanel.validateItem:82`：`ItemFactory.isItemAYuLian(id)`
##     = `getItemEquipPosition(id) == EquipS1` ⇒ 我们 `装备部位.位置(补零) == 装备部位.勾玉`
##     （四位码 **120**，如稻荷玉链 `01200010`…八尺琼玉链 `01200060`）；
##   · 页1 `GouYuCompositePanel.validateItem:283`、页2 `GouYuResetPanel.validateItem:109`：
##     `ItemFactory.isItemAGouYu(id)` = `isItemABaoShi(id)` 且 `id.toString().substr(0,3) == "131"`
##     ⇒ 我们 `补零.substr(0, 3) == "131"`（勾玉 1~15 级 `13100xxx`）。
##
## ⚠️ 这是 §3.129 那个 **id 形态**的老地方：勾玉**就是**判 `"131"` 前缀（原版也用八位），
##    而昆虫是 `0131xxxx`（前三位 `013`）—— 别把两者混了。
##
## ⚠️ 本件只判"这一类能不能落"；**满级 / 拆开**那两句弹话在页面
##    （`勾玉炼制窗.满级或拆开提示`）—— 与 `徽章放入格`/`修复放入格` 同一分工。

const 装备部位 := preload("res://脚本/单例/装备部位.gd")

## 落上一件合格料 → 请求放入（参数 = **来源背包格号**，1 基；原版提交发的就是这个 `position`）。
signal 请求放入(背包格: int)

## 页面填：这是第几页（0 = 玉链升阶 / 1 = 勾玉合成 / 2 = 勾玉重置）。
var 本页 := 0


## 这一页收不收这件（原版三个 `validateItem` 的类型闸）。判据做成 static：页面/门都能直接问。
static func 可收(物品id: Variant, 页: int) -> bool:
	var 文 := String(物品id)
	if not 文.is_valid_int():
		return false
	var 补零 := 文.pad_zeros(8)
	if 页 == 0:
		return 装备部位.位置(补零) == 装备部位.勾玉       # `isItemAYuLian`：EquipS1
	return 补零.substr(0, 3) == "131"                      # `isItemAGouYu`：前三位 131


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	return 可收(String(字典.get("物品id", "")), 本页)


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Node
	if 来源 == null:
		return
	请求放入.emit(int(来源.get("槽位号")))
