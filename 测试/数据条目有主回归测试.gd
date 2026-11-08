## 「表里有、代码没人读」的条目必须**全部有理由**（孤儿数据门）。
##
## 为什么非要有这道门（2026-10-09 用户问「为什么做不出和原版一样的流程」的直接答案之一）
## ------------------------------------------------------------------
## `Effect_PathFindingTip`（自动寻路中）的图和 `数据/特效.json` 里的条目**早就在盘上**，
## 全工程没有一行代码播它，而 76 道门全绿 —— 因为**没有任何一道门问过"这条数据有没有人读"**。
## 小地图那 17 枚标记（怪/队友/好友/家族旗/按职业分色的 NPC 点）同一形状：条目齐、图齐、没人画。
## 这类漏项是**结构上测不出来**的，不补这道门就还会再犯。
##
## 判据是**双向**的（只判一个方向就会退化成摆设）：
##   ① 每条孤儿必须落进 `数据/界面/孤儿条目基线.json` 的某个前缀组 ⇒ 新增数据忘了接线会红；
##   ② 每个声明的组必须**至少还命中一条** ⇒ 把某组接完了却没删基线，也会红（防清单腐烂）。
## 另加 ③ 每条的贴图都在盘上（防"条目在、图被挪走"这种半拉子）。
##
## 基线由 `开发工具/出孤儿基线.py` 生成，**理由那一句是写给人读的**，不许留 TODO。
extends SceneTree

const 基线路 := "res://数据/界面/孤儿条目基线.json"
const 表们 := [
	{"路": "res://数据/特效.json", "段": "特效"},
	{"路": "res://数据/界面/小地图标记.json", "段": "标记"},
]

var _失败: Array[String] = []
var _条数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


## 把所有 .gd / .tscn 拼成一整篇文本，用来判"这个键名有没有在任何一处出现过"。
func _全源码() -> String:
	var 出 := ""
	for 根 in ["res://脚本", "res://场景"]:
		出 += _扫(根)
	return 出


func _扫(路: String) -> String:
	var 出 := ""
	var 目 := DirAccess.open(路)
	if 目 == null:
		return 出
	目.list_dir_begin()
	var 名 := 目.get_next()
	while 名 != "":
		if not 名.begins_with("."):
			var 全 := 路.path_join(名)
			if 目.current_is_dir():
				出 += _扫(全)
			elif 名.ends_with(".gd") or 名.ends_with(".tscn"):
				出 += FileAccess.get_file_as_string(全) + "\n"
		名 = 目.get_next()
	return 出


func _run() -> void:
	var 基线: Variant = JSON.parse_string(FileAccess.get_file_as_string(基线路).trim_prefix("\ufeff"))
	_断言(typeof(基线) == TYPE_DICTIONARY, "读不出 %s" % 基线路)
	if typeof(基线) != TYPE_DICTIONARY:
		_finish()
		return
	var 组: Dictionary = (基线 as Dictionary).get("组", {}) as Dictionary
	_断言(not 组.is_empty(), "基线里一个组都没有 ⇒ 这道门等于没判")
	var 源码 := _全源码()
	_断言(源码.length() > 200000, "拼出来的源码只有 %d 字符，扫描没跑对（门会假绿）" % 源码.length())

	var 总孤 := 0
	var 总条 := 0
	## ⚠ 命中表**跨两张表累计**：21 个组是两张表合起来才凑齐的，
	## 每张表各自清零会让另一半组在第二张表上集体假红（第一版就红了 17 条）。
	var 命中: Dictionary = {}
	for k in 组:
		命中[String(k)] = 0
	for 表 in 表们:
		var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(表["路"])).trim_prefix("\ufeff"))
		if typeof(解) != TYPE_DICTIONARY:
			_断言(false, "读不出 %s" % String(表["路"]))
			continue
		var 段: Dictionary = ((解 as Dictionary).get(String(表["段"]), 解) as Dictionary)
		var 键: Array = 段.keys()
		键.sort()
		总条 += 键.size()
		for k in 键:
			var 条: Dictionary = 段[k] as Dictionary
			## ③ 贴图必须在盘上
			for f in (条.get("帧", []) as Array):
				var 图 := String((f as Dictionary).get("贴图", ""))
				if 图 != "" and not ResourceLoader.exists(图):
					_断言(false, "%s 的这条贴图不在盘上：%s（条目在、图没了 = 半拉子）" % [String(表["路"]), 图])
			if String(k) in 源码:
				continue
			总孤 += 1
			## ① 每条孤儿要落进某个声明组；落不进就是"新增数据没接线也没写理由"
			var 归 := ""
			for 前 in 组:
				if String(k).begins_with(String(前)):
					归 = String(前)
					命中[归] = int(命中[归]) + 1
					break
			_断言(归 != "", "%s 的条目「%s」既没有读取方、也不在基线任何一组里 ⇒ 接上它，或在 出孤儿基线.py 里补一组并写清为什么" % [String(表["路"]), String(k)])
	_断言(总条 >= 140, "两张表一共只有 %d 条，比预期少很多 ⇒ 扫描或表路径不对" % 总条)
	## ② 每个声明组必须还命中至少一条（两表跑完之后再判）
	for 前 in 组:
		_断言(int(命中[String(前)]) > 0,
				"基线里这组「%s」已经一条都不命中了 ⇒ 要么接完了该删组，要么前缀写错了（清单腐烂）" % String(前))
	print("数据条目有主回归测试：表内 %d 条，孤儿 %d 条，全部落进 %d 个声明组（%d 条断言）" % [总条, 总孤, 组.size(), _条数])
	if 总孤 == 0:
		_失败.append("孤儿数变成 0 了？要么真接完了、要么源码扫描失效 —— 两种都要人看一眼，别默默放行")
	_finish()


func _finish() -> void:
	if _失败.is_empty():
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("数据条目有主回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
