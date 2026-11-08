extends Control
## 「变身卡互换」窗两枚卡格的**落点件**（2026-10-13 接"从背包装入"）。
##
## 原版那一跳是 `UIMain2.as:1874-1950` 的 `onSwapDropA/onSwapDropB`：背包格把 `ItemData`
## 交给 `swapCardA/B`（`:610-611` 注册的 `dropFun`）。本工程照 §3.127~§3.130 那一族用**拖放**：
## 卡格是场景里的 `TextureRect`、挂不了 `可拖拽格`（Button 基）⇒ 本件 `extends Control`、
## 运行期 `set_script` 挂上去（先例 `徽章放入格.gd`）。
##
## 本件只判**类型**那一闸；其余四闸（`position<=0` / `expiration>0` /
## 普通版 `reforgeTime>0` / 与另一格同一张）在 `变身卡互换窗.放入` 里 —— 那几条要看得见 A/B 两格。

signal 请求放入(背包格: int)

## 页面填：这是哪一格（"A" / "B"）。
var 路 := "A"


## `int(id / 10000) == 121`（`UIMain2.as:1879/1918`）。
## ⚠️ 变身卡 id 是**八位 `0121xxxx`** —— `int("01210441") = 1210441`、`/10000 = 121` ✓；
##    别拿字面 `"12100050"`（那是"写轮眼卡"、另一类）当样本（§3.129 那族 id 形态的坑）。
static func 可收(物品id: Variant) -> bool:
	var 文 := String(物品id)
	if not 文.is_valid_int():
		return false
	return int(int(文) / 10000) == 121


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
