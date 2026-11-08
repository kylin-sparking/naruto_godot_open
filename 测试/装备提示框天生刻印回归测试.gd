extends SceneTree

## 提示框「基本属性段」与「刻印图」的回归（2026-10-01 用户两条反馈）。
##
## 真值 `MToolTipZhuangBei.as:405-433`，基本属性段是**抬头 + 三条独立值行**：
##   · 抬头（橙 16751126）三态：天生==基础>0 → `基本属性（满天生）`；
##     两者>0 → `基本属性（天生NN%  +天生值）`，NN=round(天生×100/基础)、**算出 100 也写 99**（:412-415）；
##     只有基础 → `基本属性`；**天生>0 而基础==0 没有抬头**（只有天生值行）。
##   · 三段值**合在同一行**（`<br/>` 只在抬头两头）：`　<属性名>　+基础`（白；类型 -1/MONEY(0) 不印）
##     + `　天生　+N`（橙，MTOOTIP_INNATENESS :2136/:427）+ `　强化　+N`（青 #3df0f7=4059383，:430），
##     各段**各看各的值**互不牵连（图证：原版满养成「攻击 +615 天生 +615 强化 +2245」一行三样色）。
##   ⚠️ 我们旧版把整段罩在 `基础类型 != 0` 下、且天生/强化无色标：
##     基础类型未定而天生>0 的件（用户实测的那类）**天生信息整个看不见**。
##     （本门第一版曾把三段钉成"三条独立行"，也是读漏 `<br/>` 位置——同一张图纠出来的。）
##
## 刻印图（`_建刻印图`，原版 `:928-950` 彩色底 + 灰盖两层）：
##   清旧图必须 **remove_child+free() 当场删**。queue_free 等帧尾，同帧内同名还在 ⇒
##   新建被 Godot 自动改名 `@TextureRect@N` ⇒ 下轮"按名清理"永远匹配不到 ⇒
##   **图案一层层摞在同一坐标**（用户报"装备多次打造后图案重叠"；探针同帧三连设复现）。
##
## 运行：Godot --headless --path . --script res://测试/装备提示框天生刻印回归测试.gd

const 提示框场景 := preload("res://场景/界面/组件/装备提示框.tscn")

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void: call_deferred("_跑")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _实例(补丁: Dictionary) -> Dictionary:
	var 实例 := {"aptitude": 1, "endure": 100, "max_endure": 120, "crash_time": 0,
		"plus_attributes": [], "inlays": [], "forge_additive_ratio": 0,
		# 基础类型 1 = 生命值上限（探针实测口径；4 是暴击，名字行别拿 1 的话去断 20）
		"base_attr_type": 1, "base_attr_value": 20}
	实例.merge(补丁, true)
	return 实例

