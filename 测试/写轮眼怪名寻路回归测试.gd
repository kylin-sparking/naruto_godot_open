extends SceneTree

## #30【怪名】绿字自动寻路（写轮眼页 12 阶）离线门。
##
## 真值链（2.2.3 反编译）：
##   `StructuredText.as:465` 点 `mob<mobid>-<mapid>` ⇒ `UI.qusetClickText(2, mobid, mapid)`
##   ⇒ `UI.as:769-775` 停挂机 + `CharacterHandler.MovePlayerToMob(mapid, mobid)`
##   （同图 `getNearMonster`/`getOneMobPostion` 真寻路；异图先 `MovePlayerToMap`）。
##   写轮眼页这一段文案/参数的出处是 `TongshuWindow.as:589`：
##   `XieLunYan.stageN.levelUp.mobid / mapid / itemId` —— 表在 `数据/原版杂项.json`。
##
## ⚠ 旧注释说"缺 BossWang 刷新点表所以做不了"是**假前提**：BossWang 只是
##   `getOneMobPostion` 取不到 MapObject 时的兜底（而且只回 mapid），不是写轮眼数据源。
##
## 五条腿：
##   ① 数据表 12 阶的 mobid/mapid 与真值逐条相等；
##   ② 场景里 12 个绿名按钮的文案 == `怪物.json` 里该 mobid 的名字（加【】）；
##   ③ 每阶按钮接到「去这只怪」，且重复渲染不叠连接；
##   ④ 逐个真按：落到 `小地图面板.走向怪(mapid, mobid)`，12 发参数全对；
##   ⑤ 源码接线：`小地图面板` 有公共出口，且先停挂机再复用任务怪那条。
##
## 跑法：Godot --headless --path . --script res://测试/写轮眼怪名寻路回归测试.gd

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 人物窗口 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 页面场景 := "res://场景/界面/窗口/人物/页面/写轮眼页.tscn"
const 阶段区路径 := "属性面板/阶段，数值名称切换区"
const 人物源 := "res://脚本/界面/窗口/人物窗口.gd"
const 小地图源 := "res://脚本/界面/小地图面板.gd"

## 真值抽样：`数据/原版杂项.json` 的 XieLunYan.stageN.levelUp
## （出处 `TongshuWindow.as:589` 取的就是这两个键）。
const 真值 := [
	[1, 1000004, 101030000], [2, 1000008, 102020000], [3, 1000012, 103030000],
	[4, 1000016, 104040000], [5, 1000020, 105040000], [6, 1000024, 106040000],
	[7, 1000028, 107030000], [8, 1000032, 108040000], [9, 1000036, 109030000],
	[10, 1000040, 110030000], [11, 1000044, 111040000], [12, 1000047, 112040000],
]

var 总 := 0
var 红 := 0
var 日志: Array[String] = []


class 假小地图:
	extends CanvasLayer
	var 收到: Array = []

	func 走向怪(图号: int, 怪号: int) -> void:
		收到.append([图号, 怪号])


