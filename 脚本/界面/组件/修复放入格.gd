extends Control
## 「破碎装备修复」窗装备格的**落点件**（2026-10-11）。
##
## 原版那一支是 `ItemDropBox.dropBtn` 的**光标收集态**（`EquipRepairWindow.clickDropBtnHandler:76-89`：
## 点「放入装备」把鼠标切成 `UpShelfCursor`、挂 `UIConfig.dropValidateFun = validateItem`），
## 本工程没有跟手光标件 ⇒ 用同族的**拖放**（先例：`宝石放入格.gd` / `残卷放入格.gd` /
## `徽章放入格.gd`）。装备格是场景里的 `TextureRect`、挂不了 `可拖拽格`（Button 基）
## ⇒ 本件 **`extends Control`**，运行期 `set_script` 挂上去。
##
## 收不收：原版 `EquipRepairWindow.validateItem:230-263` 的第一道闸门 ——
## **只有「打造装备」**（`ItemType.isItemADaZaoZhuangBei` = 类型 1/2 装备-玩家/宠物）能进，
## 且**时装 / 玉链 / 徽章**要在那里弹话拒掉。
## ⚠️ "必须处于破碎状态"**不在本件**：原版那是收下之后 `updateView` 那一步才判的话
## （`validateItem` 里 `crashTime == 0` ⇒ 弹「对不起，该装备没有破损！」**并不收**）——
## 本工程口径是**落点先收、页面弹话**（与宝石那两支一致：组件只认"这一类能不能落"）。

const 装备部位 := preload("res://脚本/单例/装备部位.gd")

## 落上一件打造装备 → 请求放入（参数 = 来源背包格号，1 基）。
signal 请求放入(背包格: int)


## 这一件是不是"可以放进修复台的打造装备"（原版 `isItemADaZaoZhuangBei` + 三条排除）。
static func 可收(物品id: Variant) -> bool:
	var 文 := String(物品id)
	if not 文.is_valid_int():
		return false
	var 补零 := 文.pad_zeros(8)
	# 类型 1 装备-玩家 / 2 装备-宠物（`ItemType.ZhuangBeiPlayer/Pet`）
	var 类型号 := int(补零.substr(0, 2))
	if 类型号 != 1 and 类型号 != 2:
		return false
	if 补零.substr(2, 2) == "21":            # `isItemAShiZhuang`：时装/变身卡
		return false
	var 四位 := int(补零.substr(0, 4))
	return 四位 != 120 and 四位 != 141       # 玉链 / 徽章


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	return 可收(String(字典.get("物品id", "")))


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Node
	if 来源 == null:
		return
	请求放入.emit(int(来源.get("槽位号")))
