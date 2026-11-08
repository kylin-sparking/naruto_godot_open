extends RefCounted

## 「格数扩展」每页要几个扩充密卷 —— 读 `数据/界面/扩容需求.json`。
##
## 那份表的真值来自 2.2.3 GameData 顶层 `Etc` 段的 `BeibaoKuozhan` / `CangKuKuoZhan`
## 两条（生成器 `开发工具/导出扩容需求.py`），两边取值相同：
## 密卷 **16000004**（扩充密卷），每页需求 2;6;18;54;162;496;1458;4374;…
##
## ⚠️ **下标怎么用是以服务端为准的**（`fake_flash_server.py:25967-25968`）：
##   `page_index = max(0, ceil(当前容量 / 30) - 1)`
##   `required   = 每页需求[min(page_index, 长度-1)]`
## 也就是**从 1 页扩到 2 页要 2 个**、不是 1 个。

const 路径 := "res://数据/界面/扩容需求.json"
## 每页格数：背包 90（用户 2026-10-31 口径：10 列 x 9 行）、仓库 30（原版）。
## 服务端 `fake_flash_server.py` 的 `BAG_PAGE_SIZE=90` / `INVENTORY_PAGE_SIZE=30` 必须与这里一致。
static func 每页格数(归属: String) -> int:
	return 90 if 归属 == "背包" else 30

static var _表: Dictionary = {}


static func _读表() -> Dictionary:
	if not _表.is_empty():
		return _表
	if not FileAccess.file_exists(路径):
		push_error("扩容需求表缺失：%s" % 路径)
		return {}
	var 解析: Variant = JSON.parse_string(FileAccess.get_file_as_string(路径))
	if typeof(解析) != TYPE_DICTIONARY:
		push_error("扩容需求表不是合法 JSON 对象：%s" % 路径)
		return {}
	_表 = 解析 as Dictionary
	return _表


## 返回 `{"密卷id": String, "需要数量": int}`。`页号` 是**要扩到第几页**（1 基）。
## 取不到时返回一套保守值（1 个密卷），并在控制台报错——不静默编数。
static func 取需求(归属: String, 页号: int) -> Dictionary:
	var 表 := _读表()
	var 条: Dictionary = 表.get(归属, {}) as Dictionary
	if 条.is_empty():
		push_error("扩容需求表里没有「%s」" % 归属)
		return {"密卷id": "", "需要数量": 1}
	var 需求: Array = 条.get("每页需求", []) as Array
	if 需求.is_empty():
		push_error("扩容需求表「%s」的每页需求是空的" % 归属)
		return {"密卷id": String(条.get("密卷id", "")), "需要数量": 1}
	# `页号` = ceil(当前容量/30)，而服务端的 `page_index = ceil(当前容量/30) - 1` ——
	# 所以**下标 = 页号 - 1**（不是 -2）。96 格时页号 4 → costs[3] = 54。
	var 下标 := clampi(页号 - 1, 0, 需求.size() - 1)
	return {"密卷id": String(条.get("密卷id", "")), "需要数量": int(需求[下标])}


## 只取密卷 id（兽栏扩容用）。
##
## ⚠️ **兽栏扩容读的就是背包那一条 `Etc.BeibaoKuozhan`**：服务端
## `fake_flash_server.py:5965` 的 `capacity_expansion_config(storage=False)` ⇒ 同一个
## `section_name = "BeibaoKuozhan"`。所以这里传 `"背包"`，别再往表里加一个假的「兽栏」行。
## 但**需求数不走每页曲线**：`_extend_pet_capacity:26221` 用 `max(1, 当前容量 − 3)`，
## 与原版 `PetWindow.as:366` 的 `curSoltNum − 3` 同一个口径。
static func 密卷id(归属: String) -> String:
	return String(_读表().get(归属, {}).get("密卷id", ""))


## 背包里那件密卷有几件（原版 `updateItemCount` 用它决定「确定」能不能点）。
static func 拥有数(会话, 密卷id: String) -> int:
	if 密卷id.is_empty() or 会话 == null:
		return 0
	for 物品 in 会话.inventory:
		if String((物品 as Dictionary).get("id", "")) == 密卷id:
			return int((物品 as Dictionary).get("quantity", 0))
	return 0
