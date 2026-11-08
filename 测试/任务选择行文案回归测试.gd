## 对话窗里**任务那一行**的成串文案门（2026-10-09 用户实机图打回「（可接）（可接）」）。
##
## 分工必须钉死，不然一定重复：原版服务端只发**裸任务名**，
## `[类型]` 前缀 + `(次数/上限)` + `（状态）` 与**颜色**全在客户端拼 ——
## `QuestDialog.as:267-313`（前缀/计数，按 `getQuestType(quest)` 回任务配置查）
## 与 `:314-334`（`switch(tag.status)`：进行中 #1e90ff，其余 #00ff00）。
## 10-09 那次 #141 把这三样搬去了服务端、客户端那份没删 ⇒ 打出双份。
## ⇒ 本门两头都判：**客户端渲染出的整串**逐字等于原版形状，且**服务端源码里不许再拼装饰**。
extends SceneTree

const 窗 := preload("res://脚本/界面/窗口/NPC对话窗.gd")
const 服务端路 := "res://服务端/runtime/tools/fake_flash_server.py"

var _失败: Array[String] = []
var _条数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


func _等(实: String, 期: String, 说明: String) -> void:
	_断言(实 == 期, "%s：期望「%s」实际「%s」" % [说明, 期, 实])


func _run() -> void:
	## ① 客户端整串（逐字）
	_等(窗.选择文案({"文字": "神奇的防具", "类型": "trunk", "任务状态": 0}),
			"[主线]神奇的防具（可接）", "主线可接")
	_等(窗.选择文案({"文字": "无尽的牵挂", "类型": "trunk", "任务状态": 1}),
			"[主线]无尽的牵挂（进行中）", "主线进行中")
	_等(窗.选择文案({"文字": "补给者", "类型": "trunk", "任务状态": 2}),
			"[主线]补给者（可交）", "主线可交")
	_等(窗.选择文案({"文字": "每日环任务", "类型": "daily", "任务状态": 0, "次数": 1, "上限": 20}),
			"[日环]每日环任务(1/20)（可接）", "日环带上限")
	_等(窗.选择文案({"文字": "护送任务", "类型": "mixin", "任务状态": 2, "次数": 3, "上限": 3}),
			"[护送]护送任务(3/3)（可交）", "护送带上限")
	# 帧里 status=3 那一支原版**不加后缀**（`:326-328` 只有 color，没有 CN.QUEST_DIALOG_*）
	_等(窗.选择文案({"文字": "某任务", "类型": "branch", "任务状态": 3}),
			"[支线]某任务", "status=3 不许有后缀")
	_等(窗.选择文案({"文字": "某任务", "类型": "trunk", "任务状态": 4}),
			"[主线]某任务（对话）", "对话档")
	# 类型查不到时不许冒出空前缀
	_等(窗.选择文案({"文字": "某任务", "任务状态": 0}), "某任务（可接）", "无类型不得有空串前缀")
	## 只有那五类拼计数（`:266-313`）；主线/支线即使给了上限也不拼
	_等(窗.选择文案({"文字": "某主线", "类型": "trunk", "任务状态": 0, "次数": 2, "上限": 9}),
			"[主线]某主线（可接）", "主线不许拼计数")
	_断言(窗.选择文案({"文字": "A:B&C", "类型": "trunk", "任务状态": 0}) == "[主线]A:B&C（可接）",
			"客户端不该管转义（那是服务端的事），这里只确认它不吞字符")

	## ② 服务端只许发裸名
	var 服 := FileAccess.get_file_as_string(服务端路)
	_断言(服.contains("def _quest_row_label(self, name: str) -> str:"),
			"服务端 _quest_row_label 的签名变了 ⇒ 它可能又开始拼装饰，两头会重复")
	var 体 := _截(服, "def _quest_row_label", "\n    def ")
	_断言(体.contains("return name.replace"), "_quest_row_label 不再只做名字净化")
	## **只看代码，不看注释**：docstring 里写着「（可接/进行中/可交）」是在解释规则，
	## 拿它当禁字判会自己咬自己（第一版就红在这）。
	var 码 := 体
	var 开 := 码.find("\u0022\u0022\u0022")
	if 开 >= 0:
		var 闭 := 码.find("\u0022\u0022\u0022", 开 + 3)
		if 闭 > 0:
			码 = 码.substr(0, 开) + 码.substr(闭 + 3)
	for 禁 in ["QUEST_STATUS_LABELS", "QUEST_TYPE_LABELS", "\uff08"]:
		_断言(not 码.contains(禁), "_quest_row_label 的代码里出现了 %s ⇒ 服务端又在拼后缀，会双份" % 禁)
	_断言(not 服.contains("QUEST_STATUS_LABELS") and not 服.contains("QUEST_TYPE_LABELS"),
			"那两张标签表应当随之后缀一起删掉（留着就会有人再引进去）")
	## 调用点一律单参（多传一个实参就说明有人又把类型/状态喂给服务端了）
	const 名长 := 17					# len("_quest_row_label(")
	var 处数 := 0
	var 尾 := 服
	while true:
		var 位 := 尾.find("_quest_row_label(")
		if 位 < 0:
			break
		尾 = 尾.substr(位 + 名长)
		if 尾.begins_with("self"):		# def 那一行
			continue
		处数 += 1
		var 收 := 尾.find(")")
		_断言(收 > 0 and not 尾.substr(0, 收).contains(","),
				"服务端这处 _quest_row_label 带了多余实参：%s" % 尾.substr(0, maxi(收, 40)).strip_edges())
	_断言(处数 >= 7, "只扫到 %d 处调用点（原表是 7 处），清单漂了" % 处数)

	## ③ 类型回表：NPC 表只覆盖有本地落地页的几扇 ⇒ 普通主线要能从 任务.json 查到
	var HUD := FileAccess.get_file_as_string("res://脚本/界面/小地图面板.gd")
	_断言(HUD.contains("_追踪定义.get(str(号), {}) as Dictionary"),
			"_选择条目 没有「NPC 表查不到就回 任务.json 查 info.type」这一层 ⇒ [主线] 前缀会掉")
	var 定: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/任务.json"))
	_断言(typeof(定) == TYPE_DICTIONARY, "数据/任务.json 读不出来")
	if typeof(定) == TYPE_DICTIONARY:
		var 找到 := 0
		for k in (定 as Dictionary).keys():
			var v: Variant = (定 as Dictionary)[k]
			if typeof(v) != TYPE_DICTIONARY:
				continue
			var 信: Dictionary = (v as Dictionary).get("info", {}) as Dictionary
			if String(信.get("type", "")) == "trunk" and String(信.get("name", "")) == "神奇的防具":
				找到 += 1
				_断言(int(信.get("loopCount", 0)) == 0, "主线不该有 loopCount")
		_断言(找到 == 1, "任务.json 里「神奇的防具」命中 %d 条（应为 1）⇒ 查类型的口径不成立" % 找到)
	_finish()


func _截(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)


func _finish() -> void:
	if _失败.is_empty():
		print("任务选择行文案回归测试：通过（%d 条）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("任务选择行文案回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
