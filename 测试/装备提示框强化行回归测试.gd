extends SceneTree

## 提示框「强化等级」行的完整形态（`MToolTipZhuangBei.as:361-377 + 732-755`）：
##   文本数字 = **`strength_info.length`（次数）**、满星看**等级≥10**、整行按等级染色、
##   行尾小蓝钻（<10 灰）、>10 再一枚蓝钻+橙字【精炼额外加一星】、下面一排**星**（10 一行）。
## ⚠️ 我们原来整段只有 `强化等级 N` 一个数，且 N 拿的是**等级**——次数/蓝钻/星排全缺。
const 提示框场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 星图标 := "res://素材/界面/原版窗口/家族/星标.png"
const 蓝钻图 := "res://素材/界面/原版窗口/人物/角色/蓝钻.png"
const 蓝钻灰图 := "res://素材/界面/原版窗口/人物/角色/蓝钻_灰.png"

var _失败: Array[String] = []

func _initialize() -> void: call_deferred("_跑")

func _实例(等级: int, 次数: int) -> Dictionary:
	var 记录: Array = []
	for i in 次数:
		记录.append(true)
	return {"aptitude": 1, "strengthen": 等级, "strength_info": 记录,
		"base_attr_type": 4, "base_attr_value": 10, "endure": 10, "max_endure": 10,
		"crash_time": 0, "plus_attributes": [], "inlays": [], "forge_additive_ratio": 0}

func _跑() -> void:
	await _案(_实例(3, 3), func(文: String, 查: Callable):
		查.call(文.contains("强化等级　3"), "次数=3 ⇒ 文本数字应是 3（不是等级——这里等级也是 3，主要防回退）")
		查.call(文.contains(蓝钻灰图), "等级<10 ⇒ 行尾应是**灰**蓝钻")
		查.call(文.count(星图标) == 3, "星排应 3 颗（实际 %d）" % 文.count(星图标))
		查.call(文.contains("[color=#ff9e16]"), "等级>0 ⇒ 整行橙"))
	await _案(_实例(10, 7), func(文: String, 查: Callable):
		查.call(文.contains("强化等级　7"), "文本=次数 7（等级 10 只影响满星/颜色/蓝钻）")
		查.call(文.contains("(满星)"), "次数>0 且 等级≥10 ⇒ 带(满星)")
		查.call(文.contains(蓝钻图) and not 文.contains(蓝钻灰图), "等级≥10 ⇒ 彩蓝钻")
		查.call(文.count(星图标) == 10, "星按**等级**给：10 颗")
		查.call(not 文.contains(星图标 + "[img=12x10]" + 蓝钻图), "等级==10 不缀额外蓝钻（>10 才有）"))
	await _案(_实例(12, 11), func(文: String, 查: Callable):
		查.call(文.count(星图标) == 10, ">10 星也只画 10 颗")
		查.call(文.contains("【精炼额外加一星】"), "等级>10 ⇒ 橙字【精炼额外加一星】")
		查.call(文.count(蓝钻图) >= 2, "行内蓝钻 + 额外蓝钻 + 星排尾蓝钻，至少 2 枚"))
	await _案({} , func(文: String, 查: Callable):
		查.call(not 文.contains("强化等级"), "没强化数据 ⇒ 整行不出现"))
	# 离线兜底：只有 strengthen、没有 strength_info ⇒ 按旧口径显示等级、无星排
	await _案_裸({"aptitude": 1, "strengthen": 5, "endure": 10, "max_endure": 10,
		"crash_time": 0, "plus_attributes": [], "inlays": [], "forge_additive_ratio": 0},
		func(文: String, 查: Callable):
			查.call(文.contains("强化等级　5"), "离线兜底：无 strength_info 时按等级显示")
			查.call(文.count(星图标) == 0, "离线兜底：没有次数记录 ⇒ 不画星排"))
	if _失败.is_empty():
		print("装备提示框强化行回归测试：通过")
		quit(0)
		return
	for 项 in _失败:
		printerr("装备提示框强化行回归测试：" + 项)
	quit(1)

func _案(实例: Dictionary, 检: Callable) -> void:
	await _案_裸2("01010023", 实例, 检)

func _案_裸(实例: Dictionary, 检: Callable) -> void:
	await _案_裸2("01010023", 实例, 检)

func _案_裸2(id: String, 实例: Dictionary, 检: Callable) -> void:
	var 框 := 提示框场景.instantiate() as Control
	root.add_child(框)
	for _i in 3:
		await process_frame
	框.call("设置", id, 100, 300, 实例)
	for _i in 2:
		await process_frame
	var 文 := (框.get_node("明细") as RichTextLabel).text
	检.call(文, func(ok: bool, 话: String):
		if not ok:
			_失败.append(话 + "　[%s]" % 文.replace("\n", "⏎").left(200)))
	框.queue_free()
	await process_frame
