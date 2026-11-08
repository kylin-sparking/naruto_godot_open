## 「意志面板竞态」门（2026-10-22 §3.183）——包装 `测试/意志面板竞态回归测试.py`。
##
## 为什么需要它：用户第三次实机报「一键学习/一键拾取/一键卖出点击后没反应」，
## 服务端 traceback 的真凶是一场**竞态**，不是发送链：
##   * 连接线程 `_pick/_sell_spirit_panel_items` 循环里
##     `spirit_panel_items.pop(p)` 与 `spirit_panel_obtained_at.pop(p)` 是两颗
##     不相邻保护的 pop（旧实现不持锁）；
##   * runtime 线程每 50ms 一跳的 tick（`_run_runtime_loop` → `_runtime_tick` →
##     `_expire_spirit_panel_items`）并发跑，一见两表长度不齐就把
##     `obtained_at` 截断"修复"；
##   * 落在两颗 pop 之间 ⇒ 挂起的那颗越界（IndexError）打死连接线程 ⇒
##     客户端「后端：离线」，三钮集体"没反应"。
## 实录（夹具 18699）：line 20853 IndexError，与 Python 锤复现的逐行对齐。
##
## 为什么包一层 .gd：竞态在 Python 服务端里，GDScript 碰不到服务端内部，
## 但离线门套件（`跑全部离线门.py` / `验证全部.ps1`）只认 .gd ⇒ 由本门
## `OS.execute` 调 Python 锤，退出码即断言。锤自身把两颗 pop 之间的窗口
## 放大 0.5ms（`_竞态放大列表`），对旧代码确定性红（两半修复各验过一次：
## 去掉卖出循环的锁 ⇒ IndexError；只回退 expire 的锁粒度 ⇒ livelock 超时）。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`
## （`.gitignore` 注释里写明的本地安装位），找不到再退到 PATH 上的 `python`；
## 两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/意志面板竞态回归测试.py"
	if not FileAccess.file_exists(锤):
		printerr("意志面板竞态回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("意志面板竞态回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("意志面板竞态回归测试：用 %s 跑竞态锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, [锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("意志面板竞态回归测试：竞态锤退出 %d —— 成对 pop 与 expire 归一化没有互斥（回归！）" % 码)
		quit(1)
		return
	print("意志面板竞态回归测试：通过（拾取/卖出与并发 expire 锤共跑，无越界无死锁）")
	quit(0)


func _initialize() -> void:
	_初始化()
