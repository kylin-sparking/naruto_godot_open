## 「寄坏强化同步」门（2026-10-31）——包装 `测试/寄坏强化同步回归测试.py`。
##
## 用户点名：「昆虫强化成功后，昆虫详情框信息不能及时同步，以至于昆虫强化面板的操作
## 成功几率也没有变化；强化成功后，不管是昆虫强化里的昆虫详情框，还是背包里的，还是
## 显示的 1 星，再次强化还是 1 星成功，但把昆虫佩戴后，会显示正确的强化等级」。
##
## 根因在**服务端**：`_strengthen_kun_chong` 改完件只发 `flag 1`（只有 quantity），
## 客户端镜像的 `strengthen`/`strength_info`/`plus_attributes` 全停在发起前 ——
## 详情框画旧件、面板按旧星级查表算几率、`_lastLevel` 也停着 ⇒ 永远「强化 1 星成功」。
## 修法与 `_finish_forge` 一致：发 flag 11 整件（`UpdateEquipSlotInfo`）。
## GDScript 这层看不到服务端帧 ⇒ 由本门 `OS.execute` 调 Python 锤（纯进程内驱动
## 真 `handle_item_change`，退出码即断言）。锤的七条钉法见 `.py` 顶部注释。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/寄坏强化同步回归测试.py"
	if not FileAccess.file_exists(锤):
		printerr("寄坏强化同步回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("寄坏强化同步回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("寄坏强化同步回归测试：用 %s 跑寄坏强化同步锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("寄坏强化同步回归测试：锤退出 %d —— 强化成功后客户端镜像没拿到新星级（回归！）" % 码)
		quit(1)
		return
	print("寄坏强化同步回归测试：通过（成功/降级都发整件帧、星级/词条/加值同步、2066 槽位口径）")
	quit(0)


func _initialize() -> void:
	_初始化()
