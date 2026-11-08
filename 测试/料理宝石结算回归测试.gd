extends SceneTree

func _initialize() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 输出: Array = []
	var 码 := OS.execute(工程.path_join("运行时/python/python.exe"),
		["-X", "utf8", 工程.path_join("测试/料理宝石结算回归测试.py")], 输出, true)
	for 行 in 输出:
		print(行)
	quit(码)
