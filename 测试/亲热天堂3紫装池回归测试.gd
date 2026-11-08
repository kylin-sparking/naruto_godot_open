## 「亲热天堂3紫装池」门（2026-10-31）——包装 `测试/亲热天堂3紫装池回归测试.py`。
##
## 用户点名：「亲热天堂3奖励池要加入高星强化紫装，6~9星」。
## 池子在**服务端**（`Box.baoxiang[4].zhuangbei` + `Box.info.zhuangbei` 才是真值，
## 候选由 `handle_fudai` 的动作 18 抽），GDScript 这层看不到；离线门套件只认
## .gd ⇒ 由本门 `OS.execute` 调 Python 锤，退出码即断言。
##
## 锤钉的五件事（详见锤顶部注释）：
##   ① 类型 4 的装备候选一定是 101~112 角色装备、资质 4、星级 6~9、职业/等级可穿；
##   ② 6/7/8/9 四档都会出，装备占比仍在 13.8% 上下；
##   ③ 亲热天堂1/2（类型 2/3）一件装备都不出；
##   ④ 预览帧 &10=资质、&22=星级，发放到背包的那件同口径；
##   ⑤ 存档重载后 candidate_aptitudes/candidate_strengths 不丢；
##   ⑥ 成就福袋与亲热天堂各占一个交易槽（福袋待领不许卡死「显示宝贝」，反向亦然），
##      两槽都活过重载、老存档按 mode 迁移、动作 18 扣件失败必须回帧。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/亲热天堂3紫装池回归测试.py"
	if not FileAccess.file_exists(锤):
		printerr("亲热天堂3紫装池回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("亲热天堂3紫装池回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("亲热天堂3紫装池回归测试：用 %s 跑紫装池锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("亲热天堂3紫装池回归测试：锤退出 %d —— 类型4 候选的紫装/星级口径不符（回归！）" % 码)
		quit(1)
		return
	print("亲热天堂3紫装池回归测试：通过（6~9星紫装 / 2、3型不出装 / 预览与发放同口径 / 福袋与宝箱两槽各活各的）")
	quit(0)


func _initialize() -> void:
	_初始化()
