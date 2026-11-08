extends SceneTree

## 用户报修「字体偏小」这一轮的回归门（2026-11-01，第三十二轮）。
##
## 用户原话（逐字）：
##   1.1 忍术面板的忍术等级字体有点偏小，不够清晰；
##   1.2 忍术面板忍术升级条件里的数值字体，也可以再大一点，变清晰一点；
##   2 右侧的当前任务、可接任务面板，里面的字体不够清晰；
##
## 原版这三处的字号都是 **12**（`MLabel.as:219` `_textFormat.size = 12`；忍术格层数
## 走元件里的 `<font size="12">`），所以 12→14 是**用户点头的偏离**，不是真值。
## 能放大又不发虚的前提是 `simsun_原版.ttf` 的内嵌点阵：ppem 12..17 有 strike，
## 18 起退回灰度 AA（字节级证据在 `字体清晰回归测试` 的腿 K / 腿 J，这里不重复解 ttf）。
## 14 在表内 ⇒ 仍是 1-bit 点阵。改回 12 或越过 17 都会被下面「14 在点阵表内」那条抓到。
##
## 本门钉四组：
##   ① 常量：忍术两档 = 14、追踪行字号 = 14 且行距换成 5（一行推进仍是原版的 20px）
##   ② 忍术场景：忍术格/详情/升级条件三处节点字号与盒子几何（层数标题加宽到 118）
##   ③ 忍术运行期：真开窗后逐格量层数标签、详情层数、升级条件三个数值
##   ④ 追踪栏：页签/更多可玩内容/行内标题与正文的字号、line_separation、一行推进 20px
##
## 跑法：Godot --headless --path . --script res://测试/界面字号放大回归测试.gd

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 忍术窗源 := "res://脚本/界面/窗口/忍术窗口.gd"
const 忍术页面场景 := "res://场景/界面/窗口/忍术/忍术窗口.tscn"
const 忍术格场景 := "res://场景/界面/组件/忍术格.tscn"
const 小地图场景 := "res://场景/界面/小地图面板.tscn"
const 小地图脚本 := "res://脚本/界面/小地图面板.gd"
const 视口 := Vector2i(960, 560)

## 用户点名的三处放大到 14；18 是这条偏离的天花板（18 起灰度）。
const 放大字号 := 14
const 点阵字号表: Array = [12, 13, 14, 15, 16, 17]
## 追踪栏一行的推进 = 原版 `StructuredText` 的 textHeight 15 + LEADING 5（`StructuredText.as:23/27`）。
const 追踪行推进 := 20.0

var 判 := 0
var 红: Array[String] = []
var 日志: Array[String] = []
var _帧数 := 0
var _完成 := false


func _记(过: bool, 话: String) -> void:
	判 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 话])
	if not 过:
		红.append(话)


func _帧(n: int) -> void:
	for _i in n:
		await process_frame


## 看门狗：`_跑` 里任何一次 await 卡住都要红着退出，不许 headless 挂死。
func _process(_delta: float) -> bool:
	_帧数 += 1
	if _完成:
		return true
	if _帧数 > 3000:
		printerr("界面字号放大回归测试：%d 帧还没跑完（多半是 await 卡住）" % _帧数)
		quit(1)
		return true
	return false


func _找(根: Node, 脚本路: String) -> Node:
	if 根.get_script() != null and str(根.get_script().resource_path) == 脚本路:
		return 根
	for 子 in 根.get_children():
		var 得 := _找(子, 脚本路)
		if 得 != null:
			return 得
	return null


func _常量(脚本路: String) -> Dictionary:
	var 脚 := load(脚本路) as GDScript
	if 脚 == null:
		return {}
	return 脚.get_script_constant_map()


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = 视口
	_一_常量()
	await _二_忍术场景()
	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	var 包 := load(场景路径) as PackedScene
	if 包 == null:
		_记(false, "地图场景加载失败（%s）⇒ 运行期两组全跳过" % 场景路径)
		_尾()
		return
	var 场景 := 包.instantiate()
	root.add_child(场景)
	current_scene = 场景
	await _帧(14)
	await _三_忍术运行期(场景)
	await _四_追踪栏(场景)
	_尾()


