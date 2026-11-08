extends Node2D

@export_storage var textures: Array[Texture2D] = []
@export_storage var positions := PackedVector2Array()
@export_storage var flipped := PackedByteArray()

func add_item(texture: Texture2D, position: Vector2, flip_h := false) -> void:
	textures.append(texture)
	positions.append(position)
	flipped.append(1 if flip_h else 0)

func _draw() -> void:
	var count := mini(textures.size(), positions.size())
	for index in count:
		var texture := textures[index]
		if texture == null:
			continue
		var position := positions[index]
		if index < flipped.size() and flipped[index] != 0:
			draw_set_transform(position + Vector2(texture.get_width(), 0.0), 0.0, Vector2(-1.0, 1.0))
		else:
			draw_set_transform(position)
		draw_texture(texture, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
