extends SceneTree

## 查：拿"整条原始命令行"（含 `--script`）在 4.7.2 上该调哪个名字。
## 这一条**只列名字、不做任何调用**（上一版直接 call() 把进程挂住了，别再拿它试）。
## 跑：Godot --headless --path . --script res://开发工具/查命令行接口.gd

func _initialize() -> void:
	for 对 in ["OS", "Engine"]:
		var 命: Array = []
		for m in ClassDB.class_get_method_list(对, false):
			var n: String = String(m.get("name", ""))
			if n.contains("cmdline") or n.contains("command_line"):
				命.append(n)
		print("MARK ", 对, " → ", 命)
	print("MARK done")
	quit(0)