## —— ① 常量与档位 ——
func _一_常量() -> void:
	var 忍 := _常量(忍术窗源)
	_记(int(忍.get("忍术等级字号", -1)) == 放大字号,
		"`忍术等级字号` = %s（用户 1.1，要 %d）" % [str(忍.get("忍术等级字号", "缺")), 放大字号])
	_记(int(忍.get("升级条件数值字号", -1)) == 放大字号,
		"`升级条件数值字号` = %s（用户 1.2，要 %d）" % [str(忍.get("升级条件数值字号", "缺")), 放大字号])
	var 小 := _常量(小地图脚本)
	_记(int(小.get("追踪行字号", -1)) == 放大字号,
		"`追踪行字号` = %s（用户 2，要 %d）" % [str(小.get("追踪行字号", "缺")), 放大字号])
	_记(int(小.get("追踪行距", -1)) == 5,
		"`追踪行距` = %s（14px 字高 15 + 5 = 推进 20，要 5）" % str(小.get("追踪行距", "缺")))
	_记(is_equal_approx(float(小.get("追踪行标题高", -1.0)), 追踪行推进),
		"`追踪行标题高` = %s（标题行仍按原版 20，不许跟着字号一起长）" % str(小.get("追踪行标题高", "缺")))
	_记(放大字号 in 点阵字号表,
		"放大到 %d 落在宋体内嵌点阵的 ppem 表 %s 内（18 起退灰度，见字体清晰回归测试腿 K）"
		% [放大字号, str(点阵字号表)])


