extends SceneTree

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const MAP_BAKER := preload("res://开发工具/烘焙当前地图.gd")
const EXPECTED_MAP_COUNT := 174
# 从烘焙器读版本号，别写死。写死过 "7"，烘焙器升到 "8" 后这里没跟上，
# 168 张地图全报"烘焙版本不是 7"，而实际烘焙产物是好的。
const EXPECTED_BAKE_VERSION := MAP_BAKER.BAKE_VERSION
const MISSING_ASSET_PATH := "res://数据/地图素材缺失.json"
## A3 查证后的真值：原版两份库的 `Map` 目录里都没有这 4 张图的库文件（`Map_<编号>.swf` 不存在），
## 小地图是**原版就没带**，不是导入器漏了。其余 11 张（水之国地图块/背景/物件）已从原版 swf 直解补回。
const EXPECTED_MISSING_ASSETS := [
	"100030001|小地图|Map_100030001_miniMap_canvas",
	"112040002|小地图|Map_112040002_miniMap_canvas",
	"408000001|小地图|Map_408000001_miniMap_canvas",
	"466100002|小地图|Map_466100002_miniMap_canvas",
]

var _failures: Array[String] = []
## 逐图判据**真正跑完**了几张。2026-10-16 实测：烘焙器被我改成有 static 混非 static，
## 整份编译失败，门里每图都刷 `Invalid call. Nonexistent function`，可 `_failures` 一条没添 ⇒
## 它照样打「通过（地图 174…）」并 `quit(0)`。跑批器只读退出码 ⇒ 这种门是**假绿**。
## 所以汇总前先自问一句"我每张都判完了吗"，判不完就红。
var _查完 := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map_ids := MAP_RESOURCES.map_ids()
	_check(map_ids.size() == EXPECTED_MAP_COUNT, "地图索引应包含 %d 张地图，实际为 %d" % [EXPECTED_MAP_COUNT, map_ids.size()])
	for map_id in map_ids:
		_validate_map(String(map_id))
	_validate_missing_assets()
	_check(_查完 == map_ids.size(),
			"逐图哈希复核只跑完 %d/%d 张 ⇒ 门自己中途报错，这份汇总不可信" % [_查完, map_ids.size()])
	if _failures.is_empty():
		print("地图烘焙回归测试：通过（地图 %d，已核实缺失素材 %d）" % [map_ids.size(), EXPECTED_MISSING_ASSETS.size()])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	if _failures.any(func(f): return "陈旧" in f):
		print("修法：重烤全部地图 —— \"%s\" --path . --headless --script res://开发工具/烘焙当前地图.gd -- --all"
				% OS.get_executable_path())
	quit(1)

func _validate_map(map_id: String) -> void:
	for data_path in [
		MAP_RESOURCES.map_data_path(map_id),
		MAP_RESOURCES.tile_data_path(map_id),
		MAP_RESOURCES.object_data_path(map_id),
	]:
		_check(FileAccess.file_exists(data_path), "%s 缺少导出数据：%s" % [map_id, data_path])
	var scene_path := MAP_RESOURCES.baked_scene_path(map_id)
	_check(FileAccess.file_exists(scene_path), "%s 缺少烘焙场景" % map_id)
	if not FileAccess.file_exists(scene_path):
		return
	_validate_external_resources(map_id, scene_path)
	var packed := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_check(packed != null, "%s 烘焙场景无法加载" % map_id)
	if packed == null:
		return
	_validate_scene_state(map_id, packed.get_state())

func _validate_external_resources(map_id: String, scene_path: String) -> void:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	_check(file != null, "%s 烘焙场景无法读取" % map_id)
	if file == null:
		return
	var path_pattern := RegEx.new()
	path_pattern.compile('path="(res://[^"]+)"')
	for match_result in path_pattern.search_all(file.get_as_text()):
		var resource_path := match_result.get_string(1)
		_check(
			ResourceLoader.exists(resource_path) or FileAccess.file_exists(resource_path),
			"%s 烘焙场景引用不存在的资源：%s" % [map_id, resource_path]
		)

func _validate_scene_state(map_id: String, state: SceneState) -> void:
	var bake_version := ""
	var bake_hash := ""
	for node_index in state.get_node_count():
		for property_index in state.get_node_property_count(node_index):
			var property_name := String(state.get_node_property_name(node_index, property_index))
			var property_value = state.get_node_property_value(node_index, property_index)
			if node_index == 0 and property_name == "metadata/bake_version":
				bake_version = String(property_value)
			elif node_index == 0 and property_name == "metadata/bake_hash":
				bake_hash = String(property_value)
			elif property_name == "z_index":
				var z_index := int(property_value)
				_check(
					z_index >= RenderingServer.CANVAS_ITEM_Z_MIN and z_index <= RenderingServer.CANVAS_ITEM_Z_MAX,
					"%s 节点 %s 的 z_index=%d 越界" % [map_id, state.get_node_path(node_index), z_index]
				)
	_check(bake_version == EXPECTED_BAKE_VERSION, "%s 烘焙版本不是 %s" % [map_id, EXPECTED_BAKE_VERSION])
	_check(not bake_hash.is_empty(), "%s 缺少烘焙哈希" % map_id)
	## 哈希不但要**在**，还要**等于拿当前源文件现算的那一个**。
	## 只查"在不在"就等于没查：`头像面板.tscn` 10-15 把层号抬到 300，输入清单里本来就有它，
	## 可这道门照样全绿 —— 于是 174 份烘焙产物各带着自己那天的旧层号，
	## 用户实机看到的信息条仍被系统消息/聊天压住（#226，上一轮的层号修复在他那边等于没落）。
	## 这一条把它变成**当天就红**：谁改了源场景/面板脚本没重烤，这里点名。
	var 现算 := String(MAP_BAKER.计算烘焙哈希(map_id))
	_check(bake_hash == 现算,
			"%s 的烘焙产物**陈旧**（源文件改了没重烤）：盘上 bake_hash=%s… 现算=%s… "
			% [map_id, bake_hash.left(12), 现算.left(12)])
	_查完 += 1

func _validate_missing_assets() -> void:
	var file := FileAccess.open(MISSING_ASSET_PATH, FileAccess.READ)
	_check(file != null, "缺少地图素材缺失清单")
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
	_check(parsed is Array, "地图素材缺失清单格式错误")
	if not parsed is Array:
		return
	var actual: Array[String] = []
	for entry in parsed:
		if not entry is Dictionary:
			continue
		actual.append("%s|%s|%s" % [entry.get("map_id", ""), entry.get("type", ""), entry.get("logical_name", "")])
	actual.sort()
	var expected: Array[String] = []
	expected.assign(EXPECTED_MISSING_ASSETS)
	expected.sort()
	_check(actual == expected, "地图缺失素材基线发生变化：%s" % [actual])

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
