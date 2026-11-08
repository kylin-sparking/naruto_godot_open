extends SceneTree

## 量**单个**资源 load 的耗时。必须在独立进程里跑 —— Godot 会缓存已加载资源，
## 同一个进程里连着 load 几个，后面的会把前面的图省掉，量出来的数没有意义。
##
## 用法：
##   Godot --headless --path . --script res://开发工具/测单项耗时.gd -- 路径

func _initialize() -> void:
	var 路径 := ""
	for 参数 in OS.get_cmdline_user_args():
		路径 = 参数
	if 路径.is_empty():
		push_error("要给一个资源路径")
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var 资 := load(路径)
	var t1 := Time.get_ticks_msec()
	print("[单项] %-52s %6d ms  %s" % [路径, t1 - t0, "OK" if 资 != null else "空"])
	quit(0)
