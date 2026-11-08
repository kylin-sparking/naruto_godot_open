extends SceneTree

## 装备打造配置表（`数据/装备打造.json`）的回归。
##
## 为什么单独一条：这张表是**从服务端 GameData 导出**的静态数据，
## 客户端只按服务端自己的字段名（`prob` / `needItemId` / `maxHelpCnt` …）读。
## 一旦字段名对不上（服务端改了名、或导出脚本改了结构），
## 客户端会**静默**退化 —— 面板上是空的或 0，而不会报错。
## §3.12.2 那条教训（"没被用例走过的链路等于没有"）就是冲着这种静默失败来的。
##
## 这里钉的是**导出那一刻的真值**（源：`EquipSystem.strength/stageup`，
## 读法见 `脚本/界面/装备打造表.gd` 顶部，服务端 `fake_flash_server.py:54300-54335`）。
## 服务端配置真变了就要连着改这里 —— 那正是我们希望被提醒的。
##
## 运行：Godot --headless --path . --script res://测试/装备打造表回归测试.gd

const 打造表 := preload("res://脚本/界面/装备打造表.gd")

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	# 段的完整性：服务端那一整段是 23 段，少了说明导出或读取断了
	var 段名 := ["strength", "stageup", "crash", "born", "inlay", "jade", "carve",
		"plus", "resetStrength", "forgeAdditive", "naijiu", "merge", "basic",
		"taleAttributes", "changeAptitude", "changeTaleAttribute", "changeToOrange",
		"stageup120", "KunChong", "avatar", "huiZhangStageUp", "special", "taozhuang"]
	var 缺: Array[String] = []
	for 名 in 段名:
		if 打造表.取段(名).is_empty():
			缺.append(名)
	if not 缺.is_empty():
		_失败.append("EquipSystem 少了这些段：%s" % ", ".join(缺))

	# 强化 1 / 8 / 10 级（8 级是实机核过的：+7 的武器升 8 级，面板显示「强化灵珠 × 80 / 35%」）
	_查强化(1, 16000016, 1, 100, 13)
	_查强化(8, 16000016, 80, 35, 188)
	_查强化(10, 16000016, 180, 25, 300)

	# level11 是**百炼**（材料换成精炼锤），别当成第 11 次普通强化
	var 百炼 := 打造表.取强化(11)
	if int(百炼.get("needItemId", 0)) != 15028002:
		_失败.append("strength.level11 的材料应是精炼锤 15028002（百炼），实际 %s" % 百炼.get("needItemId"))

	# 进阶 2 阶（实机核过：面板显示「升阶灵珠 × 1 / 金币 10000 / 60%」）
	var 进 := 打造表.取进阶(2)
	if int(进.get("needItemId", 0)) != 16000019 or int(进.get("needItemCnt", 0)) != 1 \
			or int(进.get("needMoney", 0)) != 10000 or int(进.get("prob", 0)) != 60:
		_失败.append("stageup.stage2 与实机对不上：%s" % 进)
	# 进阶那几条"可能掉属性"的字段**必须留着** —— 手抄成中文键名时最容易漏掉它们
	for 键 in ["probLoseAptitude", "probLoseStrength", "keepStrengthItemId", "keepAptitudeItemId"]:
		if not 进.has(键):
			_失败.append("stageup.stage2 少了字段 %s（原样导出就是为了不丢这种字段）" % 键)

	# 刻印（`carve.req.<阶数>`；出处 `EquipKeYinPanel.getKeYinCfg`）
	var 刻 := 打造表.取刻印(1)
	if int(刻.get("needItemId", 0)) != 16000035 or int(刻.get("prob", 0)) != 25:
		_失败.append("carve.req.stage1 与真值对不上：%s" % 刻)

	# 精炼页下拉的**两个精炼项各有各的来源**（`EquipBaiLianPanel.as:316/320`）：
	#   0 提升附加属性 → `forgeAdditive`
	#   1 提升强化星级 → `strength.level11`（百炼那条）
	# ⚠️ 两项**材料相同**（都是精炼锤），成功率 **2026-11-01 起都是 25%**
	# （用户要求把精炼页的锻造成功率提到 25%）—— 所以两个 `prob` 都得钉住：
	# 只查材料的话，"两个分支接反了"这种错照样全绿。
	var 精附 := 打造表.取精炼(打造表.精炼项_附加属性)
	if int(精附.get("needItemId", 0)) != 15028002 or int(精附.get("needItemCnt", 0)) != 1 \
			or int(精附.get("prob", 0)) != 25:
		_失败.append("forgeAdditive（提升附加属性）与真值对不上：%s" % 精附)
	var 精星 := 打造表.取精炼(打造表.精炼项_强化星级)
	if int(精星.get("needItemId", 0)) != 15028002 or int(精星.get("needItemCnt", 0)) != 1 \
			or int(精星.get("prob", 0)) != 25:
		_失败.append("strength.level11（提升强化星级）与真值对不上：%s" % 精星)
	if 打造表.精炼项_附加属性 != 0 or 打造表.精炼项_强化星级 != 1:
		_失败.append("精炼项 id 必须与下拉 split(\",\") 的下标一致（0 附加属性 / 1 强化星级）")

	# 破碎修复（`crash` 段不分级）
	var 修 := 打造表.取破碎修复()
	if int(修.get("needItemId", 0)) != 16000029 or int(修.get("prob", 0)) != 100:
		_失败.append("crash 段与真值对不上：%s" % 修)

	# 成功率：照 `_roll_forge` 的 `min(100, prob + 颗数*3)`
	_查成功率({"prob": 25}, 0, 25)
	_查成功率({"prob": 25}, 3, 34)
	_查成功率({"prob": 25}, 9, 52)
	_查成功率({"prob": 100}, 5, 100)      # 封顶 100
	_查成功率({"prob": 60}, -2, 60)       # 负数颗数当 0

	# 幸运符上限：强化 0（不能用）、进阶 9
	if int(打造表.取强化(1).get("maxHelpCnt", -1)) != 0:
		_失败.append("强化的 maxHelpCnt 应为 0（原版强化面板没有幸运符）")
	if int(打造表.取进阶(2).get("maxHelpCnt", -1)) != 9:
		_失败.append("进阶的 maxHelpCnt 应为 9")

	# 普通强化上限
	if 打造表.强化上限 != 10:
		_失败.append("强化上限应为 10")

	# 名字走 数据/物品.json（单一真值源）
	for 对 in [[16000016, "强化灵珠"], [16000015, "幸运符"], [16000019, "升阶灵珠"], [15028002, "精炼锤"]]:
		var 名 := 打造表.物品名(int(对[0]))
		if 名 != String(对[1]):
			_失败.append("物品名(%d) 应是「%s」，实际「%s」" % [int(对[0]), String(对[1]), 名])

	# 消耗文案：金币为 0 时不写那一行（强化金币恒为 0）
	var 文案 := 打造表.消耗文案(打造表.取强化(8))
	if 文案 != "强化灵珠 × 80":
		_失败.append("强化 8 级的消耗文案应是「强化灵珠 × 80」，实际「%s」" % 文案)
	if not 打造表.消耗文案(打造表.取进阶(2)).contains("金币 10000"):
		_失败.append("进阶 2 阶的消耗文案里应有「金币 10000」")

	if _失败.is_empty():
		print("装备打造表回归测试：通过（23 段齐全 / 强化 1·8·10 级 / 百炼 11 级 / 进阶 2 阶 / 刻印 / 精炼两项 / 成功率与幸运符 / 名字与文案）")
		quit(0)
	else:
		for 项 in _失败:
			push_error("装备打造表回归测试：失败 - %s" % 项)
		quit(1)


func _查强化(等级: int, 材料: int, 数量: int, 成功率: int, 比例: int) -> void:
	var 条 := 打造表.取强化(等级)
	if int(条.get("needItemId", 0)) != 材料 or int(条.get("needItemCnt", 0)) != 数量 \
			or int(条.get("prob", 0)) != 成功率 or int(条.get("addRatio", 0)) != 比例:
		_失败.append("strength.level%d 与真值对不上：%s" % [等级, 条])


func _查成功率(配置: Dictionary, 颗数: int, 期望: int) -> void:
	var 实 := 打造表.实际成功率(配置, 颗数)
	if 实 != 期望:
		_失败.append("成功率(prob=%s, 幸运符 %d 颗) 应是 %d，实际 %d"
			% [配置.get("prob"), 颗数, 期望, 实])
