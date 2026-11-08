extends Node2D

@export_storage var texture: Texture2D
@export_storage var repeat_type := 0
@export_storage var cell_size := Vector2.ZERO
@export_storage var tile_radius := Vector2i.ZERO
@export_storage var alpha := 1.0
@export_storage var flip_h := false

## 拉满整图模式：把这一层铺满 `整图矩形`，不平铺、不跟相机。
## **这是有意偏离原版的** —— 2.2.3 的背景是固定格子平铺 + 视差跟随（见 `MapBackGroup`），
## 不做按地图尺寸的缩放（`Back` 的 cx/cy/front/ani 全 AS3 从未读过）。用户看过两边后
## 要求"拉满全图"，由 `地图根节点.gd` 的 拉满整图 开关统一打开。
var 拉满整图 := false
var 整图矩形 := Rect2()
## 竖直方向也铺满（不看 repeat_type）。后景要"从最低地平面往上铺到地图顶"，
## 而原版 type=1/4 是"只横铺、竖着只有一行"，靠它自己铺不到顶。
var 竖直铺满 := false
## 缩放（后景微调用，默认 1）。只影响 `_draw` 里格子的绘制尺寸。
## `纵向缩放` 只拉竖直，用来单独把后景"上下拉伸一点"而横向不动。
var 缩放 := 1.0
var 纵向缩放 := 1.0

func configure(source: Texture2D, type: int, size: Vector2, radius: Vector2i, opacity: float, flipped: bool) -> void:
	texture = source
	repeat_type = type
	cell_size = size
	tile_radius = radius
	alpha = opacity
	flip_h = flipped
	queue_redraw()

func _draw() -> void:
	if texture == null:
		return
	if 拉满整图:
		if 整图矩形.size.x <= 0.0 or 整图矩形.size.y <= 0.0:
			return
		var 色 := Color(1.0, 1.0, 1.0, alpha)
		# ⚠️ 这里**只画在 (0,0)**：节点自己的 position 已经被摆到 整图矩形.position 了
		# （见 `地图根节点.gd 的 应用拉满整图()`）。之前这里又 `draw_set_transform(整图矩形.position)`，
		# 等于把矩形原点加了两遍 —— 整层往左上偏了整整一个矩形，右下角露出来就是那块深蓝底块。
		if flip_h:
			draw_set_transform(Vector2(整图矩形.size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		else:
			draw_set_transform(Vector2.ZERO)
		draw_texture_rect(texture, Rect2(Vector2.ZERO, 整图矩形.size), false, 色)
		draw_set_transform(Vector2.ZERO)
		return
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return
	var min_x := -tile_radius.x
	var max_x := tile_radius.x
	var min_y := -tile_radius.y
	var max_y := tile_radius.y
	if repeat_type == 0:
		min_x = 0
		max_x = 0
		min_y = 0
		max_y = 0
	elif repeat_type == 1 or repeat_type == 4:
		min_y = 0
		max_y = 0
	elif repeat_type == 2 or repeat_type == 5:
		min_x = 0
		max_x = 0
	if 竖直铺满:
		min_y = -tile_radius.y
		max_y = tile_radius.y
	var color := Color(1.0, 1.0, 1.0, alpha)
	var 格 := Vector2(cell_size.x * 缩放, cell_size.y * 缩放 * 纵向缩放)
	for y_index in range(min_y, max_y + 1):
		for x_index in range(min_x, max_x + 1):
			var cell_origin := Vector2(x_index * 格.x, y_index * 格.y) - 格 * 0.5
			if flip_h:
				draw_set_transform(cell_origin + Vector2(格.x, 0.0), 0.0, Vector2(-1.0, 1.0))
			else:
				draw_set_transform(cell_origin)
			draw_texture_rect(texture, Rect2(Vector2.ZERO, 格), false, color)
	draw_set_transform(Vector2.ZERO)
