## 「地形编辑器」只读门（2026-11-05）——包装 `测试/地形编辑器回归测试.py`。
##
## 地形浏览器（`开发工具/数据编辑器/静态/terrain.html` + `/api/terrain/*`）只读展示
## `数据/地图` 与 `素材/地图`，坐标与层级必须和客户端一致，否则运营量出来的位置是错的。
##
## 锤在临时目录里驱动真编辑器模块 + 真 HTTP 服务（74 条断言）：174 张地图清单、
## 木叶村/终结谷浅滩逐条坐标钉值、z 公式与同层叠放、素材索引与白名单、多帧排序、
## 口令 401 / 越界 400 / 写接口 404，并逐字节核对数据文件与真 project.json 没被动过。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/地形编辑器回归测试.py"
	if not FileAccess.file_exists(锤):
		printerr("地形编辑器回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("地形编辑器回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("地形编辑器回归测试：用 %s 跑地形锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("地形编辑器回归测试：锤退出 %d —— 地图坐标/素材解析/只读面失效（回归！）" % 码)
		quit(1)
		return
	print("地形编辑器回归测试：通过（地图清单、坐标层级、素材白名单、HTTP 只读面）")
	quit(0)


func _initialize() -> void:
	_初始化()
