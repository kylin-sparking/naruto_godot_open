## 「境界合计服务端」门（2026-11-08）——包装 `测试/境界合计服务端锤.py`。
##
## 用户点名：「忍术境界里的忍术层数合计有计算灵器、忍具、勾玉的层数了，但是境界没有
## 计算，例如到了 450 层，还是显示上一个境界」。
##
## 客户端面板是对的（`游戏会话.total_skill_level`），错的是**服务端**：它只数基础层，
## 而头顶的境界图标由服务端广播 ⇒ 别人看到的境界比本人低一档。修法是让
## `_total_skill_level` 与客户端同口径（基础 + 勾玉 + 世界/职业 39/40；情侣忍术豁免）。
## GDScript 这层看不到服务端函数 ⇒ 由本门 `OS.execute` 调 Python 锤（七条钉法见 `.py`）。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/境界合计服务端锤.py"
	if not FileAccess.file_exists(锤):
		printerr("境界合计服务端回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("境界合计服务端回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("境界合计服务端回归测试：用 %s 跑境界合计锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("境界合计服务端回归测试：锤退出 %d —— 服务端境界合计与客户端口径不一致（回归！）" % 码)
		quit(1)
		return
	print("境界合计服务端回归测试：通过（基础/勾玉/世界40/职业39/情侣豁免/七档门槛/跨档）")
	quit(0)


func _initialize() -> void:
	_初始化()
