## 「好友列表/私聊/打探/仇人/最近 服务端」门（2026-11-08，A2）——包装 `测试/好友服务端锤.py`。
##
## 客户端那扇 `好友交互回归测试.gd` 只钉「窗怎么拼串、回包怎么落到控件」；
## 这一扇钉**服务端收到 127 那几发之后做了什么**：
##   `61:2` 五列位次、好友行 11 段（在线 line_id／离线 -1／羁绊）、
##   `127:8` 私聊投递与「最近联系人」双记、（被拉黑整条不发、离线落信箱）、
##   `127:10` 打探三档与乾坤密卷消耗、`127:9`/`127:7` 只清对应列、
##   PvP 被杀记仇。十段钉法见 `.py` 文件头。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/好友服务端锤.py"
	if not FileAccess.file_exists(锤):
		printerr("好友服务端回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("好友服务端回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("好友服务端回归测试：用 %s 跑好友服务端锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("好友服务端回归测试：锤退出 %d —— 好友列表/私聊/打探服务端行为不符（回归！）" % 码)
		quit(1)
		return
	print("好友服务端回归测试：通过（五列位次/行编码/私聊/打探/删仇人/删最近/最近联系人/PvP记仇）")
	quit(0)


func _initialize() -> void:
	_初始化()
