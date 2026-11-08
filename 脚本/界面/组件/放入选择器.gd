extends RefCounted

## 公共「放入选择」弹层（2026-11-08）。
##
## 原版所有"放入 / 投料"钮走的都是 `CursorManager.showCursorUI("UpShelfCursor")`：
## 钮一点把光标切成收集态，玩家再去点背包里的一格。本工程背包是另一个窗口、
## 没有跟手光标件 ⇒ **用户授权的等价通道**：在游标处弹一张只列"本格收得下"的清单，
## 点一条即等于原版"点背包那一格"。先例是 `勾玉炼制窗` / `秘笈合成窗口`，
## 2026-11-08 抽到这里给全工程的放入钮共用（§3.385）。
##
## 两段式：
##   `背包候选(会话, 判据)` —— 过滤 + 拼行（`{格,id,名称,数量,物品}`）；
##   `弹(页, 清单, 选中)` —— 挂在页根下、带图标、点一条回调一行。
## 判据一律传**落点格组件自己的那把闸**（`勾玉放入格.可收` / `残卷放入格.有配方` …），
## 弹层与拖放两路同口径，别在调用点另写一套。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 从会话背包里挑出所有过判据的堆。`判据(件: Dictionary) -> bool` 收整条（含实例字段），
## 不传 = 全收。行里的 `物品` 就是背包里那条本身的引用（收料要读实例字段时用）。
static func 背包候选(会话: Variant, 判据 := Callable()) -> Array:
	var 出: Array = []
	if 会话 == null:
		return 出
	var 清单: Array = 会话.inventory
	for i in 清单.size():
		var 件: Variant = 清单[i]
		if typeof(件) != TYPE_DICTIONARY:
			continue
		var 条 := 件 as Dictionary
		if 条.is_empty():
			continue
		var 物id := String(条.get("id", ""))
		if 物id.is_empty():
			continue
		if 判据.is_valid() and not bool(判据.call(条)):
			continue
		var 格号 := int(条.get("slot_index", 0))
		if 格号 <= 0:
			格号 = i + 1
		出.append({"格": 格号, "id": 物id,
			"名称": String(游戏数据.item(物id).get("name", 物id)),
			"数量": int(条.get("quantity", 1)), "物品": 条})
	return 出


## 在页根下弹清单；点第 N 行 ⇒ `选中.call(清单[N])`。
## 同名旧弹层先 free 再重建：同一页连点两下不会叠层、也不会留下上一条的 `id_pressed` 连接。
## `popup()` 不带坐标 = 开在鼠标位（原版光标件就贴在游标上）。
static func 弹(页: Control, 清单: Array, 选中: Callable, 名 := "放入选择") -> PopupMenu:
	var 旧 := 页.get_node_or_null(名)
	if 旧 != null:
		旧.free()
	var 器 := PopupMenu.new()
	器.name = 名
	器.id_pressed.connect(func(行号: int) -> void:
		if 行号 >= 0 and 行号 < 清单.size():
			选中.call(清单[行号]))
	页.add_child(器)
	for 行号 in 清单.size():
		var 条: Dictionary = 清单[行号] as Dictionary
		器.add_item("%s ×%d" % [String(条.get("名称", "")), int(条.get("数量", 0))], 行号)
		器.set_item_icon(行号, 游戏数据.item_icon(String(条.get("id", ""))))
	器.popup()
	return 器
