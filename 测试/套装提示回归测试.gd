extends SceneTree

## 套装四灯的悬停提示（原版 `seriesEquipTooltips`，`EquipPane.as:926-945` 拼串 + `:942` 挂 MToolTipText）。
## ① 纯函数：拿真数据表（`taozhuang`/`values`/语言模板）手算钉串；
## ② 端到端：人物页开出来，对"等阶套装"灯 emit mouse_entered ⇒ 提示框可见、内容就绪、无标签残留。
const 提示 := preload("res://脚本/单例/套装提示.gd")
const 部位 := preload("res://脚本/单例/装备部位.gd")

class 假会话:
	var equipped_items := {}

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _装备(阶: int, 资: int, 强: int) -> Dictionary:
	return {"id": "0000000", "stage": 阶, "aptitude": 资, "strengthen": 强, "inlays": []}

func _run() -> void:
	var 输出: Array = []
	var 工程 := ProjectSettings.globalize_path("res://")
	var 码 := OS.execute(工程.path_join("运行时/python/python.exe"),
		["-X", "utf8", 工程.path_join("测试/等阶套装结算回归测试.py")], 输出, true)
	for 行 in 输出:
		print(行)
	_check(码 == 0, "服务端等阶套装结算必须通过")
	# —— ① 等阶灯：12 件同阶。百分比=valueProb(5)×件数1（原版 sameStageCount 恒 1）=5；
	#    假装备没有任何属性值 ⇒ 追加 "+0"。两行 = maxmp、avd。
	var 会 := 假会话.new()
	for 位 in 部位.标准槽:
		会.equipped_items[位] = _装备(7, 1, 0)
	var html0: String = 提示.提示html(0, 会)
	_check(html0.contains("【等阶套装】"), "等阶灯应带系列名（实际 %s）" % html0.left(80))
	_check(html0.contains("【已启动】"), "12 件同阶 ⇒ 状态文案是【已启动】")
	var 名1 := 提示.文("ITEM_ATTR_NAME_MAXMP")
	var 名2 := 提示.文("ITEM_ATTR_NAME_AVD")
	# ⚠️ 消息串里的百分号要么转义要么绕开——§3.68.1 的裸 `%` 坑我在这条消息里**又踩了一次**。
	_check(html0.contains(名1 + "5%" + "  +0"),
			"效果行应有 <名1>5%% +0（valueProb=5×件数1）。实际=" + html0)
	_check(html0.contains(名2), "第二行是闪避（%s）" % 名2)
	_check(html0.contains(提示.文("ITEM_ATTR_NAME_AVD")), "第二行是闪避")
	_check(html0.contains("<font") and html0.contains("<br/>"),
			"拼出的就是原版形态的 HTML（<font>/<br/>），到组件里才转 BBCode")

	# —— 全紫 3 件（未满）⇒ TIP2：红色【已启动 3/12】+ values[3]=0.4 行 + 灰色【已启动 4/12】+ values[4]=0.6 行
	var 会2 := 假会话.new()
	for i in 3:
		会2.equipped_items[部位.标准槽[i]] = _装备(1 + i, 4, 0)
	for i in range(3, 12):
		会2.equipped_items[部位.标准槽[i]] = _装备(1 + i, 1, 0)
	var html1: String = 提示.提示html(1, 会2)
	_check(html1.contains("【全紫套装】") and html1.contains("已启动 3/12") and html1.contains("已启动 4/12"),
			"未满 12 的全紫灯应有 3/12 与下阶 4/12（实际 %s）" % html1.left(160))
	_check(html1.contains("0.4%") and html1.contains("0.6%"),
			"quanzi 百分比取 values[3]=0.4 / values[4]=0.6（实际 %s）" % html1)
	# 等阶灯在"件数不足 12"时恒灰（TIP + 未启动）
	var html0g: String = 提示.提示html(0, 会2)
	_check(html0g.contains("【未启动】"), "阶数不同 + 计数不是它判的 ⇒ 等阶灯未启动")

	var 在线 := 假会话.new()
	var 编号 := [1010011, 1020010, 1030011, 1040011, 1050011, 1060011,
		1070010, 1080010, 1090010, 1100010, 1110010, 1120010]
	for i in 12:
		在线.equipped_items[部位.标准槽[i]] = {"id": str(编号[i]), "aptitude": 1,
			"plus_attributes": [{"attribute_type": 2, "attribute_value": 100},
				{"attribute_type": 7, "attribute_value": 20}]}
	_check(提示.四灯(在线)[0], "在线七位编号、无stage的同阶12件应亮灯")
	var 在线文 := 提示.提示html(0, 在线)
	_check(在线文.contains(名1 + "5%  +60"), "在线附加查克拉1200应显示加60")
	_check(在线文.contains(名2 + "5%  +12"), "在线附加闪避240应显示加12")
	在线.equipped_items[-1]["id"] = "1010021"
	_check(not 提示.四灯(在线)[0], "在线混阶不亮灯")
	在线.equipped_items[-1]["id"] = "99999999"
	_check(not 提示.四灯(在线)[0], "未知装备阶数不视作同阶")
	在线.equipped_items.erase(-1)
	_check(not 提示.四灯(在线)[0], "在线11件不亮灯")

	# —— ② 端到端悬停
	var 窗: Node = await _开窗()
	var 面板 := 窗.find_child("原版人物属性面板", true, false)
	var 页面 := 面板.get_parent()
	var 灯 := 面板.get_node("装备栏/套装图标/等阶套装") as TextureRect
	var 框 := 页面.get_node_or_null("套装提示框") as Control
	_check(灯 != null and 框 != null, "场景应有 等阶套装 灯与 套装提示框 节点")
	_check(灯.mouse_filter == Control.MOUSE_FILTER_STOP, "灯必须收得到悬停（默认 IGNORE 收不到）")
	灯.mouse_entered.emit()
	await process_frame
	_check(框.visible, "悬停灯应弹出提示框")
	框 = 页面.get_node_or_null("套装提示框") as Control
	var 文: RichTextLabel = 框.get_node("文")
	_check(文.text.contains("【等阶套装】"), "提示内容应是那枚灯的文案（实际 %s）" % 文.text.left(60))
	_check(not 文.text.contains("<font") and not 文.text.contains("<br"), "展示前必须过富文本转换，不残留 HTML 标签")
	_check(框.size.x <= 354.0 + 17.0 and 框.size.x > 60.0, "宽度应 hug 到内容且不超原版上限（实际 %.0f）" % 框.size.x)
	灯.mouse_exited.emit()
	await process_frame
	_check(not 框.visible, "移开应收起")
	_收尾()

func _开窗() -> Node:
	var 场景 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	await process_frame
	场景.call("open_page", "人物")
	for _i in 30:
		await process_frame
	return 场景

func _收尾() -> void:
	if _失败.is_empty():
		print("套装提示回归测试：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("套装提示回归测试：" + 项)
	quit(1)
