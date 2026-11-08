extends RefCounted

const DATA_ROOT := "res://数据/地图"
const ASSET_ROOT := "res://素材/地图"
const MAP_INDEX_PATH := "res://数据/地图索引.json"
const ASSET_INDEX_PATH := "res://数据/地图素材索引.json"

static var _map_folders := {}
static var _asset_paths := {}
static var _loaded := false

static func map_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	ids.assign(_map_folders.keys())
	ids.sort()
	return ids

static func map_data_path(map_id: String) -> String:
	return _data_path(map_id, "地图.json")

static func map_data(map_id: String) -> Dictionary:
	return _load_dictionary(map_data_path(map_id))

static func life_entries(map_id: String, kind := "") -> Array[Dictionary]:
	var life = map_data(map_id).get("life", {})
	var source: Array = life.values() if life is Dictionary else life if life is Array else []
	var result: Array[Dictionary] = []
	for value in source:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		if kind.is_empty() or String(entry.get("type", "")) == kind:
			result.append(entry.duplicate(true))
	return result

static func tile_data_path(map_id: String) -> String:
	return _data_path(map_id, "地图块.json")

static func object_data_path(map_id: String) -> String:
	return _data_path(map_id, "物件.json")

static func baked_scene_path(map_id: String) -> String:
	return "res://场景/生成/地图_%s_烘焙.tscn" % map_id

static func playable_scene_path(map_id: String) -> String:
	var baked := baked_scene_path(map_id)
	return baked if ResourceLoader.exists(baked) or FileAccess.file_exists(baked) else "res://场景/地图/地图场景.tscn"

## 最近用过的地图场景缓存。
##
## 为什么需要它：`change_scene_to_file` 是**同步**加载 —— 换图时旧场景被释放，它引用的
## 几百张贴图跟着被回收；再回这张图时又要重新读 .tscn、重新解析、重新上传贴图，
## 玩家看到的就是"回某张图时卡一下"。把 PackedScene 留在静态表里，它引用的贴图就被
## 一直引用着，回访就省掉这一整块。
## 上限存在的意义是别把 168 张全留在内存里（每张几百张贴图）。
const 场景缓存上限 := 4
static var _场景缓存 := {}
static var _场景缓存顺序 := []

static func playable_scene(map_id: String) -> PackedScene:
	if _场景缓存.has(map_id):
		return _场景缓存[map_id]
	var path := playable_scene_path(map_id)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("地图资源：加载地图场景失败 %s" % path)
		return null
	_场景缓存[map_id] = packed
	_场景缓存顺序.append(map_id)
	while _场景缓存顺序.size() > 场景缓存上限:
		var 老: String = _场景缓存顺序.pop_front()
		_场景缓存.erase(老)
	return packed

static func minimap_path(map_id: String) -> String:
	_ensure_loaded()
	return String(_asset_paths.get("小地图/Map_%s_miniMap_canvas" % map_id, ""))

static func find_asset(map_id: String, category: String, file_name: String) -> String:
	_ensure_loaded()
	var logical_name := file_name.get_basename()
	var indexed := String(_asset_paths.get("%s/%s" % [category, logical_name], ""))
	if not indexed.is_empty() and (ResourceLoader.exists(indexed) or FileAccess.file_exists(indexed)):
		return indexed
	var local_path := "%s/%s/%s/%s" % [ASSET_ROOT, folder_name(map_id), category, file_name]
	return local_path if ResourceLoader.exists(local_path) or FileAccess.file_exists(local_path) else ""

static func find_asset_directory(map_id: String, category: String, directory_name: String) -> String:
	_ensure_loaded()
	var indexed := String(_asset_paths.get("%s/%s" % [category, directory_name], ""))
	if not indexed.is_empty() and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(indexed)):
		return indexed
	var local_path := "%s/%s/%s/%s" % [ASSET_ROOT, folder_name(map_id), category, directory_name]
	return local_path if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(local_path)) else ""

static func folder_name(map_id: String) -> String:
	_ensure_loaded()
	return String(_map_folders.get(map_id, map_id))

static func _data_path(map_id: String, file_name: String) -> String:
	return "%s/%s/%s" % [DATA_ROOT, folder_name(map_id), file_name]

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_map_folders = _load_dictionary(MAP_INDEX_PATH)
	_asset_paths = _load_dictionary(ASSET_INDEX_PATH)
	_loaded = true

static func _load_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("地图资源：无法读取 %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
	return parsed if parsed is Dictionary else {}