## —— ② 忍术场景（用户 1.1 / 1.2 的节点层）——
func _二_忍术场景() -> void:
	var 格包 := load(忍术格场景) as PackedScene
	if 格包 == null:
		_记(false, "忍术格.tscn 加载失败")
	else:
		var 格 := 格包.instantiate()
		root.add_child(格)
		var 标签 := 格.get_node_or_null("等级") as Label
		if 标签 == null:
			_记(false, "忍术格里没有 `等级` 标签")
		else:
			var 号 := 标签.get_theme_font_size("font_size")
			var 字 := 标签.get_theme_font("font")
			_记(号 == 放大字号, "忍术格 `等级` 字号 = %d（要 %d）" % [号, 放大字号])
			var 行高 := 0.0 if 字 == null else 字.get_height(号)
			_记(行高 > 0.0 and 行高 <= 16.0,
				"14px 墨高 %.0f 装得进 `等级` 的 16px 框（26+16 = 42 ≤ 格底 42）" % 行高)
			var 宽 := 0.0 if 字 == null else 字.get_string_size("MAX", HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x
			_记(宽 > 0.0 and 宽 <= 50.0,
				"满级那枚 `MAX` 墨宽 %.0f 仍在 50px 的标签框内" % 宽)
		格.queue_free()

	var 页包 := load(忍术页面场景) as PackedScene
	if 页包 == null:
		_记(false, "忍术窗口.tscn 加载失败")
		return
	var 页 := 页包.instantiate()
	root.add_child(页)
	await _帧(2)
	var 层标 := 页.get_node_or_null("忍术详情/层数标题") as Label
	var 层值 := 页.get_node_or_null("忍术详情/层数") as Label
	_记(层标 != null and 层标.get_theme_font_size("font_size") == 放大字号,
		"详情 `层数标题` 字号 = %s（要 %d）" % [
			str(-1 if 层标 == null else 层标.get_theme_font_size("font_size")), 放大字号])
	_记(层值 != null and 层值.get_theme_font_size("font_size") == 放大字号,
		"详情 `层数` 字号 = %s（要 %d）" % [
			str(-1 if 层值 == null else 层值.get_theme_font_size("font_size")), 放大字号])
	if 层标 != null and 层值 != null:
		var 字 := 层标.get_theme_font("font")
		var 墨宽 := 0.0 if 字 == null else 字.get_string_size("层数：", HORIZONTAL_ALIGNMENT_LEFT, -1, 放大字号).x
		_记(层标.offset_right <= 层值.offset_left + 0.01,
			"`层数标题` 框右缘 %.0f ≤ `层数` 框左缘 %.0f（加宽后两块不叠）" % [
				层标.offset_right, 层值.offset_left])
		_记(层标.offset_right - 层标.offset_left >= 墨宽,
			"`层数标题` 框宽 %.0f ≥ 「层数：」14px 墨宽 %.0f" % [
				层标.offset_right - 层标.offset_left, 墨宽])
		_记(is_equal_approx(层值.offset_right, 210.0),
			"`层数` 值框右缘仍是 %.0f（详情区宽 210，改 x 不许改宽）" % 层值.offset_right)
	var 区 := 页.get_node_or_null("忍术详情/升级条件区")
	if 区 == null:
		_记(false, "忍术详情里没有 `升级条件区`")
	else:
		for 名 in ["需要等级", "金币消耗", "精华消耗"]:
			var 值 := 区.get_node_or_null(名) as Label
			_记(值 != null and 值.get_theme_font_size("font_size") == 放大字号,
				"升级条件 `%s` 字号 = %s（要 %d）" % [
					名, str(-1 if 值 == null else 值.get_theme_font_size("font_size")), 放大字号])
		# 三枚标题仍是 12：用户只点名「数值」。12px 的「需要等级：」正好 60 宽（框 9..69），
		# 放大标题就得连带挪值框，本轮不做。
		var 标题 := 区.get_node_or_null("需要等级标题") as Label
		var 值框 := 区.get_node_or_null("需要等级") as Label
		if 标题 != null and 值框 != null:
			var 字 := 标题.get_theme_font("font")
			var 号 := 标题.get_theme_font_size("font_size")
			var 墨宽 := 0.0 if 字 == null else 字.get_string_size("需要等级：", HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x
			_记(号 == 12 and 标题.offset_left + 墨宽 <= 值框.offset_left + 0.01,
				"升级条件标题仍 12px、墨迹右缘 %.0f 不压值框（左缘 %.0f）" % [
					标题.offset_left + 墨宽, 值框.offset_left])
	页.queue_free()


## —— ③ 忍术运行期：真开窗，量渲染出来的标签 ——
func _三_忍术运行期(场景: Node) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 底栏 := 场景.get_node_or_null("技能面板/技能栏") as Control
	if 管理 == null or 底栏 == null:
		_记(false, "场景里缺 `窗口管理` 或 `技能面板/技能栏` ⇒ 忍术运行期那组跳过")
		return
	var 窗: Node = 管理.call("取或建窗口", "忍术")
	if 窗 == null:
		_记(false, "取或建窗口(忍术) 返回 null")
		return
	var 按到了 := false
	for 节点 in 底栏.find_children("*", "BaseButton", true, false):
		var 钮 := 节点 as BaseButton
		if 钮 != null and 钮.tooltip_text == "忍术":
			钮.pressed.emit()
			按到了 = true
			break
	_记(按到了, "底栏找到 tooltip=忍术 的按钮（找不到说明这组根本没开窗）")
	await _帧(6)
	var 容器 := 窗.find_child("忍术格容器", true, false) as Control
	if 容器 == null:
		_记(false, "忍术页没渲染出来（`忍术格容器` 找不到）⇒ 运行期字号没得量")
		return
	var 量过 := 0
	var 错号: Array[String] = []
	for 子 in 容器.get_children():
		var 格 := 子 as Button
		if 格 == null or not 格.visible or not String(格.name).begins_with("忍术格_"):
			continue
		var 标签 := 格.get_node_or_null("等级") as Label
		if 标签 == null or not 标签.visible:
			continue
		量过 += 1
		if 标签.get_theme_font_size("font_size") != 放大字号:
			错号.append("%s=%d" % [格.name, 标签.get_theme_font_size("font_size")])
	_记(量过 > 0, "忍术页真的渲染出 %d 个带层数的格子（0 个 = 下面那条等于没测）" % 量过)
	_记(错号.is_empty(), "逐格层数字号都是 %d（不对的：%s）" % [放大字号, ", ".join(错号)])

	var 详情 := 窗.find_child("忍术详情", true, false) as Control
	if 详情 == null:
		_记(false, "忍术页里没有 `忍术详情`")
		return
	var 层标 := 详情.get_node_or_null("层数标题") as Label
	var 层值 := 详情.get_node_or_null("层数") as Label
	_记(层标 != null and 层标.get_theme_font_size("font_size") == 放大字号,
		"运行期 `层数标题` 字号 = %s（要 %d）" % [
			str(-1 if 层标 == null else 层标.get_theme_font_size("font_size")), 放大字号])
	_记(层值 != null and 层值.get_theme_font_size("font_size") == 放大字号,
		"运行期 `层数` 字号 = %s（要 %d）" % [
			str(-1 if 层值 == null else 层值.get_theme_font_size("font_size")), 放大字号])

	# 升级条件区平时只在「已学」时显形，离线档不一定有已学忍术 ⇒ 直接喂一份选中条目渲染它，
	# 量到的仍是产品码那条腿（`_渲染升级条件` 自己）。
	var 忍术脚本 := load(忍术窗源) as GDScript
	忍术脚本.call("_渲染升级条件", 窗, 详情, {"id": "0001001", "level": 1, "master_level": 0}, {}, true)
	await _帧(2)
	var 区 := 详情.get_node_or_null("升级条件区") as Control
	if 区 == null or not 区.visible:
		_记(false, "`升级条件区` 没显形（`_渲染升级条件` 没跑到）")
		return
	var 提升 := 区.get_node_or_null("提升层数") as Button
	for 名 in ["需要等级", "金币消耗", "精华消耗"]:
		var 值 := 区.get_node_or_null(名) as Label
		_记(值 != null and 值.get_theme_font_size("font_size") == 放大字号,
			"运行期升级条件 `%s` 字号 = %s（要 %d）" % [
				名, str(-1 if 值 == null else 值.get_theme_font_size("font_size")), 放大字号])
		if 值 == null or 提升 == null:
			continue
		var 字 := 值.get_theme_font("font")
		var 墨宽 := 0.0 if 字 == null else 字.get_string_size(
			值.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 值.get_theme_font_size("font_size")).x
		_记(值.offset_left + 墨宽 <= 提升.offset_left + 0.01,
			"`%s` 的 14px 墨迹右缘 %.0f 不压「提升层数」按钮（左缘 %.0f）" % [
				名, 值.offset_left + 墨宽, 提升.offset_left])


## —— ④ 追踪栏（用户 2）——
func _四_追踪栏(场景: Node) -> void:
	var 面板 := _找(场景, 小地图脚本)
	_记(面板 != null, "地图场景里挂着小地图面板（追踪栏这组要它）")
	if 面板 == null:
		return
	var 包 := load(小地图场景) as PackedScene
	if 包 == null:
		_记(false, "小地图面板.tscn 加载失败")
		return
	var 实例 := 包.instantiate()
	root.add_child(实例)
	await _帧(2)
	var 当前 := 实例.get_node_or_null("小地图区域/任务追踪/当前任务页签") as Button
	var 可接 := 实例.get_node_or_null("小地图区域/任务追踪/可接任务页签") as Button
	_记(当前 != null and 当前.get_theme_font_size("font_size") == 放大字号,
		"「当前任务」页签字号 = %s（要 %d）" % [
			str(-1 if 当前 == null else 当前.get_theme_font_size("font_size")), 放大字号])
	_记(可接 != null and 可接.get_theme_font_size("font_size") == 放大字号,
		"「可接任务」页签字号 = %s（要 %d）" % [
			str(-1 if 可接 == null else 可接.get_theme_font_size("font_size")), 放大字号])
	for 钮 in [当前, 可接]:
		if 钮 == null:
			continue
		var 按钮: Button = 钮
		var 字: Font = 按钮.get_theme_font("font")
		var 墨宽 := 0.0 if 字 == null else 字.get_string_size(
			按钮.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 放大字号).x
		_记(按钮.size.x > 0.0 and 墨宽 <= 按钮.size.x + 0.01,
			"`%s` 四字墨宽 %.0f 装得进加宽后的 %.0f 框" % [按钮.text, 墨宽, 按钮.size.x])
	var 更多 := 实例.get_node_or_null("小地图区域/任务追踪/更多可玩内容") as RichTextLabel
	_记(更多 != null and 更多.get_theme_font_size("normal_font_size") == 放大字号,
		"「更多可玩内容」字号 = %s（要 %d）" % [
			str(-1 if 更多 == null else 更多.get_theme_font_size("normal_font_size")), 放大字号])
	实例.queue_free()

	var 列表 := 面板.get_node_or_null("小地图区域/任务追踪/任务内容区/任务列表") as Control
	if 列表 == null:
		_记(false, "追踪栏没有 `任务列表`")
		return
	var 行: Node = 面板.call("_create_quest_renderer",
		{"id": "9001", "name": "暗部任务-清剿", "request_level": 30, "completed": false}, true)
	列表.add_child(行)
	await _帧(4)
	var 标: Label = null
	var 文: RichTextLabel = null
	for 子 in 行.get_children():
		if 子 is Label and 标 == null:
			标 = 子 as Label
		elif 子 is RichTextLabel and 文 == null:
			文 = 子 as RichTextLabel
	_记(标 != null and 标.get_theme_font_size("font_size") == 放大字号,
		"追踪行标题字号 = %s（要 %d）" % [
			str(-1 if 标 == null else 标.get_theme_font_size("font_size")), 放大字号])
	_记(文 != null and 文.get_theme_font_size("normal_font_size") == 放大字号,
		"追踪行正文字号 = %s（要 %d）" % [
			str(-1 if 文 == null else 文.get_theme_font_size("normal_font_size")), 放大字号])
	if 文 != null:
		_记(文.get_theme_constant("line_separation") == 5,
			"追踪行正文 line_separation = %d（要 5）" % 文.get_theme_constant("line_separation"))
	if 标 != null and 文 != null:
		var 字 := 标.get_theme_font("font")
		var 文号 := 文.get_theme_font_size("normal_font_size")
		var 行高 := 0.0 if 字 == null else 字.get_height(文号)
		var 距 := 文.get_theme_constant("line_separation")
		_记(is_equal_approx(行高 + 距, 追踪行推进),
			"一行推进 = 字高 %.0f + 行距 %d = %.0f（原版 textHeight 15 + LEADING 5 = 20）" % [
				行高, 距, 行高 + 距])
		_记(is_equal_approx(标.custom_minimum_size.y, 追踪行推进),
			"标题行框高仍 %.0f（标题不跟着字号变高）" % 标.custom_minimum_size.y)
	行.queue_free()


func _尾() -> void:
	_完成 = true
	print("界面字号放大回归测试 —— 判 %d 条，红 %d 条" % [判, 红.size()])
	for 行 in 日志:
		print(行)
	for 行 in 红:
		push_error(行)
	quit(1 if not 红.is_empty() else 0)