func _跑() -> void:
	# —— 天生段四态 + 独立行 ——
	var 文 := await _取文(_实例({"born_attr_value": 15, "strength_value": 3}))
	_查(文.contains("基本属性（天生75%  +15）"), "抬头该带百分比（15/20=75%%），实际行：%s" % _含行(文, "基本属性"))
	# ⚠️ 2026-10-01 用原版满养成图（攻击+615 天生+615 强化+2245 同行）纠口径：
	#    原版的 `<br/>` 只在抬头两头，**名字/天生/强化三段合在同一行**、各段自己带色。
	var 值行 := _含行(文, "　天生　+15")
	_查(值行.contains("　生命值上限　+20"), "基础名段应在**同一行**（白），实际「%s」" % 值行)
	_查(值行.contains("[color=#ff9e16]　天生　+15[/color]"), "天生段橙色 16751126")
	_查(值行.contains("[color=#3df0f7]　强化　+3[/color]"), "强化段青色 4059383，也在同一行")

	文 = await _取文(_实例({"born_attr_value": 20}))
	_查(文.contains("基本属性（满天生）"), "天生==基础 ⇒ 满天生抬头")

	文 = await _取文(_实例({"base_attr_value": 200, "born_attr_value": 199}))
	_查(文.contains("基本属性（天生99%  +199）"), "round(99.5)=100 也写 99（原版怪癖 :413-415）")

	文 = await _取文(_实例({"born_attr_value": 0}))
	_查(文.contains("基本属性") and not 文.contains("天生　"), "只有基础 ⇒ 裸抬头、无天生行")

	# —— 用户实测的那类：基础类型未定（0），天生/强化仍必须各自成行 ——
	文 = await _取文(_实例({"base_attr_type": 0, "base_attr_value": 0, "born_attr_value": 8,
			"strength_value": 2}))
	_查(文.contains("[color=#ff9e16]　天生　+8[/color]"), "基础类型 0 也要有天生行（旧版整段被吞=用户报的病根）")
	_查(文.contains("[color=#3df0f7]　强化　+2[/color]"), "同上，强化独立判定")
	_查(not 文.contains("基本属性"), "基础值 0 ⇒ 原版无抬头")

	# —— 秘印段的值行（顺带钉措辞两分支）——
	# ⚠️ 秘印**不在 `明细` 的文本里**：稀有段是 `稀有明细` 下的独立 Label
	#   （`秘印抬头`/`秘印段`）+ 动态刻印图，拿明细文断言等于断了个不存在的位置。
	var 框 := 提示框场景.instantiate() as Control
	root.add_child(框)
	for _i in 3:
		await process_frame
	框.call("设置", "01010023", 30, 300, _实例({"carve_id": 1, "carve_type": 1, "carve_value": 2}))
	var 秘印行 := _秘印段文(框)
	_查(秘印行.contains("（最大5%）"), "没到顶 ⇒ 带最大档（刻印值表 id=1 value_max=5），实际「%s」" % 秘印行)
	框.call("设置", "01010023", 30, 300, _实例({"carve_id": 1, "carve_type": 1, "carve_value": 5}))
	_查(_秘印段文(框).contains("【梦幻满值】"), "到顶 ⇒ 梦幻满值")
	_查((_框找(框, "秘印抬头") as Label).text == "秘印属性", "抬头措辞照 MTOOL_MIYIN_SHUXING")

	# —— 刻印图：同帧连设三次只能留一套 ——
	var 带印 := _实例({"carve_id": 1, "carve_type": 1, "carve_value": 2})
	for 三次 in 3:
		框.call("设置", "01010023", 30, 300, 带印)
	_查(_刻印图数(框) == 2, "同帧三连设后 刻印图* 必须只剩一套（彩色+灰盖），实际 %d —— queue_free 版会摞出 @N 孤儿" % _刻印图数(框))
	await process_frame
	框.call("设置", "01010023", 30, 300, _实例({"carve_id": 2, "carve_type": 1, "carve_value": 3}))
	await process_frame
	_查(_刻印图数(框) == 2, "隔帧换 carve_id 重设仍是一套（旧图当场删掉，不留残尸）")
	框.call("设置", "01010023", 30, 300, _实例({"carve_id": 0}))
	_查(_刻印图数(框) == 0, "未刻印 ⇒ 一套都不该有")
	_查(not (_框找(框, "秘印段") as CanvasItem).visible, "未刻印 ⇒ 秘印段整体收起")
	框.call("设置", "01010023", 30, 300, 带印)
	_查(_刻印图数(框) == 2, "从空到有：同帧内清出再建，仍是一套")
	# —— 2026-11-04：在线下发的是**七位** id（`_parse_item_entry` 原样收 `String(values[1])`）——
	# 元数据表键是八位补零；不补零 ⇒ stage 恒 1、type_name 空 ⇒ 上限表空 ⇒
	# 「【梦幻满值】/ 最大可提升至」**在线永远不出现**（用户报「满值后没有梦幻满值标识」）。
	# 拿 stage2.EquipA 的 atk 上限 18 验：7 位与 8 位必须出同一份明细。
	var 满值件 := _实例({"plus_attributes": [{"attribute_type": 4, "attribute_value": 18}]})
	var 文七 := await _取文(满值件, "1010023")
	var 文八 := await _取文(满值件, "01010023")
	_查(文七.contains("【梦幻满值】"),
		"七位 id 也要取到附加属性上限 ⇒ 到顶该带【梦幻满值】，实际：%s" % _含行(文七, "攻击"))
	_查(文七 == 文八, "七位 / 八位 id 的明细必须一致（补零归一）")

	if _失败.is_empty():
		print("装备提示框天生刻印回归测试：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("装备提示框天生刻印回归测试：" + 项)
	quit(1)

func _含行(文: String, 词: String) -> String:
	for 行 in 文.split("\n"):
		if 行.contains(词):
			return 行
	return "<无该行>"

func _框找(框: Control, 名: String) -> Node:
	return 框.find_child(名, true, false)

func _秘印段文(框: Control) -> String:
	var 标 := _框找(框, "秘印段") as Label
	return 标.text if 标 != null else "<找不到秘印段>"

func _取文(实例: Dictionary, 物品id := "01010023") -> String:
	var 框 := 提示框场景.instantiate() as Control
	root.add_child(框)
	for _i in 3:
		await process_frame
	框.call("设置", 物品id, 30, 300, 实例)
	await process_frame
	var 标 := 框.find_child("明细", true, false) as RichTextLabel
	var 文 := 标.text if 标 != null else ""
	框.queue_free()
	for _i in 2:
		await process_frame
	return 文

## 稀有明细下的**图类**子节点数（彩色底 + 灰盖 = 健康值 2）。
## ⚠️ 按"名以 刻印図 开头"数会被骗：queue_free 版留下的孤儿在 add_child 撞名时
## 被 Godot 改名成 `@TextureRect@N`（类名打头，不带"刻印图"），名字筛根本看不见它们——
## 反向对照跑出来才发现这个计数口径要不得，**按类型数**才数得到实物。
## （Label 三件套 伝説段/秘印抬頭/秘印段 不在这个计数里；镶嵌图标在另一个容器。）
func _刻印图数(框: Control) -> int:
	var 明细父 := 框.find_child("稀有明细", true, false) as Control
	if 明细父 == null:
		return -1
	var 数 := 0
	for 子在 in 明细父.get_children():
		if 子在 is TextureRect:
			数 += 1
	return 数
