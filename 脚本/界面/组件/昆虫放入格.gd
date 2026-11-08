extends Control
## 寄坏之术页四个虫槽（`虫槽区域/寄坏槽一..四`）的**落点件**。
##
## 场景由 SPEC 生成、**不许手改 `.tscn`** ⇒ 本件 `extends Control`、运行期 `set_script`
## 挂到 TextureButton 上（同族先例：`勾玉放入格` / `徽章放入格` / `修复放入格`；
## Control 基脚本可挂其任意派生类节点）。
##
## 原版真值（本轮 2026-10-27 逐字重读 `KunChongPanel.as` 定死，两处反直觉）：
##   · `cellMouseUpHandler:152-164` —— 虫槽的 MOUSE_UP **只认** `dragSource ==
##     DragManager.ITEM_WINDOW`（背包）的拖拽，且 `ItemType.isItemAKunChong(id)`；
##   · `isItemAKunChong`（`ItemType.as:285-288`）= `String(id).substr(0,3) == "131"` ——
##     **不是**按 `getItemEquipPosition` 判位（那条是 `KunChongE(-205)`，双击佩戴那条路
##     算出的落位会被服务端 `_can_equip` 拒 ⇒ **拖是原版唯一的穿虫路径**）。
##     ⚠ 前缀是 `131`、**勾玉（`13100xxx`，物品表分类=宝石）同样过这道闸** —— 原版客户端
##     就是这么宽，兜底的是服务端：`_can_equip` 认 `GAME_DATA_CATALOG` 的装备定义、
##     勾玉没有 ⇒ 拒（静默、报文照发）。这条"131 前缀勾玉也算"的坑与
##     `勾玉放入格.gd:19-20` 的告警同族，别拿"位置==昆虫包"当类型闸。
##   · `createCell:241-245` —— 只给 `_isMyself` 的格挂 CLICK/MOUSE_UP ⇒ **看别人时这
##     个落点根本不存在**：页面脚本在只读分支把 `槽位号` 归零（0 = 不认领）并拆掉复用旧连线，
##     ⚠ 挂同一份脚本时 `set_script` 是 no-op、变量**不会**自己回默认（2026-10-27 门 ⑦ 实测）。
##
## 分工照 `勾玉放入格`：本件只管**客户端那半道闸**（归属=背包 + 131 前缀）；
## 服务端那半（是不是真虫）由页面处理函数用**物品表分类**镜像，再走协议。

## 落上一件过闸的件 → 请求穿入（参数 = **来源背包格号**，1 基；
## 原版发的就是 `dragData.position`，服务端 `inventory.get(槽)` 按它取件）。
signal 请求放入(背包格: int)

## 页面填：这一格是哪个虫槽（`装备部位.昆虫一..四`，负数）。0 = 没认领，不当落点。
var 槽位号 := 0


## 类型闸 = `ItemType.as:285-288` 逐字：`String(id).substr(0, 3) == "131"`。
## 原版 param1 是 int（`String()` 永不带前导零）⇒ 我们先过一道 int 归一，
## 让 "01310001" 这种补零形态与原版同判（否则前缀成了 "013"，见 `勾玉放入格` 的同款告警）。
static func 可收(物品id: Variant) -> bool:
	var 文 := String(物品id)
	if not 文.is_valid_int():
		return false
	return str(int(文)).substr(0, 3) == "131"


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if 槽位号 == 0 or typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	# 原版 `_loc3_.dragSource == DragManager.ITEM_WINDOW`：只认**背包**起拖的件。
	if String(字典.get("归属", "")) != "背包":
		return false
	var 来源 := 字典.get("来源格") as Node
	if 来源 == null or 来源 == self:
		return false
	return 可收(String(字典.get("物品id", "")))


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Node
	请求放入.emit(int(来源.get("槽位号")))
