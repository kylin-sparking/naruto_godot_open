extends SceneTree

## 查一件事：**带环境变量开机**时，逻辑节拍到底被没被改（跟屏模式靠的就是这一步）。
## 有头跑才有刷新率可读；无头跑读到 0，应当**保持 60 不动**。
## 跑：NARUTO_PHYSICS=follow Godot --path . --script res://开发工具/查开机节拍.gd

func _initialize() -> void:
	_跑()


func _跑() -> void:
	await process_frame
	await process_frame
	var 记 := root.get_node_or_null("CamCadence")
	var 屏 := 0.0
	if 记 != null:
		屏 = float(记.call("_刷新率"))
	print("环境变量 NARUTO_PHYSICS = [" + OS.get_environment("NARUTO_PHYSICS") + "]")
	print("开机后逻辑节拍 = " + str(Engine.get_physics_ticks_per_second())
			+ "   读到刷新率 = " + str(屏)
			+ "   记录器在不在 = " + str(记 != null))
	quit(0)
