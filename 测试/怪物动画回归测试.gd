extends SceneTree

const 原始动画 := preload("res://脚本/角色/原始动画精灵.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	var 怪物索引 := _读取字典("res://数据/怪物动画索引.json")
	var 素材索引 := _读取字典("res://数据/角色/动画素材索引.json")
	var 缺失 := _读取数组("res://数据/怪物素材缺失.json")
	var 保真缺口 := _读取数组("res://数据/视觉保真缺口.json")
	## 基线 2026-09-26 随 A3 刷新：数据源换成 2.2.3优化版 `GameData.dat.json` 真值后怪物是 1574 条（原记 1199），
	## 且原先真缺的雪人 2200018 死亡帧已由 `补齐原版素材.mjs` 从原版 Mob SWF 直解补回 —— 缺口清单归零。
	_check(怪物索引.size() == 1574, "怪物动画应覆盖全部 1574 条怪物，实际 %d" % 怪物索引.size())
	_check(缺失.is_empty(), "怪物动画缺失清单应为空（A3 已清零），实际 %d 条" % 缺失.size())
	_check(怪物索引.has("2000006") and 怪物索引["2000006"].resolution == "link", "2000006 应通过 link 复用 2000005")
	_check(怪物索引.has("4000000") and 怪物索引["4000000"].resolution == "petLink", "忍犬应通过 petLink 使用 Pet 动画")
	_check(怪物索引.has("4000016") and 怪物索引["4000016"].resolution == "petLink-fallback", "缺图四阶忍犬应回落 petLink")
	for 编号 in ["2200018", "2200044"]:
		_check(怪物索引.has(编号), "雪人 %s 应已覆盖（帧已从原版 SWF 直解补回）" % 编号)
		# "覆盖"必须是磁盘上真有帧，不是索引里挂了个名字 —— 当初就是把它记成假覆盖才立的这条。
		# 2200044 是 link 复用 2200018，所以按**解析后的源**数帧。
		var 源 := String((怪物索引.get(编号) as Dictionary).get("source_id", 编号))
		var 帧数 := 0
		for 类名 in 素材索引:
			if not String(类名).contains(源):
				continue
			if ResourceLoader.exists(String(素材索引[类名])):
				帧数 += 1
		_check(帧数 > 0, "雪人 %s（源 %s）的动画帧在磁盘上一张都没有（索引是空挂）" % [编号, 源])
	var 保真标识: Array[String] = []
	for 条目 in 保真缺口:
		if 条目 is Dictionary:
			保真标识.append(String(条目.get("id", "")))
	for 标识 in [
		"mob-dogs-4000000-4000015",
		"mob-dogs-4000016-4000017",
		"offline-pet-first-dog-placeholder",
		"local-item-placeholder-icons",
		"local-skill-placeholder-icons",
	]:
		_check(保真标识.has(标识), "视觉保真缺口未登记：%s" % 标识)

	for 类名 in 素材索引:
		var 路径 := String(素材索引[类名])
		_check(not 路径.contains("[1]"), "动画索引不能引用 [1] 重复项：%s" % 路径)
		_check(ResourceLoader.exists(路径), "动画索引资源不存在：%s" % 路径)

	for 编号 in ["1000001", "2000006", "4000000", "4000016", "4100000"]:
		var 精灵 := 原始动画.new()
		root.add_child(精灵)
		_check(精灵.configure("mob", 编号, "stand"), "怪物 %s 应可配置静止动画" % 编号)
		精灵.play_state("move")
		_check(精灵.action == "move", "怪物 %s 应可切换移动动画" % 编号)
		精灵.play_state("attack1")
		_check(精灵.action == "attack1", "怪物 %s 应可切换攻击动画" % 编号)
		精灵.free()

	if _failures.is_empty():
		print("怪物动画回归测试：通过（覆盖 %d/%d，缺失 %d）" % [怪物索引.size(), _读取字典("res://数据/怪物.json").size(), 缺失.size()])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _读取字典(路径: String) -> Dictionary:
	var 结果 = JSON.parse_string(FileAccess.get_file_as_string(路径).trim_prefix("\ufeff"))
	if 结果 is Dictionary:
		return 结果
	_failures.append("JSON 不是字典：%s" % 路径)
	return {}

func _读取数组(路径: String) -> Array:
	var 结果 = JSON.parse_string(FileAccess.get_file_as_string(路径).trim_prefix("\ufeff"))
	if 结果 is Array:
		return 结果
	_failures.append("JSON 不是数组：%s" % 路径)
	return []

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