func _记(过: bool, 说: String) -> void:
	总 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_表腿()
	var 页 := (load(页面场景) as PackedScene).instantiate() as Control
	var 区 := 页.get_node_or_null(阶段区路径) as Control
	_记(区 != null, "场景里有「%s」" % 阶段区路径)
	if 区 == null:
		_尾()
		return
	_记(区.get_child_count() == 12, "阶段容器 12 个（实际 %d）" % 区.get_child_count())

	# 宿主小地图：名字必须是 `小地图面板`，`人物窗口._寻路到怪` 按这个名字找。
	var 场景 := Node.new()
	场景.name = "测试地图场景"
	root.add_child(场景)
	current_scene = 场景
	var 小地图 := 假小地图.new()
	小地图.name = "小地图面板"
	场景.add_child(小地图)

	# 连续接两次：第二次不许再叠一条连接（页面实例是复用的）。
	人物窗口._接写轮眼怪名(root, 页)
	人物窗口._接写轮眼怪名(root, 页)

	for i in 真值.size():
		var 阶 := int(真值[i][0])
		var 怪 := int(真值[i][1])
		var 图 := int(真值[i][2])
		var 容器 := 区.get_child(i) as Control
		var 钮们 := 容器.find_children("【叛忍喽啰】", "Button", true, false)
		var 按钮 := 钮们[0] as Button if 钮们.size() == 1 else null
		_记(按钮 != null, "第 %d 阶有一只绿字怪名按钮（实际 %d 只）" % [阶, 钮们.size()])
		if 按钮 == null:
			continue
		var 期望名 := "【%s】" % String(游戏数据.monster_name(怪))
		_记(按钮.text == 期望名, "第 %d 阶绿名文案「%s」== 怪物表 %d 的名字（期望「%s」）"
				% [阶, 按钮.text, 怪, 期望名])
		_记(按钮.pressed.get_connections().size() == 1,
				"第 %d 阶只接 1 条（连点两次初始化不叠；实际 %d）"
				% [阶, 按钮.pressed.get_connections().size()])
		_记(String(按钮.tooltip_text).contains(按钮.text), "第 %d 阶提示里带怪名" % 阶)
		小地图.收到.clear()
		按钮.pressed.emit()
		var 收: Array = 小地图.收到
		_记(收.size() == 1 and int(收[0][0]) == 图 and int(收[0][1]) == 怪,
				"第 %d 阶按下 ⇒ 走向怪(图 %d, 怪 %d)，实际 %s" % [阶, 图, 怪, str(收)])

	_接线腿()
	页.free()
	场景.queue_free()
	_尾()


func _表腿() -> void:
	var 杂项 := 游戏数据.取表("原版杂项") as Dictionary
	var 眼表 := 杂项.get("XieLunYan", {}) as Dictionary
	_记(not 眼表.is_empty(), "`原版杂项` 里有 XieLunYan")
	for 条 in 真值:
		var 阶: int = int(条[0])
		var 升级: Dictionary = ((眼表.get("stage%d" % 阶, {}) as Dictionary).get("levelUp", {}) as Dictionary)
		_记(int(升级.get("mobid", -1)) == int(条[1]) and int(升级.get("mapid", -1)) == int(条[2]),
				"stage%d.levelUp = mob %d / map %d（实际 mob %d / map %d）"
				% [阶, int(条[1]), int(条[2]), int(升级.get("mobid", -1)), int(升级.get("mapid", -1))])


func _接线腿() -> void:
	var 人 := _码(人物源)
	var 图 := _码(小地图源)
	_记(not 人.contains("自动寻路本轮未移植"), "写轮眼绿名不再挂「本轮未移植」")
	_记(人.contains("_寻路到怪.bind(窗口, 图号, 怪号, 按钮.text)"), "绿名接到唯一出口 `_寻路到怪`")
	_记(图.contains("func 走向怪(图号: int, 怪号: int)"), "`小地图面板` 有公共出口 `走向怪`")
	_记(图.contains("request_hang\", false)"), "走向怪先停挂机（原版 `UI.as:769`）")
	_记(图.contains("_走向任务怪(\"%s%d:%d\" % [打怪链接, 图号, 怪号])"),
			"走向怪复用任务怪那条（同图最近活口 / 异图传送）")


## 剥注释再比 —— 注释里会写旧口径，拿原文 grep 会自证。
func _码(路: String) -> String:
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return ""
	var 文 := g.get_buffer(g.get_length()).get_string_from_utf8()
	g.close()
	var 留: Array[String] = []
	for 行 in 文.split("\n"):
		if 行.lstrip("\t ").begins_with("#"):
			continue
		留.append(行)
	return "\n".join(留)


func _尾() -> void:
	日志.append("")
	日志.append("汇：判 %d 条 / 红 %d 条" % [总, 红])
	var f := FileAccess.open("res://测试/截图/写轮眼怪名寻路.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)
