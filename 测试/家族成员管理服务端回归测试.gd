## 「家族成员管理服务端」门（2026-11-08，B）——包装 `测试/家族服务端锤.py`。
##
## 客户端两扇门只钉「帧怎么解、钮怎么发包」；这一扇钉**服务端收到那几发之后做了什么**：
## 申请推送与离线重推（`1552:8`）、批准/拒绝（14/13 ⇒ `1552:15` 第 8 字段 / `1552:9`）、
## 邀请与开除的 manager 闸（19/4 = 族长或副族长）、职务白名单（17 ⇒ 2/3/4/5/9999）、
## 禅让（18 ⇒ 摘要第 7 字段）、自动同意（20 ⇒ 摘要第 8 字段 + 挂起全批）、
## 弹劾（22 ⇒ 只认弹劾令；原版"族长 N 天未登录"本机没有登录时间轴 ⇒ 不做）、
## 成员详细行（105 ⇒ 17 字段 / line_id / 缺职务 9999）。
## 十段钉法见 `.py` 文件头。
##
## 依赖：Python 解释器。按仓库约定用 `运行时/python/python.exe`，找不到再退到
## PATH 上的 `python`；两者都没有 ⇒ 本门**红着失败并说原因**，绝不静默跳过。
extends SceneTree


func _初始化() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/家族服务端锤.py"
	if not FileAccess.file_exists(锤):
		printerr("家族成员管理服务端回归测试：找不到锤脚本 " + 锤)
		quit(1)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("家族成员管理服务端回归测试：找不到 Python 解释器。")
		printerr("  按 .gitignore 顶部说明装一份：把 python-3.13 embeddable 拷到 运行时/python/")
		printerr("  （试过：" + str(候选) + "）")
		quit(1)
		return
	print("家族成员管理服务端回归测试：用 %s 跑家族服务端锤……" % 解释器)
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("家族成员管理服务端回归测试：锤退出 %d —— 家族成员管理/入族审批服务端行为不符（回归！）" % 码)
		quit(1)
		return
	print("家族成员管理服务端回归测试：通过（申请推送/批准/拒绝/manager闸/职务/禅让/自动同意/弹劾/105行）")
	quit(0)


func _initialize() -> void:
	_初始化()
