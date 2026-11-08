extends Node2D

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
# Renders map platform textures (tiles). Generic version.
# Position rule (aligned with Flash ByteArrayImage):
#   Flash puts image pixel (origin.x, origin.y) at tile (x, y).
#   Godot Sprite2D centered=false puts top-left at position,
#   so position = (x - origin.x, y - origin.y). Y-down, same as Flash.

@export var map_id := "101010000"

const TILE_DESCRIPTOR_Z_PATH := "res://数据/地图块描述符z.json"

var tiles: Array = []
## (tS,u,no) → 瓦片描述符里的 z。原版 `MapTile.readRawInfo()` 取的就是它，
## `MapRender.drawGroup()` 再按它 `sortOn` 排层内前后。地图实例数据里只有 `zM`（全 0），
## 拿 zM 当 mapZ 等于把所有瓦片并列。
static var _描述符z := {}

static func 瓦片描述符z(tS: String, u: String, no: int) -> int:
	if _描述符z.is_empty():
		var file := FileAccess.open(TILE_DESCRIPTOR_Z_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text().trim_prefix("﻿"))
			if parsed is Dictionary:
				_描述符z = parsed
	return int(_描述符z.get("%s/%s/%d" % [tS, u, no], 0))

func _ready():
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		map_id = str(session.current_map_id)
	if get_child_count() == 0:
		load_tiles()
	else:
		print("TileRoot: using %d baked tiles" % get_child_count())

func load_tiles():
	var path := MAP_RESOURCES.tile_data_path(map_id)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("TileRoot: cannot read " + path)
		return
	var txt := f.get_as_text()
	f.close()
	if txt.begins_with("\ufeff"):
		txt = txt.substr(1)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("TileRoot: bad tile data")
		return
	tiles = parsed

	var missing := 0
	for t: Dictionary in tiles:
		var tS = str(t.get("tS", ""))
		var u = str(t.get("u", ""))
		var no = int(t.get("no", 0))
		var tex = load_tile_tex(tS, u, no)
		if tex == null:
			missing += 1
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		var ox = float(t.get("ox", 0))
		var oy = float(t.get("oy", 0))
		sp.position = Vector2(float(t.get("x", 0)) - ox, float(t.get("y", 0)) - oy)
		sp.z_index = RenderProfile.瓦片z(int(t.get("layer", 0)), 瓦片描述符z(tS, u, no))
		add_child(sp)
	if missing > 0:
		print("TileRoot: %d textures missing" % missing)
	else:
		print("TileRoot: rendered %d tiles" % tiles.size())

func load_tile_tex(tS: String, u: String, no: int) -> Texture2D:
	for extension in ["jpg", "png"]:
		var file_name := "Tile_%s_%s_%d.%s" % [tS, u, int(no), extension]
		var path := MAP_RESOURCES.find_asset(map_id, "地图块", file_name)
		if not path.is_empty():
			return load(path) as Texture2D
	return null
