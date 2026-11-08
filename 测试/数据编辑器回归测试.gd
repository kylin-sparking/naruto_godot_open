## 「数据编辑器」门（2026-11-05）——包装 `测试/数据编辑器回归测试.py`。
##
## 编辑器（`开发工具/数据编辑器/`）是运营改数值的唯一入口：前端把最小补丁写进
## `服务端/runtime/www/editor_workspace/project.json` 的 overrides，服务端按
## revision 热加载。这条链路断掉时界面照样提示「保存成功」，线上却还是旧值。
##
## 锤在临时目录里驱动真编辑器模块 + 真服务端消费端（56 条断言）：表注册、最小补丁、
## 冲突 409、禁止删基础字段、NPC 派生键不回写、商城下架/改价、掉落池/怪物绑定、
## 全局掉率、备份回滚，并逐字节核对真 project.json 没被动过。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/数据编辑器回归测试.py"
	if not FileAccess.file_exists(锤):
		printerr("数据编辑器回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("数据编辑器回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("数据编辑器回归测试：用 %s 跑编辑器锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("数据编辑器回归测试：锤退出 %d —— 编辑器保存链路或消费端失效（回归！）" % 码)
		quit(1)
		return
	print("数据编辑器回归测试：通过（编辑器表注册、最小补丁、备份回滚、商城/NPC/掉落消费端）")
	quit(0)


func _initialize() -> void:
	_初始化()
