extends SceneTree

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 资源解析 := preload("res://脚本/单例/资源解析.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	var 索引 := _读取字典("res://数据/物品图标索引.json")
	var 缺失 := _读取数组("res://数据/物品图标缺失.json")
	var 物品表 := _读取字典("res://数据/物品.json")
	## 基线 2026-09-26 随 A3 刷新：数据源换成 2.2.3优化版 `GameData.dat.json` 真值（物品 2058 → 2699），
	## 且导入器改成「二手包 → 原版直解包」双口径扫描后多命中一批。索引 + 缺失必须等于物品总数。
	_check(索引.size() == 2650, "物品图标索引应覆盖 2650 条物品，实际 %d" % 索引.size())
	_check(缺失.size() == 49, "物品图标缺失清单应有 49 条，实际 %d" % 缺失.size())
	_check(索引.size() + 缺失.size() == 物品表.size(),
		"索引 %d + 缺失 %d 应等于物品总数 %d —— 有条目既没图也没记账"
		% [索引.size(), 缺失.size(), 物品表.size()])

	var 无定义 := 0
	var 源文件缺失 := 0
	for 条目 in 缺失:
		if not 条目 is Dictionary:
			continue
		match String(条目.get("reason", "")):
			"图标定义为空": 无定义 += 1
			"源文件不存在": 源文件缺失 += 1
	_check(无定义 == 36, "图标定义为空应为 36 条（原版数据表这条的 icon 就是空），实际 %d" % 无定义)
	_check(源文件缺失 == 13, "源文件缺失应为 13 条（A3 已逐项查证：原版客户端没带这批图标库），实际 %d" % 源文件缺失)

	var 唯一路径 := {}
	for 编号 in 索引:
		var 路径 := String(索引[编号])
		_check(not 路径.contains("[1]"), "索引不能引用 [1] 解包重复项：%s" % 路径)
		_check(ResourceLoader.exists(路径), "索引贴图不存在：%s（物品 %s）" % [路径, 编号])
		唯一路径[路径] = true
	_check(唯一路径.size() == 1389, "去重后的原版物品图标应为 1389 张，实际 %d" % 唯一路径.size())
	for 编号 in ["17100001", "17200001", "17200002", "17200003", "17200004"]:
		var 神器路径 := String(索引.get(编号, ""))
		_check(神器路径.contains(".swf_2_"), "神器 %s 应命中第 2 帧图标" % 编号)

	for 编号 in ["01010011", "03000001", "16000014"]:
		var 物品 := 游戏数据.item(编号)
		var 路径 := String(物品.get("icon", ""))
		_check(not 路径.is_empty(), "关键物品 %s 应自动补齐 icon" % 编号)
		var 贴图 := 游戏数据.item_icon(编号)
		_check(贴图 != null and 贴图.get_width() > 0 and 贴图.get_height() > 0, "关键物品 %s 图标应可加载" % 编号)

	var 基线路径 := String(索引.get("16000014", ""))
	var 二倍候选 := 资源解析.候选路径(基线路径, 2)
	_check(二倍候选.begins_with("res://素材_2x/"), "2x 候选应与素材目录保持镜像路径")
	_check(资源解析.按倍率解析(基线路径, 2) == 基线路径, "2x 资源不存在时必须回落到 1x 基线")
	_check(资源解析.画质倍率() == 1, "默认画质倍率应保持 1x，不改变复刻基线")

	if _failures.is_empty():
		print("物品图标回归测试：通过（索引 %d，原图 %d，缺失 %d）" % [索引.size(), 唯一路径.size(), 缺失.size()])
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
