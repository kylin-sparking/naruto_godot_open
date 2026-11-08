extends "res://脚本/界面/组件/可拖拽格.gd"
## 宠物装备格（`PetWindow` 右侧 5 格）。
##
## 原版对应 `SimpleItemCell`（`PetWindow.as:477-508`）的两个回调：
##   `dropItemFun = petPutOnEquip` —— **拖进来穿上**（`PetWindow.as:264-267`）；
##   `clickFun    = petTakeOffEquip` —— **点一下卸下**（`PetWindow.as:527-530`）。
## 所以这一格是**只接不吐**：`可拖拽` 保持 false，与原版一致（原版起拖端也是死代码，
## 见 `可拖拽格.gd` 里 `可拖拽` 那段）。
##
## ## 部位判据用**公共表**，不自己算
## `装备部位.gd:97` 的 `4 位前缀 → 位置` 里本来就有宠物五槽
## （`201→宠物一(兽铠) … 205→宠物五(变身)`），`位置()` 对宠物装备直接返回 **1..5**。
## 这与人物面板 `装备格.gd` 是**同一条判据**（`位置(id) == 槽位号`），
## 所以这里继承同一个写法；别再手写 `int(id)/10000 == 200+部位` 抄第二份
## （§0.0 第一原则：同一份真值不抄两遍）。
##
## 部位不对 → 返回 false，Godot 不画落点高亮；原版 `onItemUp` 不匹配也是静默撤代理，
## 手感一致（用户看到的就是"这儿放不下"）。

const 装备部位表 := preload("res://脚本/单例/装备部位.gd")


func _can_drop_data(位置: Vector2, 数据: Variant) -> bool:
	if not super._can_drop_data(位置, 数据):
		return false
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	var 物品id := String(字典.get("物品id", ""))
	if 物品id.is_empty() or 物品id == self.物品id:
		return false
	return 装备部位表.位置(物品id) == 槽位号
