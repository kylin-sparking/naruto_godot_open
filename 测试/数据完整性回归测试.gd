extends SceneTree

## 数据完整性回归：**表都装得上、覆盖层守规矩、条目有名字**。
##
## 为什么要有它（2026-09-25，落实 §3.28.1 第 2 条）：
##   内容一上量（新地图/新物品/新技能），最容易出的不是"崩"，而是**静默退化** ——
##   某个字段漏了、某条自研把原版盖掉了、某张表导出坏了，
##   表现是"名字显示成一串编号""数值显示成 0"，**没人知道是数据的问题**。
##   这类病在本项目已经被坑过三次（攻速/移速恒 0、装备部位五份定义、活跃度 thresholds 名不对）。
##
## 它查四件事：
##   ① 必需表**装得上且非空**（`游戏数据.gd` 自己也会 push_error，这里再钉一道）
##   ② **覆盖层只新增、不改原版** —— `数据_扩展/<表>.json` 的键**不得与** `数据/<表>.json` 重叠
##      （§3.28.3 那条纪律，此前只写在文档里，没有机器守）
##   ③ 物品 / 技能 / 怪物 / NPC 的每条记录都有 `id` 与 `name`
##   ④ 地图索引与 `场景/生成/` 的烘焙产物**数量对得上**（168）
##
## 运行：Godot --headless --path . --script res://测试/数据完整性回归测试.gd

const 数据目录 := "res://数据"
const 扩展目录 := "res://数据_扩展"
const 生成目录 := "res://场景/生成"

## 必需表：空掉就说明导出坏了（与 `游戏数据.gd` 的 `必需表` 保持一致）。
const 必需表 := ["怪物", "NPC", "物品", "技能", "地图名"]

## 每条记录必须带这几个键的表（值是"人看的东西"，缺了就会显示成编号）。
const 要求有名字 := ["物品", "技能", "怪物", "NPC"]

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_查表非空()
	_查覆盖层只新增()
	_查条目有名字()
	_查地图数()
	if _失败.is_empty():
		print("数据完整性回归测试：通过（必需表 %d 张、覆盖层只新增、条目有名字、地图索引与烘焙产物一致）"
			% 必需表.size())
		quit(0)
		return
	for 项 in _失败:
		push_error("数据完整性回归测试：失败 - %s" % 项)
	print("数据完整性回归测试：失败 %d 条" % _失败.size())
	quit(1)


func _读(路径: String) -> Variant:
	if not FileAccess.file_exists(路径):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(路径).trim_prefix("﻿"))


func _查表非空() -> void:
	for 表 in 必需表:
		var 数据 = _读("%s/%s.json" % [数据目录, 表])
		if 数据 == null:
			_失败.append("必需表「%s」读不出来或不是合法 JSON" % 表)
		elif not 数据 is Dictionary:
			_失败.append("必需表「%s」不是字典" % 表)
		elif (数据 as Dictionary).is_empty():
			_失败.append("必需表「%s」是空的 —— 所有查它的地方都会静默退化成显示原始 id / 0" % 表)


## §3.28.3 的纪律：**`数据/` 是从原版导出的、只读；自研内容进 `数据_扩展/`，只许新增。**
## 覆盖层里出现原版已有的 id，就意味着"这条把原版改了" —— 会让"和原版一致"的校验失去意义，
## 而且下次重新导出原版时谁也说不清哪份是真的。
func _查覆盖层只新增() -> void:
	var 目录 := DirAccess.open(扩展目录)
	if 目录 == null:
		_失败.append("打不开 %s" % 扩展目录)
		return
	目录.list_dir_begin()
	var 名 := 目录.get_next()
	while 名 != "":
		if not 名.ends_with(".json"):
			名 = 目录.get_next()
			continue
		var 表名 := 名.trim_suffix(".json")
		var 覆盖 = _读("%s/%s" % [扩展目录, 名])
		var 基表 = _读("%s/%s" % [数据目录, 名])
		if 覆盖 is Dictionary and 基表 is Dictionary:
			var 撞 := []
			for 键 in (覆盖 as Dictionary):
				if (基表 as Dictionary).has(键):
					撞.append(str(键))
			if not 撞.is_empty():
				_失败.append("覆盖层「%s」改了原版已有的 id：%s —— 只许新增（§3.28.3）"
					% [表名, ", ".join(撞.slice(0, 5))])
			print("  覆盖层 %s：新增 %d 条，改原版 0 条" % [表名, (覆盖 as Dictionary).size()])
		else:
			# ⚠️ 别静默跳过 —— 说清楚为什么没查（否则"没输出"会被当成"查过了没问题"）。
			print("  覆盖层 %s：没有同名基表（纯自研表），跳过重叠检查" % 表名)
		名 = 目录.get_next()
	目录.list_dir_end()


func _查条目有名字() -> void:
	for 表 in 要求有名字:
		var 数据 = _读("%s/%s.json" % [数据目录, 表])
		if not 数据 is Dictionary:
			continue
		var 无名 := []
		var 无id := []
		for 键 in (数据 as Dictionary):
			var 条 = (数据 as Dictionary)[键]
			if not 条 is Dictionary:
				无名.append(str(键))
				continue
			if String((条 as Dictionary).get("name", "")).strip_edges().is_empty():
				无名.append(str(键))
			if String((条 as Dictionary).get("id", "")).strip_edges().is_empty():
				无id.append(str(键))
		if not 无名.is_empty():
			_失败.append("表「%s」有 %d 条没有 name（会被显示成编号）：%s"
				% [表, 无名.size(), ", ".join(无名.slice(0, 5))])
		if not 无id.is_empty():
			_失败.append("表「%s」有 %d 条没有 id：%s" % [表, 无id.size(), ", ".join(无id.slice(0, 5))])


## 地图索引与烘焙产物数量必须一致 —— 少了就说明"加了图但没重烤"（§3.19.4 那条根因）。
func _查地图数() -> void:
	var 索引 = _读("%s/地图索引.json" % 数据目录)
	if not 索引 is Dictionary:
		_失败.append("地图索引读不出来")
		return
	var 应有 := (索引 as Dictionary).size()
	var 目录 := DirAccess.open(生成目录)
	if 目录 == null:
		# 没烤过不算失败（`场景/生成/` 是 gitignore 的派生目录），但要明说。
		print("  场景/生成/ 不存在 —— 跳过烘焙数量核对（跑一次烘焙当前地图.gd -- --all 即可）")
		return
	var 实有 := 0
	目录.list_dir_begin()
	var 名 := 目录.get_next()
	while 名 != "":
		if 名.begins_with("地图_") and 名.ends_with("_烘焙.tscn"):
			实有 += 1
		名 = 目录.get_next()
	目录.list_dir_end()
	if 实有 != 应有:
		_失败.append("地图索引有 %d 张，但 场景/生成/ 里只有 %d 张烘焙产物 —— 加了图没重烤？"
			% [应有, 实有])
	else:
		print("  地图索引 %d 张 = 烘焙产物 %d 张" % [应有, 实有])
