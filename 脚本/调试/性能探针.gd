extends Node

@export var sample_frames := 120
var _frames := 0
var _started_usec := 0
var _initial_nodes := 0

func _ready() -> void:
	_started_usec = Time.get_ticks_usec()
	_initial_nodes = _count_nodes(get_tree().current_scene)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < sample_frames:
		return
	var elapsed_ms := (Time.get_ticks_usec() - _started_usec) / 1000.0
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var session := get_node_or_null("/root/GameSession")
	var map_id := str(session.current_map_id) if session != null else "unknown"
	print("PERF map=%s frames=%d elapsed_ms=%.2f fps=%.1f draw_calls=%d scene_nodes=%d object_nodes=%d" % [
		map_id, _frames, elapsed_ms, fps, int(draw_calls), _initial_nodes, int(objects)])
	set_process(false)

func _count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total
