extends RefCounted

## 离线门的「净效果为零」工具：开场 `全快照()`，收尾 `全还原()`。
##
## 为什么不是"内存态还原后再 `_save_local_state()`"：8 条旧门（姓名战斗挂机 / 拖拽穿装备 /
## 装备格点击 / 装备穿卸离线 / 背包道具 / 富岳两窗 / 家族旗帜说明 / 自选礼包窗）都这么做过，
## 跑批器仍逐条点名"写档" —— 因为 `_save_local_state()` 的**序列化键序/成形**与磁盘上那一份
## 不必逐字节相同。内存里字段确实回去了，但文件变了。
## ⇒ 想要"跑批器不再点名"，只能**按字节快照、按字节还原**（跑批器 `跑全部离线门.py` 兜底用的
##   就是这同一套；门自己做了，那层就不会点名）。
##
## 开工前文件不存在 ⇒ 收尾把本门造出来的那份删掉（不是留一个空 JSON）。
## 同时管 `user://玩家设置.json`：`backend_authoritative` 分支的 `_save_local_state()`
## 写的是它，跑批器只看玩家数据、会漏掉这一份。

const 玩家档 := "user://玩家数据.json"
const 设置档 := "user://玩家设置.json"


static func 读字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var f := FileAccess.open(路, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var 字节 := f.get_buffer(f.get_length())
	f.close()
	return 字节


static func 全快照() -> Dictionary:
	return {玩家档: 读字节(玩家档), 设置档: 读字节(设置档)}


static func _还原一份(路: String, 前: PackedByteArray) -> bool:
	if 读字节(路) == 前:
		return true
	if 前.is_empty():
		if FileAccess.file_exists(路):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(路))
		return not FileAccess.file_exists(路)
	var f := FileAccess.open(路, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(前)
	f.close()
	return 读字节(路) == 前


## 返回是否全部按字节还原（门里可拿来断言）。
static func 全还原(前: Dictionary) -> bool:
	var 好 := true
	for 路 in 前:
		好 = _还原一份(String(路), 前[路] as PackedByteArray) and 好
	return 好
