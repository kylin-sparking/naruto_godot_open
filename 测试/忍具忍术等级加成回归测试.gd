## 「忍具忍术等级加成」门（2026-11-01）——包装 `测试/忍具忍术等级加成回归测试.py`。
##
## 用户点名：「八咫镜的忍术等级提升效果没有实装，在忍术面板不显示」。
## 加成的真值在**服务端**（`RenJuData.getSpecialAttr` 的 JOB/WORLD_SKILL_LEVEL 折成统计
## 39/40，再随 13764 / `_send_all_stats` 下发），GDScript 这层看不到；离线门套件只认
## .gd ⇒ 由本门 `OS.execute` 调 Python 锤，退出码即断言。
##
## 锤钉的七条腿（详见锤顶部注释）：
##   ① 65000002 的 specialAttr 解析成 ((39,3),(40,3))，65000001 不许凭空造加成；
##   ② 统计号就是 39/40；③ 忍具位（-24）生效；④ 背包里的不算；
##   ⑤ 十拳剑(+2) 与开光八咫镜(+3) 叠加成 5；⑥ 发给客户端的 39/40 = 成长 + 加成；
##   ⑦ `_effective_skill_level` 吃到加成（5 层 + 3 ⇒ 8）。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/忍具忍术等级加成回归测试.py"
	if not FileAccess.file_exists(锤):
		printerr("忍具忍术等级加成回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("忍具忍术等级加成回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("忍具忍术等级加成回归测试：用 %s 跑忍具加成锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("忍具忍术等级加成回归测试：锤退出 %d —— 八咫镜的 39/40 加成没进服务端统计（回归！）" % 码)
		quit(1)
		return
	print("忍具忍术等级加成回归测试：通过（specialAttr 解析 / 39·40 号 / 忍具位生效 / 背包不算 / 灵器叠加 / 发给客户端的 39·40 / 技能层数）")
	quit(0)


func _initialize() -> void:
	_初始化()
