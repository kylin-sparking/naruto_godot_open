extends Node2D

const DURATION := 0.85
const RING_COUNT := 3

var elapsed := 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var life := elapsed / DURATION
	for index in RING_COUNT:
		var phase := fposmod(life + float(index) / float(RING_COUNT), 1.0)
		var alpha := pow(1.0 - phase, 1.7)
		var radius := lerpf(5.0, 28.0, phase)
		_draw_ellipse_arc(Vector2(radius, radius * 0.42), Color(1.0, 0.78, 0.18, alpha), lerpf(3.0, 1.0, phase))
	var pulse := 1.0 - life
	draw_circle(Vector2.ZERO, 3.5 + sin(elapsed * 24.0) * 1.2, Color(1.0, 0.92, 0.48, pulse))
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), Color(1.0, 0.68, 0.12, pulse * 0.75), 1.5)
	draw_line(Vector2(0.0, -5.0), Vector2(0.0, 5.0), Color(1.0, 0.68, 0.12, pulse * 0.75), 1.5)

func _draw_ellipse_arc(radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 33:
		var angle := TAU * float(index) / 32.0
		points.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)
