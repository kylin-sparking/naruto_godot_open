extends RefCounted

const 升级开关路径 := "res://数据_扩展/升级开关.json"
const 支持倍率 := [1, 2, 4]

static var _升级开关 := {}
static var _路径缓存 := {}

static func 画质倍率() -> int:
	_确保加载()
	var 倍率 := int(_升级开关.get("画质倍率", 1))
	return 倍率 if 倍率 in 支持倍率 else 1

static func 解析(基线路径: String) -> String:
	return 按倍率解析(基线路径, 画质倍率())

static func 按倍率解析(基线路径: String, 倍率: int) -> String:
	if 基线路径.is_empty() or 倍率 <= 1 or not 基线路径.begins_with("res://素材/"):
		return 基线路径
	var 缓存键 := "%d:%s" % [倍率, 基线路径]
	if _路径缓存.has(缓存键):
		return String(_路径缓存[缓存键])
	var 候选 := 候选路径(基线路径, 倍率)
	var 结果 := 候选 if ResourceLoader.exists(候选) else 基线路径
	_路径缓存[缓存键] = 结果
	return 结果

static func 候选路径(基线路径: String, 倍率: int) -> String:
	if 倍率 <= 1 or not 基线路径.begins_with("res://素材/"):
		return 基线路径
	return 基线路径.replace("res://素材/", "res://素材_%dx/" % 倍率)

static func 纹理(基线路径: String) -> Texture2D:
	var 路径 := 解析(基线路径)
	return load(路径) as Texture2D if not 路径.is_empty() and ResourceLoader.exists(路径) else null

static func 重新加载设置() -> void:
	_升级开关.clear()
	_路径缓存.clear()
	_确保加载()

static func _确保加载() -> void:
	if not _升级开关.is_empty():
		return
	var 文件 := FileAccess.open(升级开关路径, FileAccess.READ)
	if 文件 == null:
		_升级开关 = {"画质倍率": 1}
		return
	var 解析结果 = JSON.parse_string(文件.get_as_text().trim_prefix("\ufeff"))
	_升级开关 = 解析结果 if 解析结果 is Dictionary else {"画质倍率": 1}
