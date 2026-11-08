extends SceneTree

## 实测：`OS.get_cmdline_args()` 里到底含不含引擎参数 `--script`
## （跟屏模式的"这是量具不是玩家"判据全靠这一条，名字猜错 = 自动加载直接挂不上）。
## 跑：Godot --path . --script res://开发工具/查命令行内容.gd -- 档=甲

func _initialize() -> void:
	print("MARK get_cmdline_args = ", OS.get_cmdline_args())
	print("MARK get_cmdline_user_args = ", OS.get_cmdline_user_args())
	quit(0)
