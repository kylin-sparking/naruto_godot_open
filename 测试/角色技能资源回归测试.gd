extends SceneTree

## 角色 / NPC / 宠物 / 怪物 的动画元数据与素材索引必须自洽。
##
## ⚠️ 2026-09-26 修掉一处**假绿**（§3.36.4 那 8 种之外的**第 9 种形状**，详见 §3.37.7）：
##    原来每条断言失败时 `push_error` + `quit(1)`，但 Godot 的 `quit()` 只是**设标志**、
##    函数继续往下跑，末尾那句裸 `quit()`（等价 quit(0)）把退出码**又覆盖回 0** ——
##    主门只读退出码，于是"报了 4 条 ERROR 却显示通过"。
##    而且通过行里的 `角色 49，NPC 68，宠物 33` 是**硬编码字面量**，不是算出来的，
##    所以它永远报 49/68/33，连"数字变了"都看不出来。
##    现在：失败只计数、末尾只 quit 一次，通过行一律用实算值。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

const METADATA_PATH := "res://数据/角色/动画元数据.json"
const CHAR_INDEX_PATH := "res://数据/角色/动画素材索引.json"
const SKILL_INDEX_PATH := "res://数据/技能素材索引.json"
const SKILL_MISSING_PATH := "res://数据/技能素材缺失.json"

var _失败 := 0


func _init() -> void:
	var metadata: Dictionary = _read_json(METADATA_PATH)
	var char_data: Dictionary = metadata.get("character", {})
	var npc_data: Dictionary = metadata.get("npc", {})
	var pet_data: Dictionary = metadata.get("pet", {})
	var mob_data: Dictionary = metadata.get("mob", {})
	# 基线 2026-09-26 随 A3 刷新：数据源换成 2.2.3优化版 `GameData.dat.json` 真值，
	# 角色 49→118、NPC 68→76、宠物 33→45（原来那组数字是旧二手数据源的口径）。
	_assert(char_data.size() == 118, "角色定义应为 118，实际 %d" % char_data.size())
	_assert(npc_data.size() == 76, "NPC 定义应为 76，实际 %d" % npc_data.size())
	_assert(pet_data.size() == 45, "宠物定义应为 45，实际 %d" % pet_data.size())
	_assert(mob_data.size() == 1574, "怪物定义应为 1574，实际 %d" % mob_data.size())
	var char_index: Dictionary = _read_json(CHAR_INDEX_PATH)
	_assert(char_index.size() >= 7000, "角色帧索引数量不足：%d" % char_index.size())
	for id in ["00000001", "10000001", "10000040"]:
		_assert(char_data.has(id), "缺少角色定义 %s" % id)
		if char_data.has(id):
			_assert((char_data[id] as Dictionary).has("stand"), "角色 %s 缺少 stand 动作" % id)
	# 真不变量（2026-09-26 补）：换数据源时最容易"整段丢动作"，空条目必须抓出来。
	for 分类 in [["character", char_data], ["npc", npc_data], ["pet", pet_data]]:
		var 空条目: Array[String] = []
		for id in (分类[1] as Dictionary):
			if (分类[1][id] as Dictionary).is_empty():
				空条目.append(String(id))
		_assert(空条目.is_empty(), "%s 有 %d 个空条目（动作整段丢了？）：%s"
			% [分类[0], 空条目.size(), 空条目.slice(0, 5)])
	var skill_index: Dictionary = _read_json(SKILL_INDEX_PATH)
	_assert(skill_index.size() >= 700, "技能资源索引数量不足：%d" % skill_index.size())
	var missing: Array = _read_json(SKILL_MISSING_PATH)
	# 2026-09-26：49 → 1。换真值数据源后原先缺的那批技能特效大多补上了，
	# 只剩 `Skill_000_skill_0009033_effect_0`（飞雷神之术·标 的特效）原版库里就没有。
	_assert(missing.size() == 1, "技能缺失清单数量发生变化：%d" % missing.size())
	for 条目 in missing:
		_assert(String((条目 as Dictionary).get("className", "")).begins_with("Skill_"),
			"技能缺失清单里混进了非技能条目：%s" % 条目)
	var sample := 游戏数据.skill("1001001")
	_assert(String(sample.get("icon", "")).begins_with("res://素材/技能/"), "技能图标未从批量索引回落")
	_assert(ResourceLoader.exists(String(sample.get("icon", ""))), "技能图标资源不存在")

	if _失败 > 0:
		print("角色技能资源回归测试失败：%d 项" % _失败)
		quit(1)
		return
	print("角色技能资源回归测试：通过（角色 %d，NPC %d，宠物 %d，怪物 %d，动画索引 %d，技能索引 %d，技能缺失 %d）"
		% [char_data.size(), npc_data.size(), pet_data.size(), mob_data.size(),
			char_index.size(), skill_index.size(), missing.size()])
	quit(0)


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	_assert(file != null, "无法读取 %s" % path)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("﻿"))
	return parsed


## ⚠️ 只记失败、**绝不在这里 quit** —— 见文件头那段"假绿"说明。
func _assert(condition: bool, message: String) -> void:
	if not condition:
		_失败 += 1
		push_error("角色技能资源回归失败：" + message)
